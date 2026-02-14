import SwiftUI

struct WorkoutSetupView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    
    @State private var setupMode: SetupMode = .simple
    @State private var workoutName = ""
    
    // Simple mode
    @State private var warmupMinutes = 0
    @State private var warmupSeconds = 30
    @State private var workMinutes = 0
    @State private var workSeconds = 45
    @State private var restMinutes = 0
    @State private var restSeconds = 15
    @State private var rounds = 8
    @State private var selectedSound: WorkoutSound = .chime
    
    // Custom mode
    @State private var customIntervals: [CustomInterval] = []
    
    @State private var saveAsPreset = false
    
    enum SetupMode {
        case simple
        case custom
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Mode selector
                        Picker("Setup Mode", selection: $setupMode) {
                            Text("Simple").tag(SetupMode.simple)
                            Text("Custom").tag(SetupMode.custom)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if setupMode == .simple {
                            simpleSetupView
                        } else {
                            customSetupView
                        }
                        
                        soundSelectionView
                        
                        // Save as preset option
                        Toggle("Save as Preset", isOn: $saveAsPreset)
                            .padding(.horizontal)
                        
                        if saveAsPreset {
                            TextField("Workout Name", text: $workoutName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                        
                        startButton
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    var simpleSetupView: some View {
        VStack(spacing: 20) {
            warmupPicker
            workPicker
            restPicker
            roundsStepper
        }
    }
    
    var warmupPicker: some View {
        GroupBox(label: Label("Warm-up", systemImage: "figure.walk")) {
            HStack {
                Picker("Minutes", selection: $warmupMinutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("min")
                
                Picker("Seconds", selection: $warmupSeconds) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("sec")
            }
            .frame(height: 100)
        }
        .padding(.horizontal)
    }
    
    var workPicker: some View {
        GroupBox(label: Label("Work Interval", systemImage: "flame.fill")) {
            HStack {
                Picker("Minutes", selection: $workMinutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("min")
                
                Picker("Seconds", selection: $workSeconds) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("sec")
            }
            .frame(height: 100)
        }
        .padding(.horizontal)
    }
    
    var restPicker: some View {
        GroupBox(label: Label("Rest Interval", systemImage: "pause.circle.fill")) {
            HStack {
                Picker("Minutes", selection: $restMinutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("min")
                
                Picker("Seconds", selection: $restSeconds) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("sec")
            }
            .frame(height: 100)
        }
        .padding(.horizontal)
    }
    
    var roundsStepper: some View {
        GroupBox(label: Label("Rounds", systemImage: "repeat")) {
            Stepper("\(rounds) rounds", value: $rounds, in: 1...99)
                .padding(.horizontal)
        }
        .padding(.horizontal)
    }
    
    var soundSelectionView: some View {
        GroupBox(label: Label("Alert Sound", systemImage: "speaker.wave.2.fill")) {
            Picker("Sound", selection: $selectedSound) {
                ForEach(WorkoutSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding(.horizontal)
    }
    
    var startButton: some View {
        Button(action: startWorkout) {
            Text("Start Workout")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var customSetupView: some View {
        VStack(spacing: 15) {
            Text("Custom intervals coming in advanced version")
                .foregroundColor(.secondary)
                .padding()
            
            Text("For now, use Simple mode to set up work/rest intervals")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    func startWorkout() {
        let warmupTime = warmupMinutes * 60 + warmupSeconds
        let workTime = workMinutes * 60 + workSeconds
        let restTime = restMinutes * 60 + restSeconds
        
        let workout = Workout(
            name: workoutName.isEmpty ? "HIIT Workout" : workoutName,
            warmupDuration: warmupTime,
            workDuration: workTime,
            restDuration: restTime,
            rounds: rounds,
            sound: selectedSound
        )
        
        if saveAsPreset && !workoutName.isEmpty {
            workoutManager.savePreset(workout)
        }
        
        workoutManager.startWorkout(workout)
        dismiss()
    }
}

struct CustomInterval: Identifiable {
    let id = UUID()
    var name: String
    var duration: Int
    var type: IntervalType
    
    enum IntervalType {
        case work
        case rest
    }
}
