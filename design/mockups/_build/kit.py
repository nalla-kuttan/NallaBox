"""Page template and component helpers shared by every screen builder."""
import html as _html

E = _html.escape

# Sample players (spec: names up to 12 characters; coral never a player colour)
PLAYERS = [
    ("Priya", "saffron"), ("Sam", "sky"), ("Marcus", "mint"), ("Lena", "lilac"),
    ("Wolfgangster", "pink"), ("Aiko", "lime"), ("Dev", "teal"), ("Rosa", "sand"),
]
ROOM_CODE = "KWPX"
JOIN_URL = "192.168.1.24:8080"


def page(entry, body, states=None, head=""):
    """Return a full HTML page for a manifest entry. body = inner HTML of <main class="screen">."""
    st = f' data-states="{",".join(states)}"' if states else ""
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{entry["id"]} · {E(entry["title"])} — NallaBox</title>
<link rel="stylesheet" href="../shared/tokens.css">
<link rel="stylesheet" href="../shared/base.css">
<link rel="stylesheet" href="../shared/components.css">
<link rel="stylesheet" href="../shared/frame.css">{head}
</head>
<body data-screen="{entry["id"]}" data-surface="{entry["surface"]}"{st}>
<main class="screen">
{body}
</main>
<script src="../shared/screens.js"></script>
<script src="../shared/frame.js"></script>
</body></html>
"""


def state(name, inner):
    """Markup visible only in the given state(s) (comma-separated)."""
    return f'<div data-show-state="{name}">{inner}</div>'


def avatar(name, colour, size="m"):
    return f'<span class="avatar avatar--{size}" data-player="{colour}" aria-hidden="true">{E(name[0])}</span>'


def chip(name, colour, *mods, extra=""):
    cls = " ".join(f"is-{m}" for m in mods)
    badge = '<span class="badge">Leader</span>' if "leader" in mods else ""
    tick = '<span class="chip-tick" aria-label="done">✓</span>' if "submitted" in mods else ""
    off = '<span class="chip-off">offline</span>' if "offline" in mods else ""
    return f'<div class="player-chip {cls}">{avatar(name, colour)}<span class="player-chip__name">{E(name)}</span>{badge}{tick}{off}{extra}</div>'


def seat():
    return '<div class="seat">Waiting…</div>'


def timer(text, urgent=False):
    return f'<span class="timer-pill{" is-urgent" if urgent else ""}">{E(text)}</span>'


def face(state="idle", caption=None, cls="face-corner", prefix="../"):
    cap = f'<p class="face-corner__caption">{E(caption)}</p>' if caption else ""
    return f'<div class="{cls}">{cap}<img class="face" src="{prefix}shared/face/face-{state}.svg" alt=""></div>'


def btn(label, kind="primary", disabled_reason=None, extra=""):
    if disabled_reason:
        return (f'<button class="btn btn--{kind}" disabled {extra}>{E(label)}</button>'
                f'<p class="btn__reason">{E(disabled_reason)}</p>')
    return f'<button class="btn btn--{kind}" {extra}>{E(label)}</button>'


def phone_action(*buttons):
    return f'<div class="phone-action">{"".join(buttons)}</div>'


def lb_row(rank, name, colour, points, delta=None, me=False):
    if not delta:
        d = '<span class="lb-row__delta is-zero">±0</span>'
    elif delta > 0:
        d = f'<span class="lb-row__delta">+{delta:,}</span>'
    else:
        d = f'<span class="lb-row__delta is-down">−{-delta:,}</span>'
    return (f'<div class="lb-row{" is-me" if me else ""}"><span class="lb-row__rank">{rank}</span>{avatar(name, colour)}'
            f'<span class="lb-row__name">{E(name)}</span>{d}<span class="lb-row__points">{points:,}</span></div>')


def leaderboard(rows, me=None):
    """rows: list of (name, colour, points, delta), already sorted."""
    return '<div class="leaderboard">' + "".join(
        lb_row(i + 1, n, c, p, d, me == n) for i, (n, c, p, d) in enumerate(rows)) + "</div>"


def tv_top(left, right=""):
    return f'<div class="tv-top"><div class="tv-top__left">{left}</div><div class="tv-top__right">{right}</div></div>'


def phone_top(title, sub="", leader=False):
    pill = '<button class="leader-pill" aria-label="Leader controls">Leader ▾</button>' if leader else ""
    s = f'<p class="phone-top__sub">{E(sub)}</p>' if sub else ""
    return f'<header class="phone-top"><div><p class="phone-top__title">{E(title)}</p>{s}</div>{pill}</header>'


def statusbar():
    return '<div class="ios-status"><span>9:41</span><span class="ios-status__icons">●●●● ᯤ ▮</span></div>'


def qr():
    """Static QR-like placeholder (not scannable): 25×25 modules with three finder squares."""
    n, cells = 25, []
    def finder(r, c):
        for fr, fc in ((0, 0), (0, n - 7), (n - 7, 0)):
            if fr <= r < fr + 7 and fc <= c < fc + 7:
                rr, cc = r - fr, c - fc
                return rr in (0, 6) or cc in (0, 6) or (2 <= rr <= 4 and 2 <= cc <= 4)
        return None
    for r in range(n):
        for c in range(n):
            f = finder(r, c)
            on = f if f is not None else ((r * 7 + c * 13 + r * c) % 5 < 2)
            if on:
                cells.append(f'<rect x="{c}" y="{r}" width="1" height="1"/>')
    return (f'<div class="qr"><svg viewBox="-2 -2 {n + 4} {n + 4}" shape-rendering="crispEdges">'
            f'<rect x="-2" y="-2" width="{n + 4}" height="{n + 4}" fill="#fff"/><g fill="#1E1B2E">{"".join(cells)}</g></svg></div>')
