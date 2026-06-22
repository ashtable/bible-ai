import Testing

@Suite("Task 0 — on-device image inference (gated)")
struct ImageSpikeTests {

    @Test("model loads from disk", .disabled("Task 0 negative result: no CoreAIDiffusionPipeline in iOS 27 SDK. Re-scoped to Core ML (.mlpackage) — re-enable in Task 0' (SD 1.5 coremltools export spike)."))
    func imageModel_loadsFromDisk() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("inference produces image output", .disabled("Task 0 negative result: no CoreAIDiffusionPipeline in iOS 27 SDK. Re-scoped to Core ML (.mlpackage) — re-enable in Task 0' (SD 1.5 coremltools export spike)."))
    func inference_producesImageOutput() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("inference completes under 15s", .disabled("Task 0 negative result: no CoreAIDiffusionPipeline in iOS 27 SDK. Re-scoped to Core ML (.mlpackage) — re-enable in Task 0' (SD 1.5 coremltools export spike)."))
    func inference_completesUnder15s() async throws {
        Issue.record("unreached: no on-device image API")
    }

    @Test("progress callback reports step/total", .disabled("Task 0 negative result: no CoreAIDiffusionPipeline in iOS 27 SDK. Re-scoped to Core ML (.mlpackage) — re-enable in Task 0' (SD 1.5 coremltools export spike)."))
    func progressCallback_reportsStepAndTotal() async throws {
        Issue.record("unreached: no on-device image API")
    }
}
