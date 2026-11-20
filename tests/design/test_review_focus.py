import unittest

from helpers import count_class, read_page


class TVShellFocus(unittest.TestCase):
    def test_tv_lobby_full_room(self):
        html = read_page("tv/T2.html")
        self.assertEqual(count_class(html, "player-chip", state="full"), 8)
        self.assertEqual(count_class(html, "is-leader", state="full"), 1)
        self.assertIn("Wolfgangster", html)

    def test_tv_results_full_room(self):
        self.assertEqual(count_class(read_page("tv/T10.html"), "lb-row"), 8)



class RedactedFocus(unittest.TestCase):
    def test_redacted_long_answer(self):
        html = read_page("tv/R3.html")
        i = html.index("competitive soup kitchen")
        self.assertIn('class="answer-tile', html[max(0, i - 400):i])

    def test_redacted_scores_full_room(self):
        self.assertEqual(count_class(read_page("tv/R5.html"), "lb-row"), 8)


class SketchFocus(unittest.TestCase):
    def test_sketch_lineup_full_room(self):
        self.assertEqual(count_class(read_page("tv/C3.html"), "drawing-tile"), 7)

    def test_scene_only_on_witness(self):
        from helpers import ROOT
        allowed = {"phone/C1-witness.html", "phone/C2-witness.html", "tv/C4.html"}
        found = {str(p.relative_to(ROOT)) for p in ROOT.glob("*/*.html") if "scene-raccoon" in p.read_text()}
        self.assertEqual(found, allowed)

    def test_witness_scene_is_secret(self):
        for page in ("phone/C1-witness.html", "phone/C2-witness.html"):
            html = read_page(page)
            i = html.index("scene-raccoon")
            self.assertIn("data-secret", html[max(0, i - 300):i], page)


def strip_secret(html_text):
    """The <main class="screen"> markup with every [data-secret] element removed, whitespace-normalised."""
    import re
    from html.parser import HTMLParser
    body = html_text[html_text.index('<main class="screen">'):html_text.index("</main>")]
    void = {"img", "input", "br", "hr", "meta", "link", "source"}

    class P(HTMLParser):
        def __init__(self):
            super().__init__(convert_charrefs=False)
            self.out, self.skip = [], 0

        def handle_starttag(self, tag, attrs):
            if self.skip or any(k == "data-secret" for k, _ in attrs):
                if tag not in void:
                    self.skip += 1
                return
            self.out.append(self.get_starttag_text())

        def handle_endtag(self, tag):
            if self.skip:
                self.skip -= 1
                return
            self.out.append(f"</{tag}>")

        def handle_data(self, data):
            if not self.skip:
                self.out.append(data)

    p = P()
    p.feed(body)
    return re.sub(r"\s+", " ", "".join(p.out)).strip()


class InsiderFocus(unittest.TestCase):
    def test_role_cards_identical_at_rest(self):
        for phase in ("I1", "I2"):
            with self.subTest(phase=phase):
                a = strip_secret(read_page(f"phone/{phase}-insider.html"))
                b = strip_secret(read_page(f"phone/{phase}-trader.html"))
                self.assertEqual(a, b)

    def test_insider_answer_only_in_secret(self):
        from helpers import ROOT
        for p in ROOT.glob("phone/*.html"):
            self.assertNotIn("Answer: B", strip_secret(p.read_text()), p.name)


if __name__ == "__main__":
    unittest.main()


class CopyRules(unittest.TestCase):
    def test_face_captions_one_short_line(self):
        import re
        from helpers import ROOT
        too_long = []
        for p in ROOT.glob("tv/*.html"):
            for cap in re.findall(r'<p class="face-corner__caption">(.*?)</p>', p.read_text()):
                if len(cap.replace("&#x27;", "'")) > 48:
                    too_long.append((p.name, cap))
        self.assertEqual(too_long, [])
