#!/usr/bin/env python3
"""Write the Roblox IDs of Wilhem's VFX pack into src/shared/VfxConfig.luau.

    python3 tools/vfxids.py his_list.txt      (or paste the list on stdin)

One asset per line, the key or the file name, then the ID, in any of these forms:
    HITSPARK_LIGHT_4x4 = 123456789
    VFX_COMMON_HITSPARK_LIGHT_4x4.png  rbxassetid://123456789
    VFX_COMMON_SLASH_180 : 123456790
Unknown names are listed and left out; nothing else in the file changes.
"""
import re
import sys

CONFIG = "src/shared/VfxConfig.luau"


def key_of(name):
    name = re.sub(r"\.(png|fbx)$", "", name.strip(), flags=re.I)
    return re.sub(r"^VFX_(COMMON_)?", "", name)


def main():
    text = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    config = open(CONFIG, encoding="utf-8").read()
    known = set(re.findall(r"^\t([A-Za-z0-9_]+) = \d+,$", config, flags=re.M))
    done, unknown = 0, []
    for line in text.splitlines():
        m = re.match(r"^\s*([A-Za-z0-9_.]+)\s*[=:,\s]\s*(?:rbxassetid://)?(\d+)\s*$", line)
        if not m:
            continue
        key, asset = key_of(m.group(1)), m.group(2)
        if key not in known:
            unknown.append(m.group(1))
            continue
        config, n = re.subn(r"^(\t%s = )\d+,$" % re.escape(key), r"\g<1>%s," % asset, config, flags=re.M)
        done += n
    open(CONFIG, "w", encoding="utf-8").write(config)
    left = re.findall(r"^\t([A-Za-z0-9_]+) = 0,$", config, flags=re.M)
    print("%d IDs written, %d assets still at 0" % (done, len(left)))
    if unknown:
        print("unknown (left out): " + ", ".join(unknown))


if __name__ == "__main__":
    main()
