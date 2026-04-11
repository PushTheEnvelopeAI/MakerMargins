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

    // Repositories (writes-only — reads stay on @Query)
    @State private var productRepository: SwiftDataProductRepository
    @State private var workStepRepository: SwiftDataWorkStepRepository
    @State private var materialRepository: SwiftDataMaterialRepository
    @State private var categoryRepository: SwiftDataCategoryRepository

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
                let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    self.container = try ModelContainer(for: schema, configurations: [inMemory])
                } catch {
                    fatalError("Unable to create even an in-memory ModelContainer: \(error)")
                }
                _showStoreCorruptionAlert = State(initialValue: true)
            }
        }

        // Initialize repositories with the container's main context
        let mainContext = container.mainContext
        _productRepository = State(initialValue: SwiftDataProductRepository(context: mainContext))
        _workStepRepository = State(initialValue: SwiftDataWorkStepRepository(context: mainContext))
        _materialRepository = State(initialValue: SwiftDataMaterialRepository(context: mainContext))
        _categoryRepository = State(initialValue: SwiftDataCategoryRepository(context: mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.currencyFormatter, currencyFormatter)
                .environment(\.appearanceManager, appearanceManager)
                .environment(\.laborRateManager, laborRateManager)
                .environment(\.productRepository, productRepository)
                .environment(\.workStepRepository, workStepRepository)
                .environment(\.materialRepository, materialRepository)
                .environment(\.categoryRepository, categoryRepository)
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
