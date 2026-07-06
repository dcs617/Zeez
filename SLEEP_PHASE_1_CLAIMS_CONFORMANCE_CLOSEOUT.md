# Sleep Phase 1 Claims-Conformance Closeout

Date: 2026-05-26  
Status: Complete after claims-conformance fixes in this pass

## Determination

Phase 1, Production Surface And Reachability Audit, is complete. The active
production sleep surfaces were reviewed against
`SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`. Remaining reachable conformance gaps
were limited to experimental-label and stage-context presentation, were
corrected in this pass, and were verified by focused tests and simulator
builds.

`SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md` remains a historical audit. Its
then-open remediation items are confirmed completed in current source and
regression tests: destructive startup mock recovery is removed, imported
parent sessions are saved before related-data attachment, Apple Health stage
semantics preserve unspecified/context values, and unavailable score values are
not rendered as user assessments.

## Documents Read

- `CLAUDE.md`
- `AGENTS.md`
- `SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md`
- `SLEEP_REFACTORING_PLAN.md`
- `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`

## Active Production Surface Inventory

| Surface | Routed Production Behavior | Claims Result |
| --- | --- | --- |
| Onboarding | Explains Apple Health review, optional watch summary, and selected sleep goal | Conforms after experimental-score watch copy update. |
| Root/Main navigation | Routes onboarding, Dashboard, Settings/import, Alarm, and Learn | No production route into mock or unsupported analysis results found. |
| Settings and Apple Health import | Imports Apple Health data and reports data-source/import state | Stage/source policies apply downstream; no new capability activated. |
| Dashboard summary and metrics | Recorded session duration, goal shortfall, heart-rate record summary, experimental estimate, stages | Conforms after experimental score labels/accessibility and neutral score-availability calendar indication. |
| Calendar and weekly progress | Recorded-session-duration context plus score availability | Conforms; no interval is announced as time asleep, and score accessibility is experimental. |
| Recent sessions and session detail | Routes to `EnhancedSleepDetailsView` only | Conforms after experimental score and stage provenance/context labels; weaker duplicate detail paths are not routed. |
| Stage detail/chart | Apple Health-reported or experimental Zeez-estimated stage rendering | Conforms; Apple Core naming is source-aware, `asleepUnspecified` remains explicit, and `inBed` is contextual/not included in asleep composition. |
| Heart-rate detail | Recorded average/minimum/maximum values with no quality/recovery interpretation | Conforms. |
| Goal shortfall | Recorded comparison to the selected sleep goal with explicit non-medical disclosure | Conforms. |
| iPhone-to-watch payload and watch summary | Availability-gated score transport and latest-session rendering | Conforms after watch score presentation became explicitly experimental. |

## Reachability Classifications

| Classification | Relevant Phase 1 Systems |
| --- | --- |
| Active production | `DashboardView`, dashboard components, `CalendarDropdownView`, `WeeklyProgressView`, `RecentSessionsView`, `EnhancedSleepDetailsView`, `SleepQualityView`, `SleepStageView`, `SleepStagesChart`, `HeartRateView`, `SettingsView`, `SimpleDataImportView`, `WatchConnectivityHandler`, watch `SleepSummaryView`, and active onboarding copy. |
| Debug-only | Dashboard `DebugMenuView` and intentional manual mock-data generation controls compiled under `DEBUG`. |
| Educational-only | Active Learn environmental and brain-activity presentations after disclosure changes; educational content in `LearnSleepDebtView` separated from its sourced goal-shortfall summary. |
| Dormant/not currently routed | `SleepDetailView`, `SleepInformationView`, Trends/MonthlyTrends/Trends components, widget presentation, Pillow/DataImport alternatives, sleep position presentation, sleep recommendation output, historical sleep-debt detail/history screens, and watch `WatchSleepSummary.qualityDescription` / `shortSummary` helpers. |
| Retirement candidates | Duplicate dormant detail/information screens; stub or mock-backed `SleepInfoAnalyzer`/`SleepAnalysisTypes`; unsupported recommendation system; unused watch quality-classification helpers; dead legacy analytical blocks retained below the safe educational views. |
| Later experimental/quarantine decision | `SleepStageAnalyzer` and `SleepQualityCalculator`; they still contain heuristic/fallback models but no newly activated trustworthy product claim is based on them. Active display of existing values is explicitly experimental and availability-gated. |

## Claims-Conformance Fixes

- Replaced reachable generic estimated-score terminology with
  `Experimental Zeez Estimate` wording across dashboard, detail, onboarding,
  recent-session/calendar/weekly accessibility, and watch rendering.
- Restricted active score visibility to a persisted Zeez estimate record;
  orphaned numeric values no longer render as results. Intentional mock-score
  rendering remains confined to debug builds.
- Removed the calendar's red/yellow/green score threshold coloration; it now
  indicates only the presence of an available experimental estimate.
- Changed non-Apple stage source presentation to
  `Experimental Zeez-estimated stages`.
- Made routed stage detail explicitly label `inBed` as contextual and
  `asleepUnspecified` as unspecified.
- Retained the existing baseline protections: stage composition excludes
  `inBed` and awake intervals, Apple Health Core/unspecified values remain
  honest, score sentinel values remain unavailable, goal shortfall remains
  non-medical, and the production session-detail route avoids unsupported
  analysis screens.

## Deferred Work

- Phase 2: create one `DerivedSleepMetrics` contract for interval, qualified
  asleep duration, stage composition, awake/efficiency availability,
  provenance, and goal shortfall; remove duplicated active calculations.
- Phase 3: replace start-time-proximity import identity with durable HealthKit
  identity/coverage handling and validate imported source coverage.
- Later phases: keep trends/widgets dormant until routed and audited; specify
  and validate any experimental score; make a go/no-go decision before any
  Zeez-owned stage inference or personalized recommendations reach production.
- Before future watch routing expansion, remove or replace dormant watch score
  quality classifications with the approved experimental-score presentation.

## Verification

Commands executed from the repository root:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination id=EE7AA4EF-C176-4E8E-9CC2-C13AAA56E22C -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath /private/tmp/ZeezSleepReliabilityTestsSerial -only-testing:ZeezTests/SleepAnalysisIdempotencyTests -only-testing:ZeezTests/SleepScorePresentationTests -only-testing:ZeezTests/SleepImportGroupingTests -only-testing:ZeezTests/SleepStageNormalizationTests -only-testing:ZeezTests/SleepDataPreservationTests -only-testing:ZeezTests/SleepDebtTrackingTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' -derivedDataPath /private/tmp/ZeezSleepReliabilityIOSBuildFinal build
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme 'ZeezWatch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=11.1' -derivedDataPath /private/tmp/ZeezSleepReliabilityWatchBuildFinal build
```

Results:

- Focused sleep suites: `** TEST SUCCEEDED **`; 51 tests in 6 suites passed.
- iOS `Zeez` simulator build: `** BUILD SUCCEEDED **`.
- `ZeezWatch Watch App` simulator build: `** BUILD SUCCEEDED **`.
- Non-blocking existing warnings remain, including empty watch Health usage
  description warnings, an unused widget local, a duplicate watch connectivity
  switch pattern, and Core Data entity-disambiguation messages in test logs.

## Explicit Device Deferrals

- Real Apple Health import verification on a physical iPhone.
- Verification of Apple Health stage/related physiological sample coverage on
  actual imported records.
- Paired physical Apple Watch payload synchronization and summary rendering.

These checks remain deferred until Apple Developer account and device access is
restored; they do not block Phase 1 closeout.
