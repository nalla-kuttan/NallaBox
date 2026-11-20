# NallaBox UI Mockups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build true-size, clickable HTML mockups of every NallaBox v1 screen, plus `tokens.css` and `NallaBoxTheme.swift`, exactly as specified in the approved UI/UX design.

**Architecture:** Static HTML pages, one per screen, grouped by surface (`tv/`, `phone/`, `host-iphone/`, `host-mac/`). Shared CSS (tokens, components) and two shared scripts: a JSON-literal screen manifest (`screens.js`) and a frame script (`frame.js`) that draws the true-size device frame, the screen ID bar, prev/next links and state toggles. Python `unittest` checks enforce coverage, the page contract, token parity with Swift, offline-only assets and the Review Focus cases; Chrome headless screenshots are the visual check.

**Tech Stack:** HTML5, CSS custom properties, vanilla JS (no build step, works from `file://`), Python 3 stdlib `unittest`, Swift 5.9+ / SwiftUI (token file only), Nunito variable font (SIL OFL).

**Spec:** `docs/2026-11-19-nallabox-ui-ux-design.md` (read it first; tasks cite its sections as §N). Brand source: `logo/kit/master/`.

## Global Constraints

- No network at runtime: no `http://` or `https://` URL in any mockup HTML, CSS or JS; fonts load from `design/mockups/shared/fonts/`.
- Canvas sizes: TV 1920×1080; phone 393×852 (must hold from 360 to 440 wide); iPhone host 393×852; Mac host window 1280×800 (min 960×640).
- TV body text ≥ 36 px, secondary ≥ 30 px; phone tap targets ≥ 44 px; TV safe area 80 px inset; face 160 px top-right inside the safe area.
- Colours, type scale, spacing, radii: exactly §9.1–9.3. Coral `#FF5C39` is never a player colour.
- One primary action per phone screen, pinned to the bottom, 56 px tall.
- Copy: verbs first, warm, never mean to a named player (§10); face captions ≤ 48 characters (§9.5).
- Secret content (Insider answer, Witness scene) only inside `[data-secret]` elements on that player's phone page, hidden until hold.
- Sample content is realistic: names up to 12 characters, Redacted answers up to 24 characters.
- The project folder is not a git repository: skip commit steps unless the user sets one up and asks for commits.

## Review Focus

1. **Longest content:** a 12-character name (`Wolfgangster`) and a 24-character answer must not overflow chips, tiles or leaderboard rows. Test owner: Task 5 (T2) and Task 7 (R3).
2. **Narrow phones:** at 360 px wide, no phone screen scrolls sideways or clips its primary button. Test owner: Task 12 (screenshot pass at `?w=360`).
3. **Large text:** at 130% text size (`?text=1.3`), phone screens still show the primary action without overlap. Test owner: Task 12.
4. **Secret leakage:** the resting Insider and Trader role cards are identical outside `[data-secret]`. Test owner: Task 9.
5. **Full room:** 8 players on the TV lobby, leaderboards and results, and 7 drawings in the Composite Sketch line-up, still fit the safe area. Test owner: Tasks 5, 7, 8.

---

## File Structure

```
design/
  NallaBoxTheme.swift                 Swift colour/font/space/radius tokens (Task 2)
  mockups/
    index.html                        Flow map: every screen by group, linked (Task 1)
    components.html                   Component gallery with all states (Task 3)
    faces.html                        8 face states + squash animation demo (Task 4)
    shared/
      tokens.css                      All design tokens as --nb-* custom properties (Task 1)
      base.css                        @font-face, reset, body defaults (Task 1)
      components.css                  Component classes (Task 3)
      frame.css / frame.js            Device frame, ID bar, prev/next, state toggles, ?w= ?text= (Task 1)
      screens.js                      window.NB_SCREENS = [JSON array] manifest (Task 1)
      fonts/nunito-wght.woff2         Nunito variable, latin subset (Task 1)
      fonts/Nunito[wght].ttf          For SwiftUI (Task 2)
      face/face-<state>.svg           idle blink wink grin gasp suspicious sleepy celebrate (Task 4)
      img/                            Logo copies, sample drawings and scene art (Tasks 4, 8)
    tv/      T1–T10, R1–R5, C1–C6, I1–I6 (.html)           (Tasks 5, 7, 8, 9)
    phone/   P1–P13, game phase pages (.html)               (Tasks 6, 7, 8, 9)
    host-iphone/ H1–H8 (.html)                              (Task 10)
    host-mac/    M1–M5 (.html)                              (Task 11)
tests/design/
  helpers.py                          load_manifest(), read_page(), css_tokens(), swift_tokens()
  test_manifest.py                    coverage + page contract + offline (Task 1, extended per surface)
  test_tokens.py                      spec values + contrast + Swift parity (Tasks 1–2)
  test_components.py                  gallery covers §9.4 (Task 3)
  test_faces.py                       8 states, shared viewBox (Task 4)
  test_review_focus.py                Review Focus cases 1, 4, 5 (Tasks 5, 7, 8, 9)
  shoot.py                            Chrome headless screenshots of every page (Task 12)
```

### Page contract (every screen page)

```html
<body data-screen="T1" data-surface="tv" data-states="default,help">
  <main class="screen"> … </main>
  <script src="../shared/screens.js"></script>
  <script src="../shared/frame.js"></script>
</body>
```
with `<link rel="stylesheet">` to `../shared/tokens.css`, `../shared/base.css`, `../shared/components.css`, `../shared/frame.css` in `<head>`, and `<title>` = `"<id> · <title> — NallaBox"`. `data-states` is optional; the first state is the default. Each state's markup is shown with `[data-show-state="<name>"]` wrappers that `frame.js` toggles.

### Manifest IDs (exact; `surface` → ids)

- `tv`: T1…T10, R1…R5, C1…C6, I1…I6
- `phone`: P1…P13, R1…R5, C1-witness, C1-artist, C2-witness, C2-artist, C3-witness, C3-artist, C4, C5, C6, I1-insider, I1-trader, I2-insider, I2-trader, I3, I4, I5, I6
- `host-iphone`: H1…H8
- `host-mac`: M1…M5

Each entry: `{"id": "T1", "title": "Lobby, empty", "surface": "tv", "path": "tv/T1.html", "group": "Shell"}`. Groups, in order: `Shell`, `Redacted`, `Composite Sketch`, `Insider Trading`, `iPhone host`, `Mac host`. Titles come from the spec tables (§7).

---

### Task 1: Foundation — tokens, frame, manifest, index, test harness

**Files:**
- Create: `design/mockups/shared/tokens.css`, `base.css`, `frame.css`, `frame.js`, `screens.js`, `fonts/nunito-wght.woff2`, `design/mockups/index.html`
- Create: `tests/design/helpers.py`, `tests/design/test_manifest.py`, `tests/design/test_tokens.py`

**Interfaces:**
- Produces (Python, `tests/design/helpers.py`): `ROOT: Path` (= `design/mockups`), `load_manifest() -> list[dict]` (JSON between the first `[` and last `]` of `screens.js`), `read_page(path: str) -> str`, `css_tokens() -> dict[str, str]` (every `--nb-*` in `tokens.css`, name without `--`), `swift_tokens() -> dict[str, str]` (Task 2 fills it in), `spec_ids() -> dict[str, list[str]]` (the Manifest IDs above, hard-coded).
- Produces (CSS tokens, names exact): `--nb-color-{ink, ink-raised, ink-line, coral, coral-press, text, text-dim, success, danger, paper}`, `--nb-player-{saffron, sky, mint, lilac, pink, lime, teal, sand}`, `--nb-tv-{display,title,heading,body,label,caption}-{size,weight}`, `--nb-phone-{…same…}-{size,weight}`, `--nb-space-{1..12}` (4 px steps), `--nb-radius-{sm,md,lg,xl}` = 8/14/22/32 px, `--nb-tv-safe` = 80px, `--nb-face-size` = 160px, `--nb-dur-{tap,screen,reveal}` = 150/250/400ms.
- Produces (JS): `window.NB_SCREENS` (array); `frame.js` reads `body[data-screen]`, finds its entry, wraps `main.screen` in a frame sized to the surface canvas, adds a top bar (ID · title · prev · index · next · state buttons · fit/100% toggle for TV and Mac), honours `?w=<px>` (phone width) and `?text=<scale>` (sets `--nb-text-scale` on `:root`), sets `body[data-state]`.

- [ ] **Step 1: Write failing tests** in `test_manifest.py` and `test_tokens.py`:
  - `test_manifest_covers_spec_ids`: for each surface, `sorted(ids in manifest for surface) == sorted(spec_ids()[surface])`.
  - `test_manifest_paths_unique_and_well_formed`: every `path == f"{surface}/{id}.html"`, ids unique, group in the six groups.
  - `test_index_links_every_screen`: `index.html` contains `href="<path>"` for every manifest entry.
  - `test_no_remote_urls`: no `http://` or `https://` in any `.html/.css/.js` under `design/mockups` (excluding `<svg xmlns=…>` namespace strings).
  - `test_pages_follow_contract_<surface>` (one per surface, skipped with `unittest.skip` reason "built in Task N" until that task): each manifest page for the surface exists, has `data-screen="<id>"`, `data-surface="<surface>"`, the four stylesheet links, both scripts, and the title pattern.
  - `test_color_tokens_match_spec`: `css_tokens()["nb-color-ink"] == "#1E1B2E"` … all 10 colours and 8 player colours with the §9.1 hex values; `"#FF5C39"` not among player colours.
  - `test_type_tokens_match_spec`: TV display 120/900, title 72/900, heading 52/800, body 40/700, label 32/800, caption 36/700; phone 40/900, 28/800, 22/800, 17/700, 13/800, 15/600.
  - `test_text_dim_contrast`: WCAG contrast of `text-dim` on `ink` ≥ 4.5 and `text` on `ink` ≥ 12.

- [ ] **Step 2: Run** `python3 -m unittest discover -s tests/design -v` — Expected: FAIL (files missing).

- [ ] **Step 3: Get the font.** Ask the user before downloading. Then fetch the Nunito variable latin woff2 from `https://unpkg.com/@fontsource-variable/nunito@5.1.0/files/nunito-latin-wght-normal.woff2` into `shared/fonts/nunito-wght.woff2` (OFL; record the source and licence in `shared/fonts/README.md`).

- [ ] **Step 4: Implement** `tokens.css`, `base.css` (`@font-face` Nunito 200–1000 from the local file; `body` background `--nb-color-ink`, colour `--nb-color-text`; `html { font-size: calc(16px * var(--nb-text-scale, 1)) }`), `screens.js` (all entries, titles from §7), `frame.js`/`frame.css` per the Interfaces block (TV and Mac scale-to-fit by default; phone and iPhone host at 100%), and `index.html` (groups in order, each screen as a link card with ID and title; Night stage styling).

- [ ] **Step 5: Run** the tests — Expected: PASS, with per-surface contract tests reported as skipped.

- [ ] **Step 6: Visual check.** Open `index.html` in the browser pane; confirm Nunito renders (not a fallback) and links resolve.

---

### Task 2: SwiftUI token file

**Files:**
- Create: `design/NallaBoxTheme.swift`, `design/mockups/shared/fonts/Nunito[wght].ttf`
- Modify: `tests/design/helpers.py` (`swift_tokens`), `tests/design/test_tokens.py`

**Interfaces:**
- Consumes: `css_tokens()` (Task 1).
- Produces (Swift): `extension Color { init(hex: UInt32, opacity: Double = 1) }`; `enum NB` with `enum Palette` (static `Color`s named `ink, inkRaised, inkLine, coral, coralPress, text, textDim, success, danger, paper`), `enum PlayerColor: CaseIterable` (`saffron … sand`, `var color: Color`), `enum TVType` / `enum PhoneType` (static `Font`s `display, title, heading, body, label, caption` = `Font.custom("Nunito", size: <pt>).weight(<w>)`), `enum Space` (`static func s(_ n: Int) -> CGFloat` = 4·n), `enum Radius` (`sm, md, lg, xl`), `enum Motion` (`tap 0.15, screen 0.25, reveal 0.4`, `spring = Animation.spring(response: 0.35, dampingFraction: 0.8)`), `static let tvSafeInset: CGFloat = 80`, `static let faceSize: CGFloat = 160`.
- `swift_tokens()` returns `{"nb-color-ink": "#1E1B2E", …, "nb-player-saffron": "#FFB020", …}` parsed from `Color(hex: 0x……)` lines using the CSS token names (camelCase → kebab).

- [ ] **Step 1: Write failing test** `test_swift_colors_match_css`: for every `nb-color-*` and `nb-player-*` key in `css_tokens()`, `swift_tokens()[key].upper() == css_tokens()[key].upper()`.
- [ ] **Step 2: Run** — Expected: FAIL (file missing).
- [ ] **Step 3: Implement** `NallaBoxTheme.swift`; copy `Nunito[wght].ttf` (ask before downloading from `https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf`) and add a header comment: register the font in Info.plist `UIAppFonts` / `ATSApplicationFontsPath`.
- [ ] **Step 4: Run** the tests — Expected: PASS. Then `xcrun swiftc -typecheck -sdk "$(xcrun --sdk macosx --show-sdk-path)" design/NallaBoxTheme.swift` — Expected: no output, exit 0.

---

### Task 3: Component library

**Files:**
- Create: `design/mockups/shared/components.css`, `design/mockups/components.html`, `tests/design/test_components.py`

**Interfaces:**
- Consumes: tokens (Task 1).
- Produces (CSS classes, exact): `.avatar` (+ `.avatar--s/m/l` = 32/48/96, `data-player="<colour>"`, initial inside), `.player-chip` (+ `.is-submitted`, `.is-offline`, `.is-leader`), `.seat` (empty, dashed), `.timer-pill` (+ `.is-urgent` pulses), `.answer-tile` (+ `.is-selected`, `.is-mine`, `.is-real`, `.is-fake` with `.answer-tile__author`), `.btn` (+ `.btn--primary/secondary/destructive`, `[disabled]` with `.btn__reason` below), `.field` (+ `.is-focus`, `.is-error`, `.field__counter`), `.swatches`, `.stepper`, `.segmented`, `.toggle`, `.hold-card` (+ `.is-held`; content in `[data-secret]`), `.chip-slider`, `.draw-toolbar`, `.lb-row` (rank, avatar, name, points, `.lb-row__delta`), `.toast`, `.banner`, `.leader-pill`, `.sheet`, `.face-corner` (face img + `.face-corner__caption`), `.phone-action` (bottom-pinned 56 px primary area), `.tv-safe` (80 px inset container).

- [ ] **Step 1: Write failing test** `test_gallery_shows_every_component_and_state`: `components.html` contains each class above and each state modifier listed.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `components.css` (TV sizes via `.surface-tv` ancestor, phone sizes via `.surface-phone`, set by `frame.js` from `data-surface`) and `components.html` showing every component in every state, at TV and phone scale, using the longest sample content (`Wolfgangster`, `competitive soup kitchen!`).
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot `components.html` and check: no overflow on the long samples, disabled buttons show their reason, coral used only per §9.1.

---

### Task 4: The face

**Files:**
- Create: `design/mockups/shared/face/face-{idle,blink,wink,grin,gasp,suspicious,sleepy,celebrate}.svg`, `design/mockups/shared/img/nallabox-symbol-color.svg` (copy from `logo/kit/master/`), `design/mockups/faces.html`, `tests/design/test_faces.py`

**Interfaces:**
- Consumes: logo geometry from `logo/kit/master/nallabox-symbol-color.svg` (body `rrect 32..224 r52`, eye `68..120 × 76..128 r12`, pupil `84..104 × 92..112`, wink bar `136..188 × 94..110 r8`, smile annulus centre `(128,92)` radii 80/64, 60°→120°).
- Produces: 8 SVGs, all `viewBox="32 32 192 192"`; CSS class `.face-swap` in `components.css` (180 ms squash: scaleY 0.9 → 1, `prefers-reduced-motion` → opacity fade).

State geometry (§9.5): idle = logo; blink = open eye replaced by a bar like the wink; wink = logo; grin = right eye open (same as left), smile radii 92/76 over 55°→125°; gasp = smile replaced by an O (ring, outer r 18, inner r 10, centre (128,160)); suspicious = both eyes as bars 12 px tall, smile replaced by a flat bar `100..156 × 152..164 r6`; sleepy = both eyes as bars drooping 4 px lower, smile radii 72/60; celebrate = grin with both eyes as upward arcs (r 20, 16 px thick).

- [ ] **Step 1: Write failing test** `test_eight_face_states`: 8 files exist, each parses with `xml.etree`, has `viewBox="32 32 192 192"`, uses only `#FF5C39` and `#FFFFFF` fills.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the SVGs (white features drawn under the coral body with holes, as in the logo master) and `faces.html` (all 8 at 160 px on ink with their trigger and sample caption from §9.5, plus a "cycle" button using `.face-swap`).
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot `faces.html`: every state reads as the same character; differences are visible at 160 px.

---

### Task 5: TV shell screens T1–T10

**Files:** Create `design/mockups/tv/T1.html` … `T10.html`; Modify: un-skip `test_pages_follow_contract_tv` for T-ids (the test filters to ids that start with `T` until Task 9 un-skips the rest); Modify `tests/design/test_review_focus.py`.

**Interfaces:** Consumes the page contract, components (Task 3), faces (Task 4). Content per spec §7.1 rows; flows §8.

Pinned content: room code `KWPX`; join URL `192.168.1.24:8080`; players in order Priya (saffron, leader), Sam (sky), Marcus (mint), Lena (lilac), Wolfgangster (pink), Aiko (lime), Dev (teal), Rosa (sand); T1 caption "Scan to join."; T3 is T1's layout with the Wi-Fi help panel replacing the empty seats; T10 awards "Best Liar" and "Most Wanted".

- [ ] **Step 1: Write failing tests** `test_tv_lobby_full_room` (T2 has 8 `.player-chip`, one `.is-leader`, and the name `Wolfgangster`) and `test_tv_results_full_room` (T10 has 8 `.lb-row`).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build** T1–T10 per §7.1, every layout inside `.tv-safe`, face corner on every screen except T7 (face sleepy centred) and T10 (celebrate, large).
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot each at 1920×1080: nothing inside the 80 px border, no text under 30 px.

---

### Task 6: Phone shell screens P1–P13

**Files:** Create `design/mockups/phone/P1.html` … `P13.html`; Modify: un-skip the phone contract test for P-ids.

**Interfaces:** Consumes components (`.phone-action`, `.field`, `.swatches`, `.leader-pill`, `.sheet`). Content per §7.2 rows; control model §6.

Pinned content: P2 states `wrong-code`, `room-full`, `name-taken`, `in-progress` with the copy in §7.2; P4 Start disabled reason "Need 3 players to start"; P6 Start disabled state for Insider Trading "Insider Trading needs 4 players"; P13 actions in the §6 order with confirm states for End game and Remove player.

- [ ] **Step 1: Write failing test** `test_phone_pages_have_one_primary_action`: each P page has at most one `.btn--primary` per state and it sits inside `.phone-action` (P8, P9, P10 may have none).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build** P1–P13; every state listed in `data-states`.
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot at 393×852.

---

### Task 7: Redacted (TV R1–R5, phone R1–R5)

**Files:** Create `design/mockups/tv/R1.html` … `R5.html`, `design/mockups/phone/R1.html` … `R5.html`; Modify `test_review_focus.py`.

Pinned content: passage "The Great Fire of London began in a ▮▮▮ on Pudding Lane in ▮▮▮." (2 blanks); the real words `bakery`, `1666`; fakes include `competitive soup kitchen` (24 characters with the trailing context) and `goose sanctuary`; R1 error state copy "Too close to the real word, try another"; R4 scoring copy per §7.3 (+1,000 for spotting, +500 per player fooled); R5 shows all 8 players.

- [ ] **Step 1: Write failing tests** `test_redacted_long_answer` (tv/R3 contains `competitive soup kitchen` inside an `.answer-tile`) and `test_redacted_scores_full_room` (tv/R5 has 8 `.lb-row`).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build** the 10 pages per §7.3 Redacted table; phone R3 marks the player's own version `.is-mine` and unvotable.
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot TV pages: 6 answer tiles fit at Body 40 without wrapping past 2 lines.

---

### Task 8: Composite Sketch (TV C1–C6, phone pages)

**Files:** Create `design/mockups/tv/C1.html` … `C6.html`; phone `C1-witness`, `C1-artist`, `C2-witness`, `C2-artist`, `C3-witness`, `C3-artist`, `C4`, `C5`, `C6` (.html); `design/mockups/shared/img/scene-raccoon.svg` and `drawing-1.svg` … `drawing-7.svg` (simple hand-drawn-style SVG strokes); Modify `test_review_focus.py`.

Pinned content: Witness Lena; scene caption "A raccoon in a tuxedo robbing a bakery"; banned words `raccoon`, `tuxedo`; canvas tools exactly 6 colours (white, coral, saffron, sky, mint, lilac), 3 brush sizes, undo, clear; scene shown only in `[data-secret]` on witness pages.

- [ ] **Step 1: Write failing tests** `test_sketch_lineup_full_room` (tv/C3 has 7 drawing tiles) and `test_scene_only_on_witness` (`scene-raccoon` appears in phone/C1-witness, C2-witness and tv/C4 only).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build** the 15 pages per §7.3 Composite Sketch table.
- [ ] **Step 4: Run** tests — Expected: PASS. Screenshot tv/C3: 7 drawings plus labels inside the safe area.

---

### Task 9: Insider Trading (TV I1–I6, phone pages)

**Files:** Create `design/mockups/tv/I1.html` … `I6.html`; phone `I1-insider`, `I1-trader`, `I2-insider`, `I2-trader`, `I3`, `I4`, `I5`, `I6` (.html); Modify `test_review_focus.py`; un-skip all remaining contract tests.

Pinned content: question "Which planet has the most known moons?" choices A Jupiter, B Saturn, C Uranus, D Neptune; answer B; Insider Marcus; starting chips 5,000; bet slider 100–1,000 step 100; I6 copy for both outcomes ("Marcus escaped with a 10% cut" / "Caught! Marcus pays 300 chips to each accuser").

- [ ] **Step 1: Write failing test** `test_role_cards_identical_at_rest`: strip every `[data-secret]` element (and its contents) from phone/I1-insider and phone/I1-trader `main.screen`; the remaining markup, normalised for whitespace, is identical. Same for I2.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Build** the 14 pages per §7.3 Insider Trading table; `.hold-card` reveals on press-and-hold (pointer down ≥ 300 ms) and hides on release.
- [ ] **Step 4: Run** the full suite — Expected: PASS with no skipped contract tests for tv and phone.

---

### Task 10: iPhone host H1–H8

**Files:** Create `design/mockups/host-iphone/H1.html` … `H8.html`; un-skip `test_pages_follow_contract_host_iphone`.

Pinned content: H2 copy explains "NallaBox needs your local network so friends' phones can reach this iPhone" and a `denied` state with "Open Settings"; H3 Continue disabled until the `connected` state; H5 = host strip (room code `KWPX`, player count, Pause, menu) above an `<iframe src="../phone/P4.html?embed=1">` (frame.js hides its own chrome when `embed=1`); H6 actions match §7.4.

- [ ] **Step 1: Run** the un-skipped contract test — Expected: FAIL.
- [ ] **Step 2: Build** H1–H8 using iOS conventions (large title, sheet for H6) in Night stage colours.
- [ ] **Step 3: Run** — Expected: PASS. Screenshot H5: the embedded controller is fully usable below the host strip at 393×852.

---

### Task 11: Mac host M1–M5

**Files:** Create `design/mockups/host-mac/M1.html` … `M5.html`; un-skip `test_pages_follow_contract_host_mac`.

Pinned content: M2 left column 360 px (room code, QR, player list with remove buttons, network health "8 connected · good"), right a scaled live preview of `../tv/T2.html` in an iframe, toolbar Pause / Skip / End / Settings; M3 shows the single-display state with the top-edge control bar; M4 checklist per §7.5.

- [ ] **Step 1: Run** the un-skipped contract test — Expected: FAIL.
- [ ] **Step 2: Build** M1–M5 at 1280×800 with macOS window chrome (traffic lights, toolbar).
- [ ] **Step 3: Run** — Expected: PASS. Screenshot M2 at 1280×800 and 960×640: nothing clipped at the minimum size.

---

### Task 12: Screenshot pass and Review Focus 2–3

**Files:** Create `tests/design/shoot.py`; output to `design/mockups/_shots/` (generated, not hand-edited).

**Interfaces:** `shoot.py [--surface S] [--w PX] [--text SCALE]` renders each manifest page with Chrome headless (`--headless=new --screenshot --window-size=W,H`, sizes from the surface canvas plus the frame bar) into `_shots/<surface>/<id>[-w360][-t130].png`.

- [ ] **Step 1: Run** `python3 tests/design/shoot.py` — Expected: one PNG per manifest entry (75), no errors.
- [ ] **Step 2: Run** `python3 tests/design/shoot.py --surface phone --w 360` and `--surface phone --text 1.3`. Look at every phone PNG: no sideways scroll, primary action visible and unclipped. Fix and re-shoot until clean.
- [ ] **Step 3: Run** the full suite `python3 -m unittest discover -s tests/design -v` — Expected: all PASS, 0 skipped.
- [ ] **Step 4: Anti-goal review** against §2: no secret outside `[data-secret]` on the owning phone; no TV text under 30 px; every phone screen's next action obvious; no host-device action needed during play. Record results in `design/mockups/REVIEW.md`.
