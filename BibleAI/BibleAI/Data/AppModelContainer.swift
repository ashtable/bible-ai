import Foundation
import SwiftData

/// Single seam for building the app's ModelContainer.
/// App calls make() on disk; tests call make(inMemory: true) for isolation.
enum AppModelContainer {
    static let schema = Schema(versionedSchema: SchemaV1.self)

    /// Keep every container we hand out alive for the life of the process.
    ///
    /// On iOS 27 a `ModelContext` (including `container.mainContext`) does NOT
    /// keep its `ModelContainer` alive. So `make().mainContext` lets the
    /// container deallocate at the end of the statement, and the orphaned
    /// context SIGTRAPs on the next `insert`/`save` (the backing store has been
    /// torn down). Retaining the container here keeps the store valid. The app
    /// builds one container; tests build one per case — negligible to hold.
    nonisolated(unsafe) private static var retained: [ModelContainer] = []

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            // Per-call temp SQLite file for test isolation. The in-memory store
            // doesn't enforce @Attribute(.unique) reliably on iOS 27 simulator.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".sqlite")
            configuration = ModelConfiguration(schema: schema, url: tempURL)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        let container = try ModelContainer(for: schema, configurations: configuration)
        retained.append(container)
        return container
    }
}
