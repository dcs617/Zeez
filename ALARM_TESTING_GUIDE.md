# Alarm System Testing Guide

## 🎯 **What Was Fixed**

### Major Issues Resolved:
1. **❌ Excessive duplicate scheduling** → ✅ Now only reschedules changed alarms, not all alarms
2. **❌ Alarm changes not detected** → ✅ Fixed AlarmObserver to detect all alarm updates
3. **❌ No alarm sound playing** → ✅ Switched to reliable `.defaultCritical` sound
4. **❌ Black screen full-screen alarm** → ✅ Fixed ActiveAlarmView rendering and dismissal
5. **❌ Uncloseable alarm screen** → ✅ Added emergency double-tap dismiss and proper cleanup
6. **❌ App lifecycle over-scheduling** → ✅ Removed excessive app activation reschedules

### Key Improvements:
- **Efficient scheduling**: Only reschedules the specific alarm that changed
- **Reliable sound**: Uses iOS `.defaultCritical` sound that always works
- **Dismissable alarm screen**: Emergency double-tap + proper button handling
- **Better logging**: Shows exactly which alarms changed and why
- **Reduced log spam**: Individual scheduling messages only in debug builds

---

## 🧪 **How to Test the Alarm System**

### **Step 1: Build and Run the App**
```bash
# Open in Xcode and build/run to iOS Simulator or device
xcodebuild -project Zeez.xcodeproj -scheme Zeez -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### **Step 2: Check Initial Setup**
1. **Launch the app**
2. **Go to Settings tab**
3. **Use Debug Tools section** (only visible in DEBUG builds):
   - Tap **"Check Alarm Permissions"** - should show "✅ AUTHORIZED"
   - If denied, go to iOS Settings > Notifications > Zeez and enable them
   - Tap **"Test Notification (10s)"** - you should get a test notification in 10 seconds
   - Tap **"Test Full-Screen Alarm"** - should show full-screen alarm interface immediately
4. **Check Console for these logs**:
   ```
   [Alarm] Alarm system initialized
   [Alarm] 🔐 Notification Permission Status: ✅ AUTHORIZED
   [Alarm] 🧪 Test notification scheduled - check your device in 10 seconds!
   [Alarm] 🧪 Full-screen alarm test triggered
   ```

### **Step 3: Create a Test Alarm**
1. **Go to Alarm tab** in the app
2. **Tap "+" to create new alarm**
3. **Set alarm for 2-3 minutes from now**
4. **Select today's day of the week** (important!)
5. **Give it a name** like "Test Alarm"
6. **Save the alarm**

### **Step 4: Verify Efficient Scheduling**
After saving the alarm:
1. **Check Console logs** - should see EFFICIENT scheduling:
   ```
   💾 Saving alarm 'Test Alarm' - Time: 2:15 PM, Enabled: true
   ✅ Successfully updated alarm 'Test Alarm' for 2:15 PM
   ✏️ Alarms updated - rescheduling only changed alarms
   🎯 Rescheduling single alarm: Test Alarm
   ```
2. **Should NOT see excessive logs** - no more than 2-3 scheduling messages per alarm
2. **Go to Settings > Debug Tools**
3. **Tap "Debug Scheduled Alarms"** - should show:
   ```
   [Alarm] === DEBUG: Scheduled Notifications ===
   [Alarm] Total pending notifications: 1
   [Alarm] 📅 [UUID]-day3-standard: Tuesday at 14:15
   [Alarm]    Title: Test Alarm
   [Alarm]    Body: Time to Wake Up
   [Alarm]    Sound: Optional(UNNotificationSound)
   [Alarm] === End Debug ===
   ```

### **Step 5: Test Alarm Triggering & Full-Screen UI**
1. **Wait for the scheduled time**
2. **Should see console logs**:
   ```
   🔔 Alarm notification will present: [alarm-id]
      App state: 0 (active)
      App is active - showing full-screen alarm
   📱 Full-screen alarm presented
   📱 ActiveAlarmView appeared for alarm: Test Alarm
   ```
3. **Should see working alarm screen** (NOT black screen):
   - White alarm icon with pulsing animation
   - Alarm name displayed
   - Current time display
   - Orange "Snooze" and Red "Stop" buttons
   - "Double tap anywhere to dismiss" text at bottom
4. **Test dismissal**:
   - Tap "Stop" button OR
   - Double-tap anywhere on screen
   - Screen should close and app should remain responsive

### **Step 6: Test Closed-App Functionality** 🚨
1. **Create another alarm** for 2-3 minutes from now
2. **Save the alarm** - should see efficient scheduling logs
3. **Force close the app** (swipe up in app switcher, swipe Zeez away)
4. **Wait for alarm time**
5. **Critical alert notification should fire** with sound and Snooze/Stop buttons
6. **Test snooze** - should schedule new notification in 9 minutes
7. **This proves alarms work like Apple's Clock app!** ✅

### **Step 7: Test Different Scenarios**

#### **Multiple Days Test:**
1. Create alarm for "Weekdays" (Mon-Fri)
2. Check console - should see ONLY:
   ```
   🎯 Rescheduling single alarm: Weekday Alarm
   ✅ Scheduled [id]-day2-standard for Monday 8:00
   ✅ Scheduled [id]-day3-standard for Tuesday 8:00
   ✅ Scheduled [id]-day4-standard for Wednesday 8:00
   ✅ Scheduled [id]-day5-standard for Thursday 8:00
   ✅ Scheduled [id]-day6-standard for Friday 8:00
   ```
3. Should NOT see excessive duplicate scheduling

#### **Smart Wake Test:**
1. Enable "Smart Wake" with 30-minute window
2. Check console - should see TWO notifications per day:
   - One "smart" notification 30 minutes early
   - One "standard" backup notification at set time

#### **Vibration Only Test:**
1. Enable "Vibration Only"
2. Check console - sound should be "None"

---

## 🐛 **Troubleshooting**

### **No Notifications Appear:**
- Check Settings > Notifications > Zeez (allow notifications + critical alerts)
- Check console for "Notification permissions denied" or "not authorized"
- Make sure alarm is enabled and set for correct day
- Verify you see "✅ Scheduled [id] for [day]" logs

### **Console Shows Excessive Scheduling:**
- Should see "🎯 Rescheduling single alarm" not "⚠️ Scheduling ALL alarms"
- If you see excessive logs, the efficient scheduling isn't working
- Each alarm edit should only reschedule that specific alarm

### **Black Screen or App Hangs After Alarm:**
- Should see "📱 ActiveAlarmView appeared" in console
- Try emergency double-tap anywhere to dismiss
- Check if alarm screen shows white interface with buttons
- If black screen persists, force close and reopen app

### **Smart Wake Not Working:**
- Smart wake requires active sleep session
- Without real HealthKit data, falls back to standard alarm
- Check for "fall back to standard wake" logs

---

## 📋 **Expected Behavior Summary**

### **When Creating Alarm:**
1. ✅ AlarmObserver detects new alarm
2. ✅ Scheduler creates notifications for each selected day
3. ✅ Debug logs show scheduled notifications
4. ✅ Permissions checked and reported

### **When Alarm Triggers:**
1. ✅ iOS notification appears at scheduled time
2. ✅ Notification shows correct title and body
3. ✅ Sound plays (unless vibration only)
4. ✅ Tapping notification opens app

### **Smart Wake Flow:**
1. ✅ Two notifications scheduled (smart + backup)
2. ✅ Smart notification triggers first
3. ✅ If no active sleep session, falls back to standard
4. ✅ Standard notification triggers at actual alarm time

---

## 🎯 **Success Criteria**

- [ ] App requests notification permissions on first launch
- [ ] Creating alarm shows scheduling logs in console
- [ ] Alarm notifications appear at scheduled time
- [ ] Multiple day scheduling works correctly
- [ ] Smart wake + backup scheduling works
- [ ] Vibration-only mode respects sound settings
- [ ] Editing/deleting alarms updates notifications properly

---

## 🔍 **Key Log Messages to Look For**

### **Successful Setup:**
```
[Alarm] Alarm system initialized
[Alarm] Notification permissions granted
```

### **Efficient Scheduling (NEW):**
```
💾 Saving alarm 'NAME' - Time: HH:MM, Enabled: true
✅ Successfully updated alarm 'NAME' for HH:MM
✏️ Alarms updated - rescheduling only changed alarms
🎯 Rescheduling single alarm: NAME
✅ Scheduled [id]-dayX-standard for Day HH:MM
```

### **Errors to Investigate:**
```
[Alarm] Notification permissions denied - alarms will not work
[Alarm] Cannot schedule alarm: missing required data  
[Alarm] Error scheduling notification
[Alarm] Error playing alarm sound (but should still show UI)
```

### **Bad Signs (Inefficient Scheduling):**
```
⚠️ Scheduling ALL X enabled alarms (this should be rare)
🔄 Alarm changes detected - rescheduling all alarms
```
**These should only appear when adding/removing alarms, not editing existing ones!**

The alarm system should now be fully functional! 🎉