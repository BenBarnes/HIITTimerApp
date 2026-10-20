import SwiftUI

struct ContentView: View {
    @State private var workoutManager = WorkoutManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPresets = false
    @State private var showingWorkoutSetup = false
    @State private var showingLastWorkout = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.7), Color.red.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("HIIT Timer")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    if workoutManager.isActive {
                        // Active workout view
                        WorkoutActiveView(workoutManager: workoutManager)
                    } else {
                        // Main menu
                        VStack(spacing: 20) {
                            Button(action: {
                                showingWorkoutSetup = true
                            }) {
                                MenuButton(icon: "plus.circle.fill", text: "New Workout")
                            }

                            Button(action: {
                                showingPresets = true
                            }) {
                                MenuButton(icon: "list.bullet", text: "Load Preset")
                            }

                            if workoutManager.lastWorkout != nil {
                                Button(action: {
                                    showingLastWorkout = true
                                }) {
                                    MenuButton(icon: "arrow.counterclockwise", text: "Repeat Last")
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .sheet(isPresented: $showingWorkoutSetup) {
                WorkoutSetupView(workoutManager: workoutManager)
            }
            .sheet(isPresented: $showingPresets) {
                PresetsView(workoutManager: workoutManager)
            }
            .sheet(isPresented: $showingLastWorkout) {
                WorkoutSetupView(workoutManager: workoutManager, prefillWorkout: workoutManager.lastWorkout)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-sync the countdown when returning to the app so the timer
            // keeps up with real elapsed time.
            if newPhase == .active {
                workoutManager.syncOnForeground()
            }
        }
    }
}

struct MenuButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 30))
            Text(text)
                .font(.system(size: 24, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(width: 280, height: 70)
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
}

struct WorkoutActiveView: View {
    var workoutManager: WorkoutManager
    @State private var showingStopConfirmation = false
    // Whether the workout was running when stop was pressed, so cancelling
    // the confirmation only resumes a workout this view paused itself.
    @State private var resumeOnCancel = false

    var body: some View {
        if workoutManager.isCompleted {
            WorkoutCompleteView(workoutManager: workoutManager)
        } else {
            VStack(spacing: 40) {
                // Current phase indicator
                Text(workoutManager.currentPhaseText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(workoutManager.currentPhaseColor.opacity(0.8))
                    .cornerRadius(20)

                // Timer display
                Text(workoutManager.timeString)
                    .font(.system(size: 90, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)

                // Progress indicator
                if let workout = workoutManager.currentWorkout {
                    VStack(spacing: 10) {
                        if workout.isCustom {
                            Text("Interval \(workoutManager.currentIntervalIndex + 1)/\(workoutManager.totalIntervalCount)")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                            ProgressView(value: Double(workoutManager.currentIntervalIndex + 1), total: Double(workoutManager.totalIntervalCount))
                                .progressViewStyle(.linear)
                                .tint(.white)
                                .frame(width: 250)
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        } else {
                            Text("Round \(workoutManager.currentRound)/\(workout.rounds)")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                            ProgressView(value: Double(workoutManager.currentRound), total: Double(workout.rounds))
                                .progressViewStyle(.linear)
                                .tint(.white)
                                .frame(width: 250)
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        }
                    }
                }

                // Control buttons
                HStack(spacing: 30) {
                    if workoutManager.isPaused {
                        Button(action: {
                            workoutManager.resume()
                        }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    } else {
                        Button(action: {
                            workoutManager.pause()
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    }

                    Button(action: {
                        // Pause while the user decides whether to end the workout.
                        resumeOnCancel = !workoutManager.isPaused
                        if resumeOnCancel {
                            workoutManager.pause()
                        }
                        showingStopConfirmation = true
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .confirmationDialog(
                        "End this workout?",
                        isPresented: $showingStopConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("End Workout", role: .destructive) {
                            workoutManager.stop()
                        }
                        // No `.cancel` role: when the dialog is shown as a popover,
                        // iOS hides cancel-role buttons and relies on tapping outside.
                        Button("Cancel") {}
                    }
                    .onChange(of: showingStopConfirmation) { _, isShowing in
                        // Covers both the Cancel button and tapping outside the
                        // dialog. After "End Workout" the workout is no longer active.
                        if !isShowing, resumeOnCancel, workoutManager.isActive {
                            workoutManager.resume()
                        }
                    }

                    Button(action: {
                        workoutManager.skipPhase()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

struct WorkoutCompleteView: View {
    var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)

            Text("Workout Finished")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

            Button(action: {
                workoutManager.stop()
            }) {
                Text("OK")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 60)
                    .background(Color.green)
                    .cornerRadius(15)
            }
        }
    }
}

#Preview {
    ContentView()
}
