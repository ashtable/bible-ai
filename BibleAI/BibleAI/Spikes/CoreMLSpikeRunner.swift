import CoreML
import CoreGraphics
import Foundation
#if canImport(StableDiffusion)
import StableDiffusion
#endif

/// Task 0' spike harness. Proves the four Core ML diffusers unknowns from
/// design.md §6.6 before CoreMLImageGenerator (Task 12) is built.
/// NOT a generator — no ImageGenerating conformance, no MediaStore coupling.
actor CoreMLSpikeRunner {

    enum SpikeError: Error, Equatable {
        case resourcesNotFound(path: String)
        case packageUnavailable
        case noImageProduced
    }

    /// Compiled Core ML resource files the pipeline requires.
    /// NOTE: .mlmodelc (compiled), NOT .mlpackage. The `ml-stable-diffusion`
    /// `ResourceURLs` initializer resolves exactly these names under the base URL.
    static let expectedResourceFiles: [String] = [
        "TextEncoder.mlmodelc",
        "Unet.mlmodelc",
        "VAEDecoder.mlmodelc",
        "VAEEncoder.mlmodelc",
        "vocab.json",
        "merges.txt",
    ]

    static func spikeResourceURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appending(path: "Models/sd-1-5", directoryHint: .isDirectory)
    }

    static var modelIsInstalled: Bool {
        guard let url = try? spikeResourceURL() else { return false }
        let unet = url.appending(path: "Unet.mlmodelc")
        return FileManager.default.fileExists(atPath: unet.path)
    }

    private let resourcesURL: URL

    init(resourcesURL: URL? = nil) throws {
        self.resourcesURL = try resourcesURL ?? Self.spikeResourceURL()
    }

    struct StepSample: Sendable {
        let step: Int
        let stepCount: Int
    }

#if canImport(StableDiffusion)
    func loadPipeline() throws {
        let pipeline = try makePipeline()
        try pipeline.loadResources()
    }

    /// Rebuilds and reloads the pipeline on every call — intentional for cold-start
    /// timing (the ≤15s gate measures from a cold load). Task 12 (`CoreMLImageGenerator`)
    /// must load once and reuse; do not copy this pattern into the real generator.
    func run(
        prompt: String,
        stepCount: Int = 20
    ) throws -> (image: CGImage, steps: [StepSample]) {
        let pipeline = try makePipeline()
        try pipeline.loadResources()

        var cfg = StableDiffusionPipeline.Configuration(prompt: prompt)
        cfg.stepCount = stepCount
        cfg.guidanceScale = 7.5
        cfg.seed = 42
        cfg.disableSafety = true   // no SafetyChecker.mlmodelc is side-loaded for the spike
        // DPM-Solver runs exactly `stepCount` denoising steps. The default PNDM
        // scheduler appends a duplicate PLMS warm-up timestep, so it reports
        // stepCount + 1 progress callbacks (21 for a requested 20). DPM-Solver
        // is also higher quality at the low step counts this speed gate targets.
        cfg.schedulerType = .dpmSolverMultistepScheduler

        var trace: [StepSample] = []
        let images = try pipeline.generateImages(configuration: cfg) { progress in
            // `PipelineProgress.step` is 0-indexed (timeSteps.enumerated());
            // `progress.stepCount` is timeSteps.count, which equals `stepCount`
            // under DPM-Solver. The monotonic-progress assertions expect 1...stepCount.
            trace.append(StepSample(step: progress.step + 1, stepCount: progress.stepCount))
            return true
        }
        guard let image = images.compactMap({ $0 }).first else {
            throw SpikeError.noImageProduced
        }
        return (image, trace)
    }

    /// Builds the pipeline after verifying the resource directory is present.
    /// The `ml-stable-diffusion` `resourcesAt:` initializer requires an explicit
    /// `controlNet:` argument (empty for the text-to-image spike) — there is no
    /// `controlNet`-less overload in 1.1.x.
    private func makePipeline() throws -> StableDiffusionPipeline {
        guard FileManager.default.fileExists(atPath: resourcesURL.path) else {
            throw SpikeError.resourcesNotFound(path: resourcesURL.path)
        }
        // Minimal presence check — the Unet is the load-bearing model file.
        let unet = resourcesURL.appending(path: "Unet.mlmodelc")
        guard FileManager.default.fileExists(atPath: unet.path) else {
            throw SpikeError.resourcesNotFound(path: resourcesURL.path)
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try StableDiffusionPipeline(
            resourcesAt: resourcesURL,
            controlNet: [],
            configuration: config,
            disableSafety: true,
            reduceMemory: true
        )
    }
#else
    func loadPipeline() throws {
        throw SpikeError.packageUnavailable
    }

    func run(prompt: String, stepCount: Int = 20) throws -> (image: CGImage, steps: [StepSample]) {
        throw SpikeError.packageUnavailable
    }
#endif
}
