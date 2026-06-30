import Testing
@testable import BibleAI

@Suite("Task 5 — persisted enums")
struct PersistedEnumsTests {

    // MARK: CreationFormat

    @Test("CreationFormat has exactly image/slideshow/video")
    func creationFormatCasesAreExhaustive() {
        #expect(Set(CreationFormat.allCases) == [.image, .slideshow, .video])
    }

    @Test("CreationFormat rawValues are pinned strings")
    func creationFormatRawValuesArePinned() {
        #expect(CreationFormat.image.rawValue == "image")
        #expect(CreationFormat.slideshow.rawValue == "slideshow")
        #expect(CreationFormat.video.rawValue == "video")
    }

    @Test("CreationFormat Codable round-trip")
    func creationFormatCodableRoundTrip() throws {
        for c in CreationFormat.allCases {
            let data = try JSONEncoder().encode(c)
            #expect(try JSONDecoder().decode(CreationFormat.self, from: data) == c)
        }
    }

    // MARK: Privacy

    @Test("Privacy has exactly private/published")
    func privacyCasesAreExhaustive() {
        #expect(Set(Privacy.allCases) == [.private, .published])
    }

    @Test("Privacy rawValues are pinned strings")
    func privacyRawValuesArePinned() {
        #expect(Privacy.private.rawValue == "private")
        #expect(Privacy.published.rawValue == "published")
    }

    @Test("Privacy Codable round-trip")
    func privacyCodableRoundTrip() throws {
        for c in Privacy.allCases {
            let data = try JSONEncoder().encode(c)
            #expect(try JSONDecoder().decode(Privacy.self, from: data) == c)
        }
    }

    @Test("Privacy decodes pinned wire form for .private")
    func privacyDecodesPinnedWireForm() throws {
        let data = "\"private\"".data(using: .utf8)!
        #expect(try JSONDecoder().decode(Privacy.self, from: data) == .private)
    }

    // MARK: EngineChoice

    @Test("EngineChoice has exactly onDevice/openRouter/anthropic")
    func engineChoiceCasesAreExhaustive() {
        #expect(Set(EngineChoice.allCases) == [.onDevice, .openRouter, .anthropic])
    }

    @Test("EngineChoice rawValues are pinned strings")
    func engineChoiceRawValuesArePinned() {
        #expect(EngineChoice.onDevice.rawValue == "onDevice")
        #expect(EngineChoice.openRouter.rawValue == "openRouter")
        #expect(EngineChoice.anthropic.rawValue == "anthropic")
    }

    @Test("EngineChoice Codable round-trip")
    func engineChoiceCodableRoundTrip() throws {
        for c in EngineChoice.allCases {
            let data = try JSONEncoder().encode(c)
            #expect(try JSONDecoder().decode(EngineChoice.self, from: data) == c)
        }
    }
}
