#!/usr/bin/env python3
"""Builds the place file (.rbxlx) from src/ like `rojo build` does (the same tree as
default.project.json), for sessions without Rojo. Never commit the .rbxlx it writes.

    python3 tools/build_place.py . /some/folder/BREAKFRAMEZ_vX.Y.Z.rbxlx
"""
import os, sys
root = sys.argv[1]
out = sys.argv[2]
ref = [0]
def nref():
    ref[0] += 1
    return str(ref[0])
def cdata(text):
    return text.replace("]]>", "]]]]><![CDATA[>")
def module_items(folder, skip=()):
    items = []
    for name in sorted(os.listdir(folder)):
        sub = os.path.join(folder, name)
        if os.path.isdir(sub):  # (a folder without init: a Folder, like Rojo)
            items.append('<Item class="Folder" referent="%s"><Properties><string name="Name">%s</string></Properties>%s</Item>'
                         % (nref(), name, module_items(sub)))
            continue
        if not name.endswith(".luau") or name in skip: continue
        base = name[:-5]
        src = open(os.path.join(folder, name), encoding="utf-8").read()
        items.append('<Item class="ModuleScript" referent="%s"><Properties><string name="Name">%s</string>'
                     '<string name="Source"><![CDATA[%s]]></string></Properties></Item>' % (nref(), base, cdata(src)))
    return "".join(items)
def script(cls, name, folder, init, extra=""):
    src = open(os.path.join(folder, init), encoding="utf-8").read()
    children = module_items(folder, skip=(init,))
    return ('<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>%s'
            '<string name="Source"><![CDATA[%s]]></string></Properties>%s</Item>') % (cls, nref(), name, extra, cdata(src), children)
shared = os.path.join(root, "src/shared"); server = os.path.join(root, "src/server"); client = os.path.join(root, "src/client")
parts = ['<roblox version="4">']
parts.append('<Item class="Players" referent="%s"><Properties><string name="Name">Players</string><bool name="CharacterAutoLoads">false</bool></Properties></Item>' % nref())
parts.append('<Item class="ReplicatedStorage" referent="%s"><Properties><string name="Name">ReplicatedStorage</string></Properties>' % nref())
parts.append('<Item class="Folder" referent="%s"><Properties><string name="Name">Shared</string></Properties>%s</Item>' % (nref(), module_items(shared)))
parts.append('<Item class="Folder" referent="%s"><Properties><string name="Name">Audio</string></Properties><Item class="Folder" referent="%s"><Properties><string name="Name">Music</string></Properties></Item><Item class="Folder" referent="%s"><Properties><string name="Name">SFX</string></Properties></Item></Item></Item>' % (nref(), nref(), nref()))
parts.append('<Item class="ServerScriptService" referent="%s"><Properties><string name="Name">ServerScriptService</string></Properties>%s</Item>'
             % (nref(), script("Script", "Server", server, "init.server.luau", '<token name="RunContext">0</token>')))
parts.append('<Item class="StarterPlayer" referent="%s"><Properties><string name="Name">StarterPlayer</string><bool name="EnableMouseLockOption">false</bool></Properties>' % nref())
parts.append('<Item class="StarterPlayerScripts" referent="%s"><Properties><string name="Name">StarterPlayerScripts</string></Properties>%s</Item></Item>'
             % (nref(), script("LocalScript", "Client", client, "init.client.luau")))
parts.append('<Item class="SoundService" referent="%s"><Properties><string name="Name">SoundService</string><bool name="RespectFilteringEnabled">true</bool></Properties></Item>' % nref())
parts.append('<Item class="Workspace" referent="%s"><Properties><string name="Name">Workspace</string><float name="Gravity">115</float><bool name="StreamingEnabled">false</bool></Properties></Item>' % nref())
parts.append('</roblox>')
open(out, "w", encoding="utf-8").write("\n".join(parts))
