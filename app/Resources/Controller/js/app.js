// Wires the renderer to the network and the DOM. Everything visible comes from render(view, ui).
import { connect, clockOffset } from './net.js';
import { render } from './render/index.js';
import { bindHoldCards } from './hold.js';

const $app = document.getElementById('app');
const params = new URLSearchParams(location.search);
const roomFromURL = (params.get('room') || '').trim().toUpperCase();
const wsPort = params.get('ws') || String(Number(location.port || 80) + 1);
const hostSeat = params.get('seat');

const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  del(k) { try { localStorage.removeItem(k); } catch {} },
};
const seatKey = (room) => `nb.seat.${room}`;

const ui = {
  mode: 'join',
  view: null,
  join: { room: roomFromURL, name: store.get('nb.name') || '', colour: store.get('nb.colour') || null, error: null },
  sheet: null,
  sheetTarget: null,
  local: {},
  offset: 0,
  toast: null,
  removedReason: null,
};
window.__nb = ui; // handy when debugging on a phone

let seat = hostSeat || (roomFromURL && store.get(seatKey(roomFromURL))) || null;
if (seat) ui.mode = 'reconnecting';
let failures = 0;
let toastTimer = null;
let pingSent = 0;

const net = connect({
  url: `ws://${location.hostname}:${wsPort}/`,
  onOpen() {
    failures = 0;
    pingSent = Date.now();
    net.send('ping', { t: pingSent });
    if (seat) sendJoin(seat);
  },
  onState(state) {
    if (state === 'closed') {
      failures += 1;
      if (ui.mode === 'live' || ui.mode === 'reconnecting') {
        ui.mode = failures >= 6 ? 'failed' : 'reconnecting';
        draw();
      }
    }
  },
  onMessage,
});

function sendJoin(token) {
  const j = ui.join;
  net.send('join', { room: j.room || roomFromURL, name: j.name || 'Player', colour: j.colour || 'saffron', ...(token ? { seat_token: token } : {}) });
}

function onMessage(m) {
  switch (m.type) {
    case 'pong':
      ui.offset = clockOffset(m.t, Date.now(), m.host_time);
      return;
    case 'welcome':
      seat = m.seat_token;
      store.set(seatKey(ui.join.room || roomFromURL), seat);
      ui.mode = 'live';
      ui.join.error = null;
      document.dispatchEvent(new CustomEvent('nb:welcome'));
      return;
    case 'view': {
      const prev = ui.view;
      ui.view = m;
      ui.mode = 'live';
      if (!prev || prev.screen !== m.screen || prev.data?.round !== m.data?.round) ui.local = {};
      if (!m.you.isLeader) ui.sheet = null;
      wakeLock(!['P3', 'P4', 'P5', 'P6'].includes(m.screen));
      draw();
      return;
    }
    case 'error':
      if (ui.mode !== 'live') {
        if (seat && !hostSeat) { seat = null; store.del(seatKey(ui.join.room || roomFromURL)); }
        ui.mode = 'join';
        ui.join.error = { code: m.code, message: m.message };
      } else if (m.field != null) {
        ui.local.error = { field: m.field, message: m.message };
      } else {
        showToast(m.message);
      }
      draw();
      return;
    case 'removed':
      ui.mode = 'removed';
      ui.removedReason = m.reason;
      if (m.reason !== 'replaced') { store.del(seatKey(ui.join.room || roomFromURL)); seat = null; }
      wakeLock(false);
      draw();
      return;
    default:
  }
}

function showToast(text) {
  ui.toast = text;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { ui.toast = null; draw(); }, 3000);
}

// ---------- Drawing ----------

function draw() {
  const active = document.activeElement;
  const focusId = active && active.id && $app.contains(active) ? active.id : null;
  const sel = focusId && 'selectionStart' in active ? [active.selectionStart, active.selectionEnd] : null;
  $app.innerHTML = render(ui.view, ui);
  bindHoldCards($app);
  document.dispatchEvent(new CustomEvent('nb:drawn', { detail: { root: $app, ui, net } }));
  if (focusId) {
    const el = document.getElementById(focusId);
    if (el) { el.focus({ preventScroll: true }); if (sel && el.setSelectionRange) try { el.setSelectionRange(...sel); } catch {} }
  }
  tick();
}

function remaining(deadline) { return deadline - (Date.now() / 1000 + ui.offset); }

function tick() {
  $app.querySelectorAll('[data-deadline]').forEach((el) => {
    const s = Math.max(0, Math.ceil(remaining(Number(el.dataset.deadline))));
    el.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
    el.classList.toggle('is-urgent', s <= 10);
  });
  $app.querySelectorAll('[data-progress-deadline]').forEach((el) => {
    const total = Number(el.dataset.progressTotal) || 15;
    el.style.width = `${Math.max(0, Math.min(1, remaining(Number(el.dataset.progressDeadline)) / total)) * 100}%`;
  });
}
setInterval(tick, 250);

// ---------- Input ----------

const actions = {
  join() {
    const j = ui.join;
    const code = document.getElementById('join-room');
    if (code) j.room = code.value.trim().toUpperCase();
    j.name = (document.getElementById('join-name')?.value ?? j.name).trim();
    if (!j.name || !j.colour || !j.room) return draw();
    store.set('nb.name', j.name);
    store.set('nb.colour', j.colour);
    j.error = null;
    if (!net.connected) { ui.mode = 'reconnecting'; draw(); net.retry(); return; }
    sendJoin(null);
  },
  colour({ colour }) { ui.join.colour = colour; ui.join.error = ui.join.error?.code === 'colour_taken' ? null : ui.join.error; draw(); },
  'join-reset'() { ui.join.error = null; ui.join.editCode = true; draw(); },
  leader({ action, args }) { net.send('leader', { action, args: args ?? {} }); ui.sheet = null; draw(); },
  sheet({ open, target }) { ui.sheet = open; ui.sheetTarget = target ?? null; draw(); },
  send({ type, fields }) { net.send(type, fields ?? {}); },
  local(patch) { Object.assign(ui.local, patch); draw(); },
  retry() { failures = 0; ui.mode = 'reconnecting'; draw(); net.retry(); },
  rejoin() { seat = null; ui.mode = 'join'; ui.view = null; ui.join.error = null; draw(); },
  reclaim() { ui.mode = 'reconnecting'; draw(); net.retry(); },
};

$app.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el || el.disabled || !$app.contains(el)) return;
  const fn = actions[el.dataset.act];
  const a = el.dataset.args ? JSON.parse(el.dataset.args) : {};
  if (fn) fn(a, el);
  else document.dispatchEvent(new CustomEvent('nb:act', { detail: { act: el.dataset.act, args: a, el, ui, net, draw } }));
});

$app.addEventListener('keydown', (e) => {
  const el = e.target.closest('[role="button"][data-act]');
  if (el && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); el.click(); }
  if (e.key === 'Enter' && e.target.id === 'join-name') actions.join();
});

$app.addEventListener('input', (e) => {
  if (e.target.id === 'join-name') { ui.join.name = e.target.value; draw(); }
  else if (e.target.id === 'join-room') { ui.join.room = e.target.value.toUpperCase(); draw(); }
  else document.dispatchEvent(new CustomEvent('nb:input', { detail: { el: e.target, ui, net, draw } }));
});

// ---------- Screen wake lock ----------

let lock = null, wantLock = false;
async function wakeLock(on) {
  wantLock = on;
  try {
    if (on && !lock && navigator.wakeLock) { lock = await navigator.wakeLock.request('screen'); lock.addEventListener('release', () => { lock = null; }); }
    if (!on && lock) { await lock.release(); lock = null; }
  } catch { lock = null; }
}
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    if (wantLock) wakeLock(true);
    if (!net.connected && ui.mode !== 'join' && ui.mode !== 'removed') net.retry();
  }
});

// Larger text for people who set a bigger default font size.
const base = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
if (base > 16) document.documentElement.style.setProperty('--nb-text-scale', String(Math.min(1.4, base / 16)));

draw();
