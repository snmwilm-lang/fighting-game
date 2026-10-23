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

Dernier tri : 22 octobre 2026 (routine du matin).

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : 12 octobre 2026 pour l'idée (v0.27.0) ; ces quatre persos attendent depuis la v0.33.0.
- **Wilhem** :
  - « une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue » (rappelé en tête de `Finishers.luau`) ;
  - la règle : « seulement sur la deuxième vie… si l'adversaire n'a pas peu d'HP et l'utilisateur du final n'a pas déjà un round gagné, le FATAL FINISHER s'active pas, il y a juste le fatal classique » (journal, v0.27.0).
- **Interprétation** : quand le COUP FATAL de l'un de ces quatre persos tue, le joueur voit une scène d'environ 10 s propre au perso. Cette scène est le K.O. lui-même, avec le nom du finisher.
- **Ce qui existe** (vérifié le 22 octobre 2026) :
  - 19 persos ont leur finisher : une ligne `Finisher = { Name, Length, FinalTick }` dans `MoveData.luau` et une scène `S.KIT` dans `Finishers.luau` ;
  - **NOVA est faite (v0.36.4)** : FATAL ERROR (ERREUR FATALE), 11 s. Huit drones se rangent en rail d'anneaux devant son gantelet, puis un compte 3-2-1-0 et un seul tir ; la cible « bugue », puis tombe. « ZERO HOUR » a été écarté (décision du 17/10) ;
  - la scène de NOVA a trois bugs relevés le 18/10 : B-012 (la visière dans sa tête) est ouvert ; B-013 (le rail posé sur une main mesurée au labo) et B-014 (9 lumières à la fois) attendent que Wilhem les confirme en jeu. Ils se suivent dans `BUGS.md` et ne rouvrent pas l'idée ;
  - KUROEN, ASURA et KUROEN SHIN n'ont **ni ligne ni scène**. Ils jouent encore le fatal classique ;
  - un test commun aux finishers existe depuis la v0.36.4 (`Cinematography`). Il vérifie : au moins 6 plans propres au perso, un nom unique qui n'est le nom d'aucun coup d'un autre perso, le K.O. après le coup mortel, la cible à terre, des sons de la palette ;
  - depuis la v0.36.5, `Cinematography` joue aussi chaque finisher avec l'attaquant dos au mur, à gauche puis à droite (38 tests). Un perso qui reçoit sa ligne `Finisher` y entre tout seul ;
  - depuis la v0.36.6, `Cinematography` joue aussi les COUPS FATAUX classiques des 22 kits dos au mur, des deux côtés (44 tests). Celui de KUROEN, TOTAL ECLIPSE, y passe ;
  - depuis la v0.36.6, l'outil `Kit.hiddenShare` (`tests/CinematicKit.luau`) mesure quelle part du sujet d'un plan est cachée par l'autre corps. Pour l'instant, seuls les 4 tests ISSEN de SHIN s'en servent (décision du 19/10) : contrairement au test « dos au mur », **un nouveau finisher n'y entre pas tout seul** ;
  - la règle de déclenchement existe déjà dans `CombatSimulation` : un COUP FATAL qui tue, lancé par un perso qui a déjà gagné un round (ou mis K.O. un perso d'un relais). Il n'y a rien à changer ;
  - **depuis la v0.36.8 (B-020)**, « qui tue » a un sens précis. `startCinematic` sépare deux choses :
    - `fells` : le coup abat la cible (l'ancienne condition, inchangée) ;
    - `finish` : la scène joue sa version K.O. C'est `fells`, sauf si la cible va se relever (la première vie d'ASURA, seul kit avec une seconde vie) ;
    - le finisher ne se choisit que sur `finish`. Il ne se joue donc que sur un vrai K.O. : après sa scène, la cible ne se relève jamais ;
  - **pour la scène de KUROEN, rien à prévoir** :
    - si son COUP FATAL abat ASURA dans sa première vie, c'est son fatal classique, TOTAL ECLIPSE, qui joue sa version « cible debout ». Puis ASURA se relève. C'est déjà fait, et le finisher n'y entre pas ;
    - pour voir sa scène au labo ou dans un test, il faut une autre cible qu'ASURA dans sa première vie : le labo suit la même règle. Les outils de test prennent KAI par défaut (`tests/CinematicKit.luau`) ;
    - plus tard, KUROEN SHIN n'a pas de seconde vie : un finisher se joue contre lui comme contre les autres (test de garde de la v0.36.8).
- **Pour KUROEN (la prochaine), ce que production doit savoir** :
  - **son identité** : 蝕, l'empereur de l'éclipse. Rouge E0102E et noir, « courts et brutaux » (fiche VFX 6.20). Il frappe avec les poings, les coudes, les genoux et des rafales de ki rouge à cœur noir, et laisse un petit soleil noir à l'impact (`KitFX`). Sa jauge DOMINATION a trois niveaux : trois marques rouges dans le dos, et au niveau III, ÉCLIPSE. Son son : des gantelets sur l'os, et un boom sourd en salle sur les gros coups (`SoundPalette.KUROEN`). Son allure : crinière blanche à mèches rouges, peau sombre, yeux rouges, tenue noire déchirée ;
  - **ses ultimes, à ne pas recopier** (`CinematicDirector`, `GEN.add("KUROEN")`) :
    - R, EMPEROR RUSH : des coups de tous les côtés, de plus en plus vite ; le dernier projette la cible ;
    - ÉVEIL, ZERO ABSOLU : ECLIPSE : la lumière s'éteint, une éclipse rouge apparaît dans le ciel, et il frappe depuis le noir ;
    - PORTE, EMPEROR'S GATE : une tempête de poings ;
    - FATAL, TOTAL ECLIPSE : le dernier coup sous l'éclipse (jonglage, couronne, dôme noir) ;
    - sa chope, CLINCH DE L'ÉCLIPSE : un genou, le coude sur la tête, puis la paume de ki à bout portant ;
    - l'éclipse dans le ciel est déjà prise deux fois : par son ÉVEIL, et par la PORTE de DAICHA (sa sphère devient un disque noir) ;
  - **les noms déjà pris** :
    - les 19 finishers : MAXIMUM KAIENHA, DEMPSEY ROLL: FINAL ROUND, GALE EXCALIBUR, THOUSAND SHADOWS, TEN FISTS OF RAGE, FINAL DIVISION, INVERTED WORLD, THRONE OF RUINS, SPEAR OF THE THUNDER GOD, FROZEN REQUIEM, TOXIC FEAST, TITAN QUAKE, STELLAR COLLAPSE, RESONANCE, CAGE OF CLAWS, CRIMSON COVENANT, THE GREAT HUNT, FINAL MERCY, FATAL ERROR ;
    - ses ultimes et ceux de KUROEN SHIN : EMPEROR RUSH, ZERO ABSOLU : ECLIPSE, EMPEROR'S GATE, TOTAL ECLIPSE, DIVINE EMPEROR RUSH, ZERO ABSOLU : TRUE ECLIPSE, ETERNAL ECLIPSE ;
    - les autres noms en ECLIPSE et en EMPEROR : HALF ECLIPSE (DAICHA), ECLIPSE BREAKER, ECLIPSE KICK, ECLIPSE CLINCH, DIVINE ECLIPSE, EMPEROR STEP, EMPEROR'S DECREE, FALLING EMPEROR, TRUE EMPEROR, TRUE EMPEROR'S EQUAL (un titre de défi) ;
    - « ZERO » reste à sa famille (décision du 17/10). Mais un troisième « ZERO ABSOLU » se confondrait avec son ÉVEIL ; B-009 montre ce qui arrive quand le nom d'un finisher reprend celui d'un ÉVEIL (ASTER) ;
    - KUREN (CRIMSON COVENANT) a presque le même rouge (D0102E) : la scène doit se lire « éclipse », noir et rouge avec un soleil noir, et non « sang » ;
  - **ce qu'ont appris les dernières livraisons** :
    - v0.36.5 (B-011, B-010) : sa scène doit passer le test « dos au mur, des deux côtés » de `tests/Cinematography.test.luau`. Pour la voir ainsi : `luau tests/Storyboard.luau -a KUROEN Fatal - 1 20 wall-left`, puis `wall-right` ;
    - prévoir son placement dès le départ avec `room`, dans `Finishers.luau`, comme SHIN : près d'un mur, toute la scène recule, jamais lui seul. Sinon, un perso collé au mur se retrouve trop près de l'autre, et la caméra d'un gros plan tombe dans un corps. La v0.36.6 a fait de même pour le fatal classique de SHIN (`FATAL.room`, dans `CinematicDirector.luau`). Les finishers de KUREN et de TARO montrent ce qui arrive sans `room` : dos au mur, leur visage est caché aux deux tiers à l'ouverture (B-018, ouvert) ;
    - garder les deux corps sur le sol de combat, x de -28 à 28 : 11 finishers sur 19 en sortent (B-015, confirmé le 19/10), surtout quand **la cible** est près du mur. Il faut donc jouer aussi la cible près de chaque mur, comme les tests ISSEN (la scène centrée à ±25). `room` sert aussi à ça ;
    - v0.36.6 (B-017) : la mesure `Kit.hiddenShare` (`tests/CinematicKit.luau`) compte la part du sujet d'un plan (27 points de la pièce visée) que l'autre corps cache à la caméra. Sa scène doit la passer : **jamais plus d'un quart du sujet caché**, à chaque image, au centre et dos à chaque mur. Le test commun ne l'applique pas encore : production ajoute un test pour la scène de KUROEN dans `Cinematography`, sur le modèle des tests ISSEN (fonction `issen`). La mesure se fait sur le rig KAI du labo, et les vrais avatars n'ont pas sa taille (B-018) : garder de la marge ;
    - la jouer aussi **depuis la droite**, au centre : le labo ne joue que depuis la gauche. Sa propre PORTE le montre : à l'ouverture (`kuroen-gate-backturn`), il tourne le dos avec un angle fixe ; depuis la droite, sa tête est alors cachée derrière la cible à 76 % en moyenne (B-019, ouvert). Un plan où il se retourne doit avoir un angle qui dépend du côté ;
    - poser ses formes (ki, soleil noir) sur les vraies pièces du corps, par exemple `P(A, "RightHand")`, et non sur des nombres mesurés sur le rig du labo (B-013). Un trait posé sur sa tête doit bien sortir de la tête (B-012) ;
    - au plus une lumière allumée à la fois, comme les 18 premiers finishers : NOVA en allume 9 et c'est la scène la plus lourde du jeu (B-014, mobile et mode réduit) ;
    - chasse du 21/10 (B-026, ouvert) : la scène K.O. de l'ÉVEIL et de la PORTE écrit « · VICTORY » même quand le match continue. Aucun finisher n'écrit « VICTORY », et celui de KUROEN ne doit pas le faire non plus : en relais, son finisher peut tomber sans finir le match, et le perso suivant entre après la scène.
- **Persos et systèmes touchés** :
  - NOVA (drones et gantelets, orange FF8A2A) ;
  - KUROEN (éclipse rouge et noire, E0102E) ;
  - ASURA (KAI à quatre bras, boss, or FFD23F) ;
  - KUROEN SHIN (boss, or et blanc) ;
  - fichiers : `MoveData.luau`, `Finishers.luau`, `Locale.luau` (le nom du finisher en français), sons de cinématique (`SoundPalette`), storyboards ;
  - aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : forte / gros. Une scène par perso, donc une par livraison : NOVA, puis KUROEN, puis les deux bosses.
- **Risques** :
  - les bosses ne déclenchent leur finisher qu'en relais : le joueur amène 2 ou 3 persos et le boss en a déjà mis un K.O. La scène sera rare en combat et se verra surtout au labo ;
  - KUROEN a déjà un ultime nommé ZERO ABSOLU : ECLIPSE, et KUROEN SHIN un ZERO ABSOLU : TRUE ECLIPSE. Le nom du finisher doit être différent (voir les noms pris plus haut) ;
  - KUROEN SHIN reprend les coups de KUROEN : sa scène, plus tard, devra se distinguer de celle de KUROEN (blanc et or, divin) ;
  - ASURA reprend les coups de KAI. Sa scène ne doit pas recopier MAXIMUM KAIENHA et doit montrer ses quatre bras ;
  - décision du 15/10 : le K.O. et l'aura FATAL gardent les effets du jeu, pas ceux du pack VFX.
- **Questions ouvertes** : aucune qui bloque. Production propose le nom et la mise en scène de KUROEN, comme FATAL ERROR pour NOVA. Wilhem pourra les faire refaire d'après ses planches, comme SHIN, TARO, KAI et ZEPHYR en v0.32.0.
  - Pour Wilhem, sans bloquer : a-t-il une planche ou un nom en tête pour KUROEN ? Choix : a) oui, il l'envoie et production la suit ; b) non, production propose. **Recommandation : b)**, la scène se change ensuite comme les autres.
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
  - pour chaque nouvelle scène (KUROEN, puis ASURA et KUROEN SHIN) : un test avec `Kit.hiddenShare` (v0.36.6) vérifie qu'à aucune image plus d'un quart du sujet n'est caché par l'autre corps. Il est joué au centre, des deux côtés, et dos à chaque mur ;
  - les 9 suites passent.
- **Statut** : `en production` : NOVA faite (v0.36.4, FATAL ERROR). **KUROEN faite (v0.36.9, BLACK SUN / SOLEIL NOIR)**, validée le 22/10 et livrée le 23/10. ASURA est le prochain, puis KUROEN SHIN. B-023 a été reporté ce matin (`BUGS.md`). Elle avait été reportée quatre fois, par des bugs passés avant elle :
  - le 18/10 pour B-011 (majeur, corrigé en v0.36.5) ;
  - le 19/10 pour B-017 (majeur, corrigé en v0.36.6) ;
  - le 20/10 pour B-021 (bloquant, corrigé en v0.36.7) ;
  - le 21/10 pour B-020 (majeur, corrigé en v0.36.8, livré le 22/10).
  
  Il reste un seul bug majeur ouvert : B-023 (CLASSÉ : quitter dans les 25 premières secondes, ou avec moins de 20 actions, ne coûte aucun point). Il passera avant KUROEN s'il est faisable sans Wilhem. Sa fiche (`BUGS.md`) demande de le corriger en même temps que B-028 (une mise à jour du serveur compte comme un abandon), et laisse deux choix à production : la cote n'est plus à somme nulle, et un départ subi est puni comme un abandon. Sinon, KUROEN passe. Viendront ensuite ASURA et KUROEN SHIN.

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
