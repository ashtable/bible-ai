import Testing
import Foundation
@testable import BibleAI

@Suite("Task 5 — VerseRef")
struct VerseRefTests {

    private let sample = VerseRef(
        reference: "John 3:16",
        book: "John",
        translation: "WEB",
        text: "For God so loved the world…"
    )

    @Test("init exposes all four fields")
    func initExposesAllFields() {
        #expect(sample.reference == "John 3:16")
        #expect(sample.book == "John")
        #expect(sample.translation == "WEB")
        #expect(sample.text == "For God so loved the world…")
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(VerseRef.self, from: data)
        #expect(decoded == sample)
    }

    @Test("Decodes pinned wire form — locks JSON key names")
    func decodesPinnedWireForm() throws {
        let json = """
        {"reference":"John 3:16","book":"John","translation":"WEB","text":"For God so loved the world…"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VerseRef.self, from: json)
        #expect(decoded.reference == "John 3:16")
        #expect(decoded.book == "John")
        #expect(decoded.translation == "WEB")
        #expect(decoded.text == "For God so loved the world…")
    }

    @Test("Differing any field breaks equality")
    func differingFieldsAreUnequal() {
        #expect(VerseRef(reference: "X", book: "John", translation: "WEB", text: "t") != sample)
        #expect(VerseRef(reference: "John 3:16", book: "X", translation: "WEB", text: "t") != sample)
        #expect(VerseRef(reference: "John 3:16", book: "John", translation: "X", text: "t") != sample)
        #expect(VerseRef(reference: "John 3:16", book: "John", translation: "WEB", text: "X") != sample)
    }

    @Test("Identical values collapse to one Set entry")
    func usableAsSetMember() {
        var set: Set<VerseRef> = []
        set.insert(sample)
        set.insert(sample)
        #expect(set.count == 1)
        let other = VerseRef(reference: "Psalm 23:1", book: "Psalms", translation: "KJV", text: "The Lord is my shepherd")
        set.insert(other)
        #expect(set.count == 2)
    }
}
