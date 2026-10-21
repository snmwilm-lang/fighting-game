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
- **Statut** : `ouvert` (confirmé le 19/10). Les autres cinématiques ont le même défaut, en plus fort : voir B-016.

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
- **Statut** : `ouvert` (reconfirmé le 21/10 sur la v0.36.7).
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
- **Statut** : `ouvert` (reconfirmé le 21/10 sur la v0.36.7).
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
- **Statut** : `ouvert` (code inchangé au 21/10). Depuis la v0.36.7, la règle pour porter un titre est en `init.server.luau:1456` (et `:1156`, à la mise à jour des badges et cosmétiques du joueur, qui retire un titre porté non permis).
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
- **Gravité** : mineur. Si cela arrivait, ce serait une perte de progression. Mais il faut une course serrée, et l'écriture de départ part dès que le joueur quitte, avant que l'autre serveur ne charge.
- **Statut** : `ouvert` (risque supposé, mécanisme prouvé ; code inchangé au 21/10). Depuis la v0.36.7, l'écriture est `writeProfile`, `init.server.luau:231-250` (verrou posé en `:242`, refus « held by another server » en `:248-250`).
- **Piste** : dans la boucle de vidage, réécrire aussi (renouveler le verrou) tout profil chargé dont la dernière écriture date de plus de `LOCK_TTL / 2`. Par exemple, une fonction `SaveQueue.stale(q, now, ttl)`, avec un test dans `Lobby.test`.

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
  - même chose au premier K.O. d'un relais 2v2 ou 3v3, à chaque vague de SURVIE gagnée ainsi, et dans le faux K.O. d'ASURA (B-020) ;
  - le COUP FATAL classique n'a pas ce défaut : il n'écrit que « K.O. » et le nom du coup (`FATAL.title`, `CinematicDirector.luau:2702-2710`). Le FATAL FINISHER non plus : aucun titre « VICTORY » dans `Finishers.luau`.
- **Ce qui devrait se passer** : « VICTORY » seulement quand ce K.O. gagne le match. Sinon, « K.O. » avec le nom, ou le numéro de la manche.
- **Cause** (prouvée) :
  - `src/shared/CinematicDirector.luau:5172-5174` : `cin.finish` lance `Director.ko` quel que soit le score ;
  - le dernier plan de la scène K.O. écrit `· VICTORY` en dur : `:5067` (KAI) et `koEnd`, `:3221` (les 8 scènes K.O. propres à un kit).
- **Gravité** : mineur. C'est un mot, mais sur un écran noir, à la fin d'une longue scène : le joueur croit le match gagné. Et c'est fréquent : il suffit d'un ÉVEIL ou d'une PORTE sur une cible sous 30 % de sa vie maximale (`MaxHealthShare = 0.3`, `MoveData.luau:927`, `:962`), à n'importe quelle manche.
- **Statut** : `ouvert`.
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
- **Statut** : `à confirmer` (règle à trancher par Wilhem ou production : part de vie, comme la barre, ou PV absolus).
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
- **Statut** : `à confirmer` (le mécanisme est prouvé, l'ordre des événements de Roblox à la fermeture ne l'est pas).
- **Piste** :
  - un drapeau `closing = true` posé en tête de `BindToClose`. `unseat` n'appelle alors pas `endVersus`, ou l'appelle sans points ni série (« no contest ») ;
  - si Roblox retire les joueurs **avant** d'appeler `BindToClose`, ce drapeau arrive trop tard. Repli possible : ne rien compter quand les deux joueurs d'un match partent à moins de quelques secondes d'écart. Le premier départ attendrait alors un court délai avant de conclure ;
  - à faire en même temps que B-023.

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
- **Statut** : `ouvert`.
- **Piste** :
  - dans `followEvents`, n'ajouter l'adversaire suivant (et `match.wave += 1`) que si `event.winner == 1` ;
  - ou compter les vagues gagnées à part (`match.beaten`) ;
  - un test avec la correction de B-022, qui touche le même endroit.
