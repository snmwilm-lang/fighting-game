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
| Attaque légère (combo) | **Clic gauche** (ou J) | X | COUP |
| Attaque lourde | **Clic droit** (ou K) | B | LOURD |
| Compétence spéciale : RISING STRIKE | **E** | Y | SPÉ |
| Ultime : KAIEN RUSH (2 barres de ki, cinématique) | **R** | LT | ULTI |
| Garde | **F maintenu** (F + S : garde basse) | RB | GARDE |
| Mode du mannequin (immobile, garde, CPU ×4) | M ou bouton MANNEQUIN | — | bouton |
| Replacer | Retour arrière | Select | bouton REPLACER |

## Combos (L = clic gauche, R = clic droit)

| Touches | Enchaînement | Effet |
|---|---|---|
| L L L L | JAB > CROSS > COUDE > KICK | chute |
| L L R | JAB > CROSS > LANCEUR | envoie en l'air ; **Espace** pour suivre, puis L L R en l'air |
| L R | JAB > COUP AU FOIE | effondrement : le temps de relancer un combo |
| L L L R | … > TALON TOURNOYANT | rebond sur le mur |
| R R | FRAPPE LOURDE > HACHE CÉLESTE | overhead, rebond au sol |
| R L | FRAPPE LOURDE > BALAYAGE | coup bas, chute |
| ↓ + L / ↓ + R | KICK BAS / LANCEUR | KICK BAS s'enchaîne sur CROSS |
| … touche E | RISING STRIKE | après n'importe quel coup, invincible au démarrage |
| … touche R | KAIEN RUSH | après n'importe quel coup ou la spéciale, cinématique si ça touche |

Les appuis sont mis en file dans l'ordre (3 max) : on peut taper la route d'avance.

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

La simulation de combat (`src/shared/CombatSimulation.luau`) et l'IA (`src/shared/FighterAI.luau`)
n'utilisent aucune API Roblox ; elles se testent avec le [CLI Luau](https://github.com/luau-lang/luau/releases) :

```bash
luau tests/CombatSimulation.test.luau
luau tests/FighterAI.test.luau
```

## Documents

- `docs/Roblox_Guide_Claude.md` — cahier des charges du projet.
- `docs/JOURNAL.md` — état du projet à transmettre à ChatGPT après chaque livraison.
