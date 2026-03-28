// MakerMarginsApp.swift
// MakerMargins
//
// App entry point. Creates the SwiftData ModelContainer and injects it
// into the environment. Model types are registered here as each Epic adds them.
// Epic 0 — minimal valid shell.

import SwiftUI
import SwiftData

@main
struct MakerMarginsApp: App {

    // Register all SwiftData model types here as Epics are completed.
    // e.g. for: [Product.self, Category.self, WorkStep.self, ...]
    let container: ModelContainer = {
        let schema = Schema([
            // Epic 1: Product.self, Category.self
            // Epic 2: WorkStep.self
            // Epic 3: Material.self
            // Epic 4: PlatformFeeProfile.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
