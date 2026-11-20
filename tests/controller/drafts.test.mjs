import { test } from 'node:test';
import assert from 'node:assert/strict';
import { saveDraft, loadDraft, clearDraft } from '../../app/Resources/Controller/js/drafts.js';

const store = () => {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k) };
};

test('drafts round-trip and clear', () => {
  const s = store();
  saveDraft('R1:2', ['goose', ''], s);
  assert.deepEqual(loadDraft('R1:2', s), ['goose', '']);
  clearDraft('R1:2', s);
  assert.equal(loadDraft('R1:2', s), null);
});

test('drafts survive a throwing store', () => {
  const bad = { getItem() { throw new Error('no'); }, setItem() { throw new Error('no'); }, removeItem() { throw new Error('no'); } };
  saveDraft('x', 1, bad);
  assert.equal(loadDraft('x', bad), null);
});
