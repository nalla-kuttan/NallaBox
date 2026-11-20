import re
import unittest

from helpers import GROUPS, ROOT, SURFACES, load_manifest, read_page, spec_ids

STYLESHEETS = ("../shared/tokens.css", "../shared/base.css", "../shared/components.css", "../shared/frame.css")


class ManifestTests(unittest.TestCase):
    def test_manifest_covers_spec_ids(self):
        manifest = load_manifest()
        for surface, ids in spec_ids().items():
            got = sorted(e["id"] for e in manifest if e["surface"] == surface)
            self.assertEqual(got, sorted(ids), surface)

    def test_manifest_paths_unique_and_well_formed(self):
        manifest = load_manifest()
        keys = [(e["surface"], e["id"]) for e in manifest]
        self.assertEqual(len(keys), len(set(keys)))
        for e in manifest:
            self.assertEqual(e["path"], f'{e["surface"]}/{e["id"]}.html')
            self.assertIn(e["surface"], SURFACES)
            self.assertIn(e["group"], GROUPS)
            self.assertTrue(e["title"].strip())

    def test_index_links_every_screen(self):
        index = read_page("index.html")
        for e in load_manifest():
            self.assertIn(f'href="{e["path"]}"', index, e["path"])

    def test_no_remote_urls(self):
        offenders = []
        for f in ROOT.rglob("*"):
            if f.suffix in (".html", ".css", ".js", ".svg") and "_shots" not in f.parts:
                text = re.sub(r"http://www\.w3\.org/[\w/.]*", "", f.read_text())
                if re.search(r"https?://", text):
                    offenders.append(str(f.relative_to(ROOT)))
        self.assertEqual(offenders, [])

    def test_existing_pages_follow_contract(self):
        for e in load_manifest():
            page = ROOT / e["path"]
            if not page.exists():
                continue
            html = page.read_text()
            with self.subTest(page=e["path"]):
                self.assertIn(f'data-screen="{e["id"]}"', html)
                self.assertIn(f'data-surface="{e["surface"]}"', html)
                for css in STYLESHEETS:
                    self.assertIn(f'href="{css}"', html)
                self.assertIn('src="../shared/screens.js"', html)
                self.assertIn('src="../shared/frame.js"', html)
                self.assertIn(f'<title>{e["id"]} · {e["title"]} — NallaBox</title>', html)
                self.assertIn('<main class="screen', html)

    def test_all_pages_exist(self):
        missing = [e["path"] for e in load_manifest() if not (ROOT / e["path"]).exists()]
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
