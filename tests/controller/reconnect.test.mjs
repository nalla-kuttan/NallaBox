import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createOutbox } from '../../app/Resources/Controller/js/outbox.js';
import { connect } from '../../app/Resources/Controller/js/net.js';

const view = (screen, round) => ({ type: 'view', screen, data: { round } });

test('a submit made while offline is resent once after reconnecting, for the current round only', () => {
  const out = createOutbox();
  out.queue('submit_text', { round: 2, fields: ['goose', 'bank'] });
  out.queue('cast_vote', { round: 1, choice: 3 });
  const sent = [];
  out.flush(view('R1', 2), (type, f) => sent.push([type, f]));
  assert.deepEqual(sent, [['submit_text', { round: 2, fields: ['goose', 'bank'] }]]);
  out.flush(view('R1', 2), (type, f) => sent.push([type, f]));
  assert.equal(sent.length, 1);
});

test('a newer input of the same kind replaces the queued one', () => {
  const out = createOutbox();
  out.queue('cast_vote', { round: 1, choice: 2 });
  out.queue('cast_vote', { round: 1, choice: 4 });
  const sent = [];
  out.flush(view('R3', 1), (type, f) => sent.push(f.choice));
  assert.deepEqual(sent, [4]);
});

test('net.send reports whether the message went out', () => {
  class Sock { constructor() { this.readyState = 0; Sock.last = this; } send() {} close() {} }
  const net = connect({ url: 'ws://x', WebSocketImpl: Sock, setTimer: () => 0 });
  assert.equal(net.send('ping', { t: 1 }), null);
  Sock.last.readyState = 1;
  assert.ok(net.send('ping', { t: 1 }));
});
