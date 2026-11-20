import re
import unittest
from html.parser import HTMLParser

from helpers import ROOT, load_manifest

VOID = {"img", "input", "br", "hr", "meta", "link", "source"}


def primaries(html_text, state):
    """List of (inside_phone_action) for each .btn--primary visible in `state`."""
    class P(HTMLParser):
        def __init__(self):
            super().__init__()
            self.stack, self.found = [], []

        def handle_starttag(self, tag, attrs):
            a = dict(attrs)
            cls = (a.get("class") or "").split()
            parent = self.stack[-1] if self.stack else (True, False)
            visible = parent[0]
            if a.get("data-show-state"):
                visible = visible and state in a["data-show-state"].split(",")
            in_action = parent[1] or "phone-action" in cls
            if "btn--primary" in cls and visible:
                self.found.append(in_action)
            if tag not in VOID:
                self.stack.append((visible, in_action))

        def handle_endtag(self, tag):
            if tag not in VOID and self.stack:
                self.stack.pop()

    p = P()
    p.feed(html_text)
    return p.found


class PhoneShellTests(unittest.TestCase):
    def test_phone_pages_have_one_primary_action(self):
        for e in load_manifest():
            if e["surface"] != "phone" or not (ROOT / e["path"]).exists():
                continue
            html = (ROOT / e["path"]).read_text()
            m = re.search(r'data-states="([^"]+)"', html)
            for st in (m.group(1).split(",") if m else ["default"]):
                found = primaries(html, st)
                with self.subTest(page=e["path"], state=st):
                    self.assertLessEqual(len(found), 1)
                    self.assertTrue(all(found), "primary action must sit in .phone-action")

    def test_shell_phone_pages_exist(self):
        for i in range(1, 14):
            self.assertTrue((ROOT / "phone" / f"P{i}.html").exists(), f"P{i}")


if __name__ == "__main__":
    unittest.main()
