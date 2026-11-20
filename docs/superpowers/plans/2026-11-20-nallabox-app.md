# NallaBox v1 App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship NallaBox v1: an iPhone and Mac host app that runs a local party room, shows the game on a TV, and lets guests play Redacted, Composite Sketch and Insider Trading from their phone browsers.

**Architecture:** A pure Swift rules package (`NallaCore`: a reducer `reduce(state, event, now)` plus per-player views) is driven by an actor hub in `NallaServer`. The hub sits behind Network-framework HTTP and WebSocket listeners. Phones run a bundled plain-JS controller that renders whichever mockup screen ID the server sends. The SwiftUI host app draws the TV from the same views and hosts the room on iPhone (AirPlay/HDMI) or Mac (any display).

**Tech Stack:** Swift 6.4 (language mode 6, strict concurrency), SwiftUI, Network.framework, AVFoundation, WebKit, Core Image, XcodeGen 2.45, XCTest/Swift Testing, plain ES-module JavaScript, Node 24 `node:test`.

**Spec:** `docs/superpowers/specs/2026-11-20-nallabox-app-design.md` (read it with this plan). Binding inputs: `docs/2026-11-19-nallabox-ui-ux-design.md` (screen inventory §7, visual system §9, copy voice §10) and the mockups in `design/mockups/`. The mockup builders `design/mockups/_build/pages_*.py` and `kit.py` are the **source of truth for every screen's markup, class names and copy**. "Port screen X" means: reproduce that page's structure, classes and copy, with sample names and numbers replaced by view data.

## Global Constraints

- Zero third-party dependencies (Swift and JS). No internet at play time; everything is bundled.
- Deployment targets: iOS 18.0, macOS 15.0. Swift language mode 6, `SWIFT_STRICT_CONCURRENCY=complete`, and both apps build with **zero warnings**.
- Bundle IDs: `app.nallabox.ios`, `app.nallabox.mac`; product name `NallaBox`; automatic signing with no team (Mac: "Sign to Run Locally", `CODE_SIGN_IDENTITY = "-"`). iPhone only (`TARGETED_DEVICE_FAMILY = 1`).
- Protocol version `1`; every message is JSON `{v, type, id, ...}`.
- Room: max 8 players; names 1–12 grapheme clusters after trimming, unique case-insensitively; 8 player colours (saffron, sky, mint, lilac, pink, lime, teal, sand), and coral is never a player colour.
- Room code: 4 letters from `BCDFGHJKMNPQRSTVWXZ`.
- Ports: HTTP 8080 (fallback 8081–8089); WebSocket = HTTP port + 1. QR/join URL: `http://<ip>:<port>/?room=<code>&ws=<port+1>`.
- Seat tokens are random 128-bit values (32 lowercase hex chars). Joins are limited to 10 per IP per rolling 60 s. Max WebSocket message size is 65,536 bytes.
- Timer setting `1 | 1.5 | 2 | off` multiplies **input** phase durations (write, vote, draw, pick, bet, accuse, discuss); `off` removes their deadlines. Fixed phases (briefing, read-out, reveals, scores, how-to) are never multiplied.
- Every timed input phase ends early when every **connected** player expected to act has acted. Pause freezes all deadlines.
- Leader = first joined; passes to the next-joined connected player after 30 s offline, immediately on removal, or by `pass_leader`.
- TV canvas is 1920×1080 with an 80 pt safe area and TV text ≥ 30 pt. Phone tap targets are ≥ 44 pt. Face captions are ≤ 48 characters. Copy follows UI/UX §10.
- Every screen's `data` is encoded from a public `Codable` struct in the owning Views file: room screens use the names given in Task 4, and game screens use `<ScreenID>TV` / `<ScreenID>Phone` (for example `R1TV`, `C2WitnessPhone`). The TV decodes those structs, and the controller reads the same JSON keys.
- A phone never receives another player's secret (Insider identity/answer, Witness scene). The TV shows them only at their reveal screens.
- Commit after every task in small commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Stale input after a phone wakes up:** a phone that slept through a phase change sends `submit_text`/`cast_vote` for an old round. Expect an `ack`, no state change and no error toast, and the phone then renders the current view (Task 4 `test_staleRoundInputIgnored`, Task 10 `test_staleVoteIgnored`).
2. **Same seat open twice:** a guest opens the join link in a second tab, or the phone reconnects before the old socket dies. Expect the newest connection to own the seat and the old one to get `removed {reason:"replaced"}`, with no duplicate player (Task 6 `test_secondConnectionTakesSeat`).
3. **Names that aren't plain ASCII:** emoji, accents, RTL text, leading or trailing spaces, whitespace-only. Expect names to be trimmed and counted in grapheme clusters (`"👩‍👩‍👧"` is 1), whitespace-only rejected, and uniqueness ignoring case and accents (Task 2 `test_nameRules`).
4. **The leader vanishes mid-game:** the leader is removed by the host, or drops while the game is paused. Expect leadership to pass at once (removal) or after 30 s (drop, even while paused), and the new leader's next view to carry `isLeader` (Task 4 `test_leaderRemovedPassesImmediately`, `test_leaderHandoffWhilePaused`).
5. **Garbage on the wire:** malformed JSON, unknown `type`, a wrong protocol version, a 2 MB frame, a drawing with 5,000 points. Expect `error` replies for the first three with the connection kept, the oversized frame to close only that connection, and the drawing to be truncated at 2,000 points (Task 6 `test_malformedMessages`, Task 11 `test_strokePointCap`).

---

## File Structure

```
.gitignore                                  build outputs, NallaBox.xcodeproj, _shots
app/project.yml                             XcodeGen spec for NallaBox-iOS and NallaBox-Mac
app/Assets.xcassets/                        AppIcon (logo/kit/app-icon), Face/face-<state> SVG imagesets (8)
app/Resources/Content/                      redacted.json, sketch.json, insider.json, profanity.txt
app/Resources/Controller/                   phone controller, served as a folder
  index.html  controller.css
  shared/tokens.css base.css components.css fonts/nunito-wght.woff2   (byte copies of design/mockups/shared/*)
  shared/img/nallabox-symbol-color.svg
  js/net.js  app.js  hold.js  canvas.js  drafts.js
  js/render/kit.js  room.js  redacted.js  sketch.js  insider.js  index.js
app/Shared/                                 both platforms
  HostModel.swift  HostPrefs.swift  HostVoice.swift  QRCode.swift  NetworkSelfTest.swift
  TV/TVCanvas.swift  TVRootView.swift  TVComponents.swift  StrokeCanvas.swift
  TV/RoomScreens.swift  RedactedScreens.swift  SketchScreens.swift  InsiderScreens.swift
  Face/FaceCorner.swift
app/iOS/   NallaBoxApp.swift  ExternalDisplay.swift  LocalNetwork.swift  RoutePicker.swift
           ControllerWebView.swift  Flow/H1…H8 *.swift  Info.plist
app/macOS/ NallaBoxMacApp.swift  DisplayPicker.swift  TVWindowController.swift
           M1StartView.swift  M2RoomView.swift  M4NetworkPanel.swift  M5SettingsSheet.swift  Info.plist  NallaBox.entitlements
Packages/NallaCore/Sources/NallaCore/
  Protocol/  JSONValue.swift  Messages.swift  Views.swift
  Model/     Player.swift  RoomState.swift  RoomCode.swift  SplitMix64.swift  Names.swift
  Engine/    Engine.swift  GameRules.swift  RoomViews.swift  Results.swift
  Content/   Content.swift  Moderation.swift  TextMatch.swift
  Games/     Redacted.swift  RedactedViews.swift  Sketch.swift  SketchViews.swift  Insider.swift  InsiderViews.swift
Packages/NallaCore/Tests/NallaCoreTests/    one file per source area + Fixtures.swift
Packages/NallaServer/Sources/NallaServer/
  HTTP.swift  HTTPServer.swift  WebSocketServer.swift  Hub.swift  HubClock.swift
  RateLimiter.swift  LANAddress.swift  RoomServer.swift
Packages/NallaServer/Sources/NallaDevServer/main.swift   `swift run NallaDevServer`: room in a terminal for browser testing
Packages/NallaServer/Tests/NallaServerTests/  HTTPTests, HubTests, SocketTests, ScriptedGameTests, TestClient.swift
tests/controller/*.test.mjs                 node:test for render/net/drafts/canvas
```

Two deliberate refinements of the spec, both left to the builder by spec §8:
- **Face artwork:** the face uses the 8 face SVGs from `design/mockups/shared/face/` in an asset catalog (vector-preserved), which is the exact logo geometry. They are drawn with SwiftUI `Image` plus the §9.6 squash/fade, instead of hand-ported `Shape`s.
- **Read-out timing:** "spoken duration" is estimated in the pure engine as `max(3, words / 2.6 + 1)` s with the voice on, or 4 s with it off, so the reducer stays deterministic.

---

### Task 1: Repository, Xcode project and empty packages

**Files:**
- Create: `.gitignore`, `app/project.yml`, `app/iOS/NallaBoxApp.swift`, `app/iOS/Info.plist`, `app/macOS/NallaBoxMacApp.swift`, `app/macOS/Info.plist`, `app/macOS/NallaBox.entitlements`, `app/Assets.xcassets/**`, `Packages/NallaCore/Package.swift`, `Packages/NallaCore/Sources/NallaCore/NallaCore.swift`, `Packages/NallaCore/Tests/NallaCoreTests/SmokeTests.swift`, `Packages/NallaServer/Package.swift` (+ same smoke files), `app/Resources/Controller/index.html` (placeholder), `app/Resources/Content/.keep`

**Interfaces:**
- Produces: schemes `NallaBox-iOS` and `NallaBox-Mac`; package products `NallaCore`, `NallaServer`; `public let nallaProtocolVersion = 1` in NallaCore.

- [ ] **Step 1:** `git init`. `.gitignore` covers `.build/`, `DerivedData/`, `app/NallaBox.xcodeproj/`, `*.xcuserstate`, `.DS_Store`, `design/mockups/_shots/` (26 MB, regenerable with `tests/design/shoot.py`) and `node_modules/`. Commit the existing docs, design, logo and tests as `chore: import design work`.
- [ ] **Step 2:** Packages. Both use `swift-tools-version: 6.0` and `platforms: [.iOS(.v18), .macOS(.v15)]`; NallaServer depends on `../NallaCore` and adds an executable target `NallaDevServer`. Each gets a smoke test asserting `nallaProtocolVersion == 1`.
- [ ] **Step 3:** Run `cd Packages/NallaCore && swift test` and then the same in `Packages/NallaServer`. Expected: both PASS.
- [ ] **Step 4:** Write `app/project.yml`:
  - Global settings: options `deploymentTarget {iOS: "18.0", macOS: "15.0"}`; base settings `SWIFT_VERSION: 6.0`, `SWIFT_STRICT_CONCURRENCY: complete`, `CODE_SIGN_STYLE: Automatic`, `DEVELOPMENT_TEAM: ""`, `PRODUCT_NAME: NallaBox`, `MARKETING_VERSION: 1.0`.
  - Local packages: NallaCore and NallaServer.
  - Each target's sources: `Shared`, its platform folder, `../design/NallaBoxTheme.swift` (referenced, not copied, so `tests/design/test_tokens.py` keeps guarding it), `Assets.xcassets`, `Resources/Content`, `Resources/Controller` as `type: folder`, and `../design/mockups/shared/fonts/Nunito[wght].ttf`.
  - iOS Info.plist keys:
    - `NSLocalNetworkUsageDescription` = "Friends' phones connect to this iPhone over your Wi-Fi to play." (the H2 alert copy)
    - `NSBonjourServices` = [`_nallabox._tcp`]
    - `UIAppFonts` = [`Nunito[wght].ttf`]
    - `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes = YES` and a `UIWindowSceneSessionRoleExternalDisplayNonInteractive` configuration whose delegate class is `ExternalDisplaySceneDelegate`
    - `UISupportedInterfaceOrientations` = portrait
  - Mac: `ATSApplicationFontsPath = "."`, `CODE_SIGN_IDENTITY: "-"`, and entitlements `com.apple.security.app-sandbox`, `network.server`, `network.client`.
- [ ] **Step 5:** Fill `Assets.xcassets`:
  - `AppIcon` from `logo/kit/app-icon/nallabox-app-icon-1024.png`, as a single-size iOS and macOS icon.
  - `Face/face-{idle,blink,wink,grin,gasp,suspicious,sleepy,celebrate}` imagesets from `design/mockups/shared/face/*.svg` with `preserves-vector-representation: true`.
  - `Symbol` from `logo/kit/symbol/` (colour SVG).
- [ ] **Step 6:** Placeholder apps. iOS `@main struct NallaBoxApp: App` and Mac `@main struct NallaBoxMacApp: App` each show `Text("nallabox")` in `NB.Palette.ink`. Add a stub `final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate`.
- [ ] **Step 7:** Verify:
  - Run: `cd app && xcodegen generate`.
  - Build both apps:
    - `xcodebuild -project app/NallaBox.xcodeproj -scheme NallaBox-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tee /tmp/ios.log | tail -1`
    - `xcodebuild -project app/NallaBox.xcodeproj -scheme NallaBox-Mac -destination 'platform=macOS' build 2>&1 | tee /tmp/mac.log | tail -1`
  - Then `grep -c ' warning:' /tmp/ios.log /tmp/mac.log`.
  - Expected: `** BUILD SUCCEEDED **` twice and `0` warnings.
- [ ] **Step 8:** Commit `chore: XcodeGen project, packages and placeholder apps`.

---

### Task 2: Core protocol, model and names

**Files:**
- Create: `Packages/NallaCore/Sources/NallaCore/Protocol/JSONValue.swift`, `Protocol/Messages.swift`, `Protocol/Views.swift`, `Model/Player.swift`, `Model/RoomState.swift`, `Model/RoomCode.swift`, `Model/SplitMix64.swift`, `Model/Names.swift`
- Test: `Tests/NallaCoreTests/MessagesTests.swift`, `ModelTests.swift`

**Interfaces (Produces, all `public`, `Sendable`, `Equatable`, `Codable` where they cross the wire):**
```swift
typealias PlayerID = Int                       // 1-based join order, never reused in a room
struct ConnectionID: Hashable, Sendable { let raw: UUID }
enum PlayerColour: String, CaseIterable { case saffron, sky, mint, lilac, pink, lime, teal, sand }
enum GameID: String, CaseIterable { case redacted, sketch, insider }
enum TimerSpeed: String { case x1 = "1", x15 = "1.5", x2 = "2", off }   // .multiplier: Double?
enum FaceState: String, CaseIterable { case idle, blink, wink, grin, gasp, suspicious, sleepy, celebrate }
struct FaceCue { var state: FaceState; var caption: String? }

indirect enum JSONValue: Codable { case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue]) }
extension JSONValue { static func encode<T: Encodable>(_ v: T) -> JSONValue; func decode<T: Decodable>(_ t: T.Type) throws -> T }

struct JoinRequest { var room: String; var name: String; var colour: PlayerColour; var seatToken: String? }
struct Stroke: Codable { var c: Int; var s: Int; var p: [Double] }   // colour 0–5, size 0–2, flat x,y pairs in 0…1
enum LeaderAction { case pickGame(GameID), previewGame(GameID), setSettings(SettingsPatch), start, pause, resume, skip, end,
                    removePlayer(PlayerID), passLeader(PlayerID), playAgain, newGame }
struct SettingsPatch: Codable { var rounds: Int?; var timer: TimerSpeed?; var familyFriendly: Bool?; var bannedWords: Bool? }
enum ClientMessage { case join(JoinRequest), submitText(round: Int, fields: [String]), strokeData(round: Int, strokes: [Stroke], final: Bool),
                     castVote(round: Int, choice: Int), placeBet(round: Int, choice: Int, chips: Int), leader(LeaderAction), ping(t: Double) }
enum ErrorCode: String { case badMessage = "bad_message", wrongVersion = "wrong_version", notJoined = "not_joined", wrongCode = "wrong_code",
                         roomFull = "room_full", nameTaken = "name_taken", nameInvalid = "name_invalid", colourTaken = "colour_taken",
                         rateLimited = "rate_limited", notLeader = "not_leader", notAllowed = "not_allowed", tooClose = "too_close",
                         empty, tooLong = "too_long", invalid }
enum RemovalReason: String { case byHost = "by_host", sessionEnded = "session_ended", replaced }
enum ServerMessage { case welcome(playerId: PlayerID, seatToken: String), view(PlayerView), ack(id: String),
                     error(id: String?, code: ErrorCode, message: String, field: Int?), pong(t: Double, hostTime: Double), removed(RemovalReason) }
enum Wire { static func decodeClient(_ text: String) -> Result<(id: String, ClientMessage), WireError>   // WireError carries id? + ErrorCode
            static func encode(_ m: ServerMessage) -> String }

struct ScreenView: Codable { var screen: String; var deadline: Double?; var data: JSONValue }      // screen = mockup page id: "P4", "C2-witness"
struct PlayerSummary: Codable { var id: PlayerID; var name: String; var colour: PlayerColour; var connected: Bool; var isLeader: Bool; var score: Int }
struct RoomInfo: Codable { var code: String; var players: [PlayerSummary]; var leaderId: PlayerID?; var game: GameID?; var paused: PauseInfo?; var settings: RoomSettings }
struct PauseInfo: Codable { var by: String }
struct YouInfo: Codable { var id: PlayerID; var name: String; var colour: PlayerColour; var isLeader: Bool; var isHost: Bool; var score: Int }
struct PlayerView: Codable { var version: Int; var screen: String; var deadline: Double?; var you: YouInfo; var room: RoomInfo; var data: JSONValue }
struct TVOverlays: Codable { var paused: PauseInfo?; var reconnecting: [ReconnectBanner]; var toast: String? }
struct ReconnectBanner: Codable { var player: PlayerSummary; var since: Double }
struct TVView: Codable { var screen: ScreenView; var face: FaceCue; var room: RoomInfo; var overlays: TVOverlays }

struct RoomSettings: Codable { var rounds: Int?; var timer: TimerSpeed = .x1; var familyFriendly = true; var bannedWords = false; var voiceOn = true }
struct Player: Codable { var id: PlayerID; var name: String; var colour: PlayerColour; var seatToken: String; var connected: Bool
                         var disconnectedAt: Double?; var isHost: Bool; var waitingForNextGame: Bool; var joinedAt: Double }
struct SplitMix64: RandomNumberGenerator, Codable, Equatable { init(seed: UInt64); mutating func next() -> UInt64 }
enum RoomCode { static let alphabet = "BCDFGHJKMNPQRSTVWXZ"; static func generate<R: RandomNumberGenerator>(using: inout R) -> String }
enum Names { static func normalize(_ raw: String) -> String?            // trimmed, collapsed whitespace; nil if empty or > 12 graphemes
             static func key(_ name: String) -> String }                // case- and diacritic-folded, for uniqueness
```
Wire keys are snake_case, as in the spec (`seat_token`, `player_id`, `host_time`), and leader actions are `{"type":"leader","action":"pick_game","args":{"game":"redacted"}}`. `ScreenView`/`PlayerView` field names stay camelCase in `data` because the controller reads them directly.

- [ ] **Step 1: Write failing tests**
  - `test_decodeEveryClientMessage`: one JSON literal per case round-trips to the expected enum, including `leader` with each action's `args`.
  - `test_decodeErrors`:
    - `"{"` → `.badMessage` with nil id;
    - `{"v":2,"type":"ping","id":"a","t":1}` → `.wrongVersion` with id `"a"`;
    - unknown type → `.badMessage`.
  - `test_encodeServerMessages`: `.error(id:"7", code:.tooClose, message:"Too close to the real word, try another", field:1)` encodes to JSON with `"type":"error","code":"too_close","field":1,"v":1`.
  - `test_roomCodeAlphabet`: 1,000 generated codes are 4 characters, and none contains A, E, I, O, U, L or Y.
  - `test_nameRules`:
    - `"  Priya  "` → `"Priya"`;
    - `"   "` → nil;
    - `"Wolfgangster"` (12) is accepted;
    - `"Wolfgangsters"` (13) → nil;
    - `"👩‍👩‍👧 Ana"` is accepted (5 graphemes);
    - `key("Zoë") == key("zoe")`.
  - `test_splitMixDeterministic`: two generators with seed 42 give equal first 10 values.
  - `test_jsonValueRoundTrip`: a nested Encodable struct round-trips through `JSONValue.encode`/`decode`.
- [ ] **Step 2:** Run `swift test --filter "MessagesTests|ModelTests"` in `Packages/NallaCore`. Expected: FAIL (types missing).
- [ ] **Step 3:** Implement the types above. `Wire.decodeClient` reads `v`, `type` and `id` first, then decodes the case's fields.
- [ ] **Step 4:** Run the same command. Expected: PASS.
- [ ] **Step 5:** Commit `feat(core): protocol messages, room model, names`.

---

### Task 3: Content, moderation and text matching

**Files:**
- Create: `Sources/NallaCore/Content/Content.swift`, `Moderation.swift`, `TextMatch.swift`, `app/Resources/Content/{redacted,sketch,insider}.json` (6 items each for now; Task 16 fills them), `app/Resources/Content/profanity.txt`
- Test: `Tests/NallaCoreTests/ContentTests.swift`, `TextMatchTests.swift`, `Fixtures.swift`

**Interfaces (Produces):**
```swift
struct Passage: Codable { var id: String; var text: String; var answers: [String]; var family: Bool }   // text has {1}…{3}
struct Scene: Codable { var id: String; var caption: String; var art: String; var image: String?; var banned: [String]; var family: Bool }
struct Question: Codable { var id: String; var text: String; var choices: [String]; var answer: Int; var family: Bool }
struct ContentLibrary: Sendable { var passages: [Passage]; var scenes: [Scene]; var questions: [Question]; var profanity: ProfanityFilter
  static func load(from dir: URL) throws -> ContentLibrary
  func validate() -> [String]                 // human-readable problems; empty = valid
  func pick<T>(_ kp: KeyPath<ContentLibrary,[T]>, familyOnly: Bool, used: inout Set<String>, rng: inout SplitMix64) -> T? }
struct ProfanityFilter: Sendable { init(words: [String]); func contains(_ text: String) -> Bool }   // word-boundary, folded
enum TextMatch { static func fold(_ s: String) -> String                       // lowercase, no diacritics/punctuation, single spaces
                 static func editDistance(_ a: String, _ b: String) -> Int
                 static func isTooClose(_ guess: String, to real: String) -> Bool   // fold-equal, distance ≤ 1, or equal after trimming plural s/es
                 static func isNearDuplicate(_ a: [String], _ b: [String]) -> Bool } // every field pair isTooClose
enum PassageText { static func segments(_ text: String) -> [Segment] }   // Segment: Codable enum .text(String) | .blank(Int)
```
- [ ] **Step 1: Write failing tests**
  - `test_tooClose`:
    - "Banana" vs "banana" → true;
    - "café" vs "cafe" → true;
    - "laundromat" vs "laundromats" → true;
    - "boxes" vs "box" → true;
    - "cat" vs "cut" → true;
    - "cat" vs "dog" → false;
    - "haunted laundromat" vs "laundromat" → false.
  - `test_nearDuplicate`: ["Pickled eggs"] vs ["pickled egg"] → true; a two-field pair where only one field matches → false.
  - `test_profanity`: "what the shit" → true; "Scunthorpe" → false (word-boundary).
  - `test_segments`: "A {1} in a {2}." → [.text("A "), .blank(1), .text(" in a "), .blank(2), .text(".")].
  - `test_pickWithoutRepeats`: with 3 passages, 3 picks return 3 distinct ids, the 4th returns nil, and `familyOnly` skips `family:false` items.
  - `test_bundledContentValid`: `ContentLibrary.load(from: <repo>/app/Resources/Content)` (path from `#filePath`) gives `validate() == []`. Validation checks:
    - unique ids;
    - blank count == answers count, 1–3 blanks;
    - every answer ≤ 24 graphemes;
    - 4 choices with answer 0–3;
    - captions ≤ 48 characters;
    - non-empty art.
- [ ] **Step 2:** Run `swift test --filter "ContentTests|TextMatchTests"`. Expected: FAIL.
- [ ] **Step 3:** Implement. Write 6 starter items per pack in the copy voice (UI/UX §10), all `family:true` except one passage and one question. `profanity.txt` is one lowercase word per line, about 150 common English profanities and slurs.
- [ ] **Step 4:** Run the same command. Expected: PASS.
- [ ] **Step 5:** Commit `feat(core): content packs, profanity filter, text matching`.

---

### Task 4: Room engine and room views

**Files:**
- Create: `Sources/NallaCore/Engine/Engine.swift`, `GameRules.swift`, `RoomViews.swift`, `Results.swift`
- Create (debug only): `Sources/NallaCore/Engine/TestGame.swift`: an internal 2-phase fake game (one input phase of 10 s, one fixed phase of 5 s) inside `#if DEBUG`, reached through `GameID.test` and `GameSession.test`, also `#if DEBUG`. The picker never lists it. Tests in both packages use it via `@testable import NallaCore`.
- Test: `Tests/NallaCoreTests/EngineRoomTests.swift`, `RoomViewTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 2–3.
- Produces:
```swift
struct RoomState: Equatable, Sendable { var code: String; var players: [Player]; var leaderId: PlayerID?; var nextId = 1
  var phase: RoomPhase; var settings: RoomSettings; var preview: GameID?; var pause: Pause?; var rng: SplitMix64
  var used: Set<String>; var openedAt: Double; var toast: Toast?; var face: FaceCue
  static func new(code: String, seed: UInt64, now: Double) -> RoomState }
enum RoomPhase: Equatable, Sendable { case lobby, picker, settings(GameID), howTo(GameID, until: Double), playing(GameSession), results(GameResults) }
enum GameSession: Equatable, Sendable { case redacted(RedactedState), sketch(SketchState), insider(InsiderState), test(TestGameState) }
enum HostAction: Sendable { case pause, resume, skip, removePlayer(PlayerID), setFamilyFriendly(Bool), setVoice(Bool), endSession }
enum Event: Sendable { case join(ConnectionID, JoinRequest, newToken: String, ip: String), reserveHostSeat(name: String, colour: PlayerColour, token: String),
                       message(PlayerID, id: String, ClientMessage), disconnected(PlayerID), tick, host(HostAction) }
enum Effect: Equatable, Sendable { case reply(ConnectionID, ServerMessage), bind(ConnectionID, PlayerID), send(PlayerID, ServerMessage),
                                   speak(String), closeRoom }
enum Engine { static func reduce(_ s: RoomState, _ e: Event, now: Double, content: ContentLibrary) -> (RoomState, [Effect])
              static func nextWake(_ s: RoomState) -> Double?                 // earliest deadline / handoff / toast expiry; nil when paused
              static func playerView(_ s: RoomState, _ id: PlayerID, now: Double) -> ScreenView
              static func tvView(_ s: RoomState, now: Double) -> TVView }
protocol GameRules { associatedtype State: Equatable & Sendable
  static var game: GameID { get }; static var minPlayers: Int { get }; static var rounds: (range: ClosedRange<Int>, default: Int)? { get }
  static var card: GameCard { get }; static var howTo: [HowToStep] { get }
  static func start(_ ctx: inout GameContext) -> State
  static func handle(_ st: inout State, _ m: ClientMessage, from: PlayerID, _ ctx: inout GameContext) -> GameReply   // .ok | .ignored | .error(ErrorCode, String, field: Int?)
  static func advance(_ st: inout State, _ ctx: inout GameContext)       // deadline passed, all inputs in, or leader skip
  static func allInputsIn(_ st: State, connected: Set<PlayerID>) -> Bool
  static func deadline(_ st: State) -> Double?
  static func shift(_ st: inout State, by: Double)                       // resume after pause
  static func isOver(_ st: State) -> Bool
  static func results(_ st: State, players: [Player]) -> GameResults
  static func playerView(_ st: State, for: PlayerID, _ ctx: GameContext) -> ScreenView
  static func tvView(_ st: State, _ ctx: GameContext) -> (ScreenView, FaceCue)
  static func job(for: PlayerID, _ st: State) -> JobData }               // P7 during how-to
struct GameContext { var players: [Player]; var settings: RoomSettings; var now: Double; var rng: SplitMix64; var content: ContentLibrary
  var used: Set<String>; var speech: [String]
  func duration(_ base: Double, input: Bool) -> Double?   // nil when input && timer == .off
  mutating func speak(_ line: String) }
struct GameCard: Codable { var id: GameID; var name: String; var players: String; var length: String; var tagline: String; var colour: PlayerColour; var icon: String }
struct HowToStep: Codable { var icon: String; var title: String; var text: String }
struct JobData: Codable { var label: String; var icon: String; var job: String }
struct Standing: Codable { var player: PlayerSummary; var rank: Int; var points: Int; var delta: Int }
struct Award: Codable { var title: String; var player: PlayerSummary; var note: String }
struct GameResults: Codable, Equatable, Sendable { var game: GameID; var standings: [Standing]; var awards: [Award]; var rounds: Int }
```
Room screen data (`ScreenView.data`, read by the controller in Task 7 and the TV in Task 8). Each is a public Codable struct in `RoomViews.swift`: `LobbyData` (T1/T2/P3/P4), `PickerData` (T4/P5), `SettingsData` (T5/P6), `HowToData` (T6), `JobData` (P7), `LateJoinData` (P2), `WaitingData` (P8), `PausedData` (P10), `ResultsData` (T10) and `PhoneResultsData` (P12):
- **T1/T2 (lobby):** `{code, joinURL?, players, leaderName?, seats:8}`. `joinURL` is filled by the hub. T1 shows with 0 players, T2 with ≥ 1, and T3 replaces T1 after 60 s with 0 players.
- **P3/P4 (phone lobby):** `{players, leaderName, canStart, startBlockedReason?}`. P4 for the leader, P3 for others. The reason is "Need 3 players to start" under 3 players.
- **T4/P5 (picker):** `{games:[GameCard], preview?: GameID, playerCount}`.
- **T5/P6 (settings):** `{game: GameCard, rounds?, roundsLabel, roundsRange?, timer, familyFriendly, bannedWords?, canStart, startBlockedReason?}`.
  - `roundsLabel`: Redacted "3 + final", Sketch "1 per player", Insider "6 rounds".
  - The blocked reason is "Insider Trading needs 4 players".
- **T6/P7 (how-to):** T6 `{game: GameCard, steps:[HowToStep]}` for 15 s; phones get P7 = `JobData`.
- **P2 (late joiner):** `{reason:"in-progress", game}` for `waitingForNextGame` players.
- **P8 (waiting):** `{top, title, waitingOn:[PlayerSummary]}`, built by games.
- **P10 (paused):** `{top, by}` replaces every phone screen while paused. On TV, pause is `overlays.paused`.
- **T10/P12 (results):** T10 `{game: GameCard, podium:[Standing], awards:[Award], standings}`; P12 `{gameName, rank, points, line, award?}`.

- [ ] **Step 1: Write failing tests**, all through `Engine.reduce` with a `now` you advance by hand:
  - `test_joinAndErrors`:
    - a first join → `.bind` + `.reply(welcome)`, the player is leader, and their view is P4;
    - a wrong code → `wrong_code`;
    - a duplicate "priya" → `name_taken`;
    - a taken colour → `colour_taken`;
    - a 9th player → `room_full`;
    - a profane name with family-friendly on → `name_invalid`.
  - `test_rejoinWithSeatToken`: a disconnected player rejoins with their token and gets the same PlayerID and `connected == true`; another player's token joining under a different name gets the original seat and name.
  - `test_lateJoinerWaits`: joining during `.playing` → P2 `in-progress`; at `play_again` they are in the game.
  - `test_leaderOnly`: a non-leader `leader(.start)` → `not_leader`.
  - `test_passLeader`: `leader(.passLeader(3))` makes player 3 leader, and the T9 toast is "<name> is now the leader".
  - `test_startFlow`:
    - `previewGame(.insider)` sets `preview` (T4 highlights it);
    - `pickGame(.redacted)` → `.settings`;
    - `start` with 2 players → `not_allowed`;
    - with 3 players → `.howTo(until: now+15)`;
    - a tick at +15 → `.playing`.
  - `test_insiderNeedsFour`: the settings view for Insider with 3 players has `canStart == false` and reason "Insider Trading needs 4 players".
  - `test_settingsPatchClamped`: Insider rounds 9 → 8; Redacted rounds 1 → 2; Sketch rounds are ignored.
  - `test_pauseFreezesDeadlines`: in TestGame with a deadline at +10, pause at +4 and resume at +100 → deadline +106; `nextWake` is nil while paused; phones see P10 with `by` = the leader's name.
  - `test_leaderHandoffAfter30s`: the leader disconnects at t; at t+29 they are still leader; at t+30 the next-joined connected player is leader, the toast is "Sam is now the leader", and the toast expires after 4 s.
  - `test_leaderHandoffWhilePaused`: same as above while paused.
  - `test_leaderRemovedPassesImmediately`: `host(.removePlayer(leader))` → new leader now, and the removed player gets `.send(id, .removed(.byHost))`.
  - `test_staleRoundInputIgnored`: TestGame round 2 receives `castVote(round:1…)` → reply `ack`, state unchanged.
  - `test_endAndPlayAgain`: `leader(.end)` → `.results` with T10/P12 data; `playAgain` → `.howTo(same game)` with scores reset; `newGame` → `.picker`.
  - `test_endSession`: `host(.endSession)` → results shown on the TV, `.removed(.sessionEnded)` to every player, and `.closeRoom`.
  - `test_hostSeat`: `reserveHostSeat` creates player 1 with `isHost`, leader, and disconnected; a join with that token connects them; a guest who joined earlier is not leader.
  - `test_tvLobbyHelpAfter60s`: no players at +59 → T1; at +60 → T3.
  - `test_faceCaptionsShort`: every room TV view's caption is ≤ 48 characters.
- [ ] **Step 2:** Run `swift test --filter "EngineRoomTests|RoomViewTests"`. Expected: FAIL.
- [ ] **Step 3:** Implement `Engine`, room views and `Results` (ranking: ties share a rank and are ordered by join order). Dispatch from `GameSession` to the matching `GameRules` type with a `switch`. After every reduce, the engine calls `advance` while the current game's `allInputsIn` holds or its deadline has passed. Room face cues and copy come from `pages_tv.py` T1–T10.
- [ ] **Step 4:** Run the same command. Expected: PASS.
- [ ] **Step 5:** Commit `feat(core): room engine, leader rules, pause, room views`.

---

### Task 5: HTTP static server, LAN address, rate limiter

**Files:**
- Create: `Packages/NallaServer/Sources/NallaServer/HTTP.swift`, `HTTPServer.swift`, `LANAddress.swift`, `RateLimiter.swift`
- Test: `Tests/NallaServerTests/HTTPTests.swift`

**Interfaces (Produces):**
```swift
struct HTTPRequest: Equatable { var method: String; var path: String; var query: [String: String]
  static func parse(_ head: Data) -> HTTPRequest? }                       // nil on malformed or > 8 KB
struct HTTPResponse { var status: Int; var headers: [(String, String)]; var body: Data; func serialized() -> Data }
enum StaticFiles { static func response(for req: HTTPRequest, root: URL) -> HTTPResponse }   // GET only, "/"→index.html, no "..", 404/405
final class HTTPServer: @unchecked Sendable {                             // all state on one serial DispatchQueue
  init(root: URL, bonjourName: String?)
  func start(ports: ClosedRange<UInt16>) async throws -> UInt16            // first free port
  func stop() }
enum LANAddress { static func current() -> String?
                  static func pick(_ candidates: [(name: String, address: String)]) -> String? }   // en0 > en1 > other; IPv4; no 127/169.254
struct JoinRateLimiter { init(limit: Int = 10, window: Double = 60); mutating func allow(ip: String, now: Double) -> Bool }
```
- [ ] **Step 1: Write failing tests**
  - `test_parse`: `"GET /js/app.js?x=1 HTTP/1.1\r\nHost: a\r\n\r\n"` → path `/js/app.js`, query `["x":"1"]`; garbage → nil.
  - `test_staticFiles` against a temp dir:
    - `/` → 200 `text/html; charset=utf-8`;
    - `/shared/fonts/nunito-wght.woff2` → `font/woff2`;
    - `.js` → `text/javascript`;
    - `.svg` → `image/svg+xml`;
    - `/../etc/passwd` and `/%2e%2e/x` → 404;
    - a directory → 404;
    - `POST` → 405;
    - every response has `Cache-Control: no-store`.
  - `test_lanPick`:
    - [("lo0","127.0.0.1"),("en5","169.254.1.2"),("en1","10.0.0.4"),("en0","192.168.1.20")] → "192.168.1.20";
    - without en0 → "10.0.0.4";
    - empty → nil.
  - `test_rateLimiter`: 10 allows at t=0, the 11th is denied, and t=60.1 allows again.
  - `test_serverServesFilesAndFallsBack`: start on 18080…18089 → serves `/`; a second server on the same range gets 18081; fetch with `URLSession`.
- [ ] **Step 2:** Run `swift test --filter HTTPTests` in `Packages/NallaServer`. Expected: FAIL.
- [ ] **Step 3:** Implement. `NWListener(using: .tcp, on: port)` and on `.failed(.posix(.EADDRINUSE))` try the next port. Read until `\r\n\r\n`, respond with `Connection: close`, then cancel the connection. When `bonjourName` is set, use `listener.service = .init(name:, type: "_nallabox._tcp")`.
- [ ] **Step 4:** Run the same command. Expected: PASS.
- [ ] **Step 5:** Commit `feat(server): static HTTP server, LAN address, join rate limiter`.

---

### Task 6: WebSocket server, hub and room server

**Files:**
- Create: `Sources/NallaServer/WebSocketServer.swift`, `Hub.swift`, `HubClock.swift`, `RoomServer.swift`, `Sources/NallaDevServer/main.swift`
- Test: `Tests/NallaServerTests/HubTests.swift`, `SocketTests.swift`, `TestClient.swift`

**Interfaces:**
- Consumes: `Engine`, `Wire`, `ContentLibrary` (Tasks 2–4); `HTTPServer`, `JoinRateLimiter`, `LANAddress` (Task 5).
- Produces:
```swift
protocol HubClock: Sendable { func now() -> Double; func sleep(until: Double) async throws }
struct SystemClock: HubClock                                    // Date().timeIntervalSince1970
final class ManualClock: HubClock, @unchecked Sendable { init(start: Double = 1_000_000); func advance(by: Double) async }  // resumes due sleepers
struct RoomEndpoint: Sendable, Equatable { var code: String; var ip: String; var httpPort: UInt16; var wsPort: UInt16; var joinURL: String
  func localControllerURL(seatToken: String) -> String }        // http://127.0.0.1:<port>/?room=..&ws=..&seat=<token>
enum HubEvent: Sendable { case snapshot(TVView), speak(String), roomClosed }
actor Hub { init(content: ContentLibrary, clock: any HubClock, seed: UInt64, code: String? = nil, tokens: @escaping @Sendable () -> String)
  func setJoinURL(_ url: String)
  func opened(_ c: ConnectionID, ip: String, send: @escaping @Sendable (String) -> Void, close: @escaping @Sendable () -> Void)
  func received(_ text: String, from c: ConnectionID)
  func closed(_ c: ConnectionID)
  func host(_ a: HostAction)
  func reserveHostSeat(name: String, colour: PlayerColour) -> String     // returns seat token
  func events() -> AsyncStream<HubEvent>
  var code: String { get } }
final class WebSocketServer: @unchecked Sendable { init(); func start(port: UInt16) async throws
  var events: AsyncStream<WSEvent> { get } ; func stop() }          // WSEvent: .open(ConnectionID, ip, send, close) | .text(ConnectionID, String) | .close(ConnectionID)
final class RoomServer: Sendable { init(controllerRoot: URL, content: ContentLibrary, clock: any HubClock = SystemClock())
  func start(ports: ClosedRange<UInt16> = 8080...8089) async throws -> RoomEndpoint
  var hub: Hub { get }; func stop() async }
```
How the hub works:
- **Ordering:** one consumer loop reads `WebSocketServer.events` in order and `await`s the hub once per event, so a connection's messages are never reordered.
- **Views:** after every reduce the hub builds every connected player's `PlayerView` and sends only those that changed, each with a version counter that rises for every send.
- **TV snapshot:** it also emits `.snapshot` when the TV view changed.
- **Timer:** one `Task` sleeps until `Engine.nextWake`, then feeds `.tick`; it is cancelled and re-armed whenever the wake time changes.
- **Ping:** `ping` is answered by the hub directly with `pong(t, hostTime: clock.now())`.
- **Join attempts:** `received` on an unbound connection accepts only `join`, after checking `JoinRateLimiter`.
- **Seat replacement:** if a join binds a seat that already has a live connection, the old one gets `removed(.replaced)` and is closed.
- **Frame size:** `NWProtocolWebSocket.Options.maximumMessageSize = 65_536` with `autoReplyPing = true`. A larger frame fails that connection only, which maps to `.close`.

- [ ] **Step 1: Write failing tests.**
  - **HubTests** (hub direct, `ManualClock`, fake `send` closures collecting strings):
    - `test_joinGetsWelcomeThenView`: the first message is `welcome`, then a `view` with screen P4 and version 1.
    - `test_notJoinedRejected`: `submit_text` before `join` → `error not_joined`.
    - `test_versionsIncrease`: versions rise 1, 2, 3 across changes, and an unchanged view is not resent.
    - `test_secondConnectionTakesSeat`: the second connection with the same seat token binds; the first receives `{"type":"removed","reason":"replaced"}`; still 1 player.
    - `test_malformedMessages`: `"{"`, `{"v":1,"type":"nope","id":"1"}` and `{"v":9,...}` each → `error`, and the connection is still bound afterwards.
    - `test_rateLimitedJoins`: the 11th join from IP "10.0.0.9" within 60 s → `rate_limited`.
    - `test_timerTicks`: TestGame deadline at +10; `clock.advance(by: 10)` → the next view shows the next phase.
    - `test_snapshotsStream`: a join produces a `.snapshot` whose `screen.screen == "T2"`.
  - **SocketTests** (real sockets on 127.0.0.1, ports 19080…19089, `TestClient` built on `URLSessionWebSocketTask`):
    - `test_endToEndJoin`: GET `/` returns the controller's `index.html`; the WebSocket join returns `welcome` + `view`.
    - `test_oversizedFrameClosesOnlyThatClient`: a 2 MB frame from client A closes A, and client B still receives views.
    - `test_endpointURL`: `joinURL == "http://<ip>:<port>/?room=<code>&ws=<port+1>"`.
- [ ] **Step 2:** Run `swift test --filter "HubTests|SocketTests"`. Expected: FAIL.
- [ ] **Step 3:** Implement. `NallaDevServer`:
  - **Arguments:** `--controller`, `--content` and `--seed`; defaults resolve to `app/Resources/...` from `#filePath`.
  - **Output:** prints the join URL, then each TV screen ID, its face caption and the voice lines as they change.
  - **Keyboard:** `p` = pause/resume, `s` = skip, `q` = quit.
- [ ] **Step 4:** Run the same command. Expected: PASS. Also run `swift run NallaDevServer` and expect a printed `http://…/?room=XXXX&ws=8081`.
- [ ] **Step 5:** Commit `feat(server): websocket hub, room server, dev server`.

---

### Task 7: Phone controller shell (P1–P13)

**Files:**
- Create: `app/Resources/Controller/index.html`, `controller.css`, `shared/*` (byte copies of `design/mockups/shared/{tokens,base,components}.css`, `fonts/nunito-wght.woff2`, `img/nallabox-symbol-color.svg`), `js/net.js`, `js/drafts.js`, `js/hold.js`, `js/app.js`, `js/render/kit.js`, `js/render/room.js`, `js/render/index.js`
- Test: `tests/controller/css-sync.test.mjs`, `net.test.mjs`, `drafts.test.mjs`, `render-room.test.mjs`, `fixtures.mjs`

**Interfaces:**
- Consumes: wire format and room screen data (Tasks 2, 4).
- Produces:
```js
// render/kit.js (ports of design/mockups/_build/kit.py, same class names)
export const esc, avatar(player, size), chip(player, ...mods), btn(label, {kind, act, disabledReason, args}), phoneAction(...btns),
             phoneTop(title, sub, {leader}), leaderboard(rows, meId), timer(deadline) ;
// render/index.js
export function render(view, ui) -> string      // dispatches on view.screen; ui = {offset, drafts, sheet, localScreen}
export const screens = { P3, P4, ... }           // game modules register their screen ids here (Tasks 10, 12, 14)
export function registerScreens(map)
// net.js
export function backoff(attempt) -> ms           // 500, 1000, 2000, 4000, 8000, 8000…
export function clockOffset(t0, t1, hostTime) -> seconds   // hostTime - (t0+t1)/2/1000
export function connect({url, onMessage, onState}) -> {send(type, fields) -> id, close()}   // reconnects with backoff
// drafts.js
export function saveDraft(key, value); export function loadDraft(key); export function clearDraft(key)   // localStorage, key = screen+round
```
Behaviour of the controller:
- **Join (P1):** shown locally before any `welcome`. The room code comes from `?room` and the name from `localStorage` when known. The seat token is stored in `localStorage` under `nb.seat.<room>`.
- **Host phone:** with `?seat=<token>` the controller joins at once with that token. This is the iPhone host's own controller.
- **Join errors (P2):** each `error` code from a join renders its mockup state, keyed by code: `wrong_code` → wrong-code, `room_full` → room-full, `name_taken` → name-taken.
- **Reconnecting (P9):** shown on socket loss, keeping the last view underneath. It turns into the failed state after 6 attempts.
- **Removed (P11):** shown on `removed`. For `session_ended` the copy is "The host ended the session".
- **Leader sheet (P13):** the leader pill (from `phoneTop(..., {leader:true})`) opens P13 as a local overlay. Remove and End go through the confirm states, as in the mockup.
- **Actions:** every action button carries `data-act` and optional `data-args` JSON, and `app.js` maps them to messages through event delegation.
- **Timer:** the countdown is drawn from `deadline` with the clock offset, updating each second without re-rendering the screen.
- **Wake Lock:** `navigator.wakeLock.request('screen')` when the view is not a lobby screen, re-acquired on `visibilitychange`.
- **Text size:** `--nb-text-scale` comes from `matchMedia` for larger text where supported.

- [ ] **Step 1: Write failing tests**
  - `css-sync`: each `app/Resources/Controller/shared/*.css` and the font are byte-equal to `design/mockups/shared/`.
  - `net`: `backoff(0..6)` equals `[500,1000,2000,4000,8000,8000,8000]`; `clockOffset(1000, 1200, 5.0) == 3.9`.
  - `drafts`: save, load and clear with a stub `localStorage`.
  - `render-room`, using fixtures from `fixtures.mjs` that mirror the Task 4 data:
    - P4 has exactly one `.btn--primary` with the text "Choose game", plus the leader pill;
    - P4 with `canStart:false` shows the reason text;
    - P3 has no leader pill;
    - P5 lists 3 `.game-row` items, and the preview one is `.is-selected`;
    - P6 for Insider with 3 players disables Start with "Insider Trading needs 4 players";
    - P10 contains "Paused by Priya";
    - P12 for the leader has "Play again" and "New game";
    - every rendered string escapes `<script>` in names.
- [ ] **Step 2:** Run `node --test tests/controller/`. Expected: FAIL.
- [ ] **Step 3:** Implement and port P1–P13 from `pages_phone.py`. `hold.js` exports `bindHoldCards(root)` with the frame.js behaviour: 300 ms hold, pointer-capture release, Space/Enter held, and hide on blur/leave.
- [ ] **Step 4:** Run `node --test tests/controller/`. Expected: PASS. Then run `swift run NallaDevServer`, open the join URL in the browser pane in 3 tabs at 393×852, and check:
  - join, P3/P4 and leader pill → P13;
  - pick a game → settings;
  - close a tab → it reconnects on reopen;
  - screenshots match `design/mockups/_shots/phone/P3`, `P4` and `P6` by eye.
- [ ] **Step 5:** Commit `feat(controller): phone shell, networking, room screens`.

---

### Task 8: Host shared layer: TV renderer, face, voice, QR, host model

**Files:**
- Create: `app/Shared/HostModel.swift`, `HostPrefs.swift`, `HostVoice.swift`, `QRCode.swift`, `NetworkSelfTest.swift`, `TV/TVCanvas.swift`, `TV/TVRootView.swift`, `TV/TVComponents.swift`, `TV/RoomScreens.swift`, `Face/FaceCorner.swift`
- Test: `Packages/NallaServer/Tests/NallaServerTests/TVPayloadTests.swift` (the payload decoding the TV relies on); visual check by running the Mac app.

**Interfaces:**
- Consumes: `RoomServer`, `Hub`, `HubEvent`, `TVView`, `RoomEndpoint` (Task 6); room screen data (Task 4).
- Produces:
```swift
@MainActor @Observable final class HostModel {
  var endpoint: RoomEndpoint?; var tv: TVView?; var hostSeatToken: String?; var lastError: String?
  var prefs: HostPrefs                                         // M5 settings, persisted in UserDefaults
  func startRoom() async                                       // loads Content + Controller from Bundle.main, starts RoomServer
  func stopRoom() async
  func send(_ a: HostAction)
  func reserveHostSeat(name: String, colour: PlayerColour) async }
struct HostPrefs: Codable { var familyFriendly = true; var timer: TimerSpeed = .x1; var voiceOn = true; var largeCaptions = false }
@MainActor final class HostVoice { func speak(_ line: String); func stop() }   // AVSpeechSynthesizer, queued, skipped when voiceOn == false
enum QRCode { static func image(for text: String, scale: CGFloat) -> CGImage? }  // CIQRCodeGenerator, correction "M", no interpolation
enum NetworkSelfTest { static func run(_ url: URL) async -> Bool }              // GET the LAN join URL with a 3 s timeout
struct TVCanvas<Content: View>: View { init(@ViewBuilder content: () -> Content) }   // 1920×1080 scaled to fit, letterboxed in NB.Palette.ink
struct TVRootView: View { let tv: TVView; let qr: CGImage? }   // switches on tv.screen.screen; draws the overlays (T7 dim + card, T8 banners, T9 toast)
struct FaceCorner: View { let cue: FaceCue }                    // 160 pt face + one-line caption bubble, 180 ms squash on change, fade under Reduce Motion
// TVComponents: TVAvatar, TVChip, TVTimer(deadline:), TVLeaderboard(standings:), TVTop(left:right:), TVSafe
```
- [ ] **Step 1: Write failing test** `test_roomScreensDecode`: a scripted hub session produces TV snapshots for T1, T2, T4, T5, T6 and T10. Each `screen.data` decodes into the Codable payload structs that `RoomScreens.swift` uses. Those are the Task 4 payload structs (`LobbyData`, `PickerData`, `SettingsData`, `HowToData`, `ResultsData`); the test also asserts `TVView.room.code` matches the endpoint and `screen.deadline` is set on T6.
- [ ] **Step 2:** Run `swift test --filter TVPayloadTests`. This is a contract test on Tasks 4 and 6, so it may pass at once. It also asserts `LobbyData.joinURL == RoomEndpoint.joinURL`. Any failure names a field the TV needs; fix it in `RoomViews`/`Hub` before Step 3.
- [ ] **Step 3:** Implement. The TV screens T1–T10 port `pages_tv.py` layout values (sizes, gaps, safe area) using `NB` tokens. `HostModel` consumes `hub.events()` on the main actor: `.snapshot` sets `tv`, `.speak` goes to `HostVoice`, and `.roomClosed` stops the room. Prefs changes call `send(.setFamilyFriendly)` / `send(.setVoice)`.
- [ ] **Step 4:** Run the test (expected PASS) and build both schemes with 0 warnings (the Task 1 Step 7 commands).
- [ ] **Step 5:** Commit `feat(app): TV renderer, face, voice, QR, host model`.

---

### Task 9: Mac host (M1–M5) and iPhone host (H1–H8)

**Files:**
- Create: `app/macOS/NallaBoxMacApp.swift` (replace placeholder), `DisplayPicker.swift`, `TVWindowController.swift`, `M1StartView.swift`, `M2RoomView.swift`, `M4NetworkPanel.swift`, `M5SettingsSheet.swift`; `app/iOS/NallaBoxApp.swift` (replace), `ExternalDisplay.swift`, `LocalNetwork.swift`, `RoutePicker.swift`, `ControllerWebView.swift`, `Flow/H1Welcome.swift`, `H2LocalNetwork.swift`, `H3ConnectTV.swift`, `H4Name.swift`, `H5LiveRoom.swift`, `H6HostMenu.swift`, `H7TVDisconnected.swift`, `H8LeavingAlert.swift`
- Test: manual run (below), plus 0-warning builds.

**Interfaces:**
- Consumes: `HostModel`, `TVRootView`, `TVCanvas`, `QRCode`, `NetworkSelfTest` (Task 8); `RoomEndpoint.localControllerURL` (Task 6).
- Produces:
```swift
// macOS
enum DisplayChoice: Hashable { case screen(CGDirectDisplayID), thisWindow }
final class TVWindowController { init(model: HostModel); func show(on: DisplayChoice); func close() }   // borderless, full-screen frame of the NSScreen
// iOS
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate          // hosts TVRootView via UIHostingController
@MainActor @Observable final class ExternalDisplay { static let shared; var isConnected: Bool; var name: String? }
@MainActor final class LocalNetwork { func request() async -> LocalNetworkStatus }    // .granted | .denied; NWBrowser on _nallabox._tcp, denied = .waiting(.dns(kDNSServiceErr_PolicyDenied))
struct RoutePicker: UIViewRepresentable                                               // AVRoutePickerView, tinted coral
struct ControllerWebView: UIViewRepresentable { let url: URL }                        // WKWebView, inline media, no zoom, ink background
```
Behaviour (copy and layout from `pages_host_mac.py` and `pages_host_iphone.py`):
- **Mac M1:**
  - Logo, the Local Network status and a "Show game on" list with each `NSScreen.localizedName` plus "This window".
  - **Start room** starts the room and shows M2, and the TV window appears on the chosen screen.
- **Mac M2:**
  - A 360 pt column with the code, QR, players (each with a remove button that confirms first) and network health; the live preview (a second `TVRootView`) sits on the right.
  - The toolbar holds Pause/Resume, Skip, End (with confirm) and Settings (M5 sheet).
  - M4 shows inline when `NetworkSelfTest` fails or there are 0 players after 60 s, with the checklist and **Copy join link**.
- **Mac single display ("This window"):** the room window goes full screen showing the TV and a top-edge bar when the pointer is within 8 pt of the top. Esc pauses and returns to M2.
- **iPhone first-run order (H1–H4):**
  - H1 is shown once (`@AppStorage("onboarded")`).
  - H2 calls `LocalNetwork.request()`, which starts the room first so the prompt appears; on denied it shows the denied state with **Open Settings** (`UIApplication.openSettingsURLString`).
  - H3: Continue is enabled when `ExternalDisplay.isConnected`.
  - H4 ends by calling `reserveHostSeat` and going to H5.
- **iPhone live room (H5/H6):**
  - H5 is the host strip (code, "N players · <display name>", Pause, •••) over a `ControllerWebView(localControllerURL(seatToken:))`.
  - H6 is a `.sheet` with the menu, remove and end confirms.
- **iPhone interruptions (H7/H8):**
  - H7 appears when the external display disconnects mid-room; it pauses the game.
  - H8: `scenePhase == .background` pauses the game, and the alert shows on return.
  - `isIdleTimerDisabled = true` while a room runs.

- [ ] **Step 1:** Implement the Mac app.
- [ ] **Step 2:** Build the Mac app and run it:
  - Build with 0 warnings.
  - Start a room on "This window" and join from 3 browser-pane tabs using the printed URL.
  - Expect T2 with 3 seats. Pick Redacted on the leader tab and expect the TV to show T4 → T5 live.
  - Compare against `_shots/host-mac/M2*.png` by eye.
- [ ] **Step 3:** Implement the iPhone app.
- [ ] **Step 4:** Build for the iPhone 17 Pro simulator with 0 warnings and run it:
  - Launch, then attach the simulator panel.
  - Go through H1 → H2 (allow) → H3. The simulator has no AirPlay, so enable an external display with **I/O › External Displays**; expect Continue to enable.
  - Then H4 → H5. Expect the embedded controller to show P4 with the leader pill.
  - Join one browser tab to the simulator's printed URL; expect its seat on the external display.
  - Background the app and return; expect H8.
- [ ] **Step 5:** Commit `feat(app): Mac and iPhone host flows`.

---

### Task 10: Redacted end to end

**Files:**
- Create: `Sources/NallaCore/Games/Redacted.swift`, `RedactedViews.swift`; `app/Resources/Controller/js/render/redacted.js`; `app/Shared/TV/RedactedScreens.swift`
- Test: `Tests/NallaCoreTests/RedactedTests.swift`; `tests/controller/render-redacted.test.mjs`; `Packages/NallaServer/Tests/NallaServerTests/ScriptedGameTests.swift` (`test_redactedFullGame`)

**Interfaces:**
- Consumes: `GameRules`, `GameContext`, `TextMatch`, `PassageText`, `ContentLibrary.pick` (Tasks 3–4); `registerScreens`, kit (Task 7); TV components (Task 8).
- Produces: `enum Redacted: GameRules` and `struct RedactedState`. Screen data:
  - **R1 (write):**
    - TV: `{top, passage:[Segment], waitingOn}`.
    - Phone: `{top, blanks, fields?}`. A player who has submitted gets P8 instead. Inline errors come from `error.field`.
  - **R2 (read-out):** TV `{passage, versions:[Version], current}`; phone `{count, current}`.
  - **R3 (vote):**
    - TV: `{passage, versions, waitingOn}`.
    - Phone: `{passage, versions:[Version & {mine}], vote?}`.
  - **R4 (reveal):**
    - TV: `{passage, versions:[Version & {real, authors, fooled}]}`.
    - Phone: `{myFills?, fooled, foundReal, points}`.
  - **R5 (scores):** TV `{top, standings}`; phone `{rank, points, delta, behind?}`.
  - `Version = {number, fills:[String]}`.

Rules:
- **Rounds:** `settings.rounds` normal rounds (2–5, default 3) plus a final round whose points are ×3. Labels read "Round n of N" and "Final round · points ×3".
- **Phases:**
  - write: 60 s, input;
  - read-out: per version `max(3, words/2.6+1)` s, or 4 s with the voice off; the engine speaks each version;
  - vote: 30 s, input;
  - reveal: 10 s;
  - scores: 6 s.
- **Submissions:**
  - Each fill is trimmed, 1–24 graphemes, not `isTooClose` to that blank's real answer (error `too_close`, "Too close to the real word, try another", with the field number), and must not contain profanity when family-friendly is on (error `not_allowed`, "Let's keep it friendly. Try another").
  - Resubmitting before the deadline replaces the old answer ("Change my answer" on P8).
- **Versions:**
  - The versions are the real one plus every submitted fake, with near-duplicate fakes merged into one version with several authors.
  - Order is shuffled with `ctx.rng`, and the numbers start at 1.
  - Votes: a player cannot vote for a version they wrote (`not_allowed`); `castVote.choice` is the version number.
- **Scoring:**
  - A fake earns 500 × voters fooled × multiplier, split equally among its authors and rounded down to a multiple of 10.
  - Voting for the real one earns 1,000 × multiplier.
- **Awards:** "Best Liar" (most players fooled, note "fooled N players") and "Sharpest Eye" (found the real text most often, note "found the real text N times"). P12 gives rank 1 "Top score" if they have no other award.

- [ ] **Step 1: Write failing core tests**
  - `test_tooCloseRejectedWithField`: real answer "laundromat"; submitting ["Laundromats"] → `.error(.tooClose, …, field: 1)`.
  - `test_profanityOnlyWhenFamily`.
  - `test_mergeNearDuplicates`: fakes "pickled eggs" (A) and "Pickled egg" (B) merge into one version with 2 authors; 3 fooled players → A and B get 750 each.
  - `test_cannotVoteOwn`.
  - `test_scoring`: round 1, 1 fooled → author +500; finding the real one → +1,000; in the final round the same events give +1,500 and +3,000.
  - `test_earlyEndWhenAllIn`: when all connected players have submitted, the write phase advances before the deadline; a disconnected player is not waited for.
  - `test_readoutDurations`: a 13-word version with the voice on → 6.0 s; with the voice off → 4 s.
  - `test_timerOff`: `timer = .off` → write/vote `deadline == nil`, and `leader(.skip)` advances.
  - `test_staleVoteIgnored`.
  - `test_awards`: a fixture game yields "Best Liar" for the most-fooled author.
  - `test_fullGameRounds`: 3 + final → 4 rounds, then `.results`.
- [ ] **Step 2:** Run `swift test --filter RedactedTests` in NallaCore. Expected: FAIL. Implement `Redacted`/`RedactedViews`, porting TV and phone copy from `pages_redacted.py`, and run again. Expected: PASS.
- [ ] **Step 3: Write failing controller tests**
  - R1 renders one `.field__input` per blank with `maxlength="24"` and labels "Blank 1…".
  - An `error` with field 2 shows the inline message under field 2 and keeps the typed values (drafts).
  - R3 marks `mine` as greyed with "yours", and the voted tile has `.is-selected`.
  - The R4 "found-and-fooled" state shows both lines.
- [ ] **Step 4:** Run `node --test tests/controller/` (expect FAIL), implement `redacted.js` with R1 drafts saved on input, then run again. Expected: PASS.
- [ ] **Step 5: Write the failing scripted game** `test_redactedFullGame`:
  - 4 `TestClient`s over real sockets with a `ManualClock` play a whole game: join, pick, start, then each round submit/vote with scripted answers, advancing the clock.
  - Assert the final P12 ranks and points match a hand-computed table in the test.
  - Assert no client ever received another client's unrevealed fills before R2.
  - Run `swift test --filter test_redactedFullGame` (expect FAIL until it is wired through), then PASS.
- [ ] **Step 6:** Implement `RedactedScreens.swift` (R1–R5 from `pages_redacted.py`, with the current read-out version highlighted and the REAL flip in coral). Then:
  - Build the Mac app and play a full Redacted game with 3 browser tabs.
  - Compare TV and phone screens with `_shots/tv/R*.png` and `_shots/phone/R*.png`.
- [ ] **Step 7:** Commit `feat: Redacted end to end`.

---

### Task 11: Composite Sketch core rules

**Files:**
- Create: `Sources/NallaCore/Games/Sketch.swift`, `SketchViews.swift`
- Test: `Tests/NallaCoreTests/SketchTests.swift`

**Interfaces:**
- Produces: `enum Sketch: GameRules`, `struct SketchState`, and `SketchDrawing = {number, strokes:[Stroke], mine?}`. Screen data:
  - **C1 (briefing):**
    - TV: `{top, witness}`.
    - Witness phone (`C1-witness`): `{scene:{caption, art, image?}, banned?:[String]}`.
    - Artist phone (`C1-artist`): `{witnessName}`.
  - **C2 (describe & draw):**
    - TV: `{top, witness}`.
    - Witness phone (`C2-witness`): same data as C1-witness.
    - Artist phone (`C2-artist`): `{top, round}`, or P8 once final.
  - **C3 (line-up):**
    - TV: `{drawings}`, with no artists shown.
    - Witness phone (`C3-witness`): `{drawings, pick?}`.
    - Artist phone (`C3-artist`): `{number}`.
  - **C4 (scene reveal):**
    - TV: `{scene, picked:{drawing, artist}, artistPoints:1000, witnessPoints:500}`.
    - Phone: `{points, line}`.
  - **C5 (Most Wanted):** TV `{drawings, waitingOn}`; phone `{drawings (with mine), vote?}`.
  - **C6 (scores):** TV `{top, standings}`; phone `{rank, points, delta, behind?}`.

Rules:
- **Rounds:** one round per player in the game, with the Witness in join order.
- **Phases:**
  - brief: 5 s;
  - draw: 30 s, input; artists send `stroke_data` every 2 s and with `final:true` on submit; the last data received counts;
  - pick: 20 s, input, Witness only, `castVote.choice` = drawing number;
  - reveal: 8 s;
  - Most Wanted: 15 s, input, everyone except the drawing's artist;
  - scores: 6 s.
- **Drawings:** total points per drawing are capped at 2,000 (extra points dropped); colour indices must be 0–5 and sizes 0–2, or the stroke is dropped. Drawings with no strokes are left out of C3/C5, and numbers are shuffled per round.
- **Scoring:** the picked drawing's artist +1,000, and the Witness +500 if they picked before the deadline.
- **Awards:** "Most Wanted" (most worst-likeness votes over the game, note "N votes for worst likeness") and "Sharpest Pencil" (picked most often, note "picked N times").
- **Banned words:** with `bannedWords` on, the Witness sees the scene's `banned` list.

- [ ] **Step 1: Write failing tests**
  - `test_witnessRotates`: 4 players → 4 rounds with Witnesses 1, 2, 3, 4.
  - `test_sceneOnlyInWitnessView`: during C1–C3, no view except the Witness's (all players' and the TV's, JSON-encoded) contains the scene caption or art; the C4 TV view does.
  - `test_strokePointCap`: 5,000 points → 2,000 stored; a stroke with colour 9 is dropped.
  - `test_witnessOnlyPicks`: an artist's `castVote` during the pick → `not_allowed`.
  - `test_scoring`.
  - `test_mostWantedNotOwn`.
  - `test_emptyDrawingsExcluded`.
  - `test_awards`.
  - `test_bannedWordsSetting`.
- [ ] **Step 2:** Run `swift test --filter SketchTests`. Expected: FAIL. Implement it, with copy from `pages_sketch.py`, and run again. Expected: PASS.
- [ ] **Step 3:** Commit `feat(core): Composite Sketch rules`.

---

### Task 12: Composite Sketch controller, TV and scripted game

**Files:**
- Create: `app/Resources/Controller/js/canvas.js`, `js/render/sketch.js`; `app/Shared/TV/StrokeCanvas.swift`, `TV/SketchScreens.swift`
- Test: `tests/controller/canvas.test.mjs`, `render-sketch.test.mjs`; `ScriptedGameTests.test_sketchFullGame`

**Interfaces:**
- Consumes: Sketch screen data (Task 11); `hold.js`, kit (Task 7).
- Produces:
```js
// canvas.js
export const COLOURS = [/* 6 hex values from the C2 mockup palette */], SIZES = [/* 3 widths in canvas units from the mockup */];
export function createDrawing() -> { strokes, begin(x, y, c, s), extend(x, y), end(), undo(), clear(), pointCount() }   // pure, 0…1 coords, stops adding at 2,000 points
export function strokesToSVG(strokes, size) -> string     // thumbnails in C3/C5 (phone)
export function mountCanvas(el, drawing, onChange)          // pointer events, devicePixelRatio-aware 2D canvas
```
`struct StrokeCanvas: View { let strokes: [Stroke] }` draws with SwiftUI `Path` in a square, using the same colour and size tables.

- [ ] **Step 1: Write failing JS tests**
  - `createDrawing`: points are normalised to 0…1; `undo` removes the last stroke; `clear` empties; it stops adding at 2,000 points.
  - `strokesToSVG` emits one `<polyline>` per stroke.
  - `C2-artist` renders 6 colour swatches, 3 sizes, Undo, Clear and a square canvas element.
  - `C1-witness` and `C1-artist` both contain one `.hold-card`, but only the Witness has `[data-secret]` content.
  - `C3-witness` thumbnails carry `data-act="vote"` and the drawing number.
- [ ] **Step 2:** Run `node --test tests/controller/` (expect FAIL), implement it with the strokes timer (send every 2 s while dirty, final on Submit or deadline), then run again. Expected: PASS.
- [ ] **Step 3:** Write `test_sketchFullGame`: 3 clients, scripted strokes, picks and votes. Assert the final ranks and points and the "Most Wanted" award, and that no client but the round's Witness received the scene before C4. Run it (expect FAIL, then PASS once the TV/server pieces are wired).
- [ ] **Step 4:** Implement `StrokeCanvas` and `SketchScreens` (C1–C6 from `pages_sketch.py`). Then:
  - Play a full game on the Mac app with 3 tabs, drawing with the mouse.
  - Compare with `_shots/tv/C*.png` and the phone shots.
- [ ] **Step 5:** Commit `feat: Composite Sketch end to end`.

---

### Task 13: Insider Trading core rules

**Files:**
- Create: `Sources/NallaCore/Games/Insider.swift`, `InsiderViews.swift`
- Test: `Tests/NallaCoreTests/InsiderTests.swift`

**Interfaces:**
- Produces: `enum Insider: GameRules` and `struct InsiderState`. Screen data:
  - **I1 (question):**
    - TV: `{top, question, choices}`.
    - Insider phone (`I1-insider`): `{top, role:"insider", answerKey, answerText}`.
    - Trader phone (`I1-trader`): `{top, role:"trader"}`.
  - **I2 (discuss):** TV `{top, question, choices}`; phones `I2-insider` / `I2-trader` carry the same data as I1.
  - **I3 (bet):**
    - TV: `{top, waitingOn}`.
    - Phone: `{question, choices, chips, minBet:100, maxBet, step:100, bet?:{choice, chips}}`.
  - **I4 (answer):**
    - TV: `{question, choices, answer, bets:[{player, choice, chips, won}]}`.
    - Phone: `{won?, delta, chips}`.
  - **I5 (accuse):** TV `{top, waitingOn}`; phone `{candidates (not self), vote?}`.
  - **I6 (Insider reveal):**
    - TV: `{insider, caught, accusers, voters, commission, penalty:300, standings}`.
    - Phone: `{caught, insiderName, delta, chips}`.
  - Phone screen IDs for every player are taken from the same two-variant set, and the data keys are identical except for `role`/`answerKey`/`answerText`.

Rules:
- **Rounds and Insider:** `settings.rounds` 6–8 (default 6). The Insider order is a shuffled cycle of all players, reshuffled after everyone has had a turn, never the same player twice in a row.
- **Phases:**
  - question: 5 s;
  - discuss: 30 s, input-free but multiplied (it is a talking phase);
  - bet: 15 s, input;
  - answer: 8 s;
  - accuse: 15 s, input, all players including the Insider, choice = PlayerID, not self;
  - reveal: 10 s.
- **Chips:**
  - Everyone starts with 5,000 chips. At the start of each round, anyone below 100 is topped up to 500 (bailout).
  - A bet is 100–1,000 in steps of 100 and no more than the player's chips rounded down to 100; invalid bets → `invalid`. A correct bet gains the bet, a wrong one loses it, and no bet changes nothing.
- **Reveal:**
  - **Caught:** more than half of the non-Insider players named the Insider. Each accuser gains 300, and the Insider pays 300 per accuser (floored at 0 chips) and gets no commission.
  - **Escaped:** the Insider gains ⌊10% of the sum of non-Insider winning bets⌋.
- **Score:** points = chips.
- **Awards:** "Smoothest Insider" (most escapes, note "escaped N times") and "Best Detective" (most correct accusations, note "named the Insider N times").

- [ ] **Step 1: Write failing tests**
  - `test_secretOnlyToInsider`: during I1–I5, the JSON of every view except the Insider's (players and TV) contains no `answerKey` and no `"insider"` role; trader and insider data have the same keys apart from those three.
  - `test_insiderRotationNoRepeats`: 4 players over 8 rounds → each is Insider twice, never twice in a row.
  - `test_betLimits`: 50 → invalid; 1,100 → invalid; 250 → invalid; with 300 chips, 400 → invalid.
  - `test_bailout`: 0 chips at round end → 500 at the next round start.
  - `test_mockupChipMaths`: reproduce the `pages_insider.py` example (8 players, the BETS and START tables, 5 of 7 accusers) and assert the CAUGHT and ESCAPED boards equal the mockup's numbers.
  - `test_insiderDisconnectsMidRound`: the Insider drops during the bet; the round still resolves and no other view gains the secret.
  - `test_awards`.
  - `test_sixToEightRounds`.
- [ ] **Step 2:** Run `swift test --filter InsiderTests`. Expected: FAIL. Implement it, with copy from `pages_insider.py`, and run again. Expected: PASS.
- [ ] **Step 3:** Commit `feat(core): Insider Trading rules`.

---

### Task 14: Insider Trading controller, TV and scripted game

**Files:**
- Create: `app/Resources/Controller/js/render/insider.js`; `app/Shared/TV/InsiderScreens.swift`
- Test: `tests/controller/render-insider.test.mjs`; `ScriptedGameTests.test_insiderFullGame`

**Interfaces:**
- Consumes: Insider screen data (Task 13); `hold.js`, kit (Task 7).

- [ ] **Step 1: Write failing JS tests**
  - With the `[data-secret]` subtree removed, the rendered I1-insider and I1-trader HTML is identical.
  - I3 has the A–D choices, a chip slider with `min=100 max=<maxBet> step=100`, and the Bet button disabled until a choice is made.
  - I5 lists the candidates without the viewer.
  - I6 has caught and escaped variants.
- [ ] **Step 2:** Run `node --test tests/controller/` (expect FAIL), implement `insider.js`, then run again. Expected: PASS.
- [ ] **Step 3:** Write `test_insiderFullGame`: 4 clients and 6 rounds with scripted bets and accusations. Assert the final chips per player against a hand-computed table, and that only the Insider's socket ever carried `answerKey` before I4. Run it (expect FAIL, then PASS).
- [ ] **Step 4:** Implement `InsiderScreens.swift` (I1–I6). Then:
  - Play a full game with 4 tabs on the Mac app.
  - Compare with `_shots/tv/I*.png` and the phone shots.
- [ ] **Step 5:** Commit `feat: Insider Trading end to end`.

---

### Task 15: Hardening

**Files:**
- Modify: `js/app.js`, `js/net.js` (resend drafts after `welcome`), `app/Shared/HostModel.swift`, `app/iOS/Flow/H5LiveRoom.swift`, `app/macOS/M2RoomView.swift`, TV screens (accessibility)
- Test: `tests/controller/reconnect.test.mjs`; `SocketTests.test_reconnectKeepsSeatAndScreen`

**Steps:**
- [ ] **Step 1: Write failing tests**
  - `reconnect.test.mjs`: with a fake WebSocket, after a drop and `welcome`, an unsent R1 draft for the current round is resubmitted once; a draft for an older round is discarded.
  - `test_reconnectKeepsSeatAndScreen`: a client drops mid-R1 and reconnects with its token. It gets the same PlayerID and the current R1 view; the TV shows the T8 banner while it is away and loses it on return.
- [ ] **Step 2:** Run them (expect FAIL), implement, then run again. Expected: PASS.
- [ ] **Step 3:** Accessibility pass:
  - The host app has VoiceOver labels on every host control (strip buttons, toolbar, player remove buttons, display picker).
  - `FaceCorner` honours Reduce Motion.
  - TV views use fixed canvas sizes (no Dynamic Type on the TV).
  - The controller has `aria-label`s on icon buttons and the timer as `role="timer"`.
  - Check P-screens at 360 px and 130% text in the browser pane.
- [ ] **Step 4:** Network self-test wiring: M4 shows when `NetworkSelfTest` fails at room start or the room has 0 players after 60 s. **Copy join link** puts `joinURL` on the pasteboard.
- [ ] **Step 5:** Run all suites and both builds:
  - `swift test` in both packages;
  - `node --test tests/controller/`;
  - both `xcodebuild` builds with 0 warnings;
  - `cd tests/design && python3 -m unittest discover -s .` (mockups untouched, still 55 OK).
  - Expected: all PASS.
- [ ] **Step 6:** Commit `fix: reconnect resend, accessibility, network self-test`.

---

### Task 16: Starter content

**Files:**
- Modify: `app/Resources/Content/redacted.json` (40 passages), `sketch.json` (24 scenes), `insider.json` (120 questions)
- Test: `ContentTests.test_bundledContentValid` (Task 3) plus `test_starterContentCounts`

- [ ] **Step 1: Write failing test** `test_starterContentCounts`:
  - passages ≥ 40, scenes ≥ 24, questions ≥ 120;
  - ≥ 80% of each pack is `family:true`;
  - Redacted answers are not profane when the item is family.
- [ ] **Step 2:** Run `swift test --filter ContentTests`. Expected: FAIL.
- [ ] **Step 3:** Write the content in the PRD/§10 voice:
  - Passages: odd real-sounding news, history and science snippets with 1–3 blanks.
  - Scenes: an emoji composition plus a ≤ 48-character caption, with 3 banned words each.
  - Questions: trivia with one clearly correct answer among 4 plausible choices.
- [ ] **Step 4:** Run `swift test --filter ContentTests`. Expected: PASS.
- [ ] **Step 5:** Commit `content: starter packs (40 passages, 24 scenes, 120 questions)`.

---

### Task 17: Final verification and review

- [ ] **Step 1:** Full manual play, logged in `docs/superpowers/plans/2026-11-20-nallabox-app-verification.md`:
  - Mac host, 4 browser tabs: one full game of each title.
  - iPhone simulator host with an external display plus 2 tabs: one Redacted game.
  - Drop/rejoin a tab mid-round, pause/resume from the leader sheet and from the host, and remove a player.
- [ ] **Step 2:** Screenshot the TV and phones at key screens. Compare against `design/mockups/_shots/` (regenerate first with `python3 tests/design/shoot.py --all-states`) and fix visible mismatches in layout, copy or colour.
- [ ] **Step 3:** Run every suite and both builds (the Task 15 Step 5 commands). Expected: all PASS, 0 warnings.
- [ ] **Step 4:** Commit `docs: v1 verification log`, then use superpowers:requesting-code-review for the whole branch and fix what it finds.
