"""Shared helpers for the NallaBox mockup checks (stdlib only)."""
import json
import re
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / "design" / "mockups"
SWIFT_THEME = PROJECT / "design" / "NallaBoxTheme.swift"

SURFACES = ("tv", "phone", "host-iphone", "host-mac")
GROUPS = ("Shell", "Redacted", "Composite Sketch", "Insider Trading", "iPhone host", "Mac host")


def spec_ids() -> dict:
    """Screen IDs per surface, copied from the plan's 'Manifest IDs' (spec §7)."""
    r = lambda p, n: [f"{p}{i}" for i in range(1, n + 1)]
    return {
        "tv": r("T", 10) + r("R", 5) + r("C", 6) + r("I", 6),
        "phone": r("P", 13) + r("R", 5) + [
            "C1-witness", "C1-artist", "C2-witness", "C2-artist", "C3-witness", "C3-artist", "C4", "C5", "C6",
            "I1-insider", "I1-trader", "I2-insider", "I2-trader", "I3", "I4", "I5", "I6"],
        "host-iphone": r("H", 8),
        "host-mac": r("M", 5),
    }


def load_manifest() -> list:
    text = (ROOT / "shared" / "screens.js").read_text()
    return json.loads(text[text.index("["): text.rindex("]") + 1])


def read_page(path: str) -> str:
    return (ROOT / path).read_text()


def css_tokens() -> dict:
    text = (ROOT / "shared" / "tokens.css").read_text()
    return {m.group(1): m.group(2).strip() for m in re.finditer(r"--(nb-[\w-]+)\s*:\s*([^;]+);", text)}


def _kebab(name: str) -> str:
    return re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", name).lower()


def swift_tokens() -> dict:
    """Colour tokens from NallaBoxTheme.swift, keyed like the CSS tokens."""
    text = SWIFT_THEME.read_text()
    out = {}
    palette = re.search(r"enum Palette\s*\{(.*?)\n    \}", text, re.S)
    for m in re.finditer(r"static let (\w+)\s*=\s*Color\(hex:\s*0x([0-9A-Fa-f]{6})", palette.group(1) if palette else ""):
        out[f"nb-color-{_kebab(m.group(1))}"] = "#" + m.group(2).upper()
    players = re.search(r"enum PlayerColor[^{]*\{(.*?)\n    \}", text, re.S)
    for m in re.finditer(r"case \.(\w+):\s*return Color\(hex:\s*0x([0-9A-Fa-f]{6})", players.group(1) if players else ""):
        out[f"nb-player-{m.group(1)}"] = "#" + m.group(2).upper()
    return out


def contrast(hex_a: str, hex_b: str) -> float:
    def lum(h):
        h = h.lstrip("#")
        def ch(v):
            v = int(v, 16) / 255
            return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        r, g, b = (ch(h[i:i + 2]) for i in (0, 2, 4))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    a, b = sorted((lum(hex_a), lum(hex_b)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def count_class(html_text: str, cls: str, state: str = None) -> int:
    """Count elements whose class list contains cls, optionally only inside [data-show-state] blocks for state."""
    from html.parser import HTMLParser

    class P(HTMLParser):
        def __init__(self):
            super().__init__()
            self.stack, self.n = [], 0

        def handle_starttag(self, tag, attrs):
            a = dict(attrs)
            in_state = a.get("data-show-state") and state in a["data-show-state"].split(",")
            inside = (self.stack[-1] if self.stack else state is None) or bool(in_state)
            if tag not in ("img", "input", "br", "hr", "meta", "link", "source"):
                self.stack.append(inside)
            if inside and cls in (a.get("class") or "").split():
                self.n += 1

        def handle_endtag(self, tag):
            if self.stack and tag not in ("img", "input", "br", "hr", "meta", "link", "source"):
                self.stack.pop()

    p = P()
    p.feed(html_text)
    return p.n
