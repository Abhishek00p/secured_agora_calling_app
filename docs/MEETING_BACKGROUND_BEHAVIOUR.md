# Meeting behaviour when leaving the app

This doc describes what happens when a user is in a meeting and leaves or backgrounds the app.

## User in meeting, exploring other screens inside the app

- Call keeps running; the **persistent call bar** is shown on Home, Users, Admin, and Meeting Detail.
- User can tap **Return** to go back to the meeting screen, or **End** to leave the call.

## User presses device Back (intent to leave the app)

- **From Home (or any screen that eventually leads to Home):**
  - First Back: toast *"Press back again to send app to background"*.
  - Second Back: app goes to background. If user is in a call, a toast says *"Call continues in background. Tap notification or call bar to return."*

- **From Meeting screen:**
  - Back exits the meeting **screen** only (call continues); user sees the call bar on the next screen. To leave the **app**, they must navigate to Home and then press Back twice.

## What happens when the app goes to background with an active call

1. **Persistent notification (Android)**  
   - While the user is in a meeting, a **persistent ongoing-call notification** is shown (e.g. "In call: &lt;meeting name&gt;" – "Tap to return").
   - Tapping the notification brings the app back to the foreground and navigates to the meeting screen.
   - The notification is removed automatically when the user leaves the meeting (End call).

2. **Persistent call bar**  
   - When the user is in a call and navigates to other in-app screens (Home, Users, etc.), a **call bar** is shown at the top. User can tap it to return to the meeting or end the call.

3. **When is the meeting cleaned up?**  
   - When the user **explicitly leaves** the meeting (End call in app).
   - When the app is **detached/killed** (e.g. force-stopped or removed from recents): the lifecycle manager performs cleanup (remove participant, end for all if host).
   - There is **no** automatic cleanup after X minutes in background; leaving the app in background does **not** end the meeting.

## Summary

| Scenario | Call continues? | Notification / call bar? |
|----------|-----------------|---------------------------|
| In meeting, press Back from meeting screen | Yes | Yes (call bar on next screen) |
| In meeting, on Home, press Back twice (leave app) | Yes | Yes (notification; tap to return) |
| User taps notification | Yes (app opens to meeting) | Yes |
| User ends call in app | No | No (notification removed) |
| App process killed (e.g. swiped from recents) | No (cleanup runs) | — |
