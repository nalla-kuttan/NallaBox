import { test } from 'node:test';
import assert from 'node:assert/strict';
import { render } from '../../app/Resources/Controller/js/render/index.js';
import '../../app/Resources/Controller/js/render/redacted.js';
import { view } from './fixtures.mjs';

const passage = [{ text: 'The Great Fire of London began in a ' }, { blank: 1 }, { text: ' on Pudding Lane in ' }, { blank: 2 }, { text: '.' }];
const live = (v, extra = {}) => render(v, { mode: 'live', local: {}, offset: 0, join: {}, loadDraft: () => null, ...extra });
const r1 = (over = {}) => view('R1', { top: 'Redacted · Round 2 of 4', round: 2, passage, blanks: 2, submitted: false, waitingOn: [], ...over }, { deadline: 2e9 });

test('R1 has one field per blank, max 24 characters, labelled Blank n', () => {
  const html = live(r1());
  assert.equal((html.match(/class="field__input"/g) ?? []).length, 2);
  assert.equal((html.match(/maxlength="24"/g) ?? []).length, 2);
  assert.match(html, />Blank 1</);
  assert.match(html, />Blank 2</);
  assert.match(html, /Fill both blanks/);
  assert.match(html, /class="blank">1</);
});

test('R1 field error shows under that field and keeps typed values', () => {
  const html = live(r1(), { local: { error: { field: 2, message: 'Too close to the real word, try another' } }, loadDraft: () => ['haunted laundromat', '1666'] });
  const second = html.split('Blank 2')[1];
  assert.match(second, /Too close to the real word, try another/);
  assert.doesNotMatch(html.split('Blank 2')[0], /Too close/);
  assert.match(html, /value="haunted laundromat"/);
  assert.match(html, /Fix blank 2 to submit/);
});

test('R1 after submitting shows Done with Change my answer; changing reopens the form with the answer', () => {
  const done = live(r1({ submitted: true, fields: ['llama spa', '1666'], waitingOn: [{ id: 2, name: 'Sam', colour: 'sky' }] }));
  assert.match(done, /Done!/);
  assert.match(done, /Waiting on 1 player/);
  assert.match(done, />Change my answer</);
  const again = live(r1({ submitted: true, fields: ['llama spa', '1666'] }), { local: { changing: true } });
  assert.match(again, /value="llama spa"/);
});

test('R2 says listen up with the version count', () => {
  assert.match(live(view('R2', { top: 'x', index: 3, count: 9 })), /Version 3 of 9 is being read on the TV/);
});

test('R3 greys out your own version and marks your vote', () => {
  const versions = [{ number: 1, fills: ['soup kitchen', '1066'], mine: false }, { number: 2, fills: ['llama spa', '1666'], mine: true }, { number: 3, fills: ['bakery', '1666'], mine: false }];
  const html = live(view('R3', { top: 'x', round: 2, versions, vote: 3 }, { deadline: 2e9 }));
  assert.match(html, /class="answer-tile is-mine"[^>]*disabled/);
  assert.match(html, />Yours</);
  assert.match(html, /class="answer-tile is-selected"/);
  assert.match(html, /Voted for 3 · tap another to change/);
  assert.match(html, /cast_vote/);
});

test('R4 found-and-fooled shows both lines and the points', () => {
  const html = live(view('R4', { top: 'x', myFake: { fills: ['competitive soup kitchen', '1066'], fooled: ['Aiko', 'Dev'] },
    myVote: { fills: ['bakery', '1666'], real: true, authors: [] }, points: 2000 }));
  assert.match(html, /You found the real one/);
  assert.match(html, /Fooled Aiko and Dev/);
  assert.match(html, /\+2,000/);
  const none = live(view('R4', { top: 'x', myFake: { fills: ['haunted laundromat', '1712'], fooled: [] },
    myVote: { fills: ['llama spa', '1666'], real: false, authors: ['Aiko'] }, points: 0 }));
  assert.match(none, /Fooled nobody this time/);
  assert.match(none, /Fake, written by Aiko/);
});

test('R5 shows rank, points and the line', () => {
  const html = live(view('R5', { top: 'x', label: 'After round 2', rank: 6, points: 1500, line: '+0 this round · 500 behind Aiko' }));
  assert.match(html, /#6/);
  assert.match(html, /1,500 points/);
  assert.match(html, /500 behind Aiko/);
});
