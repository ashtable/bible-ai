# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Pre-implementation. The repo contains a comprehensive design document (`design.md`) and a TDD workflow script (`tdd.md`). No Xcode project exists yet — implementation starts at Task 0 in `design.md §10`.

## TDD Workflow

`tdd.md` defines the multi-agent development loop used in this project. When the user invokes it, follow those steps exactly: identify the next incomplete task from `design.md §10`, build failing tests first, implement to pass, review, and loop.

## Platform & Stack

- **iOS 27 beta · Swift · SwiftUI · SwiftData**
- **On-device generation:**
  - Text: Apple **Foundation Models** (`FoundationModels` framework, `SystemLanguageModel.default`) — confirmed present and working in the iOS 27 SDK.
  - Image: **Core ML** (`CoreML` framework) via Apple's `swift-coreml-diffusers` package — SD 1.5/2.1/3.5 M. Models ship as `.mlpackage` files (exported with `coremltools`), downloaded at runtime (never bundled). FLUX.2 Klein 4B on-device is **TBD** pending the Task 0' Core ML export spike.
  - Custom on-device text (Qwen3): **unavailable** — there is no `CoreAILanguageModels` (or any custom-LLM) framework in the iOS 27 SDK. Qwen3 text falls through to cloud.
  - Music and video generation are cloud-only.
- **Cloud fallback:** OpenRouter (user's own key) → Anthropic (user's own key)
- **Task 0 finding (2026-06-22):** `CoreAIDiffusionPipeline` / `CoreAILanguageModels` do **not** exist in the iOS 27 SDK (`CoreAI.framework` is a 9-line stub). Do not reintroduce any `CoreAI*` API or the `.aimodel` format.
- **Navigation:** `NavigationStack` + `TabView` via a single `AppRouter` (`@Observable`) injected into `@Environment`
- **Async:** Swift Concurrency throughout; generation streams via `AsyncThrowingStream<GenerationProgress, Error>`

## Key Architecture Decisions

### State & DI
`@Observable` + `@Environment` — no third-party state management. One `@Observable` ViewModel per major feature screen.

### Data Layer
- SwiftData models: `Creation` and `AppSettings` — defined under `SchemaV1` + empty `AppMigrationPlan`. Every future `@Model` change must add a migration stage; never rename/reorder enum cases on persisted types without one.
- `Creation.verse` is a Codable blob (not queryable). Queryable filter fields (`verseReference`, `verseBook`, `verseTranslation`) are denormalized from it for `#Predicate` use.
- `MediaStore` owns `Application Support/Artifacts/`. All artifact paths stored as **relative** paths — never absolute (container UUID changes on reinstall).

### Generation Routing
`GenerationEngine` reads `AIAvailability` (AFM availability, on-device Core ML model file presence, network reachability) and `AppSettings.defaultEngine` to route each `GenerationJob` to the correct concrete generator. Image routing priority: SD 3.5 M → SD 2.1 → SD 1.5 (Core ML `.mlpackage`) → cloud (FLUX-class is cloud-only until a Core ML export is proven). Text routing priority: AFM → OpenRouter → Anthropic (Qwen3 on-device tiers removed — no custom-LLM framework in the SDK). Per-capability protocols (`ImageGenerating`, `TextGenerating`, `MusicGenerating`, `VideoGenerating`) are `Actor`-constrained.

### Concurrency Rules
- On-device (Core ML) inference and model downloads: never on main actor
- `SwiftData.ModelContext` writes: `@ModelActor`-isolated type
- Generators return `Sendable` value types only; callers insert into `ModelContext` on main actor
- Only one heavy generation at a time (serial busy-guard in `GenerationEngine`)

### Networking
`APIClient` is a shared URLSession-based client used by all network services. It is `URLProtocol`-mockable (no URLSession subclassing). All services share this — no per-service hand-rolled networking.

### Security
API keys (OpenRouter, Anthropic) stored in Keychain only — never SwiftData or UserDefaults. Cloud generation shows a one-time consent sheet before the first network call and routes to on-device if the key is missing or invalid.

## Critical Constraints

- **YouVersion API non-commercial clause** (opened April 2026): access is revoked if the app adds ads, paywalls, or paid tiers. Any monetization must be validated against current YouVersion terms first, or verse sourcing must move to a different provider.
- **Bible translations:** Default to public-domain translations (KJV, WEB, ASV). ESV/NIV are commercially restricted — do not use them for generated art.
- **Task 0 (complete) / Task 0' is the hard blocker:** Task 0 confirmed `CoreAIDiffusionPipeline` is absent from the iOS 27 SDK; on-device image is re-scoped to Core ML (`.mlpackage`). **Task 0':** prove SD 1.5 exports via `coremltools` to `.mlpackage` and runs inference in ≤15s on iOS 27 target hardware before building any image-generation UI.
- **Apple Foundation Models availability gate:** Check `SystemLanguageModel.default.availability` — handle `.unavailable(reason:)` cases (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`) with a templated-prompt fallback. Do not gate on `#available`.

## Design Tokens (from `BibleAITheme.swift`)

Colors: canvas `#e9e7e2`, card `#ffffff`, subtle `#f3f1ec`. Accent defaults to `#6C5CE7` (purple), user-selectable to teal `#1FA98F` or burnt orange `#E0673B`. Spacing follows an 8pt grid (xs=4, s=8, m=16, l=24, xl=40).

Fonts: `NunitoSans` for all UI body/headings, `Caveat` for display/handwritten accents.

## Implementation Task Order

See `design.md §10` for the full numbered task table (Tasks 0–55). Task 0' (Core ML image spike) blocks all image-generation tasks (Task 0, the original Core AI spike, returned a negative result). Tasks 9a (`APIClient`) and 9b (`ModelLocator`) must precede the services that depend on them. Task 7 (`AIAvailability`) must precede all generators. Task 3 (`AppRouter`) must precede Task 4 (`MainTabView`).
