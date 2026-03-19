import SwiftUI
import Combine
import UIKit
import CoreHaptics

// MARK: - MODELS

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isTimed: Bool
    var repsOrSeconds: Int
    var weight: String
    var sets: Int
    var restTime: Int
    var supersetID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        isTimed: Bool,
        repsOrSeconds: Int,
        weight: String,
        sets: Int,
        restTime: Int,
        supersetID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.isTimed = isTimed
        self.repsOrSeconds = repsOrSeconds
        self.weight = weight
        self.sets = sets
        self.restTime = restTime
        self.supersetID = supersetID
    }
}

struct Workout: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var exercises: [Exercise]

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [Exercise]
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

// MARK: - STORAGE

let workoutsKey = "saved_workouts"

func loadWorkouts() -> [Workout] {
    guard
        let data = UserDefaults.standard.data(forKey: workoutsKey),
        let decoded = try? JSONDecoder().decode([Workout].self, from: data)
    else {
        return []
    }
    return decoded
}

func saveWorkouts(_ workouts: [Workout]) {
    if let data = try? JSONEncoder().encode(workouts) {
        UserDefaults.standard.set(data, forKey: workoutsKey)
    }
}

// MARK: - THEME

let appBackground = Color.black
let primaryText = Color.white
let cardBackground = Color.white.opacity(0.15)

// MARK: - ROOT

struct ContentView: View {
    @State private var workouts: [Workout] = loadWorkouts()

    var body: some View {
        TabView {
            NavigationStack {
                CreateWorkoutView(workouts: $workouts)
            }
            .tabItem { Label("Create", systemImage: "plus.circle") }

            NavigationStack {
                ViewWorkoutsView(workouts: $workouts)
            }
            .tabItem { Label("Workouts", systemImage: "list.bullet") }

            NavigationStack {
                WorkoutTimerView(workouts: workouts)
            }
            .tabItem { Label("Timer", systemImage: "timer") }
        }
        .tint(.blue)
        .onChange(of: workouts) {
            saveWorkouts(workouts)
        }
    }
}

//////////////////////////////////////////////////
// MARK: - CREATE WORKOUT
//////////////////////////////////////////////////

struct CreateWorkoutView: View {
    @Binding var workouts: [Workout]

    @State private var workoutName = ""
    @State private var activeWorkoutIndex: Int? = nil

    @State private var exerciseName = ""
    @State private var isTimed = false
    @State private var repsOrSeconds = ""
    @State private var weight = ""
    @State private var sets = ""
    @State private var restTime = ""

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Create Workout")
                        .font(.largeTitle)
                        .bold()

                    if activeWorkoutIndex == nil {
                        whiteTextField("Workout Name", text: $workoutName)

                        Button("Create") {
                            guard !workoutName.isEmpty else { return }
                            workouts.append(Workout(name: workoutName, exercises: []))
                            activeWorkoutIndex = workouts.count - 1
                            workoutName = ""
                        }
                        .styledButton()
                    }

                    if let index = activeWorkoutIndex {
                        Divider().background(primaryText)

                        Text("Workout: \(workouts[index].name)")
                            .font(.title2)
                            .bold()

                        whiteTextField("Exercise Name", text: $exerciseName)
                        Toggle("Timed Exercise", isOn: $isTimed)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))

                        whiteTextField("Weight (lbs)", text: $weight, keyboard: .numberPad)
                        whiteTextField("Sets", text: $sets, keyboard: .numberPad)
                        whiteTextField(isTimed ? "Seconds" : "Reps", text: $repsOrSeconds, keyboard: .numberPad)
                        whiteTextField("Rest (seconds)", text: $restTime, keyboard: .numberPad)

                        Button("Add Exercise") {
                            guard
                                let reps = Int(repsOrSeconds),
                                let setCount = Int(sets),
                                let rest = Int(restTime),
                                !exerciseName.isEmpty
                            else { return }

                            workouts[index].exercises.append(
                                Exercise(
                                    name: exerciseName,
                                    isTimed: isTimed,
                                    repsOrSeconds: reps,
                                    weight: weight,
                                    sets: setCount,
                                    restTime: rest,
                                    supersetID: nil
                                )
                            )

                            exerciseName = ""
                            repsOrSeconds = ""
                            weight = ""
                            sets = ""
                            restTime = ""
                            isTimed = false
                        }
                        .styledButton()

                        Button("Done") {
                            activeWorkoutIndex = nil
                        }
                        .styledButton()
                    }
                }
                .padding()
                .foregroundColor(primaryText)
            }
        }
    }
}

//////////////////////////////////////////////////
// MARK: - VIEW & EDIT WORKOUTS
//////////////////////////////////////////////////

struct ViewWorkoutsView: View {
    @Binding var workouts: [Workout]
    @State private var selectedWorkoutIndex = 0

    @State private var exerciseName = ""
    @State private var isTimed = false
    @State private var repsOrSeconds = ""
    @State private var weight = ""
    @State private var sets = ""
    @State private var restTime = ""
    
    @State private var pendingSupersetSourceIndex: Int? = nil

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("My Workouts")
                        .font(.largeTitle)
                        .bold()

                    if workouts.isEmpty {
                        Text("No workouts created yet")
                    } else {
                        let clampedIndex = min(max(0, selectedWorkoutIndex), max(0, workouts.count - 1))
                        let exercises = workouts[clampedIndex].exercises

                        workoutMenu(workouts: workouts,
                                    selectedWorkoutIndex: $selectedWorkoutIndex)
                        
                        if let source = pendingSupersetSourceIndex {
                            Text("Select another exercise to pair with #\(source + 1)")
                                .font(.footnote)
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(Array(stride(from: 0, to: exercises.count, by: 1)), id: \.self) { i in
                            // Skip if this exercise is the second in a superset pair (to avoid duplicate rendering)
                            if i > 0, exercises[i].supersetID != nil, exercises[i - 1].supersetID == exercises[i].supersetID {
                                EmptyView()
                            } else if i < exercises.count - 1,
                                      exercises[i].supersetID != nil,
                                      exercises[i + 1].supersetID == exercises[i].supersetID {
                                // Render side-by-side pair (REPLACED: vertical with red outline)
                                VStack(alignment: .leading, spacing: 8) {
                                    EditExerciseCard(
                                        exercise: $workouts[clampedIndex].exercises[i],
                                        onDelete: {
                                            workouts[clampedIndex].exercises.remove(at: i)
                                        },
                                        onMoveUp: {
                                            if i > 0 {
                                                workouts[clampedIndex].exercises.swapAt(i, i - 1)
                                            }
                                        },
                                        onMoveDown: {
                                            let lastIndex = workouts[clampedIndex].exercises.count - 1
                                            if i < lastIndex {
                                                workouts[clampedIndex].exercises.swapAt(i, i + 1)
                                            }
                                        },
                                        onSuperset: {
                                            pendingSupersetSourceIndex = i
                                        }
                                    )
                                    EditExerciseCard(
                                        exercise: $workouts[clampedIndex].exercises[i + 1],
                                        onDelete: {
                                            workouts[clampedIndex].exercises.remove(at: i + 1)
                                        },
                                        onMoveUp: {
                                            if i + 1 > 0 {
                                                workouts[clampedIndex].exercises.swapAt(i + 1, i)
                                            }
                                        },
                                        onMoveDown: {
                                            let lastIndex = workouts[clampedIndex].exercises.count - 1
                                            if i + 1 < lastIndex {
                                                workouts[clampedIndex].exercises.swapAt(i + 1, i + 2)
                                            }
                                        },
                                        onSuperset: {
                                            pendingSupersetSourceIndex = i + 1
                                        }
                                    )
                                }
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                            } else {
                                // Render single exercise
                                ZStack {
                                    EditExerciseCard(
                                        exercise: $workouts[clampedIndex].exercises[i],
                                        onDelete: {
                                            workouts[clampedIndex].exercises.remove(at: i)
                                        },
                                        onMoveUp: {
                                            if i > 0 {
                                                workouts[clampedIndex].exercises.swapAt(i, i - 1)
                                            }
                                        },
                                        onMoveDown: {
                                            let lastIndex = workouts[clampedIndex].exercises.count - 1
                                            if i < lastIndex {
                                                workouts[clampedIndex].exercises.swapAt(i, i + 1)
                                            }
                                        },
                                        onSuperset: {
                                            pendingSupersetSourceIndex = i
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(pendingSupersetSourceIndex == i ? Color.yellow : Color.clear, lineWidth: 2)
                                    )
                                }
                                .onTapGesture {
                                    if let source = pendingSupersetSourceIndex, source != i {
                                        // Pair source (A) with i (B)
                                        let supID = UUID()
                                        // capture A's rest
                                        let aRest = workouts[clampedIndex].exercises[source].restTime
                                        // Assign superset IDs
                                        workouts[clampedIndex].exercises[source].supersetID = supID
                                        workouts[clampedIndex].exercises[i].supersetID = supID
                                        // Enforce no rest between A->B, and B inherits block rest
                                        workouts[clampedIndex].exercises[source].restTime = 0
                                        workouts[clampedIndex].exercises[i].restTime = aRest
                                        // Clear pending selection
                                        pendingSupersetSourceIndex = nil
                                    }
                                }
                            }
                        }

                        Divider().background(primaryText)

                        Text("Add Exercise")
                            .font(.title2)
                            .bold()

                        whiteTextField("Exercise Name", text: $exerciseName)
                        Toggle("Timed Exercise", isOn: $isTimed)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))

                        whiteTextField("Weight (lbs)", text: $weight, keyboard: .numberPad)
                        whiteTextField("Sets", text: $sets, keyboard: .numberPad)
                        whiteTextField(isTimed ? "Seconds" : "Reps", text: $repsOrSeconds, keyboard: .numberPad)
                        whiteTextField("Rest (seconds)", text: $restTime, keyboard: .numberPad)

                        Button("Add Exercise") {
                            guard
                                !exerciseName.isEmpty,
                                let setCount = Int(sets),
                                let reps = Int(repsOrSeconds),
                                let rest = Int(restTime)
                            else { return }

                            workouts[clampedIndex].exercises.append(
                                Exercise(
                                    name: exerciseName,
                                    isTimed: isTimed,
                                    repsOrSeconds: reps,
                                    weight: weight,
                                    sets: setCount,
                                    restTime: rest
                                )
                            )

                            exerciseName = ""
                            weight = ""
                            sets = ""
                            repsOrSeconds = ""
                            restTime = ""
                            isTimed = false
                        }
                        .styledButton()

                        Button("Delete Workout") {
                            if !workouts.isEmpty {
                                workouts.remove(at: clampedIndex)
                                // Adjust the selection to remain in range
                                if workouts.isEmpty {
                                    selectedWorkoutIndex = 0
                                } else {
                                    selectedWorkoutIndex = min(clampedIndex, workouts.count - 1)
                                }
                            }
                        }
                        .styledButton()
                    }
                }
                .padding()
                .foregroundColor(primaryText)
            }
        }
    }
}

//////////////////////////////////////////////////
// MARK: - WORKOUT TIMER
//////////////////////////////////////////////////

struct WorkoutTimerView: View {
    let workouts: [Workout]

    @State private var selectedWorkoutIndex = 0
    @State private var workoutStarted = false
    @State private var exerciseIndex = 0
    @State private var currentSet = 1
    @State private var restRemaining = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let haptic = UINotificationFeedbackGenerator()
    let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    
    @State private var hapticsEngine: CHHapticEngine? = nil
    @State private var hapticsAvailable: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Workout Timer")
                        .font(.largeTitle)
                        .bold()

                    if workouts.isEmpty {
                        Text("No workouts available")
                    } else if !workoutStarted {
                        workoutMenu(workouts: workouts,
                                    selectedWorkoutIndex: $selectedWorkoutIndex)

                        Button("Start Workout") {
                            workoutStarted = true
                            exerciseIndex = 0
                            currentSet = 1
                            restRemaining = 0
                        }
                        .styledButton()
                    } else {
                        let safeWorkoutIndex = min(max(0, selectedWorkoutIndex), max(0, workouts.count - 1))
                        let workout = workouts[safeWorkoutIndex]
                        let safeExerciseIndex = min(max(0, exerciseIndex), max(0, workout.exercises.count - 1))
                        let exercise = workout.exercises[safeExerciseIndex]

                        if let pair = supersetPair(in: workout.exercises, around: safeExerciseIndex) {
                            let (first, second) = pair
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Superset")
                                    .font(.title)
                                    .bold()
                                Text("Set \(currentSet) of \(max(first.sets, second.sets))")
                                
                                // Two rows, one column
                                VStack(alignment: .leading, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("A — \(first.name)")
                                            .font(.headline)
                                        Text("Weight: \(first.weight)")
                                        Text(first.isTimed ? "Seconds: \(first.repsOrSeconds)" : "Reps: \(first.repsOrSeconds)")
                                        Text("Rest: \(first.restTime)s")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(cardBackground)
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("B — \(second.name)")
                                            .font(.headline)
                                        Text("Weight: \(second.weight)")
                                        Text(second.isTimed ? "Seconds: \(second.repsOrSeconds)" : "Reps: \(second.repsOrSeconds)")
                                        Text("Rest: \(second.restTime)s")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(cardBackground)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name)
                                    .font(.title)
                                    .bold()
                                Text("Set \(currentSet) of \(exercise.sets)")
                                Text("Weight: \(exercise.weight)")
                                Text(exercise.isTimed ? "Seconds: \(exercise.repsOrSeconds)" : "Reps: \(exercise.repsOrSeconds)")
                            }
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        }

                        if restRemaining > 0 {
                            Text("Rest: \(restRemaining)s")
                                .font(.title2)
                                .foregroundColor(.blue)
                        } else {
                            Button("Done") {
                                if let pair = supersetPair(in: workout.exercises, around: safeExerciseIndex) {
                                    // Use a shared rest X for the superset; prefer the max of the two to be safe
                                    let sharedRest = max(pair.0.restTime, pair.1.restTime)
                                    restRemaining = sharedRest
                                } else {
                                    restRemaining = exercise.restTime
                                }
                            }
                            .styledButton()
                        }

                        Button("Finish Workout") {
                            workoutStarted = false
                            exerciseIndex = 0
                            currentSet = 1
                            restRemaining = 0
                        }
                        .styledButton()
                    }
                }
                .padding()
                .foregroundColor(primaryText)
            }
        }
        .onAppear {
            guard hapticsAvailable else { return }
            do {
                hapticsEngine = try CHHapticEngine()
                try hapticsEngine?.start()
            } catch {
                hapticsAvailable = false
            }
        }
        .onReceive(timer) { _ in
            if restRemaining > 0 {
                restRemaining -= 1
                if restRemaining == 0 {
                    if hapticsAvailable, let engine = hapticsEngine {
                        // Core Haptics: strong pattern (thump -> buzz -> thump)
                        let events: [CHHapticEvent] = [
                            // Initial strong transient
                            CHHapticEvent(eventType: .hapticTransient,
                                          parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                                          ],
                                          relativeTime: 0.0),
                            // Short continuous buzz
                            CHHapticEvent(eventType: .hapticContinuous,
                                          parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                                          ],
                                          relativeTime: 0.06,
                                          duration: 0.18),
                            // Final strong transient
                            CHHapticEvent(eventType: .hapticTransient,
                                          parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                                          ],
                                          relativeTime: 0.28)
                        ]
                        do {
                            let pattern = try CHHapticPattern(events: events, parameters: [])
                            let player = try engine.makePlayer(with: pattern)
                            try engine.start()
                            try player.start(atTime: 0)
                        } catch {
                            // Fallback to UIKit haptics if Core Haptics fails
                            heavyImpact.prepare()
                            rigidImpact.prepare()
                            heavyImpact.impactOccurred(intensity: 1.0)
                            haptic.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                rigidImpact.impactOccurred(intensity: 1.0)
                                haptic.notificationOccurred(.warning)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                                heavyImpact.impactOccurred(intensity: 1.0)
                                haptic.notificationOccurred(.success)
                            }
                        }
                    } else {
                        // UIKit fallback: strong triple hit
                        heavyImpact.prepare()
                        rigidImpact.prepare()
                        heavyImpact.impactOccurred(intensity: 1.0)
                        haptic.notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            rigidImpact.impactOccurred(intensity: 1.0)
                            haptic.notificationOccurred(.warning)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            heavyImpact.impactOccurred(intensity: 1.0)
                            haptic.notificationOccurred(.success)
                        }
                    }
                    advanceWorkout()
                }
            }
        }
    }

    func advanceWorkout() {
        guard workouts.indices.contains(selectedWorkoutIndex) else {
            workoutStarted = false
            return
        }
        let workout = workouts[selectedWorkoutIndex]
        guard workout.exercises.indices.contains(exerciseIndex) else {
            workoutStarted = false
            return
        }

        // If current index is part of a superset, treat the pair as one block
        if let pair = supersetPair(in: workout.exercises, around: exerciseIndex) {
            let (first, second) = pair
            let totalSets = max(first.sets, second.sets)
            if currentSet < totalSets {
                currentSet += 1
            } else {
                // Move past the entire superset block (skip 2 entries if adjacent)
                // Find the lower index of the pair
                let idx = exerciseIndex
                let isPairForward = (idx < workout.exercises.count - 1) && (workout.exercises[idx].supersetID != nil) && (workout.exercises[idx + 1].supersetID == workout.exercises[idx].supersetID)
                let startIndex = isPairForward ? idx : idx - 1
                let nextIndex = startIndex + 2
                if nextIndex < workout.exercises.count {
                    exerciseIndex = nextIndex
                    currentSet = 1
                } else {
                    workoutStarted = false
                }
            }
            return
        }

        // Single exercise behavior
        let exercise = workout.exercises[exerciseIndex]
        if currentSet < exercise.sets {
            currentSet += 1
        } else if exerciseIndex < workout.exercises.count - 1 {
            exerciseIndex += 1
            currentSet = 1
        } else {
            workoutStarted = false
        }
    }

    private func supersetPair(in exercises: [Exercise], around index: Int) -> (Exercise, Exercise)? {
        guard exercises.indices.contains(index) else { return nil }
        let current = exercises[index]
        guard let supID = current.supersetID else { return nil }

        // Check previous as pair
        if index > 0, exercises[index - 1].supersetID == supID {
            return (exercises[index - 1], current)
        }
        // Check next as pair
        if index < exercises.count - 1, exercises[index + 1].supersetID == supID {
            return (current, exercises[index + 1])
        }
        return nil
    }
}

//////////////////////////////////////////////////
// MARK: - EDIT CARD & HELPERS
//////////////////////////////////////////////////

struct EditExerciseCard: View {
    @Binding var exercise: Exercise
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var onSuperset: (() -> Void)? = nil
    @State private var editing = false
    @State private var showMoveMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name).bold()
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Menu {
                        Button("Up") { onMoveUp?() }
                        Button("Down") { onMoveDown?() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Move")
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .foregroundColor(primaryText)
                        .padding(8)
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                    Button(action: { onSuperset?() }) {
                        HStack(spacing: 6) {
                            Text("Superset")
                            Image(systemName: "link")
                        }
                        .foregroundColor(primaryText)
                        .padding(8)
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                }
            }

            if editing {
                whiteTextField("Weight (lbs)", text: $exercise.weight)
                EditableIntField("Sets", value: $exercise.sets)
                EditableIntField(exercise.isTimed ? "Seconds" : "Reps", value: $exercise.repsOrSeconds)
                EditableIntField("Rest (seconds)", value: $exercise.restTime)

                Button("Save") { editing = false }
                    .styledButton()

                Button("Delete") {
                    onDelete?()
                }
                .styledButton()
            } else {
                Text("Weight: \(exercise.weight) lbs")
                Text("Sets: \(exercise.sets)")
                Text(exercise.isTimed ? "Seconds: \(exercise.repsOrSeconds)" : "Reps: \(exercise.repsOrSeconds)")
                Text("Rest: \(exercise.restTime)s")

                Button("Edit") { editing = true }
                    .styledButton()
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(10)
    }
}

struct EditableIntField: View {
    let placeholder: String
    @Binding var value: Int
    @State private var text: String

    init(_ placeholder: String, value: Binding<Int>) {
        self.placeholder = placeholder
        self._value = value
        self._text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .foregroundColor(primaryText)
            .padding()
            .background(cardBackground)
            .cornerRadius(8)
            .onChange(of: text) {
                if let v = Int(text) {
                    value = v
                }
            }
    }
}

func whiteTextField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
    TextField(placeholder, text: text)
        .keyboardType(keyboard)
        .foregroundColor(primaryText)
        .padding()
        .background(cardBackground)
        .cornerRadius(8)
}

func workoutMenu(workouts: [Workout], selectedWorkoutIndex: Binding<Int>) -> some View {
    let safeIndex = min(max(0, selectedWorkoutIndex.wrappedValue), max(0, workouts.count - 1))
    let currentName = workouts.isEmpty ? "No Workouts" : workouts[safeIndex].name
    return Menu {
        if workouts.isEmpty {
            // Disabled picker when empty
            Text("No Workouts")
        } else {
            Picker("Workout", selection: selectedWorkoutIndex) {
                ForEach(workouts.indices, id: \.self) {
                    Text(workouts[$0].name)
                }
            }
        }
    } label: {
        HStack {
            Text(currentName)
            Spacer()
            Image(systemName: "chevron.down")
        }
        .foregroundColor(primaryText)
        .padding()
        .background(cardBackground)
        .cornerRadius(8)
    }
}

extension View {
    func styledButton() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.6))
            .cornerRadius(10)
            .foregroundColor(primaryText)
    }
}

