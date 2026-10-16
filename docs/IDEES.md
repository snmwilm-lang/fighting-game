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

## I-001 · Un FATAL FINISHER pour NOVA, KUROEN, ASURA et KUROEN SHIN
- **Date** : en attente depuis la 0.33.0.
- **Ce qui existe** : les 18 autres persos ont leur FATAL FINISHER (`Finishers.luau`) ; ces quatre-là ont encore le fatal classique.
- **Touche** : `Finishers.luau`, storyboards, sons de cinématique.
- **Valeur / effort** : forte / gros (une scène de 10 s par perso).
- **Critères d'acceptation** :
  - chaque perso a sa scène, avec son plan K.O. et le nom de son finisher ;
  - le storyboard est vérifié (`luau tests/Storyboard.luau -a KIT Fatal - 1 20`) ;
  - les tests passent.
- **Statut** : `prête`.

## I-002 · Étape 4 du pack VFX : les ultimes, puis les arènes et l'interface
- **Date** : 15 octobre 2026.
- **Wilhem** : « Les ultimes (R, ÉVEIL, PORTE), FATAL et FINISHER, les arènes et l'interface arrivent aux étapes 4 à 6. » (LISEZ-MOI de son pack).
- **Ce qui existe** : les 19 assets du pack prévus pour ça (lune, nuages, sceau, piliers, ailes…) sont dans `assets/vfx`, sans ID.
- **Statut** : `nouvelle` (en attente de l'étape 4 du pack).

## I-003 · Le pack VFX vraiment dans la DA du jeu
- **Date** : 15 octobre 2026.
- **Wilhem** : « hésite pas à retravailler pour que ça rentre vraiment dans ma DA ».
- **Ce qui existe** : le pack est branché (v0.36.1), ses effets ne sont jamais vus en jeu d'ici.
- **Questions ouvertes** : des captures ou vidéos en jeu de ce qui ne colle pas (trop gros, trop chargé, couleur, un effet préféré avant).
- **Statut** : `à clarifier`.
