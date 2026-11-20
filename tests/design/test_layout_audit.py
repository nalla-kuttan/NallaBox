"""Geometry audit: each page measures itself in headless Chrome (frame.js, ?audit=1) and reports
TV text outside the 80 px safe area, clipped one-line captions, phone tap targets under 44 px, and
sideways overflow. Slow (~1 min): it renders every page and state."""
import json
import re
import subprocess
import unittest
from concurrent.futures import ThreadPoolExecutor

from helpers import ROOT, load_manifest
from shoot import WINDOW, chrome


def audit(url, size, tries=2):
    cmd = [chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
           "--allow-file-access-from-files", "--virtual-time-budget=3000", f"--window-size={size[0]},{size[1]}", "--dump-dom", url]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        if tries > 1:
            return audit(url, size, tries - 1)   # a busy machine can stall one Chrome; retry once
        return {"error": "timeout"}
    m = re.search(r'<script type="application/json" id="nb-audit">(.*?)</script>', r.stdout, re.S)
    return json.loads(m.group(1)) if m else {"error": "no audit output"}


def jobs(extra=""):
    out = []
    for e in load_manifest():
        html = (ROOT / e["path"]).read_text()
        m = re.search(r'data-states="([^"]+)"', html)
        for st in (m.group(1).split(",") if m else [None]):
            q = "audit=1" + (f"&state={st}" if st else "") + extra
            out.append((f'{e["path"]}{"#" + st if st else ""}', e["surface"], (ROOT / e["path"]).as_uri() + "?" + q))
    return out


def run(job_list):
    with ThreadPoolExecutor(max_workers=8) as ex:
        return list(zip(job_list, ex.map(lambda j: audit(j[2], WINDOW[j[1]]), job_list)))


class LayoutAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.default = run(jobs())
        cls.stressed = run([j for j in jobs("&w=360&text=1.3") if j[1] in ("phone", "host-iphone")])

    def test_audit_ran_everywhere(self):
        self.assertEqual([j[0] for j, r in self.default + self.stressed if "error" in r], [])

    def test_tv_text_inside_safe_area(self):
        bad = [(j[0], r["outside"][:3]) for j, r in self.default if j[1] == "tv" and r.get("outside")]
        self.assertEqual(bad, [])

    def test_captions_never_clipped(self):
        bad = [(j[0], r["clipped"]) for j, r in self.default if r.get("clipped")]
        self.assertEqual(bad, [])

    def test_phone_tap_targets_at_least_44(self):
        bad = [(j[0], r["small"][:3]) for j, r in self.default if j[1] in ("phone", "host-iphone") and r.get("small")]
        self.assertEqual(bad, [])

    def test_no_sideways_overflow_narrow_large_text(self):
        bad = [j[0] for j, r in self.stressed if r.get("overflowX")]
        self.assertEqual(bad, [])


if __name__ == "__main__":
    unittest.main()
