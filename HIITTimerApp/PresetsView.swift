import SwiftUI

struct PresetsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    @State private var editingPreset: Workout?
    
    var body: some View {
        NavigationStack {
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
                                        editingPreset = preset
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
            
            if preset.isCustom, let groups = preset.resolvedGroups {
                let allIntervals = groups.flatMap { $0.intervals }
                HStack(spacing: 4) {
                    ForEach(allIntervals.prefix(8)) { interval in
                        Circle()
                            .fill(interval.color.swiftUIColor)
                            .frame(width: 10, height: 10)
                    }
                    if allIntervals.count > 8 {
                        Text("+\(allIntervals.count - 8)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 15) {
                    Label("\(groups.count) groups", systemImage: "rectangle.stack")
                        .font(.caption)
                        .foregroundColor(.purple)
                    let totalIntervals = groups.reduce(0) { $0 + $1.intervals.count * max($1.repeatCount, 1) }
                    Label("\(totalIntervals) intervals", systemImage: "list.number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                let totalSeconds = groups.reduce(0) { total, group in
                    let groupTime = group.intervals.reduce(0) { $0 + $1.duration }
                    return total + groupTime * max(group.repeatCount, 1)
                }
                Text("Total: \(formatTime(totalSeconds))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
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
                
                Text("\(preset.rounds) rounds")
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
    // Simple mode state
    @State private var warmupMinutes = 0
    @State private var warmupSeconds = 0
    @State private var workMinutes = 0
    @State private var workSeconds = 0
    @State private var restMinutes = 0
    @State private var restSeconds = 0
    @State private var rounds = 1
    // Custom mode state
    @State private var intervalGroups: [IntervalGroup] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
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
                        
                        if preset.isCustom {
                            GroupedIntervalEditor(groups: $intervalGroups)
                        } else {
                            DurationPicker(label: "Warm-up", icon: "figure.walk", minutes: $warmupMinutes, seconds: $warmupSeconds)
                            DurationPicker(label: "Work Interval", icon: "flame.fill", minutes: $workMinutes, seconds: $workSeconds)
                            DurationPicker(label: "Rest Interval", icon: "pause.circle.fill", minutes: $restMinutes, seconds: $restSeconds)
                            
                            GroupBox(label: Label("Rounds", systemImage: "repeat")) {
                                Stepper("\(rounds) rounds", value: $rounds, in: 1...99)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            .padding(.horizontal)
                        }

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
                loadPresetData()
            }
        }
    }
    
    func loadPresetData() {
        workoutName = preset.name
        if preset.isCustom {
            intervalGroups = preset.resolvedGroups ?? []
        } else {
            warmupMinutes = preset.warmupDuration / 60
            warmupSeconds = preset.warmupDuration % 60
            workMinutes = preset.workDuration / 60
            workSeconds = preset.workDuration % 60
            restMinutes = preset.restDuration / 60
            restSeconds = preset.restDuration % 60
            rounds = preset.rounds
        }
    }
    
    func saveChanges() {
        let updatedWorkout: Workout
        if preset.isCustom {
            updatedWorkout = Workout(
                id: preset.id,
                name: workoutName,
                intervalGroups: intervalGroups.filter { !$0.intervals.isEmpty }
            )
        } else {
            let warmupTime = warmupMinutes * 60 + warmupSeconds
            let workTime = workMinutes * 60 + workSeconds
            let restTime = restMinutes * 60 + restSeconds
            updatedWorkout = Workout(
                id: preset.id,
                name: workoutName,
                warmupDuration: warmupTime,
                workDuration: workTime,
                restDuration: restTime,
                rounds: rounds
            )
        }
        workoutManager.savePreset(updatedWorkout)
        dismiss()
    }
}
