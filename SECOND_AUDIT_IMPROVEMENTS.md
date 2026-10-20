# Second Audit — Improvement Tracker

Source: read-only second audit performed 2026-07-07 on branch `feature/sleep-simplification`
(clean tree, HEAD `b7572c6`). First audit (2026-07-05) is archived at
`Archive/IMPROVEMENT_ROADMAP.md`; its open device/ASC verifications live in
`FUTURE_IMPROVEMENTS.md`. This file is the tracker for the **next** round.

Verified during this audit: iOS target builds, watch target builds, and the full
`ZeezTests` bundle passes — **147 tests in 24 suites, 0 failures** (iPhone 16 Pro sim,
iOS 18.6, Xcode 26).

---

## 1. Audit summary

The codebase is in dramatically better shape than the first audit found it. The alarm
stack, StoreKit, privacy manifests, deletion flow, score-display gating
(`hasDisplayableScore`), and test suite are all solid. The remaining problems cluster in
three places the first audit did not reach:

1. **Two live Core Data threading violations** outside the alarm stack (watch data
   requests and end-of-session HealthKit sync) — the exact bug class items 1.6/2.8 fixed
   for alarms.
2. **The phone→watch push contract is broken** — pushed sleep/alarm updates are never
   parsed by the watch; only the watch-initiated request/reply path works.
3. **Legacy claims violations in secondary surfaces** — most seriously an HRV section
   that fabricates chart points with `Double.random` and grades unvalidated "quality".

Overall position: **past MVP, at the TestFlight line.** Phase A below is the honest gap
between "tests are green" and "won't crash or mislead on a real device."

## 2. Prior-roadmap reconciliation

**Complete and holding (spot-verified in current source):**
- 0.2/0.3 UUID predicates: no `id.uuidString` predicates remain; SQLite-backed suite exists.
- 0.4 mic usage description present; `EnvironmentalMonitor` meters to `/dev/null`, deletes
  the legacy recording file, and stores sentinels when denied.
- 0.5/1.x alarm scheduling: prefix-filtered removals, snooze preservation, pre-armed
  follow-up chains, budget gate (`NotificationBudget`), snapshot pattern — all present.
- 2.1 StoreKit: real purchase flow, exact product-ID mapping, offline entitlement
  resolution, honest restore errors.
- 2.3 privacy: manifests in both targets, minimal entitlements, HealthKit read-only
  3-type scope in onboarding/importer, delete-all-data flow implemented.
- 2.4 tests/CI: 147 tests green; CI workflow runs ZeezTests.
- 2.6 storage: WAL, history pruning, 90-day analytics retention in BG task.
- 2.9 environmental honesty: sentinel + `measured*` accessors used by consumers.

**Complete on paper, regressed/missed in a corner (new findings below):**
- Threading discipline (1.6/2.8-class) was fixed in the alarm stack but not in
  `WatchConnectivityHandler` (A2) or `SleepSessionManager` (A3), and
  `BackgroundTaskManager` still hands a background-context object to the monitors (A4).
- Environmental honesty (2.9) missed the dead widget tree's hardcoded "20°C / Optimal"
  reading (B3) and the noise-units fiction was explicitly deferred (B5).

**Still open, manual-only (unchanged, from `FUTURE_IMPROVEMENTS.md`):** alarm E2E on a
physical iPhone; phone↔watch round trip on paired hardware; budget banner visual check;
StoreKit sandbox + ASC product IDs; Organizer archive; real privacy-policy URL.
The watch round-trip verification is **upgraded** from "manual check" to "will fail until
A5 is fixed" — see below.

## 3. Promoted items from FUTURE_IMPROVEMENTS.md

| Item | Was | Now | Why |
| --- | --- | --- | --- |
| Real WidgetKit ext. / misleading `Zeez/Widgets` naming | Post-release | **Pre-App-Store (as deletion)** | The whole tree (`WidgetContainer`, `WidgetPickerView`, `WidgetViews`) is unreachable dead code containing a fabricated "Room Temperature 20°C / Optimal" reading, "coming in Phase 2" placeholder copy, and prohibited "sleep debt and recovery status" wording. Delete now; build a real WidgetKit extension later if wanted. |
| Environmental noise units fiction | Post-release | **Pre-App-Store** | User-visible fabricated units ("dB" label on a normalized 0–100 value); mocks emit real 20–55 dB, so debug review masks it. |
| Duration-weighted stage scoring + derived confidence | Post-release | **Pre-App-Store** | Count-based distribution skews with variable-length stages; `confidenceScore = 85.0` is a fabricated constant persisted with every estimate. Fold in a missing-input policy for the 85/75/85/85 sub-score defaults (claims rule 4). |
| Heart-rate downsampling on import | Post-release | **Pre-App-Store** | 90-day import × full-night HR = hundreds of thousands of rows; every consumer loads them via relationship faults. Growth is unbounded. |
| Import UX completion / partial-failure reporting | Post-release | **Pre-App-Store** | HR/respiratory sub-imports are still fire-and-forget; user sees "imported N sessions" while related data may silently fail. |
| First-run empty dashboard → import routing | Post-release | **Pre-App-Store** | First-run dashboard shows empty cards with no route to the one action that produces data. Biggest single retention lever. |

**Stay deferred:** critical-alerts entitlement (needs ASC anyway), NavigationView →
NavigationStack migration, singleton → protocol injection, alarm health indicator
(post-release polish), dormant sleep-product Phases 3–6.

## 4. New findings (ranked)

26 items worth tracking. Not padded to 30 — the remainder observed were cosmetic.

### Phase A — fix before TestFlight

**A1. HRV section fabricates data and grades unvalidated "quality"** — Critical · Claims/Runtime
`Zeez/Views/HeartRateView+Helpers.swift:77-185`, `HRVChart.swift` (`HRVInsightsView`), reachable via `DashboardView.swift:447` → `HeartRateView`.
- Computes "RMSSD" from averaged HK heart-rate samples (not beat-to-beat intervals) — methodologically not HRV.
- When <3 windows exist it **invents chart points with `Double.random(in: -0.15...0.15)`** (lines 156-168) and displays them as a personal HRV timeline.
- Grades results "poor/fair/good/excellent" — Tier-3+ health judgment with no spec or validation; contract lines 84/117 prohibit this.
- Fix: delete the HRV + quality sections (keep the recorded-HR chart and stage-HR table with provenance), or rebuild later on real `HKQuantityTypeIdentifier.heartRateVariabilitySDNN` import with an "Experimental" label. Also review `sleepStageCorrelationSection` labeling while there.
- Effort: Small (deletion). Validate: view a session's Heart Rate screen with sparse HR data; add a regression test that `calculateHRV` is gone/never randomizes.
- ✅ **Done 2026-07-07** — deleted `calculateHRV`, the HRV section, `HRVChart.swift` (chart + insights/quality grading) and the HRV types; relabeled the stage-HR table with provenance wording; added `HeartRateClaimsGuardTests` source-scan regression suite. ZeezTests: 150/150 green.

**A2. Core Data touched off-queue when the watch requests data** — High · Core Data/Runtime
`Zeez/Watch/WatchConnectivityHandler.swift:448-520` — `session(_:didReceiveMessage:)` arrives on a WCSession background queue; `handleDataRequest` → `getCurrentSleepSummary()`/`getNextAlarmStatus()` fetch **viewContext** and read managed objects (incl. `derivedSleepMetrics`) on that queue. Fires every time the watch opens/refreshes its summary. Same class as the fixed 1.6/2.8 alarm bugs.
- Fix: hop to the view context's queue (`viewContext.perform`) or build payloads in a background context via objectIDs.
- Effort: Small. Validate: paired-sim/device round trip launched with `-com.apple.CoreData.ConcurrencyDebug 1`.
- ✅ **Done 2026-07-07** — replaced `getCurrentSleepSummary`/`getNextAlarmStatus` (viewContext on WCSession queue) with `fetchWatchPayloads(includeSleep:includeAlarm:)` that builds plain-value payload dicts inside a background context's `perform`; `syncSleepData`/`performFullSync`/`handleDataRequest` now reply asynchronously from that queue. Paired-device ConcurrencyDebug round trip stays on the manual list. ZeezTests green.

**A3. Core Data touched off-thread in end-of-session HealthKit sync** — High · Core Data/Runtime
`Zeez/Sleep/SleepSessionManager.swift:132-168` — `syncWithHealthKit` creates `HeartRateData` in **viewContext** and saves inside the `HKSampleQuery` result handler (background thread). Runs on every manually recorded session end.
- Fix: perform inserts in `newBackgroundContext().perform`, resolve the session by objectID.
- Effort: Small. Validate: record/end a session with ConcurrencyDebug 1.
- ✅ **Done 2026-07-07** — `syncWithHealthKit` now captures only `session.objectID` into the HK result handler and performs all `HeartRateData` inserts + save inside `newBackgroundContext().perform`, resolving the session via `existingObject(with:)`. Device record/end walkthrough with ConcurrencyDebug stays on the manual list. ZeezTests green.

**A4. Background task hands a background-context session to the monitors** — High · Runtime/Core Data
`Zeez/Infrastructure/BackgroundTaskManager.swift:429-432` passes a bg-context `SleepSession` to `EnvironmentalMonitor.startMonitoring(for:)`, which later does `reading.session = session` on **viewContext** (`EnvironmentalMonitor.swift:77-98`) — illegal cross-context relationship → NSInvalidArgumentException. Also conceptually wrong: a BGAppRefreshTask can't run a foreground Timer or mic session.
- Fix: remove the monitor starts from `updateActiveSleepSession` (the foreground path in `SleepControlView`/`SleepSessionManager` already owns this), or convert `EnvironmentalMonitor` to hold an objectID.
- Effort: Small. Validate: simulate BGTask with an active session (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.danielsparano.zeez.sleepupdate"]`), ConcurrencyDebug 1. (Identifier corrected 2026-07-09: `Info.plist` derives it from `$(PRODUCT_BUNDLE_IDENTIFIER)`, so it is `com.danielsparano.zeez.sleepupdate`, never `com.zeez.Zeez.sleepupdate`.)
- ✅ **Done 2026-07-07** — removed the `EnvironmentalMonitor`/`MovementDataManager` `startMonitoring` calls (and the pointless save) from `updateActiveSleepSession`; the task now only verifies an active session exists. Monitor lifecycle is owned solely by the foreground start path. BGTask simulation with ConcurrencyDebug stays on the manual list. ZeezTests green.

**A5. Phone→watch push contract is broken end-to-end** — High · watchOS
`Zeez/Watch/WatchCommunicationSupport.swift:54-62` flattens payloads to top level (`command`, `duration`, …), but the watch's `handleDataUpdate` (`WatchConnectivityManager.swift:210-218`) only reads **nested** `message["sleepSummary"]` / `["alarmStatus"]`. Consequences:
- `syncSleepData`/`performFullSync`/`updateAlarmContext` pushes (medium priority → `updateApplicationContext`) are received and silently dropped; only the watch-initiated `requestData` reply (which nests keys, `WatchConnectivityHandler.swift:493-510`) works.
- The watch has no decompression, so any payload that trips `compressIfNeeded` is unreadable on that side.
- Heartbeats go out as `transferUserInfo` (`.low`), which the watch never handles (no `didReceiveUserInfo`), and `performSend` reports unconditional success for `.medium`/`.low` — so `connectionQuality` is fiction and userInfo transfers queue up against an unpaired watch.
- Fix: define one typed payload envelope in `Shared/WatchDataModels.swift`, encode/decode it on both sides, delete or drastically simplify the heartbeat/compression/quality machinery, and add contract tests that push a flattened message through the watch parser (extend `WatchModelRoundTripTests` — today it exercises the model, not the wire shape).
- Effort: Medium. Validate: contract tests + the already-open paired-device round trip (which, as written, would currently fail for pushed updates).
- ✅ **Done 2026-07-07** — added `WatchSyncEnvelope` + `toPayload()`/`init(payload:)` wire contract to `Shared/WatchDataModels.swift`; both sides now encode/decode the same nested shape (pushes, applicationContext, and requestData replies). Phone: deleted heartbeat/compression/sync-coordinator machinery, `ConnectionQuality` is reachability-derived (none/good), `performFullSync` sends ONE envelope (two sequential `.medium` pushes replaced each other in the single applicationContext slot), `.medium`/`.low` map to `updateApplicationContext` and no longer require reachability. Watch: `handleDataUpdate` decodes via the envelope and now writes the offline cache (previously never written); `WatchOfflineStorage` decoders delegate to the shared `init(payload:)`. Added `WatchWireContractTests` (8 tests incl. legacy-flattened-message and missing-score wire policy). ZeezTests 158/158 green; watch target builds. Paired-device round trip stays on the manual list.

**A6. Follow-up chains are not re-armed on foreground** — High · Alarm
`Zeez/Alarm/AlarmObserver.swift:79-90` — the `willEnterForeground` reschedule is commented out (`TODO: Re-enable`). Chains are armed for the **next firing only** (`AlarmScheduler.scheduleFollowUpChain`), re-armed at launch/edit/Stop-action/time-change. A user who opens the app daily but never relaunches it gets no chain for any firing after the first — Heavy Sleeper protection silently lapses.
- Fix: re-enable a throttled reschedule on foreground (e.g. only when a chain's `chainStamp` is in the past); keep the debounce.
- Effort: Small. Validate: unit test — simulate foreground notification after `nextFire` passes, assert chain re-armed with a new stamp; device E2E already on the open list.
- ✅ **Done 2026-07-07** — added `AlarmScheduler.rearmStaleFollowUpChains(context:)` (snapshot pattern; per-alarm throttle: any pending `fu-pre` entry with a future trailing stamp means the chain is current and is left untouched; otherwise stale entries are removed and `scheduleFollowUpChain` re-arms) and wired `AlarmObserver`'s `willEnterForeground` hook to it, replacing the disabled TODO. Save-triggered debounce untouched. Two regression tests in `AlarmFollowUpChainTests` (stale chain replaced with future-stamped entries; current chain byte-identical after re-arm). ZeezTests 160/160 green. Device E2E stays on the manual list.

**A7. Zeez-recorded sessions get a fabricated score and are never analyzed** — High · Claims/Runtime
`Zeez/Sleep/SleepSessionManager.swift:64-71` sets `qualityScore = hoursSlept * 10` at session end. Because it's ≠ 0, the session is excluded from the analysis backlog (`BackgroundTaskManager.swift:465`, and `ZeezApp.verifyDataIntegrity`'s DEBUG check), and nothing calls `SleepAnalyzer` at session end — so no `SleepQualityScore` record is ever created and `hasDisplayableScore` stays false forever. Net effect: the app's own recorded sessions never show an estimate, and the fabricated 0–100 number pollutes every raw-`qualityScore` consumer (`RealDataManager.DataQualityReport`, `EnvironmentalRecommendationTracker.swift:90`).
- Fix: drop the `baseScore` write (leave 0 = awaiting analysis) and trigger `SleepAnalyzer.analyzeSleepSession(objectID:)` from `endSession`.
- Effort: Small. Validate: record ≥30-min mock session; assert a persisted estimate appears and dashboard card shows it.
- ✅ **Done 2026-07-07** — `endSession` no longer writes `hoursSlept×10` (score stays 0 = awaiting analysis, so the session remains in the analysis backlog) and chains `SleepAnalyzer.shared.analyzeSleepSession(objectID:container:)` onto `syncWithHealthKit`'s completion so the estimate sees the imported heart-rate samples (analysis still runs if the sync fails — movement data may suffice). `SleepSessionManager` and `SleepSessionValidator` got injectable `init(persistenceController:)` (the validator's overlap check silently fetched from the shared store). New `SleepSessionEndTests` (in-memory container): 20-min session ends at 0 and stays 0; 8-h session with seeded movement/HR/environmental data eventually gets a persisted `SleepQualityScore` with `hasDisplayableScore`. ZeezTests 162/162 green. Device record/end walkthrough stays on the manual list.

### Phase B — fix before App Store submission

**Status: complete (2026-07-09).** B1–B13 landed one commit per item on
`feature/sleep-simplification`. Baseline moved from 162 tests / 27 suites to **206 tests /
33 suites, all green**; iOS and watch targets build. New live documents: `ZEEZ_SCORE_SPECIFICATION.md`
(B8). Phase C/D not started — awaiting explicit approval.

**B1. Delete the dead in-app "Widgets" tree** — Medium · Maintainability/Claims
`Zeez/Widgets/Widget.swift`, `WidgetContainer.swift`, `Zeez/Views/WidgetViews.swift`, `WidgetPickerView.swift` — unreachable; contains hardcoded "Room Temperature 20°C / Optimal" (`WidgetContainer.swift:131-137`), "Simplified debt tracking coming in Phase 2" (line 122), "accumulated sleep debt and recovery status" copy (line 167), and premium flags nothing enforces. (Promotion of the FUTURE item.) Effort: Small.
- ✅ **Done 2026-07-09** — deleted `Zeez/Widgets/` (`Widget.swift`, `WidgetContainer.swift`) and `Zeez/Views/{WidgetViews,WidgetPickerView}.swift` after confirming every declaration (`WidgetType`, `WidgetConfiguration`, `StatBox`, the six widget views) was referenced only from within the tree; removed the `Widgets/` row from CLAUDE.md's directory table. ZeezTests 162/162 green.

**B2. Decide the Pillow importer's fate; as written it violates the claims contract** — Medium · HealthKit/Claims
`Zeez/DataImport/PillowDataImporter.swift` is reachable only from `Zeez/Views/DataImportView.swift`, which itself is unreferenced (dead). Defects if ever wired in: missing quality → fabricated `75.0` (line 241); CSV quality fallback `duration × 12` (line 204); unknown stage → `"light"` (line 315, invents stage info); dedup tolerance ±1 h against **any** source (line 345-364) silently drops legitimate imports; naive un-quoted CSV split; `TimeZone.current` date parsing. Either delete `PillowDataImporter` + `DataImportView` (and the Settings copy that mentions Pillow, `CLAUDE.md`), or fix all five before exposing. Effort: Small (delete) / Medium (fix).
- ✅ **Done 2026-07-09** — chose deletion. Removed `PillowDataImporter.swift` and the unreferenced `DataImportView.swift` (its only `DataImportView` mentions were an internal row type and its `#Preview`), plus the `.pillow` case in `SleepDataSource`, `RealDataManager`'s `pillowImporter`/pillow source count/now-unused `fetchSessions(containing:)`/`ImportSummary.pillowSessions`, the Settings "Pillow: N sessions" row, `AppConstants.DataProvenance.pillow{CSV,JSON}Import`, and the CLAUDE.md copy. The `"Pillow Import"` test fixture stays (legacy shipped stores hold that identifier; those sessions must still survive `clearMockData`). ZeezTests 162/162 green.

**B3. Retire fabricated conveniences in `SleepSession+Extensions`** — Medium · Claims/Maintainability
`Zeez/Sleep/SleepSession+Extensions.swift`: `sleepEfficiency` (lines 98-101) is mathematically always 100 (`timeInSleep == timeInBed`); `timeToFallAsleep` (45-53) falls back to a fabricated 25-minute constant; `totalSleepCycles` (135-142) is `stageCount / 4`; `timeInSleep` is really the recorded interval and its name invites rule-7 violations (see B4). Also the watch payload sends the never-written `completedCycles` and raw `environmentalScore` fields (`WatchConnectivityHandler.swift:18-19`) that the watch ignores. Delete the unused, rename the interval property (e.g. `recordedInterval`), and route callers through `DerivedSleepMetrics`. Effort: Medium.
- ✅ **Done 2026-07-09** — deleted the unused fabrications (`sleepEfficiency` ≡ 100, `timeToFallAsleep`'s 25-min fallback, `totalSleepCycles` = stageCount/4, `TimelyData`/`timelyData`, `averageEnvironmentalScore`, and `SleepInfoComponents.timeAwake` ≡ `timeInBed - timeInSleep` ≡ 0) plus the now-orphaned `AppConstants.Sleep.defaultREMLatency`; renamed `timeInSleep` → `recordedInterval` with a doc comment pointing efficiency/asleep consumers at `DerivedSleepMetrics`, and dropped `timeInBed` (an alias of the same interval). Relabeled `SleepInfoCard`'s "Time in sleep" → "Session duration" (rule 7). The watch payload's `completedCycles`/`environmentalScore` were already gone as of A5; `WatchSleepSummary`'s envelope shape is unchanged. ZeezTests 162/162 green; watch target builds.

**B4. "Average time asleep" labels a session-interval metric** — Medium · Claims
`Zeez/Views/TrendsView.swift:99` — the Duration trend card's subtitle says "Average time asleep" but `fetchSleepDurations()` (251-257) uses `end - start` for every source. Contract rule 7. Fix the label to "Average recorded session duration" (or compute qualified asleep for AH sessions). Effort: Small.
- ✅ **Done 2026-07-09** — Duration card subtitle is now "Average recorded session duration"; the chart's `accessibilityLabel`/`accessibilityValue` carried the same "time asleep"/"duration" claim to VoiceOver and were reworded to match (rules 4 and 7 bind accessibility output too). `fetchSleepDurations()` now reads `session.recordedInterval` with a comment stating it is not qualified asleep time. ZeezTests 162/162 green.

**B5. Noise units fiction (promoted)** — Medium · Claims
`EnvironmentalMonitor.captureNoiseLevel` (149-165) stores a normalized 0–100 of `averagePower`; UI labels it dB; mocks generate real 20–55 dB. Pick one story (recommended: store true dBFS-derived approximation or relabel as "relative noise index 0–100"), align monitor, UI, mocks, and `EnvironmentalAnalyzer` thresholds (e.g. `> 40` comparisons assume dB). Effort: Small-Medium.
- ✅ **Done 2026-07-09** — chose the relative index. New `Environment/NoiseIndex.swift` is the single source of truth (dBFS→0–100 conversion, `quietCeiling`/`elevatedFloor`/`variabilityThreshold`, `displayUnit = "of 100"`), documented as uncalibrated and explicitly not dB SPL. Aligned in one commit: `EnvironmentalMonitor.captureNoiseLevel`; the one live label (`EnhancedSleepDetailsView` "Noise Level … dB" → "Relative Noise Index … of 100"); the dead-but-labeled env views (`EnvironmentalDataView`, `AverageEnvironmentalReadingView`, `EnvironmentalInsightsView`, `EnvironmentalFactors`) incl. their VoiceOver strings; `EnvironmentalAnalyzer`'s `> 40`/`> 10` thresholds and its "<40 dB ideal" copy; `SleepRecommendationSystem`'s `> 50` (also switched to the `measured*` accessors); and `MockEnvironmentalPatternGenerator`, which emitted real 20–55 dB. Deleted the unused `AppConstants.Environmental.{minimum,maximum}NoiseLevel` dB constants. `EnvironmentalFactor` keeps real dB for the *educational* Learn screens, with a doc comment forbidding reuse on stored readings. New `NoiseIndexTests` (8 vectors: silence/full-scale/midpoint/clamping/monotonicity/threshold ordering/mock scale/unit is not "dB"); `MockDataTests` range assertion updated — it had been pinning the dB fiction. ZeezTests 170/170 green.

**B6. `SleepInformationView` claims drift** — Medium · Claims
`Zeez/Sleep/SleepInformationView.swift:178-214`: Time Breakdown shows "Light Sleep" for Apple-Health Core stages (no `displayName(reportedByAppleHealth:)`, no provenance line), silently omits `asleepUnspecified`, and uses the session interval as the percentage denominator; the view also carries its own efficiency calculation instead of `DerivedSleepMetrics.sleepEfficiency` (in-bed denominator). Consolidate on `DerivedSleepMetrics` + source-aware stage names. Effort: Medium.
- ✅ **Done 2026-07-09** — the efficiency section now reads `DerivedSleepMetrics.sleepEfficiency` (reported-`inBed` denominator) and shows "Derived Sleep Efficiency" + provenance when available, otherwise the recorded interval with an explicit unavailable reason; the view's own `calculateEfficiency`/`timeInBed`/`timeInStage` helpers are gone. "Time Breakdown" became "Sleep Stage Composition", sourced from `asleepStageComposition`: the denominator is staged sleep (disclosed inline), `inBed`/awake are excluded, `asleepUnspecified` has its own row, stage names go through `displayName(reportedByAppleHealth:)`, and the provenance line uses `stageSourceDescription`. Apple-reported awake time is shown alongside — never inside the denominator — with the Apple Watch boundary-awake disclosure (rule 8). Added `accessibilityValue` to `TimeBreakdownRow`. New `SleepInformationViewTests` (5 tests) pins the stage-order constant so no asleep stage can vanish again and that `asleepUnspecified` is never renamed. Note: this view is currently unreachable (no callers outside its `#Preview`) — fixed rather than deleted per the tracker; a candidate for the C2 dead-code sweep. ZeezTests 175/175 green.

**B7. Remove prohibited "recovery / consult a professional" vocabulary** — Medium · Claims/Content
`Zeez/Sleep/Debt/DebtSeverity.swift` ("consult a healthcare professional", recovery plans), `SleepDebtMetrics.recoveryPlan`, `TrendInsightsSection.RecommendationsView` ("Weekly Sleep Debt", "Recovery Timeline", "return your sleep schedule to normal"). Currently dormant (TrendsView pins `sleepMetrics = nil`), but one line re-wires it. Replace the vocabulary with goal-shortfall wording or delete the types. Effort: Small.
- ✅ **Done 2026-07-09** — deleted the dormant clinical machinery: `DebtSeverity` (graded severity + health-risk "impacts" + "consult a healthcare professional"), `SleepDebtMetrics`/`RecoveryPlan`/`DebtTrend`, `RecommendationsView` ("Weekly/Monthly Sleep Debt", "Recovery Timeline"), the unreachable `LearnSleepDebt{History,Detail}View`, `SleepAnalysisTypes.{getDebtSeverity,calculateRecoveryDays}`, and `MonthlyTrendsView.getSeverity` (already uncalled). `TrendsView` lost its permanently-nil `sleepMetrics` plumbing. Two **live** violations surfaced beyond the tracker's list and were fixed: `SleepGoalSettingsView` showed "Weekly Sleep Debt" over a value that was already `totalShortfall` (now "Weekly Sleep Goal Shortfall"), and its "Get Personalized Recommendations" button — promising advice from age/activity data the app never collects — set state with **no sheet attached**, so it was deleted. Also relabeled `SleepDetailView`/`SleepInfoGuideView`/`MonthlyTrendsView` copy and renamed `MonthlyInsight.significantSleepDebt` → `.belowSelectedGoal` (its description was already goal-shortfall wording). New `ClinicalVocabularyGuardTests` source-scans every non-Learn tree for the prohibited phrases and for the deleted type names; it caught two stale comments in `AppConstants`/`MockDataGenerator` during the run. `LearnSleepDebtView` (live, educational, NHLBI framing) is intentionally exempt, as is Core Data / error "recovery". `DailyMetrics.sleepDebt` stays: it is a persisted attribute and renaming it needs a model version. ZeezTests 178/178 green.

**B8. Quality-score spec: duration weighting, missing-input policy, derived confidence (promoted)** — Medium · Claims
`Zeez/Sleep/Quality/SleepQualityCalculator.swift` (85/75/85/85 neutral defaults on missing sub-inputs; count-based stage distribution), `SleepAnalyzer.swift:120` (`confidenceScore = 85.0`). Write the Tier-3 score spec the contract requires, weight by duration, and make missing sub-inputs shrink coverage/confidence instead of defaulting. Effort: Medium.
- ✅ **Done 2026-07-09** — wrote `ZEEZ_SCORE_SPECIFICATION.md` (repo root, live contract; version `ZeezScore-3.0`) covering scope, components/weights, bands, missing-input policy, confidence, versioning, and an explicit "no dataset/device evaluation has been run" validation-status table. New `Sleep/Quality/ZeezScore.swift` holds the version, `ZeezScoreComponent` (weights + `isRequired`), and `ComponentResult`; `QualityMetrics` now carries `components`, `inputCoverage`, `confidence`, `version`. `SleepQualityCalculator.calculateMetrics()` returns **`QualityMetrics?`**: every component is available-or-unavailable (no 85/75/85/85 defaults), `duration` + `stageDistribution` are required, coverage has a 60% floor, and the composite renormalizes over available weights. Stage distribution is now **duration-weighted** (`asleepUnspecified` stays in the denominator, never redistributed). `efficiencyScore` became `sleepOpportunityScore` — same 0.30 weight, but the denominator is the recording window, so it must not be called sleep efficiency (rule 6); it also now sums asleep intervals instead of `window − awake`, which had counted unlabeled gaps as sleep. `SleepAnalyzer` persists `qualityMetrics.version`/`confidence` and writes the 1.0 sentinel when no estimate is possible, replacing `confidenceScore = 85.0`. Renamed to `ZeezScoreComponent` to avoid a collision with `EnhancedEnvironmentalScoring.ScoreComponent`. Rewrote `SleepQualityCalculatorTests` as the spec's deterministic vectors (14 tests, incl. weights-sum-to-1, no-estimate cases, renormalization, duration-weighting, unspecified dilution, and the confidence ladder 70/85/100). ZeezTests 186/186 green. CLAUDE.md updated.

**B9. HR downsampling on import (promoted)** — Medium · Performance/Storage — see §3. Effort: Medium.
- ✅ **Done 2026-07-09** — new `DataImport/HeartRateDownsampler.swift` buckets samples into 60-second windows anchored to absolute time (so import order cannot change bucketing) and stores the per-bucket mean. Storage is now a function of session length, not source sampling density: an 8-hour night can never exceed 480 rows. Wired into both writers — `HealthKitDataImporter.importHeartRateData` and `SleepSessionManager.syncWithHealthKit` — so a session's resolution does not depend on how it was created. The doc comment records the fidelity trade-off (`restingHeartRate` now averages per-bucket means, smoothing isolated troughs). New `HeartRateDownsamplerTests` (8 tests, incl. a 28,800-sample night collapsing to 480 rows and a curve-preservation vector). Respiratory samples are left alone — they are already sparse. ZeezTests 194/194 green.

**B10. Import completion + partial-failure UX (promoted)** — Medium · UX/HealthKit — `HealthKitDataImporter.importHeartRateData/importRespiratoryData` are fire-and-forget; `SimpleDataImportView` can report success while related data failed. Use a DispatchGroup/async let and surface per-type results. Effort: Medium.
- ✅ **Done 2026-07-09** — `importSleepData` now completes with a `HealthKitImportResult` (`sessionCount` + a `RelatedDataOutcome` per data type: `.imported(readingCount:)` / `.unavailable` / `.failed`). Both sub-imports take completions that fire on every path (including the `guard let self` and objectID-resolution failures that previously returned silently), and `importRelatedData` gathers them across all sessions with a `DispatchGroup` + `NSLock` before the caller's completion runs. Sessions are still saved before related data is fetched, so a sub-import failure degrades the *report*, not the import. `SimpleDataImportView.statusMessage(for:)` is a pure static that names each data type and its reading count, distinguishes "none recorded" from "not available on this device" from "could not be imported", and tells the user their sessions were kept and to retry; status colour is now driven by the outcome rather than by substring-matching "Error". `RealDataManager` logs partial failures. New `ImportResultReportingTests` (9 tests). ZeezTests 203/203 green.

**B11. First-run empty dashboard routes to import (promoted)** — Medium · UX — see §3. Effort: Small-Medium.
- ✅ **Done 2026-07-09** — new `Views/Dashboard/DashboardEmptyStateCard.swift` replaces the empty weekly-progress/metrics/info cards with a single "Import from Apple Health" call to action routed through the existing `ModalCoordinator.present(.dataImport)` (which `RootView` already maps to `SimpleDataImportView`); the Learn cards stay. Emptiness is decided by a **second** `@FetchRequest` with `fetchLimit = 1` over all completed sessions — `recentSessions` only covers the last month, so it cannot tell "first run" from "a quiet month". ZeezTests 203/203 green. **Rendering is not covered by tests** — added to §5 as a simulator/device check.

**B12. Sleep goal card shows hardcoded values** — Medium · UX/Trust
`Zeez/Sleep/SleepControlView.swift:158,174` — "10:30 PM" and "8h 00m" are string literals, ignoring the user's saved goal (`UserPreferences.targetBedtime` / Settings sleep-goal section). Bind to preferences or drop the card. Effort: Small.
- ✅ **Done 2026-07-09** — the card now reads a `UserPreferences` `@FetchRequest`: bedtime from `targetBedtime`, duration from `SleepGoalPolicy.duration(from:to:)` (falling back to the persisted `targetSleepDuration`). When no goal is saved, or `sleepGoalEnabled` is off, both read **"Not set"** rather than a plausible default — a goal is a user selection, so a fabricated one is exactly the rule-4 failure. Accessibility labels interpolate the real values instead of the hardcoded "10:30 PM"/"8 hours". `SleepGoalPolicy`'s overnight wrap is already covered by `SleepDebtTrackingTests`. ZeezTests 203/203 green.

**B13. HealthKit auth scope drift** — Low · Privacy
`SleepSessionManager.requestHealthKitAuthorization` (108-113) requests `restingHeartRate`, which nothing imports; onboarding/importer request the minimal 3-type set. Consolidate to one auth helper with the minimal set. Effort: Small.
- ✅ **Done 2026-07-09** — new `DataImport/HealthKitAuthorization.swift` owns the read scope (`sleepAnalysis`, `heartRate`, `respiratoryRate`) and both the completion-handler and `async` request forms; `SleepSessionManager`, `HealthKitDataImporter`, and `OnboardingManager` all route through it, so `restingHeartRate` is no longer requested. Force-unwrapped `HKObjectType` lookups became safe inserts. New `HealthKitAuthorizationTests` pins the scope to exactly those three types and asserts `restingHeartRate` is absent. ZeezTests 206/206 green; iOS and watch targets build.

### Phase C — early post-release / opportunistic

**Status: complete (2026-07-09).** C0–C4 and C6 landed one commit per item on
`feature/sleep-simplification` (`614284c`…`5a7fe1c`); **C5 is deferred by decision**, not
outstanding, and remains tracked in `FUTURE_IMPROVEMENTS.md`. Baseline moved from 206 tests /
33 suites to **218 tests / 36 suites, all green**; iOS and watch targets build. New live
document: `PARKED_CAPABILITIES.md` (C0). Two defects were found *while* implementing and fixed
in their own right: a latent clock-dependent flake in `SleepQualityCalculatorTests` (`a77cad9`,
product code untouched) and a provenance bug where legacy `"iPhone"` mock sessions counted as
real data (folded into C6 — see its note). Phase D not started — awaiting explicit approval.

**Scope decisions taken with Daniel before implementation (2026-07-09):** `SleepInformationView`
is **kept** (B6 made it correct and `SleepInformationViewTests` pins its stage-composition
contract), the environmental cluster (`EnvironmentalAnalyzer`, `EnvironmentalInsightsView`,
`EnhancedEnvironmentalScoring`, `EnvironmentalRecommendationTracker`) is **left in tree** as a
deliberately parked subsystem, and **C5 stays deferred**. Everything C2 deletes is registered in
`PARKED_CAPABILITIES.md` first (C0).

**C0. Removed capabilities were never logged as future work** — Medium · Process
Surfaced while scoping C2. `FUTURE_IMPROVEMENTS.md` (the live tracker) never recorded the HRV section (A1), the Pillow importer (B2), or sleep debt/recovery (B7), and is stale in both directions: it still lists five items Phase B completed and still describes `Zeez/Widgets/`, deleted in B1. The only record of *why* each was removed lives in this file's ✅ notes — and this file is headed for `Archive/` exactly as `IMPROVEMENT_ROADMAP.md` was. Deletions are correct; losing their rationale is not.
- Fix: a doc-only commit before any further deletion. New live register `PARKED_CAPABILITIES.md` (spec stub per capability: what it did, why removed, recovery command, inputs required, claims tier + label, missing-input policy, validation status, definition of done); repair `FUTURE_IMPROVEMENTS.md`; fix `CLAUDE.md`'s stale `Sleep/Debt/` row.
- Effort: Small (docs). Validate: none needed; no code changes.
- ✅ **Done 2026-07-09** — new `PARKED_CAPABILITIES.md` (live register) with seven spec-stub entries: HRV timeline (A1), Pillow import (B2), sleep debt/recovery (B7), real WidgetKit extension (B1), personalized recommendations (C2), the dead detail/trends/environmental views (C2), and the environmental-correlation subsystem — the last **parked in tree, not deleted**, quoting `generateMonthlyInsights`'s gating comment so a future reader cannot mistake it for abandoned code. Recovery is documented SHA-free (`git log --diff-filter=D -- <path>`). Repaired `FUTURE_IMPROVEMENTS.md`: struck the five items Phase B shipped (B5/B8/B9/B10/B11) with their IDs, corrected the `Zeez/Widgets/` description, tagged the survivors with their D-phase numbers. Fixed `CLAUDE.md`'s stale `Sleep/Debt/` directory row (B7 removed that directory) and pointed the claims paragraph at the new register. Doc-only; ZeezTests untouched at 206/206.

**C1. Double start of monitors on session start** — Low · Runtime — `SleepSessionManager.startSession` (47-48) and `SleepControlView.prepareSession` (201-202) both call `startMonitoring`. Harmless today (stop-then-start) but wasteful and permission-prompts twice. Remove one call site. Effort: Small.
- ✅ **Done 2026-07-09** — removed the `EnvironmentalMonitor`/`MovementDataManager` `startMonitoring` pair from `SleepControlView.prepareSession`, leaving `SleepSessionManager.startSession` as the sole owner: A4 had already removed the same pair from `BackgroundTaskManager.updateActiveSleepSession`, and `startSession` is the foreground path's single entry point. The mic pre-prompt (`checkSensorAvailability`) stays. New `SessionMonitorLifecycleGuardTests` (source-scan via `#filePath`, the A1/B7 pattern) asserts `startSession` still starts both monitors *and* that neither `SleepControlView` nor `BackgroundTaskManager` starts them again — the invariant, not just the current text. ZeezTests 208/208 green.
- Note: the first full run after adding those two guards exposed a **pre-existing flake** in `SleepQualityCalculatorTests.unavailableOptionalComponentRenormalizes` (fixture built its 8-hour window from two `Date()` reads, so the opportunity ratio was 0.49999999998 rather than 0.5 when they straddled a microsecond). Fixed in its own commit by anchoring the suite to a fixed instant; product code untouched. The score suite is the one the claims contract calls "deterministic test vectors", so a clock-dependent vector was a defect in its own right.

**C2. `DataQualityReport` traps on empty input** — Low · Runtime — `RealDataManager.swift:301` `0..<(count-1)` crashes when `sessions` is empty (the error path at line 245 constructs exactly that). Currently dead code — fix the guard or delete the type with the dead-code sweep (`analyzeDataQuality`, `importAllAvailableData`'s unused Pillow/manual fields, `SleepRecommendationSystem` — no view references). Effort: Small.
- **Scope corrections found by grep before implementing** (the tracker's line numbers predate A/B and its assumptions were narrower than reality): `importAllAvailableData` is *wholly* dead, not just its unused fields — nothing calls it, so `ImportSummary` and `RealDataManager.healthKitImporter` go with it. `SleepRecommendationSystem` is the sole consumer of `SleepRecommendationGenerator.swift` and `SleepRecommendationTypes.swift`, making it a three-file cluster. `HealthKitDataImporter.checkImportStatus` — half of **C6** — has zero callers, so it is deleted here rather than optimized there. `SleepDetailView` is the sole consumer of `AverageEnvironmentalReadingView`. Phase B also flagged `MonthlyTrendsView`, `EnvironmentalDataView` and `EnvironmentalFactors` as unreachable; confirmed, and deleted. `MonthlyTrendsDataProvider`/`TrendInsightsSection`/`MonthlyChartSection` are **live** via `TrendsView` and stay.
- ✅ **Done 2026-07-09** — deleted eight files (`SleepDetailView`, `MonthlyTrendsView`, `EnvironmentalDataView`, `EnvironmentalFactors`, `AverageEnvironmentalReadingView`, and the `SleepRecommendation{System,Generator,Types}` cluster) plus the inert plumbing: `analyzeDataQuality`/`DataQualityReport` (the `0..<(count-1)` trap — deleted rather than guarded, since the only construction site was its own error path), `importAllAvailableData`/`ImportSummary`/`RealDataManager.healthKitImporter`, `checkImportStatus`, and `shouldUseMockData`. The last of those cascaded: it was the sole caller of `getUserPreferences`, which was the sole reader of `UserPreferences.useMockData` — a stub whose getter always returned `nil` and whose setter did nothing, so the "use mock data" preference had never once been consulted. `SleepRecommendationSystem`'s deletion is **claims-motivated**, not hygienic: `AgeGroup.recommendedSleepRange` and `ActivityLevel.sleepAdjustment` determined physiological sleep *need* from inputs the app never collects (Tier 4). `ClinicalVocabularyGuardTests` gained a `recommendationEngineStaysDeleted` test pinning all three symbol names. Kept per the pre-implementation decisions: `SleepInformationView` + its tests, and the whole environmental cluster (`EnvironmentalAnalyzer`, `EnvironmentalInsightsView`, `EnhancedEnvironmentalScoring`, `EnvironmentalRecommendationTracker`), which is deliberately parked rather than dead — so `MonthlyInsight.environmentalImprovementNeeded` and its switch arms stay and **no live file was touched**. All eight deletions are registered in `PARKED_CAPABILITIES.md` (C0). ZeezTests 209/209 green; iOS target builds.

**C3. `scheduleAllAlarms` drops concurrent requests** — Low · Alarm — `AlarmScheduler.swift:54-57` skips (rather than coalesces) a reschedule that arrives mid-flight; a stale-state window if an edit lands during launch rescheduling. Queue a trailing rerun instead. Effort: Small.
- ✅ **Done 2026-07-09** — `scheduleAllSnapshots` now parks a mid-flight request in `pendingSnapshots` (last writer wins — every pass rewrites all alarm-owned notifications from scratch) and drains it where `isSchedulingInProgress` clears; the drain re-enters `scheduleAllSnapshots`, which re-dispatches onto `schedulingQueue`, so it cannot deadlock. `pendingSnapshots` is confined to that queue like the flag, and the `@unchecked Sendable` rationale comment was updated to say so. New `AlarmRescheduleCoalescingTests` (2 tests): a reschedule arriving mid-flight is rerun rather than dropped, and three mid-flight requests collapse into exactly one trailing rerun. Both were **verified to fail against the pre-fix scheduler** (the second alarm was never scheduled at all). `FakeNotificationCenter` gained an opt-in `holdPendingRequests`/`releaseHeldPendingRequests()` pair — the scheduler does all its work inside the `getPendingNotificationRequests` completion, so capturing that completion is what makes the race observable; it is off by default, so no existing suite changes behaviour. Passes are counted via `removeCalls`, not `getPendingNotificationRequests` calls: the latter is also called by the deferred budget audit and once per alarm inside `scheduleFollowUpChain`, so it would have measured the wrong thing. ZeezTests 211/211 green.

**C4. Watch target uses `print`** — Low · Maintainability — `WatchConnectivityManager.swift:164,177,193` etc.; add a small os.log wrapper to the watch target (ZeezLogger is iOS-only). Effort: Small.
- ✅ **Done 2026-07-09** — new `ZeezWatch Watch App/WatchLogger.swift` with `connectivity` and `haptics` categories, mirroring `ZeezLogger`'s conventions exactly: `debug` compiled out of release builds, `info`/`error` marking interpolations `.public` (os_log redacts non-literals to `<private>` in release, which makes a TestFlight sysdiagnose useless). Deliberately **not** placed in repo-root `Shared/`, which is a synchronized group compiled into both targets and is kept free of platform imports — it still imports only `Foundation`. Replaced all six `print` calls: four in `WatchConnectivityManager` (connection loss → `info`; the three `sendMessage` error handlers → `error(_:_:error:)`, which now log the underlying `Error` rather than only its `localizedDescription`) and two chatty ones in `WatchHapticManager` (the tracker's "etc.") → `debug`. No new-SDK symbols, so no `#if compiler(>=6.2)` gate needed. Watch target builds; ZeezTests 211/211 green.

**C5. Alarm health indicator in `AlarmSettingsView`** — from FUTURE, keep post-release. **Confirmed deferred (2026-07-09):** out of Phase C scope. It is the only C item that adds UI rather than removing or fixing something, and §2 already lists it under "Stay deferred". Remains in `FUTURE_IMPROVEMENTS.md`.
- ✅ **Done 2026-10-20** (post-Phase D, while the device pass waited on the developer account) — `AlarmHealth` compares enabled alarms against the pending notification requests: count scheduled, next ring (earliest main or snooze), and any enabled alarm with **no pending main**, which the scheduler can leave behind silently (e.g. it refuses an alarm with no selected days and only logs it). Missing notification permission outranks everything. `AlarmSettingsView` reads it on appear, 2 s after any alarm change (so a mid-flight remove-then-add reschedule is not misread as missing), and on returning to the foreground. New `AlarmHealthTests` (7), two against the real scheduler via `FakeNotificationCenter`.

**C6. `checkImportStatus`/`getDataSources` fetch full objects to count** — Low · Performance — use `count(for:)`/aggregate fetches. Effort: Small.
- Reduced in scope: `checkImportStatus` is dead and is deleted by C2, so this item covers `getDataSources` (live, called from `SettingsView.swift:207`) only.
- ✅ **Done 2026-07-09** — `getDataSources` no longer materializes a single `SleepSession`: each provenance bucket is a `count(for:)` plus a one-row `createdAt` fetch (`fetchLimit = 1`, descending, `.dictionaryResultType`). Previously it fetched three full object graphs to read `.count` and `max(createdAt)`, so opening Settings after a 90-day import faulted in thousands of rows to display two numbers. The three predicates are now defined once and shared with `clearMockData`. `hasRealData`'s two diagnostic table scans moved inside `#if DEBUG` — `ZeezLogger.debug` compiles out of release builds but the queries feeding it did not. `RealDataManager` gained an injectable `init(persistenceController:)` (the `SleepAnalyzer`/`SleepSessionManager` pattern) so the counting logic is testable. New `DataSourceSummaryTests` (7 tests). ZeezTests 218/218 green.
- **A pre-existing correctness bug surfaced while testing this item, and was fixed here.** `nonMockPredicate` excluded only the `"Mock Data"` marker and `nil`, not the legacy `"iPhone"` device — which `AppConstants` documents as an early-mock-build marker and which `clearMockData` deletes as mock. So legacy mock sessions counted as **real**: the `.manual` and `.mock` buckets overlapped (5 sessions summed to 6), and `hasRealData()` returned `true` for a store containing nothing but fabricated sessions, putting Settings' "Using your real sleep data" banner above mock data. `nonMockPredicate` is now literally `NOT mockPredicate`, so the two partition the store. Verified by reverting: three assertions fail against the old predicate. This is a claims-adjacent fix — the banner asserted provenance that was not true.

### Phase D — architecture / longer term

**Scoped and resequenced 2026-07-09.** Nothing in Phase D is a bug fix and nothing in it unblocks
§5. The app has never run on a device, so the only work that belongs *before* the device pass is work
that touches no app behavior (D4) or that becomes materially more expensive afterward (D3a). Everything
else is post-TestFlight. D3 was three unrelated things and is split below.

Two audit findings drove the order:

- **The store location is a one-way door.** `PersistenceController` opened the store at the default
  app-container URL and the project had no App Group. A WidgetKit extension can only reach Core Data
  through a group container. Relocating is nearly free while no user has data and becomes a migration
  against real history afterward — so D3a is the *most* urgent item in the phase, not the least.
- **There are no deep links in this app.** No `onOpenURL`, no universal links, no `widgetURL`. The alarm
  "deep link" is `AlarmNotificationHandler` posting to `NotificationCenter`, which `RootView` turns into
  a `fullScreenCover` outside the nav stack. `ModalCoordinator`'s only sheet does not wrap itself in
  `NavigationView`. Zero of ~56 `NavigationLink`s use the `isActive:`/`tag:selection:` initializers that
  break under `NavigationStack`. The watch app has no navigation containers at all. D1 is therefore much
  safer than assumed — and worth less: `NavigationView` is deprecated but works on iOS 18.1, so D1
  changes nothing a user or App Review sees.

**Order:** D3b (paperwork, async) → **D3a** → **D4** → D3d → *stop for the §5 device + paired-watch pass
and TestFlight* → D2a → D2b → D1a → D1b → D1c → D3c.

**D1. NavigationView → NavigationStack.** 88 occurrences in 67 files. Split by behavior, not file count.
- **D1a** (~4 files, the only part with observable behavior): `MainView.swift:6` wraps a `NavigationView`
  around the whole `TabView`, with `.navigationViewStyle(.stack)` as the escape hatch, and `LearnView`
  nests its *own* `NavigationView` inside it. `DashboardView` and `AlarmSettingsView` have no container
  and resolve their titles and `NavigationLink`s against MainView's ambient one. Remove the outer
  container; give each tab its own `NavigationStack`. Also delete `LearnHomeView` (unreachable, and it
  nests a `NavigationView` inside its own `NavigationStack`, so it is not a model to copy) and register
  it in `PARKED_CAPABILITIES.md`. Risk is confined here: get it wrong and the Dashboard/Alarm navigation
  bars vanish, or double-nesting reintroduces the ambiguous-element failure `SceneDelegate` documents.
- **D1b** (~40 sites): mechanical swap in `.sheet`/`.fullScreenCover` wrappers, one commit per tree
  (Learn alone is ~45 of the 88).
- **D1c** (~30 sites): `#Preview` / `PreviewProvider` bodies. One commit, zero risk.

**D2. Singleton graph → protocol injection.** Extend the existing convention — a product-side protocol
plus a `= .shared` / `= .current()` default parameter, faked by a lock-guarded `@unchecked Sendable` test
double — as established by `AlarmNotificationScheduling` + `FakeNotificationCenter`.
- **D2a** `WatchConnectivityHandler`: `WatchSessionProtocol` covering exactly the members used
  (`isSupported`, `delegate`, `activate`, `isReachable`, `isPaired`, `isWatchAppInstalled`, `sendMessage`,
  `updateApplicationContext` — **not** `transferUserInfo`, which A5 deleted), plus an injected
  `PersistenceController`. A2 and A5 rewrote `fetchWatchPayloads`' Core Data path and **nothing tests it**;
  `WatchWireContractTests` covers the envelope shape, not the fetch. Note while there: the type is an
  `ObservableObject` with four `@Published` properties and no SwiftUI observer anywhere.
  - ✅ **Data half done 2026-10-20** — `fetchWatchPayloads` moved to `Zeez/Watch/WatchPayloadBuilder.swift`
    with an injected `NSPersistentContainer` (the `SleepAnalyzer.analyzeSleepSession(objectID:container:)`
    pattern); `WatchPayloadBuilderTests` (6) run it on an in-memory store. Testing it found a real bug: the
    "next alarm" was chosen by sorting `AlarmConfiguration.time`, whose date part is whenever the alarm was
    created or edited — so the oldest-dated alarm won, weekdays were ignored, and the past date on the wire
    hid the watch's countdown. It now sends the earliest `AlarmSnapshot.nextFireDate()`, and an explicit
    disabled status when nothing can ring. `updateAlarmContext` also used to forward whichever alarm was
    just saved (even a disabled one); it now re-reads the next alarm, deletions included.
  - **Still open:** the `WatchSessionProtocol` seam. It would unlock tests of `handleDataRequest`'s reply
    path and `sendMessage`'s priority→transport mapping, which still have none.
- **D2b** `AlarmAudioController`: 18 call sites, zero tests, and it is the alarm's last mile. Seam: an
  audio-session protocol (`setCategory`/`setActive`) and a player factory. Do not fake `Timer` — call the
  health-check directly. The device pass covers the happy path; it can never cover the watchdog restart,
  the five-retry cap, the system-sound fallback, or `.notifyOthersOnDeactivation` on stop.
- **Then stop. The stopping rule: inject a singleton only when doing so unlocks a test you cannot write
  today — never for purity.** Explicit non-targets: `ErrorManager` (13 sites) and `AnalyticsManager` (3)
  are sinks whose behavior nobody asserts; `ModalCoordinator`, `OnboardingManager`, and `StoreKitManager`
  are `@MainActor ObservableObject`s already observable by construction; `PersistenceController`'s
  remaining ~20 sites are app-lifecycle or already carry the default-parameter idiom; the ~30 Learn and
  Environment singletons are out of scope. **No repo-wide `.shared` sweep.**

**D3a. App Group + group-container Core Data store.** *Before the first TestFlight build.*
- 🟡 **Code landed 2026-07-09; verification blocked on a manual step.** New `CoreData/StoreLocation.swift`
  owns the group identifier, the store URL, and `relocateStore(from:to:)`, which uses
  `replacePersistentStore` + `destroyPersistentStore` (the only APIs that carry the `-wal`/`-shm` sidecars;
  WAL is on per 2.6 and history tracking is force-enabled). `PersistenceController.adoptAppGroupStore`
  runs **before** `configureStoreForMigration()`, which reads `description.url` and asks
  `CoreDataMigrationManager` about that store, so it must see the final location. Every failure path keeps
  the app-container store: a store the user can still read beats one the widget could have read.
  A relocated install records `appGroupAdoptedKey`; if the group later becomes unreachable the app now
  logs a **fault** instead of silently opening an empty store where the history used to be (relocation
  destroys the source, so a dropped entitlement would otherwise look like total data loss).
  New `StoreRelocationTests` (7 tests). `relocationCarriesAnUncheckpointedWAL` was **verified to fail**
  against a naive `moveItem` implementation — all four sessions were lost — which is what an unclean
  shutdown leaves behind; note the plain "sessions survive" assertion passes against the naive version
  too, because closing a store checkpoints its WAL. ZeezTests 225/225 green.
- ⚠️ **Blocked:** `xcodebuild` from the CLI signs simulator builds ad-hoc and strips every profile-backed
  entitlement — the built app embeds *no* entitlements at all, not even the pre-existing HealthKit and
  time-sensitive ones. So `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` and the
  code degrades to the app-container store. **Daniel must toggle App Groups once in Xcode's Signing &
  Capabilities pane for the `Zeez` target** so automatic signing registers `group.com.danielsparano.zeez`
  with the team. Until then D3a is inert. Do not mark complete before confirming, on device, that the
  store opens from the group container.

**D3b. Critical-alerts entitlement application.** Paperwork only, no code: `AlarmPermissionManager` already
requests `.criticalAlert` and `AlarmNotificationUtils` already degrades to `.timeSensitive` + `.default`.
File it early — Apple takes weeks — it blocks nothing.

**D3c. Real WidgetKit extension target.** *After TestFlight.* Needs genuine pbxproj surgery (the one place
filesystem-synchronized groups do not help). Bound by the claims contract: any score needs the
"Experimental Zeez Estimate" label in visible text **and** in `accessibilityValue` (rule 10), must honor the
`qualityScore <= 1.0` no-score sentinel rather than render a number, and must read environmental values
through the `measured*` accessors. Read `PARKED_CAPABILITIES.md` §4 and §6 first.

**D3d. Dormant sleep-product Phases 3–6.** *Not an implementation item.*
- ✅ **Done 2026-07-09** — doc-only. `FUTURE_IMPROVEMENTS.md` called these "unexecuted Phases 3–6",
  which was wrong in both directions: A–C delivered most of them under different names, and one phase
  diverged from the plan deliberately. Each phase in `Archive/SLEEP_REFACTORING_PLAN.md` now carries a
  status line. Phase 3 mostly landed via B9/B10/C6; Phase 4 via B4/B6/B7; Phase 5 substantially via B8
  plus A1/A7; Phase 6 is untouched research. Residue registered as spec stubs in
  `PARKED_CAPABILITIES.md` §8 (durable HealthKit sample identity; coverage reporting; a component
  breakdown the user can see) and §9.
- **Two findings the reconciliation surfaced, both recorded rather than fixed.** (1) Phase 5's exit
  criterion "the score can explain itself from components" is **not met**: `QualityMetrics.components`
  and `ZeezScoreComponent`'s weights never leave `SleepQualityCalculator`, so the score is still an
  opaque number on screen. (2) Phase 6's exit criterion "no production stage inference without a
  defensible evaluation" is in direct tension with what ships — `SleepStageAnalyzer` infers stages for
  every Zeez-recorded session and B8 made `stageDistribution` a *required* component, so the score rests
  on inference that has never been evaluated against a labeled reference. The "Experimental Zeez
  Estimate" label is a **disclosure, not a validation**, and `PARKED_CAPABILITIES.md` §9 now says so.
  Neither is a Phase D item; both need Daniel's decision.
- Also corrected: Phase 5's plan text says "use imported Apple stages for inputs first; do not start with
  Zeez-owned stage inference." The shipped design does the opposite on purpose — Apple Health sessions
  with source-reported stages are **never** scored, because grading a source's own output is the larger
  claims hazard (`ZEEZ_SCORE_SPECIFICATION.md` §2). Recorded as a divergence, not a defect.

**D4. CI.** Add a watch-app build job and a scheduled UI smoke job.
- ✅ **Done 2026-07-09** — shared the watch scheme (`xcshareddata/xcschemes/ZeezWatch Watch App.xcscheme`);
  only `Zeez.xcscheme` was shared, so CI could not build the watch app at all. `watch-build` uses
  `-destination 'generic/platform=watchOS Simulator'` rather than naming a simulator model whose name
  drifts between runner images. `ui-smoke` runs on `schedule` (07:00 UTC) + `workflow_dispatch` only,
  never on push — UI tests need a warm booted simulator and their failure modes are noisy enough to erode
  trust in a required check. It pins `-configuration Debug` because `OnboardingManager` and `ZeezApp` read
  their launch-argument overrides inside `#if DEBUG`, so a Release run would hang on onboarding, and it
  excludes `ZeezUITests`/`ZeezUITestsLaunchTests` (Xcode template boilerplate; `testLaunchPerformance`
  measures a cold runner). The `concurrency` group now keys on `github.event_name` so a nightly ui-smoke
  cannot cancel a push's unit-tests.
- **`testSleepTabLoads` was asserting pre-B11 behavior and had never run.** It waited for the
  "Sleep Metrics" header, with a comment claiming it was "present regardless of whether any sleep data
  exists" — true until B11 made `metricsSection` conditional on `hasAnySleepData` and replaced it with
  `DashboardEmptyStateCard` on an empty store. The test was wrong, not the app. Replaced with
  `testFirstRunDashboardShowsEmptyStateAndOpensImporter`, which asserts the card renders and its button
  routes to the importer — automating the first-run check §5 previously listed as manual. It needs a
  deterministic empty store, so `ZeezApp` gained a DEBUG-only `-uiTestResetStore` launch argument beside
  `OnboardingManager`'s existing ones; it calls `clearAllData()` from `init()`, before `WindowGroup` builds
  `RootView` and any `@FetchRequest` observes the old store. UI: 6/6 green. ZeezTests 225/225 green;
  watch target builds via the new shared scheme.
- **Pre-existing flake found while verifying, not fixed.** `StoreKitTests`' four `SKTestSession`-backed
  tests (`purchaseGrantsEntitledTier`, `entitlementResolvesWithoutLoadedProducts`,
  `upgradeResolvesToHighestTier`, `expiryDowngrades`) failed twice in a row after a UI-test run had left
  the app installed and running on the simulator; the run took 20.6 s instead of the usual 0.7 s, which is
  timeouts expiring. A controlled A/B — `ade6f20` versus HEAD, alternating, uninstalling the app before
  each run — passed **6/6 on both sides**, and D3a's only addition to that path is a `containerURL` call
  that returns `nil` in ~1 ms for an un-entitled process. So the trigger is simulator state (a live app
  instance contending for the StoreKit test session), not the Phase D diff. It matters anyway: CI's
  `unit-tests` job runs this bundle, and the suite is already marginal (`purchaseGrantsEntitledTier` takes
  ~12 s of a ~17 s suite). Worth hardening on its own — it is not a Phase D item.

## 5. Release-gating checklist

**Physical iPhone:** alarm E2E (force-quit, locked, chain cadence, Stop re-arms — after A6); mic-denied environmental path; HealthKit import of a real Apple Watch night (incl. `asleepUnspecified` display); record/end session with ConcurrencyDebug 1 (A3); delete-all-data walkthrough.
**First run (simulator is enough):** the empty-store dashboard and its route into the importer are now
covered by `MainViewUITests.testFirstRunDashboardShowsEmptyStateAndOpensImporter` in the `ui-smoke` CI job
(D4) — no longer a manual check. Still manual: after importing, confirm the metric cards return, and that
the importer's completion message names heart-rate and respiratory outcomes (B10).
**Paired Apple Watch:** summary push after a new session (**blocked by A5**), requestData refresh, wake-pattern haptics, snooze/stop from watch, offline cache behavior.
**App Store Connect:** create/confirm the 4 product IDs char-for-char; sandbox purchase + restore; airplane-mode launch keeps premium; privacy-policy URL live; App Privacy questionnaire = "no data collected" consistent with manifests. The HealthKit read scope is now exactly `sleepAnalysis`, `heartRate`, `respiratoryRate` (B13) — answer the questionnaire against that set, not the old four.
**App Group / store location (D3a):** toggle **App Groups** once in Xcode's Signing & Capabilities pane
for the `Zeez` target so `group.com.danielsparano.zeez` is registered with the team — CLI `xcodebuild`
strips profile-backed entitlements, so this cannot be done or verified from the command line. Then, on
device: confirm the log line "Relocated the Core Data store into the App Group container" appears once on
the first launch after upgrading, that sleep history survives it, and that it does **not** appear on the
second launch. A **fault**-level log ("previously adopted it") means the entitlement was dropped and the
app is about to open an empty store — treat it as a release blocker, not a warning.

**Organizer/archive:** validate archive; confirm no `NSCameraUsageDescription` needed (AVCaptureDevice fully removed); background modes = `processing` only.
**TestFlight:** several nights of real alarm/sleep usage; battery observation (watch heartbeat machinery until A5 cleanup).
**Accessibility:** VoiceOver pass over Dashboard, session details, Trends charts, watch app; confirm every score utterance carries "Experimental Zeez estimate"; Dynamic Type on dashboard cards. Phase B reworded several VoiceOver strings (Trends duration chart B4, noise index B5, stage composition B6, sleep-goal card B12) — re-listen to those.
**Environmental units:** noise is now a relative index 0–100, not dB (B5). On device, confirm the Sleep Details environmental row reads "Relative Noise Index … of 100" and that a mic-denied session shows unavailable rather than 0.
**Score behaviour:** a recorded session with sensor data but no inferrable stages must show **no** score (B8's `qualityScore = 1.0` sentinel), not a neutral one; a scored session's `SleepQualityScore.calculationVersion` must read `ZeezScore-3.0` and its `confidenceScore` must vary with sensor breadth rather than always being 85.
**Privacy/claims review:** re-read active surfaces against `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` now that B-phase has landed, and read `ZEEZ_SCORE_SPECIFICATION.md` alongside it (B8 — the spec is binding and must be re-checked whenever `ZeezScore.version` changes); review App Store description copy against both before submission. `PARKED_CAPABILITIES.md` (C0) records the claims bar each removed feature must clear before returning — check it before re-adding any surface, and never let App Store copy promise a capability listed there. `ClinicalVocabularyGuardTests` (B7) enforces the prohibited-vocabulary rules in CI, but it exempts `Zeez/Learn` — review Learn copy by hand.

## 6. Suggested validation commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,id=55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,id=55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF' -only-testing:ZeezTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# D4: exactly what CI runs
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'generic/platform=watchOS Simulator'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -configuration Debug -destination 'platform=iOS Simulator,id=55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF' -only-testing:ZeezUITests/MainViewUITests -only-testing:ZeezUITests/OnboardingUITests

# Threading verification for A2/A3/A4: add to the scheme's launch arguments
#   -com.apple.CoreData.ConcurrencyDebug 1
```

Recovering failures after the fact (xcodebuild's console output loses them):
```bash
xcrun xcresulttool get test-results tests --path ~/Library/Developer/Xcode/DerivedData/Zeez-*/Logs/Test/<run>.xcresult
```
If `StoreKitTests` fails, uninstall the app from the simulator and re-run before investigating — its four
`SKTestSession` tests flake when a live app instance contends for the StoreKit test session.

## 7. Prompt for the next implementation chat

Replaced 2026-10-20. The Phase A prompt that stood here is in git history (`git log -p -- SECOND_AUDIT_IMPROVEMENTS.md`).

```
Read CLAUDE.md, then PARKED_CAPABILITIES.md §8a, SLEEP_METRICS_CLAIMS_AND_VALIDATION.md (Tier 1
rows and §4 rules), and FUTURE_IMPROVEMENTS.md. Context: the device pass (DEVICE_TEST_RUN.md) is
blocked until my Apple Developer Program membership is renewed, so we are doing code work that
needs no hardware.

Task: durable HealthKit import identity (PARKED_CAPABILITIES §8a). Today
HealthKitDataImporter.sessionExists skips any night whose start is within 15 minutes of an
existing import, so a night Apple Health later extends or corrects is never picked up, and
re-import cannot update anything. This needs a Core Data model version, which, like the D3a
store move, is far cheaper before any user has data.

Work in this order and stop at each checkpoint:
1. Investigate first. Write failing Swift Testing tests (in-memory PersistenceController,
   existing importer test patterns, e.g. SleepImportGroupingTests) that demonstrate the
   real failure modes: re-import duplicates, re-import silently drops a changed night,
   overlapping sources. Report which ones actually fail today. CHECKPOINT: show me the
   findings before designing anything.
2. Propose the design: what identity is persisted (HKObject.uuid of samples and/or a
   stable per-night key), the merge policy for a night that changed, and the new model
   version (Zeez 3.xcdatamodel; lightweight migration; CoreDataMigrationManager). Include
   how it interacts with D3a's App Group relocation on first launch (DEVICE_TEST_RUN.md T1).
   CHECKPOINT: wait for my approval before adding the model version.
3. Implement in small commits, one concern each. Add a CoreDataModelV2→V3 migration test
   alongside CoreDataModelV2MigrationTests. Confirm each regression test fails against the
   unfixed code by temporarily reverting the fix.
4. After each commit: run -only-testing:ZeezTests; build the watch target before the last
   commit (commands in CLAUDE.md; use the simulator id, the name is ambiguous across runtimes).
5. Update PARKED_CAPABILITIES.md §8a, FUTURE_IMPROVEMENTS.md, and add a step to
   DEVICE_TEST_RUN.md T3 for the on-device re-import check.

Do not touch Zeez.xcodeproj/project.pbxproj's uncommitted changes (mine). Do not start other
tracker items without asking.
```

**Other open items, if §8a is not wanted next** (none needs hardware):
- **Claims/polish batch (small):** `MonthlyChartSection`'s "Estimated Score" segment lacks the experimental
  label; Trends' Days and Week ranges are the same 7-day window; the dead `WatchSleepSummary(from:)` bridge
  still sends a raw quality value; debug mock sessions get no `SleepQualityScore` record, so their score
  breakdown always reads unavailable.
- **D1a** NavigationView → NavigationStack in `MainView`/`LearnView`, and delete `LearnHomeView`. D1b/D1c are mechanical.
- **D2b** `AlarmAudioController` seam + tests, and the **D2a** `WatchSessionProtocol` seam (test-unlocking work).
- **Blocked on the renewed account:** D3c WidgetKit extension (needs the App Group), D3b critical-alerts
  application, App Store Connect products, StoreKit sandbox, TestFlight.
- **Not code, not blocked:** the privacy policy at `AppConstants.Legal` is still a placeholder URL and needs real content published.
