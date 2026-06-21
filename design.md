# Bible AI — iOS App Design Document

> Source: [Bible AI Wireframes](https://claude.ai/design/p/c1bfe3de-040f-41f9-81f8-52e5bae0f363?file=Bible+AI+Wireframes.dc.html)
> Platform: iOS 27 beta · Swift · SwiftUI · Core AI

---

## 1. Product Overview

Bible AI is an iOS app that turns any Bible verse into AI-generated art, slideshows, and short-form video. It is **on-device-first**: generation runs locally via Core AI and Core ML, works in airplane mode, and nothing leaves the app without an explicit user tap.

### Core principles
- **Private by default** — creations are saved locally; publishing is always an explicit opt-in action
- **Free by default** — on-device models are free; cloud models require the user's own API keys (OpenRouter / Anthropic)
- **Studio energy** — maker-first UX, not a devotional reader
- **YouVersion integration** — verse lookup and social publishing via YouVersion's API

### Accent palette (user-selectable)
| Token | Default | Alt 1 | Alt 2 |
|-------|---------|--------|--------|
| `accent` | `#6C5CE7` (purple) | `#1FA98F` (teal) | `#E0673B` (burnt orange) |

### Typography
| Role | Font | Weight |
|------|------|--------|
| UI body | Nunito Sans | 400 / 600 / 700 / 800 |
| Handwritten / display | Caveat | 600 / 700 |

### Background tones
- Canvas: `#e9e7e2`
- Card surface: `#ffffff`
- Subtle: `#f3f1ec`

---

## 2. Platform & Framework Decisions

| Concern | Choice | Rationale |
|---------|--------|-----------|
| UI framework | **SwiftUI** (declarative, iOS 27) | First-class Apple support; `@Observable` replaces ObservableObject cleanly |
| State / DI | **`@Observable` + `@Environment`** | No third-party dependency; thread-safe; composable |
| Persistence | **SwiftData** | Replaces Core Data; integrates with `@Query` in SwiftUI |
| On-device LLM | **Apple Foundation Models** (`FoundationModels` framework, iOS 26+) | Private, no key, runs on-device; used for verse prompt generation |
| On-device image | **Core ML** + **SD-Turbo** mlpackage | ~1.8 GB; converts via `coremltools` from HuggingFace |
| On-device music | **Core ML** + **MusicGen-small** mlpackage | ~1.2 GB |
| On-device video | **Core ML** + **AnimateDiff-lite** mlpackage | ~2.4 GB |
| Cloud fallback | **OpenRouter API** (Llama-3 free, FLUX) | User supplies key; zero cost to developer |
| Premium cloud | **Anthropic API** (Claude Sonnet/Opus) | User supplies key; Apple Foundation Models for cheaper tasks |
| Navigation | **`NavigationStack` + `TabView`** | Compositional; deep-link friendly |
| Async | **Swift Concurrency** (`async/await`, `AsyncStream`) | Generation progress via `AsyncStream<GenerationProgress>` |
| YouVersion | **YouVersion API** (REST/OAuth 2.0) | Verse content, reading plans, social publishing |
| Photo export | **PhotosUI** (`PHPhotoLibrary`) | Save to Camera Roll |
| Social export | **ShareLink** + platform share sheets | Instagram, TikTok, Facebook, LinkedIn |

---

## 3. Project Structure

```
BibleAI/
├── BibleAIApp.swift               # @main, SwiftData container setup
├── RootView.swift                 # Authentication gate → MainTabView
│
├── DesignSystem/
│   ├── BibleAITheme.swift         # Color tokens, typography, spacing
│   ├── Components/
│   │   ├── PillBadge.swift        # ON-DEVICE · FREE / CLOUD badge
│   │   ├── MediaPlaceholder.swift # Hatched placeholder for media areas
│   │   ├── AccentButton.swift     # Full-width primary CTA
│   │   └── PhoneFrame.swift       # (dev-only) wireframe phone shell
│   └── Modifiers/
│       └── CardStyle.swift        # Rounded card with border
│
├── Models/                        # Pure value types + SwiftData models
│   ├── Verse.swift
│   ├── Creation.swift             # @Model — persisted
│   ├── GenerationJob.swift
│   ├── AIModel.swift
│   ├── SocialPlatform.swift
│   └── AppSettings.swift          # @Model — persisted user prefs
│
├── Services/
│   ├── YouVersionService.swift    # OAuth, verse search, reading plans
│   ├── GenerationEngine.swift     # Routes to on-device or cloud
│   ├── OnDeviceGenerator.swift    # Core ML orchestration
│   ├── CloudGenerator.swift       # OpenRouter / Anthropic REST
│   ├── ModelRegistry.swift        # Install / delete / list AI models
│   └── PublishService.swift       # ShareLink + platform OAuth
│
├── ViewModels/                    # @Observable — one per major feature
│   ├── AuthViewModel.swift
│   ├── HomeViewModel.swift
│   ├── CreateViewModel.swift
│   ├── ModelPickerViewModel.swift
│   ├── PreviewViewModel.swift
│   ├── LibraryViewModel.swift
│   └── SettingsViewModel.swift
│
└── Views/
    ├── Onboarding/
    │   ├── OnboardingFlowView.swift      # Coordinator for 1A→1B→1C
    │   ├── WelcomeView.swift             # 1A
    │   ├── YouVersionSignInView.swift    # 1B
    │   └── EngineChooserView.swift       # 1C — engine select + download
    │
    ├── Main/
    │   └── MainTabView.swift             # TabView: Home / Create / Library / Settings
    │
    ├── Home/
    │   └── HomeView.swift                # 2A — activity feed + FAB (chosen direction)
    │
    ├── Create/
    │   ├── CreateStepperView.swift       # 3A — guided 4-step flow (chosen direction)
    │   ├── steps/
    │   │   ├── VersePickerStep.swift     # Step 1
    │   │   ├── FormatPickerStep.swift    # Step 2
    │   │   ├── ModelPickerStep.swift     # Step 3
    │   │   └── StyleStep.swift           # Step 4
    │   └── LiveCanvasView.swift          # Shared live preview canvas
    │
    ├── Models/
    │   ├── ModelPickerSheet.swift        # 4A — per-generation model chooser
    │   └── ModelRegistryView.swift       # 4B — browse / download registry
    │
    ├── Preview/
    │   ├── ArtifactPreviewView.swift     # 5A — preview + save actions
    │   └── EditorView.swift             # 5B — slideshow/video editor
    │
    ├── Publish/
    │   ├── PublishDestinationsView.swift # 6A — platform multi-select
    │   └── PlatformCropView.swift        # 6B — crop / aspect / filters
    │
    ├── Library/
    │   ├── LibraryView.swift             # 7A — grid + filter chips
    │   └── ArtifactDetailView.swift      # 7B — detail + actions
    │
    └── Settings/
        └── SettingsView.swift            # 8A — connections, defaults, storage
```

---

## 4. Data Models

### 4.1 Verse
```swift
struct Verse: Identifiable, Hashable, Codable {
    let id: UUID
    let reference: String       // "Philippians 4:13"
    let text: String
    let book: String
    let chapter: Int
    let verseNumber: Int
    let translation: String     // "NIV", "ESV", etc.
    let source: VerseSource     // .youVersion | .local
}
enum VerseSource: String, Codable { case youVersion, local }
```

### 4.2 AIModel
```swift
struct AIModel: Identifiable, Hashable, Codable {
    let id: String                // "sd-turbo", "musicgen-small"
    let name: String
    let capability: ModelCapability
    let source: ModelSource
    let sizeGB: Double
    var isInstalled: Bool
    var downloadProgress: Double?   // 0.0–1.0 while downloading
    let isFree: Bool
    let requiresKey: KeyRequirement // .none | .openRouter | .anthropic
}

enum ModelCapability: String, Codable { case text, image, music, video }
enum ModelSource: String, Codable     { case onDevice, openRouter, anthropic, appleFoundation }
enum KeyRequirement: String, Codable  { case none, openRouter, anthropic }
```

### 4.3 Creation (SwiftData)
```swift
@Model
final class Creation {
    var id: UUID
    var title: String
    var verse: Verse
    var format: CreationFormat
    var prompt: String
    var modelsUsed: [String]          // model ids
    var artifactPath: String          // relative path in app container
    var thumbnailPath: String?
    var privacy: PrivacySetting
    var publishedPlatforms: [String]  // SocialPlatform raw values
    var createdAt: Date
    var generationDurationSeconds: Double
}

enum CreationFormat: String, Codable  { case image, slideshow, video }
enum PrivacySetting: String, Codable  { case `private`, published }
```

### 4.4 GenerationJob
```swift
struct GenerationJob: Identifiable {
    let id: UUID
    var verse: Verse
    var format: CreationFormat
    var prompt: String
    var selectedModels: [AIModel]
    var status: GenerationStatus
}

enum GenerationStatus {
    case queued
    case running(progress: Double, stage: String)
    case complete(Creation)
    case failed(Error)
}
```

### 4.5 AppSettings (SwiftData)
```swift
@Model
final class AppSettings {
    var defaultEngine: EnginePreference     // .onDevice | .cloud
    var defaultFallback: String             // model id
    var accentColorHex: String              // "#6C5CE7"
    var youVersionConnected: Bool
    var openRouterKeyStored: Bool
    var anthropicKeyStored: Bool
    var onboardingCompleted: Bool
}
enum EnginePreference: String, Codable { case onDevice, cloud }
```

### 4.6 SocialPlatform
```swift
enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram, tikTok, facebook, linkedin
    var id: String { rawValue }
    var displayName: String { ... }
    var supportedFormats: [CreationFormat] { ... }
    var supportedAspects: [AspectRatio] { ... }
}
enum AspectRatio: String, CaseIterable { case square, portrait45, portrait916 }
```

---

## 5. Services

### YouVersionService
- OAuth 2.0 PKCE flow; stores token in Keychain
- `searchVerses(query:) async throws -> [Verse]`
- `verseOfDay() async throws -> Verse`
- `publishCreation(_ creation: Creation, to platforms: [SocialPlatform]) async throws`

### GenerationEngine
Single entry point that routes based on `AppSettings.defaultEngine` and model availability:
```swift
func generate(job: GenerationJob) -> AsyncThrowingStream<GenerationStatus, Error>
```
Internally delegates to `OnDeviceGenerator` or `CloudGenerator`.

### OnDeviceGenerator
- Wraps Core ML model inference for each capability
- Uses `FoundationModels` framework for on-device text (Apple Foundation Models)
- Emits progress via `AsyncStream`
- All inference on background `Task` with cooperative cancellation

### ModelRegistry
- Reads `models-manifest.json` bundled in app (list of all available models + download URLs)
- `install(model: AIModel) -> AsyncThrowingStream<Double, Error>` — streams download progress
- `delete(model: AIModel) throws`
- Stores installed model file paths in SwiftData
- Reports storage usage via `FileManager`

### PublishService
- iOS 18+ `ShareLink` for system share sheet
- Platform-specific: Instagram / TikTok via `UIActivityViewController` with their app URL schemes
- LinkedIn / Facebook via their SDKs or web OAuth

---

## 6. Navigation Architecture

```
RootView
└─ if !onboarded → OnboardingFlowView (fullScreenCover)
   ├─ WelcomeView
   ├─ YouVersionSignInView
   └─ EngineChooserView
└─ if onboarded → MainTabView
   ├─ Tab 0 · HomeView
   │   └─ NavigationStack
   │       └─ push: ArtifactDetailView
   ├─ Tab 1 · CreateStepperView (sheet / push from FAB)
   │   ├─ VersePickerStep
   │   ├─ FormatPickerStep
   │   ├─ ModelPickerStep  ←─ sheet: ModelPickerSheet
   │   └─ StyleStep
   │       └─ push: ArtifactPreviewView
   │           ├─ sheet: PublishDestinationsView
   │           │   └─ push: PlatformCropView
   │           └─ sheet: EditorView (for slideshow/video)
   ├─ Tab 2 · LibraryView
   │   └─ NavigationStack
   │       └─ push: ArtifactDetailView
   │           └─ sheet: PublishDestinationsView
   └─ Tab 3 · SettingsView
       └─ NavigationStack
           └─ push: ModelRegistryView
```

All deep-linkable via `bibleai://` URL scheme using `NavigationPath` + `.navigationDestination`.

---

## 7. Screen-by-Screen Specification

### 7.1 Onboarding — WelcomeView (1A)
- Full-screen layout on warm-canvas background
- Logo: `B` in accent-coloured rounded square, Caveat font
- Headline: "Turn a verse into art, video & reels."
- Hero area: looping `VideoPlayer` or animated image placeholder (`MediaPlaceholder`)
- "RUNS OFFLINE · 100% FREE" pill badge
- Single CTA: "Get started" → pushes `YouVersionSignInView`

### 7.2 Onboarding — YouVersionSignInView (1B)
- YouVersion logo placeholder
- "Continue with YouVersion" accent button → initiates OAuth PKCE
- Divider + "Continue as guest" secondary button
- Footnote: "OAuth · verses + social via YouVersion API"

### 7.3 Onboarding — EngineChooserView (1C)
- "How should we generate?" headline
- Two option cards: **On-device (✓ selected by default)** and **Cloud fallback**
- On-device card has accent border and FREE pill
- Live progress bar for starter model download (1.8 GB SD-Turbo)
- "Start creating" CTA (enabled immediately; download continues in background)

### 7.4 HomeView (2A — Activity Feed + FAB)
- Nav bar: "Home" title + "OFFLINE OK" badge
- Resume card: thumbnail + "Continue creating"
- Section: "Recent" — 2-column masonry grid of `Creation` thumbnails
- Floating "＋ Create" pill button (accent) in bottom-right, above tab bar
- Bottom tab bar: Home · ＋ · Library · ⚙

### 7.5 CreateStepperView (3A — Guided Stepper)
This is the primary create flow, reached from the FAB or the Create tab.

**Progress bar** — 4 segments (Verse / Format / Models / Style)

**Step 1 — VersePicker**
- YouVersion verse search (`searchVerses`) or verse-of-day chip
- Tapping a verse sets `CreateViewModel.verse`

**Step 2 — FormatPicker**
- Segmented-style: Image · Slides · Video
- Selecting Video shows a note: "AnimateDiff-lite required"

**Step 3 — ModelPicker (inline)**
- Scrollable row of model chips: each shows name + ON-DEVICE/CLOUD badge
- "Change" → opens `ModelPickerSheet`

**Step 4 — Style**
- Multiline text field: "Describe the vibe…"
- Style presets (Calm / Bold / Film) as visual chips

**Live canvas** — below the steps; updates reactively as user makes choices; rendered by `LiveCanvasView` which runs a fast preview generation (low-res) asynchronously

**"Generate" CTA** → starts `GenerationJob`, navigates to `ArtifactPreviewView`

### 7.6 ModelPickerSheet (4A)
- Bottom sheet (`.presentationDetents([.large])`)
- Segmented tab: Text / Image / Music / Video
- List of `AIModel` rows: name, source, FREE/CLOUD badge, selected state
- "Use selected" accent button

### 7.7 ModelRegistryView (4B)
- Searchable list (`searchable`)
- Source filter chips: Hugging Face · Ollama · Civitai
- Rows: model name, capability, size, Install/Downloading/Installed state
- Download progress via `AsyncThrowingStream<Double, Error>`
- Footer: storage meter (used / total)

### 7.8 ArtifactPreviewView (5A)
- Full-bleed image/video preview with `TabView` pager (multiple variations if generated)
- ↺ Regenerate icon (top-right)
- Metadata footer: "Verse · Model name"
- **Save in app — private** (accent, primary action)
- Save to Gallery / Save to Files (secondary)
- Publish… button (accent outline) → `PublishDestinationsView`

### 7.9 EditorView (5B — Slideshow/Video)
- Preview area (current scene)
- Horizontal scene strip (drag to reorder)
- ＋ Add scene button
- Music row: "Generate" → `MusicGen-small` on-device inference
- Length picker (0:15, 0:30, 0:60)

### 7.10 PublishDestinationsView (6A)
- Info banner: "You're in control. Nothing posts automatically."
- Platform rows with checkbox: Instagram · TikTok · Facebook · LinkedIn
- "Continue" → `PlatformCropView` for each selected platform

### 7.11 PlatformCropView (6B)
- Platform-specific crop frame overlay (9:16 for Reels, 1:1 for Posts, etc.)
- Aspect ratio segmented control
- Length slider with platform guardrails (max 90s for Reels)
- Filter strip (visual thumbnails)
- "Next" → post confirmation or next platform

### 7.12 LibraryView (7A)
- Filter chip row: All · Private · Published · Video
- 2-column `LazyVGrid` of creation thumbnails
- Lock icon overlay for private; PUBLISHED badge for published
- Tap → `ArtifactDetailView`

### 7.13 ArtifactDetailView (7B)
- Large preview
- Metadata card: Verse, Models, Privacy (toggleable: Private → Publish)
- Action row: Gallery · Publish · Delete
- Swipe-to-delete with confirmation

### 7.14 SettingsView (8A)
- **Connections section**
  - YouVersion: "Connected ✓" or Connect button
  - OpenRouter key: masked `sk-••••` with edit arrow
  - Anthropic key: "＋ Add"
  - Info card: "Bible AI is 100% free. Premium models use your own keys."
- **Defaults section**
  - Default engine picker: ON-DEVICE (default) / Cloud
  - Cloud fallback model picker
  - Storage meter with "Manage →" → `ModelRegistryView`

---

## 8. Design System Tokens

```swift
// BibleAITheme.swift
extension Color {
    static let bibleCanvas    = Color(hex: "#e9e7e2")
    static let bibleCard      = Color.white
    static let bibleSubtle    = Color(hex: "#f3f1ec")
    static let bibleMuted     = Color(hex: "#888888")
    static let bibleBorder    = Color(hex: "#e5e5e5")
    // Accent resolved from AppSettings
}

extension Font {
    static let display  = Font.custom("Caveat", size: 34).weight(.bold)
    static let h1       = Font.custom("NunitoSans", size: 23).weight(.heavy)
    static let h2       = Font.custom("NunitoSans", size: 19).weight(.heavy)
    static let body     = Font.custom("NunitoSans", size: 13)
    static let caption  = Font.custom("NunitoSans", size: 10).weight(.bold)
}

// Spacing (8pt grid)
enum Spacing {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 16
    static let l:  CGFloat = 24
    static let xl: CGFloat = 40
}

// Corner radii
enum Radius {
    static let pill:  CGFloat = 999
    static let card:  CGFloat = 14
    static let phone: CGFloat = 40
}
```

---

## 9. Offline & Privacy Architecture

- **All creation data** stored in app sandbox (`FileManager` + SwiftData); iCloud sync opt-in only
- **AI keys** stored in Keychain (never in SwiftData / UserDefaults)
- **Network calls** only occur for: YouVersion verse fetch, OpenRouter/Anthropic cloud generation, social publishing — and only when user explicitly triggers them
- **Background model downloads** use `URLSession` background configuration so they survive app suspension
- **Core AI / FoundationModels** — prompts and outputs stay on-device; subject to Apple's privacy guarantees

---

## 10. Implementation Task Table

| # | Task | Area | Scope | Notes |
|---|------|------|-------|-------|
| 1 | Create Xcode project targeting iOS 27 beta; configure bundle ID `com.bibleai.app`, SwiftUI lifecycle, add SwiftData framework | Project setup | S | Enable FoundationModels and PhotosUI capabilities |
| 2 | Implement `BibleAITheme.swift` — Color tokens, Font extensions, Spacing & Radius enums, `Color(hex:)` helper | Design System | S | All screen-specific colors derive from here; no hardcoded hex elsewhere |
| 3 | Build reusable `PillBadge` component — accent "ON-DEVICE · FREE" variant and muted "CLOUD" variant | Design System | S | Used on model rows, home header, create screen |
| 4 | Build `AccentButton` and `SecondaryButton` components — full-width pill CTA, loading state support | Design System | S | Loading state shows `ProgressView` in-line |
| 5 | Build `MediaPlaceholder` — hatched diagonal pattern fill, accepts label text and aspect ratio | Design System | S | Used wherever generated media is not yet available |
| 6 | Build `CardView` modifier — rounded card with 1.5pt border, shadow, background | Design System | S | `.cardStyle()` ViewModifier |
| 7 | Define all data model value types: `Verse`, `AIModel`, `GenerationJob`, `GenerationStatus`, `SocialPlatform`, `AspectRatio`, `CreationFormat`, `PrivacySetting` | Models | M | Pure Swift structs / enums; Codable where needed |
| 8 | Define SwiftData models: `Creation` and `AppSettings` with all properties and relationships | Models | M | `@Model`, migration plan v1 |
| 9 | Configure `ModelContainer` in `BibleAIApp.swift`; inject into environment; add preview container helper | Models | S | |
| 10 | Implement `YouVersionService` — OAuth 2.0 PKCE flow, token Keychain storage, `searchVerses`, `verseOfDay` | Services | L | Use ASWebAuthenticationSession; stub responses for simulator |
| 11 | Define `GenerationEngine` protocol + `AsyncThrowingStream<GenerationStatus, Error>` interface | Services | S | Interface only; concrete implementations follow |
| 12 | Implement `OnDeviceGenerator` stub — accepts `GenerationJob`, simulates progress stream with 3-second fake generation, returns placeholder image | Services | M | Real Core ML integration in later tasks |
| 13 | Implement `CloudGenerator` — OpenRouter REST client for FLUX image generation and Llama-3 text; reads key from Keychain | Services | L | Handle auth errors, rate limits, streaming where supported |
| 14 | Implement `ModelRegistry` — reads bundled `models-manifest.json`, `install(model:)` with `URLSession` background download, progress `AsyncStream`, `delete(model:)`, storage meter | Services | L | Background URLSession identifier: `com.bibleai.modeldownload` |
| 15 | Create `models-manifest.json` — catalogue SD-Turbo, MusicGen-small, AnimateDiff-lite, Gemma-2 with download URLs, sizes, capabilities | Data | S | Versioned; app checks for manifest updates on launch |
| 16 | Implement `AuthViewModel` — checks `AppSettings.onboardingCompleted`, drives `RootView` gate | ViewModels | S | |
| 17 | Build `OnboardingFlowView` coordinator — manages `WelcomeView` → `YouVersionSignInView` → `EngineChooserView` using `NavigationStack` | Onboarding | M | Sets `AppSettings.onboardingCompleted = true` on finish |
| 18 | Build `WelcomeView` (screen 1A) — logo, headline, hero `MediaPlaceholder`, OFFLINE pill, "Get started" CTA | Onboarding | M | |
| 19 | Build `YouVersionSignInView` (screen 1B) — YouVersion logo placeholder, OAuth CTA, "Continue as guest" secondary | Onboarding | M | Calls `YouVersionService.authenticate()` |
| 20 | Build `EngineChooserView` (screen 1C) — engine option cards, model download progress bar, "Start creating" CTA | Onboarding | M | Triggers `ModelRegistry.install(sdTurbo)` in background |
| 21 | Build `MainTabView` — 4-tab `TabView` (Home, Create, Library, Settings) with system icons; accent active tab color | Navigation | S | Create tab triggers sheet presentation of `CreateStepperView` |
| 22 | Build `HomeView` (screen 2A) — "Home" nav title + OFFLINE OK badge, "Continue creating" resume card, "Recent" section header, 2-column `LazyVGrid` of `Creation` thumbnails, "＋ Create" FAB | Home | L | FAB positioned with `.overlay(alignment: .bottomTrailing)` above safe area |
| 23 | Build `HomeViewModel` — `@Query` for recent `Creation` items (last 10, sorted by date), last-active job resume state | Home | M | |
| 24 | Build `CreateViewModel` — step state machine (`currentStep: Int`), holds `verse`, `format`, `selectedModels`, `prompt`, orchestrates job submission | Create | M | `@Observable` |
| 25 | Build `CreateStepperView` shell (screen 3A) — progress bar (4 segments), step container, Next/Back navigation, "Generate" CTA | Create | M | Uses `@Namespace` for animated step transitions |
| 26 | Build `VersePickerStep` — search field bound to `YouVersionService.searchVerses`, results list, verse-of-day chip, selected state with accent highlight | Create | L | Debounced search (300 ms) |
| 27 | Build `FormatPickerStep` — Image / Slides / Video pill segmented control; Video shows model-required note | Create | S | |
| 28 | Build `ModelPickerStep` (inline, within stepper) — horizontal scroll of model chips, "Change" link opens `ModelPickerSheet` | Create | M | |
| 29 | Build `StyleStep` — multiline `TextEditor` for vibe prompt, 3 preset chips (Calm / Bold / Film) that pre-fill prompt | Create | M | |
| 30 | Build `LiveCanvasView` — runs fast low-res preview generation via `OnDeviceGenerator`, displays result in `MediaPlaceholder` sized container; cancels on disappear | Create | L | Debounced: regenerates 1s after last input change |
| 31 | Build `ModelPickerSheet` (screen 4A) — bottom sheet, Text/Image/Music/Video segmented tab, `AIModel` list rows with badge and selection, "Use selected" CTA | Models | L | |
| 32 | Build `ModelPickerViewModel` — loads models from `ModelRegistry`, filters by capability tab, manages selection state | Models | M | |
| 33 | Build `ModelRegistryView` (screen 4B) — search bar, source filter chips, model rows with Install/progress/Installed state, storage footer | Models | L | |
| 34 | Wire `ModelRegistry.install(model:)` into `ModelRegistryView` — progress via `AsyncThrowingStream`, cancel button while downloading | Models | M | |
| 35 | Build `ArtifactPreviewView` (screen 5A) — paged `TabView` of media, ↺ button, metadata footer, "Save in app" primary CTA, Gallery/Files secondary CTAs, "Publish…" outline button | Preview | L | |
| 36 | Implement save-in-app action — write artifact to app container, insert `Creation` into SwiftData, show confirmation toast | Preview | M | |
| 37 | Implement "Save to Gallery" — `PHPhotoLibrary.requestAuthorization`, write image/video asset | Preview | M | |
| 38 | Build `EditorView` (screen 5B) — preview area, draggable scene strip (`.onDrag` / `.onDrop`), ＋ scene button, Music "Generate" row, length picker | Preview | L | Music generation calls `OnDeviceGenerator` with `.music` capability |
| 39 | Build `PublishDestinationsView` (screen 6A) — info banner, platform rows with checkboxes, "Continue" CTA | Publish | M | |
| 40 | Build `PlatformCropView` (screen 6B) — crop overlay for selected aspect, aspect segmented control, length slider with platform max, filter strip, "Next" CTA | Publish | L | Aspect choices per `SocialPlatform.supportedAspects` |
| 41 | Implement platform export — for each selected platform: render final asset at correct aspect/length, invoke `UIActivityViewController` or platform app URL scheme | Publish | L | Instagram: `instagram://library`, TikTok: `tiktok://` |
| 42 | Build `LibraryView` (screen 7A) — filter chip row (`All / Private / Published / Video`), 2-column `LazyVGrid`, lock/published badge overlays | Library | L | `@Query` with `#Predicate` for active filter |
| 43 | Build `ArtifactDetailView` (screen 7B) — large preview, metadata card (Verse, Models, Privacy toggle), Gallery/Publish/Delete action row, swipe-to-delete with confirmation alert | Library | M | |
| 44 | Build `SettingsView` (screen 8A) — Connections section, Defaults section, storage meter, navigation to `ModelRegistryView` | Settings | L | Keychain read/write for API keys via `SecItemAdd` / `SecItemCopyMatching` |
| 45 | Implement Keychain service — `KeychainService.set(key:value:)` / `get(key:)` / `delete(key:)` for OpenRouter and Anthropic keys | Settings | M | No third-party Keychain wrapper; pure `Security` framework |
| 46 | Implement FoundationModels integration — use `LanguageModelSession` to generate verse-based image prompts (Style step); falls back to templated prompt if unavailable | Services | L | Requires iOS 26+ entitlement; gate with `#available(iOS 26, *)` |
| 47 | Implement real Core ML image generation — load SD-Turbo mlpackage, accept prompt + seed, emit progress via `AsyncThrowingStream`, return `CGImage` | Services | XL | Requires mlpackage conversion from HuggingFace checkpoint via coremltools |
| 48 | Implement deep-link routing — `bibleai://create?verse=John+3:16` opens Create flow with verse pre-filled; `bibleai://library/{id}` opens artifact detail | Navigation | M | Register URL scheme in Info.plist; use `onOpenURL` modifier |
| 49 | Add accent color theming — user can select accent in Settings (purple / teal / burnt-orange); persisted in `AppSettings`; propagated via `@Environment` | Design System | M | Use `ThemeEnvironmentKey` |
| 50 | Write SwiftUI previews for all screens using `PreviewProvider` with mock data and `previewModelContainer` | Testing | L | Enables rapid visual iteration without running simulator |
| 51 | Add unit tests for `GenerationEngine` routing logic, `ModelRegistry` state machine, `YouVersionService` response parsing | Testing | M | `XCTest`; mock URLSession with `URLProtocol` |
| 52 | App icon, launch screen, and `Info.plist` entries (camera, photo library, Keychain sharing, URL scheme, background download) | Polish | M | |
