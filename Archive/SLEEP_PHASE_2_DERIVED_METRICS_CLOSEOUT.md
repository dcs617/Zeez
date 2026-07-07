# Sleep Phase 2 Derived Metrics Closeout

Date: 2026-05-26  
Status: Complete

## Determination

Phase 2, One Derived Metrics Engine, is complete for the active production
sleep-review routes identified in the Phase 1 closeout. A shared deterministic
`DerivedSleepMetrics` contract now owns supported recorded interval, qualified
Apple Health asleep duration, asleep-stage composition, reported `inBed` and
awake duration, derived efficiency eligibility, and selected-goal comparison.

No scoring design, stage inference, recommendation, trends, widgets, or new
HealthKit/watch capability was introduced.

## Findings Corrected

| Severity | Finding | Correction |
| --- | --- | --- |
| High | Routed stage summary/chart views independently summed persisted rows, so they could not represent conflicting overlapping typed intervals as unavailable. | `DerivedSleepMetrics.asleepStageComposition` now de-duplicates same-type timed intervals and returns unavailable for conflicting typed overlap; routed stage displays consume it. |
| High | Active session/chart/goal paths used separate duration interpretations and did not expose availability/provenance as one contract. | Routed duration and goal-comparison reads now consume `SleepSession.derivedSleepMetrics`; imported sessions require qualified Apple Health asleep evidence for asleep-dependent output. |
| Medium | Dashboard average and weekly accessibility presentation could reduce invalid recorded session bounds to a displayed zero duration. | These routed surfaces now show unavailable/no duration data unless `recordedSessionInterval` is available. |
| Medium | The watch payload recomputed recorded duration independently from phone UI. | Phone-to-watch duration transport now consumes the shared recorded-session interval metric; score availability behavior is unchanged. |

## Contract Semantics

`Zeez/Sleep/DerivedSleepMetrics.swift` defines:

- `MetricAvailability<Value>`: an available value with provenance, or a typed
  unavailable reason; missing input never becomes a numeric fallback.
- `SleepMetricProvenance`: recorded session, Apple Health reported evidence,
  derived-from-Apple-Health metrics, or an experimental Zeez estimate.
- `recordedSessionInterval`: valid persisted start/end interval only; it is
  never labeled as time asleep.
- `qualifiedAsleepDuration`: Apple Health asleep rows only, including explicit
  `asleepUnspecified`; `inBed` and awake rows are excluded.
- `asleepStageComposition`: asleep categories only; `inBed` and awake are
  excluded, unspecified remains explicit, and conflicting typed overlap is
  unavailable instead of arbitrarily redistributed.
- `reportedInBedDuration` and `recordedAwakeDuration`: available only when
  Apple Health evidence for the corresponding context exists.
- `sleepEfficiency`: available only from qualified Apple Health asleep duration
  and a valid reported `inBed` denominator.
- `goalComparisonDuration` / `goalShortfall`: Apple Health sessions use
  qualified asleep duration; locally recorded Zeez sessions may use their
  recorded interval with recorded-session provenance. The result remains a
  selected-goal comparison, not medical sleep debt or recovery need.

## Active Consumers Migrated

- Dashboard stage previews, recorded-session preview, and average-session card.
- Weekly progress recorded-session duration rendering and accessibility output.
- Routed stage views: `SleepStageView` and the `SleepStagesChart` embedded by
  `EnhancedSleepDetailsView`.
- Experimental estimate supporting stage/duration presentation in
  `SleepQualityView`.
- Recent session banner and row recorded interval display.
- Active selected-goal shortfall summary calculation.
- iPhone-to-watch latest-session duration payload and shared watch-summary
  initializer.

`CalendarDropdownView` remained on the already-conforming Phase 1
score-availability policy because it does not compute derived duration or
stage metrics.

## Tests

Added `ZeezTests/DerivedSleepMetricsTests.swift`, covering:

- Apple Health-derived provenance.
- `inBed` exclusion and efficiency denominator behavior.
- explicit `asleepUnspecified` preservation.
- unavailable asleep-dependent output without qualified asleep evidence.
- unavailable awake/efficiency output without required reported inputs.
- selected-goal shortfall semantics.
- conflicting typed overlap handling.
- recorded Zeez interval comparison without claiming qualified asleep.

Existing Phase 1 sleep suites remain in the verification selection.

## Deferred Work

- Phase 3 HealthKit durable import identity, source-overlap/coverage policy,
  and re-import diagnostics.
- Dormant or later systems: Trends, Widgets, Pillow activation,
  recommendations, score redesign/validation, and Zeez-owned stage inference.
- Existing dormant watch quality-classification helpers remain retirement
  candidates and were not activated.

## Verification

Commands executed from the repository root:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination id=EE7AA4EF-C176-4E8E-9CC2-C13AAA56E22C -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -derivedDataPath /private/tmp/ZeezSleepDerivedMetricsTestsFinal -only-testing:ZeezTests/SleepAnalysisIdempotencyTests -only-testing:ZeezTests/SleepScorePresentationTests -only-testing:ZeezTests/SleepImportGroupingTests -only-testing:ZeezTests/SleepStageNormalizationTests -only-testing:ZeezTests/SleepDataPreservationTests -only-testing:ZeezTests/SleepDebtTrackingTests -only-testing:ZeezTests/DerivedSleepMetricsTests -quiet
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' -derivedDataPath /private/tmp/ZeezSleepReliabilityIOSBuildFinal build -quiet
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme 'ZeezWatch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=11.1' -derivedDataPath /private/tmp/ZeezSleepReliabilityWatchBuildFinal build -quiet
```

Results:

- Focused sleep selection: successful exit; 59 tests in 7 suites passed.
- iOS `Zeez` simulator build: successful exit.
- `ZeezWatch Watch App` simulator build: successful exit.
- Existing non-blocking warnings remain, including watch Health usage
  description warnings and previously present Swift concurrency/unused-code
  warnings outside the derived-metrics contract.

## Explicit Device Deferrals

- Real Apple Health import verification on a physical iPhone.
- Verification of Apple Health stage and related physiological sample coverage
  on actual imported records.
- Paired physical Apple Watch payload synchronization and summary rendering.

These remain deferred due unavailable Apple Developer account/device access and
do not block Phase 2.
