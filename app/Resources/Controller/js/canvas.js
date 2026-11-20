// Drawing for Composite Sketch: a pure stroke model (normalised 0…1 on a square) plus a pointer-driven canvas.

export const COLOURS = ['#1E1B2E', '#FF5C39', '#FFB020', '#3DB7FF', '#4ED19A', '#B58CFF'];
/** Brush widths as a fraction of the canvas side (5, 10 and 18 px on a 400 px canvas). */
export const SIZES = [0.0125, 0.025, 0.045];
export const MAX_POINTS = 2000;
export const PAPER = '#F6F1EA';
const MIN_STEP = 0.004;

const clamp = (v) => Math.round(Math.min(1, Math.max(0, v)) * 10000) / 10000;

export function createDrawing(initial = []) {
  const strokes = initial.map((s) => ({ c: s.c, s: s.s, p: [...s.p] }));
  let current = null;
  const pointCount = () => strokes.reduce((n, s) => n + s.p.length / 2, 0);
  return {
    strokes,
    pointCount,
    begin(x, y, c, s) {
      if (pointCount() >= MAX_POINTS) return false;
      current = { c, s, p: [clamp(x), clamp(y)] };
      strokes.push(current);
      return true;
    },
    extend(x, y) {
      if (!current || pointCount() >= MAX_POINTS) return false;
      const n = current.p.length;
      const nx = clamp(x), ny = clamp(y);
      if (Math.hypot(nx - current.p[n - 2], ny - current.p[n - 1]) < MIN_STEP) return false;
      current.p.push(nx, ny);
      return true;
    },
    end() { current = null; },
    undo() { current = null; strokes.pop(); },
    clear() { current = null; strokes.length = 0; },
  };
}

/** Small SVG of a drawing for thumbnails (viewBox 0…1). */
export function strokesToSVG(strokes) {
  const lines = strokes.map((s) => {
    const pts = s.p.length === 2 ? [...s.p, s.p[0] + 0.0001, s.p[1]] : s.p;
    const points = [];
    for (let i = 0; i < pts.length; i += 2) points.push(`${pts[i]},${pts[i + 1]}`);
    return `<polyline points="${points.join(' ')}" fill="none" stroke="${COLOURS[s.c] ?? COLOURS[0]}" stroke-width="${SIZES[s.s] ?? SIZES[1]}" stroke-linecap="round" stroke-linejoin="round"/>`;
  }).join('');
  return `<svg viewBox="0 0 1 1" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><rect width="1" height="1" fill="${PAPER}"/>${lines}</svg>`;
}

/** Wires a <canvas> to a drawing. `tool()` returns the current {c, s}; `onChange` fires after each stroke change. */
export function mountCanvas(el, drawing, tool, onChange) {
  const ctx = el.getContext('2d');
  const size = () => {
    const r = el.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    el.width = Math.round(r.width * dpr);
    el.height = Math.round(r.height * dpr);
    redraw();
  };
  function redraw() {
    const w = el.width;
    ctx.fillStyle = PAPER;
    ctx.fillRect(0, 0, w, el.height);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (const s of drawing.strokes) {
      ctx.strokeStyle = COLOURS[s.c];
      ctx.lineWidth = SIZES[s.s] * w;
      ctx.beginPath();
      ctx.moveTo(s.p[0] * w, s.p[1] * w);
      if (s.p.length === 2) ctx.lineTo(s.p[0] * w + 0.1, s.p[1] * w);
      for (let i = 2; i < s.p.length; i += 2) ctx.lineTo(s.p[i] * w, s.p[i + 1] * w);
      ctx.stroke();
    }
  }
  const pos = (e) => {
    const r = el.getBoundingClientRect();
    return [(e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height];
  };
  let down = false;
  el.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    el.setPointerCapture(e.pointerId);
    const { c, s } = tool();
    down = drawing.begin(...pos(e), c, s);
    redraw();
  });
  el.addEventListener('pointermove', (e) => {
    if (!down) return;
    for (const ev of e.getCoalescedEvents ? e.getCoalescedEvents() : [e]) drawing.extend(...pos(ev));
    redraw();
  });
  const up = () => { if (down) { down = false; drawing.end(); onChange(); } };
  el.addEventListener('pointerup', up);
  el.addEventListener('pointercancel', up);
  el.style.touchAction = 'none';
  size();
  return { redraw, resize: size };
}
