// Insider Trading phone screens I1–I6 (ported from design/mockups/_build/pages_insider.py).
// Insider and Trader pages share every byte outside [data-secret], so a glance can't tell them apart.
import { esc, args, avatar, chip, btn, phoneAction, phoneTop, ph, timerPill, grouped, signed } from './kit.js';
import { registerScreens } from './index.js';

const KEYS = ['A', 'B', 'C', 'D'];
const lead = (view) => !!view.you?.isLeader;
const top = (view, sub) => phoneTop(view.data.top, sub, { leader: lead(view) });

function qBlock(d) {
  return `<p class="ph-q">${esc(d.question)}</p><div class="ph-choices">`
    + d.choices.map((c, i) => `<div class="choice"><span class="choice__key">${KEYS[i]}</span>${esc(c)}</div>`).join('') + '</div>';
}

function rolePage(stage) {
  return (view) => {
    const d = view.data;
    const secret = d.role === 'insider'
      ? `<p class="t-label t-coral">You are the Insider</p><p class="t-title">Answer: ${esc(d.answerKey)} · ${esc(d.answerText)}</p>`
        + '<p class="hold-card__hint">Steer the group to it, but don\'t get caught.</p>'
      : '<p class="t-label t-coral">You are a Trader</p><p class="t-title">Find the Insider</p>'
        + '<p class="hold-card__hint">Someone here knows the answer. Watch who sounds too sure.</p>';
    const head = `<div class="row" style="justify-content:space-between"><p class="t-label t-dim">${stage === 'I1' ? 'Read your role' : 'Talk it out'}</p>${timerPill(view.deadline)}</div>`;
    const card = '<div class="hold-card" role="button" tabindex="0" aria-label="Hold to see your role"><div class="hold-card__cover"><div class="big-icon">🤫</div>'
      + '<p class="t-heading">Hold to see your role</p><p class="hold-card__hint">Tilt your phone away from your neighbours</p></div>'
      + `<div data-secret>${secret}</div></div>`;
    return ph(head + card + qBlock(d), { top: top(view, stage === 'I1' ? 'Your role' : 'Discuss') });
  };
}

function I3(view, ui) {
  const d = view.data;
  if (d.bet && !ui.local.changing) {
    return ph('<div class="big-icon t-success">✓</div><p class="t-title">Bet placed</p>'
      + `<p class="t-heading">${grouped(d.bet.chips)} chips on ${KEYS[d.bet.choice]} · ${esc(d.choices[d.bet.choice])}</p>`
      + '<p class="t-body t-dim">Waiting for the others to bet</p>',
    { top: top(view, 'Bet'), action: phoneAction(btn('Change my bet', { kind: 'secondary', act: 'local', actArgs: { changing: true } })), center: true });
  }
  const choice = ui.local.choice ?? d.bet?.choice;
  const max = Math.max(d.minBet, d.maxBet);
  const chips = Math.min(max, ui.local.chips ?? d.bet?.chips ?? Math.min(400, max));
  const picks = '<div class="ph-choices">' + d.choices.map((c, i) => `<button class="choice${i === choice ? ' is-selected' : ''}" aria-pressed="${i === choice}" `
    + `data-act="local" data-args="${args({ choice: i })}"><span class="choice__key">${KEYS[i]}</span>${esc(c)}</button>`).join('') + '</div>';
  const slider = `<div class="chip-slider"><div class="chip-slider__value"><span class="t-label t-dim">Your bet</span><b>${grouped(chips)}</b></div>`
    + `<input type="range" id="bet-chips" data-bet min="${d.minBet}" max="${max}" step="${d.step}" value="${chips}" aria-label="Bet">`
    + `<div class="chip-slider__ends"><span>${grouped(d.minBet)}</span><span>${grouped(max)}</span></div></div>`;
  const head = `<div class="row" style="justify-content:space-between"><p class="ph-q">${esc(d.question)}</p>${timerPill(view.deadline)}</div>`;
  const action = choice == null
    ? btn('Bet', { disabledReason: 'Pick an answer first' })
    : btn(`Bet ${grouped(chips)} on ${KEYS[choice]}`, { act: 'send', actArgs: { type: 'place_bet', fields: { round: d.round, choice, chips } } });
  return ph(head + picks + slider + `<p class="chips-left">You have ${grouped(d.chips)} chips</p>`, { top: top(view, 'Bet'), action: phoneAction(action) });
}

function I4(view) {
  const d = view.data;
  const hero = `<div class="result-hero"><p class="t-label t-dim">The answer</p><p class="t-title">${esc(d.correctKey)} · ${esc(d.correctText)}</p></div>`;
  if (!d.bet) {
    return ph(hero + '<p class="points-big" style="color:var(--nb-color-text-dim)">+0</p><p class="t-body t-dim">You didn\'t bet this round.</p>'
      + `<p class="chips-left">${grouped(d.chips)} chips</p>`, { top: top(view, 'Answer'), center: true });
  }
  const won = d.delta > 0;
  return ph(hero + `<p class="points-big ${won ? 't-success' : 't-danger'}">${signed(d.delta)} chips</p>`
    + `<p class="t-body t-dim">You bet ${grouped(d.bet.chips)} on ${esc(d.betText)}.${won ? ' Nice.' : ''}</p><p class="chips-left">Now ${grouped(d.chips)} chips</p>`,
  { top: top(view, 'Answer'), center: true });
}

function I5(view) {
  const d = view.data;
  const named = d.candidates.find((p) => p.id === d.vote);
  const list = '<div class="accuse-list">' + d.candidates.map((p) => `<button class="player-chip${p.id === d.vote ? ' is-selected' : ''}" aria-pressed="${p.id === d.vote}" `
    + `data-act="send" data-args="${args({ type: 'cast_vote', fields: { round: d.round, choice: p.id } })}">${avatar(p)}<span class="player-chip__name">${esc(p.name)}</span></button>`).join('') + '</div>';
  const hint = named ? `You named ${esc(named.name)} · tap another to change` : 'Tap a player. You can change your vote until time runs out.';
  return ph(`<div class="row" style="justify-content:space-between"><p class="t-heading">Who was the Insider?</p>${timerPill(view.deadline)}</div>`
    + `<p class="t-caption t-dim">${hint}</p>${list}`, { top: top(view, 'Accuse') });
}

function I6(view) {
  const d = view.data;
  const n = esc(d.insider.name);
  let title, text;
  if (d.caught) {
    title = d.youAreInsider ? 'You were caught!' : d.named === d.insider.name ? `You caught ${n}!` : `${n} was caught`;
    text = d.youAreInsider ? `${d.accusers} players named you. You pay each of them 300 chips.` : `${n} pays every player who named them.`;
  } else {
    title = d.youAreInsider ? 'You got away!' : `${n} got away`;
    text = d.youAreInsider ? 'You keep 10% of the Traders\' winnings.' : `${d.named ? `You named ${esc(d.named)}. ` : ''}${n} keeps their 10% cut.`;
  }
  const colour = d.delta > 0 ? ' t-success' : d.delta < 0 ? ' t-danger' : '';
  return ph(avatar(d.insider, 'l') + `<p class="t-title">${title}</p>`
    + `<p class="points-big${colour}"${d.delta ? '' : ' style="color:var(--nb-color-text-dim)"'}>${signed(d.delta)}${d.delta ? ' chips' : ''}</p>`
    + `<p class="t-body t-dim">${text}</p><p class="chips-left">Now ${grouped(d.chips)} chips</p>`, { top: top(view, 'Insider reveal'), center: true });
}

registerScreens({
  'I1-insider': rolePage('I1'), 'I1-trader': rolePage('I1'), 'I2-insider': rolePage('I2'), 'I2-trader': rolePage('I2'),
  I3, I4, I5, I6,
});
export { chip };
