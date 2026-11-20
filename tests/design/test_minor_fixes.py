"""Regression tests for the final review's deferred minor findings."""
import re
import sys
import unittest

from helpers import PROJECT, count_class, css_tokens, read_page

sys.path.insert(0, str(PROJECT / "design" / "mockups" / "_build"))


def states(html):
    m = re.search(r'data-states="([^"]+)"', html)
    return m.group(1).split(",") if m else []


class SampleData(unittest.TestCase):
    def test_lobby_has_settings_link(self):
        self.assertIn("Room settings", read_page("phone/P4.html"))

    def test_redacted_round_counts_agree(self):
        # 3 rounds + final = 4 rounds everywhere
        self.assertIn("Round 1 of 4", read_page("phone/P7.html"))
        self.assertNotIn("of 3", read_page("phone/P7.html"))

    def test_leader_results_show_leaders_own_award(self):
        html = read_page("phone/P12.html")
        leader = html[html.index('data-show-state="leader"'):]
        self.assertNotIn('data-player="lilac"', leader)

    def test_insider_chip_maths(self):
        import pages_insider as pi
        winners = [(n, a) for n, a in pi.BETS[pi.ANSWER] if n != pi.INSIDER]
        commission = sum(a for _, a in winners) // 10
        self.assertEqual(commission, 100)
        esc = dict((n, (p, d)) for n, _, p, d in pi.ESCAPED)
        cau = dict((n, (p, d)) for n, _, p, d in pi.CAUGHT)
        self.assertEqual(esc[pi.INSIDER], (pi.START[pi.INSIDER] + 1000 + commission, 1000 + commission))
        self.assertEqual(cau[pi.INSIDER][1], 1000 - 300 * len(pi.ACCUSERS))
        for n, start in pi.START.items():
            self.assertEqual(esc[n][0], start + esc[n][1], n)
            self.assertEqual(cau[n][0], start + cau[n][1], n)
        self.assertIn(f"+{commission} chips", read_page("tv/I6.html"))

    def test_redacted_results_use_redacted_awards(self):
        self.assertNotIn("Most Wanted", read_page("tv/T10.html"))


class LayoutRules(unittest.TestCase):
    def test_label_tracking_matches_spec(self):
        t = css_tokens()
        self.assertEqual(t["nb-tv-label-tracking"], "1px")
        self.assertEqual(t["nb-phone-label-tracking"], "0px")
        self.assertNotRegex(read_page("shared/components.css"), r"letter-spacing:\s*\.0[68]em")

    def test_caption_bubble_grows_with_its_text(self):
        css = read_page("shared/components.css")
        rule = re.search(r"\.face-corner__caption\s*\{([^}]*)\}", css).group(1)
        self.assertNotIn("max-width", rule)


class Interactions(unittest.TestCase):
    def test_host_menu_confirms_destructive_actions(self):
        st = states(read_page("host-iphone/H6.html"))
        self.assertIn("confirm-remove", st)
        self.assertIn("confirm-end", st)

    def test_hold_cards_are_keyboard_reachable(self):
        for page in ("phone/I1-insider.html", "phone/C1-witness.html"):
            html = read_page(page)
            self.assertRegex(html, r'class="hold-card[^"]*" role="button" tabindex="0"', page)

    def test_hold_card_script_handles_keys_capture_and_preset_state(self):
        js = read_page("shared/frame.js")
        self.assertIn("keydown", js)
        self.assertIn("releasePointerCapture", js)
        self.assertIn('classList.contains("is-held")', js)

    def test_game_picker_shows_player_count_warning(self):
        html = read_page("tv/T4.html")
        self.assertIn("too-few", states(html))
        self.assertGreaterEqual(count_class(html, "game-card__warn", state="too-few"), 1)

    def test_game_phase_shows_leader_pill(self):
        html = read_page("phone/R1.html")
        self.assertIn("leader", states(html))
        self.assertGreaterEqual(count_class(html, "leader-pill", state="leader"), 1)


if __name__ == "__main__":
    unittest.main()
