# jeuxcombat — KAI 開 · TARO 火 · ZEPHYR 風 · AKEMI 影

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
| Spéciale (invincible au départ) | **E** | Y | SPÉ |
| Ultime (2 barres de ki, cinématique) | **R** | LT | ULTI |
| Garde | **F maintenu** (F + S : garde basse) | RB | GARDE |
| Spéciale basse (projectile, ou PARADE de TARO) | **S + E** | Bas + Y | BAS + SPÉ |
| **Changer de perso** | **T** ou bouton PERSO | — | bouton |
| Perso du CPU (solo) | **G** ou bouton ADVERSAIRE | — | bouton |
| Mode du mannequin (immobile, garde, CPU ×4) | M ou bouton MANNEQUIN | — | bouton |
| Apparence : avatar R15 → avatar R6 → modèle | bouton APPARENCE | — | bouton |
| Couleurs du perso | bouton STYLE | — | bouton |
| Sons on / off | bouton SON | — | bouton |
| Replacer | Retour arrière | Select | bouton REPLACER |

En versus, on change de perso avant le premier coup du match ou une fois le match fini (le
match repart à zéro) ; en solo, à tout moment.

## Les 4 combattants

| Perso | Style | Vie | Points forts | Points faibles | S + E |
|---|---|---|---|---|---|
| **KAI 開** | polyvalent : poings, pieds, ki | 1550 | rien de faible, boule de ki | rien d'extrême | KIKOHO (boule de ki) |
| **TARO 火** | **boxeur** : que les poings | 1600 | le plus robuste, **garde de fer** (−20 % d'usure de garde), jab le plus rapide | allonge courte, le plus lent | **PARADE** : bloque un coup debout ou un projectile et contre-attaque (perd contre les coups bas et les ultimes) |
| **ZEPHYR 風** | **que les pieds** | 1450 | **plus grande allonge** (+12 %), saut le plus haut, dégâts +5 % | coups qui démarrent un peu plus tard | LAME DE VENT (projectile) |
| **AKEMI 影** | **esquive** | **1100** | la plus rapide, **dash intouchable** au départ, passif **VOILE D'OMBRE** | **encaisse le moins**, dégâts −12 % | KUNAÏ (projectile) |

**VOILE D'OMBRE** (passif d'AKEMI) : au neutre — sans attaquer, sans être déjà touchée, sans
garder — le premier coup reçu est esquivé : AKEMI recule hors de portée, intouchable un
instant, puis se remet en garde. Recharge en **20 s** (jauge à côté de la barre de garde),
jamais contre les ultimes. Elle remet le neutre à zéro, elle ne donne pas de punition
gratuite ; pour la vider, un jab seul suffit.

Chaque perso porte **sa tenue sur ton avatar Roblox** (R15 ou R6), taillée sur ses vraies
pièces : KAI bandeau, ceinture et bandages ; TARO gants de boxe, short et ceinture de
champion ; ZEPHYR longue écharpe au vent, protège-tibias ; AKEMI capuche, masque et
brassards. Kanji du perso dans le dos, 2 à 4 styles de couleurs chacun (bouton STYLE).

## Combos (L = clic gauche, R = clic droit)

Les 4 persos ont **la même grammaire** : mêmes touches, mêmes effets, chacun avec ses
propres coups (bouton **COMBOS** en jeu : la liste du perso choisi). Pour KAI :

| Touches | Enchaînement | Effet |
|---|---|---|
| L L L L | JAB > CROSS > COUDE > KICK | chute |
| L L R | JAB > CROSS > LANCEUR | envoie en l'air ; **Espace** pour suivre, puis L L R en l'air |
| L R | JAB > COUP AU FOIE | effondrement : le temps de relancer un combo |
| L L L R | … > TALON TOURNOYANT | rebond sur le mur |
| R R | FRAPPE LOURDE > HACHE CÉLESTE | overhead, rebond au sol |
| R L | FRAPPE LOURDE > BALAYAGE | coup bas, chute |
| ↓ + L / ↓ + R | KICK BAS / LANCEUR | KICK BAS s'enchaîne sur CROSS |
| **L R L R** ★ | … > **TORNADE DU DRAGON** | skill |
| **R L R L** ★ | … > **RAFALE DE KI** | skill, rebond mur |
| **L L R R** ★ | … > **POING DU DRAGON** | skill : triple uppercut |
| **R R L R** ★ | … > **POING DU DRAGON** | skill |
| **L L L L R** ★ | … > **CROISSANT DE LUNE** | skill, rebond au sol |
| … touche E | spéciale | après n'importe quel coup, invincible au démarrage |
| … touche R | ultime 1 | après n'importe quel coup ou la spéciale |

### Le rythme (route « propre »)

Un combo se joue **en rythme** : chaque appui **après la sortie du coup d'avant** (dès ses
frames actives, l'impact, la récupération ou les 6 frames de tolérance). Appuyer pendant
l'élan du coup précédent continue le combo mais il n'est plus **propre** (« TROP TÔT »). La
file garde 3 appuis et chacun expire au bout de 10 frames (« APPUI PERDU ») : impossible de
taper toute la route d'avance. Plusieurs boutons à la fois, un appui de trop ou un mauvais
bouton = « SPAM ». **Changer d'avis gagne** : garde, saut ou dash annulent les coups en
attente, et un coup dans le vide oublie les appuis faits pendant son élan. L'ENTRAÎNEUR dit
pourquoi une route n'est pas propre.

### Routes complètes et les 3 ultimes

Chaque route ★ se prolonge par **L** (poursuite) puis **R** (coup de grâce) : 6 routes de
6 appuis par perso.

| Ultime | Comment | KAI | TARO | ZEPHYR | AKEMI |
|---|---|---|---|---|---|
| 1 · ruée | **R** seul, 2 barres | KAIEN RUSH | RUSH DÉVASTATEUR | VENT TRANCHEUR | OMBRES MULTIPLES |
| 2 · éveil | route complète **propre**, 6e au **clic droit**, 3 barres | ÉVEIL ÉCARLATE | UPPERCUT CÉLESTE | DRAGON ASCENDANT | TEMPS SUSPENDU |
| 3 · porte | route complète **propre**, 6e à la **touche R**, 3 barres | 開天 PORTE DES CIEUX | 火嵐 TEMPÊTE DE CROCHETS | 旋風 CYCLONE FURIEUX | 幻舞 DANSE FANTÔME |

TARO, ZEPHYR et AKEMI ont chacun leur mise en scène (planche d'ultimes de Wilhem) : TARO
charge et cogne de face, soulève l'adversaire dans un pilier de feu puis tourne autour de lui
crochet après crochet ; ZEPHYR enchaîne les coups de pied avec des lames de vent, monte avec
sa cible dans un dragon de vent, puis l'enferme dans un cyclone ; AKEMI frappe de partout
avec ses ombres, arrête le temps (noir et blanc) pour frapper au ralenti, puis danse entre
esquives et coups instantanés. KAI garde les siennes (finale de l'éveil selon la route).

L'éveil retire **95 % de la vie actuelle** ; sous **50 %** c'est un **FINAL FINISH** (K.O.) ;
la finale change selon la route ; QTE en rythme pendant la rafale. La porte retire 40 % de la
vie max (peut tuer) ; R pile au sommet : +10 %. Les ultimes ne sont ni esquivés ni parés.

## Avatars R15 et R6

Par défaut, tu joues **ton avatar Roblox**, dans le type de corps choisi sur ton compte
(R15 ou R6), mis à la taille du jeu (≈ 5,7 studs) et habillé de la tenue de ton perso. Le
bouton APPARENCE passe de l'avatar R15 à l'avatar R6, puis au modèle en blocs. Un corps R6
n'a ni coudes ni genoux : l'animation tourne sur un squelette R15 virtuel aux proportions
du corps R6, puis chaque membre rigide est orienté vers le poing ou le pied correspondant
(`src/shared/Retarget.luau`). Le CPU est un **clone d'ombre** de ton avatar (même type de
corps). Si l'avatar ne peut pas se charger, un corps par défaut porte la tenue et la ligne
d'état dit pourquoi.

## Animation

Moteur d'animation pur (`src/shared/Animator.luau`), testé hors Studio avec la cinématique du
vrai rig : coups en 4 temps (anticipation, impact, contact, retour), pieds plantés par IK,
course sans glissade, corps posé au sol quelle que soit la taille de l'avatar, réactions selon
le coup reçu, regard vers l'adversaire, ressorts, tissus qui ondulent. Chaque perso a sa
garde, sa course et ses coups. Bouton **POSES** : 12 / 15 / 24 poses par seconde ou FLUIDE.

## S'entraîner et vérifier

- **ENTRAÎNEUR** : choisis une route de ton perso ; la barre en bas montre les touches,
  s'allume en jaune (« MAINTENANT ! ») quand le prochain appui tombe en rythme, et dit
  pourquoi un combo casse.
- **LABO CINÉ** (solo) : lance chaque cinématique de ton perso directement. Avec **HITBOX**
  activé, le nom du plan et le tick s'affichent.
- Les appuis faits pendant qu'on se fait frapper sont ignorés (sauf les 4 dernières frames,
  pour un reversal), et maintenir la garde au relevé l'emporte.

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

La simulation de combat, l'IA, les kits, la mise en scène des cinématiques et l'animation
(`src/shared/`) n'utilisent aucune API Roblox ; elles se testent avec le
[CLI Luau](https://github.com/luau-lang/luau/releases) :

```bash
luau tests/CombatSimulation.test.luau
luau tests/FighterAI.test.luau
luau tests/CinematicDirector.test.luau
luau tests/Animation.test.luau
luau tests/Kits.test.luau
luau tests/PressQueue.test.luau
luau tests/Fuzz.test.luau            # entrées aléatoires, tous les duels : invariants
luau tests/Cinematography.test.luau  # cadrage de chaque ultime avec le vrai rig
luau tests/Balance.luau -a 4 120   # rapport d'équilibrage CPU contre CPU (niveau, matchs)
```

### Planche de poses R6 / R15

Les mêmes poses sur un corps R6 (à gauche) et sur le rig R15 (à droite), vues par la caméra du
jeu :

```bash
luau tests/PoseSheet.luau -a AKEMI 0 > sheet.txt
python3 tools/storyboard.py sheet.txt sheet.png
```

### Storyboard des cinématiques

Planche de ce que voit la caméra, image par image (corps posés par le vrai moteur
d'animation, effets simplifiés) — Python 3 et Pillow :

```bash
luau tests/Storyboard.luau -a TARO Gate - 0 8 > story.txt
python3 tools/storyboard.py story.txt story.png
```

## Documents

- `docs/Roblox_Guide_Claude.md` — cahier des charges du projet.
- `docs/JOURNAL.md` — état du projet à transmettre après chaque livraison.
