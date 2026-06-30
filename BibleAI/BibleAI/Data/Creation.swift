import Foundation
import SwiftData

@Model
final class Creation {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    /// Codable composite blob. DO NOT #Predicate on `verse.*` — runtime trap.
    /// Query via verseReference / verseBook / verseTranslation instead.
    var verse: VerseRef

    // Denormalized scalar mirrors of `verse` — the ONLY legal predicate targets.
    var verseReference: String
    var verseBook: String
    var verseTranslation: String

    var format: CreationFormat
    var privacy: Privacy
    var isEphemeral: Bool

    var imageModelID: String?
    var textModelID: String?
    var musicModelID: String?

    /// Relative to the Artifacts container — NEVER absolute (container UUID
    /// rotates on reinstall).
    var artifactRelativePaths: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        verse: VerseRef,
        format: CreationFormat,
        privacy: Privacy = .private,
        isEphemeral: Bool = false,
        imageModelID: String? = nil,
        textModelID: String? = nil,
        musicModelID: String? = nil,
        artifactRelativePaths: [String] = []
    ) {
        precondition(artifactRelativePaths.allSatisfy { !$0.hasPrefix("/") },
                     "artifactRelativePaths must be relative, got an absolute path")
        self.id = id
        self.createdAt = createdAt
        self.verse = verse
        self.verseReference = verse.reference
        self.verseBook = verse.book
        self.verseTranslation = verse.translation
        self.format = format
        self.privacy = privacy
        self.isEphemeral = isEphemeral
        self.imageModelID = imageModelID
        self.textModelID = textModelID
        self.musicModelID = musicModelID
        self.artifactRelativePaths = artifactRelativePaths
    }
}
