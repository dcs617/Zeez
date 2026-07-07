# Zeez Improvement Roadmap

> **ARCHIVED 2026-07-07.** Phases 0, 1, and 2 are complete (all items checked; full
> detail in the progress log below). Live follow-ups — the open device/App Store Connect
> verifications and the Phase 3 nice-to-have list — now live in `FUTURE_IMPROVEMENTS.md`
> at the repo root. This file is kept as the historical record of the audit, decisions,
> and per-item progress.

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
- [x] Done *(implemented + unit-tested with a fake notification center; the physical-device end-to-end test below is still pending — no device available in this environment)*
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
- [x] Done
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
- [x] Done
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
- [x] Done *(final product IDs need Daniel's confirmation against App Store Connect — see progress log; sandbox purchase/restore on device still open)*
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
- [x] Done
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
- [x] Done *(privacy-policy URL is a placeholder pending Daniel; Organizer archive validation + manual delete-flow walkthrough still open — see progress log)*
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
- [x] Done *(full ZeezTests 144/144 green ×2 consecutively; ZeezUITests 10/10 and kept in the scheme's test action. CI executed for the first time on the 2.4 pushes — first run failed on an Xcode 16.4 type-check-budget compile error in SleepQualityCalculatorTests, fixed; see progress log for final CI status.)*
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
- [x] Done
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
- **F. Documentation truth pass:** ~~CLAUDE.md — remove `SessionValidationService` from the
  pipeline description (validation is inline in `SleepAnalyzer` now); fix the watch build
  command (Series 9 sim doesn't exist here); note the `DEVELOPER_DIR` requirement. AGENTS.md —
  correct the `Shared/` claim once 1.5 lands.~~ *(all done in the Phase-1 sessions: watch
  section + testing + Core Data threading + model versioning + build commands updated
  2026-07-06; AGENTS.md `Shared/` claim became true with 1.5)* — re-verify docs at 2.5 time.
- **G. Warning sweep** (from the audit build): dead `serverTime`/`metrics`/`modelURL`/`session`
  variables, deprecated `allowBluetooth` option in `AlarmAudioController.swift:23,51`
  (→ `.allowBluetoothHFP`), non-exhaustive switch in `BackgroundTaskManager.swift:231`,
  `objc_setAssociatedObject` timer hack in `AlarmAudioController.swift:102,118` → stored
  property. Also `PillowDataImporter.swift:83,146` unused `session` values — check they're
  not masking a missed dedup branch before deleting.

### 2.6 Core Data storage hygiene
- [x] Done *(fix 2 deviation: history tracking KEPT + pruned, not deleted — removing the key
  force-opens previously-tracked stores read-only; see progress log)*
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
- [x] Done
- **Problem:** the prefix-filtered removals from 0.5/0.6 only match the NEW identifier
  schemes. Installs that scheduled notifications on earlier builds still have pending
  requests with un-prefixed Learn identifiers (`challenge_*`, `challenge_completion_*`,
  `learning_*`, `streak_reminder_*`, `snoozed_*`) that no removal path can ever target.
- **Fix:** a one-time migration on launch (UserDefaults flag) that enumerates pending
  requests and removes the known legacy Learn patterns. Low urgency pre-TestFlight (no
  external installs exist), but must land before the first update shipped over an
  installed build.

### 2.8 `heavySleeperMode` missing from generated Core Data properties *(discovered during 0.3)*
- [x] Done *(folded into 1.6 — see progress log; AlarmDataMigrationHelper's KVC nil-checks deliberately kept: `value(forKey:)` returning nil is meaningful there for never-set optional scalars)*
- **Problem:** the attribute exists in the model (`Zeez.xcdatamodel/contents`) but not in
  `Zeez/CoreData/AlarmConfiguration+CoreDataProperties.swift`, so production reads it via
  KVC (`value(forKey: "heavySleeperMode")` in `AlarmNotificationHandler`) — stringly-typed
  and invisible to the compiler.
- **Fix:** add the `@NSManaged public var heavySleeperMode: Bool` property (or regenerate
  the class files) and replace the KVC reads. Audit the other entities for the same drift
  while there.

### 2.9 Environmental monitoring honesty check *(discovered during 0.4)*
- [x] Done
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

## Open verifications needing a device / Daniel / App Store Connect

Carried over from HANDOVER.md at Phase-2 closeout (2026-07-07). These are the only
remaining open items from Phases 0–2; all code work is complete and verified in-simulator.

- **1.1 end-to-end on a physical device:** set an alarm, force-quit the app, lock the
  phone → follow-ups fire at cadence; Stop re-arms the next chain. (Also covers the
  delegate-callback threading paths noted in the 1.6/2.8 row.)
- **1.5 phone↔watch message round-trip** (no paired simulators were scriptable in the
  dev environment).
- **1.4 banner visual check** with ~5 smart-wake alarms creating real pending-notification
  pressure.
- **2.1 StoreKit on device:** sandbox purchase + restore; airplane-mode launch keeps
  premium; product IDs confirmed/created in App Store Connect **exactly** as
  `com.zeez.subscription.{premium,premiumplus}.{monthly,annual}`.
- **2.3:** Organizer archive validation (needs signing/Xcode UI); manual walkthrough of
  the delete-all-data flow; publish the real privacy-policy URL (placeholder
  `https://dcs617.github.io/zeez-privacy/` in `AppConstants.Legal`).

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
- Environmental noise units fiction (flagged during 2.9, pre-existing): `EnvironmentalMonitor`
  stores a normalized 0–100 of `averagePower`, but the UI labels it "dB" and mock data
  generates real 20–55 dB values — pick one unit story and align monitor, UI, and mocks.

---

## Progress log

| Date | Items | Notes |
|---|---|---|
| 2026-07-05 | — | Roadmap created from audit. |
| 2026-07-05 | 0.1–0.6 | Phase 0 complete, one commit per item (0.2+0.3 shared). 0.4 decision: KEEP noise monitoring — usage string added; recorder was also found persisting lossless audio to Documents from init, now metering-only to /dev/null behind an explicit permission request. 0.5: in-flight snoozes survive reschedules unless the owning alarm is disabled/deleted; also fixed scheduleSpecificAlarm's never-matching prefix filter and cancelAllAlarms' global wipe. New AlarmPredicateSQLiteTests passes 6/6. Pre-existing suites (EndToEnd/Reliability/RaceCondition) fail identically at the pre-change baseline commit — Core Data 132001 "recursively call -save:" from testing against PersistenceController.shared while the host app runs; that is item 2.4's scope, not a Phase 0 regression. Note: `grep -rn "id.uuidString" Zeez/` still matches 2 non-predicate serialization sites (Widget.swift, WatchCommunicationSupport.swift) — predicate-form matches are zero. |
| 2026-07-06 | 1.2, 1.7; 1.3 WIP | 1.2: UIBackgroundModes → processing only, armv7 key dropped, UILaunchScreen dict replaces phantom storyboard, time-sensitive entitlement added, critical-sound gating on scheduleBasicSnooze/scheduleTestNotification, all INFOPLIST_KEY_NSHealth* build settings removed (watch target now 0 warnings). 1.7: Option B — SmartWakeAnalyzer deleted, UI/notification copy relabeled to "Gentle Pre-Alarm", pre-alert now genuinely quieter (default sound, .timeSensitive, never critical). 1.3 WIP: "Zeez 2.xcdatamodel" created (smartWakeEnabled=NO, smartWakeWindow=30), .xccurrentversion → v2, AlarmEditView new-alarm default false — NOT yet built/tested; see HANDOVER.md. Branch pushed to origin. |
| 2026-07-06 | 1.3 | Completed and verified. Key finding: default-value-only changes don't alter Core Data version hashes, so v1 stores are **directly compatible** with model v2 — no migration runs at all; existing rows keep stored values, new rows get corrected defaults (best-case upgrade). Verified by new `CoreDataModelV2MigrationTests` (4 tests: v1-store compatibility, v1 data readable under v2, `migrateStore` round-trip for future structural hops, new-alarm defaults enabled=false/window=30). While confirming the hop, found and removed a latent data-wipe: `handleMigrationError` treated empty `NSStoreModelVersionIdentifiers` as "unversioned DB" and recreated the store — but every v1 store has an empty identifier (Xcode default), so a future structural migration would have wiped user data; 134100 now routes to `performManualMigration` (backup + lightweight migrate + swap). v2 model now carries `userDefinedModelVersionIdentifier="2"`. AlarmPredicateSQLiteTests 6/6 green. CoreDataMigrationTests: 10/12 pass; `migrationErrorRecovery` + `migrationPerformanceWithLargeDataset` fail identically at baseline c889047 (worktree-verified) → logged under 2.4. |
| 2026-07-06 | 1.5 | Enhanced pair deleted (re-grep `EnhancedWatch` clean). Gotcha found: the deleted watch Enhanced file carried **live** code — `WatchOfflineStorage`/`OfflineAction`, used by the real `WatchConnectivityManager` — extracted to `ZeezWatch Watch App/WatchOfflineStorage.swift`. Root `Shared/` added as a `PBXFileSystemSynchronizedRootGroup` compiled into BOTH app targets; models reconciled into `Shared/WatchDataModels.swift` (superset: watch copy + `qualityColor`); Core-Data-dependent init split to `Zeez/Watch/WatchSleepSummary+CoreData.swift`; duplicated `WatchMessageType`/`HapticPattern`/`WakePatternData` removed from `WatchCommunicationSupport.swift` (iOS gains their `Codable` conformance — additive). Orphaned zero-caller `Shared/AlarmGestureType.swift` deleted (part of 2.5-B). CLAUDE.md watch section updated; AGENTS.md `Shared/` claim is now actually true (2.5-F item pre-done). Both targets build, watch still 0 warnings; AlarmPredicateSQLiteTests + CoreDataModelV2MigrationTests green. NOT done: paired-simulator message round-trip (no paired sims scriptable here) — cover during device testing of 1.1. |
| 2026-07-06 | 1.6, 2.8 | New `AlarmSnapshot` struct (Zeez/Alarm/AlarmSnapshot.swift): snapshot taken inside `context.perform`, everything downstream Core-Data-free. `AlarmScheduler` schedule paths rewritten to snapshots; both `DispatchSemaphore` waits deleted (ordering now chained inside notification-center callbacks). `AlarmNotificationHandler`: follow-up settings + heavy-sleeper check via `AlarmSnapshot.fetch` on a background context; `presentActiveAlarmUI` hops to main before touching viewContext. `AlarmNotificationUtils.scheduleSnooze` same treatment. 2.8 folded in: `@NSManaged heavySleeperMode` added, KVC wrapper deleted (UserDefaults fallback obsolete — launch-time migration covers it); HeavySleeperToggleView keeps `modifiedAt` fresh in `saveChanges`. **ConcurrencyDebug verification found a pre-existing crash outside the alarm stack:** `UserPatternAnalyzer.analyzeUserPatterns` fetched viewContext from `BackgroundTaskManager`'s queue — app died at startup on every `-com.apple.CoreData.ConcurrencyDebug 1` launch; fixed with `performAndWait` on a background context. Verified in sim under the flag: startup, onboarding UI, MainView dashboard, and the full-reschedule path (log-confirmed) run with **zero multithreading assertions**. Delegate-callback paths (follow-up/snooze/present-UI) are Core-Data-free by construction but not runtime-fired this session — cover during 1.1 device testing. AlarmPredicateSQLiteTests + CoreDataModelV2MigrationTests green; watch target still 0 warnings. |
| 2026-07-06 | 1.1 | Follow-up chains now armed at **scheduling time** in `AlarmScheduler.scheduleFollowUpChain(for:)`: next-firing-day only (via new `AlarmSnapshot.nextFireDate()`), 6 normal / 8 heavy-sleeper one-shot `UNCalendarNotificationTrigger`s at `nextFire + n×cadence`, IDs `alarm-<uuid>-fu-pre-…` (matched by all existing `fu-` cancel paths). Snoozes pre-arm their own chain (`-fu-snz-…`) so a snooze firing with the app killed still escalates. Foreground fires: `handleNotificationArrived` removes any pre-armed chain before scheduling the dynamic one (no double-fire); `willPresent` now presents ActiveAlarmView + starts looped audio for `type == "main"` (audit 8.7). Stop action re-arms the next chain via `rearmFollowUpChain` (works from background activation). Re-arm also happens on every reschedule (launch, edits, significantTimeChange). New `AlarmNotificationScheduling` protocol + injected center (pre-does 2.4 step 1); new `AlarmFollowUpChainTests` 6/6 green with an in-memory fake (chain counts, cadence windows, next-day-only, replace-not-stack, disabled-alarm, nextFireDate). Mains scheduled before chains (1.4 ordering). **Pending:** physical-device end-to-end (set alarm, force-quit, locked phone → follow-ups at cadence) — cannot run in this environment. |
| 2026-07-06 | 2.1 | StoreKit correctness. `restorePurchases` no longer swallows `AppStore.sync()` failures; entitlements now map tiers straight from `transaction.productID` (offline launch can't persist a wrongful downgrade); `SubscriptionTier` got an explicit numeric `rank` + `Comparable` (raw values are display strings — never compare them). Product IDs are now an explicit table in `StoreKitManager.productIDs` with exact-match lookup, fixing the contains-matching bug (premium_plus IDs *contain* "premium") — **and** the old generated IDs were `com.zeez.subscription.premium+.monthly` ("+" is not a valid ASC product-ID character, so the premium_plus IDs never could have worked). **Final IDs — ⚠️ Daniel must confirm/create these in App Store Connect exactly:** `com.zeez.subscription.premium.monthly`, `.premium.annual`, `.premiumplus.monthly`, `.premiumplus.annual`. Bigger find: `SubscriptionView.subscribe()` was a **fake** (1s sleep, then granted the tier without payment) and restore called an empty `PremiumManager.restorePurchases()` stub — both now go through `StoreKitManager` with error alerts; prices prefer `product.displayPrice`. New `ZeezTests/Zeez.storekit` (4 products, one group, Premium+ level 1/Premium level 2) wired into a new **shared scheme** `Zeez.xcscheme` (LaunchAction StoreKit config; testables = ZeezTests + ZeezUITests, mirroring the autogenerated scheme — verify it looks right when next opened in Xcode). New `StoreKitTests` 9/9 green **including live SKTestSession flows**: purchase grants tier, entitlement resolves with products unloaded (offline regression), upgrade resolves to highest tier, expiry downgrades, cached tier survives reload. NOT possible here: sandbox purchase + restore on device, airplane-mode launch — device session. Must-stay-green suites all pass; watch target still 0 warnings. |
| 2026-07-06 | 2.4 WIP | Injection extended per plan: `AlarmNotificationScheduling` gained `criticalAlertsEnabled` (default impl; fakes answer directly since `UNNotificationSettings` can't be constructed); `AlarmNotificationHandler.init(notificationCenter:container:)`; `AlarmNotificationUtils` static `notificationCenter`/`container` seams; `AlarmObserver.init(scheduler:)`; scheduler criticality now via its own injected center. Legacy suites REWRITTEN hermetic (in-memory store + shared `FakeNotificationCenter` + confirmation waiting, current ID scheme): AlarmEndToEndTests (10), AlarmReliabilityTests (9), AlarmRaceConditionTests (3, incl. observer-debounce via injected scheduler); new AlarmSnoozeAndHandlerTests (5, serialized static-seam swap), SleepQualityCalculatorTests (6: weights sum to 1, missing-data defaults, duration bands, fragmentation, count-vs-duration limitation pinned), WatchModelRoundTripTests (5: Codable round-trips + wire raw-value stability). CoreDataMigrationTests both pre-existing failures fixed: `migrateStore` now throws typed `.storeNotFound` (was NSCocoaErrorDomain 260); perf-test SIGABRT was off-main viewContext access → wrapped in `performAndWait`. **Two systemic flake classes root-caused:** (1) duplicate `NSManagedObjectModel` loads made `+entity` ambiguous → 134020/133010/SIGSEGV; all containers now share `PersistenceController.model`, v1 test model neutralized. (2) Swift Testing runs off-main; unguarded main-queue viewContext use races the main runloop → crashes/empty fetches; `performAndWait` sweep applied to ~7 files (4 files remain — listed in HANDOVER). Also fixed: `waitUntil` no longer re-evaluates after success (remove-then-add counts transiently dip — caught by the new race test); MockDataTests bounds aligned to generator envelopes (old bounds used comfort constants, failed systematically). CI workflow authored at `.github/workflows/tests.yml` (**never executed yet**). Full bundle = 144 tests/~7s; last 4 runs: P/F/P/F with both Fs traced (one fixed, one = StoreKit shared-session TODO). |
| 2026-07-06 | 2.3 | Privacy scaffolding. `PrivacyInfo.xcprivacy` added to BOTH targets (verified present in both built .app bundles): no tracking, empty collected-data (nothing leaves the device), accessed-API declarations — iOS: UserDefaults CA92.1 + DiskSpace E174.1 (ResourceMonitor); watch: UserDefaults CA92.1 (WatchOfflineStorage). New Settings "Privacy & Data" section: privacy-policy link (**placeholder URL `https://dcs617.github.io/zeez-privacy/` in `AppConstants.Legal` — Daniel must publish the policy and confirm/replace**), version/build row, and "Delete All My Data" with destructive confirmation → `clearAllData()` + UserDefaults wipe (subscription_tier deliberately survives — entitlements belong to the Apple Account) + full notification wipe (justified here, unlike 0.5/0.6 routine paths) + `OnboardingManager.reset()` so RootView returns to onboarding immediately. HealthKit importer trimmed 8→3 read types (sleepAnalysis, heartRate, respiratoryRate — exactly what's mapped; now identical to onboarding's set). Unused `healthkit.background-delivery` entitlement removed (no `enableBackgroundDelivery` anywhere). Hardened StoreKitTests entitlement assertions with confirmation-based waiting after a parallel-suite flake (`expireSubscription` applies async); combined suites 30/30 ×3 consecutive. NOT verifiable here: Organizer archive validation (needs signing/Xcode UI) and a hands-on walkthrough of the delete flow (UI driving) — fold both into the device/App Store session. |
| 2026-07-06 | 2.2 | `ZeezLogger.info/error/fault` now interpolate with `privacy: .public` (debug unchanged — stripped in release). Call-site sweep before making them public: sleep session times/windows, stage distribution, and quality scores demoted to `ZeezLogger.debug` (health data, DEBUG-only); user-entered alarm names replaced with alarm UUIDs or moved to debug (AlarmScheduler, AlarmEditView, ActiveAlarmView, AlarmDataMigrationHelper, AlarmConfiguration+Extensions); user audio filename moved to debug; store paths now log `lastPathComponent` only (drops container UUIDs). Also fixed while sweeping: 6 direct-`Logger` wrapper bypasses (SleepAnalyzer, SleepStageAnalyzer, SleepQualityCalculator, SleepControlView ×3, WakeUpProgressionManager) that stayed `<private>` in release; a literal `\\(granted)` string bug in AlarmPermissionManager; and a **pre-existing Release-config build break** — `DashboardView` referenced the `#if DEBUG`-only `DebugMenuView` unguarded, so Release never compiled (sheet now DEBUG-gated). Verified per roadmap: Release build in sim + `log stream --level info` → all Zeez messages readable, 0 `<private>`, no health values in stream. Must-stay-green suites + StoreKitTests 30/30; watch 0 warnings. |
| 2026-07-06 | 2.4 | Completed (WIP → done). Finished the viewContext-confinement sweep: `SleepScorePresentationTests` rewritten on the `withInMemoryContext` pattern (controller retained, all Core Data work inside `performAndWait`), `SleepStageNormalizationTests.stagePercentsEquivalentAcrossCasings`, both `OnboardingTests` persistence tests, and both `CoreDataModelTests` tests wrapped. `StoreKitTests` now uses ONE shared static `SKTestSession` (per-test sessions churned the local StoreKit-test server — one full run flaked with ASDErrorDomain 500 / AMS 400); each test does `resetToDefaultState()` + `disableDialogs` + `clearTransactions()`. Full `-only-testing:ZeezTests` plan: **144 tests / 23 suites green twice consecutively** (~6–9 s test time), re-verified ×2 after the app fix below. ZeezUITests run for the first time: 4/10 failed with "multiple matching elements" — root cause was a REAL app bug, not test flake: `SceneDelegate.willConnectTo` built a second `UIWindow` + `RootView` on top of the SwiftUI `WindowGroup` window (Info.plist declares `UISceneDelegateClassName`), so the entire live UI existed twice (double view hierarchy + @FetchRequests since the reorg). Manual window creation removed — SceneDelegate is lifecycle-hooks-only now. `MainViewUITests.testSleepTabLoads` also hardened (data-dependent anchor → fixed "Sleep Metrics" header, `waitForExistence`). **ZeezUITests now 10/10** — kept in the shared scheme's test action; CI still runs `-only-testing:ZeezTests`. CI (`tests.yml`) executed for the FIRST time on the 2.4 WIP/final pushes: the Xcode-path step worked (picked Xcode 16.4), but the run failed with a compile error only under 16.4's stricter type-check budget — the mixed Int/Double literal weights expression in `SleepQualityCalculatorTests` ("unable to type-check in reasonable time"); split into explicit `Double` terms. Watch target 0 warnings. |
| 2026-07-06 | 1.4 | New `NotificationBudget` (Zeez/Alarm/NotificationBudget.swift): categorizes pending requests by identifier scheme (mains / follow-ups / snoozes / other) against the 64 cap. `AlarmScheduler.scheduleFollowUpChain` now gates on `canFit` (keeps a 4-slot safety margin) — a chain that would blow the budget is skipped and logged; mains schedule first and are never displaced by chains. Post-reschedule audit log (`logNotificationBudget`). `AlarmSettingsView` shows an accessibility-labeled warning banner when within 10 of the cap (refreshes on appear + alarm-count change). `NotificationBudgetTests` 4/4 green with synthetic request lists + the fake center (categorization, near-cap boundary, margin math, chain-skipped-but-main-schedules under a tight budget). NOT run: the 5-smart-wake-alarms×7-days manual sim test (needs UI driving) and banner visual check — both need real pending pressure; covered logically by the gate test. |
| 2026-07-06 | 2.4 CI | CI verified green: run 28831459063 for 0373f34 (`Fix CI-only compile error in SleepQualityCalculatorTests`) completed **success** in 5m28s on GitHub Actions — first fully green CI run. The two earlier failures (28816980737, 28831317458) were the pre-fix Xcode 16.4 type-check-budget compile error, as diagnosed. 2.4 fully closed. |
| 2026-07-06 | 2.5 | Cleanup sweep. A: `SessionValidationService.swift` deleted (+ its `SessionValidator` protocol — zero external refs re-verified); SmartWakeAnalyzer already gone (1.7), `EnhancedWatch` survives only as a comment. B: root `MockDataTestScript.swift`, `PreviewData.swift`, `Scripts/convert_print_to_logging.py` deleted; empty `Zeez/Models/` + `Scripts/` dirs removed. C: iOS target now 100% print-free — ModalCoordinator prints → `ZeezLogger.debug(.ui)`, AlarmSounds → error logs, #Preview stubs emptied (watch target still has ~6 prints; ZeezLogger is not compiled into the watch target — acceptable, noted). D: placeholder modal cases (`.healthKitError`/`.settings`/`.debug`) deleted from ModalCoordinator + RootView (only `.dataImport` was ever presented). E: `Notification.Name` statics in new `Zeez/Shared/NotificationNames.swift` (showActiveAlarm/alarmPermissionDenied/modalDismissed, 7 call sites); `AppConstants.DataProvenance` centralizes deviceIdentifier markers (HealthKit/Pillow/Mock + legacy "iPhone", 8 files; BackgroundTaskManager predicate now parameterized). F: CLAUDE.md pipeline line fixed, shared-scheme/StoreKit-config facts added to Dev Commands; AGENTS.md watch sim Series 9→10 + DEVELOPER_DIR note. G: clean build had exactly 14 warnings — ALL fixed, now **0 warnings**: allowBluetooth→allowBluetoothHFP ×2; `objc_setAssociatedObject` timer hacks → stored/@State property in AlarmAudioController AND ActiveAlarmView (the latter was a real bug: associating on a struct boxes a fresh object per call, so the vibration timer could never be retrieved — vibration-only alarms vibrated forever after dismiss); AlarmScheduler `final + @unchecked Sendable` + components-var snapshot; SleepAnalyzer `: Sendable`; BackgroundTaskManager fetch request built inside `context.perform` + new `.immediateRunIneligible` case (Xcode 26 SDK); dead `modelURL`/`metrics` removed (audit-listed `serverTime` no longer existed); PillowDataImporter unused `session` values → `!= nil` after confirming dedup lives INSIDE `createSessionFrom*` via `sessionExists` (no masked dedup branch — roadmap concern cleared). Verified: iOS clean build 0 warnings, watch build 0 warnings, ZeezTests 144/144 green ×2 consecutively. |
| 2026-07-06 | 2.6 | Core Data storage hygiene. Pragmas block deleted (journal_mode=DELETE was disabling WAL; auto_vacuum-via-pragma ineffective) — default WAL now applies; SQLite migrates journal mode automatically on open. **Fix-2 decision deviates from the roadmap text:** history tracking KEPT + pruned rather than deleted — the roadmap claim "deleting the option on an existing store is safe" is wrong: Core Data force-opens a previously-tracked store READ-ONLY when the key is omitted (the exact "Store opened without NSPersistentHistoryTrackingKey…" warning seen when migration-test stores reopen), which would have bricked saves on every existing install. Instead: new `purgePersistentHistory(olderThan:in:)` + `BackgroundTaskManager.performStorageMaintenance` prunes history >7 days and batch-deletes `AnalyticsEvent`/`FeatureAccessRecord` rows >90 days (fix 5), serialized ahead of backlog work in the processing task; retention constants in `AppConstants.Background`. Singleton enforced: `init(inMemory:)` default value removed so accidental `PersistenceController()` no longer compiles (audit: every existing call site already passed `inMemory: true` explicitly; `LearnContentLoader` scratch container documented as deliberate). `handleMigrationFallback` now sets a UserDefaults flag (`migrationDataLossNoticeKey`) and RootView shows a one-time "Sleep History Unavailable — a backup was kept" alert (fix 4, replaces silent data loss). Verified: build 0 warnings, ZeezTests 147/147 ×2 (incl. 2.7 suite). NOT verifiable here: a real failed-migration → alert end-to-end (needs a corrupted store on device); the alert path is trivial flag-read UI. |
| 2026-07-06 | 2.7 | One-time legacy notification cleanup. New `Zeez/Learn/LegacyNotificationCleanup.runOnce()` called from `ZeezApp.setupApp()` after AlarmDataMigrationHelper: behind a UserDefaults flag, enumerates pending requests and removes identifiers with the pre-0.6 un-prefixed Learn patterns (`challenge_*` — which also covers `challenge_completion_*` — `learning_*`, `streak_reminder_*`, `snoozed_*`). Safe by construction: every current identifier carries a `learn-`/`alarm-`/`snooze-` prefix, so plain prefix matches can only hit legacy requests. Injectable via the existing `AlarmNotificationScheduling` seam; new `LegacyNotificationCleanupTests` (3 tests: removes-only-legacy against a mixed pending set, one-shot semantics, flag set even when nothing to remove) using `FakeNotificationCenter` + throwaway UserDefaults suites. Flag is set synchronously before the async enumeration (UserDefaults is non-Sendable and cannot cross into the callback) — if the process dies in that window the stale requests persist exactly as if the cleanup never ran, acceptable pre-TestFlight. ZeezTests now 147 tests / 24 suites, green ×2 consecutively. |
| 2026-07-06 | 2.9 | Environmental honesty — completed and verified 2026-07-07 (see closeout row). Design: `EnvironmentalReading.notMeasured = -1` sentinel + `measured*` optional accessors (new `Zeez/Environment/EnvironmentalReading+Measured.swift`; attributes are non-optional scalars, no model change). `EnvironmentalMonitor`: camera-ISO `captureLightLevel()` DELETED (fiction — `device.iso` is static without a running capture session; removes all AVCaptureDevice use, mooting the NSCameraUsageDescription question), hardcoded-0 `estimateRoomTemperature()` DELETED; real captures store noise (mic metering) + sentinel for light/temp/humidity; mic-denied stores sentinel not fake 0; `checkSensorAvailability` mic-only; class doc + status text state the honest scope (foreground-only Timer — decided per 1.7 relabel precedent, no background sampling claim). Consumers updated to filter sentinels: EnvironmentalAnalyzer (compactMap → measured*), EnvironmentalDataManager (per-metric averages, fixes pre-existing NaN on empty results; historical series skip unmeasured), AverageEnvironmentalReadingView (optional averages + "No environmental measurements" empty state), EnvironmentalDataView (charts/tiles per-metric conditional), EnvironmentalFactors (chartPoints/measuredValue), SleepSession+Extensions.averageEnvironmentalScore (skips unmeasured — was penalizing temp=0 as "too cold" and humidity=0 as "too dry" on every real reading), EnhancedSleepDetailsView (omits unmeasured rows). SleepRecommendationSystem left as-is (its `> threshold` filters exclude -1 by construction). Mock generators emit real values — pass through unchanged. Flagged follow-up (NOT addressed, pre-existing): noise UNITS fiction — monitor stores normalized 0–100 of averagePower but UI labels it "dB" and mock data generates real 20–55 dB; moved to the Phase 3 list. |
| 2026-07-07 | 2.9 closeout + CI | **CI outcomes for the four pushes checked (first action this session): f22213f, d1573f7, 7ab8f63 (2.5–2.7) all FAILED CI** — despite genuinely green local suites — plus the 2.9 WIP push, all with one cause: 2.5's zero-warnings sweep renamed `.allowBluetooth` → `.allowBluetoothHFP`, which only exists in the Xcode 26 SDK; CI's Xcode 16.4 fails SwiftCompile at `AlarmAudioController.swift:24,52`. Fixed with a `#if compiler(>=6.2)` gate (warning-free on both toolchains), committed as its own 2.5 follow-up. A second identical drift surfaced on the next CI run: `BGTaskScheduler.Error.Code.immediateRunIneligible` (also from the 2.5 sweep; on Xcode 16 the case falls into `@unknown default`) — same gate applied. **CI verified green: run 28841956100 (3m35s) at the final branch head.** Lesson recorded: when silencing deprecation warnings under the local Xcode 26, confirm the replacement symbol exists in CI's Xcode 16 SDK or gate on compiler version. 2.9 verification: iOS **clean build 0 warnings** (the string-replaced consumer edits compiled as written, no fixups needed); claims-doc sweep completed (the interrupted check's light/temperature matches are all sleep-*stage* rows — no environmental-monitoring claims); `grep -rn AVCaptureDevice Zeez/` empty; `LearnEnvironmentalDetailView` purely educational. Sweep additions: `LearnEnvironmentalImpactView` dead private members deleted (~150 lines incl. a 30 s timer and `updateCurrentValue` that displayed `optimalRange.min` as a live "current reading" when nothing was measured — the live body was already honest); `EnvironmentalDataManager` orphaned `getLatestReadings`/`getAverageReadings`/`getOptimalityScore`/`getRecommendations` deleted (only `getHistoricalData` has a live caller); `SleepControlView.prepareSession` no longer refuses to start a sleep session when mic permission is denied — permission is still requested up front, but monitoring now degrades to not-measured sentinels per the 2.9 design instead of blocking sleep tracking entirely. ZeezTests **147/24 green ×2**; watch target 0 warnings. History note: WIP 928170a was folded into the final 2.9 commit (force-push with lease). |
