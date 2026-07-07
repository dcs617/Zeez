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
```

The `Zeez` scheme is a shared scheme (`Zeez.xcodeproj/xcshareddata/xcschemes/Zeez.xcscheme`). Its launch action is wired to the local StoreKit configuration `ZeezTests/Zeez.storekit` (product IDs must match App Store Connect exactly), and its test action includes both ZeezTests and ZeezUITests — CI (`.github/workflows/tests.yml`) runs `-only-testing:ZeezTests`.

## Core Architecture

### App Entry Flow
`App/ZeezApp.swift` → `Views/RootView.swift` → `Views/MainView.swift` (TabView: Sleep/Alarm/Learn)

`RootView` checks `OnboardingManager.shared.hasCompletedOnboarding` to decide between `OnboardingView` and `MainView`. It also uses `ModalCoordinator.shared` (`Shared/ModalCoordinator.swift`) to present sheets globally (data import, settings, etc.).

At startup, `ZeezApp.setupApp()` runs `AlarmDataMigrationHelper` and starts `AlarmObserver.shared`.

### Data Layer
- **Core Data stack**: `PersistenceController.shared` — use `.container.viewContext` for UI, `newBackgroundContext()` for heavy work. Migration is automatic via `CoreDataMigrationManager`.
- **Model versioning**: the model is versioned; `Zeez 2.xcdatamodel` is current (check `Zeez.xcdatamodeld/.xccurrentversion`). Structural changes require a new model version — default-value-only changes don't alter version hashes, so old stores stay compatible.
- **Primary entity**: `SleepSession` — links to `SleepStage`, `HeartRateData`, `MovementData`, `EnvironmentalReading`, `SleepQualityScore`.
- **Generated classes**: All Core Data entity classes live in `CoreData/` (paired `+CoreDataClass.swift` / `+CoreDataProperties.swift`).

### Sleep Analysis Pipeline
`SleepAnalyzer.shared.analyzeSleepSession(_:)` orchestrates analysis in four steps:
1. Inline validation in `SleepAnalyzer` — checks the session has valid times and minimum data
2. `SleepStageAnalyzer` (`Sleep/Stage/`) — detects stages from movement + heart rate
3. `SleepQualityCalculator` (`Sleep/Quality/`) — scores duration, efficiency, stage distribution, fragmentation, latency (research-based weights)
4. Updates session with results in a background context

**`QualityMetrics`** (from `SleepQualityCalculator`) is the primary quality model. The overall score is a weighted composite: efficiency 30%, duration 25%, stage distribution 25%, fragmentation 15%, latency 5%.

### Directory Layout
```
Zeez/
├── App/             # Entry point: ZeezApp, ApplicationDelegate, SceneDelegate, AppConstants
├── Infrastructure/  # ZeezLogger, ErrorManager, BackgroundTaskManager, AnalyticsManager, ResourceMonitor
├── Utilities/       # Extensions and helpers: Array+Statistics, DateHelper, FormatterUtils, CollectionExtensions
├── Commerce/        # PremiumFeatures, PremiumFeatureGating, StoreKitManager, SubscriptionEvents
├── DataImport/      # HealthKitDataImporter, PillowDataImporter, RealDataManager
├── CoreData/        # Core Data entity class files (paired +CoreDataClass / +CoreDataProperties)
├── Shared/          # ModalCoordinator and other cross-cutting components
├── Watch/           # WatchConnectivityHandler, EnhancedWatchConnectivityHandler, WatchCommunicationSupport
├── Widgets/         # Widget, WidgetContainer
├── Development/     # DeveloperSettings
│   └── Mocks/       # MockDataGenerator, MockSleepPatternGenerator
├── Sleep/           # Sleep analysis and views
│   ├── Cycle/       # Cycle chart and info views (visualization only)
│   ├── Debt/        # SleepDebtMetrics
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
- `RealDataManager.shared` (`DataImport/`) — coordinates HealthKit and Pillow data import
- `ErrorManager.shared` — centralized error tracking
- `AnalyticsManager.shared` — analytics events
- `ModalCoordinator.shared` — global sheet presentation from `RootView`

### Premium Features
`Commerce/PremiumFeatures.swift` defines `PremiumFeature` enum. `PremiumFeatureGating` checks entitlements. `StoreKitManager` manages subscription products and `purchasedSubscriptions`.

### Data Import
Users import via Settings > Sleep Data > Import Sleep Data (`Views/SimpleDataImportView.swift`). `DataImport/HealthKitDataImporter` and `DataImport/PillowDataImporter` map to Core Data, coordinated by `DataImport/RealDataManager`. Mock data generation is manually triggered via the debug menu in DEBUG builds — it is **not** generated automatically at launch.

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
Uses Swift Testing framework (`import Testing`, `@testable import Zeez`). Test suites: `AlarmEndToEndTests`, `AlarmRaceConditionTests`, `AlarmReliabilityTests`, `AlarmPredicateSQLiteTests`, `AlarmFollowUpChainTests`, `NotificationBudgetTests`, `CoreDataMigrationTests`, `CoreDataModelV2MigrationTests`, `CoreDataModelTests`, `MockDataTests`. Alarm-scheduler tests inject a fake center via the `AlarmNotificationScheduling` protocol instead of using the real `UNUserNotificationCenter` (see `AlarmFollowUpChainTests` for the pattern).

### Logging
Use `ZeezLogger` (`Infrastructure/ZeezLogger.swift`) — never `print`. Import `os.log`. Categories: `ZeezLogger.coreData`, `.sleepTracking`, `.alarm`, `.learning`, `.ui`, `.environment`, `.background`, `.analytics`, `.network`, `.mockData`, `.error`, `.app`. Debug logs are stripped from release builds.

### Accessibility
All interactive elements must have `accessibilityLabel` and `accessibilityHint`. Complex components use `accessibilityElement(children: .combine)`. Data visualizations expose values via `accessibilityValue`.
