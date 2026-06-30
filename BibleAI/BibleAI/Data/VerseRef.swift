import Foundation

/// Codable composite describing a verse. Stored on `Creation` as an opaque blob —
/// NOT queryable via #Predicate. Filter/sort via the denormalized scalars on `Creation`.
struct VerseRef: Codable, Hashable, Sendable {
    var reference: String    // "John 3:16"
    var book: String         // "John"
    var translation: String  // "WEB"
    var text: String
}
