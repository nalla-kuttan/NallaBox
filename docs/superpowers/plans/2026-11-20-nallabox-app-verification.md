# NallaBox v1: verification log

Date: 2026-11-20. Branch `nallabox-v1`. Plan: `docs/superpowers/plans/2026-11-20-nallabox-app.md`.

## Automated suites (all passing)

| Suite | Command | Result |
|---|---|---|
| Rules (NallaCore) | `cd Packages/NallaCore && swift test` | 90 tests pass |
| Server (NallaServer), incl. full scripted games over real sockets | `cd Packages/NallaServer && swift test` | 27 tests pass |
| Phone controller | `node --test 'tests/controller/*.test.mjs'` | 45 tests pass |
| Mockups (unchanged) | `cd tests/design && python3 -m unittest discover -s .` | 55 tests pass |
| App builds | `xcodebuild` NallaBox-iOS (iPhone 17 Pro simulator) and NallaBox-Mac | both succeed, 0 warnings |

The scripted games play Redacted (4 players, 3 rounds + final), Composite Sketch (3 players, 3 rounds) and Insider Trading
(4 players, 6 rounds) end to end over WebSockets with a manual clock, and check final scores against hand-worked
tables and that no phone ever received another player's secret.

## Hands-on play

Phones were the in-app browser (393×852) plus scripted bot players; TV screens were captured from the Mac app at
1920×1080 with its debug snapshot flag and compared with `design/mockups/_shots/tv/`.

| Check | Host | Result |
|---|---|---|
| Join (P1), too-few lobby (P4), lobby fills live, leader sheet → remove → confirm, page reload rejoins the same seat | dev server | Pass |
| TV room screens T1, T2, T3 tip, T4, T5, T6, T7 pause, T8 reconnect banner, T9 toast, T10 | Mac | Pass, match mockups |
| Redacted full game: too-close inline error with answers kept, read-out, vote (own greyed), reveal +2,000, scores, results | Mac | Pass |
| Composite Sketch full game: hold-to-reveal scene + banned words, Witness pick (+500), drawing with the mouse, Undo, I'm done, Most Wanted vote | Mac | Pass |
| Insider Trading full game: P7 leader pill → Skip, role card, bet with choice buttons + slider, answer (+900), escape (+50 commission), 6 rounds | Mac | Pass |
| iPhone host H1 → H2 (local network) → H3 → H4 → H5 (host plays in the embedded controller), guests join live, H6 menu | iOS simulator | Pass |
| iPhone host starts Redacted from its own phone; Home → guests see P10; return → H8 alert; Resume | iOS simulator | Pass |
| Mac M1, M2, M4 panel, M5 sheet | Mac (rendered) | Pass, match mockups |
| Phone screens at 360 px wide with text ×1 and ×1.3 (18 screens, long names): no sideways overflow, tap targets ≥ 44 pt | browser | Pass |

## Bugs found and fixed while verifying

TV timer wrapping onto two lines; long podium names and award notes truncated; Sketch scene caption truncated;
iPhone host controller zooming on double-tap; leader couldn't skip the how-to from P7; offline submissions silently
dropped (now resent after reconnecting).

## Not verified by hand

- A real TV over AirPlay or HDMI, and the iPhone "TV disconnected" screen (H7). The simulator can't attach a display
  from the command line, so a debug-only `-simulateTV YES` flag stood in.
- The Mac game on a second physical display, and the Mac "This window" full-screen mode (M3) with the top-edge bar.
  Computer-use access to the Mac app was declined, so Mac screens were checked from rendered snapshots.
- Real phones on Wi-Fi (all phones here were browser tabs and bots on this Mac).
- Signing for a real device (needs your Apple developer team).
