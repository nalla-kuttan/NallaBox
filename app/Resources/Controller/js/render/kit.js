// Component helpers ported from design/mockups/_build/kit.py (same markup and class names).

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/** data-args attribute value (JSON, escaped for a double-quoted attribute). */
export const args = (obj) => esc(JSON.stringify(obj));

/** "1,500" */
export const grouped = (n) => {
  const s = String(Math.abs(Math.trunc(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return (n < 0 ? '−' : '') + s;
};
export const signed = (n) => (n < 0 ? grouped(n) : '+' + grouped(n));

export const firstLetter = (name) => [...String(name ?? '?')][0] ?? '?';

export function avatar(p, size = 'm') {
  return `<span class="avatar avatar--${size}" data-player="${esc(p.colour)}" aria-hidden="true">${esc(firstLetter(p.name))}</span>`;
}

export function chip(p, mods = [], extra = '') {
  const cls = mods.map((m) => `is-${m}`).join(' ');
  const badge = mods.includes('leader') ? '<span class="badge">Leader</span>' : '';
  const tick = mods.includes('submitted') ? '<span class="chip-tick" aria-label="done">✓</span>' : '';
  const off = mods.includes('offline') ? '<span class="chip-off">offline</span>' : '';
  return `<div class="player-chip ${cls}">${avatar(p)}<span class="player-chip__name">${esc(p.name)}</span>${badge}${tick}${off}${extra}</div>`;
}

/** A button. act/actArgs wire it to app.js; disabledReason disables it and shows why below. */
export function btn(label, { kind = 'primary', act, actArgs, disabledReason, small = false, extra = '' } = {}) {
  const cls = `btn btn--${kind}${small ? ' btn--small' : ''}`;
  const wire = act ? ` data-act="${esc(act)}"${actArgs ? ` data-args="${args(actArgs)}"` : ''}` : '';
  if (disabledReason) {
    return `<button class="${cls}"${wire} disabled ${extra}>${esc(label)}</button><p class="btn__reason">${esc(disabledReason)}</p>`;
  }
  return `<button class="${cls}"${wire} ${extra}>${esc(label)}</button>`;
}

export const phoneAction = (...buttons) => `<div class="phone-action">${buttons.join('')}</div>`;

export function phoneTop(title, sub = '', { leader = false } = {}) {
  const pill = leader ? `<button class="leader-pill" aria-label="Leader controls" data-act="sheet" data-args="${args({ open: 'menu' })}">Leader ▾</button>` : '';
  const s = sub ? `<p class="phone-top__sub">${esc(sub)}</p>` : '';
  return `<header class="phone-top"><div><p class="phone-top__title">${esc(title)}</p>${s}</div>${pill}</header>`;
}

/** Screen body: scrolling column (default) or centred, with an optional pinned action. */
export function ph(body, { top = '', action = '', center = false } = {}) {
  return `${top}<div class="${center ? 'phone-center' : 'phone-body'}">${body}</div>${action}`;
}

/** Countdown pill; app.js keeps its text current from data-deadline (host seconds). */
export function timerPill(deadline) {
  if (deadline == null) return '';
  return `<span class="timer-pill" role="timer" data-deadline="${deadline}">0:00</span>`;
}

export function lbRow(s, meId) {
  const d = !s.delta ? '<span class="lb-row__delta is-zero">±0</span>'
    : s.delta > 0 ? `<span class="lb-row__delta">+${grouped(s.delta)}</span>`
      : `<span class="lb-row__delta is-down">${grouped(s.delta)}</span>`;
  return `<div class="lb-row${s.player.id === meId ? ' is-me' : ''}"><span class="lb-row__rank">${s.rank}</span>${avatar(s.player)}`
    + `<span class="lb-row__name">${esc(s.player.name)}</span>${d}<span class="lb-row__points">${grouped(s.points)}</span></div>`;
}

export const leaderboard = (standings, meId) => `<div class="leaderboard">${standings.map((s) => lbRow(s, meId)).join('')}</div>`;

export const logo = () => '<div class="ph-logo"><img src="shared/img/nallabox-symbol-color.svg" alt="">nallabox</div>';

export const plural = (n, one, many = one + 's') => `${n} ${n === 1 ? one : many}`;
