//
//  TrainLogAppApp.swift
//  TrainLogApp
//
//  Created by Takanori Hirohashi on 2025/11/02.
//
import SwiftUI
import SwiftData

@main
struct TrainLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, ExerciseSet.self])
    }
}
