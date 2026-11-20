# NallaBox App — Technical Design

Status: approved · 2026-11-20
Inputs (binding): [PRD](https://claude.ai/artifact/T3mx85dvW5cY8ydmDxaUsq) · UI/UX design `docs/2026-11-19-nallabox-ui-ux-design.md` · mockups `design/mockups/` (screen IDs T*, P*, R*, C*, I*, H*, M*) · tokens `design/NallaBoxTheme.swift`, `design/mockups/shared/tokens.css`.
**(your call)** = decided by you in conversation; **(my call)** = my default, open to change.

## 1. Intent

Build NallaBox v1 as a working app: a host app on iPhone and Mac that runs a party room on the local network, shows the game on a TV, and lets guests play from their phone browsers after one QR scan. Every screen matches the approved mockups.

## 2. Goals, non-goals, anti-goals

**Goals**
- Full v1 scope **(your call)**: iPhone host and Mac host, room/lobby/leader/reconnect, and all three launch games: Redacted, Composite Sketch, Insider Trading.
- Native Swift with zero third-party dependencies **(your call)**.
- Playable end to end on this Mac: iOS Simulator or Mac host + browser tabs as phones.

**Non-goals (v1):** Apple TV host, iPad-specific layouts, audience mode, remote play, accounts, analytics, monetization, sound design, the full content library (PRD targets 150 passages / 100 scenes / 500 questions).

**Anti-goals** (from the UI/UX design §2, plus):
- A phone ever receives another player's secret: the server sends each phone only its own view.
- Anyone must touch the host device during normal play.
- Game rules living in UI code: rules live in the core package and are tested without any UI.

## 3. Constraints

- Xcode 27.2, Swift 6.4 (strict concurrency), XcodeGen 2.45 (installed). Deployment targets: **iOS 18, macOS 15 (my call)**: current minus one, and enough for `@Observable` and SwiftUI scene APIs.
- No internet at play time; everything (controller page, fonts, content) is bundled in the app.
- Real-device runs need your Apple developer team for signing; the project is set to automatic signing with no team **(my call)**. Bundle IDs: `app.nallabox.ios`, `app.nallabox.mac` **(my call)**.
- The folder becomes a git repository at the start of the build; work lands in small commits **(my call, agreed in conversation)**.

## 4. Approaches considered

1. **All native Swift, no third-party libraries (chosen, your call).** Apple's Network framework for HTTP and WebSocket, a Swift package for the engine, SwiftUI for TV and host, plain HTML/CSS/JS controller grown from the mockups.
2. Swift + SwiftNIO server (Vapor/Hummingbird): mature HTTP/WebSocket, but a large dependency tree and unsupported inside iOS apps.
3. Web-technology TV + JS engine: maximum mockup reuse, but not the SwiftUI app, and still needs a native server.

## 5. Architecture

```
NallaBox/
  app/project.yml                 XcodeGen spec → NallaBox.xcodeproj (generated, not committed)
  app/Shared/                     SwiftUI: theme, TV screens, face, host flows (both platforms)
  app/iOS/  app/macOS/            Platform entry points, external display, Info.plists
  app/Resources/Controller/       Phone controller: index.html, *.js, *.css, fonts (bundled as a folder)
  app/Resources/Content/          redacted.json, sketch.json, insider.json, profanity.txt
  Packages/NallaCore/             Pure Swift: protocol, room, games, content, moderation (no UI, no networking)
  Packages/NallaServer/           Network-framework HTTP + WebSocket servers, connection registry
  tests/controller/               Node `node:test` tests for the controller's pure render/logic modules
```

### 5.1 NallaCore (Swift package, iOS 18 / macOS 15)

- **Protocol** (`Codable`, protocol version `1`): every message has `v`, `type`, `id`.
  - Phone → host: `join {room, name, colour, seatToken?}`, `submit_text {round, fields[]}`, `stroke_data {round, strokes[], final}`, `cast_vote {round, choice}`, `place_bet {round, choice, chips}`, `leader {action, args}` (pick_game, preview_game, set_settings, start, pause, resume, skip, end, remove_player, pass_leader, play_again, new_game), `ping {t}`.
  - Host → phone: `welcome {playerId, seatToken}`, `view {version, screen, deadline?, you, room, data}`, `ack {id}`, `error {id?, code, message}`, `pong {t, hostTime}`, `removed`.
  - `screen` is the mockup screen ID (`P3`, `R1`, `C2-witness`, `I1-insider` …) so the controller renders exactly that mockup.
- **Room**: seats (max 8), names (≤ 12, unique, filtered), colours (8, coral never), seat tokens, connection state, leader (first joined; passes to next-joined after 30 s offline), pause, settings (rounds, timer multiplier 1/1.5/2/off, family-friendly, banned words), late joiners wait for the next game.
- **Engine**: a pure reducer `reduce(state, event, now) -> (state, [Effect])`. Events: player messages, ticks, timers, disconnects. Effects: schedule a deadline, send views, speak a line, set the face state. Time comes from an injected clock so tests run instantly.
- **Games** (one type per game, conforming to `GameRules`): phases, scoring and per-player views exactly as UI/UX §7.3 and the PRD:
  - Redacted: 3 rounds + final ×3, 60 s write / 30 s vote, too-close check (case/accents/edit distance ≤ 1, plurals), near-duplicate fakes merge and split points, +500 per player fooled, +1,000 for the real one.
  - Composite Sketch: one round per player (max 8), Witness rotates, 5 s brief / 30 s draw / 20 s pick / 15 s worst vote, +1,000 artist and +500 Witness, Most Wanted award, optional banned words.
  - Insider Trading: 6–8 rounds, Insider rotates without repeats, 5,000 starting chips, 500 bailout at 0, 30 s discuss / 15 s bet / 15 s accuse, 10% commission, majority unmask → 300 chips per accuser.
  - Every timed phase ends early when all expected inputs are in; pause freezes all deadlines.
- **Views**: one function per game builds each player's view and the TV view from state. Secret fields (Insider answer, Witness scene) are only ever written into the owning player's view; a test asserts no other view contains them.
- **Content**: JSON packs + loader; picks without repeats per room, honours the family-friendly tag. **Starter content (my call):** 40 passages, 24 scenes, 120 questions: enough for several sessions; the full library is a content task, not code.
- **Moderation**: built-in profanity list, applied to names and answers when family-friendly is on.

### 5.2 NallaServer (Swift package, depends on NallaCore)

- **HTTP** on port 8080 (fallback 8081–8089 if busy) via `NWListener` (TCP): a minimal HTTP/1.1 GET server for the bundled controller folder (correct MIME types, `index.html` default, no directory listing, 404 otherwise).
- **WebSocket** on HTTP port + 1 via `NWListener` with `NWProtocolWebSocket`; the controller page learns the port from a query parameter in the QR URL.
- **Security** (PRD): `join` requires the room code; every later message must come from a joined connection; seat tokens are random 128-bit; join attempts rate-limited per IP (10/min).
- **Hub actor**: owns the room/engine state, serialises events, runs timers on the injected clock, fans out per-player `view` snapshots (sent on every change, with a monotonically increasing version), answers `ping` for clock offset.
- **LAN address**: `getifaddrs`, preferring `en0`/Wi-Fi IPv4; the QR encodes `http://<ip>:<port>/?room=<code>&ws=<port+1>`.
- **Bonjour**: advertises `_nallabox._tcp` (also used to trigger and detect the Local Network permission on iOS).

### 5.3 Phone controller (web, bundled)

- Plain ES modules, no build step, no frameworks **(my call)**: `net.js` (WebSocket, reconnect with backoff, seat token in `localStorage`, clock offset), `render.js` (pure functions `screen → HTML string` per mockup ID), `app.js` (wires events), `canvas.js` (drawing: pointer events, 6 colours, 3 sizes, undo, clear; strokes batched every 2 s and on submit), `hold.js` (hold-to-reveal, as fixed in the mockups).
- CSS = the mockup `tokens.css` + `components.css` + a small `controller.css`; Nunito `woff2` bundled.
- Screen Wake Lock during games; Dynamic Type honoured via the existing `--nb-text-scale` approach.
- Inputs are kept locally while reconnecting and resent after `welcome`.

### 5.4 Host app (SwiftUI, iOS + macOS targets)

- **TV renderer**: SwiftUI views for every TV mockup screen, laid out on a fixed 1920×1080 canvas and scaled to fit the display (letterboxed). Uses `NallaBoxTheme.swift` and bundled Nunito.
- **Face**: SwiftUI `Shape`s for the 8 states from the logo geometry, with the 180 ms squash and Reduced Motion fade; captions from engine effects; host voice via `AVSpeechSynthesizer` (on by default, captions always).
- **iPhone host** (H1–H8): onboarding, Local Network explainer + denied state, AirPlay route picker (`AVRoutePickerView`), external display as its own scene (`windowExternalDisplayNonInteractive`) showing the TV renderer, name entry, live room = host strip + `WKWebView` loading the local controller (`?host=1` auto-joins as player 1 and leader), host menu with confirms, TV-disconnected and backgrounding handling (pause + resume prompt), idle timer disabled.
- **Mac host** (M1–M5): start window with display picker (each `NSScreen`, or this window full screen), TV renderer in a borderless full-screen window on the chosen screen, room window with live preview (a second instance of the TV view), player list, emergency toolbar, network-problem panel, settings sheet. Esc in single-display mode pauses and shows the top-edge bar.
- **QR**: Core Image `CIQRCodeGenerator`.

### 5.5 Details settled for the builder (my calls)

- **Room codes**: 4 letters from an alphabet without I, O, L or vowels, so codes are easy to read aloud and can't spell words.
- **Strokes**: each stroke = colour index (0–5), size index (0–2), points normalised to 0…1 on the square canvas; the TV and Witness pick screens draw them with SwiftUI `Path`; the controller sends at most 2,000 points per drawing.
- **Composite Sketch art**: starter scenes ship as a caption plus a large emoji composition (for example 🦝🤵🥖🏪) as the Witness's "illustration"; commissioned illustrations replace them later with no code change (the content field accepts an image name).
- **Redacted read-out**: each version shows for its spoken duration (host voice on) or 4 s (voice off), then voting opens.

## 6. Testing and verification

- `swift test` for NallaCore: every rule above, scoring tables, timers via the fake clock, pause, reconnect, leader handoff, privacy of views, content loading. Target: game rules fully covered before any UI.
- `swift test` for NallaServer: real sockets on localhost: HTTP serving, WebSocket join/view/ack, room-code and token checks, rate limiting, and a full scripted Redacted, Composite Sketch and Insider Trading game played by simulated clients.
- `node --test tests/controller`: render functions produce each mockup screen's key elements per view; reconnect/backoff logic.
- `xcodebuild` builds both app targets (iOS Simulator, macOS) with zero warnings in strict concurrency.
- Manual-style verification I run myself: launch the Mac app and the iOS app in the simulator, open browser tabs as phones, play each game; compare TV and phone screenshots against `design/mockups/_shots/`.

## 7. Build order (for the plan)

1. Repo + XcodeGen project + empty packages building on both platforms.
2. NallaCore protocol, room, engine skeleton, content loader.
3. NallaServer HTTP + WebSocket + hub; scripted clients join a room.
4. Controller shell (P1–P13) against the live server.
5. Host app shell: TV lobby/picker/results (T1–T10), face, iPhone host flow, Mac host flow.
6. Redacted end to end (core → server → controller → TV).
7. Composite Sketch end to end.
8. Insider Trading end to end.
9. Hardening: reconnect, pause, backgrounding, network self-test, accessibility, starter content, final review.

## 8. Left to the builder

File and type names inside each module, SwiftUI view decomposition, exact animation curves beyond the UI/UX spec, the internal HTTP parser shape, and the starter content's wording (within the PRD's tone and family-friendly tagging).
