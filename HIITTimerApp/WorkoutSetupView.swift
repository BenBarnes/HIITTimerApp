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
    @State private var repeatCount = 1
    
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
        CustomIntervalEditor(intervals: $customIntervals, repeatCount: $repeatCount)
    }
    
    func startWorkout() {
        let workout: Workout
        
        if setupMode == .custom {
            guard !customIntervals.isEmpty else { return }
            workout = Workout(
                name: workoutName.isEmpty ? "Custom Workout" : workoutName,
                customIntervals: customIntervals,
                repeatCount: repeatCount
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

struct CustomIntervalEditor: View {
    @Binding var intervals: [CustomInterval]
    @Binding var repeatCount: Int

    var totalSeconds: Int {
        intervals.reduce(0) { $0 + $1.duration } * max(repeatCount, 1)
    }

    var body: some View {
        VStack(spacing: 15) {
            // Template buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Interval")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 10) {
                    ForEach(IntervalTemplate.allCases, id: \.self) { template in
                        Button {
                            withAnimation {
                                intervals.append(template.toInterval())
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: template.icon)
                                    .font(.system(size: 18))
                                Text(template.label)
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(template.defaultColor.swiftUIColor.opacity(0.85))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Interval list
            if intervals.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Tap a button above to add intervals")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(intervals.enumerated()), id: \.element.id) { index, _ in
                        CustomIntervalRow(interval: $intervals[index], onDelete: {
                            withAnimation {
                                _ = intervals.remove(at: index)
                            }
                        }, onMoveUp: index > 0 ? {
                            withAnimation {
                                intervals.swapAt(index, index - 1)
                            }
                        } : nil, onMoveDown: index < intervals.count - 1 ? {
                            withAnimation {
                                intervals.swapAt(index, index + 1)
                            }
                        } : nil)
                        
                        if index < intervals.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            // Repeat stepper
            GroupBox(label: Label("Repeat", systemImage: "repeat")) {
                Stepper("\(repeatCount)x", value: $repeatCount, in: 1...50)
                    .padding(.horizontal)
            }
            .padding(.horizontal)

            // Total time summary
            if !intervals.isEmpty {
                HStack {
                    Text("Total time:")
                        .foregroundColor(.secondary)
                    Text(formatTotalTime(totalSeconds))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
    }

    func formatTotalTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins == 0 {
            return "\(secs)s"
        } else if secs == 0 {
            return "\(mins)m"
        } else {
            return "\(mins)m \(secs)s"
        }
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


