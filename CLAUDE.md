# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zeez is an iOS sleep tracking and analysis application built with SwiftUI and Core Data. The app provides comprehensive sleep monitoring, educational content, alarm management, and includes a companion watchOS app.

### Key Architecture Components

- **SwiftUI + Core Data**: Modern iOS app using declarative UI with persistent data storage
- **Multi-target project**: Main iOS app + watchOS companion app + test targets
- **Modular organization**: Feature-based directory structure with clear separation of concerns

## Development Commands

### Building and Testing
```bash
# Build the main iOS target
xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run tests using Swift Testing framework
xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build watch app
xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

### Development Workflow
- The app automatically generates 90 days of mock data in DEBUG builds when no valid sleep sessions exist
- Use the debug menu (available in DEBUG builds) to generate test data or clear existing data
- Core Data migration is handled automatically

## Core Architecture

### Data Layer
- **Core Data Stack**: Managed by `PersistenceController` singleton with automatic migration
- **Primary Entity**: `SleepSession` - central entity containing sleep tracking data
- **Key Relationships**: Sessions link to sleep stages, heart rate data, movement data, environmental readings, and quality scores
- **Mock Data**: `MockDataGenerator` creates realistic test data with person-specific metrics

### App Structure
- **Entry Point**: `ZeezApp.swift` → `RootView.swift` → `MainView.swift` (TabView)
- **Main Tabs**: Dashboard (Sleep), Alarm, Learn
- **Navigation**: Uses NavigationView with stack style, supports deep linking to detail views

### Feature Organization
```
Zeez/
├── Views/           # Main UI views and shared components
├── Sleep/           # Sleep tracking, analysis, and quality components
│   ├── Cycle/       # Sleep cycle analysis and visualization
│   ├── Debt/        # Sleep debt calculation and education  
│   ├── Quality/     # Sleep quality scoring and analysis
│   └── Stage/       # Sleep stage detection and visualization
├── Learn/           # Educational content system
│   ├── Note/        # Note-taking and highlighting system
│   ├── Quiz/        # Interactive quizzes and progress tracking
│   └── Sleep/       # Sleep education specific content
├── Environment/     # Environmental monitoring and analysis
├── Alarm/           # Smart alarm and wake-up features
├── Onboarding/      # User onboarding flow
└── CoreData/        # Core Data model classes
```

### Key Systems

**Sleep Analysis Pipeline**:
1. `SleepAnalyzer` - Orchestrates analysis of sleep sessions
2. Data collection from multiple sources (movement, heart rate, environmental)
3. Quality scoring using weighted component analysis
4. Sleep stage detection and cycle analysis

**Mock Data System**:
- Generates realistic sleep patterns with person-specific baselines
- Creates coherent time series data for heart rate, movement, environmental factors
- Maintains realistic sleep stage progressions and quality variations

**Learning System**:
- Comprehensive educational content with articles, quizzes, and interactive elements
- Progress tracking and achievement system
- Note-taking with highlighting and cross-referencing

## Development Guidelines

### Core Data Usage
- Always use `PersistenceController.shared.container.viewContext` for UI operations
- Use background contexts for heavy data operations via `newBackgroundContext()`
- Ensure proper save operations after data modifications
- Leverage automatic Core Data migration for schema changes

### SwiftUI Patterns
- Use `@FetchRequest` for Core Data integration in views
- Implement proper preview contexts using `PersistenceController.preview`
- Follow MVVM patterns with `@StateObject` and `@ObservedObject`
- Use NavigationLink for view transitions and maintain proper navigation hierarchy

### Testing Strategy  
- Uses Swift Testing framework (not XCTest)
- Test files use `@testable import Zeez`
- Mock data generation supports consistent testing scenarios

### Feature Development
- Add new features following the existing modular structure
- Create feature-specific directories under appropriate parent folders
- Ensure Core Data entities have proper relationships and indexes
- Use the debug menu for testing new features with generated data

### Logging Guidelines
- Use `ZeezLogger` for all logging instead of print statements
- Import `os.log` in files that use logging
- Choose appropriate logger categories:
  - `ZeezLogger.coreData` - Core Data operations
  - `ZeezLogger.sleepTracking` - Sleep analysis and tracking
  - `ZeezLogger.learning` - Educational content system
  - `ZeezLogger.alarm` - Alarm and wake-up features
  - `ZeezLogger.ui` - User interface operations
  - `ZeezLogger.error` - Error tracking and reporting
- Use appropriate log levels: `.debug()`, `.info()`, `.error()`, `.fault()`
- Debug logs are automatically excluded from release builds

### Code Organization
- Keep view files focused on UI presentation
- Extract business logic into dedicated analyzer/manager classes
- Use extensions to organize code by functionality
- Follow Swift naming conventions and use meaningful file names

## File Organization Notes

### Recent Restructuring
The codebase has undergone significant reorganization with many files moved to feature-based directories:
- Many former root-level files now organized under `Views/`, `Sleep/`, `Learn/`, `Environment/`, `Alarm/`, and `Onboarding/`
- Sleep-related functionality divided into specialized subdirectories: `Cycle/`, `Debt/`, `Quality/`, and `Stage/`
- Learning system organized with `Note/`, `Quiz/`, and `Sleep/` subdirectories
- Shared components and utilities grouped in `Shared/` directory

### Key Entry Points
- **Main App**: `ZeezApp.swift` → `RootView.swift` → `MainView.swift`
- **Core Data**: `PersistenceController.swift` with model in `Zeez.xcdatamodeld/`
- **Mock Data**: `MockDataGenerator.swift` for realistic test data generation
- **Logging**: `ZeezLogger.swift` provides structured logging throughout the app

## Accessibility Implementation

### Current Status
- **Coverage**: 95.5% of view files (84/88) have comprehensive accessibility support
- **Implementation**: 1000+ accessibility modifiers across the entire app
- **Testing**: Validated with VoiceOver, Dynamic Type, high contrast, and reduced motion

### Accessibility Patterns
- All interactive elements have descriptive `accessibilityLabel` and `accessibilityHint`
- Complex UI components use `accessibilityElement(children: .combine)` for logical grouping
- Data visualizations include `accessibilityValue` for meaningful announcements
- Premium features and buttons have clear accessibility feedback
- Chart data is presented in accessible text formats alongside visualizations

### Testing Accessibility
```bash
# Enable VoiceOver in iOS Settings > Accessibility > VoiceOver
# Test key navigation flows:
# 1. Dashboard - sleep metrics and navigation
# 2. Alarm creation and management
# 3. Learn module - articles, quizzes, notes
# 4. Settings and preferences

# Test accessibility settings:
# - Dynamic Type (up to 80% works well, 100% may have layout issues)
# - High contrast mode
# - Reduced motion
```

### Future Accessibility Development
- Follow established patterns when adding new views
- Test with VoiceOver enabled during development
- Ensure all new interactive elements have proper accessibility labels
- Use accessibility identifiers for UI testing: `accessibilityIdentifier("unique-id")`