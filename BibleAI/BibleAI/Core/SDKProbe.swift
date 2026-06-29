/// Compile-time probe for AI SDK module availability on the build SDK.
///
/// Task 0 uses this to record a negative result: the iOS 27 SDK ships
/// `FoundationModels` (AFM) but does **not** ship a Core AI diffusion /
/// language-model framework. Each property resolves at compile time via
/// `canImport`, so it reflects the SDK the app is built against.
enum SDKProbe {
    static var hasCoreAIDiffusion: Bool {
        #if canImport(CoreAIDiffusionPipeline)
        return true
        #else
        return false
        #endif
    }

    static var hasCoreAILanguageModels: Bool {
        #if canImport(CoreAILanguageModels)
        return true
        #else
        return false
        #endif
    }

    static var hasFoundationModels: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// Task 0': true when Apple's `ml-stable-diffusion` (`StableDiffusion`) module
    /// is linked. The package dependency is intentionally absent at the start of
    /// Task 0' — this resolves `false` until the spike adds it.
    static var hasStableDiffusion: Bool {
        #if canImport(StableDiffusion)
        return true
        #else
        return false
        #endif
    }
}
