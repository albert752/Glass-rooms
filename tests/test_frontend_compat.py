"""Guard the legacy delivery contract; not a substitute for an iOS device test."""
from html.parser import HTMLParser
from pathlib import Path
import re
import unittest
from urllib.parse import urljoin, urlsplit

WWW = Path(__file__).resolve().parents[1] / "glass_rooms" / "www"


class Markup(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.assets = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script" and "src" in attrs:
            self.assets.append(attrs["src"])
        if tag == "link" and attrs.get("rel") == "stylesheet":
            self.assets.append(attrs["href"])


class LegacyDeliveryTests(unittest.TestCase):
    def test_assets_resolve_at_root_and_inside_a_subdirectory(self):
        assets = Markup((WWW / "index.html").read_text()).assets
        self.assertEqual(len(assets), 3)
        for base in ("http://localhost:8099/", "http://homeassistant:8080/local/glass_rooms/index.html"):
            for asset in assets:
                self.assertTrue(asset.startswith("./"))
                target = urlsplit(urljoin(base, asset))
                self.assertEqual(target.path.rsplit("/", 1)[0], urlsplit(base).path.rsplit("/", 1)[0])
                self.assertTrue((WWW / target.path.rsplit("/", 1)[1]).is_file())

    def test_script_runs_after_markup_and_boot_failure_remains_visible(self):
        html = (WWW / "index.html").read_text()
        self.assertGreater(html.index('<script src='), html.index('id="view"'))
        self.assertIn('id="boot-status"', html)
        self.assertNotIn('id="boot-status" class="hidden', html)
        self.assertIn('id="css-probe"', html)

    def test_css_baseline_avoids_fragile_layout_requirements(self):
        css = re.sub(r"/\*.*?\*/", "", (WWW / "style.css").read_text(), flags=re.S)
        for pattern in (r"display\s*:\s*(?:-webkit-)?grid", r"\bobject-fit\s*:",
                        r"backdrop-filter\s*:", r":focus-visible"):
            self.assertIsNone(re.search(pattern, css), pattern)
        self.assertIn('-webkit-appearance: none', css)
        self.assertIn('.room-wrap { float: left;', css)

    def test_images_and_api_are_relative_and_icons_use_svg_namespace(self):
        js = (WWW / "app.js").read_text()
        self.assertNotIn("'/assets/", js)
        self.assertNotIn("'/api/", js)
        self.assertIn("'./assets/'", js)
        self.assertIn("'./api/session'", js)
        self.assertIn('xmlns="http://www.w3.org/2000/svg"', js)
        self.assertNotIn('.innerHTML=', js)


if __name__ == "__main__":
    unittest.main()
