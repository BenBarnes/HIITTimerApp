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
    
    // Custom mode
    @State private var customIntervals: [CustomInterval] = []
    
    @State private var saveAsPreset = false
    
    enum SetupMode {
        case simple
        case custom
    }
    
    var body: some View {
        NavigationStack {
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
            DurationPicker(label: "Warm-up", icon: "figure.walk", minutes: $warmupMinutes, seconds: $warmupSeconds)
            DurationPicker(label: "Work Interval", icon: "flame.fill", minutes: $workMinutes, seconds: $workSeconds)
            DurationPicker(label: "Rest Interval", icon: "pause.circle.fill", minutes: $restMinutes, seconds: $restSeconds)
            roundsStepper
        }
    }
    
    var roundsStepper: some View {
        GroupBox(label: Label("Rounds", systemImage: "repeat")) {
            Stepper("\(rounds) rounds", value: $rounds, in: 1...99)
                .padding(.horizontal)
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
            rounds: rounds
        )
        
        if saveAsPreset && !workoutName.isEmpty {
            workoutManager.savePreset(workout)
        }
        
        workoutManager.startWorkout(workout)
        dismiss()
    }
}

struct DurationPicker: View {
    let label: String
    let icon: String
    @Binding var minutes: Int
    @Binding var seconds: Int
    
    var body: some View {
        GroupBox(label: Label(label, systemImage: icon)) {
            HStack {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                Text("min")
                
                Picker("Seconds", selection: $seconds) {
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
