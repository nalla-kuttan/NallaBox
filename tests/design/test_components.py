import unittest

from helpers import read_page

COMPONENTS = {
    "avatar": ["avatar--s", "avatar--m", "avatar--l"],
    "player-chip": ["is-submitted", "is-offline", "is-leader"],
    "seat": [],
    "timer-pill": ["is-urgent"],
    "answer-tile": ["is-selected", "is-mine", "is-real", "is-fake", "answer-tile__author"],
    "btn": ["btn--primary", "btn--secondary", "btn--destructive", "btn__reason"],
    "field": ["is-focus", "is-error", "field__counter"],
    "swatches": [], "stepper": [], "segmented": [], "toggle": [],
    "hold-card": ["is-held", "data-secret"],
    "chip-slider": [], "draw-toolbar": [],
    "lb-row": ["lb-row__delta"],
    "toast": [], "banner": [], "leader-pill": [], "sheet": [],
    "face-corner": ["face-corner__caption"],
    "phone-action": [], "tv-safe": [],
}


class ComponentGalleryTests(unittest.TestCase):
    def test_gallery_shows_every_component_and_state(self):
        gallery = read_page("components.html")
        for comp, mods in COMPONENTS.items():
            self.assertIn(f'class="{comp}', gallery.replace("class='", 'class="'), comp)
            for m in mods:
                self.assertIn(m, gallery, f"{comp}: {m}")

    def test_components_css_defines_every_component(self):
        css = read_page("shared/components.css")
        for comp in COMPONENTS:
            self.assertIn(f".{comp}", css, comp)


if __name__ == "__main__":
    unittest.main()
