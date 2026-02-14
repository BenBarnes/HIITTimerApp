import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var showingPresets = false
    @State private var showingWorkoutSetup = false
    
    var body: some View {
        NavigationView {
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
    @ObservedObject var workoutManager: WorkoutManager
    
    var body: some View {
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
                    Text("Round \(workoutManager.currentRound)/\(workout.rounds)")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    
                    ProgressView(value: Double(workoutManager.currentRound), total: Double(workout.rounds))
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 250)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
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
                    workoutManager.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
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

#Preview {
    ContentView()
}
