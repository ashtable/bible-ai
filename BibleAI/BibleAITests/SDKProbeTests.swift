import Testing
@testable import BibleAI

// NOTE: @testable import BibleAI compiles, but `SDKProbe` does not exist yet.
// That is intentional — tests are written first (TDD red phase). The build
// will fail with "cannot find 'SDKProbe' in scope" until SDKProbe.swift is added.

@Suite("Task 0 — SDK probe")
struct SDKProbeTests {

    @Test("Core AI diffusion module is NOT in the iOS 27 SDK (negative result)")
    func coreAIDiffusionModule_isUnavailable() {
        // This test references SDKProbe which doesn't exist yet — compile error is the red phase
        #expect(!SDKProbe.hasCoreAIDiffusion)
        #expect(!SDKProbe.hasCoreAILanguageModels)
    }

    @Test("FoundationModels (AFM) IS available")
    func foundationModels_isImportable() {
        #expect(SDKProbe.hasFoundationModels)
    }
}
