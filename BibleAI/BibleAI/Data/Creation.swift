import Foundation
import SwiftData

@Model
final class Creation {
    // iOS 27 beta SwiftData SIGTRAP on ctx.insert() when the schema contains
    // ANY Codable-backed property (enums, [String]). All stored properties are
    // raw primitives; public accessors reconstruct the domain types.
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // VerseRef primitives — four Strings, each stored natively.
    // verseReference/verseBook/verseTranslation are the #Predicate targets.
    var verseReference: String
    var verseBook: String
    var verseTranslation: String
    var verseText: String

    // format / privacy — stored as raw String values (enum Codable blobs trap).
    var formatRaw: String
    var privacyRaw: String

    var isEphemeral: Bool

    var imageModelID: String?
    var textModelID: String?
    var musicModelID: String?

    // [String] is stored via Codable encoding which also traps. Serialised as a
    // newline-delimited String instead (paths never contain newlines).
    var artifactRelativePathsRaw: String

    // MARK: — Computed accessors (not persisted by SwiftData)

    /// Assembles a VerseRef from stored String primitives.
    /// DO NOT #Predicate on `verse.*` — use verseReference/verseBook/verseTranslation.
    var verse: VerseRef {
        get { VerseRef(reference: verseReference, book: verseBook,
                       translation: verseTranslation, text: verseText) }
        set {
            verseReference = newValue.reference
            verseBook = newValue.book
            verseTranslation = newValue.translation
            verseText = newValue.text
        }
    }

    var format: CreationFormat {
        get { CreationFormat(rawValue: formatRaw) ?? .image }
        set { formatRaw = newValue.rawValue }
    }

    var privacy: Privacy {
        get { Privacy(rawValue: privacyRaw) ?? .private }
        set { privacyRaw = newValue.rawValue }
    }

    var artifactRelativePaths: [String] {
        get {
            artifactRelativePathsRaw.isEmpty
                ? []
                : artifactRelativePathsRaw.components(separatedBy: "\n")
        }
        set {
            assert(newValue.allSatisfy { !$0.hasPrefix("/") },
                   "artifactRelativePaths must be relative, got an absolute path")
            artifactRelativePathsRaw = newValue.joined(separator: "\n")
        }
    }

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
        assert(artifactRelativePaths.allSatisfy { !$0.hasPrefix("/") },
               "artifactRelativePaths must be relative, got an absolute path")
        self.id = id
        self.createdAt = createdAt
        self.verseReference = verse.reference
        self.verseBook = verse.book
        self.verseTranslation = verse.translation
        self.verseText = verse.text
        self.formatRaw = format.rawValue
        self.privacyRaw = privacy.rawValue
        self.isEphemeral = isEphemeral
        self.imageModelID = imageModelID
        self.textModelID = textModelID
        self.musicModelID = musicModelID
        self.artifactRelativePathsRaw = artifactRelativePaths.joined(separator: "\n")
    }
}
