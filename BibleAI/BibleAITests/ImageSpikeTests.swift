import Testing

@Suite("Task 0 — on-device image inference (gated)")
struct ImageSpikeTests {

    @Test("model loads from disk", .disabled("No on-device diffusion API in iOS 27 SDK — Task 0 negative result; image gen re-scopes to Core ML or cloud."))
    func imageModel_loadsFromDisk() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("inference produces image output", .disabled("No on-device diffusion API in iOS 27 SDK — Task 0 negative result; image gen re-scopes to Core ML or cloud."))
    func inference_producesImageOutput() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("inference completes under 15s", .disabled("No on-device diffusion API in iOS 27 SDK — Task 0 negative result; image gen re-scopes to Core ML or cloud."))
    func inference_completesUnder15s() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("progress callback reports step/total", .disabled("No on-device diffusion API in iOS 27 SDK — Task 0 negative result; image gen re-scopes to Core ML or cloud."))
    func progressCallback_reportsStepAndTotal() async throws {
        Issue.record("unreached: no on-device image API")
    }
}
