import { test } from 'node:test';
import assert from 'node:assert/strict';
import { render } from '../../app/Resources/Controller/js/render/index.js';
import '../../app/Resources/Controller/js/render/insider.js';
import { view, players } from './fixtures.mjs';

const live = (v, extra = {}) => render(v, { mode: 'live', local: {}, offset: 0, join: {}, loadDraft: () => null, ...extra });
const q = { question: 'Which planet has the most known moons?', choices: ['Jupiter', 'Saturn', 'Uranus', 'Neptune'] };
const stripSecret = (html) => html.replace(/<div data-secret>.*?<\/div><\/div>/s, '');

test('I1: Insider and Trader pages are identical outside the secret', () => {
  for (const s of ['I1', 'I2']) {
    const ins = live(view(`${s}-insider`, { top: 'x', role: 'insider', answerKey: 'B', answerText: 'Saturn', ...q }, { deadline: 2e9 }));
    const tra = live(view(`${s}-trader`, { top: 'x', role: 'trader', ...q }, { deadline: 2e9 }));
    assert.equal(stripSecret(ins), stripSecret(tra));
    assert.match(ins, /You are the Insider/);
    assert.match(ins, /Answer: B · Saturn/);
    assert.doesNotMatch(tra, /Saturn<\/p>/);
    assert.match(tra, /You are a Trader/);
  }
});

test('I3: choices A–D, a 100-step slider up to your max, Bet disabled until you choose', () => {
  const d = { top: 'x', round: 3, ...q, chips: 5500, minBet: 100, maxBet: 1000, step: 100 };
  const html = live(view('I3', d, { deadline: 2e9 }));
  assert.equal((html.match(/class="choice__key"/g) ?? []).length, 4);
  assert.match(html, /type="range"[^>]*min="100"[^>]*max="1000"[^>]*step="100"/);
  assert.match(html, /Pick an answer first/);
  const chosen = live(view('I3', d, { deadline: 2e9 }), { local: { choice: 1, chips: 400 } });
  assert.match(chosen, />Bet 400 on B</);
  assert.match(chosen, /You have 5,500 chips/);
  const placed = live(view('I3', { ...d, bet: { choice: 1, chips: 400 } }));
  assert.match(placed, /Bet placed/);
  assert.match(placed, /400 chips on B · Saturn/);
});

test('I5 lists everyone but you, and marks your vote', () => {
  const html = live(view('I5', { top: 'x', round: 3, candidates: players.slice(1), vote: 3 }, { deadline: 2e9 }));
  assert.doesNotMatch(html, />Priya</);
  assert.match(html, /Sam/);
  assert.match(html, /class="player-chip is-selected"[^]*Lena/);
  assert.match(html, /You named Lena/);
});

test('I6 caught and escaped', () => {
  const insider = { id: 2, name: 'Marcus', colour: 'mint' };
  const caught = live(view('I6', { top: 'x', caught: true, insider, youAreInsider: false, named: 'Marcus', accusers: 5, commission: 0, delta: 300, chips: 6200 }));
  assert.match(caught, /You caught Marcus!/);
  assert.match(caught, /\+300 chips/);
  const escaped = live(view('I6', { top: 'x', caught: false, insider, youAreInsider: false, named: 'Dev', accusers: 2, commission: 100, delta: 0, chips: 5900 }));
  assert.match(escaped, /Marcus got away/);
  assert.match(escaped, /You named Dev/);
  const me = live(view('I6', { top: 'x', caught: false, insider, youAreInsider: true, accusers: 1, commission: 100, delta: 100, chips: 6800 }));
  assert.match(me, /You got away/);
});

test('I4 won and lost', () => {
  const won = live(view('I4', { top: 'x', correctKey: 'B', correctText: 'Saturn', bet: { choice: 1, chips: 400 }, betText: 'Saturn', delta: 400, chips: 5900 }));
  assert.match(won, /\+400 chips/);
  assert.match(won, /Now 5,900 chips/);
  const lost = live(view('I4', { top: 'x', correctKey: 'B', correctText: 'Saturn', bet: { choice: 0, chips: 800 }, betText: 'Jupiter', delta: -800, chips: 4500 }));
  assert.match(lost, /−800 chips/);
  assert.match(lost, /You bet 800 on Jupiter/);
});
