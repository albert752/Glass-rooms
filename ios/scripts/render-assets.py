#!/usr/bin/env python3
"""Rasterise the web panel's icons and the app icon into PNGs for the iOS 9 app (UIKit cannot draw SVG).

Uses macOS `sips`. The PNGs are committed, so building the app does not need this script.
Run again after changing the ICONS table in glass_rooms/www/app.js.
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WWW = ROOT / "glass_rooms" / "www"
OUT = ROOT / "ios" / "GlassRooms" / "Resources"


def render(svg_text, target, work):
    source = work / (target.stem + ".svg")
    source.write_text(svg_text, encoding="utf-8")
    subprocess.run(["sips", "-s", "format", "png", str(source), "--out", str(target)],
                   check=True, stdout=subprocess.DEVNULL)


def icons():
    source = (WWW / "app.js").read_text(encoding="utf-8")
    table = source[source.index("var ICONS = {"):source.index("};", source.index("var ICONS = {"))]
    return dict(re.findall(r"(\w+):'([^']*)'", table))


def icon_svg(name, paths, size):
    solid = name == "lightOn"
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="%d" height="%d" fill="%s" stroke="%s" '
            'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
            % (size, size, "#000" if solid else "none", "none" if solid else "#000", paths))


BACKGROUND = "#000000"


def brand_mark():
    # Four rounded panes, one lit in amber: the "Nit càlida" look of the iPad app.
    return ('<g transform="rotate(-5 50 50)" stroke="#ffb766" stroke-width="2.6">'
            '<rect x="25" y="23" width="23" height="25" rx="7" fill="#1d1812"/>'
            '<rect x="52" y="23" width="23" height="25" rx="7" fill="#ffb766"/>'
            '<rect x="25" y="52" width="23" height="25" rx="7" fill="#1d1812"/>'
            '<rect x="52" y="52" width="23" height="25" rx="7" fill="#1d1812"/></g>')


def brand_svg(size):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="%d" height="%d">'
            '<rect width="100" height="100" fill="%s"/>%s</svg>' % (size, size, BACKGROUND, brand_mark()))


def launch_svg(width, height):
    mark = min(width, height) * 0.12
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">'
            '<rect width="%d" height="%d" fill="%s"/>'
            '<g transform="translate(%f %f) scale(%f)">%s</g></svg>'
            % (width, height, width, height, width, height, BACKGROUND, (width - mark) / 2, (height - mark) / 2, mark / 100,
               brand_mark()))


def main():
    if sys.platform != "darwin":
        raise SystemExit("Aquest script necessita sips de macOS.")
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        for name, paths in icons().items():
            for suffix, size in (("", 23), ("-large", 44)):
                render(icon_svg(name, paths, size), OUT / ("icon-%s%s.png" % (name, suffix)), work)
                render(icon_svg(name, paths, size * 2), OUT / ("icon-%s%s@2x.png" % (name, suffix)), work)
        for points in (29, 40, 76):
            render(brand_svg(points), OUT / ("AppIcon%dx%d.png" % (points, points)), work)
            render(brand_svg(points * 2), OUT / ("AppIcon%dx%d@2x.png" % (points, points)), work)
        render(brand_svg(167), OUT / "AppIcon83.5x83.5@2x.png", work)
        for name, width, height in (("Default-Landscape", 1024, 768), ("Default-Portrait", 768, 1024)):
            render(launch_svg(width, height), OUT / (name + "~ipad.png"), work)
            render(launch_svg(width * 2, height * 2), OUT / (name + "@2x~ipad.png"), work)
    print("PNG generats a", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
