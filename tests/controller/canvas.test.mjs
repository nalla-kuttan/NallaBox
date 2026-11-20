import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDrawing, strokesToSVG, COLOURS, SIZES, MAX_POINTS } from '../../app/Resources/Controller/js/canvas.js';

test('palette: 6 colours, 3 sizes, 2,000 points', () => {
  assert.equal(COLOURS.length, 6);
  assert.equal(SIZES.length, 3);
  assert.equal(MAX_POINTS, 2000);
});

test('strokes are normalised to 0…1; undo and clear work', () => {
  const d = createDrawing();
  d.begin(0.2, 0.3, 1, 2);
  d.extend(1.4, -0.2);
  d.end();
  assert.deepEqual(d.strokes, [{ c: 1, s: 2, p: [0.2, 0.3, 1, 0] }]);
  d.begin(0.5, 0.5, 0, 0); d.extend(0.6, 0.6); d.end();
  assert.equal(d.strokes.length, 2);
  d.undo();
  assert.equal(d.strokes.length, 1);
  d.clear();
  assert.equal(d.strokes.length, 0);
  assert.equal(d.pointCount(), 0);
});

test('drawing stops adding at 2,000 points', () => {
  const d = createDrawing();
  d.begin(0, 0, 0, 0);
  for (let i = 0; i < 3000; i++) d.extend((i % 100) / 100, (i % 37) / 37);
  d.end();
  assert.equal(d.pointCount(), 2000);
  assert.equal(d.begin(0.5, 0.5, 0, 0), false);
});

test('tiny moves are skipped so points are not wasted', () => {
  const d = createDrawing();
  d.begin(0.5, 0.5, 0, 0);
  d.extend(0.5001, 0.5001);
  assert.equal(d.pointCount(), 1);
});

test('strokesToSVG emits one polyline per stroke on paper', () => {
  const svg = strokesToSVG([{ c: 1, s: 0, p: [0.1, 0.1, 0.5, 0.5] }, { c: 3, s: 2, p: [0.2, 0.2] }]);
  assert.equal((svg.match(/<polyline /g) ?? []).length, 2);
  assert.match(svg, /#F6F1EA/);
  assert.match(svg, new RegExp(COLOURS[1]));
});
