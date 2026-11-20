"""TV shell screens T1–T10 (spec §7.1). Canvas 1920×1080, content inside the 80 px safe area."""
from kit import E, JOIN_URL, PLAYERS, ROOM_CODE, avatar, chip, face, leaderboard, qr, seat, state, timer, tv_top

CSS = """<style>
.lobby { flex: 1; display: grid; grid-template-columns: 560px 1fr; gap: 96px; min-height: 0; }
.join-col { display: flex; flex-direction: column; gap: 28px; }
.join-col .qr { width: 300px; padding: 12px; }
.room-code { font-size: var(--fs-display); font-weight: 900; letter-spacing: .14em; color: var(--nb-color-coral); line-height: 1; }
.seats { display: grid; grid-template-columns: 1fr 1fr; gap: 20px 24px; align-content: start; }
.tv-foot { display: flex; justify-content: space-between; color: var(--nb-color-text-dim); font-size: var(--fs-caption); font-weight: 700; }
.help { background: var(--nb-color-ink-raised); border-radius: var(--nb-radius-xl); padding: 48px; display: flex; flex-direction: column; gap: 28px; }
.help ol { margin: 0; padding-left: 1.2em; display: flex; flex-direction: column; gap: 20px; }
.games { flex: 1; display: grid; grid-template-columns: repeat(3, 1fr); gap: 40px; align-items: stretch; }
.games .game-card { padding: 32px; gap: 20px; }
.games .game-card__art { font-size: 120px; aspect-ratio: 21 / 9; }
.settings-sum { display: grid; grid-template-columns: repeat(3, 1fr); gap: 32px; }
.settings-sum > div { background: var(--nb-color-ink-raised); border-radius: var(--nb-radius-xl); padding: 40px; display: flex; flex-direction: column; gap: 12px; }
.howto { flex: 1; display: grid; grid-template-columns: repeat(3, 1fr); gap: 40px; }
.howto > div { background: var(--nb-color-ink-raised); border-radius: var(--nb-radius-xl); padding: 48px 40px; display: flex; flex-direction: column; gap: 24px; }
.howto .big-icon { width: 160px; height: 160px; font-size: 88px; }
.progress { height: 12px; border-radius: 6px; background: var(--nb-color-ink-line); overflow: hidden; }
.progress > i { display: block; height: 100%; width: 40%; background: var(--nb-color-coral); }
.ghost { opacity: .35; filter: blur(2px); }
.top-banner { position: absolute; left: 50%; bottom: 96px; transform: translateX(-50%); white-space: nowrap; }
.results { flex: 1; display: grid; grid-template-columns: 820px 1fr; gap: 80px; min-height: 0; }
.podium { display: grid; grid-template-columns: repeat(3, 1fr); align-items: end; gap: 24px; height: 400px; }
.podium > div { display: flex; flex-direction: column; align-items: center; gap: 12px; }
.podium .step { width: 100%; border-radius: var(--nb-radius-lg) var(--nb-radius-lg) 0 0; background: var(--nb-color-ink-raised); display: grid; place-items: center; font-size: var(--fs-title); font-weight: 900; }
.podium .first .step { background: var(--nb-color-coral); }
.awards { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.award p { white-space: nowrap; }
.leaderboard--compact .leaderboard { gap: 10px; }
.leaderboard--compact .lb-row { padding: 4px 20px; line-height: 1.15; }
.leaderboard--compact .avatar--m { --avatar: 48px; }
.award { background: var(--nb-color-ink-raised); border-radius: var(--nb-radius-lg); padding: 20px 24px; display: flex; align-items: center; gap: 20px; }
</style>"""

SCORES = [("Priya", "saffron", 7400, 1500), ("Wolfgangster", "pink", 6900, 2000), ("Sam", "sky", 5800, 1000),
          ("Lena", "lilac", 5100, 500), ("Marcus", "mint", 4300, 1000), ("Aiko", "lime", 3900, None),
          ("Dev", "teal", 2700, 500), ("Rosa", "sand", 1800, None)]


def brand(label=""):
    lab = f'<span class="t-label t-dim">{E(label)}</span>' if label else ""
    return f'<div class="tv-brand"><img src="../shared/img/nallabox-symbol-color.svg" alt="">nallabox</div>{lab}'


def join_col():
    return (f'<div class="join-col">{qr()}<div><p class="t-label t-dim">Room code</p><p class="room-code">{ROOM_CODE}</p></div>'
            f'<p class="t-caption t-dim">or open <b style="color:#fff">{JOIN_URL}</b></p></div>')


def safe(*parts):
    return f'<div class="tv-safe">{"".join(parts)}</div>'


def t1():
    seats = "".join(seat() for _ in range(8))
    return safe(tv_top(brand("Up to 8 players"), face("wink", "Scan to join.")),
                f'<div class="lobby">{join_col()}<div class="stack"><p class="t-title">Grab your phone and join</p>'
                f'<p class="t-body t-dim">No app needed. Same Wi-Fi as this TV.</p><div class="seats">{seats}</div></div></div>',
                '<div class="tv-foot"><span>The first player to join becomes the leader</span><span>Family-friendly on</span></div>'), None, CSS


def t2():
    def seats(n):
        out = []
        for i, (name, colour) in enumerate(PLAYERS[:n]):
            out.append(chip(name, colour, *(["leader"] if i == 0 else [])))
        out += [seat() for _ in range(8 - n)]
        return "".join(out)
    body = (state("filling", safe(tv_top(brand("5 of 8 players"), face("wink", "Five in. Room for three more.")),
                                  f'<div class="lobby">{join_col()}<div class="stack"><p class="t-title">5 players in</p>'
                                  f'<div class="seats">{seats(5)}</div></div></div>',
                                  '<div class="tv-foot"><span>Priya starts the game from her phone</span><span>Family-friendly on</span></div>'))
            + state("full", safe(tv_top(brand("Room full"), face("grin", "Full house! Over to you, Priya.")),
                                 f'<div class="lobby">{join_col()}<div class="stack"><p class="t-title">8 players in · room full</p>'
                                 f'<div class="seats">{seats(8)}</div></div></div>',
                                 '<div class="tv-foot"><span>Priya starts the game from her phone</span><span>Family-friendly on</span></div>')))
    return body, ["filling", "full"], CSS


def t3():
    return safe(tv_top(brand("Waiting for players"), face("suspicious", "Still nobody? Let's check the Wi-Fi.")),
                f'<div class="lobby">{join_col()}<div class="help"><p class="t-title">Nobody in yet?</p><ol class="t-body">'
                '<li>Phones must be on the <b>same Wi-Fi</b> as the device running NallaBox.</li>'
                '<li>Guest, hotel and office Wi-Fi often stop phones reaching each other.</li>'
                '<li>No luck? Turn on <b>Personal Hotspot</b> on the host iPhone and join that.</li></ol>'
                '<p class="t-caption t-dim">This tip shows after 60 seconds with no one in.</p></div></div>'), None, CSS


GAMES = [
    ("Redacted", "saffron", "▮▮", "3–8 players · 15 min", "Fake the missing words. Spot the real ones."),
    ("Composite Sketch", "sky", "✎", "3–8 players · 15 min", "One witness describes. Everyone draws blind."),
    ("Insider Trading", "mint", "?!", "4–8 players · 15 min", "One of you knows the answer. Who?"),
]


def game_card(name, colour, glyph, meta, pitch, selected=False, warn=""):
    w = f'<span class="game-card__warn">⚠ {E(warn)}</span>' if warn else f'<span>{E(meta)}</span>'
    return (f'<div class="game-card{" is-selected" if selected else ""}"><div class="game-card__art" data-player="{colour}">{glyph}</div>'
            f'<p class="t-heading">{E(name)}</p><p class="t-body t-dim">{E(pitch)}</p><div class="game-card__meta">{w}</div></div>')


def t4():
    def picker(players, warn_insider):
        cards = "".join(game_card(*g, selected=(i == 0),
                                  warn=("Needs 4 players · 3 in the room" if warn_insider and g[0] == "Insider Trading" else ""))
                        for i, g in enumerate(GAMES))
        return safe(tv_top(brand("Choose a game"), face("wink", "Priya is picking a game.")),
                    f'<div class="games">{cards}</div>',
                    f'<div class="tv-foot"><span>Priya is choosing on her phone</span><span>{players} players in</span></div>')
    return state("ready", picker(5, False)) + state("too-few", picker(3, True)), ["ready", "too-few"], CSS


def t5():
    return safe(tv_top(brand("Next up"), face("idle")),
                '<p class="t-display">Redacted</p><p class="t-body t-dim">Fake the missing words. Spot the real ones.</p>'
                '<div class="settings-sum"><div><p class="t-label t-dim">Rounds</p><p class="t-title">3 + final</p></div>'
                '<div><p class="t-label t-dim">Timer</p><p class="t-title">Normal (1×)</p></div>'
                '<div><p class="t-label t-dim">Family-friendly</p><p class="t-title">On</p></div></div>',
                '<div class="tv-foot"><span>Priya can still change these on her phone</span><span>5 players in</span></div>'), None, CSS


def t6():
    steps = [("✍", "1 · Fake it", "Each phone shows the text with blanks. Type a believable fake."),
             ("🔍", "2 · Spot it", "All the versions appear here. Vote for the real one."),
             ("🏆", "3 · Score", "+500 for each player you fool. +1,000 for finding the real one.")]
    cards = "".join(f'<div><div class="big-icon">{i}</div><p class="t-heading">{E(h)}</p><p class="t-body t-dim">{E(t)}</p></div>' for i, h, t in steps)
    return safe(tv_top(brand("How to play · Redacted"), face("wink", "Quick rules, then we go.")),
                f'<div class="howto">{cards}</div>',
                '<div class="stack"><div class="progress"><i></i></div><div class="tv-foot"><span>Starts in 9 s</span>'
                '<span>Priya can skip from her phone</span></div></div>'), None, CSS


def ghost_round():
    """A faint game screen behind overlays."""
    return ('<div class="tv-safe ghost"><div class="tv-top"><p class="t-label">Redacted · Round 2 of 4</p></div>'
            '<p class="t-title">The Great Fire of London began in a ▮▮▮ on Pudding Lane in ▮▮▮.</p></div>')


def t7():
    return (ghost_round() + '<div class="tv-dim-overlay">' + face("sleepy", cls="face-big") +
            '<p class="t-display">Paused</p><p class="t-heading t-dim">Priya paused the game · resume from her phone</p></div>'), None, CSS


def t8():
    waiting = "".join(chip(n, c, *(["submitted"] if i in (0, 2) else []) + (["offline"] if n == "Sam" else []))
                      for i, (n, c) in enumerate(PLAYERS[:5]))
    return safe(tv_top('<p class="t-label t-dim">Redacted · Round 2 of 4 · Write your fakes</p>',
                       timer("0:31") + face("idle")),
                '<p class="t-title">The Great Fire of London began in a <span class="t-coral">▮▮▮ 1</span> on Pudding Lane in <span class="t-coral">▮▮▮ 2</span>.</p>',
                '<div class="banner" style="font-size:var(--fs-body)"><span>📶</span><span class="grow">Waiting for Sam to reconnect… the round keeps going.</span><span class="t-dim">0:24</span></div>',
                f'<div class="stack"><p class="t-label t-dim">Waiting on 3 players</p><div class="seats" style="grid-template-columns:repeat(3,1fr)">{waiting}</div></div>'), None, CSS


def t9():
    seats = "".join(chip(n, c, *(["leader"] if n == "Sam" else [])) for n, c in PLAYERS[1:5]) + seat() + seat()
    return (safe(tv_top(brand("4 of 8 players"), face("wink", "New boss: Sam.")),
                 f'<div class="lobby">{join_col()}<div class="stack"><p class="t-title">4 players in</p><div class="seats">{seats}</div></div></div>')
            + '<div class="top-banner"><span class="toast" style="font-size:var(--fs-heading)">👑 Priya left · Sam is now the leader</span></div>'), None, CSS


def t10():
    top3 = SCORES[:3]
    order = [(top3[1], 2, 130, ""), (top3[0], 1, 180, "first"), (top3[2], 3, 100, "")]
    pod = "".join(f'<div class="{cls}">{avatar(n, c, "m")}<p class="t-heading">{E(n)}</p><p class="t-body t-dim">{p:,}</p>'
                  f'<div class="step" style="height:{h}px">{rank}</div></div>' for (n, c, p, _), rank, h, cls in order)
    awards = ('<div class="award">' + avatar("Wolfgangster", "pink") + '<div><p class="t-label t-coral">Best Liar</p><p class="t-body">Wolfgangster</p><p class="t-caption t-dim">fooled 9 players</p></div></div>'
              '<div class="award">' + avatar("Lena", "lilac") + '<div><p class="t-label t-coral">Sharpest Eye</p><p class="t-body">Lena</p><p class="t-caption t-dim">found the real text 3 times</p></div></div>')
    return safe(tv_top(brand("Redacted · Final results"), face("celebrate", "And the winner is Priya!")),
                f'<div class="results"><div class="stack" style="gap:24px"><div class="podium">{pod}</div><div class="awards">{awards}</div></div>'
                f'<div class="leaderboard--compact">{leaderboard(SCORES)}</div></div>',
                '<div class="tv-foot"><span>Priya: Play again or pick a new game</span><span></span></div>'), None, CSS


PAGES = {(f"T{i}", "tv"): fn for i, fn in enumerate([t1, t2, t3, t4, t5, t6, t7, t8, t9, t10], start=1)}
