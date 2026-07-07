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
- Effort: Small. Validate: simulate BGTask with an active session (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.zeez.Zeez.sleepupdate"]`), ConcurrencyDebug 1.

**A5. Phone→watch push contract is broken end-to-end** — High · watchOS
`Zeez/Watch/WatchCommunicationSupport.swift:54-62` flattens payloads to top level (`command`, `duration`, …), but the watch's `handleDataUpdate` (`WatchConnectivityManager.swift:210-218`) only reads **nested** `message["sleepSummary"]` / `["alarmStatus"]`. Consequences:
- `syncSleepData`/`performFullSync`/`updateAlarmContext` pushes (medium priority → `updateApplicationContext`) are received and silently dropped; only the watch-initiated `requestData` reply (which nests keys, `WatchConnectivityHandler.swift:493-510`) works.
- The watch has no decompression, so any payload that trips `compressIfNeeded` is unreadable on that side.
- Heartbeats go out as `transferUserInfo` (`.low`), which the watch never handles (no `didReceiveUserInfo`), and `performSend` reports unconditional success for `.medium`/`.low` — so `connectionQuality` is fiction and userInfo transfers queue up against an unpaired watch.
- Fix: define one typed payload envelope in `Shared/WatchDataModels.swift`, encode/decode it on both sides, delete or drastically simplify the heartbeat/compression/quality machinery, and add contract tests that push a flattened message through the watch parser (extend `WatchModelRoundTripTests` — today it exercises the model, not the wire shape).
- Effort: Medium. Validate: contract tests + the already-open paired-device round trip (which, as written, would currently fail for pushed updates).

**A6. Follow-up chains are not re-armed on foreground** — High · Alarm
`Zeez/Alarm/AlarmObserver.swift:79-90` — the `willEnterForeground` reschedule is commented out (`TODO: Re-enable`). Chains are armed for the **next firing only** (`AlarmScheduler.scheduleFollowUpChain`), re-armed at launch/edit/Stop-action/time-change. A user who opens the app daily but never relaunches it gets no chain for any firing after the first — Heavy Sleeper protection silently lapses.
- Fix: re-enable a throttled reschedule on foreground (e.g. only when a chain's `chainStamp` is in the past); keep the debounce.
- Effort: Small. Validate: unit test — simulate foreground notification after `nextFire` passes, assert chain re-armed with a new stamp; device E2E already on the open list.

**A7. Zeez-recorded sessions get a fabricated score and are never analyzed** — High · Claims/Runtime
`Zeez/Sleep/SleepSessionManager.swift:64-71` sets `qualityScore = hoursSlept * 10` at session end. Because it's ≠ 0, the session is excluded from the analysis backlog (`BackgroundTaskManager.swift:465`, and `ZeezApp.verifyDataIntegrity`'s DEBUG check), and nothing calls `SleepAnalyzer` at session end — so no `SleepQualityScore` record is ever created and `hasDisplayableScore` stays false forever. Net effect: the app's own recorded sessions never show an estimate, and the fabricated 0–100 number pollutes every raw-`qualityScore` consumer (`RealDataManager.DataQualityReport`, `EnvironmentalRecommendationTracker.swift:90`).
- Fix: drop the `baseScore` write (leave 0 = awaiting analysis) and trigger `SleepAnalyzer.analyzeSleepSession(objectID:)` from `endSession`.
- Effort: Small. Validate: record ≥30-min mock session; assert a persisted estimate appears and dashboard card shows it.

### Phase B — fix before App Store submission

**B1. Delete the dead in-app "Widgets" tree** — Medium · Maintainability/Claims
`Zeez/Widgets/Widget.swift`, `WidgetContainer.swift`, `Zeez/Views/WidgetViews.swift`, `WidgetPickerView.swift` — unreachable; contains hardcoded "Room Temperature 20°C / Optimal" (`WidgetContainer.swift:131-137`), "Simplified debt tracking coming in Phase 2" (line 122), "accumulated sleep debt and recovery status" copy (line 167), and premium flags nothing enforces. (Promotion of the FUTURE item.) Effort: Small.

**B2. Decide the Pillow importer's fate; as written it violates the claims contract** — Medium · HealthKit/Claims
`Zeez/DataImport/PillowDataImporter.swift` is reachable only from `Zeez/Views/DataImportView.swift`, which itself is unreferenced (dead). Defects if ever wired in: missing quality → fabricated `75.0` (line 241); CSV quality fallback `duration × 12` (line 204); unknown stage → `"light"` (line 315, invents stage info); dedup tolerance ±1 h against **any** source (line 345-364) silently drops legitimate imports; naive un-quoted CSV split; `TimeZone.current` date parsing. Either delete `PillowDataImporter` + `DataImportView` (and the Settings copy that mentions Pillow, `CLAUDE.md`), or fix all five before exposing. Effort: Small (delete) / Medium (fix).

**B3. Retire fabricated conveniences in `SleepSession+Extensions`** — Medium · Claims/Maintainability
`Zeez/Sleep/SleepSession+Extensions.swift`: `sleepEfficiency` (lines 98-101) is mathematically always 100 (`timeInSleep == timeInBed`); `timeToFallAsleep` (45-53) falls back to a fabricated 25-minute constant; `totalSleepCycles` (135-142) is `stageCount / 4`; `timeInSleep` is really the recorded interval and its name invites rule-7 violations (see B4). Also the watch payload sends the never-written `completedCycles` and raw `environmentalScore` fields (`WatchConnectivityHandler.swift:18-19`) that the watch ignores. Delete the unused, rename the interval property (e.g. `recordedInterval`), and route callers through `DerivedSleepMetrics`. Effort: Medium.

**B4. "Average time asleep" labels a session-interval metric** — Medium · Claims
`Zeez/Views/TrendsView.swift:99` — the Duration trend card's subtitle says "Average time asleep" but `fetchSleepDurations()` (251-257) uses `end - start` for every source. Contract rule 7. Fix the label to "Average recorded session duration" (or compute qualified asleep for AH sessions). Effort: Small.

**B5. Noise units fiction (promoted)** — Medium · Claims
`EnvironmentalMonitor.captureNoiseLevel` (149-165) stores a normalized 0–100 of `averagePower`; UI labels it dB; mocks generate real 20–55 dB. Pick one story (recommended: store true dBFS-derived approximation or relabel as "relative noise index 0–100"), align monitor, UI, mocks, and `EnvironmentalAnalyzer` thresholds (e.g. `> 40` comparisons assume dB). Effort: Small-Medium.

**B6. `SleepInformationView` claims drift** — Medium · Claims
`Zeez/Sleep/SleepInformationView.swift:178-214`: Time Breakdown shows "Light Sleep" for Apple-Health Core stages (no `displayName(reportedByAppleHealth:)`, no provenance line), silently omits `asleepUnspecified`, and uses the session interval as the percentage denominator; the view also carries its own efficiency calculation instead of `DerivedSleepMetrics.sleepEfficiency` (in-bed denominator). Consolidate on `DerivedSleepMetrics` + source-aware stage names. Effort: Medium.

**B7. Remove prohibited "recovery / consult a professional" vocabulary** — Medium · Claims/Content
`Zeez/Sleep/Debt/DebtSeverity.swift` ("consult a healthcare professional", recovery plans), `SleepDebtMetrics.recoveryPlan`, `TrendInsightsSection.RecommendationsView` ("Weekly Sleep Debt", "Recovery Timeline", "return your sleep schedule to normal"). Currently dormant (TrendsView pins `sleepMetrics = nil`), but one line re-wires it. Replace the vocabulary with goal-shortfall wording or delete the types. Effort: Small.

**B8. Quality-score spec: duration weighting, missing-input policy, derived confidence (promoted)** — Medium · Claims
`Zeez/Sleep/Quality/SleepQualityCalculator.swift` (85/75/85/85 neutral defaults on missing sub-inputs; count-based stage distribution), `SleepAnalyzer.swift:120` (`confidenceScore = 85.0`). Write the Tier-3 score spec the contract requires, weight by duration, and make missing sub-inputs shrink coverage/confidence instead of defaulting. Effort: Medium.

**B9. HR downsampling on import (promoted)** — Medium · Performance/Storage — see §3. Effort: Medium.

**B10. Import completion + partial-failure UX (promoted)** — Medium · UX/HealthKit — `HealthKitDataImporter.importHeartRateData/importRespiratoryData` are fire-and-forget; `SimpleDataImportView` can report success while related data failed. Use a DispatchGroup/async let and surface per-type results. Effort: Medium.

**B11. First-run empty dashboard routes to import (promoted)** — Medium · UX — see §3. Effort: Small-Medium.

**B12. Sleep goal card shows hardcoded values** — Medium · UX/Trust
`Zeez/Sleep/SleepControlView.swift:158,174` — "10:30 PM" and "8h 00m" are string literals, ignoring the user's saved goal (`UserPreferences.targetBedtime` / Settings sleep-goal section). Bind to preferences or drop the card. Effort: Small.

**B13. HealthKit auth scope drift** — Low · Privacy
`SleepSessionManager.requestHealthKitAuthorization` (108-113) requests `restingHeartRate`, which nothing imports; onboarding/importer request the minimal 3-type set. Consolidate to one auth helper with the minimal set. Effort: Small.

### Phase C — early post-release / opportunistic

**C1. Double start of monitors on session start** — Low · Runtime — `SleepSessionManager.startSession` (47-48) and `SleepControlView.prepareSession` (201-202) both call `startMonitoring`. Harmless today (stop-then-start) but wasteful and permission-prompts twice. Remove one call site. Effort: Small.

**C2. `DataQualityReport` traps on empty input** — Low · Runtime — `RealDataManager.swift:301` `0..<(count-1)` crashes when `sessions` is empty (the error path at line 245 constructs exactly that). Currently dead code — fix the guard or delete the type with the dead-code sweep (`analyzeDataQuality`, `importAllAvailableData`'s unused Pillow/manual fields, `SleepRecommendationSystem` — no view references). Effort: Small.

**C3. `scheduleAllAlarms` drops concurrent requests** — Low · Alarm — `AlarmScheduler.swift:54-57` skips (rather than coalesces) a reschedule that arrives mid-flight; a stale-state window if an edit lands during launch rescheduling. Queue a trailing rerun instead. Effort: Small.

**C4. Watch target uses `print`** — Low · Maintainability — `WatchConnectivityManager.swift:164,177,193` etc.; add a small os.log wrapper to the watch target (ZeezLogger is iOS-only). Effort: Small.

**C5. Alarm health indicator in `AlarmSettingsView`** — from FUTURE, keep post-release. 

**C6. `checkImportStatus`/`getDataSources` fetch full objects to count** — Low · Performance — use `count(for:)`/aggregate fetches. Effort: Small.

### Phase D — architecture / longer term

**D1.** NavigationView → NavigationStack (start `MainView.swift:6`; ~40 files use NavigationView).
**D2.** Singleton graph → protocol injection (continue the `SleepAnalyzer` container-param pattern; next best target: `WatchConnectivityHandler`).
**D3.** Real WidgetKit extension (after B1 deletion), critical-alerts entitlement application, dormant sleep-product Phases 3–6 (claims contract stays binding).
**D4.** CI: add a watch-app build job and a `-only-testing` UI smoke job on a schedule (UI tests exist but never run in CI); keep the `#if compiler(>=6.2)` SDK-drift gate discipline.

## 5. Release-gating checklist

**Physical iPhone:** alarm E2E (force-quit, locked, chain cadence, Stop re-arms — after A6); mic-denied environmental path; HealthKit import of a real Apple Watch night (incl. `asleepUnspecified` display); record/end session with ConcurrencyDebug 1 (A3); delete-all-data walkthrough.
**Paired Apple Watch:** summary push after a new session (**blocked by A5**), requestData refresh, wake-pattern haptics, snooze/stop from watch, offline cache behavior.
**App Store Connect:** create/confirm the 4 product IDs char-for-char; sandbox purchase + restore; airplane-mode launch keeps premium; privacy-policy URL live; App Privacy questionnaire = "no data collected" consistent with manifests.
**Organizer/archive:** validate archive; confirm no `NSCameraUsageDescription` needed (AVCaptureDevice fully removed); background modes = `processing` only.
**TestFlight:** several nights of real alarm/sleep usage; battery observation (watch heartbeat machinery until A5 cleanup).
**Accessibility:** VoiceOver pass over Dashboard, session details, Trends charts, watch app; confirm every score utterance carries "Experimental Zeez estimate"; Dynamic Type on dashboard cards.
**Privacy/claims review:** re-read active surfaces against `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` after B-phase lands; review App Store description copy against the same contract before submission.

## 6. Suggested validation commands

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,id=55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,id=55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF' -only-testing:ZeezTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Zeez.xcodeproj -scheme "ZeezWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
# Threading verification for A2/A3/A4: add to the scheme's launch arguments
#   -com.apple.CoreData.ConcurrencyDebug 1
```

## 7. Prompt for the next implementation chat

```
Read SECOND_AUDIT_IMPROVEMENTS.md at the repo root (second audit, 2026-07-07). Also read
CLAUDE.md and skim FUTURE_IMPROVEMENTS.md for the open device/ASC verifications.

Implement Phase A only (items A1–A7), one item per commit, in order. Do not start Phase B
or broaden scope without my explicit approval.

Rules:
- Small, reviewable changes; one finding per commit with the item ID (e.g. "A2") in the
  commit subject.
- For the Core Data items (A2, A3, A4), follow the snapshot/objectID patterns already
  used in the alarm stack, and verify with -com.apple.CoreData.ConcurrencyDebug 1.
- A1 is a deletion, not a rewrite: remove the HRV/quality/random-fill sections; keep the
  recorded heart-rate chart with provenance wording per
  SLEEP_METRICS_CLAIMS_AND_VALIDATION.md.
- A5: define the payload contract in Shared/WatchDataModels.swift and add wire-shape
  contract tests before changing the handlers.
- A6 and A7 need new regression tests (Swift Testing, injected fake notification center /
  in-memory container, per existing patterns).
- After each item: run the ZeezTests bundle; after A5 also build the watch target
  (commands in SECOND_AUDIT_IMPROVEMENTS.md §6).
- After completing each item, check it off in SECOND_AUDIT_IMPROVEMENTS.md §4 with a
  one-line note of what was done.
```
