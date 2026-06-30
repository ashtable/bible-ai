import Testing
import SwiftData
import Foundation
@testable import BibleAI

@MainActor
@Suite("Task 5 — ModelContainer")
struct ModelContainerTests {

    private func freshContainer() throws -> ModelContainer {
        try AppModelContainer.make(inMemory: true)
    }

    private func sampleVerse(reference: String = "John 3:16", book: String = "John") -> VerseRef {
        VerseRef(reference: reference, book: book, translation: "WEB", text: "For God so loved the world…")
    }

    @Test("make(inMemory:) builds without throwing")
    func buildsInMemory() throws {
        _ = try freshContainer()
    }

    @Test("Insert + save + fetch round-trips a Creation")
    func insertAndFetchCreation() throws {
        let ctx = try freshContainer().mainContext
        let c = Creation(verse: sampleVerse(), format: .image)
        ctx.insert(c)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<Creation>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.verseReference == "John 3:16")
    }

    @Test("Insert + save + fetch round-trips AppSettings")
    func insertAndFetchAppSettings() throws {
        let ctx = try freshContainer().mainContext
        ctx.insert(AppSettings())
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<AppSettings>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.defaultEngine == .onDevice)
    }

    @Test("verse Codable blob survives a save/fetch cycle")
    func verseBlobSurvivesPersistence() throws {
        let ctx = try freshContainer().mainContext
        let verse = sampleVerse()
        let c = Creation(verse: verse, format: .image)
        ctx.insert(c)
        try ctx.save()
        let fetched = try #require(try ctx.fetch(FetchDescriptor<Creation>()).first)
        #expect(fetched.verse == verse)
    }

    @Test("#Predicate on verseReference returns only the match")
    func predicateOnVerseReferenceMatches() throws {
        let ctx = try freshContainer().mainContext
        ctx.insert(Creation(verse: sampleVerse(reference: "John 3:16", book: "John"), format: .image))
        ctx.insert(Creation(verse: sampleVerse(reference: "Psalm 23:1", book: "Psalms"), format: .image))
        try ctx.save()
        let hits = try ctx.fetch(FetchDescriptor<Creation>(
            predicate: #Predicate { $0.verseReference == "John 3:16" }
        ))
        #expect(hits.count == 1)
        #expect(hits.first?.verseBook == "John")
    }

    @Test("#Predicate on verseBook returns only the match")
    func predicateOnVerseBookMatches() throws {
        let ctx = try freshContainer().mainContext
        ctx.insert(Creation(verse: sampleVerse(reference: "John 3:16", book: "John"), format: .image))
        ctx.insert(Creation(verse: sampleVerse(reference: "Psalm 23:1", book: "Psalms"), format: .image))
        try ctx.save()
        let hits = try ctx.fetch(FetchDescriptor<Creation>(
            predicate: #Predicate { $0.verseBook == "Psalms" }
        ))
        #expect(hits.count == 1)
        #expect(hits.first?.verseReference == "Psalm 23:1")
    }

    @Test("FetchDescriptor sorts by createdAt descending")
    func sortByCreatedAtDescending() throws {
        let ctx = try freshContainer().mainContext
        let older = Creation(
            id: UUID(), createdAt: Date(timeIntervalSince1970: 1_000_000),
            verse: sampleVerse(), format: .image
        )
        let newer = Creation(
            id: UUID(), createdAt: Date(timeIntervalSince1970: 2_000_000),
            verse: sampleVerse(), format: .image
        )
        ctx.insert(older)
        ctx.insert(newer)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<Creation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        #expect(fetched.first?.createdAt == newer.createdAt)
    }

    @Test("@Attribute(.unique) upserts rather than duplicating on same id")
    func uniqueIdUpsertsRatherThanDuplicating() throws {
        let ctx = try freshContainer().mainContext
        let id = UUID()
        ctx.insert(Creation(id: id, verse: sampleVerse(), format: .image))
        ctx.insert(Creation(id: id, verse: sampleVerse(), format: .video))
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Creation>()).count == 1)
    }
}
