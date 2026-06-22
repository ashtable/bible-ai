# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Pre-implementation. The repo contains a comprehensive design document (`design.md`) and a TDD workflow script (`tdd.md`). No Xcode project exists yet — implementation starts at Task 0 in `design.md §10`.

## TDD Workflow

`tdd.md` defines the multi-agent development loop used in this project. When the user invokes it, follow those steps exactly: identify the next incomplete task from `design.md §10`, build failing tests first, implement to pass, review, and loop.

## Platform & Stack

- **iOS 27 beta · Swift · SwiftUI · SwiftData**
- **On-device generation:** Apple Foundation Models (`FoundationModels` framework), Core ML (SD-Turbo for image, MusicGen-small for audio, AnimateDiff-lite for video)
- **Cloud fallback:** OpenRouter (user's own key) → Anthropic (user's own key)
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
`GenerationEngine` reads `AIAvailability` (on-device LLM status, Core ML model file presence, network reachability) and `AppSettings.defaultEngine` to route each `GenerationJob` to the correct concrete generator. Per-capability protocols (`ImageGenerating`, `TextGenerating`, `MusicGenerating`, `VideoGenerating`) are `Actor`-constrained.

### Concurrency Rules
- Core ML inference and model downloads: never on main actor
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
- **Task 0 is a hard blocker:** Prove SD-Turbo (or equivalent) converts to `.mlpackage` and runs inference in ≤10s on target hardware before building any image-generation UI.
- **Apple Foundation Models availability gate:** Check `SystemLanguageModel.default.availability` — handle `.unavailable(reason:)` cases (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`) with a templated-prompt fallback. Do not gate on `#available`.

## Design Tokens (from `BibleAITheme.swift`)

Colors: canvas `#e9e7e2`, card `#ffffff`, subtle `#f3f1ec`. Accent defaults to `#6C5CE7` (purple), user-selectable to teal `#1FA98F` or burnt orange `#E0673B`. Spacing follows an 8pt grid (xs=4, s=8, m=16, l=24, xl=40).

Fonts: `NunitoSans` for all UI body/headings, `Caveat` for display/handwritten accents.

## Implementation Task Order

See `design.md §10` for the full numbered task table (Tasks 0–52). Task 0 (SD-Turbo spike) blocks all image-generation tasks. Tasks 9a (`AIAvailability`) and 9b (`APIClient`) must precede the services that depend on them. Task 20a (`AppRouter`) must precede `MainTabView` (Task 21).
