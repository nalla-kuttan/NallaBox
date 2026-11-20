"""Phone controller shell screens P1–P13 (spec §7.2), 393×852, dark (Night stage)."""
from kit import E, PLAYERS, ROOM_CODE, avatar, btn, chip, phone_action, phone_top, state, statusbar

CSS = """<style>
.ph-logo { display: flex; align-items: center; gap: 10px; justify-content: center; padding: 12px 0 4px; font-weight: 900; font-size: calc(20px * var(--nb-text-scale, 1)); }
.ph-logo img { width: 36px; height: 36px; }
.room-chip { display: flex; align-items: center; justify-content: space-between; padding: 14px 16px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); }
.room-chip b { font-size: calc(24px * var(--nb-text-scale, 1)); font-weight: 900; letter-spacing: .2em; color: var(--nb-color-coral); }
.who { display: grid; grid-template-columns: 1fr; gap: 8px; }
.who .player-chip { --pad: 10px; font-size: calc(15px * var(--nb-text-scale, 1)); }
.who .avatar { --avatar: 32px; }
.me-card { display: flex; flex-direction: column; align-items: center; gap: 10px; padding: 20px; border-radius: var(--nb-radius-xl); background: var(--nb-color-ink-raised); }
.spinner { width: 56px; height: 56px; border-radius: 50%; border: 6px solid var(--nb-color-ink-line); border-top-color: var(--nb-color-coral); animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.auto-bar { width: 160px; height: 6px; border-radius: 3px; background: var(--nb-color-ink-line); overflow: hidden; }
.auto-bar i { display: block; width: 55%; height: 100%; background: var(--nb-color-coral); }
.avatars-row { display: flex; gap: 8px; justify-content: center; flex-wrap: wrap; }
.rank-big { font-size: 72px; font-weight: 900; line-height: 1; color: var(--nb-color-coral); }
.award-card { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); width: 100%; text-align: left; }
.phone-game { display: flex; gap: 12px; align-items: center; padding: 12px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); border: 3px solid transparent; }
.phone-game.is-selected { border-color: var(--nb-color-coral); }
.phone-game__art { width: 64px; height: 64px; flex: none; border-radius: 18px; display: grid; place-items: center; font-size: 26px; font-weight: 900; color: var(--nb-color-ink); }
.phone-game p { font-size: calc(13px * var(--nb-text-scale, 1)); }
.dimmed { filter: brightness(.6); }
</style>"""

ME = ("Lena", "lilac")


def ph(body, top="", action="", center=False):
    """Compose a phone screen: status bar, header, body (scroll or centred), pinned action, home indicator."""
    wrap = "phone-center" if center else "phone-body"
    return f'{statusbar()}{top}<div class="{wrap}">{body}</div>{action}<div class="home-indicator"></div>'


def logo():
    return '<div class="ph-logo"><img src="../shared/img/nallabox-symbol-color.svg" alt="">nallabox</div>'


OWNERS = {"saffron": "P", "sky": "S"}


def swatches(selected="lilac", taken=("saffron", "sky")):
    return '<div class="swatches">' + "".join(
        f'<button class="swatch{" is-selected" if c == selected else ""}{" is-taken" if c in taken else ""}" data-player="{c}" '
        f'aria-label="{c}{" (taken)" if c in taken else ""}">{"✓" if c == selected else OWNERS.get(c, "") if c in taken else ""}</button>'
        for c in ("saffron", "sky", "mint", "lilac", "pink", "lime", "teal", "sand")) + "</div>"


def name_field(value="", error=None, focus=False):
    cls = " is-error" if error else (" is-focus" if focus else "")
    err = f'<span class="field__error">{E(error)}</span>' if error else "<span></span>"
    return (f'<div class="field{cls}"><label class="field__label">Your name</label>'
            f'<input class="field__input" maxlength="12" placeholder="Up to 12 letters" value="{E(value)}">'
            f'<div class="field__foot">{err}<span class="field__counter">{len(value)}/12</span></div></div>')


def room_chip(code=ROOM_CODE, ok=True):
    return (f'<div class="room-chip"><span class="t-label t-dim">Room</span><b>{code}</b>'
            f'<span class="{"t-success" if ok else "t-danger"}" style="font-weight:900">{"✓ found" if ok else "not found"}</span></div>')


def who(n=5, leader="Priya"):
    return '<div class="who">' + "".join(chip(nm, c, *(["leader"] if nm == leader else [])) for nm, c in PLAYERS[:n]) + "</div>"


def p1():
    empty = ph(logo() + '<p class="t-title">Join the game</p>' + room_chip() + name_field(focus=True) +
               '<p class="field__label">Pick a colour</p>' + swatches(selected=None),
               action=phone_action(btn("Join the room", disabled_reason="Enter your name to join")))
    filled = ph(logo() + '<p class="t-title">Join the game</p>' + room_chip() + name_field("Lena") +
                '<p class="field__label">Pick a colour</p>' + swatches(),
                action=phone_action(btn("Join the room")))
    return state("empty", empty) + state("filled", filled), ["empty", "filled"], CSS


def p2():
    wrong = ph(logo() + '<p class="t-title">Join the game</p>' +
               '<div class="field is-error"><label class="field__label">Room code</label><input class="field__input field__input--code" value="KWPZ">'
               '<div class="field__foot"><span class="field__error">No room KWPZ. Check the code on the TV.</span></div></div>' + name_field("Lena"),
               action=phone_action(btn("Try again")))
    full = ph('<div class="big-icon">🚪</div><p class="t-title">This room is full</p>'
              '<p class="t-body t-dim">8 players is the limit. Watch the TV, or ask the leader to start a new room.</p>',
              action=phone_action(btn("Try another code")), center=True)
    taken = ph(logo() + '<p class="t-title">Join the game</p>' + room_chip() +
               name_field("Sam", error="Sam is taken. Add a letter or pick another.") +
               '<p class="field__label">Pick a colour</p>' + swatches(), action=phone_action(btn("Join the room")))
    progress = ph(avatar("Lena", "lilac", "l") + "<p class=\"t-title\">You're in, Lena</p>"
                  "<p class=\"t-body t-dim\">A game is already running. You'll join when the next game starts.</p>"
                  '<p class="t-caption t-dim">Keep this page open.</p>', center=True)
    return (state("wrong-code", wrong) + state("room-full", full) + state("name-taken", taken) + state("in-progress", progress),
            ["wrong-code", "room-full", "name-taken", "in-progress"], CSS)


def p3():
    me = f'<div class="me-card">{avatar(*ME, "l")}<p class="t-title">You\'re in, Lena</p><p class="t-body t-dim">Waiting for Priya to start</p></div>'
    return ph(me + '<p class="field__label">5 players in</p>' + who(),
              top=phone_top("Room KWPX"), action=phone_action(btn("Change name or colour", "secondary"))), None, CSS


def p4():
    ready = ph('<div class="me-card">' + avatar("Priya", "saffron", "l") +
               '<p class="t-title">You\'re the leader</p><p class="t-body t-dim">Pick a game when everyone\'s in. The TV follows you.</p></div>'
               '<p class="field__label">5 players in</p>' + who() +
               btn("Room settings", "secondary", extra='style="width:auto;align-self:center"').replace('class="btn btn--secondary"', 'class="btn btn--secondary btn--small"'),
               top=phone_top("Room KWPX", leader=True), action=phone_action(btn("Choose a game")))
    few = ph('<div class="me-card">' + avatar("Priya", "saffron", "l") +
             '<p class="t-title">You\'re the leader</p><p class="t-body t-dim">Waiting for more players to join.</p></div>'
             '<p class="field__label">2 players in</p>' + who(2),
             top=phone_top("Room KWPX", leader=True), action=phone_action(btn("Choose a game", disabled_reason="Need 3 players to start")))
    return state("ready", ready) + state("too-few", few), ["ready", "too-few"], CSS


GAMES = [("Redacted", "saffron", "▮▮", "3–8 players · 15 min", "Fake the missing words."),
         ("Composite Sketch", "sky", "✎", "3–8 players · 15 min", "Describe it. Draw it blind."),
         ("Insider Trading", "mint", "?!", "4–8 players · 15 min", "One of you knows the answer.")]


def p5():
    cards = "".join(
        f'<div class="phone-game{" is-selected" if i == 0 else ""}"><div class="phone-game__art" data-player="{c}">{g}</div>'
        f'<div class="grow"><p class="t-heading" style="font-size:19px">{E(n)}</p><p class="t-dim">{E(pitch)}</p><p class="t-dim">{E(meta)}</p></div></div>'
        for i, (n, c, g, meta, pitch) in enumerate(GAMES))
    return ph('<p class="t-caption t-dim">Tap a game to show it on the TV.</p>' + cards,
              top=phone_top("Choose a game", "5 players in", leader=True), action=phone_action(btn("Pick Redacted"))), None, CSS


def settings(game, rounds, banned=False, few=False):
    rows = (f'<div class="field"><span class="field__label">Rounds</span><div class="stepper"><button>−</button>'
            f'<span class="stepper__value">{rounds}</span><button>+</button></div></div>'
            '<div class="field"><span class="field__label">Timer speed</span><div class="segmented"><button class="is-selected">1×</button>'
            '<button>1.5×</button><button>2×</button><button>Off</button></div><p class="t-caption t-dim">Slower timers give more time to write and draw.</p></div>'
            '<div class="setting-row"><div><p>Family-friendly</p><p class="t-caption t-dim">Safe prompts, profanity filter</p></div><button class="toggle is-on" aria-label="on"></button></div>')
    if banned:
        rows += '<div class="setting-row"><div><p>Banned words</p><p class="t-caption t-dim">The Witness can\'t say 2–3 words</p></div><button class="toggle" aria-label="off"></button></div>'
    action = btn("Start", disabled_reason="Insider Trading needs 4 players") if few else btn("Start")
    return ph(rows, top=phone_top("Game settings", game, leader=True), action=phone_action(action))


def p6():
    return (state("redacted", settings("Redacted", "3 + final")) + state("sketch", settings("Composite Sketch", "1 per player", banned=True))
            + state("insider-too-few", settings("Insider Trading", "6 rounds", few=True)), ["redacted", "sketch", "insider-too-few"], CSS)


def p7():
    return ph('<p class="t-label t-dim">Redacted · Round 1 of 4</p><div class="big-icon">✍</div><p class="t-label t-coral">Your job</p>'
              '<p class="t-title">Write a fake word for each blank</p><p class="t-body t-dim">Make it believable. Fooling people scores.</p>'
              '<div class="auto-bar"><i></i></div>', center=True), None, CSS


def p8():
    waiting = "".join(avatar(n, c) for n, c in (PLAYERS[1], PLAYERS[4], PLAYERS[5]))
    return ph('<div class="big-icon t-success" style="font-size:56px">✓</div><p class="t-title">Done!</p>'
              f'<p class="t-body t-dim">Waiting on 3 players</p><div class="avatars-row">{waiting}</div>',
              top=phone_top("Redacted · Round 1"), action=phone_action(btn("Change my answer", "secondary")), center=True), None, CSS


def p9():
    trying = ph('<div class="spinner"></div><p class="t-title">Reconnecting to the room…</p>'
                '<p class="t-body t-dim">Your answer is saved on this phone.</p>', center=True)
    failed = ph('<div class="big-icon">📶</div><p class="t-title">Can\'t reach the room</p>'
                '<p class="t-body t-dim">Check you\'re on the same Wi-Fi as the host, then try again. Your answer is saved.</p>',
                action=phone_action(btn("Try again")), center=True)
    return state("trying", trying) + state("failed", failed), ["trying", "failed"], CSS


def p10():
    player = ph('<div class="big-icon">⏸</div><p class="t-title">Paused by Priya</p><p class="t-body t-dim">Timers are frozen. Hang tight.</p>', center=True)
    leader = ph('<div class="big-icon">⏸</div><p class="t-title">You paused the game</p><p class="t-body t-dim">Everyone\'s timer is frozen.</p>',
                top=phone_top("Redacted · Round 2", leader=True), action=phone_action(btn("Resume")), center=True)
    return state("player", player) + state("leader", leader), ["player", "leader"], CSS


def p11():
    return ph('<div class="big-icon">👋</div><p class="t-title">You were removed from this room</p>'
              '<p class="t-body t-dim">The host removed you. If that was a mistake, you can join again.</p>',
              action=phone_action(btn("Join again")), center=True), None, CSS


def results(name, colour, rank, points, line, award, award_note, leader=False):
    body = (f'<p class="t-label t-dim">Redacted · Final results</p><p class="rank-big">#{rank}</p>' + avatar(name, colour, "l") +
            f'<p class="t-title">{points} points</p><p class="t-body t-dim">{E(line)}</p>'
            f'<div class="award-card">{avatar(name, colour, "s")}<div><p class="t-label t-coral">{E(award)}</p>'
            f'<p class="t-caption">{E(award_note)}</p></div></div>')
    if leader:
        return ph(body, top=phone_top("Game over", leader=True), action=phone_action(btn("Play again"), btn("New game", "secondary")), center=True)
    return ph(body, top=phone_top("Game over"), center=True)


def p12():
    player = results("Lena", "lilac", 4, "5,100", "+500 this round · 2,300 behind Priya", "Sharpest Eye", "Found the real text 3 times")
    leader = results("Priya", "saffron", 1, "7,400", "+1,500 this round · winner", "Top score", "Highest total after 4 rounds", leader=True)
    return state("player", player) + state("leader", leader), ["player", "leader"], CSS


def p13():
    bg = f'<div class="dimmed">{ph(chip("Priya", "saffron", "leader"), top=phone_top("Redacted · Round 2", "Vote: which is real?", leader=True))}</div>'
    menu = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">Leader controls</p>'
            '<button class="sheet__item">⏸ Pause game</button><button class="sheet__item">⏭ Skip this round</button>'
            '<button class="sheet__item">👥 Remove a player ›</button><button class="sheet__item">👑 Pass leadership ›</button>'
            '<button class="sheet__item sheet__item--danger">⏹ End game</button></div>')
    remove = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">Remove a player</p>' +
              "".join(f'<div class="sheet__item">{avatar(n, c, "s")}<span class="grow">{E(n)}</span>'
                      f'<button class="btn btn--destructive btn--small">Remove</button></div>' for n, c in PLAYERS[1:5]) +
              '<p class="t-caption t-dim">They can join again with the room code.</p></div>')
    confirm = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">End the game for everyone?</p>'
               '<p class="t-body t-dim">Scores so far are shown, then everyone goes back to the lobby.</p>' +
               btn("End game", "destructive") + btn("Keep playing", "secondary") + "</div>")
    confirm_remove = ('<div class="sheet-scrim"></div><div class="sheet"><div class="sheet__handle"></div><p class="sheet__title">Remove Sam from the room?</p>'
                      '<p class="t-body t-dim">Sam leaves the game now. They can join again with the room code.</p>' +
                      btn("Remove Sam", "destructive") + btn("Cancel", "secondary") + "</div>")
    return (bg + state("menu", menu) + state("remove-player", remove) + state("confirm-remove", confirm_remove) + state("confirm-end", confirm),
            ["menu", "remove-player", "confirm-remove", "confirm-end"], CSS)


PAGES = {(f"P{i}", "phone"): fn for i, fn in enumerate([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13], start=1)}
