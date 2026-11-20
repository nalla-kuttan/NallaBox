"""Insider Trading: TV I1–I6, phone role/discuss pages per role, I3–I6 (spec §7.3).
Insider: Marcus. Answer: B · Saturn. Insider and Trader phone pages are identical outside [data-secret]."""
from kit import E, PLAYERS, avatar, btn, chip, face, leaderboard, phone_action, phone_top, state, statusbar, timer, tv_top

COLOUR = dict(PLAYERS)
INSIDER = "Marcus"
TOP = "Insider Trading · Round 3 of 6"
QUESTION = "Which planet has the most known moons?"
CHOICES = [("A", "Jupiter"), ("B", "Saturn"), ("C", "Uranus"), ("D", "Neptune")]
ANSWER = "B"
BETS = {"A": [("Lena", 800), ("Aiko", 300)], "B": [("Marcus", 1000), ("Priya", 600), ("Sam", 400)],
        "C": [("Dev", 500)], "D": [("Wolfgangster", 1000), ("Rosa", 200)]}

CSS = """<style>
.question { font-size: var(--fs-title); font-weight: 900; line-height: 1.2; }
.choices { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.surface-tv .choice { font-size: var(--fs-heading); --pad: 28px; }
.surface-tv .choice__key { width: 1.5em; height: 1.5em; }
.bets { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 12px; width: 100%; }
.bet { display: inline-flex; align-items: center; gap: 8px; padding: 4px 12px 4px 4px; border-radius: 12px; background: rgba(30,27,46,.5); font-size: 30px; font-weight: 800; }
.bet .avatar { --avatar: 40px; font-size: 20px; }
.choice-col { display: flex; flex-direction: column; align-items: flex-start; }
.waiting-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.waiting-grid .avatar { --avatar: 52px; font-size: 26px; }
.waiting-grid .player-chip { font-size: 36px; }
.accuse-count { flex: none; min-width: 1.6em; padding: 0 .3em; border-radius: 10px; background: var(--nb-color-coral); color: #fff; font-weight: 900; text-align: center; }
.unmask { display: grid; grid-template-columns: 1fr 1fr; gap: 80px; flex: 1; min-height: 0; }
.unmask__hero { display: flex; flex-direction: column; gap: 24px; justify-content: center; }
.tv-foot { display: flex; justify-content: space-between; color: var(--nb-color-text-dim); font-size: var(--fs-caption); font-weight: 700; margin-top: auto; }
.ph-q { font-size: calc(20px * var(--nb-text-scale, 1)); font-weight: 900; line-height: 1.25; }
.ph-choices { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.ph-choices .choice { --pad: 12px; font-size: calc(16px * var(--nb-text-scale, 1)); }
.result-hero { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 22px 16px; border-radius: var(--nb-radius-xl); background: var(--nb-color-ink-raised); width: 100%; }
.points-big { font-size: 44px; font-weight: 900; }
.accuse-list { display: flex; flex-direction: column; gap: 8px; }
.accuse-list .player-chip { --pad: 12px; border: 3px solid transparent; }
.accuse-list .player-chip.is-selected { border-color: var(--nb-color-coral); }
.chips-left { font-weight: 800; color: var(--nb-color-text-dim); font-size: var(--fs-caption); text-align: center; }
</style>"""


def safe(*parts):
    return f'<div class="tv-safe">{"".join(parts)}</div>'


def top(t=None, fs="suspicious", cap=None, label=TOP):
    return tv_top(f'<p class="t-label t-dim">{E(label)}</p>', (timer(t) if t else "") + face(fs, cap))


def choices_tv(reveal=False):
    out = []
    for k, v in CHOICES:
        cls = "choice"
        if reveal:
            cls += " is-correct" if k == ANSWER else " is-dim"
        bets = ""
        if reveal:
            bets = '<span class="bets">' + "".join(
                f'<span class="bet">{avatar(n, COLOUR[n], "s")}{"+" if k == ANSWER else "−"}{amt:,}</span>' for n, amt in BETS[k]) + "</span>"
        out.append(f'<div class="{cls}"><span class="choice__key">{k}</span><span class="choice-col">{E(v)}{bets}</span></div>')
    return '<div class="choices">' + "".join(out) + "</div>"


def i1_tv():
    return safe(top("0:05", "suspicious", "One of you already knows."), f'<p class="question">{E(QUESTION)}</p>', choices_tv(),
                '<div class="tv-foot"><span>Check your phone for your role</span><span>Hold the card so no one else sees it</span></div>'), None, CSS


def i2_tv():
    return safe(top("0:30", "suspicious", "Who sounds a little too sure?"), f'<p class="question">{E(QUESTION)}</p>', choices_tv(),
                '<div class="tv-foot"><span>Talk it out. Betting opens next.</span><span>Insider: steer them, don\'t get caught</span></div>'), None, CSS


def i3_tv():
    chips = "".join(chip(n, c, *(["submitted"] if i % 3 != 1 else [])) for i, (n, c) in enumerate(PLAYERS))
    return safe(top("0:15", "wink", "Bets close in 15 seconds."), f'<p class="question">{E(QUESTION)}</p>',
                '<p class="t-heading">Place your bets: 100 to 1,000 chips</p>',
                f'<div class="stack"><p class="t-label t-dim">Waiting on 3 players</p><div class="waiting-grid">{chips}</div></div>'), None, CSS


def i4_tv():
    return safe(top(None, "gasp", "Saturn! Who saw that coming?"), f'<p class="question">{E(QUESTION)}</p>', choices_tv(reveal=True),
                '<div class="tv-foot"><span>Right answers win their bet. Wrong answers lose it.</span><span>Next: find the Insider</span></div>'), None, CSS


def i5_tv():
    chips = "".join(chip(n, c, *(["submitted"] if i not in (3, 6) else [])) for i, (n, c) in enumerate(PLAYERS))
    return safe(top("0:15", "suspicious", "Someone here knew the answer."),
                '<p class="t-display" style="font-size:96px">Who was the Insider?</p>',
                '<p class="t-heading t-dim">Vote on your phone. A majority unmasks them.</p>',
                f'<div class="stack"><p class="t-label t-dim">6 of 8 voted</p><div class="waiting-grid">{chips}</div></div>'), None, CSS


# Chip maths for round 3, built from the rules (spec §7.3) so every number on I4–I6 agrees.
START = {"Marcus": 5700, "Priya": 5500, "Sam": 5500, "Aiko": 5300, "Lena": 5300, "Rosa": 4800, "Dev": 4300, "Wolfgangster": 4200}
RESULT = {n: (amt if k == ANSWER else -amt) for k, bets in BETS.items() for n, amt in bets}   # win or lose your bet
COMMISSION = sum(a for n, a in BETS[ANSWER] if n != INSIDER) // 10                           # 10% of Traders' winnings
ACCUSERS = ["Priya", "Sam", "Aiko", "Lena", "Rosa"]                                         # 5 of 7 name Marcus
PENALTY = 300


def board(deltas):
    rows = [(n, COLOUR[n], START[n] + d, d) for n, d in deltas.items()]
    return sorted(rows, key=lambda r: -r[2])


ESCAPED = board({n: RESULT[n] + (COMMISSION if n == INSIDER else 0) for n in START})
CAUGHT = board({n: RESULT[n] + (-PENALTY * len(ACCUSERS) if n == INSIDER else PENALTY if n in ACCUSERS else 0) for n in START})


def i6_tv():
    lbcss = ("<style>.leaderboard--compact .lb-row{padding:4px 20px;line-height:1.15}.leaderboard--compact .avatar--m{--avatar:48px}"
             ".leaderboard--compact .leaderboard{gap:10px}</style>")
    caught = safe(top(None, "gasp", "Caught red-handed!"),
                  f'<div class="unmask"><div class="unmask__hero">{avatar(INSIDER, COLOUR[INSIDER], "l")}<p class="t-display" style="font-size:96px">Caught!</p>'
                  f'<p class="t-title">Marcus was the Insider</p><p class="t-heading t-dim">{len(ACCUSERS)} of 7 named him. '
                  f'He pays {PENALTY} chips to each accuser and loses his cut.</p></div>'
                  f'<div class="leaderboard--compact">{leaderboard(CAUGHT)}</div></div>')
    escaped = safe(top(None, "wink", "Smooth. Very smooth."),
                   f'<div class="unmask"><div class="unmask__hero">{avatar(INSIDER, COLOUR[INSIDER], "l")}<p class="t-display" style="font-size:96px">Escaped!</p>'
                   f'<p class="t-title">Marcus was the Insider</p><p class="t-heading t-dim">Only 2 of 7 named him. '
                   f'He keeps 10% of the Traders\' winnings: +{COMMISSION} chips.</p></div>'
                   f'<div class="leaderboard--compact">{leaderboard(ESCAPED)}</div></div>')
    return state("caught", caught) + state("escaped", escaped), ["caught", "escaped"], CSS + lbcss


# ---------- phone ----------
def ph(body, sub="", action="", center=False):
    wrap = "phone-center" if center else "phone-body"
    return f'{statusbar()}{phone_top(TOP, sub)}<div class="{wrap}">{body}</div>{action}<div class="home-indicator"></div>'


def role_card(insider, held):
    secret = ('<p class="t-label t-coral">You are the Insider</p><p class="t-title">Answer: B · Saturn</p>'
              '<p class="hold-card__hint">Steer the group to it, but don\'t get caught.</p>') if insider else \
             ('<p class="t-label t-coral">You are a Trader</p><p class="t-title">Find the Insider</p>'
              '<p class="hold-card__hint">Someone here knows the answer. Watch who sounds too sure.</p>')
    return (f'<div class="hold-card{" is-held" if held else ""}" role="button" tabindex="0" aria-label="Hold to see your role"><div class="hold-card__cover"><div class="big-icon">🤫</div>'
            '<p class="t-heading">Hold to see your role</p><p class="hold-card__hint">Tilt your phone away from your neighbours</p></div>'
            f'<div data-secret>{secret}</div></div>')


def q_block():
    return f'<p class="ph-q">{E(QUESTION)}</p><div class="ph-choices">' + "".join(
        f'<div class="choice"><span class="choice__key">{k}</span>{E(v)}</div>' for k, v in CHOICES) + "</div>"


def role_page(insider, phase):
    sub, t = ("Your role", "0:05") if phase == "I1" else ("Discuss", "0:30")
    head = f'<div class="row" style="justify-content:space-between"><p class="t-label t-dim">{"Read your role" if phase == "I1" else "Talk it out"}</p>{timer(t)}</div>'
    rest = ph(head + role_card(insider, False) + q_block(), sub)
    held = ph(head + role_card(insider, True) + q_block(), sub)
    return state("resting", rest) + state("held", held), ["resting", "held"], CSS


def i3_phone():
    def picks(sel):
        return '<div class="ph-choices">' + "".join(
            f'<button class="choice{" is-selected" if k == sel else ""}"><span class="choice__key">{k}</span>{E(v)}</button>' for k, v in CHOICES) + "</div>"
    slider = ('<div class="chip-slider"><div class="chip-slider__value"><span class="t-label t-dim">Your bet</span><b>400</b></div>'
              '<input type="range" min="100" max="1000" step="100" value="400" aria-label="Bet"><div class="chip-slider__ends"><span>100</span><span>1,000</span></div></div>')
    head = f'<div class="row" style="justify-content:space-between"><p class="ph-q">{E(QUESTION)}</p>{timer("0:15")}</div>'
    betting = ph(head + picks("B") + slider + '<p class="chips-left">You have 5,500 chips</p>', "Bet", phone_action(btn("Bet 400 on B")))
    placed = ph('<div class="big-icon t-success">✓</div><p class="t-title">Bet placed</p><p class="t-heading">400 chips on B · Saturn</p>'
                '<p class="t-body t-dim">Waiting on 3 players</p>', "Bet", center=True)
    return state("betting", betting) + state("placed", placed), ["betting", "placed"], CSS


def i4_phone():
    won = ph('<div class="result-hero"><p class="t-label t-dim">The answer</p><p class="t-title">B · Saturn</p></div>'
             '<p class="points-big t-success">+400 chips</p><p class="t-body t-dim">You bet 400 on Saturn. Nice.</p><p class="chips-left">Now 5,900 chips</p>',
             "Answer", center=True)
    lost = ph('<div class="result-hero"><p class="t-label t-dim">The answer</p><p class="t-title">B · Saturn</p></div>'
              '<p class="points-big t-danger">−800 chips</p><p class="t-body t-dim">You bet 800 on Jupiter.</p><p class="chips-left">Now 4,500 chips</p>',
              "Answer", center=True)
    return state("won", won) + state("lost", lost), ["won", "lost"], CSS


def i5_phone():
    others = [p for p in PLAYERS if p[0] != "Sam"]
    def lst(sel):
        return '<div class="accuse-list">' + "".join(
            chip(n, c, *(["selected"] if n == sel else []))  for n, c in others) + "</div>"
    head = f'<div class="row" style="justify-content:space-between"><p class="t-heading">Who was the Insider?</p>{timer("0:15")}</div>'
    nv = ph(head + '<p class="t-caption t-dim">Tap a player. You can change your vote until time runs out.</p>' + lst(None), "Accuse")
    v = ph(head + '<p class="t-caption t-dim">You named Marcus · tap another to change</p>' + lst("Marcus"), "Accuse")
    return state("not-voted", nv) + state("voted", v), ["not-voted", "voted"], CSS


def i6_phone():
    caught = ph(avatar(INSIDER, COLOUR[INSIDER], "l") + '<p class="t-title">You caught Marcus!</p>'
                '<p class="points-big t-success">+300 chips</p><p class="t-body t-dim">He pays every player who named him.</p><p class="chips-left">Now 6,200 chips</p>',
                "Insider reveal", center=True)
    escaped = ph(avatar(INSIDER, COLOUR[INSIDER], "l") + '<p class="t-title">Marcus got away</p>'
                 '<p class="points-big" style="color:var(--nb-color-text-dim)">+0</p><p class="t-body t-dim">You named Dev. Marcus keeps his 10% cut.</p>'
                 '<p class="chips-left">5,900 chips</p>', "Insider reveal", center=True)
    return state("caught", caught) + state("escaped", escaped), ["caught", "escaped"], CSS


PAGES = {
    ("I1", "tv"): i1_tv, ("I2", "tv"): i2_tv, ("I3", "tv"): i3_tv, ("I4", "tv"): i4_tv, ("I5", "tv"): i5_tv, ("I6", "tv"): i6_tv,
    ("I1-insider", "phone"): lambda: role_page(True, "I1"), ("I1-trader", "phone"): lambda: role_page(False, "I1"),
    ("I2-insider", "phone"): lambda: role_page(True, "I2"), ("I2-trader", "phone"): lambda: role_page(False, "I2"),
    ("I3", "phone"): i3_phone, ("I4", "phone"): i4_phone, ("I5", "phone"): i5_phone, ("I6", "phone"): i6_phone,
}
