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
│   ├── middleware/        # HTTP interceptor (token refresh)
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
On a `401` response the HTTP service automatically calls `GET api/auth/refreshLoginToken` and retries once.

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
| 9 | `GET` | `/api/auth/refreshLoginToken` | Bearer | `?userId=<id>` | `{ success, token }` | Silently refresh a JWT — called automatically by the HTTP interceptor on 401 |

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

### Recording Playback & Listing

| # | Method | Path | Auth | Request Body | Response | Description |
|---|--------|------|------|--------------|----------|-------------|
| 18 | `POST` | `/api/agora/recording/list/mix` | Bearer | `{ channelName, meetingId }` | `{ success, data: [ { url, startTime }, ... ] }` | List all mix recordings for a meeting. Returns pre-signed HLS `.m3u8` URLs cached in Firestore. |
| 19 | `POST` | `/api/agora/recording/list/individual/audiofile` | Bearer | `{ channelName, type: "mix", startTime, endTime }` | `{ success, data: { playableUrl } }` | Get a signed HLS `.m3u8` URL for a specific individual recording clip. |
| 20 | `POST` | `/api/agora/recording/cleanupSecureFiles` | Bearer | `{}` | _(not checked)_ | Fire-and-forget cleanup of temporary signed files on R2. |

---

### External — FCM Push Notifications

| # | Method | URL | Auth | Request Body | Description |
|---|--------|-----|------|--------------|-------------|
| 23 | `POST` | `https://fcm.googleapis.com/fcm/send` | `key=<SERVER_KEY>` | `{ to, notification: { title, body }, data: {...} }` | Send a push notification via FCM legacy API. **⚠️ Server key is currently a placeholder** — not active in production. |

---

### HLS Media (Direct CDN — not backend)

These are plain HTTP GET calls made by `ClipAudioDownloader` directly to Cloudflare R2. The signed URLs are obtained from endpoints 18 / 19 above.

| # | Method | URL | Description |
|---|--------|-----|-------------|
| 24 | `GET` | `<playableUrl>` (signed `.m3u8`) | Fetch HLS playlist from R2 to parse segment list |
| 25 | `GET` | `<segment_url>` (signed `.ts`) | Download each MPEG-TS audio segment for offline save |

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
   401 received?
        │
        ▼
GET /api/auth/refreshLoginToken?userId=<id>
        │
  { token } ──► update stored token ──► retry original request
        │
   Still 401? ──► force logout
```

---

## Recording Flow

```
Host joins meeting
        │
        ▼
POST /api/agora/token (publisher role)
        │
POST /api/agora/recording/start (type: individual)
POST /api/agora/recording/start (type: mix)  [member only]
        │
POST /api/agora/recording/status  ──► poll until active
        │
During call: POST /api/agora/recording/update  (when participant list changes)
        │
Host ends / leaves meeting
        │
POST /api/agora/recording/stop (individual)
POST /api/agora/recording/stop (mix)           [member only]
        │
POST /api/agora/recording/cleanupSecureFiles
        │
        ▼
Recordings stored on Cloudflare R2 as HLS (.m3u8 + .ts segments)
        │
        ▼
Meeting detail page:
  POST /api/agora/recording/list/mix              → playable URLs (cached in Firestore)
  POST /api/agora/recording/list/individual/audiofile → clip URL per speaking event
        │
        ▼
User taps Download:
  GET <m3u8 URL>  → parse segments
  GET <.ts URLs>  → download one-by-one
  FFmpeg merge    → .m4a saved to Downloads (Android)
  Binary concat   → .ts saved to Downloads (Windows)
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
| `GET /refreshLoginToken` | `app_http_interceptor.dart` _(unused)_ | `GET /api/auth/refreshLoginToken` |

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
