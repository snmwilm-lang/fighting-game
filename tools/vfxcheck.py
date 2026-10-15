#!/usr/bin/env python3
"""Check Wilhem's VFX pack against src/shared/VfxConfig.luau: every key has its file in
assets/vfx, every file its key, every asset the client modules name is a key, and the
textures follow the rules (power of two, 1024 at most, transparent).

    python3 tools/vfxcheck.py
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
config = open(os.path.join(ROOT, "src/shared/VfxConfig.luau"), encoding="utf-8").read()
block = lambda name: re.search(r"VfxConfig\.%s = \{\n(.*?)\n\}" % name, config, re.S).group(1)
textures = set(re.findall(r"^\t([A-Za-z0-9_]+) = \d+,$", block("TEXTURES"), re.M))
meshes = set(re.findall(r"^\t([A-Za-z0-9_]+) = \d+,$", block("MESHES"), re.M))
problems = []

files = {}
for kind, ext in (("textures", ".png"), ("meshes", ".fbx")):
    for f in os.listdir(os.path.join(ROOT, "assets/vfx", kind)):
        if f.endswith(ext):
            files[re.sub(r"^VFX_(COMMON_)?", "", f[: -len(ext)])] = (kind, f)
for key in sorted(textures | meshes):
    if key not in files:
        problems.append("no file for " + key)
for key in sorted(files):
    if key not in textures | meshes:
        problems.append("no key for " + files[key][1])

# every asset the pack's client modules name
known = textures | meshes
for f in ("VFX_Common.luau", "VFX_Chars.luau", "VFX_Specials.luau"):
    path = os.path.join(ROOT, "src/client/VFX", f)
    if not os.path.exists(path):
        continue
    text = open(path, encoding="utf-8").read()
    names = set(re.findall(r'(?:tex|mesh|Template|sprite|layer|orbit|flipFx|ring|Mark|fullImage)\b[^"\n]{0,40}"([A-Z][A-Z0-9_x]+)"', text))
    names |= set(re.findall(r'Tex\.([A-Z][A-Z0-9_x]+)', text))
    for name in names:
        if name not in known and not name.startswith("SPEEDLINES_"):
            problems.append("%s names %s, not in VfxConfig" % (f, name))

try:
    from PIL import Image
    for key, (kind, f) in files.items():
        if kind != "textures":
            continue
        im = Image.open(os.path.join(ROOT, "assets/vfx/textures", f))
        w, h = im.size
        if w & (w - 1) or h & (h - 1) or max(w, h) > 1024:
            problems.append("%s: %dx%d (power of two, 1024 at most)" % (f, w, h))
        if im.mode != "RGBA":
            problems.append("%s: no transparency (%s)" % (f, im.mode))
except ImportError:
    print("(Pillow missing: texture sizes not checked)")

left = re.findall(r"^\t([A-Za-z0-9_]+) = 0,$", config, re.M)
print("%d textures, %d meshes, %d files; %d still to upload" % (len(textures), len(meshes), len(files), len(left)))
for p in problems:
    print("  " + p)
sys.exit(1 if problems else 0)
