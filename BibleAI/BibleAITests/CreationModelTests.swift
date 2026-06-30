import Testing
import Foundation
@testable import BibleAI

@MainActor
@Suite("Task 5 — Creation model")
struct CreationModelTests {

    private let verse = VerseRef(
        reference: "John 3:16",
        book: "John",
        translation: "WEB",
        text: "For God so loved the world…"
    )

    @Test("init seeds denormalized fields from verse")
    func initSeedsDenormalizedFieldsFromVerse() {
        let c = Creation(verse: verse, format: .image)
        #expect(c.verseReference == verse.reference)
        #expect(c.verseBook == verse.book)
        #expect(c.verseTranslation == verse.translation)
    }

    @Test("init stores core fields correctly")
    func initStoresCoreFields() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let c = Creation(
            id: id,
            createdAt: date,
            verse: verse,
            format: .slideshow,
            privacy: .published,
            isEphemeral: true,
            imageModelID: "sd-1-5",
            textModelID: "afm",
            musicModelID: nil,
            artifactRelativePaths: ["artifacts/abc.png"]
        )
        #expect(c.id == id)
        #expect(c.createdAt == date)
        #expect(c.format == .slideshow)
        #expect(c.privacy == .published)
        #expect(c.isEphemeral == true)
        #expect(c.imageModelID == "sd-1-5")
        #expect(c.textModelID == "afm")
        #expect(c.musicModelID == nil)
        #expect(c.artifactRelativePaths == ["artifacts/abc.png"])
    }

    @Test("Default flags and optionals match spec")
    func defaultsForFlagsAndOptionals() {
        let c = Creation(verse: verse, format: .image)
        #expect(c.isEphemeral == false)
        #expect(c.imageModelID == nil)
        #expect(c.textModelID == nil)
        #expect(c.musicModelID == nil)
        #expect(c.artifactRelativePaths == [])
        #expect(c.privacy == .private)
    }

    @Test("Artifact paths are relative by convention")
    func storedArtifactPathsAreRelativeByConvention() {
        let c = Creation(
            verse: verse,
            format: .image,
            artifactRelativePaths: ["artifacts/foo.png", "artifacts/bar.png"]
        )
        #expect(c.artifactRelativePaths.allSatisfy { !$0.hasPrefix("/") })
    }

    @Test("verse.text is retained even though it has no denormalized mirror")
    func verseBlobRetainsTextNotMirrored() {
        let c = Creation(verse: verse, format: .image)
        #expect(c.verse.text == verse.text)
    }
}
