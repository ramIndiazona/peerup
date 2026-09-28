# PeerUp — Mobile (Flutter)

Flutter client for the PeerUp social English conversation platform.

## Overview

This is the Phase 9 scaffold: a feature-first Flutter app that wires the mobile
UI to the NestJS backend (`../backend`) — REST for data, Socket.IO for
matchmaking/signaling, and WebRTC for live voice calls.

## Requirements

- Flutter 3.29+ (Dart 3.7+)
- Backend running on `http://localhost:3100`

## Run

```sh
flutter pub get
flutter run          # defaults to API_BASE_URL=http://localhost:3100
```

Point the app at a different backend:

```sh
flutter run --dart-define=API_BASE_URL=https://api.peerup.example \
            --dart-define=WS_URL=https://api.peerup.example
```

## Structure

```
lib/
  main.dart                       entry point
  app.dart                        MaterialApp.router + theme + auth listen
  core/
    config/                       AppConfig (from --dart-define) + routes
    network/                      Dio ApiClient with auth + token refresh
    sockets/                      Socket.IO wrapper (matchmaking + signaling)
    storage/                      secure token storage
    theme/                        Material 3 light/dark themes + brand colors
    router/                       go_router config (auth-gated redirect)
    widgets/                      shared widgets (avatar, buttons, async view)
    utils/                        validators
  models/                         DTOs mirroring the Prisma schema
  features/
    auth/                         login, register, splash, session controller
    onboarding/                   language/level/goals/interests setup
    match/                        matchmaking repo + search state machine
    call/                         WebRTC service, call controller + screens
    ai/                           AI characters, chat, feedback screens
    profile/                      profile screen, edit, public profile
    notifications/                in-app notifications list
    premium/                      subscription/usage + premium screen
    settings/                     settings + logout
```

## Backend integration

| Area            | REST / WS                                    |
| --------------- | -------------------------------------------- |
| Auth            | `POST /auth/register · /login · /refresh`    |
| Profile         | `GET/PATCH /users/me`, `GET /users/:id`      |
| Interests       | `GET /users/interests`                       |
| Matchmaking     | `POST /matchmaking/start · cancel · status`  |
| Realtime events | Socket.IO `/realtime` (MATCH_FOUND, calls)   |
| Calls           | `GET /calls/:id`, `POST /calls/:id/end·report` |
| AI practice     | `/ai/characters · scenarios · sessions:...`  |
| Subscriptions   | `/subscriptions/me · usage · purchase · cancel` |
| Notifications   | `/notifications`, `PATCH /notifications/:id/read` |
| Blocks/Reports  | `/blocks`, `/blocks/:userId/report`          |
| Storage         | `POST /storage/avatar` (base64)              |

## Test

```sh
flutter test
```

## Config keys

- `API_BASE_URL` — REST base (default `http://localhost:3100`)
- `API_PREFIX` — global Nest prefix (default `api`)
- `WS_URL` — Socket.IO origin (default same as API_BASE_URL)
- `TURN_URL / TURN_USERNAME / TURN_CREDENTIAL` — optional TURN for WebRTC