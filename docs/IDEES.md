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

Dernier tri : 1er novembre 2026 (routine du matin, sur la v0.36.15, HEAD 889b22a, livrée ce matin : ZENITH, le FATAL FINISHER de KUROEN SHIN). Aucune idée nouvelle de Wilhem depuis le 27/10 : aucune fiche « nouvelle ». I-001 est `faite (v0.36.15)` et resserrée : son détail de production est dans l'historique du dépôt (`git show 889b22a:docs/IDEES.md`), ses leçons restent. I-005 reste `prête`, mise à jour avec les outils de ZENITH, maintenant dans le dépôt. I-002, I-003 et I-004 : rien n'a bougé, elles attendent Wilhem.

Tri précédent : 31 octobre 2026 (sur HEAD 2d11414, pendant que la production refaisait ZENITH).

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : 12 octobre 2026 pour l'idée (v0.27.0) ; ces quatre persos attendaient depuis la v0.33.0. Close le 1er novembre 2026 (v0.36.15).
- **Wilhem** :
  - « une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue » (rappelé en tête de `Finishers.luau`) ;
  - la règle : « seulement sur la deuxième vie… si l'adversaire n'a pas peu d'HP et l'utilisateur du final n'a pas déjà un round gagné, le FATAL FINISHER s'active pas, il y a juste le fatal classique » (journal, v0.27.0).
- **Interprétation** : quand le COUP FATAL de l'un de ces quatre persos tue, le joueur voit une scène d'environ 10 s propre au perso. Cette scène est le K.O. lui-même, avec le nom du finisher.
- **Ce qui est fait** : les 22 persos ont leur FATAL FINISHER (les 20 jouables, ASURA et KUROEN SHIN). Pour ces quatre, une scène par livraison :
  - **NOVA (v0.36.4)** : FATAL ERROR (ERREUR FATALE), 11 s. Huit drones se rangent en rail d'anneaux devant son gantelet, un compte 3-2-1-0, un seul tir ; la cible « bugue », puis tombe. « ZERO HOUR » a été écarté (décision du 17/10). Suivis dans `BUGS.md` : B-012, B-013, B-014 ;
  - **KUROEN (v0.36.9)** : BLACK SUN (SOLEIL NOIR), 10,7 s. Les trois marques de DOMINATION s'allument dans son dos ; trois coups (genou, coude, paume) laissent chacun un petit soleil noir sur la cible ; les trois soleils n'en font plus qu'un dans son poing levé, puis AXE OF NIGHT abat la cible des deux poings. Ses trois coups sont ceux de sa chope, ECLIPSE CLINCH : assumé, à revoir par Wilhem (`DECISIONS.md`, 22/10). Suivi : B-031 ;
  - **ASURA (v0.36.12)** : SAMSARA, 10,7 s, coup mortel au tick 430 (`S.ASURA`, `Finishers.luau:3264`). Son dos dans l'aura noire, le sol fendu en X ; ses quatre bras jetés en X devant une roue d'or ; ses quatre poings qui prennent feu un à un ; deux paumes ouvrent la garde de la cible, deux poings entrent dans le ventre ; elle retombe face contre terre dans la roue gravée au sol. Le nom (décision du 26/10) : la roue des renaissances, où ASURA se relève et sa cible non. Ses trois plans mal cadrés sont devenus **I-005**. Suivi : B-040 (`asura-ss-blown`) ;
  - **KUROEN SHIN (v0.36.15, 1/11)** : ZENITH (ZÉNITH), 11 s, coup mortel au tick 440, 13 plans (`S["KUROEN SHIN"]`). Le boss que Wilhem voulait « cassé comme Gogeta » (journal, v0.17.0) : debout et calme, les mains basses ; la cible frappe deux fois et traverse chaque fois une image rémanente de lui (l'INSTINCT DIVIN) ; elle se retourne dans son JAB, arrêté à un pouce de sa poitrine ; trois ondes sortent de son dos, une ligne d'or se grave au sol ; il lui tourne le dos, et, vue du zénith, elle est face contre terre à ses pieds. Livré avec sa matière sonore (B-033 corrigé par `SoundPalette.materialOf`, ASURA compris). Validé du premier coup après deux refus le 30/10 et une refonte complète. Suivi : B-051 (remarques de la validation, cosmétiques).
- **Le détail de production est dans l'historique du dépôt** :
  - la préparation d'ASURA : `git show 8c1c308:docs/IDEES.md` ;
  - la fiche de production de KUROEN SHIN (où brancher la scène, son identité, ce qu'il ne fallait pas recopier, les noms usés et refusés, les pièges, B-033, le test « kit sans finisher », les fichiers) et ses critères : `git show 889b22a:docs/IDEES.md` ;
  - les choix de chaque scène sont dans `DECISIONS.md` (17/10, 22/10, 26/10, 31/10).
- **Ce qui existe pour tous** (sur HEAD 889b22a) :
  - chaque kit a une ligne `Finisher = { Name, Length, FinalTick }` dans `MoveData.luau` et une scène dans `Finishers.luau` (`S.KIT`, ou `S["KUROEN SHIN"]` pour un nom avec une espace), cherchée sous le nom du kit de l'attaquant (`CinematicDirector.luau:5179`) ;
  - la règle de déclenchement (`CombatSimulation`) n'a pas changé : un COUP FATAL qui tue vraiment (B-020), lancé par un perso qui a déjà gagné une manche, ou mis K.O. un perso d'un relais ;
  - le test « kit sans finisher » rejoue la règle sur une copie de `MoveData`, chaque kit tour à tour (décision du 31/10) : il vaut pour tout perso ajouté plus tard ;
  - le labo des cinématiques (`tests/CinematicKit.luau`) prend, depuis la v0.36.15, une cible au choix (`foe`), la cible collée au mur (`wall = "target"`, x = ±27,5), l'orientation de chaque corps (`yaws`, et `clientYaws` comme la tourne le client, B-048) et l'écart entre deux pièces (`Kit.boxGap`). Les tests de ZENITH (`tests/Cinematography.test.luau:944-1361`) sont le modèle le plus complet pour une nouvelle scène.
- **Pour chaque nouvelle scène, ce qu'ont appris les livraisons** (à garder : pour I-005, pour toute reprise d'après une planche de Wilhem, pour tout perso ajouté) :
  - **les placements** : au centre des deux côtés, dos à chaque mur, la cible près de chaque mur et collée contre lui (`wall = "target"`). Prévoir `room` dès le départ (`Finishers.luau:44-48`) : près d'un mur, toute la scène recule, jamais le perso seul (B-011, B-018). Chaque coin de chaque pièce des deux corps reste sur le sol, x de -28 à 28 (B-015) ;
  - **le côté** : la jouer aussi depuis la droite. En défi, un boss frappe depuis la droite ; un plan où le perso se retourne a un angle qui dépend du côté (B-019) ;
  - **les cibles** : la jouer contre les 20 persos jouables, armes comprises (`foe`, `WeaponKit.pieces`) : rien de la cible n'entre dans l'attaquant (B-047). La règle du quart mesurée sur KAI seul ne suffit pas : la validation de ZENITH a trouvé la tête de VENOM cachée à 33 % (B-051) ;
  - **le sujet caché** (`Kit.hiddenShare`) : jamais plus d'un quart du sujet caché par l'autre corps, à chaque image et à chaque placement, avec de la marge (le rig du labo n'a pas la taille des vrais avatars, B-018) ;
  - **le cadre** (les leçons de SAMSARA) : le sujet entier dans le cadre, ou tout à fait dehors ; aucune forme plate (roue, sceau, disque) vue à plus de 70° de sa face ; pas plus de 30° de plongée sur le sujet ; ses mains jamais cachées par son propre corps, ce que `Kit.hiddenShare` ne mesure pas seul ;
  - **rien ne saute dans un plan** : la tête de la cible pas plus de 2 studs d'une image à l'autre, la caméra pas plus de 1,5 stud, aucun corps ne tourne de plus de 21° par image, mesuré comme le labo et comme le client (B-040, B-041, B-046, B-048). Une disparition, une réapparition, une chute face contre terre ou un demi-tour se font sur une coupe, ou caché (`a.hidden = true`), et le plan qui tient se compose sur des points fixes ;
  - **les formes** : posées sur les vraies pièces du corps (B-013) ; un trait posé sur une tête en sort (B-012) ; une seule lumière à la fois (B-014) ; chaque forme porte un `mark` et ne saute pas de plus de 0,5 stud, coup mortel compris (B-031) ;
  - **la scène** : aucune chope reprise ; jamais « VICTORY » ni pose de victoire (B-026 : en relais, un finisher peut tomber sans finir le match) ;
  - **le nom** : le test des noms des bosses refuse les mots usés, mais laisse passer un nom égal à un texte du jeu et les mots de 3 lettres (GOD, SUN, SKY) : vérifier à la main avant de l'ajouter à `Locale`. Pas de nom en ECLIPSE, EMPEROR, DIVINE, TRUE ou ZERO, pas de kanji (décision du 22/10) ;
  - **le son** : un boss a sa propre matière (`SoundPalette.materialOf`, B-033). Le test commun accepte la matière de KAI : il ne verrait pas un perso qui sonne comme un autre ;
  - **la méthode** : un correctif ne doit pas en aggraver un autre, ce qui se touche se mesure ensemble (le second refus du 30/10, B-046 et B-047) ; un travail non livré se garde en patch dans le dépôt (`docs/attente/`), jamais seulement dans le scratchpad, qui peut disparaître.
- **Les retours de Wilhem sur les bras d'ASURA**, à garder pour toute retouche (journal v0.15.1, v0.16.1 et v0.23.20) : « les deux autres bras d'ASURA sortent des côtés normalement » ; « travaille les 4 bras d'ASURA, c'est dégueulasse » ; « ce bug avec les bras d'ASURA, les bras du bas se lèvent, règle-le » (capture en cinématique) ; « ASURA, ses bras, la deuxième paire, rends-la agréable ». Les bras du bas ne montent pas devant son visage et ne passent jamais dans son corps (test Animation, poses de `FourArms.SCENE`). Deux autres règles de Wilhem tiennent pour lui : chacun de ses coups a sa propre pose (« chaque animation est obligatoirement différente ») ; ses deux victoires viennent des images d'Asura's Wrath qu'il a envoyées (« tu peux alterner les deux »), et restent à la fin du match, jamais dans un finisher.
- **Persos et systèmes touchés** : NOVA, KUROEN, ASURA, KUROEN SHIN ; les cinématiques (`Finishers.luau`), le son (B-033), les tests. Aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : forte / gros, en quatre livraisons (du 17/10 au 1/11).
- **Risques restants** : les scènes des bosses sont rares en combat (un défi en relais, leur vie sous 30 %, leur COUP FATAL prêt) et se voient surtout sur les storyboards ; rien n'est vu dans Studio (ni ZENITH, ni l'or de SAMSARA sur l'aura noire, ni les sons de B-033 à l'oreille).
- **Questions ouvertes** (pour Wilhem, sans rien bloquer) :
  1. Veut-il renommer ZENITH, FATAL ERROR, BLACK SUN ou SAMSARA, ou refaire l'une de ces scènes d'après une planche ? Choix : a) oui, il envoie le nom ou la planche ; b) non, on garde. **Recommandation : b)**. Un nom se change avec une ligne de `MoveData` et une de `Locale` ; une planche devient sa propre fiche, un perso par fiche. Les finishers de SHIN, TARO, KAI et ZEPHYR, faits d'après ses planches, ne changent pas sans lui (décision du 15/10) ;
  2. BLACK SUN reprend les trois coups de la chope de KUROEN (genou, coude, paume). Choix : a) on garde ; b) production les change. **Recommandation : a)**, sauf s'il trouve en jeu que la scène ressemble trop à la chope ;
  3. Comment voir les scènes des bosses, qu'aucun joueur ne lance au labo ? Choix : a) sur les storyboards envoyés avec la livraison ; b) un bouton du labo réservé à l'accès développeur (une autre idée, à ranger à part). **Recommandation : a)**.

  Dans `BUGS.md`, attendent aussi son avis : l'ombre presque noire de l'image rémanente de ZENITH (B-051), le nom du COUP FATAL de KUROEN (B-034), celui du finisher d'ASTER (B-009), et B-013 et B-014 (NOVA, à confirmer en jeu).
- **Critères d'acceptation** (remplis pour les quatre) : sa ligne `Finisher` et sa scène ; la scène remplace le fatal classique seulement quand le COUP FATAL tue et que le perso a déjà gagné une manche ; un seul K.O., une seule fin de manche, le perso suivant entre après la scène en relais ; jamais « VICTORY » ; le nom traduit dans `Locale.luau` ; des plans composés avec `frameOn` ; le storyboard vérifié au centre, depuis la droite et dos à chaque mur ; des sons de `SoundPalette` seulement, dans la matière du perso ; le test commun, « dos au mur » et `Kit.hiddenShare` passent ; les 9 suites passent. Les critères ajoutés pour KUROEN SHIN sont dans `git show 889b22a:docs/IDEES.md`.
- **Statut** : `faite (v0.36.15)`. NOVA (v0.36.4), KUROEN (v0.36.9), ASURA (v0.36.12), KUROEN SHIN (v0.36.15). La suite se suit ailleurs, sans rouvrir l'idée : les trois plans de SAMSARA dans I-005 (`prête`) ; les défauts dans `BUGS.md` (B-012, B-031, B-040, B-041, B-048, B-051, et B-015, B-018, B-019 pour les autres finishers).
  - Historique : l'idée a été reportée neuf matins entre le 18 et le 28/10 par des bugs passés avant elle, puis ZENITH a été bloqué le 30/10 par deux refus de la validation (B-015, puis B-046 et B-047), refait de zéro les 31/10 et 1/11, et validé du premier coup.

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
- **Statut** : `à clarifier`. La fiche attend Wilhem : l'étape 4 du pack (question 1), les IDs (question 2) et le choix « s'ajouter ou remplacer » (question 3).
  - **Revue le 1/11** (HEAD 889b22a, v0.36.15) : rien n'a bougé. Aucun fichier du pack (`assets/vfx`, `VfxConfig.luau`, `src/client/VFX`, `VfxPack.luau`) n'a changé depuis la v0.36.3 (16/10). `WING`, prévu pour ELIAN et KUROEN SHIN, est toujours à 0 (`VfxConfig.luau:151`) ;
  - les livraisons depuis (v0.36.4 à v0.36.15) n'ont rien ajouté au pack. Les quatre finishers livrés depuis (FATAL ERROR, BLACK SUN, SAMSARA, ZENITH) sont faits avec les effets du jeu (ZENITH : l'image rémanente, les ondes, la ligne d'or) : ils entrent tous dans la question 3, comme les autres scènes. Les ajouts à l'interface (v0.36.13, v0.36.14) n'utilisent pas le pack.

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
- **Statut** : `à clarifier`. Aucun retour de Wilhem au 1/11. Les fichiers du pack n'ont pas changé depuis la v0.36.3 (16/10), et la v0.36.15 (ZENITH) n'y touche pas. Rien ne peut avancer ici sans ses captures ou ses retours en jeu.

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
    - les classements `JeuxCombat_Classement_2v2_v1` et `_3v3_v1` (`Matchmaker.BOARDS`) gardent la dernière cote écrite de chaque joueur. Le serveur ne les écrit que pour une catégorie déjà jouée, dans `writeProfile`, après une écriture réussie du profil (`init.server.luau:283-292` de la v0.36.10) ;
    - un joueur qui n'a pas rejoué en 2v2 ou en 3v3 depuis la perte y a donc encore sa dernière cote ;
    - aujourd'hui, le serveur ne lit ces classements que par le haut (les 10 premiers), jamais la ligne d'un joueur ;
  - **l'étoile** :
    - un titre à exploit n'entre dans la liste des titres (`titles`) que de deux façons : acheté avec des pièces (`Store.buyItem`, qui note aussi l'achat dans `ownedItems`), ou gagné en jouant (`GameModes.grantFeatTitles`) ;
    - `ownedItems` est dans les valeurs par défaut du profil depuis la boutique (v0.20.0) : un achat n'a jamais été perdu ;
    - `!give … title` ne l'ajoute pas à `titles` (B-024). Les Game Pass et les Robux ne donnent aucun de ces six titres ;
    - donc un titre à exploit présent dans `titles` sans achat dans `ownedItems` a forcément été gagné en jouant. On peut lui rendre son étoile sans aucune lecture en plus ;
    - FINAL BOSS revient déjà seul, car son compteur est recalculé à partir des notes des défis (`featBosses`), jamais perdues. Mais il ne revient qu'au combat suivant, avec une seconde annonce ;
  - décision du 20/10 (`DECISIONS.md`) : pas de récupération automatique, elle est seulement proposée. Elle touche la cote CLASSÉE, que les joueurs voient ;
  - **relu le 25/10 sur la v0.36.10** (B-025 et B-032, livrée le 24/10). Elle a changé le chargement et l'écriture du profil (`DECISIONS.md`, 23/10) :
    - chaque visite d'un joueur est une session (`SaveQueue`) ;
    - une nouvelle visite attend que l'ancienne libère le profil, jusqu'à 65 s (`SaveQueue.held`, `init.server.luau:159-164`), puis le verrou d'un autre serveur (`:168-217`) ;
    - `writeProfile` (`:253-302`) est le seul point d'écriture du profil. Il n'écrit qu'un profil chargé par sa propre session (« unloaded »), et plus jamais un profil qu'un autre serveur a pris (« lost ») ;
    - le verrou d'un profil chargé est réécrit dès qu'il a 20 s, au vidage suivant (toutes les 15 s), même sans changement (`SaveQueue.RENEW`).

    **Ce que cela change pour la récupération** (à suivre si Wilhem dit oui) :
    - **où** : dans `loadProfile` (`:151-226`), une fois la session chargée (`SaveQueue.loaded`, `:205`), dans son propre fil, pour ne pas retarder l'entrée dans le hub. Jamais sur une session « SAVES UNAVAILABLE » (`:218-224`) : `writeProfile` refuserait d'écrire, et les lectures seraient perdues ;
    - **après chaque lecture** (elle attend la réponse du DataStore) : vérifier que c'est toujours la même visite (`clients[player] == client`, comme le chargement en `:163` et `:180`), et que la catégorie n'a toujours pas de cote (`Matchmaker.played` faux). Sinon, ne rien changer ;
    - **l'écriture** : la récupération n'écrit rien elle-même. Elle change le profil en mémoire (`Matchmaker.setRating`, l'étoile, le marqueur), puis `saveProfile(player, client)` le marque, et le vidage suivant l'écrit par `writeProfile`, comme le reste. Si un autre serveur a pris le profil (« lost »), rien n'est écrit d'ici, ni la cote ni le marqueur : la récupération se refera au prochain chargement. La règle « une seule fois » tient ;
    - **le classement** : après `setRating`, la catégorie compte comme jouée. L'écriture suivante remet donc la même cote dans le classement (`:284-291`) : une écriture de plus, sans effet ;
    - **le budget** : les renouvellements du verrou (2 écritures par minute pour un joueur inactif) et les essais d'un chargement qui attend un autre serveur (un toutes les 3 s) prennent aussi sur le budget DataStore du serveur. Raison de plus pour ne faire les deux lectures qu'une fois par joueur.

    Rien de cela ne change la question posée à Wilhem, ni la recommandation. La fiche reste à clarifier : la réponse attend toujours Wilhem.
  - **relu le 26/10 sur la v0.36.11** (B-023 et B-028 en partie, livrée le 25/10) :
    - **ce qui ne bouge pas** : le chargement et l'écriture du profil, `Profile.luau` et `Matchmaker.luau`. La v0.36.11 ne touche `init.server.luau` qu'après la ligne 580 : toutes les lignes citées plus haut tiennent (`:151-226`, `:159-164`, `:168-217`, `:205`, `:218-224`, `:253-302`, `:283-292`) ;
    - **ce qui change** : `endVersus` compte maintenant chaque place avec sa propre part (`AntiCheat.versusShares`, décision D1 du 25/10). En CLASSÉ 2v2 ou 3v3, celui qui part perd toujours ses points, même à la première seconde. Pour un joueur touché par B-021, la cote d'une catégorie sans cote vaut 1000 (`Matchmaker.ratingOf`). Il repart donc de 1000, moins sa perte, et la catégorie compte comme jouée (`Matchmaker.played`) : la récupération ne se lancera plus pour lui. Avant la v0.36.11, un départ dans les 25 premières secondes ne touchait pas sa cote, et il restait récupérable. C'est une façon de plus de devenir irrécupérable : la recommandation « vite » compte encore plus ;
    - **sans effet** : celui qui reste après un départ rapide (part 0) ne reçoit aucune cote, et reste récupérable. Un match arrêté par une mise à jour (NO CONTEST, décision D3) ne touche à aucune cote ;
    - **B-035** (trouvé par la chasse du 25/10, mineur, ouvert) touche la même fenêtre : pendant l'attente du chargement, un CLASSÉ se lance sur le profil par défaut, à 1000. La récupération part après `SaveQueue.loaded`, donc après la fusion : sa règle tient. Il reste un cas rare. Un joueur touché fait sa première visite depuis la v0.36.7 : sa sauvegarde n'a pas encore de champ `ratings`. S'il finit un CLASSÉ 2v2 ou 3v3 pendant l'attente, la fusion garde la cote jouée sur 1000, faute de champ à reprendre dans la sauvegarde (`Profile.merge`), et la récupération ne se lance plus. Si sa sauvegarde a déjà ce champ, la fusion efface le match (le tableau de B-035), et la récupération reste possible. Corriger B-035 avant elle, ou avec elle (la piste `needsSave` : aucun CLASSÉ avant le chargement), ferme ce cas. C'est la recommandation pour production, si Wilhem dit oui.

    La question posée à Wilhem et la recommandation ne changent pas.
  - **relu le 28/10 sur la v0.36.13** (B-035, livrée le 27/10) :
    - **ce qui change** : pendant le chargement de la sauvegarde, seul TRAINING se lance, et TRAINING n'écrit rien dans le profil. Les trois voies d'un CLASSÉ sont gardées : la garde de `start` (`GameModes.waitsForSave`, `init.server.luau:1652`), le DÉFI accepté qui reste en attente (`Lobby.accept`, `:1417`), et le serveur réservé du CLASSÉ entre serveurs, qui attend les deux profils jusqu'à 65 s puis ne lance pas le match (`GlobalQueue.crossStart`, `:1192`) ;
    - **le lien avec B-035 est levé.** Le cas rare du 26/10 (un CLASSÉ 2v2 ou 3v3 fini pendant l'attente, gardé par la fusion faute de champ `ratings` dans la sauvegarde, et qui rendait le joueur irrécupérable) ne peut plus arriver : aucun CLASSÉ ne part avant la fin du chargement. Une session « SAVES UNAVAILABLE » peut jouer, mais rien n'est écrit, ni le profil ni les classements (`writeProfile` refuse « unloaded » en `:264`, avant toute écriture de classement) : le joueur reste récupérable à la session suivante. Le critère « B-035 corrigé avec elle, ou le cas rare noté dans `DECISIONS.md` » tombe. Il devient : la garde de B-035 reste entière ;
    - **ce qui reste, et que la v0.36.13 rend plus simple à fermer** : les modes s'ouvrent maintenant exactement à la fin du chargement (`client.profileLoaded`, `:212`), donc au moment où une récupération dans son propre fil commencerait ses deux lectures. Un joueur qui lance tout de suite un CLASSÉ 2v2 entre dans la file à 1000 (`:1669-1670`). Si la lecture répond pendant le match, la cote est rendue en plein match, et la fin du match compte bien la cote rendue (`endVersus` relit la cote à la fin, `:771`) : seul l'appariement s'est fait à 1000. Rien n'est perdu, et la règle « jamais écraser une cote jouée » tient ;
    - **une option nouvelle pour production** : faire les deux lectures **dans** le chargement, après `SaveQueue.loaded` (`:206`) et avant `client.profileLoaded = true` (`:212`). Le bandeau « LOADING YOUR SAVE… » reste alors le temps des deux lectures, une seule fois par joueur grâce au marqueur. Aucun mode ne part avant la cote rendue, pas même le CLASSÉ du serveur réservé. La raison de l'ancien choix, « ne pas retarder l'entrée dans le hub », ne tient plus : depuis la v0.36.13, le joueur est dans le hub pendant le chargement, seuls les modes attendent. Le prix : une lecture lente retarde les modes. Il faut donc un seul essai par lecture, sous `pcall`, sans nouvel essai pendant le chargement ; une lecture en échec est refaite à la connexion suivante. **Recommandation : dans le chargement.** Production choisit, ce n'est pas une question pour Wilhem ;
    - **le menu** : la cote 2v2 et 3v3 s'affiche en texte simple sur la page CLASSEMENT (`MenuController.luau:2034-2036`), sans compteur qui monte. Faite dans le chargement, la récupération est déjà dans le statut de fin (`onProfileLoaded`, `:1328-1343`, statut en `:1342`). Faite dans un fil à part, il faut un `menuStatus` après elle, sinon le menu montre 1000 jusqu'au statut suivant ;
    - **B-036** (ouvert, la copie superficielle de `writeProfile`, `table.clone` en `:266`) : la cote rendue vit dans `ratings`, une table imbriquée partagée avec une écriture déjà partie ; le marqueur, au premier niveau, ne l'est pas. Au pire, la sauvegarde garde la cote rendue sans le marqueur. C'est sans danger : une cote présente suffit à ne plus relancer la récupération (`Matchmaker.played`) ;
    - **sans effet** : B-039 (le premier arrivé sur le serveur réservé) ne joue qu'une fois son profil chargé ; `Profile.luau`, `Matchmaker.luau`, `Store.luau` et `Admin.luau` n'ont pas changé ;
    - **les lignes à jour** (le serveur a gagné une ligne avant `loadProfile`, et 9 avant `writeProfile`) : `loadProfile` `:152-228` ; l'attente de l'ancienne visite `:156-165` ; celle du verrou d'un autre serveur `:166-218` ; « même visite » `:164` et `:181` ; `SaveQueue.loaded` `:206` ; `profileLoaded` `:212` (réussite) et `:219` (échec) ; « SAVES UNAVAILABLE » `:219-226` ; `writeProfile` `:262-311` ; les classements 2v2 et 3v3 `:292-301`, écrits après le profil (`:297`). Les lignes citées plus haut pour la v0.36.10 et la v0.36.11 sont celles de ces versions.

    La question posée à Wilhem et la recommandation ne changent pas : la v0.36.13 ferme une façon de devenir irrécupérable, mais pas la principale (rejouer ou quitter un CLASSÉ 2v2 ou 3v3 après la perte).
  - **relu le 29/10 sur la v0.36.14** (B-039 et B-042, livrée le 28/10). La question : la v0.36.14 refuse le CLASSÉ après un chargement échoué ; est-ce que cela touche la récupération de la cote 2v2 et 3v3 ?
    - **la réponse courte : non, pas sa règle.** La récupération ne se lance que sur une session chargée (`SaveQueue.loaded`), jamais sur une session « SAVES UNAVAILABLE ». Le nouveau refus ne vise que ces sessions-là : `GameModes.saveState` vaut alors `"failed"`, et `GameModes.startRefusal` refuse le CLASSÉ (`init.server.luau:1708`). Les deux ne se croisent jamais ;
    - **pour les joueurs touchés, rien ne change non plus** : avant la v0.36.14, une session en échec pouvait jouer un CLASSÉ 2v2 ou 3v3 à 1000, mais rien n'en était écrit, ni le profil ni les classements (`writeProfile` refuse « unloaded » en `:275`, avant les classements, `:303-312`). Le joueur restait récupérable. Depuis, il ne joue plus ce CLASSÉ du tout : même résultat pour lui, et son adversaire n'est plus compté contre 1000. Le refus couvre les trois catégories (1v1, 2v2, 3v3 : le même `VERSUS` en file `RANKED`) et le serveur réservé (`crossStart` annule dès qu'un chargement échoue, `:1236`) ;
    - **ce qui change pour production, et rend l'option « dans le chargement » encore plus juste** :
      - un seul état décide de tout : `saveState` (`init.server.luau:238-240`, `GameModes.saveState`). Tant que `client.profileLoaded` n'est pas vrai, il vaut `"loading"`. Si les deux lectures se font entre `SaveQueue.loaded` (`:206`) et `client.profileLoaded = true` (`:212`), tout reste refusé sauf TRAINING, et le serveur réservé attend (`crossStart` rend `"wait"`). Le CLASSÉ 2v2 ou 3v3, local ou entre serveurs, part donc toujours avec la cote rendue. Rien à ajouter à `startRefusal` ;
      - le serveur réservé n'annule plus au bout de 65 s : il attend la fin du chargement, sous un filet, `PROFILE_CAP` = 120 s (`GlobalQueue.luau:160`). Le test de B-039 (`Lobby.test.luau:1519`) garde ce filet au-dessus du plus long chargement, recalculé sur le miroir `saveWorld` (`:625`) : 81 s et 26 appels au DataStore, à 1 s par appel (`:1647-1660`). Deux lectures dans le chargement en font 28 au plus : 109 s, toujours sous 120 s. **Mais le miroir doit les compter**, sinon le test ne mesure plus le vrai chargement. Attention : le plus long chargement du test est celui qui échoue, alors que les lectures ne se font que sur un chargement réussi. Le test doit prendre le plus long des deux ;
      - dans un fil à part (l'autre option), le serveur réservé lance le CLASSÉ dès que les deux profils sont chargés, sans attendre les lectures. L'appariement s'est fait sur le serveur d'origine, avec la cote de la sauvegarde. Le match compte la cote rendue si elle arrive avant la fin (`endVersus` relit la cote à la fin, `:790`). Mais si le match finit avant la lecture, la catégorie compte comme jouée, et la récupération ne se fait plus. C'est rare, et c'est une raison de plus pour la recommandation ;
    - **un trou qui existait déjà, que la v0.36.14 rend simple à fermer si production le veut** : le chargement réussit, mais une lecture échoue. Le marqueur n'est pas posé, et la lecture sera refaite à la connexion suivante. En attendant, le joueur peut jouer un CLASSÉ 2v2 ou 3v3 à 1000 : la catégorie devient jouée, et il n'est plus récupérable. `GameModes.startRefusal` est maintenant le seul endroit où un mode est refusé avec sa raison : on pourrait y refuser le CLASSÉ de cette catégorie pour la session. **Recommandation : ne pas le faire.** Un échec de lecture est rare, et un CLASSÉ 2v2 fermé toute une session se verrait. C'est un choix de production, à noter dans `DECISIONS.md`, pas une question pour Wilhem ;
    - **sans effet** : B-043 (un CLASSÉ contre soi-même, avec des données falsifiées) ne touche que le tricheur ; B-044 (des réclamations perdues) ne touche aucune cote ; `startVersus`, qui sort maintenant les deux joueurs de toute file et de tout match (B-039), ne touche pas au profil. `Profile.luau`, `Matchmaker.luau`, `Store.luau` et `Admin.luau` n'ont pas changé ;
    - **les lignes à jour** (le serveur a gagné 11 lignes en `:236-246`, avant `writeProfile`, puis d'autres plus loin) : `loadProfile` `:152-228` (inchangé) ; « même visite » `:164` et `:181` ; `SaveQueue.loaded` `:206` ; `profileLoaded` `:212` (réussite) et `:219` (échec) ; « SAVES UNAVAILABLE » `:219-226` ; `saveState` `:238-240` ; `writeProfile` `:273-322`, « unloaded » `:275`, la copie de B-036 (`table.clone`) `:277`, les classements 2v2 et 3v3 `:303-312`, écrits après le profil (`:308`) ; `endVersus` relit la cote en `:790` ; la garde de `start` (`GameModes.startRefusal`) en `:1708`, et la file locale prend la cote en `:1726` ; le DÉFI (`Lobby.accept`) en `:1470` ; le serveur réservé (`crossStart`) en `:1236` ; `onProfileLoaded` `:1378-1392` (le statut de fin en `:1392`) ; le menu, page CLASSEMENT, `MenuController.luau:2032-2038`. Les lignes citées plus haut pour la v0.36.10, la v0.36.11 et la v0.36.13 sont celles de ces versions.

    La question posée à Wilhem et la recommandation ne changent pas.
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
    - le classement est écrit après le profil, à part (`init.server.luau:288` de la v0.36.10). Si cette écriture a échoué, il garde une cote plus ancienne, et c'est elle qui revient ;
    - un joueur qui a rejoué en 2v2 ou en 3v3 après la perte est reparti de 1000. Sa vraie cote est perdue, et le classement a gardé la nouvelle. La récupération ne peut rien pour lui (elle ne se lance pas, puisqu'il a une cote). Depuis la v0.36.11, c'est vrai aussi pour un CLASSÉ 2v2 ou 3v3 quitté tout de suite ;
    - chaque jour où la v0.36.7 tourne en ligne sans la récupération, des joueurs touchés rejouent et ne peuvent plus être récupérés. Si la v0.36.7 n'est pas encore publiée sur Roblox, mieux vaut publier les deux ensemble ;
    - si un jour une cote est remise à zéro exprès (nouvelle saison, tricheur) sans vider les classements, la relecture la rendrait. Rien ne le fait aujourd'hui, et le marqueur « une seule fois » écarte ce cas ;
  - **des cas où l'étoile est fausse** :
    - un titre acheté puis gagné en jouant ne retrouve pas son étoile, car on ne peut pas le distinguer d'un titre seulement acheté. Le joueur doit refaire l'exploit ;
    - si un jour un titre à exploit est donné autrement (récompense de quête, cadeau du propriétaire sans `ownedItems`), la règle lui mettrait une étoile à tort. Un commentaire dans le code et le test doivent le rappeler.
- **Questions ouvertes** (pour Wilhem) :
  1. Faut-il rendre ce qui a été perdu ? Choix : a) oui, la cote et les étoiles ; b) seulement les étoiles (aucune lecture en plus, aucun risque de valeur fausse) ; c) non, on laisse comme c'est. **Recommandation : a)**, une seule fois par joueur, en silence, et vite : chaque jour, moins de joueurs peuvent retrouver leur cote.
- **Statut** : `à clarifier`. Rendre une cote CLASSÉE que les joueurs voient est un choix de Wilhem (décision du 20/10), et sa réponse n'est pas arrivée.
  - **l'historique des relectures** (le détail est plus haut, dans « Ce qui existe ») : après la v0.36.10 et la v0.36.11, la fiche suit le nouveau chargement et les nouvelles règles de départ ; après la v0.36.13, le lien avec B-035 est levé, et une option de production s'ajoute (les deux lectures dans le chargement) ; après la v0.36.14, l'option « dans le chargement » gagne, et un critère s'ajoute (le miroir du test de B-039 compte les deux lectures). Rien de cela ne demande plus à Wilhem ;
  - **revue le 1/11** (HEAD 889b22a, v0.36.15) : aucun fichier du serveur, ni `Profile.luau`, ni `Matchmaker.luau`, ni `GameModes.luau` n'a changé depuis la v0.36.14 ; la v0.36.15 ne touche que les finishers, le son et leurs tests. Les lignes citées le 29/10 tiennent ;
  - la recommandation « vite » compte toujours : chaque jour sans réponse, des joueurs touchés rejouent un CLASSÉ 2v2 ou 3v3 et ne peuvent plus retrouver leur cote. La routine ne la lance pas sans lui.
- **Critères d'acceptation** (si Wilhem dit oui) :
  - une règle pure (dans `Profile.luau` ou `GameModes`), testée dans `Lobby.test` :
    - au chargement, un titre à exploit présent dans `titles` et sans achat dans `ownedItems` reçoit son étoile ;
    - un titre acheté n'en reçoit pas, un titre hors des six n'est jamais touché ;
    - aucune annonce « titre gagné » ;
  - à la connexion, pour une catégorie sans cote (`Matchmaker.played` faux), le serveur lit la ligne du joueur dans le classement 2v2 ou 3v3. S'il y trouve un nombre, `Matchmaker.setRating` le rend ; sinon, rien ne change ;
  - une seule fois par joueur : le marqueur figure dans `Profile.default` et n'est posé que si les deux lectures ont répondu. Une lecture en échec est refaite à la connexion suivante ;
  - la lecture n'empêche jamais le chargement de finir : au plus deux lectures, un seul essai chacune, sous `pcall`. Une cote jouée entre-temps n'est jamais écrasée ;
  - elle ne se lance qu'une fois la session chargée (`SaveQueue.loaded`), jamais sur une session « SAVES UNAVAILABLE ». Après chaque lecture, elle ne change rien si la visite a changé ;
  - elle n'écrit rien elle-même : la cote, l'étoile et le marqueur passent par `saveProfile`, puis par `writeProfile`, comme le reste du profil ;
  - la garde de B-035 (v0.36.13) et celles de B-039 et B-042 (v0.36.14) restent entières : aucun mode, sauf TRAINING, ne part avant la fin du chargement ; aucun CLASSÉ après un chargement échoué ; rien pendant l'attente du serveur réservé (`GameModes.startRefusal`). Si les lectures sont faites dans le chargement (avant `client.profileLoaded`), le CLASSÉ part avec la cote rendue, local ou entre serveurs. Si elles sont faites dans un fil à part, un `menuStatus` suit la récupération. Le choix est noté dans `DECISIONS.md` ;
  - si les lectures sont dans le chargement, le miroir `saveWorld` du test de B-039 (`Lobby.test.luau`) les compte, et `PROFILE_CAP` reste au-dessus du plus long chargement, réussi (avec les deux lectures) ou échoué ;
  - le cas « chargement réussi, lecture en échec, CLASSÉ 2v2 joué avant la connexion suivante » est tranché par production et noté dans `DECISIONS.md` (recommandé : on l'accepte, sans fermer le CLASSÉ) ;
  - le test « saved profile » passe avec le nouveau champ, et les 9 suites passent ;
  - rien n'est affirmé testé sur le vrai DataStore : Wilhem confirme en jeu (un joueur touché revoit sa cote 2v2).

## I-005 · SAMSARA (ASURA) : revoir trois plans mal cadrés
- **Date** : 30 octobre 2026 (fiche ouverte par la routine du matin). Les trois plans ont été relevés par la validation du 26 octobre 2026 (SAMSARA, v0.36.12) et suivis dans I-001 jusqu'ici.
- **Wilhem** : rien sur ces plans. L'idée ne vient pas de lui : elle sort de I-001, son idée du 12/10 (« une animation comme les Legendary Finish de DBL quand le fatal tue, une anime spéciale plus longue »). Ses mots sur les bras d'ASURA comptent pour cette retouche : « ASURA, ses bras, la deuxième paire, rends-la agréable » (journal).
- **Interprétation** : dans le FATAL FINISHER d'ASURA, trois plans de la montée vers le coup se voient mal. On les recadre, sans rien changer à ce qui s'y passe :
  - `asura-ss-guard` (ticks 304 à 350, la cible lève sa garde) : ASURA est coupé en deux par le bord du cadre ;
  - `asura-ss-step` (ticks 350 à 372, son pas lourd) : la roue d'or est vue par la tranche et ne se lit plus ;
  - `asura-ss-draw` (ticks 372 à 420, ses quatre poings tirés aux hanches qui se rallument ensemble) : vu de très haut, deux poings sont cachés par son corps, alors que c'est le temps « les quatre à la fois ».

  Le joueur voit ASURA entier ou pas du tout, la roue bien ronde, et ses quatre poings qui se rallument.
- **Ce qui existe déjà** :
  - **la scène** : `S.ASURA` (`Finishers.luau:3264`), ses 12 plans composés avec `frameOn` (`:3250-3261`). Les trois à revoir sont en `:3255-3257` ; ZENITH, ajouté plus bas dans le fichier, ne les déplace pas. Leurs réglages aujourd'hui :
    - `asura-ss-guard` : la cible pour sujet (`subjects = "d"`, `band = "bust"`), `yaw = -40`, `pitch = 2` ;
    - `asura-ss-step` : les deux corps, `yaw = -36`, `pitch = 4` ;
    - `asura-ss-draw` : les deux corps, `yaw = 14`, `pitch = 46` ;
  - **la roue** : un anneau (`kind = "ring"`, `mark = "wheel"`, avec son moyeu, `mark = "hub"`) dans son dos, tourné vers l'avant d'ASURA (`normal = fwd`), donc vers la cible. Une caméra placée de côté, loin de l'axe des deux corps, la voit par la tranche ;
  - **mesuré le 30/10 sur le labo** (rig KAI avec ses bras du bas ; mêmes chiffres au centre et dos à chaque mur, en miroir depuis la droite), avec les seuils des tests de ZENITH :
    - `asura-ss-guard`, ASURA dans le cadre (de -1 à 1) : de -1,17 à -0,50, coupé dans les 46 images. Seuil : entier, ou tout à fait dehors ;
    - `asura-ss-step`, la roue face à la caméra (|n·c|) : de 0,03 à 0,11, soit 84 à 88° de la face, dans les 22 images. Seuil : 0,34 au moins (70° au plus) ;
    - `asura-ss-draw`, la plongée sur lui : 45°. Seuil : 30° au plus ;
    - `asura-ss-draw`, chaque poing caché par le reste de son corps (bras à part), au pire : depuis la gauche, `LeftHand` 96 % et `AsuraFistLeft` 100 % ; depuis la droite, `RightHand` 96 % et `AsuraFistRight` 67 % ; les deux autres poings, 0 à 7 %. Seuil : un quart au plus ;
    - la caméra ne saute pas dans ces trois plans (0,07 stud au plus d'une image à l'autre) ;
  - **les tests de SAMSARA** (`tests/Cinematography.test.luau`, numéros de HEAD 889b22a, relus le 1/11) : la scène, `:698-877`, des deux côtés ; ses 6 placements, `:879-942` (la liste des placements en `:885-888` : au centre des deux côtés, dos à chaque mur, la cible près de chaque mur, `Config.ArenaMaxX - 3` et `ArenaMinX + 3`, donc jamais au-delà de x = 25,3). Ils passent par `film(kit, center, mirror, wall)` (`:602`), qui donne `wall` tel quel à `Kit.play`. Aucun ne regarde le cadre d'ASURA, la roue par la tranche ou la plongée : seule la planche le montrait ;
  - **les outils de ZENITH, dans le dépôt depuis la v0.36.15** (le labo, `tests/CinematicKit.luau`) :
    - `Kit.play(kit, kind, style, hp, center, onFrame, mirror, wall, foe)` (`:101`) ;
    - `wall = "target"` (`:113-117`) : la cible collée au mur devant l'attaquant, à 0,5 du mur (x = ±27,5). Il suffit d'ajouter deux lignes à la liste des placements de SAMSARA, comme ZENITH en `:1275` (`{ …, 0, false, "target" }`, `{ …, 0, true, "target" }`) : `film` les passe déjà ;
    - `foe` (`:88-89`, `:103`) : la cible au choix, KAI si rien n'est donné ; son arme se dessine avec `WeaponKit.pieces`. `film` ne le prend pas encore : un paramètre de plus ;
    - `yaws` et `clientYaws` (`:79`, `:90-94`) : l'orientation de chaque corps, comme le labo et comme le client (B-046, B-048) ; `Kit.boxGap` (`:279`) : l'écart entre deux pièces (B-047) ;
  - **les mesures de ZENITH, à reprendre** : elles sont écrites dans son test, pas dans le labo (`tests/Cinematography.test.luau:984-1219`) ; I-005 les recopie pour les trois plans, avec les mêmes seuils :
    - « entier dans le cadre » (`:1093-1098`, avec `Kit.projector` et `Kit.bodyBounds`). ZENITH exige « entier » ; pour `asura-ss-guard`, la règle est « entier, ou tout à fait dehors » : une ligne de plus ;
    - « pas plus de 30° de plongée » sur le perso du focus (`:1099-1104`) : le focus de `asura-ss-draw` est bien ASURA (`{ "A", "UpperTorso" }`) ;
    - « aucun anneau à plus de 70° de sa face » (`:1127-1135`), soit |n·c| ≥ 0,34 : la roue de SAMSARA est un anneau du même genre (`kind = "ring"`, `mark = "wheel"`) ;
    - « la caméra ne saute pas de plus de 1,5 stud » (`:1075-1076`) ;
  - **ce qui n'existe pas encore, et qu'I-005 écrit** : « chaque poing caché par son propre corps » (`Kit.hiddenShare`, `tests/CinematicKit.luau:338`, sur le corps d'ASURA sans le bras du poing mesuré). ZENITH n'en a pas besoin, ses mains sont toujours lisibles ;
  - **les chiffres du 30/10 tiennent** : la scène de SAMSARA n'a pas bougé depuis la v0.36.12 (la v0.36.15 n'ajoute ZENITH qu'après la ligne 3489 de `Finishers.luau`), et la v0.36.15 a rejoué 194 scènes, identiques image par image avec l'ancien labo (journal). Mesuré le 30/10 avec le même placement « cible contre le mur » : les corps de SAMSARA restent sur le sol (27,8 studs au plus), des deux côtés ;
  - **les bugs de ZENITH et SAMSARA** : B-046 (un demi-tour d'une image dans un plan) et B-048 (le client reprend un cap périmé après un `lookDir`) ne la touchent pas, elle n'est dans aucun de leurs relevés. B-047 et B-051 (la règle du quart mesurée sur KAI seul a laissé passer la tête de VENOM cachée à 33 % dans ZENITH) valent pour elle comme pour tous les finishers : voir les risques ;
  - **les bras du bas** ne montent pas devant son visage et ne passent jamais dans son corps (test Animation, poses de `FourArms.SCENE`) : rien ne change, seule la caméra bouge.
- **Persos et systèmes touchés** : ASURA (boss). Seulement sa cinématique (`Finishers.luau`, les réglages de trois plans) et ses tests (`Cinematography`). Ni gestes, ni sons, ni effets, ni nom. Aucun dégât ni aucune vie : pas d'équilibrage.
- **Valeur / effort** : faible à moyenne / petit.
  - Valeur : la scène est rare (le défi d'ASURA, en relais, sa vie basse et son COUP FATAL prêt) et se voit surtout sur les planches. Mais c'est le temps « les quatre à la fois », et Wilhem tient à ses bras.
  - Effort : trois plans recadrés ; dans le test, trois mesures reprises de ZENITH, une écrite (le poing caché par son propre corps) ; deux lignes de placement.
- **Risques** :
  - un nouvel angle peut cacher le sujet derrière l'autre corps, ou mettre la caméra dans un corps près du mur : les 6 placements, plus les deux nouveaux, le vérifient ;
  - dans `asura-ss-guard`, la cible est le sujet : ASURA peut sortir tout entier du cadre ou y entrer tout entier, les deux sont justes. S'il entre, la cible reste le sujet (au plus un quart d'elle caché) ;
  - la roue regarde la cible : pour la voir de face, la caméra se rapproche de l'axe des deux corps (dans le dos d'ASURA, ou du côté de la cible, la roue derrière lui). Si production veut aussi tourner un peu la roue vers la caméra, ce n'est plus seulement un recadrage : elle le note dans `DECISIONS.md`, et le test de la roue (ses rayons, `spoke1` à `spoke4`, suivis sans saut) doit repasser ;
  - moins de plongée dans `asura-ss-draw` peut mettre la cible devant lui : le test de placement le voit ;
  - les mesures se font sur le rig KAI du labo, et les vrais avatars n'ont pas sa taille (B-018) : garder de la marge ;
  - **la cible n'est pas toujours KAI** (B-047, B-051) : en défi, c'est l'un des 20 persos du joueur, avec son arme. Un nouvel angle dans `asura-ss-guard` (la cible pour sujet, en buste) ou dans `asura-ss-draw` peut mettre la lance de RAIJIN ou le katana de SHIN devant ASURA, ou cacher plus d'un quart de la cible, sans que le test sur KAI le voie. Le labo choisit maintenant la cible (`foe`) : **recommandé**, jouer aussi ces trois plans contre les 20 persos jouables, au moins depuis la droite (le côté du défi), avec la règle du quart, comme le test de ZENITH contre les 20 cibles (`tests/Cinematography.test.luau:1338-1361`). Pas exigé, puisque les 9 autres plans n'y passent pas ; production choisit et le note.
- **Questions ouvertes** : aucune pour Wilhem. S'il préfère refaire ces plans d'après une planche, production suit sa planche à la place. Rien ne l'attend.
- **Statut** : `prête`. Rien n'attend Wilhem. Revue le 1/11 sur HEAD 889b22a (v0.36.15) : la scène de SAMSARA et ses tests n'ont pas bougé (seuls leurs numéros, remis à jour), et ZENITH a livré le placement « cible contre le mur », la cible au choix et trois des quatre mesures (voir « Ce qui existe déjà »). Elle n'attend plus rien.
  - **L'ordre** : le journal de la v0.36.15 propose B-049, puis B-044, puis I-005. C'est la seule idée prête ; elle passe dès qu'aucun bug n'est choisi avant elle.
  - **Voisine, à regrouper si production le veut** : B-040 dans SAMSARA (`asura-ss-blown`, ticks 464 et 470 : la cible bascule au sol en deux temps, et la caméra saute de 7 studs). C'est la même scène et les mêmes tests. Si production corrige B-040 scène par scène (pistes 2 ou 3), SAMSARA peut passer dans cette livraison. Si elle choisit la règle de l'animateur (piste 1), SAMSARA en profite d'office. Le choix est le sien, noté dans `DECISIONS.md`.
- **Critères d'acceptation** :
  - seul le cadrage de `asura-ss-guard`, `asura-ss-step` et `asura-ss-draw` change (angle, plongée, part de l'écran, focale, sujet si besoin), toujours composé avec `frameOn`, jamais par un décalage de caméra à la main. Les 9 autres plans, les gestes, les formes, les sons, le nom et les durées ne changent pas ;
  - `asura-ss-guard` : ASURA n'est jamais coupé par le bord du cadre. Il est entier dedans, ou tout à fait dehors, à chaque image, des deux côtés ;
  - `asura-ss-step` : la roue (`wheel`) n'est jamais vue par la tranche : |n·c| vaut 0,34 au moins à chaque image, des deux côtés ;
  - `asura-ss-draw` : la plongée sur ASURA est de 30° au plus, et chacun de ses quatre poings est caché à un quart au plus par le reste de son corps, à chaque image, des deux côtés. On voit les quatre se rallumer ;
  - ces mesures entrent dans le test de SAMSARA (`Cinematography`), avec les seuils de ZENITH, et elles échouent sur le code d'aujourd'hui ;
  - le test de la scène et ses 6 placements repassent, sans que leurs seuils changent. Deux placements s'ajoutent, la cible contre chaque mur (x = ±27,5 : le placement `wall = "target"` de `CinematicKit.play`, deux lignes de plus dans la liste des placements), avec les mêmes exigences : les corps sur le sol, et au plus un quart du sujet caché par l'autre corps ;
  - dans ces trois plans, la caméra ne saute jamais de plus de 1,5 stud d'une image à l'autre ;
  - la planche est vérifiée au centre, depuis la droite et dos à chaque mur (`luau tests/Storyboard.luau -a ASURA Fatal - 1 20`, puis la même avec `right`, `wall-left` et `wall-right`, et `python3 tools/storyboard.py`) ;
  - les tests de ZENITH, BLACK SUN et des autres finishers passent sans retouche ;
  - les 9 suites passent. La version, le journal et la place suivent, comme pour toute livraison.
