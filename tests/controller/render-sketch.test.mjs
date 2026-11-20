import { test } from 'node:test';
import assert from 'node:assert/strict';
import { render } from '../../app/Resources/Controller/js/render/index.js';
import '../../app/Resources/Controller/js/render/sketch.js';
import { view } from './fixtures.mjs';

const live = (v, extra = {}) => render(v, { mode: 'live', local: {}, offset: 0, join: {}, loadDraft: () => null, ...extra });
const scene = { caption: 'A raccoon in a tuxedo buying bread', art: '🦝🤵🥖🏪' };
const tile = (number, mine = false) => ({ number, strokes: [{ c: 0, s: 1, p: [0.1, 0.1, 0.9, 0.9] }], mine });

test('C1: the Witness holds to see the scene; artists get ready and never see it', () => {
  const w = live(view('C1-witness', { top: 'x', scene, banned: ['raccoon', 'tuxedo', 'bread'], hint: 'Keep your screen to yourself.' }));
  assert.equal((w.match(/class="hold-card"/g) ?? []).length, 1);
  assert.match(w.split('data-secret')[1], /A raccoon in a tuxedo/);
  assert.doesNotMatch(w.split('data-secret')[0], /A raccoon in a tuxedo/);
  assert.match(w, /Don't say/);
  const a = live(view('C1-artist', { top: 'x', witnessName: 'Lena' }, { id: 2, deadline: 2e9 }));
  assert.match(a, /Get ready to draw/);
  assert.doesNotMatch(a, /data-secret|raccoon/);
});

test('C2-artist: 6 colours, 3 sizes, Undo, Clear, a square canvas and I\'m done', () => {
  const html = live(view('C2-artist', { top: 'x', round: 2, witnessName: 'Lena', done: false, waitingOn: [] }, { id: 2, deadline: 2e9 }));
  assert.equal((html.match(/class="draw-color/g) ?? []).length, 6);
  assert.equal((html.match(/class="draw-size/g) ?? []).length, 3);
  assert.match(html, />↶ Undo</);
  assert.match(html, />Clear</);
  assert.match(html, /<canvas[^>]*data-canvas="2"/);
  assert.match(html, />I&#39;m done</);
  const done = live(view('C2-artist', { top: 'x', round: 2, witnessName: 'Lena', done: true, waitingOn: [{ id: 3, name: 'Sam', colour: 'sky' }] }, { id: 2 }));
  assert.match(done, /Done!/);
});

test('C3-witness: thumbnails pick a drawing, then Pick #n sends the vote', () => {
  const html = live(view('C3-witness', { top: 'x', round: 1, drawings: [tile(1), tile(2), tile(3)] }), { local: { pick: 2 } });
  assert.equal((html.match(/class="drawing-tile( is-selected| is-mine)*"/g) ?? []).length, 3);
  assert.match(html, /data-act="local"[^>]*pick&quot;:3/);
  assert.match(html, /class="drawing-tile is-selected"/);
  assert.match(html, />Pick #2</);
  assert.match(html, /cast_vote/);
  assert.match(live(view('C3-witness', { top: 'x', round: 1, drawings: [tile(1)] })), /Tap a drawing first/);
});

test('C3-artist: your drawing is up, or you did not draw', () => {
  assert.match(live(view('C3-artist', { top: 'x', witnessName: 'Lena', number: 2, strokes: tile(2).strokes }, { id: 2 })), /Your drawing is up/);
  assert.match(live(view('C3-artist', { top: 'x', witnessName: 'Lena' }, { id: 2 })), /You didn't draw this round|You didn&#39;t draw this round/);
});

test('C4: picked and not-picked artists, and the Witness', () => {
  const picked = { number: 3, strokes: tile(3).strokes, artist: { id: 2, name: 'Sam', colour: 'sky' } };
  assert.match(live(view('C4', { top: 'x', role: 'artist', witnessName: 'Lena', picked, yours: true, points: 1000 }, { id: 2 })), /Lena picked yours!/);
  const other = live(view('C4', { top: 'x', role: 'artist', witnessName: 'Lena', picked, yours: false, points: 0 }, { id: 3 }));
  assert.match(other, /Lena picked Sam('|&#39;)s drawing/);
  assert.match(other, /\+0/);
  assert.match(live(view('C4', { top: 'x', role: 'witness', witnessName: 'Lena', picked, yours: false, points: 500 })), /You picked #3/);
});

test('C5: your drawing is greyed out and your vote is marked', () => {
  const html = live(view('C5', { top: 'x', round: 1, drawings: [tile(1), tile(2, true), tile(3)], vote: 3 }));
  assert.match(html, /class="drawing-tile is-mine"[^>]*disabled/);
  assert.match(html, /class="drawing-tile is-selected"/);
  assert.match(html, /Voted for #3 · tap another to change/);
});

test('C6 shows the next Witness', () => {
  assert.match(live(view('C6', { top: 'x', label: 'After round 4', rank: 4, points: 2000, line: '+0 this round · 500 behind Priya', nextWitness: 'Wolfgangster' })),
    /Next Witness: Wolfgangster/);
});
