# Journal du projet — état à transmettre

## Version 0.5.0 — 1er octobre 2026

Demandes de Wilhem : routes de 6 appuis au lieu de 4 ; enchaîner les 2 derniers coups avec
3 barres déclenche une attaque unique en cinématique qui retire 95 % de la vie ; sous 50 %
c'est un « final finish » avec pose de K.O. au sol et plusieurs points de vue ; travailler
les modèles et les cinématiques. **Toujours rien de lancé dans Roblox Studio.**

Interprétation retenue (à confirmer) : 95 % de la vie **actuelle** de la cible, quel que soit
son total ; sous 50 % de la vie **maximale**, FINAL FINISH (K.O. garanti).

### Nouveautés

- **6 routes complètes de 6 appuis** (`MoveData.FullRoutes`) : TORNADE (L R L R L R),
  RAFALE (R L R L L R), DRAGON (L L R R L R), FOUDRE (R R L R L R), MUR (L L L R L R),
  LUNE (L L L L R R). Les deux derniers maillons : POURSUITE ÉCARLATE (L, bond à tête
  chercheuse qui vise la hauteur et la position de la cible) puis COUP DE GRÂCE (R).
  Dégâts mesurés : 311 à 407, et la route remplit ~la moitié de la jauge.
- **ÉVEIL ÉCARLATE** (champ `awakens` de COUP DE GRÂCE) : avec 300 de ki au moment du 6e
  coup, il le remplace (3 barres consommées, super flash, invincible 1-14). Cinématique
  autoritaire de 220 ticks : 7 coups puis le coup final ; dégâts totaux = 95 % de la vie au
  début de la cinématique (la cible reste à ~5 %), sans réduction de combo.
- **FINAL FINISH** : si la cible a moins de 50 % de sa vie maximale, la cinématique dure
  110 ticks de plus et se termine par un K.O. Le round ne se termine qu'après.
- **Cinématique ÉVEIL ÉCARLATE** (client) : gros plan sur les yeux avec le kanji peint,
  contre-plongée pendant l'éruption d'aura sous un ciel écarlate, travelling du dash, un
  angle de caméra différent à chaque coup (épaule, face, plongée, contre-plongée inclinée,
  trois-quarts), bond dans le ciel vu du sol, plongeon, onde de choc et instant noir et
  blanc. FINAL FINISH : chute au ralenti en noir et blanc, plan au ras du sol à l'impact,
  plongée sur le corps face contre terre, puis KAI bras croisés dos à l'adversaire tombé ;
  titres « FINAL FINISH » et « K.O. ».
- **Modèle de KAI** : cou, oreilles, nez, mâchoire, yeux avec paupières encrées, pupilles et
  reflets ; frange et 6 mèches de couronne ; débardeur à encolure, lignes de pectoraux et
  d'abdos ; gilet à col montant doublé de rouge, ourlet évasé, **kanji 開 dans le dos** ;
  deltoïdes et biceps arrondis ; bandages à bandes ; pantalon large avec plis et revers ;
  baskets avec embout, bande, talon et lacets ; ceinture épaisse à gros nœud.
- **IA** : DIFFICILE et LÉGENDE jouent aussi les routes de 6 appuis (donc l'ÉVEIL quand
  leur jauge est pleine).
- Mécaniques ajoutées : `homing` (bond vers la cible) et `track` (suivi horizontal des coups
  multi-touches) pour que les routes tiennent quelle que soit la trajectoire de la cible.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 48 tests (dont les 6 routes complètes jouées comme un joueur, ÉVEIL = −95 % exact, FINAL FINISH = K.O. après la cinématique, pas d'ÉVEIL sans 3 barres) | ✅ |
| `luau tests/FighterAI.test.luau` : 8 tests | ✅ |
| Compilation + analyse Luau | ✅ |
| Studio : modèle, cinématiques, angles de caméra | ❌ non exécuté — angles et poses estimés sans rendu |

## Version 0.4.0 — 1er octobre 2026

Demandes de Wilhem : plus de diversité, skills spéciaux en alternant clic gauche / clic
droit, meilleures animations, possibilité d'utiliser les rigs Roblox, et correction « quand
j'active l'IA, je tape tout seul ». **Toujours rien de lancé dans Roblox Studio.**

### Nouveautés

- **Skills par alternance** (★, nom annoncé à l'écran) : L R L R → TORNADE DU DRAGON
  (4 touches, lance) ; R L R L → RAFALE DE KI (7 coups, rebond mur) ; L L R R et
  R R L R → POING DU DRAGON (triple uppercut) ; L L L L R → CROISSANT DE LUNE (saltos, rebond
  au sol). Nouveaux maillons : PAUME DE KI (L R L), VENT ASCENDANT (R L R), TALON FOUDRE
  (R R L). Dégâts mesurés : 245 à 303 contre 202 pour la chaîne simple.
- **Coups multi-touches** (`hits`, `hitInterval`) : lancement / rebonds seulement sur la
  dernière touche ; un coup multi-touches ne s'annule qu'une fois toutes ses touches sorties ;
  le jonglage compte les coups, pas les touches.
- **KIKOHO** (S + E) : boule de ki, une à la fois, détection balayée (pas de traversée entre
  deux ticks), blocable, annulée par une boule adverse (clash).
- **File d'appuis** : seul le prochain appui vieillit, et pas pendant le démarrage / l'actif
  du coup en cours — taper L R L R d'avance donne exactement la route.
- **IA** : sous pression, le CPU restait en garde après chaque coup reçu ou bloqué (jusqu'à
  90 %) et ne contre-attaquait presque jamais, surtout en FACILE (premier mode CPU de la
  touche M). Maintenant : punition une fois par coup adverse en récupération,
  reversal invincible (E) et contre-attaque à la sortie d'étourdissement ou au réveil,
  boules de ki à distance, routes ★ en DIFFICILE / LÉGENDE, agressivité relevée. Mesure
  (4 min de pression continue d'un joueur qui ne fait qu'attaquer) : le CPU rend 74 à 81
  touches en FACILE, ~110 en NORMAL / DIFFICILE, ~200 en LÉGENDE.
- **Animations** : démarrage interpolé (par paliers) de la garde vers l'anticipation,
  impact net, retour progressif en garde ; deux poses alternées pour les coups multi-touches ;
  marche arrière ; deux réactions aux coups en alternance ; pose de kiai à l'intro ; poses
  pour tous les nouveaux coups.
- **Rigs Roblox** : bouton APPARENCE pour jouer avec son propre avatar R15
  (`Players:CreateHumanoidModelFromDescription`). Les 15 articulations R15 ont les mêmes noms
  que celles de KAI : les mêmes poses s'appliquent. Repli automatique sur KAI si l'avatar ne
  se charge pas (joueurs de test d'un serveur local Studio). Le R6 n'est pas utilisé : il
  n'a pas de coudes ni de genoux.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 39 tests (dont les 5 skills, multi-touches, KIKOHO, clash, garde de la boule) | ✅ |
| `luau tests/FighterAI.test.luau` : 8 tests (dont « sous pression, chaque niveau rend des coups » et « zoning à distance ») | ✅ |
| Compilation + analyse Luau de tous les scripts | ✅ |
| Studio, avatar R15, rendu des poses et des effets | ❌ non exécuté |

### Problèmes ouverts

- Avatars R15 : accessoires très grands ou avatars Rthro à vérifier visuellement ; les
  hurtboxes restent celles de KAI (identiques pour tous).
- Le reste des problèmes ouverts de la 0.3.0 ci-dessous tient toujours.

## Version 0.3.0 — 1er octobre 2026

**Phase :** à la demande de Wilhem, au-dessus de la 0.2.0 : arbre de combos clic gauche /
clic droit, jauge de ki, compétence spéciale (E), ultime (R) avec cinématique, mannequin
CPU à 4 niveaux. **Rien n'a encore été lancé dans Roblox Studio** (ni la 0.2.0 ni la 0.3.0) :
un rapport de test est attendu avant la suite.

### Architecture réseau retenue

Prototype **classique** : `RemoteEvent` + simulation autoritaire côté serveur à 60 Hz
(boucle à pas fixe sur `Heartbeat`, rattrapage limité à 8 ticks). Le client envoie des
inputs validés et affiche des snapshots (30/s) avec une légère extrapolation. **Pas de
prédiction client ni de rollback** : le joueur ressent la latence réseau sur ses propres
actions. Input Action System et Server Authority n'ont pas été vérifiés (pas d'accès à
Studio) ; à réévaluer avant la phase 7. Le CPU tourne sur le serveur et envoie les mêmes
inputs qu'un joueur : il obéit aux mêmes règles.

### Fichiers

| Chemin Rojo | Instance dans Studio | Rôle |
|---|---|---|
| `src/shared/CombatConfig.luau` | ReplicatedStorage.Shared.CombatConfig | Valeurs globales (ticks, vitesses, garde, ki, rounds) |
| `src/shared/MoveData.luau` | …Shared.MoveData | Frame data, routes de combo, script de la cinématique |
| `src/shared/CombatSimulation.luau` | …Shared.CombatSimulation | Simulation pure : mouvement, coups, garde, combos, ki, ultime, rounds |
| `src/shared/FighterAI.luau` | …Shared.FighterAI | CPU pur (4 niveaux), produit des inputs |
| `src/shared/CharacterData.luau` | …Shared.CharacterData | KAI 開, skins CLASSIQUE (P1) et NUIT (P2) |
| `src/shared/InputConfig.luau` | …Shared.InputConfig | Bindings clavier/souris/manette |
| `src/server/init.server.luau` | ServerScriptService.Server | Slots, modes du mannequin, validation, boucle 60 Hz, snapshots, événements |
| `src/server/ArenaBuilder.luau` | Server.ArenaBuilder | Arène « Temple écarlate » + éclairage |
| `src/server/RigBuilder.luau` | Server.RigBuilder | Rig R15 en blocs de KAI (15 Motor6D) |
| `src/client/init.client.luau` | StarterPlayerScripts.Client | Affichage, interpolation, branchements |
| `src/client/InputController.luau` | Client.InputController | Adaptateur d'inputs (clavier, souris, manette, tactile) |
| `src/client/AnimationController.luau` | Client.AnimationController | Seul écrivain des Motor6D ; poses par paliers |
| `src/client/EffectsController.luau` | Client.EffectsController | VFX : étincelles, smears, bouclier, impact frames, afterimages, aura, debug hitbox |
| `src/client/CinematicController.luau` | Client.CinematicController | Cut-in du super flash, cinématique de l'ultime, retour caméra garanti |
| `src/client/CameraController.luau` | Client.CameraController | Caméra latérale, secousse, zoom d'impact |
| `src/client/HUDController.luau` | Client.HUDController | Vie, garde, ki, chrono, combos, annonces, panneau COMBOS |
| `tests/CombatSimulation.test.luau` | — | 30 tests de la simulation |
| `tests/FighterAI.test.luau` | — | 6 tests du CPU |
| `tests/TestKit.luau` | — | Aides de test |

### Conventions

- X = gauche/droite, Y = hauteur, Z verrouillé à 0. 1 tick = 1/60 s.
- Un coup dure `startup + active + recovery` ticks, la frame 1 étant le tick où il démarre.
  La hitbox existe pour `startup < frame ≤ startup + active` et ne touche qu'une fois.
- Le hitstop et le super flash gèlent les combattants (frames, stun) : aucune fenêtre
  n'avance pendant le gel.
- Les appuis sont mis en file (3 max, 12 ticks de vie, gelés pendant le hitstop) et joués
  dans l'ordre tapé.
- L'orientation est verrouillée pendant les attaques, stuns, dashs et sauts.
- Hurtbox, hitbox et pushbox sont séparées et purement logiques (pas de `Touched`).
- Le client ne décide jamais d'un coup, de la vie, du ki ni d'un KO. La cinématique est un
  script autoritaire (coups à des ticks fixes) ; le client ne fait que la mettre en scène.

### Gameplay

**Combos** (L = clic gauche, R = clic droit) — un coup s'enchaîne si le précédent a touché
ou a été bloqué :

| Touches | Route | Effet |
|---|---|---|
| L L L L | JAB > CROSS > COUDE > KICK | chute |
| L L R | JAB > CROSS > LANCEUR | lance ; Espace = super saut, puis L L R aérien (KICK AÉRIEN > DOUBLE KICK > MÉTÉORE) |
| L R | JAB > COUP AU FOIE | effondrement (52 ticks) pour relancer un combo |
| L L L R | JAB > CROSS > COUDE > TALON TOURNOYANT | rebond au mur |
| R R | FRAPPE LOURDE > HACHE CÉLESTE | overhead, rebond au sol |
| R L | FRAPPE LOURDE > BALAYAGE | coup bas, chute |
| ↓L / ↓R | KICK BAS / LANCEUR | KICK BAS > CROSS > … |
| tout normal > E | RISING STRIKE | spéciale invincible (frames 1-10), lance |
| tout coup > R | KAIEN RUSH | ultime, 2 barres |

Règles anti-boucle : réduction ×0,9 par coup déjà pris (min ×0,4 ; ×0,5 pour l'ultime),
6 coups aériens maximum, un seul effondrement / rebond sol / rebond mur par combo.

**Ki** : 3 barres (300). Gain : 50 % des dégâts infligés, 30 % des dégâts reçus, 25 % / 20 %
sur garde. Conservé entre les rounds, remis à 0 à chaque nouveau match. Plein en
entraînement après chaque combo.

**Ultime KAIEN RUSH** (touche R, 2 barres) : super flash de 40 ticks (cut-in), ruée
invincible ; si ça touche : cinématique de 150 ticks, 11 coups + coup final (dégâts réduits
×0,5 au minimum), adversaire projeté. Le chrono est en pause et le round ne peut se finir
qu'après la cinématique. Bloqué ou raté : pas de cinématique, longue récupération.

**Garde (F)** : 15 % des dégâts (jamais de KO en garde), jauge de garde, GUARD BREAK à 0.
Garde basse (F + S) contre les coups bas, debout contre les overheads.

**Mannequin** (touche M ou bouton) : IMMOBILE → GARDE → CPU FACILE → NORMAL → DIFFICILE →
LÉGENDE. Les modes CPU jouent en règles versus (rounds, chrono). Le CPU perçoit avec un
délai (24 / 16 / 10 / 6 ticks), garde par réaction et par anticipation, contre les sauts
avec la spéciale, punit les coups ratés, choisit des routes de combo selon son niveau et
utilise l'ultime (NORMAL et au-dessus).

Résultats hors ligne CPU contre CPU (3 matchs de 4 min par duel) : LÉGENDE bat FACILE 15-0,
NORMAL 13-0, DIFFICILE 7-1 ; DIFFICILE bat NORMAL 11-0 ; NORMAL bat FACILE 11-0.

| Coup | Startup | Actif | Récup. | Dégâts | Hitstun | Garde | Propriétés |
|---|---|---|---|---|---|---|---|
| JAB | 5 | 3 | 9 | 45 | 17 | Mid | |
| CROSS | 6 | 3 | 11 | 55 | 19 | Mid | |
| COUDE | 6 | 3 | 13 | 60 | 21 | Mid | |
| KICK | 8 | 4 | 18 | 80 | 24 | Mid | lance (chute) |
| COUP AU FOIE | 9 | 3 | 16 | 70 | 22 | Mid | effondrement |
| LANCEUR | 8 | 4 | 22 | 70 | 26 | Mid | lance, saut-cancel |
| TALON TOURNOYANT | 10 | 3 | 22 | 95 | 26 | Mid | lance, rebond mur |
| FRAPPE LOURDE | 13 | 4 | 22 | 110 | 26 | Mid | grosse usure de garde |
| HACHE CÉLESTE | 12 | 4 | 20 | 90 | 28 | High | rebond sol |
| BALAYAGE | 9 | 4 | 20 | 60 | 22 | Low | chute |
| KICK BAS | 5 | 3 | 10 | 35 | 16 | Low | |
| KICK AÉRIEN | 6 | 6 | 10 | 55 | 20 | High | |
| DOUBLE KICK | 6 | 4 | 12 | 55 | 20 | High | |
| MÉTÉORE | 9 | 5 | 14 | 80 | 24 | High | smash vers le sol, rebond |
| RISING STRIKE | 9 | 5 | 26 | 100 | 30 | Mid | lance, saut-cancel, invincible 1-10 |
| KAIEN RUSH | 8 | 10 | 36 | 30 (+ cinématique) | 40 | Mid | invincible 1-12, 2 barres |

Vie : 1000. Route la plus forte mesurée : L L L E puis R ≈ 480 dégâts (2 barres). Toutes
ces valeurs sont des points de départ à régler en jeu.

### Direction artistique appliquée

Planches « KAI 開 » et roster de Wilhem : noir / blanc / rouge, gilet sans manches ouvert,
débardeur blanc, ceinture rouge, bandages, pantalon large, cheveux noirs en pointes à
mèches rouges. P2 = skin NUIT (bleu). Contour encre via `Highlight`. Poses par paliers
(12/15/24/s ou fluide). Étincelles manga, smears par coup lourd, bouclier bleu/violet,
impact frames noir/blanc/rouge, afterimages (dash et téléportations de l'ultime), aura de
ki, cut-in diagonal du super, bandes cinéma, plans de caméra coupés « à l'anime ».
Bouton EFFETS : réduit flashs et secousses (réduit par défaut sur mobile).

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` (30 tests : chaque route de combo, file d'appuis, garde haute/basse, ki, ultime et cinématique, rebonds, effondrement, saut-cancel, invincibilité, rounds, KO, timeout, double KO…) | ✅ passés |
| `luau tests/FighterAI.test.luau` (6 tests : chaque niveau inflige des dégâts, matchs complets sans erreur, hiérarchie des niveaux, garde, routes et ultime, déterminisme) | ✅ passés |
| Compilation + analyse Luau de tous les scripts | ✅ |
| Jeu dans Studio (solo, CPU, 2 clients, manette, tactile, téléphone) | ❌ non exécuté |
| Rendu visuel (rig, poses, cinématique, cut-in, HUD) | ❌ non vérifié, valeurs à ajuster |

### Problèmes ouverts / risques

- Aucune prédiction client : délai entrée → action égal au ping + jusqu'à 33 ms.
- Poses, angles caméra de la cinématique et ornements estimés sans rendu : à retoucher.
- Pas de sons (aucun ID d'asset inventé) : prévoir des SFX fournis par Wilhem.
- `UserInputService.PreferredInput` (texte d'aide) à confirmer dans le Studio utilisé.
- Sur mobile, la rangée de boutons du HUD peut déborder sur petit écran.

### Prochaine étape proposée

1. Wilhem teste dans Studio (entraînement, chaque niveau CPU, puis 2 clients) et renvoie le
   rapport : Output complet, captures, courte vidéo de la cinématique.
2. Corrections de poses / ressenti / équilibrage, puis SFX.
3. Ensuite, d'après le roster : sélection de personnage (RYUEN, ZEPHYR, KARA, DAIGO, SORA,
   AKEMI, TARO) et environnements (ville néon, cascade, torii de nuit).
