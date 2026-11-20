"""components.html — every component in every state, at phone and TV scale (spec §9.4)."""
from kit import E, avatar, btn, chip, face, lb_row, seat, timer

LONG_NAME = "Wolfgangster"
LONG_ANSWER = "competitive soup kitchen"


def _sec(title, phone, tv=""):
    tv_html = f'<div class="g-tv screen surface-tv">{tv}</div>' if tv else ""
    return (f'<section class="g-sec"><h2>{E(title)}</h2><div class="g-row">'
            f'<div class="g-phone screen surface-phone">{phone}</div>{tv_html}</div></section>')


def build():
    secs = []
    secs.append(_sec("Avatar · S / M / L",
        '<div class="row">' + "".join(avatar(n, c, s) for (n, c), s in zip([("Priya", "saffron"), ("Sam", "sky"), ("Marcus", "mint")], "sml")) + "</div>",
        '<div class="row">' + "".join(avatar(n, c, s) for (n, c), s in zip([("Priya", "saffron"), ("Sam", "sky"), ("Marcus", "mint")], "sml")) + "</div>"))
    chips = (chip("Priya", "saffron", "leader") + chip(LONG_NAME, "pink") + chip("Sam", "sky", "submitted")
             + chip("Lena", "lilac", "offline") + seat())
    secs.append(_sec("Player chip · joined, leader, submitted, offline · seat", f'<div class="stack">{chips}</div>', f'<div class="g-grid2">{chips}</div>'))
    secs.append(_sec("Timer pill · normal, urgent (last 5 s)", f'<div class="row">{timer("0:42")}{timer("0:04", True)}</div>', f'<div class="row">{timer("0:42")}{timer("0:04", True)}</div>'))
    tiles = (
        f'<div class="answer-tile"><span class="answer-tile__num">1</span><span class="answer-tile__text">{LONG_ANSWER}</span></div>'
        f'<div class="answer-tile is-selected"><span class="answer-tile__num">2</span><span class="answer-tile__text">goose sanctuary</span></div>'
        f'<div class="answer-tile is-mine"><span class="answer-tile__num">3</span><span class="answer-tile__text">wig shop</span><span class="answer-tile__tag">Yours</span></div>'
        f'<div class="answer-tile is-real"><span class="answer-tile__num">4</span><span class="answer-tile__text">bakery</span><span class="answer-tile__tag">Real</span></div>'
        f'<div class="answer-tile is-fake"><span class="answer-tile__num">5</span><span class="answer-tile__text">very small volcano'
        f'<span class="answer-tile__author">{avatar("Sam", "sky", "s")} Sam · fooled 2</span></span><span class="answer-tile__tag">Fake</span></div>')
    secs.append(_sec("Answer tile · default, selected, mine, real, fake with author", f'<div class="stack">{tiles}</div>', f'<div class="g-grid2">{tiles}</div>'))
    buttons = (btn("Join the room") + btn("Change name", "secondary") + btn("End game", "destructive")
               + btn("Start game", disabled_reason="Need 3 players to start"))
    secs.append(_sec("Buttons · primary, secondary, destructive, disabled with reason", f'<div class="stack">{buttons}</div>'))
    fields = (
        '<div class="field"><label class="field__label">Your name</label><input class="field__input" placeholder="Up to 12 letters"></div>'
        f'<div class="field is-focus"><label class="field__label">Your name</label><input class="field__input" value="{LONG_NAME}">'
        '<div class="field__foot"><span class="field__counter">12/12</span></div></div>'
        '<div class="field is-error"><label class="field__label">Blank 1</label><input class="field__input" value="bakery">'
        '<div class="field__foot"><span class="field__error">Too close to the real word, try another</span><span class="field__counter">6/24</span></div></div>')
    secs.append(_sec("Text field · default, focus with counter, error", f'<div class="stack">{fields}</div>'))
    sw = '<div class="swatches">' + "".join(
        f'<button class="swatch{" is-selected" if c == "pink" else ""}{" is-taken" if c == "sky" else ""}" data-player="{c}" aria-label="{c}"></button>'
        for c in ("saffron", "sky", "mint", "lilac", "pink", "lime", "teal", "sand")) + "</div>"
    controls = (sw + '<div class="stepper"><button>−</button><span class="stepper__value">4 rounds</span><button>+</button></div>'
                '<div class="segmented"><button>1×</button><button class="is-selected">1.5×</button><button>2×</button><button>Off</button></div>'
                '<div class="setting-row"><span>Family-friendly</span><button class="toggle is-on" aria-label="on"></button></div>'
                '<div class="setting-row"><span>Banned words</span><button class="toggle" aria-label="off"></button></div>')
    secs.append(_sec("Swatches (selected, taken) · stepper · segmented · toggle", f'<div class="stack">{controls}</div>'))
    hold = ('<div class="hold-card" role="button" tabindex="0" aria-label="Hold to see your role"><div class="hold-card__cover"><div class="big-icon">🤫</div><p class="t-heading">Hold to see your role</p>'
            '<p class="hold-card__hint">Tilt your phone away from your neighbours</p></div>'
            '<div data-secret><p class="t-label t-coral">You are the Insider</p><p class="t-title">Answer: B · Saturn</p></div></div>'
            '<div class="hold-card is-held" role="button" tabindex="0" aria-label="Hold to see your role"><div class="hold-card__cover"><p class="t-heading">Hold to see your role</p></div>'
            '<div data-secret><p class="t-label t-coral">You are the Insider</p><p class="t-title">Answer: B · Saturn</p></div></div>')
    secs.append(_sec("Hold-to-reveal card · resting, held", f'<div class="stack">{hold}</div>'))
    slider = ('<div class="chip-slider"><div class="chip-slider__value"><span class="t-label t-dim">Your bet</span><b>600</b></div>'
              '<input type="range" min="100" max="1000" step="100" value="600"><div class="chip-slider__ends"><span>100</span><span>You have 5,000 chips</span><span>1,000</span></div></div>')
    tb = ('<div class="draw-toolbar"><div class="draw-toolbar__row">' + "".join(
        f'<button class="draw-color{" is-selected" if i == 1 else ""}" style="background:{c}" aria-label="colour"></button>'
        for i, c in enumerate(("#1E1B2E", "#FF5C39", "#FFB020", "#3DB7FF", "#4ED19A", "#B58CFF"))) + '</div><div class="draw-toolbar__row">'
        + "".join(f'<button class="draw-size{" is-selected" if s == 10 else ""}"><i style="width:{s}px;height:{s}px"></i></button>' for s in (5, 10, 18))
        + '<span class="grow"></span><button class="draw-tool">Undo</button><button class="draw-tool">Clear</button></div></div>')
    secs.append(_sec("Chip slider · drawing toolbar", f'<div class="stack">{slider}{tb}</div>'))
    lb = ('<div class="leaderboard">' + lb_row(1, "Priya", "saffron", 4200, 1500) + lb_row(2, LONG_NAME, "pink", 3700, 500, True)
          + lb_row(3, "Sam", "sky", 2100, None) + "</div>")
    secs.append(_sec("Leaderboard row · delta, zero delta, me", lb, lb))
    misc = ('<div class="row"><span class="toast">Sam is now the leader</span><span class="toast toast--success">+1,000</span></div>'
            '<div class="banner">Waiting for Sam… (0:24)</div><div class="banner banner--warning">TV disconnected</div>'
            '<div class="row"><button class="leader-pill">Leader ▾</button></div>'
            '<div style="position:relative;height:260px;border-radius:24px;overflow:hidden"><div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div>'
            '<p class="sheet__title">Leader controls</p><button class="sheet__item">⏸ Pause</button><button class="sheet__item sheet__item--danger">End game</button></div></div>')
    secs.append(_sec("Toast · banner · leader pill · sheet", f'<div class="stack">{misc}</div>'))
    secs.append(_sec("Face corner (TV)", "",
        face("wink", "Scan to join.", prefix="") + face("suspicious", "Someone here knows the answer.", prefix="")))
    secs.append(_sec("Phone action (bottom-pinned) · TV safe area",
        '<div style="position:relative;height:200px;border:1px dashed #3A3556;border-radius:24px;overflow:hidden">'
        '<div class="phone-action">' + btn("Submit") + '</div></div>',
        '<div style="position:relative;height:420px;outline:1px dashed #3A3556"><div class="tv-safe" style="outline:3px dashed #FF5C39">'
        '<p class="t-heading">Everything lives inside the 80 px safe area</p></div></div>'))
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Components — NallaBox</title>
<link rel="stylesheet" href="shared/tokens.css"><link rel="stylesheet" href="shared/base.css"><link rel="stylesheet" href="shared/components.css">
<style>
 body {{ background: #121019; padding: 32px; }}
 h1 {{ font-size: 36px; font-weight: 900; margin-bottom: 4px; }}
 .lede {{ color: var(--nb-color-text-dim); font-weight: 700; margin-bottom: 24px; }}
 .lede a {{ color: var(--nb-color-coral); }}
 .g-sec {{ margin: 0 0 40px; }}
 .g-sec h2 {{ font-size: 18px; font-weight: 900; margin-bottom: 12px; color: #CFCBE0; }}
 .g-row {{ display: flex; gap: 24px; align-items: flex-start; flex-wrap: wrap; }}
 .g-phone {{ width: 393px; padding: 20px; border-radius: 24px; display: flex; flex-direction: column; gap: 12px; overflow: visible; }}
 .g-phone:empty {{ display: none; }}
 .g-tv {{ flex: 1; min-width: 900px; padding: 32px; border-radius: 12px; overflow: visible; }}
 .g-grid2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }}
 .g-tv .avatar {{ margin-right: 16px; }} .g-phone > .avatar {{ display: inline-grid; }}
</style></head>
<body>
<h1>Components</h1>
<p class="lede">Spec §9.4. Left: phone scale (393 pt). Right: TV scale (1920×1080 canvas, shown at 100%). <a href="index.html">All screens</a></p>
{''.join(secs)}
<script>document.querySelectorAll('.hold-card:not(.is-held)').forEach(c => {{ let t;
 c.addEventListener('pointerdown', () => t = setTimeout(() => c.classList.add('is-held'), 300));
 ['pointerup','pointerleave','pointercancel'].forEach(e => c.addEventListener(e, () => {{ clearTimeout(t); c.classList.remove('is-held'); }})); }});</script>
</body></html>
"""
