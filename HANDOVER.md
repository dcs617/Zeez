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

**1.6 + 2.8 done (2026-07-06):** `AlarmSnapshot` struct is the pattern — snapshot
inside `context.perform`, scheduling queues and UN callbacks are Core-Data-free.
Semaphore waits deleted. `heavySleeperMode` is a real `@NSManaged` property now.
Bonus find: `UserPatternAnalyzer.analyzeUserPatterns` fetched viewContext from
BackgroundTaskManager's queue — crashed the app at startup under
`-com.apple.CoreData.ConcurrencyDebug 1` (fixed; app verified clean under the flag
through startup/onboarding/MainView). To launch the app with the flag in a sim:
`xcrun simctl launch <sim> com.danielsparano.zeez -com.apple.CoreData.ConcurrencyDebug 1`
— note the app must be foregrounded (open Simulator.app) or it sits at the home screen.

**1.1 done in code (2026-07-06), device test pending:** chains pre-armed at
scheduling time (`AlarmScheduler.scheduleFollowUpChain`), next-firing-day only,
6/8 entries; snoozes pre-arm their own chain; foreground fires swap in the dynamic
chain; Stop re-arms. New `AlarmNotificationScheduling` protocol + fake center
(pre-does 2.4 step 1); `AlarmFollowUpChainTests` 6/6. **The roadmap's physical-device
verification (force-quit, locked phone, follow-ups at cadence) has NOT run — do it
when a device is available.**

**Not started:** 1.4 (notification budget) — main pressure valve (next-day-only
chains) already landed with 1.1; remaining: budget accounting + UI warning +
mains-first trimming. Then Phase 2 (2.1–2.7, 2.9).

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

- **1.4:** the injected `AlarmNotificationScheduling` fake (see
  `ZeezTests/AlarmFollowUpChainTests.swift`) is the harness for the budget
  calculator tests. Mains are already scheduled before chains in
  `AlarmScheduler.scheduleSnapshot`.
