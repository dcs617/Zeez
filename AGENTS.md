# Repository Guidelines

## Project Structure & Module Organization

`Zeez/` contains the iOS SwiftUI application. Organize changes by feature: `Alarm/`, `Sleep/`, `Learn/`, `Onboarding/`, `Environment/`, `DataImport/`, `Watch/`, and `Views/` for UI grouped by screen area. Cross-cutting code belongs in `App/`, `Infrastructure/`, `Utilities/`, `CoreData/`, `Commerce/`, `Development/`, or `Widgets/`. Shared phone/watch models live in `Shared/`; the companion target is in `ZeezWatch Watch App/`. Unit tests are in `ZeezTests/`, UI tests in `ZeezUITests/`, with corresponding watch test targets alongside them.

## Build, Test, and Development Commands

Use Xcode or `xcodebuild` with an installed simulator:

```bash
xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ZeezTests/AlarmEndToEndTests
xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

The first command compiles the iOS app; the second runs its test plan; the third targets one regression suite; the fourth verifies the watch companion.

## Coding Style & Naming Conventions

Follow existing Swift style: four-space indentation, `UpperCamelCase` types, `lowerCamelCase` properties/functions, and one primary SwiftUI view or service per file. Keep feature code in its owning directory and extend existing managers rather than duplicating orchestration. Use `ZeezLogger` categories instead of `print`. Add accessibility labels and hints for interactive SwiftUI controls and accessible values for charts.

## Testing Guidelines

Logic tests use Swift Testing (`import Testing`, `@Test`, `#expect`) in `ZeezTests/`; UI tests use XCTest and `XCUIApplication` in `ZeezUITests/`. Name focused regression suites after behavior, such as `AlarmReliabilityTests.swift` or `CoreDataMigrationTests.swift`. Add tests for alarm scheduling, persistence migrations, and analysis changes; run the focused suite during development and the full scheme before review.

## Commit & Pull Request Guidelines

History is limited and uses concise milestone-style subjects, for example `v0.3` and `Comprehensive Error Resolution & Architecture Enhancement`; use a short imperative subject describing the delivered change. Pull requests should explain behavior changes, identify affected targets, list test commands run, link relevant issues or plans, and include screenshots for UI changes on iPhone or watchOS.
