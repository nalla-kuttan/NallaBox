"""Screenshot mockup pages with headless Chrome.

  python3 tests/design/shoot.py                       # every manifest page
  python3 tests/design/shoot.py --surface phone --w 360
  python3 tests/design/shoot.py --surface phone --text 1.3
  python3 tests/design/shoot.py --ids T1 T2 --state help
  python3 tests/design/shoot.py --file components.html --size 1600x4000
Output: design/mockups/_shots/<surface>/<id>[-state][-w360][-t130].png
"""
import argparse
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from helpers import ROOT, load_manifest  # noqa: E402

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    shutil.which("google-chrome") or "", shutil.which("chromium") or "",
]
WINDOW = {"tv": (1968, 1200), "phone": (520, 1000), "host-iphone": (520, 1000), "host-mac": (1328, 920)}


def chrome():
    for c in CHROME_CANDIDATES:
        if c and Path(c).exists():
            return c
    sys.exit("Chrome/Chromium not found")


def shoot(url, out, size):
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
           "--allow-file-access-from-files", "--virtual-time-budget=2500",
           f"--window-size={size[0]},{size[1]}", f"--screenshot={out}", url]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return out if out.exists() else f"FAILED {out}: {r.stderr[-300:]}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--surface")
    ap.add_argument("--ids", nargs="*")
    ap.add_argument("--w", type=int)
    ap.add_argument("--h", type=int)
    ap.add_argument("--text", type=float)
    ap.add_argument("--state")
    ap.add_argument("--all-states", action="store_true")
    ap.add_argument("--file")
    ap.add_argument("--size", default="1600x3000")
    ap.add_argument("--contact", help="make a contact sheet of _shots/<CONTACT>/*.png (glob suffix via --match)")
    ap.add_argument("--match", default="*.png")
    ap.add_argument("--cols", type=int, default=3)
    a = ap.parse_args()
    shots = ROOT / "_shots"
    if a.contact:
        d = shots / a.contact
        imgs = sorted((p for p in d.glob(a.match) if not p.name.startswith("contact")),
                      key=lambda p: (p.stem[0], int("".join(ch for ch in p.stem[1:3] if ch.isdigit()) or 0), p.stem))
        cells = "".join(f'<figure><img src="{p.name}"><figcaption>{p.stem}</figcaption></figure>' for p in imgs)
        page = d / "contact.html"
        page.write_text(f'<html><body style="margin:0;background:#000;font:14px sans-serif;color:#fff">'
                        f'<div style="display:grid;grid-template-columns:repeat({a.cols},1fr);gap:8px;padding:8px">{cells}</div>'
                        f'<style>figure{{margin:0}}img{{width:100%;display:block}}</style></body></html>')
        w, h = map(int, a.size.split("x"))
        print(shoot(page.as_uri(), d / f"contact-{a.match.replace('*', '').replace('.png', '') or 'all'}.png", (w, h)))
        return
    jobs = []
    if a.file:
        w, h = map(int, a.size.split("x"))
        jobs.append(((ROOT / a.file).as_uri(), shots / (Path(a.file).stem + ".png"), (w, h)))
    else:
        for e in load_manifest():
            if a.surface and e["surface"] != a.surface or a.ids and e["id"] not in a.ids:
                continue
            if not (ROOT / e["path"]).exists():
                continue
            states = [a.state]
            if a.all_states:
                m = re.search(r'data-states="([^"]+)"', (ROOT / e["path"]).read_text())
                states = m.group(1).split(",") if m else [None]
            for st in states:
                q, suffix = [], ""
                if st:
                    q.append(f"state={st}"); suffix += f"-{st}"
                if a.w:
                    q.append(f"w={a.w}"); suffix += f"-w{a.w}"
                if a.h:
                    q.append(f"h={a.h}"); suffix += f"-h{a.h}"
                if a.text:
                    q.append(f"text={a.text}"); suffix += f"-t{int(a.text * 100)}"
                url = (ROOT / e["path"]).as_uri() + ("?" + "&".join(q) if q else "")
                jobs.append((url, shots / e["surface"] / f'{e["id"]}{suffix}.png', WINDOW[e["surface"]]))
    with ThreadPoolExecutor(max_workers=6) as ex:
        for res in ex.map(lambda j: shoot(*j), jobs):
            print(res)


if __name__ == "__main__":
    main()
