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
- **Source** : vu en passant par l'agent `production` (routine du 17/10), à confirmer par l'agent `bugs`.
- **Ce qui se passe** : le FATAL FINISHER d'ASTER s'appelle STELLAR COLLAPSE, comme son ÉVEIL (`src/shared/MoveData.luau`, vers la ligne 763).
- **Ce qui devrait se passer** : un nom propre au finisher, comme pour les 18 autres.
- **Gravité** : cosmétique.
- **Statut** : `ouvert`. Changer le nom demande un choix de nom : production peut le proposer.

## B-010 · Le finisher de TARO, joué depuis la droite, met la caméra presque au contact d'un corps
- **Date** : 17 octobre 2026.
- **Source** : vu en passant par l'agent `production` (routine du 17/10), à confirmer par l'agent `bugs`.
- **Ce qui se passe** : joué avec TARO à droite, une image met la caméra à 0,24 stud d'un corps, sous la limite de 0,25. Le labo ne joue jamais ce côté.
- **Comment reproduire** : `Kit.play` avec l'argument `mirror` (nouveau, `tests/CinematicKit.luau`) sur TARO.
- **Gravité** : mineur (une image).
- **Statut** : `ouvert`. Étendre le test miroir aux 18 autres finishers le montrerait.

