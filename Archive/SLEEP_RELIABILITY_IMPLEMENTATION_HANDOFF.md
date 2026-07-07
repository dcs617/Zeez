# Sleep Reliability Remediation Handoff - Third Audit Pass

Date: 2026-05-26
Status: Audit only. Application source was not edited in this pass.
Verdict: Buildable after targeted fixes; not yet trustworthy enough to ship the sleep output as-is.

## Pipeline Snapshot

The currently reachable real-data input is Apple Health through `SettingsView` -> `SimpleDataImportView` -> `HealthKitDataImporter`. It saves `SleepSession` rows and Apple Health `SleepStage` child rows, starts asynchronous heart-rate and respiratory imports, and leaves imported quality score unavailable. `BackgroundTaskManager` now excludes HealthKit sessions that already have imported stages from Zeez stage inference.

The active iPhone dashboard renders duration, stage/cycle summaries, quality details, calendar/weekly accessibility output, and recent-session detail. The active watch path sends the latest session through `WatchConnectivityHandler` and renders duration and quality. Manual sleep tracking and Pillow import code exist, but no current production navigation into those input surfaces was found. Mock generation is reachable in debug UI.

## Confirmed Completed From Prior Handoff

- The `Dictionary(uniqueKeysWithValues:)` HealthKit duplicate-start crash path was removed; samples are grouped directly.
- HealthKit sessions with imported stages are skipped by `SleepAnalyzer` and excluded from background stage replacement.
- User-triggered stage inference was removed from `EnhancedSleepDetailsView`.
- `LearnSleepDebtView`, `LearnSleepPositionView`, and `PersonalizationSettingsView` no longer present fabricated personal results.
- Stage name normalization is used by the dashboard deep/REM preview.
- `SleepInformationView` labels its interval value as session duration and uses the shared sleep target constant.
- The primary iPhone score card, recent banner, session row, and the currently dormant `TrendsView` filter use `hasDisplayableScore`.
- Regression test sources were added for stage preservation, sentinel score display policy, normalization, mock cleanup, and import grouping.

## Remaining Required Work

### 1. Critical (Debug builds): Startup integrity failure deletes real data

Evidence: `Zeez/App/ZeezApp.swift:56-63`

If a startup Core Data count request throws in a debug build, the app schedules `clearAllData()` and generates mock data. A developer or beta debug build with imported Apple Health data can lose it because of a transient fetch/store error.

Implementation scope:
- Remove automatic destructive recovery from `verifyDataIntegrity()`.
- Log/report the failure non-destructively; mock generation must remain explicitly user-triggered.
- Add a narrow regression test around the extracted recovery policy or equivalent testable helper.

### 2. High: HealthKit related samples can still be silently dropped

Evidence: `Zeez/DataImport/HealthKitDataImporter.swift:177-204`, `:296-325`, `:331-362`

The importer obtains permanent object IDs, but it starts heart-rate and respiratory queries before saving every newly inserted parent session. Only the first row in each five-session batch is saved before callbacks can resolve it in another context. A permanent ID does not make an unsaved row visible cross-context.

Implementation scope:
- Save each newly created session before launching related asynchronous queries, or queue related queries until a successful parent save completes.
- Do not pass managed objects between queues.
- Add an in-memory test proving the parent is resolvable from a second context before related-record insertion is attempted.

### 3. High: Imported Apple Health stage semantics remain incorrect

Evidence: `Zeez/DataImport/HealthKitDataImporter.swift:237-263`; consuming calculations in `Zeez/Views/Dashboard/DashboardSummaryCards.swift:144-167` and `Zeez/Sleep/Stage/SleepStageView.swift:130-145`

The crash fix preserves overlapping Apple Health samples, but the app stores `inBed` beside asleep stages and maps `asleepUnspecified` to `light`. Apple Health does not assert that unspecified sleep is light sleep, and overlapping in-bed records must not be counted as an additional sleep stage. Stage previews/distributions can therefore show fabricated light sleep or distorted percentages.

Implementation scope:
- Preserve source meaning: represent `asleepUnspecified` as an unspecified-asleep state rather than `light`; treat `inBed` as contextual/non-stage data in stage percentage calculations.
- Ensure dashboard/detail stage consumers do not double count overlapping non-stage intervals.
- Label Apple Health stages as imported measurements; do not present unspecified state as inferred light sleep.
- Add deterministic tests for sample-value mapping and a distribution containing overlapping `inBed` plus typed asleep intervals.

### 4. High: Unavailable scores still render as quality judgments on active surfaces

Evidence: `Zeez/Sleep/Quality/SleepQualityView.swift:8-14`, `:79-123`, `:175-217`; `Zeez/Views/CalendarDropdownView.swift:89-101`, `:158-218`; `Zeez/Views/WeeklyProgressView.swift:84-108`; `Zeez/Views/RecentSessionsView.swift:42-57`; `Zeez/Watch/WatchConnectivityHandler.swift:287-310`; `ZeezWatch Watch App/SleepSummaryView.swift:30-44`

`SleepQualityView` says “Score Not Available” for an imported HealthKit session and immediately supplies fabricated duration/stage quality percentages. The dashboard calendar and accessibility labels still classify raw zero/sentinel values as poor quality. The watch bridge sends raw `qualityScore`, and the watch displays `0/100` as sleep quality for imported sessions.

Implementation scope:
- Gate all score-derived UI and accessibility text through a shared display policy.
- When score is unavailable, hide quality breakdown/rating/color semantics and render a clear unavailable state.
- Extend the watch payload/model with score availability (or omit score) and render unavailable on watch.
- Retain explicit “Zeez Estimate” or neutral “Estimated” labeling only where an estimate actually exists.
- Add tests for unavailable presentation policy, watch payload availability, and calendar/weekly/recent accessibility helper logic if extracted.

## Activation Blockers / QoL

- `hasDisplayableScore` currently means only `qualityScore > 1.0`, while its documentation says this guarantees a Zeez estimate (`Zeez/Sleep/SleepSession+Extensions.swift:55-63`). Pillow and manual tracking code still write non-Zeez scalar scores. Before either feature is exposed, define provenance explicitly or use a neutral label consistently.
- `TrendsView`, `MonthlyTrendsView`, and `WidgetContainer` compile but no production navigation into them was found. Before activation, remove the remaining personal sleep-debt chart/values and raw quality aggregation in `Zeez/Views/Trends/MonthlyChartSection.swift:9-40` and `Zeez/Views/Trends/MonthlyTrendsDataProvider.swift:70-75`, `:196-203`.
- `SleepStageAnalyzer` still makes heuristic REM assignments and `SleepQualityCalculator` presents weighted scoring as research-based. They are not used for imported HealthKit-stage sessions now. Any future manual/device inference UI must call these estimates and disclose their input limitations.

## Verification State

Command attempted:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' -derivedDataPath /private/tmp/ZeezThirdSleepAuditTests -only-testing:ZeezTests/SleepAnalysisIdempotencyTests -only-testing:ZeezTests/SleepScorePresentationTests -only-testing:ZeezTests/SleepImportGroupingTests -only-testing:ZeezTests/SleepStageNormalizationTests -only-testing:ZeezTests/SleepDataPreservationTests
```

The iOS and watch app sources compiled through the modified sleep files. Test execution was blocked because `ZeezTests/OnboardingTests.swift` synchronously calls `@MainActor` `OnboardingManager.computeBedtime(...)`; this existing test-target compilation error must be minimally corrected before sleep tests can run.

The new duplicate-start tests exercise `groupIntervalsIntoSessions`, not the production `groupSamplesIntoSessions` HealthKit helper. Keep them, but add mapping/overlap coverage at the production boundary or share one tested grouping implementation.

## Ready-To-Paste Codex Prompt

```text
Work in /Users/daniel/Documents/AppProjects/Zeez.

Read CLAUDE.md, AGENTS.md, and SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md first. The worktree contains in-progress changes. Preserve unrelated work and do not revert or clean it.

Objective: implement only the remaining sleep reliability fixes documented in the third-audit handoff, with focused deterministic tests and verification. Do not reopen already completed onboarding or sleep remediation work except for the minimum test-target compile fix needed to run the requested sleep suites.

Required implementation:
1. Remove the debug-only destructive startup fallback in Zeez/App/ZeezApp.swift: a data-integrity fetch failure must never call clearAllData() or auto-generate mock data. Keep mock generation user-triggered. Add a narrow regression test if you extract testable policy.
2. Fix HealthKitDataImporter related-data ordering. A SleepSession must be saved and resolvable cross-context before heart-rate or respiratory callbacks can attach children. Keep Core Data queue confinement and add a deterministic in-memory regression test for parent resolvability before attachment.
3. Correct Apple Health stage semantics. Do not map asleepUnspecified to light; represent it honestly as unspecified asleep. Do not include overlapping inBed intervals as a peer sleep stage in displayed stage percentages/cycle summaries. Keep imported typed stages intact and label them as source-reported. Add tests for HealthKit value mapping and an overlapping inBed + asleep distribution case.
4. Complete unavailable-score handling on active surfaces: SleepQualityView must not show quality percentages below an unavailable overall score; CalendarDropdownView, WeeklyProgressView, RecentSessionsView accessibility, WatchConnectivityHandler payloads, and ZeezWatch Watch App/SleepSummaryView must not announce/display raw zero or sentinel scores as quality. Reuse a single score availability rule and make watch availability explicit. Add focused tests where logic can be extracted.

Scoped QoL only if it stays narrow:
- Correct misleading hasDisplayableScore documentation/provenance labels so non-Zeez external scores are not called Zeez estimates.
- Do not activate or expand dormant Trends/Widget/manual systems. If touching their shared code is unavoidable, remove rather than expose personal sleep-debt claims and filter unavailable scores.

Test unblock:
- The selected sleep tests currently cannot execute because ZeezTests/OnboardingTests.swift calls @MainActor OnboardingManager.computeBedtime from nonisolated test methods. Apply only the minimal actor annotation needed to compile the test target; do not change onboarding behavior.

Verification:
- Run the focused sleep tests listed in SLEEP_RELIABILITY_IMPLEMENTATION_HANDOFF.md.
- Build the iOS Zeez scheme and the ZeezWatch Watch App scheme if the available simulators support them.
- Report modified files, tests run/results, and any remaining manual Apple Health/watch verification steps.
```
