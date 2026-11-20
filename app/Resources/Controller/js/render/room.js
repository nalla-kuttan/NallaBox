// Room screens P1–P13 (ported from design/mockups/_build/pages_phone.py) plus local-only states.
import { esc, args, avatar, chip, btn, phoneAction, phoneTop, ph, grouped, logo, plural } from './kit.js';

export const COLOURS = ['saffron', 'sky', 'mint', 'lilac', 'pink', 'lime', 'teal', 'sand'];
const LOBBY_SCREENS = new Set(['P2', 'P3', 'P4', 'P5', 'P6', 'P12']);
export const inGame = (view) => !!view && !LOBBY_SCREENS.has(view.screen);

const isLeader = (view) => !!view?.you?.isLeader;

// ---------- P1 / P2: join (local until welcome) ----------

function swatches(selected) {
  return '<div class="swatches">' + COLOURS.map((c) => {
    const on = c === selected;
    return `<button class="swatch${on ? ' is-selected' : ''}" data-player="${c}" aria-label="${c}${on ? ' (selected)' : ''}" aria-pressed="${on}"`
      + ` data-act="colour" data-args="${args({ colour: c })}">${on ? '✓' : ''}</button>`;
  }).join('') + '</div>';
}

function nameField(value, error) {
  const v = value ?? '';
  const err = error ? `<span class="field__error">${esc(error)}</span>` : '<span></span>';
  return `<div class="field${error ? ' is-error' : ''}"><label class="field__label" for="join-name">Your name</label>`
    + `<input class="field__input" id="join-name" maxlength="12" autocomplete="nickname" autocapitalize="words" enterkeyhint="go" placeholder="Up to 12 letters" value="${esc(v)}">`
    + `<div class="field__foot">${err}<span class="field__counter" id="join-count">${[...v].length}/12</span></div></div>`;
}

function roomChip(code) {
  return `<div class="room-chip"><span class="t-label t-dim">Room</span><b>${esc(code)}</b><span class="t-success" style="font-weight:900">✓ found</span></div>`;
}

function codeField(code, error) {
  const err = error ? `<span class="field__error">${esc(error)}</span>` : '<span></span>';
  return `<div class="field${error ? ' is-error' : ''}"><label class="field__label" for="join-room">Room code</label>`
    + `<input class="field__input field__input--code" id="join-room" maxlength="4" autocapitalize="characters" autocomplete="off" value="${esc(code ?? '')}">`
    + `<div class="field__foot">${err}</div></div>`;
}

export function join(ui) {
  const j = ui.join ?? {};
  const e = j.error;
  if (e?.code === 'room_full') {
    return ph('<div class="big-icon">🚪</div><p class="t-title">This room is full</p>'
      + '<p class="t-body t-dim">8 players is the limit. Watch the TV, or ask the leader to start a new room.</p>',
    { action: phoneAction(btn('Try another code', { act: 'join-reset' })), center: true });
  }
  const name = j.name ?? '';
  let nameError = null, colourError = null, codeError = null;
  if (e?.code === 'name_taken') nameError = `${name} is taken. Add a letter or pick another.`;
  else if (e?.code === 'colour_taken') colourError = "That colour's taken. Pick another.";
  else if (e?.code === 'wrong_code') codeError = `No room ${j.room || '----'}. Check the code on the TV.`;
  else if (e) nameError = e.message;
  const showCode = !j.room || e?.code === 'wrong_code' || j.editCode;
  const reason = !name.trim() ? 'Enter your name to join' : !j.colour ? 'Pick a colour' : (showCode && !(j.room ?? '').trim()) ? 'Enter the room code from the TV' : null;
  const label = e?.code === 'wrong_code' ? 'Try again' : 'Join the room';
  const body = logo() + '<p class="t-title">Join the game</p>'
    + (showCode ? codeField(j.room, codeError) : roomChip(j.room))
    + nameField(name, nameError)
    + `<p class="field__label">Pick a colour</p>${colourError ? `<p class="field__error">${esc(colourError)}</p>` : ''}${swatches(j.colour)}`;
  return ph(body, { action: phoneAction(btn(label, { act: 'join', disabledReason: reason })) });
}

// ---------- Local states ----------

export function reconnecting(failed) {
  if (failed) {
    return ph('<div class="big-icon">📶</div><p class="t-title">Can\'t reach the room</p>'
      + '<p class="t-body t-dim">Check you\'re on the same Wi-Fi as the host, then try again. Your answer is saved.</p>',
    { action: phoneAction(btn('Try again', { act: 'retry' })), center: true });
  }
  return ph('<div class="spinner" role="status" aria-label="Reconnecting"></div><p class="t-title">Reconnecting to the room…</p>'
    + '<p class="t-body t-dim">Your answer is saved on this phone.</p>', { center: true });
}

export function removed(reason) {
  if (reason === 'session_ended') {
    return ph('<div class="big-icon">👋</div><p class="t-title">The host ended the session</p>'
      + '<p class="t-body t-dim">Thanks for playing! The final scores are on the TV.</p>', { center: true });
  }
  if (reason === 'replaced') {
    return ph('<div class="big-icon">📱</div><p class="t-title">You\'re playing somewhere else</p>'
      + '<p class="t-body t-dim">This seat opened on another tab or phone. Use that one, or take it back here.</p>',
    { action: phoneAction(btn('Play on this phone', { act: 'reclaim' })), center: true });
  }
  return ph('<div class="big-icon">👋</div><p class="t-title">You were removed from this room</p>'
    + '<p class="t-body t-dim">The host removed you. If that was a mistake, you can join again.</p>',
  { action: phoneAction(btn('Join again', { act: 'rejoin' })), center: true });
}

export const fallback = (view) => ph('<div class="spinner" role="status" aria-label="Loading"></div><p class="t-title">Hang tight</p>'
  + '<p class="t-body t-dim">Look at the TV.</p>', { top: phoneTop(view?.room?.code ? `Room ${view.room.code}` : 'NallaBox', '', { leader: isLeader(view) }), center: true });

// ---------- Server screens ----------

function who(players) {
  return '<div class="who">' + players.map((p) => chip(p, [...(p.isLeader ? ['leader'] : []), ...(p.connected ? [] : ['offline'])])).join('') + '</div>';
}

function P2(view) {
  const you = view.you;
  return ph(avatar(you, 'l') + `<p class="t-title">You're in, ${esc(you.name)}</p>`
    + '<p class="t-body t-dim">A game is already running. You\'ll join when the next game starts.</p>'
    + '<p class="t-caption t-dim">Keep this page open.</p>', { center: true });
}

function P3(view) {
  const d = view.data, you = view.you;
  const me = `<div class="me-card">${avatar(you, 'l')}<p class="t-title">You're in, ${esc(you.name)}</p>`
    + `<p class="t-body t-dim">Waiting for ${esc(d.leaderName ?? 'the leader')} to start</p></div>`;
  return ph(me + `<p class="field__label">${plural(d.players.length, 'player')} in</p>` + who(d.players), { top: phoneTop(`Room ${d.code}`) });
}

function P4(view) {
  const d = view.data, you = view.you;
  const text = d.canStart ? 'Pick a game when everyone\'s in. The TV follows you.' : 'Waiting for more players to join.';
  const me = `<div class="me-card">${avatar(you, 'l')}<p class="t-title">You're the leader</p><p class="t-body t-dim">${text}</p></div>`;
  return ph(me + `<p class="field__label">${plural(d.players.length, 'player')} in</p>` + who(d.players), {
    top: phoneTop(`Room ${d.code}`, '', { leader: true }),
    action: phoneAction(btn('Choose a game', { act: 'leader', actArgs: { action: 'preview_game', args: { game: 'redacted' } }, disabledReason: d.canStart ? null : d.startBlockedReason })),
  });
}

function P5(view) {
  const d = view.data;
  const rows = d.games.map((g) => {
    const sel = g.id === d.preview;
    const meta = d.playerCount < g.minPlayers ? `⚠ Needs ${g.minPlayers} players · ${d.playerCount} in the room` : `${g.players} · ${g.length}`;
    return `<div class="phone-game${sel ? ' is-selected' : ''}" role="button" tabindex="0" aria-pressed="${sel}" data-act="leader" data-args="${args({ action: 'preview_game', args: { game: g.id } })}">`
      + `<div class="phone-game__art" data-player="${esc(g.colour)}">${esc(g.icon)}</div>`
      + `<div class="grow"><p class="t-heading" style="font-size:calc(19px * var(--nb-text-scale, 1))">${esc(g.name)}</p><p class="t-dim">${esc(g.tagline)}</p><p class="t-dim">${esc(meta)}</p></div></div>`;
  }).join('');
  const chosen = d.games.find((g) => g.id === d.preview);
  const action = chosen
    ? btn(`Pick ${chosen.name}`, { act: 'leader', actArgs: { action: 'pick_game', args: { game: chosen.id } } })
    : btn('Pick a game', { disabledReason: 'Tap a game first' });
  return ph('<p class="t-caption t-dim">Tap a game to show it on the TV.</p>' + rows,
    { top: phoneTop('Choose a game', `${plural(d.playerCount, 'player')} in`, { leader: true }), action: phoneAction(action) });
}

const TIMERS = [['1', '1×'], ['1.5', '1.5×'], ['2', '2×'], ['off', 'Off']];
const set = (patch) => ({ action: 'set_settings', args: patch });

function P6(view) {
  const d = view.data, r = d.roundsRule;
  const stepBtn = (label, to, ok) => `<button ${ok ? `data-act="leader" data-args="${args(set({ rounds: to }))}"` : 'disabled'} aria-label="${label === '−' ? 'Fewer' : 'More'} rounds">${label}</button>`;
  const stepper = `<div class="stepper">${stepBtn('−', (d.rounds ?? 0) - 1, r && d.rounds > r.min)}`
    + `<span class="stepper__value">${esc(d.roundsLabel)}</span>${stepBtn('+', (d.rounds ?? 0) + 1, r && d.rounds < r.max)}</div>`;
  const seg = TIMERS.map(([v, l]) => `<button${v === d.timer ? ' class="is-selected"' : ''} aria-pressed="${v === d.timer}" data-act="leader" data-args="${args(set({ timer: v }))}">${l}</button>`).join('');
  const toggle = (on, patch, label) => `<button class="toggle${on ? ' is-on' : ''}" role="switch" aria-checked="${on}" aria-label="${label}" data-act="leader" data-args="${args(set(patch))}"></button>`;
  let rows = `<div class="field"><span class="field__label">Rounds</span>${stepper}</div>`
    + `<div class="field"><span class="field__label">Timer speed</span><div class="segmented">${seg}</div><p class="t-caption t-dim">Slower timers give more time to write and draw.</p></div>`
    + `<div class="setting-row"><div><p>Family-friendly</p><p class="t-caption t-dim">Safe prompts, profanity filter</p></div>${toggle(d.familyFriendly, { family_friendly: !d.familyFriendly }, 'Family-friendly')}</div>`;
  if (d.bannedWords != null) {
    rows += `<div class="setting-row"><div><p>Banned words</p><p class="t-caption t-dim">The Witness can't say 2–3 words</p></div>${toggle(d.bannedWords, { banned_words: !d.bannedWords }, 'Banned words')}</div>`;
  }
  rows += btn('Choose another game', { kind: 'secondary', small: true, act: 'leader', actArgs: { action: 'preview_game', args: { game: d.game.id } }, extra: 'style="width:auto;align-self:center"' });
  return ph(rows, {
    top: phoneTop('Game settings', d.game.name, { leader: true }),
    action: phoneAction(btn('Start', { act: 'leader', actArgs: { action: 'start' }, disabledReason: d.canStart ? null : d.startBlockedReason })),
  });
}

function P7(view) {
  const d = view.data;
  return ph(`<p class="t-label t-dim">${esc(d.label)}</p><div class="big-icon">${esc(d.icon)}</div><p class="t-label t-coral">Your job</p>`
    + `<p class="t-title">${esc(d.job)}</p>${d.detail ? `<p class="t-body t-dim">${esc(d.detail)}</p>` : ''}`
    + (view.deadline ? `<div class="auto-bar"><i data-progress-deadline="${view.deadline}" data-progress-total="15"></i></div>` : ''), { center: true });
}

export function waiting(view, d, { leader = isLeader(view) } = {}) {
  const n = d.waitingOn.length;
  const line = n ? `Waiting on ${plural(n, 'player')}` : 'Everyone\'s in';
  return ph(`<div class="big-icon t-success" style="font-size:56px">✓</div><p class="t-title">${esc(d.title)}</p>`
    + (d.detail ? `<p class="t-body">${esc(d.detail)}</p>` : '')
    + `<p class="t-body t-dim">${line}</p><div class="avatars-row">${d.waitingOn.map((p) => avatar(p)).join('')}</div>`,
  { top: phoneTop(d.top, '', { leader }), action: d.canChange ? phoneAction(btn('Change my answer', { kind: 'secondary', act: 'local', actArgs: { changing: true } })) : '', center: true });
}

const P8 = (view) => waiting(view, view.data);

function P10(view) {
  const d = view.data;
  if (d.byYou || (isLeader(view) && view.room?.paused)) {
    return ph(`<div class="big-icon">⏸</div><p class="t-title">${d.byYou ? 'You paused the game' : `Paused by ${esc(d.by)}`}</p><p class="t-body t-dim">Everyone's timer is frozen.</p>`,
      { top: phoneTop(d.top, '', { leader: true }), action: phoneAction(btn('Resume', { act: 'leader', actArgs: { action: 'resume' } })), center: true });
  }
  return ph(`<div class="big-icon">⏸</div><p class="t-title">Paused by ${esc(d.by)}</p><p class="t-body t-dim">Timers are frozen. Hang tight.</p>`, { center: true });
}

function P12(view) {
  const d = view.data, you = view.you;
  const award = d.award ? `<div class="award-card">${avatar(you, 's')}<div><p class="t-label t-coral">${esc(d.award.title)}</p><p class="t-caption">${esc(d.award.note)}</p></div></div>` : '';
  const body = `<p class="t-label t-dim">${esc(d.gameName)} · Final results</p>`
    + (d.rank ? `<p class="rank-big">#${d.rank}</p>` : '') + avatar(you, 'l')
    + `<p class="t-title">${grouped(d.points)} points</p><p class="t-body t-dim">${esc(d.line)}</p>` + award;
  if (isLeader(view)) {
    return ph(body, {
      top: phoneTop('Game over', '', { leader: true }),
      action: phoneAction(btn('Play again', { act: 'leader', actArgs: { action: 'play_again' } }), btn('New game', { kind: 'secondary', act: 'leader', actArgs: { action: 'new_game' } })),
      center: true,
    });
  }
  return ph(body, { top: phoneTop('Game over'), center: true });
}

// ---------- P13: leader sheet (local overlay) ----------

export function sheet(view, ui) {
  const players = (view.room?.players ?? []).filter((p) => p.id !== view.you.id);
  const close = `data-act="sheet" data-args="${args({ open: null })}"`;
  const open = (to, extra = {}) => `data-act="sheet" data-args="${args({ open: to, ...extra })}"`;
  const leaderAct = (action, a) => `data-act="leader" data-args="${args({ action, ...(a ? { args: a } : {}) })}"`;
  const wrap = (title, inner) => `<div class="sheet-scrim" ${close}></div><div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}">`
    + `<div class="sheet__handle"></div><p class="sheet__title">${esc(title)}</p>${inner}</div>`;
  const target = players.find((p) => p.id === ui.sheetTarget);
  switch (ui.sheet) {
    case 'remove-player':
      return wrap('Remove a player', players.map((p) => `<div class="sheet__item">${avatar(p, 's')}<span class="grow">${esc(p.name)}</span>`
        + `<button class="btn btn--destructive btn--small" ${open('confirm-remove', { target: p.id })}>Remove</button></div>`).join('')
        + '<p class="t-caption t-dim">They can join again with the room code.</p>');
    case 'confirm-remove':
      if (!target) return '';
      return wrap(`Remove ${target.name} from the room?`, `<p class="t-body t-dim">${esc(target.name)} leaves the game now. They can join again with the room code.</p>`
        + `<button class="btn btn--destructive" ${leaderAct('remove_player', { player: target.id })}>Remove ${esc(target.name)}</button>`
        + `<button class="btn btn--secondary" ${close}>Cancel</button>`);
    case 'pass-leader':
      return wrap('Pass leadership', players.filter((p) => p.connected).map((p) => `<button class="sheet__item" ${leaderAct('pass_leader', { player: p.id })}>`
        + `${avatar(p, 's')}<span class="grow">${esc(p.name)}</span><span class="t-dim">›</span></button>`).join('')
        + '<p class="t-caption t-dim">They get the leader controls straight away.</p>');
    case 'confirm-end':
      return wrap('End the game for everyone?', '<p class="t-body t-dim">Scores so far are shown, then everyone goes back to the lobby.</p>'
        + `<button class="btn btn--destructive" ${leaderAct('end')}>End game</button><button class="btn btn--secondary" ${close}>Keep playing</button>`);
    default: {
      const g = inGame(view);
      const paused = !!view.room?.paused;
      const items = (g ? `<button class="sheet__item" ${leaderAct(paused ? 'resume' : 'pause')}>${paused ? '▶ Resume game' : '⏸ Pause game'}</button>`
        + `<button class="sheet__item" ${leaderAct('skip')}>⏭ Skip this round</button>` : '')
        + `<button class="sheet__item" ${open('remove-player')}>👥 Remove a player ›</button>`
        + `<button class="sheet__item" ${open('pass-leader')}>👑 Pass leadership ›</button>`
        + (g ? `<button class="sheet__item sheet__item--danger" ${open('confirm-end')}>⏹ End game</button>` : '');
      return wrap('Leader controls', items);
    }
  }
}

export const screens = { P2, P3, P4, P5, P6, P7, P8, P10, P12 };
