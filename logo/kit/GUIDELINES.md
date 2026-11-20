# NallaBox — Logo Guidelines

## 1. The logo
- **Idea:** a QR-code eye that winks. Guests scan to join, then bluff their friends; the smile keeps it friendly.
- **Versions:** horizontal (primary) · stacked · symbol · wordmark · app icon
- **Masters:** `master/*.svg`. PNGs for quick use are in `png/`, `symbol/` and `lockups/`.

| Use | File |
|---|---|
| Website header, slides, docs | `master/nallabox-horizontal.svg` |
| Square or tall spaces (posters, splash screen, merch) | `master/nallabox-stacked.svg` |
| Avatars, stickers, in-game corner | `master/nallabox-symbol-color.svg` |
| On Night Ink or dark photos | `master/nallabox-horizontal-reversed.svg`, `-stacked-reversed.svg` |
| One colour (print, engraving, fax-grade) | `*-black.svg`, `*-white.svg`, `symbol/*-mono-*.svg` |
| iOS / Android app icon | `app-icon/nallabox-app-icon.svg` (full bleed; the OS applies the corner mask) |
| Browser tab, PWA, touch icons | `web-icons/` (paste `head-snippet.html` into `<head>`) |
| 16–32 px | `master/nallabox-symbol-small*.svg` (bigger features, drawn for small sizes) |

## 2. Clear space
Keep clear space of **1 × the eye** (the square eye's height) on every side of the logo. It scales with the logo.

## 3. Minimum size
| Version | Screen | Print |
|---|---|---|
| Horizontal | 120 px wide | 30 mm wide |
| Stacked | 64 px wide | 18 mm wide |
| Symbol | 16 px (use the small cut) | 6 mm |

## 4. Colour
| Name | HEX | RGB | CMYK (approx.) | Pantone (nearest) |
|---|---|---|---|---|
| Nalla Coral | #FF5C39 | 255 92 57 | 0 75 80 0 | 171 C |
| Night Ink | #1E1B2E | 30 27 46 | 75 72 35 80 | 5255 C |
| Paper | #FFF4EA | 255 244 234 | 0 4 8 0 | — |

CMYK and Pantone values are nearest matches; check them against a printed swatch before a print run.

**Approved logo and background pairs:** full colour on white or Paper · full colour on Night Ink (the reversed lockup, white wordmark) · white features on a Coral tile (app icon, merch) · black on white · white on black.

**Text on colour:** white on Coral is 3.1:1, which is fine for the logo and large headlines, but too low for body text. Set small text on Coral in Night Ink.

## 5. Typography
- **Wordmark:** custom drawn shapes. Never retype "nallabox" in a font to stand in for it.
- **Headlines:** Nunito ExtraBold (SIL Open Font Licence). Its rounded ends match the wordmark.
- **Body and UI:** the system font (SF Pro on Apple devices; `system-ui` on the web).

## 6. The face in motion (optional)
The face is built for small animations: the open eye blinks, the wink opens, the smile widens on a win. Keep the shapes and proportions; animate only position, scale or a squash of 10% or less.

## 7. Don'ts
- Don't stretch, squash or rotate the logo.
- Don't recolour outside the palette, or add gradients, shadows or outlines.
- Don't swap the eyes (the wink is always on the right) or change the features.
- Don't rearrange or resize the parts of a lockup.
- Don't put the full-colour symbol on Coral: use the white-features app-icon style instead.
- Don't place it on busy photos without a solid container.

## 8. Before launch
- Run a professional trademark search on the name and the mark; this kit includes no clearance check.
- The wordmark is original geometry, so no font licence is needed for the logo itself.
