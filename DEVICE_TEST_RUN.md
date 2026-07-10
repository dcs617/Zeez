# Zeez — Device Test Run

**Temporary file.** Delete it when the run is finished and the findings have been folded into
`SECOND_AUDIT_IMPROVEMENTS.md` §5 and `FUTURE_IMPROVEMENTS.md`.

Hardware: iPhone 13 Pro Max + paired Apple Watch. Branch `feature/sleep-simplification`.
Baseline at start of run: 225 tests / 37 suites green, iOS + watch targets build.

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
2. **Log lines.** This matters more than a description. Console.app → select your iPhone in the sidebar
   → filter `Subsystem: com.danielsparano.zeez`. Start the capture *before* the step. Copy the 20 lines
   around the moment it went wrong, not just the error.
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

## T1 — Core Data store relocation into the App Group (D3a)

**Goal:** prove that an existing install's sleep history survives the move to the group container.
This is a **one-time migration**. Once it runs, it never runs again on that install.

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

Have **Console.app open and filtering on `com.danielsparano.zeez` before you launch.**

**Expected — pass:**
- Exactly one log line, category `CoreData`: `Relocated the Core Data store into the App Group container`
- The dashboard shows the same data as in T1.1.

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

**Expected:** the `Relocated…` line does **not** appear again. Data still present.
If it appears twice, the legacy store wasn't cleaned up — tell me.

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

**Silent failures:** the import reports success while heart rate silently failed (that's exactly what B10
was meant to end — if the message doesn't name HR, the reporting broke); or an Apple session shows a
score.

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

**Goal:** phone→watch pushes have **never** been verified on hardware. A5 rewrote the wire contract; the
unit tests cover the envelope shape, not the transport.

1. Install the watch app. Open it.
2. **Watch-initiated:** pull to refresh / open the summary. Expect current sleep + next alarm.
3. **Phone-initiated (the one that was broken):** on the phone, record and end a session, or edit an alarm.
   **Expected:** the watch's summary updates without you asking it to.
4. Wake-pattern haptics fire when an alarm rings.
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
still works after a relaunch (the store is removed and re-added — that's the risky bit).

**Note:** after T1, this now deletes the store in the **group container**. Worth confirming it still finds it.

**Result:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:**
```


```

---

## T12 — Accessibility

**Goal:** the claims contract binds VoiceOver output, not just visible text (rules 4, 7, 10).

VoiceOver on (triple-click side button). Sweep: Dashboard → session details → Trends charts → watch app.

**Expected — every score utterance carries "Experimental Zeez estimate".** Specifically re-listen to the
four surfaces Phase B reworded:
- Trends **duration** chart → "average recorded session duration", never "time asleep" (B4)
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

## Run summary — fill in at the end

| Test | Pass | Fail | Blocked | One-line note |
|---|---|---|---|---|
| T0 signing / App Group | | | | |
| T1 store relocation | | | | |
| T2 first-run empty state | | | | |
| T3 HealthKit import | | | | |
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

**Anything surprising that isn't on this list:**
```


```

**Battery observation over a few nights of real use (TestFlight, not now):**
```


```
