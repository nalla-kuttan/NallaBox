<p align="center"><img src="logo/kit/master/nallabox-symbol-color.svg" width="96" alt="NallaBox logo"></p>

# NallaBox

A party game box for your living room. One iPhone or Mac hosts the room and puts the game on the TV; everyone else
plays from their own phone's browser after scanning a QR code. No app, no account, nothing leaves your Wi-Fi.

## The games

| Game | Players | What happens |
|---|---|---|
| **Redacted** | 3–8 | A true fact appears with words blanked out. Everyone writes believable fakes, then votes for the real one. +500 for each player you fool, +1,000 for finding the truth. Three rounds and a final worth triple. |
| **Composite Sketch** | 3–8 | One Witness secretly sees a scene and describes it out loud. Everyone else draws it blind on their phone. The Witness picks the closest match, then everyone votes for the worst likeness. |
| **Insider Trading** | 4–8 | Everyone sees a trivia question, but one secret Insider knows the answer. Talk it out, bet chips on an answer, then unmask the Insider. |

## How it works

```
 iPhone or Mac (host app)                         TV
 ┌──────────────────────────────┐   AirPlay /   ┌──────────────┐
 │ NallaServer                  │   HDMI /      │ SwiftUI TV   │
 │  HTTP :8080  → phone page    │   2nd screen  │ renderer     │
 │  WebSocket :8081 → live game │ ────────────▶ │ + host face  │
 │ NallaCore (all game rules)   │               └──────────────┘
 └──────────────▲───────────────┘
                │ Wi-Fi
   ┌────────────┴─────────────┐
   │ phones: plain HTML/CSS/JS │  each phone gets only its own view,
   │ controller in the browser │  so secrets never leak
   └───────────────────────────┘
```

- **`Packages/NallaCore`**: the game rules as a pure Swift reducer (`reduce(state, event, now)`), with room, leader,
  pause, results and the three games. No UI and no networking, so every rule is tested instantly with a fake clock.
- **`Packages/NallaServer`**: Network.framework HTTP and WebSocket servers and the hub actor that sends each phone
  its own view. `NallaDevServer` runs a room in the terminal for testing with browser tabs.
- **`app/`**: the SwiftUI host app for iPhone (AirPlay/HDMI to the TV, the host plays on the same phone) and Mac
  (game on any display). The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- **`app/Resources/Controller`**: the phone controller, plain ES modules with no build step.
- **`app/Resources/Content`**: starter packs (40 passages, 26 scenes, 120 questions) as editable JSON.
- **`design/`**: the approved clickable HTML mockups for every screen, and the Swift design tokens.

Zero third-party dependencies.

## Requirements

- Xcode 27 (Swift 6.4), iOS 18 / macOS 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Node 24 (only for the controller tests)

## Build and run

```bash
cd app && xcodegen generate
open NallaBox.xcodeproj
```

Run the **NallaBox-Mac** scheme, pick a display and press **Start room**. Phones on the same Wi-Fi scan the QR code
on the TV. For the **NallaBox-iOS** scheme on a real iPhone, set your Apple developer team under Signing.

To try the games without the app, start a room in the terminal and open the printed URL in a few browser tabs:

```bash
cd Packages/NallaServer && swift run NallaDevServer
```

## Tests

```bash
cd Packages/NallaCore && swift test        # game rules
cd Packages/NallaServer && swift test      # server, including full scripted games over real sockets
node --test 'tests/controller/*.test.mjs'  # phone controller
cd tests/design && python3 -m unittest discover -s .   # mockups (needs Google Chrome)
```

## Docs

- [UI/UX design](docs/2026-11-19-nallabox-ui-ux-design.md) and [mockups](design/mockups/index.html)
- [Technical design](docs/superpowers/specs/2026-11-20-nallabox-app-design.md) and [build plan](docs/superpowers/plans/2026-11-20-nallabox-app.md)
- [Verification log](docs/superpowers/plans/2026-11-20-nallabox-app-verification.md) and [build decisions](docs/superpowers/plans/2026-11-20-nallabox-app-decisions.md)
- [Logo guidelines](logo/kit/GUIDELINES.md)

## Status

v1 is feature-complete and tested on the iOS Simulator, the Mac and browser phones. Not yet tried with a real TV over
AirPlay, real phones over Wi-Fi, or the Mac's second-display mode. Known limitation: guests' phones may auto-lock
during quiet moments (browsers only allow keep-awake on secure pages); the page reconnects when unlocked.
