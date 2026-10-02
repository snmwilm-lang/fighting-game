# Journal du projet — état à transmettre

## Version 0.11.2 — 2 octobre 2026

Retour de Wilhem : « en fin de cinématique avec un coup de poing, beaucoup de persos ont les
mains jointes » (capture : le titre de la PORTE DES CIEUX de KAI) ; « c'est peut-être l'angle
qui porte à confusion » ; « la position de KAI pendant le kamehameha ».

- **Diagnostic** : en 3D, les mains ne se touchent jamais (mesuré sur R15 et R6, tous les styles,
  FINAL FINISH, scènes de K.O.). C'était l'angle : des plans regardaient le perso dans l'axe des
  bras, un poing cachait l'autre et l'on croyait voir des mains jointes (titre de la Porte de
  KAI : 48 images sur 48).
- **Angles recomposés** (`CinematicDirector`, toujours par `frameOn`) : 23 plans, dont
  porte-after, porte-shatter, eveil-strike1 (CUTS[1]), taro-tempete-liver, zephyr-vent-drift,
  zephyr-cyclone-gust, akemi-temps-tableau3, ryuken-effondrement-body, ryuken-round-guard / cock,
  shin-tempete-still / rise, shin-zero-cuts, daicha-riviere-strike, daicha-eclipse-mirror,
  daicha-eclipse-flash, daicha-domaine-crown, hibecares-colosse-march, hibecares-ruines-fist,
  ko-shin-horizon, ko-shin-leave, ko-zephyr-orbit. Seul reste l'iai de SHIN (ses deux mains sont
  vraiment sur la poignée).
- **Kamehameha de KAI** (fin de la Ruée) : il tirait le rayon vers le sol avec les bras à
  l'horizontale. Nouvelle pose `KiBeamDown` : penché sur la cible, les deux bras tendus vers le
  bas, paumes jointes, jambes repliées ; le rayon part de ses paumes.
- Tests : Cinematography + 1 (aucun plan où un poing cache l'autre, 8 kits, R / Éveil / Porte /
  K.O.), Animation 34 (+1 : bras du rayon vers le bas, paumes jointes, R15 et avatar) ; CombatSimulation 82, FighterAI 10, CinematicDirector 250 (suites longues : voir le commit suivant).

### Problèmes ouverts / prochaine étape

- Confirmer en jeu que l'orbe de DAICHA vole (v0.11.1).
- Ajustement IK des contacts (poing arrêté à la surface de l'adversaire).

## Version 0.11.1 — 2 octobre 2026

Retour de Wilhem : « refais le même focus animation / cinématiques ; DAICHA, c'est encore buggé,
l'orbe est collée à sa main ».

- **Orbe collée à la main (bug client)** : `EffectsController` ne libérait l'orbe qu'une fois,
  quand le corps arrivait ; les pièces de tenue (KitShadowOrb, KitOrbCore) répliquent souvent
  après le corps, l'orbe restait donc soudée. Nouveau `attachWeapon`, réessayé toutes les 0,2 s
  tant que l'arme n'est pas là (et de nouveau si la tenue est reconstruite) ; toutes les
  soudures qui la tiennent sont détruites, où qu'elles soient rangées (WeldConstraint, Weld,
  Motor6D). Non vérifiable hors Studio : à confirmer en jeu.
- **Mise en scène propre** (`CinematicDirector`, après chaque image d'une cinématique) :
  - vitesse : un corps qui va plus vite que 0,9 stud par image dans un même plan est dessiné
    avec ses images rémanentes (ghost) : plus aucune téléportation visible (TARO qui tournait
    autour de sa cible par sauts, ZEPHYR, AKEMI et RYUKEN qui changeaient de côté, la cible
    de HIBECARES, les chutes) ;
  - place : au sol, un attaquant ne se colle jamais à moins de 2,8 studs de sa cible.
- Outil `tests/CinematicQuality.luau` (interpénétration, téléportations, à-coups par
  cinématique) ; `CinematicKit` donne aussi les poses. Téléportations visibles : 79 → 0 ;
  interpénétration moyenne TARO Ruée 5,5 % → 2,5 %, RYUKEN Éveil 3,3 % → 1,5 %, Porte 2,2 % → 1,1 %.
- Tests : CinematicDirector 250 (+1 : ni téléportation sans images rémanentes ni attaquant
  collé) ; CombatSimulation 82, FighterAI 10, Animation 33, Kits 54, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Confirmer en jeu que l'orbe vole (et sa chaîne en attaque).
- Ajustement IK des contacts (poing arrêté à la surface de l'adversaire).

## Version 0.11.0 — 2 octobre 2026

Demande de Wilhem : « concentre-toi purement sur les animations, parfois c'est très brouillon,
rends ça plus qualitatif » ; « ensuite la même chose avec les cinématiques et les scènes de
K.O. / victoire » ; « l'orbe noire doit bouger pendant les attaques comme un nunchaku ».

- **Outils pour juger le mouvement** (avant, on ne jugeait que des images fixes) :
  `tests/ClipKit.luau` joue un combat scénarisé (vraie simulation + vrai Animator, caméra du
  jeu), `tests/AnimClip.luau` en fait un GIF (`tools/storyboard.py clip.txt clip.gif`, zoom
  possible), `tests/AnimQuality.luau` mesure les à-coups (articulation qui saute de plus de 28°
  en une image hors impact), les tremblements et l'interpénétration des deux corps.
- **Animator** (pur) :
  - anticipation : l'armé est atteint plus tôt (45 % du démarrage) puis continue de se tendre
    à l'opposé du coup jusqu'au départ (moving hold) au lieu d'une pose figée ;
  - **inertie / follow-through** : ressorts par articulation après le mélange — buste, épaules,
    coudes, poignets, tête, et la jambe libre (coups de pied, sauts, chutes) ; un impact (snap)
    tombe instantanément sur sa pose et fouette au-delà ; les jambes plantées par l'IK ne
    traînent jamais ; une coupure (blink, nouveau round, plan) remet tout à zéro (déplacement
    > 2,5 studs en une image) ;
  - **espacement d'affichage** `Animator.spacing` : à bout portant, chaque corps est dessiné
    jusqu'à 0,42 stud plus loin de l'autre, sans jamais de saut (la séparation affichée croît
    toujours avec la vraie), rien à distance ni au croisement (DAICHA) ; dessin seulement, les
    positions, hitbox et caméra restent celles du serveur ; jamais en cinématique ;
  - garde : un rythme par perso (`IDLE_RHYTHM` : TARO 1,9 Hz, SHIN 0,55 Hz, HIBECARES 0,5 Hz...)
    et un transfert de poids d'un pied à l'autre ;
  - saut : poussée des jambes au décollage ; dash avant : élan, puis freinage accroupi ;
  - les poses de chute, de relevé, de réaction et de saut peuvent être propres à un kit ;
    SHIN : la lame se couche le long du bras au sol, horizontale à genou (avant : plantée à la
    verticale comme un piquet) ;
  - les poses tenues des scènes (victoire, rugissement, iai...) respirent.
- **POSES : FLUIDE par défaut** (`CombatConfig.PoseRate = 60`) : les paliers 12/15/24 ne font
  qu'interpoler entre 3 poses clés, ce qui saccade sur ces corps ; le rythme anime vient des
  maintiens, smears et impacts. Le bouton POSES garde 12/15/24.
- **Orbe de DAICHA en nunchaku** (`OrbFlight`) : à l'armé elle tourne autour de sa main (un
  tour complet s'il a le temps, un demi sinon), fouette en arc jusqu'au point d'impact (la
  chaîne s'allonge), continue son élan vers le bas et revient en orbite ; jamais dans son corps
  ni sous le sol. Chaîne d'ombre (Beam) main-orbe pendant les attaques (client et planches).
- **Cinématiques et K.O.** : plus de montage stroboscopique (champs/contrechamps toutes les
  4-8 images → tous les deux coups ; le dernier coup reste dans le plan d'avant ; HIBECARES
  CHÂTIMENT en un seul plan avec un vrai mouvement continu : soulevée en arc, abattue de
  l'autre côté en accélérant, au lieu de téléporter la cible) ; **caméra vivante**
  (`Director.drift`) : chaque plan composé glisse lentement autour du sujet et avance un peu
  (6°/s, 5 %/s, 1,6 s au plus) ; poses tenues qui respirent.
- Mesures (`AnimQuality`, 8 persos × 3 scénarios) : tremblements 236 → 156, interpénétration
  moyenne 1,6 % → 0,6 % (pire cas 14,8 % → 10,4 %, sur 2 images d'impact), à-coups 839 → 786
  (ceux qui restent sont des démarrages de coups en 2-3 images, voulus). Plus aucun plan de
  moins de 5 images, au plus deux de moins de 9 par cinématique.
- Tests : Animation 33 (+4 : armé qui se tend, inertie qui traîne/dépasse/se pose et impact
  instantané, espacement sans saut, rythme de garde par perso ; + lame de SHIN au sol, orbe
  nunchaku), CinematicDirector 249 (+2 : montage sans stroboscope, caméra jamais figée),
  CombatSimulation 82, FighterAI 10, Kits 54, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅.
  Studio ❌ non exécuté. Combat inchangé (rien dans la simulation).

### Problèmes ouverts / prochaine étape

- Juger en jeu le rendu FLUIDE contre 15/s, et l'espacement à bout portant (les étincelles
  d'impact restent à la position serveur, jusqu'à 0,4 stud de la main dessinée).
- Prochaine étape possible : ajustement IK des contacts (le poing s'arrête à la surface de
  l'adversaire), poses retouchées une à une avec les GIF.

## Version 0.10.4 — 2 octobre 2026

Retour de Wilhem : « les R de KAI, TARO, ZEPHYR et AKEMI, change-les aussi ».

- `CinematicDirector` : les 4 ruées refaites, chacune avec sa structure et son effet à elle :
  - KAI · KAIEN RUSH : lancer, poursuite dans le ciel (téléportations autour de la cible,
    anneau de ki à chaque choc, filmée d'en dessous puis d'au-dessus), smash au sol, charge en
    lévitation et **rayon de ki** vers le bas (`kiBeam`) ;
  - TARO · RUSH DÉVASTATEUR : poussée dans le coin, **cordes de feu** (`ropes`), DEMPSEY ROLL
    (balancement gauche / droite, crochets alternés) filmé comme une retransmission avec les
    flashs, coups au corps, crochet de K.O. à travers les cordes ;
  - ZEPHYR · VENT TRANCHEUR : reste à distance, **lames de vent** (`windBlade`) à chaque coup
    de pied, vortex de lames qui soulève la cible, traversée d'un coup de pied volant ;
  - AKEMI · OMBRES MULTIPLES : frappe depuis un cercle autour de la cible en laissant **son
    ombre** (`afterimage`, copie sombre du corps) à chaque place ; rengainée en noir et blanc ;
    toutes les ombres frappent ensemble.
- Client (`EffectsController`) : `kiBeam`, `windBlade`, `ropes`, `shadowCopy` ;
  `CinematicController` les joue. Storyboard : les nouveaux effets, et l'ombre d'AKEMI dessinée
  comme un corps sombre.
- Test « chaque ruée a sa manière » étendu aux 8 persos (effet propre à chacun, KAI monte la
  cible à plus de 10 studs, ZEPHYR reste à plus de 3 studs jusqu'au coup final).
- **Nerf du E de DAICHA** (TÉLÉPORTATION, « on peut se TP à chaque clic ») : seulement si
  l'adversaire est à 9 studs ou moins (`teleportRange`), 2 s avant la suivante
  (`teleportCooldown`, règle de `CombatSimulation`), invulnérabilité 1-8 (au lieu de 1-12),
  dégâts 70 (au lieu de 76), récupération 32. Un coût en ki a été essayé : le CPU DAICHA
  tombait à 27 %, abandonné. Test Kits : trop loin ou dans les 2 s, pas de téléportation.
- Équilibrage (`Balance.luau -a 4 120`, niveau LÉGENDE, moyennes) : KAI 47 %, TARO 53 %,
  ZEPHYR 48 %, AKEMI 60 %, RYUKEN 57 %, SHIN 45 %, DAICHA 40 %, HIBECARES 51 % ✅.
- Tests : CombatSimulation 82, FighterAI 10, CinematicDirector 247, Animation 28, Kits 54,
  PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Studio ❌ non exécuté.

### Problèmes ouverts / prochaine étape

- Voir en jeu les 8 ruées ; ajuster tailles / durées des effets.

## Version 0.10.3 — 2 octobre 2026

Retours de Wilhem : « l'orbe doit vraiment voler autour de DAICHA, pas coller à sa main » ;
« toutes les cinématiques du R se ressemblent, pousse le travail » ; « je n'ai toujours pas
accès au hub multi » ; « les ultimes et les combos doivent vraiment être différents visuellement ».

- **Orbe de DAICHA qui vole** : `src/shared/OrbFlight.luau` (pur) calcule où est l'orbe à
  chaque instant à partir de la vue du combattant : orbite autour des épaules au repos (plus
  basse accroupi), devant lui en garde, rassemblée près de la main à l'armé, au bout de la
  portée du coup à l'impact (un sursaut par coup des rafales), tourbillon pour les coups
  tournoyants, retour en orbite pendant la récupération, en retrait quand il est touché ou
  qu'il dashe. Le client détache l'orbe de la main (pièces ancrées, traînée conservée) ;
  `WeaponKit`, `PoseSheet` et `Storyboard` la dessinent au même endroit.
- **Les ruées (R) refaites**, une structure par perso (`CinematicDirector`) :
  - RYUKEN · FUREUR DU POING : cible tenue par le col et pilonnée (caméra dans son visage, le
    cadre « cogne » à chaque coup), écrasée au sol (vue du dessus), uppercut au rebond,
    jonglée des deux côtés (vue du sol), smashée, puis la rage se concentre dans le poing
    (zoom) et part en **poing géant de ki** (nouvel effet `rageFist`) ;
  - SHIN · DANSE DES COURANTS : un seul plan vu d'en haut qui tourne lentement pendant qu'il
    dessine un **huit** autour de la cible (coupe à chaque quart, sillage d'eau au sol :
    `wake`), puis une **trombe d'eau** (`waterspout`) avale la cible, il saute par-dessus et
    la fend du ciel en diagonale ; ronds dans l'eau à la fin ;
  - DAICHA · DOMAINE OBSCUR : il ne touche jamais la cible ; son orbe se divise dans sa main,
    couronne la cible et plonge dedans orbe par orbe (`orbs`, `orbDart`), 8 orbes sur deux
    anneaux croisés vus du dessus, vortex qui la soulève (monde à l'envers), fusion en
    sphère noire qui s'abat ;
  - HIBECARES · COLOSSE ÉVEILLÉ : trois coups colossaux seulement ; chaque pas est un séisme
    (ligne de rochers `rockLine` jusqu'à la cible), le 1er coup l'envoie rouler, il la suit
    sans se presser (par-dessus son épaule), le 2e l'enfonce (cratère), les piétinements la
    font décoller de plus en plus haut, le 3e fait le cratère. Les rochers retombent après
    chaque séisme (paramètre `life` de `rocks`) pour ne jamais boucher le cadre.
- **Combos visuellement différents** (`EffectsController.kitSwing / kitHit`) : chaque coup
  laisse la marque de son perso (traînée de ki / feu / vent / ombre / chaleur, anneau de
  flammes, bourrasque, croix d'ombre, fissure de rage, coupe nette, explosion d'orbe, débris
  de pierre et secousse), en plus des arcs d'épée et d'orbe de la 0.10.2.
- **Hub** : bouton doré « HUB MULTI (H) » plus grand, touche **H**, panneau central qui s'ouvre
  tout seul à l'arrivée, avec l'état (seul / en combat / en attente), les joueurs, DÉFIER,
  INVITER, JOUER CONTRE LE CPU et une explication quand on est seul : l'ami doit être sur le
  **même serveur** (invitation Roblox, ou « Test > Clients et serveurs » à 2 dans Studio).
- Outils : `Storyboard` sort la durée de vie / la rotation des effets ; `tools/storyboard.py`
  dessine les nouveaux effets (poing géant, orbes, sillage, trombe, ligne de rochers).
- Tests : CinematicDirector 247 (+1 : chaque ruée a ses effets à elle et sa manière — DAICHA
  reste à plus de 4 studs, RYUKEN jongle à plus de 6 studs, le sol tremble sur au moins 8
  pas / coups de HIBECARES, personne ne traverse sa cible) ; CombatSimulation 82, FighterAI 10,
  Animation 28 (dont l'orbe qui vole : orbite au repos, hors du corps, au bout de la portée à
  l'impact, retour), Kits 53, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Planches des 4 ruées
  regardées avant / après. Studio ❌ non exécuté : les nouveaux effets (poing géant, orbes en
  vol, trombe, lignes de rochers) et le hub restent à voir en jeu. Équilibrage inchangé
  (aucune donnée de combat touchée).

### Problèmes ouverts / prochaine étape

- Voir en jeu les 4 ruées refaites et l'orbe qui vole ; ajuster tailles et durées des effets.
- Hub : à deux, les joueurs doivent être sur le même serveur (pas de matchmaking entre serveurs).
- Prochaine étape possible : le même travail de différenciation sur les éveils / portes si
  Wilhem les trouve encore trop proches.

## Version 0.10.2 — 2 octobre 2026

Retour de Wilhem (avec sa planche « attaques à l'épée / attaques à l'orbe ») : « t'as rien
compris, le clic gauche donne encore des coups de poing, il n'y a pas vraiment d'animation ».

- Cause réelle : le katana sort du poing perpendiculairement à l'avant-bras ; sans poignet
  orienté, bras tendu, **la lame pointait vers le ciel** à chaque impact : on voyait un jab
  tenant un bâton levé. Et le client ne dessinait d'arc que pour les coups lourds, aucune
  traînée sur la lame. Mesuré, pas deviné : nouvel outil `tests/WeaponKit.luau` qui place
  l'arme sur un corps posé, et `PoseSheet` / `Storyboard` dessinent maintenant l'arme.
- `src/shared/WeaponSpec.luau` (pur) : géométrie du katana et de l'orbe, utilisée par le
  RigBuilder et par les tests. Prise du katana inclinée de 20° vers l'avant : poignet à −70°,
  la lame prolonge le bras. Sur un corps R6 (sans poignet), prise alignée sur le bras.
- **SHIN** : tous ses coups réécrits en vraies coupes en trois temps — armé (lame en arrière),
  impact (lame dans le prolongement du bras, à travers la cible), accompagnement (la lame
  continue son arc, joué entre l'impact et le retour en garde) : TRANCHE 1 (plate, de droite à
  gauche), TRANCHE 2 (revers montant), ESTOC, COMBO LAME (grand croissant à deux mains),
  BRISE-GARDE (vertical à deux mains, lame au sol), FENDOIR, montante, percée, fil du courant,
  courant tranchant, PAS DU VENT et COUPE FINALE (iai depuis la hanche), cercles, coupes
  basses, coupes aériennes, piqué. Garde « seigan » (pointe vers les yeux), blocage lame
  dressée, garde basse lame en travers.
- **DAICHA** : frappe avec l'orbe (main gauche, poignet fléchi : l'orbe mène le poing) — jab
  d'orbe, balayage en pas oblique, poussée à deux mains, orbe levé puis abattu, coup lourd
  orbe au centre puis poussé, vortex bras ouverts ; garde : l'orbe tenu en bouclier.
- **Client** (`EffectsController`) : traînée (Trail) le long de la lame / derrière l'orbe,
  allumée de l'armé à l'accompagnement ; pour chaque coup d'épée un arc à sa forme (plat,
  diagonal, vertical, cercle complet) avec un liseré blanc, estocs en trait de lumière,
  coups lourds qui fendent le sol (fissure, étincelles, poussière) ; pour chaque coup d'orbe
  une explosion d'orbe, un faisceau pour le coup lourd et les finales, un vortex d'orbes en
  orbite pour les coups tournoyants ; gardes : arc de lumière devant la lame, anneaux
  d'ombre autour de l'orbe, qui flashent au coup bloqué.
- Tests : Animation 28 (+2 : les coupes de SHIN font voyager la pointe et ne dressent jamais
  la lame à l'impact ; DAICHA mène avec l'orbe — R15, avatar et R6) ; CombatSimulation 82,
  FighterAI 10, CinematicDirector 246, Kits 53, PressQueue 4, Fuzz 2, Cinematography 81,
  Lobby 5 ✅ ; `rigcheck` ✅. Planches armé / impact / suite de SHIN et DAICHA regardées.
  Studio ❌ non exécuté : les effets du client (traînées, arcs, faisceau, gardes) restent à
  voir en jeu. Équilibrage inchangé (aucune donnée de combat touchée).

## Version 0.10.1 — 2 octobre 2026

Retour de Wilhem : « corrige les animations à l'épée et celle à l'orbe d'ombre, pourquoi ils
mettent des coups de poing ? Crées-en de nouvelles, et si le problème est sur d'autres persos,
fais-le partout. »

- Cause : un coup sans pose propre prend celle de son rôle chez KAI. SHIN n'avait que 11 coups
  à lui (17 reprenaient les poings, pieds et ki de KAI), DAICHA 6 (22 repris), HIBECARES 7
  (22 repris, dont les coups de pied retournés et le salto) et AKEMI 4 (ses coups de main
  étaient des poings fermés).
- **74 nouveaux jeux de poses** (`PoseLibrary`, section « weapon kits ») bâtis sur des gabarits
  communs (coup debout, coup bas, coup aérien, saut, salto, tourbillon, rafale, coup final,
  plongeon, poursuite, ultime) où seuls les bras, la rotation des hanches et la fente changent :
  - SHIN : tous ses coups sont des coupes et estocs de la main droite (lame aérienne, piqué,
    percée, croissant en salto, tranche céleste, fil du courant à deux mains, tourbillon,
    fauche, tranche basse, coupe finale en iai) ; ultimes : iai puis la coupe.
  - DAICHA : griffes, paumes et gestes d'ombre, l'orbe dans la main gauche (combo, étreinte,
    ombre montante, distorsion bras ouverts, flèche d'ombre, demi-éclipse, voile, courant
    d'ombres, poussée à deux paumes, chute, griffe basse, piqué, retour au néant) ; ultimes :
    lévitation puis la poussée / la sphère.
  - HIBECARES : poings de pierre, piétinement et chaînes (coup de masse, coude de pierre,
    soulèvement, écrasement, revers de chaîne, balayage du bras, séisme poings au sol, pilier
    de pierre, avalanche, pluie de gravats, charge à l'épaule, effondrement du roi).
  - AKEMI : main-lame pour ses coups de main (paume, genou, percée, envol, estoc, mille
    entailles, triple croc, lames jumelles, tourbillon, lame aérienne, piqué, exécution) ; ses
    coups de pied (salto, talon, fauche, coup bas, genou volant, hache) restent des coups de
    pied.
  - TARO, RYUKEN (poings) et ZEPHYR (pieds) empruntaient à KAI des coups du même type :
    inchangés.
- Traînées (`STRIKE`) de chaque nouveau coup sur la bonne main / le bon pied.
- Tests : Animation 26 (+1 : SHIN, DAICHA, HIBECARES et les coups de main d'AKEMI n'empruntent
  jamais une pose de KAI ; toutes les nouvelles poses passent pieds au sol, limites des
  articulations, R15 et avatar) ; CombatSimulation 82, FighterAI 10, CinematicDirector 246,
  Kits 53, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Planches R6 / R15 de SHIN,
  DAICHA, AKEMI, HIBECARES regardées. Studio ❌ non exécuté. Équilibrage inchangé (aucune
  donnée de combat touchée).
- Problème ouvert : le storyboard dessine le rig en blocs sans le katana ni l'orbe ; en jeu ils
  sont portés à la main (`RigBuilder`), à confirmer à l'œil.

## Version 0.10.0 — 1er octobre 2026

Demandes de Wilhem : la planche des 4 nouveaux persos (« tiens les nouveaux perso » :
RYUKEN, SHIN, DAICHA, HIBECARES, leurs coups, spéciales et ultimes) ; « comment on dodge avec
TARO ? » (répondu, et aide du style ESQUIVE dans le jeu) ; « les bruitages, sois cohérent » ;
« chaque perso a sa propre tête et son propre corps, pas la base de KAI ; fais-le pour tout
le monde, review total ».

### Les 4 nouveaux persos (les 8 sont jouables : `MoveData.KitOrder`)

| Perso | Rôle | Vie | Passif | S + E |
|---|---|---|---|---|
| RYUKEN 拳 | force, pression | 1500 | **RAGE** : +2,5 % de dégâts par coup porté (max 10), perdue quand il est touché | FRAPPE SISMIQUE (onde basse) |
| SHIN 流 | sabre, allonge +22 % | 1400 | **PRÉCISION** : +20 % au bout de la lame | COURANT TRANCHANT |
| DAICHA 闇 | zoning | 1400 | **OMBRE INVERSÉE** : le dash vers l'adversaire (≤ 5 m) le traverse | SPHÈRE INVERSÉE (lente, énorme) |
| HIBECARES 崩 | endurance | 1800 | **ROI DES RUINES** : jusqu'à +30 % de dégâts à 30 % de vie | MUR DE PIERRE (encaisse à moitié, même les bas, et riposte) |

- Données et mécaniques (`MoveData`, `CombatSimulation`) : chaque kit associe les rôles de
  KAI à ses propres coups (noms de la planche) ; TÉLÉPORTATION de DAICHA (réapparaît derrière),
  CHARGE FRONTALE de RYUKEN, PAS DU VENT de SHIN ; `passiveBonus`, `crossed` (passer de
  l'autre côté remet la poussée à zéro), parade `absorb` / `lows` du MUR DE PIERRE.
- Corps en blocs : **chaque perso a sa propre tête et son propre corps** (`RigBuilder.BODIES`)
  au lieu de la base de KAI : ZEPHYR, AKEMI, RYUKEN, SHIN, DAICHA, HIBECARES (TARO l'avait
  déjà). Tenues sur avatar : gantelet fissuré qui luit (RYUKEN), katana et fourreau (SHIN),
  sphère d'ombre et obi (DAICHA), poings de pierre et chaînes (HIBECARES). Deux styles de
  couleurs chacun.
- Poses R15 / R6 de chaque garde et de chaque coup (coupes de sabre, gestes d'ombre, coups
  lourds, MUR DE PIERRE…) ; 4 poses de mise en scène : `Roar`, `Iai`, `Levitate`, `Colossus`.
  La garde de DAICHA tend la sphère plus bas (en R6, le bras pointait vers le haut).
- **12 ultimes et 4 scènes de K.O.**, chacun avec son langage de caméra et son étalonnage
  (nouveaux : `rage`, `current`, `inverse`, `ruin`) — composés avec `frameOn`, vérifiés au
  storyboard :
  - RYUKEN : zooms brutaux, gros plans sur les poings, un impact à chaque coup —
    FUREUR DU POING, EFFONDREMENT (cratère vu du ciel), 拳 DERNIER ROUND ; K.O. : poings qui
    fument, rugissement, dos tourné.
  - SHIN : longues focales, travellings latéraux, l'iai qui fige le temps, une seule ligne de
    lame — DANSE DES COURANTS, TEMPÊTE CONTINUE, 零 ZÉRO HORIZON (une ligne d'un bout à
    l'autre de l'horizon) ; K.O. : la lame rengainée, le clic qui ride le sol.
  - DAICHA : angles penchés, plans en miroir, caméra à l'envers, soleil noir — DOMAINE
    OBSCUR, RIVIÈRE D'OMBRES, 蝕 ÉCLIPSE TOTALE ; K.O. : l'ombre avale le corps.
  - HIBECARES : contre-plongées monumentales, piliers de pierre, débris, secousses (`quake`)
    — COLOSSE ÉVEILLÉ, CHÂTIMENT (soulevé et écrasé de chaque côté), 崩 RUINES DU MONDE ;
    K.O. : décombres et poussière.
  - Client : effets `rocks`, `debris`, `crack`, `cut`, `eclipse`, `smoke` ; storyboard : les
    nouveaux étalonnages et effets, piliers triés en profondeur avec les corps.
- HUD : jauge de chaque passif (RAGE ×N, OMBRE INVERSÉE prête / recharge, bonus du ROI DES
  RUINES selon la vie, règle de PRÉCISION) via `Sim.passiveGauge` (champ `passive` du
  snapshot) ; annonces « BOUT DE LAME ! », « MUR DE PIERRE ! −N », « OMBRE INVERSÉE ! » ;
  liste des COMBOS avec chaque passif. Effets : ombre et flaque à la téléportation (elle
  n'avait aucun effet), trait net au bout de la lame, débris sur le mur, corps de RYUKEN qui
  chauffe avec la RAGE.
- IA : DAICHA traverse l'adversaire à mi-distance ; HIBECARES lève son mur contre un
  adversaire accroupi (un bas trop rapide pour être vu) et contre les bas qu'il voit venir.

### Bruitages cohérents

- Constat : le manifeste du client Roblox (dépôt public Roblox-Client-Tracker,
  `rbxManifest.txt`) ne contient que **11 sons** ; `swordslash.wav`, `swordlunge.wav`,
  `unsheath.wav` et `electronicpingshort.wav` n'y sont plus. Les sons d'épée (coups lourds,
  élans), de garde, de parade, de super et le « ping » des QTE ne jouaient donc rien : seuls
  les pas, sauts et chutes s'entendaient. De plus, un bruit d'épée servait aux poings et un
  bruit de dégainage à la garde.
- Nouvelle palette (`src/shared/SoundPalette.luau`, pur et testé) : uniquement ces 11 fichiers,
  retravaillés (hauteur, durée coupée en fondu, bus de distorsion / écho / réverbération /
  égaliseur). Un son par action, le même pour tous ; une **matière par perso** (poings de ki,
  gants de cuir, pieds qui fendent le vent, main-lame de l'ombre, poings qui écrasent, lame
  d'eau, ombre en écho, pierre) ; un coup lourd = la version lourde de la même matière ;
  projectile propre à chaque perso ; pas plus lents pour HIBECARES. Aucun ID d'asset.

### Tests

- CombatSimulation 82, FighterAI 10 (+1 : DAICHA traverse, HIBECARES lève le mur),
  CinematicDirector 246 (8 kits, signatures d'étalonnage), Animation 25 (listes étendues aux
  8 kits), Kits 53 (+2 : jauge des passifs ; palette de sons : seulement les sons du client,
  une matière par kit, un son par action), PressQueue 4, Fuzz 2 (tous les duels des 8 kits),
  Cinematography 81 (cadrage de chaque ultime et K.O. avec le vrai rig), Lobby 5 ✅ ;
  `rigcheck` ✅. Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`, LÉGENDE, 120 matchs par duel) : KAI 48 %,
  TARO 53 %, ZEPHYR 48 %, AKEMI 58 %, RYUKEN 56 %, SHIN 45 %, DAICHA 42 %, HIBECARES 51 %
  (aucun sous 35 % ni au-dessus de 65 %). Duels les plus déséquilibrés : DAICHA contre TARO
  35 %, contre KAI 37 %.

### Problèmes ouverts / prochaine étape

- Les sons sont tous des sons du client retravaillés : à écouter en jeu (le vent coupé court
  sert de « whoosh » ; si un son est trop faible, ajuster `SoundPalette`). De vrais SFX de
  Wilhem pourront remplacer les fichiers sans toucher au reste.
- DAICHA est le plus faible des 8 (42 %) : à surveiller en vrai match.
- Avatar : toujours à confirmer en jeu (ligne d'état et Output donnent la raison).
- Prochaine étape : retours de Wilhem sur les 4 nouveaux en jeu (looks, cinématiques, sons).

## Version 0.9.8 — 1er octobre 2026

Retours de Wilhem : « toujours pas possible de jouer avec mon avatar » ; « et le lobby
multi » ; « pour le boxeur, un switch de mode : boxeur qui esquive (contres, Dempsey Roll) et
boxeur classique, sur les touches & et é, seulement TARO » ; « revois les animations des
cinématiques, optimise au max le ping avec deux joueurs de deux régions différentes » ; puis
une planche de 4 nouveaux persos (RYUKEN, SHIN, DAICHA, HIBECARES) — prochaine étape.

### Avatar

- Cause probable : la **mise à niveau des articulations d'avatar** de Roblox, qui remplace
  les Motor6D des corps R15 par des AnimationConstraint. Le serveur refusait alors le corps
  (« articulation Root absente » → modèle en blocs) ou le client attendait des Motor6D qui
  n'arrivaient jamais (corps figé).
- `RigReader.ensureJoints` (partagé) : chaque Motor6D attendu qui manque est reconstruit
  entre les deux mêmes pièces, depuis leurs points d'attache (comme
  `Humanoid:BuildRigFromAttachments`), sinon depuis les repères R6 standard ou les pivots du
  rig KAI mis à l'échelle ; les contraintes remplacées sont retirées. Appelé par le serveur à
  la création du corps et une fois placé ; par le client en secours si un corps n'a toujours
  pas ses Motor6D au bout de 2 s.
- Les erreurs de construction (pcall) sont affichées sur la ligne d'état au lieu d'un
  « chargement… » sans fin ; la ligne d'état garde la raison même en modèle en blocs.
- `tools/rigcheck.py` construit aussi `RigReader` et vérifie : R15 en AnimationConstraint avec
  et sans points d'attache, R15 déjà en Motor6D, R6 sans articulations — 15 / 6 Motor6D
  reconstruits sans déplacer aucune pièce, rien deux fois.

### TARO : deux styles (touches & / 1 et é / 2, ou les boutons du HUD)

| | BOXEUR CLASSIQUE (& / 1) | BOXEUR ESQUIVE (é / 2) |
|---|---|---|
| Garde | **de fer** (−40 % d'usure) | normale |
| Dégâts | +8 % | −5 % |
| Vitesse | marche 15, dash 34 | marche 17, dash 40 |
| ↓ + E | **DROITE DU CHAMPION** (lente, écrase la garde, met au sol) | **PARADE** qui contre |
| Dash vers l'adversaire | dash normal | **esquive de buste**, puis **DEMPSEY ROLL** |
| Pose | garde orthodoxe droite, bras avant tendu | peek-a-boo baissé |

- Changement au neutre (pas pendant un coup), au sol, 0,5 s entre deux ; le style reste d'une
  manche à l'autre ; TARO commence en CLASSIQUE. Événement `Stance` (annonce + son).
- Données : `kit.Stances` (stats, spéciale accroupie, esquive) ; simulation : `stanceOf`,
  `startersOf`, `weaveOf`, multiplicateur `DamageDealt` ; IA : change de style de temps en
  temps, n'utilise le Dempsey qu'en ESQUIVE ; poses `Kits.TARO_CLASSIQUE` (l'Animator prend
  la variante du style d'abord) et `TaroChampion`.

### Lobby multi

- Le client demande le statut du hub à son démarrage (`hello`) ; annonce « X a rejoint le
  serveur · HUB pour le défier » / « X a quitté le serveur » ; la liste s'ouvre seule quand un
  adversaire possible arrive.

### Réseau : deux joueurs de régions différentes

- **Ping** de chaque joueur mesuré par le serveur (`Player:GetNetworkPing`, chaque seconde),
  affiché sur la ligne d'état (« PING VOUS 40 ms / ADV. 180 ms »).
- **Compensation de latence** dans la simulation (`latencyTicks`, plafond
  `MaxLatencyTicks` = 12 ticks = 200 ms aller) : la fenêtre d'enchaînement après un coup
  s'allonge de la latence du joueur (ses combos ne cassent plus à cause du ping) ; un QTE de
  cinématique est jugé au tick que le joueur **voyait** quand il a appuyé (`cinTick` envoyé
  par le client, accepté dans la limite de son aller-retour), et n'est déclaré raté qu'après
  ce délai. Le serveur reste seul juge.
- **Prédiction visuelle** de son propre perso : la marche suit tout de suite la direction
  tenue et est dessinée en avance de la latence ; le serveur corrige par le lissage.
- **Cinématiques** : horloge locale lisse et monotone (au rythme du ralenti, recalée en
  douceur sur le serveur) : un paquet en retard ne fait plus sauter les plans en arrière.
- **Paquets plus légers** : noms, styles, kits et vie max ne partent que quand ils changent
  (ou toutes les 2 s), au lieu de 30 fois par seconde ; `InputTimeout` 0,8 s (un pic de lag
  ne lâche plus la garde).

### Tests

- CombatSimulation 82 (+2 : enchaînement tardif d'un joueur lointain, plafond ; QTE jugé au
  tick vu, refus d'un tick trop ancien) ; Kits 31 (+2 : changement de style, règles du style
  CLASSIQUE) ; Animation 25 (+1 : les deux gardes diffèrent et restent au sol, R15 et R6) ;
  Fuzz : appuis de style aléatoires. FighterAI 9, CinematicDirector 126, PressQueue 4,
  Cinematography 41, Lobby 5 ✅ ; `rigcheck` ✅. Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 42 %, TARO 53 %, ZEPHYR 46 %,
  AKEMI 59 % ; niveau 3 : 51 / 57 / 52 / 40.

### Problèmes ouverts / prochaine étape

- Avatar : à confirmer en jeu ; si ça échoue encore, la ligne d'état et la fenêtre Output
  (« [FightingGame] … ») donnent la raison exacte.
- Garde « au réflexe » toujours plus dure pour le joueur lointain (le serveur est l'arbitre).
- Prochaine étape : les 4 nouveaux persos de la planche (RYUKEN, SHIN, DAICHA, HIBECARES).

## Version 0.9.7 — 1er octobre 2026

Demandes de Wilhem : « le chara design de TARO ressemble trop à celui de KAI » ; « rajoute
des mécaniques de boxeur comme le Dempsey Roll » ; « gère aussi ces animations sur mon avatar
R15 » ; « lance un hub pour que je puisse jouer en 1v1 avec un pote ».

### TARO a son propre look

- Avant : le modèle en blocs de TARO était celui de KAI (cheveux en pics, veste ouverte à
  col, pantalon large, baskets) avec des gants, et sa palette BRASIER était noir / rouge
  comme KAI. Maintenant (`RigBuilder.taroHead` / `taroBody`) : cheveux courts en **mèche
  relevée**, nez scotché, cicatrice au sourcil, protège-dents ; **torse nu** musclé (pecs,
  abdos, trapèzes) avec une **serviette autour du cou** et **火 tatoué dans le dos** ; avant-bras
  bandés, **short de boxe** à bande latérale, **bottines de boxe lacées**. Palettes : BRASIER
  = gants orange, short or, bottines noires, peau mate ; CHAMPION = blanc et or.
- Sur avatar R15 / R6 : en plus des gants, du short et de la ceinture, la serviette au cou.
- **Nouvel outil `tools/rigcheck.py`** (+ `tools/RobloxMock.luau`, une imitation des API
  Roblox utilisées par RigBuilder) : construit chaque perso et chaque style hors Studio
  (modèle en blocs, tenue sur un corps R6 et sur un corps R15), vérifie que chaque pièce est
  attachée, de taille correcte et près du corps (`check`), et dessine une planche de design
  face / dos (`render`). `tools/storyboard.py` accepte maintenant la couleur propre de
  chaque pièce.

### Mécaniques de boxeur (TARO)

- **Esquive de buste** : le dash *vers l'adversaire* de TARO (`kit.Weave`) le fait plonger
  sous la garde ; pendant le dash, les coups qui ne sont pas bas passent au-dessus
  (événement `Slip`, « ESQUIVE ! », +12 de ki la première fois par coup, `SlipMeter`). Les
  coups bas, les projectiles et les ultimes touchent. Le dash arrière n'esquive pas.
- **DEMPSEY ROLL** : pendant l'esquive ou dans les 10 ticks qui suivent, **L** lance
  `TaroDempseyL`, puis L enchaîne `TaroDempseyR`, `TaroDempseyL`… (crochets en huit qui
  avancent, esquive des coups hauts sur leurs 5 premières images, 6 crochets au plus) ;
  **R** : `TaroDempseyFinish` (crochet final, envoie au mur). R directement depuis l'esquive
  = crochet final seul. L sans esquive reste le jab.
- L'ancienne compétence de combo `TaroDempsey` s'appelle maintenant **RAFALE EN HUIT** (route
  « HUIT ») pour ne pas confondre.
- CPU : TARO utilise l'esquive + Dempsey (approche et combos), à tous les niveaux.
- Animations : pose d'esquive propre à TARO (le buste roule en huit pendant le dash, champ
  `weave` du snapshot), poses des deux crochets et du crochet final, traînées des poings.
  Testées en **R15** (rig KAI et avatar aux proportions différentes) et en **R6** (retarget).
- Client : arc blanc au-dessus de la tête au slip, annonce « ESQUIVE ! », son ; la liste des
  COMBOS de TARO explique l'esquive et le Dempsey.

### HUB : 1 contre 1 entre amis

- `src/server/Lobby.luau` (pur, testé) : le premier arrivé combat le CPU, les suivants
  attendent au hub et regardent ; **DÉFIER** (30 s), **ACCEPTER** (le défiant en place 1,
  le défié en 2, les autres retournent au hub), **REFUSER**, **QUITTER LE COMBAT**, **JOUER**
  (si personne ne combat) ; quand un combattant part, le premier joueur du hub prend la place.
- Serveur : le lobby décide qui occupe les places (`sync`), remplace l'ancienne attribution
  automatique (où le 2e joueur entrait d'office en versus). Télécommande `Hub` (actions
  validées, anti-spam 0,4 s), statut envoyé à tous à chaque changement, défis expirés.
- Client `HubController` : bouton **HUB** (en haut à droite), liste des joueurs avec leur
  état, boutons DÉFIER / ACCEPTER, bandeau « X TE DÉFIE » avec compte à rebours,
  **INVITER UN AMI** (invitation Roblox `SocialService:PromptGameInvite`, dans un pcall).
- Pour jouer en ligne, la place doit être **publiée** (Studio : Publier sur Roblox, jeu
  public ou réservé aux amis) — voir le README.

### Tests

- Nouveau `tests/Lobby.test.luau` (5) ; Kits 29 (+3 : esquive de buste et slip, Dempsey Roll
  complet / limite / R seul / jab inchangé, esquive au départ des crochets) ; Animation 24
  (+1 : esquive et Dempsey en R15 et R6, au sol, poing vers l'avant, buste qui roule).
- CombatSimulation 80, FighterAI 9, CinematicDirector 126, PressQueue 4, Fuzz 2,
  Cinematography 41 ✅ ; `python3 tools/rigcheck.py check` : tous les corps construits.
  Studio ❌ non exécuté (le hub et l'invitation ne peuvent se vérifier qu'en jeu).
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 45 %, TARO 52 %, ZEPHYR 44 %,
  AKEMI 58 % ; niveau 3 : 52 / 60 / 49 / 40.

### Problèmes ouverts / prochaine étape

- À vérifier en jeu : le hub à deux joueurs (Test > Clients et serveurs), l'invitation (ne
  marche que sur une place publiée), la lisibilité du nouveau TARO en jeu.
- Plusieurs combats en parallèle sur un même serveur (une seule arène aujourd'hui) et un
  mode classé : à faire si besoin.

## Version 0.9.6 — 1er octobre 2026

Retour de Wilhem : « en R6 tu peux faire mieux, vraiment beaucoup mieux ». Nouvel outil pour
le voir au lieu de le deviner : **planche de poses R6 / R15** (`tests/PoseSheet.luau`), même
moteur que le jeu, corps R6 à gauche et rig R15 à droite, vue de la caméra du jeu.

### Ce que la planche montrait, et les corrections (`Retarget.luau`)

- **Jambes en compas** : un R6 n'a pas de genoux ; le bassin descendait à la hauteur du R15
  (genoux pliés), donc les jambes rigides s'ouvraient en grand V (jusqu'à ~60°). Désormais,
  en garde debout, les jambes gardent `LEG_KEEP` (75 %) de l'écart vers la jambe tendue :
  garde à ~25-35° au lieu de 45-60°. La hauteur est jugée sur tout le corps (la jambe d'appui
  la plus haute) : l'accroupi, le balayage et les coups bas restent aussi bas qu'avant.
- **Bras « zombie » en garde** : les bras rigides suivaient l'avant-bras R15, soit tendus à
  l'horizontale, soit levés vers le visage, et le bras arrière partait sur le côté vers la
  caméra. Nouvelle **garde R6** : bras vers l'adversaire (avant du buste, légèrement rentrés
  vers l'axe), inclinés de `ARM_GUARD_PITCH` (38°) sous l'horizontale ; ils se tendent vers
  le poing à mesure que le bras R15 s'allonge (coup = ~95 % d'allonge, garde = 45-75 %). Un
  poing levé au-dessus de la tête (marteau, victoire) garde sa ligne.
- **Buste** : le torse rigide suit la poitrine à 70 % (`CHEST_SHARE`, avant 50 %) : la
  rotation des coups se voit davantage.
- Contrôlé : les coups de pied et de poing R6 partent bien dans la même direction que le R15
  (mesures sur la planche).

### Tests

- Animation 23 (+1 : pour les 4 kits, en garde et en blocage, chaque bras R6 pointe vers
  l'avant et vers le bas, chaque jambe reste à moins de ~37° de la verticale ; le LowKick R6
  reste plus bas que la garde). Vérifié : ce test échoue avec l'ancien réglage.
- CombatSimulation 80, FighterAI 9, CinematicDirector 126, Kits 26, PressQueue 4, Fuzz 2,
  Cinematography 41 ✅. Studio ❌ non exécuté. Équilibrage inchangé (aucune donnée de combat
  touchée).
- Planche : `luau tests/PoseSheet.luau -a KIT [angle] > sheet.txt` puis
  `python3 tools/storyboard.py sheet.txt sheet.png`.

### Problèmes ouverts / prochaine étape

- À juger en jeu sur de vrais avatars R6 (proportions et accessoires variés).
- Les blocs R6 étant massifs, en vue 3/4 le bras côté caméra masque parfois le buste.
- Prochaine étape : le jeu en ligne et le lobby.

## Version 0.9.5 — 1er octobre 2026

Retours de Wilhem : « en fin de combo l'adversaire finit en l'air, donc les ultimes ne sont
pas dans le bon axe » ; « ralentis le jeu pour les cinématiques, qu'on ressente les coups » ;
puis « refais les scènes de K.O. sur tous les persos, chacun la sienne avec son thème ».

### Ultimes : même ligne, au sol

- `CombatSimulation.startCinematic` : au départ de chaque ultime, la cible (même en l'air,
  jonglée ou à terre) est posée au sol, l'attaquant est placé à `CinematicGap` (2,6 studs)
  devant elle, sur la même ligne, les deux face à face et dans l'arène (contre un mur, c'est
  l'attaquant qui se recale). Vitesses, dash, rebonds et chute en cours sont annulés.
- Client : à l'ouverture d'une cinématique, les positions affichées sautent directement à
  leur place (pas de glissade visible).

### Ralenti des cinématiques

- `CombatConfig` : `CinematicTimeScale` 0,6 (la cinématique avance à 60 % du temps réel),
  `CinematicImpactScale` 0,3 autour du coup final (de 4 ticks avant à 16 après,
  `CinematicImpactTicks`).
- `stepCinematic` avance sur une horloge : les frappes, le coup final et la chute qui suit
  tombent au ralenti ; les QTE sont lus à chaque tick réel (fenêtres un peu plus larges en
  temps réel). Dégâts et ordre des coups inchangés : l'équilibrage ne bouge pas.
- Le snapshot envoie `cinematic.scale` ; `CinematicController` extrapole le tick avec.

### Scènes de K.O. par perso (match gagné ou FINAL FINISH)

| Perso | Déroulé | Étalonnage |
|---|---|---|
| KAI 開 | inchangé : storyboard de Wilhem (main au sol, pieds, visage, dos au couchant) | — |
| TARO 火 | chute N&B au bord du ring, gants frappés au-dessus du corps (étincelles), **le compte de 1 à 8** en plan retransmission, poing levé dans un pilier de feu vu du sol, plan large du champion | feu, caméra portée |
| ZEPHYR 風 | chute vue du ciel, rafale au ras du sol (lames, lignes de vitesse), ZEPHYR **descend du ciel** et atterrit (onde), orbite lente dans l'anneau de vent, la caméra monte vers le ciel | ciel |
| AKEMI 影 | plans fixes : chute, **scène vide**, elle apparaît derrière le corps, rengaine sa lame… et la coupure tombe **après**, elle tourne le dos, disparaît : il ne reste que le corps et son sceau 影 | ombre |

La scène suit le kit du **gagnant** (`view.kit`). Plans réglés au storyboard.

### Tests

- CombatSimulation 80 (+2 : ultime sur cible jonglée contre chaque mur → même ligne au sol,
  écart 2,6, dans l'arène, face à face ; ralenti → plus de ticks réels que la cinématique,
  coup final plus lent que le reste, dégâts identiques). Budgets de ticks des anciens tests
  de cinématique agrandis.
- CinematicDirector 126 (+1 : chaque kit a sa scène de K.O. — plans propres, étalonnage,
  K.O. final, au moins 5 plans ; le test de placement couvre les 4 kits, deux gagnants,
  centre et murs).
- Cinematography : les plans de K.O. de TARO / ZEPHYR / AKEMI sont contrôlés comme des plans
  normaux (seuls les gros plans du storyboard de KAI restent exemptés).
- Kits : le test d'équilibrage joue 60 matchs par duel au lieu de 30 (à 30, AKEMI tombait à
  34 % par simple bruit ; à 120 matchs elle est à 40 %).
- FighterAI 9, Animation 22, Kits 26, PressQueue 4, Fuzz 2, Cinematography 41 ✅.
  Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 42 %, TARO 53 %, ZEPHYR 45 %,
  AKEMI 60 % (niveau 3 : 53 / 57 / 50 / 40).

### Problèmes ouverts / prochaine étape

- À juger en jeu : vitesse du ralenti (0,6 / 0,3), lisibilité du compte de TARO.
- Prochaine étape : R6 (« tu peux faire beaucoup mieux »), puis le jeu en ligne et le lobby.

## Version 0.9.4 — 1er octobre 2026

Retour de Wilhem : « toutes les animations cinématiques se ressemblent, chaque perso doit
être différent à 100 % ». C'était vrai : TARO, ZEPHYR et AKEMI partageaient la même ossature
(ouverture « prêt + ruée », fin « élan, impact, suivi », sceau + plan héroïque des portes,
intro « yeux, héros, ruée » et conclusion des éveils, même jeu d'angles). Tout est refait.

### Une identité de mise en scène par perso

| Perso | Caméra | Étalonnage | Signature |
|---|---|---|---|
| KAI 開 | coupes franches, orbites | rouge / sang (crimson, void) | ruée en téléportations, éveil vu des yeux, torii |
| TARO 火 | plans bas, **caméra portée** (balancement constant), champ / contrechamp façon retransmission de boxe | **feu** (orange chaud) | il **marche** sur la cible et la repousse : jamais de ruée ni de téléportation ; pose GloveTap (gants frappés), victoire en champion |
| ZEPHYR 風 | grands mouvements continus (grue, orbite), objectifs larges, peu de coupes | **ciel** (froid, lumineux) | tout est **aérien** : bond depuis le lointain, montée dans le vent, vortex vu de très loin puis de l'intérieur ; pose WindGather ; fin de dos face au ciel |
| AKEMI 影 | **plans fixes**, coupes sèches, souvent **sans elle à l'image** | **ombre** (violet sombre) + noir et blanc | elle disparaît, la cible la cherche du regard ; frappes de nulle part ; temps arrêté, tableaux fixes ; pose Sheathe (lame rengainée) |

Les 9 ultimes de TARO, ZEPHYR et AKEMI ont chacun leur propre déroulé (début, milieu, fin) ;
le timing autoritaire (frappes, QTE, coup final) est inchangé, donc l'équilibrage aussi.

- `CinematicDirector` : nouvelles stagings complètes (l'éveil de ces kits n'utilise plus
  l'intro ni la conclusion de KAI) ; nouveaux champs de frame `grade.fire / sky / shadow` et
  `handheld`.
- `PoseLibrary` : poses GloveTap, WindGather, Sheathe ; `Animator` : une pose mise en scène
  prend d'abord la version du kit (victoire, garde…).
- `CinematicController` : étalonnages feu / ciel / ombre, caméra portée.
- Test : « every character's cinematics are its own » (aucun plan partagé entre deux kits ni
  entre deux ultimes, au moins 5 plans par ultime, chaque kit garde son étalonnage et
  n'utilise jamais celui d'un autre). Les storyboards ont servi à régler chaque plan.

### Tests

CombatSimulation 78, FighterAI 9, CinematicDirector 125, Animation 22, Kits 26, PressQueue 4,
Fuzz 2, Cinematography 41 ✅. Studio ❌ non exécuté.

### Problèmes ouverts

- À juger en jeu : force de la caméra portée de TARO, teintes des trois étalonnages, AKEMI
  « hors champ » (placée au-dessus de la scène pendant ses disparitions).
- Audit Codex : points 3 et suivants toujours non reçus.

## Version 0.9.3 — 1er octobre 2026

Mission de Wilhem : corriger un maximum de bugs, améliorer les animations et **vraiment
améliorer les cinématiques** (« prends le temps qu'il faut, make it cool »). Ensuite : le
jeu en ligne et le lobby. Toujours **rien de lancé dans Studio**.

### Chasse aux bugs

- **Nouveau `tests/Fuzz.test.luau`** : des joueurs aléatoires (appuis en rafale, garde,
  sauts, dashs, ultimes, deux boutons à la fois) sur les 16 duels de kits, en versus et en
  entraînement, plus le CPU contre un joueur aléatoire. À chaque tick : pas de NaN, vie / ki /
  garde dans leurs bornes, personne sous le sol ni hors de l'arène, file d'appuis bornée,
  aucun état bloqué, chaque cinématique se termine. ✅ (aucun bug de simulation trouvé ;
  une « attaque bloquée » signalée était une vraie chaîne de coups, le critère a été affiné.)
- **Nouveau `tests/Cinematography.test.luau`** (41 cas) : chaque ultime des 4 persos (et ses
  versions K.O., au centre et contre le mur) est joué avec la vraie simulation, le vrai
  réalisateur et le **vrai moteur d'animation** (corps posés membre par membre) ; à chaque
  image : caméra hors des corps, sujet à l'écran et lisible.
- Bugs trouvés et corrigés :
  - **caméra dans les corps** sur une grande partie des plans (« windup », poing, gros plan
    des yeux, charge du dragon, plans serrés de l'éveil…) : jusqu'à 20 fois la hauteur de
    l'écran, la caméra à 0,66 stud d'un bras ;
  - **plan « ko-feet » de la scène K.O.** : la caméra était dans le corps du perdant ;
  - corps qui se chevauchaient pendant les tourbillons (TARO, ZEPHYR, AKEMI) ;
  - cible des ruées de kit épinglée au centre après le coup final.

### Cinématiques refaites

- `CinematicDirector` : les plans ne sont plus posés à la main (« tête + décalage ») mais
  **composés** par `frameOn` : angle autour des sujets (relatif au sens de l'attaque),
  plongée / contre-plongée, part de l'écran à remplir, tranche du corps (plein pied, buste),
  distance minimale aux corps. Chaque ultime a été repris plan par plan et vérifié en
  storyboard :
  - ouverture (pose de prêt, plan héroïque en contre-plongée, ruée suivie de côté) ;
  - rafales en **coupes franches** sur un jeu d'angles forts (trois-quarts, moyen,
    plongée verticale, contre-plongée inclinée, large derrière l'attaquant) ;
  - élan en contre-plongée derrière l'attaquant avec **poussée lente** vers les deux ;
  - impact incliné, puis plan large qui suit la cible projetée ;
  - TEMPS SUSPENDU : AKEMI face caméra, la cible figée derrière, les coupures en croix
    au retour du temps.
- Nouveaux procédés côté client : **lignes de vitesse** anime pendant les ruées et les
  rafales, et **impact** (image d'impact contrastée + coup de zoom de la caméra + secousse)
  sur les grosses frappes, une fois par coup.
- Outil **storyboard** : `tests/Storyboard.luau` + `tools/storyboard.py` dessinent la planche
  de ce que voit la caméra (Python 3 + Pillow, pour vérifier une cinématique hors Studio).

### Animations

Revue des poses de KAI (R15) état par état et coup par coup, de face et de profil : pas de
défaut trouvé (les coups de pied paraissaient pliés en vue 3/4, ils sont bien tendus de
profil). Le R6 a été retravaillé en 0.9.1.

### Tests

CombatSimulation 78, FighterAI 9, CinematicDirector 125, Animation 22, Kits 26, PressQueue 4,
**Fuzz 2**, **Cinematography 41** ✅. Compilation et analyse statique ✅. Studio ❌.

### Problèmes ouverts

- Storyboards hors ligne : corps en blocs, effets simplifiés ; le rendu réel (avatars,
  particules, étalonnage) reste à juger en jeu avec le LABO CINÉ.
- Audit Codex : points 3 et suivants toujours non reçus.

### Prochaine étape : en ligne et lobby

À préparer avec Wilhem (proposition dans la réponse) : lieu de rassemblement, file de
matchmaking, arènes de match en serveurs réservés (TeleportService), retour au lobby.

## Version 0.9.2 — 1er octobre 2026

Wilhem a fourni une **planche d'ultimes** (boxeur, combattant au pied, esquiveur) et un
**audit Codex** de la 0.9.0 (commit `8bea7a3`). Le message de l'audit est **coupé après le
point 2** : les points suivants restent à recevoir. Chaque point reçu a été vérifié dans le
code avant correction. Rien lancé dans Studio.

### Audit, point 1 — un 開天 parfait pouvait tuer sans assez de dégâts ✅ corrigé

Confirmé (`judgePrompts`) : au QTE (tick 140), les deux premières frappes (118, 126) sont
déjà dans les PV, mais la décision de K.O. additionnait tout le plan. Avec 800 PV et 775 de
dégâts : K.O. au lieu de 25 PV. La décision compare maintenant les PV restants aux seules
frappes encore à venir. Test : « gate: a perfect gate only KOs if the blows left can
finish » (les 4 kits ; 25 PV exacts restants, K.O. si les dégâts suffisent).

### Audit, point 2 — appuis perdus ou réordonnés ✅ corrigé

Confirmé : le serveur fusionnait les appuis avec `or` (2 clics entre deux ticks = 1) et la
simulation les lisait dans un ordre fixe (lourd puis léger devenait léger d'abord) ; le
client fusionnait aussi entre deux paquets. Nouveau module pur `src/shared/PressQueue.luau` :
le client envoie la liste ordonnée des appuis d'attaque (`presses`), le serveur la valide
(tableau de 8 noms connus au plus), la met en file (6 au plus) et donne **un appui par tick**
à la simulation. Nouveau `tests/PressQueue.test.luau` (4 tests, dont « lourd puis léger dans
un seul paquet joue R puis L »). Plusieurs boutons à la même frame arrivent maintenant à un
tick d'écart : ils restent marqués (« TROP TÔT » / « SPAM ») par la règle du rythme.

### Ultimes selon la planche

| Perso | 1 · R seul | 2 · route + clic droit | 3 · route + R |
|---|---|---|---|
| TARO | RUSH DÉVASTATEUR : charge, coups de face, droite finale | UPPERCUT CÉLESTE : coups au corps, uppercut dans un pilier de feu, finition aérienne | 火嵐 TEMPÊTE DE CROCHETS : tourne autour de la cible, crochet après crochet, anneaux de feu |
| ZEPHYR | VENT TRANCHEUR : un coup de pied toutes les 4 frames, lame de vent sur chacun | DRAGON ASCENDANT : pied montant, montée dans un dragon de vent, coups des deux côtés, vrille puis piqué | 旋風 CYCLONE FURIEUX : vortex qui soulève la cible, rotation de coups de pied |
| AKEMI | OMBRES MULTIPLES : des copies frappent de tous les côtés | TEMPS SUSPENDU : temps arrêté (noir et blanc), esquive, coups au ralenti, coupures en croix | 幻舞 DANSE FANTÔME : esquives et réapparitions, frappes instantanées |

- Mise en scène pure dans `CinematicDirector` (`Director.KIT_ULTIMATES`) ; timing
  autoritaire inchangé (frappes, QTE à 140, coup final) : équilibrage identique. KAI garde
  ses 3 ultimes.
- Nouvel effet client `arc` (lames de vent, crochets, coupures) ; un perso qui tourne autour
  de la cible reste sur la moitié arrière, la caméra devant la voit toujours.
- Corrigé au passage : les traînées d'arc des gros coups (`EffectsController:slash`) ne
  marchaient que pour les coups de KAI ; elles passent par le rôle du coup.

### Tests

CombatSimulation **78**, FighterAI 9, CinematicDirector **125** (+ « TARO, ZEPHYR et AKEMI
jouent leurs propres ultimes » ; les 3 ultimes × 4 persos × 3 positions passent les
contrôles de caméra), Animation 22, Kits 26, **PressQueue 4** ✅. Compilation et analyse
statique ✅. Studio ❌ non exécuté.

### Problèmes ouverts

- Audit : points 3 et suivants non reçus (message coupé).
- Ultimes : poses et effets vérifiés hors ligne seulement (cadrage, pas de rendu) ; à juger
  en jeu avec le LABO CINÉ.

## Version 0.9.1 — 1er octobre 2026

Retours de Wilhem sur la 0.9.0 (vue en jeu) : après le passage de R15 à R6 « ça ne veut
plus vraiment marcher », les animations R6 ne sont pas belles (planche de référence R6
fournie : gardes basses et larges, buste penché, poings levés devant), et un texte qui
apparaît reste à l'infini. Toujours **rien de lancé dans Studio** de mon côté.

### Animation R6 (`src/shared/Retarget.luau`)

- **Torse** : un seul bloc pour le bassin et la poitrine virtuels, tourné à mi-chemin entre
  les deux et accroché à la taille (avant, il suivait toute la torsion de la poitrine : le
  corps entier pivotait sur chaque coup de poing).
- **Bras** : visent le milieu de l'avant-bras virtuel (`ARM_REACH` = 0,7) au lieu du poing.
  Bras tendu : identique ; garde : bras levés devant en diagonale, plus à travers la tête.
- **Jambes** : une jambe pliée ne peut pas se plier en R6. Au sol, elle garde la hauteur du
  pied et s'écarte à l'horizontale (`STANCE_DEPTH` = 0,88, un peu plus bas) : garde large et
  basse, l'accroupi baisse vraiment le corps. En l'air (armés de coups de pied, sauts), elle
  suit le milieu du tibia. Jambe tendue : vise la semelle comme avant.
- Vérifié par rendus hors ligne (garde, accroupi, course, saut, coups des 4 persos) et par un
  nouveau test.

### Passage R15 → R6

Cause probable trouvée côté client (non confirmée en jeu) : si le corps R6 n'était pas
entièrement répliqué quand le client le lisait, le contrôleur d'animation était créé sans
squelette et gardé : corps figé pour toujours. Le client relit maintenant le squelette
toutes les 0,25 s tant qu'il est incomplet. Si le problème persiste, il faut la sortie de la
console (F9) au moment du passage en R6.

### Textes qui restaient affichés

- Le tampon des cinématiques (nom du coup « !! », « RYTHME : … ») ne disparaissait qu'à la
  fin de la cinématique ; un événement arrivé juste après (remote séparé) le laissait à
  l'écran. Il se cache maintenant seul après 1,2 s.
- Annonces et noms de techniques : devenus transparents mais jamais masqués (le contour
  `UIStroke` restait) ; ils sont maintenant cachés après leur fondu.

### Tests

CombatSimulation 77, FighterAI 9, CinematicDirector 124, **Animation 22** (+ « R6 : l'accroupi
baisse le corps, la garde garde les poings hors de la tête », pour les 4 persos), Kits 26 ✅.
Compilation et analyse statique ✅. Studio ❌ non exécuté.

### Prochaine étape proposée

1. Wilhem refait le passage R15 → R6 ; si ça bloque encore, envoyer la console (F9).
2. Dire si la garde R6 doit être encore plus basse ou les bras plus hauts : ce sont deux
   réglages (`Retarget.STANCE_DEPTH`, `Retarget.ARM_REACH`).

## Version 0.9.0 — 1er octobre 2026

Deuxième quête de Wilhem : **R15 et R6**, des combos **ni trop simples ni injouables**
(« le juste milieu »), **4 persos** avec chacun leur style (un boxeur, un perso qui ne frappe
qu'avec les pieds, un perso qui esquive avec un passif mais encaisse peu, le reste libre),
des **coups qui ne partent plus quand on change d'avis**, et un jeu **vraiment équilibré,
compétitif**. Toujours **rien de lancé dans Roblox Studio** : tout est vérifié hors ligne
(tests Luau, analyse statique) ou relu, pas vu en jeu.

### Combos : la règle du rythme

- Un appui ne compte « propre » que s'il est fait **après la sortie du coup d'avant**
  (frames actives, impact, récupération ou 6 frames de tolérance). Tapé pendant l'élan, le
  combo continue mais n'est plus propre (`dirtyReason` = « TROP TÔT ») : plus d'ÉVEIL ni de
  PORTE. Fini de taper toute la route d'avance.
- File de **3 appuis**, chacun expire en **10 frames** (« APPUI PERDU ») ; plusieurs boutons
  à la fois / appui de trop = « SPAM » ; mauvais bouton = « MAUVAIS BOUTON ».
- **Changer d'avis gagne** : garde, saut ou dash vident la file ; un coup dans le vide
  oublie les appuis faits pendant son élan (sauf un appui délibéré dans ses 4 dernières
  frames). Testé au clavier comme à la souris côté simulation (les deux envoient les mêmes
  impulsions).
- L'ENTRAÎNEUR affiche la raison exacte (snapshot `dirtyReason`).

### 4 persos (kits)

Un kit associe chaque **rôle** de KAI (Jab, Cross, Smash, KiChase, Finale, KaienRush…) à
ses propres coups : même grammaire de combos pour tous, l'IA et les cinématiques marchent
pour chacun. `MoveData.Kits`, `MoveData.KitOrder`, `MoveData.MoveKit`.

| Perso | Vie | Identité | S + E |
|---|---|---|---|
| KAI 開 polyvalent | 1550 | équilibré | KIKOHO |
| TARO 火 boxeur | 1600 | que les poings, allonge ×0,94, jab en 4 frames, garde de fer (usure ×0,8) | PARADE (frames 3–12) → CONTRE |
| ZEPHYR 風 jambes | 1450 | que les pieds, allonge ×1,12, dégâts ×1,05, saut le plus haut | LAME DE VENT |
| AKEMI 影 esquive | 1100 | la plus rapide, dégâts ×0,88, dash intouchable 5 frames, passif VOILE D'OMBRE (20 s) | KUNAÏ |

- Chaque kit a ses noms, ses 11 routes, ses 6 routes complètes, ses 3 ultimes et leurs
  cinématiques (couleurs et finales propres), ses poses (garde, course, accroupi, coups,
  victoire) et 2 à 4 styles de couleurs (`CharacterData` : BRASIER / CHAMPION, AZUR /
  TEMPÊTE, OMBRE / LUNE ROUGE en plus des 4 de KAI).
- **Tenues sur l'avatar** (`RigBuilder.applyKit`, R15 et R6) : KAI bandeau + ceinture +
  bandages ; TARO gants de boxe, short, ceinture de champion ; ZEPHYR longue écharpe qui
  flotte, protège-tibias ; AKEMI capuche, masque à nœud flottant, brassards. Kanji dans le
  dos. Sur le modèle en blocs, la tenue du kit s'ajoute au corps de KAI.
- Choix : **T** / bouton PERSO, **G** / bouton ADVERSAIRE (CPU, solo). Serveur : impulsions
  `kit` / `foeKit` validées et limitées (0,5 s), `Sim.setKits`, nouveau match. En versus,
  seulement avant le premier coup du match ou après sa fin.
- HUD : barres de vie à la vie max du perso, kanji / nom / rôle, jauge du passif, liste
  COMBOS, ENTRAÎNEUR et LABO du perso local, annonces « PARADE ! » et « VOILE D'OMBRE ! ».
  Effets (étincelle dorée, image rémanente) et sons (fichiers moteur) de parade / esquive.

### Équilibrage (CPU contre CPU, `luau tests/Balance.luau`)

Taux de victoire de la ligne contre la colonne, chaque duel joué des deux côtés.

| LÉGENDE, 120 matchs | KAI | TARO | ZEPHYR | AKEMI | moyenne |
|---|---|---|---|---|---|
| KAI | — | 43 % | 53 % | 40 % | 45 % |
| TARO | 57 % | — | 48 % | 55 % | 53 % |
| ZEPHYR | 48 % | 52 % | — | 33 % | 44 % |
| AKEMI | 60 % | 45 % | 68 % | — | 57 % |

| DIFFICILE, 200 matchs | KAI | TARO | ZEPHYR | AKEMI | moyenne |
|---|---|---|---|---|---|
| KAI | — | 55 % | 50 % | 56 % | 53 % |
| TARO | 45 % | — | 48 % | 64 % | 53 % |
| ZEPHYR | 51 % | 52 % | — | 56 % | 53 % |
| AKEMI | 44 % | 36 % | 44 % | — | 42 % |

Toutes les moyennes entre 42 et 57 % (test de régression : 35–65 %). AKEMI monte avec le
niveau (perso technique) ; les duels extrêmes (AKEMI–ZEPHYR 68 % en LÉGENDE, TARO–AKEMI
64 % en DIFFICILE) changent de sens selon le niveau : c'est surtout le style du CPU qui
pèse. Leviers utilisés : recharge du passif (le plus fort, l'ÉVEIL étant en %), vie
d'AKEMI, KUNAÏ et PAS DE L'OMBRE affaiblis, esquive seulement au neutre, l'IA « appâte »
le passif avec un jab seul et garde contre les projectiles.

### R6

- `RigReader.rigType` reconnaît un corps R6 (Torso sans UpperTorso), `RigSpec.R6` donne les
  joints R6 standard.
- `src/shared/Retarget.luau` (nouveau, pur) : squelette R15 **virtuel** aux proportions du
  corps R6 ; l'Animator l'anime sans changement (IK, timelines) ; chaque membre R6 rigide est
  orienté de son pivot vers le poing ou la semelle virtuels, tourné comme l'avant-bras / le
  pied ; ancrage au sol avec la géométrie R6.
- Serveur : avatar construit en R15 ou R6 (`CreateHumanoidModelFromDescription`), type par
  défaut lu sur le compte (`GetCharacterAppearanceInfoAsync`, `playerAvatarType`) ;
  APPARENCE : avatar R15 → avatar R6 → modèle. Le clone d'ombre du CPU prend le même type.
- Effets et cinématiques visent les bonnes pièces sur R6 (`RigReader.part`).

### Corrections au passage

- Cinématiques : la caméra ne visait jamais la pièce du corps (une expression `if` ne
  renvoyait qu'une valeur) ; elle retombait sur la position du combattant. Corrigé.
- Panneaux COMBOS / LABO qui recouvraient la 3e rangée de boutons : placés sous la dernière.
- IK du pied : cheville calculée exactement (pied à plat et droit quel que soit l'écart des
  hanches, la flexion et l'inclinaison du bassin).

### Fichiers

Nouveaux : `src/shared/Retarget.luau`, `tests/Kits.test.luau`, `tests/BalanceKit.luau`,
`tests/Balance.luau`. Modifiés : `MoveData`, `CombatSimulation`, `FighterAI`,
`CharacterData`, `PoseLibrary`, `Animator`, `Kinematics`, `RigSpec`, `RigReader`,
`CinematicDirector`, `CombatConfig` (0.9.0), `InputConfig` (T, G), `RigBuilder`,
`init.server`, `init.client`, `AnimationController`, `CinematicController`,
`EffectsController`, `HUDController`, `InputController`, `SoundController`, README,
CLAUDE.md.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` (77) : règle du rythme, changement d'avis, parade, esquive, dash intouchable… | ✅ |
| `luau tests/FighterAI.test.luau` (9) | ✅ |
| `luau tests/CinematicDirector.test.luau` (124) : les 3 ultimes de chaque perso, plans par type | ✅ |
| `luau tests/Animation.test.luau` (21) : gardes et coups de chaque perso (TARO ne frappe pas du pied), R6 (corps standard et mis à l'échelle, combat CPU complet sans enfoncement ni flottement) | ✅ |
| `luau tests/Kits.test.luau` (26) : rôles complets avec les coups propres à chaque kit, stats, allonge de ZEPHYR, garde de fer et PARADE de TARO (et ce qui la bat), VOILE D'OMBRE et dash d'AKEMI, équilibrage 35–65 % | ✅ |
| Compilation et analyse statique Luau de tous les scripts | ✅ |
| Jeu dans Studio (tenues sur de vrais avatars R15/R6, HUD, sons) | ❌ non exécuté |

### Problèmes ouverts

- Rien vu en jeu : tenues taillées par calcul sur les pièces de l'avatar (accessoires et
  cheveux peuvent traverser la capuche d'AKEMI), animation R6 vérifiée seulement hors ligne.
- La taille visible d'une tête R6 classique est estimée (taille de la pièce × échelle du
  mesh) : bandeau / masque à ajuster si besoin.
- `Model:ScaleTo` sur un R6 non parenté, et `GetCharacterAppearanceInfoAsync`, à vérifier
  en jeu (repli : R15).
- Équilibrage mesuré entre CPU, pas entre humains : à recouper avec de vrais matchs.
- Sons toujours provisoires (fichiers du moteur).

### Prochaine étape proposée

1. Wilhem lance la 0.9.0 dans Studio : T pour passer les 4 persos, APPARENCE en R6, une
   route en rythme avec l'ENTRAÎNEUR, la parade de TARO et le passif d'AKEMI.
2. Retours précis (perso, coup, frame) ; tests entre joueurs pour l'équilibrage.
3. Ensuite : SFX du jeu, écran de sélection des persos avant le match.

## Version 0.8.0 — 1er octobre 2026

Mission de Wilhem : **qualité** — graphismes, jouer **son avatar avec le kit KAI**, et une
**vraie amélioration des animations**. Toujours **rien de lancé dans Roblox Studio** : tout
ce qui suit est vérifié hors ligne (tests Luau) ou relu, pas vu en jeu.

### Animation : nouveau moteur, testé hors Studio

L'animation n'est plus une table de poses dans le client : c'est un module pur
(`Animator`) qui tourne aussi dans les tests, avec la cinématique directe (FK) du vrai rig.

| Module | Rôle |
|---|---|
| `src/shared/RigSpec.luau` | Géométrie du rig KAI (pièces, pivots) : une seule source pour le RigBuilder et les tests |
| `src/shared/Kinematics.luau` | Maths pures : transformations au format CFrame, FK, IK de jambe à 2 os, pied qui roule sur le talon / la pointe, ressorts |
| `src/shared/PoseLibrary.luau` | Toutes les poses (déplacées du client) + nouvelles poses |
| `src/shared/Animator.luau` | Timelines, marche, mélanges, ressorts, regard, ancrage au sol |
| `src/shared/RigReader.luau` | Lit les Motor6D d'un rig vivant (KAI ou avatar R15) au format de Kinematics |
| `src/client/AnimationController.luau` | Réécrit : lit le squelette réel, appelle l'Animator, écrit les Motor6D et les tissus |

Ce qui change à l'écran :

- **Coups en 4 temps** : anticipation (la pose de départ est poussée 15 % plus loin puis
  tenue), **frame d'impact** qui dépasse la pose de contact pendant 2 ticks (smear), contact,
  puis récupération et retour en garde avec un léger rebond. Toujours calé sur la frame
  autoritaire du serveur ; « POSES : 12/15/24/s » garde l'effet par paliers de l'anime.
- **Pieds plantés par IK** : garde, accroupi, coups de poing, réactions… les pieds sont posés
  au sol par cinématique inverse, talon levé sur les coups (le pied pivote sur sa pointe).
- **Course sans glissade** : la marche avant devient une course de combattant (phase en
  l'air), la marche arrière un pas chassé ; la phase suit la distance réellement parcourue à
  l'écran, le pied d'appui ne glisse plus (vérifié pour KAI et pour un corps d'avatar).
- **Ancrage au sol pour tout corps** : le point le plus bas (ou les pieds plantés) est posé
  sur le sol à chaque frame, quelle que soit la taille de l'avatar ; plus rien ne flotte ni
  ne traverse le sol (couché, à genoux, balayage…).
- **Réactions selon le coup reçu** : tête rejetée (2 variantes alternées), plié en deux
  (coups au corps, rafales), jambes fauchées (coups bas) ; impact puis vacillement.
- **Nouvelles séquences** : relevé en 3 temps (au sol → un genou → garde), chute avec impact
  et rebond des membres, effondrement en 2 temps (mains au ventre → à genoux), garde brisée
  qui titube, saut en 3 phases selon la vitesse verticale, **atterrissage amorti**, dash
  arrière en petit saut, victoire avec poing levé, pose 開天 PORTE DES CIEUX (manquait).
- **Mouvements secondaires** (ressorts) : inclinaison selon l'accélération, secousse du
  buste à chaque coup reçu, respiration, et **le regard suit l'adversaire** (lève la tête
  vers une cible en l'air, la baisse vers un adversaire au sol).
- **Demi-tour** : quand les combattants se croisent, le corps pivote en quelques frames
  (par le côté caméra) au lieu de se retourner d'un coup.
- **Tissus** : pans de ceinture et du bandeau sur des `Weld` (`TailJoint`) qui ondulent avec
  le mouvement (ressorts), sur KAI et sur le kit posé sur l'avatar.

### Ton avatar avec le kit KAI

- Chargement en cascade, jamais d'échec silencieux : compte (UserId) → identifiant
  d'apparence (`CharacterAppearanceId`, utile en Studio) → 2 essais chacun → avatar **sans
  accessoires** si le corps complet ne se construit pas → **corps R15 par défaut** aux
  couleurs du style → KAI seulement si même ça échoue. Le kit est posé dans tous les cas.
- L'avatar est **mis à la taille de KAI** (≈ 5,7 studs) avec `Model:ScaleTo` quand il est
  trop petit ou trop grand : les hurtboxes de la simulation correspondent au corps affiché.
- Attribut joueur `AvatarStatus` (`CHARGEMENT`, `OK`, `SANS ACCESSOIRES|raison`,
  `DÉFAUT|raison`, `KAI|raison`) : le HUD l'affiche dans la ligne d'état et annonce
  « AVATAR INDISPONIBLE » avec la raison.
- Apparence mise en cache par joueur (changer de style ne recharge plus l'avatar).

### Graphismes

- Arène : plancher en `WoodPlanks` avec zone de combat usée, marches et ruines en `Slate` /
  `Cobblestone`, bannières en `Fabric`, lanternes rondes avec chapeau et lumière qui projette
  des ombres, **cerisiers** (2e plan de profondeur), **braises** qui montent du plancher,
  **brume au sol** (texture moteur `rbxasset://textures/particles/smoke_main.dds`).
- Lumière de coucher de soleil retravaillée, ombres du soleil plus nettes, `SunRays`,
  bloom et étalonnage ajustés ; le corps de KAI **projette maintenant son ombre**.
- Client (`StageController`, nouveau) : lanternes qui vacillent, bannières au vent, **ombre
  de contact** douce sous chaque combattant (rétrécit en l'air), léger flou de profondeur
  sur le décor pendant le combat (coupé pendant les cinématiques).
- **Traînées de mouvement** (`Trail`) sur le poing ou le pied qui frappe, couleur du ki ;
  **lueur de ki** (lumière) pendant les compétences et ultimes, pulsation quand l'ultime est
  prêt.

### Sons (provisoires)

`SoundController` (nouveau) : impacts, garde, garde brisée, sauts, atterrissages, chutes,
relevés, souffle des coups, super flash, QTE, pas de course. **Uniquement des sons livrés
avec le moteur Roblox** (`rbxasset://sounds/...` : `action_jump_land.mp3`, `action_jump.mp3`,
`action_get_up.mp3`, `action_footsteps_plastic.mp3`, `swordslash.wav`, `swordlunge.wav`,
`unsheath.wav`, `electronicpingshort.wav`) : ce sont des fichiers du client Roblox, pas des
ID d'asset. Bouton **SON** pour couper. À remplacer par les SFX du jeu quand Wilhem les fournit.

### Tests

| Test | État |
|---|---|
| `luau tests/Animation.test.luau` (16, nouveau) : chaque coup a ses poses, chaque état a son animation, angles dans les limites, pieds plantés au sol et à plat (KAI **et** un corps d'avatar aux proportions différentes), rien ne traverse le sol, couché = vraiment au sol, **course sans glissade** dans les 2 sens et les 2 orientations, phase en l'air, timelines (impact snappé, retour exact en garde, pas de saut > 75°/frame), anticipation et smear, paliers, réactions selon le coup, atterrissage, regard, ressorts stables, **combat CPU complet de 45 s** sans NaN ni traversée du sol | ✅ |
| `luau tests/CombatSimulation.test.luau` (73) | ✅ |
| `luau tests/FighterAI.test.luau` (9) | ✅ |
| `luau tests/CinematicDirector.test.luau` (33) | ✅ |
| Compilation Luau de tous les scripts | ✅ |
| Jeu dans Studio (rendu, avatar réel, sons, performances) | ❌ non exécuté |

Les tests ont trouvé et fait corriger : pieds qui glissaient au contact du sol (la course
démarre et s'arrête maintenant à vitesse nulle par rapport au sol), torsion du bassin qui
décalait les pieds, bras qui calaient le corps 1 stud au-dessus du sol en position couchée,
pied replié qui traversait le sol (KICK BAS), genou arrière sous le sol (BALAYAGE), cou
au-delà de sa limite pendant les coups.

### Problèmes ouverts

- Rien vu en jeu : poses, vitesse de la course, force des ressorts, ombres et flou de
  profondeur sont à juger dans Studio (le bouton POSES : FLUIDE aide à comparer).
- Sons provisoires (fichiers du moteur), à remplacer.
- `Model:ScaleTo` sur un avatar non parenté à vérifier en jeu (sinon la mise à l'échelle est
  sautée, un avertissement s'affiche).
- La lecture des `CFrame` des pièces juste après l'écriture des `Motor6D` (tissus) peut avoir
  une frame de retard : sans gravité visible.

### Prochaine étape proposée

1. Wilhem lance la 0.8.0 dans Studio : son avatar avec le kit (et la ligne d'état si ça
   échoue), la course, les coups en POSES 15/s puis FLUIDE, les chutes et relevés.
2. Retours visuels précis (« tel coup, telle frame ») : le labo + HITBOX donnent le plan et
   le tick ; les poses se règlent dans `PoseLibrary.luau` et les tests vérifient le reste.
3. Ensuite : kits du roster (proposition 0.7.0) et SFX du jeu.

## Version 0.7.1 — 1er octobre 2026

Précision de Wilhem : « spammer », c'est appuyer sur tous les boutons, pas appuyer vite sur
les bons. Nouvelle règle de route **propre** (ultimes 2 et 3) :

- taper la bonne suite, aussi vite qu'on veut et même entièrement d'avance, reste propre ;
- est du spam : plusieurs boutons sur le même tick, un appui qui déborde de la file, un
  mauvais bouton quand la fenêtre d'enchaînement est ouverte, ou un appui jamais utilisé ;
- la file d'appuis passe de 3 à 6 (une route complète d'avance) ; la règle « 1 appui après
  l'impact » et la tolérance précoce (`CleanEarlyTicks`) sont supprimées.

Tests : 73 (combat, dont « route tapée d'avance très vite = ÉVEIL » et « tous les boutons à
la fois = pas d'ultime »), 9 (IA), 33 (caméra) ✅.

## Version 0.7.0 — 1er octobre 2026

Retours de Wilhem : impossible de placer les combos, cinématiques à déboguer ; l'IA lui a
mis un ultime ; équilibrer les barres de vie ; repenser les persos comme « le perso du
joueur avec un kit » ; à la manette, les appuis faits pendant qu'on se fait frapper sortent
au relevé alors qu'il veut garder. **Toujours rien de lancé dans Roblox Studio.**

### Combos jouables

- **Tolérance tardive** (`LateCancelTicks = 6`) : un appui reçu jusqu'à 6 ticks après la fin
  d'un coup qui a touché enchaîne encore (latence réseau Roblox).
- (0.7.1 : la tolérance précoce est remplacée par la nouvelle définition du spam.)
- Réglages de VENT ASCENDANT, BALAYAGE, TALON FOUDRE, POING DU DRAGON : **les 6 routes
  passent avec 4 à 16 ticks de réaction et un écart de départ de 3 à 4,4** (test permanent).
- **Entraîneur de combo** (HUD) : route choisie, cases des touches, « MAINTENANT ! » quand le
  serveur juge le prochain appui bon (`cancelReady`), et la raison d'un échec.

### Appuis pendant les coups reçus

Pendant l'étourdissement, la chute, le relevé ou la garde, les appuis sont **ignorés** sauf
dans les 4 derniers ticks (`ReversalBufferTicks`, reversal volontaire) ; maintenir la garde
au moment de récupérer **vide** la file d'appuis.

### Cinématiques testables

- Nouvelle **mise en scène pure** `src/shared/CinematicDirector.luau` (positions, poses,
  plans, effets demandés) ; le client ne fait plus qu'exécuter.
- `tests/CinematicDirector.test.luau` rejoue chaque cinématique avec la vraie simulation et
  vérifie chaque frame : caméra au-dessus du sol, hors des corps, dans l'arène, sujet devant
  et **non caché par l'autre combattant** ; au centre et contre les deux murs ; et que chaque
  route d'ÉVEIL a sa propre finale et que le FINAL FINISH contient tous les plans de K.O.
- **Bugs trouvés et corrigés** : « DOS DU GAGNANT » filmait dans le mauvais sens (le gagnant
  hors champ) ; l'orbite de TORNADE passait derrière KAI qui cachait la cible.
- **LABO CINÉ** (solo) : lance n'importe quelle cinématique sans combo
  (`CombatSimulation.debugCinematic`, remote `Debug` validé côté serveur) + aperçu de la scène
  de K.O. ; avec HITBOX, affichage « plan · tick · FOV » pour signaler un plan précis.

### Équilibrage

Vie 1000 → **1500** : une route complète ≈ 20-27 %, KAIEN RUSH ≈ 28 % ; PORTE DES CIEUX
40 % de la vie max (+10 % au QTE) ; ÉVEIL inchangé (−95 % de la vie actuelle).

### Kits sur l'avatar Roblox

KAI devient un **kit** : style de combat + tenue posée sur l'avatar du joueur, dimensionnée
sur ses vraies pièces (bandeau noué, ceinture à nœud et pans, bandages, 開 dans le dos). Quatre
**styles** de la planche : CLASSIQUE, NUIT, SACRÉ, MAUDIT (bouton STYLE ; le CPU prend un autre
style). `CharacterData[slot]` est l'apparence courante d'un slot, changée par le serveur et
synchronisée par le snapshot.

**Proposition pour la suite (à valider)** : un kit par perso du roster de la planche — RYUEN
龍 (vitesse, combos), ZEPHYR 風 (aérien), KARA 花 (technique, portée), DAIGO 岩 (lourd, zone),
SORA 雷 (projectiles), AKEMI 影 (assassin, feintes), TARO 火 (puissance). Chaque kit = son
propre MoveData (routes, 3 ultimes), sa tenue sur l'avatar et ses styles ; écran de sélection
avant le combat.

### Animation

Fondu court (~0,07 s) entre les poses qui ne sont pas des impacts (garde, marche, accroupi,
récupérations) ; impacts et réactions aux coups restent instantanés.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 71 tests | ✅ |
| `luau tests/FighterAI.test.luau` : 9 tests | ✅ |
| `luau tests/CinematicDirector.test.luau` : 33 tests (caméra de chaque cinématique) | ✅ |
| Studio | ❌ non exécuté |

## Version 0.6.0 — 1er octobre 2026

Demandes de Wilhem : l'attaque écarlate doit se mériter (plus de spam) ; un combo combiné
au R qui change la cinématique ; **3 ultimes par perso** (R classique, fin de chaîne, fin
de chaîne + R) ; scène de K.O. d'après ses planches ; cinématiques bien plus travaillées ;
utiliser les personnages Roblox. **Toujours rien de lancé dans Roblox Studio.**

### Les 3 ultimes

| # | Entrée | Coût | Règle |
|---|---|---|---|
| 1 | R seul | 2 barres | KAIEN RUSH (inchangé) |
| 2 | route complète **propre**, 6e = clic droit | 3 barres | ÉVEIL ÉCARLATE : −95 % de la vie actuelle ; < 50 % de la vie max : FINAL FINISH |
| 3 | route complète **propre**, 6e = touche R | 3 barres | 開天 PORTE DES CIEUX : −50 % de la vie max (sans réduction de combo, peut tuer) ; R pile au sommet (±4 ticks) : +10 % |

**Route propre** (`chainClean`) : chaque appui doit arriver quand rien n'attend dans la file
et, en plein combo, quand le coup en cours a déjà sorti toutes ses touches. Tout appui
« sale » (spam, anticipation) verrouille les ultimes 2 et 3 pour ce combo. La route jouée
(`chainKeys`) doit correspondre aux 5 premiers maillons d'une route complète.

**QTE d'ÉVEIL** : 4 appuis en rythme pendant la rafale (les 4 premières touches de la route
jouée), fenêtre ±7 ticks ; trop tôt, mauvaise touche ou raté = échec. Tout réussi =
PARFAIT et +1 barre ; sinon GRAND / BON. Le CPU les réussit selon son niveau.

### Cinématiques (client)

- Plans décrits par des points liés aux **parties du rig** (tête, main, pieds, torse),
  résolus après placement : le cadrage marche sur KAI comme sur n'importe quel avatar.
  Coupes franches entre plans, léger travelling avant, **flou de profondeur** sur le sujet.
- **ÉVEIL** : yeux + kanji, aura en contre-plongée, dash, un angle par coup, puis **finale
  selon la route** : TORNADE (montée en spirale dans des anneaux de ki), RAFALE (barrage de
  poings), DRAGON (charge puis uppercut avec dragon de ki en spirale), FOUDRE (saut dans
  l'orage, plongeon sous les éclairs), MUR (talon qui envoie la cible dans le mur), LUNE
  (croissant géant puis hache depuis la lune) ; onde de choc, titre.
- **PORTE DES CIEUX** : sceau 開 en plongée, torii géant qui surgit, porte qui s'ouvre et
  aspire la cible pendant que KAI marche (vue de dos), monde écarlate, deux coups, gros plan
  sur le poing et gel noir et blanc (QTE R), coup unique, la porte vole en éclats.
- **Scène de K.O.** (FINAL FINISH et K.O. qui gagne le match) d'après les planches : chute au
  ralenti, MAIN AU SOL, SCÈNE 1 (vaincu au premier plan, gagnant debout, angle très bas),
  DÉTAIL PIEDS, ZOOM VISAGE, SCÈNE 2 (bras croisés, légère contre-plongée), DOS DU GAGNANT,
  PLAN LARGE ARÈNE, FONDU NOIR + K.O. Les rigs peuvent être orientés librement et placés en
  profondeur pour composer ces plans.

### Personnages Roblox

Avatar R15 du joueur par défaut ; le CPU / mannequin est un **clone d'ombre** de l'avatar
adverse (corps sombre, contour et voile de la couleur d'énergie). Sans avatar chargeable
(joueurs de test Studio) : R15 Roblox par défaut aux couleurs NUIT. Le bouton APPARENCE
revient à KAI.

### Arène

Bannières rouges à kanji (闘 魂 開 炎), piliers en ruine et gravats en fond, pour les plans
larges.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 64 tests (dont ÉVEIL et PORTE mérités sur chaque route, spam qui verrouille, QTE PARFAIT / spam = BON, bonus et K.O. de la PORTE, R seul = KAIEN RUSH) | ✅ |
| `luau tests/FighterAI.test.luau` : 9 tests (dont LÉGENDE mérite un ultime et réussit le rythme) | ✅ |
| Studio : cinématiques, cadrages, avatars, clone d'ombre | ❌ non exécuté |

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
