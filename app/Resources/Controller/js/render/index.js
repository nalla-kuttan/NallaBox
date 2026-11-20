// Renders the whole phone screen from the latest view and local UI state. Pure: returns an HTML string.
import * as room from './room.js';
import { esc } from './kit.js';

const screens = {};

/** Game modules add their screen renderers: { R1: (view, ui) => html, ... }. */
export function registerScreens(map) { Object.assign(screens, map); }
registerScreens(room.screens);

export function render(view, ui) {
  switch (ui.mode) {
    case 'join': return room.join(ui);
    case 'reconnecting': return room.reconnecting(false);
    case 'failed': return room.reconnecting(true);
    case 'removed': return room.removed(ui.removedReason);
    default: break;
  }
  if (!view) return room.reconnecting(false);
  const fn = screens[view.screen] ?? room.fallback;
  let html = fn(view, ui);
  if (ui.sheet && view.you?.isLeader) html += room.sheet(view, ui);
  if (ui.toast) html += `<div class="ctrl-toast" role="alert">${esc(ui.toast)}</div>`;
  return html;
}
