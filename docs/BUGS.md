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

