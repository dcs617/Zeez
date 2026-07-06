# HANDOVER — Zeez roadmap execution (written 2026-07-06, session 2 of roadmap work)

Delete this file once Phase 1 and 2 are complete.

## Where things stand

Branch: `feature/sleep-simplification`, pushed to `origin` (tracking set up).
Working tracker: `IMPROVEMENT_ROADMAP.md` at repo root — checkboxes + progress log are
current. Read it first; this file only adds session context the roadmap doesn't carry.

**Done and committed:** all of Phase 0 (0.1–0.6), plus Phase 1 items 1.2, 1.3, and 1.7.
One commit per item (0.2+0.3 share one). Roadmap items 2.7–2.9 were added from
Phase 0 discoveries.

**1.3 verified and closed (2026-07-06):** v1 stores are hash-compatible with model v2
(default-value changes don't affect version hashes), so upgrade-in-place is a no-op —
pinned by `ZeezTests/CoreDataModelV2MigrationTests`. Removed the "unversioned database"
wipe branch in `PersistenceController.handleMigrationError` (it misclassified every
v1 store). ⚠️ `.xccurrentversion` silently reverted to v1 once (likely a race with a
background xcodebuild) — worth re-checking it says `Zeez 2.xcdatamodel` before builds.

**1.5 done (2026-07-06):** Enhanced pair deleted; root `Shared/` is now a real
synchronized group in BOTH app targets; models single-sourced in
`Shared/WatchDataModels.swift`. Gotcha: the watch Enhanced file carried live
`WatchOfflineStorage`/`OfflineAction` — extracted to
`ZeezWatch Watch App/WatchOfflineStorage.swift`. Paired-sim round-trip NOT run
(no paired sims here) — fold into 1.1's device testing.

**Not started:** 1.6 (Core Data threading), 1.1 (pre-scheduled
follow-up chains), 1.4 (notification budget) — recommended in that order, because
1.6's snapshot refactor makes 1.1 much cleaner, and 1.1+1.4 are coupled (the 64-request
budget). Then Phase 2 (2.1–2.9).

## Decisions already made (do not re-litigate)

- **0.4:** KEEP noise monitoring. Usage string is in Info.plist; recorder meters to
  `/dev/null` (no audio ever stored — the string promises this), permission requested
  before first use, denial degrades gracefully.
- **0.5:** full reschedules must NOT cancel in-flight snoozes unless the owning alarm
  was disabled or deleted. Implemented in `AlarmScheduler.scheduleAllAlarms` and
  `scheduleSpecificAlarm`.
- **1.7:** Option B (relabel). UI says "Gentle Pre-Alarm"; pre-alert uses default
  sound at `.timeSensitive`. `SmartWakeAnalyzer.swift` is deleted. Core Data attribute
  names unchanged.

## Verified facts that save time

- **Legacy alarm suites (`AlarmEndToEndTests`, `AlarmReliabilityTests`,
  `AlarmRaceConditionTests`) FAIL en masse (42F/2P) — pre-existing.** Verified by
  running them at the pre-change baseline commit in a worktree: identical failures.
  Signature: Core Data 132001 "attempt to recursively call -save:" (they use
  `PersistenceController.shared` with the live host app). Fix is item 2.4 — do NOT
  chase these as regressions, and don't expect them green until 2.4 lands.
- `ZeezTests/AlarmPredicateSQLiteTests` (new in 0.3) passes and must stay green.
- Both targets build; watch target builds with **zero warnings** since 1.2.
- `grep -rn "id.uuidString" Zeez/` intentionally still matches 2 sites
  (`Widget.swift:87`, `WatchCommunicationSupport.swift:56`) — plain UUID→String
  serialization, not predicates. Predicate-form (`id.uuidString ==`) matches are zero.

## Environment / workflow quirks

- Build prefix: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (xcode-select
  points at CommandLineTools). iPhone 16 Pro iOS-18.6 sim id:
  `55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF`. Watch sim: `Apple Watch Series 10 (46mm)`.
- All targets are Xcode 16 **synchronized folder groups** — new files under
  `Zeez/`, `ZeezTests/` etc. join the target automatically; no pbxproj edit needed.
  (Relevant to 1.5: root `Shared/` is NOT such a group yet — adding it to both targets
  is part of that item; the pbxproj has `PBXFileSystemSynchronizedRootGroup` entries to
  mirror.)
- SourceKit emits phantom "Cannot find X in scope / No such module UIKit" diagnostics
  in this repo — ignore them; trust xcodebuild.
- The model was edited by hand (no Xcode GUI): v2 is a directory copy + edited
  `contents` + `.xccurrentversion`. momc compiles all versions in the .xcdatamodeld.
- `xcuserdata/.../xcschememanagement.plist` gets dirtied by xcodebuild runs; commit or
  ignore, but keep `git status` clean at item boundaries.
- Commit style: one focused commit per roadmap item, imperative subject with item
  number, body explains why + any extras folded in. Push after each session.

## Item-specific context for what's next

- **1.6:** follow the `SleepAnalyzer.analyzeSleepSession(objectID:container:)` pattern
  already in the codebase; snapshot alarm fields into a struct on the context's queue.
  Verify with scheme argument `-com.apple.CoreData.ConcurrencyDebug 1`. Note
  `AlarmNotificationHandler.checkHeavySleeperMode` reads `heavySleeperMode` via KVC
  because the generated properties file lacks the attribute (item 2.8) — consider
  fixing 2.8 while in there.
- **1.1:** interacts with the 64-request cap (1.4). Roadmap's mitigation: pre-schedule
  the chain only for the NEXT firing day, 6–8 follow-ups not 12–20, re-arm on
  launch/significantTimeChange. Stop/snooze handlers already call
  `cancelFollowUps(for:)` — extend its prefix matching to the new IDs. Also make
  `willPresent` post `ShowActiveAlarm` + start looped audio for `type == "main"`.
- **0.5 leftover noted in roadmap:** the remaining `DispatchSemaphore` in
  `scheduleAllAlarms` and Core Data reads on `schedulingQueue` are 1.6's scope.
