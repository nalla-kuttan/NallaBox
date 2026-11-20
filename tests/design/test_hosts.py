import unittest

from helpers import ROOT, load_manifest


class HostPagesTests(unittest.TestCase):
    def test_host_iphone_pages_exist(self):
        for e in load_manifest():
            if e["surface"] == "host-iphone":
                self.assertTrue((ROOT / e["path"]).exists(), e["path"])

    def test_live_room_embeds_the_real_controller(self):
        html = (ROOT / "host-iphone" / "H5.html").read_text()
        self.assertIn('src="../phone/P4.html?embed=1"', html)

    def test_host_mac_pages_exist(self):
        for e in load_manifest():
            if e["surface"] == "host-mac":
                self.assertTrue((ROOT / e["path"]).exists(), e["path"])

    def test_mac_room_previews_the_tv(self):
        html = (ROOT / "host-mac" / "M2.html").read_text()
        self.assertIn('src="../tv/T2.html?embed=1&amp;state=full"', html)


if __name__ == "__main__":
    unittest.main()
