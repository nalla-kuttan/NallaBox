// Hold-to-reveal cards: press and hold >= 300 ms (pointer, or Space/Enter held) shows [data-secret].
// Sliding off the card, lifting the finger or losing focus hides it again.
export function bindHoldCards(root) {
  root.querySelectorAll('.hold-card').forEach((card) => {
    if (card.dataset.holdBound) return;
    card.dataset.holdBound = '1';
    let t;
    const on = () => { clearTimeout(t); t = setTimeout(() => card.classList.add('is-held'), 300); };
    const off = () => { clearTimeout(t); card.classList.remove('is-held'); };
    card.addEventListener('pointerdown', (e) => {
      // Touch pointers are captured implicitly; release so sliding off the card hides the secret.
      if (card.hasPointerCapture && card.hasPointerCapture(e.pointerId)) card.releasePointerCapture(e.pointerId);
      on();
    });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => card.addEventListener(ev, off));
    card.addEventListener('contextmenu', (e) => e.preventDefault());
    card.addEventListener('keydown', (e) => { if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) { e.preventDefault(); on(); } });
    card.addEventListener('keyup', (e) => { if (e.key === ' ' || e.key === 'Enter') off(); });
    card.addEventListener('blur', off);
  });
}
