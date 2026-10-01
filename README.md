# jeuxcombat — KAI 開

Jeu de combat Roblox 2.5D (persos 3D, combat sur un plan 2D, caméra de côté), style anime
noir / blanc / rouge. Le code vit dans `src/` et est synchronisé dans Roblox Studio par
[Rojo](https://rojo.space) 7.7.

## Contrôles

| Action | Clavier / souris | Manette | Mobile |
|---|---|---|---|
| Bouger | Q/A · D (ou flèches) | Stick gauche / croix | Joystick |
| Saut | Espace (ou Z/W) | A | SAUT |
| Accroupi | S | Bas | BAS / joystick bas |
| Dash | Shift + direction | RT | DASH |
| Combo (JAB → CROSS → COUDE → KICK) | **Clic gauche** (ou J), à répéter | X | COUP |
| Lourd / finisher RISING STRIKE | **Clic droit** (ou K) — seul : frappe lourde ; pendant le combo : envoie en l'air | B | LOURD |
| Garde | **F maintenu** (ou I) — F + S : garde basse | RB | GARDE |
| Replacer (entraînement) | R | Select | bouton REPLACER |

## Lancer le jeu

```bash
rojo serve
```

Puis, dans Roblox Studio, ouvrir le plugin Rojo et cliquer sur **Connect** : les scripts de
`src/` remplacent ceux de la place. Pour générer une place sans Rojo serve :

```bash
rojo build -o "jeuxcombat.rbxlx"
```

⚠️ Ne modifie pas les scripts directement dans Studio quand Rojo est connecté : Rojo les
écrase avec le contenu de `src/`. Toute modification passe par les fichiers du dépôt.

## Tests hors Studio

La simulation de combat (`src/shared/CombatSimulation.luau`) n'utilise aucune API Roblox ; elle
se teste avec le [CLI Luau](https://github.com/luau-lang/luau/releases) :

```bash
luau tests/CombatSimulation.test.luau
```

## Documents

- `docs/Roblox_Guide_Claude.md` — cahier des charges du projet.
- `docs/JOURNAL.md` — état du projet à transmettre à ChatGPT après chaque livraison.
