// WebSocket link to the host: v1 messages with ids, reconnect with backoff, clock offset helpers.

/** Delay before reconnect attempt n (0-based): 500 ms doubling to an 8 s cap. */
export function backoff(attempt) {
  return Math.min(500 * 2 ** attempt, 8000);
}

/** Host clock minus local clock, in seconds. t0/t1 are local ms around a ping; hostTime is host seconds. */
export function clockOffset(t0, t1, hostTime) {
  return Math.round((hostTime - (t0 + t1) / 2 / 1000) * 1e6) / 1e6;
}

export function connect({ url, onOpen, onMessage, onState, WebSocketImpl = globalThis.WebSocket, setTimer = setTimeout, clearTimer = clearTimeout }) {
  let ws = null;
  let attempt = 0;
  let counter = 0;
  let stopped = false;
  let timer = null;

  function open() {
    ws = new WebSocketImpl(url);
    const me = ws;
    ws.onopen = () => {
      if (me !== ws) return;
      attempt = 0;
      onState?.('open', 0);
      onOpen?.();
    };
    ws.onmessage = (e) => {
      if (me !== ws) return;
      let msg;
      try { msg = JSON.parse(e.data); } catch { return; }
      onMessage?.(msg);
    };
    ws.onclose = () => {
      if (me !== ws) return;
      onState?.('closed', attempt);
      if (stopped) return;
      const delay = backoff(attempt++);
      timer = setTimer(open, delay);
    };
    ws.onerror = () => {};
  }
  open();

  return {
    /** Sends now and returns the message id, or null when not connected (nothing is sent). */
    send(type, fields = {}) {
      if (!ws || ws.readyState !== 1) return null;
      const id = String(++counter);
      ws.send(JSON.stringify({ v: 1, type, id, ...fields }));
      return id;
    },
    get connected() { return !!ws && ws.readyState === 1; },
    get attempts() { return attempt; },
    retry() {
      if (timer) clearTimer(timer);
      attempt = 0;
      const old = ws;
      ws = null;
      try { old?.close(); } catch {}
      open();
    },
    close() {
      stopped = true;
      if (timer) clearTimer(timer);
      ws?.close();
    },
  };
}
