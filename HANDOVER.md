# HANDOVER — Zeez roadmap execution (updated 2026-07-06, end of session 3: Phase 1 complete)

Delete this file once Phase 1 and 2 are complete.

## Where things stand

Branch: `feature/sleep-simplification`, pushed to `origin` (all commits through 1.4).
Working tracker: `IMPROVEMENT_ROADMAP.md` at repo root — checkboxes + progress log are
current and carry the full detail per item. Read it first; this file only adds session
context the roadmap doesn't carry.

**Done and committed:** all of Phase 0 (0.1–0.6) and all of Phase 1 (1.1–1.7), plus 2.8
(folded into 1.6). One focused commit per item. **Next: Phase 2 in roadmap order —
2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.9** (2.8 done).

**Open Phase-1 verifications that need a physical device** (fold into first device session):
- 1.1 end-to-end: set alarm, force-quit, lock phone → follow-ups arrive at cadence;
  Stop action re-arms the next chain.
- 1.5: one phone↔watch message round-trip (no paired sims scriptable here).
- 1.4: banner appears with ~5 smart-wake alarms × 7 days (logic unit-tested; visual unchecked).

## Key architecture facts introduced by Phase 1 (also summarized in CLAUDE.md)

- **`AlarmSnapshot`** (`Zeez/Alarm/AlarmSnapshot.swift`): all alarm scheduling and
  UNUserNotificationCenter delegate work is Core-Data-free — snapshot taken inside
  `context.perform`, values passed around. Don't reintroduce managed-object reads on
  `schedulingQueue` or in notification callbacks.
- **`AlarmNotificationScheduling`** protocol + injected center in `AlarmScheduler`;
  tests use the in-memory `FakeNotificationCenter` in `ZeezTests/AlarmFollowUpChainTests.swift`.
  This is 2.4 step 1 pre-done for the scheduler — 2.4 extends it to
  `AlarmNotificationHandler`/`AlarmNotificationUtils` (both still call
  `UNUserNotificationCenter.current()` directly).
- **Follow-up chains** are pre-armed at scheduling time for the next firing day only
  (IDs `alarm-<uuid>-fu-pre-…`, snooze chains `alarm-<uuid>-fu-snz-…`); foreground fires
  replace them with the dynamic chain; `NotificationBudget` gates chains against the 64 cap.
- **Model v2** (`Zeez 2.xcdatamodel`, identifier "2") is current; v1 stores are
  hash-compatible (default-value changes don't alter version hashes) so no migration runs.
  ⚠️ `.xccurrentversion` silently reverted to v1 once (likely a background-xcodebuild race) —
  re-check it says `Zeez 2.xcdatamodel` if model behavior looks wrong.

## Decisions already made (do not re-litigate)

- **0.4:** KEEP noise monitoring. Usage string is in Info.plist; recorder meters to
  `/dev/null` (no audio ever stored — the string promises this), permission requested
  before first use, denial degrades gracefully.
- **0.5:** full reschedules must NOT cancel in-flight snoozes unless the owning alarm
  was disabled or deleted.
- **1.7:** Option B (relabel). UI says "Gentle Pre-Alarm"; pre-alert uses default
  sound at `.timeSensitive`. `SmartWakeAnalyzer.swift` is deleted. Core Data attribute
  names unchanged.
- **1.1/1.4:** pre-scheduled chains are 6 (normal) / 8 (heavy sleeper) entries,
  next-firing-day only, with a 4-slot budget safety margin — sizes chosen against the
  64-request cap; don't inflate them without redoing the budget math.

## Verified facts that save time

- **Legacy alarm suites (`AlarmEndToEndTests`, `AlarmReliabilityTests`,
  `AlarmRaceConditionTests`) FAIL en masse (42F/2P) — pre-existing** (verified at
  baseline in a worktree). Also pre-existing: `CoreDataMigrationTests.migrationErrorRecovery`
  and `.migrationPerformanceWithLargeDataset` (flaky SIGABRT). All are item 2.4's scope —
  do NOT chase as regressions.
- **Must stay green at every commit:** `AlarmPredicateSQLiteTests` (6),
  `CoreDataModelV2MigrationTests` (4), `AlarmFollowUpChainTests` (6),
  `NotificationBudgetTests` (4).
- Both targets build; watch target builds with **zero warnings** since 1.2 (transient
  `appintentsmetadataprocessor` warnings on non-clean builds are environmental noise).
- App runs clean under `-com.apple.CoreData.ConcurrencyDebug 1` (startup → onboarding →
  MainView). Launch flagged in a sim:
  `xcrun simctl launch <sim> com.danielsparano.zeez -com.apple.CoreData.ConcurrencyDebug 1`
  — the app must be foregrounded (open Simulator.app) or it sits at the home screen; if it
  "launches to home screen", check for a crash report in `~/Library/Logs/DiagnosticReports/`.
- `grep -rn "id.uuidString" Zeez/` intentionally still matches 2 sites
  (`Widget.swift`, `WatchCommunicationSupport.swift`) — plain UUID→String serialization,
  not predicates.

## Environment / workflow quirks

- Build prefix: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (xcode-select
  points at CommandLineTools). iPhone 16 Pro iOS-18.6 sim id:
  `55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF`. Watch sim: `Apple Watch Series 10 (46mm)`.
- All targets (now including root `Shared/`) are Xcode 16 **synchronized folder
  groups** — new files under `Zeez/`, `ZeezTests/`, `Shared/` etc. join their targets
  automatically; no pbxproj edit needed.
- SourceKit emits phantom "Cannot find X in scope / No such module UIKit" diagnostics
  in this repo — ignore them; trust xcodebuild.
- `xcuserdata/.../xcschememanagement.plist` gets dirtied by xcodebuild runs; commit or
  ignore, but keep `git status` clean at item boundaries.
- Commit style: one focused commit per roadmap item, imperative subject with item
  number, body explains why + any extras folded in. Push after each item or few.
- Onboarding can be skipped in a sim for testing:
  `xcrun simctl spawn <sim> defaults write com.danielsparano.zeez hasCompletedOnboarding -bool true`.

## Item-specific context for Phase 2

- **2.1 (StoreKit):** on top of the roadmap's list, note
  `StoreKitManager.subscriptionTier(from:)` matches by `identifier.contains(tier.rawValue)`
  with `allCases = [.premium, .premium_plus]` — a `premium_plus` product ID *contains*
  "premium", so premium_plus entitlements can resolve to the lower tier depending on
  iteration order. Fix alongside the explicit numeric rank. Also
  `updatePurchasedSubscriptions` sorts tiers with `rawValue >` (string comparison).
- **2.4:** extend `AlarmNotificationScheduling` injection to
  `AlarmNotificationHandler` + `AlarmNotificationUtils`; point legacy suites at
  `PersistenceController(inMemory: true)`; keep the one SQLite suite. The fake center +
  confirmation-based waiting pattern to copy is in `AlarmFollowUpChainTests`.
- **2.5-B partially done:** `Shared/AlarmGestureType.swift` already deleted (orphan);
  root `Shared/` is now real. Remaining orphans: `MockDataTestScript.swift`,
  `PreviewData.swift`, `Zeez/Models/` empty dir.
- **2.5-F partially done:** CLAUDE.md watch section rewritten in 1.5; AGENTS.md `Shared/`
  claim is now accurate. Remaining: CLAUDE.md pipeline description
  (`SessionValidationService`), watch build command (Series 9 → 10), `DEVELOPER_DIR` note.
- **2.6:** the "unversioned database" wipe branch in `PersistenceController` is already
  gone (removed in 1.3); `handleMigrationFallback` user-visible notice is still open.
