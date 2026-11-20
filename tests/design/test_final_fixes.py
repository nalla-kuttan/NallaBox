"""Regression tests for the final review's Important findings."""
import re
import unittest

from helpers import count_class, read_page


def rule(css_text, selector):
    m = re.search(re.escape(selector) + r"\s*\{([^}]*)\}", css_text)
    return m.group(1) if m else ""


class FinalReviewFixes(unittest.TestCase):
    def test_phone_lists_follow_text_size(self):
        cases = [("phone/R3.html", ".surface-phone .answer-tile"), ("phone/I3.html", ".ph-choices .choice"),
                 ("phone/P4.html", ".who .player-chip"), ("phone/P5.html", ".phone-game p"),
                 ("phone/C5.html", ".surface-phone .drawing-tile__num")]
        for page, sel in cases:
            with self.subTest(page=page, selector=sel):
                body = rule(read_page(page), sel)
                self.assertIn("font-size", body)
                self.assertIn("--nb-text-scale", body)

    def test_remove_player_has_confirm_step(self):
        html = read_page("phone/P13.html")
        self.assertIn("confirm-remove", re.search(r'data-states="([^"]+)"', html).group(1))
        self.assertIn("Remove Sam from the room?", html)

    def test_sheet_item_names_truncate(self):
        body = rule(read_page("shared/components.css"), ".sheet__item .grow")
        self.assertIn("text-overflow: ellipsis", body)

    def test_leader_pill_meets_tap_minimum(self):
        body = rule(read_page("shared/components.css"), ".leader-pill")
        self.assertIn("min-height: var(--nb-tap-min)", body)

    def test_mac_room_lists_full_room_and_scrolls(self):
        html = read_page("host-mac/M2.html")
        self.assertEqual(count_class(html, "mac-player"), 8)
        self.assertRegex(rule(html, ".mac-players"), r"overflow(-y)?:\s*auto")

    def test_readout_face_gives_nothing_away(self):
        html = read_page("tv/R2.html")
        self.assertIn("face-idle.svg", html)
        self.assertNotIn("face-gasp.svg", html)


if __name__ == "__main__":
    unittest.main()
