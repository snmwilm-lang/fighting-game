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
| Boule de ki : KIKOHO | **S + E** | Bas + Y | BAS + SPÉ |
| Mode du mannequin (immobile, garde, CPU ×4) | M ou bouton MANNEQUIN | — | bouton |
| Apparence : KAI ou ton avatar Roblox (R15) | bouton APPARENCE | — | bouton |
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
| **L R L R** ★ | JAB > COUP AU FOIE > PAUME DE KI > **TORNADE DU DRAGON** | skill : 4 touches, lance |
| **R L R L** ★ | FRAPPE > BALAYAGE > VENT ASCENDANT > **RAFALE DE KI** | skill : 7 coups de poing, rebond mur |
| **L L R R** ★ | JAB > CROSS > LANCEUR > **POING DU DRAGON** | skill : triple uppercut |
| **R R L R** ★ | FRAPPE > HACHE > TALON FOUDRE > **POING DU DRAGON** | skill |
| **L L L L R** ★ | … > KICK > **CROISSANT DE LUNE** | skill : saltos, rebond au sol |
| … touche E | RISING STRIKE | après n'importe quel coup, invincible au démarrage |
| … touche R | KAIEN RUSH | après n'importe quel coup ou la spéciale, cinématique si ça touche |

### Routes complètes (6 appuis)

Chaque route ★ se prolonge par **L** (POURSUITE ÉCARLATE, bond à tête chercheuse) puis
**R** (COUP DE GRÂCE) :

| Touches | Route |
|---|---|
| L R L R L R | TORNADE |
| R L R L L R | RAFALE |
| L L R R L R | DRAGON |
| R R L R L R | FOUDRE |
| L L L R L R | MUR |
| L L L L R R | LUNE (CROISSANT DE LUNE > COUP DE GRÂCE) |

### Les 3 ultimes de KAI

| Ultime | Comment | Effet |
|---|---|---|
| **KAIEN RUSH** | touche **R** seule, 2 barres | ruée cinématique |
| **ÉVEIL ÉCARLATE** | route complète jouée **proprement**, 6e coup au **clic droit**, 3 barres | l'adversaire perd **95 % de sa vie actuelle** ; sous **50 %** : **FINAL FINISH** (K.O. et scène de K.O.) ; la **finale change selon la route** (TORNADE, RAFALE, DRAGON, FOUDRE, MUR, LUNE) ; **QTE en rythme** pendant la rafale : tout réussi = PARFAIT, 1 barre rendue |
| **開天 PORTE DES CIEUX** | même route propre, 6e coup avec la **touche R**, 3 barres | un torii géant aspire l'adversaire dans un monde écarlate pour un coup unique : 50 % de la vie max (peut tuer) ; **R pile au sommet** : +10 % |

« Proprement » = un seul appui par coup, **après** que le coup précédent a touché (toutes ses
touches). Spammer pendant la route verrouille ÉVEIL et PORTE (on obtient COUP DE GRÂCE ou
KAIEN RUSH à la place).

Les persos sont des **personnages Roblox** : ton avatar R15 par défaut (bouton APPARENCE pour
revenir à KAI), et le CPU est un **clone d'ombre** de ton avatar.

★ = skill spécial débloqué en **alternant clic gauche et clic droit** : son nom s'affiche à
l'écran. Les appuis sont mis en file dans l'ordre (3 max) : on peut taper la route d'avance.

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
