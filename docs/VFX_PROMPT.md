# BREAKFRAMEZ — Le grand prompt VFX

Pour Wilhem. Ce document liste **tous les VFX dont le jeu a besoin**. Pour chacun, il donne :
- **la méthode Roblox** : quels objets utiliser et avec quels réglages ;
- **les assets à produire** : textures et meshes, avec leurs specs ;
- **la priorité**.

Il peut aller tel quel à un artiste VFX ou à une IA d'images (les prompts d'images sont en anglais, ces IA les comprennent mieux). Il peut aussi servir à Claude pour brancher les assets dans le code.

**Comment s'en servir**

1. **Section 0** : le *prompt maître*. Le coller en tête de toute commande (artiste ou IA).
2. **Sections 3 et 4** : la *bibliothèque commune*, environ 50 textures et 25 meshes. À produire **d'abord** : elle sert à tous les persos, car le jeu la recolore.
3. **Sections 5 à 9** : tous les VFX par usage. Chaque ligne cite la bibliothèque (`T..` = texture, `M..` = mesh) et ajoute ce qui est propre au perso.
4. **Section 10** : l'ordre de production.
5. **Section 11** : comment me donner les IDs pour que je branche les assets.

**État actuel.** La plupart de ces effets existent déjà dans le jeu en version **procédurale** : des Parts Neon ou ForceField, des Beams, et deux textures intégrées à Roblox (`smoke_main`, `sparkles_main`). Le jeu marche donc sans aucun de ces assets. Chaque asset livré **remplace une version procédurale** et monte la qualité d'un cran.

---

## 0. Le prompt maître (à coller tel quel)

```
Tu es un artiste VFX senior, spécialiste de Roblox et des jeux de combat anime. Références de
qualité : Guilty Gear Strive, Dragon Ball FighterZ, Jujutsu Kaisen Cursed Clash, Demon Slayer
Hinokami Chronicles, et les « battlegrounds » Roblox les plus soignés.

LE JEU — BREAKFRAMEZ : jeu de combat 1 contre 1 (équipes de 1 à 3) sur Roblox, caméra de côté,
60 images par seconde, personnages en blocs (rig R15 « bloc »). 22 combattants, chacun avec un
élément : ki, feu, vent, ombre, rage, eau, vide, pierre, foudre, glace, poison, titan, gravité,
son, acier, sang, nature, lumière, technologie, éclipse, plus 2 boss (or divin, or à quatre bras).
Chaque perso a : des coups normaux, un projectile, un dash, un passif, 3 ultimes (R = rush,
ÉVEIL, PORTE), un FATAL et un FINISHER cinématique.

STYLE : anime en cel-shading. Formes nettes, 2 ou 3 tons, bords durs. Cœur blanc + corps de
couleur + liseré sombre. Jamais de fumée réaliste, jamais de photo. Le mouvement prime :
anticipation (1 à 3 images), explosion (1 ou 2 images, très grande), puis dissipation lente
(10 à 30 images).

CONTRAINTES ROBLOX :
- Pas de shaders. Outils disponibles : ParticleEmitter (avec flipbooks), Beam, Trail, MeshPart
  (Neon, ForceField, Glass), Highlight, PointLight / SpotLight, post-process (ColorCorrection,
  Bloom, Blur), et ScreenGui (ImageLabel) pour les effets d'écran.
- Textures : PNG 32 bits, fond transparent, côtés en puissance de 2, 1024 × 1024 maximum.
  Dessiner en BLANC ou en niveaux de gris : le jeu donne la couleur (propriété Color), pour que
  chaque skin recolore ses effets. Exception : les effets « encre » (ombre, vide, éclipse, sang)
  se dessinent en noir avec un bord clair.
- Flipbooks : grille 2×2 (512 px), 4×4 (1024 px, images de 256 px) ou 8×8 (1024 px, images de
  128 px). Lecture de gauche à droite puis de haut en bas, sujet centré, dernière image vide ou
  presque.
- Pas de halo noir autour des formes : étendre la couleur des bords sous les pixels
  transparents (« alpha bleed » / dilatation).
- Meshes : FBX ou OBJ, low poly (un arc de slash fait moins de 300 triangles, un gros décor
  moins de 3 000). Origine au centre. UV dépliés de 0 à 1 le long de la forme, pour pouvoir
  faire défiler une texture dessus.
- Budget mobile : un coup normal ≤ 40 particules ; un ultime ≤ 600 particules à l'écran,
  ≤ 24 Beams, ≤ 4 lumières.
- Les effets sont cosmétiques et calculés côté client : ils ne décident jamais d'un coup, de la
  vie ni d'un K.O.
- Aucun texte dans les images (sauf les kanji demandés), aucun logo, rien qui imite une marque.
- Sang : stylisé (énergie cramoisie, cristaux, pétales), jamais réaliste (classement d'âge Roblox).

LIVRABLE, pour chaque asset : le fichier nommé VFX_<PERSO|COMMON>_<NOM>[_<GRILLE>].png (ou
.fbx), avec une ligne qui donne l'usage, la taille, la grille, les images par seconde
conseillées et le LightEmission (0 ou 1).
```

---

## 1. Les méthodes Roblox de référence

Ce sont les recettes utilisées dans tout le document : « méthode : burst T05 » renvoie ici.

### 1.1 ParticleEmitter — étincelles, fumée, éclats, auras

| Réglage | Valeur type | Pourquoi |
|---|---|---|
| `Rate = 0`, `Enabled = false`, puis `:Emit(n)` | n = nombre du niveau d'impact (§2.2) | Un **burst** au moment exact du coup. |
| Pool | un émetteur par type et par perso, réutilisé | Jamais de `Instance.new` à chaque coup (mobile). |
| `LightEmission` | 1 pour ce qui brille, 0 pour fumée et encre | 1 = additif (s'éclaircit sur le décor). |
| `LightInfluence` | 0 | La lumière de l'arène ne salit pas les couleurs. |
| `Brightness` | 1,5 à 4 sur les cœurs | Au-dessus de 1, le Bloom s'allume. |
| `Orientation = VelocityParallel` + `Squash` (0,5 à 2) | étincelles | Des traits allongés dans le sens du vol. |
| `Shape = Sphere` / `Disc` / `Cylinder`, `ShapeStyle = Surface` | auras, anneaux | Émettre depuis une forme. |
| `ShapeInOut = Inward` | charges | L'énergie est **aspirée** vers le centre. |
| `FlipbookLayout = Grid4x4`, `FlipbookMode = OneShot`, `FlipbookFramerate` 24 à 40 | impacts, fumée | Une animation dessinée par particule. |
| `FlipbookStartRandom = true`, `FlipbookMode = Random` | variantes 2×2 | Quatre dessins tirés au hasard. |
| `Drag` 6 à 15 | explosions | La particule part vite et **freine net** (look anime). |
| `Size` (NumberSequence) | 0 → 1 en 10 % de la vie, puis 1 → 1,2 | Expansion rapide, puis lente. |
| `Transparency` (NumberSequence) | 0 jusqu'à 60 %, puis 1 | Elle reste pleine, puis disparaît vite. |
| `TimeScale` | 0 pendant le gel d'impact (hitstop), 1 après | Les effets se figent avec les persos : le « freeze frame » anime. |
| `LockedToPart = true` | auras | L'aura suit le corps. |
| `ZOffset` | +1 cœur, 0 corps, -1 fumée | L'ordre d'affichage. |

### 1.2 Beam — rayons, éclairs, traînées longues, tourbillons

- Deux Attachments ; `Segments` de 10 à 60 ; `CurveSize0` et `CurveSize1` pour courber ; `FaceCamera = true`.
- `TextureMode = Wrap` + `TextureSpeed` (1 à 4) : l'énergie **coule** le long du rayon. `Stretch` : une forme fixe (un slash, un arc).
- `Width0` / `Width1` et la NumberSequence `Transparency` font l'effilé.
- **Éclair** : une chaîne de 6 à 12 Beams. On déplace leurs Attachments au hasard toutes les 2 ou 3 images (le jeu le fait déjà pour `lightning`).
- **Tourbillon** : 3 Beams très courbés autour d'un axe, qui tournent à des vitesses différentes.

### 1.3 Trail — traînées de coups

- Deux Attachments sur le membre ou l'arme : base et pointe de la lame, ou haut et bas du poing ou du pied.
- `Lifetime` de 0,08 à 0,2 s ; `MinLength = 0` ; `WidthScale` de 1 à 0.
- `FaceCamera = false` pour les lames, `true` pour les poings et les pieds.
- Texture : T15 ou T16.
- Activé **seulement pendant les images actives** du coup, puis `:Clear()`.

### 1.4 MeshPart — slashes, ondes de choc, dômes, piliers

- **Neon** + tween de `Transparency` et de `Size` : arcs, anneaux, piliers.
- **ForceField** : avec ce matériau, le `TextureID` du MeshPart devient un motif lumineux animé par Roblox. Idéal pour les boucliers, les dômes, les orbes et les coques d'énergie.
- **Recette d'un slash** (M01 à M03) :
  - échelle de 0,6 à 1,1 en 4 images ;
  - rotation de 10 à 20° pendant sa vie ;
  - transparence de 0 à 1 en 10 images.
- **Décalques au sol** (fissures, brûlures, flaques) : une Part très fine avec un `Decal`, qui s'efface en 1 ou 2 s.
- **Texture qui défile sur une Part** : un objet `Texture`, dont on fait varier `OffsetStudsU` ou `OffsetStudsV` à chaque image.

### 1.5 Lumières et post-process

- **PointLight d'impact** : `Brightness` de 3 à 8, `Range` de 8 à 16, durée de 4 à 8 images, `Shadows = false`.
- **ColorCorrectionEffect** : les « grades » des ultimes (§7.2).
- **BloomEffect** : en combat `Intensity` 0,4, `Size` 24, `Threshold` 0,95 ; en ultime, `Intensity` monte jusqu'à 1.
- **Highlight** : silhouettes (image d'impact, aura FATAL, flash d'armure). Roblox en accepte 31 en même temps ; le jeu en garde 6 au plus.

### 1.6 Effets d'écran (ScreenGui)

- ImageLabel plein écran, avec `IgnoreGuiInset = true`.
- **Flipbook en UI** : changer `ImageRectOffset` à chaque image (`ImageRectSize` = la taille d'une case).
- **Reflet qui balaie** (sheen) : tween de `Offset` ou de `Rotation` sur un `UIGradient`.
- ⚠️ Un **ViewportFrame n'affiche ni les particules, ni les Beams, ni les Trails, ni les lumières**. Les aperçus de la boutique et des menus doivent donc montrer les auras en **images UI** (un flipbook derrière le perso), pas en particules.

### 1.7 Règles du jeu, pour tous les VFX

- Les effets sont **côté client** et se déclenchent sur les **événements de la simulation**. Les événements qui existent déjà :
  - `Hit`, `Block`, `GuardBreak`, `Parry`, `Resolve` ;
  - `Clash`, `ClashStep`, `Reflect`, `Projectile` ;
  - `Throw`, `ThrowBeat`, `ThrowImpact`, `GrabTech` ;
  - `AirDash`, `SuperJump`, `FastFallLand`, `WallBounce`, `GroundBounce` ;
  - `Burst`, `Armor`, `Evade`, `Slip`, `Blink` ;
  - `SuperFlash`, `Skill`, `Perfect`, `Heal`, `Revive` ;
  - `Poison`, `Chilled`, `Shackled`, `Domination`, `Drone`.
- **Mode réduit** (l'option existe : `effects.reduced`) : 40 % des particules, pas de grade de couleur, secousse divisée par 2,5, pas de flash blanc.
- **Photosensibilité** : un flash blanc plein écran dure 3 images au plus, et jamais plus de 3 flashes par seconde.
- **IDs** : Wilhem envoie les assets sur Roblox et donne leurs IDs. On ne met **jamais** un ID inventé (voir §11).

---

## 2. Direction artistique

### 2.1 Couleurs des 22 combattants

La couleur **Énergie** change avec le skin : les textures blanches suivent donc le skin toutes seules. L'**accent** est fixe pour le kit.

Matière :
- **lumière** = textures blanches, `LightEmission` 1 ;
- **encre** = textures noires à bord clair, `LightEmission` 0 sur le noir, plus une couche lumineuse de la couleur Énergie par-dessus ;
- **matière** = effets opaques et ombrés (pierre, poussière), `LightEmission` 0.

| Perso | Élément | Énergie (skins) | Accent | Matière |
|---|---|---|---|---|
| KAI 開 | ki | FF2A3D classique · 4D8DFF NIGHT · FFD23F SACRED · B060FF CURSED · FFD23F AWAKENED | FFFFFF | lumière |
| TARO 火 | feu | FF6A1A BLAZE · FFB21A CHAMPION | FFD45A | lumière |
| ZEPHYR 風 | vent | 5FE0D0 AZURE · 9FD8FF STORM | E8F6FF | lumière, très transparente |
| AKEMI 影 | ombre | B060FF SHADOW · FF2A3D RED MOON | 140A1E | encre |
| RYUKEN 拳 | rage | FF2A2A SHATTERED · FF4A2A BLACK BLOOD | FF3A1A (vapeur 8C8A90) | lumière + vapeur |
| SHIN 流 | eau | 4DA8FF CURRENT · 8FE0FF STEEL | BFF4FF | lumière, liquide |
| DAICHA 闇 | vide | B060FF INVERTED · C080FF ECLIPSE | 0B0712 | encre |
| HIBECARES 崩 | pierre | FF8A1A RUINS (braises) · MAGMA | 7A6D62 (poussière B8A890) | matière + braises |
| RAIJIN 雷 | foudre | FFE85A THUNDERSTORM · 8FD8FF DIVINE | FFF6A0 | lumière, scintillante |
| YUKINA 雪 | glace | 9FE6FF WINTER · C8F0FF EMPRESS | DFF6FF | lumière + cristal |
| VENOM 毒 | poison | 7CFF4A TOXIC · B8FF5A MUTATION | 7CFF4A (ombre 2A5A10) | liquide, à moitié lumineux |
| GORAN 剛 | titan | FF4A3A TITAN · FFB03A GLADIATOR | C9BFC0 | matière |
| ASTER 星 | gravité | B49CFF COSMOS · FF7A3A SINGULARITY | E8E0FF | lumière + noir |
| HIBIKI 響 | son | FF6FC8 TECHNO · 6FE0FF HARMONY | 6FE0FF | lumière, anneaux |
| KAZAN 鎖 | acier | FFB04A PRISONER · FF5A3A EXECUTIONER | E0E0E8 | métal + étincelles |
| KUREN 血 | sang | D0102E ROYAL BLOOD · FF2A4A FORBIDDEN | 8A0A1A | encre cramoisie |
| SYLVA 森 | nature | 4AD86A WILD · 8AF08A BLOSSOM | 8AD84A | matière (feuilles) |
| ELIAN 癒 | lumière | FFE9A0 CELESTIAL · C080FF CORRUPTED | FFE9A0 | lumière |
| NOVA 機 | tech | FF8A2A PROTOTYPE · 6FE0FF OMEGA | 6FE0FF | lumière + hologramme |
| KUROEN 蝕 | éclipse | E0102E EMPEROR · FFE9A0 DIVINE ECLIPSE · FF4A2A BLOOD MOON | 0A0204 | encre rouge et noire |
| ASURA (boss) | or à quatre bras | FFD23F | FF2A3D | lumière dorée |
| KUROEN SHIN (boss) | divin | FFE9A0 | FFFFFF + FFD23F | lumière blanche et or |

### 2.2 Hiérarchie des impacts

Plus le coup compte, plus l'effet est gros. C'est la règle numéro 1 de la lisibilité.

| Niveau | Exemples | Étincelle | Particules | Onde | Lumière | Image d'impact | Fumée |
|---|---|---|---|---|---|---|---|
| Léger | jab, coup rapide | T05, 2 à 3 studs | 6 à 10 | — | 3 / 8 studs, 4 images | — | — |
| Moyen | 2e et 3e coups | T05, 4 studs | 12 à 16 | T08, petite | 4 / 10, 5 images | — | T13 × 2 |
| Lourd | launcher, rebond au mur, smash | T06, 6 studs | 20 à 28 | T09 + T12 | 6 / 14, 6 images | 1 image (option) | T11 × 4 |
| Fin de combo, contre | dernier coup d'une route | T06 + T07, 8 studs | 30 à 40 | T09 ×2 + débris M11 | 8 / 16, 8 images | 2 images | T11 × 6 |
| Coup final d'ultime | — | tout, 12 studs et plus | 80 à 150 | dôme M06 | 10 / 24 | 2 images + flash blanc | gros nuage |
| FATAL, K.O. | — | tout + carte K.O. | 150 à 300 | dôme + fissures | — | 3 images | gros nuage |

### 2.3 Rythme d'un effet (à 60 images par seconde)

- **Anticipation** (1 à 3 images) : un point de lumière qui se contracte, ou de l'énergie aspirée.
- **Image 0 de l'impact** : la forme la plus grande, un « smear ». Ensuite (images 1 et 2) : l'étoile.
- **Dissipation** (10 à 30 images) : on ralentit (`Drag`) et on éclaircit.
- **Courbes** : expansion en *ease-out* exponentiel ; disparition en *ease-in*.
- **Pendant le hitstop** : `TimeScale = 0` sur les émetteurs, et les tweens sont en pause.

---

## 3. Bibliothèque de textures communes (T01 à T50)

Toutes en **blanc ou niveaux de gris** sur fond transparent, sauf indication contraire.

Colonne « Qui » :
- **C** = Claude peut la générer en script (géométrique ou procédurale) ;
- **A** = à dessiner par un artiste ou une IA d'images.

Méthode IA conseillée : générer **sur fond noir pur**, puis convertir la luminance en alpha (Claude peut fournir le script) et dilater les bords.

| ID | Fichier | Format | Ce que c'est | Prompt image (EN) | Qui | Sert à |
|---|---|---|---|---|---|---|
| T01 | VFX_COMMON_GLOW_SOFT | 256 | Dégradé radial doux | — | C | halos, auras, lumières |
| T02 | VFX_COMMON_GLOW_CORE | 256 | Disque à bord dur + halo doux (cœur anime) | — | C | cœurs de boules, impacts |
| T03 | VFX_COMMON_STAR4 | 256 | Étoile à 4 branches fines (scintillement) | "anime sparkle, four-pointed thin star flare, white on black, centered" | C | étincelles, reflets |
| T04 | VFX_COMMON_STREAK | 256 | Trait effilé aux deux bouts | — | C | étincelles allongées, pluie |
| T05 | VFX_COMMON_HITSPARK_LIGHT_4x4 | 1024, 4×4 | Étincelle d'impact anime (étoile à pointes qui éclate), 16 images | "anime hit spark sprite sheet 4x4, 16 frames, sharp spiky starburst exploding then fading, white on black, cel shaded, centered" | A | coups légers et moyens |
| T06 | VFX_COMMON_HITSPARK_HEAVY_4x4 | 1024, 4×4 | Impact lourd : étoile + éclats + anneau | "anime heavy impact sprite sheet 4x4, starburst with shards and a shockwave ring, white on black, cel shaded" | A | coups lourds |
| T07 | VFX_COMMON_IMPACT_BURST_2x2 | 1024, 2×2 | 4 explosions de BD dentelées (sans texte) | "comic impact burst shapes, jagged, 4 variants in 2x2 grid, white on black, no text" | A | fins de combo, contres |
| T08 | VFX_COMMON_RING_THIN | 512 | Anneau fin | — | C | ondes, son, parade |
| T09 | VFX_COMMON_RING_SOFT | 512 | Anneau épais à bord flou (onde de choc) | — | C | chocs lourds |
| T10 | VFX_COMMON_RING_DASHED | 512 | Anneau en tirets (anneau de vitesse) | — | C | dash, vent, saut |
| T11 | VFX_COMMON_SMOKE_CEL_8x8 | 1024, 8×8 | Bouffée de fumée anime (2 tons, bords nets), 64 images ; **LightEmission 0** | "anime cel shaded smoke puff animation sprite sheet 8x8, 64 frames, white with light grey shading, hard edges, billowing then dissipating" | A | fumée, vapeur, poussière |
| T12 | VFX_COMMON_DUST_GROUND_4x4 | 1024, 4×4 | Poussière soulevée au sol, vue de côté | "anime ground dust kick sprite sheet 4x4, side view, cel shaded, white and grey" | A | dash, atterrissage, chute |
| T13 | VFX_COMMON_PUFF_2x2 | 512, 2×2 | 4 petites bouffées fixes (version légère) | "4 small cel shaded smoke puffs, 2x2 grid, white" | A | mobile, petits coups |
| T14 | VFX_COMMON_SLASH_ARC | 1024×256 | Croissant en dégradé : bord d'attaque vif, queue qui s'efface | "anime sword slash arc texture, bright leading edge fading tail, horizontal, white on black" | A | meshes de slash, Beams |
| T15 | VFX_COMMON_TRAIL_GRADIENT | 256×64 | Dégradé horizontal avec stries | — | C | Trails des poings et pieds |
| T16 | VFX_COMMON_TRAIL_WISPY | 512×128 | Traînée d'énergie effilochée, avec des trous | "wispy energy trail texture, horizontal, tileable, white on black" | A | Trails d'énergie, brins |
| T17 | VFX_COMMON_ENERGY_FLOW | 512×128 | Bruit d'énergie qui coule, **raccordable** | — | C | corps des rayons, tourbillons, eau |
| T18 | VFX_COMMON_LIGHTNING_A..D | 512×128 ×4 | 4 éclairs raccordables (fichiers séparés : un Beam ne lit pas un atlas) | "lightning bolt strip, tileable horizontally, white on black, jagged with branches" | C | foudre, crépitements |
| T19 | VFX_COMMON_SPEEDLINES_RADIAL_4x4 | 1024, 4×4 | Lignes de vitesse radiales animées, centre vide | — | C | écran (ultimes) |
| T20 | VFX_COMMON_SPEEDLINES_LINEAR_4x4 | 1024, 4×4 | Lignes d'action horizontales | — | C | écran, dash, vent |
| T21 | VFX_COMMON_CRACK_2x2 | 1024, 2×2 | 4 fissures au sol (décalque, centre plus sombre) | "ground crack decal top view, 4 variants 2x2, black cracks on transparent" | C/A | coups lourds, quakes |
| T22 | VFX_COMMON_SCORCH | 512 | Trace de brûlure (décalque) | — | A | feu, dash RYUKEN |
| T23 | VFX_COMMON_DEBRIS_2x2 | 512, 2×2 | Éclats de roche vus de loin (les gros sont des meshes M11) | "small rock fragments sprites 2x2, cel shaded grey" | A | débris lointains |
| T24 | VFX_COMMON_SHARD | 256 | Éclat de cristal ou de verre | "crystal shard sprite, sharp facets, white" | A | glace, garde brisée |
| T25 | VFX_COMMON_SCREEN_CRACK | 1024 | Vitre brisée plein écran | "broken glass overlay, cracks radiating from center, white lines on transparent" | C/A | FATAL, image d'impact |
| T26 | VFX_COMMON_VIGNETTE | 1024 | Vignette radiale sombre | — | C | super flash, ultimes |
| T27 | VFX_COMMON_SEAL_CIRCLE | 1024 | Cercle de sceau (anneaux, traits, motifs, **sans écriture**) | "ornate magic seal circle, concentric rings and geometric marks, no letters, white on black" | A | sceaux de kanji, PORTE |
| T28 | VFX_COMMON_AURA_FLAME_8x8 | 1024, 8×8 | Langue de flamme d'aura qui monte (style DBZ), 64 images | "anime power aura flame tongue rising, sprite sheet 8x8, cel shaded, white" | A | auras d'ultime, jauge pleine |
| T29 | VFX_COMMON_WISP_4x4 | 1024, 4×4 | Volute qui monte et s'effiloche | "wisp of energy rising and fading, sprite sheet 4x4, white" | A | auras douces, encre |
| T30 | VFX_COMMON_MOTE | 128 | Petit point lumineux | — | C | ambiance, charges |
| T31 | VFX_COMMON_FLARE_ANAMORPHIC | 1024×256 | Reflet horizontal (lens streak) | — | C | super flash, lâchers |
| T32 | VFX_COMMON_DISTORT_RING | 512 | Anneau « réfraction » (bord clair très transparent) | — | C | faux remous de chaleur, gravité |
| T33 | VFX_COMMON_GLINT | 256 | Reflet diagonal net | — | C | parade, saisie, lame |
| T34 | VFX_COMMON_SPLASH_4x4 | 1024, 4×4 | Éclaboussure de liquide anime | "anime liquid splash sprite sheet 4x4, cel shaded, white with grey shading" | A | eau, poison, sang |
| T35 | VFX_COMMON_DROPLET | 128 | Goutte | — | C | eau, poison, sang |
| T36 | VFX_COMMON_FLAME_8x8 | 1024, 8×8 | Flamme anime en boucle | "anime fire flame loop sprite sheet 8x8, cel shaded, two tones, white" | A | feu, propulseurs |
| T37 | VFX_COMMON_EMBER | 64 | Braise | — | C | feu, forge, magma |
| T38 | VFX_COMMON_LEAF_2x2 | 512, 2×2 | 4 feuilles | "4 stylized leaves 2x2, flat anime style, white with grey vein" | A | SYLVA, dojo |
| T39 | VFX_COMMON_PETAL_2x2 | 512, 2×2 | 4 pétales (sakura) | "4 cherry blossom petals 2x2, flat anime style, white" | A | SYLVA BLOSSOM, aura SAKURA, temple |
| T40 | VFX_COMMON_SNOWFLAKE_2x2 | 512, 2×2 | 4 flocons | — | C | YUKINA, lac gelé, aura FROST |
| T41 | VFX_COMMON_BUBBLE | 128 | Bulle (anneau + reflet) | — | C | VENOM |
| T42 | VFX_COMMON_NOTE_2x2 | 512, 2×2 | 4 notes de musique | — | C/A | HIBIKI |
| T43 | VFX_COMMON_HEX_GRID | 512 | Grille hexagonale raccordable | — | C | boucliers tech (ForceField), NOVA |
| T44 | VFX_COMMON_INK_4x4 | 1024, 4×4 | Explosion d'encre **noire** à bord clair | "black ink splash burst sprite sheet 4x4, sumi-e style, black with thin white rim" | A | AKEMI, DAICHA, KUROEN |
| T45 | VFX_COMMON_GODRAY | 512×128 | Rayon de lumière vertical doux | — | C | piliers de lumière, dojo, palais |
| T46 | VFX_COMMON_CHAIN | 128×256 | Chaîne raccordable verticalement | "metal chain link strip, tileable vertical, flat cel shading, grey" | A | KAZAN (Beam) |
| T47 | VFX_COMMON_CLAW_2x2 | 512, 2×2 | Griffures à 3 traits | "three parallel claw slash marks, 4 variants 2x2, white" | A | KAZAN, VENOM |
| T48 | VFX_COMMON_PIXEL_2x2 | 256, 2×2 | Carrés de glitch | — | C | NOVA |
| T49 | VFX_COMMON_CLOUD_2x2 | 1024, 2×2 | Nuages anime | "anime cel shaded cloud shapes 2x2, white with grey underside" | A | palais des nuages, orage |
| T50 | VFX_COMMON_MOON | 512 | Disque de lune (cratères légers) | — | C/A | ZEPHYR, KUREN |

---

## 4. Meshes communs (M01 à M25)

| ID | Fichier | Forme | Notes de fabrication | Sert à |
|---|---|---|---|---|
| M01 | VFX_COMMON_SLASH_90 | Ruban en croissant (90°) | Plat, plus épais au centre ; UV U le long de l'arc ; ≤ 200 triangles | slashes courts, traînées de coups |
| M02 | VFX_COMMON_SLASH_180 | Croissant de 180° | idem | grands slashes, vagues de son |
| M03 | VFX_COMMON_SLASH_360 | Anneau complet en spirale légère | idem | coups tournoyants, grand balancement |
| M04 | VFX_COMMON_SHOCK_RING | Tore plat (ruban d'anneau) | UV U autour de l'anneau | ondes au sol, anneaux de vitesse |
| M05 | VFX_COMMON_SHOCK_CYLINDER | Cylindre ouvert, sans fond ni couvercle | UV V en hauteur | piliers, colonnes d'énergie |
| M06 | VFX_COMMON_DOME | Hémisphère, faces des deux côtés | — | gros impacts, explosions |
| M07 | VFX_COMMON_SPHERE | Icosphère lisse | — | boules (avec matériau ForceField) |
| M08 | VFX_COMMON_CONE_FLARE | Cône évasé ouvert | — | bouche des rayons, lâchers |
| M09 | VFX_COMMON_HELIX | Ruban en hélice (2 tours) | UV U le long | brins d'énergie, dragon, vent |
| M10 | VFX_COMMON_TWISTER | Entonnoir torsadé ouvert | UV qui défile en V | tornade, trombe d'eau |
| M11 | VFX_COMMON_ROCK_A..C | 3 rochers low poly | ≤ 60 triangles chacun, aplats | débris, pierres |
| M12 | VFX_COMMON_PILLAR | Colonne brisée | ≤ 400 triangles | HIBECARES |
| M13 | VFX_COMMON_ICE_SHARD_A..C | 3 éclats de glace | facettes nettes, matériau Glass | YUKINA |
| M14 | VFX_COMMON_SPIKE | Pointe (épine, stalagmite) | — | glace, épines, roche |
| M15 | VFX_COMMON_FIST_GIANT | Poing géant stylisé | ≤ 800 triangles | RYUKEN, ASURA |
| M16 | VFX_COMMON_CLAW3 | 3 lames-rubans parallèles courbes | — | KAZAN, VENOM |
| M17 | VFX_COMMON_CRESCENT_BLADE | Croissant épais (lame de vent) | — | ZEPHYR, SHIN |
| M18 | VFX_AKEMI_KUNAI | Kunai | ≤ 150 triangles | AKEMI |
| M19 | VFX_RAIJIN_SPEAR_BOLT | Lance de foudre | — | RAIJIN |
| M20 | VFX_KUREN_LANCE | Lance de cristal de sang | — | KUREN |
| M21 | VFX_KAI_GATE | Porte (torii massive) en 2 battants, pour s'ouvrir puis se briser | morceaux séparés pour la casse | KAI PORTE |
| M22 | VFX_NOVA_DRONE | Drone | ≤ 500 triangles | NOVA |
| M23 | VFX_COMMON_ROOT | Racine ou liane (tube courbe) | UV le long | SYLVA |
| M24 | VFX_COMMON_FLOOR_DISC | Plan carré (pour un sceau ou un décalque) | — | sceaux, zones |
| M25 | VFX_COMMON_WING | Aile (plumes en aplats) | — | ELIAN, KUROEN SHIN |

---

## 5. VFX communs du combat (tous les persos)

Chaque effet utilise la couleur **Énergie** de l'attaquant, sauf indication contraire. `Shield` est la couleur de garde du skin (champ `Shield` des styles).

### 5.1 Impacts et défense

| VFX | Événement | Look | Méthode | Assets | Priorité |
|---|---|---|---|---|---|
| Impact léger, moyen, lourd | `Hit` | Étincelle qui éclate, traits, onde selon le niveau (§2.2) | Burst T05 ou T06 (Grid4x4 OneShot, 30 fps) ; 6 à 16 traits T04 en `VelocityParallel` ; anneau T08 ou T09 face caméra ; PointLight ; `TimeScale` 0 pendant le hitstop | T04, T05, T06, T08, T09 | P0 |
| Fin de combo, contre | `Hit` (dernier coup) | Impact lourd + explosion BD + débris | T07 (Random 2×2) + 2 anneaux décalés de 3 images + M11 ×4 avec gravité | T07, M11 | P0 |
| Garde | `Block` | Bouclier hexagonal qui flashe du côté du coup, quelques étincelles | MeshPart disque (M24) en matériau ForceField + T43, couleur `Shield`, 6 images ; burst T04 ×6 | T43 | P0 |
| Garde brisée | `GuardBreak` | Le bouclier vole en éclats, petites étoiles d'étourdissement | Burst T24 ×14 en couleur `Shield` (+ Drag) ; flash blanc du disque ; 3 étoiles T03 qui tournent au-dessus de la tête pendant l'étourdissement | T24, T03 | P0 |
| Parade | `Parry` | Reflet blanc net + anneau + micro-ralenti | T33 + anneau T08 blanc qui grandit vite ; PointLight blanche 4 images | T33, T08 | P1 |
| RESOLVE (KAI) | `Resolve` | Comme la parade, mais rouge et blanc, avec une flamme qui s'échappe du corps | Parade + burst T28 ×4 vers le haut | T28 | P1 |
| Choc de coups | `Clash` | Deux étincelles qui se repoussent, éclair blanc entre les deux | Deux bursts T05 dos à dos + Beam T18 court entre eux pendant 6 images | T05, T18 | P1 |
| Choc de projectiles | `Projectile` qui s'annule | Les deux couleurs explosent ensemble | Bursts T06 aux deux couleurs + anneau T09 | — | P1 |
| Renvoi | `Reflect` | Le projectile rebondit sur un miroir | Disque ForceField + T33 + petit anneau | — | P2 |
| Super armure | `Armor` | Le corps flashe rouge-orange, anneau métallique | Highlight `FillColor` FF5A2A, `FillTransparency` de 0,5 à 1 en 6 images ; anneau T08 | — | P1 |
| Burst (sortie de combo) | `Burst` | Sphère d'énergie qui repousse tout | M07 en ForceField : échelle de 1 à 8 en 10 images ; T09 au sol ; T11 ×8 | M07, T09 | P1 |

### 5.2 Mouvement

| VFX | Événement | Look | Méthode | Assets | Priorité |
|---|---|---|---|---|---|
| Dash au sol | dash | Poussière qui part en arrière + une image fantôme | T12 aux pieds (2 bursts) ; clone du rig avec Highlight Énergie, transparence de 0,5 à 1 en 8 images ; la variante du kit s'ajoute (§6) | T12 | P0 |
| Dash aérien | `AirDash` | Anneau de vitesse derrière, traits | Anneau T10 face au mouvement + T20 local + T04 ×8 | T10 | P0 |
| Super saut | `SuperJump` | Colonne d'air + anneau au sol | M04 au sol + traits T04 vers le haut + T12 | M04 | P1 |
| Saut, atterrissage | saut | Petit nuage, sans plus | T13 ×2 | T13 | P0 |
| Atterrissage en chute rapide | `FastFallLand` | Onde au sol + poussière + fissure légère | M04 + T12 + T21 (Decal, 30 % d'opacité) | M04, T21 | P1 |
| Rebond au mur | `WallBounce` | Fissure en étoile sur le « mur » invisible, poussière | T21 posé à la verticale, face caméra (1 s) + T06 + T11 ×4 | T21 | P0 |
| Rebond au sol | `GroundBounce` | Cratère, débris, onde | T21 au sol + M11 ×4 + M04 + T12 | — | P0 |
| Chute au sol (knockdown) | à terre | Poussière qui retombe | T12 ×2 + T13 | — | P0 |
| Image fantôme (afterimage) | dash, ultimes | Silhouette de couleur qui s'efface | Clone du rig (sans scripts) + Highlight (`FillTransparency` 0,4, `OutlineTransparency` 1), tween de 0,4 à 1 ; 3 au plus en même temps | — | P0 |

### 5.3 Saisies

| VFX | Événement | Look | Méthode | Assets | Priorité |
|---|---|---|---|---|---|
| Saisie | `Throw` | Reflet sur la main au moment où elle attrape | T33 sur la main + petit anneau | T33 | P1 |
| Coups pendant la saisie | `ThrowBeat` | Impacts moyens, sans projection | Impact « moyen » (§5.1) | — | P1 |
| Fin de la saisie | `ThrowImpact` | Impact lourd + cratère selon la famille de saisie | GroundBounce ou WallBounce | — | P1 |
| Évasion de saisie | `GrabTech` | Éclair blanc entre les deux, ils se repoussent | T31 horizontal + 2 bursts T04 | T31 | P2 |

### 5.4 Jauges et états

| VFX | Événement | Look | Méthode | Assets | Priorité |
|---|---|---|---|---|---|
| Super flash (lancement d'un ultime) | `SuperFlash` | Écran qui s'assombrit, reflet horizontal sur le perso, gel de 10 images | Vignette T26 + ColorCorrection `Brightness` -0,15 ; T31 sur le torse ; Highlight contour blanc ; T19 à l'écran 10 images | T26, T31, T19 | P0 |
| Jauge : niveaux 1, 2, 3 | jauge | Une aura qui grandit avec la jauge | Émetteur T28 sur un Cylinder autour du HumanoidRootPart (`LockedToPart`) : `Rate` 0, puis 6, 14, 26 ; plus 2 motes T30 qui montent | T28, T30 | P1 |
| FATAL disponible (aura façon Tekken) | FATAL prêt | Aura rouge électrique qui crépite, pulsation | T28 en rouge + Beams T18 courts qui sautent sur le corps (6 Beams, nouvelle position toutes les 3 images) + Highlight rouge qui pulse | T28, T18 | P0 (existe, à améliorer) |
| Soin | `Heal` | Anneaux dorés qui montent, motes | M04 ×3 qui montent + T30 vert-or | — | P2 |
| Retour à la vie | `Revive` | Pilier de lumière + anneau au sol | M05 + T45 + M04 | — | P2 |
| PERFECT | `Perfect` | Anneau doré qui frappe le rythme + étoile | T08 or + T03 ×6 | — | P1 |
| Étourdissement | état | 3 étoiles qui tournent | T03 sur une orbite (CFrame à chaque image) | T03 | P1 |

### 5.5 Fin de round

| VFX | Look | Méthode | Assets | Priorité |
|---|---|---|---|---|
| K.O. | Ralenti, image d'impact, flash blanc, carte K.O. | §7 : image d'impact 3 images + flash blanc 2 images + carte K.O. ; burst lourd ×2 ; `TimeScale` des émetteurs à 0,3 | carte K.O. (§7.3) | P0 |
| Victoire | L'aura du perso monte une dernière fois, la poussière retombe | T28 burst ×6 + T13 | — | P2 |
| PERFECT (bannière) | Coup de pinceau doré | §9 | — | P1 |

---

## 6. VFX par combattant

Chaque fiche reprend les **éléments du kit** (`KitFX.luau`), puis les moments clés de ses **ultimes**. Le déroulé des ultimes est celui des cinématiques actuelles (`CinematicDirector.luau`, `Finishers.luau`) : les VFX servent la mise en scène qui existe déjà.

Lignes de chaque fiche :
- *Aura* : particules d'ambiance autour du perso en combat (mouvement `rise` = monte, `fall` = tombe, `drift` = flotte, `orbit` = tourne, `flicker` = scintille).
- *Traînée* : ce que laissent ses coups.
- *Impact* : son effet sur la cible.
- *Dash*.
- *Projectile* : son ki-blast.
- *Passif*.
- Puis **R**, **ÉVEIL**, **PORTE**, **FATAL**, **FINISHER**.

### 6.1 KAI 開 — ki

Identité : énergie pure qui monte. Cœur blanc, corps rouge (ou la couleur du skin), crépitements.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Motes de ki qui montent. Jauge pleine : flammes d'aura façon DBZ | T30 (Rate 2) ; T28 en jauge pleine (§5.4) | T28, T30 |
| Traînée `kiStreak` | Traînée blanche à bord rouge sur les poings et les pieds | Trail T15 : `Color` blanc → Énergie, Lifetime 0,12 | T15 |
| Impact `kiPop` | Petite boule de ki qui éclate | Burst T02 + T05 + anneau T08 ; lourd : T06 + mini-dôme M06 | T02, T05, M06 |
| Dash `dust` | Poussière + une image fantôme rouge | §5.2 | — |
| Projectile **KIKOHO** (`kiBall`, fait en 0.35) | Boule 3D : cœur blanc, coque de ki, 3 boucles, étincelles, queue de comète à 2 brins | Existe déjà (`KiBall.luau` + `EffectsController:kiBallDraw`). À améliorer : coque M07 en ForceField avec une texture d'énergie ; boucles en Beams avec la texture « boucle » ci-contre ; queue en Beams T17 (Wrap, TextureSpeed 3) ; charge : motes T30 aspirées (`Inward`) vers les paumes | VFX_KAI_LOOP (512×64 : trait vif avec des trous), T17, T30 |
| Passif RESOLVE | §5.1 RESOLVE | — | — |
| **R — KAIEN RUSH** | Rush, puis la boule grossit entre les paumes (deux montées), puis le KAIENHA (rayon 3D ondulant, 3 brins, bouche). Grade *crimson* | Existe (0.35). À améliorer : corps du rayon en T17 qui coule ; bouche M08 ; brins M09 + T16 ; impact : dôme M06, anneaux T09, rochers M11, fissure T21, fumée T11 en grand, flash blanc 2 images | T17, M08, M09, M06 |
| **ÉVEIL — SCARLET AWAKENING** | Explosion d'aura écarlate, yeux qui brillent, rochers qui se soulèvent lentement | Grade *crimson* ; T28 ×3 en taille ×3 ; anneau T10 au sol ; M11 ×8 qui montent (CFrame à chaque image) ; T03 sur les yeux | T28, M11 |
| **PORTE — 開天 GATE OF HEAVEN** | Sceau 開 sous ses pieds ; une porte céleste s'ouvre (lumière qui jaillit), puis se brise ; dragon de ki en spirale ; éclairs | Sceau : M24 + T27 + kanji ; porte M21 (battants qui tournent) ; T45 en éventail par l'ouverture ; casse : morceaux de M21 + T24 ; dragon M09 + T16 ; éclairs T18 | M21, T27, VFX_KAI_KANJI, T45, M09 |
| **FATAL — 滅 DEAD SKY** | Le ciel s'éteint, des fissures rouges dans le ciel | ColorCorrection sombre + `Lighting.Ambient` rouge ; T25 rouge sur un grand plan derrière | T25 |
| **FINISHER — MAXIMUM KAIENHA** | La boule grossit dans les mains (fait), crépitements, gros plan des paumes ; le rayon enfle ×3,1 et blanchit | Existe (0.34). À améliorer : crépitements T18 autour des mains ; fin : T19 plein écran + flash | T18, T19 |

### 6.2 TARO 火 — feu (boxeur)

Identité : le ring, les flammes, les flashs des photographes.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Braises qui montent ; petites flammes sur les gants | T37 (Rate 4) ; T36 en `LockedToPart` sur chaque gant (Rate 3, petites) | T36, T37 |
| Traînée `fireStreak` | Traînée orange à cœur jaune + braises qui tombent | Trail T15 (FFD45A → Énergie) + T37 ×4 aux images actives | T15, T37 |
| Impact `fireRing` | Anneau de feu + gerbe de flammes | T08 orange + T36 OneShot + T37 ×12 (Drag 8) | T36 |
| Dash `embers` | Traînée de braises + flou de chaleur | T37 en Trail d'émission + T32 très transparent | T32 |
| Projectile (`ball`) | Boule de feu à fumée sombre | M07 Neon + T36 en `LockedToPart` + T37 en traîne + T13 gris foncé | — |
| Mécanique : esquive, Dempsey Roll | Images fantômes orange à gauche et à droite, arcs du ∞ | 2 clones (§5.2) + M01 fins qui suivent le balancement | M01 |
| **R — DEVASTATING RUSH** | Cordes de feu derrière la cible ; flashs des photographes ; le crochet final à travers les cordes | 3 Beams T17 teintés feu sur les lignes des cordes ; flashs : PointLight blanche + T03 à des points au hasard dans le public, 1 image chacun ; dernier coup : impact « ultime » + T36 en éventail | VFX_TARO_ROPE_FIRE (512×64, raccordable) |
| **ÉVEIL — HEAVENLY UPPERCUT** | Cratère de feu, uppercut en colonne de feu, la cible retombe en météore | Anneau de T36 au sol (`Disc`, `Surface`) + T21/T22 orangés ; pilier M05 + T36 ; météore : Trail T16 + T37 ; cratère final : dôme M06 | M05, M06 |
| **PORTE — 火嵐 HOOK STORM** | Un anneau de feu se referme sur les deux combattants ; crochets ; l'anneau explose | Émetteur T36 en `Disc` (rayon de 12 à 6) ; arcs M02 ; fin : burst radial T36 ×40 + T09 | — |
| **FATAL — 終 FINAL BELL** | Le coup de cloche final : onde dorée, projecteur | Anneaux T09 dorés ×3 (2 images d'écart) + SpotLight du haut | — |
| **FINISHER — DEMPSEY ROLL: FINAL ROUND** | ∞ de flammes, flashs, dernier crochet en image d'impact | Arcs M01 en ∞ + flashs (comme R) + image d'impact §7 | — |

### 6.3 ZEPHYR 風 — vent (jambes)

Identité : l'air qu'on voit à peine. Blanc et cyan, très transparent, des lignes plutôt que des masses.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (flotte) | Fines lignes d'air qui tournent autour de lui | 3 Beams courts et courbés T16 (FaceCamera) qui tournent ; T30 rare | T16 |
| Traînée `windCrescent` | Croissant d'air sur chaque coup de pied | M01 / M17 + T14, transparence 0,4 → 1, blanc-cyan | M17, T14 |
| Impact `airBurst` | Anneau en tirets + bouffée en spirale | T10 + T11 blanc (8 images) | T10 |
| Dash `gust` | Lignes de vent horizontales | T20 local (BillboardGui) ou T04 ×10 en `VelocityParallel` | T20 |
| Projectile **WIND BLADE** (`crescent`) | Lame de vent en croissant | M17 Neon cyan + T14 + Trail | M17 |
| Mécaniques : Perfect Rhythm, Sparks, Clash Step | Pulsation dorée sur le temps ; étincelles cyan qui orbitent (les charges) ; anneau blanc + image fantôme au Clash Step | T08 or (Perfect) ; T03 en orbite (une par charge) ; §5.2 | — |
| **R — CUTTING WIND** | Des lames de vent traversent l'arène, se croisent en vortex ; coup de pied volant qui fend l'air | M17 ×N ; vortex : M10 + anneaux M04 empilés qui tournent ; fin : M02 géant + T20 plein écran | M10 |
| **ÉVEIL — RISING DRAGON** | Le vent s'enroule en dragon ; coup montant ; vrille très haut ; plongeon | M09 + T16 (dragon) ; traînée verticale ; M03 en haut | M09 |
| **PORTE — 旋風 RAGING CYCLONE** | Cyclone géant vu de loin ; la cible soulevée ; l'œil de la tempête ; le calme | 3 couches de M10 à des vitesses différentes + T17 ; débris M11 en orbite ; lumière qui tombe dans l'œil (SpotLight + T45) ; fin : T38 et T30 qui tombent doucement | M10, T45 |
| **FATAL — 嵐 MOONFALL** | Une lune énorme ; le coup de pied tombe de la lune | Disque T50 (BillboardGui ou plan) ; croissant M17 géant qui tombe | T50 |
| **FINISHER — GALE EXCALIBUR** | Épée de vent géante (style Vegito), coupe à travers l'écran | Lame : M17 étirée + T17 qui coule ; coupe : M02 plein cadre + T20 | VFX_ZEPHYR_SWORD (mesh) |

### 6.4 AKEMI 影 — ombre (vitesse, esquive)

Identité : de l'encre noire bordée de violet. Rien ne brille sauf le bord.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (flotte) | Volutes noires + motes violets | T29 noir (`LightEmission` 0) + T30 Énergie | T29 |
| Traînée `shadowSlash` | Slash noir à bord violet | Deux couches : M01 noir (SmoothPlastic, `LightEmission` 0) + M01 un peu plus grand en Neon Énergie, transparent | M01 |
| Impact `shadowCross` | X de deux slashes fins + éclaboussure d'encre | 2 × M01 croisés + T44 | T44 |
| Dash `shade` | 2 ou 3 silhouettes d'encre | Clones (§5.2) : Highlight noir, contour Énergie | — |
| Projectile **KUNAI** | Kunai + fine traînée + reflet | M18 + Trail fin + T33 | M18 |
| Passif INSTINCT (esquives, 3 charges) | Image fantôme argentée façon Ultra Instinct ; 3 petites orbes qui tournent autour d'elle (une par charge) | Clone Highlight argent ; 3 T30 en orbite qui se rallument au rechargement | — |
| **R — MANY SHADOWS** | Des clones d'ombre frappent de tous les côtés ; grand X | Clones Highlight noirs + M01 ×12 rapides | — |
| **ÉVEIL — TIME STOP** | Temps arrêté (noir et blanc) ; tableaux figés ; puis toutes les coupes arrivent ensemble | Grade *mono* (`Saturation` -1) ; `TimeScale = 0` sur tous les émetteurs ; anneau T09 « horloge » au départ ; reprise : 12 × M01 qui flashent la même image | — |
| **PORTE — 幻舞 PHANTOM DANCE** | Lumières éteintes ; son sceau brûle sous la cible ; chaque téléportation est un éclair noir ; X géant à travers l'image | Lighting assombri ; sceau M24 + T27 + kanji 影 ; T18 en noir ; X : 2 × M02 géants ou T44 plein écran | VFX_AKEMI_KANJI |
| **FATAL — 刻 STOLEN INSTANT** | L'instant volé : l'image se fissure comme du verre et retombe en éclats | T25 à l'écran + T24 ×30 qui tombent | T25 |
| **FINISHER — THOUSAND SHADOWS** | Des centaines de coupes d'ombre, explosions d'encre | 40 Beams droits très courts, au hasard, chacun 3 images ; T44 ×8 | — |

### 6.5 RYUKEN 拳 — rage (le poing brisé)

Identité : vapeur grise, chaleur rouge, fissures.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Vapeur grise qui monte, chaleur rouge ; vapeur du gantelet | T11 gris 8C8A90 (Rate 2, `LightEmission` 0) + T37 rouges ; T11 sur le gantelet | — |
| Traînée `heatStreaks` | Traînée de chaleur rouge-orange | Trail T15 + T32 très léger | — |
| Impact `rageCrack` | Fissure rouge en étoile sur l'impact + anneau + éclats | T21 (billboard face caméra, rouge, 10 images) + T09 + M11 petits | T21 |
| Dash `scorch` | Trace brûlée au sol + braises | Decal T22 (1 s) + T37 | T22 |
| Projectile **SEISMIC STRIKE** (`wave`) | Une ligne de roche jaillit vers la cible | M11 qui sortent un par un (`rockLine`) + T21 qui avance + T12 | M11 |
| Passif RAGE (0 à 10 charges) | La vapeur et le rouge montent avec les charges ; à 10, des flammes | Rate de T11 = 1 + charges ; Highlight rouge (`FillTransparency` de 1 à 0,65) ; à 10 : T28 | — |
| **R — FIST FURY** | Coups à bout portant face caméra ; rebond ; jonglage ; poing géant de ki ; vapeur du gantelet | Anneaux T09 face caméra à chaque coup ; poing M15 + T17 + bords T28 ; T11 sur le gantelet | M15 |
| **ÉVEIL — COLLAPSE** | Gros plan du gantelet fissuré qui brille ; le sol se fend jusqu'à la cible ; cratère | Lignes Neon sur le gantelet ; fissure : bande de Decals T21 qui avance ; cratère : M06 + M11 | — |
| **PORTE — 拳 LAST ROUND** | Kanji 拳 qui brûle sous lui ; chaque pas fissure le sol ; le dernier coup fait éclater le sol | Sceau + kanji + T36 ; T21 à chaque pas ; fin : T21 ×4 + M11 ×12 + anneau T12 | VFX_RYUKEN_KANJI |
| **FATAL — 砕 WORLD FIST** | Le poing qui brise le monde : l'écran se fissure | M15 géant + T25 + dôme | — |
| **FINISHER — TEN FISTS OF RAGE** | Dix poings de ki géants, un impact chacun | 10 × M15 (pool de 3 réutilisés) + T09 | — |

### 6.6 SHIN 流 — eau (le katana des courants)

Identité : de l'eau qui coupe. Lignes nettes, éclaboussures, ondes.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tombe) | Gouttes qui tombent + ondes à ses pieds | T35 (Rate 1,5) ; T08 à plat au sol | — |
| Traînée (lame) | Ruban d'eau bleu à bord blanc + éclaboussure en fin de coup | Trail base → pointe de la lame (`WeaponSpec`) avec T16 bleu ; T34 à la pointe sur la dernière image active | T16, T34 |
| Impact `bladeLine` | Ligne vive en travers + éclaboussure + gouttes | Beam droit très fin (4 images) + T34 + T35 ×8 | — |
| Dash `ripple` | Ondes au sol + gerbe d'eau | M04 au sol ×2 + T35 | — |
| Projectile **CUTTING CURRENT** (`slash`) | Croissant d'eau qui vole | M17 + T17 qui coule + gouttes | M17, T17 |
| Passif PRECISION (coup de pointe) | Reflet sur la pointe de la lame quand elle touche | T33 + T08 | T33 |
| **R — DANCE OF CURRENTS** | Sillage d'eau en 8 sur le sol ; trombe qui avale la cible ; coupe depuis le ciel ; ondes | Sillage : Beams T17 posés au sol le long du 8 ; trombe : M10 + T17 + T34 ; coupe : Beam vertical ; M04 ×3 | M10 |
| **ÉVEIL — ENDLESS STORM** | Anneaux de courant qui montent ; tempête de coupes ; ligne verticale jusqu'au ciel ; croix de lumière | M04 qui montent ; 20 Beams fins ; Beam vertical géant ; 2 Beams en croix | — |
| **PORTE — 零 ZERO HORIZON** | Kanji 零 sous ses pieds ; une seule ligne d'un bout à l'autre de l'horizon | Sceau + kanji ; Beam blanc à halo bleu sur toute la largeur de l'arène, puis la coupure qui arrive en retard | VFX_SHIN_KANJI |
| **FATAL — 一閃 ISSEN** | Un seul éclair : image d'impact inversée ; il range la lame ; la coupe apparaît | §7 image d'impact + Beam + T34 | — |
| **FINISHER — FINAL DIVISION** | Le monde coupé en deux (l'écran partagé existe) | Écran partagé + T33 sur la ligne + T34 | — |

### 6.7 DAICHA 闇 — vide (l'orbe inversée)

Identité : de la matière noire à reflets violets ; ça aspire avant d'exploser.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tourne) | Particules sombres en orbite + ombre violette sous elle | Émetteur `Sphere`, `Surface`, faible `Speed` ; T29 noir | — |
| L'orbe (son arme) | Sphère noire à bord violet, coque d'énergie | Existe (`OrbFlight`). À améliorer : cœur M07 noir (SmoothPlastic) + coque M07 un peu plus grande en ForceField Énergie + VFX_DAICHA_VOID | VFX_DAICHA_VOID (512, motif de coque raccordable) |
| Traînée (orbe) | Traînée noire à bord violet derrière l'orbe | Trail sur l'orbe, deux couleurs | — |
| Impact `orbBurst` | Matière aspirée, puis éclatement | Particules `Inward` 4 images, puis burst T44 + anneau T08 violet | T44 |
| Dash `warp` + passif INVERTED SHADOW (Blink) | Elle disparaît dans un trou noir et réapparaît | Implosion (`Inward`) + petit disque noir M24 ; à l'arrivée : explosion inverse ; clone en ForceField noir | — |
| Projectile **INVERTED SPHERE** | Sphère noire, anneau de distorsion, matière qui tourne autour | M07 + T32 + T30 noirs en orbite | T32 |
| **R — DARK DOMAIN** | Matière aspirée dans son poing ; sphère, puis disque, puis sphère ; elle perce et éclate | `Inward` ; changement de forme : tween d'échelle de M07 vers un disque aplati ; burst final T44 ×3 | — |
| **ÉVEIL — RIVER OF SHADOWS** | Rivière noire au sol, qui serpente jusqu'à la cible et l'enroule ; vagues ; les gouttes reviennent dans sa main | Beams au sol T17 en noir à reflets violets ; vagues M05 noires ; gouttes T35 noires qui reviennent | — |
| **PORTE — 蝕 TOTAL ECLIPSE** | Disque d'éclipse géant dans le ciel ; pluie de sphères ; sphère géante qui écrase | Disque noir + couronne VFX_COMMON_CORONA ; M07 ×20 avec Trails ; M07 géant ; grade *void* | VFX_COMMON_CORONA (1024 : anneau de couronne solaire) |
| **FATAL — 虚 THE VOID** | Le monde s'inverse ; débris qui flottent | Grade *inverse* (§7.2) + ciel noir ; M11 qui flottent | — |
| **FINISHER — INVERTED WORLD** | Caméra à l'envers, monde inversé, sphère géante | Grade *inverse* + M07 géant + T44 | — |

### 6.8 HIBECARES 崩 — pierre (le roi des ruines)

Identité : le poids. Peu d'effets, mais énormes ; poussière, roche, braises dans les fissures.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (flotte) | Poussière + petits cailloux en orbite lente ; braises en skin MAGMA | T23 + T30 B8A890 ; T37 en MAGMA | T23 |
| Traînée `stoneWeight` | Arc lourd, traînée de poussière | Trail épais couleur pierre + T12 | — |
| Impact `rubble` | Rochers qui éclatent + poussière + fissure | M11 ×4 avec gravité + T12 + T21 | M11 |
| Dash `tremor` | Le sol tremble, vague de poussière | M04 au sol + T12 + petits M11 qui rebondissent | — |
| Projectile (`ball`) | Rocher lancé + traînée de poussière | M11 grand + T12 | — |
| Passif KING OF RUINS | Les fissures sous ses pieds grandissent quand sa vie baisse ; des braises en sortent | Decal T21 sous lui (taille et opacité suivent la vie perdue) + T37 | — |
| **R — AWAKENED COLOSSUS** | Anneau de pierre ; chaque pas lève une ligne de roche ; cratère vu du dessus | M12 qui sortent en anneau ; `rockLine` M11 ; cratère T21 + M06 | M12 |
| **ÉVEIL — PUNISHMENT** | Le sol se fend jusqu'à la cible ; il la frappe au sol de chaque côté ; un anneau de roche jaillit dessous | Decals T21 en ligne + lueur T37 ; T12 à chaque coup ; M14 en anneau | M14 |
| **PORTE — 崩 RUIN OF THE WORLD** | Anneaux de piliers qui jaillissent puis s'effondrent ; pluie de pierres ; le monde se brise | M12 ×12 ; M11 qui tombent ; fissures partout + grade *ruin* | — |
| **FATAL — 墓 TOMB OF KINGS** | Des dalles se referment en tombeau | 4 plaques (Parts) qui se ferment + T12 | — |
| **FINISHER — THRONE OF RUINS** | Un trône de roche s'élève, il s'assoit | Mesh trône (VFX_HIBECARES_THRONE) + T12 + T23 | VFX_HIBECARES_THRONE |

### 6.9 RAIJIN 雷 — foudre (la lance)

Identité : ça scintille, ça saute, ça claque. Images d'éclairs, jamais lisses.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (scintille) | Arcs électriques qui sautent sur le corps | 4 Beams T18 courts entre des Attachments au hasard, nouvelle position toutes les 3 images ; T04 jaunes | T18 |
| Traînée `spearBolt` | Ruban électrique sur la lance, arcs qui suivent | Trail base → pointe T18 + 2 Beams qui sautent | — |
| Impact `thunderStrike` | Petit éclair qui part de l'impact, flash | Beam T18 de l'impact vers le haut (4 images) + PointLight qui clignote (on/off/on) | — |
| Dash `sparks` | Étincelles + image fantôme jaune | T04 ×12 + clone | — |
| Projectile **LIGHTNING SPEAR** (`bolt`) | Lance de lumière entourée d'éclairs | M19 Neon + 3 Beams T18 autour + PointLight | M19 |
| Passif OVERCHARGE (tous les 3 coups) | La lance s'illumine et crépite ; 3 pastilles qui se remplissent | Highlight sur la lance + Beams T18 ; 3 T30 au-dessus de l'épaule | — |
| **R — THOUSAND BOLTS** | Chaque estoc est une ligne d'éclair | Beams T18 droits | — |
| **ÉVEIL — THUNDER JUDGMENT** | La tempête frappe du haut : nuages sombres, éclairs du ciel | T49 gris foncé en haut ; chaînes de Beams T18 du ciel au sol ; grade *storm* | T49 |
| **PORTE — 雷神 DIVINE WRATH** | Piliers de foudre sur la cible ; anneau de tambours taiko derrière lui (l'image du dieu Raijin) | M05 + T18 ; 8 disques VFX_RAIJIN_DRUM en anneau, qui s'allument tour à tour | VFX_RAIJIN_DRUM (512 : tambour vu de face, sans texte) |
| **FATAL — 天罰 HEAVENLY SENTENCE** | Des éclairs de tous les côtés convergent sur la cible | 12 chaînes T18 qui se rejoignent + dôme blanc | — |
| **FINISHER — SPEAR OF THE THUNDER GOD** | Lance géante lancée du ciel | M19 géant + T17 + T18 + cratère | — |

### 6.10 YUKINA 雪 — glace (les éventails)

Identité : cristal, givre, flocons. Bleu très pâle et blanc, facettes nettes.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tombe) | Flocons + souffle de givre | T40 (Rate 3) + T29 blanc | T40 |
| Traînée `fanArcs` | Arcs de givre bordés de petits cristaux | M01 + T14 glacé + T24 ×4 sur le bord | — |
| Impact `iceShards` | Éclats de glace + anneau de givre + bouffée de neige | M13 ×5 + T08 + T11 blanc | M13 |
| Dash `frost` | Plaque de givre au sol qui s'efface + neige | Decal VFX_YUKINA_FROST_PATCH + T40 | VFX_YUKINA_FROST_PATCH (512) |
| Projectile **ICE SHARDS** | 3 éclats + traînée | M13 ×3 + Trail | — |
| Passif DEEP FREEZE (`Chilled`, 1 à 3 charges, ralentit) | Givre sur la cible ; à 3 charges, une gangue de glace aux pieds | Highlight bleu (`FillTransparency` 0,85 → 0,6) ; M13 aux pieds à 3 charges ; T40 | — |
| **R — ICE GARDEN** | Un jardin de pics de glace jaillit ; la cible prise dans un bloc de glace | M14 Glass qui poussent ; bloc : Part en Glass autour de la cible | — |
| **ÉVEIL — WINTER WALTZ** | Éclats de glace tirés de loin ; fleurs de givre | M13 ; « fleurs » : M14 en couronne ; grade *frost* | — |
| **PORTE — 氷獄 ETERNAL PRISON** | Marionnette sur des fils de givre ; prison de piliers de glace | Beams blancs très fins ; M14 en cercle | — |
| **FATAL — 絶対零度 ABSOLUTE ZERO** | Tout gèle, givre sur les bords de l'écran, puis tout éclate | Grade *frost* + VFX_YUKINA_SCREEN_FROST (1024, givre sur les bords, centre vide) ; éclatement : T24 ×40 | VFX_YUKINA_SCREEN_FROST |
| **FINISHER — FROZEN REQUIEM** | Cercueil de glace, puis il éclate en neige | Part Glass + M13 ; T40 ×60 | — |

### 6.11 VENOM 毒 — poison

Identité : vert acide, bulles, gouttes, vapeur.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Bulles toxiques + vapeur verte | T41 + T11 vert (`LightEmission` 0,3) | T41 |
| Traînée `fangSwipe` | Griffures vertes + gouttes | M16 ou T47 + T35 vert | T47 |
| Impact `toxicSplash` | Éclaboussure verte + bulles + grésillement | T34 vert + T41 ×6 | — |
| Dash `venomTrail` | Flaque toxique au sol + vapeur | Decal VFX_VENOM_PUDDLE (1 s) + T11 | VFX_VENOM_PUDDLE (512) |
| Projectile **TOXIC MIST** (`cloud`) | Nuage lent, bulles dedans | T11 vert ×10 en `LockedToPart` + T41 | — |
| Passif CONTAMINATION (`Poison`, 1 à 3 charges) | Teinte verte qui pulse sur la cible, bulles, gouttes (existe : `KitFX.POISON`) | Garder les réglages actuels (bulles 4/8/14 par s, gouttes 1,5/3/5) ; remplacer les sprites par T41 et T35 vert | — |
| **R — FATAL BITE** | Le prédateur sort de l'ombre : yeux qui luisent, morsure de crocs | 2 T03 verts (les yeux) dans le noir ; crocs : 2 × M01 qui se referment | — |
| **ÉVEIL — EPIDEMIC** | La cible titube ; veines vertes qui se répandent | Highlight vert ; Decals de veines VFX_VENOM_VEINS ; grade *toxic* | VFX_VENOM_VEINS (512) |
| **PORTE — 毒王 VENOM KING** | Bonds de tous les côtés ; une silhouette de cobra en fumée derrière lui | Clones verts ; T11 vert foncé + VFX_VENOM_COBRA (silhouette) | VFX_VENOM_COBRA (1024) |
| **FATAL — 蝕 TOTAL CORROSION** | Pluie acide ; éclaboussures qui grésillent | T04 verts qui tombent (`VelocityParallel`) + T34 au sol + Decals de flaques | — |
| **FINISHER — TOXIC FEAST** | Le nuage forme une gueule de serpent qui avale la cible | T11 ×40 en forme de gueule (positions scriptées) + VFX_VENOM_COBRA | — |

### 6.12 GORAN 剛 — titan (le lutteur)

Identité : la masse ; le ring qui saute ; poussière et ondes au sol.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (flotte) | Poussière lourde, chaleur | T23 + T32 léger | — |
| Traînée `titanStomp` | Onde au sol sur les coups lourds | M04 à plat + T12 | — |
| Impact `quake` | Fissure + poussière + débris qui sautent | T21 + T12 + M11 | — |
| Dash `stomp` | Poussière à chaque pas | T13 | — |
| Projectile **TITAN'S HUG** | Onde de choc de l'étreinte | M04 vertical + T09 | — |
| Passif ANCHOR (armure sur les coups lourds) | Flash d'armure + ancre lumineuse sous les pieds | §5.1 Armure + Decal VFX_GORAN_ANCHOR | VFX_GORAN_ANCHOR (512) |
| **R — APOCALYPSE SUPLEX** | Suplex d'un côté à l'autre ; anneau géant au sol ; séisme | M04 géant (`titanRing`) + T21 + T12 | — |
| **ÉVEIL — SPINE BREAKER** | Ses frappes au sol font sauter tout le ring | M04 + T12 sur toute la largeur | — |
| **PORTE — 巨神 FALL OF THE TITAN** | La cible lancée au ciel, puis elle retombe en météore | Trail T16 + T37 ; cratère M06 ; grade *titan* | — |
| **FATAL — 終幕 FINAL THROW** | Le grand balancement : traînée circulaire, tornade de poussière | M03 + T12 en `Cylinder` | — |
| **FINISHER — TITAN QUAKE** | Une fissure traverse toute l'arène | Bande de Decals T21 + M11 ×20 + T12 | — |

### 6.13 ASTER 星 — gravité

Identité : espace, étoiles, anneaux qui se resserrent ; le noir au centre.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tourne) | Petites étoiles en orbite + anneaux | T03 petits en orbite + M04 fin | — |
| Traînée `gravityRings` | Anneaux concentriques qui se resserrent | M04 ×3, échelle de 1,5 à 0,5 | — |
| Impact `implode` | Aspiration, puis éclat | Particules `Inward` + anneau qui rétrécit, puis T05 | — |
| Dash `float` | Glissé en apesanteur + poussière d'étoiles | T30 + T03 | — |
| Projectile **PULL** (`well`) | Puits de gravité : sphère noire + disque d'accrétion | M07 noir + M04 avec T17 en spirale + `Inward` + T32 | — |
| Passif SHIFTING MASS | La cible plus légère ou plus lourde : anneaux au-dessus d'elle (légère) ou en dessous (lourde) | M04 fins qui montent ou descendent | — |
| **R — DEADLY ORBIT** | La cible flotte plus haut à chaque coup ; traces d'orbite | Beams en ellipse T16 | — |
| **ÉVEIL — STELLAR COLLAPSE** | Il tourne autour d'elle ; ellipses | Beams en orbite + T03 | — |
| **PORTE — 重力 EVENT HORIZON** | Trou noir : sphère noire, disque d'accrétion qui tourne, anneau de lentille, étoiles aspirées | M07 noir + M04 T17 + T32 + T30 `Inward` ; grade *cosmos* | — |
| **FATAL — 星葬 COSMIC FUNERAL** | Des étoiles filantes tombent de tous les côtés | M07 petits + Trails T16 + impacts T05 | — |
| **FINISHER — STELLAR COLLAPSE** | Une étoile s'effondre, puis supernova | M07 qui rétrécit, puis dôme M06 + T09 ×3 + flash | — |

### 6.14 HIBIKI 響 — son

Identité : le rythme. Tout pulse sur le temps ; anneaux, ondes, notes.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (flotte) | Notes de musique + anneaux qui pulsent sur le temps | T42 + T08 toutes les 0,5 s | T42 |
| Traînée `soundRipples` | Ondulations le long du coup | T08 ×3 en ligne | — |
| Impact `soundBurst` | Anneaux concentriques en rafale, comme une enceinte | M04 ×3 décalés de 2 images | — |
| Dash `beat` | Un anneau à chaque pas | T08 au sol | — |
| Projectile **SONIC WAVE** (`pulse`) | Arcs qui s'élargissent, l'un après l'autre | M02 ×3 en série | — |
| Passif TEMPO (enchaînement en rythme) | Indicateur de rythme ; quand TEMPO est actif, tout pulse | Anneau T08 au rythme ; légère pulsation du FOV de la caméra (cosmétique) | — |
| **R — BRUTAL SYMPHONY** | La cible saute sur son rythme | `beatRing` M04 à chaque temps | — |
| **ÉVEIL — FORBIDDEN FREQUENCY** | Ondes de tous les côtés | M04 qui arrivent de partout ; grade *sonic* | — |
| **PORTE — 絶響 LAST RESONANCE** | Un mur de son qui avance | Mesh VFX_HIBIKI_SOUNDWALL (paroi ondulée) + T17 | VFX_HIBIKI_SOUNDWALL |
| **FATAL — 無音 ABSOLUTE SILENCE** | Plus aucun son, image désaturée ; les anneaux se figent, puis se brisent | Grade *mono* ; `TimeScale` 0 ; T24 | — |
| **FINISHER — RESONANCE** | Toute l'arène vibre | Secousse longue + M04 partout + T08 | — |

### 6.15 KAZAN 鎖 — acier (griffes jumelles, chaînes)

Identité : métal froid, étincelles chaudes, chaînes.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (scintille) | Étincelles métalliques orange + reflets de chaîne | T04 orange (Rate 1,5) + T33 | — |
| Traînée `tripleClaw` | Trois griffures parallèles, acier blanc + étincelles | M16 + T04 orange | M16 |
| Impact `clawMarks` | Griffures sur la cible + étincelles | T47 en billboard + T04 ×10 | T47 |
| Dash `chain` | Une chaîne qui traîne | Beam T46 (Wrap) | T46 |
| Projectile **SHACKLE HOOK** | Crochet + chaîne jusqu'à son poignet | Mesh VFX_KAZAN_HOOK + Beam T46 | VFX_KAZAN_HOOK |
| Passif SHACKLED | Une chaîne le relie à la cible, un anneau à sa cheville | Beam T46 + M04 petit | — |
| **R — PREDATOR'S FEAST** | Il tourne autour de la proie et la griffe à chaque passage | M16 ×N + T04 | — |
| **ÉVEIL — IRON FANGS** | Les griffes saisissent et écrasent | M16 géant (`clawBurst`) + T21 | — |
| **PORTE — 鎖獄 CLAW PRISON** | Cage de chaînes | 12 Beams T46 en cage ; grade *iron* | — |
| **FATAL — 断罪 FINAL VERDICT** | Accrochée et traînée ; griffure-guillotine | Beam T46 + M16 vertical géant | — |
| **FINISHER — CAGE OF CLAWS** | Une cage de griffes géante se referme | M16 ×8 qui se referment | — |

### 6.16 KUREN 血 — sang (la vampire)

Identité : cramoisi profond, cristaux, pétales, chauves-souris. **Stylisé, jamais réaliste.**

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tombe) | Gouttes ou pétales cramoisis qui tombent | T35 / T39 teintés 8A0A1A → Énergie | — |
| Traînée `bloodCrescent` | Croissant à cœur sombre et bord rouge vif | M01 en deux couches (comme AKEMI) | — |
| Impact `bloodBloom` | Une fleur cramoisie éclôt | T39 ×12 en couronne + T02 | — |
| Dash `mist` | Brume rouge + petites chauves-souris qui s'envolent | T11 rouge + VFX_KUREN_BAT_2x2 (Random) | VFX_KUREN_BAT_2x2 |
| Projectile **BLOOD LANCE** | Lance de cristal cramoisi | M20 (Glass rouge) + Trail | M20 |
| Passif SCARLET PACT (elle paie en vie, frappe plus fort) | Veines cramoisies, aura qui aspire | Highlight rouge léger + T30 `Inward` vers elle | — |
| **R — SCARLET RAIN** | Pluie cramoisie sur la cible | T04 rouges qui tombent + T34 au sol | — |
| **ÉVEIL — FORBIDDEN PACT** | Des lances de tous les côtés | M20 ×12 | — |
| **PORTE — 血王 BLOOD THRONE** | Elle sort du noir ; flaque cramoisie brillante au sol ; trône de cristaux | Decal VFX_KUREN_POOL + M14 rouges ; grade *blood* | VFX_KUREN_POOL (512) |
| **FATAL — 血月 BLOOD MOON** | Lune rouge dans le ciel ; une lance la traverse | T50 rouge ; M20 géant | — |
| **FINISHER — CRIMSON COVENANT** | Sceau cramoisi + lances de cristal | T27 rouge + M20 ×8 | — |

### 6.17 SYLVA 森 — nature (la chasseresse)

Identité : feuilles, lianes, racines, épines ; vert vivant (rose en BLOSSOM).

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (tombe) | Feuilles (pétales en BLOSSOM) qui flottent | T38 / T39 (Rate 2, RotSpeed au hasard) | T38, T39 |
| Traînée `vineWhip` | Traînée de liane verte + feuilles | Trail VFX_SYLVA_VINE + T38 | VFX_SYLVA_VINE (256×64) |
| Impact `leafBurst` | Gerbe de feuilles + anneau vert | T38 ×14 + T08 | — |
| Dash `petals` | Traînée de pétales | T39 | — |
| Projectile **HUNGRY ROOTS** (`trap`) | Piège de racines qui sort du sol et se referme | M23 ×4 qui sortent et se courbent | M23 |
| Passif TERRITORY (zone de 12 studs) | Un anneau d'herbe et de fleurs au sol autour d'elle | Decal VFX_SYLVA_TERRITORY (1024, anneau) sur M24 | VFX_SYLVA_TERRITORY |
| **R — HOSTILE FOREST** | Les racines soulèvent la proie | M23 qui montent | — |
| **ÉVEIL — WILD GRASP** | Les lianes la tirent vers elle | Beams VFX_SYLVA_VINE | — |
| **PORTE — 森王 BRAMBLE DOMAIN** | Épines de tous les côtés | M14 verts (`thornBurst`) ; grade *wild* | — |
| **FATAL — 世界樹 THE LAST TREE** | Un arbre géant pousse et cloue la cible | Mesh VFX_SYLVA_TREE (tronc + couronne) qui grandit + T38 ×80 | VFX_SYLVA_TREE |
| **FINISHER — THE GREAT HUNT** | La chasseresse sort des feuilles ; des bêtes spectrales faites de feuilles | T38 en masse + silhouettes VFX_SYLVA_BEAST | VFX_SYLVA_BEAST (1024) |

### 6.18 ELIAN 癒 — lumière (le guérisseur)

Identité : or pâle, halos, piliers, plumes de lumière.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Motes de lumière + halo discret au-dessus de la tête | T30 + M04 fin au-dessus de la tête | — |
| Traînée `lightPalm` | Empreinte lumineuse de paume | T02 + T03 + T08 | — |
| Impact `halo` | Anneau de halo + plumes | T08 or + VFX_ELIAN_FEATHER ×6 | VFX_ELIAN_FEATHER (256) |
| Dash `glow` | Traînée de lumière | Trail T15 + T30 | — |
| Projectile **RAY** (`ball`) | Orbe de lumière, rayons | M07 + T45 en étoile | — |
| Passif SECOND WIND (sous 30 % de vie : `Heal`, `Revive`) | Pilier de lumière + anneaux | §5.4 | — |
| **R — REBIRTH** | Piliers de lumière sur la cible | M05 + T45 (`lightPillar`) | — |
| **ÉVEIL — PURIFICATION** | La cible tenue par un sceau de lumière | T27 or au sol + Beams « chaînes de lumière » | — |
| **PORTE — 神癒 DIVINE MIRACLE** | Le carillon de lumière : anneaux, la cible saute à chaque coup | M04 ; grade *holy* | — |
| **FATAL — 天光 LAST LIGHT** | Un rayon de soleil tombe du ciel | M05 géant + T45 + flash | — |
| **FINISHER — FINAL MERCY** | Des ailes de lumière enveloppent la cible | M25 ×2 (Neon or, transparent) + plumes | M25 |

### 6.19 NOVA 機 — tech (l'ingénieure)

Identité : hologrammes, glitch, propulseurs, lasers.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (scintille) | Lignes d'hologramme, petites étincelles | VFX_NOVA_SCANLINE (Beam vertical qui défile) + T04 | VFX_NOVA_SCANLINE (256×256, raccordable) |
| Traînée `pistonPunch` | Jet de vapeur du piston + bouffée à l'extension | T11 blanc ×2 + T09 petit | — |
| Impact `glitch` | Carrés de glitch + anneau cyan | T48 ×10 (Random) + T08 | T48 |
| Dash `thrusters` | Jets de flamme bleue (dos, pieds) | T36 cyan en `LockedToPart` + Trail | — |
| Projectile **DRONE SHOT** (`bullet`) | Les drones tirent des traits laser | M22 + Beam court + éclair de bouche T03 | M22 |
| Passif ENGINEERING (2 charges de drone) | Drone qui se déploie en hologramme ; anneau de recharge | M22 en ForceField + T43 | T43 |
| **R — SATURATION** | Les drones tirent de tous les côtés | 8 × M22 + Beams laser | — |
| **ÉVEIL — OMEGA PROTOCOL** | Rayon orbital : réticule au sol, puis rayon vertical géant | Decal VFX_NOVA_RETICLE + M05 + T17 cyan | VFX_NOVA_RETICLE (1024, sans texte) |
| **PORTE — 機神 MECHANICAL ARMY** | Barrage de missiles venu du ciel | Petits meshes + Trails de fumée T13 + impacts T06 | VFX_NOVA_MISSILE (mesh) |
| **FATAL — 終焉 PROGRAMMED EXTINCTION** | Mitrailleuse des gantelets ; l'image se « bugge » | Flashs de bouche T03 + T48 plein écran | — |
| **FINISHER** | *Pas encore créé* (reste le fatal classique). Idée : un mécha | — | — |

### 6.20 KUROEN 蝕 — éclipse (l'empereur)

Identité : rouge et noir, courts et brutaux.

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Flammes noires à bord rouge | T28 noir (`LightEmission` 0) + T28 rouge Neon un peu plus grand derrière | — |
| Traînée `eclipseStreak` | Traînée noire à bord rouge | Trail en deux couches | — |
| Impact `eclipseBurst` | Éclat de sphère noire + anneau de couronne rouge | M07 noir + VFX_COMMON_CORONA rouge | — |
| Dash `redShade` | Image fantôme rouge et noire | Clone | — |
| Projectile **ECLIPSE BREAKER** (`eclipse`) | Disque d'éclipse : noir + couronne rouge | M24 noir + couronne | — |
| Passif DOMINATION (3 charges, pas de l'empereur) | 3 marques rouges qui s'allument dans son dos ; à III, l'aura change | 3 T02 rouges (BillboardGui) ; à III : T28 ×2 | — |
| **R — EMPEROR RUSH** | Coups de tous les côtés, de plus en plus vite | M01 rouge et noir ×N | — |
| **ÉVEIL — ZERO ABSOLU: ECLIPSE** | La lumière s'éteint, éclipse rouge dans le ciel, il frappe depuis le noir | Lighting à 0 + couronne géante | — |
| **PORTE — 皇 EMPEROR'S GATE** | Une tempête de poings | Anneaux T09 face caméra en rafale | — |
| **FATAL — 蝕 TOTAL ECLIPSE** | Le dernier coup sous l'éclipse | Couronne + dôme noir | — |
| **FINISHER** | *Pas encore créé* | — | — |

### 6.21 ASURA (boss) — l'or à quatre bras

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Flammes dorées + rouge (Rate 3) | T28 or + T37 rouges | — |
| Traînée `fourArms` | Quatre traînées dorées, une par bras | 4 Trails T15 (deux sur les bras de `FourArms`) | — |
| Impact `goldenFists` | Empreinte de poing dorée | VFX_ASURA_FIST (256, poing vu de face) + T09 or | VFX_ASURA_FIST |
| Dash `goldShade` + passif ASURA'S WRATH (armure en dash) | Image fantôme dorée + flash d'armure | Clone + §5.1 Armure | — |
| **PORTE — 阿修羅 WRATH OF THE FOUR ARMS** | Mille poings ; une roue de halo enflammée derrière lui (comme une statue d'Asura) | VFX_ASURA_FIST en rafale + M04 géant + T28 sur son bord | — |
| R, ÉVEIL | Il utilise les coups de KAI : ce sont ceux de KAI, en or | — | — |

### 6.22 KUROEN SHIN (boss) — le vrai empereur, blanc et or

| VFX | Look | Méthode | Assets |
|---|---|---|---|
| Aura (monte) | Flammes blanches + motes dorés, très dense (Rate 4) | T28 blanc + T30 or | — |
| Traînée `divineStreak` | Traînée blanc-or | Trail T15 | — |
| Impact `divineBurst` | Éclat blanc + anneau doré + plumes de lumière | T06 + T08 or + VFX_ELIAN_FEATHER | — |
| Dash `goldShade` | Téléportation instantanée : images fantômes blanches | Clones ×3 | — |
| Passif TRUE DOMINATION | Comme KUROEN, en or | — | — |
| **PORTE — 真 TRUE EMPEROR** | Il tourne autour de la cible plus vite que l'œil ; pilier de lumière | Anneau d'images fantômes + M05 + T45 | — |
| R, ÉVEIL, FATAL | La cible tirée de loin ; tempête de poings et d'images fantômes ; pilier de lumière du ciel | Clones + T09 + M05 | — |

---

## 7. Cinématiques et effets d'écran

### 7.1 Effets d'écran

| Effet | Usage | Méthode | Assets |
|---|---|---|---|
| Bandes noires (letterbox) | Toutes les cinématiques | 2 Frames noires, tween de hauteur (existe) | — |
| Lignes de vitesse radiales | Charges, gros plans d'ultime | ImageLabel plein écran, flipbook UI T19 à 24 fps, `ImageTransparency` 0,3 | T19 |
| Lignes de vitesse linéaires | Dash d'ultime, coups traversants | T20, tourné dans le sens du mouvement | T20 |
| Image d'impact | Coup final, K.O., ISSEN | Frame plein écran noire + Highlight blanc `AlwaysOnTop` (`FillTransparency` 0) sur les deux rigs, 2 ou 3 images ; variante : fond blanc + silhouettes noires | — |
| Flash blanc | Gros impacts | Frame blanche, 1 ou 2 images, puis fondu en 6 images (≤ 3 par seconde) | — |
| Teinte (tint) | Ambiance de plan | Frame de couleur à 0,85 de transparence | — |
| Vitre brisée | FATAL | T25 qui apparaît d'un coup et tombe en 20 images | T25 |
| Vignette | Super flash, ultimes | T26 | T26 |
| Écran partagé | FINAL DIVISION | Existe ; ajouter T33 sur la ligne | — |
| Secousse | Partout | Existe (réduite en mode réduit) | — |

### 7.2 Grades de couleur (ColorCorrectionEffect)

Réglages de départ, à ajuster à l'œil. TintColor en hexadécimal ; Saturation, Contraste et Luminosité vont de -1 à 1.

| Grade | Perso, moment | TintColor | Saturation | Contraste | Luminosité |
|---|---|---|---|---|---|
| crimson | KAI | FFC8C8 | 0,15 | 0,2 | -0,05 |
| void | DAICHA, KAI | D8C8FF | -0,35 | 0,25 | -0,12 |
| mono | AKEMI TIME STOP, HIBIKI silence | FFFFFF | -1 | 0,3 | 0 |
| fire | TARO | FFD8B0 | 0,2 | 0,15 | 0 |
| sky | ZEPHYR | D8F4FF | 0,05 | 0,05 | 0,05 |
| shadow | AKEMI | C8B8E0 | -0,3 | 0,3 | -0,15 |
| rage | RYUKEN | FFB8A8 | 0,1 | 0,3 | -0,05 |
| current | SHIN | C8E8FF | 0 | 0,15 | 0 |
| inverse | DAICHA (Roblox ne sait pas inverser les couleurs : on s'en approche) | B8A0FF | -0,8 | 0,5 | -0,2 |
| ruin | HIBECARES | E8D8C0 | -0,25 | 0,2 | -0,05 |
| storm | RAIJIN | D0D8FF | -0,2 | 0,3 | -0,1 |
| frost | YUKINA | D8F0FF | -0,3 | 0,1 | 0,08 |
| toxic | VENOM | D8FFC0 | 0 | 0,2 | -0,05 |
| titan | GORAN | FFE0C8 | -0,1 | 0,25 | 0 |
| cosmos | ASTER | C8C0FF | -0,2 | 0,3 | -0,15 |
| sonic | HIBIKI | FFD0F0 | 0,1 | 0,15 | 0 |
| iron | KAZAN | E0E0E8 | -0,5 | 0,3 | -0,05 |
| blood | KUREN | FFB0B8 | -0,1 | 0,3 | -0,12 |
| wild | SYLVA | D8FFC8 | 0,15 | 0,1 | 0 |
| holy | ELIAN | FFF4D0 | 0 | 0,05 | 0,1 |

À chaque grade, monter aussi le **Bloom** (`Intensity` 0,8) et baisser un peu `Lighting.ExposureCompensation` (-0,2) pour que les effets ressortent.

### 7.3 Cartes et titres

| Élément | Méthode | Assets |
|---|---|---|
| Carte **K.O.** | ImageLabel : échelle de 1,4 à 1 en 4 images (ease-out), secousse, éclaboussure d'encre rouge derrière. « K.O. » reste du texte du jeu (traduit), posé sur un fond pinceau | VFX_UI_KO_BRUSH (1024×512 : coup de pinceau rouge et noir, sans lettres) |
| **Sceaux de kanji** (9 cinématiques) | Plan M24 au sol, T27 qui tourne lentement, kanji au centre ; il apparaît en 6 images, brûle (T36 sur le bord), puis s'efface | T27 + un kanji par perso |
| **Kanji** | ⚠️ Les IA d'images écrivent mal les kanji. Méthode sûre : une police pinceau sous licence libre (par exemple Yuji Boku, Google Fonts, licence OFL), rendue en PNG blanc 1024, puis retouchée (éclaboussures, traînées de pinceau). Les kanji sont aujourd'hui affichés en texte : la texture est une amélioration | VFX_<PERSO>_KANJI : 開 火 風 影 拳 流 闇 崩 雷 雪 毒 剛 星 響 鎖 血 森 癒 機 蝕 阿修羅 真 |
| Kanji des ultimes et des FATAL (option) | Même méthode, pour les titres des cinématiques | 開天 火嵐 旋風 幻舞 零 蝕 雷神 氷獄 毒王 巨神 重力 絶響 鎖獄 血王 森王 神癒 機神 皇 · 滅 終 嵐 刻 砕 一閃 虚 墓 天罰 絶対零度 終幕 星葬 無音 断罪 血月 世界樹 天光 終焉 |
| Pas de nom d'attaque crié à l'écran | Wilhem : « il doit pas dire kamehameha ». Les titres restent sobres (le nom de l'ultime en petit, en bas) | — |

---

## 8. Arènes (6 cartes)

Le sol de combat (y = 0, x de -28 à 28) ne change jamais : ces effets sont du **décor**. Ils tournent en boucle et coûtent peu (≤ 80 particules par arène). Les gros coups peuvent y laisser une trace (fissure, éclaboussure), qui s'efface en 2 s.

| Arène | Ambiance | Réaction aux gros coups | Méthode | Assets |
|---|---|---|---|---|
| **SCARLET TEMPLE 寺** | Feuilles d'érable rouges qui tombent, lanternes qui vacillent, fumée d'encens | Les feuilles au sol s'envolent | T38 rouge (Rate 3, vent latéral) ; PointLights à `Brightness` aléatoire (±15 %) ; T11 fin et lent ; burst T38 à l'impact | T38 |
| **FROZEN LAKE 氷** | Neige, buée, aurore boréale dans le ciel | La glace se fissure | T40 ; T11 blanc devant la bouche des persos ; aurore : 3 Beams très larges en dégradé vert-violet, TextureSpeed 0,1 ; Decal T21 bleu-blanc | T40, T21 |
| **NEON ROOFTOP 街** | Pluie, éclaboussures, enseignes néon qui clignotent (des symboles, pas de texte), vapeur des bouches d'aération | Gerbe d'eau au sol | T04 en pluie (`VelocityParallel`) ; T34 minuscules au sol ; Neon qui clignote ; T11 | T04, T34 |
| **VOLCANO FORGE 炎** | Braises qui montent, cendre qui tombe, lueur de lave qui pulse, chaleur | Gerbe d'étincelles | T37 ; T23 gris ; PointLights orange qui pulsent ; T32 qui monte, très transparent | T37, T32 |
| **BAMBOO DOJO 竹** | Feuilles de bambou, rayons de lumière, lucioles, poussière dans la lumière | Feuilles qui tombent du haut | T38 vert ; Beams T45 en biais ; T30 qui clignotent | T38, T45 |
| **CLOUD PALACE 天** | Mer de nuages, rayons divins, vent, oiseaux au loin, pétales dorés | Les nuages proches se dispersent | T49 en grands BillboardGui lents ; T45 ; T20 très léger ; oiseaux VFX_MAP_BIRD_2x2 ; T39 or | T49, VFX_MAP_BIRD_2x2 |

---

## 9. Interface, menus, boutique

Rappel de Wilhem : le menu doit avoir un caractère de **jeu de combat**, pas de jeu mobile. Effets **brefs et nets** : coups de pinceau, encre, éclats. Pas de confettis ni de rebonds mous.

| VFX | Où | Méthode | Assets |
|---|---|---|---|
| **Auras de la boutique** (cosmétiques, en combat) | FROST, EMBER, SHADOW, SAKURA, VOID, VIP GOLD | Aujourd'hui, seules les couleurs changent. Donner à chaque aura **sa texture** : FROST = T40 + T24 ; EMBER = T37 + T36 ; SHADOW = T29 noir + T44 ; SAKURA = T39 ; VOID = VFX_SHOP_CUBE (petits cubes) + T29 ; VIP GOLD = T03 + T28 or + motes | VFX_SHOP_CUBE (256) |
| **Aperçu des auras** dans la boutique | Page SHOP | Le ViewportFrame n'affiche pas les particules : faire un **flipbook UI** 4×4 de chaque aura, en boucle derrière le perso | VFX_SHOP_AURA_<NOM>_4x4 ×6 |
| Skins GOLD | Combat et boutique | Un reflet T03 de temps en temps sur le corps + l'aura dorée ; en boutique, `UIGradient` qui balaie la carte | — |
| Choix du perso | Écran de sélection | Coup de pinceau d'encre qui balaie le portrait (flipbook UI) ; à la validation, éclat + T33 | VFX_UI_INK_WIPE_4x4 |
| Écran VS | Avant le combat | Diagonale coupée + éclair T18 + secousse | — |
| Montée ou baisse de rang (Elo) | Fin de match classé | Pilier de lumière UI + reflet `UIGradient` sur le badge | — |
| Pièces gagnées | Fin de match | Les pièces volent jusqu'au compteur (tween sur une courbe), petit éclat | — |
| Quête, succès | Notification | Bandeau qui glisse + reflet | — |
| Champion de la semaine | Hub | Couronne qui brille au-dessus du joueur (BillboardGui) + motes dorés T30 | — |
| PERFECT | Fin de round | Coup de pinceau doré derrière le mot | VFX_UI_GOLD_BRUSH |
| READY / FIGHT | Début de round | Fond pinceau ; le texte reste du texte du jeu (traduit) | VFX_UI_KO_BRUSH (réutilisé) |
| Barre de vie | Combat | Perte blanche, puis rouge (existe) ; flash à FATAL prêt (existe) | — |
| Compteur de combo | Combat | Échelle qui « frappe » (1,3 → 1 en 4 images) | — |
| Boutons | Menus | Survol : reflet T33 qui passe ; appui : petit éclat d'encre (discret) | — |
| File d'attente | Hub | Anneau de kanji qui tourne (T27) | — |

---

## 10. Priorités de production

| Lot | Contenu | Pourquoi d'abord | Volume |
|---|---|---|---|
| **P0** | T01 à T20 + M01 à M04 ; impacts, garde, dash, rebonds, super flash, K.O., aura FATAL | Ils servent à **tous** les coups de **tous** les persos : 80 % du rendu en combat | ~24 assets |
| **P1** | Le reste de la bibliothèque (T21 à T50, M05 à M25) ; traînée, impact et dash des 8 persos de départ (KAI, TARO, ZEPHYR, AKEMI, RYUKEN, SHIN, DAICHA, HIBECARES) | L'identité des persos joués le plus | ~55 |
| **P2** | Projectiles et passifs des 22 ; les 14 autres persos | — | ~40 |
| **P3** | Ultimes R, ÉVEIL, PORTE ; puis FATAL et FINISHER ; kanji | Les moments « clip » | ~50 |
| **P4** | Arènes | Ambiance | ~10 |
| **P5** | UI et boutique (auras avec textures, aperçus) | Vente des cosmétiques | ~15 |

**Total** : environ **200 assets**. Une bonne partie (marquée **C** en §3) peut être **générée en script par Claude** : halos, anneaux, traits, lignes de vitesse, bruits d'énergie, éclairs, grille hexagonale, vignette, fissures simples. Restent à dessiner, par un artiste ou une IA : fumée anime, flammes, éclaboussures, feuilles, pétales, encre, griffures, kanji retouchés et meshes.

---

## 11. Brancher un asset (pour Claude)

1. Wilhem envoie l'asset sur Roblox (Creator Hub → Asset Manager, ou Bulk Import dans Studio). Il donne l'ID (`rbxassetid://…`) **avec son nom de fichier**.
2. `python3 tools/vfxids.py sa_liste.txt` écrit les IDs dans le module pur `src/shared/VfxConfig.luau` (fait en 0.36.0 : `TEXTURES` et `MESHES`, une clé par asset, **0 = pas encore envoyé**). On n'y met jamais d'ID inventé.
3. Le client (`VfxPack` → `EffectsController`, `CinematicController`) utilise le pack dès que tous les assets d'une famille d'effets ont un ID (les effets communs, puis chaque perso), sinon la version procédurale actuelle. On peut donc livrer les assets un par un, sans rien casser.
4. Pour chaque branchement : relire le rendu avec les outils du dépôt (planches `Storyboard`, clips `AnimClip`), lancer les 9 suites, mettre à jour `docs/JOURNAL.md`.
5. Les sons ne sont pas dans ce document : voir `docs/AUDIO.md` et `SoundPalette`.

> Rappel : rien de ceci n'a été vérifié dans Roblox Studio. Les réglages sont des points de départ, à ajuster à l'œil en jeu.
