import SwiftUI
import AVFoundation
import UIKit
import Observation

@Observable
class WorkoutManager {
    var isActive = false
    var isPaused = false
    var isCompleted = false
    var currentWorkout: Workout?
    var currentPhase: WorkoutPhase = .warmup
    var currentRound = 1
    var remainingTime = 0
    var presets: [Workout] = []
    var lastWorkout: Workout?
    var currentIntervalIndex = 0
    var totalIntervalCount = 0

    @ObservationIgnored private var timer: Timer?
    // Wall-clock time at which the current phase ends. Driving the countdown
    // from a target date (instead of decrementing a counter) keeps phase
    // durations exact, avoids timer drift, and lets the timer catch up when
    // the app returns to the foreground. Nil whenever the timer isn't running.
    @ObservationIgnored private var phaseEndDate: Date?
    @ObservationIgnored private var expandedIntervals: [CustomInterval] = []
    @ObservationIgnored private let soundManager = SoundManager.shared
    
    var timeString: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var currentPhaseText: String {
        switch currentPhase {
        case .warmup:
            return "WARM UP"
        case .work:
            return "WORK"
        case .rest:
            return "REST"
        case .customInterval(let index):
            guard index < expandedIntervals.count else { return "" }
            return expandedIntervals[index].label.uppercased()
        case .complete:
            return "COMPLETE!"
        }
    }
    
    var currentPhaseColor: Color {
        switch currentPhase {
        case .warmup:
            return .orange
        case .work:
            return .red
        case .rest:
            return .blue
        case .customInterval(let index):
            guard index < expandedIntervals.count else { return .clear }
            return expandedIntervals[index].color.swiftUIColor
        case .complete:
            return .green
        }
    }
    
    init() {
        loadPresets()
        loadLastWorkout()
        soundManager.setupAudioSession()
    }
    
    func startWorkout(_ workout: Workout) {
        currentWorkout = workout
        currentRound = 1
        isActive = true
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = true
        saveLastWorkout(workout)

        if workout.isCustom, let groups = workout.resolvedGroups {
            expandedIntervals = groups.flatMap { group in
                (0..<max(group.repeatCount, 1)).flatMap { _ in group.intervals }
            }
            totalIntervalCount = expandedIntervals.count
            currentIntervalIndex = 0
            let first = expandedIntervals[0]
            startPhase(.customInterval(index: 0), duration: first.duration)
            soundManager.playIntervalChime()
        } else {
            if workout.warmupDuration > 0 {
                startPhase(.warmup, duration: workout.warmupDuration)
            } else {
                startPhase(.work, duration: workout.workDuration)
            }
            soundManager.playIntervalChime()
        }

        soundManager.startKeepAlive()
        startTimer()
    }
    
    func pause() {
        isPaused = true

        // Freeze the remaining time so it can be resumed from exactly here.
        if let end = phaseEndDate {
            remainingTime = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        }
        phaseEndDate = nil
        timer?.invalidate()
        timer = nil

        // Nothing needs to run while paused, so let the system suspend us
        // in the background instead of holding audio open.
        soundManager.stopKeepAlive()

        // Allow screen to lock when paused
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func resume() {
        isPaused = false

        // Recompute the end date from the frozen remaining time.
        phaseEndDate = Date().addingTimeInterval(TimeInterval(remainingTime))

        // Prevent screen from locking when workout resumes
        UIApplication.shared.isIdleTimerDisabled = true

        soundManager.startKeepAlive()
        startTimer()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        phaseEndDate = nil
        isActive = false
        isPaused = false
        isCompleted = false
        currentWorkout = nil
        currentPhase = .warmup
        currentRound = 1
        remainingTime = 0
        currentIntervalIndex = 0
        totalIntervalCount = 0
        expandedIntervals = []
        soundManager.stopKeepAlive()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func skipPhase() {
        advancePhase()

        // If the workout was paused, advance to the next phase but stay paused:
        // freeze its target date so it doesn't count down until the user resumes.
        // remainingTime already holds the new phase's full duration, and no timer
        // is running while paused.
        if isPaused {
            phaseEndDate = nil
        }
    }

    /// Re-syncs the countdown when the app returns to the foreground. The timer
    /// is suspended by the system while backgrounded, so we re-evaluate elapsed
    /// time and restart ticking unless the workout is paused.
    func syncOnForeground() {
        guard isActive, !isPaused else { return }
        if timer == nil {
            startTimer()
        }
        tick()
    }

    /// Configures the current phase and its target end date in one place.
    /// `start` defaults to now; automatic transitions pass the previous
    /// phase's end date so consecutive phases chain without drift.
    private func startPhase(_ phase: WorkoutPhase, duration: Int, startingAt start: Date = Date()) {
        currentPhase = phase
        remainingTime = duration
        phaseEndDate = start.addingTimeInterval(TimeInterval(duration))
    }

    private func startTimer() {
        timer?.invalidate()
        // Fire several times a second so the display and phase transitions stay
        // responsive; the actual timing comes from phaseEndDate.
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let now = Date()

        // Advance through every phase whose end date has passed. Normally that's
        // at most one, but if ticks were delayed (e.g. the app was suspended)
        // several may have elapsed. Each new phase starts exactly when the
        // previous one ended so no time is lost, and cues only play for
        // transitions happening now rather than stale ones being caught up.
        while let end = phaseEndDate, end <= now {
            advancePhase(startingAt: end, playCues: now.timeIntervalSince(end) < 1)
        }

        guard let end = phaseEndDate else { return }
        let newRemaining = max(0, Int(end.timeIntervalSince(now).rounded(.up)))

        // Play countdown beeps as we cross into 3, 2 and 1 seconds remaining.
        if newRemaining < remainingTime && (1...3).contains(newRemaining) {
            soundManager.playCountdownBeep()
            if newRemaining == 3 { soundManager.prepareHaptic() }
        }

        if newRemaining != remainingTime {
            remainingTime = newRemaining
        }
    }
    
    private func advancePhase(startingAt start: Date = Date(), playCues: Bool = true) {
        guard let workout = currentWorkout else { return }
        
        switch currentPhase {
        case .warmup:
            startPhase(.work, duration: workout.workDuration, startingAt: start)
            
        case .work:
            if currentRound < workout.rounds {
                startPhase(.rest, duration: workout.restDuration, startingAt: start)
            } else {
                completeWorkout(playCues: playCues)
                return
            }
            
        case .rest:
            currentRound += 1
            startPhase(.work, duration: workout.workDuration, startingAt: start)

        case .customInterval(let index):
            let nextIndex = index + 1
            if nextIndex < expandedIntervals.count {
                currentIntervalIndex = nextIndex
                let next = expandedIntervals[nextIndex]
                startPhase(.customInterval(index: nextIndex), duration: next.duration, startingAt: start)
            } else {
                completeWorkout(playCues: playCues)
                return
            }
            
        case .complete:
            stop()
            return
        }

        if playCues {
            soundManager.playIntervalChime()
            soundManager.triggerHaptic()
        }
    }
    
    private func completeWorkout(playCues: Bool = true) {
        currentPhase = .complete
        remainingTime = 0
        phaseEndDate = nil
        timer?.invalidate()
        timer = nil
        isCompleted = true
        soundManager.stopKeepAlive()

        if playCues {
            soundManager.playIntervalChime()
            soundManager.triggerHaptic(style: .success)
        }
    }
    
    // MARK: - Preset Management
    
    func savePreset(_ workout: Workout) {
        if let index = presets.firstIndex(where: { $0.id == workout.id }) {
            presets[index] = workout
        } else {
            presets.append(workout)
        }
        savePresetsToUserDefaults()
    }
    
    func deletePreset(_ workout: Workout) {
        presets.removeAll { $0.id == workout.id }
        savePresetsToUserDefaults()
    }
    
    private func savePresetsToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: "workoutPresets")
        }
    }
    
    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: "workoutPresets"),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            presets = decoded
        }
    }
    
    private func saveLastWorkout(_ workout: Workout) {
        lastWorkout = workout
        if let encoded = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(encoded, forKey: "lastWorkout")
        }
    }
    
    private func loadLastWorkout() {
        if let data = UserDefaults.standard.data(forKey: "lastWorkout"),
           let decoded = try? JSONDecoder().decode(Workout.self, from: data) {
            lastWorkout = decoded
        }
    }
}

enum WorkoutPhase: Equatable {
    case warmup
    case work
    case rest
    case customInterval(index: Int)
    case complete
}

enum IntervalColor: String, Codable, CaseIterable, Identifiable {
    case fieryRed, coral, orange, amber
    case yellow, lime, green, teal
    case cyan, skyBlue, blue, indigo
    case purple, magenta, pink, gray

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .fieryRed: return .red
        case .coral: return Color(red: 1.0, green: 0.5, blue: 0.31)
        case .orange: return .orange
        case .amber: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .yellow: return .yellow
        case .lime: return Color(red: 0.5, green: 0.85, blue: 0.2)
        case .green: return .green
        case .teal: return .teal
        case .cyan: return .cyan
        case .skyBlue: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .magenta: return Color(red: 0.85, green: 0.2, blue: 0.6)
        case .pink: return .pink
        case .gray: return .gray
        }
    }
}

struct CustomInterval: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var duration: Int
    var color: IntervalColor

    init(id: UUID = UUID(), label: String, duration: Int, color: IntervalColor) {
        self.id = id
        self.label = label
        self.duration = duration
        self.color = color
    }
}

struct IntervalGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var intervals: [CustomInterval]
    var repeatCount: Int

    init(id: UUID = UUID(), intervals: [CustomInterval] = [], repeatCount: Int = 1) {
        self.id = id
        self.intervals = intervals
        self.repeatCount = repeatCount
    }
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var warmupDuration: Int
    var workDuration: Int
    var restDuration: Int
    var rounds: Int
    var customIntervals: [CustomInterval]?
    var repeatCount: Int?
    var intervalGroups: [IntervalGroup]?

    var isCustom: Bool {
        resolvedGroups != nil
    }

    var resolvedGroups: [IntervalGroup]? {
        if let groups = intervalGroups, groups.contains(where: { !$0.intervals.isEmpty }) {
            return groups
        }
        if let intervals = customIntervals, !intervals.isEmpty {
            return [IntervalGroup(intervals: intervals, repeatCount: repeatCount ?? 1)]
        }
        return nil
    }

    init(id: UUID = UUID(), name: String, warmupDuration: Int, workDuration: Int, restDuration: Int, rounds: Int) {
        self.id = id
        self.name = name
        self.warmupDuration = warmupDuration
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.rounds = rounds
    }

    init(id: UUID = UUID(), name: String, intervalGroups: [IntervalGroup]) {
        self.id = id
        self.name = name
        self.warmupDuration = 0
        self.workDuration = 0
        self.restDuration = 0
        self.rounds = 1
        self.intervalGroups = intervalGroups
    }
}

class SoundManager {
    static let shared = SoundManager()
    
    private let countdownBeep = CuePlayer(resource: "countdown_beep", volume: 0.8, fallbackSoundID: 1103)
    private let intervalChime = CuePlayer(resource: "interval_chime", volume: 1.0, fallbackSoundID: 1013)

    // iOS suspends a backgrounded app within seconds unless it is actively
    // playing audio (with the "audio" background mode). While a workout is
    // running we loop silence through this engine so the timer keeps ticking
    // and cues keep sounding when the user switches to another app.
    private let keepAliveEngine = AVAudioEngine()
    private let silencePlayer = AVAudioPlayerNode()
    private var keepAliveRequested = false
    private var isActivatingKeepAlive = false

    private init() {
        observeAudioEvents()
    }
    
    /// Only sets the category. The session isn't activated until a workout
    /// starts, so launching the app never interrupts the user's music.
    func setupAudioSession() {
        sessionQueue.async {
            // Use .playback so sounds bypass the silent switch, and .mixWithOthers
            // so the user's background audio (music, podcasts) keeps playing while
            // our beeps and chimes play over the top.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
    }

    /// Audio session calls can block, so they run on this serial queue instead
    /// of the main thread. Being serial also guarantees the category is set
    /// before any activation.
    private let sessionQueue = DispatchQueue(label: "SoundManager.session")

    /// Activates the audio session without blocking the main thread, then
    /// calls `completion` on the main actor with whether activation succeeded.
    private func activateSession(then completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        sessionQueue.async {
            AVAudioSession.sharedInstance().activate { success, _ in
                Task { @MainActor in completion(success) }
            }
        }
    }

    /// Starts looping silence so the app stays alive in the background.
    func startKeepAlive() {
        keepAliveRequested = true
        guard !keepAliveEngine.isRunning, !isActivatingKeepAlive else { return }

        isActivatingKeepAlive = true
        activateSession { [weak self] success in
            guard let self else { return }
            isActivatingKeepAlive = false
            // The workout may have been paused or stopped while activating.
            guard success, keepAliveRequested, !keepAliveEngine.isRunning else { return }
            startSilenceLoop()
        }
    }

    private func startSilenceLoop() {
        // Build the engine graph on first use rather than at launch, so the
        // app doesn't set up audio output until a workout actually starts.
        if silencePlayer.engine == nil {
            keepAliveEngine.attach(silencePlayer)
            keepAliveEngine.connect(silencePlayer, to: keepAliveEngine.mainMixerNode, format: nil)
        }

        let format = silencePlayer.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate)) else { return }
        buffer.frameLength = buffer.frameCapacity
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                channels[channel].update(repeating: 0, count: Int(buffer.frameLength))
            }
        }

        do {
            try keepAliveEngine.start()
            silencePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            silencePlayer.play()
        } catch {}
    }

    /// Stops the silent loop so the system can suspend the app normally.
    func stopKeepAlive() {
        keepAliveRequested = false
        silencePlayer.stop()
        keepAliveEngine.stop()
    }

    /// Restarts the silent loop after the system stopped it.
    private func restartKeepAliveIfNeeded() {
        guard keepAliveRequested else { return }
        silencePlayer.stop()
        keepAliveEngine.stop()
        startKeepAlive()
    }

    /// Phone calls, Siri, alarms and route changes (e.g. unplugging headphones)
    /// stop our audio. Restart it afterwards so cues and background
    /// keep-alive continue for the rest of the workout.
    private func observeAudioEvents() {
        Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance()
            ) {
                guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: rawType) == .ended else { continue }
                self?.restartKeepAliveIfNeeded()
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: .AVAudioEngineConfigurationChange,
                object: self?.keepAliveEngine
            ) {
                self?.restartKeepAliveIfNeeded()
            }
        }
    }
    
    func playCountdownBeep() {
        countdownBeep.play()
    }

    func playIntervalChime() {
        intervalChime.play()
    }
    
    private let hapticGenerator = UINotificationFeedbackGenerator()

    func triggerHaptic(style: UINotificationFeedbackGenerator.FeedbackType = .warning) {
        hapticGenerator.notificationOccurred(style)
    }

    func prepareHaptic() {
        hapticGenerator.prepare()
    }
}

/// Plays a short bundled sound cue. AVAudioPlayer touches the audio session
/// synchronously when preparing and playing, so the player is only ever used
/// on a private serial queue to keep those calls off the main thread.
/// The file is loaded on first play rather than at init, because preparing a
/// player activates the audio session, which would interrupt other audio at launch.
nonisolated final class CuePlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "SoundManager.CuePlayer", qos: .userInteractive)
    private let resource: String
    private let volume: Float
    private let fallbackSoundID: SystemSoundID
    private var player: AVAudioPlayer?

    init(resource: String, volume: Float, fallbackSoundID: SystemSoundID) {
        self.resource = resource
        self.volume = volume
        self.fallbackSoundID = fallbackSoundID
    }

    /// Plays from the start, or a system sound if the file couldn't be loaded.
    func play() {
        queue.async { [self] in
            if player == nil, let url = Bundle.main.url(forResource: resource, withExtension: "wav") {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = volume
            }
            if let player {
                player.currentTime = 0
                player.play()
            } else {
                AudioServicesPlaySystemSound(fallbackSoundID)
            }
        }
    }
}

func formatTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    if mins == 0 { return "\(secs)s" }
    if secs == 0 { return "\(mins)m" }
    return "\(mins)m \(secs)s"
}
