# Bugs — la liste

Tenue par l'agent `bugs` (`.claude/agents/bugs.md`). Une entrée par bug, numérotée `B-###`.

Gravité :
- **bloquant** : la partie casse ;
- **majeur** : faux en combat, ou très visible ;
- **mineur** : visuel ou son ponctuel ;
- **cosmétique**.

Statuts : `ouvert`, `à confirmer`, `en correction`, `corrigé (vX.Y.Z)`, `pas un bug (raison)`.

Dernière chasse : 27/10, sur la v0.36.12 (HEAD 8c1c308). Les 8 suites rapides passent (1 615 tests : CombatSimulation 175, FighterAI 19, CinematicDirector 872, Animation 65, PressQueue 4, Fuzz 2, Cinematography 421, Lobby 57). AnimPops est identique au relevé de la validation (16 sauts, tous déjà connus), et AnimQuality d'ASURA est identique avant et après la v0.36.12 : rien n'a changé pour lui en combat. La v0.36.12 ne touche ni le serveur, ni le client, ni la simulation, ni le directeur, ni le son, ni les VFX. Lignes décalées : `Finishers.luau` après la ligne 3219 (+270), `MoveData.luau` après 1410 (+4), `Locale.luau` après 1329 (+1) ; les fiches concernées ont une note « 27/10 ». Les autres lignes citées tiennent.

Ancienne chasse : 26/10, sur la v0.36.11 (HEAD 331765b), 1 603 tests.

---

## B-001 · L'écran K.O. des FATAL FINISH avait l'air cassé
- **Date** : 15 octobre 2026.
- **Source** : Wilhem, « ya ce bug sur tous les ko screen de FATAL FINISH », avec une capture du plan `kai-mx-ko`, image 632/720.
- **Ce qui se passait** : la carte K.O. était un aplat opaque de couleur qui cachait toute la scène, avec des rectangles pour l'éclaboussure (`CinematicController`, `koCard`).
- **Gravité** : majeur.
- **Statut** : `corrigé (v0.36.1)`, à confirmer en jeu par Wilhem. La scène reste maintenant visible sous la teinte, et les coups de pinceau KO_BRUSH remplacent les rectangles.

## B-002 · La voix « K.O. » sur les explosions des cinématiques
- **Date** : 15 octobre 2026.
- **Source** : Wilhem, « le son qui dit KO il doit venir que sur les KO ».
- **Cause** : `SoundController:cinematicSound("boom")` jouait `ACTIONS.KO`. Il y a 28 « boom » dans les cinématiques.
- **Gravité** : mineur.
- **Statut** : `corrigé (v0.36.1)`. Les booms jouent `Explosion` ; un test dans Kits vérifie qu'aucune autre action ne dit K.O.

## B-003 · Des IDs de textures VFX recopiés depuis des captures
- **Date** : 15 octobre 2026.
- **Risque** : 52 des 97 IDs ont été lus sur des captures non agrandissables. Un chiffre mal lu donnerait une texture vide.
- **Comment le voir** : au lancement, la console Studio affiche `[VFX] these textures did not load …` avec le nom et l'ID.
- **Ce qui se passe** : depuis la v0.36.3, cette texture est seulement laissée de côté. Rien de ce qu'elle dessine n'est montré (particules, traînées, rayons, meshes ; ses images sont vides), et le reste du pack reste allumé. En v0.36.1, un seul ID commun mal lu éteignait le pack pour tous les persos (voir B-004).
- **Gravité** : mineur.
- **Statut** : `à confirmer` (Wilhem regarde la console en jeu).

## B-004 · Les sprites d'impact du pack ne s'affichaient pas sur les coups
- **Date** : 16 octobre 2026.
- **Source** : Wilhem, « pq t'as pas mis les sprites des impacts sur l'update ?? ».
- **Comment reproduire** : `python3 tools/vfxrun.py` (le pack joué sur une copie stricte du moteur) ; avant la correction, on cherchait l'émetteur des planches HITSPARK après chaque coup.
- **Ce qui se passait** (prouvé) :
  - le pont appelle l'impact propre à chaque perso (`VFX_Chars` : `C.Impact`) ;
  - les planches communes HITSPARK_LIGHT, HITSPARK_HEAVY et IMPACT_BURST n'étaient que dans l'impact commun (`V.Impact`), que le jeu n'appelle pas, et dans la signature de 6 persos (RYUKEN, RAIJIN, KAZAN, SYLVA, NOVA, KUROEN SHIN) ;
  - les 16 autres, dont KAI, TARO, ZEPHYR, AKEMI, SHIN, DAICHA et HIBECARES, n'en montraient aucune (KAI : seulement l'anneau KI_POP).
- **Ce qui a pu s'y ajouter** (supposé, rien n'est vérifiable d'ici) : un ID commun mal lu (B-003) éteignait en v0.36.1 tout le pack, donc aucun sprite du tout.
- **Ce qui devrait se passer** : la planche d'impact au cœur de chaque coup, à la taille du niveau du coup.
- **Cause** : `src/client/VFX/VFX_Chars.luau`, fonction `compose`, et `src/client/VfxPack.luau`, fonction `ready`.
- **Gravité** : majeur (très visible).
- **Statut** : `corrigé (v0.36.2, complété en v0.36.3)`, à confirmer en jeu par Wilhem. La planche est maintenant sous la signature de chaque perso, sur les 88 coups testés (22 persos × 4 niveaux), une seule par coup. Une texture qui ne charge pas n'éteint plus tout le pack. Depuis la v0.36.3, rien de ce qu'elle dessine n'est montré : ni particules, ni traînées, ni rayons, ni meshes.

## B-005 · Une texture qui ne charge pas laissait des traînées, rayons et meshes sans texture
- **Date** : 16 octobre 2026.
- **Source** : trouvé par l'agent `validation` sur la v0.36.2 (REFUSÉ).
- **Ce qui se passait** : en v0.36.2, `V.Blank` ne retirait que les particules. Les traînées (`Trail`), les rayons (`Beam`) et les meshes (`TextureID`) dessinés avec cette texture étaient créés quand même, avec une texture vide. D'après la doc Roblox, ils s'affichent alors en bande unie (non vérifiable d'ici).
- **Comment reproduire** : `python3 tools/vfxrun.py`, passages 3 et 4 (11 textures qui ne chargent pas : particules, traînées, rayons, meshes). À chaque image, rien de ce qui est dessiné avec elles ne doit être dans le monde.
- **Cause** : `src/client/VFX/VFX_Common.luau` (`V.Blank`, `beam`, `V.SwingTrail`, `V.Slash`, `V.Guard`, `V.Burst`, `V.SuperJump`), `VFX_Chars.luau` (`trailObj`), `VFX_Specials.luau` (`weldMesh`, traînées des tirs).
- **Gravité** : mineur. Le cas n'arrive que si un ID est mal recopié.
- **Deuxième refus** : une pièce créée **avant** la fin du préchargement restait affichée. C'est le cas des traînées, de l'aura et du passif d'un corps habillé dès la première image, donc au premier combat.
- **Statut** : `corrigé (v0.36.3)`. `V.Unseen` laisse hors du monde toute pièce dessinée avec une texture qui n'a pas chargé. Le pack garde aussi en mémoire les pièces texturées encore en vie (registre faible) : quand une texture est déclarée en échec, `V.Blank` retire celles qui existent déjà.

## B-006 · En mode réduit, un avertissement « budget hors limites » à presque chaque coup
- **Date** : 17 octobre 2026.
- **Source** : trouvé par la chasse (routine du matin). `vfxrun` ne joue jamais le mode réduit (`effects.reduced = false`, `tools/vfxrun.py:260`).
- **Comment reproduire** :
  - ici : une copie de `tools/vfxrun.py` avec `reduced = true` qui affiche les avertissements de budget ;
  - en jeu : SETTINGS → REDUCED EFFECTS (ou un téléphone, ou moins de 38 images par seconde : le mode s'allume tout seul), puis des coups forts, et la console (F9).
- **Ce qui se passe** (prouvé sur la copie du moteur) :
  - mode normal : aucun avertissement ;
  - mode réduit : 84 avertissements par passage, du type `[VFX_Chars] budget heavy hors limites : 16`. Ils tombent sur tous les coups `heavy`, `finisher` et `ko` des 22 persos (66 coups), sur 4 coups légers (KAZAN, KUROEN SHIN, NOVA, RAIJIN) et sur 14 impacts de tirs ;
  - au passage, le mode réduit émet 67 % des particules (1 617 contre 2 408), pas la moitié annoncée au journal de la v0.36.1 : le complément d'étincelles rattrape une partie de la réduction.
- **Ce qui devrait se passer** : aucun avertissement en mode réduit, et la part de particules prévue.
- **Cause** (prouvée) : `V.Emit` compte les particules après la réduction (`src/client/VFX/VFX_Common.luau:351-352`, `V.Quality = 0.5` posé par `src/client/VfxPack.luau:172`). `compose` compare ce total réduit aux fourchettes du mode normal (`src/client/VFX/VFX_Chars.luau:43`, `115-119`). Les étincelles de complément (`VFX_Chars.luau:107-111`) se calculent sur ce même total réduit, puis sont réduites à leur tour. Le défaut existe depuis la v0.36.1.
- **Gravité** : mineur. Rien ne se voit à l'écran, mais :
  - le téléphone, c'est-à-dire là où le mode réduit sert, fait un `warn` (et son formatage) presque à chaque coup ;
  - la console se remplit et noie le message `[VFX] these textures did not load …` dont dépend B-003, si Wilhem regarde en mode réduit.
- **Statut** : `ouvert`.
- **Piste** :
  - dans `compose`, comparer à la fourchette multipliée par `V.Quality` (ou compter les particules demandées avant la réduction), et calculer le complément dans la même unité ;
  - ajouter à `vfxrun` un passage en mode réduit qui échoue sur un avertissement de budget.

## B-007 · `V.Blank` appelé sans `pcall` dans `VfxPack.preload`
- **Date** : 17 octobre 2026.
- **Source** : point non bloquant relevé par l'agent `validation` sur la v0.36.3 (journal, problèmes ouverts).
- **Le risque décrit** : si `V.Blank` levait une erreur, le fil du préchargement s'arrêterait avant `self.readiness = {}` (`src/client/VfxPack.luau:126-128`). Deux conséquences :
  - les textures suivantes de la liste ne seraient pas retirées : retour de B-005 pour elles ;
  - un perso qui a perdu trop de textures resterait sur le pack, car sa disponibilité, déjà notée « prête », ne serait jamais revue.
- **Ce qui a été vérifié** :
  - `V.Blank` (`src/client/VFX/VFX_Common.luau:373-387`) ne fait que des écritures qui ne lèvent pas : les tables `V.Missing` et `V.Tex`, la `Transparency` d'un émetteur, et `Parent = nil` sur une pièce qui a encore un parent (une pièce détruite a un parent nul, elle est sautée) ;
  - il tourne dans son propre fil, après `PreloadAsync`, jamais dans un `AncestryChanged` (le seul cas connu où changer un parent avertit) ;
  - `self.V` est toujours posé avant, car `preload` n'est lancé que par `load()` (`VfxPack.luau:81-92`) ;
  - `vfxrun`, passages 3 et 4 : 11 textures en échec, dont des pièces créées avant la fin du préchargement, sans aucune erreur.
- **Gravité, si cela arrivait** : mineur.
- **Statut** : `pas un bug (aucun chemin d'erreur trouvé ; c'est une question de robustesse)`.
- **Piste**, si le code de `V.Blank` grandit : mettre `self.readiness = {}` avant la boucle et chaque `V.Blank(key)` dans un `pcall`. Le coût est nul.

## B-008 · Si `HITSPARK_LIGHT` ne charge pas, RYUKEN, RAIJIN, KAZAN, SYLVA et NOVA perdent aussi la planche de leurs coups lourds
- **Date** : 17 octobre 2026.
- **Source** : trouvé par la chasse, dans la sortie de `python3 tools/vfxrun.py`, passage 3 (« particles, a trail, a beam and meshes do not load »).
- **Comment reproduire** : `python3 tools/vfxrun.py`. Au passage 3, la liste « impact sheet not drawn » contient `KAZAN finisher, KAZAN ko, NOVA finisher, NOVA ko, RAIJIN finisher, RAIJIN ko, RYUKEN finisher, RYUKEN ko, SYLVA finisher, SYLVA ko`. L'outil ne le compte pas comme un échec.
- **Ce qui se passe** (prouvé) :
  - les signatures de ces 5 persos dessinent `HITSPARK_LIGHT_4x4` à tous les niveaux (`src/client/VFX/VFX_Chars.luau:368, 559, 753, 822, 879`) ;
  - `compose` note la planche comme dessinée même quand sa texture est en échec (`VFX_Chars.luau:73-75`), donc il ne pose pas la planche commune `HITSPARK_HEAVY` (`VFX_Chars.luau:83`) ;
  - résultat : aucune planche sur leurs fins d'enchaînement ni sur leurs coups de K.O., alors que `HITSPARK_HEAVY` a chargé. Les 17 autres persos gardent la leur (KUROEN SHIN dessine `HITSPARK_HEAVY`).
- **Ce qui devrait se passer** : une planche en échec ne compte pas ; la planche commune la remplace quand elle existe.
- **Cause** : `src/client/VFX/VFX_Chars.luau:73-75` (le relevé ne regarde pas `V.Missing`).
- **Gravité** : cosmétique. Il faut un ID de `HITSPARK_LIGHT_4x4` mal recopié (B-003), et cela ne touche que 5 persos.
- **Statut** : `ouvert`.
- **Piste** : dans le relevé de `compose`, ne noter `sheets[tex]` que si `not V.Missing[tex]`.

## B-009 · Le finisher d'ASTER porte le même nom que son ÉVEIL
- **Date** : 17 octobre 2026.
- **Source** : vu en passant par l'agent `production` (routine du 17/10). Confirmé par la chasse du 18/10.
- **Ce qui se passe** : le FATAL FINISHER d'ASTER s'appelle STELLAR COLLAPSE, comme son ÉVEIL (`src/shared/MoveData.luau`, vers la ligne 763).
- **Ce qui devrait se passer** : un nom propre au finisher, comme pour les 18 autres.
- **Preuve** (18/10) :
  - `MoveData.luau:763` : STELLAR COLLAPSE est le 27e nom de la liste d'ASTER, donc le rôle `Awakening` (`ROLE_ORDER`, `MoveData.luau:684-688`) ;
  - `MoveData.luau:1299` : `Finisher = { Name = "STELLAR COLLAPSE", … }` ;
  - un script compare le nom des 19 finishers aux noms de tous les coups de leur propre kit : seul ASTER est touché (`AsterAwakening`).
- **Pourquoi le test ne l'a pas vu** : le test commun aux finishers (`tests/Cinematography.test.luau:214`) refuse le nom d'un coup d'un **autre** perso, mais accepte celui d'un coup du même perso (`owner == nil or owner == kit`).
- **À côté** : « STELLAR COLLAPSE » est deux fois dans `Locale.FR` (`Locale.luau:594` et `:1057`), avec la même traduction. Sans effet, mais il faudra retirer la ligne du finisher au renommage.
- **Gravité** : cosmétique.
- **Statut** : `ouvert` (confirmé). Changer le nom demande un choix de nom : production peut le proposer, Wilhem tranche. Le même genre de doublon, entre deux persos cette fois : B-034 (TOTAL ECLIPSE).
- **27/10** : inchangé. Les deux lignes de `Locale.FR` sont maintenant `Locale.luau:594` et `:1062` ; `MoveData.luau:763` et `:1299` tiennent. Les 21 noms de finishers comparés à tous les textes du jeu (hors `Locale`) : seul STELLAR COLLAPSE est en double. SAMSARA n'est nulle part ailleurs.
- **Piste** :
  - un nouveau nom pour le finisher (une ligne de `MoveData`, une de `Locale`) ;
  - dans le test commun, refuser aussi le nom d'un coup du même perso (`owner == nil`).

## B-010 · Le finisher de TARO, joué depuis la droite, met la caméra presque au contact d'un corps
- **Date** : 17 octobre 2026.
- **Source** : vu en passant par l'agent `production` (routine du 17/10). Confirmé par la chasse du 18/10.
- **Ce qui se passe** : joué avec TARO à droite, une image met la caméra à 0,24 stud d'un corps, sous la limite de 0,25. Le labo ne joue jamais ce côté.
- **Comment reproduire** :
  - `Kit.play` avec l'argument `mirror` (nouveau, `tests/CinematicKit.luau`) sur TARO ;
  - ou la fonction `check` de `tests/Cinematography.test.luau`, recopiée telle quelle, sur les 19 finishers en miroir aux x = -25, 0 et 25 (script de la chasse, hors dépôt) ;
  - ou les 19 finishers sur toute l'arène, des deux côtés (même méthode que B-011).
- **Ce qui a été mesuré** (18/10) :
  - TARO depuis la droite : **une seule image** (t250, plan subjectif `taro-dr-eyes`), à 0,243-0,245 stud du haut du bras droit de TARO, contre une limite de 0,25. Ce cas se reproduit à **chacune** des 43 positions de l'arène ;
  - depuis la gauche, jamais ;
  - c'est 2,5 fois la distance où la caméra commence à couper ce qu'elle voit (0,1, plan proche) : très probablement invisible à l'écran ;
  - les 17 autres finishers sont propres des deux côtés, à toutes les positions, sauf SHIN dos au mur (B-011, plus grave) ;
  - les autres cinématiques (Rush, Éveil, Porte, Fatal et leurs K.O. ; 22 kits, 2 sens, 11 positions dont les deux murs : 2 904 lectures) n'ont que deux plans qui frôlent la marge du test depuis la droite, à toutes les positions. Le point de mise au point y monte à 0,78 de la demi-hauteur, pour 0,78 permis (0,74-0,77 depuis la gauche) : `zephyr-lune-launch` (Fatal de ZEPHYR, t22-t24) et `daicha-domain-clench` (Rush de DAICHA, t9). Le point reste à l'écran, ce n'est pas un bug, mais un test miroir échouera dessus.
- **Cause probable** : `src/shared/Finishers.luau:368`. L'œil de la cible porte un décalage `sway` en z, en axes du monde, qui ne change pas avec le côté. Avec le corps tourné de 3/4 vers la caméra (`ModelYaw`, 22°), le crochet de TARO passe un peu plus près de l'objectif quand il frappe depuis la droite.
- **Gravité** : cosmétique (abaissée : une image, 5 millièmes de stud sous la limite du test).
- **Statut** : `corrigé (v0.36.5)`. TARO se tient à 3,5 studs de la cible au lieu de 3,4 pendant le plan subjectif : la caméra est à 0,275 stud au plus près depuis la droite, 0,278 depuis la gauche. Testé dos au mur des deux côtés dans `Cinematography`.
- **Piste** :
  - reculer un peu l'œil (par exemple 0,6 au lieu de 0,55) ;
  - surtout, jouer les 19 finishers en miroir dans `Cinematography` (la boucle de la ligne 129 avec `mirror`), pas seulement NOVA.

## B-011 · SHIN dos au mur : son FATAL FINISHER met la caméra dans le bras de la cible
- **Date** : 18 octobre 2026.
- **Source** : trouvé par la chasse, en jouant les 19 finishers à toutes les positions possibles de l'arène, des deux côtés.
- **Comment reproduire** :
  - ici : une copie de `Kit.play` (`tests/CinematicKit.luau`) qui place la cible et l'attaquant comme `startCinematic` (écart 2,6, murs à ±27,5), puis la fonction `check` de `tests/Cinematography.test.luau` recopiée telle quelle, sur SHIN, `Fatal`, `hp` 300, attaquant de x = -27,5 à 27,5 tous les 0,2 stud ;
  - en jeu : SHIN a déjà gagné une manche, il a **le dos au mur** (à moins de 2,5 studs), et son COUP FATAL tue : FINAL DIVISION se joue.
- **Ce qui se passe** (prouvé sur le labo) :
  - plan `shin-fd-eye` (gros plan de son œil, t60-t119, une seconde) ;
  - quand SHIN est au-delà de x = 25,1 (mur droit, il frappe vers la gauche) ou en deçà de x = -25,5 (mur gauche, il frappe vers la droite), la caméra passe entre 0 et 0,33 stud de l'avant-bras ou de la main de la cible, sur 12 à 60 images (limite d'un gros plan : 0,35) ;
  - de x = -27,5 à -26,1, et de 25,5 à 26,3, la caméra est **dans** le bras (0,000) pendant tout le plan ;
  - sur le storyboard rendu dos au mur gauche : à t60 et t72, toute l'image est l'avant-bras de la cible ; de t84 à t108, son bras et le katana coupent l'image. Au centre, le même plan montre bien la tête de SHIN.
- **Ce qui devrait se passer** : le gros plan de l'œil de SHIN, dégagé, où qu'il soit dans l'arène.
- **Cause** (prouvée) :
  - `src/shared/Finishers.luau:107` : `front = inside(ctx, cx - dir * 5.8)`. SHIN se place à 5,8 studs devant la cible. Dos au mur, `inside` (`Finishers.luau:35-37`) le bloque à ±27 : il n'est plus qu'à 2,1-3,8 studs de la cible ;
  - la caméra du plan de l'œil (`Finishers.luau:134`) est à 1,85-2,4 studs de sa tête, du côté de la cible : elle tombe dans le bras de la cible.
- **Pourquoi le labo ne le voit pas** :
  - `debugCinematic` centre le combat au plus à ±24 (`src/shared/CombatSimulation.luau:2785`), et l'attaquant y est toujours à gauche ;
  - `Cinematography` ne joue que x = 0 et x = 25 (`tests/Cinematography.test.luau:129`), où c'est la **cible** qui a le dos au mur, jamais l'attaquant.
- **Gravité** : majeur. Très visible quand cela arrive : une seconde du plan le plus marquant du finisher, celui qui clôt le match, cachée par un bras. Il faut que SHIN soit acculé au moment d'achever : une situation courante en combat (supposé).
- **Statut** : `corrigé (v0.36.5)`, à confirmer en jeu par Wilhem. Toute la scène de SHIN recule loin du mur, plans inchangés. Les 19 finishers sont testés dos au mur des deux côtés dans `Cinematography` (38 tests ; sur l'ancien code, ils échouent pour SHIN et TARO).
- **Vérifié par la chasse du 19/10** :
  - storyboards `luau tests/Storyboard.luau -a SHIN Fatal - 1 20 wall-left|wall-right` : le gros plan de l'œil est dégagé ; dos au mur gauche, chaque caméra est celle du centre décalée de 22,5 studs, à l'identique ;
  - SHIN, à toutes les places de l'arène (cible de -27,5 à 27,5 tous les 0,5 stud, deux sens) : aucun corps au-delà de x = 27, aucun plan où la cible cache son sujet.
- **Le même mécanisme existe ailleurs** : dans le COUP FATAL classique de SHIN (ISSEN), voir B-017, et dans d'autres scènes, voir B-018.
- **Piste** :
  - déplacer toute la scène plutôt que SHIN seul, comme le font celles de KAI (`Finishers.luau:455`) et de NOVA (`Finishers.luau:2677-2679`). Par exemple, poser la cible à au moins 5,8 + 1 studs du mur côté SHIN, puis `front` à 5,8 d'elle ;
  - ajouter au test de cadrage un cas « attaquant dos au mur », des deux côtés : une option de placement dans `Kit.play`, pour toutes les cinématiques et tous les finishers.

## B-012 · NOVA, FATAL ERROR : la visière est enfouie dans sa tête au gros plan du « 0 »
- **Date** : 18 octobre 2026.
- **Source** : trouvé par la chasse, en relisant le storyboard de la v0.36.4 (`luau tests/Storyboard.luau -a NOVA Fatal - 1 20`).
- **Comment reproduire** :
  - le storyboard ne le montre pas : il dessine les formes par-dessus les corps, sans profondeur ;
  - ici : on joue la scène des deux côtés (`Kit.play`, avec et sans `mirror`). À chaque image, on mesure quelle part du trait de visière (les `slash` posés sur `Head`) tombe dans la boîte de sa tête (1,1 × 1,1 × 1,0).
- **Ce qui se passe** (prouvé sur le labo, même chose des deux côtés) :
  - t420-t449, plan `nova-fe-zero` (« 0 », silence, gros plan `face` sur sa visière) : **85 à 88 %** du trait est dans la tête, 12 à 15 % dépasse sur le visage ;
  - t620-t659, plan `nova-fe-last` (sa visière s'éteint) : 80 à 88 % dans la tête ;
  - t6-t23 (démarrage, avant sa pose d'attaque) : 63 % ;
  - seul t24-t69 est entièrement sur le visage ;
  - le client dessine un `slash` en deux pièces 3D (`src/client/CinematicController.luau:1128-1138`) : la tête cache ce qui est dedans. Au gros plan du « 0 », on ne verrait sans doute qu'un bout de trait sur le côté du visage (supposé : non vérifiable d'ici).
- **Ce qui devrait se passer** : un trait de lumière en travers des yeux, devant le visage, surtout dans le plan qui lui est consacré.
- **Cause** (prouvée) :
  - `src/shared/Finishers.luau:2693` : `fwd` et `side` sont les axes du **corps** (tourné de 3/4, `ModelYaw`) ;
  - `visor()` (`Finishers.luau:2733-2737`) pose le trait avec `P(A, "Head", décalage)`, dont le décalage est en axes du monde (`CinematicController.luau:774-789`, `tests/CinematicKit.luau:33-43`) ;
  - dans sa pose de tir, sa tête est tournée d'environ 40° de plus vers la caméra que son corps ; au repos, d'environ 17° dans l'autre sens. Dans les deux cas, le trait passe à travers la tête.
- **À côté**, sans entrée propre : les étincelles de la boule de KAI (MAXIMUM KAIENHA) et le trait du pied de ZEPHYR sont posés de la même façon, en partie dans le corps. Mais ce sont des éclats brefs, qui tournent : ce n'est pas l'objet de leur plan.
- **Gravité** : mineur (visuel, ponctuel, mais c'est le sujet du plan).
- **Statut** : `ouvert`.
- **Piste** :
  - poser la visière dans le repère de la tête : une option de point « décalage dans le repère de la pièce », à ajouter dans `CinematicController` (`resolve`) et dans `CinematicKit.resolve` ;
  - ou, plus simple, l'avancer (environ 0,75 au lieu de 0,5) et vérifier au moins la pose de tir ;
  - un test : le trait de visière hors de la boîte de la tête aux plans `nova-fe-zero` et `nova-fe-last`.

## B-013 · NOVA, FATAL ERROR : le rail part d'une main mesurée sur le rig du labo, pas de sa vraie main
- **Date** : 18 octobre 2026.
- **Source** : trouvé par la chasse en relisant `S.NOVA`. Le journal de la v0.36.4 le note déjà en problème ouvert (« le rail sur le gantelet d'un vrai avatar »), mais il n'était pas dans cette liste.
- **Ce qui est prouvé** :
  - `src/shared/Finishers.luau:2697` : la main est faite de nombres fixes (2,13 ou -2,44 ; 4,5 ; 1,31 ou 0,54), mesurés sur le rig KAI du labo. Les 8 anneaux, la bouche du canon et le trait du tir en découlent (`Finishers.luau:2698-2705`) ;
  - en jeu, chaque joueur se bat avec son propre avatar Roblox, R15 ou R6, habillé du kit (`src/server/RigBuilder.luau:1750`, `preferredRig` vers la ligne 1930). La taille et les bras changent d'un avatar à l'autre ;
  - c'est la seule scène de finisher qui pose une forme sur une main mesurée : ailleurs, ce qui part d'une main suit la vraie pièce (`P(A, "LeftHand")`, etc.).
- **Ce qui est supposé** : sur un R15 petit ou grand, ou sur un R6, le premier anneau peut flotter à quelques dixièmes de stud du gantelet, ou entrer dans le bras. Ce n'est pas mesurable d'ici : `CinematicKit` ne pose que le rig KAI.
- **Comment le vérifier** : en jeu, avec un avatar R6 puis un petit R15, gagner une manche avec NOVA et tuer au COUP FATAL. Regarder les plans `nova-fe-dock` (t250-t329) et `nova-fe-three` (t330-t359).
- **Gravité** : cosmétique (si confirmé).
- **Statut** : `à confirmer` (Wilhem, en jeu).
- **Piste** : poser les anneaux sur la vraie main, avec `P(A, "LeftHand", axe × k)`, en gardant l'axe calculé vers la cible.

## B-014 · NOVA, FATAL ERROR : la scène la plus lourde du jeu, 9 lumières à la fois, même en mode réduit
- **Date** : 18 octobre 2026.
- **Source** : trouvé par la chasse (piège connu : le mobile, le mode réduit, les performances).
- **Comment reproduire** : on joue les 19 finishers (`Kit.play`), et on compte ce que le pool de `CinematicController:drawShapes` doit tenir à chaque image. Pièces par forme : sphère 3 plus une `PointLight`, anneau 22, poussière 40, trait 2.
- **Ce qui a été mesuré** (prouvé, sur le labo) :
  - NOVA : jusqu'à **30 formes** dans une image, environ **417 pièces** dans le pool, **9 lumières** allumées en même temps (ses 8 drones et la boule du canon) ;
  - le plus lourd des 18 autres : KAI, 251 pièces et 1 lumière. Aucun autre finisher n'allume plus d'une lumière à la fois ;
  - en mode réduit, les sphères gardent leur lumière (`src/client/CinematicController.luau:1052-1064`, aucun test de `reduced`) ; les anneaux n'affichent que 12 segments, mais en gardent 22.
- **Ce qui est supposé** : une baisse d'images par seconde sur téléphone, de t44 (premiers drones) à t450 (le tir). Ce n'est pas mesurable d'ici.
- **Ce qui devrait se passer** : en mode réduit, une scène qui ne coûte pas plus que les autres.
- **Gravité** : mineur (si confirmé : le mobile, pendant 7 secondes).
- **Statut** : `à confirmer` (Wilhem : la scène sur un téléphone, ou avec SETTINGS → REDUCED EFFECTS et le compteur d'images de Roblox, par exemple le MicroProfiler, Ctrl+F6).
- **Piste** :
  - en mode réduit, ne pas allumer la lumière des petites sphères (rayon sous 0,3 : les drones) ;
  - ou une seule lumière par scène pour les drones.

## B-015 · Plusieurs finishers dessinent un corps au-delà de la ligne peinte x = 28
- **Date** : 18 octobre 2026.
- **Source** : relevé par l'agent `validation` (routine du 18/10), à confirmer par l'agent `bugs`.
- **Ce qui se passe** : dans HEAD (v0.36.4), plusieurs finishers dessinent un corps au-delà de la ligne x = 28 : SYLVA 31,3, ASTER 31,1, AKEMI 29,8, KAZAN 29,6, YUKINA 28,9, VENOM 28,8, ELIAN 28,2. Dos au mur, ils vont jusqu'à 31,4. Le sol continue jusqu'à ±40.
- **Ce qui devrait se passer** : les corps restent sur le sol de combat, x de -28 à 28 (`CLAUDE.md` : ce sol ne change jamais).
- **Confirmé par la chasse du 19/10, sur la v0.36.5** :
  - **comment reproduire** : un script hors dépôt joue les 19 finishers (`Fatal`, `hp` 300) à toutes les places possibles, comme `startCinematic` (`src/shared/CombatSimulation.luau:1349-1356`) : cible de x = -27,5 à 27,5 tous les 0,5 stud, attaquant à 2,6 d'un côté ou de l'autre, soit 222 parties par finisher. Il relève la position du corps (`view.x`, celle que le client donne au rig) à chaque image ;
  - **ce qui a été mesuré** : 11 finishers sur 19 posent un corps au-delà de x = 28, et toujours à l'écran. La validation ne jouait pas la **cible dos au mur** (cible à ±27,5) : c'est là que les écarts sont les plus grands ;

    | Finisher | Corps le plus loin | Corps entier au-delà (x > 29) | Plans |
    |---|---|---|---|
    | SYLVA | 33,5 | 5,6 s (attaquant dos au mur) | `sylva-gh-aim`, `-bind`, `-roots`, `-hunt`, `-stalk` |
    | ASTER | 33,3 (cible en l'air, y = 11) | 0,9 s | `aster-sc-orbit`, `-collapse` |
    | AKEMI | 32,0 | 1,8 s (cible dos au mur) | `akemi-ts-after` |
    | KAZAN | 31,6 | 4,0 s (cible dos au mur) | `kazan-cc-rake`, `-x`, `-after` |
    | YUKINA | 31,1 | 3,9 s (attaquant dos au mur) | `yukina-fr-away`, `-shatter`, `-after` |
    | VENOM | 31,0 | 1,1 s | `venom-tf-kneel`, `-strike2` |
    | ELIAN | 30,4 | 0,6 s | `elian-fm-walk` |
    | ZEPHYR | 30,0 | 0,4 s | `zephyr-ge-flash` |
    | DAICHA | 29,7 | 2,6 s | `daicha-iw-crash`, `-after` |
    | HIBECARES, TARO | 28,7 et 28,4 | jamais | (moins d'un stud au-delà) |

  - les 8 autres restent sur le sol : KAI, RAIJIN, RYUKEN, SHIN, HIBIKI, GORAN, KUREN, NOVA ;
  - aucun corps ne sort du plancher (x = ±40).
- **Cause** (prouvée) : ces scènes placent l'attaquant ou la cible à une distance fixe du centre, sans `inside` ni `room`. Exemples :
  - SYLVA : `src/shared/Finishers.luau:2624` (`cx - dir * 6.5`) et `:2642` (`cx + dir * 4.2`) ;
  - KAZAN : `:2412` (`cx + dir * 2.6`) ;
  - YUKINA : `:1768-1775` (`cx - dir * 6.2`) ;
  - ELIAN : `:3001` (`cx - dir * lerp(5.5, 2.4, q)`).
- **Pourquoi aucun test ne le voit** : `Cinematography` ne regarde que la caméra et le cadrage, jamais où sont les corps.
- **Piste** :
  - un test « corps sur le sol » sur les 19 finishers, joués au centre, l'attaquant dos au mur **et la cible dos au mur** (`Kit.play` n'a pas encore ce dernier placement) ;
  - puis le placement de chaque scène, comme pour SHIN (`room`).
- **Gravité** : mineur, relevée depuis « cosmétique ». C'est visible : jusqu'à 5,5 studs au-delà de la ligne, ou un corps entier au-delà pendant 5,6 s (SYLVA), toujours à l'écran. Mais rien n'est faux en combat.
- **Statut** : `ouvert` (confirmé le 19/10). Les autres cinématiques ont le même défaut, en plus fort : voir B-016. Depuis la v0.36.9, la ligne d'ELIAN est `Finishers.luau:3244` (et non plus `:3001`). La nouvelle scène de KUROEN, elle, reste sur le sol (`room`, tests de placement de `Cinematography`).
- **27/10, sur la v0.36.12** : la ligne d'ELIAN est maintenant `Finishers.luau:3514` (SAMSARA est inséré avant elle) ; les autres lignes citées n'ont pas bougé. Script de la chasse : les 21 finishers dans 6 placements (centre des deux côtés, attaquant dos à chaque mur, **cible** dos à chaque mur, à x = ±27,5 comme `startCinematic` ; une option ajoutée à une copie de `CinematicKit`, hors dépôt), en relevant la pièce de corps la plus loin :
  - SAMSARA (ASURA) et BLACK SUN (KUROEN) restent sur le sol partout : 27,4 au plus (une main), grâce à `room`. La validation notait que son placement « cible au mur » ne dépasse jamais x = 25,3 : pour ces deux scènes, cela ne change rien, `room` ramène la cible au même endroit depuis 25,3 ou 27,5 ;
  - les 11 autres du tableau ci-dessus sortent toujours, comme le 19/10 (mesure par pièce, donc un peu plus loin que la mesure par corps : jusqu'à 36,5 pour une main d'ASTER).

## B-016 · Près d'un mur, les ultimes posent des corps loin au-delà de la ligne x = 28, et la caméra au-delà du bout du sol
- **Date** : 19 octobre 2026.
- **Source** : trouvé par la chasse (routine du matin), en jouant Rush, Éveil, Porte et Fatal dos au mur, ce qu'aucun test ne fait.
- **Comment reproduire** :
  - `Kit.play(kit, kind, style, hp, 0, onFrame, mirror, true)` (option `wall` de `tests/CinematicKit.luau`), des deux côtés, en relevant `views[i].x` et la caméra ;
  - pour la cible dos au mur, le même placement que `startCinematic` (`src/shared/CombatSimulation.luau:1349-1356`) avec la cible à ±27,5 (script de la chasse, hors dépôt) ;
  - le plus parlant : `luau tests/Storyboard.luau -a KAI Rush - 0 6 wall-left`, puis `python3 tools/storyboard.py`.
- **Ce qui se passe** (prouvé sur le labo, v0.36.5, 22 kits × Rush, Éveil, Porte, Fatal, 11 places dont les deux murs, deux sens) :
  - 84 cinématiques sur 88 posent un corps au-delà de x = 28, 56 un corps entier au-delà de x = 29, 17 au-delà de x = 31. Toujours dans l'image ;
  - les pires :

    | Cinématique | Corps le plus loin | Placement | Plans |
    |---|---|---|---|
    | DAICHA, Rush | cible à **37,0** (3 studs du bout du sol) | cible dos au mur | `daicha-domain-blast`, `-after` |
    | AKEMI, Fatal | 34,5 | cible dos au mur | `akemi-instant-leave` |
    | KAI, Rush et Éveil | 33,9 (KAI 6,4 studs derrière le mur) | KAI dos au mur | `rush-ready`, `rush-dash`, `eveil-eyes` |
    | SHIN, Porte | 32,9, pendant 2,5 s | SHIN dos au mur | `shin-zero-horizon` à `shin-zero-hilt` |
    | ZEPHYR, Rush et Éveil | 32,9, pendant 2 s | ZEPHYR dos au mur | `zephyr-vent-gather` … `-dash` |
    | DAICHA, Fatal | 32,4, au-delà de 28 pendant 5,8 s | DAICHA dos au mur | `daicha-void-bind` … |

  - la caméra passe au-delà du bout du sol (x = ±40) dans 42 cinématiques sur 88. Les pires : SHIN, Porte (x = 49 à 50,7, plan `shin-zero-horizon`), DAICHA, Rush (47 à 48), ZEPHYR, KAI, GORAN, Rush (43 à 44). Au centre, jamais ;
  - au plan `shin-zero-horizon` dos au mur droit, toute l'extrémité du sol (x = 40, de z = -11 à 11) est dans l'image ; au centre, ni la ligne x = 28 ni le bout du sol n'y sont.
- **Ce qui est supposé** (non vérifiable d'ici, rendu Roblox) : le bout du plancher et le vide derrière lui se voient dans ces plans larges ; un perso qui attend 6 studs derrière la ligne néon se lit comme « hors de l'arène ».
- **Ce qui ne casse pas** : avec la vérification de `Cinematography` recopiée telle quelle, dos aux deux murs, les 22 kits passent, à deux plans près. Ces deux plans échouent depuis la droite, mur ou pas, et ils sont déjà connus (B-010) : `zephyr-lune-launch` (Fatal de ZEPHYR, point de mise au point à 0,7845 de la demi-hauteur pour 0,78 permis) et `daicha-domain-clench` (Rush de DAICHA, 0,7802). Un test Rush/Éveil/Porte dos au mur droit échouera d'abord sur eux. Le COUP FATAL classique qui tue (sans FATAL FINISHER, son lanceur n'a pas encore gagné de manche), jamais joué par le labo pour les 19 kits qui ont un finisher, passe aussi : 114 parties, seul `zephyr-lune-launch` échoue.
- **Ce qui devrait se passer** : les corps restent sur le sol de combat, et la scène recule loin du mur, comme celle de SHIN depuis B-011.
- **Cause** (prouvée) :
  - `src/shared/CinematicDirector.luau` pose les places à une distance fixe du centre, sans borne :
    - KAI, Rush : `:269` (`cx - dir * 9`) ;
    - ZEPHYR, Rush : `:972` (`home = cx - dir * 8`) ;
    - SHIN, Porte : `:1961` (`cx - dir * 8`) ;
    - DAICHA, Rush : la cible est poussée de 4,5 (`:2041`), puis projetée de 5 (`:2123`). `roomAhead` (`:230`) existe pour cela, mais cette scène ne s'en sert pas ;
  - `clean` (`:5098-5106`) écarte l'attaquant à `ROOM` = 2,8 de la cible (`:5094`) sans le garder sur le sol.
- **Pourquoi aucun test ne le voit** : `Cinematography` ne joue Rush, Éveil et Porte qu'à x = 0 et x = 25, l'attaquant à gauche (`tests/Cinematography.test.luau:127-139`). L'attaquant n'y est jamais dos au mur, et aucun test ne regarde où sont les corps.
- **Gravité** : mineur. C'est très fréquent (un ultime lancé acculé), et visible plusieurs secondes, mais rien n'est faux en combat : le serveur garde ses positions et le client revient sur elles à la fin.
- **Statut** : `ouvert`.
- **Piste** :
  - le même `room` que pour SHIN (`Finishers.luau:43-47`), à porter dans le directeur pour les scènes « loin du centre » ;
  - `roomAhead` pour les cibles projetées ;
  - un `clean` qui garde l'attaquant sur le sol (il recule alors la cible) ;
  - un test « corps sur le sol » sur toutes les cinématiques, au centre et dos à chaque mur (attaquant et cible) ;
  - ajouter les Rush, Éveil et Porte dos au mur à `Cinematography`, en traitant d'abord les deux plans de B-010.

## B-017 · SHIN, COUP FATAL ISSEN dos au mur : le duel à 12 studs se joue à 2,8, et la cible cache SHIN dans ses gros plans
- **Date** : 19 octobre 2026.
- **Source** : trouvé par la chasse, dans le COUP FATAL classique de SHIN (一閃 ISSEN, l'idée de Wilhem : « un vieux film de samouraï », les deux très loin l'un de l'autre). C'est le défaut de B-011, dans une autre scène.
- **Comment reproduire** :
  - `luau tests/Storyboard.luau -a SHIN Fatal - 0 12 wall-right`, puis `python3 tools/storyboard.py`, à comparer avec `… left` ;
  - en jeu : SHIN acculé à son mur lance son COUP FATAL (qu'il tue ou non : le fatal classique se joue à chaque fois que ce n'est pas un FATAL FINISHER).
- **Ce qui se passe** (prouvé sur le labo) :
  - au centre, SHIN attend à 12 studs de la cible. Dès qu'il est à moins de 11 studs de la ligne de son côté (x = ±17), l'écart fond : 9,5 studs à x = ±20,1, et 2,8 seulement dos au mur ;
  - dos au mur, sur le storyboard :
    - le plan large `shin-issen-duel` montre deux corps collés ;
    - le gros plan des yeux (`shin-issen-eyes`) et celui de la cible (`shin-issen-foe`) sont encombrés par l'autre corps et le katana ;
    - au plan `shin-issen-still`, les corps se confondent ;
  - la main sur la garde (`shin-issen-hilt`, t88-t127) : SHIN au mur droit, sa tête est cachée par la cible à 60 % en moyenne, à plus de moitié pendant 35 images sur 40. Au mur gauche, 27 % en moyenne. Au centre, 0 % ;
  - la vérification de `Cinematography` passe : elle ne regarde pas si le sujet est caché.
- **Ce qui devrait se passer** : le même film qu'au centre, où que soit SHIN.
- **Cause** (prouvée) :
  - `src/shared/CinematicDirector.luau:2999` : `far = FATAL.inside(ctx, cx - dir * 12)`. Dos au mur, `FATAL.inside` le bloque à ±27, à 2,1 studs de la cible ;
  - puis `clean` (`:5098-5106`) l'écarte à 2,8 ;
  - la v0.36.5 a corrigé ce mécanisme dans le FATAL FINISHER de SHIN seulement (`room`, `Finishers.luau:43-47`).
- **Gravité** : majeur. Ce COUP FATAL se voit bien plus souvent que le finisher, et toute sa mise en scène (le duel à distance, la garde, l'immobilité) disparaît pendant 2,5 secondes.
- **Statut** : `corrigé (v0.36.6)`, à confirmer en jeu par Wilhem. Toute la scène recule loin du mur (`FATAL.room`, dans `CinematicDirector.luau`) : 12 studs de sol du côté de SHIN, 10 au-delà de la cible. Au centre, la planche est identique à l'octet près ; dos au mur, c'est le même film décalé de 16,3 studs. Quatre tests dans `Cinematography` (SHIN dos à chaque mur, cible près de chaque mur) ; ils échouent sur l'ancien code. Validé au deuxième passage (le premier a refusé une exception de test trop large pour ZEPHYR, resserrée depuis).
- **Piste** :
  - reculer toute la scène loin du mur, comme `room` : 12 studs de sol du côté de SHIN, 10 au-delà de la cible (`beyond`) ;
  - un test : le fatal de chaque kit dos au mur, avec une vérification « sujet caché par l'autre corps » (voir B-018).

## B-018 · Dos au mur, d'autres plans cachent leur sujet derrière l'autre corps
- **Date** : 19 octobre 2026.
- **Source** : trouvé par la chasse, avec une mesure que les tests n'ont pas. Pour le point visé de chaque plan (`focus`), on échantillonne la pièce visée en 27 ou 125 points, et on compte la part que l'autre corps cache à la caméra.
- **Comment reproduire** :
  - `Kit.play` au centre (gauche, puis `mirror`) et dos à chaque mur (`wall`), toutes les cinématiques des 22 kits, finishers compris (script de la chasse, hors dépôt) ;
  - sont retenus les plans où un placement cache plus de la moitié du sujet pendant au moins 15 images, alors que le labo (centre, gauche) le fait moins de 5 fois ;
  - storyboards : `luau tests/Storyboard.luau -a KUREN Fatal - 1 15 wall-right` ; `-a TARO Fatal - 1 20 wall-right` ; `-a HIBIKI Fatal - 0 6 wall-right`.
- **Ce qui se passe** (prouvé sur le labo, rig KAI) :

  | Plan | Placement | Sujet caché à plus de 50 % | Au centre |
  |---|---|---|---|
  | KUREN, FATAL FINISHER, `kuren-cv-palm` (ouverture, t0-t89) | KUREN dos au mur droit | sa tête : 83 images sur 90, 63 % en moyenne | 0 % |
  | TARO, FATAL FINISHER, `taro-dr-guard` (t0-t59) | TARO dos au mur droit | sa tête : 44 images sur 60, 61 % en moyenne | 0 % |
  | HIBIKI, COUP FATAL, `hibiki-fatal-blow` (le coup) | HIBIKI dos au mur, des deux côtés | la cible : 21 à 24 images sur 24, 76 à 85 % | 4 % |
  | ELIAN, Porte, `elian-gate-advance` | ELIAN dos au mur gauche | la cible : 35 images sur 42, 48 % | 10 % |

  - dans le gros plan de la garde de TARO, la boîte de la cible couvre jusqu'à 64-70 % de l'image dos au mur, contre 15-20 % au centre. Le plan est écrit pour que la cible reste hors champ (`Finishers.luau:347`) ;
  - plus courts, 15 à 20 images : NOVA (Rush, `nova-rush-blows-a`), KUROEN SHIN (Éveil, `trueemperor-eveil-approach`), ELIAN (Fatal, `elian-fatal-levitate`), SYLVA (Éveil, `sylva-eveil-backturn`), HIBIKI (Éveil, `hibiki-eveil-final`), ASURA (Éveil, `asura-eveil-crater`).
- **Ce qui devrait se passer** : le sujet du plan visible, comme au centre.
- **Cause** (prouvée pour les trois premiers) : comme B-011, l'attaquant est bloqué au mur au lieu de reculer toute la scène, puis `clean` le met à 2,8 de la cible. Le plan, composé pour l'écart prévu, met alors la cible dans l'axe :
  - KUREN : `src/shared/Finishers.luau:2454` (`inside(ctx, cx - dir * 4.6)`). L'écart passe de 4,6 à 2,8 ;
  - TARO : `Finishers.luau:316` (`start = inside(ctx, cx - dir * 5.2)`), et la caméra est posée sur `start` (`:349`), alors que `clean` a mis TARO ailleurs (27,7 au lieu de 27). L'écart passe de 5,2 à 2,8 ;
  - HIBIKI : `GEN.place` (`src/shared/CinematicDirector.luau:3669-3671`) sur `cx - dir * GEN.reach(style)` (`:3853`). L'écart passe de 5,5 à 2,2.
- **Ce qui ne se mesure pas d'ici** : les vrais avatars n'ont pas la taille du rig KAI du labo ; la part cachée change avec eux.
- **Gravité** : mineur. Le pire est l'ouverture du finisher de KUREN (1,5 s, visage aux deux tiers caché).
- **Statut** : `ouvert`.
- **Revérifié par la chasse du 20/10, sur la v0.36.6**, avec la mesure du dépôt (`Kit.hiddenShare` de `tests/CinematicKit.luau`, appliquée au point visé de chaque plan, comme le test ISSEN) :

  | Plan | Centre | Mur gauche | Mur droit |
  |---|---|---|---|
  | `kuren-cv-palm` | 0 % | 7 % | 72 % en moyenne, 83 images sur 90 à plus de moitié |
  | `taro-dr-guard` | 0 % | 23 % | 61 %, 43 sur 60 |
  | `hibiki-fatal-blow` | 4 % | 76 %, 58 sur 68 | 87 %, 68 sur 68 |
  | `elian-gate-advance` | 9 % | 49 %, 52 sur 70 | 22 % |

  Le défaut est inchangé : la v0.36.6 n'a touché que l'ISSEN de SHIN. Le test ISSEN fournit maintenant la mesure : il suffit de l'étendre à ces quatre scènes.
- **Piste** :
  - `room` dans ces scènes (et dans `GEN.place` pour les ultimes générés), puis poser les caméras sur les places réelles ;
  - ajouter à `Cinematography` une vérification « sujet caché par l'autre corps » (part de la pièce visée derrière l'autre corps, hors plans par-dessus l'épaule et vue subjective), jouée au centre et dos aux murs.

## B-019 · Joués depuis la droite, la PORTE de KUROEN et le FATAL FINISHER d'ELIAN cachent leur perso derrière la cible
- **Date** : 19 octobre 2026.
- **Source** : trouvé par la chasse, avec la même mesure que B-018. Ce n'est pas lié aux murs : c'est le côté. Le labo ne joue ces cinématiques que depuis la gauche (comme B-010).
- **Comment reproduire** :
  - `luau tests/Storyboard.luau -a KUROEN Gate - 0 12 right`, à comparer avec `… left` ;
  - `luau tests/Storyboard.luau -a ELIAN Fatal - 1 20 right` ;
  - en jeu : KUROEN lance sa PORTE alors qu'il est à droite de sa cible ; ELIAN achève au COUP FATAL après une manche gagnée, à droite de sa cible.
- **Ce qui se passe** (prouvé sur le labo, rig KAI) :
  - KUROEN, Porte, plan d'ouverture `kuroen-gate-backturn` (t0-t69 : il tourne le dos, puis se retourne vers la caméra) :
    - depuis la droite, sa tête est cachée par la tête et le dos de la cible à 76 % en moyenne, à plus de moitié pendant 51 images sur 70 ;
    - dos au mur, 70 sur 70 (jusqu'à 97 % au mur droit) ;
    - depuis la gauche, 12 % ;
  - ELIAN, FATAL FINISHER, plan d'ouverture `elian-fm-walk` (t0-t89) : depuis la droite, sa tête est cachée à 39 % en moyenne, à plus de moitié pendant 41 images sur 90. Depuis la gauche, 4 % ;
  - HIBIKI, COUP FATAL, `hibiki-fatal-blow` : 34 % depuis la droite contre 4 % (8 images à plus de moitié) ; dos au mur, c'est B-018 ;
  - la vérification de `Cinematography` passe dans les deux cas.
- **Cause probable** (supposée) : le rig est tourné de 3/4 vers la caméra (`ModelYaw`, 22°) du même côté quel que soit le sens. Ces plans, réglés depuis la gauche, mettent alors la cible dans l'axe quand on les joue en miroir. Pour KUROEN, l'ouverture `backturn` (`src/shared/CinematicDirector.luau:3935-3944`) a un angle propre à son kit (`turn`, `["gate-backturn"] = 30`, `:4906`).
- **Ce qui devrait se passer** : le perso visible au plan qui le présente, des deux côtés.
- **Gravité** : mineur. Mais fréquent : une PORTE de KUROEN sur deux environ, n'importe où dans l'arène.
- **Statut** : `ouvert`.
- **Piste** :
  - jouer toutes les cinématiques en miroir dans `Cinematography`, avec la vérification « sujet caché » de B-018 ;
  - pour KUROEN, un angle de `backturn` qui dépend du sens.

## B-020 · CHALLENGE · ASURA : un ultime qui l'abat dans sa première vie joue un K.O. complet, puis il se relève
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, avec un fuzz de relais hors dépôt (3 contre 3, défi ASURA, SURVIE) qui vérifie qu'un coup annoncé K.O. finit bien la manche. Le Fuzz du dépôt ne joue ni les relais ni les boss.
- **Comment reproduire** :
  - ici, dans le vrai déroulé, sans le labo : `Sim.setKits(w, "KAI", "ASURA")`, KAI à 20 % de vie et jauge pleine, ASURA à 50 PV, puis KAI appuie sur C (COUP FATAL) ;
  - le fuzz de la chasse le trouve seul dans 20 défis ASURA sur 40 : 15 COUPS FATAUX, 4 ÉVEILS, 1 PORTE. Ce fuzz baisse la vie toutes les 700 images, ce qui favorise le COUP FATAL ;
  - en jeu : CHALLENGE · ASURA, l'abattre la première fois avec un COUP FATAL, un ÉVEIL ou une PORTE.
- **Ce qui se passe** (prouvé dans la simulation ; l'affichage est déduit du code client) :
  - le coup final part avec `ko = true` : la voix K.O. joue (`src/client/SoundController.luau:192`) ;
  - la cinématique se joue en version « qui tue » (`finish`) :
    - COUP FATAL : la cible reste à terre et le titre « K.O. » s'affiche (`FATAL.title`, `src/shared/CinematicDirector.luau:2705`) ;
    - ÉVEIL ou PORTE : la scène K.O. complète de 200 images, avec le fondu au noir et « K.O. · <perso> · VICTORY » (`CinematicDirector.luau:5172-5175`, `:5067`) ;
  - au tick même de `CinematicEnd`, ASURA se relève dans son aura noire (`Revive`), et le combat reprend ;
  - puis, quand le joueur l'abat pour de bon, le vrai K.O. n'a **ni titre ni scène** :
    - `world.finishedByCinematic` est resté à `true` depuis la cinématique (il n'est remis à zéro qu'à la manche suivante, `src/shared/CombatSimulation.luau:106`). Le `RoundEnd` part donc avec `inCinematic = true` (mesuré), et le HUD tait le « K.O. » (`src/client/HUDController.luau:1439`) ;
    - le client a noté `finishEpoch` pendant la cinématique (`src/client/CinematicController.luau:759`). L'epoch n'a pas changé, donc la scène K.O. du match est sautée (`:725`) ;
    - le match se termine sur l'écran de résultat, sans aucun K.O. à l'écran (supposé : non vérifiable d'ici) ;
  - le titre NO MERCY compte ce faux K.O. : `GameModes.featEvent` lit `event.ko` sur un coup `fatal` (`src/shared/GameModes.luau:174`).
- **Ce qui devrait se passer** : abattu dans sa première vie, ASURA tombe sans K.O. annoncé, puis se relève. Le seul K.O. est celui de la fin, avec sa scène.
- **Cause** (prouvée) :
  - un coup normal tient compte de la seconde vie : `event.ko = not CombatSimulation.canRevive(d)` (`CombatSimulation.luau:2029`) ;
  - une cinématique ne le fait pas :
    - `finish` est décidé sans `canRevive` (`CombatSimulation.luau:1281` pour le COUP FATAL, `:1288` pour l'ÉVEIL et la PORTE) ;
    - le coup final annonce `ko = d.hp <= 0` (`:2412`) ;
    - la fin pose `finishedByCinematic = state.finish or d.hp <= 0` (`:2441`) ;
  - ASURA est le seul kit avec `SecondLife` (`src/shared/MoveData.luau:1400`). Le défaut ne touche donc que le défi ASURA, le mode boss le plus mis en avant.
- **Gravité** : majeur. C'est très visible : un « K.O. · VICTORY » suivi d'un boss qui se relève, puis une victoire sans K.O. Et c'est fréquent : il suffit qu'un ultime l'abatte, ce qui arrive dès qu'il descend sous 960 PV (ÉVEIL, PORTE) ou sous 1 600 PV après un combo (COUP FATAL), sur 3 200.
- **Statut** : `corrigé (v0.36.8)`, à confirmer en jeu par Wilhem. Correction dans `CombatSimulation.luau` (`fells` séparé de `finish`) et 5 tests dans `CombatSimulation.test` ; validé le 21/10 (378 duels et 480 défis CPU instrumentés : 0 faux K.O. au lieu de 132 ; les 21 autres cibles identiques au tick près). Livré le 22/10 : la livraison du 21 avait été oubliée après le verdict.
- **Revérifié par la chasse du 22/10, sur la v0.36.8** (`git diff 3d188f8..f009349`) : aucun effet de bord dans la simulation, un faux raccord à l'image (B-030).
  - fuzz hors dépôt, CPU de niveau 4 contre CPU, joué deux fois sur les mêmes graines : avec le module d'avant la correction, puis avec celui de la v0.36.8. Chaque mode est joué au naturel, puis « sous pression » (jauges pleines et vie × 0,55 toutes les 700 images) :

    | Mode | Matchs | Fins de manche | Matchs différents, ancien et nouveau module | Écarts aux invariants, v0.36.8 |
    |---|---|---|---|---|
    | relais 2v2 et 3v3 | 240 | 867 | 0 | 0 |
    | 1v1 au meilleur des 3 | 240 | 604 | 0 | 0 |
    | SURVIE (ajout de l'adversaire suivant recopié du serveur) | 240 | 1 382 | 0 | 0 |
    | CHALLENGE · KUROEN SHIN, équipes de 1 à 3 | 240 | 457 | 0 | 0 |
    | CHALLENGE · ASURA, équipes de 1 à 3 | 240 | 480 | 25 | 0 (109 avec l'ancien module : les faux K.O.) |

  - invariants vérifiés à chaque tick :
    - un coup annoncé K.O. finit la manche, sans `Revive` avant le `RoundEnd` ;
    - `Revive` seulement pour un kit à `SecondLife`, une fois par match, avec `finishedByCinematic` faux ;
    - aucun `RoundEnd` tant qu'un combattant à 0 PV peut se relever ;
    - `inCinematic` vrai seulement si le coup K.O. venait d'une cinématique ;
    - `CinematicEnd.finish` vrai seulement si la cible est à 0 PV ;
    - jamais de FATAL FINISHER sur une première vie ;
    - `finishedByCinematic` faux au début de chaque manche ;
  - `canRevive` en général : vrai seulement pour ASURA avant sa relève. ASURA n'est que dans le défi : il n'est ni dans `MoveData.KitOrder` (`MoveData.luau:1445-1446`), ni dans les équipes CPU des relais (`GameModes.cpuTeam`), ni dans la SURVIE (`GameModes.survivalOpponent`). `revived` passe d'une manche à l'autre (`CombatSimulation.luau:92`), et `resetMatch` remet tout à zéro à chaque match (`:219`). Dans un défi en équipe, ASURA garde donc sa seconde vie consommée quand le perso suivant du joueur entre (vérifié dans le fuzz : jamais deux `Revive`) ;
  - KUROEN SHIN n'a pas de `SecondLife` (`MoveData.luau:1427-1430`) : les cinq expressions retouchées sont les anciennes pour lui. Le fuzz le confirme : 240 défis identiques au tick près ;
  - la limite notée par la validation (QTE allumés, un COUP FATAL raté laisse la première vie debout) n'a aucun effet dans le jeu livré : `CinematicPrompts = false` (`CombatConfig.luau:107`) ;
  - **le seul effet de bord trouvé est à l'image.** La scène du COUP FATAL, dans sa version « cible debout », finit ASURA **à genoux**. Mais la simulation le couche au même instant (`Knockdown`, puis `Revive`) : voir B-030.
- **Revérifié par la chasse du 21/10, sur la v0.36.7** (le code de `CombatSimulation` n'a pas changé depuis le 20/10 ; toutes les lignes citées tiennent) :
  - script hors dépôt, dans le vrai déroulé (`Sim.newWorld` hors entraînement, `Sim.setKits(w, KIT, "ASURA")`, attaquant à 20 % et jauge pleine, ASURA à 50 PV), puis on achève ASURA relevé à coups de poing, et on fait suivre chaque événement à `GameModes.featEvent` comme le serveur :

    | Lanceur, coup | Coup final | Fin de la cinématique | Vrai K.O. | NO MERCY |
    |---|---|---|---|---|
    | KAI, COUP FATAL | t312 `Hit` `ko = true`, `finish = true` | t490 `CinematicEnd`, puis `Revive` au même tick | t623 `RoundEnd` avec `inCinematic = true` | compté (1) |
    | SHIN, COUP FATAL | t312, idem | t490, idem | t623, idem | compté (1) |
    | KAI, RUSH (R seul) | t299 `Hit` `ko = true`, `finish = false` | t411, `Revive` | t545 `RoundEnd` avec `inCinematic = true` | non |
    | DAICHA, RUSH | t229 `Hit` `ko = true`, `finish = false` | t318, `Revive` | t437, idem | non |

  - **nouveau : le RUSH aussi.** Son dernier coup peut tuer (`canKO`, `CombatSimulation.luau:2405-2406`) et annonce `ko = true` (`:2412`) : la voix K.O. joue, ASURA se relève. Comme `finish` est faux, le client ne note pas `finishEpoch` : la scène K.O. du match se joue bien à la fin (déduit du code, `CinematicController.luau:725`, `:759`). Seuls la voix et `inCinematic` sont faux. C'est la forme la plus fréquente : le RUSH ne demande ni combo ni vie basse ;
  - **aggravé par la v0.36.7** : depuis la correction de B-021, le compteur `feats.fatalKO` est sauvegardé. Chaque CHALLENGE · ASURA où un COUP FATAL abat sa première vie ajoute un faux K.O. au titre NO MERCY, **pour de bon**.
- **Piste de correction précise** (`src/shared/CombatSimulation.luau`, 5 lignes) :
  1. `:1281` et `:1288` (`startCinematic`) : `finish = … and not CombatSimulation.canRevive(d)`. La scène joue alors sa version « cible encore debout », sans titre K.O. ni scène K.O. ;
  2. `:2352` (le même calcul, refait après les QTE) : ajouter la même condition ;
  3. `:2405` : `local canKO = step.final and (state.type == "Rush" or CombatSimulation.canRevive(d))`. L'ultime peut faire tomber la première vie à 0, et la branche « jeté au sol » (`:2417-2420`) s'applique. Sans ce point, l'ultime le laisse à 1 PV (`math.max(1, …)`), et il faut un coup de plus pour déclencher la seconde vie. Ce choix revient à production ;
  4. `:2412` : `ko = d.hp <= 0 and not CombatSimulation.canRevive(d)`. Le revive n'est posé qu'au tick de `CinematicEnd` (mesuré), donc `canRevive` est encore vrai au coup final ;
  5. `:2441` : `world.finishedByCinematic = state.finish or (d.hp <= 0 and not CombatSimulation.canRevive(d))`.

  Le test à ajouter dans `CombatSimulation` : COUP FATAL, ÉVEIL, PORTE et RUSH qui abattent ASURA dans sa première vie. On attend :
  - aucun `Hit` avec `ko`, et `finish` faux ;
  - un `Revive` ;
  - au vrai K.O., `RoundEnd` avec `inCinematic = false` ;
  - `feats.fatalKO` inchangé.

  Puis les relais et les boss dans le Fuzz, avec l'invariant « un coup annoncé K.O. finit la manche » (le fuzz de relais de la chasse du 21/10 : 24 matchs 2v2 et 3v3, 77 manches, aucun écart hors ASURA).
- **Risque de la correction : faible.**
  - `canRevive(d)` n'est vrai que pour ASURA avant sa résurrection (`SecondLife`, `MoveData.luau:1400`, seul kit à l'avoir). Pour les 21 autres cibles, les cinq expressions redeviennent exactement les anciennes : aucun changement possible hors du défi ASURA ;
  - pour ASURA, la scène change de version : « cible debout » au lieu de « K.O. ». À relire au storyboard ;
  - le FATAL FINISHER ne peut pas se déclencher contre lui : le joueur n'a aucune manche gagnée avant la fin du défi ;
  - à relancer : CombatSimulation, Fuzz, Kits, Cinematography, `BossDuel` (ASURA).
- **Ancienne piste** (20/10, toujours valable) :
  - production choisit si la scène doit aussi mettre en scène la chute avant la résurrection ;
  - ajouter les relais et les boss au Fuzz, avec l'invariant « un coup annoncé K.O. finit la manche ».

## B-021 · La cote 2v2 et 3v3, les compteurs des titres et leur étoile sont perdus à chaque reconnexion
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, en relisant le chargement des profils (`src/server/init.server.luau`) à côté des modules purs qui écrivent dans le profil.
- **Comment reproduire** :
  - ici : un script hors dépôt recopie tels quels `defaultProfile()` (`init.server.luau:117-144`) et la boucle de chargement (`:196-198`). Il joue une session (cote 1v1 1180, 2v2 1240, 3v3 1310 ; compteurs de titres ; NO MERCY gagné), la sauvegarde comme `writeProfile` (`table.clone`), puis la recharge. Résultat :
    - 1v1 : 1180, gardée ;
    - 2v2 et 3v3 : **1000**, et `played` passe à faux ;
    - `feats` et `earnedTitles` : `nil` ;
    - NO MERCY reste dans la liste des titres, mais **sans son étoile** ;
    - BREAKER : 0 sur 25, au lieu de 24 ;
  - en jeu : jouer un CLASSÉ 2v2, quitter, revenir. Le menu affiche 1000 en 2v2.
- **Ce qui se passe** (prouvé sur le code recopié) :
  - au chargement, seules les clés présentes dans `defaultProfile()`, et du même type, sont reprises de la sauvegarde (`init.server.luau:196-198`) ;
  - trois champs écrits par les modules purs n'y sont pas :
    - `ratings` (`Matchmaker.setRating`, `src/server/Matchmaker.luau:169-170`) ;
    - `feats` (`GameModes.featEvent`, `src/shared/GameModes.luau:161-163`) ;
    - `earnedTitles` (`GameModes.grantFeatTitles`, `:202-207`) ;
  - ils sont donc ignorés au chargement. La première écriture de la nouvelle session (`GlobalQueue.stamp` du profil entier) les **efface** aussi de la sauvegarde ;
  - conséquences :
    - la cote 2v2 et 3v3 repart de 1000 à chaque session. Le matchmaking CLASSÉ 2v2 et 3v3 se fait sur cette cote, puis le classement 2v2 ou 3v3 reçoit la cote remise à zéro au premier match ;
    - un titre à exploit (BREAKER : 25 bris de garde ; UNTOUCHABLE : 3 manches PERFECT ; NO MERCY : 5 K.O. au COUP FATAL…) ne s'obtient que dans une seule session ;
    - l'étoile « gagné en jouant » disparaît à la reconnexion. Le titre se gagne alors une seconde fois, avec une nouvelle annonce.
- **Depuis quand** : la v0.23.29 pour `ratings`, la v0.23.37 pour l'étoile (6 octobre).
- **Pourquoi aucun test ne le voit** : `defaultProfile` et le chargement vivent dans `init.server.luau`, que les tests ne chargent pas. `Lobby.test` vérifie bien que la cote 2v2 est rangée sous une clé texte (`tests/Lobby.test.luau:295`), mais jamais un aller-retour sauvegarde puis chargement.
- **Ce qui devrait se passer** : tout ce qu'un module écrit dans le profil revient à la session suivante.
- **Gravité** : bloquant (progression perdue à chaque reconnexion : cote CLASSÉE 2v2 et 3v3, progression des titres).
- **Statut** : `corrigé (v0.36.7)`, à confirmer en jeu par Wilhem (une reconnexion après un CLASSÉ 2v2). Les valeurs par défaut et la fusion du chargement passent dans un module pur, `src/server/Profile.luau`, avec `ratings`, `feats` et `earnedTitles`. Un test de `Lobby.test` (« saved profile ») fait écrire chaque module, sauvegarde, recharge et compare ; il échoue sur l'ancien code. Validé : l'ancienne et la nouvelle fusion donnent le même résultat sur 20 006 sauvegardes, aux trois champs ajoutés près.
- **Relu par la chasse du 21/10** (`git diff 0c2ed8e..HEAD`) :
  - `Profile.luau` est pur : aucun `require`, aucune API Roblox ;
  - `init.server.luau` l'appelle à deux endroits : `defaultProfile()` (`:120-123`) et la fusion du chargement (`:175`). Le reste du chargement est inchangé : kit inconnu, saison des succès, testeurs ;
  - tous les champs du profil écrits par le serveur et les modules purs ont été relevés (recherche des écritures `profile.X =`, `+=` et `profile[…]` dans `src/server` et `src/shared`). Chacun figure dans `Profile.default`, avec le bon type ;
  - Lobby : 48 tests, dont « saved profile », tous passés.
- **Ce qui reste** (pas un nouveau bug) : la récupération de la cote 2v2 et 3v3 perdue avant la v0.36.7 (piste 3 ci-dessous) n'a pas été faite. Un joueur qui avait joué ces catégories avant le 20/10 repart de 1000 ; seuls les classements `_2v2_v1` et `_3v3_v1` gardent sa dernière cote. Production peut décider de la relire au chargement quand `ratings` est vide.
- **Piste** :
  - ajouter `ratings = {}`, `feats = {}` et `earnedTitles = {}` à `defaultProfile()` ;
  - mieux : sortir `defaultProfile` et la boucle de chargement dans un module pur (par exemple `src/server/Profile.luau`), avec un test d'aller-retour. Ce test fait écrire chaque module (Matchmaker, GameModes, Store, Economy, Quests, AntiCheat, Champions), puis sauvegarde, recharge et compare ;
  - récupération possible pour la cote : tant que le joueur n'a pas rejoué en 2v2 ou en 3v3, les classements `JeuxCombat_Classement_2v2_v1` et `_3v3_v1` gardent sa dernière cote (ils ne sont écrits que si `played` est vrai). Le chargement peut la relire quand `ratings` manque. Les compteurs des titres et les étoiles sont perdus.

## B-022 · SURVIE : chaque vague gagnée par K.O. n'affiche pas « K.O. »
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, en suivant les `RoundEnd` d'une SURVIE jouée CPU contre CPU, avec la règle du serveur qui ajoute l'adversaire suivant.
- **Comment reproduire** :
  - ici : `Sim.setTeams(w, { kit }, { adversaire })`, deux `FighterAI`. À chaque `RoundEnd`, on ajoute l'adversaire suivant comme le serveur (`init.server.luau:2002-2008`) ;
  - sur 3 parties, chaque vague gagnée (jusqu'à 9 de suite) part avec `matchOver = true`, puis la manche suivante commence ;
  - en jeu : SURVIE, gagner la première vague par K.O.
- **Ce qui se passe** :
  - prouvé : `endRound` calcule `matchOver = team.index > #team.kits` (`src/shared/CombatSimulation.luau:2482`). L'équipe CPU n'a qu'un combattant à la fois : à chaque vague gagnée, c'est vrai. Le serveur n'ajoute l'adversaire suivant qu'**après** l'événement (`init.server.luau:2008`), et l'événement part tel quel (`:2129-2147`) ;
  - déduit du code client : le HUD tait le « K.O. » quand `matchOver` est vrai, parce qu'il compte sur la scène K.O. du match (`src/client/HUDController.luau:1439`). Mais cette scène ne se joue pas : l'instantané montre déjà une équipe CPU allongée, donc `Director.matchDecided` est faux (`src/shared/CinematicDirector.luau:5206-5214`) ;
  - résultat : ni « K.O. · … WINS THE ROUND », ni scène K.O., à chaque vague. Il reste la voix K.O. et le jingle K.O. Une manche PERFECT affiche toujours « PERFECT ».
- **Ce qui devrait se passer** : « K.O. » à chaque vague gagnée, et la scène K.O. seulement à la vraie fin.
- **Gravité** : mineur (visuel, mais à chaque vague d'un mode entier).
- **Statut** : `ouvert` (code inchangé au 21/10). Depuis la v0.36.7, les lignes du serveur ont bougé : l'ajout de l'adversaire est en `init.server.luau:1979-1985`, et l'événement part dans `batch` en `:2109`, puis il est envoyé en `:2121-2123`, après `followEvents` (`:2111`).
- **Revu le 22/10 sur la v0.36.8** (code inchangé, lignes identiques) : le fuzz de la chasse (240 SURVIES, avec l'ajout de l'adversaire recopié du serveur) compte 1 382 fins de manche, **toutes** avec `matchOver = true`, vagues gagnées comprises.
- **23/10** : code inchangé sur la v0.36.9 (elle ne touche ni le serveur, ni la simulation, ni le directeur) ; lignes citées valables.
- **25/10** : code inchangé sur la v0.36.10 (elle ne touche que l'écriture des profils), mais les lignes du serveur ont bougé : l'ajout de l'adversaire est en `init.server.luau:2029-2037` (`match.wave += 1` en `:2033`), l'événement part dans `batch` en `:2159`, `followEvents` en `:2161`, l'envoi en `:2171-2173`. Côté simulation, depuis la v0.36.8, `matchOver` est calculé en `CombatSimulation.luau:2487-2491` (la ligne citée plus haut, `:2482`, est devenue `:2490`). `HUDController.luau:1439` : inchangé.
- **26/10** : code inchangé sur la v0.36.11, mais les lignes du serveur ont encore bougé : l'ajout de l'adversaire est en `init.server.luau:2052-2060` (`match.wave += 1` en `:2056`), l'événement part dans `batch` en `:2182`, `followEvents` en `:2184`, l'envoi en `:2194-2198`. `CombatSimulation.luau:2487-2491` et `HUDController.luau:1439` tiennent.
- **À côté** : une vague gagnée par un ÉVEIL ou une PORTE qui tue finit, elle, sur « K.O. · … · VICTORY » (B-026).
- **Piste** :
  - dans `followEvents`, quand le serveur ajoute l'adversaire, remettre `event.matchOver = false` sur ce `RoundEnd`. C'est la même table que celle envoyée juste après, dans `batch` ;
  - ou laisser la simulation savoir qu'une équipe est sans fin (`world.endless[2]`) ;
  - un test `CombatSimulation` : en SURVIE, un `RoundEnd` de vague gagnée a `matchOver = false`.

## B-023 · CLASSÉ : quitter dans les 25 premières secondes ne coûte aucun point
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, en relisant `endVersus` (`src/server/init.server.luau:663-759`) à côté de la règle annoncée : « CLASSÉ : the one who left loses points » (`:576`).
- **Comment reproduire** :
  - ici : un script hors dépôt refait le calcul de cote de `endVersus` (`:672-728`) avec `AntiCheat` et `Matchmaker`. Un joueur à 1500 quitte face à un joueur à 1200 :

    | Départ | Actions (lui, l'autre) | Cote de celui qui part | Raison |
    |---|---|---|---|
    | après 12 s | 4, 6 | 1500 → **1500** | `short` |
    | après 24 s | 30, 40 | 1500 → **1500** | `short` |
    | après 60 s | 12, 80 | 1500 → **1500** | `idle` |
    | après 60 s | 80, 80 | 1500 → 1473 | compté |

  - en jeu : un CLASSÉ contre un adversaire plus fort, puis quitter le match (ou le jeu) pendant l'intro ou le début de la première manche.
- **Ce qui se passe** (prouvé sur les modules purs, avec le calcul recopié) :
  - `unseat` appelle `endVersus(match, 3 - i, i)` (`init.server.luau:584`) ;
  - la part anti-farm de la cote est `math.min(shareA.rating, shareB.rating)` (`:676`). Elle vaut 0 si le match dure moins de `MIN_MATCH` = 25 s, intro comprise (`src/server/AntiCheat.luau:88`), ou si l'un des deux a fait moins de 20 actions (`:90`) ;
  - la cote ne bouge alors pour personne (`init.server.luau:725`). Celui qui part ne perd que ses pièces et sa série.
- **Ce qui devrait se passer** : celui qui quitte un CLASSÉ perd ses points, comme annoncé. Le filtre anti-farm sert à ne pas **donner** de gains (un compte secondaire qui part tout de suite), pas à épargner une perte.
- **Gravité** : majeur. Le résultat d'un CLASSÉ abandonné est faux, et le défaut s'exploite : on fuit sans frais tout match mal parti dans les 25 premières secondes, et le classement (donc le champion de la semaine) se fausse. Rien ne se voit à l'écran.
- **Statut** : `corrigé (v0.36.11)`, à confirmer sur le jeu publié. Livré le 25/10, portée V1, validé à la seconde passe (la première a refusé le défi accepté qui sortait de son CLASSÉ celui qui l'avait lancé ; voir « Correction du 25/10 » tout en bas de la fiche). Le reste relevé par la validation (la REVANCHE sans `fromBusy`, `init.server.luau:1510`, et le résumé de l'API de `Lobby.luau:24-25`) est suivi depuis le 26/10 dans **B-038**, avec les défis reçus en plein combat. Deux effets de bord de la correction, trouvés le 26/10 : B-037 (la touche P) et B-038 (un défi reçu pendant un CLASSÉ). Avant : `ouvert` (reconfirmé le 21/10 sur la v0.36.7 ; code inchangé au 22/10 sur la v0.36.8, toutes les lignes citées tiennent). À corriger **avec B-028**, par la piste commune du 22/10 ci-dessous. **Reporté par production le 22/10** : B-025 doit passer avant (voir « Reporté par production » en bas de la fiche). **25/10 : la raison du report est levée par la v0.36.10. B-023 est faisable sans Wilhem, et sans attendre le relevé** (prouvé, voir « Chasse du 25/10 » tout en bas de la fiche). Le relevé ne sert plus qu'à mesurer ce que la correction couvre de B-028.
- **24/10** : code inchangé (HEAD 7fada09) ; les lignes de la v0.36.9 tiennent. Quand la correction de B-025 et B-032 (arbre de travail, en validation) sera livrée, elles descendent de 44 lignes avant `PlayerRemoving` et d'environ 50 après : `unseat` en `:599` (appel `endVersus` en `:605`), `endVersus` en `:684`, `share` en `:697`, `PlayerRemoving` en `:1313` (`unseat` en `:1321`), `BindToClose` en `:2202`. Ce diff pose déjà le drapeau `closing` et les deux lignes de console du point 2 de la piste commune.
- **Revérifié par la chasse du 21/10** : `AntiCheat` et `Matchmaker` n'ont pas changé. Depuis la v0.36.7, les lignes du serveur ont bougé :
  - `unseat` : `init.server.luau:555`, appel `endVersus(match, 3 - i, i)` en `:561` ;
  - `endVersus` : `:640` ;
  - `share` : `:653` ;
  - victoires et défaites : `:656` ;
  - cote : `:702`.

  Le calcul recopié donne, pour un joueur à 1500 qui quitte face à un joueur à 1200 :

  | Départ | Actions (lui, l'autre) | Cote de celui qui part | Raison |
  |---|---|---|---|
  | après 12 s | 4, 6 | 1500 → **1500** | `short` |
  | après 24 s | 30, 40 | 1500 → **1500** | `short` |
  | après 60 s | 12, 80 | 1500 → **1500** | `idle` |
  | après 120 s | 19, 300 | 1500 → **1500** | `idle` |
  | après 60 s | 80, 80 | 1500 → 1473 | compté |
  | 2v2 ou 3v3, après 20 s | 40, 40 | 1300 → **1300** | `short` |

  - **précisions nouvelles** :
    - la fuite gratuite ne dure pas que 25 s. Un joueur qui reste sous 20 actions (`MIN_ACTIONS`, `AntiCheat.luau:90`) peut partir à tout moment sans rien perdre ;
    - la défaite n'est pas comptée non plus (`losses`, `:656-658`) ;
    - le défaut touche aussi le CLASSÉ 2v2 et 3v3.
- **Piste de correction précise** :
  1. une fonction pure, par exemple `AntiCheat.ratingShares(shareA, shareB, leftSlot)`, qui rend une part par place :
     - sans départ : `min(shareA.rating, shareB.rating)` pour les deux (inchangé) ;
     - avec départ : **1** pour celui qui part (perte Elo entière) et `min(...)` pour celui qui reste (0 si le match est trop court : un compte secondaire qui part tout de suite ne fait pas monter le principal) ;
  2. dans `endVersus`, `:702-705` : `Matchmaker.setRating(ca.profile, size, AntiCheat.scaleRating(before[1], newA, shares[1]))`, et de même pour B. La condition `share > 0` devient `shares[slot] > 0` pour chaque place ;
  3. `:656-658` : compter la défaite de celui qui part, même si `share` vaut 0 ;
  4. tests dans `Lobby.test` :
     - « celui qui quitte un CLASSÉ perd des points, même après 10 s, ou avec moins de 20 actions » ;
     - « celui qui reste ne gagne rien si le match est trop court » ;
     - « sans départ, rien ne change ».
- **Risque de la correction : faible dans le code, mais deux décisions à prendre.**
  - La cote n'est plus à somme nulle : celui qui part perd, celui qui reste peut ne rien gagner. Le classement baisse donc un peu au fil des abandons. C'est voulu (contre les comptes secondaires), mais production doit l'acter ;
  - **un départ subi est puni comme un abandon.** C'est la règle annoncée pour une coupure réseau. Mais c'est aussi le cas à la mise à jour du serveur (B-028) : la correction étendrait cette punition aux 25 premières secondes. Il faut corriger B-028 en même temps ;
  - `endVersus` vit dans `init.server.luau`, que les tests ne chargent pas : sans la fonction pure, rien ne vérifie la correction.
- **Ancienne piste** (20/10) : la même, en moins détaillé.
- **Piste commune B-023 + B-028 (chasse du 22/10)**. Elle remplace les deux pistes séparées.
  - **Ce que la relecture du 22/10 ajoute** (prouvé dans le code) :
    - le profil de celui qui part est écrit **tout de suite** dans `PlayerRemoving`, avec le verrou relâché (`init.server.luau:1276-1281`), puis `clients[player] = nil` (`:1291`). Et `endVersus` ne fait rien si l'un des deux clients manque (`:644-645`). Une décision prise plus tard, après quelques secondes d'attente, ne pourrait donc plus toucher son profil ;
    - le serveur qui charge un profil encore verrouillé attend jusqu'à `LOCK_TTL + 5` = 65 s (`:166-170`). Retarder de quelques secondes l'écriture finale de celui qui part ne fait rien perdre *(dépassé le 22/10 : faux quand le verrou de session est périmé, ce qui est presque toujours le cas après un match ; voir le report ci-dessous)* ;
    - Roblox ne dit pas pourquoi un joueur part. `PlayerRemoving` reçoit bien une raison, mais `Enum.PlayerExitReason` ne vaut que `Unknown`, `PlatformKick` ou `CreatorKick` (`Full-API-Dump.json`, la source de `tools/vfxrun.py --refresh`, copie du 16/10). Aucune propriété lisible par un script ne dit non plus « serveur en fermeture ». Seuls signaux : l'appel de `BindToClose`, et le départ des deux joueurs à quelques secondes d'écart ;
    - le CLASSÉ entre serveurs se joue sur un serveur réservé (`TeleportToPrivateServer`, `:1013`), avec le même `endVersus` : il est touché de la même façon.
  - **Trois façons de quitter un match contre un joueur, trois règles** :
    1. **quitter volontairement** : QUITTER LE COMBAT (action `leave`, `:1565-1569`), lancer un autre mode (`:1548-1550`), accepter un DÉFI (`:1317-1322`). C'est un abandon, tranché tout de suite, comme aujourd'hui ;
    2. **quitter le serveur** (`PlayerRemoving`, `:1269-1274`) : fermer le jeu, perdre la connexion, ou être retiré par une mise à jour. C'est un abandon, sauf si le serveur ferme. On attend quelques secondes avant de trancher ;
    3. **le serveur ferme** (`BindToClose`, `:2152`) : match sans résultat (« no contest ») pour les deux.
  - **Le code** :
    1. **une fonction pure** (`AntiCheat.luau`, par exemple `AntiCheat.versusShares(shareA, shareB, leftSlot)`) qui rend une part de cote par place :
       - sans départ : `min(shareA.rating, shareB.rating)` pour les deux, comme aujourd'hui ;
       - avec départ : **1** pour celui qui part (sa défaite compte en entier, même après 5 s ou avec 3 actions), `min(...)` pour celui qui reste (0 si le match est trop court ou trop calme : un compte secondaire qui part tout de suite ne fait rien gagner) ;
    2. **`endVersus`** (`:640`) :
       - `:653` : une part par place ;
       - `:656-658` : la défaite de celui qui part compte toujours, la victoire de l'autre seulement si sa part est > 0 ;
       - `:702-705` : `setRating` de chaque place avec sa propre part, si elle est > 0 ;
       - la série (`:684-686`), les pièces et les points de la semaine ne changent pas : celui qui part n'a déjà rien ;
       - l'historique (`:711-717`) montre déjà le `delta` de chacun ;
    3. **un drapeau de fermeture** : `local closing = false`, mis à `true` à la **première ligne** de `BindToClose` (`:2152`). Juste après, tout match VERSUS en cours devient « sans résultat » : `match.finished = true` et `match.void = true`. Le `MatchEnd` qui arriverait ensuite ne compte plus (`endVersus` sort en `:641`). Dans `unseat` (`:560`), `and not closing` s'ajoute à la condition ;
    4. **un délai de grâce, seulement pour `PlayerRemoving`**. C'est le cas où Roblox retirerait les joueurs **avant** d'appeler `BindToClose` (ordre inconnu, voir B-028) :
       - `unseat(player, "removed")` ne tranche pas tout de suite. Le match est mis en pause (`stepMatch`, `:2079`, ne l'avance plus) : le perso abandonné ne peut pas être mis K.O. entre-temps, ce qui ferait un vrai `MatchEnd`. Le client de celui qui part est gardé dans `match.held`, et son écriture finale attend ;
       - au bout de `GRACE` secondes (5 s proposées) : si `closing`, ou si l'autre joueur a quitté le **serveur** entre-temps (son propre `PlayerRemoving`), le match est sans résultat. Sinon, `endVersus(match, 3 - i, i)` avec le client gardé (règle 1 ci-dessus), puis l'écriture finale de celui qui part, verrou relâché ;
       - `BindToClose` attend aussi ces écritures en attente (compteur `pending`, `:2159-2170`) ;
       - celui qui reste voit un message pendant l'attente (par exemple « OPPONENT DISCONNECTED »), puis son résultat. Ce texte, et celui du match sans résultat, ont besoin de leur traduction dans `Locale.FR` ;
    5. **les tests** (`Lobby.test`) :
       - la fonction pure : celui qui part perd des points après 10 s, ou avec moins de 20 actions ; celui qui reste ne gagne rien si le match est trop court ; sans départ, rien ne change ;
       - la décision du délai de grâce, sortie dans une fonction pure (par exemple `AntiCheat.departure({ closing, otherGone, voluntary })` → `"abandon"` ou `"void"`) ;
       - l'ordre réel des événements de Roblox ne se teste pas hors ligne : voir B-028.
  - **Les décisions que cette piste suppose** :
    - **D1, la cote n'est plus à somme nulle quand quelqu'un part** : celui qui part perd ses points Elo en entier, celui qui reste ne gagne que si le match compte. **Les joueurs le voient** :
      - sur la carte de résultat, celui qui reste lit « +0 » après un départ dans les 25 premières secondes ;
      - au classement, chaque abandon retire des points sans en donner (par exemple −27 pour un joueur à 1500 qui part face à un joueur à 1200).

      L'autre choix, la somme nulle (celui qui reste gagne ce que l'autre perd), rouvre le farm par compte secondaire : le compte secondaire lance un CLASSÉ, part tout de suite, et le compte principal gagne. C'est le cas que le filtre anti-farm devait fermer. La règle écrite en v0.17.0, « l'Elo reste à somme nulle » (`docs/JOURNAL.md:2485`, et le commentaire de `:653`), était un choix d'implémentation de Claude, pas une demande de Wilhem ;
    - **D2, une déconnexion compte comme un abandon**, sans retour possible dans le match. C'est déjà la règle annoncée : « the one who left loses points » (`:552`), « Quitter un 1v1 le donne perdu » (`docs/JOURNAL.md:3013`). Mais le cahier des charges prévoit « déconnexions, reconnexion aux matchs selon les règles choisies » (`docs/Roblox_Guide_Claude.md:172`). Une règle plus clémente, ou un retour dans le match, serait un choix de Wilhem, hors de cette correction ;
    - **D3, un match coupé par le serveur est sans résultat** : ni cote, ni pièces, ni série, ni victoire ou défaite. Reste à choisir : une ligne d'historique (« NC ») ou rien, et le texte affiché ;
    - **D4, la durée de grâce** (5 s proposées) et la pause du match pendant ce temps. Le trou qui reste : si l'adversaire quitte lui aussi le serveur dans ces 5 s, celui qui est parti s'en sort sans perte. L'adversaire n'y a aucun intérêt (il est renvoyé au menu sans quitter le serveur, `:581-586`) ;
    - **D5, le compteur de défaites** (`profile.losses`, la fiche V/D) compte l'abandon même quand le match est trop court.
  - **À qui revient le choix, selon moi** : production peut trancher D1, D3, D4 et D5 et les noter dans `DECISIONS.md`. Ce sont les conséquences d'une règle déjà annoncée (celui qui part perd), et D1 défait un choix de Claude, pas de Wilhem. Il faut le dire à Wilhem dans le compte rendu, parce que les joueurs voient le « +0 ». Seule une règle plus clémente pour les déconnexions (D2) attendrait Wilhem, et cette correction ne la demande pas. **B-023 n'est donc pas bloqué par Wilhem.**
  - **Le risque** :
    - les points 1 et 2 sont simples et testables ;
    - les points 3 et 4 touchent le départ des joueurs et l'écriture des profils (le verrou de session). Aucun test hors ligne ne les couvre, et ils ne se vérifient qu'en jeu publié (B-028) ;
    - le point 3 seul, sans le délai de grâce, est sûr mais ne couvre que l'ordre « `BindToClose` d'abord ». Sans le point 3 ni le point 4, corriger B-023 étendrait la perte de B-028 aux 25 premières secondes.
- **Reporté par production le 22/10** (routine du matin ; KUROEN passe à sa place, `DECISIONS.md`).
  - **Ce qui est vérifié** : la chasse a raison sur le fond, aucune décision n'attend Wilhem :
    - « Quitter un 1v1 le donne perdu » est la règle annoncée (`docs/JOURNAL.md:3013`, commentaire de `unseat`) ;
    - « l'Elo reste à somme nulle » est écrit dans le bloc anti-triche de la v0.17.0 (`docs/JOURNAL.md:2485`), sans citation de Wilhem : c'est un choix de Claude ;
    - le « +0 » de celui qui reste après un départ rapide existe déjà aujourd'hui (`share` = 0 pour les deux).
  - **La raison exacte du report** : le point 4 (l'écriture finale retardée de quelques secondes) peut faire perdre l'écriture de départ. C'est prouvé sur les modules purs (`GlobalQueue.canLock`, script hors dépôt) :
    - rien n'écrit le profil pendant un match. `saveProfile` n'est appelé qu'à la fin (`endVersus`, `followEvents`), et la boucle de vidage n'écrit qu'un profil modifié (`SaveQueue.due`). Un CLASSÉ de plus de 60 s a donc toujours un verrou périmé (B-025) quand un joueur le quitte ;
    - le joueur arrive sur un autre serveur pendant les 5 s de grâce. Une migration le fait (« Migrate to Latest Update » le téléporte), un retour rapide aussi. Le nouveau serveur prend alors le verrou périmé, et charge le profil d'avant ;
    - l'écriture retardée de l'ancien serveur est ensuite refusée (« held by another server », `writeProfile`). Cela touche la perte de cote, mais aussi tout ce qui n'était pas encore écrit ;
    - les mesures :

      | Match commencé | Départ | Grâce | Arrivée sur l'autre serveur | Ce que charge l'autre serveur | Écriture finale de l'ancien |
      |---|---|---|---|---|---|
      | t = 0 | t = 30 | 0 s (aujourd'hui) | t = 33 | le profil à jour | écrite |
      | t = 0 | t = 30 | 5 s | t = 33 | rien : il attend le verrou | écrite |
      | t = 0 | t = 120 | 0 s (aujourd'hui) | t = 123 | le profil à jour | écrite |
      | t = 0 | t = 120 | 5 s | t = 123 | **le profil d'avant** | **refusée** |

    - le reste dépend de l'ordre des événements de Roblox à la fermeture, qui ne se rejoue pas hors ligne : `BindToClose` avant ou après les `PlayerRemoving`, l'écart entre les départs des deux joueurs d'un match, le temps qui reste aux fils lancés pendant l'attente de `BindToClose`. Un test hors ligne ne pourrait qu'encoder une supposition ;
    - corriger B-023 sans le point 4 étendrait la perte de B-028 à toute la durée du match (consigne de la routine : ne pas le corriger seul).
  - **L'ordre proposé** :
    1. **B-025 d'abord** : renouveler le verrou de tout profil chargé, même sans changement, pendant tout le temps où le joueur est sur le serveur. Le nouveau serveur attend alors toujours l'écriture finale de l'ancien (2e ligne du tableau). C'est un module pur (`SaveQueue`) avec un test ;
    2. **un relevé dans le jeu publié** (Wilhem, sans risque) : une ligne de console dans `PlayerRemoving` et une dans `BindToClose`, avec l'heure (`os.clock()`) et le nombre de joueurs encore là. Pendant une migration, Wilhem lit les journaux du serveur (console développeur, onglet Server) : quel événement arrive d'abord, et à quel écart partent les deux joueurs d'un match ;
    3. **puis B-023 et B-028 ensemble**, avec la piste commune ci-dessus. La décision du délai de grâce est un module pur (le point 5), et un test rejoue les ordres d'événements relevés au point 2.
  - **23/10** : code inchangé sur la v0.36.9, lignes citées valables. Le premier pas, B-025, a maintenant une piste détaillée et testable (chasse du 23/10), à livrer avec B-032 (l'écriture de départ retentée). Une fois les deux livrés, la grâce de 5 s du point 4 ne perd plus l'écriture de départ : l'autre serveur attend le verrou (rejoué, tableau de B-025).
  - **Ce qu'il faudrait vérifier sur le jeu publié** :
    - l'ordre `BindToClose` / `PlayerRemoving` à une migration et à « Shut Down All Servers » (le relevé du point 2) ;
    - après la correction de B-025 : un joueur qui quitte un CLASSÉ de plus de 60 s et rejoint un autre serveur dans les 5 s retrouve bien sa défaite (pas de « held by another server » dans la console de l'ancien serveur) ;
    - le test de B-028 (deux comptes en CLASSÉ, puis une migration : aucun ne doit bouger).
- **Chasse du 25/10, sur la v0.36.10 (HEAD 45a8b55) : faisable sans Wilhem.**
  - **Les lignes après la v0.36.10** (`AntiCheat` et `Matchmaker` inchangés : `AntiCheat.luau:88`, `:90`, `scaleRating` en `:149-152`) :
    - `unseat` : `init.server.luau:599`, condition en `:604`, appel `endVersus` en `:605`, retour au menu de l'autre en `:622-630` ;
    - `endVersus` : `:684`. Il sort en `:688-689` si l'un des deux clients manque ;
    - `share` : `:697` ; victoires et défaites : `:700-706` ; pièces : `:709-716` ; points de la semaine : `:718-725` ; série : `:727-730` ; quêtes : `:733-742` ; cote : `:746-754` ; historique : `:756-763` ; carte de résultat : `:764-779` ;
    - `PlayerRemoving` : `:1313-1343`. La ligne de console est en `:1315-1316`, `unseat` en `:1321`, l'écriture de départ en `:1324-1335`, et `clients[player] = nil` en `:1341` ;
    - `BindToClose` : `:2202-2224`. `closing = true` est en `:2203`, sa ligne de console en `:2204`, l'attente en `:2223` ;
    - `stepMatch` : `:2129` ; les départs volontaires : `leave` en `:1615-1618`, un autre mode en `:1600`, un DÉFI accepté en `:1371`.
  - **La raison du report du 22/10 ne tient plus.** Une grâce de 5 s faisait charger le profil d'avant à un autre serveur, parce qu'à la fin d'un CLASSÉ le verrou était périmé. Depuis la v0.36.10, le verrou d'un joueur présent a 35 s au plus quand il part (20 s, plus un vidage de 15 s ; 50 s si un renouvellement a raté). L'autre serveur l'attend donc.
  - **Prouvé** sur les `SaveQueue` et `GlobalQueue` livrés. Le fuzz de la chasse (script hors dépôt) recopie le fil de `PlayerRemoving`. L'écriture de départ y part après la grâce, avec la décision d'abandon appliquée au profil à ce moment. Un autre serveur arrive de 5 s avant à 20 s après le départ :

    | Grâce | Renouvellement du verrou | Scénarios | L'autre serveur charge une version d'avant la décision | Son attente, au plus |
    |---|---|---|---|---|
    | 0 s | oui (v0.36.10) | 8 000 | 0 | 6 s |
    | 5 s | oui (v0.36.10) | 8 000 | **0** | 9 s |
    | 5 s | retiré (`RENEW` = 100 000) | 3 000 | **56** | 9 s |
    | 0 s | retiré | 3 000 | 31 | 6 s |

    - avec des pannes du DataStore (15 % des requêtes, plus des coupures de 1 à 30 s), l'autre serveur charge une version d'avant dans 0,56 % des cas sans grâce, 0,61 % avec 5 s, et 0,91 % avec 10 s (12 000 scénarios chacun) ;
    - **5 s n'ajoute rien de mesurable. Il ne faut pas aller au-delà.**
  - **Ce que le relevé de Wilhem décide encore** : seulement ce que la correction couvre de B-028, dans un ordre précis des événements (ci-dessous). Ce n'est plus une condition de sûreté : on peut livrer, puis lire les lignes de console.
  - **Deux façons de livrer, les deux sans Wilhem** :
    - **V1, rien n'est retardé** : les parts de cote par place (points 1 et 2 ci-dessous) et le drapeau de fermeture (point 3). Elle corrige B-023 en entier, et B-028 quand `BindToClose` arrive avant les départs. Elle laisse un cas : si Roblox retire les joueurs avant d'appeler `BindToClose`, le premier retiré perd, comme aujourd'hui, et désormais même dans les 25 premières secondes. Production a écarté cette option le 22/10 pour cette raison ;
    - **V2, la piste commune (recommandée)** : V1, plus la grâce de 5 s sur `PlayerRemoving` (point 4). Elle couvre aussi l'ordre « départs d'abord », si les deux joueurs d'un match partent à moins de 5 s d'écart ou si `BindToClose` arrive dans ces 5 s. Le seul cas laissé : des départs espacés de plus de 5 s, avant `BindToClose`. Le relevé dira s'il existe.
  - **Le code de V2** :
    1. `AntiCheat.luau` (pur) :
       - `AntiCheat.versusShares(ratingA, ratingB, leftSlot)` rend une part par place. Sans départ : `min` pour les deux. Avec un départ : 1 pour celui qui part, `min` pour l'autre ;
       - `AntiCheat.departure({ voluntary, closing, otherGone })` rend `"abandon"` ou `"void"`, dans cet ordre : `closing` donne `"void"`, puis `voluntary` donne `"abandon"`, puis `otherGone` donne `"void"`. Sinon, `"abandon"`.
    2. `endVersus` (`:684`) :
       - **les clients** : `:688` lit `clients[a]`. Pendant la grâce, celui qui part n'y est plus (`:1341`). Il faut lui passer le client gardé (`match.held`), sinon `endVersus` sort en `:689` sans rien compter ;
       - `:697` : `local shares = AntiCheat.versusShares(shareA.rating, shareB.rating, leftSlot)` ;
       - `:700-706` : la défaite de celui qui part compte toujours (D5). La victoire de l'autre ne compte que si sa part est > 0 ;
       - `:718-742` : les points, la série (`share > 0` devient `shares[slot] > 0`) et les quêtes, chacun avec la part de sa place ;
       - `:746-749` : en CLASSÉ, chaque place dont la part est > 0 reçoit `AntiCheat.scaleRating(before[slot], new, shares[slot])`. Une part de 1 donne la perte Elo entière ;
       - `:731` et `:764-779` : rien n'est envoyé au joueur déjà retiré (pas de `SetAttribute` ni de `FireClient`), il n'y a que son écriture.
    3. **la fermeture** : en `:2203`, juste après `closing = true`, chaque match VERSUS en cours devient sans résultat (`match.finished = true`, `match.void = true`). Celui qui reste reçoit « NO CONTEST ». Dans `unseat`, `and not closing` s'ajoute à la condition de `:604`.
    4. **la grâce** (`PlayerRemoving`, `:1313-1343`), quand le joueur quitte un VERSUS entre joueurs en cours, hors fermeture :
       - `match.paused = true` : `stepMatch` (`:2129`) ne l'avance plus. Le perso abandonné ne peut donc pas être mis K.O. entre-temps, ce qui ferait un vrai `MatchEnd` ;
       - `match.held = { slot = i, player = player, client = client }`. La place garde son propriétaire jusqu'à la décision : `endVersus` lit `match.slots[i].owner` (`:687`). `player.Character = nil` se fait tout de suite, comme `unseat` le fait en `:613`, pour que Roblox ne détruise pas le modèle du perso ;
       - le retour au menu de l'autre (`:622-630`) attend la décision ;
       - `SaveQueue.leaving` se fait tout de suite, comme aujourd'hui. `finalWrites += 1` se fait **dès le départ**, pour que `BindToClose` (`:2223`) attende aussi les décisions en cours ;
       - au bout de `GRACE = 5` s, on appelle `AntiCheat.departure({ closing = closing, otherGone = <l'autre a eu son propre PlayerRemoving> })`. Sur `"abandon"` : `endVersus(match, 3 - i, i)` avec le client gardé, puis `finalWrite`. Sur `"void"` : rien n'est compté, puis `finalWrite` ;
       - celui qui reste voit « OPPONENT DISCONNECTED » pendant ces 5 s.
    5. **les départs volontaires** (`:1371`, `:1600`, `:1615-1618`) n'ont pas de grâce : `departure` rend `"abandon"` tout de suite.
  - **Les tests** (`Lobby.test`) :
    - `versusShares` :
      - un départ après 10 s, ou avec 3 actions : celui qui part perd ses points en entier (−27 pour un joueur à 1500 qui part face à un joueur à 1200), et celui qui reste ne gagne rien ;
      - après 60 s et 80 actions chacun : les deux cotes sont celles d'aujourd'hui ;
      - sans départ : `min` pour les deux ;
      - en 2v2 et en 3v3 aussi ;
    - `departure` : les quatre cas, puis quatre ordres d'événements rejoués :
      - `BindToClose`, puis les deux départs : sans résultat ;
      - départ de A, 2 s plus tard départ de B, puis `BindToClose` : sans résultat ;
      - départ de A seul : abandon ;
      - départs espacés de plus de 5 s, avant `BindToClose` : abandon. C'est la limite connue, et le test l'écrit ;
    - sur le banc `saveWorld` de B-025 : un joueur quitte un CLASSÉ de 3 min, et son écriture de départ part 5 s plus tard avec la perte de cote. Un autre serveur, arrivé 3 s après le départ, charge la version avec la perte. Sans le renouvellement, ce même cas perd la décision (tableau ci-dessus) ;
    - « languages » : « OPPONENT DISCONNECTED » et « NO CONTEST » ont leur ligne dans `Locale.FR`.
  - **Le risque qui reste** :
    - le fil de la grâce vit dans `init.server.luau`, que les tests ne chargent pas. La validation doit le rejouer sur un ordonnanceur et un DataStore simulés, comme pour la v0.36.10. Ce banc n'est pas dans le dépôt ;
    - une double panne : un renouvellement raté juste avant le départ (le verrou a alors 50 s), puis une écriture de départ ratée. Les nouveaux essais (après 1, 2 et 4 s) dépassent alors les 60 s, et un autre serveur peut prendre le verrou. C'est le cas de B-032, à peine élargi par la grâce (pas de différence mesurable à 5 s, ci-dessus) ;
    - les décisions D1, D3, D4 et D5 (plus haut) : production les tranche et les note dans `DECISIONS.md`. **Wilhem doit savoir que les joueurs verront « +0 » et « NO CONTEST »**, mais rien ne l'attend.
- **Correction du 25/10 (production, portée V1, en attente de la seconde validation)**. Les décisions D1 à D5 et la portée sont dans `DECISIONS.md` (25/10).
  - **Le code** :
    - `AntiCheat.luau` (pur) : `versusShares(ratingA, ratingB, leftSlot, queue)` (`:170`), `departure(match, slot, closing)` (`:183`) et `noContest(match)` (`:194`) ;
    - `Lobby.luau` (pur) : `Lobby.drop` (`:61`) ; `challenge` (`:92`) et `accept` (`:111`) prennent `fromBusy` ;
    - `init.server.luau` :
      - `seat` retire les défis d'un joueur qui s'assoit dans un VERSUS (`:585`) ;
      - `unseat` (`:604`) décide avec `AntiCheat.departure` (`:609`), en lisant `closing` ;
      - `inVersus` (`:644`) dit si un joueur est dans un 1v1 entre joueurs en cours ;
      - `endVersus` (`:701`) compte chaque place avec sa propre part (`:717`) : victoires et défaites, points de la semaine, série, quêtes, cote, et compteurs des succès de cote (`:770-771`) ;
      - le hub (`:1381`, `:1386`) passe `inVersus` à `Lobby.challenge` et `Lobby.accept` ;
      - `BindToClose` (`:2225`) arrête chaque 1v1 entre joueurs en cours juste après `closing = true`, avant toute attente (`:2232`), et envoie `noContest` à ses deux joueurs ;
    - `init.client.luau:183-193` : « NO CONTEST » dans le bandeau et la notification de mise à jour (`Locale.luau:976-978`, « MATCH ANNULÉ »).
  - **Ce qui est corrigé** : en CLASSÉ (1v1, 2v2, 3v3), celui qui part perd ses points en entier, à tout moment et avec n'importe quel nombre d'actions. Sa défaite compte. Celui qui reste ne gagne que si le match compte (0 avant 25 s, ou sous 20 actions), et ses succès de cote n'avancent pas. Joué jusqu'au bout, rien ne change. Hors CLASSÉ, un départ ne change pas.
  - **Premier refus de la validation (25/10)** : accepter un défi faisait sortir de son CLASSÉ celui qui l'avait lancé (`unseat` des deux joueurs). Le paquet `accept` d'un autre joueur décidait donc de son résultat : −27 dès la 1re seconde avec le premier diff, et déjà −27 après 25 s avec l'ancien code. **Corrigé** : un défi d'un joueur en 1v1 entre joueurs est retiré au lieu d'être accepté, un tel joueur n'en envoie pas, et ses défis disparaissent quand il s'assoit (`DECISIONS.md`). Celui qui accepte quitte bien son propre match : c'est un abandon de sa part, avec le résultat normal pour son adversaire.
  - **Tests** (`Lobby.test`, banc `versusBench` en `:1100`) :
    - `:1159` : départ à 0, 10, 24, 26, 60 et 120 s, avec de 0 à 300 actions ; 2v2, 3v3 ; 8e match de la paire ; les deux qui partent ; NORMAL et AMI ; le compteur de succès de celui qui reste ;
    - `:1214` : sans départ, la cote d'avant, et la somme nulle sur 200 matchs ;
    - `:1256` : les ordres d'événements avec `BindToClose` (voir B-028) ;
    - `:1301` : un défi accepté pendant un CLASSÉ (la scène de la validation à 5 et 24 s, le retrait à l'entrée dans le match, l'envoi refusé, les deux dans le même match, celui qui accepte en CLASSÉ, celui qui défie contre le CPU) ;
    - et « languages ».

    Ils échouent sur la v0.36.10. `:1301` échoue sur le premier diff (A à 1473 à 5 et 24 s). Le banc de la validation, sur le texte exact du serveur, donne pour A : 1500 → 1500 (S10 à 5 et 60 s, S12, S13), puis 1505 après le K.O.
  - **Ce qui reste (la suite, V2)** : la grâce de 5 s au plus sur `PlayerRemoving`, avec le match en pause et le client gardé pour `endVersus` (son piège : il sort sans rien compter si le client de celui qui part n'est plus dans `clients`). C'est elle qui couvrirait l'ordre « départs d'abord » de B-028. Elle attend le relevé des lignes de console sur le jeu publié (`[FightingGame] leave …` et `[FightingGame] closing at …`). La piste et les mesures de la chasse du 25/10, plus haut, restent valables.
- **Relu par la chasse du 26/10, sur le code livré (HEAD 331765b)** :
  - toutes les lignes de « Correction du 25/10 » tiennent. Plus loin, `PlayerRemoving` est en `:1332-1362` (`unseat` en `:1340`), `leave` en `:1638-1642`, un autre mode en `:1621-1623`, le DÉFI accepté en `:1382-1397`. Dans `AntiCheat.luau`, `MIN_MATCH` est en `:44`, `MIN_ACTIONS` en `:47`, `share` en `:98-113` ;
  - le banc de la validation, rejoué sur des sources identiques à HEAD (seule la version de `CombatConfig` change), donne la même sortie à la ligne près ;
  - rien de cassé dans le reste du serveur, prouvé sur ce banc et par la relecture : hors VERSUS, `departure` rend `nil` et `unseat` ne fait rien, comme avant ; joué jusqu'au bout, les deux places ont la même part, donc victoires, pièces, points de la semaine, série, quêtes, cote et historique sont ceux de la v0.36.10 ; après un départ, celui qui reste garde la part d'avant, et celui qui part n'a que sa perte (sa série tombait déjà à 0 : `Economy.streak`, « left ») ; `achRating` est un maximum (`GameModes.luau:294`), une cote qui baisse ne le fait pas reculer ; `Matchmaker`, `GlobalQueue`, `Champions`, `Quests` et `Profile` n'ont pas changé ;
  - un match lancé **pendant** l'attente de `BindToClose` (la boucle de recherche tourne encore) n'est pas dans la boucle de `noContest`, mais le départ de ses joueurs rend `"void"` (`closing`) : il est couvert ;
  - **deux effets de bord**, parce qu'un départ coûte maintenant la cote entière dès la 1re seconde (avant : rien pendant 25 s) : la touche P quitte un CLASSÉ d'un seul appui (**B-037**), et n'importe quel joueur peut afficher un défi, avec son bouton ACCEPT, par-dessus le combat d'un joueur en CLASSÉ (**B-038**).

## B-024 · `!give … title <titre de la boutique>` donne un titre impossible à porter
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, en comparant `Admin.apply` et `Store.buyItem`.
- **Comment reproduire** :
  - ici : pour les 6 titres de la boutique hors Game Pass, `Admin.apply(profil, Admin.parse("!give me title <nom>"))`, puis la règle du serveur pour porter un titre (`Champions.canShow` ou `Store.passTitle`, `src/server/init.server.luau:1479`). Le titre est possédé (`Store.ownsItem` vrai), mais **pas portable**. Acheté avec des pièces, il est portable ;
  - en jeu : `!give <joueur> title FRAME PERFECT`, puis ce joueur essaie de le porter.
- **Ce qui se passe** (prouvé sur les modules purs) :
  - `Admin.apply` n'écrit que `profile.ownedItems[id] = true` (`src/server/Admin.luau:92`, et `:109` pour `!give … item`) ;
  - `Store.buyItem` ajoute en plus le nom à `profile.titles` (`src/shared/Store.luau:136-139`) ;
  - le serveur n'accepte de porter qu'un titre de `profile.titles`, ou celui d'un Game Pass. La boutique le montre possédé (on ne peut plus l'acheter), mais le serveur refuse de le porter, sans message (supposé pour le menu).
- **Pourquoi le test ne le voit pas** : `tests/Lobby.test.luau:1312` vérifie `ownedItems`, pas que le titre se porte.
- **Gravité** : mineur. Un outil du propriétaire, mais le joueur qui reçoit le cadeau ne peut pas s'en servir.
- **Statut** : `ouvert` (code inchangé au 25/10, sur la v0.36.10 : `Admin.luau:92` et `:109` tiennent ; la règle pour porter un titre est en `init.server.luau:1506`, le retrait d'un titre porté non permis en `:1200`). Depuis la v0.36.7, la règle pour porter un titre est en `init.server.luau:1456` (et `:1156`, à la mise à jour des badges et cosmétiques du joueur, qui retire un titre porté non permis).
- **26/10** : code inchangé sur la v0.36.11 (`Admin.luau` et `Store.luau` n'ont pas bougé). Dans le serveur, la règle pour porter un titre est maintenant en `init.server.luau:1529`, le retrait d'un titre porté non permis en `:1219`, et `!give` en `:1724`.
- **Piste** : dans `Admin.apply`, pour un objet `TITLE` (branches `title` et `item`), ajouter aussi le nom à `profile.titles`. Dans le test, vérifier `Champions.canShow`.

## B-025 · Le verrou de session d'un joueur inactif expire alors qu'il est encore sur le serveur
- **Date** : 20 octobre 2026.
- **Source** : trouvé par la chasse, en relisant `SaveQueue` et `GlobalQueue` (verrou de session).
- **Comment reproduire** :
  - ici, avec les modules purs : un profil chargé, un changement à t = 1, la boucle de vidage toutes les 15 s. Seule l'écriture de t = 15 a lieu, et le verrou reste daté de t = 15. À t = 76, le joueur est toujours sur le serveur A, mais `GlobalQueue.canLock(sauvegarde, "B", 76)` est vrai : un autre serveur peut prendre le profil ;
  - la course elle-même (deux serveurs, DataStore) n'est pas reproductible d'ici.
- **Ce qui se passe** :
  - prouvé : le verrou n'est réécrit que lors d'une écriture (`src/server/init.server.luau:254-266`), et on n'écrit qu'un profil modifié (`src/server/SaveQueue.luau:61`). Un joueur qui ne change rien pendant plus de 60 s (`LOCK_TTL`) a un verrou « périmé », que `canLock` traite comme celui d'un serveur planté (`src/server/GlobalQueue.luau:104`) ;
  - supposé, le risque : le joueur change de serveur ou d'appareil juste après un changement (fin de match, achat avec des pièces), alors que son dernier verrou date de plus de 60 s. Si le nouveau serveur charge le profil avant que l'écriture de départ de l'ancien arrive, il le prend aussitôt et lit l'ancienne version. L'écriture de départ arrive ensuite, voit un verrou frais d'un autre serveur, et n'est pas écrite (« held by another server », `:271-273`). Les derniers changements sont perdus.
- **Ce qui devrait se passer** : tant que le joueur est sur le serveur, son verrou reste frais ; seul un serveur planté laisse un verrou périmé.
- **Gravité** : **majeur** (relevée le 23/10 ; c'était « mineur »). Trois raisons :
  - le verrou périmé n'est pas un cas rare, c'est l'état normal. Un joueur qui ne change rien a un verrou périmé dès la 61e seconde (90 % du temps sur 10 minutes). Et **tout** CLASSÉ finit avec un verrou périmé : les 80 matchs 1v1 CPU contre CPU mesurés le 23/10 durent tous plus de 60 s (médiane 107 à 115 s, minimum 63 s), et rien n'écrit le profil pendant un match, sauf un titre gagné ou un achat ;
  - quand la course est perdue, c'est de la progression perdue : le résultat du dernier match (cote, pièces, série, historique, quêtes), et tout ce qui n'était pas encore écrit ;
  - c'est lui qui bloque la correction de B-023 et B-028, deux bugs majeurs.

  Pas bloquant : aujourd'hui, la perte demande encore que l'autre serveur charge le profil avant que l'écriture de départ de l'ancien arrive.
- **Revu par la chasse du 25/10 sur le code livré** (HEAD 45a8b55) : `SaveQueue` et `GlobalQueue` sont identiques à ceux que le fuzz du 24/10 avait passés. Le même fuzz, rejoué sur les fichiers livrés, passe 24 000 scénarios sans échec (12 000 sans panne, 12 000 avec des pannes du DataStore). Tous les appels à `SaveQueue` du serveur passent la session (`client`), et `client` est défini à chaque endroit (`menuStatus`, menu, achats, `grantChampion`, `ProcessReceipt`). Seuls `loadProfile` et `writeProfile` écrivent la clé `joueur_…`. Les classements ne sont pas réécrits par les renouvellements : seulement quand une valeur change (`:282-300`). Deux effets de bord trouvés, sans lien avec la justesse du verrou : B-035 (le menu pendant l'attente du chargement) et B-036 (une écriture en vol pendant un achat).
- **Statut** : `corrigé (v0.36.10)`, à confirmer sur le jeu publié. Livré le 24/10 avec B-032, validé à la seconde passe (la première, le 23/10, a refusé le cas du joueur revenu sur le même serveur). Reproduit le 23/10 sur la v0.36.9. Avant la correction, l'écriture était `writeProfile`, `init.server.luau:231-251` (verrou posé en `:242`, refus « held by another server » en `:248-250`) et la boucle de vidage `:283-292`. La correction suit la piste du 23/10, avec quatre écarts notés dans `DECISIONS.md` :
  - le renouvellement compte depuis la dernière écriture **réussie** ;
  - un profil pris par un autre serveur n'est plus jamais écrit d'ici ;
  - la transformation d'écriture passe dans `GlobalQueue.write` ;
  - après le premier refus de la validation, **chaque visite du joueur est une session** dans `SaveQueue`. Un joueur revenu sur le même serveur pendant les nouveaux essais de son écriture de départ ne compte pas comme chargé avant son propre chargement. Il attend la fin de l'ancienne visite (`SaveQueue.held`), et `writeProfile` n'écrit que le profil que cette session a chargé.
- **Reproduit par la chasse du 23/10** :
  - **comment** : un script hors dépôt charge les vrais `SaveQueue` et `GlobalQueue`, et recopie la boucle de vidage (`:283-292`) et `writeProfile`. À chaque seconde, il lit `GlobalQueue.canLock(sauvegarde, "B", t)` : vrai veut dire qu'un autre serveur peut prendre le profil. La colonne « avec la piste » joue la correction proposée plus bas, écrite dans le script (rien n'est changé dans le dépôt) ;
  - **le verrou d'un joueur présent** :

    | Cas | Aujourd'hui | Avec la piste |
    |---|---|---|
    | un joueur, aucun changement pendant 10 min | périmé 90 % du temps, dès t = 61 | jamais périmé ; verrou au plus vieux de 29 s |
    | 100 joueurs inactifs sur un serveur | périmé 90 % du temps | jamais ; 2,0 écritures par joueur et par minute |
    | un renouvellement échoue une fois | (sans objet) | jamais périmé ; verrou au plus vieux de 37 s |

  - **un CLASSÉ, puis le départ 2 s après la fin**. L'autre serveur charge D s après le départ ; l'écriture de départ de l'ancien arrive après la grâce et la latence :

    | Match | D | Grâce | Latence | Aujourd'hui | Avec la piste |
    |---|---|---|---|---|---|
    | 45, 90 ou 120 s | 3 s | 0 | 0,4 s | profil à jour, écriture gardée | à jour |
    | 90 s | 3 s | 0 | 4 s | **le profil d'avant le match ; écriture refusée** | à jour (il attend un essai, 3 s) |
    | 120 s | -1 s (il arrive avant le départ) | 0 | 0,4 s | **le profil d'avant ; refusée** | à jour (3 s) |
    | 120 s | 3 s | 5 s (la grâce de B-023) | 0,4 s | **le profil d'avant ; refusée** | à jour (3 s) |
    | 45 s | 3 s | 5 s | 0,4 s | à jour (le verrou n'a que 57 s) | à jour (3 s) |

  - **trois façons de perdre la course aujourd'hui** :
    - l'écriture de départ est lente : file d'attente du DataStore, ou limite d'une écriture toutes les 6 s par clé ;
    - le joueur arrive sur l'autre serveur avant que l'ancien voie son départ. C'est le cas du même compte lancé sur un autre appareil : Roblox expulse l'ancienne session, mais l'ordre des deux événements n'est pas vérifiable d'ici (supposé) ;
    - tout délai ajouté à l'écriture de départ, comme la grâce de B-023.
- **Piste précise** (sûre : elle n'écrit rien de nouveau, seulement plus souvent le même profil) :
  1. **`SaveQueue`** (pur) :
     - `SaveQueue.RENEW = 20` (secondes) ;
     - `SaveQueue.loaded(q, id, now)` note `lastWrite = now` quand `now` est donné. Le chargement pose déjà le verrou (`init.server.luau:165`). Sans cela, le premier vidage renouvelle tout de suite (une écriture inutile) ;
     - `SaveQueue.renewals(q, now)` rend les ids chargés dont la dernière écriture date de `RENEW` s ou plus, sales ou non, du plus ancien au plus récent, **sans** la limite `BATCH`. Avec `BATCH` (8 par vidage, soit 32 écritures par minute), les verrous de plus de 16 joueurs inactifs expireraient quand même. Sans elle, 100 joueurs inactifs font 2 écritures par joueur et par minute, loin du budget de Roblox (60 + 10 par joueur et par minute) ;
  2. **`init.server.luau`** :
     - `:192` : `SaveQueue.loaded(saves, player.UserId, os.clock())` ;
     - boucle de vidage (`:286-290`) : après la boucle `due`, `if not closing then` une seconde boucle sur `SaveQueue.renewals(saves, os.clock())`, même corps (`GetPlayerByUserId`, `clients[player]`, `task.spawn(writeProfile, …)`). `writeProfile` appelle `SaveQueue.writing`, qui remet `lastWrite` à l'heure : un id écrit par `due` dans le même vidage n'est pas repris ;
     - `local closing = false`, mis à `true` à la première ligne de `BindToClose` (`:2152`). Après les écritures de fermeture, qui relâchent le verrou, aucun renouvellement ne le reprend. C'est le même drapeau que le point 3 de la piste commune de B-023 et B-028 ;
     - dans la transformation de `writeProfile` (`:236-243`), en tête : `if not release and clients[player] ~= client then return nil end`. Une écriture non relâchée, partie juste avant le départ, ne reprend jamais un verrou que l'écriture de départ a relâché. Le cas existe déjà avec une écriture de vidage ; les renouvellements le rendraient plus fréquent ;
  3. **tests** (`Lobby.test`, à côté du test `SaveQueue` de la ligne 508) :
     - un profil chargé, sans changement, vidé toutes les 15 s pendant 10 min : `GlobalQueue.canLock(sauvegarde, "B", t)` est faux à chaque seconde. Sur le code actuel, il échoue dès t = 61 ;
     - 100 profils inactifs : aucun verrou périmé ;
     - un renouvellement raté : le verrou reste frais jusqu'à la reprise ;
     - un profil oublié (`forget`) n'est plus renouvelé ; rien avant `RENEW` s après le chargement ;
     - la marge : `RENEW + 2 * FLUSH_PERIOD < GlobalQueue.LOCK_TTL` (20 + 30 < 60).
- **Le risque de la correction** :
  - le budget : au plus une écriture par joueur et par vidage (4 par minute), comme aujourd'hui pour un profil qui change sans cesse ;
  - **ce que le joueur voit changer** : le serveur suivant attend toujours l'écriture de départ de l'ancien, en général un seul essai de 3 s. Si cette écriture **échoue**, il attend que le verrou expire, jusqu'à 60 s, au lieu de charger tout de suite le profil d'avant. Cette écriture n'est jamais retentée : c'est **B-032**, à corriger dans la même livraison ;
  - par le même chemin, un CLASSÉ entre serveurs démarre au bout de 20 s même si un profil n'est pas chargé (`init.server.luau:1115-1119`). Le chargement finit ensuite pendant le match (au plus 65 s), et `Profile.merge` remplace le profil par défaut. C'est déduit du code, et il faut une écriture de départ ratée ;
  - non vérifiable hors ligne : dans quel ordre le DataStore traite deux requêtes sur la même clé envoyées par le même serveur (supposé : dans l'ordre d'envoi) ;
  - **un joueur déconnecté que l'ancien serveur tarde à retirer voit « SAVES UNAVAILABLE » sur le nouveau** (relevé par la validation le 23/10, accepté par production, `DECISIONS.md`) :
    - pourquoi : tant que l'ancien serveur garde le joueur (coupure réseau pas encore détectée), il renouvelle son verrou. Le nouveau serveur attend ce verrou ;
    - le seuil, d'après `loadProfile` : 22 essais espacés de 3 s (66 s), puis 1 + 2 + 4 + 8 s. Le dernier essai part vers 73 s : un verrou libéré au plus **environ 73 s** après l'arrivée est encore pris, et le message s'affiche vers 81 s (mesuré par la validation du 24/10). Si l'ancien serveur met plus longtemps à retirer le joueur, la nouvelle session n'est pas sauvegardée et le dit (« SAVES UNAVAILABLE »). Avant la correction, le verrou était presque toujours déjà périmé, et le nouveau serveur le prenait tout de suite ;
    - non vérifiable d'ici : le temps que met Roblox à retirer un joueur dont la connexion est coupée ;
  - sur le même serveur, une nouvelle visite attend l'ancienne (son écriture de départ et ses nouveaux essais) au plus `LOCK_TTL + 5` = 65 s. Au-delà, elle charge quand même et prend l'id. Une écriture de l'ancienne visite encore en route à ce moment pourrait alors relâcher son verrou, jusqu'au renouvellement suivant (20 à 35 s). Et les derniers changements de l'ancienne visite peuvent être perdus (rejoué par la validation du 24/10 sur le vrai code) : si son écriture de départ reste plus de 65 s dans la file du DataStore, la nouvelle visite charge la version d'avant, puis la réécrit à son renouvellement ; si Roblox retire l'ancienne visite plus de 65 s après l'arrivée de la nouvelle, son changement n'est jamais écrit. C'est mieux que la v0.36.9, où cela arrivait sans aucune attente. Une autre option, à trancher plus tard : afficher « SAVES UNAVAILABLE » au lieu de prendre l'id ;
  - non traité (pas bloquant, relevé par la validation) : un renouvellement envoyé juste avant `BindToClose` pourrait arriver **après** l'écriture de fermeture et reprendre le verrou, si le DataStore ne garde pas l'ordre des requêtes d'un même serveur. Le serveur suivant attendrait alors jusqu'à 65 s ;
  - hors de cette correction : si Roblox ajoute la nouvelle visite avant de retirer l'ancienne, le départ de l'ancienne appelle aussi `Lobby.leave` et `Matchmaker.leave` sur le même id (déduit du code, non vérifié).
- **À vérifier sur le jeu publié, après la correction** :
  - un joueur reste 2 minutes sans rien faire dans le hub, puis rejoint un autre serveur. La console de l'ancien serveur ne doit pas afficher « held by another server » ;
  - **le relevé de l'attente** : l'écart entre la ligne `[FightingGame] leave <id> at … (os.time …)` de l'ancien serveur et la ligne `[FightingGame] profile <id> loaded at … (os.time) after …` du nouveau. Cette ligne n'apparaît que si le chargement a attendu. Le cas à relever : fermer le jeu brutalement (coupure réseau), puis rejoindre aussitôt. Si l'ancien serveur garde le verrou plus d'environ 73 s, la ligne `profile <id> not loaded … saves unavailable` apparaît à la place, vers 81 s. **Attention** : la ligne `profile <id> not loaded … after N s … saves unavailable` (`init.server.luau:219-220`) ne compte pas l'attente d'une ancienne visite sur le **même** serveur (`held`). Elle peut afficher « after 0 s » après 7 s d'attente (relevé par la validation, non corrigé dans la v0.36.10). *(Précisé par la chasse du 25/10 : la ligne `profile <id> loaded … after …`, elle, est en `:206-209` et donne les deux attentes séparément, celle de l'ancienne visite et celle du verrou d'un autre serveur ; le défaut ne touche que la ligne d'échec. La note du journal de la v0.36.10, « la ligne de console du chargement ne compte pas l'attente d'une ancienne visite », vise donc la ligne d'échec seulement.)* Sur un autre serveur, les deux lignes sont justes ;
  - un retour sur le même serveur (par exemple « Rejoindre » sur un ami) juste après un départ : le profil revient à jour.
- **Ancienne piste** (20/10) : la même idée (`SaveQueue.stale(q, now, ttl)` à `LOCK_TTL / 2`). Elle est remplacée par celle du 23/10 : à 30 s, avec un vidage toutes les 15 s, la marge ne couvre pas un renouvellement raté, et la limite `BATCH` affamait les renouvellements.

## B-026 · Un ÉVEIL ou une PORTE qui tue avant la dernière manche finit sur « K.O. · … · VICTORY », puis le match continue
- **Date** : 21 octobre 2026.
- **Source** : trouvé par la chasse, en suivant les fins de manche des modes (1 VS 1 · CPU, relais, SURVIE).
- **Comment reproduire** :
  - ici : script de la chasse, hors dépôt. On prend un monde hors entraînement, manche 1, aucune manche gagnée. On lance `Sim.debugCinematic(w, 1, "Gate" ou "Awaken", nil, 30 % de la vie de la cible)`, puis on appelle `Director.cinematic` à chaque tick et on relève le dernier titre affiché ;
  - en jeu : 1 VS 1 · CPU, dès la manche 1, une PORTE ou un ÉVEIL sur un adversaire sous 30 % de sa vie maximale (FINAL FINISH).
- **Ce qui se passe** (prouvé sur la simulation et le directeur) :

  | Lanceur, ultime | Dernier titre à l'écran | `RoundEnd` | Ensuite |
  |---|---|---|---|
  | KAI, PORTE | « K.O. » / « … · VICTORY » | `matchOver = false`, `inCinematic = true` | manche 2 (score 1-0) |
  | TARO, ÉVEIL | idem | idem | manche 2 |
  | SHIN, PORTE | idem | idem | manche 2 |

  - un FINAL FINISH joue toujours la scène K.O. complète, jusqu'au fondu au noir (c'est voulu : « Scène de K.O. (FINAL FINISH et K.O. qui gagne le match) », `docs/JOURNAL.md`) ;
  - mais le sous-titre « · VICTORY » est écrit sans regarder si le match est gagné ;
  - le HUD se tait (`inCinematic`, `HUDController.luau:1439`) : « VICTORY » est le seul texte de cette fin de manche ;
  - même chose au premier K.O. d'un relais 2v2 ou 3v3, à chaque vague de SURVIE gagnée ainsi, et dans le faux K.O. d'ASURA (B-020 ; plus depuis la v0.36.8 : abattu dans sa première vie, il n'a plus de scène K.O.) ;
  - le COUP FATAL classique n'a pas ce défaut : il n'écrit que « K.O. » et le nom du coup (`FATAL.title`, `CinematicDirector.luau:2702-2710`). Le FATAL FINISHER non plus : aucun titre « VICTORY » dans `Finishers.luau`.
- **Ce qui devrait se passer** : « VICTORY » seulement quand ce K.O. gagne le match. Sinon, « K.O. » avec le nom, ou le numéro de la manche.
- **Cause** (prouvée) :
  - `src/shared/CinematicDirector.luau:5172-5174` : `cin.finish` lance `Director.ko` quel que soit le score ;
  - le dernier plan de la scène K.O. écrit `· VICTORY` en dur : `:5067` (KAI) et `koEnd`, `:3221` (les 8 scènes K.O. propres à un kit).
- **Gravité** : mineur. C'est un mot, mais sur un écran noir, à la fin d'une longue scène : le joueur croit le match gagné. Et c'est fréquent : il suffit d'un ÉVEIL ou d'une PORTE sur une cible sous 30 % de sa vie maximale (`MaxHealthShare = 0.3`, `MoveData.luau:927`, `:962`), à n'importe quelle manche.
- **Statut** : `ouvert` (code inchangé au 23/10, sur la v0.36.9 ; la v0.36.8 retire seulement le cas du faux K.O. d'ASURA). Le FATAL FINISHER de KUROEN (v0.36.9) n'écrit jamais VICTORY : un test de `Cinematography` le vérifie. **25/10** : inchangé sur la v0.36.10. `CinematicDirector.luau:5174`, `:5067` et `:3221` tiennent. Le calcul de `matchOver` cité dans la piste est maintenant en `CombatSimulation.luau:2487-2491` (et non plus `:2479-2483`). **26/10** : inchangé sur la v0.36.11, lignes valables.
- **Piste** :
  - la simulation sait, au coup final, si ce K.O. décide le match : c'est le même calcul que `matchOver` dans `endRound` (`CombatSimulation.luau:2479-2483`), avec une victoire de plus ou un perso de moins. On le pose dans `world.cinematic` (par exemple `decides = true`), qui part dans l'instantané ;
  - la scène K.O. écrit « VICTORY » seulement si `ctx.cin.decides`, ou si elle joue après la fin du match (`victoryScene`) ;
  - un test dans `Cinematography` : un FINAL FINISH à la manche 1 n'affiche pas VICTORY ; à la balle de match, il l'affiche ;
  - en SURVIE, ce calcul dit « décidé » à chaque vague (même cause que B-022) : à corriger ensemble.

## B-027 · Temps écoulé : la manche va au plus de PV, pas à la barre de vie la plus pleine
- **Date** : 21 octobre 2026.
- **Source** : trouvé par la chasse (modes et règles de fin de manche).
- **Comment reproduire** :
  - ici : script de la chasse, hors dépôt, deux kits de vies différentes, `timerTicks = 2`, puis on regarde le `RoundEnd` :

    | Combattant 1 | Combattant 2 | Gagnant |
    |---|---|---|
    | GORAN 680/1700 (barre 40 %) | AKEMI 630/1050 (barre 60 %) | **GORAN** |
    | TARO 780/1560 (barre 50 %) | YUKINA 775/1250 (barre 62 %) | **TARO** |
    | KAI 930/1550 (barre 60 %) | ASURA 960/3200 (barre 30 %), défi en relais | **ASURA** |

  - en jeu : laisser filer les 99 s avec la barre la plus pleine, face à un perso qui a plus de vie maximale.
- **Ce qui se passe** (prouvé) :
  - `src/shared/CombatSimulation.luau:2455` : `winner = if a.hp > b.hp then 1 elseif b.hp > a.hp then 2 else 0`, en PV absolus ;
  - les vies maximales vont de 1 050 (AKEMI) à 1 700 (GORAN), 3 200 pour ASURA, 3 000 pour KUROEN SHIN ;
  - le HUD dessine des barres proportionnelles (`view.hp / view.maxHp`, `src/client/HUDController.luau:1457`) : le joueur voit sa barre plus pleine et perd la manche ;
  - au défi ASURA, un temps écoulé élimine le perso du joueur tant qu'ASURA a plus de PV absolus, donc presque toujours ;
  - le test du dépôt (`tests/CombatSimulation.test.luau:1083`) ne joue que KAI contre KAI.
- **Fréquence mesurée** : aucun temps écoulé sur 101 manches CPU contre CPU (77 manches de niveau 4, sur 5 paires de kits aux vies très différentes ; 24 contre ASURA). Des joueurs prudents vont plus souvent au bout des 99 s ; cela ne se mesure pas d'ici.
- **Ce qui devrait se passer** : à décider. Le cahier des charges demande de « définir double K.O. et timeout avant implémentation » (`docs/Roblox_Guide_Claude.md:156`), et la règle n'est écrite nulle part pour des vies différentes. L'usage des jeux de combat, et ce que montre le HUD, c'est la part de vie restante.
- **Gravité** : mineur. C'est rare, mais faux en combat quand cela arrive, et toujours en défaveur du perso fragile ou du joueur face au boss.
- **Statut** : `à confirmer` (règle à trancher par Wilhem ou production : part de vie, comme la barre, ou PV absolus ; code inchangé au 25/10). Depuis la v0.36.8, la ligne fautive est `CombatSimulation.luau:2463` (et non plus `:2455`) ; le test du dépôt commence en `tests/CombatSimulation.test.luau:1082`.
- **Piste** :
  - comparer `a.hp / a.maxHp` à `b.hp / b.maxHp`, avec égalité = manche nulle comme aujourd'hui ;
  - un test avec deux kits de vies différentes, et un relais contre ASURA ;
  - relancer Balance, même si les temps écoulés y sont rares.

## B-028 · Une mise à jour du serveur pendant un CLASSÉ compte comme un abandon pour le premier joueur retiré
- **Date** : 21 octobre 2026.
- **Source** : trouvé par la chasse, en préparant la piste de B-023 (qui part de `unseat`).
- **Comment reproduire** :
  - ici : relecture du code ; la fermeture d'un serveur Roblox ne se rejoue pas hors Studio ;
  - en jeu : deux comptes en CLASSÉ, depuis plus de 25 s, chacun avec au moins 20 actions. Wilhem publie, puis « Migrate to Latest Update » (ou « Shut Down All Servers »). On compare ensuite la cote, la série et l'historique des deux.
- **Ce qui se passe** :
  - prouvé dans le code :
    - `Players.PlayerRemoving` (`src/server/init.server.luau:1269-1274`) appelle `unseat`, qui appelle `endVersus(match, 3 - i, i)` (`:561`) : le joueur retiré est traité en déserteur ;
    - rien ne marque la fermeture du serveur : `BindToClose` (`:2152-2171`) prévient les clients (`updating = true`) et écrit les profils, c'est tout ;
    - celui qui part le premier perd donc sa cote (si le match compte, voir B-023), ses pièces et sa série (`Economy.streak`, « left ») ;
    - l'autre gagne la victoire, les pièces, la série, les quêtes et les points de la semaine ;
  - supposé (non vérifiable d'ici) : à la fermeture, Roblox retire les joueurs un par un (téléportation vers le nouveau serveur, ou déconnexion), et le premier retiré déclenche `PlayerRemoving` pendant que l'autre est encore assis. L'ordre entre `BindToClose` et `PlayerRemoving` n'est pas connu d'ici.
- **Ce qui devrait se passer** : un match coupé par le serveur ne compte pour personne (aucun point, aucune série perdue), comme un match annulé.
- **Gravité** : mineur. Cela ne touche que les CLASSÉS en cours au moment d'une mise à jour, mais les livraisons sont quotidiennes (à chaque publication suivie d'un « Migrate », supposé), et le joueur perd des points sans rien avoir fait. La correction de B-023, si elle ne traite pas ce cas, l'aggrave : la perte s'appliquerait dès la première seconde.
- **Statut** : `corrigé en partie (v0.36.11)` (25/10, avec B-023 : la portée V1 couvre l'ordre « `BindToClose` d'abord » ; voir « Correction du 25/10 » en bas de la fiche). Reste ouvert : si Roblox retire les joueurs avant `BindToClose`, le premier retiré perd toujours ; la suite (V2, grâce de 5 s au plus) attend le relevé des lignes de console sur le jeu publié. Avant : `à confirmer` (le mécanisme est prouvé, l'ordre des événements de Roblox à la fermeture ne l'est pas). Code inchangé au 24/10. À corriger avec B-023, après B-025 et B-032. Le diff de B-025 (en validation) pose déjà le drapeau `closing` en tête de `BindToClose`, et deux lignes de console qui donneront l'ordre réel des événements : `[FightingGame] leave <id> at … · closing true|false` et `[FightingGame] closing at …`. Il ne change pas `unseat` : la perte décrite ici reste.
- **25/10, sur la v0.36.10** : B-025 et B-032 sont livrés. Le drapeau `closing` est en `init.server.luau:149` (posé en `:2203`), les lignes de console en `:1315-1316` et `:2204`. `unseat` (`:599-606`) ne le lit pas encore : la perte reste. **La correction n'attend plus le relevé** (voir « Chasse du 25/10 » dans B-023) :
  - le drapeau de fermeture couvre l'ordre « `BindToClose` d'abord » sans rien retarder ;
  - la grâce de 5 s couvre l'ordre « départs d'abord » si les départs des deux joueurs, ou `BindToClose`, tombent dans ces 5 s. Elle ne perd plus l'écriture de départ (prouvé) ;
  - le relevé dira s'il reste un cas, des départs espacés de plus de 5 s avant `BindToClose`, et s'il faut régler la grâce.
- **Précision du 25/10** (déduite du code) : dans l'ordre « `BindToClose` d'abord », la perte ne se garde pas toujours. L'écriture de fermeture (`:2211-2220`) écrit le profil d'avant le résultat et relâche le verrou. Puis le départ du joueur appelle `endVersus` et lance une nouvelle écriture de départ. Si le nouveau serveur du joueur (la migration) a déjà pris le verrou, elle est refusée (« lost ») : la perte reste en mémoire seulement. Sinon, elle est écrite. Le résultat dépend donc d'une course, et le test en jeu peut donner l'un ou l'autre.
- **Revu par la chasse du 22/10** :
  - aucun signal sûr d'une fermeture, à part `BindToClose` lui-même. `PlayerRemoving` reçoit une raison, mais `Enum.PlayerExitReason` ne vaut que `Unknown`, `PlatformKick` ou `CreatorKick`, et aucune propriété lisible par un script ne dit « en fermeture » (dump d'API complet de Roblox, copie du 16/10) ;
  - Wilhem met à jour par « Migrate to Latest Update » (`docs/JOURNAL.md`, v0.24.5). Chaque livraison suivie d'une migration touche donc les CLASSÉS en cours, y compris ceux des serveurs réservés (CLASSÉ entre serveurs, `init.server.luau:1013`) ;
  - pas de doublon : c'est le même endroit que B-023. **La piste commune est dans B-023** (drapeau de fermeture, délai de grâce de quelques secondes sur `PlayerRemoving`, match sans résultat si les deux joueurs quittent le serveur dans ce délai).
- **Comment le confirmer** (Wilhem, jeu publié) : deux comptes en CLASSÉ, depuis plus de 25 s, chacun avec plus de 20 actions. Wilhem publie, puis lance « Migrate to Latest Update ». Ensuite, sur les deux comptes, il compare la cote, la série et la ligne d'historique de ce match. Aujourd'hui, l'un perd et l'autre gagne. Après la correction, aucun ne doit bouger.
- **Piste** (20/10 ; remplacée par la piste commune de B-023) :
  - un drapeau `closing = true` posé en tête de `BindToClose`. `unseat` n'appelle alors pas `endVersus`, ou l'appelle sans points ni série (« no contest ») ;
  - si Roblox retire les joueurs **avant** d'appeler `BindToClose`, ce drapeau arrive trop tard. Repli possible : ne rien compter quand les deux joueurs d'un match partent à moins de quelques secondes d'écart. Le premier départ attendrait alors un court délai avant de conclure ;
  - à faire en même temps que B-023.
- **Correction du 25/10 (production, avec B-023, portée V1, en attente de la validation)** :
  - **couvert : l'ordre « `BindToClose` d'abord »**. En `init.server.luau:2232`, juste après `closing = true` et avant toute attente, chaque 1v1 entre joueurs en cours devient sans résultat (`AntiCheat.noContest`). Les départs (`unseat`, `AntiCheat.departure`) et le K.O. qui arrivent ensuite ne comptent plus. Rien n'est écrit dans le profil : ni cote, ni pièces, ni série, ni ligne d'historique. Cela règle aussi la course de la « Précision du 25/10 » : plus aucune écriture de départ ne porte un résultat après l'écriture de fermeture. Les deux joueurs lisent « NO CONTEST » (« MATCH ANNULÉ ») dans le bandeau UPDATE. Cela vaut pour NORMAL, AMI et CLASSÉ, et pour les serveurs réservés du CLASSÉ entre serveurs ;
  - **pas couvert : l'ordre « départs d'abord »**. Si Roblox retire les joueurs avant d'appeler `BindToClose`, le premier retiré perd, comme avant. Depuis la correction de B-023, il perd aussi dans les 25 premières secondes. Le test `Lobby.test:1256` l'écrit comme la limite connue ;
  - **la suite** : relever sur le jeu publié l'ordre des lignes `[FightingGame] leave …` et `[FightingGame] closing at …` à une migration. Si les départs arrivent avant, faire V2 (la grâce de 5 s au plus sur `PlayerRemoving`, piste de la chasse du 25/10 dans B-023) ;
  - **comment le confirmer** : le test en jeu ci-dessus (deux comptes en CLASSÉ, puis « Migrate to Latest Update »). Avec cette correction, aucun ne doit bouger si `BindToClose` arrive d'abord. Sinon, le premier retiré perd : c'est le signe qu'il faut V2.
- **26/10, sur la v0.36.11** : rien de nouveau du jeu publié (le relevé n'est pas encore fait). Les lignes : le drapeau `closing` en `init.server.luau:149`, posé en `:2226` ; les lignes de console en `:1334-1335` (`leave …`) et `:2227` (`closing at …`) ; la boucle `noContest` en `:2230-2237` ; l'envoi de « NO CONTEST » en `:2240-2242` ; les écritures de fermeture en `:2245-2253`, l'attente en `:2256`. Un match lancé pendant l'attente de `BindToClose` est couvert par la décision `"void"` au départ de ses joueurs (relu, voir la note du 26/10 de B-023).

## B-029 · SURVIE : un double K.O. compte l'adversaire comme battu
- **Date** : 21 octobre 2026.
- **Source** : trouvé par la chasse, en rejouant les règles de SURVIE du serveur.
- **Comment reproduire** :
  - ici : script de la chasse, hors dépôt. On recopie les règles du serveur (`init.server.luau:610-614`, `:1979-1985`, `:2004-2012`), puis on fait tomber les deux combattants au même tick de la vague 1 ;
  - en jeu : un double K.O. (ou un temps écoulé à vie égale) en SURVIE.
- **Ce qui se passe** (prouvé sur la simulation, avec les règles du serveur recopiées) :
  - `RoundEnd` `winner = 0` : les deux équipes perdent leur combattant (`CombatSimulation.luau:2458-2468`) ;
  - le serveur voit l'équipe CPU vide, ajoute l'adversaire suivant et passe à la vague 2 (`:1981-1985`) ;
  - la partie finit (`MatchEnd`, le CPU gagne), et le serveur compte `beaten = match.wave - 1 = 1` (`:2006`) : 10 pièces, record de SURVIE 1, succès SURVIVOR avancé d'un adversaire qui n'a pas été battu.
- **Ce qui devrait se passer** : seuls les adversaires vraiment battus comptent. Un double K.O. finit la course au score d'avant.
- **Gravité** : cosmétique (rare, un adversaire de trop dans le compte).
- **Statut** : `ouvert` (code inchangé au 24/10 ; aucun double K.O. dans les 240 SURVIES du fuzz de la chasse du 22/10 : c'est rare). Après la correction de B-025, les lignes citées descendent de 44 (`:654-658`) et de 50 (`:2029-2035`, `:2054-2062`). **25/10, vérifié sur la v0.36.10** : le départ de la SURVIE est en `init.server.luau:654-658`, l'ajout de l'adversaire en `:2029-2037`, et `beaten = match.wave - 1` en `:2056`. Côté simulation, le relais (les deux équipes perdent leur combattant sur un nul) est en `CombatSimulation.luau:2466-2477`.
- **26/10** : code inchangé sur la v0.36.11 ; les lignes du serveur ont bougé : le départ de la SURVIE est en `init.server.luau:669-673` (`match.wave, match.seed = 1, …` en `:670`), l'ajout de l'adversaire en `:2052-2060`, et `beaten = match.wave - 1` en `:2079`. `CombatSimulation.luau:2466-2477` tient.
- **Piste** :
  - dans `followEvents`, n'ajouter l'adversaire suivant (et `match.wave += 1`) que si `event.winner == 1` ;
  - ou compter les vagues gagnées à part (`match.beaten`) ;
  - un test avec la correction de B-022, qui touche le même endroit.

## B-030 · CHALLENGE · ASURA : un COUP FATAL qui abat sa première vie le laisse à genoux à l'écran, puis il est couché d'un coup
- **Date** : 22 octobre 2026.
- **Source** : trouvé par la chasse, en cherchant les effets de bord de la correction de B-020 (v0.36.8).
- **Comment reproduire** :
  - ici : script hors dépôt. `Sim.debugCinematic(w, 1, "Fatal", nil, vie)`, sans finisher, puis on joue jusqu'à `CinematicEnd` et on relève l'état de la cible :

    | Lanceur, cible, vie de la cible | `finish` | Fin de la scène (directeur) | État dans la simulation à `CinematicEnd` |
    |---|---|---|---|
    | KAI, KAI, 90 % | faux | à genoux (`Kneel`) | `Idle` : debout, cohérent |
    | KAI, KAI, 5 % | vrai | face au sol (`DownFace`), « K.O. » | `KO` : cohérent |
    | KAI, ASURA, 90 % | faux | à genoux | `Idle` : cohérent |
    | KAI, ASURA, 1 % (première vie) | faux | **à genoux** | **`Knockdown`** pour 90 images, `Revive` au même tick |

    Avec l'ÉVEIL, la PORTE et le RUSH, la cible est en `Knockdown` à la fin de la scène, qu'elle soit abattue ou non : pas d'écart ;
  - en jeu : CHALLENGE · ASURA, l'abattre dans sa première vie avec un COUP FATAL (C), après un combo qui l'a mis sous 50 % de sa vie.
- **Ce qui se passe** :
  - prouvé : depuis la v0.36.8, `finish` est faux sur sa première vie (B-020). Toutes les scènes de COUP FATAL posent alors la cible à genoux : `FATAL.fall` (`src/shared/CinematicDirector.luau:2690-2699`, les 8 scènes propres à un kit) et `GEN.lie` (`:4183-4191`, les autres). Leur titre est « <nom du coup> · FATAL BLOW » : c'est juste ;
  - prouvé : au même instant, la simulation le couche. Le dernier coup l'a mis à 0 PV et en `KO`, puis `revive` le met en `Knockdown` pour `KnockdownTicks + RiseTicks` = 90 images (`src/shared/CombatSimulation.luau:1204-1212`) ;
  - déduit du code client : à la fin de la scène, la caméra revient au combat, et le corps passe d'à genoux à couché en 0,07 s (fondu de l'`Animator`, `src/shared/Animator.luau:851`). Puis il se relève dans son aura noire 1,5 s plus tard ;
  - avant la v0.36.8, la scène jouait sa version K.O. (face au sol), cohérente avec la simulation. Mais elle était fausse : c'était le faux K.O. de B-020.
- **Ce qui devrait se passer** : abattu, ASURA finit la scène au sol, sans titre K.O., puis se relève dans son aura.
- **Cause probable** : le snapshot n'envoie que `finish` (`src/server/init.server.luau:1910`), pas `fells`. Le directeur ne peut donc pas savoir que la cible est abattue sans être K.O.
- **Gravité** : cosmétique. Un faux raccord, au moment d'une coupe de caméra, une fois par défi au plus (la seconde vie ne revient pas). Mais c'est le moment fort du défi, le plus mis en avant.
- **Statut** : `ouvert` (mécanisme prouvé ; l'effet à l'écran est à juger en jeu). Code inchangé au 25/10 : le snapshot est en `init.server.luau:1960` (v0.36.10). `FATAL.fall` (`CinematicDirector.luau:2690-2699`), `GEN.lie` (`:4186`) et `revive` (`CombatSimulation.luau:1204-1212`) tiennent. **26/10** : inchangé sur la v0.36.11 ; le snapshot de la cinématique (`finish = world.cinematic.finish`) est maintenant en `init.server.luau:1983`.
- **Piste** :
  - ajouter `fells = world.cinematic.fells` au snapshot (`init.server.luau:1910`) ;
  - pour la **pose** seulement : `cin.finish or cin.fells` dans `FATAL.fall` (`CinematicDirector.luau:2694`) et dans `GEN.lie` (`:4186`). Le **titre** reste sur `cin.finish` (`FATAL.title`, `:2705`), comme la scène K.O. et `finishEpoch` (`src/client/CinematicController.luau:759`) ;
  - un test dans `Cinematography` : un COUP FATAL qui abat la première vie d'ASURA finit en `DownFace`, avec le titre « FATAL BLOW » et non « K.O. ». Le même coup sur une cible qui reste debout finit toujours à genoux ;
  - à relire au storyboard. `tests/Storyboard.luau` ne choisit pas la cible (corps de KAI) : il faut lui passer `fells = true, finish = false` à la main, ou lui ajouter une cible ASURA ;
  - risque faible : seule la première vie d'ASURA a `fells` vrai et `finish` faux (prouvé par la comparaison de la chasse du 22/10, B-020).

## B-031 · BLACK SUN (KUROEN) : le grand soleil saute à l'impact
- **Date** : 22 octobre 2026.
- **Source** : relevé par l'agent `validation` (routine du 22/10).
- **Ce qui se passe** : au tick 440, dans le même plan (`kuroen-bs-blow`), le grand soleil saute de 3,62 studs (2,29 depuis la droite). Les poings de KUROEN finissent ailleurs que là où il apparaît (`pos = At(v(tx + dir * 0.3, …))`, `S.KUROEN`). Le test ne suit que les trois petits soleils.
- **Piste** : faire voyager le grand soleil depuis `P(A, "RightHand")` jusqu'au point d'impact, lui donner un `mark`, et étendre le test au grand soleil.
- **Gravité** : cosmétique.
- **Statut** : `ouvert` (confirmé le 23/10 sur la v0.36.9 ; `Finishers.luau` inchangé au 25/10, sur la v0.36.10).
- **Confirmé par la chasse du 23/10** :
  - comment : script hors dépôt, `Kit.play("KUROEN", "Fatal", nil, 300, 0, …)` des deux côtés. On suit la sphère noire (`07040C`) et on relève chaque saut de plus de 0,5 stud d'une image à l'autre ;
  - au tick 440, dans le plan `kuroen-bs-blow` : 3,62 studs depuis la gauche, 2,29 depuis la droite, comme l'a mesuré la validation. Cause : `src/shared/Finishers.luau:3155` (`pos = At(v(tx + dir * 0.3, lerp(1.6, -0.4, q), 0.3))`). Jusqu'au tick 439, le soleil est accroché à la main (`:3152`) ; au tick 440, il passe d'un coup à ce point fixe ;
  - au tick 436, il saute aussi de 4,57 studs, des deux côtés. Mais c'est l'image de la coupe entre `kuroen-bs-sun` et `kuroen-bs-blow`, quand le coup AXE OF NIGHT passe en frappe (`:3085`). Une coupe franche cache ce saut : ce n'est pas un défaut ;
  - le reste de la scène est propre : une lumière à la fois (l'image rémanente du tick 110 s'éteint au tick 131, avant le premier petit soleil au 132), et le client connaît chaque effet (`eclipse`, `eclipseSeal`, `debris`, `afterimage`), chaque son (`charge`, `heavy`, `boom`, `whoosh`) et la teinte `eclipse`.

## B-032 · L'écriture finale d'un joueur qui part n'est jamais retentée
- **Date** : 23 octobre 2026.
- **Source** : trouvé par la chasse, en préparant la piste de B-025.
- **Comment reproduire** :
  - ici : un script hors dépôt charge le vrai `SaveQueue` et recopie le fil de `PlayerRemoving` (`writeProfile`, puis `SaveQueue.forget`). Un CLASSÉ finit à t = 120 et marque le profil ; le joueur part à t = 125, avant le vidage suivant, et l'écriture échoue une fois. Après `forget`, le profil n'est plus ni chargé ni sale, et `SaveQueue.due` (même urgent) est vide. La sauvegarde garde la version d'avant le match ;
  - en jeu : cela ne se provoque pas. Il faut une erreur du DataStore au moment du départ (incident Roblox, budget dépassé).
- **Ce qui se passe** (prouvé dans le code, et sur le module rejoué) :
  - `PlayerRemoving` (`src/server/init.server.luau:1276-1281`) appelle `writeProfile(player, client, true)`, puis `SaveQueue.forget`, quel que soit le résultat. Si `UpdateAsync` lève une erreur, `writeProfile` remet bien le profil « sale » (`:244-246`), mais `forget` l'efface aussitôt : personne ne réessaie ;
  - même chose dans `BindToClose` (`:2160-2167`) : une seule tentative par joueur, alors que la fermeture attend jusqu'à 25 s ;
  - ce qui est perdu : tout ce qui n'était pas encore écrit. Après un match, c'est son résultat (cote, pièces, série, historique, quêtes), si le joueur part avant le vidage suivant (jusqu'à 15 s) ;
  - le verrou n'est pas relâché non plus. Le serveur suivant attend qu'il expire : mesuré avec `GlobalQueue.canLock`, un verrou posé à t = 100, puis le joueur arrive sur B à t = 130 : B ne charge qu'à t = 163 (33 s d'attente). Aujourd'hui, souvent pas d'attente, parce que le verrou est souvent déjà périmé (B-025). Après la correction de B-025, ce sera jusqu'à 60 s.
- **Ce qui devrait se passer** : l'écriture finale est retentée quelques fois tant que le serveur vit ; seule une erreur qui dure fait perdre les derniers changements.
- **Cause** : `src/server/init.server.luau:1276-1281` (départ) et `:2160-2167` (fermeture).
- **Gravité** : mineur. C'est rare, mais c'est de la progression perdue quand cela arrive. Et la correction de B-025 le rend plus visible : une attente au chargement suivant.
- **Statut** : `corrigé (v0.36.10)`, à confirmer sur le jeu publié. Livré le 24/10 avec B-025. Règle pure `SaveQueue.finalRetry`, et `BindToClose` attend aussi les écritures de départ encore en cours. **Relu le 25/10 sur le code livré** : les nouveaux essais sont dans `finalWrite` (`init.server.luau:314-323`), appelés au départ (`:1324-1332`) et à la fermeture (`:2211-2220`), et `BindToClose` attend `finalWrites` (`:2223`). Dans le fuzz rejoué avec pannes, 3 856 nouveaux essais sur 12 000 scénarios, sans échec. **26/10** : depuis la v0.36.11, l'écriture de départ est en `init.server.luau:1343-1351`, celles de la fermeture en `:2245-2253`, l'attente en `:2256` ; `finalWrite` (`:314-323`) n'a pas bougé.
- **Piste** :
  - `writeProfile` rend la raison d'un échec : `false, "error"` (le `pcall` a échoué) ou `false, "lost"` (le verrou est à un autre serveur ; réessayer ne sert à rien) ;
  - dans `PlayerRemoving` et dans `BindToClose` : jusqu'à `SaveQueue.LOAD_TRIES` (4) tentatives, avec `task.wait(SaveQueue.retryDelay(n))` entre deux (1, 2, 4 s : 7 s en tout, dans les 25 s de `BindToClose`), seulement sur `"error"`. Puis `forget` ;
  - le choix « réessayer ou abandonner » peut être une fonction pure de `SaveQueue` (par exemple `SaveQueue.finalRetry(reason, attempt)` → le délai, ou `nil`), testée dans `Lobby.test`. Le fil Roblox lui-même ne se teste pas hors ligne ;
  - à faire dans la même livraison que B-025 : même endroit, et c'est ce qui rend sa correction sûre.

## B-033 · Les deux bosses mélangent leur matière sonore avec celle du perso qui leur prête ses coups
- **Date** : 24 octobre 2026.
- **Source** : relevé par le tri des idées du 24/10 pour KUROEN SHIN (« il n'a pas d'entrée dans `SoundPalette.MATERIALS`, donc `SoundController` le fait sonner comme KAI »). Vérifié par la chasse, qui a trouvé le cas inverse chez ASURA. Règle de `CLAUDE.md` : « chaque perso garde sa matière sonore ».
- **Comment reproduire** :
  - ici : un script charge les vrais `MoveData` et `SoundPalette`, puis refait le choix de `SoundController` pour chaque son. Résultat :

    | Boss | Entrée dans `MATERIALS` | Élans, élans lourds, temps de chope, pas (`view.kit`) | Coups et projectiles (`MoveKit[move]`, 29 rôles) |
    |---|---|---|---|
    | KUROEN SHIN | **aucune** | **KAI** | KUROEN |
    | ASURA | oui | ASURA | **KAI** (29 sur 29) |

  - en jeu : CHALLENGE · KUROEN SHIN, écouter ses élans lourds et sa chope ECLIPSE CLINCH. Puis CHALLENGE · ASURA, écouter ses coups.
- **Ce qui se passe** (prouvé dans le code et sur les modules) :
  - `material(kit)` rend `MATERIALS[kit] or MATERIALS.KAI` (`src/client/SoundController.luau:32-34`) ;
  - les élans et les pas prennent le kit de la vue (`:237`, `:270`), les temps de chope celui de l'attaquant (`:182`). Pour KUROEN SHIN, ce kit n'a pas d'entrée (`src/shared/SoundPalette.luau:57-200`) : c'est la matière de KAI. Ses élans lourds perdent l'écho de KUROEN (`whoosh` 0,47 à 0,97, sans bus, au lieu de 0,56 à 0,94 dans `echo`), et les genoux et coudes de sa chope tapent le `punch` grave et sec de KAI (0,82) au lieu de celui de KUROEN (1,12, dans `hall`) ;
  - les coups (`Hit`, `:186`) et les projectiles (`:198`) prennent d'abord le propriétaire du coup, `MoveData.MoveKit[event.move]`. `MoveKit` ignore les bosses (`src/shared/MoveData.luau:1459`, « ASURA borrows KAI's moves: they stay KAI's »). KUROEN SHIN frappe donc avec la matière de KUROEN, et ASURA avec celle de KAI : ses `hit`, `heavyHit` et `projectile` à lui (`SoundPalette.luau:114-120`, « KAI's blows, deeper, in the hall ») ne jouent jamais sur un coup, seulement sur les temps de sa chope ;
  - chez ASURA, c'est ainsi depuis son arrivée (v0.15.0 ; `MoveKit` dans `Hit` depuis le commit `7e93cbe`, 12/10). Ce n'est pas une régression.
- **Pourquoi les tests ne le voient pas** : les vérifications des matières de `tests/Kits.test.luau` (`:508-513` et `:535-547`, « does not land with », « has no sound material », « hits like ») ne parcourent que `MoveData.KitOrder`, sans les bosses. Le choix lui-même est dans `SoundController`, du code client qui ne se teste pas hors ligne.
- **Ce qui devrait se passer** : chaque boss sonne avec sa matière à lui, du premier élan au dernier coup : KUROEN SHIN comme un KUROEN plus lourd, ASURA comme le prévoit son entrée.
- **Gravité** : mineur. C'est du son, assez discret (même famille de fichiers, mais ni le même bus ni la même hauteur), et cela dure tout le combat des deux défis, le moment fort du jeu.
- **Statut** : `ouvert` (mécanisme prouvé ; l'écart s'entend en jeu, à juger par Wilhem). Code inchangé au 25/10 : la v0.36.10 ne touche ni `SoundPalette`, ni `SoundController`, ni `MoveData`.
- **27/10** : inchangé sur la v0.36.12. La ligne de `MoveKit` est maintenant `MoveData.luau:1463` (et non plus `:1459`). Dans SAMSARA, les sons de la scène (`sfx`) prennent bien la matière d'ASURA (`cin.kit`) ; le coup porté par la simulation sonne encore comme KAI. Choix noté par production le 26/10 (`DECISIONS.md`).
- **Piste** :
  - `SoundPalette.luau` : une entrée `["KUROEN SHIN"]` à lui, faite de **nouvelles tables**, par exemple celles de KUROEN un peu plus graves et dans `hall`, comme ASURA par rapport à KAI. Pas `MATERIALS["KUROEN SHIN"] = MATERIALS.KUROEN` : `SoundController.new` range chaque liste sous la clé `kit .. "." .. part` (`:45-49`). Une table partagée prendrait le nom du dernier kit parcouru, et un son de Wilhem nommé `KUROEN.hit` ne serait peut-être plus trouvé ;
  - le choix dans une fonction pure de `SoundPalette`, testable. Par exemple `Palette.materialOf(kit, moveKit, isBoss)` : le kit de l'attaquant s'il est un boss qui a sa matière, sinon le propriétaire du coup, sinon le kit. `SoundController` l'appelle en `:182`, `:186`, `:198` et `:237` (l'événement `Projectile` porte déjà `attacker`, `CombatSimulation.luau:1032`) ;
  - étendre les deux vérifications de `Kits.test` à tous les kits de `MoveData.Kits`, bosses compris, et vérifier qu'un coup d'ASURA et un coup de KUROEN SHIN choisissent leur propre matière ;
  - aucun ID nouveau : seulement les fichiers déjà livrés (`CLIENT_SOUNDS`) et les bus existants.

## B-034 · Le COUP FATAL de KUROEN porte le nom de la PORTE de DAICHA : « 蝕 · TOTAL ECLIPSE »
- **Date** : 24 octobre 2026.
- **Source** : relevé par le tri des idées du 24/10. Vérifié par la chasse.
- **Comment reproduire** :
  - ici : un script charge le vrai `MoveData`, puis compare les noms des ultimes (RUSH, ÉVEIL, PORTE, COUP FATAL), des finishers, des titres de PORTE et des passifs de tous les kits, sans le kanji ;
  - en jeu : un COUP FATAL de KUROEN (avant qu'il ait gagné une manche, donc le fatal classique), puis une PORTE de DAICHA. Les deux grands titres disent « 蝕 · TOTAL ECLIPSE ».
- **Ce qui se passe** (prouvé) :
  - `src/shared/MoveData.luau:785` : « 蝕 · TOTAL ECLIPSE » est le 29e nom de la liste de KUROEN, donc son rôle `Fatal` (`KuroenFatal`) ;
  - `MoveData.luau:617` : `DaichaGate = "蝕 · TOTAL ECLIPSE"`, et son titre de PORTE est `{ text = "蝕", sub = "TOTAL ECLIPSE" }` (`:1220`) ;
  - les deux cinématiques affichent ce nom : `FATAL.title` écrit « <nom> · FATAL BLOW », ou « K.O. » avec le nom (`src/shared/CinematicDirector.luau:2702-2710`). La PORTE de DAICHA écrit son titre. Le même nom est aussi dans la liste des coups du menu, et KUROEN SHIN l'emprunte (son thème l'affiche sous un autre nom, « 真 · ETERNAL ECLIPSE », `CinematicDirector.luau:4940`) ;
  - le kanji 蝕 est aussi celui de KUROEN lui-même (`MoveData.luau:1327`) ;
  - c'est le **seul** doublon entre deux persos jouables. Les autres noms communs sont voulus : la PORTE d'un kit et son propre titre de PORTE, ou les ultimes prêtés aux bosses (ASURA par KAI, KUROEN SHIN par KUROEN). Dans un même kit, il y a B-009 (ASTER) ;
  - la liste date du commit `40023d0` (04/10, KUROEN remplace MARION). Les documents ne disent pas d'où vient ce nom : il peut venir de Wilhem.
- **Pourquoi les tests ne le voient pas** : aucun test ne compare les noms des ultimes entre deux kits. Le test commun des finishers (`tests/Cinematography.test.luau`, B-009) ne regarde que les finishers.
- **Ce qui devrait se passer** : chaque ultime a un nom à lui. Le joueur qui voit « TOTAL ECLIPSE » sait de quelle scène il s'agit.
- **Gravité** : cosmétique.
- **Statut** : `ouvert` (confirmé ; `MoveData.luau` inchangé au 25/10). Le renommage demande un nom : production peut le proposer, Wilhem tranche, surtout si le nom vient de lui. Le nom à changer est plutôt celui de KUROEN : celui de DAICHA vient de sa planche (« 蝕 TOTAL ECLIPSE, porte », `docs/JOURNAL.md:2086`) et de son titre de PORTE.
- **Piste** :
  - un autre nom pour `KuroenFatal` : une ligne de `MoveData.luau:785`, et une ligne de `Locale.FR` à ajouter. Garder `["蝕 · TOTAL ECLIPSE"]` (`Locale.luau:1307`) pour DAICHA ;
  - sans ECLIPSE, EMPEROR ni ZERO, déjà dans une quinzaine de noms de sa famille (`DECISIONS.md`, 22/10, le nom de BLACK SUN) ;
  - un test dans `Kits.test` ou `Lobby.test` : aucun nom d'ultime ou de finisher (sans le kanji) n'est partagé entre deux kits jouables, les bosses et le titre de PORTE de son propre kit mis à part. Il échoue aujourd'hui sur ce doublon seul ; l'étendre au même kit attrape aussi B-009.

## B-035 · Pendant que le profil charge, le menu montre un profil vierge, et un CLASSÉ se lance avec lui
- **Date** : 25 octobre 2026.
- **Source** : trouvé par la chasse, en cherchant ce que la v0.36.10 change ailleurs dans le serveur (l'attente du verrou au chargement).
- **Comment reproduire** :
  - ici : un script hors dépôt charge les vrais `Profile` et `Matchmaker`. Le joueur a une sauvegarde à 1600, 40 victoires et 5 000 pièces. Pendant l'attente, il gagne un CLASSÉ contre un joueur à 1000 sur le profil par défaut, puis la sauvegarde arrive :

    | Moment | Cote | Victoires | Pièces | Ce que perd l'adversaire à 1000 |
    |---|---|---|---|---|
    | menu pendant l'attente | 1000 | 0 | 0 | |
    | fin du match, avant le chargement | 1016 | 1 | 40 | **−16** (contre sa vraie cote de 1600 : −1) |
    | après le chargement (`Profile.merge`) | 1600 | 40 | 5 000 | |

    Le match est effacé pour lui, et l'adversaire a perdu 16 points au lieu d'un ;
  - en jeu : un joueur dont le chargement attend. Par exemple, couper le réseau en plein jeu, puis rejoindre aussitôt un autre serveur. La ligne de console `profile <id> loaded … after N s` donne l'attente. Pendant ce temps, ouvrir le menu, puis lancer un CLASSÉ.
- **Ce qui se passe** (prouvé dans le code, et sur les modules rejoués) :
  - `loadProfile` pose le profil par défaut (`src/server/init.server.luau:152`). Il ne le remplace par la sauvegarde qu'à la fin de l'attente : `:160-164` pour une ancienne visite sur ce serveur, `:181-184` pour le verrou d'un autre serveur, puis la fusion en `:188` ;
  - `menuStatus` envoie ce profil par défaut (`:783` et suivantes) : cote 1000, 0 pièce, aucun perso acheté. Seuls les réglages, le guide et les achats Robux attendent le chargement (`:803`, `:812`, `:816`). Le menu n'a aucun état « sauvegarde en cours de chargement » ; seule la boutique le dit (`src/client/ShopPage.luau:220`) ;
  - l'action `start` (`:1586-1609`) n'attend pas le chargement. Un CLASSÉ part avec la cote par défaut (`:1605-1606`) et les seuls persos gratuits : `Economy.teamAllowed` lit le profil par défaut (`:1593`), et un perso acheté répond « FIGHTER LOCKED … (TRAINING ONLY) ». Les achats, eux, attendent le chargement (`:1446`, `:1461`, `:1474`, `:1526`, `:1551`) ;
  - si le chargement finit pendant le match, la cote comptée à la fin est la vraie (`endVersus` relit `ratingOf` en `:745`) : seul l'appariement s'est fait à 1000. Si le match finit avant le chargement, il est compté sur le profil par défaut. Puis `Profile.merge` (`src/server/Profile.luau:58-64`) remet chaque champ sauvegardé : c'est le tableau ci-dessus. Même chose pour une SURVIE ou un défi joués pendant l'attente ;
  - même cause pour `!give` (`:1701`) : `profileLoaded` est aussi vrai quand le chargement a **échoué** (`:218`, « SAVES UNAVAILABLE »). Le propriétaire lit « GIVEN TO … », et le joueur voit le cadeau. Mais rien n'est écrit, puisque `saveProfile` n'écrit qu'un profil chargé (`:307`) : le cadeau disparaît à la session suivante.
- **Ce que la v0.36.10 change** (déduit, non mesuré) :
  - avant elle, le verrou d'un joueur qui changeait de serveur était presque toujours périmé (B-025) : le nouveau serveur chargeait tout de suite ;
  - maintenant, il attend toujours l'écriture de départ de l'ancien serveur. Ce n'est rien si elle est déjà arrivée, et 3 s par essai sinon. C'est jusqu'à environ 73 s quand l'ancien serveur tarde à retirer le joueur (risque accepté, `DECISIONS.md` du 23/10), puis « SAVES UNAVAILABLE » ;
  - supposé : la plupart des changements de serveur durent plus longtemps que l'écriture de départ, et ne voient aucune attente. La fréquence réelle ne se mesure qu'en jeu publié.
- **Ce qui devrait se passer** : tant que la sauvegarde n'est pas là, le menu le dit, et rien de ce qui compte (CLASSÉ, modes qui paient, cadeaux du propriétaire) ne part du profil par défaut.
- **Gravité** : mineur. C'est très visible quand cela arrive (le joueur croit sa progression perdue, et ses persos achetés sont verrouillés), mais passager. La perte réelle, un match effacé et une cote faussée pour l'adversaire, demande en plus un match fini avant le chargement.
- **Statut** : `corrigé (v0.36.13)`, à confirmer sur le jeu publié. Validé le 27/10 du premier coup. Reste, non bloquant (validation) : le serveur réservé annule à 65 s alors qu'un chargement peut encore réussir jusqu'à environ 73 s (proposé : `PROFILE_WAIT` à 74 s, à valider) ; le menu refuse aussi la voie DÉFIER AMI pendant le chargement (affichage seulement, le hub reste ouvert par H) ; `crossPending[code]` reste en mémoire après une annulation. Ce qui change : `GameModes.needsSave`, `saveLoading`, `waitsForSave` (purs) ; la garde dans `start` (avant `Economy.teamAllowed`) et sur les deux joueurs d'un DÉFI accepté (`Lobby.accept`, nouveau paramètre `waiting` : le défi reste) ; `!give` sur `SaveQueue.isLoaded` (« NOT GIVEN · SAVES UNAVAILABLE » après un échec) ; un champ `loading` dans `menuStatus`, un `menuStatus` à la fin de chaque chargement (échec compris), le bandeau « LOADING YOUR SAVE… » sur le porte-monnaie ; le serveur réservé attend les deux profils jusqu'à `GlobalQueue.PROFILE_WAIT` (65 s), puis ne lance pas le match (`GlobalQueue.crossStart`). Décisions dans `DECISIONS.md` (27/10). Avant : `ouvert` (code inchangé au 27/10 ; ni la v0.36.11 ni la v0.36.12 ne touchent le chargement ou le menu).
- **26/10, les lignes après la v0.36.11** : `loadProfile` n'a pas bougé (`:152`, `:160-164`, `:181-184`, `:188`, `profileLoaded` en `:211` et `:218`). Plus loin : `menuStatus` en `:802` (`options` en `:822`, le guide en `:831`, les achats Robux en `:835`) ; `start` en `:1609-1633` (`Economy.teamAllowed` en `:1616`, la file avec la cote en `:1628-1629`) ; les achats attendent en `:1469`, `:1484`, `:1497`, `:1549` et `:1574` ; `endVersus` relit `ratingOf` en `:763` ; le DÉFI accepté en `:1382-1397` ; `!give` en `:1724`. `writeProfile` refuse un profil non chargé en `:255` (« unloaded »). « YOUR SAVE IS NOT LOADED YET » est en `Locale.luau:1600`.
- **Ce que la v0.36.11 y ajoute** (déduit du code, avec le banc de la validation) : celui qui quitte un CLASSÉ perd maintenant toute sa cote. S'il le quitte **avant** la fin de son chargement, cette perte tombe sur le profil par défaut, qui n'est jamais écrit (`PlayerRemoving` n'écrit qu'un profil chargé, `:1343`), puis la sauvegarde revient telle quelle à la session suivante : il ne perd rien. Même cas sur le serveur réservé du CLASSÉ entre serveurs, qui lance le match au bout de 20 s même si un profil n'est pas là (`:1176-1182`).
- **Piste** (précisée le 26/10) :
  - une règle pure, par exemple `GameModes.needsSave(mode)` : vraie pour VERSUS (CLASSÉ, NORMAL, AMI), 1 VS 1 · CPU, la SURVIE et les défis, fausse pour TRAINING ;
  - dans `start` (`:1609`), **avant** `Economy.teamAllowed` (`:1616`, sinon un perso acheté répond « FIGHTER LOCKED » d'abord) : `if store and GameModes.needsSave(request.mode) and not client.profileLoaded then` « YOUR SAVE IS NOT LOADED YET », et rien d'autre. **`client.profileLoaded`, pas `SaveQueue.isLoaded`** : `profileLoaded` devient vrai aussi quand le chargement a échoué (`:218`, « SAVES UNAVAILABLE »). Avec `isLoaded`, un joueur dont les sauvegardes sont indisponibles ne pourrait plus jouer qu'en TRAINING de toute la session ; aujourd'hui, il joue sans être sauvegardé, et il est prévenu ;
  - la même garde pour un DÉFI accepté (`:1382-1397`), sur les deux joueurs (pas de cote, mais des pièces, l'historique, et l'abandon de celui qui accepte) ;
  - `!give` (`:1724`) : `SaveQueue.isLoaded(saves, t.id, c)` au lieu de `c.profileLoaded`, avec la réponse « SAVES UNAVAILABLE » quand le chargement a échoué (là, le cadeau serait perdu) ;
  - le menu : un bandeau « LOADING YOUR SAVE… » tant que le statut n'a pas `options` **et** que le serveur a des sauvegardes (sans sauvegardes, dans Studio, `options` est toujours là, `:822`). C'est un nouveau texte, avec sa ligne dans `Locale.FR` ;
  - les tests : `needsSave` dans `Lobby.test` (seul TRAINING est permis), et le texte dans « languages ». Le fil de `start` vit dans `init.server.luau` : la validation peut le rejouer sur le banc du 25/10 (`unseat`, `endVersus` et le hub y sont déjà, au texte exact).
- **27/10, relu sur la v0.36.12** (elle ne touche pas le serveur) : toutes les lignes de la note du 26/10 tiennent, relues une à une (`:152`, `:160-164`, `:181-184`, `:188`, `:211`, `:218`, `:255`, `:802`, `:822`, `:831`, `:835`, `:1609`, `:1616`, `:1628-1629`, `:1469`, `:1484`, `:1497`, `:1549`, `:1574`, `:763`, `:1382-1397`, `:1724`). Seule différence : « YOUR SAVE IS NOT LOADED YET » est maintenant en `Locale.luau:1601`. La piste tient, avec trois précisions :
  - **le bandeau du menu ne peut pas se fier à l'absence d'`options`.** `options` manque tant que `SaveQueue.isLoaded` est faux (`:822`), donc aussi pendant **toute** une session dont le chargement a échoué (`profileLoaded` vrai, `isLoaded` faux, `:218`). Le bandeau « LOADING YOUR SAVE… » y resterait jusqu'au départ du joueur. Il vaut mieux un champ à lui dans `menuStatus` (`:802`), par exemple `loading = store ~= nil and not client.profileLoaded` ;
  - **un `menuStatus` à la fin de chaque chargement.** Il part déjà en fin de chargement réussi (`client.onProfileLoaded`, `:1312` et `:1317`). Après un échec, le serveur n'envoie que l'erreur « SAVES UNAVAILABLE » (`:221-224`), sans nouveau statut : le bandeau ne s'éteindrait jamais. Ajouter `menuStatus(player)` après cette erreur ;
  - **le serveur réservé du CLASSÉ entre serveurs** (`:1176-1182`) n'entre pas par `start` : la garde ne le couvre pas. Il attend les deux profils 20 s, puis lance quand même. Le plus simple : attendre jusqu'à `GlobalQueue.LOCK_TTL + 5` (65 s, l'attente la plus longue d'un chargement) au lieu de 20, puis, si un profil manque encore, ne pas lancer le match (les deux joueurs retournent au menu). À trancher par production ; c'est aussi le terrain de B-039.

## B-036 · Une écriture partie juste avant l'achat d'un pack de pièces peut garder le reçu sans les pièces
- **Date** : 25 octobre 2026.
- **Source** : trouvé par la chasse, en relisant les achats après la v0.36.10 (les renouvellements multiplient les écritures en vol).
- **Comment reproduire** :
  - ici : un script hors dépôt charge les vrais `Store` et `GlobalQueue`, et suit l'ordre des étapes du serveur :
    1. un renouvellement copie le profil (`table.clone`), sa requête attend son tour ;
    2. `ProcessReceipt` donne un pack de 1 000 pièces au profil vivant ;
    3. la transformation du renouvellement s'exécute.

    Résultat : la sauvegarde a **100 pièces et le reçu `PID-1`**. Si l'écriture de `ProcessReceipt` échoue et qu'aucune écriture suivante ne réussit, Roblox renvoie le reçu au serveur suivant. `Store.grantReceipt` y répond `"duplicate"`, le serveur rend `PurchaseGranted`, et les 1 000 pièces ne sont jamais données ;
  - en jeu : cela ne se provoque pas. Il faut une panne du DataStore, ou un serveur planté, juste après l'achat.
- **Ce qui se passe** :
  - prouvé : `writeProfile` copie le profil avec `table.clone` (`src/server/init.server.luau:257`), une copie **superficielle**. Les tables du profil (`receipts`, `history`, `ratings`, `ownedItems`…) restent partagées avec le profil vivant jusqu'à ce que la transformation d'`UpdateAsync` s'exécute, plus tard. `GlobalQueue.stamp` (`src/server/GlobalQueue.luau:109-113`) ne recopie que le premier niveau, lui aussi ;
  - prouvé : `Store.grantReceipt` (`src/shared/Store.luau:89-112`) ajoute les pièces au premier niveau (`profile.coins`, `:96`) et le reçu dans une table imbriquée (`profile.receipts`, `:103`). Une écriture partie avant l'achat emporte donc le reçu, mais pas les pièces ;
  - prouvé : un reçu déjà présent rend `"duplicate"` (`:94`), et `ProcessReceipt` répond alors `PurchaseGranted` (`init.server.luau:1258-1270`) ;
  - en temps normal, rien n'est perdu. Les requêtes d'une même clé passent dans l'ordre (supposé), et l'écriture de `ProcessReceipt`, ou le vidage suivant, écrit les pièces. La perte demande que **toutes** les écritures suivantes de la session échouent : une panne qui dure, ou un serveur planté ;
  - ce que la v0.36.10 change : avant elle, un joueur qui ne faisait rien n'avait aucune écriture en vol. Maintenant, chaque joueur présent en a une toutes les 20 à 35 s, et un joueur qui regarde la boutique est souvent dans ce cas ;
  - le même partage touche d'autres paires (un objet acheté avec des pièces, l'historique et la cote d'un match), mais dans l'autre sens ou sans perte : un objet gardé sans que les pièces soient retirées, un historique en avance sur la cote.
- **Ce qui devrait se passer** : une écriture contient le profil tel qu'il était à son départ, tout entier.
- **Gravité** : mineur. C'est très rare, mais ce sont des Robux payés et jamais rendus.
- **Statut** : `ouvert` (mécanisme prouvé sur les modules ; la fenêtre réelle, qui demande une panne au mauvais moment, n'est pas mesurable d'ici). **26/10** : code inchangé sur la v0.36.11. `table.clone` est toujours en `init.server.luau:257` ; `ProcessReceipt` est maintenant en `:1266-1290` (un reçu `"duplicate"` est réécrit, puis `PurchaseGranted` en `:1289`).
- **Piste** :
  - le plus simple : une copie profonde dans `writeProfile` (`:257`), par exemple une fonction pure `Profile.copy`. Une écriture ne voit alors jamais un changement fait après son départ. Le profil reste petit (10 lignes d'historique, 200 reçus au plus, `Store.KEEP_RECEIPTS`) ;
  - ou, plus étroit : dans `Store.grantReceipt`, remplacer `profile.receipts` par une copie avant d'y ajouter le reçu (`profile.receipts = table.clone(profile.receipts)`). Cela ne couvre que les reçus ;
  - un test dans `Lobby.test` : une copie faite avant `grantReceipt` ne contient pas le reçu. Il échoue aujourd'hui.

## B-037 · La touche P quitte un combat d'un seul appui : depuis la v0.36.11, une fausse touche coûte toute la cote d'un CLASSÉ
- **Date** : 26 octobre 2026.
- **Source** : trouvé par la chasse, en cherchant ce que la v0.36.11 change pour les départs volontaires.
- **Comment reproduire** :
  - ici : le banc de la validation du 25/10, au texte exact du serveur (`unseat`, `endVersus`), copié dans le bloc-notes de la chasse. Scène H3 : A (1500) quitte un CLASSÉ contre B (1200) au bout de 2 s par l'action `leave` du menu, celle qu'envoie P. Résultat : A passe à **1473**, une défaite comptée, sa série à 0 ; B ne gagne rien. Sur la v0.36.10, ce départ ne coûtait rien avant 25 s ;
  - en jeu : un CLASSÉ, puis P dès les premières secondes du combat. La carte de défaite arrive aussitôt, avec la perte de points (−27 pour un joueur à 1500 face à un joueur à 1200).
- **Ce qui se passe** :
  - prouvé dans le code : P envoie tout de suite `{ action = "leave" }`, dans n'importe quel match, sans maintien ni confirmation (`src/client/init.client.luau:125-128`, puis `MenuController:leave`, `src/client/MenuController.luau:2994-2996`). Le serveur fait `unseat` (`src/server/init.server.luau:1638-1642`), donc un abandon : en CLASSÉ, la perte entière à tout moment (`AntiCheat.versusShares`, part 1) ;
  - la manette, elle, demande de **maintenir L3 une seconde**, avec une jauge, et le code dit pourquoi : « no leaving a RANKED match by accident » (`init.client.luau:129-148`). Le clavier n'a pas cette garde ;
  - P est collé aux touches de combat de la main droite : `InputConfig.luau:18-22` donne J (coup), K et L (lourd), U (spéciale), I (garde), O (ultime). Sur QWERTY comme sur AZERTY, P est juste à droite de O, l'ultime, et au-dessus de L. L'aide en combat l'annonce : « P: menu » (`HUDController.luau:637`) ;
  - le bouton ◀ MENU du HUD n'a pas ce défaut : il est dans la colonne des outils, fermée par défaut (deux clics, `HUDController.luau:507-515`).
- **Ce qui devrait se passer** : comme à la manette, on ne quitte pas un CLASSÉ par accident.
- **Cause** : `src/client/init.client.luau:126-128`. Le défaut date de la v0.14.0 (P), et la garde de la manette de la v0.19.0. La v0.36.11 l'aggrave : avant, une fausse touche ne coûtait aucun point pendant les 25 premières secondes (seulement la série).
- **Gravité** : mineur. La perte est réelle (la cote, la fiche V/D, la série), mais il faut jouer avec les touches de la main droite, que l'aide ne montre pas (sauf J + K pour la chope), et toucher P au lieu de O ou de L.
- **Statut** : `ouvert` (mécanisme prouvé sur le banc ; le client ne se teste pas hors ligne).
- **Piste** :
  - P comme L3 : maintenir une seconde pour quitter, avec la même jauge (`hud:setLeaveProgress`, `HUDController.luau:807`). Le plus simple : le même fil que L3 (`init.client.luau:132-148`), avec P en plus de `ButtonL3` ;
  - la jauge écrit « HOLD L3 TO LEAVE » en dur (`HUDController.luau:815`) : un texte selon la touche (« HOLD P TO LEAVE »), avec sa ligne dans `Locale.FR`. L'aide « P: menu » devient « HOLD P: menu » (et sa ligne `Locale.luau:86`) ;
  - le garder partout (entraînement compris), comme L3 : une seule règle à apprendre ;
  - rien côté serveur. Production peut trancher : la règle existe déjà à la manette.

## B-038 · Pendant un CLASSÉ, n'importe quel joueur peut afficher un défi par-dessus le combat, et son ACCEPT coûte toute la cote ; la REVANCHE passe encore depuis un CLASSÉ
- **Date** : 26 octobre 2026.
- **Source** : trouvé par la chasse, en cherchant les effets de bord de la v0.36.11 (les défis). La partie REVANCHE vient de la validation du 25/10 (notée jusqu'ici dans B-023).
- **Comment reproduire** :
  - ici : le banc de la validation du 25/10, au texte exact de `seat`, `startVersus`, du gestionnaire du hub et de la REVANCHE, copié dans le bloc-notes de la chasse. Scène H1 : D avait défié A ; A entre dans un CLASSÉ contre B ; D le redéfie 2 s plus tard ; A accepte à 3 s :

    | A accepte à | Le défi d'avant | Le nouveau défi de D | Le hub de A | A (1500) | B (1200) |
    |---|---|---|---|---|---|
    | 3 s | retiré par `seat` | **envoyé** | 1 défi reçu | **1473**, une défaite | 1200 |
    | 60 s | retiré | envoyé | 1 défi reçu | 1473, une défaite | 1227, une victoire |

    Sur la v0.36.10, l'acceptation à 3 s ne coûtait rien. La scène S16 de la validation donne la même chose. La scène S15 (REVANCHE envoyée depuis un CLASSÉ, paquet forgé) : le défi part, puis l'ACCEPT est retiré sans un mot ;
  - en jeu : deux comptes en CLASSÉ, un troisième dans le menu qui clique CHALLENGE sur l'un d'eux (sa ligne dit « IN A FIGHT »). Le bandeau « … CHALLENGES YOU TO A 1 VS 1! » s'affiche en plein combat.
- **Ce qui se passe** :
  - prouvé sur le banc : `Lobby.challenge` ne regarde que l'état de **celui qui envoie** (`fromBusy`, `src/server/Lobby.luau:92-99`). La place de la cible n'est jamais vue : `lobby.slots` est toujours vide (`init.server.luau:1327`, `:1359`, `:1388`). `seat` retire bien les défis reçus **avant** le match (`:585`), mais un nouveau arrive aussitôt après ;
  - prouvé dans le code client : le bandeau s'affiche dès qu'un défi est reçu, sans regarder le match (`src/client/HubController.luau:323-338`). `setInMatch` ne cache que la fenêtre du hub (`:224-228`). Le hub est un `ScreenGui` d'ordre 30 (`:57`), au-dessus du HUD (5), des commandes tactiles (10) et des cinématiques (20) : le bandeau, jusqu'à 420 × 132 px à 150 px du haut (`:124-127`), passe par-dessus le combat et les ultimes. Son ACCEPT (`:140-142`) fait sortir celui qui accepte de son match (`init.server.luau:1391-1395`) : c'est son abandon, donc en CLASSÉ toute sa cote à tout moment depuis la v0.36.11 ;
  - la liste du hub propose CHALLENGE sur la ligne de chaque autre joueur, « IN A FIGHT » compris (`HubController.luau:297-310`). DECLINE cache le bandeau, mais l'autre peut redéfier aussitôt (une action du hub toutes les 0,4 s, `init.server.luau:1372`) : le bandeau revient tant qu'il insiste ;
  - la REVANCHE (`init.server.luau:1510`) appelle `Lobby.challenge` sans `fromBusy` : un paquet forgé depuis un CLASSÉ envoie encore un défi, dont l'ACCEPT est retiré en silence. Le résumé de l'API en tête de `Lobby.luau:24-25` ne cite pas `fromBusy` ;
  - **ce qui est voulu** : « celui qui accepte en plein CLASSÉ quitte son propre match : c'est son abandon » est une décision de production (`DECISIONS.md`, 25/10, le défi accepté), testée exprès (`tests/Lobby.test.luau:1383-1393`, cas 5 : « D could not challenge a player in a match »). Le défaut n'est pas cette règle, c'est ce qu'elle laisse faire : un autre joueur pose sur l'écran d'un joueur en CLASSÉ un bouton qui lui fait perdre son match en un clic, et le reposer à volonté. La même décision retire les défis reçus à l'entrée dans le match pour éviter « un bouton ACCEPT qui ne mène à rien » : ceux qui arrivent pendant le match passent à côté.
- **Ce qui devrait se passer** : pendant un 1v1 entre joueurs, aucun bandeau de défi par-dessus le combat ; un défi ne fait quitter un CLASSÉ que si le joueur le veut vraiment.
- **Gravité** : mineur. Visible et gênant quand cela arrive (le bandeau couvre le haut de l'arène, ultimes compris), et un clic sur ACCEPT coûte un CLASSÉ, mais il faut qu'un autre joueur du serveur défie un joueur en plein combat. Ce peut être un ami sans mauvaise intention (le bandeau dit bien « the fight starts as soon as you accept »), ou quelqu'un qui harcèle.
- **Statut** : `ouvert` (prouvé sur le banc pour le serveur ; l'affichage est déduit du code client, à voir en jeu). Le choix entre les deux pistes ci-dessous revient à production, la seconde revoit son cas 5.
- **Piste** :
  1. **client, sans toucher à la règle** : dans `HubController:render` (`:323-338`), ne pas montrer le bandeau quand le joueur local est dans un 1v1 entre joueurs. Le serveur le dit déjà : `where == "IN A FIGHT"` sur sa propre ligne (`hubStatus`, `init.server.luau:906`). Le défi reste dans la liste du hub, avec son bouton ACCEPT, pour qui l'ouvre exprès (H) ;
  2. **serveur, plus fort** : `Lobby.challenge(lobby, from, to, now, fromBusy, toBusy)` refuse aussi quand la cible est dans un 1v1 entre joueurs ; le hub passe `inVersus(Players:GetPlayerByUserId(target))` (`:1381`). Le cas 5 de `Lobby.test` s'écrit alors : D ne peut pas défier C pendant le CLASSÉ de C ; C peut toujours quitter, puis accepter. Côté client, la ligne d'un joueur « IN A FIGHT » montre un CHALLENGE grisé ;
  3. **la REVANCHE**, dans les deux cas : `Lobby.challenge(lobby, player.UserId, target.UserId, now, inVersus(player))` (`:1510`), et `inVersus(target)` en plus avec la piste 2. Un test : une REVANCHE envoyée depuis un CLASSÉ ne part pas ;
  4. compléter le résumé de l'API (`Lobby.luau:24-25`).
- **À côté** (cosmétique) : le commentaire dit que le bandeau montre « le plus récent » des défis reçus (`HubController.luau:323`), mais il montre celui de l'id le plus grand : `Lobby.status` trie les défis reçus par id (`Lobby.luau:158`).

## B-039 · Serveur réservé du CLASSÉ entre serveurs : le premier arrivé peut lancer un autre mode en attendant, et il est alors assis dans deux matchs
- **Date** : 26 octobre 2026.
- **Source** : trouvé par la chasse, en relisant `GlobalQueue` et le serveur réservé après la v0.36.11.
- **Comment reproduire** :
  - ici : le même banc (texte exact de `seat`, `startVersus`, `unseat` et `endVersus`). Scène H4 : A est assis dans un match contre le CPU (`newMatch` puis `seat`, comme `startSolo`) et a relancé une recherche CLASSÉ (`client.queue = "RANKED"`). Puis le serveur réservé lance le CLASSÉ, `startVersus(A, B, "RANKED")`. Résultat : le match contre le CPU a **toujours A pour propriétaire**, après `startVersus`, après la fin du CLASSÉ et après le `unseat` de A ; il reste dans `matches`. Et la file de A reste « RANKED » pendant tout le CLASSÉ, et après ;
  - en jeu : un CLASSÉ entre serveurs (deux comptes sur deux serveurs, plus de 6 s de recherche). Sur le serveur réservé, le premier arrivé voit le menu normal : y lancer TRAINING ou 1 VS 1 · CPU, ou relancer RANKED, avant l'arrivée de l'autre.
- **Ce qui se passe** :
  - prouvé dans le code : le premier arrivé attend l'autre jusqu'à 40 s (`GlobalQueue.ARRIVE_TIMEOUT`, `src/server/GlobalQueue.luau:24`), puis les deux profils jusqu'à 20 s (`init.server.luau:1176-1181`). Pendant ce temps, son menu est le menu normal (« menu », `menuStatus`) : rien ne dit qu'un match arrive, et tous les modes sont permis ;
  - prouvé sur le banc : `startVersus` (`:679-696`) assoit les deux joueurs sans `unseat`, sans `Matchmaker.leave` et sans vider `client.queue`. Les deux autres appelants s'en chargent : le DÉFI accepté sort les deux joueurs de leur match et de leur file (`:1391-1395`) ; la recherche vide la file (`:1654`), et ses joueurs ne sont dans aucun match (`start` les en a sortis, `:1621-1623`). Le serveur réservé ne fait ni l'un ni l'autre (`:1182`) ;
  - déduit du code, ce qui suit :
    - le match d'avant n'est jamais fermé : il garde A comme propriétaire et tourne à chaque image jusqu'à la fin du serveur. Ses événements partent vers A (`recipients`, `:1916-1922`). Le client trie les instantanés par match (`init.client.luau:281`), pas les événements (`:326-345`) : sons, effets et jingles du combat contre le CPU tombent sur les corps du CLASSÉ. Sa fin écrit une ligne d'historique contre le CPU et des quêtes dans le profil de A ;
    - si A avait relancé RANKED, `crossStep` le publie dans la file mondiale **pendant** son CLASSÉ : la publication ne regarde pas `client.match` (`:1090`). Si un autre serveur le prend, `teleportToMatch` (`:1069-1081`) le téléporte en plein match : c'est un départ, donc toute sa cote depuis la v0.36.11. Cette partie ne se rejoue pas d'ici (MemoryStore, téléportation).
- **Ce qui devrait se passer** : entrer dans le CLASSÉ du serveur réservé sort le joueur de tout autre match et de toute file, comme partout ailleurs.
- **Cause** : `src/server/init.server.luau:1182` (et `startVersus`, `:679-696`, qui ne le fait pas lui-même).
- **Gravité** : mineur. Il faut se servir du menu pendant les quelques secondes d'attente du serveur réservé, mais le menu ne montre rien d'autre : un joueur qui croit la recherche perdue relance RANKED. Le pire cas (téléporté en plein CLASSÉ, cote perdue) demande en plus qu'un autre serveur le prenne.
- **Statut** : `ouvert` (la double place est prouvée sur le banc ; la téléportation en plein match est déduite du code). **27/10, v0.36.13** : la fenêtre s'allonge, l'attente des profils passant de 20 à 65 s au plus ; celui qui charge n'a que TRAINING, donc il y est poussé (scène Y1 du banc de la validation du 27/10). À traiter bientôt.
- **Piste** :
  - dans `startVersus` (`:679`), avant les deux `seat`, pour chaque joueur : `Matchmaker.leave(matchmaker, p.UserId)`, `clients[p].queue = nil`, `unseat(p)`. C'est ce que font déjà le DÉFI accepté et la recherche : les trois appelants passent alors par le même chemin. Attention : `unseat` d'un joueur en 1v1 entre joueurs est un abandon. Sur le serveur réservé, il ne peut pas en jouer un autre (les deux seuls joueurs sont ceux du match) ;
  - dans `crossStep` (`:1090`), ne publier que `not client.match` ;
  - le menu du serveur réservé pourrait dire « OPPONENT FOUND · CONNECTING… » (nouveau texte, `Locale.FR`) : à voir avec B-035, qui y montre aussi un profil vierge pendant le chargement ;
  - un test : le fil vit dans `init.server.luau` ; la validation peut le rejouer sur le banc du 25/10 (scène H4).

## B-040 · La cible se retourne d'un coup au sol (face contre terre en une image) : 16 FATAL FINISHERS, la scène K.O. de fin de match des 22 persos, et chaque ÉVEIL ou PORTE qui tue
- **Date** : 26 octobre 2026 (validation). Confirmé et étendu par la chasse du 27 octobre.
- **Source** : relevé par la validation de SAMSARA (ASURA, v0.36.12), avec le script `/tmp/claude-0/-home-user-fighting-game/9500fc37-bfe5-5fc8-8b48-019f0348026a/scratchpad/qa/scripts/tgtpop.luau`. Repris par la chasse le 27/10 (scripts `b040.luau`, `ultpop.luau`, `kopop.luau` et `camjump.luau` dans `/tmp/claude-0/-home-user-fighting-game/9500fc37-bfe5-5fc8-8b48-019f0348026a/scratchpad/hunt27/`, sur une copie de `src` et `tests`).
- **Comment reproduire** :
  - ici, les finishers : `Kit.play(kit, "Fatal", nil, 300, 0, …)` (`tests/CinematicKit.luau`). On suit la tête de la cible et on relève chaque saut de plus de 2 studs d'une image à l'autre dans un même plan, après le coup mortel (le critère de la validation). Mêmes résultats depuis la droite et dos au mur (`mirror`, `wall`), au centième de stud près ;
  - ici, le reste : `Kit.playKO(kit, 1 ou 2, …)` (la scène K.O. de fin de match), et `Kit.play(kit, "Rush" | "Awaken" | "Gate" | "Fatal", nil, 300, …)` sans finisher (copie du module où `world.labFinisher` est forcé à faux) ;
  - à l'œil : `luau tests/Storyboard.luau -a ASURA Fatal - 1 1`, puis `python3 tools/storyboard.py`, images t463 à t471 ;
  - en jeu : n'importe quel match gagné par K.O. Le premier plan de la scène K.O. (noir et blanc, le corps qui tombe) se termine, à 0,37 s, par ce retournement.
- **Ce qui se passe** (prouvé sur le labo : rig KAI, animateur réel) :
  - **les finishers** (critère de la validation) : **19 sur 21**, et non 18. Il y a **16 vraies bascules face contre terre** (plus de 4 studs, vers `DownFace`) :

    | Finisher | Tick | Plan | Saut de la tête | Poses | À l'écran |
    |---|---|---|---|---|---|
    | AKEMI | t492 | `akemi-ts-neck` | 4,73 | `Launched` → `DownFace` | oui |
    | ASTER | t500 | `aster-sc-crash` | 4,76 | idem | oui, sous le titre K.O. |
    | ASURA | t464 puis t470 | `asura-ss-blown` | 3,06 puis 4,56 | `Launched` → `DownImpact` → `DownFace` | oui |
    | DAICHA | t520 | `daicha-iw-after` | 4,76 | `Launched` → `DownFace` | oui, sous le titre K.O. |
    | ELIAN | t560 | `elian-fm-after` | 4,76 | idem | oui, sous le titre K.O. |
    | HIBIKI | t482 | `hibiki-rs-after` | 4,80 | idem | non : la tête est hors du cadre |
    | KAI | t525 | `kai-mx-blast` | 4,82 | idem | oui |
    | KAZAN | t470 | `kazan-cc-x` | 4,76 | idem | oui |
    | KUREN | t500 | `kuren-cv-after` | 4,76 | idem | oui, sous le titre K.O. |
    | RAIJIN | t514 | `raijin-st-bolt` | 4,87 | idem | oui |
    | RYUKEN | t520 | `ryuken-tf-wall` | 4,85 | idem | oui |
    | SHIN | t560 | `shin-fd-ko` | 4,75 | idem | oui, sous la carte K.O. (la scène reste visible dessous depuis B-001) |
    | SYLVA | t486 | `sylva-gh-through` | 4,76 | idem | oui |
    | TARO | t552 | `taro-dr-crash` | 5,47 | idem | oui |
    | VENOM | t474 | `venom-tf-burst` | 4,76 | idem | oui |
    | YUKINA | t488 | `yukina-fr-shatter` | 4,76 | idem | oui |

    - les 3 autres qui passent le critère sont d'une autre nature : GORAN t496 (`goran-tq-slam`, 3,18, un rebond `DownImpact` → `Launched`), HIBECARES t478 (`hibecares-tr-crater`, 5,04 : debout, `HitHigh`, à couché sur le dos, `DownImpact`, d'un coup) puis t500 (3,20, rebond), KUROEN t446 (`kuroen-bs-blow`, 2,07, `Crumple` → `DownFace`). Aussi SHIN t540 et SYLVA t466 (2,4 : `HitBody` → `Launched`) ;
    - propres : NOVA et ZEPHYR ;
  - **la caméra suit le saut** quand le plan cadre le corps de la cible : dans SAMSARA, `asura-ss-blown` (`subjects = "d"`, `frameOn`) saute de **7,0 studs** à t464 et à t470, parce que la boîte du corps change d'un coup. Même chose pour KUREN t480 (`kuren-cv-pierce`, 7,6 studs, `HitHigh` → `Launched`), SYLVA (`sylva-gh-stalk`, 2,5 à 3,4 studs à t230, t238, t270, t278, t310 et t318, quand la cible passe de `Launched` à `HitBody` et retour) et RAIJIN (`raijin-st-lit`, 5,6 studs toutes les 3 images de t453 à t471). Chez RAIJIN, le clignotement de la cible foudroyée est voulu (`HitHigh` et `Launched` en alternance, `Finishers.luau:1638`) ; la caméra qui saute avec lui, sans doute pas ;
  - **le même saut ailleurs, bien plus souvent** :
    - **la scène K.O. de fin de match** (`Director.ko`) : les **22 persos**, et les deux scènes de ceux qui en ont deux. À t22 (t24 pour KAI et ZEPHYR), au premier plan `ko-…-fall`, 4,8 à 5,1 studs. C'est la scène de presque chaque match gagné par K.O. ;
    - **un ÉVEIL ou une PORTE qui tue** : 22 sur 22 et 22 sur 22. Ils enchaînent sur la même chute (`ko-…-fall`, à t242 ou t232) ;
    - **un COUP FATAL classique qui tue** (sans finisher) : 11 sur 22 (`FATAL.fall`), par exemple `shin-issen-fall` t226 ou `kai-ciel-back` t170. Quand il ne tue pas, les mêmes 11 passent de `Launched` à `Kneel` en une image (2,4 studs) ;
    - **un RUSH qui tue** : 4 sur 22 (KAI `rush-meteor` t102, 5,85 ; ASTER t146 ; RYUKEN t103 ; YUKINA t139) ;
    - à part, des sauts de 7 à 11 studs, répétés toutes les 7 à 8 images, dans des scènes qui écrasent la cible au sol coup après coup : le RUSH de GORAN (`goran-rush-blows-a`, `-b`, `-c`), l'ÉVEIL de HIBECARES (`hibecares-chatiment-punish`) et celui de KAZAN (`kazan-eveil-blows-a`, `-b`). C'est peut-être voulu (des images d'impact) : à juger avec le reste.
- **Ce qui devrait se passer** : la cible tombe, roule ou se retourne en quelques images, ou le changement tombe sur une coupe de plan ; la caméra ne saute pas au milieu d'un plan.
- **Cause** (prouvée) :
  - `src/shared/Animator.luau:494` et `:496` : une pose de scène donne la clé `"Pose:" .. nom`. Toutes les poses de scène sont donc dans la même famille, `Pose` ;
  - `Animator.luau:830` : `instant = snap or family == last`. D'une pose de scène à une autre, l'animateur ne fond jamais : il coupe. `Launched` (`src/shared/PoseLibrary.luau:197`, le bassin penché en arrière de 40°) ou `DownImpact` (`:208`, sur le dos, 84°) devient `DownFace` (`:219`, face contre terre, −90°) d'une image à l'autre : 130 à 174° de rotation d'un coup ;
  - les scènes qui le font :
    - `FATAL.fall` (`src/shared/CinematicDirector.luau:2690-2699`), appelé 19 fois dans `Finishers.luau` et par les COUPS FATAUX du directeur ;
    - les chutes des scènes K.O. : `CinematicDirector.luau:3233`, `:3283`, `:3334`, `:3392`, `:3437`, `:3488`, `:3536`, `:4784`, `:5022` (`if t < 22 then "Launched" else "DownFace"`), et celle du RUSH de KAI (`:317`) ;
    - `GEN.lie` (`:4183-4191`), pour les ultimes générés ;
    - SAMSARA : `src/shared/Finishers.luau:3329-3335` ;
  - le combat n'a pas ce défaut : un corps qui tombe y est déjà penché sur le dos (`Launched` puis `LaunchedFall`, 40 à 72°), la coupe vers `DownImpact` (84°) est donc petite, puis il se fond vers `Down` (sur le dos) par étapes (`Animator.luau:599-606`).
- **Ce qui ne se mesure pas d'ici** : à 60 images par seconde, le saut dure une image. En jeu, il peut se lire comme un choc voulu, ou comme un corps qui « clignote ». Le client place les corps et les anime avec le même animateur (`src/client/init.client.luau:585-600`, `AnimationController:update`) : rien ne lisse le saut.
- **Gravité** : **mineur** (relevée depuis « cosmétique »). C'est visuel et ça ne dure qu'une image, mais c'est dans presque chaque match (la scène K.O. de fin), dans un plan qui ne montre que ce corps qui tombe. Ce n'est pas une régression de la v0.36.12.
- **Statut** : `ouvert` (confirmé le 27/10).
- **Piste** (le choix revient à production) :
  1. **une règle dans l'animateur**, la plus large : quand une pose de scène passe à une pose couchée (`DownFace`, `DownImpact`, `Down`, `Kneel`) depuis une pose en l'air ou frappée (`Launched`, `HitHigh`, `HitBody`, `Crumple`…), fondre en 0,1 à 0,15 s au lieu de couper (`Animator.luau:830` : une famille à part pour ces poses, avec son `BLEND_TIMES`). Attention : un fondu linéaire du bassin de +40° à −90° fait pivoter le corps vers l'avant en passant par la verticale. À juger avec `luau tests/AnimClip.luau` et le storyboard ; une pose intermédiaire « sur le côté » rendrait le retournement plus lisible ;
  2. **ou, scène par scène** : faire basculer le corps vers l'avant pendant la chute (une pose `FallFace` : penché en avant, les mains tendues), pour que l'arrivée en `DownFace` ne tourne plus que d'environ 30°. Sans la règle 1, la coupe a seulement lieu en l'air ;
  3. **ou, un choix de mise en scène** (production, ou Wilhem s'il tient au « face contre terre ») : tomber sur le dos comme en combat (`DownImpact`, puis `Down`), et garder `DownFace` pour les scènes qui jettent la cible vers l'avant ;
  4. **dans tous les cas, un test** dans `Cinematography` : dans un même plan, la tête de la cible ne saute jamais de plus de 2 studs d'une image à l'autre, et la caméra jamais de plus de 1,5 stud. À faire sur les 21 finishers, les ultimes qui tuent et les 22 scènes K.O., avec les exceptions nommées (`vanish` de DAICHA, cible cachée).

## B-041 · TOXIC FEAST (VENOM) : après chacune de ses trois frappes, VENOM saute de 6 à 9 studs en une image, dans le même plan, et la caméra avec lui
- **Date** : 27 octobre 2026.
- **Source** : trouvé par la chasse, en relevant les sauts de caméra à l'intérieur d'un plan sur les 21 FATAL FINISHERS (`camjump.luau`, dans `/tmp/claude-0/-home-user-fighting-game/9500fc37-bfe5-5fc8-8b48-019f0348026a/scratchpad/hunt27/`).
- **Comment reproduire** :
  - ici : `Kit.play("VENOM", "Fatal", nil, 300, 0, …)`, en suivant la place de VENOM (`views[A].x`, `.z`), la caméra (`info.cam`) et le cadre (`Kit.projector`, `Kit.bodyBounds`) autour des ticks 164, 214 et 264. Ou `luau tests/Storyboard.luau -a VENOM Fatal - 1 1`, images t163 et t164 ;
  - en jeu : gagner une manche avec VENOM, puis tuer au COUP FATAL. Regarder la fin de chacune des trois frappes qui sortent de la brume (de 2,7 s à 4,4 s).
- **Ce qui se passe** (prouvé sur le labo, même chose depuis la droite, en miroir) :

  | Frappe | Tick | Plan | VENOM (x ; z), avant → après | Saut | Caméra | À l'écran |
  |---|---|---|---|---|---|---|
  | 1 | t164 | `venom-tf-strike1` | (0,29 ; −2,61) → (7,21 ; −4,02) | 7,1 studs | 5,2 studs | oui, avant et après |
  | 2 | t214 | `venom-tf-strike2` | (4,10 ; −0,12) → (5,77 ; −5,77) | 5,9 studs | 1,6 stud | oui |
  | 3 | t264 | `venom-tf-strike3` | (0,51 ; 2,68) → (−2,92 ; −5,99) | 9,3 studs | 3,0 studs | oui |

  - le plan de la frappe est gardé 12 images de plus (« the strike's shot holds while he goes »), mais il est composé sur les deux corps (`frameOn` sur `{ a, d }`). Il se recompose donc aussitôt sur la nouvelle place de VENOM : la caméra saute avec lui ;
  - rien ne le cache : il n'est pas masqué (`hidden`), et les bouffées de brume (`smoke`) sont posées au hasard autour de la cible, pas sur lui. Le client place les corps sans lissage (`src/client/init.client.luau:585-600`).
- **Ce qui devrait se passer** : comme le dit le commentaire, il « se fond dans la brume » : il glisse vers l'arrière, ou disparaît, pendant que le plan tient.
- **Cause** (prouvée) : `src/shared/Finishers.luau:1843-1844`. La frappe dure jusqu'à `s + 14`, puis vient `after`. À `s + 14`, VENOM quitte sa place de frappe (`circle(a, cx, dir, s_[3], 2.8, 0)`, `:1851`) pour sa ronde autour de la proie (l'ellipse, `:1875`), d'une image à l'autre. Le plan gardé (`:1888-1891`) est recomposé sur lui.
- **Gravité** : cosmétique. Trois sauts d'une image, dans des plans courts, au milieu de la brume.
- **Statut** : `ouvert`.
- **Piste** :
  - pendant `after` (12 images), faire glisser VENOM de sa place de frappe jusqu'à l'ellipse (un `lerp` sur `smooth(progress(tick, s + 14, s + 26))`), ou le masquer (`a.hidden = true`, comme SHIN entre ses coupes) ;
  - composer le plan gardé sur des points fixes (la cible, la place de la frappe), pas sur son corps ;
  - le test de B-040 (caméra jamais plus de 1,5 stud d'une image à l'autre dans un plan) l'attraperait.
- **À côté** (mêmes mesures, sans fiche à part pour l'instant ; à juger par production) :
  - ZEPHYR, `zephyr-ge-sway` : le même nom de plan change d'angle à chaque coup esquivé (`yaws[k]`, `Finishers.luau:743-744`). La caméra saute de 6 à 14° et de 1,8 à 4 studs à t76, t122, t144 et t168. Cela se lit comme une petite coupe dans le même axe ; c'est peut-être voulu ;
  - TARO, `taro-dr-eyes` : 13 à 17° à chaque coup, en vue subjective. C'est le coup de tête de la vue subjective, voulu.
