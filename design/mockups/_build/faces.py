"""The 8 face states (spec §9.5) drawn from the logo geometry, plus faces.html."""
import math
from pathlib import Path

from kit import E

ROOT = Path(__file__).resolve().parent.parent
CORAL, WHITE = "#FF5C39", "#FFFFFF"
BODY = "M84 32H172A52 52 0 0 1 224 84V172A52 52 0 0 1 172 224H84A52 52 0 0 1 32 172V84A52 52 0 0 1 84 32Z"


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def rrect(x0, y0, x1, y1, r):
    return (f"M{f(x0 + r)} {f(y0)}H{f(x1 - r)}A{f(r)} {f(r)} 0 0 1 {f(x1)} {f(y0 + r)}V{f(y1 - r)}"
            f"A{f(r)} {f(r)} 0 0 1 {f(x1 - r)} {f(y1)}H{f(x0 + r)}A{f(r)} {f(r)} 0 0 1 {f(x0)} {f(y1 - r)}"
            f"V{f(y0 + r)}A{f(r)} {f(r)} 0 0 1 {f(x0 + r)} {f(y0)}Z")


def circle(cx, cy, r):
    return f"M{f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 1 0 {f(cx + r)} {f(cy)}A{f(r)} {f(r)} 0 1 0 {f(cx - r)} {f(cy)}Z"


def arc_band(cx, cy, ro, ri, a0, a1):
    """Annular sector from angle a0 to a1 (degrees, SVG y-down) with round caps."""
    rc = (ro - ri) / 2
    p = lambda r, a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    o0, o1, i1, i0 = p(ro, a0), p(ro, a1), p(ri, a1), p(ri, a0)
    return (f"M{f(o0[0])} {f(o0[1])}A{f(ro)} {f(ro)} 0 0 1 {f(o1[0])} {f(o1[1])}"
            f"A{f(rc)} {f(rc)} 0 0 1 {f(i1[0])} {f(i1[1])}A{f(ri)} {f(ri)} 0 0 0 {f(i0[0])} {f(i0[1])}"
            f"A{f(rc)} {f(rc)} 0 0 1 {f(o0[0])} {f(o0[1])}Z")


# Building blocks (logo coordinates)
def qr_eye(x0):           # open eye: white rounded square with a coral pupil
    return rrect(x0, 76, x0 + 52, 128, 12), rrect(x0 + 16, 92, x0 + 36, 112, 4)


def bar(x0, y0=94, h=16):  # closed eye / wink
    return rrect(x0, y0, x0 + 52, y0 + h, h / 2), ""


SMILE = arc_band(128, 92, 80, 64, 60, 120)
GRIN = arc_band(128, 92, 92, 76, 55, 125)

STATES = {
    # name: (features, cores)
    "idle": [qr_eye(68), bar(136), (SMILE, "")],
    "wink": [qr_eye(68), bar(136), (SMILE, "")],
    "blink": [bar(68), bar(136), (SMILE, "")],
    "grin": [qr_eye(68), qr_eye(136), (GRIN, "")],
    "gasp": [qr_eye(68), qr_eye(136), (circle(128, 164, 18), circle(128, 164, 10))],
    "suspicious": [bar(68, 96, 12), bar(136, 96, 12), (rrect(100, 152, 156, 164, 6), "")],
    "sleepy": [bar(68, 98, 14), bar(136, 98, 14), (arc_band(128, 96, 72, 60, 62, 118), "")],
    "celebrate": [(arc_band(94, 116, 28, 12, 200, 340), ""), (arc_band(162, 116, 28, 12, 200, 340), ""), (GRIN, "")],
}

INFO = {  # trigger, sample caption (spec §9.5)
    "idle": ("Default", ""),
    "blink": ("Random while idle, every 4–7 s", ""),
    "wink": ("Lobby, round start", "Scan to join."),
    "grin": ("Points awarded", "Sam fooled three of you."),
    "gasp": ("Reveals, real answer shown", "That one was real?!"),
    "suspicious": ("Insider discuss/accuse, Witness phase", "Someone here knows the answer."),
    "sleepy": ("Pause; last 5 s of a timer", "Paused. Take your time."),
    "celebrate": ("Final results", "And the winner is Priya!"),
}


def svg(name):
    feats = "".join(a for a, _ in STATES[name])
    cores = "".join(b for _, b in STATES[name])
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="32 32 192 192" width="192" height="192">'
            f'<title>NallaBox face, {name}</title><path fill="{WHITE}" d="{feats}"/>'
            f'<path fill="{CORAL}" fill-rule="evenodd" d="{BODY}{feats}{cores}"/></svg>\n')


def write_svgs():
    d = ROOT / "shared" / "face"
    d.mkdir(parents=True, exist_ok=True)
    for name in STATES:
        (d / f"face-{name}.svg").write_text(svg(name))


def build():
    write_svgs()
    cards = "".join(
        f'<div class="fc"><img class="face" src="shared/face/face-{n}.svg" alt="{n}"><h3>{n}</h3>'
        f'<p class="t-dim">{E(INFO[n][0])}</p>{f"<p class=cap>{E(INFO[n][1])}</p>" if INFO[n][1] else ""}</div>'
        for n in STATES)
    order = ",".join(f"'{n}'" for n in STATES)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Face states — NallaBox</title>
<link rel="stylesheet" href="shared/tokens.css"><link rel="stylesheet" href="shared/base.css"><link rel="stylesheet" href="shared/components.css">
<style>
 body {{ background: var(--nb-color-ink); padding: 32px; }}
 h1 {{ font-size: 36px; font-weight: 900; }} .lede {{ color: var(--nb-color-text-dim); font-weight: 700; margin: 4px 0 24px; }}
 .lede a {{ color: var(--nb-color-coral); }}
 .grid {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; }}
 .fc {{ background: var(--nb-color-ink-raised); border-radius: var(--nb-radius-lg); padding: 24px; display: flex; flex-direction: column; align-items: center; gap: 8px; text-align: center; }}
 .fc .face {{ width: 160px; height: 160px; }} .fc h3 {{ font-size: 22px; font-weight: 900; text-transform: capitalize; }}
 .fc p {{ font-weight: 700; font-size: 15px; }} .cap {{ background: var(--nb-color-paper); color: var(--nb-color-ink); padding: 6px 12px; border-radius: 12px; }}
 .demo {{ margin-top: 32px; display: flex; align-items: center; gap: 24px; }}
 .demo img {{ width: 160px; height: 160px; }}
</style></head>
<body>
<h1>Face states</h1>
<p class="lede">Spec §9.5 · drawn from the logo master · shown at 160 px, the TV corner size. <a href="index.html">All screens</a></p>
<div class="grid">{cards}</div>
<div class="demo"><img id="demo" class="face" src="shared/face/face-idle.svg" alt="">
<button class="btn btn--primary" style="width:auto" onclick="nbNext()">Next state (180 ms squash)</button><span id="demo-name" class="t-heading">idle</span></div>
<script>
 const S = [{order}]; let i = 0; const img = document.getElementById('demo');
 function nbNext() {{ i = (i + 1) % S.length; img.src = 'shared/face/face-' + S[i] + '.svg';
   document.getElementById('demo-name').textContent = S[i]; img.classList.remove('face-swap'); void img.offsetWidth; img.classList.add('face-swap'); }}
</script>
</body></html>
"""
