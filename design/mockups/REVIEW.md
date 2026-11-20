# Mockup review against the spec's anti-goals

Spec: `docs/2026-11-19-nallabox-ui-ux-design.md` §2. Checked 2026-11-19 after Task 12 (75 pages, every state screenshotted, phones also at 360 px wide and 130% text).

| Anti-goal | Result | Evidence |
|---|---|---|
| A guest's phone shows another player's secret | Pass | `test_role_cards_identical_at_rest`, `test_insider_answer_only_in_secret`, `test_scene_only_on_witness`, `test_witness_scene_is_secret`. Insider and Trader role pages are byte-identical outside `[data-secret]`; the Witness scene exists only on the Witness's phone (behind hold-to-reveal) and on the TV at the reveal. |
| Anyone has to touch the host device during normal play | Pass | All game control is on the leader's phone (P4–P6, P13). iPhone host H5 is the host's own controller; the strip above it is for emergencies. Mac M2 labels its toolbar "for emergencies". |
| TV text unreadable from 3 m | Pass, one ruling | Every TV text style is ≥ 30 px (body 40, caption 36, label 32). Avatar initials inside small TV avatars are 18–26 px; they are colour+letter identifiers next to the full name (ruling in the ledger). |
| Phone screen whose next action isn't obvious in 2 s | Pass | `test_phone_pages_have_one_primary_action`: at most one primary per state, pinned at the bottom. Screens with no primary (waiting, voting, reveals) carry a one-line status ("Voted for 3 · tap another to change", "Waiting on 3 players"). |
| The face slows rounds down | Pass | Face lives in the top-right corner on every TV screen with one caption line ≤ 48 characters (`test_face_captions_one_short_line`); no screen waits on the face. |

## Review Focus (from the plan)

1. Longest content (`Wolfgangster`, `competitive soup kitchen`): fits chips, tiles and leaderboards on TV and phone (T2, R1, R3, R4, components.html).
2–3. Narrow phones and large text, together: every state of all 35 phone pages and 8 iPhone host pages at 360 px wide and 130% text (`_shots/*/*-w360-t130.png`): no sideways scroll, primary action unclipped, long names truncate cleanly.
4. Secret leakage: see the first row above.
5. Full room: 8 chips on T2 (full), 8 rows on T10/R5/C6/I6, 7 drawings in C3/C5, 9 versions in R3/R4, all inside the TV safe area.

## Final review

A fresh reviewer found 0 critical and 6 important issues; all 6 are fixed with regression tests in `tests/design/test_final_fixes.py`. The 13 minor findings were then fixed too (`tests/design/test_minor_fixes.py`). `tests/design/test_layout_audit.py` now measures every page and state in headless Chrome: TV text inside the safe area, captions never clipped, phone tap targets ≥ 44 px, and no sideways overflow at 360 px + 130% text.

## Known limits

- The QR code is a placeholder pattern, not scannable.
- Fonts, scene art and drawings are sample content; the real content packs come later.
- Mockups show states side by side via the bar's state buttons; transitions and the face animation are specified (spec §9.5–9.6) but only the face swap is demoed (`faces.html`).
