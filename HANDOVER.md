# HANDOVER — Zeez roadmap execution (updated 2026-07-06, end of session 6: 2.4–2.7 done + CI green, 2.9 WIP)

Delete this file once Phase 2 is complete (move remaining device-test debts to a roadmap note).

## Where things stand

Branch: `feature/sleep-simplification`. **2.4, 2.5, 2.6, 2.7 are DONE, committed one per
item, and pushed** (f22213f cleanup sweep, d1573f7 storage hygiene, 7ab8f63 legacy
notification cleanup). CI executed green for 0373f34 (run 28831459063, 5m28s); CI results
for the 2.5–2.7 pushes were NOT checked — do that first. **2.9 is committed as WIP** —
code complete, NOT built or tested; see "2.9 remaining". ZeezTests = 147 tests / 24 suites,
last verified green ×2 at the 2.7 commit. iOS + watch targets both build 0 warnings as of
2.6. `IMPROVEMENT_ROADMAP.md` is the tracker; its progress log carries per-item detail.

## 2.9 remaining (pick up exactly here)

The working tree / WIP commit contains the complete 2.9 implementation (sentinel
`EnvironmentalReading.notMeasured = -1` + `measured*` accessors; monitor captures noise
only; 7 consumer files filter sentinels — full detail in the roadmap "2.9 WIP" row).
Remaining steps:

1. **Build iOS clean** — must be 0 warnings. The consumer edits were applied by exact
   string replacement and never compiled; expect possible small breakage (e.g. optional
   dictionary assignments in `EnvironmentalDataManager`, `compactMap` closure type
   inference in views).
2. **Sweep for missed claims:** check `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` for
   light/temperature claims (interrupted mid-check); grep UI copy in
   `Learn*Environmental*` views and `checkSensorAvailability` callers for promises of
   light/temperature monitoring; confirm `grep -rn AVCaptureDevice Zeez/` is empty.
3. **ZeezTests ×2 green** (147/24). Note the environmental scoring change
   (`averageEnvironmentalScore` now skips unmeasured) could affect any test pinning
   scores over mock readings — mock data has real values so behavior should be unchanged.
4. Check the roadmap 2.9 checkbox, replace the "2.9 WIP" progress row's remaining-steps
   note, make the final focused commit (or amend the WIP), push, verify CI.
5. **Phase 2 end state:** delete this file and move the "Open verifications needing a
   device / Daniel / App Store Connect" section below into a roadmap note.

## Architecture facts introduced by 2.4 (do not regress)

- **`PersistenceController.model`** — the ONE shared `NSManagedObjectModel`. Duplicate
  model loads re-register NSManagedObject subclasses and make `+entity` ambiguous
  ("Failed to find a unique match…"), causing 134020/133010 and a SIGSEGV in
  MockDataGenerator. Every container (production, migration manager, raw test containers)
  now takes `managedObjectModel: PersistenceController.model`. The v1 test model in
  `CoreDataModelV2MigrationTests` is loaded ONCE and neutralized
  (`managedObjectClassName = "NSManagedObject"`), so it never competes.
- **`AlarmNotificationScheduling`** gained a `criticalAlertsEnabled(completionHandler:)`
  requirement (default impl derives from `getNotificationSettings`; fakes answer directly
  because `UNNotificationSettings` can't be constructed). AlarmScheduler now resolves
  criticality via its own injected center — never via Utils statics.
- **Injection seams:** `AlarmNotificationHandler.init(notificationCenter:container:)`;
  `AlarmNotificationUtils.notificationCenter` / `.container` (STATIC — tests that swap
  them must be `.serialized` and restore previous values, see `AlarmSnoozeAndHandlerTests`);
  `AlarmObserver.init(scheduler:)`. `AlarmSnapshot.fetch` calls now pass the resolved container.
- **Shared test support** in `ZeezTests/AlarmTestSupport.swift`: `FakeNotificationCenter`
  (single definition — the nested copy in AlarmFollowUpChainTests was removed;
  NotificationBudgetTests uses it too), `AlarmTestSupport.makeAlarm`, and `waitUntil`.
  `waitUntil` (both copies — support file + AlarmFollowUpChainTests) RETURNS on success and
  never re-evaluates the predicate after a successful loop exit: remove-then-add
  rescheduling makes pending counts transiently dip, so "assert again immediately" is a
  race (this exact race was caught in `concurrentReschedulingOfTheSameAlarmDoesNotDuplicate`).
- `CoreDataMigrationManager.migrateStore` now throws typed
  `CoreDataMigrationError.storeNotFound` (new case) when the source file doesn't exist.
- `MockDataTests` range assertions now use the GENERATOR's design envelopes (HR 40–100,
  temp 16–24 °C, noise 20–55 dB) — the old bounds were the app's comfort-validation
  constants, which the mock data intentionally exceeds (awake HR spikes, day/night swing).

## Decisions already made (do not re-litigate)

- 0.4 keep noise monitoring; 0.5 reschedules keep in-flight snoozes; 1.7 Option B
  ("Gentle Pre-Alarm"); 1.1/1.4 chain sizes 6/8 next-day-only with 4-slot margin.
- **2.1:** product IDs are an explicit table in `StoreKitManager.productIDs`
  (`com.zeez.subscription.{premium,premiumplus}.{monthly,annual}`) — ⚠️ Daniel must
  confirm/create in App Store Connect ("+" was invalid in the old generated IDs).
  `.storekit` file lives at `ZeezTests/Zeez.storekit`, wired into the shared scheme's
  LaunchAction. `SubscriptionTier` compares by numeric `rank`.
- **2.3:** privacy manifests in both targets; delete-all-data keeps `subscription_tier`
  (entitlements belong to the Apple Account); privacy-policy URL in `AppConstants.Legal`
  is a PLACEHOLDER (`https://dcs617.github.io/zeez-privacy/`) pending Daniel.
- **2.2:** ZeezLogger info/error/fault are `.public`; health values/user content stay in
  debug-level logs only; store paths log `lastPathComponent`.

## Verified facts that save time

- Must-stay-green suites (all currently green): AlarmPredicateSQLiteTests(6),
  CoreDataModelV2MigrationTests(4), AlarmFollowUpChainTests(6), NotificationBudgetTests(4),
  StoreKitTests(9). Full ZeezTests bundle = 144 tests / 23 suites, ~7 s test time.
- The legacy 42F/2P failures are GONE (suites rewritten). CoreDataMigrationTests 12/12.
- Release config builds now (DashboardView referenced DEBUG-only DebugMenuView unguarded —
  fixed in 2.2; Release never compiled before that).
- `xcodebuild` prints `xcrun: error: unable to find utility "simctl"` while collecting
  diagnostics after failing runs — environmental (xcode-select → CommandLineTools), ignore.
- Crash reports land in `~/Library/Logs/DiagnosticReports/Zeez-*.ips` — the fastest way
  to identify which test crashed a runner.
- Watch target still builds 0 warnings. Zeez scheme is now a SHARED scheme file
  (`Zeez.xcodeproj/xcshareddata/xcschemes/Zeez.xcscheme`) — verify it looks right in Xcode.

## Open verifications needing a device / Daniel / App Store Connect

- 1.1 end-to-end (force-quit, locked phone → follow-ups at cadence; Stop re-arms).
- 1.5 phone↔watch round-trip. 1.4 banner visual with ~5 smart-wake alarms.
- 2.1 sandbox purchase + restore on device; airplane-mode launch keeps premium;
  product IDs vs ASC. 2.3 Organizer archive validation; manual delete-flow walkthrough;
  real privacy-policy URL.

## Environment / workflow quirks

- Build prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; iPhone 16 Pro
  iOS-18.6 sim `55075C0E-1B8E-479A-9DED-7E0E2AF0F8CF`; watch sim `Apple Watch Series 10 (46mm)`.
- All targets are Xcode 16 synchronized folder groups — new files join targets automatically.
- SourceKit phantom diagnostics ("Cannot find X in scope", "No such module Testing") are
  noise — trust xcodebuild.
- One focused commit per item, imperative subject with item number; push after each item.
- Full-suite run: `xcodebuild test … -only-testing:ZeezTests` (avoids UI tests).

## Item-specific context for the rest of Phase 2

*(2.5/2.6/2.7 context removed — those items are done; see roadmap progress log.)*

- **2.9 (WIP, see "2.9 remaining" above):** decisions already taken this session —
  camera-ISO light metric DELETED as fiction (not relabeled); temperature/humidity marked
  not-measured rather than fabricated; foreground-only sampling kept and labeled honestly
  (1.7 precedent); sentinel = `-1` with `measured*` optional accessors because the Core
  Data attributes are non-optional scalars (no model version change). Legacy rows written
  by old builds keep their fake 0s — acceptable, no external installs. FLAGGED not fixed:
  noise units fiction (normalized 0–100 stored, "dB" displayed, mock data in real dB) —
  Phase-3 candidate, listed in the 2.9 WIP roadmap row.
