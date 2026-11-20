"""Composite Sketch: TV C1–C6, phone Witness/Artist pages (spec §7.3).
Witness: Lena. Artists draw #1–#7 in this order; the Witness picks #3 (Marcus); Most Wanted is #6 (Dev).
The scene image appears only on the Witness's phone (inside [data-secret]) and at the TV reveal (C4)."""
import random
from pathlib import Path

from kit import E, PLAYERS, avatar, btn, chip, face, leaderboard, phone_action, phone_top, state, statusbar, timer, tv_top

IMG = Path(__file__).resolve().parent.parent / "shared" / "img"
COLOUR = dict(PLAYERS)
WITNESS = "Lena"
ARTISTS = [n for n, _ in PLAYERS if n != WITNESS]          # Priya, Sam, Marcus, Wolfgangster, Aiko, Dev, Rosa
PICK, WORST, ME = 3, 6, "Sam"                               # Sam drew #2
CAPTION = "A raccoon in a tuxedo robbing a bakery"
BANNED = ["raccoon", "tuxedo"]
TOP = "Composite Sketch · Round 4 of 8"

CSS = """<style>
.drawings { display: grid; grid-template-columns: repeat(4, 1fr); gap: 24px; }
.drawing-tile { position: relative; aspect-ratio: 1; border-radius: var(--nb-radius-lg); overflow: hidden; background: #F6F1EA; border: 4px solid transparent; }
.drawing-tile img { width: 100%; height: 100%; }
.drawing-tile__num { position: absolute; left: 10px; top: 10px; min-width: 1.6em; height: 1.6em; padding: 0 .3em; border-radius: 10px; display: grid; place-items: center;
  background: var(--nb-color-ink); color: #fff; font-weight: 900; }
.drawing-tile__who { position: absolute; left: 10px; right: 10px; bottom: 10px; display: flex; align-items: center; gap: 8px; padding: 6px 10px; border-radius: 12px;
  background: rgba(30,27,46,.88); font-weight: 800; }
.drawing-tile.is-selected { border-color: var(--nb-color-coral); }
.drawing-tile.is-mine { opacity: .45; }
.surface-tv .drawing-tile__num { font-size: 32px; }
.surface-phone .drawing-tile__num { font-size: calc(13px * var(--nb-text-scale, 1)); left: 6px; top: 6px; border-radius: 6px; }
.surface-tv .drawing-tile__who { font-size: 30px; }
.lineup { display: grid; grid-template-columns: repeat(4, 380px); gap: 24px; justify-content: center; }
.thumbs { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.countdown { font-size: 220px; font-weight: 900; line-height: 1; color: var(--nb-color-coral); font-variant-numeric: tabular-nums; }
.artist-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.artist-grid .avatar { --avatar: 52px; font-size: 26px; }
.artist-grid .player-chip { font-size: 36px; }
.witness-hero { display: flex; align-items: center; gap: 48px; }
.reveal { display: grid; grid-template-columns: 1fr 1fr; gap: 64px; align-items: start; }
.reveal figure { margin: 0; display: flex; flex-direction: column; gap: 16px; }
.reveal figure img, .reveal .drawing-tile { width: 640px; height: 480px; border-radius: var(--nb-radius-xl); object-fit: cover; }
.reveal figure p { white-space: nowrap; }
.scene-img { width: 100%; aspect-ratio: 4 / 3; border-radius: var(--nb-radius-md); }
.banned { display: flex; gap: 8px; flex-wrap: wrap; justify-content: center; }
.banned span { padding: 4px 10px; border-radius: 8px; background: var(--nb-color-ink); color: var(--nb-color-danger); font-weight: 900; text-decoration: line-through; }
.ph-canvas { border-radius: var(--nb-radius-lg); overflow: hidden; background: #F6F1EA; aspect-ratio: 1; }
.ph-canvas img { width: 100%; height: 100%; }
.tv-foot { display: flex; justify-content: space-between; color: var(--nb-color-text-dim); font-size: var(--fs-caption); font-weight: 700; margin-top: auto; }
.points-big { font-size: 48px; font-weight: 900; color: var(--nb-color-success); }
</style>"""


# ---------- art ----------
def scene_svg():
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300" width="400" height="300"><title>Scene: a raccoon in a tuxedo robbing a bakery</title>
<rect width="400" height="300" fill="#F9E3C8"/><rect y="230" width="400" height="70" fill="#C98E5A"/>
<rect x="30" y="40" width="210" height="190" rx="6" fill="#8C4A2F"/><rect x="45" y="80" width="180" height="120" rx="4" fill="#BFE3F0"/>
<rect x="55" y="48" width="160" height="26" rx="6" fill="#FFF4EA"/><text x="135" y="67" font-family="sans-serif" font-size="18" font-weight="900" text-anchor="middle" fill="#8C4A2F">BAKERY</text>
<g fill="#E8B04A"><ellipse cx="85" cy="185" rx="22" ry="10"/><ellipse cx="135" cy="185" rx="22" ry="10"/><ellipse cx="185" cy="185" rx="22" ry="10"/></g>
<g transform="translate(290 120)"><ellipse cx="0" cy="90" rx="44" ry="62" fill="#7D7A85"/><path d="M-44 70 L0 150 L44 70 Z" fill="#1E1B2E"/><path d="M-8 64 L0 120 L8 64Z" fill="#fff"/>
<path d="M-14 62 L0 70 L14 62 L14 76 L0 70 L-14 76Z" fill="#FF5C39"/><circle cx="0" cy="18" r="36" fill="#9A97A3"/><path d="M-30 -6 L-22 -34 L-8 -12Z M30 -6 L22 -34 L8 -12Z" fill="#7D7A85"/>
<path d="M-34 14 Q0 -2 34 14 L30 26 Q0 14 -30 26Z" fill="#1E1B2E"/><circle cx="-12" cy="18" r="5" fill="#fff"/><circle cx="12" cy="18" r="5" fill="#fff"/><circle cx="0" cy="34" r="5" fill="#1E1B2E"/>
<rect x="40" y="60" width="70" height="18" rx="9" fill="#E8B04A" transform="rotate(-20 40 60)"/><path d="M44 110 q30 -10 40 20 q-30 20 -40 -20" fill="#F2E8D5" stroke="#8C4A2F" stroke-width="3"/></g>
</svg>
"""


def wobble(rng, pts, amt):
    return " ".join(f"{x + rng.uniform(-amt, amt):.1f},{y + rng.uniform(-amt, amt):.1f}" for x, y in pts)


def drawing_svg(seed):
    """A crude phone sketch of the scene. Higher seeds get worse."""
    rng = random.Random(seed)
    amt = 2 + seed * 1.2
    s = 0.75 + rng.uniform(-.15, .2)
    cx, cy = 200 + rng.uniform(-40, 40), 150 + rng.uniform(-20, 30)
    ink = ["#1E1B2E", "#1E1B2E", "#FF5C39", "#3DB7FF", "#4ED19A", "#B58CFF"]
    parts = []
    def stroke(pts, col="#1E1B2E", w=6, closed=False):
        tag = "polygon" if closed else "polyline"
        parts.append(f'<{tag} points="{wobble(rng, pts, amt)}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
    import math
    head = [(cx + 46 * s * math.cos(t / 10 * math.pi * 2), cy - 60 * s + 40 * s * math.sin(t / 10 * math.pi * 2)) for t in range(11)]
    stroke(head)
    if seed != 6:
        stroke([(cx - 36 * s, cy - 84 * s), (cx - 30 * s, cy - 118 * s), (cx - 10 * s, cy - 96 * s)])
        stroke([(cx + 36 * s, cy - 84 * s), (cx + 30 * s, cy - 118 * s), (cx + 10 * s, cy - 96 * s)])
    if seed not in (5, 7):
        stroke([(cx - 40 * s, cy - 62 * s), (cx + 40 * s, cy - 62 * s)], w=14)  # mask
    body = [(cx - 40 * s, cy - 20 * s), (cx - 56 * s, cy + 90 * s), (cx + 56 * s, cy + 90 * s), (cx + 40 * s, cy - 20 * s)]
    stroke(body, closed=True)
    stroke([(cx - 14 * s, cy - 16 * s), (cx + 14 * s, cy - 2 * s), (cx + 14 * s, cy - 16 * s), (cx - 14 * s, cy - 2 * s)], col=rng.choice(ink[2:]), w=5, closed=True)
    if seed in (1, 2, 3, 4):
        stroke([(cx + 50 * s, cy + 10 * s), (cx + 120 * s, cy - 20 * s)], col="#FFB020", w=14)  # baguette
    if seed in (1, 3, 4, 5):
        stroke([(40, 40), (40, 250), (130, 250), (130, 40)], col="#8C4A2F", w=5, closed=True)  # shop
    if seed == 6:  # Most Wanted: a potato with legs
        stroke([(cx - 30, cy + 90), (cx - 40, cy + 130)], w=6)
        stroke([(cx + 30, cy + 90), (cx + 40, cy + 130)], w=6)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300" width="400" height="300">'
            f'<rect width="400" height="300" fill="#F6F1EA"/>{"".join(parts)}</svg>\n')


def write_art():
    IMG.mkdir(parents=True, exist_ok=True)
    (IMG / "scene-raccoon.svg").write_text(scene_svg())
    for i in range(1, 8):
        (IMG / f"drawing-{i}.svg").write_text(drawing_svg(i))


write_art()


# ---------- helpers ----------
def drawing(i, show_who=False, selected=False, mine=False):
    who = ""
    if show_who:
        n = ARTISTS[i - 1]
        who = f'<span class="drawing-tile__who">{avatar(n, COLOUR[n], "s")}{E(n)}</span>'
    cls = "drawing-tile" + (" is-selected" if selected else "") + (" is-mine" if mine else "")
    return f'<div class="{cls}"><img src="../shared/img/drawing-{i}.svg" alt="Drawing {i}"><span class="drawing-tile__num">{i}</span>{who}</div>'


def safe(*parts):
    return f'<div class="tv-safe">{"".join(parts)}</div>'


def top(label, t=None, fs="idle", cap=None):
    return tv_top(f'<p class="t-label t-dim">{E(label)}</p>', (timer(t) if t else "") + face(fs, cap))


def ph(body, sub="", action="", center=False):
    wrap = "phone-center" if center else "phone-body"
    return f'{statusbar()}{phone_top(TOP, sub)}<div class="{wrap}">{body}</div>{action}<div class="home-indicator"></div>'


def secret_scene(held, hint):
    held_cls = " is-held" if held else ""
    banned = '<div class="banned">' + "".join(f"<span>{w}</span>" for w in BANNED) + "</div>"
    return (f'<div class="hold-card{held_cls}" role="button" tabindex="0" aria-label="Hold to see the scene" style="min-height:360px"><div class="hold-card__cover"><div class="big-icon">👁</div>'
            f'<p class="t-heading">Hold to see the scene</p><p class="hold-card__hint">{E(hint)}</p></div>'
            f'<div data-secret><img class="scene-img" src="../shared/img/scene-raccoon.svg" alt="The scene">'
            f'<p class="t-heading">{E(CAPTION)}</p><p class="t-label t-dim">Don\'t say</p>{banned}</div></div>')


# ---------- pages ----------
def c1_tv():
    return safe(top(TOP, "0:05", "gasp", "Lena saw something. Listen closely."),
                f'<div class="witness-hero">{avatar(WITNESS, COLOUR[WITNESS], "l")}<div class="stack">'
                '<p class="t-display">Lena is the Witness</p><p class="t-heading t-dim">Everyone else: get ready to draw what Lena describes.</p></div></div>',
                '<div class="tv-foot"><span>Banned words are on</span><span>Drawing starts in 5 s</span></div>'), None, CSS


def c1_witness():
    rest = ph(secret_scene(False, "You'll describe it out loud for 30 seconds. Keep your screen to yourself."), "You're the Witness")
    held = ph(secret_scene(True, ""), "You're the Witness")
    return state("resting", rest) + state("held", held), ["resting", "held"], CSS


def c1_artist():
    return ph('<div class="big-icon">✎</div><p class="t-title">Get ready to draw</p>'
              '<p class="t-body t-dim">Lena will describe a scene out loud. Draw what you hear. No peeking at Lena\'s phone!</p>'
              f'{timer("0:05")}', "You're an Artist", center=True), None, CSS


def c2_tv():
    artists = "".join(chip(n, COLOUR[n]) for n in ARTISTS)
    return safe(top(TOP, None, "suspicious", "Artists: eyes on your own phone."),
                f'<div class="row" style="gap:64px"><p class="countdown">0:24</p><div class="stack"><p class="t-title">Lena, describe it out loud!</p>'
                '<p class="t-heading t-dim">Artists are drawing on their phones.</p></div></div>',
                f'<div class="stack"><p class="t-label t-dim">7 artists drawing</p><div class="artist-grid">{artists}</div></div>'), None, CSS


def c2_witness():
    rest = ph(f'<div class="row" style="justify-content:space-between"><p class="t-heading">Describe it out loud!</p>{timer("0:24")}</div>' +
              secret_scene(False, "Hold to peek again any time."), "You're the Witness")
    held = ph(f'<div class="row" style="justify-content:space-between"><p class="t-heading">Describe it out loud!</p>{timer("0:24")}</div>' +
              secret_scene(True, ""), "You're the Witness")
    return state("resting", rest) + state("held", held), ["resting", "held"], CSS


def toolbar():
    return ('<div class="draw-toolbar"><div class="draw-toolbar__row">' + "".join(
        f'<button class="draw-color{" is-selected" if i == 0 else ""}" style="background:{c}" aria-label="colour"></button>'
        for i, c in enumerate(("#1E1B2E", "#FF5C39", "#FFB020", "#3DB7FF", "#4ED19A", "#B58CFF"))) + '</div><div class="draw-toolbar__row">'
        + "".join(f'<button class="draw-size{" is-selected" if s == 10 else ""}" aria-label="brush"><i style="width:{s}px;height:{s}px"></i></button>' for s in (5, 10, 18))
        + '<span class="grow"></span><button class="draw-tool">↶ Undo</button><button class="draw-tool">Clear</button></div></div>')


def c2_artist():
    return ph(f'<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Draw what Lena describes</p>{timer("0:24")}</div>'
              '<div class="ph-canvas"><img src="../shared/img/drawing-2.svg" alt="Your drawing"></div>' + toolbar(),
              "You're an Artist", phone_action(btn("I'm done"))), None, CSS


def c3_tv():
    tiles = "".join(drawing(i) for i in range(1, 8))
    return safe(top(TOP, "0:20", "suspicious", "Lena, which one did you see?"),
                f'<div class="lineup">{tiles}</div>'), None, CSS + "<style>.lineup .drawing-tile{aspect-ratio:4/3}</style>"


def c3_witness():
    thumbs = "".join(drawing(i, selected=(i == PICK)) for i in range(1, 8))
    return ph(f'<p class="t-heading">Pick the closest match</p><div class="thumbs">{thumbs}</div>',
              "You're the Witness", phone_action(btn(f"Pick #{PICK}"))), None, CSS


def c3_artist():
    return ph(f'<p class="t-label t-dim">Your drawing</p><div style="width:220px">{drawing(2)}</div>'
              '<p class="t-title">Your drawing is up</p><p class="t-body t-dim">Lena is picking the closest match.</p>',
              "You're an Artist", center=True), None, CSS


def c4_tv():
    n = ARTISTS[PICK - 1]
    return safe(top(TOP, None, "gasp", "Nailed it, Marcus."),
                f'<div class="reveal"><figure><p class="t-label t-dim">What Lena saw</p><img src="../shared/img/scene-raccoon.svg" alt="The scene">'
                f'<p class="t-heading">{E(CAPTION)}</p></figure>'
                f'<figure><p class="t-label t-dim">Lena\'s pick · #{PICK}</p>{drawing(PICK, show_who=True)}'
                f'<p class="t-heading"><span class="t-success">+1,000</span> {E(n)} · <span class="t-success">+500</span> Lena</p></figure></div>'), None, CSS


def c4_phone():
    picked = ph('<div class="toast toast--success">Lena picked yours!</div><div style="width:220px">' + drawing(3) + '</div>'
                '<p class="points-big">+1,000</p><p class="t-body t-dim">Closest match to the real scene.</p>', "Scene reveal", center=True)
    not_picked = ph('<p class="t-title">Lena picked Marcus\'s drawing</p><div style="width:220px">' + drawing(3, show_who=True) + '</div>'
                    '<p class="points-big" style="color:var(--nb-color-text-dim)">+0</p><p class="t-body t-dim">Look at the TV to see the real scene.</p>',
                    "Scene reveal", center=True)
    return state("not-picked", not_picked) + state("picked", picked), ["not-picked", "picked"], CSS


def c5_tv():
    tiles = "".join(drawing(i) for i in range(1, 8))
    return safe(top(TOP, "0:15", "grin", "Now vote for the worst likeness."),
                f'<div class="lineup">{tiles}</div>'), None, CSS + "<style>.lineup .drawing-tile{aspect-ratio:4/3}</style>"


def c5_phone():
    def thumbs(sel):
        return "".join(drawing(i, selected=(i == sel), mine=(i == 2)) for i in range(1, 8))
    head = f'<div class="row" style="justify-content:space-between"><p class="t-heading">Vote for the worst one</p>{timer("0:15")}</div>'
    nv = ph(head + '<p class="t-caption t-dim">Yours (#2) is greyed out.</p>' + f'<div class="thumbs">{thumbs(None)}</div>', "Most Wanted")
    v = ph(head + f'<p class="t-caption t-dim">Voted for #{WORST} · tap another to change</p>' + f'<div class="thumbs">{thumbs(WORST)}</div>', "Most Wanted")
    return state("not-voted", nv) + state("voted", v), ["not-voted", "voted"], CSS


SCORES = [("Marcus", "mint", 3500, 1000), ("Lena", "lilac", 3000, 500), ("Priya", "saffron", 2500, None), ("Sam", "sky", 2000, None),
          ("Wolfgangster", "pink", 2000, None), ("Aiko", "lime", 1500, None), ("Rosa", "sand", 1000, None), ("Dev", "teal", 500, None)]


def c6_tv():
    return safe(top(TOP, None, "grin", "Most Wanted goes to Dev's potato."),
                f'<div class="row" style="align-items:stretch;gap:48px"><div style="width:420px" class="stack"><p class="t-label t-coral">Most Wanted</p>'
                f'{drawing(WORST, show_who=True)}</div><div class="grow leaderboard--compact">{leaderboard(SCORES)}</div></div>'), None, \
        CSS + "<style>.leaderboard--compact .lb-row{padding:4px 20px;line-height:1.15}.leaderboard--compact .avatar--m{--avatar:48px}.leaderboard--compact .leaderboard{gap:10px}</style>"


def c6_phone():
    return ph('<p class="t-label t-dim">After round 4</p><p class="points-big" style="color:var(--nb-color-coral)">#4</p>' +
              avatar("Sam", "sky", "l") + '<p class="t-title">2,000 points</p><p class="t-body t-dim">+0 this round · 500 behind Priya</p>'
              '<p class="t-caption t-dim">Next Witness: Wolfgangster</p>', "Scores", center=True), None, CSS


PAGES = {
    ("C1", "tv"): c1_tv, ("C1-witness", "phone"): c1_witness, ("C1-artist", "phone"): c1_artist,
    ("C2", "tv"): c2_tv, ("C2-witness", "phone"): c2_witness, ("C2-artist", "phone"): c2_artist,
    ("C3", "tv"): c3_tv, ("C3-witness", "phone"): c3_witness, ("C3-artist", "phone"): c3_artist,
    ("C4", "tv"): c4_tv, ("C4", "phone"): c4_phone,
    ("C5", "tv"): c5_tv, ("C5", "phone"): c5_phone,
    ("C6", "tv"): c6_tv, ("C6", "phone"): c6_phone,
}
