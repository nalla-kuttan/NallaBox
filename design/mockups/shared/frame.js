/* Mockup frame: wraps <main class="screen"> in a true-size device, adds the screen bar,
   prev/next from NB_SCREENS, state toggles, ?w=<px> (phone width), ?text=<scale>, ?embed=1, ?state=<name>. */
(function () {
  const CANVAS = {
    tv: [1920, 1080],
    phone: [393, 852],
    "host-iphone": [393, 852],
    "host-mac": [1280, 800],
  };
  const body = document.body;
  const id = body.dataset.screen;
  const surface = body.dataset.surface;
  const params = new URLSearchParams(location.search);
  const screens = window.NB_SCREENS || [];
  const idx = screens.findIndex((s) => s.id === id && s.surface === surface);
  const entry = screens[idx] || { id, title: "" };

  if (params.get("text")) document.documentElement.style.setProperty("--nb-text-scale", params.get("text"));
  const embed = params.get("embed") === "1";
  if (embed) body.classList.add("nbf-embed");

  let [w, h] = CANVAS[surface] || [1280, 800];
  if ((surface === "phone" || surface === "host-iphone") && params.get("w")) w = Number(params.get("w"));
  if (surface === "host-mac" && params.get("w")) { w = Number(params.get("w")); h = Number(params.get("h") || h); }
  if (embed && surface !== "tv" && surface !== "host-mac") { w = window.innerWidth || w; h = window.innerHeight || h; }

  const main = document.querySelector("main.screen");
  main.classList.add(`surface-${surface === "tv" || surface === "host-mac" ? surface : "phone"}`);
  main.style.width = w + "px";
  main.style.height = h + "px";

  const device = document.createElement("div");
  device.className = "nbf-device";
  device.dataset.surface = surface;
  const scaler = document.createElement("div");
  scaler.className = "nbf-scaler";
  main.replaceWith(scaler);
  scaler.appendChild(device);
  device.appendChild(main);
  device.style.width = w + "px";
  device.style.height = h + "px";
  const stage = document.createElement("div");
  stage.className = "nbf-stage";
  scaler.replaceWith(stage);
  stage.appendChild(scaler);

  // States
  const states = (body.dataset.states || "default").split(",").map((s) => s.trim());
  function setState(name) {
    body.dataset.state = name;
    document.querySelectorAll("[data-show-state]").forEach((el) => {
      el.classList.toggle("nbf-on", el.dataset.showState.split(",").map((s) => s.trim()).includes(name));
    });
    document.querySelectorAll(".nbf-states button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.state === name)));
  }

  // Fit-to-window scaling for big canvases
  let fit = surface === "tv" || surface === "host-mac";
  function layout() {
    if (embed && surface !== "tv" && surface !== "host-mac") {
      // Embedded controllers fill their iframe, which may only get its final size after load.
      w = window.innerWidth || w; h = window.innerHeight || h;
      main.style.width = device.style.width = w + "px";
      main.style.height = device.style.height = h + "px";
    }
    const avail = embed ? window.innerWidth : Math.max(320, window.innerWidth - 48);
    const s = fit ? Math.min(1, avail / w) : 1;
    device.style.transform = `scale(${s})`;
    scaler.style.width = w * s + "px";
    scaler.style.height = h * s + "px";
  }

  if (!embed) {
    const bar = document.createElement("div");
    bar.className = "nbf-bar";
    const prev = screens[idx - 1], next = screens[idx + 1];
    const link = (s, label) => s ? `<a href="../${s.path}">${label}</a>` : `<a aria-disabled="true">${label}</a>`;
    bar.innerHTML =
      `<b>${entry.id}</b><span>${entry.title || ""}</span><span class="nbf-size">${w}×${h}</span>` +
      `<span class="nbf-spacer"></span>` +
      `<span class="nbf-states">${states.length > 1 ? states.map((s) => `<button data-state="${s}">${s}</button>`).join("") : ""}</span>` +
      (surface === "tv" || surface === "host-mac" ? `<button class="nbf-fit">Fit / 100%</button>` : "") +
      link(prev, "← Prev") + `<a href="../index.html">All screens</a>` + link(next, "Next →");
    body.prepend(bar);
    bar.querySelectorAll(".nbf-states button").forEach((b) => b.addEventListener("click", () => setState(b.dataset.state)));
    const fb = bar.querySelector(".nbf-fit");
    if (fb) fb.addEventListener("click", () => { fit = !fit; layout(); });
    document.title = document.title || `${entry.id} · ${entry.title} — NallaBox`;
  }

  // Hold-to-reveal cards: press-and-hold >= 300 ms (pointer, or Space/Enter held) shows [data-secret].
  // Cards that start held are mock "held" states and stay as drawn.
  document.querySelectorAll(".hold-card").forEach((card) => {
    if (card.classList.contains("is-held")) return;
    let t;
    const on = () => { clearTimeout(t); t = setTimeout(() => card.classList.add("is-held"), 300); };
    const off = () => { clearTimeout(t); card.classList.remove("is-held"); };
    card.addEventListener("pointerdown", (e) => {
      // Touch pointers are implicitly captured; release so sliding off the card hides the secret.
      if (card.hasPointerCapture && card.hasPointerCapture(e.pointerId)) card.releasePointerCapture(e.pointerId);
      on();
    });
    ["pointerup", "pointerleave", "pointercancel"].forEach((ev) => card.addEventListener(ev, off));
    card.addEventListener("contextmenu", (e) => e.preventDefault());
    card.addEventListener("keydown", (e) => { if ((e.key === " " || e.key === "Enter") && !e.repeat) { e.preventDefault(); on(); } });
    card.addEventListener("keyup", (e) => { if (e.key === " " || e.key === "Enter") off(); });
    card.addEventListener("blur", off);
  });

  setState(states.includes(params.get("state")) ? params.get("state") : states[0]);
  layout();

  // Geometry audit (?audit=1): measured after fonts load, written as JSON for tests/design/test_layout_audit.py.
  if (params.get("audit") === "1") {
    const visible = (el) => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";
    const label = (el) => (el.className && typeof el.className === "string" ? "." + el.className.split(" ")[0] + " " : el.tagName + " ") +
      (el.textContent || el.value || el.getAttribute("aria-label") || "").trim().slice(0, 30);
    const run = () => {
      const out = { outside: [], clipped: [], small: [], overflowX: false };
      const box = main.getBoundingClientRect();
      const scale = box.width / main.offsetWidth || 1;
      if (surface === "tv") {
        const safe = 80;
        main.querySelectorAll("*").forEach((el) => {
          if (el.closest(".ghost") || !visible(el)) return;
          const own = [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());
          if (!own) return;
          const r = el.getBoundingClientRect();
          const x0 = (r.left - box.left) / scale, y0 = (r.top - box.top) / scale;
          const x1 = (r.right - box.left) / scale, y1 = (r.bottom - box.top) / scale;
          if (x0 < safe - 1 || y0 < safe - 1 || x1 > w - safe + 1 || y1 > h - safe + 1)
            out.outside.push(label(el) + ` [${Math.round(x0)},${Math.round(y0)} → ${Math.round(x1)},${Math.round(y1)}]`);
        });
      }
      main.querySelectorAll(".face-corner__caption").forEach((el) => {
        if (!visible(el)) return;
        const rg = document.createRange();
        rg.selectNodeContents(el);
        const cs = getComputedStyle(el);
        const avail = el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
        if (rg.getBoundingClientRect().width / scale > avail + 1) out.clipped.push(label(el));
      });
      if (surface === "phone" || surface === "host-iphone") {
        out.overflowX = main.scrollWidth > main.clientWidth + 1 ||
          [...main.querySelectorAll(".phone-body, .phone-center")].some((el) => visible(el) && el.scrollWidth > el.clientWidth + 1);
        main.querySelectorAll("button, input, .swatch, .toggle, .answer-tile, .choice, .accuse-list .player-chip").forEach((el) => {
          if (!visible(el) || el.closest(".ios-alert")) return;
          const r = el.getBoundingClientRect();
          if (r.height / scale < 43.5 || r.width / scale < 43.5) out.small.push(label(el) + ` ${Math.round(r.width / scale)}×${Math.round(r.height / scale)}`);
        });
      }
      const s = document.createElement("script");
      s.type = "application/json";
      s.id = "nb-audit";
      s.textContent = JSON.stringify(out);
      document.body.appendChild(s);
    };
    (document.fonts ? document.fonts.ready : Promise.resolve()).then(() => setTimeout(run, 50));
  }
  window.addEventListener("resize", layout);
})();
