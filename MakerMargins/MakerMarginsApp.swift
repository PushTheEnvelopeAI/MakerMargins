// MakerMarginsApp.swift
// MakerMargins
//
// App entry point. Creates the SwiftData ModelContainer with the full schema
// and injects it into the environment for all child views.

import SwiftUI
import SwiftData

@main
struct MakerMarginsApp: App {

    let container: ModelContainer = {
        let schema = Schema([
            Product.self,
            Category.self,
            WorkStep.self,
            Material.self,
            PlatformFeeProfile.self,
            ProductWorkStep.self,
            ProductMaterial.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var currencyFormatter = CurrencyFormatter()
    @State private var appearanceManager = AppearanceManager()
    @State private var laborRateManager = LaborRateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.currencyFormatter, currencyFormatter)
                .environment(\.appearanceManager, appearanceManager)
                .environment(\.laborRateManager, laborRateManager)
                .preferredColorScheme(appearanceManager.resolvedColorScheme)
                .tint(AppTheme.Colors.accent)
        }
        .modelContainer(container)
    }
}
