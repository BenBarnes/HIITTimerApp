import SwiftUI
import Combine
import AVFoundation
import UIKit

class WorkoutManager: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var isCompleted = false
    @Published var currentWorkout: Workout?
    @Published var currentPhase: WorkoutPhase = .warmup
    @Published var currentRound = 1
    @Published var remainingTime = 0
    @Published var presets: [Workout] = []
    @Published var currentIntervalIndex = 0
    @Published var totalIntervalCount = 0
    
    private var timer: Timer?
    private var expandedIntervals: [CustomInterval] = []
    private let soundManager = SoundManager.shared
    
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
        soundManager.setupAudioSession()
    }
    
    func startWorkout(_ workout: Workout) {
        currentWorkout = workout
        currentRound = 1
        isActive = true
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = true

        if workout.isCustom {
            let intervals = workout.customIntervals!
            let repeats = max(workout.repeatCount ?? 1, 1)
            expandedIntervals = (0..<repeats).flatMap { _ in intervals }
            totalIntervalCount = expandedIntervals.count
            currentIntervalIndex = 0
            let first = expandedIntervals[0]
            currentPhase = .customInterval(index: 0)
            remainingTime = first.duration
            soundManager.playIntervalChime()
        } else {
            if workout.warmupDuration > 0 {
                currentPhase = .warmup
                remainingTime = workout.warmupDuration
            } else {
                currentPhase = .work
                remainingTime = workout.workDuration
            }
            soundManager.playIntervalChime()
        }

        startTimer()
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil

        // Allow screen to lock when paused
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func resume() {
        isPaused = false

        // Prevent screen from locking when workout resumes
        UIApplication.shared.isIdleTimerDisabled = true

        startTimer()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
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
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func skipPhase() {
        remainingTime = 0
        advancePhase()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.remainingTime > 0 {
                // Play countdown beeps at exactly 3, 2, and 1 seconds remaining
                // Check BEFORE decrementing
                if self.remainingTime == 3 || self.remainingTime == 2 || self.remainingTime == 1 {
                    self.soundManager.playCountdownBeep()
                }
                
                self.remainingTime -= 1
            } else {
                self.advancePhase()
            }
        }
    }
    
    private func advancePhase() {
        guard let workout = currentWorkout else { return }
        
        switch currentPhase {
        case .warmup:
            currentPhase = .work
            remainingTime = workout.workDuration
            soundManager.playIntervalChime()
            soundManager.triggerHaptic()
            
        case .work:
            if currentRound < workout.rounds {
                currentPhase = .rest
                remainingTime = workout.restDuration
                soundManager.playIntervalChime()
                soundManager.triggerHaptic()
            } else {
                completeWorkout()
            }
            
        case .rest:
            currentRound += 1
            currentPhase = .work
            remainingTime = workout.workDuration
            soundManager.playIntervalChime()
            soundManager.triggerHaptic()

        case .customInterval(let index):
            let nextIndex = index + 1
            if nextIndex < expandedIntervals.count {
                currentIntervalIndex = nextIndex
                let next = expandedIntervals[nextIndex]
                currentPhase = .customInterval(index: nextIndex)
                remainingTime = next.duration
                soundManager.playIntervalChime()
                soundManager.triggerHaptic()
            } else {
                completeWorkout()
            }
            
        case .complete:
            stop()
        }
    }
    
    private func completeWorkout() {
        currentPhase = .complete
        remainingTime = 0
        timer?.invalidate()
        timer = nil
        isCompleted = true

        soundManager.playIntervalChime()
        soundManager.triggerHaptic(style: .success)
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

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var warmupDuration: Int
    var workDuration: Int
    var restDuration: Int
    var rounds: Int
    var customIntervals: [CustomInterval]?
    var repeatCount: Int?

    var isCustom: Bool { customIntervals != nil && !(customIntervals!.isEmpty) }

    init(id: UUID = UUID(), name: String, warmupDuration: Int, workDuration: Int, restDuration: Int, rounds: Int) {
        self.id = id
        self.name = name
        self.warmupDuration = warmupDuration
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.rounds = rounds
    }

    init(id: UUID = UUID(), name: String, customIntervals: [CustomInterval], repeatCount: Int = 1) {
        self.id = id
        self.name = name
        self.warmupDuration = 0
        self.workDuration = 0
        self.restDuration = 0
        self.rounds = 1
        self.customIntervals = customIntervals
        self.repeatCount = repeatCount
    }
}

class SoundManager {
    static let shared = SoundManager()
    
    private var countdownBeepPlayer: AVAudioPlayer?
    private var intervalChimePlayer: AVAudioPlayer?
    
    private init() {}
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use .playback category to bypass silent switch
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            loadAudioFiles()
        } catch {}
    }
    
    private func loadAudioFiles() {
        if let beepURL = Bundle.main.url(forResource: "countdown_beep", withExtension: "wav") {
            countdownBeepPlayer = try? AVAudioPlayer(contentsOf: beepURL)
            countdownBeepPlayer?.prepareToPlay()
            countdownBeepPlayer?.volume = 0.8
        }
        
        if let chimeURL = Bundle.main.url(forResource: "interval_chime", withExtension: "wav") {
            intervalChimePlayer = try? AVAudioPlayer(contentsOf: chimeURL)
            intervalChimePlayer?.prepareToPlay()
            intervalChimePlayer?.volume = 1.0
        }
    }
    
    func playCountdownBeep() {
        if let player = countdownBeepPlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1103)
        }
    }
    
    func playIntervalChime() {
        if let player = intervalChimePlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1013)
        }
    }
    
    func triggerHaptic(style: UINotificationFeedbackGenerator.FeedbackType = .warning) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
    }
}
