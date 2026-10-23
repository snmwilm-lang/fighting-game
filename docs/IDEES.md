# Idées de Wilhem — la boîte à idées

Tenue par l'agent `idees` (`.claude/agents/idees.md`). Une fiche par idée, numérotée `I-###`.

Statuts :
- `nouvelle` ;
- `à clarifier` ;
- `prête` (elle passe à l'agent `production`) ;
- `en production` ;
- `faite (vX.Y.Z)` ;
- `refusée (raison)`.

---

Dernier tri : 23 octobre 2026 (routine du matin).

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : 12 octobre 2026 pour l'idée (v0.27.0) ; ces quatre persos attendent depuis la v0.33.0.
- **Wilhem** :
  - « une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue » (rappelé en tête de `Finishers.luau`) ;
  - la règle : « seulement sur la deuxième vie… si l'adversaire n'a pas peu d'HP et l'utilisateur du final n'a pas déjà un round gagné, le FATAL FINISHER s'active pas, il y a juste le fatal classique » (journal, v0.27.0).
- **Interprétation** : quand le COUP FATAL de l'un de ces quatre persos tue, le joueur voit une scène d'environ 10 s propre au perso. Cette scène est le K.O. lui-même, avec le nom du finisher.
- **Ce qui existe** (vérifié le 23 octobre 2026) :
  - 20 persos ont leur finisher, tous les persos jouables : une ligne `Finisher = { Name, Length, FinalTick }` dans `MoveData.luau` et une scène `S.KIT` dans `Finishers.luau` ;
  - **NOVA est faite (v0.36.4)** : FATAL ERROR (ERREUR FATALE), 11 s. Huit drones se rangent en rail d'anneaux devant son gantelet, puis un compte 3-2-1-0 et un seul tir ; la cible « bugue », puis tombe. « ZERO HOUR » a été écarté (décision du 17/10) ;
  - la scène de NOVA a trois bugs relevés le 18/10 : B-012 (la visière dans sa tête) est ouvert ; B-013 (le rail posé sur une main mesurée au labo) et B-014 (9 lumières à la fois) attendent que Wilhem les confirme en jeu. Ils se suivent dans `BUGS.md` et ne rouvrent pas l'idée ;
  - **KUROEN est fait (v0.36.9)** : BLACK SUN (SOLEIL NOIR), 10,7 s. Les trois marques de DOMINATION s'allument dans son dos. Trois coups (genou, coude, paume) laissent chacun un petit soleil noir sur la cible. Les trois soleils volent dans son poing levé et n'en font plus qu'un, puis AXE OF NIGHT abat la cible des deux poings. Deux points se suivent ailleurs et ne rouvrent pas l'idée :
    - ses trois coups sont ceux de sa chope, ECLIPSE CLINCH : assumé pour cette livraison, à revoir par Wilhem (`DECISIONS.md`, 22/10) ;
    - le grand soleil saute de 3,6 studs au coup mortel (B-031, cosmétique, ouvert) ;
  - ASURA et KUROEN SHIN n'ont **ni ligne ni scène**. Ils jouent encore leur fatal classique : 阿修羅 · FINAL WRATH pour ASURA, 真 · ETERNAL ECLIPSE pour KUROEN SHIN ;
  - un test commun aux finishers existe depuis la v0.36.4 (`Cinematography`). Il vérifie : au moins 6 plans propres au perso, un nom unique qui n'est le nom d'aucun coup d'un autre perso, le K.O. après le coup mortel, la cible à terre, des sons de la palette. Il joue aussi les bosses : un finisher d'ASURA y entre tout seul ;
  - depuis la v0.36.5, `Cinematography` joue aussi chaque finisher avec l'attaquant dos au mur, à gauche puis à droite. Un perso qui reçoit sa ligne `Finisher` y entre tout seul, bosses compris ;
  - depuis la v0.36.6, `Cinematography` joue aussi les COUPS FATAUX classiques des 22 kits dos au mur, des deux côtés (44 tests) ;
  - l'outil `Kit.hiddenShare` (`tests/CinematicKit.luau`, v0.36.6) mesure quelle part du sujet d'un plan est cachée par l'autre corps. S'en servent les 4 tests ISSEN de SHIN et, depuis la v0.36.9, les 6 tests de placement de BLACK SUN. **Un nouveau finisher n'y entre pas tout seul** : il lui faut ses propres tests. La fonction `film` de `Cinematography`, écrite pour BLACK SUN, prend déjà le nom du kit ;
  - la règle de déclenchement existe déjà dans `CombatSimulation` : un COUP FATAL qui tue, lancé par un perso qui a déjà gagné un round (ou mis K.O. un perso d'un relais). Il n'y a rien à changer ;
  - **depuis la v0.36.8 (B-020)**, « qui tue » a un sens précis. `startCinematic` sépare deux choses :
    - `fells` : le coup abat la cible (l'ancienne condition, inchangée) ;
    - `finish` : la scène joue sa version K.O. C'est `fells`, sauf si la cible va se relever (la première vie d'ASURA, seul kit avec une seconde vie) ;
    - le finisher ne se choisit que sur `finish`. Il ne se joue donc que sur un vrai K.O. : après sa scène, la cible ne se relève jamais. Contre KUROEN SHIN, qui n'a pas de seconde vie, un finisher se joue comme contre les autres (test de garde de la v0.36.8).
- **Pour chaque nouvelle scène (ASURA, puis KUROEN SHIN), ce qu'ont appris les livraisons** :
  - passer le test « dos au mur, des deux côtés » de `tests/Cinematography.test.luau` (v0.36.5, B-011, B-010). Pour la voir ainsi : `luau tests/Storyboard.luau -a KIT Fatal - 1 20 wall-left`, puis `wall-right` ;
  - prévoir le placement dès le départ avec `room`, dans `Finishers.luau`, comme SHIN et KUROEN : près d'un mur, toute la scène recule, jamais le perso seul. Sans `room`, la caméra d'un gros plan tombe dans un corps, ou un visage est caché aux deux tiers (B-018, finishers de KUREN et de TARO, ouvert) ;
  - garder les deux corps sur le sol de combat, x de -28 à 28 : 11 finishers sur 19 en sortent (B-015), surtout quand **la cible** est près du mur. Il faut donc jouer aussi la cible près de chaque mur. `room` sert aussi à ça ;
  - `Kit.hiddenShare` : **jamais plus d'un quart du sujet caché**, à chaque image, au centre des deux côtés, dos à chaque mur et la cible près de chaque mur. Le modèle : les 6 tests de placement de BLACK SUN (au pire 22 % caché). La mesure se fait sur le rig KAI du labo, et les vrais avatars n'ont pas sa taille (B-018) : garder de la marge ;
  - la jouer aussi **depuis la droite**, au centre : le labo ne joue que depuis la gauche. Un plan où le perso se retourne doit avoir un angle qui dépend du côté (B-019 : la PORTE de KUROEN cache sa tête derrière la cible depuis la droite) ;
  - poser les formes sur les vraies pièces du corps, par exemple `P(A, "RightHand")`, et non sur des nombres mesurés sur le rig du labo (B-013). Un trait posé sur une tête doit bien en sortir (B-012) ;
  - au plus une lumière allumée à la fois (B-014 : NOVA en allume 9, la scène la plus lourde du jeu) ;
  - jamais « VICTORY » (B-026) : en relais, un finisher peut tomber sans finir le match, et le perso suivant entre après la scène.
- **Pour ASURA (le prochain), ce que production doit savoir** :
  - **son identité** :
    - 阿, « un KAI à quatre bras, sorti de la Porte des Cieux » (sa description). C'est le boss du CHALLENGE · ASURA, jamais jouable (il n'est pas dans `KitOrder`) ;
    - l'or FFD23F sur du noir, avec du rouge sang : peau sombre, cheveux noirs à pointes d'or, yeux d'or, gilet noir bordé d'or, chemise rouge très sombre, bandes d'or. Il n'a qu'un style (`CharacterData`) ;
    - ses effets (`KitFX`) : des poings de ki dorés, deux coups dorés à la fois. Dans ses ultimes : un poing doré (`asuraFist`), une auréole des quatre bras (`asuraHalo`), un sceau brûlant au sol (`asuraSeal`), le sol qui tremble sous ses pas lourds ;
    - son son (`SoundPalette.ASURA`) : « les coups de KAI, plus graves, en salle » (souffle, poing, boom). Pas d'acier : le son `slash` n'est pas sa matière ;
    - ses poses : le rugissement (`Roar`) ouvre ses ultimes ; au repos, il se tient debout (`StandTall`). Ses deux victoires viennent des images d'Asura's Wrath envoyées par Wilhem (« tu peux alterner les deux ») : double biceps de face, bras en auréole de dos ;
    - sa seconde vie : abattu une fois, il se relève dans une aura noire (corps assombri, contour rouge sang, « ASURA RISES AGAIN »), avec la musique WRATH ;
    - il a les coups de KAI (les mêmes rôles), mais chacun avec sa propre pose (test Animation ; Wilhem : « chaque animation est obligatoirement différente »).
  - **ses quatre bras** (`FourArms.luau` ; journal v0.15.1, v0.16.1 et v0.23.20) :
    - la deuxième paire sort de ses flancs, sous les vraies épaules (Wilhem : « les deux autres bras d'ASURA sortent des côtés normalement ») : bras, avant-bras, poing bandé, brassards d'or (`RigBuilder.addFourArms`) ;
    - une scène ne les pose pas elle-même : ils suivent la vue d'ASURA (`FourArms.pose`). Chaque pose de scène a sa clé (`FourArms.SCENE`) :
      - debout : lourds, le long du corps ;
      - bras croisés : la paire du bas se croise sous la première ;
      - kiai, rugissement : écartés comme une auréole ;
      - à genoux : poings au sol ;
      - projeté : rejetés en arrière ;
      - un coup avec ses données : une paire frappe, l'autre garde (les deux sur un coup lourd ou un ultime). Un coup sans données : une rafale ;
      - la victoire : double biceps ou auréole ;
    - les retours de Wilhem à respecter : « travaille les 4 bras d'ASURA, c'est dégueulasse » (v0.15.1) ; « ce bug avec les bras d'ASURA, les bras du bas se lèvent, règle-le » (capture en cinématique, v0.23.20) ; « ASURA, ses bras, la deuxième paire, rends-la agréable ». Les bras du bas ne montent pas devant son visage et ne s'emmêlent pas avec sa vraie garde ;
    - pour un geste nouveau (par exemple, ses quatre poings ensemble), production ajoute une clé dans `FourArms` (module pur) et sa pose dans `FourArms.SCENE`. Le test Animation vérifie toute pose de `SCENE` : jamais à travers son corps ;
    - en jeu, le client lisse leurs mouvements (`AnimationController:swingFourArms`) : ils atteignent leur pose environ 0,1 à 0,25 s plus tard. Le storyboard les dessine sans ce lissage (`WeaponKit.fourArms`). Un poing du bas qui doit toucher pile au coup mortel doit donc partir quelques images avant.
  - **ses ultimes, à ne pas recopier** (`CinematicDirector`, `GEN.add("ASURA")`) :
    - R, FOUR-ARMED GATLING : une tempête de poings de ses quatre bras, la cible clouée sur place. C'est aussi son E ;
    - ÉVEIL, THOUSAND ARMS : la cible projetée plus haut à chaque coup ;
    - PORTE (titre 阿修羅 · WRATH OF THE FOUR ARMS) : la cible balancée en rond au bout de ses bras ;
    - FATAL, 阿修羅 · FINAL WRATH : la cible saisie, écrasée au sol d'un côté, soulevée, écrasée de l'autre ;
    - **sa chope** : la cible saisie à la taille, soulevée au-dessus de sa tête dans ses quatre bras, puis jetée au sol (`MoveData.Throws.ASURA`) ;
    - **et ceux de KAI, dont il reprend les coups** :
      - MAXIMUM KAIENHA, faite d'après la planche de Wilhem (12 plans) : l'énergie entre ses mains, l'aura qui éclate, la vague qui traverse l'arène, l'explosion de lumière, le K.O. sur une carte de lumière, KAI vu de dos dans la fumée ;
      - le KAIENHA, le KIKOHO (la boule des dessins de Wilhem, décision du 15/10) et 滅 · DEAD SKY ;
      - donc pas de vague ni de boule d'énergie tirée des mains : en or, ce serait MAXIMUM KAIENHA joué par KAI en style SACRÉ ou ÉVEILLÉ, dorés eux aussi (FFD23F), mais sans les quatre bras.
  - **les noms déjà pris** :
    - les 20 finishers : MAXIMUM KAIENHA, DEMPSEY ROLL: FINAL ROUND, GALE EXCALIBUR, THOUSAND SHADOWS, TEN FISTS OF RAGE, FINAL DIVISION, INVERTED WORLD, THRONE OF RUINS, SPEAR OF THE THUNDER GOD, FROZEN REQUIEM, TOXIC FEAST, TITAN QUAKE, STELLAR COLLAPSE, RESONANCE, CAGE OF CLAWS, CRIMSON COVENANT, THE GREAT HUNT, FINAL MERCY, FATAL ERROR, BLACK SUN ;
    - les siens : FOUR-ARMED GATLING, THOUSAND ARMS, WRATH OF THE FOUR ARMS, 阿修羅 · FINAL WRATH, ASURA'S WRATH (son passif), ASURA RISES AGAIN, ASURA CRUSHED YOU, les titres du défi (ASURA SLAYER, ARM BREAKER, ASURA'S EQUAL, ASURA) et le succès FACE THE GATE ;
    - ceux de KAI : KAIEN RUSH, SCARLET AWAKENING, 開天 · GATE OF HEAVEN, 滅 · DEAD SKY ;
    - les mots déjà très pris : WRATH (4 noms, dont 雷神 · DIVINE WRATH de RAIJIN), THOUSAND (THOUSAND ARMS, THOUSAND SHADOWS, THOUSAND BOLTS, THOUSAND THRUSTS), ARMS, FINAL (FINAL ROUND, FINAL DIVISION, FINAL MERCY, FINAL WRATH, 終 · FINAL BELL), FIST (TEN FISTS OF RAGE, FIST FURY, 砕 · WORLD FIST) ;
    - **attention, le test commun ne voit pas ses noms** : il compare le nom du finisher aux noms des coups de `MoveData`. Ceux d'ASURA vivent dans `CinematicDirector` (les noms de son thème, son `GateTitle`), et son E n'appartient à aucun kit (`MoveKit`). Un finisher appelé THOUSAND ARMS passerait le test, comme celui d'ASTER, qui porte le nom de son ÉVEIL (B-009). Vérifier à la main, ou étendre le test à ces noms.
  - **ses pièges à lui** :
    - **les outils de test ne voient pas ses bras du bas**. `CinematicKit` ne construit que le squelette de KAI (`info.parts`), sans eux :
      - `Kit.hiddenShare` ne les compte pas parmi ce qui cache la cible ;
      - un plan ou une forme accrochés à ses poings du bas (`AsuraFistLeft`, `AsuraFistRight`) marchent en jeu, car `RigReader.part` trouve la pièce par son nom. Mais ils font planter les outils : `resolve` (`CinematicKit`) ne connaît pas ces pièces ;
      - seul le storyboard les dessine (`WeaponKit.fourArms`) ;
      - avant de filmer ses bras du bas ou d'y accrocher une forme, production les ajoute aux corps des outils, à partir de `WeaponKit.fourArms`. Sinon, ne s'accrocher qu'aux vraies pièces ;
    - **en défi, sa scène se jouera surtout depuis la droite** : ASURA est l'emplacement 2 (`init.server.luau:609`), qui commence à droite (`SpawnX`). Le labo ne joue que depuis la gauche : pour lui, les tests et les planches depuis la droite (`right`, `wall-right`) comptent autant que les autres ;
    - **la cible est l'un des 20 persos jouables**, avec son arme s'il en a une (le katana de SHIN, la lance de RAIJIN, l'orbe de DAICHA…). Les outils prennent KAI : garder de la marge (B-018) ;
    - **sa seconde vie** : la scène peut se jouer pendant sa seconde vie, le corps assombri dans son aura noire (`EffectsController.luau:1965`), que les outils ne dessinent pas. Elle doit rester lisible ainsi : de l'or sur du noir ;
    - **la couleur** : l'or FFD23F est aussi celui de KAI en SACRÉ et en ÉVEILLÉ, et du thème OR de la boutique. KUROEN SHIN est blanc et or, ELIAN or pâle (FINAL MERCY, ses ailes). La scène doit se lire « ASURA » (quatre bras, colère, or sur noir et rouge sang), et non « divin » ou « lumière » ;
    - **ni VICTORY, ni ses poses de victoire** : en défi, son finisher tombe souvent en plein relais. Ses poses `Victory` et `VictoryAlt` appartiennent à la fin du match, et elles changent aussi la pose de ses bras du bas.
  - **seconde vie et B-020 : vérifié le 23/10, rien ne bloque quand c'est lui l'attaquant** :
    - `finish` ne regarde que la **cible** (`fells and not canRevive(d)`). Les cibles d'ASURA sont les persos du joueur, et aucun n'a de seconde vie : seul ASURA en a une (`SecondLife`, `MoveData.luau:1402`), et il n'est jamais dans l'équipe du joueur. Pour lui, `finish` vaut donc `fells`, comme pour tout autre attaquant ;
    - la ligne `Finisher` se lit sur **son** kit (`kitOf(world, a)`, `CombatSimulation.luau:1330-1332`), pas sur celui de KAI, et sa scène se cherche sous son nom (`kit = a.kit`, `:1341` ; `CinematicDirector.luau:5179`) : ce sera `S.ASURA`. KAI garde MAXIMUM KAIENHA ;
    - sa propre seconde vie ne gêne pas : sa résurrection (`revive`, `CombatSimulation.luau:1204-1212`) ne touche ni ses victoires (`wins`), ni son COUP FATAL déjà utilisé (`fatalUsed`). Le finisher peut donc se jouer dans ses deux vies ;
    - **mais la scène sera rare**. Il faut, à la fois :
      - un défi à 2 ou 3 persos, dont un déjà mis K.O. par ASURA : c'est sa « manche gagnée » (une marque par perso K.O., `:2473`). Contre un seul perso, son premier K.O. finit le défi : jamais de finisher ;
      - sa vie sous 30 % (`FatalHealth`), soit 960 PV sur 3 200. Sa seconde vie repart à 45 % (1 440 PV), jauge pleine ;
      - son COUP FATAL pas encore utilisé : il n'en a qu'un par match, d'un perso à l'autre du relais (`:91`) ;
      - le CPU qui le lance, après un coup qui touche et selon le hasard de son niveau (`FighterAI.luau:496-501`), et un coup qui tue ;
    - **correction de la fiche** : « se verra surtout au labo » est faux pour les bosses. Le labo ne joue que le perso du joueur (`debugCinematic`, `init.server.luau:1945`), et un boss n'est jouable nulle part, même à l'entraînement (`GameModes.validate` ne prend que `KitOrder`). Sa scène ne se verra qu'en défi, et sur les storyboards.
  - **les leçons de la v0.36.9, relevées par la validation** :
    - **ne pas reprendre sa chope** : les trois coups de BLACK SUN sont ceux de la chope de KUROEN, alors que la fiche la rangeait dans « à ne pas recopier ». Pour ASURA : pas de cible saisie à la taille, soulevée au-dessus de sa tête, puis jetée ;
    - **aucun objet qui saute à l'impact** (B-031) : le grand soleil de BLACK SUN apparaît à un point fixe au lieu de suivre les poings, et saute de 3,6 studs au coup mortel. Toute forme qui traverse le coup mortel part d'une vraie pièce et voyage sans saut. Chacune porte un `mark`, et le test les suit **toutes** (celui de BLACK SUN ne suivait que les trois petits soleils) ;
    - **le test « kit sans finisher »** (`CombatSimulation.test`) prend le premier kit sans ligne `Finisher`, les bosses en dernier : aujourd'hui ASURA. Quand ASURA aura sa ligne, il passera tout seul à KUROEN SHIN, et réussira encore. Il échouera exprès (« no kit left without a finisher ») quand KUROEN SHIN aura la sienne : cette livraison-là devra tester la règle autrement, et le noter dans `DECISIONS.md`, sans la supprimer en silence.
- **Persos et systèmes touchés** :
  - NOVA (drones et gantelets, orange FF8A2A) ;
  - KUROEN (éclipse rouge et noire, E0102E) ;
  - ASURA (KAI à quatre bras, boss, or FFD23F) ;
  - KUROEN SHIN (boss, or et blanc) ;
  - fichiers : `MoveData.luau`, `Finishers.luau`, `Locale.luau` (le nom du finisher en français), sons de cinématique (`SoundPalette`), storyboards ;
  - pour ASURA, en plus : `FourArms.luau` si ses bras du bas font un geste nouveau, et les outils de test (`tests/CinematicKit.luau`, `tests/WeaponKit.luau`) pour qu'ils voient ses bras du bas ;
  - aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : forte / gros. Une scène par perso, donc une par livraison : NOVA, puis KUROEN, puis les deux bosses.
  - Pour les bosses, la valeur est moindre : leur scène sera rare (voir « Pour ASURA »).
  - L'effort d'ASURA est un peu plus gros que celui de KUROEN : ses bras du bas sont à montrer aux outils de test.
- **Risques** :
  - les bosses ne déclenchent leur finisher qu'en relais : le joueur amène 2 ou 3 persos et le boss en a déjà mis un K.O. Pour ASURA, il faut en plus sa vie sous 30 % et son COUP FATAL lancé par le CPU. Un boss n'est jouable nulle part, même au labo : la scène se verra rarement en combat, et surtout sur les storyboards ;
  - KUROEN SHIN a déjà un ultime nommé ZERO ABSOLU : TRUE ECLIPSE. Le nom de son finisher devra être différent, comme celui de KUROEN l'a été (BLACK SUN) ;
  - KUROEN SHIN reprend les coups de KUROEN : sa scène, plus tard, devra se distinguer de BLACK SUN (blanc et or, divin) ;
  - ASURA reprend les coups de KAI. Sa scène ne doit pas recopier MAXIMUM KAIENHA et doit montrer ses quatre bras ;
  - décision du 15/10 : le K.O. et l'aura FATAL gardent les effets du jeu, pas ceux du pack VFX.
- **Questions ouvertes** : aucune qui bloque. Production propose le nom et la mise en scène d'ASURA, comme FATAL ERROR pour NOVA et BLACK SUN pour KUROEN. Wilhem pourra les faire refaire d'après ses planches, comme SHIN, TARO, KAI et ZEPHYR en v0.32.0. Pour Wilhem, sans bloquer :
  1. A-t-il une planche ou un nom en tête pour ASURA ? Choix : a) oui, il l'envoie et production la suit ; b) non, production propose. **Recommandation : b)**, la scène se change ensuite comme les autres.
  2. BLACK SUN reprend les trois coups de la chope de KUROEN (genou, coude, paume). Choix : a) on garde ; b) production les change (avec une nouvelle validation). **Recommandation : a)**, sauf s'il trouve en jeu que la scène ressemble trop à la chope. Elle filme ces coups en gros plan avec les soleils noirs, et ne reprend ni l'éclipse, ni le jonglage, ni la tempête de poings.
  3. Comment voir la scène d'ASURA, puisque aucun joueur ne peut la lancer au labo ? Choix : a) sur les storyboards envoyés avec la livraison ; b) avec un bouton du labo réservé à l'accès développeur (une autre idée, à ranger à part). **Recommandation : a)** pour cette livraison.
- **Critères d'acceptation** :
  - chaque perso a sa ligne `Finisher` dans `MoveData.luau` et sa scène dans `Finishers.luau`, avec son plan K.O. et le nom de son finisher ;
  - quand son COUP FATAL tue et qu'il a déjà gagné un round, la scène remplace le fatal classique. Sinon, le fatal classique joue, inchangé ;
  - il y a un seul K.O. et une seule fin de round. En relais, le perso suivant entre après la scène ;
  - la scène n'affiche pas « VICTORY », comme les 19 autres finishers (B-026) ;
  - le nom du finisher a sa traduction dans `Locale.luau` ;
  - les plans sont composés avec `frameOn` ;
  - le storyboard est vérifié au centre et dos au mur (`luau tests/Storyboard.luau -a KIT Fatal - 1 20`, puis avec `wall-left` et `wall-right`) ;
  - les sons ne viennent que de `SoundPalette`, et chaque perso garde sa matière sonore ;
  - le test commun des finishers passe (`Cinematography`) ;
  - le test « dos au mur, des deux côtés » passe pour lui (`Cinematography`, v0.36.5) ;
  - pour chaque nouvelle scène (ASURA, puis KUROEN SHIN) : un test avec `Kit.hiddenShare` (v0.36.6) vérifie qu'à aucune image plus d'un quart du sujet n'est caché par l'autre corps. Il est joué au centre, des deux côtés, dos à chaque mur, et la cible près de chaque mur ;
  - **pour ASURA, en plus** :
    - sa ligne `Finisher` est sur son kit, pas sur celui de KAI, et sa scène est `S.ASURA`. MAXIMUM KAIENHA ne change pas ;
    - ses quatre bras se voient dans la scène et y font autre chose que sa gatling, sa chope ou son FATAL. Ils ne passent jamais dans son corps (test Animation pour toute nouvelle clé de `FourArms`), et les bras du bas ne montent pas devant son visage ;
    - les outils de test voient ses bras du bas (corps mesuré par `Kit.hiddenShare`, pièces que l'on peut viser), ou bien la scène ne vise et n'accroche rien à eux ;
    - un test joue le vrai défi : ASURA contre une équipe de 3. Il met le premier perso K.O., puis son COUP FATAL tue le deuxième : la scène joue, sans VICTORY, et le troisième entre après elle. La même chose dans sa seconde vie. Contre un seul perso, jamais de finisher ;
    - la scène est vérifiée depuis la droite autant que depuis la gauche (au centre, dos au mur, storyboard) ;
    - toutes ses formes portent un `mark`, et aucune ne saute de plus de 0,5 stud d'une image à l'autre dans un même plan, coup mortel compris (B-031) ;
    - son nom ne reprend aucun nom de la liste « les noms déjà pris », y compris ceux de son thème que le test commun ne voit pas ;
    - le test « kit sans finisher » de `CombatSimulation` joue KUROEN SHIN et passe ;
  - les 9 suites passent.
- **Statut** : `en production` : NOVA faite (v0.36.4, FATAL ERROR). **KUROEN fait (v0.36.9, BLACK SUN / SOLEIL NOIR)**, validé le 22/10 et livré le 23/10. **ASURA est le prochain, et rien ne le bloque** : aucune question n'attend Wilhem, et sa seconde vie ne gêne pas (vérifié le 23/10). Puis KUROEN SHIN. L'idée avait été reportée quatre fois, par des bugs passés avant elle :
  - le 18/10 pour B-011 (majeur, corrigé en v0.36.5) ;
  - le 19/10 pour B-017 (majeur, corrigé en v0.36.6) ;
  - le 20/10 pour B-021 (bloquant, corrigé en v0.36.7) ;
  - le 21/10 pour B-020 (majeur, corrigé en v0.36.8, livré le 22/10).
  
  B-023 (CLASSÉ : quitter tôt ne coûte aucun point) reste le seul bug majeur ouvert, mais il est reporté depuis le 22/10 (`BUGS.md`, `DECISIONS.md`). Son plan commence par B-025 (mineur, faisable sans Wilhem), puis attend un relevé sur le jeu publié que seul Wilhem peut lire ; B-023 et B-028 viendront ensuite ensemble. ASURA ne dépend pas de ce chemin.

## I-002 · Étape 4 du pack VFX : les ultimes, puis les arènes et l'interface
- **Date** : 15 octobre 2026.
- **Wilhem** : « Les ultimes (R, ÉVEIL, PORTE), FATAL et FINISHER, les arènes et l'interface arrivent aux étapes 4 à 6. » (LISEZ-MOI de son pack).
- **Interprétation** : c'est la suite du pack VFX de Wilhem.
  - Étape 4 : les ultimes (R, ÉVEIL, PORTE), les FATAL et les FATAL FINISHERS de chaque perso reçoivent les effets dessinés par Wilhem (sceaux, lune, nuages, piliers, ailes…).
  - Étapes 5 et 6 : les arènes, puis l'interface.
- **Ce qui existe** :
  - les étapes 1 à 3 sont branchées (v0.36.0 à v0.36.3) : coups, traînées, impacts, dashs, auras, compétences et passifs des 22 persos ;
  - aujourd'hui, les ultimes, les fatals et les finishers ont leurs effets dessinés par le jeu : la lumière 3D des cinématiques (boules, rayons, anneaux, dômes ; `CinematicController`) ;
  - **le code de l'étape 4 n'est pas dans le pack** : chaque fiche perso du pack dit « Ultimes (R, ÉVEIL, PORTE), FATAL et FINISHER : étape 4 » ;
  - 19 assets du pack sont prévus pour l'étape 4. Ils sont dans `assets/vfx`, sans ID, et le combat ne s'en sert pas :
    - 8 textures : CLOUD_2x2, GLOW_SOFT, LIGHTNING_A, LIGHTNING_C, LIGHTNING_D, MOON, SCREEN_CRACK, SEAL_CIRCLE ;
    - 11 meshes : CLAW3, CONE_FLARE, DOME, FIST_GIANT, FLOOR_DISC, HELIX, PILLAR, SLASH_90, SLASH_360, TWISTER, WING ;
    - le manifeste du pack donne leur usage. Par exemple : SEAL_CIRCLE pour les sceaux d'ultimes et la PORTE, MOON pour MOONFALL et les arènes, WING pour FINAL MERCY et KUROEN SHIN, SCREEN_CRACK pour les FATAL de RYUKEN et AKEMI ;
  - les arènes sont dans `Maps.luau` et `ArenaBuilder.luau`, l'interface dans `UIArt.luau`.
- **Décisions à respecter** (`DECISIONS.md`, 15/10) :
  - « Le PERFECT, l'aura FATAL, le super flash et le K.O. gardent leurs effets du jeu » (Wilhem : « jamais par-dessus le combat ») ;
  - le KIKOHO de KAI reste la boule de ses dessins ;
  - le Red Kamehameha ne coule qu'à l'intérieur du rayon KAIENHA ;
  - un effet du pack ne s'affiche que si tous ses assets ont un ID ;
  - les finishers de SHIN, TARO, KAI et ZEPHYR suivent ses planches (v0.32.0) : leur mise en scène ne doit pas changer.
- **Persos et systèmes touchés** :
  - les 22 persos ;
  - les cinématiques : R, ÉVEIL, PORTE, FATAL, FATAL FINISHERS ;
  - `VfxPack.luau`, `VfxConfig.luau`, `src/client/VFX` ;
  - plus tard, les arènes et l'interface.
- **Valeur / effort** : forte / gros (22 persos × 5 moments, puis les arènes et l'interface).
- **Risques** :
  - la performance sur mobile pendant les ultimes (budget du pack : 40 particules au plus par coup) ;
  - des doublons avec la lumière 3D des scènes actuelles ;
  - les IDs : ces 19 assets s'ajoutent aux 14 meshes déjà attendus.
- **Questions ouvertes** (pour Wilhem) :
  1. Comment avance l'étape 4 ? Choix : a) Wilhem envoie l'étape 4 du pack (code et textures) ; b) production dessine dès maintenant les effets des ultimes avec les 19 assets. **Recommandation : a)**, pour ne pas faire le travail deux fois ni choisir la DA à sa place.
  2. Les IDs des 19 assets (Bulk Import, comme les autres), à envoyer avec ceux des 14 meshes.
  3. Dans les cinématiques, les effets du pack s'ajoutent-ils à la lumière 3D actuelle ou la remplacent-ils ? Choix : a) ils s'ajoutent, la mise en scène reste ; b) ils la remplacent ; c) on décide au cas par cas. **Recommandation : a)**, surtout pour les finishers faits d'après ses planches.
- **Statut** : `à clarifier`. La fiche attend l'étape 4 du pack et les IDs.

## I-003 · Le pack VFX vraiment dans la DA du jeu
- **Date** : 15 octobre 2026.
- **Wilhem** : « hésite pas à retravailler pour que ça rentre vraiment dans ma DA ».
- **Interprétation** : les effets du pack doivent avoir l'air du jeu (taille, couleur, quantité), et non d'une démo posée par-dessus.
- **Ce qui existe** :
  - le pack est branché (v0.36.1) ; ses effets ne peuvent pas être vus en jeu d'ici ;
  - depuis la v0.36.2 (complétée en v0.36.3), les planches d'impact du pack sont au cœur de chaque coup, sous la signature du perso. C'est la suite d'une demande de Wilhem du 16 octobre, « pq t'as pas mis les sprites des impacts sur l'update ?? », rangée en bug B-004 ;
  - la taille et l'éclat des effets ne se règlent qu'à l'œil, dans Studio.
- **Persos et systèmes touchés** : les 22 persos, les VFX du combat (`src/client/VFX`, `VfxPack.luau`). Rien sur le combat ni sur l'équilibrage.
- **Valeur / effort** : forte / moyen (des réglages, une fois qu'on voit ce qui ne va pas).
- **Risques** : la performance sur mobile si les effets restent trop chargés.
- **Questions ouvertes** :
  1. Des captures ou des vidéos en jeu de ce qui ne colle pas : trop gros, trop chargé, mauvaise couleur, ou un effet qu'il préférait avant ?
  2. Le premier retour attendu : les planches d'impact de la v0.36.3 sur les coups (taille, éclat). Il faudrait aussi le message de la console Studio si une texture ne charge pas (B-003).
- **Statut** : `à clarifier`.

## I-004 · Rendre aux joueurs touchés par B-021 leur cote 2v2 / 3v3 et l'étoile de leurs titres
- **Date** : 20 octobre 2026 pour la proposition (routine du matin, v0.36.7). Fiche ouverte le 21 octobre 2026.
- **Wilhem** : rien encore. L'idée ne vient pas de lui : la routine la propose dans `BUGS.md` (B-021, piste) et dans le journal (v0.36.7) : « Récupération proposée, non appliquée, à décider par Wilhem : relire la cote dans les classements 2v2 et 3v3, et rendre l'étoile aux titres à exploit possédés sans achat en boutique. »
- **Interprétation** : à sa prochaine connexion, un joueur touché par B-021 retrouve :
  - sa cote CLASSÉE 2v2 et 3v3 : le menu affiche la dernière qu'il avait, au lieu de 1000 ;
  - l'étoile « gagné en jouant » sur ses titres à exploit qu'il n'a pas achetés (UNTOUCHABLE, COMBO ARTIST, FRAME PERFECT, NO MERCY, FINAL BOSS, BREAKER), sans nouvelle annonce « titre gagné ».
  
  Les compteurs des titres pas encore gagnés (par exemple BREAKER à 24 sur 25) restent perdus : rien ne les garde ailleurs.
- **Ce qui existe** (vérifié le 21 octobre 2026) :
  - la cause est corrigée depuis la v0.36.7 (`src/server/Profile.luau`) : plus personne ne perd ces champs. Une sauvegarde qui les contenait encore à la fin de la dernière session les retrouve seule ;
  - **la cote** :
    - les classements `JeuxCombat_Classement_2v2_v1` et `_3v3_v1` (`Matchmaker.BOARDS`) gardent la dernière cote écrite de chaque joueur. Le serveur ne les écrit que pour une catégorie déjà jouée (`init.server.luau:255-264`) ;
    - un joueur qui n'a pas rejoué en 2v2 ou en 3v3 depuis la perte y a donc encore sa dernière cote ;
    - aujourd'hui, le serveur ne lit ces classements que par le haut (les 10 premiers), jamais la ligne d'un joueur ;
  - **l'étoile** :
    - un titre à exploit n'entre dans la liste des titres (`titles`) que de deux façons : acheté avec des pièces (`Store.buyItem`, qui note aussi l'achat dans `ownedItems`), ou gagné en jouant (`GameModes.grantFeatTitles`) ;
    - `ownedItems` est dans les valeurs par défaut du profil depuis la boutique (v0.20.0) : un achat n'a jamais été perdu ;
    - `!give … title` ne l'ajoute pas à `titles` (B-024). Les Game Pass et les Robux ne donnent aucun de ces six titres ;
    - donc un titre à exploit présent dans `titles` sans achat dans `ownedItems` a forcément été gagné en jouant. On peut lui rendre son étoile sans aucune lecture en plus ;
    - FINAL BOSS revient déjà seul, car son compteur est recalculé à partir des notes des défis (`featBosses`), jamais perdues. Mais il ne revient qu'au combat suivant, avec une seconde annonce ;
  - décision du 20/10 (`DECISIONS.md`) : pas de récupération automatique, elle est seulement proposée. Elle touche la cote CLASSÉE, que les joueurs voient.
- **Persos et systèmes touchés** :
  - aucun perso, rien sur le combat ni l'équilibrage ;
  - le chargement du profil (`init.server.luau`, `Profile.luau`), la cote CLASSÉE (`Matchmaker`), les titres et leur étoile (`GameModes`), les classements (DataStore) ;
  - le menu montre le résultat. Aucun texte nouveau à traduire si le retour se fait en silence.
- **Valeur / effort** : moyenne / petit.
  - Valeur : elle ne concerne que les joueurs touchés, mais c'est leur progression visible (la cote CLASSÉE, et l'étoile qui distingue un titre gagné d'un titre acheté).
  - Effort : pour l'étoile, une règle pure avec un test ; pour la cote, deux lectures au chargement et un test de la règle.
- **Risques** :
  - **des lectures en plus à chaque connexion** :
    - relire la cote coûte deux lectures DataStore (une par classement) pour chaque joueur sans cote 2v2 ou 3v3. C'est le cas de la plupart des joueurs, qui n'ont jamais joué ces modes. Sans limite, ces lectures se feraient à chaque connexion, pour toujours, et pour rien ;
    - elles prennent sur le budget DataStore du serveur, le même que celui des profils et du CLASSÉ entre serveurs ;
    - la parade : **une seule fois par joueur**. Un marqueur dans le profil (un champ de plus dans `Profile.default`, vérifié par le test « saved profile ») n'est posé que si les deux lectures ont répondu. La lecture ne bloque pas l'entrée dans le hub, et elle n'écrase jamais une cote jouée entre-temps ;
  - **des cas où la cote relue est fausse** :
    - le classement est écrit après le profil, à part (`init.server.luau:260`). Si cette écriture a échoué, il garde une cote plus ancienne, et c'est elle qui revient ;
    - un joueur qui a rejoué en 2v2 ou en 3v3 après la perte est reparti de 1000. Sa vraie cote est perdue, et le classement a gardé la nouvelle. La récupération ne peut rien pour lui (elle ne se lance pas, puisqu'il a une cote) ;
    - chaque jour où la v0.36.7 tourne en ligne sans la récupération, des joueurs touchés rejouent et ne peuvent plus être récupérés. Si la v0.36.7 n'est pas encore publiée sur Roblox, mieux vaut publier les deux ensemble ;
    - si un jour une cote est remise à zéro exprès (nouvelle saison, tricheur) sans vider les classements, la relecture la rendrait. Rien ne le fait aujourd'hui, et le marqueur « une seule fois » écarte ce cas ;
  - **des cas où l'étoile est fausse** :
    - un titre acheté puis gagné en jouant ne retrouve pas son étoile, car on ne peut pas le distinguer d'un titre seulement acheté. Le joueur doit refaire l'exploit ;
    - si un jour un titre à exploit est donné autrement (récompense de quête, cadeau du propriétaire sans `ownedItems`), la règle lui mettrait une étoile à tort. Un commentaire dans le code et le test doivent le rappeler.
- **Questions ouvertes** (pour Wilhem) :
  1. Faut-il rendre ce qui a été perdu ? Choix : a) oui, la cote et les étoiles ; b) seulement les étoiles (aucune lecture en plus, aucun risque de valeur fausse) ; c) non, on laisse comme c'est. **Recommandation : a)**, une seule fois par joueur, en silence, et vite : chaque jour, moins de joueurs peuvent retrouver leur cote.
- **Statut** : `à clarifier`. Rendre une cote CLASSÉE que les joueurs voient est un choix de Wilhem (décision du 20/10).
- **Critères d'acceptation** (si Wilhem dit oui) :
  - une règle pure (dans `Profile.luau` ou `GameModes`), testée dans `Lobby.test` :
    - au chargement, un titre à exploit présent dans `titles` et sans achat dans `ownedItems` reçoit son étoile ;
    - un titre acheté n'en reçoit pas, un titre hors des six n'est jamais touché ;
    - aucune annonce « titre gagné » ;
  - à la connexion, pour une catégorie sans cote (`Matchmaker.played` faux), le serveur lit la ligne du joueur dans le classement 2v2 ou 3v3. S'il y trouve un nombre, `Matchmaker.setRating` le rend ; sinon, rien ne change ;
  - une seule fois par joueur : le marqueur figure dans `Profile.default` et n'est posé que si les deux lectures ont répondu. Une lecture en échec est refaite à la connexion suivante ;
  - la lecture ne bloque pas le chargement, et une cote jouée entre-temps n'est jamais écrasée ;
  - le test « saved profile » passe avec le nouveau champ, et les 9 suites passent ;
  - rien n'est affirmé testé sur le vrai DataStore : Wilhem confirme en jeu (un joueur touché revoit sa cote 2v2).
