import unittest

from helpers import contrast, css_tokens, swift_tokens

COLORS = {
    "ink": "#1E1B2E", "ink-raised": "#2B2742", "ink-line": "#3A3556", "coral": "#FF5C39",
    "coral-press": "#E54826", "text": "#FFFFFF", "text-dim": "#B9B4CF", "success": "#4ED19A",
    "danger": "#FF6B7A", "paper": "#FFF4EA",
}
PLAYERS = {
    "saffron": "#FFB020", "sky": "#3DB7FF", "mint": "#4ED19A", "lilac": "#B58CFF",
    "pink": "#FF7AB6", "lime": "#C6E85A", "teal": "#2EC4B6", "sand": "#E9D8B4",
}
TYPE = {
    "tv": {"display": (120, 900), "title": (72, 900), "heading": (52, 800), "body": (40, 700), "label": (32, 800), "caption": (36, 700)},
    "phone": {"display": (40, 900), "title": (28, 800), "heading": (22, 800), "body": (17, 700), "label": (13, 800), "caption": (15, 600)},
}


class TokenTests(unittest.TestCase):
    def test_color_tokens_match_spec(self):
        t = css_tokens()
        for name, hexv in COLORS.items():
            self.assertEqual(t[f"nb-color-{name}"].upper(), hexv, name)
        for name, hexv in PLAYERS.items():
            self.assertEqual(t[f"nb-player-{name}"].upper(), hexv, name)
        self.assertNotIn("#FF5C39", [t[f"nb-player-{n}"].upper() for n in PLAYERS])

    def test_type_tokens_match_spec(self):
        t = css_tokens()
        for surface, styles in TYPE.items():
            for style, (size, weight) in styles.items():
                self.assertEqual(t[f"nb-{surface}-{style}-size"], f"{size}px", f"{surface} {style}")
                self.assertEqual(t[f"nb-{surface}-{style}-weight"], str(weight), f"{surface} {style}")

    def test_layout_tokens_match_spec(self):
        t = css_tokens()
        self.assertEqual([t[f"nb-radius-{r}"] for r in ("sm", "md", "lg", "xl")], ["8px", "14px", "22px", "32px"])
        self.assertEqual(t["nb-tv-safe"], "80px")
        self.assertEqual(t["nb-face-size"], "160px")
        self.assertEqual([t[f"nb-dur-{d}"] for d in ("tap", "screen", "reveal")], ["150ms", "250ms", "400ms"])
        self.assertEqual(t["nb-space-4"], "16px")

    def test_swift_colors_match_css(self):
        css = {k: v.upper() for k, v in css_tokens().items() if k.startswith(("nb-color-", "nb-player-"))}
        self.assertEqual(swift_tokens(), css)

    def test_text_dim_contrast(self):
        t = css_tokens()
        self.assertGreaterEqual(contrast(t["nb-color-text-dim"], t["nb-color-ink"]), 4.5)
        self.assertGreaterEqual(contrast(t["nb-color-text"], t["nb-color-ink"]), 12)


if __name__ == "__main__":
    unittest.main()
