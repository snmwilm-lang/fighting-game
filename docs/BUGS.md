# Bugs — la liste

Tenue par l'agent `bugs` (`.claude/agents/bugs.md`). Une entrée par bug, numérotée `B-###`.

Gravité :
- **bloquant** : la partie casse ;
- **majeur** : faux en combat, ou très visible ;
- **mineur** : visuel ou son ponctuel ;
- **cosmétique**.

Statuts : `ouvert`, `à confirmer`, `en correction`, `corrigé (vX.Y.Z)`, `pas un bug (raison)`.

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
- **Statut** : `ouvert` (confirmé). Changer le nom demande un choix de nom : production peut le proposer, Wilhem tranche.
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
- **Statut** : `ouvert` (confirmé).
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
- **Statut** : `ouvert`.
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
