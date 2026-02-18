# Meeting behaviour when leaving the app

This doc describes what happens when a user is in a meeting and leaves or backgrounds the app.

## User in meeting, exploring other screens inside the app

- Call keeps running; the **persistent call bar** is shown on Home, Users, Admin, and Meeting Detail.
- User can tap **Return** to go back to the meeting screen, or **End** to leave the call.

## User presses device Back (intent to leave the app)

- **From Home (or any screen that eventually leads to Home):**
  - First Back: toast *"Press back again to exit the app"*.
  - Second Back: app goes to background. If user is in a call, a toast says *"Call continues in background. Reopen app or use PIP to return."*

- **From Meeting screen:**
  - Back exits the meeting **screen** only (call continues); user sees the call bar on the next screen. To leave the **app**, they must navigate to Home and then press Back twice.

## What happens when the app goes to background with an active call

1. **Persistent notification (Android)**  
   - While the user is in a meeting, a **persistent ongoing-call notification** is shown in the device notification/status bar (e.g. "SecuredCalling – In call: &lt;meeting name&gt; — Tap to return").
   - Tapping the notification brings the app back to the foreground so the user can return to the call.
   - The notification is removed automatically when the user leaves the meeting (End call).

2. **PIP (Picture-in-Picture)**  
   - If the device supports it (e.g. Android 8+), the app may also request **PIP** when the app is paused and the user is in a meeting.
   - A small floating window can appear with a **"Back to app"** action. The call keeps running while in PIP or background.

3. **Closing PIP**  
   - If the user closes/dismisses the PIP window, the app goes to background. **The meeting is not ended.**
   - The **persistent notification** remains so the user can tap it to return to the app and the call.
   - Cleanup (leave/end meeting) runs only when the app process is **killed** (e.g. user swipes app away from recents), not when PIP is closed or app is just in background.

4. **When is the meeting cleaned up?**  
   - When the user **explicitly leaves** the meeting (End call in app).
   - When the app is **detached/killed** (e.g. force-stopped or removed from recents): the lifecycle manager performs cleanup (remove participant, end for all if host).
   - There is **no** automatic cleanup after X minutes in background; closing PIP or leaving the app in background does **not** end the meeting.

## Summary

| Scenario | PIP? | Call continues? | Notification bar? |
|----------|------|-----------------|-------------------|
| In meeting, press Back from meeting screen | N/A (still in app) | Yes | Yes (persistent) |
| In meeting, on Home, press Back twice (leave app) | Yes (when supported) | Yes | Yes (persistent) |
| User closes PIP window | — | Yes | Yes (tap to return) |
| User taps notification | — | Yes (app opens) | Yes |
| User ends call in app | — | No | No (notification removed) |
| App process killed (e.g. swiped from recents) | — | No (cleanup runs) | — |
