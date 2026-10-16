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
- **Comment le voir** : au lancement, la console Studio affiche `[VFX] these textures did not load …` avec le nom et l'ID. Le perso concerné garde alors les effets du jeu.
- **Gravité** : mineur.
- **Statut** : `à confirmer` (Wilhem regarde la console en jeu).
