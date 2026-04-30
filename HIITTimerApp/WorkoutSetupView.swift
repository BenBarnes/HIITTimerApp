import SwiftUI

struct WorkoutSetupView: View {
    @ObservedObject var workoutManager: WorkoutManager
    var prefillWorkout: Workout? = nil
    var editingPreset: Workout? = nil
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
    @State private var intervalGroups: [IntervalGroup] = []

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
                        if editingPreset != nil {
                            TextField("Workout Name", text: $workoutName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                        }

                        if editingPreset == nil {
                            Picker("Setup Mode", selection: $setupMode) {
                                Text("Simple").tag(SetupMode.simple)
                                Text("Custom").tag(SetupMode.custom)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                        }

                        if setupMode == .simple {
                            simpleSetupView
                        } else {
                            customSetupView
                        }

                        if editingPreset != nil {
                            savePresetButton
                        } else {
                            Toggle("Save as Preset", isOn: $saveAsPreset)
                                .padding(.horizontal)

                            if saveAsPreset {
                                TextField("Workout Name", text: $workoutName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }

                            startButton
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(editingPreset != nil ? "Edit Preset" : prefillWorkout != nil ? "Edit Workout" : "New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard let workout = editingPreset ?? prefillWorkout else { return }
                workoutName = workout.name
                if workout.isCustom {
                    setupMode = .custom
                    intervalGroups = workout.resolvedGroups ?? []
                } else {
                    setupMode = .simple
                    warmupMinutes = workout.warmupDuration / 60
                    warmupSeconds = workout.warmupDuration % 60
                    workMinutes = workout.workDuration / 60
                    workSeconds = workout.workDuration % 60
                    restMinutes = workout.restDuration / 60
                    restSeconds = workout.restDuration % 60
                    rounds = workout.rounds
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
    
    var savePresetButton: some View {
        Button(action: savePreset) {
            Text("Save Changes")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
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
        GroupedIntervalEditor(groups: $intervalGroups)
    }

    func savePreset() {
        guard let preset = editingPreset else { return }
        let updatedWorkout: Workout
        if setupMode == .custom {
            updatedWorkout = Workout(
                id: preset.id,
                name: workoutName.isEmpty ? preset.name : workoutName,
                intervalGroups: intervalGroups.filter { !$0.intervals.isEmpty }
            )
        } else {
            let warmupTime = warmupMinutes * 60 + warmupSeconds
            let workTime = workMinutes * 60 + workSeconds
            let restTime = restMinutes * 60 + restSeconds
            updatedWorkout = Workout(
                id: preset.id,
                name: workoutName.isEmpty ? preset.name : workoutName,
                warmupDuration: warmupTime,
                workDuration: workTime,
                restDuration: restTime,
                rounds: rounds
            )
        }
        workoutManager.savePreset(updatedWorkout)
        dismiss()
    }

    func startWorkout() {
        let workout: Workout
        
        if setupMode == .custom {
            let nonEmpty = intervalGroups.filter { !$0.intervals.isEmpty }
            guard !nonEmpty.isEmpty else { return }
            workout = Workout(
                name: workoutName.isEmpty ? "Custom Workout" : workoutName,
                intervalGroups: nonEmpty
            )
        } else {
            let warmupTime = warmupMinutes * 60 + warmupSeconds
            let workTime = workMinutes * 60 + workSeconds
            let restTime = restMinutes * 60 + restSeconds
            workout = Workout(
                name: workoutName.isEmpty ? "HIIT Workout" : workoutName,
                warmupDuration: warmupTime,
                workDuration: workTime,
                restDuration: restTime,
                rounds: rounds
            )
        }
        
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

// MARK: - Custom Interval Editor

enum IntervalTemplate: String, CaseIterable {
    case work, rest, warmup, cooldown

    var label: String {
        switch self {
        case .work: return "Work"
        case .rest: return "Rest"
        case .warmup: return "Warm Up"
        case .cooldown: return "Cool Down"
        }
    }

    var icon: String {
        switch self {
        case .work: return "flame.fill"
        case .rest: return "pause.circle.fill"
        case .warmup: return "figure.walk"
        case .cooldown: return "wind"
        }
    }

    var defaultColor: IntervalColor {
        switch self {
        case .work: return .fieryRed
        case .rest: return .blue
        case .warmup: return .orange
        case .cooldown: return .green
        }
    }

    var defaultDuration: Int {
        switch self {
        case .work: return 45
        case .rest: return 15
        case .warmup: return 30
        case .cooldown: return 60
        }
    }

    func toInterval() -> CustomInterval {
        CustomInterval(label: label, duration: defaultDuration, color: defaultColor)
    }
}

struct GroupedIntervalEditor: View {
    @Binding var groups: [IntervalGroup]

    var totalSeconds: Int {
        groups.reduce(0) { total, group in
            let groupTime = group.intervals.reduce(0) { $0 + $1.duration }
            return total + groupTime * max(group.repeatCount, 1)
        }
    }

    var body: some View {
        VStack(spacing: 15) {
            if groups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Add a group to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, _ in
                    IntervalGroupCard(
                        group: $groups[index],
                        groupIndex: index,
                        totalGroups: groups.count,
                        onDelete: {
                            withAnimation { _ = groups.remove(at: index) }
                        },
                        onMoveUp: index > 0 ? {
                            withAnimation { groups.swapAt(index, index - 1) }
                        } : nil,
                        onMoveDown: index < groups.count - 1 ? {
                            withAnimation { groups.swapAt(index, index + 1) }
                        } : nil
                    )
                }
            }

            Button {
                withAnimation { groups.append(IntervalGroup()) }
            } label: {
                Label("Add Group", systemImage: "plus.rectangle.on.rectangle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            if totalSeconds > 0 {
                HStack {
                    Text("Total time:")
                        .foregroundColor(.secondary)
                    Text(formatTime(totalSeconds))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
    }
}

struct IntervalGroupCard: View {
    @Binding var group: IntervalGroup
    let groupIndex: Int
    let totalGroups: Int
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack {
                Text("Group \(groupIndex + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let onMoveUp {
                    Button { onMoveUp() } label: {
                        Image(systemName: "arrow.up").font(.caption)
                    }
                }
                if let onMoveDown {
                    Button { onMoveDown() } label: {
                        Image(systemName: "arrow.down").font(.caption)
                    }
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground))

            Divider()

            // Template buttons
            HStack(spacing: 6) {
                ForEach(IntervalTemplate.allCases, id: \.self) { template in
                    Button {
                        withAnimation { group.intervals.append(template.toInterval()) }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: template.icon).font(.system(size: 14))
                            Text(template.label).font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(template.defaultColor.swiftUIColor.opacity(0.85))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // Interval rows
            if !group.intervals.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(group.intervals.enumerated()), id: \.element.id) { index, _ in
                        CustomIntervalRow(
                            interval: $group.intervals[index],
                            onDelete: {
                                withAnimation { _ = group.intervals.remove(at: index) }
                            },
                            onMoveUp: index > 0 ? {
                                withAnimation { group.intervals.swapAt(index, index - 1) }
                            } : nil,
                            onMoveDown: index < group.intervals.count - 1 ? {
                                withAnimation { group.intervals.swapAt(index, index + 1) }
                            } : nil
                        )
                        if index < group.intervals.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }

            Divider()

            // Repeat stepper
            HStack {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Stepper("Repeat \(group.repeatCount)x", value: $group.repeatCount, in: 1...50)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct CustomIntervalRow: View {
    @Binding var interval: CustomInterval
    let onDelete: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Color swatch (tap to expand picker)
                Button {
                    withAnimation { showColorPicker.toggle() }
                } label: {
                    Circle()
                        .fill(interval.color.swiftUIColor)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }

                // Label
                TextField("Label", text: $interval.label)
                    .font(.body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)

                // Duration steppers
                HStack(spacing: 4) {
                    Text(formatDuration(interval.duration))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 52, alignment: .trailing)

                    VStack(spacing: 0) {
                        Button { adjustDuration(by: 5) } label: {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                                .frame(width: 28, height: 18)
                        }
                        Button { adjustDuration(by: -5) } label: {
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .frame(width: 28, height: 18)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Reorder / delete
                VStack(spacing: 2) {
                    if let onMoveUp {
                        Button { onMoveUp() } label: {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let onMoveDown {
                        Button { onMoveDown() } label: {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 20)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if showColorPicker {
                ColorSwatchPicker(selection: $interval.color)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    func adjustDuration(by amount: Int) {
        let newValue = max(1, interval.duration + amount)
        interval.duration = min(newValue, 3599)
    }

    func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct ColorSwatchPicker: View {
    @Binding var selection: IntervalColor

    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(IntervalColor.allCases) { color in
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: selection == color ? 3 : 0)
                    )
                    .overlay(
                        selection == color ?
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundColor(.white) : nil
                    )
                    .onTapGesture { selection = color }
            }
        }
    }
}


