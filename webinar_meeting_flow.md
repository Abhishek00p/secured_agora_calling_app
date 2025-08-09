# Webinar Meeting Architecture & Role Flow

## 1. System Architecture Overview

```
┌─────────────────────────┐
│        Flutter App      │
│ ┌─────────────────────┐ │
│ │ UI Layer             │ │
│ │  - host_view.dart    │ │
│ │  - subhost_view.dart │ │
│ │  - participant_view. │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ Controller Layer    │ │
│ │  - webinar_meeting_ │ │
│ │    controller.dart  │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ Service Layer       │ │
│ │  - webinar_meeting_ │ │
│ │    service.dart     │ │
│ │  (Agora SDK +       │ │
│ │   Firestore/RTM)    │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

---

**Data & Signaling Flow**  

```
Participant ↔ Firestore/RTM ↔ Host
Participant ↔ Firestore/RTM ↔ SubHost
Host ↔ Firestore/RTM ↔ SubHost
Agora Voice SDK → handles audio transmission

Firestore/RTM Events:
- request_to_speak
- approve_speak
- revoke_speak
- promote_to_subhost
- demote_to_participant
- kick_user
- mic_status_update
```

---

## 2. Role Permission Flow

### Host
- **Can hear:** Everyone
- **Can speak to:** Everyone
- **Controls:**
  - Mute/unmute any participant
  - Grant/revoke speak permission
  - Kick participants
  - Promote/demote SubHost
- **UI:** Horizontal scrollable grid (6 per screen), own grid always first.

### SubHost
- **Can hear:** Everyone
- **Can speak to:** Everyone
- **Controls:**
  - Mute/unmute participants
  - Grant/revoke speak permission
  - Kick participants **(except Host)**
  - Promote/demote participants to SubHost (optional if allowed)
- **UI:** Same as Host view but no “Kick Host” option.

### Participant
- **Can hear:** Host & SubHost only
- **Can speak:** Only if granted permission
- **When speaking:** Audio goes only to Host & SubHost (not to other participants)
- **UI:** Shows only Host’s grid + self grid, request-to-speak button, mic toggle (if allowed), speaker toggle, end call.

---

## 3. Role & Audio Routing Diagram

```
[HOST] ←→ [SubHost]
   ↑         ↑
   │         │
   │         │
[Approved Speaker Participant]
   ↑
(Request to Speak flow)
   ↑
[Participant (Listen-only)]
```

Audio Rules:
- Host ↔ SubHost: Two-way
- Host ↔ Participant: One-way unless permission granted
- SubHost ↔ Participant: One-way unless permission granted
- Participant ↔ Participant: ❌ Never

---

## 4. Suggested New Files

```
/lib/webinar/
   ├── controllers/
   │    └── webinar_meeting_controller.dart
   ├── services/
   │    └── webinar_meeting_service.dart
   ├── views/
   │    ├── host_view.dart
   │    ├── subhost_view.dart
   │    └── participant_view.dart
   └── models/
        └── webinar_user_model.dart
```


