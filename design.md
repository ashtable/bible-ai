# Bible AI — Design Document

> Authoritative reference for implementation. Build test-first per `tdd.md`. Work the task table in §10 top to bottom, respecting dependencies. Task 0 is a hard blocker for all image-generation work.

---

## §1 Product Overview

**Bible AI** turns a Bible verse into AI-generated art, slideshows, and short-form video. It is **on-device-first**: the full create→preview→save loop runs offline, in airplane mode, with zero network calls. Nothing leaves the device without an explicit tap.

### Positioning
- **On-device-first.** Image generation runs locally via **Core ML** (iOS 27); prompt/caption generation runs locally via **Apple Foundation Models**. Cloud is a user-opted fallback, never a default dependency. (Custom on-device LLMs like Qwen3 are not available in the iOS 27 SDK — see §6.7.)
- **Private by default.** Creations save *inside the app* first. Saving to Photos/Files and publishing to social are explicit, separate actions.
- **Free by default.** The app charges nothing. The only money that ever changes hands is the user's own OpenRouter/Anthropic spend on their own keys.
- **Studio energy, not a devotional reader.** The product is a creative tool. Verse lookup is an input, not the destination.

### Target user
Someone who shares faith-themed visual content (Reels, Stories, quote posts) and wants it generated quickly, privately, and for free — without learning a desktop creative suite.

### What the app is *not*
- Not a Bible study / reading app (YouVersion already owns that).
- Not a social network — it publishes *out* to existing platforms.
- Not a subscription product (see §8 — YouVersion non-commercial clause).

### Core capabilities
| Capability | On-device | Cloud fallback |
|---|---|---|
| Prompt / caption generation (text) | AFM (FoundationModels) | OpenRouter → Anthropic |
| Image generation | SD 3.5 M, SD 2.1, SD 1.5 (Core ML `.mlpackage`) | OpenRouter (incl. FLUX-class) |
| Slideshow assembly | local (compositing) | — |
| Music | curated sample library | OpenRouter (cloud-only generation) |
| Video | — | cloud-only (OpenRouter) |
| ASR (verse dictation, future) | Whisper large-v3-turbo | — |

---

## §2 Design Principles

1. **Offline is the contract, not a feature.** Any code path that *requires* network must degrade to an on-device path or fail loudly with a recovery action. The happy path never touches the network.
2. **Explicit egress.** Three distinct trust boundaries — (a) save in app, (b) export to device, (c) publish/cloud. Each crossing is a deliberate, visible user action. Cloud generation gates behind a one-time consent sheet.
3. **Free means free.** No ads, no paywalls, no in-app purchase. Billing is exclusively the user's own provider keys.
4. **Routing is invisible, attribution is not.** The engine picks the best available generator silently, but every artifact records *which* model produced it and surfaces it in the UI.
5. **One heavy job at a time.** Generation is serialized behind a busy-guard. The UI always reflects whether the device is busy.
6. **Availability over assumption.** Never assume an on-device model or Apple Intelligence is present. Check `AIAvailability` and `SystemLanguageModel.default.availability` at runtime; fall back gracefully.
7. **Public-domain by default.** Verse text defaults to KJV/WEB/ASV. Copyrighted translations are surfaced per-translation with their licensing caveats, never silently used for generated art.
8. **Minimal surface.** No third-party state library, no DI container, no networking layer per service. `@Observable` + `@Environment`, one shared `APIClient`, one `AppRouter`.

---

## §3 Design Tokens & Visual Language

All tokens live in `BibleAITheme.swift` and are consumed through SwiftUI environment/`Color` extensions — never hardcoded hex in views.

### Color
| Token | Hex | Use |
|---|---|---|
| `canvas` | `#e9e7e2` | App background |
| `card` | `#ffffff` | Cards, sheets, elevated surfaces |
| `subtle` | `#f3f1ec` | Secondary fills, inset rows, disabled states |
| `accent` (default) | `#6C5CE7` | Primary actions, selection, progress — purple |
| `accent` (alt 1) | `#1FA98F` | Teal (user-selectable) |
| `accent` (alt 2) | `#E0673B` | Burnt orange (user-selectable) |

Accent is stored in `AppSettings.accentChoice` and resolved through the theme. All three accents must clear WCAG AA contrast on `canvas` and `card` for their text/icon usages.

### Spacing — 8pt grid
`xs = 4 · s = 8 · m = 16 · l = 24 · xl = 40`. No off-grid spacing values in views.

### Typography
- **`NunitoSans`** — all UI body, labels, headings.
- **`Caveat`** — display/handwritten accents only (verse-of-day flourish, hero callouts). Never for body or controls.

Fonts are bundled and registered via the type scale in `BibleAITheme.swift`. Provide a `Font` extension exposing named roles (`.displayHandwritten`, `.titleL`, `.body`, `.caption`) so views never reference raw font names or sizes.

### Iconography & motion
- SF Symbols throughout; custom glyphs only where SF Symbols has no equivalent.
- Progress is always determinate when step counts are known (the Core ML diffusers pipeline exposes `step`/`stepCount`); spinner only when truly indeterminate (model download negotiation).
- Generation progress uses the accent color and a subtle pulse; never blocks the whole screen — the canvas stays visible behind it.

---

## §4 Navigation Architecture

A single `AppRouter` (`@Observable`) owns navigation state and is injected into `@Environment`. The root is a `TabView` with four tabs, each wrapping its own `NavigationStack` driven by a typed path on the router.

```swift
import SwiftUI

@Observable
final class AppRouter {
    enum Tab: Hashable { case home, create, library, settings }

    // Typed destinations per stack. Each tab owns its own path.
    enum Route: Hashable {
        case artifactDetail(creationID: UUID)
        case modelRegistry
        case apiKeyEntry(provider: CloudProvider)
        case slideshowEditor(creationID: UUID)
        case publishDestinations(creationID: UUID)
    }

    var selectedTab: Tab = .home
    var homePath: [Route] = []
    var createPath: [Route] = []
    var libraryPath: [Route] = []
    var settingsPath: [Route] = []

    // Sheets are modal and global; presented over whichever tab is active.
    enum Sheet: Identifiable {
        case modelPicker(jobDraftID: UUID)
        case cloudConsent
        case saveActions(creationID: UUID)
        var id: String { String(describing: self) }
    }
    var activeSheet: Sheet?

    func push(_ route: Route, on tab: Tab) { /* append to the matching path */ }
    func present(_ sheet: Sheet) { activeSheet = sheet }
    func resetToRoot(_ tab: Tab) { /* clear matching path */ }
}
```

**Why this shape:** One observable owns *all* navigation, so deep links, "jump to library after save," and tab resets are single-call mutations rather than scattered `@State` bindings. Per-tab paths keep each stack independent (switching tabs preserves position). Sheets are global because consent and model-picking can be triggered from multiple screens.

**Tab map:**
- **Home** → Verse-of-day hero (§5.2, direction B).
- **Create** → Guided stepper (§5.3, direction A).
- **Library** → Saved artifacts grid (§5.7).
- **Settings** → Connections, defaults, storage (§5.8).

`ModelRegistryView` is reachable from both the Create model picker and Settings; it pushes onto the *active* tab's path.

---

## §5 Screens & Flows

Each screen group below maps to its wireframe section and names the `@Observable` ViewModel that owns its state. Default directions (where multiple were proposed) are called out and are the ones to implement.

### §5.1 Onboarding

Three sequential steps presented before the main `TabView` on first launch (tracked by `AppSettings.hasOnboarded`).

**1A — Welcome.** Hero loop showing verse→art animation. Single "Get started" CTA. Badge: **"RUNS OFFLINE · 100% FREE."** No account required to proceed.

**1B — YouVersion sign-in.** Presents the YouVersion OAuth sheet (verse highlights/notes sync, see §7). Prominent **"Continue as guest"** fallback — guest mode uses bundled public-domain verse data and still reaches the full create loop.

**1C — Engine setup.** On-device is **pre-selected and labeled FREE**. Cloud fallback is an optional toggle (explains it needs the user's own key). If the user proceeds with on-device, kick off the first image-model download with a determinate progress bar: **"downloading · 38% · compiling for Core ML."** Download is resumable and can be backgrounded; the user can enter the app and the model finishes in the background.

ViewModel: `OnboardingViewModel` (owns step index, YouVersion auth result, selected engine, download progress observed from `ModelDownloadManager`).

### §5.2 Home — Verse-of-Day Hero (DEFAULT: direction B)

Full-height hero card with generated art behind the verse-of-day text + reference. Three quick-create buttons (**Image · Slideshow · Video**) seed a `GenerationJob` draft and deep-link into Create with verse + format pre-filled. A **"Your library →"** link jumps to the Library tab.

- Verse-of-day comes from YouVersion (or bundled rotation in guest mode).
- The hero art is generated on-device the first time per day and cached as a `Creation` flagged ephemeral (not shown in Library unless saved).
- Directions A (activity feed) and C (template gallery) are documented as future home variants but **not** implemented now.

ViewModel: `HomeViewModel` (verse-of-day fetch, hero art generation/caching, quick-create seeding).

### §5.3 Create Studio — Guided Stepper (DEFAULT: direction A)

Four-step progress bar: **VERSE → FORMAT → MODELS → STYLE**, then **Generate**.

1. **VERSE** — `VersePickerView`: search/browse, translation selector (public-domain default), or accept the seeded verse.
2. **FORMAT** — toggle Image / Slides / Video. Selecting Video/Music surfaces the cloud-only notice inline (no on-device path).
3. **MODELS** — horizontal models row, each chip badged **ON-DEVICE** (FREE) or **CLOUD**. "Auto" is the default and lets `GenerationEngine` route. Tapping opens `ModelPickerSheet` (§5.4).
4. **STYLE** — prompt editor (pre-filled by AFM, or a cloud text generator, from the verse), style presets, live `LiveCanvasView` preview.

**Generate** validates the draft, then runs the job through `GenerationEngine`, streaming into `GenerationProgressView`. Directions B/C/D documented as alternates; not implemented now.

ViewModel: `CreateViewModel` (holds the `GenerationJob` draft, current step, validation, drives generation, owns the progress stream subscription).

### §5.4 Model Picker & Registry

**4A — Per-generation model sheet (`ModelPickerSheet`).** Tabs: Text / Image / Music / Video. On-device models are starred and labeled **FREE**; cloud models labeled **CLOUD · FREE** or **CLOUD · PREMIUM** (premium = user's paid provider tier). Only installed on-device models are selectable; uninstalled ones link to the registry.

**4B — On-device registry (`ModelRegistryView`).** Search bar + source chips (HuggingFace / Ollama / Civitai). Rows show download state (**✓ Installed** / `progress %` / **Get**) and a storage meter. Downloads go through `ModelDownloadManager` into `Application Support/Models/<model-name>/`. Models are **never bundled** — always runtime-downloaded.

ViewModels: `ModelPickerViewModel`, `ModelRegistryViewModel`.

### §5.5 Preview, Save & Edit

**5A — Preview + save (`ArtifactPreviewView` / `SaveActionsView`).** Carousel (with play button for slideshow/video). Verse text + **model attribution** shown. Primary CTA: **"Save in app — private 🔒"** (default). Secondary: **Save to Gallery**, **Save to Files**. Outline button: **Publish…** (routes through consent → §5.6).

**5B — Slideshow/video editor (`SlideshowEditorView`).** Scene thumbnails strip, **+ add scene**, music row (curated sample or cloud MusicGen), length picker. Editing mutates the draft and re-composites on-device.

ViewModels: `ArtifactPreviewViewModel`, `SlideshowEditorViewModel`.

### §5.6 Publish (explicit opt-in only)

**6A — Destinations (`PublishDestinationsView`).** "You're in control" banner. Multi-select: Instagram / TikTok / Facebook / LinkedIn. "Continue."

**6B — Platform crop + filters (`PlatformCropView` / `PublishConfirmView`).** Per-platform crop frame (e.g. 9:16 for IG Reel), aspect toggle (1:1 / 4:5 / 9:16), length slider (max 90s), filter strip. Publishing uses the system share sheet / platform SDKs as available; the artifact is marked **Published** in the Library.

ViewModels: `PublishViewModel`.

### §5.7 Library

**7A — Saved artifacts (`LibraryView`).** 2×2 grid, filter chips (All / Private / Published / Video). Private items show 🔒; published show a **PUBLISHED** badge. Backed by a `#Predicate`-filtered `@Query` over `Creation` using the denormalized fields.

**7B — Artifact detail (`ArtifactDetailView`).** Full preview, metadata (verse, models, privacy), actions: Gallery / Publish / Delete, privacy toggle.

ViewModels: `LibraryViewModel`, `ArtifactDetailViewModel`.

### §5.8 Settings (`SettingsView`)

- **Connections:** YouVersion (Connected ✓ / Connect), OpenRouter key (`sk-•••• ▸`), Anthropic key (+ Add ▸). Keys entered via `APIKeyEntryView`, stored in Keychain.
- **"Bible AI is 100% free" callout** — billing only through OpenRouter/Anthropic on the user's own account.
- **Defaults:** Default engine (ON-DEVICE), Fallback (OpenRouter free ▾).
- **On-device storage meter** (e.g. 4.2 / 64 GB · **Manage ▸** → registry for deletion).

ViewModel: `SettingsViewModel`.

---

## §6 Technical Architecture

### §6.1 Stack & Platform
- **iOS 27 beta · Swift (Swift 6 concurrency) · SwiftUI · SwiftData.**
- **On-device generation:**
  - Image: **Core ML** (`CoreML` framework) via Apple's `swift-coreml-diffusers` package — models as `.mlpackage` files, exported with `coremltools`. SD 1.5/2.1/3.5 M on-device; FLUX.2 Klein 4B path TBD pending the Task 0' Core ML export spike.
  - Built-in text: Apple **Foundation Models** (`FoundationModels`, `SystemLanguageModel.default`) — confirmed present and working in the iOS 27 SDK.
  - Custom on-device text (Qwen3): **unavailable** — there is no on-device custom-LLM framework in the iOS 27 SDK. Qwen3 text falls through to cloud (OpenRouter → Anthropic) for now.
- **Cloud fallback:** OpenRouter (user key) → Anthropic (user key).

> ⚠️ **Task 0 finding (confirmed 2026-06-22):** the `CoreAIDiffusionPipeline` / `CoreAILanguageModels` frameworks the original design assumed **do not exist** in the iOS 27 SDK — `CoreAI.framework` is a 9-line stub with no diffusion or language-model API. `FoundationModels` (AFM) *is* fully present. On-device image generation is re-scoped to **Core ML** (`.mlpackage`). Do not reintroduce any `CoreAI*` API or `.aimodel` packaging. The Core ML diffusers API and SD-export viability must still be confirmed in **Task 0'** before any image-generation UI is built.

### §6.2 State & DI
`@Observable` + `@Environment`. **No third-party state management, no DI container.** One `@Observable` ViewModel per major feature screen (named in §5). Shared services (`GenerationEngine`, `MediaStore`, `APIClient`, `KeychainStore`, `AIAvailability`, `ModelDownloadManager`, `YouVersionService`) are constructed once at app root and injected via `@Environment`.

### §6.3 Navigation
Single `AppRouter` (`@Observable`) in `@Environment`; `TabView` + per-tab `NavigationStack` with typed `Route` paths; global `Sheet` enum. See §4.

### §6.4 Data Layer

SwiftData models `Creation` and `AppSettings` under `SchemaV1` with an (initially empty) `AppMigrationPlan`. **Every future `@Model` change must add a migration stage.** Never rename/reorder enum cases on persisted types without a migration.

```swift
import SwiftData
import Foundation

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Creation.self, AppSettings.self] }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] } // append a stage on every schema change
}

// Verse is a Codable composite blob — NOT directly queryable.
struct VerseRef: Codable, Hashable, Sendable {
    var reference: String       // "John 3:16"
    var book: String            // "John"
    var translation: String     // "WEB"
    var text: String
}

@Model
final class Creation {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // Codable composite. Sub-fields are NOT reliably queryable in #Predicate,
    // so we denormalize the fields we filter on (below).
    var verse: VerseRef

    // Denormalized, queryable mirrors of verse fields. Keep in sync on write.
    var verseReference: String
    var verseBook: String
    var verseTranslation: String

    var format: CreationFormat        // image / slideshow / video
    var privacy: Privacy              // private / published
    var isEphemeral: Bool             // verse-of-day hero cache, not user-saved

    // Model attribution (which generators produced this).
    var imageModelID: String?
    var textModelID: String?
    var musicModelID: String?

    // Relative artifact paths (see §6.12). NEVER absolute.
    var artifactRelativePaths: [String]

    init(verse: VerseRef, format: CreationFormat) {
        self.id = UUID()
        self.createdAt = .now
        self.verse = verse
        self.verseReference = verse.reference
        self.verseBook = verse.book
        self.verseTranslation = verse.translation
        self.format = format
        self.privacy = .private
        self.isEphemeral = false
        self.artifactRelativePaths = []
    }
}

@Model
final class AppSettings {
    var defaultEngine: EngineChoice      // .onDevice / .openRouter / .anthropic
    var fallbackEngine: EngineChoice
    var accentChoice: AccentChoice
    var hasOnboarded: Bool
    var hasConsentedToCloud: Bool
    var youVersionConnected: Bool

    init() {
        self.defaultEngine = .onDevice
        self.fallbackEngine = .openRouter
        self.accentChoice = .purple
        self.hasOnboarded = false
        self.hasConsentedToCloud = false
        self.youVersionConnected = false
    }
}
```

> ⚠️ **Predicate caveat (verified mid-2026, re-test on iOS 27):** a single Codable struct property persists as a *composite attribute* and its sub-fields *may* be queryable — but **collections of structs and enums persist as opaque blobs and crash in `#Predicate`.** That is why `verseReference/Book/Translation` are denormalized scalar `String`s rather than queried out of `verse`. Filter and sort only on the denormalized scalars and on first-class scalar fields.

### §6.5 Generation Architecture

`GenerationEngine` is the single entry point. It reads `AIAvailability` and `AppSettings.defaultEngine`/`fallbackEngine`, then routes a `GenerationJob` to the correct concrete generator behind a serial busy-guard, emitting progress over an `AsyncThrowingStream`.

```swift
// Sendable value types only cross actor/stream boundaries — never a live @Model.
struct GenerationJob: Sendable, Identifiable {
    let id: UUID
    var verse: VerseRef
    var format: CreationFormat
    var prompt: String
    var preferredImageModelID: String?  // nil = Auto
    var preferredTextModelID: String?
    var enginePreference: EngineChoice?  // nil = use AppSettings
}

enum GenerationProgress: Sendable {
    case queued
    case routing(engine: String, model: String)
    case downloadingModel(progress: Double)
    case step(current: Int, total: Int)        // diffusion steps
    case producedArtifact(relativePath: String, kind: ArtifactKind)
    case finished(GenerationResult)            // Sendable result, NOT a @Model
}

struct GenerationResult: Sendable {
    let jobID: UUID
    let artifactRelativePaths: [String]
    let imageModelID: String?
    let textModelID: String?
    let musicModelID: String?
}

// Per-capability protocols are Actor-constrained.
protocol ImageGenerating: Actor {
    func generate(_ job: GenerationJob) -> AsyncThrowingStream<GenerationProgress, Error>
}
protocol TextGenerating: Actor {
    func generate(prompt: String, verse: VerseRef) async throws -> String
}
protocol MusicGenerating: Actor { /* cloud-only or curated */ }
protocol VideoGenerating: Actor { /* cloud-only */ }

@Observable
final class GenerationEngine {
    private var isBusy = false   // serial busy-guard: one heavy job at a time

    func run(_ job: GenerationJob) -> AsyncThrowingStream<GenerationProgress, Error> {
        // 1. reject if busy
        // 2. route via AIAvailability + AppSettings
        // 3. drive the chosen Actor generator off the main actor
        // 4. yield Sendable progress; caller inserts the Creation on main actor
    }
}
```

**Routing tables (best-available first):**
- **Image (revised, Core ML):** SD 3.5 Medium → SD 2.1 → SD 1.5 (all on-device `.mlpackage`) → cloud (OpenRouter). FLUX.2 Klein is cloud-only until a Core ML export is proven (§6.6); on-device order finalizes after Task 0' perf data.
- **Text (revised):** AFM (if `.available`) → OpenRouter → Anthropic. The Qwen3 on-device tiers were removed — no custom-LLM framework in the iOS 27 SDK (§6.7).
- **Music:** curated sample library → cloud (OpenRouter). No on-device model.
- **Video:** cloud (OpenRouter) only. No on-device model.

**Concurrency:** on-device (Core ML) inference and model downloads never run on the main actor. Generators are `Actor`s returning `Sendable` value types; the *caller* inserts the resulting `Creation` into the `ModelContext` on the main actor (or via the `@ModelActor` writer). The busy-guard guarantees a single heavy job at a time.

### §6.6 On-Device Image Integration (Core ML)

> **Task 0 finding (2026-06-22):** the originally-specified `CoreAIDiffusionPipeline` is **absent** from the iOS 27 SDK; `CoreAI.framework` is a stub. On-device image generation is re-scoped to **Core ML**. The code below is the *target shape* — the concrete Core ML diffusers API must be confirmed in **Task 0'** before Tasks 12/13 are built.

`CoreMLImageGenerator` (SD family) conforms to `ImageGenerating`, backed by the `CoreML` framework and Apple's **`swift-coreml-diffusers`** package (`StableDiffusionPipeline` from `ml-stable-diffusion`). Models are exported with **`coremltools`** to `.mlpackage` and load from `Application Support/Models/<model-name>/`.

```swift
import CoreML
import StableDiffusion   // Apple's swift-coreml-diffusers package (ml-stable-diffusion)

actor CoreMLImageGenerator: ImageGenerating {
    func generate(_ job: GenerationJob) -> AsyncThrowingStream<GenerationProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Resolves to the model's compiled .mlmodelc / .mlpackage directory.
                    let resourceURL = try ModelLocator.url(for: job.preferredImageModelID ?? "sd-1-5")

                    var mlConfig = MLModelConfiguration()
                    mlConfig.computeUnits = .cpuAndNeuralEngine   // ANE-first; confirm in Task 0'

                    let pipeline = try StableDiffusionPipeline(
                        resourcesAt: resourceURL,
                        configuration: mlConfig
                    )
                    try pipeline.loadResources()

                    var cfg = StableDiffusionPipeline.Configuration(prompt: job.prompt)
                    cfg.stepCount = 20
                    cfg.guidanceScale = 7.5

                    // progressHandler returns false to cancel; emit determinate step progress.
                    let images = try pipeline.generateImages(configuration: cfg) { progress in
                        continuation.yield(.step(current: progress.step, total: progress.stepCount))
                        return true
                    }
                    guard let cgImage = images.compactMap({ $0 }).first else {
                        throw ImageGenError.noOutput
                    }

                    let rel = try MediaStore.shared.persistImage(cgImage, for: job.id)
                    continuation.yield(.producedArtifact(relativePath: rel, kind: .image))
                    continuation.yield(.finished(.init(jobID: job.id,
                                                       artifactRelativePaths: [rel],
                                                       imageModelID: job.preferredImageModelID ?? "sd-1-5",
                                                       textModelID: nil, musicModelID: nil)))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}
```

**SD 1.5 / 2.1 / 3.5 M:** Core ML `.mlpackage` is the on-device route. SD 1.5 is the Task 0' target (smallest, most likely to clear the ≤15s bar on target hardware); 2.1 and 3.5 M follow once SD 1.5 is proven.

**FLUX.2 Klein 4B:** **TBD** — Core ML export viability for FLUX.2 is unknown (`coremltools` support for the FLUX architecture is unverified, and 4B may exceed the on-device memory ceiling). Do not plan FLUX.2 on-device until a dedicated spike confirms a working `.mlpackage` export and acceptable inference time. Until then, FLUX-class quality is a cloud-only option.

> ⚠️ Confirm in **Task 0'**: the exact `swift-coreml-diffusers` API surface (`StableDiffusionPipeline` initializer, `Configuration` fields, `progressHandler` `step`/`stepCount` semantics, `return false` to cancel), the `coremltools` SD-1.5 export recipe, and the compiled-resource layout `ModelLocator` must resolve.

### §6.7 Apple Foundation Models (AFM)

`FoundationModelsTextGenerator` conforms to `TextGenerating`. **Always gate on `SystemLanguageModel.default.availability` — never on `#available`.** Handle every `.unavailable(reason:)` case with a fallback (next text generator in the routing table, ultimately a templated prompt).

```swift
import FoundationModels

actor FoundationModelsTextGenerator: TextGenerating {
    func generate(prompt: String, verse: VerseRef) async throws -> String {
        let afm = SystemLanguageModel.default
        switch afm.availability {
        case .available:
            let session = LanguageModelSession(model: afm)
            let response = try await session.respond(to: prompt)
            return response.content
        case .unavailable(let reason):
            // .deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady
            throw TextGenError.afmUnavailable(reason)  // engine routes to cloud (OpenRouter) next
        }
    }
}
```

AFM has content guardrails that may refuse religious-adjacent prompts. Handle refusals as a recoverable error: fall back to the next text generator, and ultimately to a deterministic templated prompt builder so the create loop never dead-ends.

**Custom on-device text (Qwen3) — unavailable.** The original design assumed a `CoreAILanguageModels` framework (`CoreAILanguageModel(resourcesAt:)` → `LanguageModelSession(model:)`) for running downloaded Qwen3 4B / 0.6B weights on-device. **Task 0 confirmed (2026-06-22) that no such framework exists in the iOS 27 SDK.** There is no supported way to run arbitrary custom LLM weights on-device in this SDK.

Consequently, the **Qwen3 on-device tiers are removed from the text routing table**. Custom-text generation falls through to cloud:

- **Text routing (revised):** AFM (`FoundationModels`, if `.available`) → OpenRouter → Anthropic.

If a supported on-device custom-LLM path appears in a later iOS 27 seed (or via a third-party Core ML / MLX-backed runtime), reintroduce a `CoreMLTextGenerator` actor and restore the Qwen3 tiers between AFM and the cloud generators. Until then, do not implement a custom on-device text generator.

### §6.8 Cloud Fallback

`OpenRouterTextGenerator` and `AnthropicTextGenerator` conform to `TextGenerating` and use the shared `APIClient`. They are only reachable after: (a) `AppSettings.hasConsentedToCloud == true`, (b) a valid key exists in Keychain, (c) network is reachable. If any is false, the engine routes back on-device or surfaces the appropriate recovery sheet (§5.8 / §6.13). Image cloud fallback also routes through OpenRouter. Music and video generation are cloud-only via OpenRouter.

### §6.9 Networking

Single `APIClient` — URLSession-based, **`URLProtocol`-mockable (no URLSession subclassing)**, shared by all network services (`YouVersionService`, `OpenRouterTextGenerator`, `AnthropicTextGenerator`, cloud image/music/video). No per-service hand-rolled networking.

```swift
final class APIClient: Sendable {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func send<Response: Decodable>(_ request: URLRequest, decoding: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try APIClient.validate(response)
        return try JSONDecoder().decode(Response.self, from: data)
    }
    static func validate(_ response: URLResponse) throws { /* status mapping */ }
}
// Tests inject a URLSession configured with a custom URLProtocol — no subclassing.
```

### §6.10 Security

API keys (OpenRouter, Anthropic) live in **Keychain only** — never SwiftData, never UserDefaults. `KeychainStore` is the sole accessor.

```swift
struct KeychainStore {
    enum Key: String { case openRouter, anthropic }
    func set(_ value: String, for key: Key) throws { /* SecItem add/update */ }
    func get(_ key: Key) throws -> String? { /* SecItemCopyMatching */ }
    func delete(_ key: Key) throws { /* SecItemDelete */ }
}
```

Cloud generation presents a one-time `CloudConsentSheet` before the first network call; on accept, set `AppSettings.hasConsentedToCloud = true`. If a key is missing or invalid at call time, route to on-device or present the key-missing recovery sheet (§6.13) — never silently fail.

### §6.11 Concurrency
- On-device (Core ML) inference and model downloads: **never on the main actor.**
- `SwiftData.ModelContext` writes: confined to a `@ModelActor`-isolated writer type.
- Generators return `Sendable` value types only; callers insert into `ModelContext` on the main actor (or via the writer actor).
- One heavy generation at a time (serial busy-guard in `GenerationEngine`).
- Never return a live `@Model` across an actor or `AsyncThrowingStream` — pass IDs / `Sendable` results, then refetch.

### §6.12 Storage

`MediaStore` owns `Application Support/Artifacts/`. **All artifact paths stored as relative paths — never absolute** (the container UUID changes on reinstall; absolute paths break).

```swift
struct MediaStore {
    static let shared = MediaStore()
    private let root: URL // <Application Support>/Artifacts

    func absoluteURL(forRelative rel: String) -> URL { root.appending(path: rel) }
    func persistImage(_ image: GeneratedImage, for jobID: UUID) throws -> String {
        // write under Artifacts/<jobID>/..., return the RELATIVE path
    }
}
```

Downloaded models live in `Application Support/Models/<model-name>/` via `ModelDownloadManager`, **never bundled**. `ModelLocator` resolves a model ID to its on-disk Core ML resource URL (`.mlpackage` / compiled `.mlmodelc`) and reports presence to `AIAvailability`.

**`AIAvailability`** (the routing oracle) checks, in order:
1. `SystemLanguageModel.default.availability` (AFM).
2. On-device (Core ML) model file presence in `Application Support/Models/`.
3. Network reachability.

```swift
@Observable
final class AIAvailability {
    private(set) var afm: SystemLanguageModel.Availability
    private(set) var installedModelIDs: Set<String>
    private(set) var isNetworkReachable: Bool
    func refresh() async { /* re-evaluate all three */ }
}
```

---

## §7 External Integrations

### YouVersion
- **Auth:** OAuth (sign-in preserves highlights/notes) with a **"Continue as guest"** fallback that uses bundled public-domain verse data. Token via `APIClient`; no hand-rolled networking.
- **Content:** verse lookup and verse-of-day. `YouVersionService` returns `Sendable` `VerseRef` values.
- **Constraint:** the **non-commercial clause** (API opened April 2026) revokes access if the app adds ads, paywalls, or paid tiers. See §8.

### Social Publishing
- Explicit opt-in only (§5.6). Multi-select destinations (Instagram / TikTok / Facebook / LinkedIn). Per-platform crop/aspect/length (max 90s) and filters.
- Use the system share sheet / available platform SDKs. Mark the `Creation` as `published` on success.

---

## §8 Critical Constraints

1. **YouVersion non-commercial clause (April 2026).** No ads, paywalls, or paid tiers — doing so can revoke API access. Any monetization must be re-validated against current YouVersion terms first, *or* verse sourcing must move to another provider. This is why the product is "100% free."
2. **Bible translation copyright.** Default to **public-domain** translations (**KJV, WEB, ASV**). **ESV/NIV are commercially restricted — do not use them for generated art.** Surface licensing caveats per-translation; never silently use a copyrighted translation as an art input.
3. **Task 0 hard blocker.** Task 0 spike (complete): `CoreAIDiffusionPipeline` absent from iOS 27 SDK — confirmed negative. On-device image re-scoped to Core ML (`.mlpackage`). **Task 0' required:** prove **SD 1.5** exports via `coremltools` to `.mlpackage` and runs inference **≤15s on iOS 27 target hardware** before any image-generation UI is built. If it cannot, image generation re-scopes to cloud-first.
4. **AFM availability gate.** Always check `SystemLanguageModel.default.availability`; handle `.deviceNotEligible` / `.appleIntelligenceNotEnabled` / `.modelNotReady`. **Do not gate on `#available`.**
5. **Music generation:** no on-device model → cloud-only (OpenRouter) or curated sample library fallback.
6. **Video generation:** no on-device model → cloud-only (OpenRouter).
7. **Relative paths only** for artifacts; **models never bundled**; **keys in Keychain only.**

---

## §9 Open Questions

1. **Core AI SDK signatures. — ANSWERED.** Confirmed 2026-06-22: `CoreAIDiffusionPipeline` / `CoreAILanguageModels` are not present in the iOS 27 SDK. `CoreAI.framework` is a 9-line stub. `FoundationModels` is fully present. Image generation re-scoped to Core ML; Qwen3 on-device path unavailable, falls to cloud. The remaining unknowns (Core ML diffusers API surface, `coremltools` SD-1.5 export recipe, inference time) move to **Task 0'**.
2. **SwiftData predicate-on-composite support.** Re-test on iOS 27 whether sub-fields of the `verse` composite are queryable. The denormalized fields make us safe regardless, but if composites *are* queryable we could drop them in a future migration.
3. **AFM refusal rate on religious prompts.** Need empirical data — if AFM frequently refuses, demote it below the cloud generators in the text routing table (there is no on-device fallback left below it, so frequent refusals push text generation to cloud).
4. **FLUX.2 Klein vs SD on target hardware.** FLUX.2 is 4-step (faster in theory) but 4B (larger). Now gated on whether FLUX.2 even exports to Core ML `.mlpackage` via `coremltools` (architecture support unverified) and fits the on-device memory ceiling — a dedicated spike beyond Task 0'. Until then FLUX-class quality is cloud-only; Task 0' perf benchmarks decide the default *SD* model and on-device routing order.
5. **SD 3.5 Medium HF-gating.** It is HuggingFace-gated — confirm the registry download flow can handle gated models (auth token) before listing it.
6. **Publishing SDKs vs share sheet.** Which platforms get true SDK integration vs system share sheet? Affects §5.6 scope.
7. **Music: curated library sourcing.** Need royalty-free/public-domain audio for the curated fallback — licensing TBD.
8. **Storage pressure.** Multiple multi-GB `.mlpackage` model files plus artifacts may exceed comfortable storage on smaller devices. Need an eviction/"Manage" policy in the registry.

---

## §10 Implementation Tasks

Work top to bottom, respecting **Dependencies**. The TDD agent appends ` - Done!` to the `#` column per `tdd.md §17`. Phases: **P0** spike · **P1** skeleton · **P2** services · **P3** generators · **P4** UI · **P5** resilience/polish · **P6** tests · **P7** submission.

| # | Task | Description | Dependencies | Phase |
|---|---|---|---|---|
| 0 - Done! | Core AI image spike (HARD BLOCKER) | Export SD 1.5 or FLUX.2 Klein 4B to `.aimodel`; run inference on iOS 27 target hardware in ≤15s. Confirm `CoreAIDiffusionPipeline` API. | — | P0 |
| 0' | Core ML image spike | Export SD 1.5 to `.mlpackage` via `coremltools`; run inference on iOS 27 target hardware in ≤15s. Confirm Core ML diffusers API. Unblocks Tasks 12, 13, 52, 53. | — | P0 |
| 1 | Xcode project skeleton | Create iOS 27 SwiftUI app target, Swift 6 mode, folder structure, bundled fonts. | — | P1 |
| 2 | `BibleAITheme.swift` | Color/spacing/typography tokens; accent resolution; `Font`/`Color` extensions. | 1 | P1 |
| 3 | `AppRouter` | `@Observable` router: tabs, per-tab `Route` paths, global `Sheet` enum. | 1 | P1 |
| 4 | `MainTabView` | `TabView` + per-tab `NavigationStack` wired to `AppRouter`. | 3 | P1 |
| 5 | SwiftData setup | `Creation`, `AppSettings`, `VerseRef`, `SchemaV1`, empty `AppMigrationPlan`, `ModelContainer` at root. | 1 | P1 |
| 6 | `MediaStore` | Owns `Artifacts/`; relative-path read/write/delete. | 5 | P2 |
| 7 | `AIAvailability` | `@Observable` oracle: AFM availability, model presence, reachability; `refresh()`. | 5 | P2 |
| 8 | `KeychainStore` | Keychain CRUD for OpenRouter/Anthropic keys. | 1 | P2 |
| 9a | `APIClient` | Shared URLSession client; `URLProtocol`-mockable; status validation. | 1 | P2 |
| 9b | `ModelLocator` | Resolve model ID → Core ML resource URL (`.mlpackage` / `.mlmodelc`) under `Models/`; report presence. | 5 | P2 |
| 10 | `YouVersionService` | OAuth + guest; verse lookup + verse-of-day; returns `Sendable` `VerseRef`. | 9a | P2 |
| 11 | `ModelDownloadManager` | Resumable, backgroundable downloads into `Models/`; progress; HF-gated support. | 9a, 9b | P2 |
| 12 | `CoreMLImageGenerator` (SD) | `ImageGenerating` actor (Core ML / `swift-coreml-diffusers`) for SD 1.5/2.1/3.5; streams step progress. | 0', 6, 9b | P3 |
| 13 | FLUX.2 Core ML export spike + generator | Spike: can FLUX.2 Klein 4B export to `.mlpackage` via `coremltools` and fit the on-device memory ceiling? If yes, add a generator; if no, FLUX-class stays cloud-only. | 0', 12 | P3 |
| 14 | `FoundationModelsTextGenerator` | `TextGenerating` actor over AFM; availability gate + refusal handling. | 7 | P3 |
| ~~15~~ | ~~`CoreAITextGenerator` (Qwen3)~~ | **Removed — no on-device custom-LLM framework in iOS 27 SDK (§6.7). Qwen3 text falls through to cloud.** | — | — |
| 16 | `OpenRouterTextGenerator` | `TextGenerating` actor via `APIClient`; consent + key + reachability gated. | 9a, 8 | P3 |
| 17 | `AnthropicTextGenerator` | `TextGenerating` actor via `APIClient`; consent + key + reachability gated. | 9a, 8 | P3 |
| 18 | `GenerationEngine` | Routing tables (image/text/music/video), serial busy-guard, `AsyncThrowingStream`, `Sendable` results. | 7, 12, 13, 14, 16, 17 | P3 |
| 19 | `WelcomeView` (1A) | Hero loop, "Get started", "RUNS OFFLINE · 100% FREE" badge. | 2, 3 | P4 |
| 20 | `YouVersionSignInView` (1B) | OAuth sheet + "Continue as guest". | 10, 19 | P4 |
| 21 | `EngineSetupView` (1C) | On-device pre-selected (FREE), cloud toggle, first-model download progress. | 11, 20 | P4 |
| 22 | `HomeView` (2B) | Verse-of-day hero shell, quick-create seeding, "Your library →". | 4, 10 | P4 |
| 23 | `DailyVerseHeroCard` | Hero card: cached generated art + verse + reference + 3 quick-create buttons. | 18, 22 | P4 |
| 24 | `CreateView` stepper (3A) | 4-step progress (VERSE→FORMAT→MODELS→STYLE) + Generate; owns `CreateViewModel`. | 4, 18 | P4 |
| 25 | `VersePickerView` | Search/browse, translation selector (public-domain default). | 10, 24 | P4 |
| 26 | `FormatStyleStep` | Format toggle (Image/Slides/Video) + style prompt editor (AFM-or-cloud prefill). | 14, 24 | P4 |
| 27 | `ModelPickerSheet` (4A) | Text/Image/Music/Video tabs; on-device starred FREE, cloud labeled; link to registry. | 7, 24 | P4 |
| 28 | `LiveCanvasView` | Live preview surface during STYLE step. | 24 | P4 |
| 29 | `GenerationProgressView` | Consumes engine stream; determinate step/download progress; non-blocking. | 18, 24 | P4 |
| 30 | `ArtifactPreviewView` (5A) | Carousel + play; verse + model attribution. | 6, 29 | P4 |
| 31 | `SaveActionsView` | "Save in app — private 🔒" (primary), Gallery, Files, Publish… ; writes `Creation`. | 5, 6, 30 | P4 |
| 32 | `SlideshowEditorView` (5B) | Scene strip, +scene, music row (curated/cloud), length picker; re-composite. | 30 | P4 |
| 33 | `CloudConsentSheet` | One-time consent before first cloud call; sets `hasConsentedToCloud`. | 5 | P4 |
| 34 | `PublishDestinationsView` (6A) | "You're in control" banner, multi-select destinations, Continue. | 31, 33 | P4 |
| 35 | `PlatformCropView` (6B) | Per-platform crop/aspect (1:1/4:5/9:16), length slider (≤90s), filter strip. | 34 | P4 |
| 36 | `PublishConfirmView` | Final confirm; share sheet / SDK; mark `Creation` published. | 35 | P4 |
| 37 | `LibraryView` (7A) | 2×2 grid, filter chips, 🔒/PUBLISHED badges; `#Predicate` over denormalized fields. | 5, 6 | P4 |
| 38 | `ArtifactDetailView` (7B) | Full preview, metadata, Gallery/Publish/Delete, privacy toggle. | 37 | P4 |
| 39 | `ModelRegistryView` (4B) | Search + source chips, download state, storage meter; delete/manage. | 11, 27 | P4 |
| 40 | `SettingsView` | Connections, "100% free" callout, defaults, storage meter (Manage→registry). | 4, 8, 39 | P4 |
| 41 | `APIKeyEntryView` | Enter/validate OpenRouter/Anthropic keys → Keychain. | 8, 40 | P4 |
| 42 | AFM-unavailable banner | Resilience banner + templated-prompt fallback when AFM `.unavailable`. | 7, 24 | P5 |
| 43 | Offline banner | Reachability-driven banner; cloud actions disabled offline. | 7, 24 | P5 |
| 44 | Key-missing sheet | Recovery sheet when a cloud call lacks a valid key. | 33, 41 | P5 |
| 45 | Haptics | Generation start/finish, save, publish haptics. | 29, 31 | P5 |
| 46 | Accessibility audit | Dynamic Type, VoiceOver labels, contrast on all accents. | 19–41 | P5 |
| 47 | App icon | Final icon + marketing asset. | 2 | P5 |
| 48 | Unit: `GenerationEngine` | Routing tables, busy-guard, fallback ordering, `Sendable` boundaries. | 18 | P6 |
| 49 | Unit: `MediaStore` | Relative-path round-trip; reinstall (container UUID) robustness. | 6 | P6 |
| 50 | Unit: `AIAvailability` | All AFM `.unavailable` reasons, model-presence, reachability transitions. | 7 | P6 |
| 51 | UI: create→save golden path | Verse→format→models→style→Generate→Save in app end-to-end. | 24–31 | P6 |
| 52 | Integration: Core ML pipeline | Real `.mlpackage` load + inference produces a persisted artifact. | 12, 13 | P6 |
| 53 | Perf benchmarks | Image inference ≤15s; SD-tier comparison; memory ceiling on target hardware. | 12, 13 | P6 |
| 54 | Privacy manifest | `PrivacyInfo.xcprivacy`: no tracking; document Keychain + user-key cloud egress. | 40 | P7 |
| 55 | App Store metadata | Listing, screenshots, "100% free / runs offline" copy; review notes on YouVersion + keys. | 46, 47, 54 | P7 |
