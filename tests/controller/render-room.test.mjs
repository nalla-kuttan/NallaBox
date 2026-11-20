import { test } from 'node:test';
import assert from 'node:assert/strict';
import { render } from '../../app/Resources/Controller/js/render/index.js';
import { games, lobby, view, card } from './fixtures.mjs';

const live = (v, extra = {}) => render(v, { mode: 'live', local: {}, offset: 0, join: {}, ...extra });
const count = (html, needle) => html.split(needle).length - 1;

test('P4: one primary "Choose a game" and the leader pill', () => {
  const html = live(view('P4', lobby()));
  assert.equal(count(html, 'btn btn--primary'), 1);
  assert.match(html, />Choose a game</);
  assert.match(html, /class="leader-pill"/);
  assert.match(html, /3 players in/);
});

test('P4 with too few players shows the reason and disables the button', () => {
  const html = live(view('P4', lobby(2)));
  assert.match(html, /<button class="btn btn--primary"[^>]* disabled/);
  assert.match(html, /Need 3 players to start/);
});

test('P3 has no leader pill and names the leader', () => {
  const html = live(view('P3', lobby(), { id: 2 }));
  assert.doesNotMatch(html, /leader-pill/);
  assert.match(html, /Waiting for Priya to start/);
});

test('P5 lists the games and highlights the previewed one', () => {
  const html = live(view('P5', { games, preview: 'sketch', playerCount: 3, leaderName: 'Priya' }));
  assert.equal((html.match(/class="phone-game( is-selected)?"/g) ?? []).length, 3);
  assert.match(html, /class="phone-game is-selected"[^>]*data-args="[^"]*sketch/);
  assert.match(html, />Pick Composite Sketch</);
});

test('P6 for Insider Trading with 3 players disables Start with the reason', () => {
  const data = {
    game: card('insider', 'Insider Trading', 4), rounds: 6, roundsLabel: '6 rounds', roundsRule: { min: 6, max: 8, default: 6 },
    timer: '1', familyFriendly: true, canStart: false, startBlockedReason: 'Insider Trading needs 4 players', playerCount: 3,
  };
  const html = live(view('P6', data));
  assert.match(html, /<button class="btn btn--primary"[^>]* disabled[^>]*>Start</);
  assert.match(html, /Insider Trading needs 4 players/);
  assert.match(html, /stepper__value">6 rounds</);
  assert.match(html, /class="is-selected"[^>]*>1×</);
});

test('P10 shows who paused, and the leader gets Resume', () => {
  assert.match(live(view('P10', { top: 'Redacted', by: 'Priya', byYou: false }, { id: 2 })), /Paused by Priya/);
  const mine = live(view('P10', { top: 'Redacted', by: 'Priya', byYou: true }));
  assert.match(mine, /You paused the game/);
  assert.match(mine, />Resume</);
});

test('P12 for the leader has Play again and New game', () => {
  const data = { gameName: 'Redacted', rank: 1, points: 7400, line: '+1,500 this round · winner',
    award: { title: 'Top score', note: 'Highest total after 4 rounds', player: { id: 1, name: 'Priya', colour: 'saffron' } } };
  const html = live(view('P12', data));
  assert.match(html, />Play again</);
  assert.match(html, />New game</);
  assert.match(html, /7,400 points/);
  assert.match(html, /Top score/);
  assert.doesNotMatch(live(view('P12', data, { id: 2 })), />Play again</);
});

test('P13 sheet opens over the screen and lists removable players', () => {
  const html = live(view('R3', {}), { sheet: 'remove-player' });
  assert.match(html, /Remove a player/);
  assert.match(html, /Sam/);
  assert.doesNotMatch(html.split('sheet__title')[1], /Priya<\/span><button/);
  const confirm = live(view('R3', {}), { sheet: 'confirm-remove', sheetTarget: 2 });
  assert.match(confirm, /Remove Sam from the room\?/);
});

test('local screens: join form, join errors, reconnecting, removed', () => {
  const join = render(null, { mode: 'join', join: { room: 'BCDF', name: '', colour: null }, local: {} });
  assert.match(join, /Join the game/);
  assert.match(join, /Enter your name to join/);
  assert.equal((join.match(/class="swatch( is-selected)?"/g) ?? []).length, 8);
  assert.match(render(null, { mode: 'join', join: { room: 'BCDF', name: 'Sam', error: { code: 'name_taken', message: 'x' } }, local: {} }), /Sam is taken/);
  assert.match(render(null, { mode: 'join', join: { room: 'KWPZ', error: { code: 'wrong_code' } }, local: {} }), /No room KWPZ/);
  assert.match(render(null, { mode: 'join', join: { error: { code: 'room_full' } }, local: {} }), /This room is full/);
  assert.match(render(null, { mode: 'reconnecting', local: {} }), /Reconnecting to the room/);
  assert.match(render(null, { mode: 'failed', local: {} }), /Can't reach the room/);
  assert.match(render(null, { mode: 'removed', removedReason: 'by_host', local: {} }), /You were removed from this room/);
  assert.match(render(null, { mode: 'removed', removedReason: 'session_ended', local: {} }), /The host ended the session/);
});

test('names are escaped everywhere', () => {
  const evil = { ...lobby(), players: [{ id: 1, name: '<script>x', colour: 'sky', connected: true, isLeader: true, score: 0 }], leaderName: '<script>x' };
  const html = live(view('P3', evil, { id: 1 }));
  assert.doesNotMatch(html, /<script>/);
  assert.match(html, /&lt;script&gt;x/);
});

test('unknown screens render a safe fallback', () => {
  assert.match(live(view('Z9', {})), /Hang tight/);
});

test('P7 gives the leader the pill, and the sheet can skip the how-to', () => {
  const job = { label: 'Redacted · Round 1', icon: '✍', job: 'Write a fake word for each blank' };
  assert.match(live(view('P7', job, { deadline: 2e9 })), /class="leader-pill"/);
  assert.doesNotMatch(live(view('P7', job, { id: 2, deadline: 2e9 })), /leader-pill/);
  assert.match(live(view('P7', job), { sheet: 'menu' }), /Skip this round/);
});
