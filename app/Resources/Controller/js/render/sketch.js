// Composite Sketch phone screens C1–C6 (ported from design/mockups/_build/pages_sketch.py) and the drawing wiring.
import { esc, args, avatar, btn, phoneAction, phoneTop, ph, timerPill, grouped, signed } from './kit.js';
import { registerScreens } from './index.js';
import { waiting } from './room.js';
import { COLOURS, strokesToSVG } from '../canvas.js';

const lead = (view) => !!view.you?.isLeader;
const top = (view, sub) => phoneTop(view.data.top, sub, { leader: lead(view) });

function tile(d, { selected = false, mine = false, act, who } = {}) {
  const cls = `drawing-tile${selected ? ' is-selected' : ''}${mine ? ' is-mine' : ''}`;
  const tag = act ? 'button' : 'div';
  const wire = act ? (mine ? ' disabled aria-disabled="true"' : ` data-act="${act.act}" data-args="${args(act.args)}"`) : '';
  const whoTag = who ? `<span class="drawing-tile__who">${avatar(who, 's')}${esc(who.name)}</span>` : '';
  return `<${tag} class="${cls}"${wire} aria-label="Drawing ${d.number}"${act ? ` aria-pressed="${selected}"` : ''}>${strokesToSVG(d.strokes)}`
    + `<span class="drawing-tile__num">${d.number}</span>${whoTag}</${tag}>`;
}

function sceneCard(d, hint) {
  const banned = d.banned?.length ? `<p class="t-label t-dim">Don't say</p><div class="banned">${d.banned.map((w) => `<span>${esc(w)}</span>`).join('')}</div>` : '';
  const art = d.scene.image ? `<img class="scene-img" src="${esc(d.scene.image)}" alt="">` : `<div class="scene-art" aria-hidden="true">${esc(d.scene.art)}</div>`;
  return '<div class="hold-card" role="button" tabindex="0" aria-label="Hold to see the scene" style="min-height:360px">'
    + `<div class="hold-card__cover"><div class="big-icon">👁</div><p class="t-heading">Hold to see the scene</p><p class="hold-card__hint">${esc(hint)}</p></div>`
    + `<div data-secret>${art}<p class="t-heading">${esc(d.scene.caption)}</p>${banned}</div></div>`;
}

const C1Witness = (view) => ph(sceneCard(view.data, view.data.hint), { top: top(view, "You're the Witness") });

const C1Artist = (view) => ph('<div class="big-icon">✎</div><p class="t-title">Get ready to draw</p>'
  + `<p class="t-body t-dim">${esc(view.data.witnessName)} will describe a scene out loud. Draw what you hear. No peeking at ${esc(view.data.witnessName)}'s phone!</p>`
  + timerPill(view.deadline), { top: top(view, "You're an Artist"), center: true });

const C2Witness = (view) => ph(`<div class="row" style="justify-content:space-between"><p class="t-heading">Describe it out loud!</p>${timerPill(view.deadline)}</div>`
  + sceneCard(view.data, view.data.hint), { top: top(view, "You're the Witness") });

function toolbar(ui) {
  const c = ui.local.colour ?? 0, s = ui.local.size ?? 1;
  const sizes = [5, 10, 18];
  return '<div class="draw-toolbar"><div class="draw-toolbar__row">'
    + COLOURS.map((hex, i) => `<button class="draw-color${i === c ? ' is-selected' : ''}" style="background:${hex}" aria-label="Colour ${i + 1}" aria-pressed="${i === c}" data-act="local" data-args="${args({ colour: i })}"></button>`).join('')
    + '</div><div class="draw-toolbar__row">'
    + sizes.map((px, i) => `<button class="draw-size${i === s ? ' is-selected' : ''}" aria-label="Brush ${['small', 'medium', 'large'][i]}" aria-pressed="${i === s}" data-act="local" data-args="${args({ size: i })}"><i style="width:${px}px;height:${px}px"></i></button>`).join('')
    + '<span class="grow"></span><button class="draw-tool" data-act="draw-undo">↶ Undo</button><button class="draw-tool" data-act="draw-clear">Clear</button></div></div>';
}

function C2Artist(view, ui) {
  const d = view.data;
  if (d.done && !ui.local.changing) {
    return waiting(view, { top: d.top, title: 'Done!', detail: 'Your drawing is in.', waitingOn: d.waitingOn, canChange: false });
  }
  return ph(`<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Draw what ${esc(d.witnessName)} describes</p>${timerPill(view.deadline)}</div>`
    + `<div class="ph-canvas"><canvas data-canvas="${d.round}" aria-label="Drawing canvas"></canvas></div>` + toolbar(ui),
  { top: top(view, "You're an Artist"), action: phoneAction(btn("I'm done", { act: 'draw-done', actArgs: { round: d.round } })) });
}

function C3Witness(view, ui) {
  const d = view.data;
  const sel = ui.local.pick ?? d.pick;
  const thumbs = d.drawings.map((t) => tile(t, { selected: t.number === sel, act: { act: 'local', args: { pick: t.number } } })).join('');
  const action = sel
    ? btn(`Pick #${sel}`, { act: 'send', actArgs: { type: 'cast_vote', fields: { round: d.round, choice: sel } } })
    : btn('Pick', { disabledReason: 'Tap a drawing first' });
  const status = d.pick ? `<p class="t-caption t-dim">You picked #${d.pick} · tap another and Pick to change</p>` : '';
  return ph(`<div class="row" style="justify-content:space-between"><p class="t-heading">Pick the closest match</p>${timerPill(view.deadline)}</div>${status}<div class="thumbs">${thumbs}</div>`,
    { top: top(view, "You're the Witness"), action: phoneAction(action) });
}

function C3Artist(view) {
  const d = view.data;
  if (d.number == null) {
    return ph("<div class=\"big-icon\">✎</div><p class=\"t-title\">You didn't draw this round</p>"
      + `<p class="t-body t-dim">${esc(d.witnessName)} is picking the closest match.</p>`, { top: top(view, "You're an Artist"), center: true });
  }
  return ph(`<p class="t-label t-dim">Your drawing</p><div style="width:220px">${tile({ number: d.number, strokes: d.strokes ?? [] })}</div>`
    + `<p class="t-title">Your drawing is up</p><p class="t-body t-dim">${esc(d.witnessName)} is picking the closest match.</p>`,
  { top: top(view, "You're an Artist"), center: true });
}

function C4(view) {
  const d = view.data;
  const pts = `<p class="points-big"${d.points ? '' : ' style="color:var(--nb-color-text-dim)"'}>${signed(d.points)}</p>`;
  let body;
  if (!d.picked) {
    body = '<p class="t-title">No pick this time</p><p class="t-body t-dim">Look at the TV to see the real scene.</p>' + pts;
  } else if (d.role === 'witness') {
    body = `<p class="t-title">You picked #${d.picked.number}</p><div style="width:220px">${tile(d.picked, { who: d.picked.artist })}</div>${pts}`
      + '<p class="t-body t-dim">Look at the TV to see how close it was.</p>';
  } else if (d.yours) {
    body = `<div class="toast toast--success">${esc(d.witnessName)} picked yours!</div><div style="width:220px">${tile(d.picked)}</div>${pts}`
      + '<p class="t-body t-dim">Closest match to the real scene.</p>';
  } else {
    body = `<p class="t-title">${esc(d.witnessName)} picked ${esc(d.picked.artist.name)}'s drawing</p><div style="width:220px">${tile(d.picked, { who: d.picked.artist })}</div>${pts}`
      + '<p class="t-body t-dim">Look at the TV to see the real scene.</p>';
  }
  return ph(body, { top: top(view, 'Scene reveal'), center: true });
}

function C5(view) {
  const d = view.data;
  const mine = d.drawings.find((t) => t.mine);
  const hint = d.vote ? `Voted for #${d.vote} · tap another to change` : mine ? `Yours (#${mine.number}) is greyed out.` : 'Tap the one that looks least like the scene.';
  const thumbs = d.drawings.map((t) => tile(t, { selected: t.number === d.vote, mine: t.mine,
    act: { act: 'send', args: { type: 'cast_vote', fields: { round: d.round, choice: t.number } } } })).join('');
  return ph(`<div class="row" style="justify-content:space-between"><p class="t-heading">Vote for the worst one</p>${timerPill(view.deadline)}</div>`
    + `<p class="t-caption t-dim">${hint}</p><div class="thumbs">${thumbs}</div>`, { top: top(view, 'Most Wanted') });
}

const C6 = (view) => {
  const d = view.data;
  return ph(`<p class="t-label t-dim">${esc(d.label)}</p><p class="points-big" style="color:var(--nb-color-coral)">#${d.rank}</p>`
    + avatar(view.you, 'l') + `<p class="t-title">${grouped(d.points)} points</p><p class="t-body t-dim">${esc(d.line)}</p>`
    + (d.nextWitness ? `<p class="t-caption t-dim">Next Witness: ${esc(d.nextWitness)}</p>` : ''), { top: top(view, 'Scores'), center: true });
};

registerScreens({
  'C1-witness': C1Witness, 'C1-artist': C1Artist, 'C2-witness': C2Witness, 'C2-artist': C2Artist,
  'C3-witness': C3Witness, 'C3-artist': C3Artist, C4, C5, C6,
});
