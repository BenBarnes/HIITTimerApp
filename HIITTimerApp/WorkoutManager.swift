import SwiftUI
import Combine
import AVFoundation

class WorkoutManager: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentWorkout: Workout?
    @Published var currentPhase: WorkoutPhase = .warmup
    @Published var currentRound = 1
    @Published var remainingTime = 0
    @Published var presets: [Workout] = []
    
    private var timer: Timer?
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
        
        if workout.warmupDuration > 0 {
            currentPhase = .warmup
            remainingTime = workout.warmupDuration
            // Play chime immediately when starting
            soundManager.playIntervalChime()
        } else {
            currentPhase = .work
            remainingTime = workout.workDuration
            // Play chime immediately when starting
            soundManager.playIntervalChime()
        }
        
        startTimer()
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        isPaused = false
        startTimer()
    }
    
    func stop() {
        isActive = false
        isPaused = false
        currentWorkout = nil
        currentRound = 1
        remainingTime = 0
        timer?.invalidate()
        timer = nil
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
                    print("Countdown beep: \(self.remainingTime) seconds remaining")
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
            
        case .complete:
            stop()
        }
    }
    
    private func completeWorkout() {
        currentPhase = .complete
        remainingTime = 0
        timer?.invalidate()
        timer = nil
        
        soundManager.playIntervalChime()
        soundManager.triggerHaptic(style: .success)
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.stop()
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
    
    func updatePreset(_ workout: Workout) {
        if let index = presets.firstIndex(where: { $0.id == workout.id }) {
            presets[index] = workout
            savePresetsToUserDefaults()
        }
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

enum WorkoutPhase {
    case warmup
    case work
    case rest
    case complete
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var warmupDuration: Int
    var workDuration: Int
    var restDuration: Int
    var rounds: Int
    var sound: WorkoutSound
    
    init(id: UUID = UUID(), name: String, warmupDuration: Int, workDuration: Int, restDuration: Int, rounds: Int, sound: WorkoutSound = .chime) {
        self.id = id
        self.name = name
        self.warmupDuration = warmupDuration
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.rounds = rounds
        self.sound = sound
    }
}

enum WorkoutSound: String, CaseIterable, Codable {
    case chime = "Chime"
    case bell = "Bell"
    case tone = "Tone"
    case alert = "Alert"
    case horn = "Horn"
    case beep = "Beep"
    case complete = "Complete"
    
    var displayName: String {
        return self.rawValue
    }
    
    var systemSoundID: SystemSoundID {
        switch self {
        case .chime:
            return 1013
        case .bell:
            return 1005
        case .tone:
            return 1304
        case .alert:
            return 1007
        case .horn:
            return 1009
        case .beep:
            return 1103
        case .complete:
            return 1016
        }
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
            print("✓ Audio session configured - sounds will bypass silent switch")
            
            // Load audio files
            loadAudioFiles()
        } catch {
            print("⚠️ Audio session setup failed: \(error.localizedDescription)")
        }
    }
    
    private func loadAudioFiles() {
        // Load countdown beep
        if let beepURL = Bundle.main.url(forResource: "countdown_beep", withExtension: "wav") {
            do {
                countdownBeepPlayer = try AVAudioPlayer(contentsOf: beepURL)
                countdownBeepPlayer?.prepareToPlay()
                countdownBeepPlayer?.volume = 0.8
                print("✓ Countdown beep loaded")
            } catch {
                print("⚠️ Failed to load countdown beep: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ countdown_beep.wav not found in bundle")
        }
        
        // Load interval chime
        if let chimeURL = Bundle.main.url(forResource: "interval_chime", withExtension: "wav") {
            do {
                intervalChimePlayer = try AVAudioPlayer(contentsOf: chimeURL)
                intervalChimePlayer?.prepareToPlay()
                intervalChimePlayer?.volume = 1.0
                print("✓ Interval chime loaded")
            } catch {
                print("⚠️ Failed to load interval chime: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ interval_chime.wav not found in bundle")
        }
    }
    
    func playCountdownBeep() {
        if let player = countdownBeepPlayer {
            player.currentTime = 0
            player.play()
            print("🔊 Countdown beep")
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1103)
            print("🔊 Countdown beep (system sound fallback)")
        }
    }
    
    func playIntervalChime() {
        if let player = intervalChimePlayer {
            player.currentTime = 0
            player.play()
            print("🔔 Interval chime")
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1013)
            print("🔔 Interval chime (system sound fallback)")
        }
    }
    
    func triggerHaptic(style: UINotificationFeedbackGenerator.FeedbackType = .warning) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
    }
}
