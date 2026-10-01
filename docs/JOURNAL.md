# Journal du projet — état à transmettre

## Version 0.2.0 — 1er octobre 2026

**Phase :** sur demande de Wilhem, la livraison regroupe le cœur des phases 2 à 4 (coups,
garde, rounds, combos) et un premier essai visuel de la phase 5, au-dessus de la phase 1 de
ChatGPT. Le cahier des charges prévoyait d'attendre un rapport de test entre chaque phase :
**rien de cette version n'a encore été lancé dans Roblox Studio.**

### Architecture réseau retenue

Prototype **classique** : `RemoteEvent` + simulation autoritaire côté serveur à 60 Hz
(boucle à pas fixe sur `Heartbeat`, rattrapage limité à 8 ticks). Le client envoie des
inputs validés et affiche des snapshots (30/s) avec une légère extrapolation. **Pas de
prédiction client ni de rollback** : le joueur ressent la latence réseau sur ses propres
actions. Input Action System et Server Authority n'ont pas été vérifiés (pas d'accès à
Studio) ; à réévaluer avant la phase 7.

### Fichiers

| Chemin Rojo | Instance dans Studio | Rôle |
|---|---|---|
| `src/shared/CombatConfig.luau` | ReplicatedStorage.Shared.CombatConfig | Valeurs globales (ticks, vitesses, garde, rounds) |
| `src/shared/MoveData.luau` | …Shared.MoveData | Frame data des coups, cancels, hitboxes |
| `src/shared/CombatSimulation.luau` | …Shared.CombatSimulation | Simulation pure : mouvement, coups, garde, combos, rounds |
| `src/shared/CharacterData.luau` | …Shared.CharacterData | KAI 開, skins CLASSIQUE (P1) et NUIT (P2) |
| `src/shared/InputConfig.luau` | …Shared.InputConfig | Bindings clavier/souris/manette |
| `src/server/init.server.luau` | ServerScriptService.Server | Slots joueurs/mannequin, validation des inputs, boucle 60 Hz, snapshots, événements |
| `src/server/ArenaBuilder.luau` | Server.ArenaBuilder | Arène « Temple écarlate » + éclairage |
| `src/server/RigBuilder.luau` | Server.RigBuilder | Rig R15 en blocs de KAI (15 Motor6D) |
| `src/client/init.client.luau` | StarterPlayerScripts.Client | Affichage, interpolation, branchements |
| `src/client/InputController.luau` | Client.InputController | Adaptateur d'inputs (clavier, souris, manette, tactile) |
| `src/client/AnimationController.luau` | Client.AnimationController | Seul écrivain des Motor6D ; poses par paliers |
| `src/client/EffectsController.luau` | Client.EffectsController | VFX : étincelles, smears, bouclier, impact frames, afterimages, debug hitbox |
| `src/client/CameraController.luau` | Client.CameraController | Caméra latérale, secousse, zoom d'impact |
| `src/client/HUDController.luau` | Client.HUDController | Barres de vie/garde, chrono, combos, annonces |
| `tests/CombatSimulation.test.luau` | — | Tests hors ligne de la simulation |

`Movement.luau` (phase 1) a été fusionné dans `CombatSimulation.luau` pour que la
simulation soit testable sans `require` Roblox.

### Conventions

- X = gauche/droite, Y = hauteur, Z verrouillé à 0. 1 tick = 1/60 s.
- Un coup dure `startup + active + recovery` ticks, la frame 1 étant le tick où il démarre.
  La hitbox existe pour `startup < frame ≤ startup + active` et ne touche qu'une fois.
- Le hitstop gèle tout le combattant (frames du coup, stun) : les fenêtres actives
  n'avancent pas pendant le gel.
- L'orientation est verrouillée pendant les attaques, stuns, dashs et sauts.
- Hurtbox, hitbox et pushbox sont séparées et purement logiques (pas de `Touched`).
- Le client ne décide jamais d'un coup, de la vie, de la garde ni d'un KO.

### Gameplay

- **Clic gauche** : JAB → CROSS → COUDE → KICK. Chaque coup s'enchaîne si le précédent a
  touché ou a été bloqué (buffer de 8 ticks).
- **Clic droit** : seul, FRAPPE LOURDE (grosse dégradation de garde). Après JAB, CROSS,
  COUDE ou KICK, RISING STRIKE envoie l'adversaire en l'air → chute → knockdown
  (invulnérable), relevé.
- En l'air, clic gauche ou droit : KICK AÉRIEN (overhead : non bloquable en garde basse).
- **F maintenu** : garde. Elle réduit les dégâts à 15 % (jamais de KO en garde), vide la
  jauge de garde ; à 0, GUARD BREAK (55 ticks sans défense).
- Combos : réduction de dégâts ×0,9 par coup déjà pris (minimum ×0,4). Jonglage limité à
  3 coups aériens.
- Rounds : 99 s, 2 rounds gagnants. Timeout : le plus de vie gagne. Double KO ou égalité :
  le round compte pour les deux ; si les deux atteignent 2, match nul.
- Entraînement (seul) : mannequin, pas de chrono, vie qui se recharge après le combo,
  bouton MANNEQUIN pour le faire garder, R pour replacer.

| Coup | Startup | Actif | Récup. | Dégâts | Hitstun | Blockstun | Hitstop |
|---|---|---|---|---|---|---|---|
| JAB | 5 | 3 | 9 | 45 | 17 | 11 | 6 |
| CROSS | 6 | 3 | 11 | 55 | 19 | 12 | 7 |
| COUDE | 6 | 3 | 13 | 60 | 21 | 13 | 8 |
| KICK | 8 | 4 | 17 | 75 | 24 | 14 | 9 |
| FRAPPE LOURDE | 13 | 4 | 22 | 120 | 26 | 16 | 11 |
| RISING STRIKE | 9 | 5 | 24 | 100 | 30 | 15 | 12 |
| KICK AÉRIEN | 6 | 8 | 10 | 65 | 20 | 12 | 8 |

Vie : 1000. Toutes ces valeurs sont des points de départ à régler en jeu.

### Direction artistique appliquée

D'après la planche « KAI 開 » de Wilhem : noir / blanc / rouge, gilet sans manches ouvert,
débardeur blanc, ceinture rouge, bandages, pantalon large, cheveux noirs en pointes à
mèches rouges. P2 = skin NUIT (bleu). Contour encre via `Highlight`. Poses maintenues par
paliers (12/15/24/s ou fluide, bouton POSES) ; les poses d'attaque changent dès que l'état
de combat change. Étincelles manga, smear rouge sur les coups lourds, bouclier bleu/violet
en garde, impact frames noir/blanc/rouge, afterimages au dash, aura de ki. Bouton EFFETS
pour réduire flashs et secousses (réduit par défaut sur mobile).

### Tests

| Test | État |
|---|---|
| Simulation hors ligne (`luau tests/CombatSimulation.test.luau`) : 17 tests (coup unique, hitstop, garde, overhead, combo 5 coups, knockdown, guard break, orientation verrouillée, coin, KO unique, timeout, double KO, fin de match, recharge entraînement, pushbox) | ✅ passés |
| Compilation Luau de tous les scripts | ✅ |
| Jeu dans Studio (solo, 2 clients, manette, tactile, téléphone) | ❌ non exécuté |
| Rendu visuel (rig, cheveux, poses, arène, effets) | ❌ non vérifié, valeurs à ajuster |

### Problèmes ouverts / risques

- Aucune prédiction client : délai entrée → action égal au ping + jusqu'à 33 ms.
- Les poses et ornements (cheveux, gilet) sont estimés sans rendu : angles probablement à
  retoucher.
- Pas de sons (aucun ID d'asset inventé) : prévoir des SFX fournis par Wilhem.
- `UserInputService.PreferredInput` (texte d'aide) à confirmer dans le Studio utilisé.
- Garde haute/basse : seul le KICK AÉRIEN est « High » ; aucun coup « Low » pour l'instant.

### Prochaine étape proposée

1. Wilhem teste dans Studio (solo puis Server & Clients à 2) et renvoie le rapport : Output
   complet, captures, courte vidéo.
2. Corrections de poses / ressenti, puis SFX.
3. Ensuite : prise, spéciale/ultime (KAIEN RUSH), écran de sélection des skins.
