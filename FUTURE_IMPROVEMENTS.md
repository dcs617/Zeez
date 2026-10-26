# Future improvements

Live follow-up tracker, created 2026-07-07 when `IMPROVEMENT_ROADMAP.md` was archived
(Phases 0–2 complete; see `Archive/IMPROVEMENT_ROADMAP.md` for the full audit, decisions,
and progress log).

## Open verifications needing a device / Daniel / App Store Connect

These are the only remaining open items from the 2026-07-05 audit's Phases 0–2; all code
work is complete and verified in-simulator.

- **Alarm end-to-end on a physical device (1.1):** set an alarm, force-quit the app, lock
  the phone → follow-ups fire at cadence; Stop re-arms the next chain. (Also covers the
  delegate-callback threading paths noted in the roadmap's 1.6/2.8 row.)
- **Phone↔watch message round-trip (1.5)** (no paired simulators were scriptable in the
  dev environment).
- **Notification-budget banner visual check (1.4)** with ~5 smart-wake alarms creating
  real pending-notification pressure.
- **StoreKit on device (2.1):** sandbox purchase + restore; airplane-mode launch keeps
  premium; product IDs confirmed/created in App Store Connect **exactly** as
  `com.zeez.subscription.{premium,premiumplus}.{monthly,annual}`.
- **Release checks (2.3):** Organizer archive validation (needs signing/Xcode UI); manual
  walkthrough of the delete-all-data flow; publish the real privacy-policy URL
  (placeholder `https://dcs617.github.io/zeez-privacy/` in `AppConstants.Legal`).

## Removed capabilities

Features deleted during the second audit are registered in **`PARKED_CAPABILITIES.md`** at the
repo root, with the reason, the recovery command, and what the claims contract requires before
each could ship. Deletion is not abandonment; that file is where the intent lives.

## Post-release / nice-to-have (tracked, not scheduled)

Carried over from the archived roadmap's Phase 3.

**Completed by the second audit (2026-07-09), kept here for provenance:**

- ~~Heart-rate downsampling on HealthKit import.~~ Done — second audit **B9**
  (`DataImport/HeartRateDownsampler.swift`, 60-second buckets).
- ~~Duration-weighted stage-distribution scoring; derive `confidenceScore`.~~ Done — **B8**.
  See `ZEEZ_SCORE_SPECIFICATION.md`, now a live contract.
- ~~Import UX: completion signal and partial-failure reporting.~~ Done — **B10**
  (`HealthKitImportResult` with a per-type `RelatedDataOutcome`).
- ~~First-run empty-dashboard state that routes to HealthKit import.~~ Done — **B11**
  (`Views/Dashboard/DashboardEmptyStateCard.swift`).
- ~~Environmental noise units fiction.~~ Done — **B5**. Noise is a relative index 0–100
  (`Environment/NoiseIndex.swift`), explicitly not dB SPL.

**Completed 2026-10-25:**

- ~~Swift Testing can pass a test whose expectation failed.~~ Done — `b7a3379`…`3dff641`. Canaries re-run on
  Xcode 26.6 confirmed the losing patterns (CLAUDE.md, Testing), and the full run before any change had no
  hidden failure. 112 assertions in 13 suites ran where a failure reached no test, not the ~130 in 16 a lexical
  scan estimated. They now return values from their closures and assert outside them, as do 6 safe
  private-context ones. `SwiftTestingAttributionGuardTests` scans for the shapes, and the `unit-tests` job runs
  `.github/scripts/check-swift-testing-attribution.sh` over its log and result bundle.
  Known limits of the guard: it knows only `perform`, `performAndWait`, and helpers whose closure parameter is
  handed an `NSManagedObjectContext`, and it matches asserting helpers by name. It does not see other ways to leave
  the test's task (`Task.detached`, `DispatchQueue` blocks, delegate or notification callbacks), none of which the
  suites use today; the CI check catches those only once such an assertion fails. Extend the scanner if a suite
  starts using one.

**Still open:**

- Real WidgetKit extension. The in-app `Zeez/Widgets/` tree was deleted in **B1** (it was
  unreachable and carried fabricated readings); a genuine extension target has not been built.
  Tracked as Phase **D3c**; see `PARKED_CAPABILITIES.md` §4. Its Core Data prerequisite is done:
  **D3a** moved the store into an App Group container, which had to happen before any user had data.
  ⚠️ D3a is inert until the **App Groups capability is toggled once in Xcode** — CLI `xcodebuild`
  strips profile-backed entitlements, so it cannot be done from the command line.
  Delete All Data no longer breaks the store while a second connection holds it (`9d5b3b7`). Re-run T11 with the
  extension installed.
- Apply for the critical-alerts entitlement (defensible for an alarm app); until granted,
  keep the graceful `checkCriticalAlertsEnabled` degradation. Phase **D3b** — paperwork only, no code
  to write; file it early, Apple takes weeks.
- ~~Alarm health indicator in `AlarmSettingsView`.~~ Done 2026-10-20 — second audit **C5**
  (`Zeez/Alarm/AlarmHealth.swift`). Also flags an enabled alarm with no pending main notification,
  and missing notification permission, with a one-tap fix for each.
- ~~Durable HealthKit import identity.~~ Done in code 2026-10-22 — `PARKED_CAPABILITIES.md` §8a, Core Data
  model **v3**. Re-import updates changed nights, applies deletions HealthKit reports, and duplicates nothing.
  The v2→v3 hop is the store's first structural migration; on a pre-D3a install it runs on the same first launch
  as the App Group relocation (`DEVICE_TEST_RUN.md` T1). Device check T3.1 pending.
- ~~`PersistenceController.clearAllData` (Delete All Data) removes `Zeez.sqlite.wal`/`.shm` — names SQLite never
  writes — so the real `-wal`/`-shm` survive beside the recreated store.~~ Done 2026-10-22 (`9d5b3b7`):
  `recreateStore(at:options:in:)` destroys the store in place with `destroyPersistentStore` and reopens it. A probe
  showed the old code lost nothing with today's single connection (closing it had already emptied the WAL), but
  with a second connection on the store — the future widget extension — the recreated store failed every read and
  save. The `-wal`/`-shm` now stay on purpose: the recreated store reuses them. Device check T11.
- **Trends has no entry point — reconnect it (Daniel decided 2026-10-26).** `TrendsView` lost its tab in `ac140c2` (2025-08-19).
  Its only remaining link is in `WeeklyTrendCard`, which nothing creates. So nothing on it has reached a user:
  not B4's duration relabel, not the 2026-10-20 night-coverage card, not the 2026-10-22 monthly-chart fixes
  (`8280934`). The second audit recorded the monthly views as "live behind TrendsView" (C2); that was wrong.
  Reconnecting means a tab or a dashboard link (`WeeklyTrendCard` already holds one), which lands on D1a's
  per-tab `NavigationStack`s, so it is queued with D1 in `SECOND_AUDIT_IMPROVEMENTS.md` §7. `TrendsView` also nests
  its own `NavigationView`. Three things must be fixed before it returns:
  - Monthly consistency compares variances (seconds²) with limits written in seconds, so more than about a
    minute of spread reads 0% and triggers "Consider stabilizing your sleep schedule".
  - Bedtimes are measured as seconds since midnight, so 23:50 and 00:10 count as almost 24 hours apart.
  - `TrendChart` divides by zero when every plotted value is equal, which plots NaN coordinates.

  `StatsDataProvider` and `SleepStatsRange`, in the same tree, have no callers either.
- **Confirm the Swift Testing attribution check on CI.** It was verified only on Xcode 26.6; the `unit-tests` job
  runs Xcode 16.x. The first CI run after `3dff641` shows whether that Swift Testing prints the same
  `Test «unknown» recorded an issue` and `Test run with …` lines, and whether its result bundle files unattributed
  issues as a failed test. A missing summary line fails the job loudly rather than passing it. Not pushed as of
  2026-10-26. A `/code-review` of `f3c6a47..5a377d3` first is worthwhile: the guard is ~450 lines of heuristic
  scanning.
- **Dead stubs in `Zeez/Sleep/SleepAnalysisTypes.swift`** (found 2026-10-25). The file's header calls them temporary
  Phase 1A types. Every type in it except `SleepGoalPolicy`, the `SleepGoalShortfall*` types and
  `SleepDebtCalculator` has no caller: `SessionInfo`, `CycleAnalysis`, `AnalysisResult`, `TrendDirection`,
  `PersonalizedBaselines`, `QualityTrends`, `SleepPatternAnalysis`, `PersonalizationManager`,
  `HistoricalAnalyzer`. The last two return hard-coded `.mock` values (a 75 consistency score, "Regular"/"Delayed"
  patterns, 0.7–0.8 confidence). Nothing shows them today, but the first caller would put made-up numbers in front
  of a user. Delete them. Separately, Settings → Sleep Analysis → Personalization links to a screen that only says
  "Coming Soon"; whether that link stays is a product call (`PARKED_CAPABILITIES.md` §5).
- **Tests named for what they do not test** (found 2026-10-25). Real migration coverage is
  `CoreDataModelV2MigrationTests`, `CoreDataModelV3MigrationTests` and `StoreMigrationPathTests`; these are not it:
  - `CoreDataMigrationTests.migrationManagerInitialization` asserts a non-optional singleton is non-nil.
  - `dataPreservationDuringMigration`, `relationshipIntegrityAfterMigration`, `storeRecoveryAfterCorruption` and
    `migrationPerformanceWithLargeDataset` save to and read from a fresh in-memory store. Nothing migrates and
    nothing is corrupted.
  - `CoreDataModelTests` says it "validates the index fix", but an in-memory store has no indexes.
  - `respiratoryDataIndexPerformance` (`< 0.1 s`) and `migrationPerformanceWithLargeDataset` (`< 5 s`) assert
    wall-clock limits that measure the runner, not the model, and can fail on a loaded CI machine.

  Rename each to what it checks, or delete the ones the real suites cover, and drop the wall-clock limits.
  Test-only; no product change.
- Per-night preferred source for overlapping sleep sources — needs an amendment to
  `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` first, which defines time asleep as the union across sources.
- `NavigationView` → `NavigationStack` migration (start with `MainView` — remove the
  NavigationView wrapping the TabView; give each tab its own NavigationStack). Phase D1. Approved 2026-10-26 to
  run before the device pass, with Trends reconnected on top of it: the prompt is in `SECOND_AUDIT_IMPROVEMENTS.md`
  §7.
- Singleton graph → protocol injection, incrementally, following the
  `SleepAnalyzer.analyzeSleepSession(objectID:container:)` pattern. Phase D2. Approved 2026-10-26; it follows D1, and
  the D1 chat queues its prompt.

## Sleep product roadmap (reconciled 2026-07-09, second-audit D3d)

`Archive/SLEEP_REFACTORING_PLAN.md` (2026-05-26) was described here as holding "unexecuted
Phases 3–6". That was wrong in both directions: phases A–C delivered most of it under different
names, and one phase diverged from the plan on purpose. Each phase in the archive now carries a
status line. In summary:

- **Phase 3 (import integrity)** — delivered in code (B9, B10, C6; durable HealthKit sample identity,
  re-import reconciliation, explicit deletion and the source policy 2026-10-22, `PARKED_CAPABILITIES.md`
  §8a). Outstanding: the on-device re-import check, `DEVICE_TEST_RUN.md` T3.1.
- **Phase 4 (longitudinal review)** — mostly delivered (B4, B6, B7). Night and per-session input
  coverage landed 2026-10-20 (`SleepCoverage.swift`). Outstanding: an explicit date-range picker beyond
  the fixed Week/Month ranges (a duplicate 7-day "Days" range was removed 2026-10-22). Trends itself has no
  entry point, so its share of this phase has never shipped; see "Still open" above.
- **Phase 5 (experimental score)** — substantially delivered (B8, plus A1/A7). It **diverges** from
  the plan on purpose: the score is computed only from Zeez-inferred stages and never grades
  Apple-reported ones. The user-visible component breakdown landed 2026-10-20
  (`ZEEZ_SCORE_SPECIFICATION.md` §8), so the score now "explains itself" as the phase required.
- **Phase 6 (owned-sensor staging)** — not started, and it is a research project whose deliverable is
  a go/no-go report. Note that production **already** infers stages (`SleepStageAnalyzer`) and the
  score depends on them, with an "Experimental" label standing in for an evaluation that has never
  been run.

The residue is registered as spec stubs in `PARKED_CAPABILITIES.md` §8 and §9. Claims rules remain
binding on all of it: `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` and `ZEEZ_SCORE_SPECIFICATION.md` at
the repo root are **live** contracts and are deliberately not archived.
