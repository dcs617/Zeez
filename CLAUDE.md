# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zeez is an iOS sleep tracking and analysis application built with SwiftUI and Core Data. The app provides sleep monitoring, educational content, and alarm management, plus a companion watchOS app.

## Development Commands

```bash
# NOTE: xcode-select on this machine points at CommandLineTools — prefix commands with
# DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Build iOS target
xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run all tests
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run a specific test suite
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ZeezTests/AlarmEndToEndTests

# Build watch app
xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Build watch app the way CI does (no simulator model name to drift)
xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'generic/platform=watchOS Simulator' build

# UI smoke tests (Debug only — the launch-argument overrides are #if DEBUG)
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ZeezUITests/MainViewUITests -only-testing:ZeezUITests/OnboardingUITests
```

Never run two `xcodebuild` invocations concurrently. To recover which tests failed from a finished run:
`xcrun xcresulttool get test-results tests --path <…/Logs/Test/*.xcresult>` — grepping xcodebuild output loses them.

Both the `Zeez` and `ZeezWatch Watch App` schemes are shared (`Zeez.xcodeproj/xcshareddata/xcschemes/`) — CI cannot build a scheme that is not. The `Zeez` scheme's launch action is wired to the local StoreKit configuration `ZeezTests/Zeez.storekit` (product IDs must match App Store Connect exactly), and its test action includes both ZeezTests and ZeezUITests.

CI (`.github/workflows/tests.yml`) has three jobs: `unit-tests` (`-only-testing:ZeezTests`) and `watch-build` on every push/PR, and `ui-smoke` on a nightly schedule plus `workflow_dispatch` only. UI tests never gate a merge — they need a warm booted simulator and fail noisily.

## Core Architecture

### App Entry Flow
`App/ZeezApp.swift` → `Views/RootView.swift` → `Views/MainView.swift` (TabView: Sleep/Alarm/Learn)

`RootView` checks `OnboardingManager.shared.hasCompletedOnboarding` to decide between `OnboardingView` and `MainView`. It also uses `ModalCoordinator.shared` (`Shared/ModalCoordinator.swift`) to present sheets globally (data import, settings, etc.).

At startup, `ZeezApp.setupApp()` runs `AlarmDataMigrationHelper` and starts `AlarmObserver.shared`.

### Data Layer
- **Core Data stack**: `PersistenceController.shared` — use `.container.viewContext` for UI, `newBackgroundContext()` for heavy work. Migration is automatic via `CoreDataMigrationManager`.
- **Store location**: the store lives in the **App Group** container (`group.com.danielsparano.zeez`), not the app container, so a future WidgetKit extension can read it. `CoreData/StoreLocation.swift` owns the identifier, the URL, and the one-time relocation of a legacy app-container store; `PersistenceController.adoptAppGroupStore` runs it *before* `configureStoreForMigration()`, which reads `description.url`. Relocation uses `replacePersistentStore` — never `moveItem`, which drops uncheckpointed WAL frames. Every failure path keeps the app-container store. Note that CLI `xcodebuild` signs simulator builds ad-hoc and strips all profile-backed entitlements, so `containerURL(...)` returns `nil` and the group path is only exercised in Xcode/device builds.
- **Model versioning**: the model is versioned; `Zeez 3.xcdatamodel` is current (check `Zeez.xcdatamodeld/.xccurrentversion`). Structural changes require a new model version — default-value-only changes don't alter version hashes, so old stores stay compatible. `PersistenceController.prepareForLoading` backs an out-of-date store up and migrates it with Core Data's automatic lightweight migration; the manual `CoreDataMigrationManager` path is only the fallback. Copy store files with `replacePersistentStore`, never `FileManager` — sidecars are `-wal`/`-shm` suffixes, not path extensions.
- **Primary entity**: `SleepSession` — links to `SleepStage`, `HeartRateData`, `MovementData`, `EnvironmentalReading`, `SleepQualityScore`.
- **Generated classes**: All Core Data entity classes live in `CoreData/` (paired `+CoreDataClass.swift` / `+CoreDataProperties.swift`).

### Sleep Analysis Pipeline
`SleepAnalyzer.shared.analyzeSleepSession(_:)` orchestrates analysis in four steps:
1. Inline validation in `SleepAnalyzer` — checks the session has valid times and minimum data
2. `SleepStageAnalyzer` (`Sleep/Stage/`) — detects stages from movement + heart rate
3. `SleepQualityCalculator` (`Sleep/Quality/`) — scores duration, sleep opportunity, stage distribution, fragmentation, latency
4. Updates session with results in a background context

**`QualityMetrics`** (from `SleepQualityCalculator`) is the primary quality model. The overall score is a weighted composite: sleep opportunity 30%, duration 25%, stage distribution 25%, fragmentation 15%, latency 5%, renormalized over the components that are actually available.

The score is a Tier-3 "Experimental Zeez Estimate" governed by **`ZEEZ_SCORE_SPECIFICATION.md`** (repo root), which is a live contract alongside `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`. Capabilities removed by the audits — and the claims bar each must clear before it can return — are registered in **`PARKED_CAPABILITIES.md`**; consult it before rebuilding a feature that looks missing. Key rules: missing inputs make a component *unavailable* (never a neutral default); `duration` and `stageDistribution` are required, so `calculateMetrics()` returns `nil` without them and `SleepAnalyzer` writes the `qualityScore = 1.0` sentinel; `confidenceScore` is derived from input coverage × sensor breadth. Bump `ZeezScore.version` and update the spec together whenever inputs, weights, bands, or the missing-input policy change.

### Directory Layout
```
Zeez/
├── App/             # Entry point: ZeezApp, ApplicationDelegate, SceneDelegate, AppConstants
├── Infrastructure/  # ZeezLogger, ErrorManager, BackgroundTaskManager, AnalyticsManager, ResourceMonitor
├── Utilities/       # Extensions and helpers: Array+Statistics, DateHelper, FormatterUtils, CollectionExtensions
├── Commerce/        # PremiumFeatures, PremiumFeatureGating, StoreKitManager, SubscriptionEvents
├── DataImport/      # HealthKitDataImporter, RealDataManager
├── CoreData/        # Core Data entity class files (paired +CoreDataClass / +CoreDataProperties)
├── Shared/          # ModalCoordinator and other cross-cutting components
├── Watch/           # WatchConnectivityHandler, WatchCommunicationSupport, WatchSleepSummary+CoreData
├── Development/     # DeveloperSettings
│   └── Mocks/       # MockDataGenerator, MockSleepPatternGenerator
├── Sleep/           # Sleep analysis and views
│   ├── Cycle/       # Cycle chart and info views (visualization only)
│   ├── Quality/     # SleepQualityCalculator, SleepQualityView
│   └── Stage/       # SleepStageAnalyzer, SleepStageTypes, SleepStageView
├── Alarm/           # AlarmScheduler, AlarmObserver, AlarmAudioController, all alarm views
├── Learn/           # Educational content: articles, quizzes, notes, progress tracking
│   ├── Note/        # Note-taking and highlighting
│   ├── Quiz/        # Interactive quizzes
│   └── Sleep/       # Sleep-specific educational content
├── Environment/     # EnvironmentalMonitor, EnvironmentalAnalyzer, views
├── Onboarding/      # OnboardingManager, OnboardingView, OnboardingTypes, OnboardingModifiers
├── Views/           # Screen-level views and shared UI
│   ├── Dashboard/   # DashboardView components (metric cards, session rows, banners)
│   ├── HeartRate/   # HeartRateView components and helpers
│   └── Trends/      # TrendsView components (charts, stats, monthly data)
└── Documentation/   # Internal documentation files
```

### Key Singletons and Managers
- `PersistenceController.shared` — Core Data stack
- `AlarmObserver.shared` — notification and alarm lifecycle management
- `BackgroundTaskManager.shared` — BGTask registration and execution for sleep data processing
- `StoreKitManager.shared` — StoreKit 2 subscription handling (async/await, transaction listener)
- `RealDataManager.shared` (`DataImport/`) — coordinates HealthKit data import
- `ErrorManager.shared` — centralized error tracking
- `AnalyticsManager.shared` — analytics events
- `ModalCoordinator.shared` — global sheet presentation from `RootView`

### Premium Features
`Commerce/PremiumFeatures.swift` defines `PremiumFeature` enum. `PremiumFeatureGating` checks entitlements. `StoreKitManager` manages subscription products and `purchasedSubscriptions`.

### Data Import
Users import via Settings > Sleep Data > Import Sleep Data (`Views/SimpleDataImportView.swift`). `DataImport/HealthKitDataImporter` maps Apple Health data to Core Data, coordinated by `DataImport/RealDataManager`. Re-import is reconciled by HealthKit sample uuid in `DataImport/SleepImportReconciler.swift` (policy in `PARKED_CAPABILITIES.md` §8a): absence is never deletion — only deletions HealthKit reports through the anchored query are applied. Mock data generation is manually triggered via the debug menu in DEBUG builds — it is **not** generated automatically at launch.

### watchOS Companion
`ZeezWatch Watch App/` is a separate target. iOS↔watch communication uses `Watch/WatchConnectivityHandler.swift` on the iOS side, mirrored by `WatchConnectivityManager.swift` on the watch side. Message/model types (`WatchSleepSummary`, `WatchAlarmStatus`, `WatchMessageType`, `HapticPattern`, `WakePatternData`) are defined once in the repo-root `Shared/` folder, which is a synchronized group compiled into **both** app targets — keep that folder free of Core Data and platform-specific imports (iOS-only bridges go in `Zeez/Watch/`).

## Development Guidelines

### Core Data
- UI reads: `PersistenceController.shared.container.viewContext` with `@FetchRequest`
- Heavy writes: `newBackgroundContext()`, always save and merge back
- Previews: `PersistenceController.preview`
- **EnvironmentalReading**: numeric attributes use the sentinel `EnvironmentalReading.notMeasured` (-1) for metrics the hardware can't measure — always read via the `measured*` optional accessors (`Environment/EnvironmentalReading+Measured.swift`), never the raw attributes, or absent sensors read as freezing/pitch-dark rooms.
- **Threading**: never touch a managed object or context off its queue. The alarm stack uses the snapshot pattern — `AlarmSnapshot` (`Zeez/Alarm/AlarmSnapshot.swift`) is built inside `context.perform` and only plain values cross onto dispatch queues or `UNUserNotificationCenter` callbacks. Verify threading changes by launching with `-com.apple.CoreData.ConcurrencyDebug 1`.

### Testing
Uses Swift Testing (`import Testing`, `@testable import Zeez`); `ZeezUITests` is XCTest. ~36 suites live in `ZeezTests/` — read the directory rather than trusting a list here. Established patterns:

- **Fakes**: a product-side protocol with a `= .shared` / `= .current()` default parameter, faked by a lock-guarded `@unchecked Sendable` double. `AlarmNotificationScheduling` + `FakeNotificationCenter` (`ZeezTests/AlarmTestSupport.swift`) is the reference; see `AlarmFollowUpChainTests`. Never use the real `UNUserNotificationCenter`.
- **Polling**: `AlarmTestSupport.waitUntil` — never fixed sleeps.
- **Core Data**: in-memory `PersistenceController(inMemory:)`, backed by SQLite at `/dev/null`, so SQL semantics apply (NULLs sort last in a descending order).
- **Fixtures**: `SleepSessionValidator` needs `EnvironmentalReading` timestamps covering ≥80% of a session, so any test that ends a session must seed readings or it throws `.incompleteSensorData`.
- **Guard suites**: source-scanning tests (`HeartRateClaimsGuardTests`, `ClinicalVocabularyGuardTests`, `SessionMonitorLifecycleGuardTests`) locate sources via `#filePath` so they work in CI. Use them to pin an invariant a refactor establishes.
- **A regression test that passes against the unfixed code pins nothing** — temporarily revert the fix and confirm the test fails before trusting it.
- **UI tests** read `#if DEBUG` launch arguments: `-uiTestCompletedOnboarding` / `-uiTestResetOnboarding` (`OnboardingManager`) and `-uiTestResetStore` (`ZeezApp.init`, clears the store before `RootView` exists). A Release UI-test run hangs on onboarding.
- `StoreKitTests`' four `SKTestSession` tests flake under simulator contention when a live app instance is present. If they fail, uninstall the app from the simulator and re-run before investigating.

### Logging
Use `ZeezLogger` (`Infrastructure/ZeezLogger.swift`) — never `print`. Import `os.log`. Categories: `ZeezLogger.coreData`, `.sleepTracking`, `.alarm`, `.learning`, `.ui`, `.environment`, `.background`, `.analytics`, `.network`, `.mockData`, `.error`, `.app`. Debug logs are stripped from release builds.

### Accessibility
All interactive elements must have `accessibilityLabel` and `accessibilityHint`. Complex components use `accessibilityElement(children: .combine)`. Data visualizations expose values via `accessibilityValue`.
