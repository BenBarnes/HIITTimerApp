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
                WorkoutSetupView(workoutManager: workoutManager, editingPreset: preset)
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
}

