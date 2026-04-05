// MakerMarginsApp.swift
// MakerMargins
//
// App entry point. Creates the SwiftData ModelContainer with the full schema
// and injects it into the environment for all child views.

import SwiftUI
import SwiftData

@main
struct MakerMarginsApp: App {

    let container: ModelContainer
    @State private var showStoreCorruptionAlert = false

    @State private var currencyFormatter = CurrencyFormatter()
    @State private var appearanceManager = AppearanceManager()
    @State private var laborRateManager = LaborRateManager()

    init() {
        let schema = Schema([
            Product.self,
            Category.self,
            WorkStep.self,
            Material.self,
            PlatformFeeProfile.self,
            ProductWorkStep.self,
            ProductMaterial.self,
            ProductPricing.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed incompatibly — delete the old store and retry.
            let storeURL = config.url
            let related = [
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm"),
            ]
            for url in [storeURL] + related {
                try? FileManager.default.removeItem(at: url)
            }
            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                // Last resort: run in-memory so the app at least launches.
                // In-memory containers have no disk/migration issues, so force-try is safe here.
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [inMemory])
                _showStoreCorruptionAlert = State(initialValue: true)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.currencyFormatter, currencyFormatter)
                .environment(\.appearanceManager, appearanceManager)
                .environment(\.laborRateManager, laborRateManager)
                .preferredColorScheme(appearanceManager.resolvedColorScheme)
                .tint(AppTheme.Colors.accent)
                .alert("Data Recovery", isPresented: $showStoreCorruptionAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Your data could not be loaded. The app is running with a fresh database. If this persists, try reinstalling the app.")
                }
        }
        .modelContainer(container)
    }
}
