import SwiftUI

struct PresetsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    @State private var editingPreset: Workout?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if workoutManager.presets.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No saved presets")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Create a workout and save it as a preset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(workoutManager.presets) { preset in
                            PresetRow(preset: preset)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    workoutManager.startWorkout(preset)
                                    dismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        workoutManager.deletePreset(preset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        print("Edit button tapped for: \(preset.name)")
                                        editingPreset = preset
                                        print("editingPreset set to: \(preset.name)")
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Workout Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingPreset) { preset in
                EditPresetView(workoutManager: workoutManager, preset: preset)
            }
        }
    }
}

struct PresetRow: View {
    let preset: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(preset.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 15) {
                if preset.warmupDuration > 0 {
                    Label("\(formatTime(preset.warmupDuration)) warmup", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Label("\(formatTime(preset.workDuration)) work", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Label("\(formatTime(preset.restDuration)) rest", systemImage: "pause.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("\(preset.rounds) rounds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Sound: \(preset.sound.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
    
    func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(mins)m"
            } else {
                return "\(mins)m \(secs)s"
            }
        }
    }
}

struct EditPresetView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    
    let preset: Workout
    
    @State private var workoutName = ""
    @State private var warmupMinutes = 0
    @State private var warmupSeconds = 0
    @State private var workMinutes = 0
    @State private var workSeconds = 0
    @State private var restMinutes = 0
    @State private var restSeconds = 0
    @State private var rounds = 1
    @State private var selectedSound: WorkoutSound = .chime
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Workout Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Name")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            TextField("Name", text: $workoutName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // Warm-up
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
                            .frame(height: 120)
                        }
                        .padding(.horizontal)
                        
                        // Work interval
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
                            .frame(height: 120)
                        }
                        .padding(.horizontal)
                        
                        // Rest interval
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
                            .frame(height: 120)
                        }
                        .padding(.horizontal)
                        
                        // Number of rounds
                        GroupBox(label: Label("Rounds", systemImage: "repeat")) {
                            Stepper("\(rounds) rounds", value: $rounds, in: 1...99)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Sound selection
                        GroupBox(label: Label("Alert Sound", systemImage: "speaker.wave.2.fill")) {
                            Picker("Sound", selection: $selectedSound) {
                                ForEach(WorkoutSound.allCases, id: \.self) { sound in
                                    Text(sound.displayName).tag(sound)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("Edit: \(preset.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                print("EditPresetView appeared for: \(preset.name)")
                loadPresetData()
            }
        }
    }
    
    func loadPresetData() {
        workoutName = preset.name
        warmupMinutes = preset.warmupDuration / 60
        warmupSeconds = preset.warmupDuration % 60
        workMinutes = preset.workDuration / 60
        workSeconds = preset.workDuration % 60
        restMinutes = preset.restDuration / 60
        restSeconds = preset.restDuration % 60
        rounds = preset.rounds
        selectedSound = preset.sound
        print("Data loaded - Name: \(workoutName), Work: \(workMinutes):\(workSeconds), Rest: \(restMinutes):\(restSeconds), Rounds: \(rounds)")
    }
    
    func saveChanges() {
        let warmupTime = warmupMinutes * 60 + warmupSeconds
        let workTime = workMinutes * 60 + workSeconds
        let restTime = restMinutes * 60 + restSeconds
        
        let updatedWorkout = Workout(
            id: preset.id,
            name: workoutName,
            warmupDuration: warmupTime,
            workDuration: workTime,
            restDuration: restTime,
            rounds: rounds,
            sound: selectedSound
        )
        
        workoutManager.updatePreset(updatedWorkout)
        print("Preset saved: \(workoutName)")
        dismiss()
    }
}
