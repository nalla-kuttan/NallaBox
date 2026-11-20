# NallaBox — UI/UX Design

Status: draft for approval · 2026-11-19
Inputs: [NallaBox PRD](https://claude.ai/artifact/T3mx85dvW5cY8ydmDxaUsq), logo kit in `logo/kit/` (see `logo/kit/GUIDELINES.md`).
Decisions marked **(your call)** were made by you in conversation; **(my call)** marks a default I chose that you can overrule.

## 1. Intent

This plan specifies every screen of NallaBox v1 well enough for one person (you) to build the host app in SwiftUI
and the phone controller in HTML without guessing. The deliverable after approval is a set of **full, true-size,
clickable mockups** plus a SwiftUI token file.

The experience should feel like a show in the living room: the TV is the stage, phones are private notebooks, and the
host device stays out of the way. A group should go from "let's play" to the first round in under 60 seconds.

## 2. Goals, non-goals, anti-goals

**Goals**
- Mock up every v1 screen and state on all four surfaces: TV, phone controller, iPhone host, Mac host.
- Make the three launch games (Redacted, Composite Sketch, Insider Trading) fully specified, phase by phase.
- One visual system (Night stage) and one component set shared by TV, phone and host.
- Specs a solo builder can translate directly: sizes in points, exact colours, type styles, spacing, states.

**Non-goals (v1)**
- Apple TV host app and iPad-specific layouts (iPad runs the iPhone layout).
- The six Wave 2–3 games, audience mode, remote play, accounts.
- Sound design (cues are named in the spec; no audio is produced).

**Anti-goals: things that would make this a failure even if every screen exists**
- A guest's phone ever shows another player's secret (Insider answer, Witness scene).
- Anyone has to touch the host device during normal play.
- TV text that can't be read from 3 m, or a phone screen whose next action isn't obvious within 2 seconds.
- The face becoming a chatty character that slows rounds down.

## 3. Constraints

- **Zero install.** Guests use a web page served by the host over local Wi-Fi. No internet at play time, so every font,
  image and script is bundled in the host app (Nunito as local `woff2` for the web; bundled `.ttf` for SwiftUI).
- **Surfaces and sizes.** TV: 1920×1080 pt canvas (scale to the external display). Phone controller: designed at
  393×852 pt (iPhone 16), must work from 360 to 440 pt wide. iPhone host: same 393×852. Mac host: resizable window,
  designed at 1280×800, minimum 960×640.
- **Legibility.** TV body text ≥ 36 pt, secondary text ≥ 30 pt. Phone tap targets ≥ 44 pt.
- **Brand.** Night Ink `#1E1B2E` background, Nalla Coral `#FF5C39` accent, Nunito type, Finder Face mark.
- **Accessibility** (from the PRD): captions for every spoken line, timer multipliers 1× / 1.5× / 2× / off for writing,
  colour never the only signal, phone honours Dynamic Type / browser text size up to 130%.

## 4. Approaches considered

1. **Clickable HTML mockups at true size + SwiftUI spec sheet (chosen, your call).** Fast to iterate, viewable on any
   device at real size, phone mockups are close to production HTML/CSS. TV and host screens are rebuilt in SwiftUI from the specs.
2. **Mockups as static SwiftUI views with `#Preview`.** Code you keep, but every design change needs a build, and it
   starts implementation before the design is agreed.
3. **Figma.** Dropped: Figma isn't connected here, and a solo builder doesn't need a designer handoff tool.

## 5. Decisions made in conversation

| Topic | Decision |
|---|---|
| Who reads this | You, building the SwiftUI screens; full mockups needed **(your call)** |
| How the host plays | The host joins like everyone else; the **first player to join is the room leader** and controls the game from their phone **(your call)** |
| Host devices in v1 | **Mac and iPhone** (iPad runs the iPhone app) **(your call)** |
| iPhone host playing | The iPhone host app shows the **same controller in-app** (a `WKWebView` of the local controller page) while the TV shows the game **(your call)** |
| TV mood | **Night stage**: dark Ink background, coral for what matters **(your call)** |
| The face | **Face reacts**: top-right corner, one caption line, ~8 expression states **(your call)** |
| Phone theme | Dark, matching the TV, so phones don't flash bright in a dim room **(my call)** |
| Leader handoff | If the leader leaves or drops for 30 s, leadership passes to the next-joined player; the TV announces it **(my call)** |

## 6. Control model

| Who | Can do | Where |
|---|---|---|
| Room leader | Choose game, change settings, start, pause, skip round, end game, remove a player | Phone: leader tray + lobby controls |
| Host device owner | Everything the leader can, plus family-friendly filter, end session, reconnect TV | iPhone: host strip in the host app · Mac: room window |
| Player | Join, submit, vote, bet, accuse, see own score | Phone |

Rules: only one leader at a time; leader controls are always one tap away (a coral **pill** at the top right of every
phone screen, opening the leader sheet). Pausing freezes every timer and shows the pause screen on TV and phones.
Destructive actions (end game, remove player) need a confirm step.

## 7. Information architecture: screen inventory

IDs are used by the mockups (`T` TV, `P` phone, `R/C/I` game phases, `H` iPhone host, `M` Mac host).

### 7.1 TV (1920×1080)

| ID | Screen | Notes |
|---|---|---|
| T1 | Lobby, empty | QR, room code, join URL, 8 empty seats, face idle: "Scan to join" |
| T2 | Lobby, filling | Seats fill with avatar + name; leader badge; "Priya starts the game from her phone" |
| T3 | No-one-joining help | After 60 s with 0 players: Wi-Fi tips panel (same network, guest Wi-Fi blocks, try Personal Hotspot) |
| T4 | Game picker | Three large game cards; the leader's current choice is highlighted live; player-count fit shown |
| T5 | Game settings summary | Rounds, timer speed, family-friendly; mirrors leader edits |
| T6 | How to play | One card, 3 steps with icons, 15 s, skippable by leader |
| T7 | Pause | Dimmed game, "Paused by Priya", face sleepy |
| T8 | Player reconnecting | Non-blocking banner "Waiting for Sam… (0:24)"; round continues |
| T9 | Leader changed | Toast "Sam is now the leader" |
| T10 | Final results | Podium top 3, awards row (e.g. "Best Liar", "Most Wanted"), "Play again / New game" mirrored from leader |

### 7.2 Phone controller (393×852, web)

| ID | Screen | Notes |
|---|---|---|
| P1 | Join | Room code (prefilled from QR), name (max 12), colour picker (8 swatches), Join |
| P2 | Join errors | Wrong code · room full (8) · name taken · game in progress ("you'll join next game") |
| P3 | Lobby, player | Your avatar, "Waiting for Priya to start", list of who's in |
| P4 | Lobby, leader | Same + **Choose game** (primary) + settings link; Start disabled under 3 players with reason |
| P5 | Game picker (leader) | Vertical list of 3 games with player range and length; tapping highlights on TV; **Pick this game** |
| P6 | Game settings (leader) | Rounds (stepper), timer speed (1×/1.5×/2×/off), family-friendly toggle, banned words on/off (Composite Sketch only), **Start**; Start is disabled with a reason below the game's minimum (Insider Trading needs 4) |
| P7 | Your job | One-line role for the next phase, big icon; auto-advances |
| P8 | Waiting | "Done! Waiting on 3 players" with their avatars; face-free (the face lives on TV) |
| P9 | Reconnecting | Spinner, "Reconnecting to the room…", retry; keeps typed input |
| P10 | Paused | "Paused by Priya" |
| P11 | Removed | "The host removed you from this room" + rejoin option |
| P12 | Your results | Your rank, points, award if any; leader gets Play again / New game |
| P13 | Leader sheet | Pause/Resume, Skip round, End game, Remove player (list), Pass leadership |

### 7.3 Game phases (TV + phone per phase)

**Redacted** (3 rounds + final at ×3)

| ID | TV | Phone |
|---|---|---|
| R1 Write (60 s) | Passage with numbered blanks, timer, "waiting on" avatars | One text field per blank (max 24 characters), labelled "Blank 1"…; Submit; inline error "Too close to the real word, try another" |
| R2 Read-out | Versions appear one at a time, current one highlighted; caption = spoken text | "Listen up" + version count |
| R3 Vote (30 s) | All versions numbered in a grid | Vote list (your own greyed "yours"); tap to vote, tap again to change |
| R4 Reveal | Real version flips to coral "REAL"; each fake shows its author and who it fooled | "You fooled 2 players: +1,000" or "You found the real one: +1,000" |
| R5 Scores | Leaderboard with animated deltas | Your rank + points |

**Composite Sketch** (one round per player, max 8)

| ID | TV | Phone (Witness) | Phone (Artist) |
|---|---|---|---|
| C1 Briefing (5 s) | "Lena is the Witness" + face gasp | **Hold to see the scene** + banned words (if on) | "Get ready to draw" |
| C2 Describe & draw (30 s) | Big countdown, Witness name, "Describe it out loud!" | Hold-to-peek scene stays available | Canvas: 6 colours, 3 brush sizes, undo, clear; full-width square canvas |
| C3 Line-up | All drawings in a grid, numbered, artist names hidden | "Pick the closest match" (thumbnails) | "Your drawing is up" |
| C4 Scene reveal | Real scene next to the Witness's pick; points | — | Points toast |
| C5 Most Wanted | Grid again, "Vote for the worst likeness" | Vote | Vote (not own) |
| C6 Scores | Leaderboard | Rank | Rank |

**Insider Trading** (6–8 rounds)

| ID | TV | Phone (Insider) | Phone (Trader) |
|---|---|---|---|
| I1 Question (5 s) | Question + choices A–D | **Hold to reveal role**: "You are the Insider · Answer: C" | **Hold to reveal role**: "You are a Trader" |
| I2 Discuss (30 s) | Question, timer, face suspicious | Role reminder (hold to peek) | Same layout, no answer |
| I3 Bet (15 s) | "Place your bets", waiting avatars | Choice A–D + chip slider (100–1,000, steps of 100) + Bet | Same |
| I4 Answer | Correct choice lights coral; each player's bet and win/loss | Result toast | Result toast |
| I5 Accuse (15 s) | "Who was the Insider?" | Player list (not self) | Same |
| I6 Insider reveal | Insider unmasked or escaped; commission or penalty; leaderboard | Points | Points |

Both role cards look identical at a glance and require a press-and-hold to show their content, so a neighbour can't
tell an Insider from a Trader by layout or by a glance **(my call)**.

### 7.4 iPhone host app (SwiftUI, 393×852)

| ID | Screen | Notes |
|---|---|---|
| H1 | Welcome (first run) | Logo, "Turn any TV into a party", Continue |
| H2 | Local network explainer | Why the permission matters, then triggers the system prompt; denied state deep-links to Settings |
| H3 | Connect to TV | AirPlay route button (`AVRoutePickerView`), "or use a cable", detected-display check, Continue enabled once an external display exists |
| H4 | Your name | Host enters name + colour, becomes player 1 and leader |
| H5 | Live room | Host strip on top (room code · players · Pause · menu), controller `WKWebView` below; this is where the host plays |
| H6 | Host menu | Sheet: Pause/Resume, Skip round, Remove player, Family-friendly, End session |
| H7 | TV disconnected | Full-screen warning: game paused, "Reconnect AirPlay", reconnect button |
| H8 | Leaving warning | Shown on return if the app was backgrounded: "The room paused while you were away" |

### 7.5 Mac host app (SwiftUI, 1280×800 window)

| ID | Screen | Notes |
|---|---|---|
| M1 | Start | Logo, Local network status, **Show game on** display picker (each connected display, or "this window"), Start room |
| M2 | Room window | Left 360 pt column: room code, QR, player list with remove buttons, network health; right: live TV preview; toolbar: Pause, Skip, End, Settings |
| M3 | Game display | The TV screens (T*/R*/C*/I*) full-screen on the chosen display. With a single display ("this window"), the game goes full-screen and host controls appear in a bar when the pointer moves to the top edge; Esc returns to M2 and pauses |
| M4 | Network problem | Inline panel in M2 when joins fail: checklist + "Copy join link" |
| M5 | Settings sheet | Family-friendly, timer speed default, host voice on/off, captions size |

## 8. Key flows

1. **iPhone host start:** H1 → H2 → H3 (AirPlay to TV) → H4 → H5; TV shows T1 → T2 as guests join.
2. **Mac host start:** M1 (pick display) → M2; TV/display shows T1. Host joins from their own phone like a guest.
3. **Guest join:** scan QR → P1 → P3 (or P4 if first). Errors → P2.
4. **Start a game:** leader P4 → P5 (TV T4 mirrors) → P6 (TV T5) → Start → T6 / P7 → first phase.
5. **Round loop:** phase screens per game (7.3); every timed phase ends early when everyone has submitted.
6. **Drop and return:** phone loses connection → P9 with input kept → back on the same screen; TV shows T8 banner.
7. **Leader leaves:** 30 s grace → leadership passes → T9 toast, new leader's phone gains the pill.
8. **End:** T10 + P12 → leader picks Play again (same game, same settings) or New game (→ P5).

## 9. Visual system

### 9.1 Colour tokens

| Token | Hex | Use |
|---|---|---|
| `ink` | #1E1B2E | App/TV background |
| `ink-raised` | #2B2742 | Cards, answer tiles, inputs |
| `ink-line` | #3A3556 | Borders, dividers, empty seats |
| `coral` | #FF5C39 | Primary buttons, timer, room code, leader, selection, REAL stamp |
| `coral-press` | #E54826 | Pressed primary |
| `text` | #FFFFFF | Primary text |
| `text-dim` | #B9B4CF | Secondary text (≥ 4.5:1 on ink) |
| `success` | #4ED19A | Correct, gained points |
| `danger` | #FF6B7A | Errors, lost chips (always paired with an icon/sign) |
| `paper` | #FFF4EA | Caption bubble fill, QR plate |

**Player colours** (avatar fills; coral is reserved for the system): Saffron #FFB020 · Sky #3DB7FF · Mint #4ED19A ·
Lilac #B58CFF · Pink #FF7AB6 · Lime #C6E85A · Teal #2EC4B6 · Sand #E9D8B4. Avatars always show the player's
initial (ink text) so colour is never the only identifier **(my call)**.

### 9.2 Type (Nunito)

| Style | TV size / weight | Phone size / weight | Use |
|---|---|---|---|
| Display | 120 / Black | 40 / Black | Room code, countdown numbers |
| Title | 72 / Black | 28 / ExtraBold | Prompts, passage, question |
| Heading | 52 / ExtraBold | 22 / ExtraBold | Section heads, game names |
| Body | 40 / Bold | 17 / Bold | Answers, lists |
| Label | 32 / ExtraBold, +1 tracking, caps | 13 / ExtraBold, caps | Labels, badges |
| Caption | 36 / Bold | 15 / SemiBold | Face caption, help text |

### 9.3 Spacing, radii, layout

- 8-pt grid on TV (gutters 96, section gaps 48), 4-pt grid on phone (side margins 20, stack gap 12–16).
- Radii: `sm` 8 · `md` 14 · `lg` 22 · `xl` 32 (TV cards). Avatars use 30% corner radius to echo the logo body.
- TV safe area: 80 pt inset on all sides (overscan). Face corner: 160 pt face + caption bubble, top-right inside the safe area.
- Phone: one primary action per screen, pinned to the bottom (56 pt tall, full width minus margins), safe-area aware.

### 9.4 Components

Avatar (S 32 / M 48 / L 96, initial inside) · Player chip (avatar + name, states: joined, submitted ✓, offline,
leader badge) · Seat (empty dashed) · Timer pill (normal; last 5 s pulses) · Answer tile (number + text; states:
default, selected, mine, real, fake-with-author) · Primary / secondary / destructive button (default, pressed,
disabled with reason) · Text field (default, focus, error, char counter) · Colour swatch picker · Stepper · Segmented
control (timer speed) · Toggle · Hold-to-reveal card (resting, held) · Chip slider (Insider bets) · Drawing toolbar ·
Leaderboard row (rank, avatar, name, points, delta) · Toast · Banner · Leader pill + sheet · Face corner (face + caption).

### 9.5 The face (Face reacts)

The face is drawn from the logo master (`logo/kit/master/nallabox-symbol-color.svg`) at 160 pt on TV. States change
with a 180 ms squash-and-settle (scale Y 0.9 → 1.0); idle blinks every 4–7 s.

| State | Look | Trigger | Example caption |
|---|---|---|---|
| idle | Logo as is | Default | — |
| blink | Eye closes to a bar for 120 ms | Random idle | — |
| wink | The logo's wink | Lobby, round start | "Scan to join." |
| grin | Smile widens 15%, both eyes open | Points awarded | "Sam fooled three of you." |
| gasp | Smile becomes an O | Reveals, real answer shown | "That one was real?!" |
| suspicious | Eye narrows, smile flat | Insider discuss/accuse, Witness phase | "Someone here knows the answer." |
| sleepy | Eyes half closed | Pause; last 5 s of a timer | "Paused. Take your time." |
| celebrate | Big grin + bounce | Final results | "And the winner is Priya!" |

Captions are one line, at most 48 characters, also spoken by the host voice when voice is on. Host voice is on by
default; captions always show, voice or not **(my call)**.

### 9.6 Motion

Durations: 150 ms (taps), 250 ms (screen transitions, cross-fade + 16 pt slide), 400 ms (reveals). Easing: spring
(response 0.35, damping 0.8). Reduced Motion: replace slides and bounces with fades.

## 10. Copy voice

Short, warm, a little cheeky; never mean to a player by name. Instructions are verbs first ("Write a fake word",
"Hold to see your role"). Errors say what to do next.

## 11. Mockup deliverable (what gets built after approval)

- `design/mockups/index.html`: a flow map linking every screen by ID, grouped by surface and game.
- One HTML page per screen at true size: `tv/`, `phone/`, `host-iphone/`, `host-mac/`, with a size frame and the screen ID.
  Phone pages also open full-screen on a real phone for size checks.
- Each page shows its key states (e.g. button disabled, error) as toggles.
- `design/mockups/shared/tokens.css` (colours, type, spacing) used by every page and reusable in the real controller.
- `design/NallaBoxTheme.swift`: `Color`, `Font` and spacing/radius constants matching section 9.
- Realistic sample content (names, passages, questions, drawings) so layouts are tested against real lengths.

## 12. Left to the builder

- SwiftUI view structure, navigation implementation, state management.
- Exact animation curves beyond section 9.6.
- How the TV scale maps to non-1080p displays (fit the 1920×1080 canvas, letterbox if needed).
- Sound cue design and the content packs themselves.
