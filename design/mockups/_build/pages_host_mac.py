"""Mac host app M1–M5 (spec §7.5), SwiftUI window designed at 1280×800 (min 960×640)."""
from kit import E, JOIN_URL, PLAYERS, ROOM_CODE, avatar, btn, qr, state

CSS = """<style>
.mac { position: absolute; inset: 0; display: flex; flex-direction: column; background: var(--nb-color-ink); }
.mac-bar { height: 52px; flex: none; display: flex; align-items: center; gap: 12px; padding: 0 16px; background: #17151F; border-bottom: 1px solid #2E2A40; }
.lights { display: flex; gap: 8px; margin-right: 8px; }
.lights i { width: 12px; height: 12px; border-radius: 50%; background: #FF5F57; } .lights i:nth-child(2) { background: #FEBC2E; } .lights i:nth-child(3) { background: #28C840; }
.mac-title { font-weight: 900; font-size: 15px; display: flex; align-items: center; gap: 8px; }
.mac-title img { width: 22px; height: 22px; }
.mac-tools { margin-left: auto; display: flex; gap: 8px; }
.mac-tools button { height: 32px; padding: 0 12px; border-radius: 8px; border: 0; background: var(--nb-color-ink-raised); font-weight: 800; font-size: 13px; }
.mac-tools button.is-danger { color: var(--nb-color-danger); }
.mac-body { flex: 1; min-height: 0; display: grid; grid-template-columns: 360px 1fr; }
.mac-side { border-right: 1px solid #2E2A40; padding: 20px; display: flex; flex-direction: column; gap: 14px; overflow: hidden; }
.mac-main { padding: 24px; display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.mac-code { font-size: 44px; font-weight: 900; letter-spacing: .14em; color: var(--nb-color-coral); line-height: 1; }
.mac-side .qr { width: 132px; padding: 8px; border-radius: 12px; }
.mac-players { display: flex; flex-direction: column; gap: 6px; flex: 1; min-height: 0; overflow-y: auto; }
.mac-player { display: flex; align-items: center; gap: 10px; padding: 6px 8px; border-radius: 10px; background: var(--nb-color-ink-raised); font-weight: 800; font-size: 14px; }
.mac-player .avatar { --avatar: 28px; font-size: 14px; }
.mac-player button { margin-left: auto; height: 26px; padding: 0 8px; border-radius: 6px; border: 0; background: transparent; color: var(--nb-color-text-dim); font-size: 12px; font-weight: 800; }
.health { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 800; color: var(--nb-color-text-dim); }
.health i { width: 10px; height: 10px; border-radius: 50%; background: var(--nb-color-success); }
.preview { width: 100%; aspect-ratio: 16 / 9; border: 0; border-radius: 12px; background: #000; box-shadow: 0 0 0 1px #3A3556; }
.mac-center { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 18px; text-align: center; }
.mac-center img.logo { width: 96px; height: 96px; }
.displays { width: 460px; display: flex; flex-direction: column; gap: 8px; text-align: left; }
.display { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 12px; background: var(--nb-color-ink-raised); border: 2px solid transparent; font-weight: 800; font-size: 15px; }
.display.is-selected { border-color: var(--nb-color-coral); }
.display small { display: block; color: var(--nb-color-text-dim); font-weight: 700; font-size: 12px; }
.radio { width: 18px; height: 18px; border-radius: 50%; border: 2px solid var(--nb-color-ink-line); flex: none; }
.display.is-selected .radio { border: 5px solid var(--nb-color-coral); }
.mac .btn { width: 460px; }
.fullgame { position: absolute; inset: 0; background: #000; display: flex; align-items: center; justify-content: center; }
.fullgame iframe { width: 1280px; height: 720px; border: 0; }
.edge-bar { position: absolute; left: 50%; top: 12px; transform: translateX(-50%); display: flex; gap: 8px; padding: 8px; border-radius: 14px; background: rgba(23,21,31,.94);
  box-shadow: 0 10px 30px rgba(0,0,0,.5); font-weight: 800; font-size: 13px; align-items: center; }
.edge-bar span { padding: 0 8px; color: var(--nb-color-text-dim); }
.edge-bar button { height: 32px; padding: 0 12px; border-radius: 8px; border: 0; background: var(--nb-color-ink-raised); font-weight: 800; font-size: 13px; }
.netpanel { padding: 16px; border-radius: 14px; background: var(--nb-color-ink-raised); box-shadow: inset 4px 0 0 var(--nb-color-danger); display: flex; flex-direction: column; gap: 10px; font-size: 14px; }
.netpanel ol { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 6px; color: var(--nb-color-text-dim); font-weight: 700; }
.mac-sheet-scrim { position: absolute; inset: 52px 0 0 0; background: rgba(10,8,16,.55); }
.mac-sheet { position: absolute; top: 52px; left: 50%; width: 480px; margin-left: -240px; padding: 22px; border-radius: 0 0 16px 16px; background: #2B2742;
  box-shadow: 0 20px 50px rgba(0,0,0,.5); display: flex; flex-direction: column; gap: 14px; font-size: 15px; }
.mac-sheet .segmented button { font-size: 13px; min-height: 32px; }
.mac-sheet .btn { width: auto; align-self: flex-end; min-height: 36px; font-size: 14px; padding: 0 22px; border-radius: 10px; }
</style>"""


def chrome(title_extra="", tools=True):
    t = ('<div class="mac-tools"><button>⏸ Pause</button><button>⏭ Skip round</button><button class="is-danger">End game</button>'
         '<button>⚙ Settings</button></div>') if tools else ""
    return (f'<div class="mac-bar"><div class="lights"><i></i><i></i><i></i></div><div class="mac-title">'
            f'<img src="../shared/img/nallabox-symbol-color.svg" alt="">NallaBox{E(title_extra)}</div>{t}</div>')


def side(network_problem=False):
    players = "".join(f'<div class="mac-player">{avatar(n, c)}<span>{E(n)}{" · leader" if i == 0 else ""}</span><button>Remove</button></div>'
                      for i, (n, c) in enumerate(PLAYERS))
    if network_problem:
        body = ('<div class="netpanel"><p style="font-weight:900;font-size:16px">Phones can\'t connect?</p><ol>'
                '<li>Phones must be on the same Wi-Fi as this Mac (“Home”).</li>'
                '<li>Guest and office Wi-Fi often block phones from reaching each other.</li>'
                '<li>Check the macOS firewall allows NallaBox.</li>'
                '<li>Still stuck? Share this Mac\'s connection, or use an iPhone hotspot.</li></ol>'
                f'<button class="btn btn--secondary btn--small" style="width:100%">Copy join link · {JOIN_URL}</button></div>'
                '<div class="health"><i style="background:var(--nb-color-danger)"></i>0 connected · 3 failed attempts</div>')
    else:
        body = (f'<p class="t-label t-dim" style="font-size:12px">8 players</p><div class="mac-players">{players}</div>'
                '<div class="health"><i></i>8 connected · good</div>')
    return (f'<aside class="mac-side"><p class="t-label t-dim" style="font-size:12px">Room code</p><p class="mac-code">{ROOM_CODE}</p>'
            f'<div class="row" style="gap:14px;align-items:flex-start">{qr()}<p style="font-size:13px;font-weight:700;color:var(--nb-color-text-dim)">'
            f'Scan, or open<br><b style="color:#fff">{JOIN_URL}</b></p></div>{body}</aside>')


def room(network_problem=False, preview="T2"):
    return (f'<div class="mac">{chrome(" — Room " + ROOM_CODE)}<div class="mac-body">{side(network_problem)}'
            f'<section class="mac-main"><div class="row" style="justify-content:space-between"><p class="t-heading" style="font-size:18px">On the TV now</p>'
            f'<span class="health"><i></i>LG TV · HDMI · 1920×1080</span></div>'
            f'<iframe class="preview" src="../tv/{preview}.html?embed=1{"&amp;state=full" if preview == "T2" else ""}" title="TV preview"></iframe>'
            '<p style="font-size:13px;font-weight:700;color:var(--nb-color-text-dim)">The leader runs the game from their phone. These controls are for emergencies.</p>'
            '</section></div></div>')


def m1():
    displays = [("LG TV", "HDMI · 1920×1080 · recommended", True), ("Built-in Retina Display", "This Mac's screen", False),
                ("This window, full screen", "For a projector mirroring this Mac", False)]
    rows = "".join(f'<div class="display{" is-selected" if sel else ""}"><span class="radio"></span><div>{E(n)}<small>{E(d)}</small></div></div>'
                   for n, d, sel in displays)
    return (f'<div class="mac">{chrome(tools=False)}<div class="mac-center"><img class="logo" src="../shared/img/nallabox-symbol-color.svg" alt="">'
            '<p class="t-title" style="font-size:32px">Start a party room</p>'
            '<div class="health"><i></i>Local network on · Wi-Fi “Home”</div>'
            f'<p class="t-label t-dim" style="font-size:12px">Show the game on</p><div class="displays">{rows}</div>'
            f'{btn("Start room")}</div></div>'), None, CSS


def m2():
    return room(), None, CSS


def m3():
    game = '<div class="fullgame"><iframe src="../tv/R3.html?embed=1" title="Game"></iframe></div>'
    bar = ('<div class="edge-bar"><span>Room KWPX · Esc pauses</span><button>⏸ Pause</button><button>⏭ Skip round</button>'
           '<button style="color:var(--nb-color-danger)">End game</button><button>Exit full screen</button></div>')
    return (state("clean", game) + state("controls", game + bar)), ["clean", "controls"], CSS


def m4():
    return room(network_problem=True, preview="T3"), None, CSS


def m5():
    sheet = ('<div class="mac-sheet-scrim"></div><div class="mac-sheet"><p style="font-weight:900;font-size:18px">Room settings</p>'
             '<div class="setting-row"><div><p>Family-friendly</p><p class="t-caption t-dim" style="font-size:12px">Safe prompts and a profanity filter</p></div><button class="toggle is-on" aria-label="on"></button></div>'
             '<div class="field"><span class="field__label" style="font-size:11px">Default timer speed</span><div class="segmented"><button class="is-selected">1×</button><button>1.5×</button><button>2×</button><button>Off</button></div></div>'
             '<div class="setting-row"><div><p>Host voice</p><p class="t-caption t-dim" style="font-size:12px">Reads prompts aloud. Captions always show.</p></div><button class="toggle is-on" aria-label="on"></button></div>'
             '<div class="field"><span class="field__label" style="font-size:11px">Caption size</span><div class="segmented"><button>Medium</button><button class="is-selected">Large</button><button>Extra large</button></div></div>'
             f'{btn("Done")}</div>')
    return room() + sheet, None, CSS


PAGES = {(f"M{i}", "host-mac"): fn for i, fn in enumerate([m1, m2, m3, m4, m5], start=1)}
