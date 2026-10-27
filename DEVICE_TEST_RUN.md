# Zeez — Device Test Run

**Temporary file.** Delete it when the run is finished and the findings have been folded into
`SECOND_AUDIT_IMPROVEMENTS.md` §5 and `FUTURE_IMPROVEMENTS.md`.

Hardware: iPhone 13 Pro Max + paired Apple Watch. Branch `feature/sleep-simplification`.
Baseline at start of run: 352 tests / 55 suites green (2026-10-27, after D2), UI smoke 10/10, iOS + watch
targets build.

---

## How to use this file

Work top to bottom. **T0 must come first** and **T1 must be the very first launch** of the new build —
it tests a one-time migration and you only get one shot per install.

Each test has a **Result** line and a **Notes** box. Fill them in as you go. Leave failures in place;
don't fix anything mid-run. A run where three things fail is a *successful* run.

Tests marked **[SIM OK]** don't need the phone. Do those while waiting for hardware if you like.

### How to report back to me

For each failure, paste:

1. The test ID (`T5.3`) and what you actually saw versus what the file said to expect.
2. **Log lines** — see [Appendix A: reading the logs](#appendix-a--reading-the-logs). This matters more
   than a description. Copy the 20 lines around the moment it went wrong, not just the error.
3. Whether it reproduces on a second attempt, and whether it reproduces in the simulator.

If something crashes: Xcode → Window → Devices and Simulators → your phone → View Device Logs. Find the
crash by timestamp, right-click → Export, and tell me the top 10 frames of the crashing thread.

**The three failure modes to watch for**, in order of how easily they're missed:

- **Silent.** Nothing appears, nothing errors. Almost every one of the checks below has a silent variant,
  called out explicitly per test. These are the dangerous ones — an empty screen looks like "no data yet",
  not like a bug.
- **Fault-level log with a working UI.** The app looks fine and is quietly telling you it's broken. The
  App Group check (T1) is exactly this. Always have Console open.
- **Loud.** A crash or a visible error. These are the easy ones.

---

## T0 — Prerequisites (do this before anything else)

**Goal:** get a signed build with the App Group entitlement onto the phone. Nothing else in this file
works until this does.

1. Open `Zeez.xcodeproj` in Xcode. Select the **Zeez** target → **Signing & Capabilities**.
2. Confirm **Automatically manage signing** is on and Team = `QQH4V4JLV5`.
3. Click **+ Capability** → **App Groups**. Add (or tick) `group.com.danielsparano.zeez`.
   - It's already written into `Zeez/Zeez.entitlements`. The point of doing it through the UI is that
     Xcode registers the group with Apple and regenerates the provisioning profile. Editing the file by
     hand does not.
4. Plug in the phone, select it as the destination, **Product → Run**.

**Expected:** builds, installs, launches.

**If signing fails here, stop and tell me.** Symptoms: "Provisioning profile doesn't include the
`com.apple.security.application-groups` entitlement", or the group shows a red warning triangle. Don't
work around it by deleting the capability — that silently reverts D3a and I need to know.

**Silent failure to watch for:** the build succeeds but the entitlement wasn't embedded. Verify:

```bash
# with the phone connected, after a successful Run
codesign -d --entitlements :- --xml \
  ~/Library/Developer/Xcode/DerivedData/Zeez-*/Build/Products/Debug-iphoneos/Zeez.app 2>/dev/null \
  | plutil -p -
```
You must see `com.apple.security.application-groups` in the output. If you only see `{}`, the entitlement
was stripped and every result in T1 is meaningless.

> ⚠️ Note: `xcodebuild` from the terminal **always** strips these entitlements. Only builds started from
> Xcode's UI carry them. Don't test T1 with a command-line build.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T1 — Core Data store relocation into the App Group (D3a) and model v3 migration (§8a)

**Goal:** prove that an existing install's sleep history survives the move to the group container
**and** the upgrade to Core Data model v3, which both happen on the same first launch.
Each is **one-time**. Once they run, they never run again on that install.

`ade6f20` predates both D3a and model v3, so T1.2's launch first relocates the v2 store, then migrates
it to v3 in place. Relocation copies the store as-is, so the migration happens in the group container.
This is the store's first ever structural migration (v1→v2 only changed defaults), so it is the first
time that path runs on a device.

**This is the single most destructive thing in the codebase right now.** If it's wrong, users lose
everything, and the failure is silent — the app opens to an empty dashboard that looks like a fresh install.

### T1.1 — Set up an "old" install with data

```bash
cd /Users/daniel/Documents/AppProjects/Zeez
git stash list                      # make sure you have nothing uncommitted
git checkout ade6f20                # the commit before D3a
```
Now **Run from Xcode onto the phone**. In the app: Dashboard → 🐞 debug button (bottom of the scroll) →
**Generate New Mock Data** with **90 Days**. Wait for the spinner to finish.

Confirm on the dashboard that metric cards and a recent-sleep banner are showing. Note the numbers:

**Sessions/metrics before migration:**
```


```

### T1.2 — Upgrade to the new build

```bash
git checkout feature/sleep-simplification
```
**Run from Xcode again** (do *not* delete the app first — deleting destroys the data container and the
whole point of this test).

Watch **Xcode's own console pane** for this one — the app isn't force-quit, so the debug session stays
attached and Xcode shows every level without configuration. If you'd rather use Console.app, you *must*
first tick **Action → Include Info Messages**, or the success line is invisible (see
[Appendix A](#appendix-a--reading-the-logs)).

**Expected — pass:**
- Exactly one log line, category `CoreData`: `Relocated the Core Data store into the App Group container`
- Then, in this order, still `CoreData`:
  `Migration compatibility check - compatible: false, …`,
  `Migration backup created at Zeez.sqlite.migration-backup-<timestamp>`,
  `Migration required - backed up the store to …, migrating automatically`,
  `Core Data store loaded successfully`
- The dashboard shows the same data as in T1.1.

**Expected — the migration fell back:** `Core Data failed to load` followed by
`Attempting migration recovery` means automatic migration failed and the manual path ran. If the data
is still there it worked, but tell me — that path should not be needed for this change. If you instead
see the one-time "your history could not be migrated" notice, the fallback moved the store aside as
`Zeez.sqlite.corrupted-<timestamp>` and the pre-migration backup is next to it. **Don't delete the app.**

**Expected — the silent failure:** the dashboard is empty and shows `DashboardEmptyStateCard`
("No Sleep Data Yet"). That means the store didn't come across. **Do not tap anything, do not delete the
app** — capture the log and tell me. The old store may still be recoverable.

**Expected — the loud-but-quiet failure:** a `fault`-level line reading
`App Group container is unreachable but this install previously adopted it`. That means the entitlement
was dropped between builds. Release blocker. Go back to T0.

**Also possible:** `App Group container unavailable — keeping the app-container store`. This is the
*graceful* path — data is safe, but the group wasn't reachable, so T0 didn't take. Not a data bug; a
signing bug.

### T1.3 — Confirm it doesn't run twice

Force-quit and relaunch.

**Expected:** neither the `Relocated…` line nor any `Migration required…` line appears again. Data still present.
If either appears twice, the first run didn't finish its job — tell me.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T2 — First-run empty state → import (B11)

**Goal:** confirm the first screen has a route to the one action that produces data.

Mostly covered by CI now (`MainViewUITests.testFirstRunDashboardShowsEmptyStateAndOpensImporter`), so this
is a visual/Dynamic-Type check rather than a functional one.

1. Delete Zeez from the phone. Run from Xcode. Complete onboarding.
2. Dashboard should show **"No Sleep Data Yet"** with an **Import from Apple Health** button, and *no*
   empty metric cards.
3. Tap it. The importer sheet appears, titled **Import Your Sleep Data**.
4. Dismiss. Settings → check nothing claims "Using your real sleep data".

**Silent failure:** a grid of metric cards showing `0` / `--`. That's the pre-B11 behavior and would mean
`hasAnySleepData` is wrong.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T3 — HealthKit import of a real Apple Watch night

**Goal:** the import path against real data, not mocks. Needs at least one night slept wearing the watch.

1. Settings → Sleep Data → **Import Sleep Data**. Tap **Import from Apple Health**.
2. Grant the HealthKit prompt. **Check the prompt lists exactly three types**: Sleep Analysis, Heart Rate,
   Respiratory Rate. If it asks for **Resting Heart Rate**, B13 regressed — tell me.
3. Wait for completion.

**Expected:** a completion message naming the per-type outcomes (B10) — sessions imported, and for heart
rate and respiratory *either* a reading count, *or* "none recorded", *or* "not available on this device",
*or* "could not be imported". It must not just say "imported N sessions".

4. Open the imported session. Check:
   - Stage names carry **"Reported by Apple Health"** provenance, not "Experimental Zeez-estimated stages".
   - If your watch reported `asleepUnspecified`, it appears as its own row — not silently folded into Light.
   - **No Zeez score is shown.** Apple-reported sessions are deliberately never scored (spec §2). A score
     here is a claims violation, not a feature.
   - The **Recorded Inputs** card at the bottom lists all seven inputs. Sleep stages, time asleep and
     in-bed say "Reported by Apple Health"; heart rate and respiratory give a sample count or "Not
     recorded", and must agree with the import's completion message.
5. Open **Trends** (Sleep tab → **Sleep Trends**, under Weekly Progress; reconnected 2026-10-26). Check that the
   top card reads "Recorded on N of the last 7 nights" with the N you actually have, and that the Experimental
   Zeez Estimate card shows **no number and no chart**, not 0, for a week of Apple Health nights (they are never
   scored). The rest of Trends is T15.2.

**Silent failures:** the import reports success while heart rate silently failed (that's exactly what B10
was meant to end — if the message doesn't name HR, the reporting broke); or an Apple session shows a
score.

### T3.1 — Re-import picks up changes, and duplicates nothing (§8a)

Re-import used to skip any night whose start was within 15 minutes of an earlier import, so a night Apple
Health changed was never updated, and one that moved further was stored twice. It now reconciles nights by
HealthKit sample id. Do these in order, after T3 — **only data imported by this build carries sample ids**,
so a night imported by an older build can be updated but not have its deletions applied.

Note the number of nights in the session list before you start.

1. **Unchanged.** Import again straight away. **Expected:** "✅ Already up to date…". Same nights, none
   doubled. (The old build said "No sleep data found" here.)
2. **Extended earlier.** Health app → Browse → Sleep → **Add Data** → an "In Bed" entry that starts
   **30 minutes before** one of your imported nights and ends inside it. Import. **Expected:** "Updated 1
   sleep session that changed in Apple Health". That night now starts 30 minutes earlier and is still
   **one** session — not two overlapping ones.
3. **Deleted.** Health app → Sleep → **Show All Data** → delete the entry you added in step 2. Import.
   **Expected:** "Updated 1 sleep session…", and the night's start goes back to where it was.
4. **Whole night deleted** (optional — it removes real data from Health). Delete every sample of one
   night in Show All Data, then import. **Expected:** "Removed 1 sleep session deleted in Apple Health",
   and that night is gone from Zeez.
5. **Access revoked.** Settings → Health → Data Access & Devices → Zeez → turn **Sleep** off. Import.
   **Expected:** nothing is removed or changed in Zeez. Turn Sleep back on afterwards.

**Logs** (`CoreData`, info): `HealthKit reports N sleep sample(s) deleted since the last import` (absent on the
very first import), then `HealthKit import: N night(s) fetched, a new, b updated, c removed`.

**Silent failures:** a night appearing twice after step 2; a night shrinking or vanishing after step 5 (absence
must never be treated as deletion); "No sleep data found" in step 1.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T4 — Score behaviour (B8)

**Goal:** the "Experimental Zeez Estimate" only appears when it's earned, and says so.

1. Record a session in the app: Sleep tab → start → wait **≥ 30 minutes** → end. (Under 30 min is
   deliberately never scored.)
2. Reopen it.

**Expected — a scored session:**
- Screen titled **Experimental Zeez Estimate**.
- VoiceOver on the score reads "Experimental Zeez estimated sleep score: N points" (test in T12).
- Persisted `calculationVersion` = `ZeezScore-3.0`, and `confidenceScore` is **not** 85 for every session —
  it must vary with how many sensors contributed. (Ask me for a query if you want to check the DB directly.)

**Expected — the breakdown (score breakdown, added after the audit):** below the score, a card titled
**How This Estimate Was Calculated** lists five rows with a weight each (25 / 30 / 25 / 15 / 5%) and a
score out of 100 or "Not available". The session details screen has a "How this estimate was calculated"
link to the same place. VoiceOver on a row reads its name, its weight, and "Experimental Zeez estimate
component: N out of 100".
- **Silent variant:** the card says "The breakdown for this estimate isn't available" on a session you
  just recorded. That means recomputing from its stored stages didn't reproduce the stored score — report it.
  "Produced by an earlier version" is expected only for sessions scored before `ZeezScore-3.0`.

**Expected — a session with sensor data but no inferrable stages:** shows **no score at all**, not a
neutral or middling one. Internally `qualityScore <= 1.0` is the "no estimate" sentinel.

**Silent failure — the important one:** a session shows a plausible-looking score (say 68) that was never
actually computed. If every session you record scores identically, or confidence is always 85, tell me.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T5 — Alarm end to end

**Goal:** the reason this app exists. If any of this fails, nothing else on the list matters.

Set alarms a few minutes out so you're not waiting. Default cadence is **60 s** between follow-ups, max
**6** pre-armed follow-ups per alarm; Heavy Sleeper mode uses **31 s** and up to 20.

### T5.1 — Foreground
Set an alarm 2 minutes out. Leave the app open.
**Expected:** alarm fires, `ActiveAlarmView` appears full-screen, audio loops.

**Then the watchdog (D2b).** While it loops, hold the side button for Siri, then dismiss Siri within about
5 s without asking anything. Siri should interrupt the audio, and only the watchdog, which checks every
2 s, starts it again. If the audio never stops while Siri is up, the check didn't happen; say so. Have
Console.app open (Method 2, info messages on, category `Alarm`).
**Expected:** the audio comes back within a few seconds of Siri closing, and Console shows
`⚠️ Audio watchdog: restarting audio (attempt 1)`.
**Silent failures:**
- No watchdog line, and the alarm stays quiet: the watchdog's timer never runs. The audio can be started
  from the notification callback's queue, whose run loop may never run (`FUTURE_IMPROVEMENTS.md`, "Found
  by D2").
- `max retries reached, falling back to system sound`, then silence: five restarts in a row failed, the
  alarm fell back, and nothing watches the fallback sound. Note how long Siri was up.

Paste the `Alarm` lines from the Siri press onward either way. The cap, the fallbacks and the hand-back
to other audio on Stop are unit-tested (`AlarmAudioControllerTests`); this is the only check that the
watchdog runs on a device.

**Vibration-only.** Repeat with an alarm set to vibration only. **Expected:** it vibrates and plays no
sound. The code suggests it will also loop the long alarm sound (`FUTURE_IMPROVEMENTS.md`, "Found by
D2"); report what you hear, and whether Stop ends it.

### T5.2 — Locked screen
Set an alarm 2 minutes out. Lock the phone. Do not force-quit.
**Expected:** notification fires with sound. Tapping it opens the full-screen alarm UI.

### T5.3 — Force-quit (the one that historically breaks)
Set an alarm 3 minutes out. **Force-quit the app** (swipe up from app switcher). Lock the phone.
**Expected:** the alarm still fires, and follow-ups continue at ~60 s intervals. This works only because
the chain is *pre-armed* at scheduling time.

**Silent failure:** the first notification fires and nothing follows. That's the chain not being armed.

### T5.4 — Follow-up cadence
Let T5.3's alarm ring without touching it. Count the follow-ups and time them.
**Expected:** up to 6, roughly 60 s apart. Note actuals:
```
follow-ups seen: ____    intervals: ____
```

### T5.5 — Stop re-arms the next chain (A6)
Tap **Stop**. Then, **without relaunching the app**, wait for the next scheduled firing (set a repeating
alarm for this, e.g. daily, and check the following day — or set two alarms).
**Expected:** the next firing also has its follow-up chain.

**Silent failure:** the second firing has no follow-ups. This was A6's bug — the app used to only re-arm
chains at launch, so a user who opens the app daily but never relaunches lost Heavy Sleeper protection
after the first alarm.

### T5.6 — Foreground re-arm (A6, the actual fix)
Set an alarm for tomorrow. Background the app (don't force-quit). Wait past a firing. Bring the app to the
foreground.
**Expected:** log line, category `Alarm`: `🔁 Removing N stale chain entries…` followed by
`📅 Pre-armed 6 follow-ups…`. If the chain is still current it should be left alone and you'll see neither.

### T5.7 — Snooze
Fire an alarm, tap **Snooze**.
**Expected:** re-fires after **9 minutes** (default). Snoozed state survives a force-quit.

### T5.8 — Alarm health card
On the Alarm tab with at least one alarm on: a green card reads "N alarm notifications scheduled · Next
rings <day time>", and the day/time matches the alarm you expect next (during a snooze, the snooze).
Then turn notifications off for Zeez in iOS Settings and return: the card turns red, "Notifications are
off", and **Open Settings** goes to Zeez's page. Turn them back on.
**Silent variant:** an orange "isn't scheduled" card on an alarm you just created that doesn't clear
within a few seconds — report it with the alarm's settings. Tap **Reschedule Alarms** and note whether it clears.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T6 — Notification budget banner

**Goal:** iOS silently drops pending notifications beyond **64**. The app is supposed to warn before that.

Create ~5 alarms with Heavy Sleeper on (20 follow-ups each ⇒ well over 64).

**Expected:** a warning banner in the alarm UI. Log lines, category `Alarm`, of the form
`Notification budget: mains: N, follow-ups: N, snoozes: N, other: N — total N/64`.

**Silent failure:** no banner, total exceeds 64, and later alarms simply never fire. This is the worst bug
class in the app — total silence with a green UI.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T7 — Critical alerts degrade gracefully (D3b)

**Goal:** you have **not** been granted the critical-alerts entitlement, and must not have.

**Expected:** alarms use `.timeSensitive` interruption level and the default sound. They should still
break through Focus modes (time-sensitive is entitled). No crash, no console error about a missing
entitlement.

Test with **Do Not Disturb on**. Alarm should still arrive.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T8 — Paired Apple Watch round trip (A5)

**Goal:** phone→watch pushes have **never** been verified on hardware. A5 rewrote the wire contract. The
unit tests cover the envelope shape and, since D2a (`WatchConnectivityHandlerTests`), the phone's reply to
the watch's request and its choice of transport. What they cannot cover is the transport itself:
activation, reachability and delivery. A failure in (2) or (3) is most likely there.

1. Install the watch app. Open it.
2. **Watch-initiated:** pull to refresh / open the summary. Expect current sleep + next alarm.
3. **Phone-initiated (the one that was broken):** on the phone, record and end a session, or edit an alarm.
   **Expected:** the watch's summary updates without you asking it to.
   - **Next alarm (fixed after the audit):** with two alarms on, the watch shows the one that rings
     *next*, with an "in Xh Ym" countdown under it. Turn that alarm off on the phone: the watch moves to the
     other one. Turn both off: the watch shows no next alarm. A missing countdown, or the watch showing an
     alarm you just disabled, is a failure.
4. Wake-pattern haptics fire when an alarm rings. Try it twice: once with the watch app open, once with
   it closed (wrist down for a minute first). The phone sends a wake pattern only to a reachable watch
   and never resends a refused one (`FUTURE_IMPROVEMENTS.md`, "Found by D2"), so expect haptics only the
   first time. In Console.app (the phone, category `Network`), `Failed to send wake pattern to watch` is
   a refusal. Report which runs buzzed.
5. Snooze and Stop from the watch both control the phone's alarm.
6. **Offline cache:** put the phone in airplane mode. The watch should show the last known summary, not
   blank.

**Silent failure:** everything in (2) works and (3) silently does nothing. That was the exact A5 bug — the
phone flattened the payload and the watch only read a nested one. If (3) fails, capture the watch's log
too (Console.app → select the Watch).

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T9 — Environmental: mic denied, and the noise index (B5)

**Goal:** noise is a **relative index 0–100**, explicitly *not* decibels. And a denied mic must read
*unavailable*, never `0` and never "quiet".

1. Settings → Privacy → Microphone → **deny** Zeez.
2. Record a session. Open its details.

**Expected:** the environmental row reads **"Relative Noise Index … of 100"**. With the mic denied it shows
**unavailable**.

**Silent failure — the one this was built to prevent:** it reads `0`, or "Quiet", or displays "dB". A
denied microphone reading as a silent room is a fabricated measurement. Same class: temperature/light
showing `-1`, or a freezing pitch-dark room — those are the raw sentinels leaking through.

3. Re-grant the mic, record again, confirm a real index appears.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T10 — Core Data threading **[SIM OK]**

**Goal:** catch the bug class A2/A3/A4 fixed. Do this in the simulator; the assertion is what matters.

1. Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch:
   add `-com.apple.CoreData.ConcurrencyDebug 1`
2. Run. Exercise, in one session: record and **end** a session (A3), let the watch request data (A2), and
   let a background task fire (A4):

```
# in the LLDB console while paused, for the background task (A4):
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.danielsparano.zeez.sleepupdate"]
```

> The tracker's §4 A4 note gives this identifier as `com.zeez.Zeez.sleepupdate`. That's wrong — it's
> derived from the bundle id. I'll fix the tracker.

**Expected:** no crash. ConcurrencyDebug turns an off-queue Core Data access into an immediate
`__Multithreading_Violation_AllThatIsLeftToUsIsHonor__` trap, so a pass here is meaningful.

**Remember to remove the launch argument afterwards** — it slows everything down.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T11 — Delete all data **[SIM OK]**

Settings → the delete-all-data control. Confirm.

**Expected:** all sessions gone, dashboard returns to `DashboardEmptyStateCard`, app doesn't crash, and it
still works after a relaunch (the store is destroyed and re-added — that's the risky bit). Then import or record
one session, relaunch, and confirm it is the only one: nothing from before the delete may come back.

**Log** (`CoreData`, info): `Successfully cleared and recreated store`. The error `Failed to clear and recreate
store` means the destroy or the reopen failed; paste the error that follows it.

**Side files (simulator):** list the store's folder after the delete.
```
xcrun simctl get_app_container booted com.danielsparano.zeez groups   # Xcode build: the App Group container
xcrun simctl get_app_container booted com.danielsparano.zeez data     # CLI build: Library/Application Support
```
Expect `Zeez.sqlite`, `Zeez.sqlite-wal` and `Zeez.sqlite-shm`, plus any `*.migration-backup-*` from T1, and nothing
else. The `-wal`/`-shm` **should** still be there. Before 2026-10-22 the app deleted the store file but left the
old sidecars behind, because it removed `Zeez.sqlite.wal`/`.shm` (names SQLite never uses). It now truncates all
three in place and the recreated store reuses them (`PersistenceController.recreateStore`). Deleting them while
another process had them open is what broke the old version.

**Note:** after T1, this now deletes the store in the **group container**. Worth confirming it still finds it.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T12 — Accessibility

**Goal:** the claims contract binds VoiceOver output, not just visible text (rules 4, 7, 10).

VoiceOver on (triple-click side button). Sweep: Dashboard → session details → Trends (Sleep Trends link) → watch
app.

**Expected — every score utterance carries "Experimental Zeez estimate".** Specifically re-listen to the
four surfaces Phase B reworded:
- Trends **duration** chart → "average recorded session duration", never "time asleep" (B4). Its card is now
  titled "Recorded Session Duration" (2026-10-26)
- Noise → "relative noise index", never "decibels" (B5)
- Stage composition rows announce their values (B6)
- Sleep-goal card → real values, and **"Not set"** when no goal is saved (B12) — never a plausible default

Then Dynamic Type at the largest accessibility size on the dashboard cards. Truncation is a bug; overlap
is a worse one.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T13 — StoreKit sandbox

⚠️ **Blocked in this build: no screen opens the paywall.** Its only links were Trends' "Upgrade to Premium"
cards, removed 2026-10-26 because `SubscriptionView` sells capabilities that do not exist (`FUTURE_IMPROVEMENTS.md`),
and `PaywallReachabilityGuardTests` keeps it unreachable. Run T13 once a reviewed entry point exists.

Needs the four product IDs to exist in App Store Connect **character for character**:

```
com.zeez.subscription.premium.monthly
com.zeez.subscription.premium.annual
com.zeez.subscription.premiumplus.monthly
com.zeez.subscription.premiumplus.annual
```

1. Sign in to a Sandbox Apple ID on the phone (Settings → App Store → Sandbox Account).
2. Purchase each tier. Confirm entitlement unlocks.
3. **Restore Purchases.** Confirm it restores, and that a *failed* restore shows an honest error rather
   than pretending success.
4. **Airplane mode, force-quit, relaunch.** Premium must still be active — entitlement resolves offline.

**Silent failure:** products list is empty and the paywall shows nothing, which looks like a UI bug but
means the IDs don't match ASC.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T14 — Archive validation

Xcode → Product → Archive → Organizer → **Validate App**.

Check: no `NSCameraUsageDescription` demanded (AVCaptureDevice is fully removed); background modes are
`processing` only; App Group present in the profile.

Before submission, not before TestFlight: publish the real privacy-policy URL. `AppConstants.Legal` still
points at the placeholder `https://dcs617.github.io/zeez-privacy/`.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T15 — Navigation per tab, and Trends (D1)

**Goal:** since D1 (2026-10-26) each tab owns its `NavigationStack`, a push stays inside its tab, and Trends has an
entry point again after 14 months without one. `MainViewUITests` covers the simulator happy path; this is the
device pass, and iPad if you have one. **[SIM OK]** apart from step 6.

### T15.1 — Each tab keeps its own stack

1. **Sleep:** the dashboard shows its date header and no navigation bar. Tap the gear. **Expected:** a "Settings"
   bar with a back button, and the **tab bar still visible** (before D1 a push covered it).
2. Settings → Sleep Analysis → **Personalization**. **Expected:** exactly **one** bar, "Sleep Personalization",
   with a back button to Settings (before D1 two bars stacked).
3. Without going back, switch to **Alarm**: the title reads "Rise". Switch back to **Sleep**: you are still on
   Personalization. Back twice returns to the dashboard.
4. **Alarm:** + (new alarm), then edit an existing alarm, then the Schedule and Alarm Sound pickers inside it. Each
   sheet has one bar with its own title and buttons; dismissing returns to where you were.
5. **Learn:** "Learn" in the bar, Learning Path at the leading edge, the ⋯ menu at the trailing edge. Open
   Learning Path: its back button reads "Learn". From ⋯ open Bookmarks, Settings and Quick Note: one bar each.
6. Push two screens deep in Sleep, then let an alarm fire (T5): the full-screen alarm still appears over it.
7. **iPad, if available:** reset onboarding (debug build, `-uiTestResetOnboarding`) — one column, not a split view
   with an empty pane.

**Silent failures:** a tab whose title is missing, a second bar under the first, a missing back button, or a tab
switch that resets another tab's stack.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

### T15.2 — Trends

Needs recorded nights: T3's import, or Debug Menu → Generate Mock Data in a debug build.

1. Sleep tab → **Sleep Trends**, under the Weekly Progress chart. On an empty store (T2) the link is absent — intended.
2. **Week.** Coverage card: "Recorded on N of the last 7 nights" with your real N. Experimental Zeez Estimate: no
   number and no chart for a week without estimates. Recorded Session Duration: an average such as "8h 24m".
   Sleep Schedule: one bar per night from its start down to its end, never wrapping past the bottom; the subtitle
   reads "Recorded sleep start time varied by about N minutes over M nights", or asks for at least 4 recorded nights.
3. **Month.** The time axes are labelled weekly ("Oct 5"), not with thirty overlapping weekday names. Monthly Trends:
   the estimate on a 0–100 axis, so a one-point change looks like one. Pick each type from the menu: Recorded Session
   Duration (hours), Start Time Spread (minutes), Goal Shortfall (hours; needs a goal). Observations describe —
   nothing reads "Excellent…" or "Consider…".
4. There is **no** "Upgrade to Premium" card anywhere on Trends.
5. Dark mode: every card stands out from the background.
6. VoiceOver (with T12): the estimate chart's points carry "Experimental Zeez estimate"; each schedule bar reads its
   night and "Recorded from … to …"; the monthly chart reads every month, including "no estimate" months.

**Silent failures:** the link missing although you have nights; a 0 where "no estimate" belongs; a monthly line
swinging across the whole chart for a small change (the old scaling).

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## Run summary — fill in at the end

| Test | Pass | Fail | Blocked | One-line note |
|---|---|---|---|---|
| T0 signing / App Group | | | | |
| T1 store relocation + v3 migration | | | | |
| T2 first-run empty state | | | | |
| T3 HealthKit import | | | | |
| T3.1 re-import (§8a) | | | | |
| T4 score behaviour | | | | |
| T5 alarm E2E | | | | |
| T6 notification budget | | | | |
| T7 critical alerts | | | | |
| T8 watch round trip | | | | |
| T9 mic denied / noise | | | | |
| T10 threading | | | | |
| T11 delete all data | | | | |
| T12 accessibility | | | | |
| T13 StoreKit sandbox | | | | |
| T14 archive | | | | |
| T15.1 navigation per tab | | | | |
| T15.2 Trends | | | | |

**Anything surprising that isn't on this list:**
```


```

**Battery observation over a few nights of real use (TestFlight, not now):**
```


```

---

# Appendix A — Reading the logs

Yes: phone connected to the laptop by cable (iPhone 13 Pro Max is Lightning), app running **on the phone**.
You have three ways to see its output, and you need two of them because they fail in different places.

## ⚠️ Read this first: the app's key lines are `info`-level

Almost everything this guide asks you to look for — `Relocated the Core Data store…`,
`Notification budget: … total N/64`, `📅 Pre-armed 6 follow-ups…` — is logged at **info** level.

**Console.app hides info and debug messages by default.** If you don't turn them on, you will see nothing
and wrongly conclude the code never ran. This is the single easiest way to get a false negative out of
this whole document.

Only `error` and `fault` lines show up without changing anything. Those are the App Group failure paths
(T1) — so the *bad* news is visible by default and the *good* news isn't.

`ZeezLogger.debug` is compiled out of Release builds entirely. Running from Xcode gives you a Debug build,
so you're fine.

---

## First: "Xcode's console" and "Console.app" are two different things

This trips everyone up. **Console.app is not part of Xcode.** It is a separate macOS application.

| | What it is | How to open it |
|---|---|---|
| **Xcode's console** | A pane at the bottom of the Xcode window showing output from the app Xcode is currently running | It's already there. `⇧⌘C` focuses it; `⇧⌘Y` toggles the whole debug area |
| **Console.app** | A standalone macOS app that reads the system log from your Mac *or* from an attached iPhone/Watch | `⌘Space`, type `Console`, Return. (Or `open -a Console` in Terminal. It lives at `/System/Applications/Utilities/Console.app`, which Finder shows as Applications → Utilities) |

You need both. Xcode's pane only works while Xcode is attached to a running process — the moment you
force-quit Zeez, Xcode detaches and the pane goes dead, even though the alarm keeps firing (iOS owns the
scheduled notification, not your app). Console.app doesn't care whether anything is being debugged.

---

## Method 1 — Xcode's console (easiest; use for T1, T2, T3, T4, T9, T10, T11)

Run the app from Xcode onto the phone (Product → Run). The pane at the bottom of Xcode streams everything,
all levels, no configuration. Filter with the search box at its bottom-right.

**Where it breaks:** the moment you force-quit the app, the debug session dies and the stream ends. It also
ends if you unplug. So it is useless for T5.3, T5.5, T5.6, T6, and T8, which are all about what happens
when the app *isn't* being debugged.

## Method 2 — Console.app (use for T5, T6, T8, and anything after a force-quit)

1. Connect the phone by cable. **Unlock it.** Tap **Trust This Computer** if asked. (A locked phone will
   not appear, and that is the usual reason it's missing.)
2. Open Console.app — it's a **separate app, not part of Xcode**: press `⌘Space`, type `Console`, hit
   Return. You can also launch it from Terminal: `open -a Console`.
3. In the **left sidebar**, under **Devices**, click your iPhone. (If the sidebar is hidden:
   View → Show Sidebar.) Your Mac is listed there too — make sure you pick the phone.
4. **Action menu → tick "Include Info Messages" and "Include Debug Messages".** ← the step everyone skips.
   Without it you will see nothing and wrongly conclude the code never ran.
5. In the search field (top right), type `com.danielsparano.zeez`, press Return, then **click the token
   that appears and choose "Subsystem"** from its dropdown. Free text also works but matches noisily.
6. Click **Start** *before* you perform the step you're testing. The stream is live-only; it does not
   backfill. If you forgot, use Method 3 to pull the log back after the fact.

To narrow further, add a second token for **Category**: `CoreData`, `Alarm`, `Environment`, `Background`,
`SleepTracking`, `UI`. These are the `ZeezLogger` categories.

The app keeps logging while it's force-quit-and-relaunched, locked, or backgrounded — Console doesn't care.
That's why it's the right tool for the alarm tests.

## Method 3 — Terminal, *after the fact* (best for pasting to me)

Two things to know before you type anything:

- **`log` is a zsh builtin.** Plain `log show …` fails with `too many arguments`. Always write
  **`/usr/bin/log`**.
- **There is no terminal live-stream for a connected device.** `log stream --device` was removed from
  macOS; on this machine `log stream` doesn't accept `--device` at all, and `devicectl` has no console
  subcommand. For *live* device logs, use Console.app (Method 2). The terminal is for pulling logs back
  **after** something happened.

That "after" case is the one you actually need — the alarm tests happen while you're asleep or the app is
force-quit, and you won't have a stream running.

```bash
# 1. Pull the last 30 minutes off the connected phone.
sudo /usr/bin/log collect --device --last 30m --output ~/Desktop/zeez.logarchive

# 2. Replay just Zeez's lines, including info and debug.
/usr/bin/log show ~/Desktop/zeez.logarchive \
  --predicate 'subsystem == "com.danielsparano.zeez"' \
  --info --debug --style compact > ~/Desktop/zeez.txt
```
Paste the relevant chunk of `zeez.txt`. `--last` takes `30m`, `2h`, `1d`.

The `--info --debug` on step 2 is the same trap as Console's Action menu: without them you get only
`error` and `fault`, and every line in the table below marked ❌ vanishes.

> If `--device` errors: the phone isn't connected, unlocked, or trusted. Check with
> `xcrun devicectl list devices` — it should show `iPhone 13 Pro Max` as `available`, not `unavailable`.

## Watch logs (T8)

Same as Method 2, but select the **Apple Watch** in Console's sidebar. The watch must be paired to the
phone and the phone connected to the Mac. Watch-side categories come from `WatchLogger`: `Connectivity`
and `Haptics`.

If the watch doesn't appear in the sidebar, open the Watch app on the phone → General → and make sure
it's not in a low-power state. Wireless-only watch logging is unreliable; give it a minute.

## Crashes

Xcode → Window → **Devices and Simulators** → your phone → **View Device Logs**. Sort by date, find yours,
right-click → **Export Log**. Send me the top ~10 frames of the crashing thread and the exception type.

A Core Data threading violation (T10) shows up as a frame named
`__Multithreading_Violation_AllThatIsLeftToUsIsHonor__`. If you see that, the test found exactly what it
was looking for.

## Quick reference — what to expect at which level

| Line | Level | Visible in Console by default? |
|---|---|---|
| `Relocated the Core Data store into the App Group container` | info | ❌ turn on Info |
| `App Group container unavailable — keeping the app-container store` | error | ✅ |
| `App Group container is unreachable but this install previously adopted it` | **fault** | ✅ |
| `Notification budget: … total N/64` | info | ❌ |
| `🔁 Removing N stale chain entries for alarm …` | info | ❌ |
| `📅 Pre-armed 6 follow-ups for alarm … at next fire …` | info | ❌ |
| `⚠️ Audio watchdog: restarting audio (attempt N)` | info | ❌ |
| `Audio watchdog: max retries reached, falling back to system sound` | error | ✅ |
| `Failed to send wake pattern to watch` | error | ✅ |
| `Core Data store loaded successfully` | info | ❌ |
| Anything from `ZeezLogger.debug` | debug | ❌, and Release-stripped |
