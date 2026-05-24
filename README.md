# SecuredCalling — Developer Documentation

A Flutter-based video/audio calling application with role-based user management, Agora RTC integration, and cloud recording.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Android · iOS · Windows) |
| State Management | GetX |
| Architecture | Feature-based MVVM |
| Backend API | Node.js / Express on Render |
| Database | Firebase Firestore (direct SDK) |
| Authentication | Custom JWT (no Firebase Auth) |
| Video Calling | Agora RTC Engine v6 |
| Cloud Storage | Cloudflare R2 (via AWS S3 SDK) |
| Local Storage | Shared Preferences |

---

## Project Structure

```
lib/
├── app/                  # App entry & routing shell
├── core/
│   ├── config/           # Base URL, env constants
│   ├── constants/        # App-wide constants
│   ├── extensions/       # Dart extensions
│   ├── middleware/        # Legacy HTTP client wrapper (unused by main app)
│   ├── models/           # Shared data models
│   ├── routes/           # AppRouter (named routes + bindings)
│   ├── services/         # Core services (HTTP, Firebase, Auth, Download…)
│   └── theme/            # AppTheme
├── features/
│   ├── admin/            # Admin screens (member management)
│   ├── auth/             # Login screen + auth controller
│   ├── home/             # Home, user list, meeting list
│   ├── meeting/          # Meeting room, detail page, recording, download
│   └── welcome/          # Splash / welcome screen
├── models/               # Shared models (MeetingDetail, …)
├── utils/                # Logger, toast util
└── widgets/              # Shared reusable widgets
```

---

## Roles

| Role | Can do |
|---|---|
| **Admin** | Create/edit members and users, reset any password |
| **Member** | Create/edit users under their member code, start recordings, view mix recordings |
| **User** | Join meetings, view and download their own recordings |

---

## Base URL

```
https://secured-agora-calling-app.onrender.com
```

Configured in `lib/core/config/app_config.dart`.

All requests (except login) carry an `Authorization: Bearer <jwt>` header.  
On a `401` response, `AppHttpService` does **not** refresh or retry: it runs the session-expired handler once (toast, clear local session, navigate to login). Concurrent `401`s are deduplicated so logout runs only once.
Implementation: `lib/core/services/http_service.dart` (`_executeRequest`), handler registered in `main.dart` via `AppSessionExpiredHandler` (`lib/core/services/app_session_expired_handler.dart`).

---

## API Endpoints

### Authentication

| # | Method | Path | Auth | Request Body | Response | Description |
|---|--------|------|------|--------------|----------|-------------|
| 1 | `POST` | `/api/auth/login` | None | `{ email, password }` | `{ success, data: { token, user } }` | Login — returns a 7-day JWT |
| 2 | `POST` | `/api/auth/create-user` | Bearer | `{ name, email, password, memberCode, memberUserId }` | `{ success }` | Create a user under a member |
| 3 | `POST` | `/api/auth/update-user` | Bearer | `{ userId, name, email, memberCode, memberUserId, password? }` | `{ success }` | Update existing user details |
| 4 | `POST` | `/api/auth/create-member` | Bearer (admin) | `{ name, email, password, memberCode, purchaseDate, planDays, maxParticipantsAllowed, isMember, isActive, canSeeMixRecording }` | `{ success }` | Create a new member (admin only) |
| 5 | `POST` | `/api/auth/update-member` | Bearer (admin) | Same as create-member + `userId` | `{ success }` | Update a member's details (admin only) |
| 6 | `POST` | `/resetPassword` | Bearer | `{ targetEmail, newPassword }` | `{ success }` | Reset a user's password _(legacy — no `/api/` prefix)_ |
| 7 | `GET` | `/api/auth/user-credentials/:userId` | Bearer | — | `{ success, data: { email, password } }` | Retrieve plain-text credentials (admin/member view) |
| 8 | `POST` | `/getUsersForPasswordReset` | Bearer | `{}` | `{ success, data: { users: [...] } }` | List users eligible for password reset _(legacy — no `/api/` prefix)_ |
| 9 | `GET` | `/api/auth/refreshLoginToken` | Bearer | `?userId=<id>` | `{ success, token }` | Optional JWT refresh (available on the server; the Flutter app does **not** call this on `401` — see Base URL section above) |

---

### Agora RTC Token

| # | Method | Path | Auth | Request Body | Response | Description |
|---|--------|------|------|--------------|----------|-------------|
| 10 | `POST` | `/api/agora/token` | Bearer | `{ channelName, uid, userRole }` | `{ success, data: { token }, expireTime }` | Generate an Agora RTC token. `userRole`: `0` = subscriber, `1` = publisher |
| 11 | `POST` | `/verifyToken` | Bearer | `{ channelName, uid, userRole }` | `{ success, token }` | Re-generate token on Agora privilege-will-expire event _(legacy — no `/api/` prefix)_ |

---

### Cloud Recording

All recording endpoints share the same base path. The `type` field in the body distinguishes `"mix"` (server-side composite) from `"individual"` (per-user track).

| # | Method | Path | Auth | Request Body | Response | Description |
|---|--------|------|------|--------------|----------|-------------|
| 12 | `POST` | `/api/agora/recording/start` | Bearer | `{ cname, uid, type: "mix", token }` | `{ success }` | Start **mix** recording |
| 13 | `POST` | `/api/agora/recording/start` | Bearer | `{ cname, uid, type: "individual", token }` | `{ success }` | Start **individual** (per-user) recording |
| 14 | `POST` | `/api/agora/recording/stop` | Bearer | `{ cname, type: "mix", uid }` | `{ success }` | Stop mix recording |
| 15 | `POST` | `/api/agora/recording/stop` | Bearer | `{ cname, type: "individual", uid }` | `{ success }` | Stop individual recording |
| 16 | `POST` | `/api/agora/recording/status` | Bearer | `{ cname, uid, type: "mix" \| "individual" }` | `{ success: bool }` | Poll recording status — the app retries until `success: true` |
| 17 | `POST` | `/api/agora/recording/update` | Bearer | `{ cname, uid, type, audioSubscribeUids: [uid, ...] }` | `{ success }` | Update the list of users whose audio the recorder subscribes to |

---

### Recording Playback (Flutter app)

| # | Method | Path | Auth | Request Body | Response | Description |
|---|--------|------|------|--------------|----------|-------------|
| 18 | `POST` | `/api/agora/recording/fetch-m4a` | Bearer | `{ channelName, recordingStartTime, recordingEndTime, type }` | `{ success, data: "<url>" }` | Full track `.m4a` (HLS → ffmpeg on server, cached in R2) |
| 19 | `POST` | `/api/agora/recording/fetch-m4a/trimmed` | Bearer | `{ channelName, type, recordingFullStartTime, recordingFullEndTime, trimmedStartTime, trimmedEndTime }` | `{ success, data: "<url>" }` | One speaking-event clip |
| 20 | `POST` | `/api/agora/recording/fetch-m4a/trimmed/batch` | Bearer | `{ channelName, type, clips: [...], concurrency?: 5 }` | `{ success, data: { clips: [{ clipId, url, success }] } }` | Many clips (server concurrency cap) |
| 21 | `GET` | `/api/agora/recording/hls/proxy` | Bearer | `?key=<r2-key>` | HLS body | Proxy m3u8/ts with Bearer auth |
| 22 | `POST` | `/api/agora/recording/cleanupSecureFiles` | Bearer | `{}` | _(not checked)_ | Cleanup temporary signed files on R2 |

**Legacy (not used by current app):** `/recording/list/mix`, `/recording/list/individual/audiofile`.

---

### External — FCM Push Notifications

| # | Method | URL | Auth | Request Body | Description |
|---|--------|-----|------|--------------|-------------|
| 23 | `POST` | `https://fcm.googleapis.com/fcm/send` | `key=<SERVER_KEY>` | `{ to, notification: { title, body }, data: {...} }` | Send a push notification via FCM legacy API. **⚠️ Server key is currently a placeholder** — not active in production. |

---

### Media download (direct CDN)

`ClipAudioDownloader` downloads the signed `.m4a` URL from endpoints 18–20 (single HTTP GET).

| # | Method | URL | Description |
|---|--------|-----|-------------|
| 24 | `GET` | `<signed .m4a url>` | Save clip to device Downloads |

---

## Firestore Collections (Direct SDK — no backend)

| Collection path | Operations | Purpose |
|---|---|---|
| `users` | get, where, update, snapshots | User profiles |
| `meetings` | get, set, update, where, snapshots | Meeting records |
| `meetings/{id}/participants` | set, update, get, snapshots | Live participant tracking |
| `meetings/{id}/joinRequests` | set, update, delete, snapshots | Join-request approval flow |
| `meetings/{id}/recordingTrack` | get, set, update, snapshots | Recording start/stop timestamps per track |
| `meetings/{id}/recordingTrack/{trackId}/speakingEvents` | set, update, get, where | Per-user speaking clip metadata |
| `meetings/{id}/recordingUrls` | get, set | Pre-signed URL cache (3 h TTL) written by backend |
| `meetings/{id}/extensions` | add, snapshots | Meeting time-extension log |
| `call_logs` | add, update | Call start/end audit trail |

---

## Authentication Flow

```
User enters credentials
        │
        ▼
POST /api/auth/login
        │
   { token, user }
        │
        ▼
Token stored in SharedPreferences
        │
        ▼
All subsequent requests: Authorization: Bearer <token>
        │
   401 received (authenticated request)?
        │
        ▼
Session-expired handler (once if many calls fail together):
  toast → clear local session → Get.offAllNamed(/login)
```

---

## Recording Flow

### During meeting (metadata)

```
PTT on/off while recording → Firestore speakingEvents { start, stop, userId, userName }
recordingTrack.stopTime set when cloud recording ends
```

### Meeting detail — individual clips

```
loadMeetingDetails()
        │
        ▼
Firestore: recordingTrack + speakingEvents
  (participants: where userId == logged-in user)
        │
        ▼
Show list immediately (name, time, per-row “Loading audio…”)
        │
        ▼
POST /fetch-m4a/trimmed/batch (chunks of 25, server concurrency 5)
  → fallback: POST /fetch-m4a/trimmed (client pool of 5)
        │
        ▼
Rows gain playable URL → RecorderAudioTile + download enabled
```

### Server (cloud recording → R2)

```
start/stop recording → HLS on R2 → fetch-m4a builds .m4a via ffmpeg (cached under audiorecording/)
```

---

## Legacy Endpoints

The following endpoints have **no `/api/` prefix** and pre-date the current Express server layout. They are still called by the app but should be migrated to the versioned path in a future backend update.

| Endpoint | Current caller | Replacement target |
|---|---|---|
| `POST /resetPassword` | `app_auth_service.dart` | `POST /api/auth/reset-password` |
| `POST /getUsersForPasswordReset` | `app_auth_service.dart` | `GET /api/auth/users` |
| `POST /verifyToken` | `agora_token_helper.dart` | `POST /api/agora/token` |
| `GET /generateLoginToken` | `app_http_interceptor.dart` _(unused)_ | `POST /api/auth/login` |
| `GET /refreshLoginToken` | `app_http_interceptor.dart` _(unused)_ | `GET /api/auth/refreshLoginToken` _(app does not auto-call on 401)_ |

---

## Environment / Configuration

| Key | Location | Description |
|---|---|---|
| `baseUrl` | `lib/core/config/app_config.dart` | Backend Express server base URL |
| `agoraAppId` | `lib/core/constants/` | Agora App ID |
| `cloudflareEndpoint` | server `.env` | Cloudflare R2 S3-compatible endpoint |
| `cloudflareAccessKey` | server `.env` | R2 access key |
| `cloudflareSecretKey` | server `.env` | R2 secret key |
| `bucketName` | server `.env` | R2 bucket name |
| Firebase config | `lib/firebase_options.dart` | Auto-generated by FlutterFire CLI |
