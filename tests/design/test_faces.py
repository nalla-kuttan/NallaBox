import re
import unittest
import xml.etree.ElementTree as ET

from helpers import ROOT

STATES = ("idle", "blink", "wink", "grin", "gasp", "suspicious", "sleepy", "celebrate")


class FaceTests(unittest.TestCase):
    def test_eight_face_states(self):
        for s in STATES:
            f = ROOT / "shared" / "face" / f"face-{s}.svg"
            with self.subTest(state=s):
                self.assertTrue(f.exists())
                root = ET.parse(f).getroot()
                self.assertEqual(root.get("viewBox"), "32 32 192 192")
                fills = {m.upper() for m in re.findall(r'fill="(#[0-9A-Fa-f]{6})"', f.read_text())}
                self.assertTrue(fills <= {"#FF5C39", "#FFFFFF"}, fills)

    def test_states_differ(self):
        texts = [(ROOT / "shared" / "face" / f"face-{s}.svg").read_text() for s in STATES if s not in ("idle", "wink")]
        self.assertEqual(len(set(texts)), len(texts))

    def test_faces_page_shows_all_states(self):
        page = (ROOT / "faces.html").read_text()
        for s in STATES:
            self.assertIn(f"face-{s}.svg", page)


if __name__ == "__main__":
    unittest.main()
