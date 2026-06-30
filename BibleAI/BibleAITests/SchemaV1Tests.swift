import Testing
import SwiftData
@testable import BibleAI

@Suite("Task 5 — SchemaV1 & migration plan")
struct SchemaV1Tests {

    @Test("Version identifier is 1.0.0")
    func versionIdentifierIsOneZeroZero() {
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    }

    @Test("models array contains exactly Creation and AppSettings")
    func modelsContainBothTypes() {
        let ids = Set(SchemaV1.models.map { ObjectIdentifier($0) })
        #expect(ids == Set([ObjectIdentifier(Creation.self), ObjectIdentifier(AppSettings.self)]))
        #expect(SchemaV1.models.count == 2)
    }

    @Test("AppMigrationPlan.schemas contains exactly SchemaV1")
    func migrationPlanSchemasIsSchemaV1Only() {
        #expect(AppMigrationPlan.schemas.count == 1)
        #expect(ObjectIdentifier(AppMigrationPlan.schemas[0]) == ObjectIdentifier(SchemaV1.self))
    }

    @Test("AppMigrationPlan.stages is empty")
    func migrationPlanStagesIsEmpty() {
        #expect(AppMigrationPlan.stages.isEmpty)
    }
}
