# Future improvements

Live follow-up tracker, created 2026-07-07 when `IMPROVEMENT_ROADMAP.md` was archived
(Phases 0–2 complete; see `Archive/IMPROVEMENT_ROADMAP.md` for the full audit, decisions,
and progress log).

## Open verifications needing a device / Daniel / App Store Connect

These are the only remaining open items from the 2026-07-05 audit's Phases 0–2; all code
work is complete and verified in-simulator.

- **Alarm end-to-end on a physical device (1.1):** set an alarm, force-quit the app, lock
  the phone → follow-ups fire at cadence; Stop re-arms the next chain. (Also covers the
  delegate-callback threading paths noted in the roadmap's 1.6/2.8 row, and since D2b whether the
  audio watchdog runs: `DEVICE_TEST_RUN.md` T5.1.)
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

**Completed 2026-10-26:**

- ~~Confirm the Swift Testing attribution check on CI.~~ Done — run `40282995935` on `3a59775` (Xcode 16.4): Swift
  Testing printed `✔ Test run with 315 tests passed …`, and "Fail on Swift Testing issues that no test owns" passed.
  That shows 16.4's summary line matches what the script reads; a clean run cannot show that 16.4 would word an
  unattributed issue the same way. The `/code-review` of `f3c6a47..5a377d3` was not done.
- ~~`NavigationView` → `NavigationStack`.~~ Done — second audit **D1** (`5f2d4a5`, `4e74791`…`05c7d6a`). Each tab owns
  a `NavigationStack` in `MainView`, so pushes stay in their tab and the tab bar stays visible. `LearnView`'s nested
  container and the unreachable `LearnHomeView` are gone (`PARKED_CAPABILITIES.md` §10). The one pushed view that
  wrapped itself, `PersonalizationSettingsView`, stacked a second bar under Settings'; it no longer does. Sheets and
  previews swapped mechanically. No `NavigationView` remains. Device check: `DEVICE_TEST_RUN.md` T15.1.
- ~~Trends has no entry point.~~ Reconnected (`5583586`) through a **Sleep Trends** link under the dashboard's Weekly
  Progress chart, shown once there are recorded nights (Daniel chose it over a fourth tab or `WeeklyTrendCard`).
  `TrendsView`'s own body had no `NavigationView` after all, only its preview and a sheet nothing opened. Before it
  returned (`2274ab4`…`55e388f`), each fix with a test that failed first:
  - the three known bugs: consistency compared seconds² with seconds, bedtimes wrapped at midnight, and
    `TrendChart` divided by zero;
  - its three "Upgrade to Premium" cards, which would have been the paywall's first entry point, are removed (see
    below);
  - "consistency" was a percentage grade with "Excellent…"/"Consider stabilizing…" insights; it is now
    `SleepStartSpread`, "your recorded sleep start time varied by about N minutes over M nights", from at least 4
    nights, each represented by its longest recording, so a nap is not a bedtime;
  - the schedule chart drew a 23:00–07:00 night across the 16 waking hours; it is one bar per night on a
    noon-to-noon axis;
  - "Sleep Duration" is "Recorded Session Duration", and the monthly duration no longer mixes in Apple Health
    time asleep;
  - trends use only current-`ZeezScore.version` estimates (spec §6), under their experimental series name;
  - an estimate change needs at least 4 estimated nights in each month compared (Daniel's minimum);
  - the monthly chart had no value axis and stretched a two-point change across its height; it is Swift Charts
    on 0–100;
  - the Month range's thirty overlapping weekday labels became weekly ones;
  - cards vanished in dark mode.
  `StatsDataProvider`, `SleepStatsRange`, `StatsComponents`, `WeeklyTrendCard` and `TrendChart` are deleted.
  Device check: `DEVICE_TEST_RUN.md` T15.2.

**Still open:**

- **The paywall sells features that do not exist** (found 2026-10-26). `SubscriptionView` lists `PremiumFeature`
  descriptions: "Personalized recommendations and coaching", "Real-time heart rate monitoring and advanced analytics",
  "Live environmental impact tracking and optimization", "Detailed reports on how your environment affects sleep".
  None of these exists, and the last is a causal claim the contract prohibits. A developer flag, not an entitlement,
  hid Trends' upgrade cards, so a subscriber would have kept seeing them, and unlocking showed nothing. No screen opens
  the paywall now, and `PaywallReachabilityGuardTests` keeps it that way. **This blocks `DEVICE_TEST_RUN.md` T13**
  (StoreKit sandbox), which needs a paywall to buy from. Decide what premium actually unlocks, rewrite the feature
  list against `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`, then give it an entry point and change the guard on purpose.
- **Learn screens left without callers** (2026-10-26): `LearnDailyFactView` and `LearnNoteBrowserView` were reachable
  only from `LearnHomeView`, deleted in D1a. They were already unreachable. Decide with the other Learn cleanup
  (`PARKED_CAPABILITIES.md` §10).
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
- **Dead stubs in `Zeez/Sleep/SleepAnalysisTypes.swift`** (found 2026-10-25). The file's header calls them temporary
  Phase 1A types. Every type in it except `SleepGoalPolicy`, the `SleepGoalShortfall*` types and
  `SleepDebtCalculator` has no caller: `SessionInfo`, `CycleAnalysis`, `AnalysisResult`, `TrendDirection`,
  `PersonalizedBaselines`, `QualityTrends`, `SleepPatternAnalysis`, `PersonalizationManager`,
  `HistoricalAnalyzer`. The last two return hard-coded `.mock` values (a 75 consistency score, "Regular"/"Delayed"
  patterns, 0.7–0.8 confidence). Nothing shows them today, but the first caller would put made-up numbers in front
  of a user. Delete them. Separately, Settings → Sleep Analysis → Personalization links to a screen that only says
  "Coming Soon"; whether that link stays is a product call (`PARKED_CAPABILITIES.md` §5).
  Two more files belong in the same cleanup (found 2026-10-26): `Zeez/Sleep/SleepInfoCard.swift`, whose
  "fell asleep" row is a hard-coded "25 min" (`calculateFellAsleepTime`, a TODO), and
  `Zeez/Sleep/SleepPositionAnalyzer.swift` ("Remove or simplify when Learn module is refactored"). Neither has a caller.
- **The alarm sound picker's "Import from Files" button does nothing** (found 2026-10-26). It is reachable today:
  Alarm → edit an alarm → Alarm Sound. `AlarmSoundPickerView` shows a "Pro Tip" telling the user to import their own
  sounds, above a button whose action is `// TODO: Implement custom sound import`. Remove the tip and button, or
  build the import; a dead control is also an App Review completeness risk. The only other code TODO,
  `ErrorManager`'s "send to analytics", is a sink nobody asserts on (D2's non-targets) and needs nothing.
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
- ~~Singleton graph → protocol injection, incrementally.~~ Done for the two seams D2's stopping rule allows:
  `WatchSessionProtocol` (`d46a2e2`, 2026-10-26) and the alarm audio session and player factory (`3b9b1fd`,
  `f6de1a1`, 2026-10-27), with 21 tests. Nothing else unlocks a test, so the rest stays as it is
  (`SECOND_AUDIT_IMPROVEMENTS.md` Phase D, D2). D2b fixed one bug: the audio watchdog's five-retry cap never tripped.
- **Found by D2 (2026-10-26/27), recorded and not fixed.** At the D2 checkpoints Daniel chose to record these rather
  than fix them, except the vibration-only alarm, which was found afterwards and still needs his call. The first three
  need hardware to judge.
  - **The alarm's volume table never applies to bundled sounds.** `AlarmAudioController.normalizeVolume`'s keys
    carry `.caf` (`"Zeez_Long_Default.caf": 0.9`), but bundled sounds are looked up by bare name, so every bundled
    alarm plays at the requested volume unadjusted. Fixing the keys makes bundled alarms 10–20% quieter; hear that on a
    device before changing it.
  - **The alarm's audio can start on the notification delegate's queue.** `AlarmNotificationHandler`'s
    `willPresent` and `didReceive` call `startContinuousAudio()` directly, and its own comment says those callbacks
    arrive off the main thread. `Timer.scheduledTimer` there schedules the watchdog (and the system-sound beep timer)
    on a run loop that may never run, and the controller's state is then touched from that queue and from
    `ActiveAlarmView` on main. Usually `ActiveAlarmView.onAppear` restarts the loop on main, which replaces the
    timer, though its `stop()` then invalidates a timer from a thread other than the one it was scheduled on.
    Device check `DEVICE_TEST_RUN.md` T5.1. If it fails: hop to main in `startContinuousAudio`, or make the
    controller `@MainActor`.
  - **A vibration-only alarm still plays audio when it rings in the app.** `startContinuousAudio()` ignores
    `vibrationOnly`, and `ActiveAlarmView` returns early for such an alarm without stopping the loop the handler
    started. That loop is also the one case where the off-main watchdog above survives. Found 2026-10-27 while
    mapping D2b's call sites. Device check T5.1.
  - **The fallback sound has no watchdog.** When the watchdog falls back to Alarm_Classic, nothing restarts that
    player if it stops too. This was already true before D2b, which left it alone.
  - **Refused wake patterns are never resent.** `WatchConnectivityHandler.sendMessage` refuses a `.high` message
    (`sendWakePattern`, `stopWakePattern`) when the watch is unreachable and leaves it in `WatchMessageQueue`.
    `retryFailedMessages` only resends messages whose `retryCount` is above 0, and neither side implements
    `sessionReachabilityDidChange`, so the message is never sent and the queue only grows. A watch whose app is not
    running when the alarm rings gets no haptics, which may be the right outcome for a wake pattern; the leak is not.
    Device check T8 step 4.
  - **`isWatchAvailable` means two things.** Activation sets it to "activated"; `sessionWatchStateDidChange` sets it
    to "reachable". `AlarmNotificationHandler` gates the watch haptics on it, and no view observes it.
  - **The watch's heartbeat fields go unread.** The watch sends `batteryLevel` and `appState` with every
    `heartbeat`; the phone answers "pong" and reads those fields only under `statusUpdate`, which the watch never
    sends, and then only to a debug log. Drop the fields or the `statusUpdate` branch.

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
  the fixed Week/Month ranges (a duplicate 7-day "Days" range was removed 2026-10-22). Trends had no entry point
  from 2025-08-19 until 2026-10-26, so its share of this phase reaches users only from this build on.
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
