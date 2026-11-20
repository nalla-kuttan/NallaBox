"""iPhone host app H1–H8 (spec §7.4), SwiftUI, 393×852, Night stage. The host plays in H5 through the
same web controller everyone else uses (embedded with ?embed=1)."""
from kit import E, PLAYERS, ROOM_CODE, avatar, btn, phone_action, state, statusbar

CSS = """<style>
.h-large { font-size: calc(34px * var(--nb-text-scale, 1)); font-weight: 900; line-height: 1.1; }
.h-hero { display: flex; flex-direction: column; align-items: center; gap: 14px; text-align: center; }
.h-hero img { width: 120px; height: 120px; }
.h-word { font-size: 34px; font-weight: 900; }
.h-points { display: flex; flex-direction: column; gap: 14px; text-align: left; width: 100%; }
.h-points div { display: flex; gap: 14px; align-items: center; padding: 14px 16px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); font-weight: 800; }
.h-points span { font-size: 24px; }
.ios-alert-scrim { position: absolute; inset: 0; background: rgba(0,0,0,.45); display: grid; place-items: center; }
.ios-alert { width: 270px; border-radius: 14px; background: rgba(44,44,46,.97); color: #fff; text-align: center; overflow: hidden; font-family: -apple-system, system-ui, sans-serif; }
.ios-alert p { padding: 18px 16px 4px; font-size: 17px; font-weight: 600; line-height: 1.3; }
.ios-alert small { display: block; padding: 0 16px 16px; font-size: 13px; color: #EBEBF5; line-height: 1.35; }
.ios-alert div { display: grid; grid-template-columns: 1fr 1fr; border-top: .5px solid #545458; }
.ios-alert div span { padding: 11px; color: #0A84FF; font-size: 17px; }
.ios-alert div span + span { border-left: .5px solid #545458; font-weight: 600; }
.tv-art { width: 180px; height: 116px; border-radius: 14px; border: 6px solid var(--nb-color-ink-line); display: grid; place-items: center; font-size: 44px; position: relative; }
.tv-art::after { content: ""; position: absolute; bottom: -22px; left: 50%; width: 60px; height: 8px; margin-left: -30px; border-radius: 4px; background: var(--nb-color-ink-line); }
.tv-art.is-on { border-color: var(--nb-color-coral); background: rgba(255,92,57,.12); }
.route-btn { display: flex; align-items: center; gap: 12px; min-height: 56px; padding: 0 16px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); font-weight: 800; width: 100%; border: 0; color: #fff; }
.route-btn b { margin-left: auto; color: var(--nb-color-success); }
.host-strip { display: flex; align-items: center; gap: 10px; padding: 6px 16px 10px; border-bottom: 1px solid var(--nb-color-ink-line); }
.host-strip__code { font-weight: 900; letter-spacing: .14em; color: var(--nb-color-coral); font-size: 20px; }
.host-strip__meta { font-size: 13px; font-weight: 800; color: var(--nb-color-text-dim); }
.host-strip button { min-width: 44px; height: 44px; border-radius: 12px; border: 0; background: var(--nb-color-ink-raised); font-weight: 900; font-size: 15px; padding: 0 12px; }
.controller { flex: 1; width: 100%; border: 0; display: block; background: var(--nb-color-ink); }
.live { display: flex; flex-direction: column; height: 100%; }
.h-steps { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 8px; color: var(--nb-color-text-dim); font-weight: 700; text-align: left; }
</style>"""


def ph(body, action="", center=True):
    wrap = "phone-center" if center else "phone-body"
    return f'{statusbar()}<div class="{wrap}" style="padding-top:24px">{body}</div>{action}<div class="home-indicator"></div>'


def h1():
    return ph('<div class="h-hero"><img src="../shared/img/nallabox-symbol-color.svg" alt=""><p class="h-word">nallabox</p>'
              '<p class="h-large">Turn any TV into a party</p></div>'
              '<div class="h-points"><div><span>📱</span>Friends join with their phones</div><div><span>🚫</span>No app or account for guests</div>'
              '<div><span>📺</span>Play on your TV with AirPlay or a cable</div></div>',
              phone_action(btn("Get started"))), None, CSS


def h2():
    explain = ph('<div class="big-icon">📡</div><p class="h-large">Let friends\' phones find this iPhone</p>'
                 '<p class="t-body t-dim">NallaBox needs your local network so friends\' phones can reach this iPhone. Nothing leaves your Wi-Fi.</p>'
                 '<p class="t-caption t-dim">Next, iOS will ask. Tap <b style="color:#fff">Allow</b>.</p>', phone_action(btn("Continue")))
    prompt = explain + ('<div class="ios-alert-scrim"><div class="ios-alert"><p>“NallaBox” would like to find and connect to devices on your local network.</p>'
                        '<small>Friends\' phones connect to this iPhone over your Wi-Fi to play.</small><div><span>Don\'t Allow</span><span>Allow</span></div></div></div>')
    denied = ph('<div class="big-icon">🔒</div><p class="h-large">Local network is off</p>'
                '<p class="t-body t-dim">Without it, no one can join. Turn it on in Settings:</p>'
                '<ol class="h-steps"><li>Open Settings › NallaBox</li><li>Turn on Local Network</li><li>Come back here</li></ol>',
                phone_action(btn("Open Settings")))
    return state("explain", explain) + state("system-prompt", prompt) + state("denied", denied), ["explain", "system-prompt", "denied"], CSS


def h3():
    searching = ph('<div class="tv-art">📺</div><p class="h-large" style="margin-top:20px">Put the game on your TV</p>'
                   '<p class="t-body t-dim">Pick your TV in AirPlay, or plug in an HDMI adapter. Your iPhone stays your controller.</p>'
                   '<button class="route-btn"><span>⎚</span>Choose AirPlay display<b style="color:var(--nb-color-text-dim)">›</b></button>',
                   phone_action(btn("Continue", disabled_reason="Connect a TV to continue")))
    connected = ph('<div class="tv-art is-on">✓</div><p class="h-large" style="margin-top:20px">Connected to Living Room TV</p>'
                   '<p class="t-body t-dim">You should see the NallaBox lobby on the TV now.</p>'
                   '<button class="route-btn"><span>⎚</span>Living Room TV<b>✓ AirPlay</b></button>',
                   phone_action(btn("Continue")))
    return state("searching", searching) + state("connected", connected), ["searching", "connected"], CSS


def h4():
    sw = '<div class="swatches">' + "".join(
        f'<button class="swatch{" is-selected" if c == "saffron" else ""}" data-player="{c}" aria-label="{c}">{"✓" if c == "saffron" else ""}</button>'
        for c in ("saffron", "sky", "mint", "lilac", "pink", "lime", "teal", "sand")) + "</div>"
    return ph('<p class="h-large">What should we call you?</p><p class="t-body t-dim">You\'re player 1 and the leader. You\'ll play right here on this iPhone.</p>'
              '<div class="field is-focus"><label class="field__label">Your name</label><input class="field__input" value="Priya" maxlength="12">'
              '<div class="field__foot"><span></span><span class="field__counter">5/12</span></div></div>'
              f'<p class="field__label">Pick a colour</p>{sw}', phone_action(btn("Open the room")), center=False), None, CSS


def strip(players=5):
    return (f'<div class="host-strip"><div class="grow"><p class="host-strip__code">{ROOM_CODE}</p>'
            f'<p class="host-strip__meta">{players} players · Living Room TV</p></div><button aria-label="Pause">⏸</button><button aria-label="Host menu">•••</button></div>')


def live(extra=""):
    return (f'<div class="live">{statusbar()}{strip()}<iframe class="controller" src="../phone/P4.html?embed=1" title="Your controller"></iframe></div>'
            f'{extra}<div class="home-indicator"></div>')


def h5():
    return live(), None, CSS


def h6():
    sheet = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">Host controls</p>'
             '<button class="sheet__item">⏸ Pause game</button><button class="sheet__item">⏭ Skip this round</button>'
             '<button class="sheet__item">👥 Remove a player ›</button>'
             '<div class="sheet__item"><span class="grow">Family-friendly</span><button class="toggle is-on" aria-label="on"></button></div>'
             '<button class="sheet__item sheet__item--danger">⏹ End session</button></div>')
    confirm_remove = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">Remove Sam from the room?</p>'
                      '<p class="t-body t-dim">Sam leaves the game now. They can join again with the room code.</p>' +
                      btn("Remove Sam", "destructive") + btn("Cancel", "secondary") + '</div>')
    confirm_end = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">End the session?</p>'
                   '<p class="t-body t-dim">The game stops for all 5 players and the room closes. Scores so far are shown on the TV.</p>' +
                   btn("End session", "destructive") + btn("Keep playing", "secondary") + '</div>')
    # One embedded controller; only the sheet changes between states.
    return (live(state("menu", sheet) + state("confirm-remove", confirm_remove) + state("confirm-end", confirm_end)),
            ["menu", "confirm-remove", "confirm-end"], CSS)


def h7():
    return ph('<div class="tv-art" style="border-color:var(--nb-color-danger)">✕</div><p class="h-large" style="margin-top:20px">TV disconnected</p>'
              '<p class="t-body t-dim">The game is paused for everyone. Players stay connected while you reconnect.</p>',
              phone_action(btn("Reconnect AirPlay"), btn("End session", "secondary"))), None, CSS


def h8():
    alert = ('<div class="ios-alert-scrim"><div class="ios-alert" style="width:300px"><p>The room paused while you were away</p>'
             '<small>NallaBox has to stay open to run the game. All 5 players are still connected.</small>'
             '<div style="grid-template-columns:1fr"><span style="font-weight:600">Resume game</span></div></div></div>')
    return live(alert), None, CSS


PAGES = {(f"H{i}", "host-iphone"): fn for i, fn in enumerate([h1, h2, h3, h4, h5, h6, h7, h8], start=1)}
