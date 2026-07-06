# Zeez Improvement Roadmap

Source: full repository audit performed 2026-07-05 on branch `feature/sleep-simplification`.
Both app targets build successfully (Xcode 26.6, iOS 18.6 sim / watchOS Series 10 sim). Unit
test results were not verified during the audit. This file is the working tracker for the
top 20 audit findings — check items off as they land, and keep the "Verification" steps
honest (run them, don't assume).

**Build note for terminal sessions:** `xcode-select` on this machine points at
CommandLineTools. Either run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
once, or prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
The available iPhone 16 Pro simulator ID (iOS 18.6) is `55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF`.
There is no "Apple Watch Series 9" simulator — use `Apple Watch Series 10 (46mm)`.

Ordering rule: **Phase 0 must be completed (and committed) before any other phase begins.**
Within later phases, items are independent unless noted.

---

## Phase 0 — Critical fixes (each < 1 hour; do these first, in order)

### 0.1 Reconcile git index and commit the reorganization
- [x] Done
- **Problem:** 214 dirty entries (86 deletions, 75 untracked files, 49 modified) — the entire
  directory reorganization exists only in the working tree. The index contains stale staged
  adds: `Zeez/Environment/ActiveAlarmView.swift` and `Zeez/Learn/ActiveAlarmView.swift` show
  status `AD` (staged add, deleted on disk). Because the project uses Xcode 16 synchronized
  folder groups, committing those staged adds would give any fresh checkout **three**
  `ActiveAlarmView` type declarations and a build failure. `Zeez/Onboarding/OnboardingModule.swift`
  and `PreferencesManager.swift` are staged deletes (`D `).
- **Steps:**
  1. `git status --short` and confirm the `AD`/`D ` entries.
  2. `git add -A` so the index matches the working tree exactly (this converts the stale
     staged adds into nothing and stages the deletions/renames properly).
  3. Re-run `git status --short` — there must be **no** `AD` entries remaining.
  4. Commit. One commit for the whole reorg is acceptable given it's already entangled;
     a short body listing the major moves (flat `Zeez/*.swift` → feature directories) helps.
  5. Do NOT commit the scratch/root orphans blindly: `MockDataTestScript.swift`,
     `PreviewData.swift`, and root `Shared/` are not part of any target (see item 2.5-B) —
     commit them anyway for safety now, delete/relocate later in item 2.5.
- **Verification:** after committing, `git stash list` empty, `git status` clean, and the
  app still builds.

### 0.2 Fix the four invalid `id.uuidString` Core Data predicates
- [x] Done
- **Problem:** `AlarmConfiguration.id` is a **UUID** attribute (confirmed in
  `Zeez/Zeez.xcdatamodeld/Zeez.xcdatamodel/contents`). SQLite stores cannot evaluate the
  keypath `id.uuidString` — the fetch raises an ObjC `NSInvalidArgumentException` at runtime
  that a Swift `catch` does not reliably intercept. In-memory stores (used by tests) mask
  this. Affected user flows: snooze from a notification action, heavy-sleeper mode lookup,
  follow-up sound selection, and presenting the full-screen `ActiveAlarmView` on notification
  tap.
- **Sites (all currently `NSPredicate(format: "id.uuidString == %@", alarmId)`):**
  - `Zeez/Alarm/AlarmNotificationUtils.swift:37` (`scheduleSnooze`)
  - `Zeez/Alarm/AlarmNotificationHandler.swift:93` (`checkHeavySleeperMode`)
  - `Zeez/Alarm/AlarmNotificationHandler.swift:111` (`scheduleFollowUps`)
  - `Zeez/Alarm/AlarmNotificationHandler.swift:213` (`presentActiveAlarmUI`)
- **Fix:** parse the string to a UUID first, then compare the attribute directly:
  ```swift
  guard let uuid = UUID(uuidString: alarmId) else { return /* or fallback */ }
  request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
  ```
  Each site already has a sensible fallback path for "alarm not found" — keep those.
- **Verification:** item 0.3's regression test; plus `grep -rn "id.uuidString" Zeez/` returns
  nothing.

### 0.3 Add a SQLite-backed regression test for alarm-ID predicates
- [x] Done
- **Problem:** the existing alarm suites (`ZeezTests/AlarmEndToEndTests.swift` etc.) run
  against `PersistenceController.shared` or in-memory stores; in-memory predicate evaluation
  would not have caught 0.2. Without a SQLite-backed test this bug class returns.
- **Steps:**
  1. New file `ZeezTests/AlarmPredicateSQLiteTests.swift` (Swift Testing, `import Testing`,
     `@testable import Zeez`).
  2. Build an `NSPersistentContainer` with the Zeez model backed by a **SQLite** store at a
     temp URL (NOT `/dev/null`, NOT in-memory) — e.g.
     `FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).sqlite")`.
     Delete the store files in a `defer`/teardown.
  3. Insert an `AlarmConfiguration` with a known `id = UUID()`, save.
  4. For each of the four query shapes used in production (snooze lookup, heavy-sleeper,
     follow-up sound, present-UI), execute the same fetch with the same predicate form the
     production code now uses, and `#expect` the alarm is found.
  5. Optionally add a test asserting the OLD predicate form throws/fails, documenting why
     the new form exists (wrap in `#expect(throws:)` if it surfaces as a Swift error; if it
     traps via ObjC exception, skip this half and note it in a comment).
- **Verification:** suite passes from Xcode; predicate tests fail if someone reverts 0.2.

### 0.4 Add `NSMicrophoneUsageDescription` (or gate the environmental recorder)
- [x] Done
- **Problem:** `Zeez/Environment/EnvironmentalMonitor.swift:92-95` creates an
  `AVAudioRecorder` and calls `.record()` for noise sampling. `Zeez/Info.plist` has **no**
  `NSMicrophoneUsageDescription`. iOS terminates the app the instant the mic is accessed
  without that key. Call sites that reach it: `Zeez/Sleep/SleepSessionManager.swift:47`,
  `Zeez/Sleep/SleepControlView.swift:195-222`, `Zeez/Infrastructure/BackgroundTaskManager.swift:391`.
- **Decision to make first:** is live environmental noise monitoring a shipping feature?
  - If YES: add to `Zeez/Info.plist`:
    `NSMicrophoneUsageDescription` = "Zeez samples ambient noise levels while you sleep to
    score your sleep environment. Audio is analyzed on-device and never stored or uploaded."
    Then confirm that claim is true — trace what `EnvironmentalMonitor` does with the
    recorded file (retention/deletion was NOT traced during the audit; do it now).
    Also request mic permission explicitly (`AVAudioApplication.requestRecordPermission`)
    before first use, with a denial path that degrades gracefully.
  - If NO / NOT YET: remove or `#if DEBUG`-gate the `AVAudioRecorder` usage so no code path
    can touch the mic, and have `captureEnvironmentalData` record only non-mic metrics.
- **Verification:** on a simulator/device, start a sleep session from `SleepControlView` —
  app must not crash; if the key was added, the permission prompt shows the string.

### 0.5 Stop `AlarmScheduler` from wiping ALL pending notifications
- [x] Done
- **Problem:** `Zeez/Alarm/AlarmScheduler.swift:50` — `scheduleAllAlarms` calls
  `notificationCenter.removeAllPendingNotificationRequests()`. This wipes pending snoozes,
  heavy-sleeper follow-ups, and Learn reminders. It runs on **every app launch**
  (`ApplicationDelegate.didFinishLaunching` → first-activation reschedule at
  `Zeez/App/ApplicationDelegate.swift:30-33`) and on every alarm insert/delete
  (via `AlarmObserver.debouncedReschedule`). Concretely: a user snoozes an alarm, opens the
  app, and the snooze is silently cancelled.
- **Fix:** enumerate pending requests and remove only alarm-owned ones. Alarm identifiers
  all use recognizable prefixes already: main alarms `"alarm-<uuid>-main-..."`, follow-ups
  `"alarm-<uuid>-fu-..."`, snoozes `"snooze-<uuid>-..."`. Replace the global removal with:
  ```swift
  notificationCenter.getPendingNotificationRequests { requests in
      let ids = requests.map(\.identifier)
          .filter { $0.hasPrefix("alarm-") || $0.hasPrefix("snooze-") }
      notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
      ...
  }
  ```
  **Design question to answer while here:** should a full reschedule cancel an in-flight
  snooze? Arguably no — consider excluding `"snooze-"` from the wipe unless the alarm was
  disabled/deleted. Decide and document in a comment.
  While in the file, also note the `DispatchSemaphore` + `asyncAfter(0.1)` and
  `usleep(100_000)` timing hacks (lines ~49-56, ~93) — removal APIs don't need settle time
  when you remove by identifier; fold this cleanup in or defer to item 1.6.
- **Verification:** manual sim test — schedule a Learn reminder, then toggle an alarm; the
  Learn reminder must survive (`xcrun simctl` or `AlarmScheduler.debugScheduledAlarms()` to
  inspect pending requests).

### 0.6 Stop `LearnNotificationManager` from cancelling alarms
- [x] Done
- **Problem:** `Zeez/Learn/LearnNotificationManager.swift:163-164` —
  `removeAllPendingNotifications()` calls the global
  `removeAllPendingNotificationRequests()`. It is invoked from
  `Zeez/Learn/LearnSettingsView.swift:246`, so toggling Learn notifications off **cancels
  every scheduled alarm**.
- **Fix:** Learn must own an identifier prefix. Audit the four `notificationCenter.add(...)`
  call sites in the file (lines ~84, 112, 136, 158, 249) — give every request an identifier
  beginning with `"learn-"` (they may already share a scheme; normalize it). Then filter the
  removal to that prefix, mirroring the pattern in 0.5.
- **Verification:** schedule an alarm, toggle Learn notifications off in Learn settings,
  confirm the alarm's pending requests survive.

**Phase 0 exit criteria:** all six items done, committed in separate logical commits, iOS +
watch targets build, alarm test suites pass (now including the SQLite predicate test).

---

## Phase 1 — Alarm reliability & correctness (before TestFlight)

### 1.1 Pre-schedule follow-up chains so Heavy Sleeper works with the app closed
- [ ] Done
- **Problem (design flaw):** follow-up "still ringing" notifications are scheduled in
  `AlarmNotificationHandler.handleNotificationArrived` (`AlarmNotificationHandler.swift:70-87`),
  which is only reached from `willPresent` — i.e., **only when the app is foregrounded at
  fire time**. In the real scenario (phone locked, app suspended/killed), the alarm fires
  once and the follow-up barrage never arms. Heavy Sleeper mode does not function in the
  exact situation it exists for.
- **Fix direction:** schedule the follow-up chain **at alarm-scheduling time** in
  `AlarmScheduler.scheduleAlarmSynchronous`: for each weekday trigger, also create N
  `UNCalendarNotificationTrigger`s offset by `cadence * n` past the alarm time
  (cadence/maxCount from `AlarmNotificationUtils.getCadence/getMaxFollowUps`, driven by
  `alarm.heavySleeperMode`). Cancel the chain when the user stops/snoozes (the
  stop/snooze handlers already call `cancelFollowUps(for:)` — extend its prefix matching to
  the new IDs) and re-arm on reschedule.
- **Hard constraint — interacts with 1.4:** iOS caps pending requests at 64. Pre-scheduled
  chains multiply per-day requests. Mitigations to implement together: only pre-schedule
  the chain for the **next** firing day (not all 7), reduce maxCount (e.g. 6–8 rather than
  12–20 pre-scheduled), and re-arm daily on any launch/`significantTimeChange`.
- **Also fix while here:** foreground fires should present the alarm UI immediately —
  `willPresent` currently returns `[.banner, .sound]` only. Post `ShowActiveAlarm` and start
  looped audio from `willPresent` when `type == "main"` (item was 8.7/15 in the audit).
- **Verification:** on a physical device (simulators throttle notifications unreliably):
  set an alarm 2 min out, force-quit the app, lock the phone, let it fire, don't touch it —
  follow-ups must arrive at the configured cadence.

### 1.2 Info.plist and capability cleanup
- [x] Done
- **Problems in `Zeez/Info.plist`:**
  - `UIBackgroundModes` contains `audio` (but `AlarmAudioController` is documented and
    implemented as foreground-only) and `remote-notification` (no push registration exists
    anywhere). Both are App Review rejection triggers. Keep only `processing`.
  - `UIRequiredDeviceCapabilities = [armv7]` — wrong for an arm64/iOS-18 app. Remove the key
    entirely (safest) or set `arm64`.
  - `UILaunchStoryboardName = LaunchScreen` — **no storyboard exists in the repo**. Either
    add a LaunchScreen or delete the key and set `INFOPLIST_KEY_UILaunchScreen_Generation`
    properly (note: `GENERATE_INFOPLIST_FILE = NO`, so `INFOPLIST_KEY_*` build settings are
    ignored for the iOS target — the manual plist is the only source of truth).
  - Interruption levels: nearly every alarm notification sets `.timeSensitive`, but the
    entitlements file (`Zeez/Zeez.entitlements`) contains only HealthKit keys — no
    time-sensitive capability, so the level silently downgrades. Add the Time Sensitive
    Notifications capability in Signing & Capabilities. Separately:
    `AlarmNotificationUtils.scheduleBasicSnooze` (line ~101) and
    `AlarmScheduler.scheduleTestNotification` (lines ~191-192) unconditionally use
    `.defaultCritical` / `.critical` — route them through the existing
    `checkCriticalAlertsEnabled` gate like every other path.
  - Project build settings: remove the ignored `INFOPLIST_KEY_NSHealth*` duplicates on the
    iOS target and the **empty** `NSHealth*` strings on the watch target (source of 3 build
    warnings; the watch app does not use HealthKit at all).
- **Verification:** clean build produces zero Info.plist-related warnings; app launches with
  a proper launch screen.

### 1.3 Fix `AlarmConfiguration` model defaults — with model versioning
- [x] Done
- **Problem:** in `Zeez/Zeez.xcdatamodeld/Zeez.xcdatamodel/contents`,
  `smartWakeEnabled` (Boolean) has `defaultValueString="30"` and `smartWakeWindow` has
  default `9`. These look transposed (window should plausibly be 30 min; snooze-ish 9).
  Consequence: newly created alarms may be born with smart wake enabled unintentionally.
- **Steps:**
  1. **Create a new model version first** (Editor → Add Model Version) and set it current.
     This codebase has only ONE model version; start versioning before any data-bearing
     release. The custom `CoreDataMigrationManager` exists but is untested against a real
     v1→v2 hop — this lightweight-migratable change is the safest first exercise of it.
  2. In the new version: `smartWakeEnabled` default `NO`, `smartWakeWindow` default `30`.
     Audit neighbors while there: `snoozeDuration` default `0` is OK (runtime fallback to 9
     exists in `AlarmConfiguration+Extensions.swift:57-60`).
  3. Confirm `PersistenceController.configureStoreForMigration` handles the hop (lightweight
     migration path, `NSMigratePersistentStoresAutomaticallyOption`).
- **Verification:** run `ZeezTests/CoreDataMigrationTests`; upgrade-in-place test: run old
  build in sim, create an alarm, run new build, data intact; create a NEW alarm and confirm
  `smartWakeEnabled == false` by default.

### 1.4 Notification budget accounting
- [ ] Done
- **Problem:** iOS silently drops pending notification requests beyond 64. Per alarm today:
  up to 7 weekdays × 2 (smart-wake pre-alert + backup) = 14 requests; follow-up chains and
  snoozes add more. Three or four smart-wake alarms approach the cap; the excess alarms
  simply never fire, with no error.
- **Steps:**
  1. Add a budget check to `AlarmScheduler`: after scheduling, `getPendingNotificationRequests`
     and log/count per-category totals.
  2. Enforce ordering: main alarm triggers get scheduled before follow-up chains, so if the
     budget is tight, follow-ups are what get trimmed, never a main fire.
  3. Surface state in UI: `AlarmSettingsView` shows a warning banner when pending count is
     within ~10 of the cap ("You have many alarms/follow-ups; some reminders may not fire").
  4. Coordinate with 1.1's "next-day-only chain" strategy — that is the main pressure valve.
- **Verification:** unit test the budget calculator with synthetic request lists; manual test
  with 5 smart-wake alarms × 7 days verifying mains survive.

### 1.5 Delete the dead Enhanced watch-connectivity stack; unify shared models
- [x] Done
- **Problem A (dead code, live hazard):** `Zeez/Watch/EnhancedWatchConnectivityHandler.swift`
  (558 lines, iOS) and `ZeezWatch Watch App/EnhancedWatchConnectivityManager.swift` (570
  lines, watch) have **zero callers** (verified by grep). Every connectivity class sets
  `WCSession.default.delegate = self` in its singleton `init` — the first accidental
  `.shared` touch of an Enhanced class steals the session delegate from the live handler and
  silently kills phone↔watch messaging. Delete both files.
- **Problem B (model triplication):** watch message/model types exist in three places:
  root `Shared/WatchDataModels.swift` (**not compiled into any target** — the pbxproj's
  synchronized root groups are only the six target folders), `ZeezWatch Watch App/WatchDataModels.swift`
  (the watch's diverged copy), and `Zeez/Watch/WatchCommunicationSupport.swift` (iOS side).
  They have already drifted (root copy has a `SleepSession`-based initializer the watch copy
  lacks). CLAUDE.md/AGENTS.md *claim* Shared/ is shared — it isn't.
- **Steps:**
  1. Delete the two Enhanced files. Re-grep `EnhancedWatch` to confirm nothing references them.
  2. In Xcode, add the root `Shared/` folder as a synchronized group with membership in BOTH
     the `Zeez` and `ZeezWatch Watch App` targets.
  3. Reconcile the three model definitions into `Shared/WatchDataModels.swift`. The
     Core-Data-dependent initializer (`init(from coreDataSession:)`) can't live in a file the
     watch compiles unless the watch has those types — split it into an iOS-only extension
     file under `Zeez/Watch/`.
  4. Delete `ZeezWatch Watch App/WatchDataModels.swift` and the duplicated types in
     `WatchCommunicationSupport.swift` (keep genuinely iOS-only helpers there).
  5. Also delete `Shared/AlarmGestureType.swift` duplication if it exists on both sides
     (check `Zeez/Alarm/AlarmGesturePickerView.swift` usage).
- **Verification:** both targets build; a paired-simulator (or device) round-trip of one
  message type (e.g. alarm ack) still works.

### 1.6 Fix Core Data threading in the alarm stack
- [ ] Done
- **Problem:** undefined behavior — Core Data objects/contexts touched off their queues:
  - `AlarmScheduler.scheduleAllAlarms` (`AlarmScheduler.swift:26-64`): `context.fetch` on the
    private `schedulingQueue` against (usually) the viewContext.
  - `scheduleSpecificAlarm` / `scheduleAlarmSynchronous` (`:68-141`): reads
    `alarm.name/.enabled/.time/.daysOfWeek/.smartWakeEnabled...` on `schedulingQueue`.
  - `AlarmNotificationHandler.checkHeavySleeperMode/scheduleFollowUps/presentActiveAlarmUI`
    (`:89-228`): fetches `PersistenceController.shared.container.viewContext` from
    UNUserNotificationCenter delegate callbacks (non-main threads).
- **Fix pattern (already proven in this codebase — see `SleepAnalyzer.analyzeSleepSession(objectID:container:)`):**
  - Pass `NSManagedObjectID`s (not objects) into queues; resolve + read inside
    `context.perform { }` on a background context, or snapshot the needed alarm fields into
    a plain struct (`AlarmSnapshot`: id, name, time, days, sound, flags) on the context's
    queue and pass the struct around.
  - The scheduling queue should operate exclusively on snapshots; UNUserNotificationCenter
    calls have no Core Data dependency once the snapshot exists.
  - Delete the `DispatchSemaphore`/`usleep`/`asyncAfter(0.1)` settle-time hacks — removal by
    identifier is synchronous enough; where ordering matters, chain inside the callbacks.
- **Verification:** run the app and alarm test suites with the scheme argument
  `-com.apple.CoreData.ConcurrencyDebug 1` — zero multithreading assertions.

### 1.7 Decide Smart Wake honestly (implement or relabel)
- [x] Done
- **Problem:** `Zeez/Alarm/SmartWakeAnalyzer.swift` (194 lines,
  `calculateOptimalWakeTime`) has **zero callers**. The shipped "smart wake" behavior
  (`AlarmScheduler.swift:120-141`) is just a second notification scheduled
  `smartWakeWindow` minutes early with body "Smart Wake Initializing". A toggle promising
  sleep-stage-aware waking that doesn't exist violates the project's own
  `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` contract and is an App Review / user-trust risk.
- **Option A (implement, larger):** at pre-alert time the app would need to run analysis and
  reschedule — but iOS won't reliably wake the app for this. Honest implementable version:
  when the pre-alert fires and the user's device has recent HR/movement data AND the app can
  run (foreground/background task), compute optimal time and schedule the final alert;
  otherwise fall back to the backup alert. Requires 1.1's infrastructure. Scope carefully.
- **Option B (relabel, small — recommended for MVP):** rename the feature in UI to what it
  does ("Gentle pre-alarm: get an earlier, quieter alert up to N minutes before your
  alarm"), delete `SmartWakeAnalyzer.swift`, and change the pre-alert notification copy
  ("Smart Wake Initializing" → something truthful like "Gentle wake-up").
- **Verification:** UI copy, notification copy, and behavior agree; claims doc conformance.

**Phase 1 exit criteria:** alarm behaves correctly with app killed (device-tested),
`ConcurrencyDebug` clean, Info.plist/capabilities clean, model v2 migrated, watch stack
single-sourced.

---

## Phase 2 — Pre-App-Store hardening

### 2.1 StoreKit correctness
- [ ] Done
- **File:** `Zeez/Commerce/StoreKitManager.swift`
- **Fixes:**
  1. Line ~53: `restorePurchases()` is declared `throws` but swallows failure via
     `try? await AppStore.sync()` — the UI can report "restored" after a failed sync.
     Remove the `try?`.
  2. Lines ~105-130: `updatePurchasedSubscriptions()` resolves entitlements by looking up
     `transaction.productID` in the in-memory `subscriptions` array. If `loadProducts()`
     failed (offline first launch), every entitlement resolves to nothing and
     `PremiumManager.updateSubscription(nil)` **persists a wrongful downgrade** to
     UserDefaults (`subscription_tier` key in `PremiumFeatures.swift:133-141`). Map tiers
     directly from `transaction.productID` via `subscriptionTier(from:)` instead of
     requiring a loaded Product.
  3. `SubscriptionTier` ordering uses raw-string comparison (`"premium_plus" > "premium"` —
     works by luck). Give the enum an explicit numeric rank.
  4. Add a `.storekit` configuration file with the exact product IDs
     (`com.zeez.subscription.premium.monthly` etc. — **confirm these match App Store
     Connect**; bundle ID is `com.danielsparano.zeez`, product IDs need not match it but
     must match ASC exactly). Wire it into the scheme for local testing.
  5. Add StoreKitTest-based tests: purchase grants tier, restore after reinstall, offline
     launch preserves cached tier, expiry downgrades.
- **Verification:** sandbox purchase + restore pass on device; airplane-mode launch keeps
  premium.

### 2.2 Make release logs debuggable (os_log privacy annotations)
- [ ] Done
- **Problem:** `Zeez/Infrastructure/ZeezLogger.swift:72-100` — `logger.info("\(message)")`
  interpolates the whole message as a non-literal, which os_log redacts to `<private>` in
  release builds. Consequence: TestFlight sysdiagnoses contain zero useful Zeez output,
  including all error messages.
- **Fix:** in `info`, `error`, and `fault`, annotate the message
  `\(message, privacy: .public)`. Keep `debug` as-is (DEBUG-only anyway). Then **sweep call
  sites for sensitive payloads** that would now become public: anything logging sleep times,
  heart-rate values, or store paths should either drop the payload or keep it in a separate
  `.private` interpolation. Known sensitive-ish call sites: `SleepAnalyzer` (session
  start/end times), `SleepStageAnalyzer` (HR values), `PersistenceController`
  (backup file paths). The existing `debugWithSensitiveData` helper is the pattern for those.
- **Verification:** build Release config, run, `log stream --predicate 'subsystem == "com.danielsparano.zeez"'`
  shows readable messages with no health values.

### 2.3 Privacy & App Store scaffolding
- [ ] Done
- **Gaps found:**
  1. **No `PrivacyInfo.xcprivacy` anywhere.** Required: declare UserDefaults use
     (required-reason API CA92.1), Health data category, no tracking. Add one to the iOS
     target (and watch target if required by its API use).
  2. **No user-facing data deletion.** `PersistenceController.clearAllData()` exists with
     zero callers. Add a Settings row ("Delete All My Data") with a destructive confirmation
     dialog that calls it (plus UserDefaults reset for onboarding/subscription keys — decide
     whether subscription cache survives; it should, entitlements come from StoreKit).
  3. **No privacy policy link** in Settings — required for HealthKit apps. Also add an app
     version/build row while there.
  4. HealthKit scope unification: `HealthKitDataImporter.requestFullAuthorization`
     (`DataImport/HealthKitDataImporter.swift:115-143`) requests 8 read types including
     stepCount/distance/oxygen that nothing consumes; onboarding requests 3
     (`OnboardingManager.swift:150-154`). Trim the importer to the types actually mapped
     (sleepAnalysis, heartRate, respiratoryRate — add HRV/restingHR only if actually
     imported) so both surfaces request the same minimal set.
  5. Check `com.apple.developer.healthkit.background-delivery` in `Zeez/Zeez.entitlements`:
     no `enableBackgroundDelivery` call exists in the codebase — remove the entitlement if
     it stays unused.
- **Verification:** archive validates in Organizer with no privacy warnings; delete-data flow
  leaves app in clean first-run state.

### 2.4 Test suite reliability + CI
- [ ] Done
- **Problem:** `ZeezTests/AlarmEndToEndTests.swift` (and reliability/race suites) use
  `PersistenceController.shared` — the **real simulator store** — plus the real
  `UNUserNotificationCenter` and fixed `Task.sleep(2-5s)` waits. They're slow, stateful,
  order-dependent, and CI-hostile (need notification permission).
  **Verified 2026-07-05 (Phase 0 exit):** these suites currently FAIL en masse — 42
  failed / 2 passed — and fail **identically at the pre-Phase-0 baseline commit**, so this
  is not a regression. Dominant signature: Core Data 132001 "attempt to recursively call
  -save: on the context aborted" (tests saving to the shared viewContext while the live
  host app's observers react), plus downstream `isScheduled`/`isDeleted` expectation
  failures and one `checkNotificationPermissions` abrt. The in-memory + fake-center
  refactor below is the fix.
  **Also pre-existing (verified 2026-07-06 at baseline c889047 in a worktree):**
  `CoreDataMigrationTests.migrationErrorRecovery` (expects `CoreDataMigrationError` but
  `migrateStore` surfaces NSCocoaErrorDomain 260 from the backup-copy step when the source
  path doesn't exist) and `CoreDataMigrationTests.migrationPerformanceWithLargeDataset`
  (flaky SIGABRT that crashes the runner, which then fails the whole suite's retry clone
  at 0.000s). Fix both here.
- **Steps:**
  1. Introduce a `NotificationScheduling` protocol wrapping the UNUserNotificationCenter
     calls used by `AlarmScheduler`/`AlarmNotificationHandler`/`AlarmNotificationUtils`;
     production conforms via the real center; tests use an in-memory fake recording
     requests. (This also unlocks testing 1.4's budget logic.)
  2. Point alarm tests at `PersistenceController(inMemory: true)` — note the public
     `init(inMemory:)` already exists. Keep the ONE SQLite-backed suite from 0.3.
  3. Replace `Task.sleep` waits with confirmation-based waiting on the fake.
  4. Add missing high-value unit tests: `SleepQualityCalculator` (weights sum, missing-data
     defaults, count-vs-duration behavior), watch model encode/decode round-trips.
  5. CI: a GitHub Actions (or Xcode Cloud) workflow running
     `xcodebuild test -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.
- **Verification:** full suite green twice consecutively, < 2 min, on a clean simulator.

### 2.5 Cleanup sweep (dead code, docs, hygiene)
- [ ] Done
- **A. Dead code to delete** (all verified zero-caller during audit):
  - `Zeez/Sleep/SessionValidationService.swift`
  - `Zeez/Alarm/SmartWakeAnalyzer.swift` (unless 1.7 Option A chose to wire it)
  - Enhanced watch pair (done in 1.5 — verify)
- **B. Orphan files not in any target** — relocate or delete: root `MockDataTestScript.swift`,
  root `PreviewData.swift`, `Scripts/convert_print_to_logging.py` (keep if useful, it's
  inert), root `Shared/` (becomes real in 1.5). Empty dir `Zeez/Models/` — remove.
- **C. `print()` sweep** (~15 calls violating the project's own logging rule):
  `Zeez/Alarm/ActiveAlarmView.swift`, `Zeez/Shared/ModalCoordinator.swift`,
  `Zeez/Alarm/AlarmSounds.swift`, `Zeez/Alarm/AlarmPermissionExplainerView.swift`,
  `Zeez/Alarm/AlarmPermissionDeniedView.swift` → `ZeezLogger`.
- **D. RootView placeholders** (`Zeez/Views/RootView.swift:32-40`): `Text("Settings Modal")`,
  `Text("Debug Tools")`, `Text("HealthKit Error")` — implement the modal or delete the enum
  case from `ModalCoordinator`.
- **E. Stringly-typed constants:** centralize `NSNotification.Name("ShowActiveAlarm")`,
  `"AlarmPermissionDenied"`, `"ModalDismissed"` as `extension Notification.Name` statics;
  centralize `deviceIdentifier` provenance strings ("HealthKit Import", Pillow, mock
  markers) currently scattered across `RealDataManager`/importers/`SleepAnalyzer`.
- **F. Documentation truth pass:** CLAUDE.md — remove `SessionValidationService` from the
  pipeline description (validation is inline in `SleepAnalyzer` now); fix the watch build
  command (Series 9 sim doesn't exist here); note the `DEVELOPER_DIR` requirement. AGENTS.md —
  correct the `Shared/` claim once 1.5 lands.
- **G. Warning sweep** (from the audit build): dead `serverTime`/`metrics`/`modelURL`/`session`
  variables, deprecated `allowBluetooth` option in `AlarmAudioController.swift:23,51`
  (→ `.allowBluetoothHFP`), non-exhaustive switch in `BackgroundTaskManager.swift:231`,
  `objc_setAssociatedObject` timer hack in `AlarmAudioController.swift:102,118` → stored
  property. Also `PillowDataImporter.swift:83,146` unused `session` values — check they're
  not masking a missed dedup branch before deleting.

### 2.6 Core Data storage hygiene
- [ ] Done
- **File:** `Zeez/CoreData/PersistenceController.swift`
- **Fixes:**
  1. Lines ~132-139: delete the `NSSQLitePragmasOption` block — `journal_mode=DELETE`
     disables WAL (worse concurrency for zero stated benefit); `auto_vacuum=FULL` via pragma
     post-creation is ineffective. Default WAL is correct here.
  2. Persistent history tracking (`NSPersistentHistoryTrackingKey`) is enabled but nothing
     consumes or purges it → unbounded growth. Either delete the option (nothing uses it) or
     add a periodic `NSPersistentHistoryChangeRequest.deleteHistory(before:)` (e.g., 7 days,
     from `BackgroundTaskManager`'s processing task). Deleting the option on an existing
     store is safe; keep the choice consistent.
  3. Enforce the singleton: two initializers exist (`private init()` and public
     `init(inMemory:)`), so `PersistenceController()` compiles anywhere. Make
     `init(inMemory:)` internal-with-comment (tests need it) and audit for accidental extra
     instances.
  4. `handleMigrationFallback` (lines ~288-311) silently renames the user's store to
     `.corrupted-<timestamp>` and starts fresh. Add a user-visible notice path (set a flag
     read at next launch → alert "Your sleep history could not be migrated; a backup was
     kept.") rather than silent data loss.
  5. Add retention for `AnalyticsEvent`/`FeatureAccessRecord` rows (no pruning exists;
     local-only but unbounded).

### 2.7 One-time cleanup of legacy notification identifiers *(discovered during 0.6)*
- [ ] Done
- **Problem:** the prefix-filtered removals from 0.5/0.6 only match the NEW identifier
  schemes. Installs that scheduled notifications on earlier builds still have pending
  requests with un-prefixed Learn identifiers (`challenge_*`, `challenge_completion_*`,
  `learning_*`, `streak_reminder_*`, `snoozed_*`) that no removal path can ever target.
- **Fix:** a one-time migration on launch (UserDefaults flag) that enumerates pending
  requests and removes the known legacy Learn patterns. Low urgency pre-TestFlight (no
  external installs exist), but must land before the first update shipped over an
  installed build.

### 2.8 `heavySleeperMode` missing from generated Core Data properties *(discovered during 0.3)*
- [ ] Done
- **Problem:** the attribute exists in the model (`Zeez.xcdatamodel/contents`) but not in
  `Zeez/CoreData/AlarmConfiguration+CoreDataProperties.swift`, so production reads it via
  KVC (`value(forKey: "heavySleeperMode")` in `AlarmNotificationHandler`) — stringly-typed
  and invisible to the compiler.
- **Fix:** add the `@NSManaged public var heavySleeperMode: Bool` property (or regenerate
  the class files) and replace the KVC reads. Audit the other entities for the same drift
  while there.

### 2.9 Environmental monitoring honesty check *(discovered during 0.4)*
- [ ] Done
- **Problems found while tracing `EnvironmentalMonitor` for 0.4:**
  1. `captureLightLevel()` reads camera ISO from `AVCaptureDevice` with **no running
     capture session** — the value is almost certainly static/meaningless, so the "light
     level" metric may be fiction. Verify on-device; fix or remove the metric. Also confirm
     whether this AVCaptureDevice usage requires `NSCameraUsageDescription` (device
     configuration without a session generally doesn't, but verify before App Review).
  2. Sampling runs on a foreground `Timer` every 5 min — a locked phone suspends the app,
     so overnight environmental data is mostly never collected. Decide the honest story:
     background-task-based sampling, "works while charging + foreground" labeling, or cut.
     Same claims-conformance standard as Smart Wake (1.7).
  3. `estimateRoomTemperature()` returns a hardcoded 0 that gets persisted as a reading.

---

## Phase 3 — Post-release / nice-to-have (tracked, not scheduled)

- Real WidgetKit extension (current `Zeez/Widgets/` is in-app cards only; naming misleads).
- Apply for the critical-alerts entitlement (defensible for an alarm app); until granted,
  keep the graceful `checkCriticalAlertsEnabled` degradation.
- Heart-rate downsampling on HealthKit import (a full night = thousands of `HeartRateData`
  managed objects; store growth).
- Duration-weighted stage-distribution scoring in
  `Zeez/Sleep/Quality/SleepQualityCalculator.swift:119-137` (currently counts stages, which
  skews with variable-length HealthKit stages); derive `confidenceScore` instead of the
  hardcoded `85.0` at `SleepAnalyzer.swift:116`.
- Import UX: completion signal for the fire-and-forget HR/respiratory sub-imports; partial
  failure reporting.
- Alarm health indicator in `AlarmSettingsView` ("N notifications scheduled; next fires
  at…").
- `NavigationView` → `NavigationStack` migration (start with `MainView.swift:6-7` — remove
  the NavigationView wrapping the TabView; give each tab its own NavigationStack).
- Singleton graph → protocol injection, incrementally, following the
  `SleepAnalyzer.analyzeSleepSession(objectID:container:)` pattern.
- First-run empty-dashboard state that routes to HealthKit import.

---

## Progress log

| Date | Items | Notes |
|---|---|---|
| 2026-07-05 | — | Roadmap created from audit. |
| 2026-07-05 | 0.1–0.6 | Phase 0 complete, one commit per item (0.2+0.3 shared). 0.4 decision: KEEP noise monitoring — usage string added; recorder was also found persisting lossless audio to Documents from init, now metering-only to /dev/null behind an explicit permission request. 0.5: in-flight snoozes survive reschedules unless the owning alarm is disabled/deleted; also fixed scheduleSpecificAlarm's never-matching prefix filter and cancelAllAlarms' global wipe. New AlarmPredicateSQLiteTests passes 6/6. Pre-existing suites (EndToEnd/Reliability/RaceCondition) fail identically at the pre-change baseline commit — Core Data 132001 "recursively call -save:" from testing against PersistenceController.shared while the host app runs; that is item 2.4's scope, not a Phase 0 regression. Note: `grep -rn "id.uuidString" Zeez/` still matches 2 non-predicate serialization sites (Widget.swift, WatchCommunicationSupport.swift) — predicate-form matches are zero. |
| 2026-07-06 | 1.2, 1.7; 1.3 WIP | 1.2: UIBackgroundModes → processing only, armv7 key dropped, UILaunchScreen dict replaces phantom storyboard, time-sensitive entitlement added, critical-sound gating on scheduleBasicSnooze/scheduleTestNotification, all INFOPLIST_KEY_NSHealth* build settings removed (watch target now 0 warnings). 1.7: Option B — SmartWakeAnalyzer deleted, UI/notification copy relabeled to "Gentle Pre-Alarm", pre-alert now genuinely quieter (default sound, .timeSensitive, never critical). 1.3 WIP: "Zeez 2.xcdatamodel" created (smartWakeEnabled=NO, smartWakeWindow=30), .xccurrentversion → v2, AlarmEditView new-alarm default false — NOT yet built/tested; see HANDOVER.md. Branch pushed to origin. |
| 2026-07-06 | 1.3 | Completed and verified. Key finding: default-value-only changes don't alter Core Data version hashes, so v1 stores are **directly compatible** with model v2 — no migration runs at all; existing rows keep stored values, new rows get corrected defaults (best-case upgrade). Verified by new `CoreDataModelV2MigrationTests` (4 tests: v1-store compatibility, v1 data readable under v2, `migrateStore` round-trip for future structural hops, new-alarm defaults enabled=false/window=30). While confirming the hop, found and removed a latent data-wipe: `handleMigrationError` treated empty `NSStoreModelVersionIdentifiers` as "unversioned DB" and recreated the store — but every v1 store has an empty identifier (Xcode default), so a future structural migration would have wiped user data; 134100 now routes to `performManualMigration` (backup + lightweight migrate + swap). v2 model now carries `userDefinedModelVersionIdentifier="2"`. AlarmPredicateSQLiteTests 6/6 green. CoreDataMigrationTests: 10/12 pass; `migrationErrorRecovery` + `migrationPerformanceWithLargeDataset` fail identically at baseline c889047 (worktree-verified) → logged under 2.4. |
| 2026-07-06 | 1.5 | Enhanced pair deleted (re-grep `EnhancedWatch` clean). Gotcha found: the deleted watch Enhanced file carried **live** code — `WatchOfflineStorage`/`OfflineAction`, used by the real `WatchConnectivityManager` — extracted to `ZeezWatch Watch App/WatchOfflineStorage.swift`. Root `Shared/` added as a `PBXFileSystemSynchronizedRootGroup` compiled into BOTH app targets; models reconciled into `Shared/WatchDataModels.swift` (superset: watch copy + `qualityColor`); Core-Data-dependent init split to `Zeez/Watch/WatchSleepSummary+CoreData.swift`; duplicated `WatchMessageType`/`HapticPattern`/`WakePatternData` removed from `WatchCommunicationSupport.swift` (iOS gains their `Codable` conformance — additive). Orphaned zero-caller `Shared/AlarmGestureType.swift` deleted (part of 2.5-B). CLAUDE.md watch section updated; AGENTS.md `Shared/` claim is now actually true (2.5-F item pre-done). Both targets build, watch still 0 warnings; AlarmPredicateSQLiteTests + CoreDataModelV2MigrationTests green. NOT done: paired-simulator message round-trip (no paired sims scriptable here) — cover during device testing of 1.1. |
