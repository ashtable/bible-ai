import Foundation
import SwiftData

@Model
final class AppSettings {
    // iOS 27 beta SwiftData SIGTRAPs on insert/save when a @Model stores any
    // Codable-encoded property (enums included). Persist enums as their raw
    // String and expose the enum via a computed accessor (not persisted).
    // Mirrors the primitive-only storage strategy used by Creation.
    var defaultEngineRaw: String
    var fallbackEngineRaw: String
    var accentChoiceRaw: String

    var hasOnboarded: Bool
    var hasConsentedToCloud: Bool
    var youVersionConnected: Bool

    // MARK: — Computed accessors (not persisted by SwiftData)

    var defaultEngine: EngineChoice {
        get { EngineChoice(rawValue: defaultEngineRaw) ?? .onDevice }
        set { defaultEngineRaw = newValue.rawValue }
    }

    var fallbackEngine: EngineChoice {
        get { EngineChoice(rawValue: fallbackEngineRaw) ?? .openRouter }
        set { fallbackEngineRaw = newValue.rawValue }
    }

    var accentChoice: AccentChoice {
        get { AccentChoice(rawValue: accentChoiceRaw) ?? .purple }
        set { accentChoiceRaw = newValue.rawValue }
    }

    init(
        defaultEngine: EngineChoice = .onDevice,
        fallbackEngine: EngineChoice = .openRouter,
        accentChoice: AccentChoice = .purple,
        hasOnboarded: Bool = false,
        hasConsentedToCloud: Bool = false,
        youVersionConnected: Bool = false
    ) {
        self.defaultEngineRaw = defaultEngine.rawValue
        self.fallbackEngineRaw = fallbackEngine.rawValue
        self.accentChoiceRaw = accentChoice.rawValue
        self.hasOnboarded = hasOnboarded
        self.hasConsentedToCloud = hasConsentedToCloud
        self.youVersionConnected = youVersionConnected
    }
}
