import Foundation
import SwiftData

@Model
final class AppSettings {
    var defaultEngine: EngineChoice
    var fallbackEngine: EngineChoice
    var accentChoice: AccentChoice
    var hasOnboarded: Bool
    var hasConsentedToCloud: Bool
    var youVersionConnected: Bool

    init(
        defaultEngine: EngineChoice = .onDevice,
        fallbackEngine: EngineChoice = .openRouter,
        accentChoice: AccentChoice = .purple,
        hasOnboarded: Bool = false,
        hasConsentedToCloud: Bool = false,
        youVersionConnected: Bool = false
    ) {
        self.defaultEngine = defaultEngine
        self.fallbackEngine = fallbackEngine
        self.accentChoice = accentChoice
        self.hasOnboarded = hasOnboarded
        self.hasConsentedToCloud = hasConsentedToCloud
        self.youVersionConnected = youVersionConnected
    }
}
