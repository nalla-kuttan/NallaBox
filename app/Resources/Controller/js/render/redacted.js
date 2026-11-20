// Redacted phone screens R1–R5 (ported from design/mockups/_build/pages_redacted.py).
import { esc, args, avatar, btn, phoneAction, phoneTop, ph, timerPill, grouped, signed, plural } from './kit.js';
import { registerScreens } from './index.js';
import { waiting } from './room.js';

const lead = (view) => !!view.you?.isLeader;

function passage(segments) {
  return '<p class="ph-passage">' + segments.map((s) => (s.blank ? `<span class="blank">${s.blank}</span>` : esc(s.text))).join('') + '</p>';
}

function field(n, value, error) {
  const cls = error ? ' is-error' : '';
  const err = error ? `<span class="field__error">${esc(error)}</span>` : '<span></span>';
  return `<div class="field${cls}"><label class="field__label" for="blank-${n}">Blank ${n}</label>`
    + `<input class="field__input" id="blank-${n}" data-blank="${n}" maxlength="24" autocomplete="off" autocapitalize="none" enterkeyhint="next" placeholder="A believable fake" value="${esc(value)}">`
    + `<div class="field__foot">${err}<span class="field__counter">${[...value].length}/24</span></div></div>`;
}

const fillWord = (n) => (n === 1 ? 'Fill the blank' : n === 2 ? 'Fill both blanks' : `Fill all ${n} blanks`);

function R1(view, ui) {
  const d = view.data;
  if (d.submitted && !ui.local.changing) {
    return waiting(view, { top: d.top, title: 'Done!', detail: d.fields?.join(' · '), waitingOn: d.waitingOn, canChange: true });
  }
  const draft = ui.loadDraft?.(`R1:${d.round}`) ?? d.fields ?? [];
  const values = Array.from({ length: d.blanks }, (_, i) => draft[i] ?? '');
  const err = ui.local.error;
  const empty = values.some((v) => !v.trim());
  const reason = err ? `Fix blank ${err.field} to submit` : empty ? fillWord(d.blanks) : null;
  const head = `<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Fill the blanks with fakes</p>${timerPill(view.deadline)}</div>`;
  const fields = values.map((v, i) => field(i + 1, v, err?.field === i + 1 ? err.message : null)).join('');
  return ph(head + passage(d.passage) + `<div class="stack" data-draft="R1:${d.round}">${fields}</div>`, {
    top: phoneTop(d.top, 'Write your fakes', { leader: lead(view) }),
    action: phoneAction(btn('Submit', { act: 'submit-text', actArgs: { round: d.round }, disabledReason: reason })),
  });
}

function R2(view) {
  const d = view.data;
  return ph('<div class="big-icon">👂</div><p class="t-title">Listen up</p>'
    + `<p class="t-body t-dim">Version ${d.index} of ${d.count} is being read on the TV.</p>`
    + `<p class="t-caption t-dim">Voting opens on your phone when all ${d.count} are read.</p>`,
  { top: phoneTop(d.top, 'Read-out', { leader: lead(view) }), center: true });
}

function tileText(fills) { return esc(fills.join(' · ')); }

function R3(view) {
  const d = view.data;
  const tiles = d.versions.map((v) => {
    const cls = `answer-tile${v.mine ? ' is-mine' : ''}${d.vote === v.number ? ' is-selected' : ''}`;
    const wire = v.mine ? 'disabled aria-disabled="true"' : `data-act="send" data-args="${args({ type: 'cast_vote', fields: { round: d.round, choice: v.number } })}"`;
    return `<button class="${cls}" ${wire} aria-pressed="${d.vote === v.number}"><span class="answer-tile__num">${v.number}</span>`
      + `<span class="answer-tile__text">${tileText(v.fills)}</span>${v.mine ? '<span class="answer-tile__tag">Yours</span>' : ''}</button>`;
  }).join('');
  const hint = d.vote ? `Voted for ${d.vote} · tap another to change` : 'Yours is greyed out. You can\'t vote for it.';
  const head = `<div class="row" style="justify-content:space-between"><p class="t-label t-dim">Tap the real one</p>${timerPill(view.deadline)}</div>`;
  return ph(head + `<p class="vote-hint">${hint}</p>` + tiles, { top: phoneTop(d.top, 'Vote', { leader: lead(view) }) });
}

function names(list) {
  return list.length <= 1 ? esc(list.join('')) : `${esc(list.slice(0, -1).join(', '))} and ${esc(list[list.length - 1])}`;
}

function R4(view) {
  const d = view.data;
  let body = '';
  const vote = d.myVote && `<div class="result-hero"><p class="t-label t-dim">Your vote</p><p class="t-heading">${tileText(d.myVote.fills)}</p>`
    + (d.myVote.real ? '<p class="t-body t-success">✓ You found the real one</p>' : `<p class="t-body t-danger">✗ Fake, written by ${names(d.myVote.authors)}</p>`) + '</div>';
  const fake = d.myFake && `<div class="result-hero"><p class="t-label t-dim">Your fake</p><p class="t-heading">${tileText(d.myFake.fills)}</p>`
    + (d.myFake.fooled.length ? `<p class="t-body t-success">Fooled ${names(d.myFake.fooled)}</p>` : '<p class="t-body t-dim">Fooled nobody this time.</p>') + '</div>';
  body = d.myVote?.real ? (vote ?? '') + (fake ?? '') : (fake ?? '') + (vote ?? '');
  if (!body) body = '<p class="t-body t-dim">Look at the TV to see the real text.</p>';
  body += `<p class="points-big"${d.points ? '' : ' style="color:var(--nb-color-text-dim)"'}>${signed(d.points)}</p>`;
  return ph(body, { top: phoneTop(d.top, 'Reveal', { leader: lead(view) }), center: true });
}

function R5(view) {
  const d = view.data;
  return ph(`<p class="t-label t-dim">${esc(d.label)}</p><p class="points-big" style="color:var(--nb-color-coral)">#${d.rank}</p>`
    + avatar(view.you, 'l') + `<p class="t-title">${grouped(d.points)} points</p><p class="t-body t-dim">${esc(d.line)}</p>`
    + '<p class="t-caption t-dim">Next round starts on the TV.</p>', { top: phoneTop(d.top, 'Scores', { leader: lead(view) }), center: true });
}

registerScreens({ R1, R2, R3, R4, R5 });
export { plural };
