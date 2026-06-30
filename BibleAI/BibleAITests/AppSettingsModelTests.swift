import Testing
@testable import BibleAI

@MainActor
@Suite("Task 5 — AppSettings model")
struct AppSettingsModelTests {

    @Test("Default values match spec")
    func defaultsMatchSpec() {
        let s = AppSettings()
        #expect(s.defaultEngine == .onDevice)
        #expect(s.fallbackEngine == .openRouter)
        #expect(s.accentChoice == .purple)
        #expect(s.hasOnboarded == false)
        #expect(s.hasConsentedToCloud == false)
        #expect(s.youVersionConnected == false)
    }

    @Test("All fields are mutable")
    func fieldsAreMutable() {
        let s = AppSettings()
        s.defaultEngine = .anthropic
        s.fallbackEngine = .onDevice
        s.accentChoice = .teal
        s.hasOnboarded = true
        s.hasConsentedToCloud = true
        s.youVersionConnected = true
        #expect(s.defaultEngine == .anthropic)
        #expect(s.fallbackEngine == .onDevice)
        #expect(s.accentChoice == .teal)
        #expect(s.hasOnboarded == true)
        #expect(s.hasConsentedToCloud == true)
        #expect(s.youVersionConnected == true)
    }
}
