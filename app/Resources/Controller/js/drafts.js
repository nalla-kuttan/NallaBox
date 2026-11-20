// Typed input kept on the phone (survives reloads and reconnects). Keys look like "R1:2" (screen:round).
const PREFIX = 'nb.draft.';

export function saveDraft(key, value, store = globalThis.localStorage) {
  try { store.setItem(PREFIX + key, JSON.stringify(value)); } catch {}
}

export function loadDraft(key, store = globalThis.localStorage) {
  try {
    const raw = store.getItem(PREFIX + key);
    return raw == null ? null : JSON.parse(raw);
  } catch {
    return null;
  }
}

export function clearDraft(key, store = globalThis.localStorage) {
  try { store.removeItem(PREFIX + key); } catch {}
}
