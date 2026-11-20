"""Redacted, TV R1–R5 and phone R1–R5 (spec §7.3). Sample round: all 8 players, 9 versions."""
from kit import E, PLAYERS, avatar, btn, chip, face, leaderboard, phone_action, phone_top, state, statusbar, timer, tv_top

CSS = """<style>
.passage { font-size: var(--fs-title); font-weight: 900; line-height: 1.25; }
.blank { display: inline-block; min-width: 3.2em; padding: 0 .3em; border-radius: 12px; background: var(--nb-color-coral); color: var(--nb-color-ink); text-align: center; }
.fill { color: var(--nb-color-coral); }
.waiting-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
.waiting-grid .avatar { --avatar: 52px; font-size: 26px; }
.waiting-grid .player-chip { font-size: 36px; }
.reveal-grid { gap: 14px; }
.reveal-grid .answer-tile { --pad: 14px; font-size: 30px; }
.reveal-grid .answer-tile__author { font-size: 30px; margin-top: 4px; }
.reveal-grid .voters { display: inline-flex; flex-wrap: nowrap; margin: 0 0 0 10px; vertical-align: middle; }
.reveal-grid .voters .avatar { --avatar: 36px; font-size: 18px; }
.surface-phone .answer-tile { --pad: 11px; font-size: calc(16px * var(--nb-text-scale, 1)); }
.tile-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
.tile-grid .answer-tile { --pad: 22px; font-size: 36px; }
.voters { display: flex; gap: 6px; margin-top: 10px; flex-wrap: wrap; }
.voters .avatar { --avatar: 44px; font-size: 22px; }
.tv-foot { display: flex; justify-content: space-between; color: var(--nb-color-text-dim); font-size: var(--fs-caption); font-weight: 700; margin-top: auto; }
.readout-list { display: flex; gap: 16px; }
.readout-list span { width: 64px; height: 64px; border-radius: 18px; display: grid; place-items: center; background: var(--nb-color-ink-raised); font-weight: 900; color: var(--nb-color-text-dim); }
.readout-list span.is-done { background: var(--nb-color-ink-line); color: #fff; }
.readout-list span.is-now { background: var(--nb-color-coral); color: #fff; }
.ph-passage { font-size: calc(19px * var(--nb-text-scale, 1)); font-weight: 800; line-height: 1.4; padding: 14px 16px; border-radius: var(--nb-radius-md); background: var(--nb-color-ink-raised); }
.ph-passage .blank { font-size: .85em; border-radius: 6px; min-width: 2.4em; }
.vote-hint { font-size: var(--fs-caption); font-weight: 700; color: var(--nb-color-text-dim); text-align: center; }
.result-hero { display: flex; flex-direction: column; align-items: center; gap: 10px; padding: 24px 16px; border-radius: var(--nb-radius-xl); background: var(--nb-color-ink-raised); }
.points-big { font-size: 48px; font-weight: 900; color: var(--nb-color-success); }
</style>"""

TOP = "Redacted · Round 2 of 4"
REAL = ("bakery", "1666")
# (fill 1, fill 2, author or None for the real text, voters for it)
VERSIONS = [
    ("competitive soup kitchen", "1066", "Wolfgangster", ["Aiko", "Dev"]),
    ("goose sanctuary", "1666", "Sam", ["Rosa"]),
    ("bakery", "1666", None, ["Priya", "Marcus", "Wolfgangster"]),
    ("wig shop", "1665", "Marcus", ["Sam"]),
    ("very small volcano", "1999", "Priya", []),
    ("haunted laundromat", "1712", "Lena", []),
    ("llama spa", "1666", "Aiko", ["Lena"]),
    ("pie museum", "1667", "Dev", []),
    ("candle shop", "1666", "Rosa", []),
]
COLOUR = dict(PLAYERS)
ME = "Lena"


def passage(a="", b="", tv=True):
    one = f'<span class="fill">{E(a)}</span>' if a else '<span class="blank">1</span>'
    two = f'<span class="fill">{E(b)}</span>' if b else '<span class="blank">2</span>'
    cls = "passage" if tv else "ph-passage"
    return f'<p class="{cls}">The Great Fire of London began in a {one} on Pudding Lane in {two}.</p>'


def safe(*parts):
    return f'<div class="tv-safe">{"".join(parts)}</div>'


def top(label, right_timer=None, face_state="idle", caption=None):
    right = (timer(right_timer, right_timer.endswith(("4", "3", "2", "1")) and right_timer.startswith("0:0")) if right_timer else "") + face(face_state, caption)
    return tv_top(f'<p class="t-label t-dim">{E(label)}</p>', right)


def r1_tv():
    chips = "".join(chip(n, c, *(["submitted"] if i in (0, 2, 4, 6) else [])) for i, (n, c) in enumerate(PLAYERS))
    return safe(top("Round 2 of 4 · Write", "0:42", "wink", "Two blanks. Make them believable."),
                passage(),
                f'<div class="stack"><p class="t-label t-dim">Waiting on 4 players</p><div class="waiting-grid">{chips}</div></div>',
                '<div class="tv-foot"><span>Write on your phone</span><span>Adapted from Wikipedia · CC BY-SA</span></div>'), None, CSS


def ph(body, action="", sub="", center=False, leader=False):
    wrap = "phone-center" if center else "phone-body"
    return (f'{statusbar()}{phone_top(TOP, sub, leader=leader)}<div class="{wrap}">{body}</div>{action}<div class="home-indicator"></div>')


def field(n, value="", error=None):
    cls = " is-error" if error else (" is-focus" if n == 1 and not value else "")
    err = f'<span class="field__error">{E(error)}</span>' if error else "<span></span>"
    return (f'<div class="field{cls}"><label class="field__label">Blank {n}</label><input class="field__input" maxlength="24" '
            f'placeholder="A believable fake" value="{E(value)}"><div class="field__foot">{err}<span class="field__counter">{len(value)}/24</span></div></div>')


def r1_phone():
    head = f'<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Fill the blanks with fakes</p>{timer("0:42")}</div>'
    typing = ph(head + passage(tv=False) + field(1, "haunted laundromat") + field(2, "1712"), phone_action(btn("Submit")), "Write your fakes")
    error = ph(head + passage(tv=False) + field(1, "Bakery", "Too close to the real word, try another") + field(2, "1712"),
               phone_action(btn("Submit", disabled_reason="Fix blank 1 to submit")), "Write your fakes")
    empty = ph(head + passage(tv=False) + field(1) + field(2), phone_action(btn("Submit", disabled_reason="Fill both blanks")), "Write your fakes")
    # The leader sees the same screen plus the Leader pill in the header; the timer stays in the body row.
    leader = ph(head + passage(tv=False) + field(1, "very small volcano") + field(2, "1999"), phone_action(btn("Submit")),
                "Write your fakes", leader=True)
    return (state("typing", typing) + state("empty", empty) + state("too-close", error) + state("leader", leader),
            ["typing", "empty", "too-close", "leader"], CSS)


def r2_tv():
    marks = "".join(f'<span class="{"is-done" if i < 2 else "is-now" if i == 2 else ""}">{i + 1}</span>' for i in range(len(VERSIONS)))
    a, b, *_ = VERSIONS[2]
    return safe(top("Round 2 of 4 · Read-out", None, "idle", "Version 3: bakery, 1666."),
                '<p class="t-label t-coral">Version 3 of 9</p>', passage(a, b),
                f'<div class="readout-list">{marks}</div>',
                '<div class="tv-foot"><span>Listen. Voting opens after all 9.</span><span>Captions on</span></div>'), None, CSS


def r2_phone():
    return ph('<div class="big-icon">👂</div><p class="t-title">Listen up</p><p class="t-body t-dim">Version 3 of 9 is being read on the TV.</p>'
              '<p class="t-caption t-dim">Voting opens on your phone when all 9 are read.</p>', center=True), None, CSS


def tile(i, v, mode="vote", me=False, selected=False):
    a, b, author, voters = v
    text = f'<span class="answer-tile__text">{E(a)} · {E(b)}'
    tag = ""
    cls = "answer-tile"
    if mode == "reveal":
        if author is None:
            cls += " is-real"; tag = '<span class="answer-tile__tag">Real</span>'
            if voters:
                text += '<span class="voters">' + "".join(avatar(n, COLOUR[n], "s") for n in voters) + "</span>"
        else:
            cls += " is-fake"
            fooled = len(voters)
            vs = ('<span class="voters">' + "".join(avatar(n, COLOUR[n], "s") for n in voters) + "</span>") if voters else ""
            text += (f'<span class="answer-tile__author">{avatar(author, COLOUR[author], "s")} {E(author)}'
                     f'{" · fooled " + str(fooled) if fooled else ""}{vs}</span>')
    else:
        if me:
            cls += " is-mine"; tag = '<span class="answer-tile__tag">Yours</span>'
        if selected:
            cls += " is-selected"
    return f'<div class="{cls}"><span class="answer-tile__num">{i + 1}</span>{text}</span>{tag}</div>'


def r3_tv():
    tiles = "".join(tile(i, v) for i, v in enumerate(VERSIONS))
    return safe(top("Round 2 of 4 · Vote", "0:18", "suspicious", "Eight of these are lies."),
                '<p class="t-heading">Which one is the real text?</p>',
                f'<div class="tile-grid">{tiles}</div>',
                '<div class="tv-foot"><span>Vote on your phone · 3 of 8 voted</span><span>You can\'t vote for your own</span></div>'), None, CSS


def r3_phone():
    def tiles(sel):
        return "".join(tile(i, v, me=(v[2] == ME), selected=(i == sel)) for i, v in enumerate(VERSIONS))
    head = f'<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Tap the real one</p>{timer("0:18")}</div>'
    not_voted = ph(head + '<p class="vote-hint">Yours is greyed out. You can\'t vote for it.</p>' + tiles(None), sub="Vote")
    voted = ph(head + '<p class="vote-hint">Voted for 3 · tap another to change</p>' + tiles(2), sub="Vote")
    return state("not-voted", not_voted) + state("voted", voted), ["not-voted", "voted"], CSS


def r4_tv():
    tiles = "".join(tile(i, v, "reveal") for i, v in enumerate(VERSIONS))
    return safe(top("Round 2 of 4 · Reveal", None, "gasp", "That one was real?!"),
                '<p class="t-heading">The real text: <span class="t-coral">bakery · 1666</span></p>',
                f'<div class="tile-grid reveal-grid">{tiles}</div>'), None, CSS


def r4_phone():
    fooled = ph('<div class="result-hero"><p class="t-label t-dim">Your fake</p><p class="t-heading">haunted laundromat · 1712</p>'
                '<p class="t-body t-dim">Fooled nobody this time.</p></div>'
                '<div class="result-hero"><p class="t-label t-dim">Your vote</p><p class="t-heading">llama spa · 1666</p>'
                '<p class="t-body t-danger">✗ Fake, written by Aiko</p></div><p class="points-big" style="color:var(--nb-color-text-dim)">+0</p>',
                sub="Reveal", center=True)
    found = ph('<div class="result-hero"><p class="t-label t-dim">Your vote</p><p class="t-heading">bakery · 1666</p>'
               '<p class="t-body t-success">✓ You found the real one</p></div>'
               '<div class="result-hero"><p class="t-label t-dim">Your fake</p><p class="t-heading">competitive soup kitchen · 1066</p>'
               '<p class="t-body t-success">Fooled Aiko and Dev</p></div><p class="points-big">+2,000</p>',
               sub="Reveal", center=True)
    return state("nothing", fooled) + state("found-and-fooled", found), ["nothing", "found-and-fooled"], CSS


SCORES = [("Wolfgangster", "pink", 4100, 2000), ("Priya", "saffron", 3600, 1000), ("Marcus", "mint", 3100, 1500),
          ("Sam", "sky", 2600, 500), ("Aiko", "lime", 2000, 500), ("Lena", "lilac", 1500, None),
          ("Dev", "teal", 1100, None), ("Rosa", "sand", 600, None)]


def r5_tv():
    return safe(top("Round 2 of 4 · Scores", None, "grin", "Wolfgangster fooled two of you."),
                f'<div class="leaderboard--compact">{leaderboard(SCORES)}</div>'), None, CSS + \
        "<style>.leaderboard--compact .lb-row{padding:4px 20px;line-height:1.15}.leaderboard--compact .avatar--m{--avatar:48px}.leaderboard--compact .leaderboard{gap:10px}</style>"


def r5_phone():
    return ph('<p class="t-label t-dim">After round 2</p><p class="points-big" style="color:var(--nb-color-coral)">#6</p>' +
              avatar("Lena", "lilac", "l") + '<p class="t-title">1,500 points</p><p class="t-body t-dim">+0 this round · 500 behind Aiko</p>'
              '<p class="t-caption t-dim">Next round starts on the TV.</p>', sub="Scores", center=True), None, CSS


PAGES = {
    ("R1", "tv"): r1_tv, ("R1", "phone"): r1_phone, ("R2", "tv"): r2_tv, ("R2", "phone"): r2_phone,
    ("R3", "tv"): r3_tv, ("R3", "phone"): r3_phone, ("R4", "tv"): r4_tv, ("R4", "phone"): r4_phone,
    ("R5", "tv"): r5_tv, ("R5", "phone"): r5_phone,
}
