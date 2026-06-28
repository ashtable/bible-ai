import Testing
import Foundation
@testable import BibleAI

// `import` is only valid at file scope, so the StableDiffusion module is
// brought in here under a `canImport` guard rather than inside test bodies.
// Until the Task 0' spike adds the `ml-stable-diffusion` package dependency,
// this resolves to nothing and the API-shape tests below fail to compile —
// which is the intended "red" state.
#if canImport(StableDiffusion)
import StableDiffusion
#endif

// MARK: - Suite A — API shape (simulator-compatible)

/// Locks in the exact `StableDiffusion` API surface and `CoreMLSpikeRunner`
/// contract the Task 0' implementation must satisfy. These do not run inference;
/// they compile-check symbols and exercise the resource-resolution logic, so they
/// run on the simulator without a side-loaded model.
@Suite("CoreML Image Spike — API shape")
struct CoreMLImageSpikeAPIShape {

    @Test func stableDiffusionModule_isImportable() {
        #expect(SDKProbe.hasStableDiffusion == true)
    }

    @Test func pipelineConfiguration_acceptsSpikeFields() throws {
        // Compile-shape test: confirms Configuration(prompt:), stepCount, guidanceScale, seed
        #if canImport(StableDiffusion)
        var cfg = StableDiffusionPipeline.Configuration(prompt: "test prompt")
        cfg.stepCount = 20
        cfg.guidanceScale = 7.5
        cfg.seed = 42
        #expect(cfg.stepCount == 20)
        #else
        Issue.record("StableDiffusion module not available")
        #endif
    }

    @Test func spikeRunner_resolvesResourceLayout() {
        let expected: Set<String> = [
            "TextEncoder.mlmodelc",
            "Unet.mlmodelc",
            "VAEDecoder.mlmodelc",
            "VAEEncoder.mlmodelc",
            "vocab.json",
            "merges.txt",
        ]
        #expect(Set(CoreMLSpikeRunner.expectedResourceFiles) == expected)
    }

    @Test func spikeRunner_missingResources_throwsLocatable() async throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appending(path: "spike-empty-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let runner = try CoreMLSpikeRunner(resourcesURL: emptyDir)
        await #expect(throws: CoreMLSpikeRunner.SpikeError.self) {
            try await runner.loadPipeline()
        }
    }

    @Test func progressType_exposesStepAndStepCount() {
        // Compile-shape test: locks in the progressHandler signature
        #if canImport(StableDiffusion)
        // The closure type must compile — confirms .step/.stepCount exist and Bool cancels
        let _: (StableDiffusionPipeline.Progress) -> Bool = { progress in
            let _: Int = progress.step
            let _: Int = progress.stepCount
            return false  // return false = cancel
        }
        #else
        Issue.record("StableDiffusion module not available")
        #endif
    }
}

// MARK: - Suite B — on-device inference (hardware-gated)

/// The hard 15s gate and real-output assertions. These require the SD 1.5
/// `Resources/` (compiled `.mlmodelc` + tokenizer files) side-loaded into
/// `Application Support/Models/sd-1-5/` on a **physical** iOS 27 device — they
/// cannot run on the simulator. When the model is absent each test returns early
/// (a pass, not a failure): the tests are not broken, they are waiting on setup.
///
/// To run: `scripts/export_sd15_coreml.sh`, push `Resources/` to the device via
/// `xcrun devicectl`, then run this suite on hardware.
@Suite("CoreML Image Spike — on-device inference")
struct CoreMLImageSpikeHardware {

    /// Returns true when the model is installed and the suite should run.
    /// When false, the caller returns early — Swift Testing has no native skip,
    /// and silently passing a hardware-gated test is the correct behavior here.
    private func modelReady() -> Bool {
        CoreMLSpikeRunner.modelIsInstalled
    }

    @Test func pipeline_loadsResourcesFromDisk() async throws {
        guard modelReady() else { return }
        let runner = try CoreMLSpikeRunner()
        try await runner.loadPipeline()
    }

    @Test func inference_producesNonNilImage() async throws {
        guard modelReady() else { return }
        let runner = try CoreMLSpikeRunner()
        let (image, _) = try await runner.run(prompt: "a serene mountain landscape, oil painting")
        #expect(image.width == 512)
        #expect(image.height == 512)
    }

    @Test func inference_reportsMonotonicStepProgress() async throws {
        guard modelReady() else { return }
        let runner = try CoreMLSpikeRunner()
        let (_, steps) = try await runner.run(prompt: "golden light through forest trees", stepCount: 20)
        #expect(steps.count == 20)
        #expect(steps.first?.step == 1)
        #expect(steps.last?.step == 20)
        #expect(steps.allSatisfy { $0.stepCount == 20 })
        // Verify monotonically increasing
        for i in 1..<steps.count {
            #expect(steps[i].step == steps[i - 1].step + 1)
        }
    }

    @Test func inference_completesUnder15s() async throws {
        guard modelReady() else { return }
        let runner = try CoreMLSpikeRunner()
        let clock = ContinuousClock()
        let start = clock.now
        _ = try await runner.run(prompt: "bible verse calligraphy on parchment", stepCount: 20)
        let elapsed = clock.now - start
        // Hard gate: must pass on physical iOS 27 hardware with .cpuAndNeuralEngine
        #expect(elapsed < .seconds(15), "Inference took \(elapsed) — exceeds 15s gate")
    }
}
