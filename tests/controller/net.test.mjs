import { test } from 'node:test';
import assert from 'node:assert/strict';
import { backoff, clockOffset, connect } from '../../app/Resources/Controller/js/net.js';

test('backoff doubles from 500 ms to an 8 s cap', () => {
  assert.deepEqual([0, 1, 2, 3, 4, 5, 6].map(backoff), [500, 1000, 2000, 4000, 8000, 8000, 8000]);
});

test('clock offset is host time minus the round-trip midpoint', () => {
  assert.equal(clockOffset(1000, 1200, 5.0), 3.9);
});

class FakeSocket {
  static all = [];
  constructor(url) { this.url = url; this.sent = []; this.readyState = 0; FakeSocket.all.push(this); }
  send(s) { this.sent.push(JSON.parse(s)); }
  close() { this.readyState = 3; this.onclose?.(); }
  open() { this.readyState = 1; this.onopen?.(); }
  push(obj) { this.onmessage?.({ data: JSON.stringify(obj) }); }
}

test('connect sends v1 messages with ids, reconnects with backoff after a drop', () => {
  FakeSocket.all = [];
  const timers = [];
  const states = [], got = [];
  const net = connect({
    url: 'ws://h:8081/', WebSocketImpl: FakeSocket, setTimer: (fn, ms) => { timers.push(ms); fn(); return 0; },
    onMessage: (m) => got.push(m), onState: (s) => states.push(s),
  });
  const ws = FakeSocket.all[0];
  ws.open();
  const id = net.send('ping', { t: 5 });
  assert.deepEqual(ws.sent[0], { v: 1, type: 'ping', id, t: 5 });
  ws.push({ type: 'pong', t: 5, host_time: 9 });
  assert.equal(got[0].type, 'pong');
  ws.close();
  assert.equal(FakeSocket.all.length, 2);
  assert.deepEqual(timers, [500]);
  FakeSocket.all[1].close();
  assert.deepEqual(timers, [500, 1000]);
  assert.ok(states.includes('open') && states.includes('closed'));
});
