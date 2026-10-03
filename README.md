# jeuxcombat — KAI 開 · TARO 火 · ZEPHYR 風 · AKEMI 影 · RYUKEN 拳 · SHIN 流 · DAICHA 闇 · HIBECARES 崩

Jeu de combat Roblox 2.5D (persos 3D, combat sur un plan 2D, caméra de côté), style anime
noir / blanc / rouge. Le code vit dans `src/` et est synchronisé dans Roblox Studio par
[Rojo](https://rojo.space) 7.7.

## Contrôles

| Action | Clavier / souris | Manette | Mobile |
|---|---|---|---|
| Bouger | Q/A · D (ou flèches) | Stick gauche / croix | Joystick |
| Saut | Espace (ou Z/W) | A | SAUT |
| Accroupi | S | Bas | BAS / joystick bas |
| Dash | Shift + direction | RT | DASH |
| Attaque légère (combo) | **Clic gauche** (ou J) | X | COUP |
| Attaque lourde | **Clic droit** (ou K) | B | LOURD |
| Spéciale (invincible au départ) | **E** | Y | SPÉ |
| Ultime (2 barres de ki, cinématique) | **R** | LT | ULTI |
| **Coup fatal** (3 barres, ta vie sous 30 %, une fois par match) | **C** | LB | FATAL |
| Garde | **F maintenu** (F + S : garde basse) | RB | GARDE |
| Spéciale basse (projectile, PARADE de TARO, MUR DE PIERRE d'HIBECARES) | **S + E** | Bas + Y | BAS + SPÉ |
| **Changer de perso** | **T** ou bouton PERSO | — | bouton |
| Perso du CPU (solo) | **G** ou bouton ADVERSAIRE | — | bouton |
| Mode du mannequin (immobile, garde, CPU ×4) | M ou bouton MANNEQUIN | — | bouton |
| Apparence : avatar R15 → avatar R6 → modèle | bouton APPARENCE | — | bouton |
| Couleurs du perso | bouton STYLE | — | bouton |
| Sons on / off | bouton SON | — | bouton |
| Replacer | Retour arrière | Select | bouton REPLACER |

En versus, on change de perso avant le premier coup du match ou une fois le match fini (le
match repart à zéro) ; en solo, à tout moment.

## Les 8 combattants

| Perso | Style | Vie | Points forts | Points faibles | S + E |
|---|---|---|---|---|---|
| **KAI 開** | polyvalent : poings, pieds, ki | 1550 | rien de faible, boule de ki | rien d'extrême | KIKOHO (boule de ki) |
| **TARO 火** | **boxeur** : que les poings | 1560 | le plus robuste, **garde de fer** (−20 % d'usure de garde), jab le plus rapide, **esquive de buste + DEMPSEY ROLL** | allonge courte, le plus lent | **PARADE** : bloque un coup debout ou un projectile et contre-attaque (perd contre les coups bas et les ultimes) |
| **ZEPHYR 風** | **que les pieds** | 1450 | **plus grande allonge** (+12 %), saut le plus haut, dégâts +8 % | coups qui démarrent un peu plus tard | LAME DE VENT (projectile) |
| **AKEMI 影** | **esquive** | **1060** | la plus rapide, **dash intouchable** au départ, passif **VOILE D'OMBRE** | **encaisse le moins**, dégâts −15 % | KUNAÏ (projectile) |
| **RYUKEN 拳** | **force** : poings brisés, pression | 1500 | coups lourds, **CHARGE FRONTALE** qui traverse l'écran, passif **RAGE** | allonge un peu courte ; perd sa RAGE dès qu'il est touché | FRAPPE SISMIQUE (onde au ras du sol : à garder accroupi) |
| **SHIN 流** | **sabre** : vitesse, précision | 1450 | **la plus grande allonge** (+22 %), coupes rapides (dégâts +15 %), **PAS DU VENT**, passif **PRÉCISION** | encaisse peu ; moins fort collé à l'adversaire | COURANT TRANCHANT (projectile) |
| **DAICHA 闇** | **zoning** : l'espace inversé | 1500 | **SPHÈRE INVERSÉE** lente et énorme, dégâts +15 %, **TÉLÉPORTATION** (réapparaît derrière), passif **OMBRE INVERSÉE** | marche lente, vie moyenne | SPHÈRE INVERSÉE (projectile lent) |
| **HIBECARES 崩** | **endurance** : le roi des ruines | **1620** | **le plus de vie**, coups lourds, garde solide, passif **ROI DES RUINES** | **le plus lent**, coups qui démarrent tard | **MUR DE PIERRE** : encaisse n'importe quel coup (même bas) à moitié, puis riposte |

**Difficulté** (affichée dans le jeu) : ★☆☆ SIMPLE — KAI, RYUKEN, HIBECARES ; ★★☆ MOYEN —
TARO, ZEPHYR, SHIN ; ★★★ TECHNIQUE — AKEMI, DAICHA. Tous équilibrés (CPU contre CPU : entre
44 et 59 % de victoires).

**VOILE D'OMBRE** (passif d'AKEMI, façon Goku Ultra Instinct de FighterZ) : au neutre — sans
attaquer, sans être déjà touchée, sans garder — le coup reçu est esquivé : AKEMI recule hors
de portée, intouchable un instant. Elle a **2 esquives d'avance** (●● à côté de la barre de
garde) ; chacune revient en **18 s**, et **chaque coup qu'elle porte retire 0,33 s**. Juste
après une esquive, **L ou R** : **CONTRE-INSTINCT**, elle réapparaît dans le dos de
l'attaquant et frappe. Jamais contre les ultimes ; pour vider ses esquives, des jabs suffisent.

Passifs des 4 nouveaux (jauge à côté de la barre de garde) :

- **RAGE** (RYUKEN) : chaque coup porté (pas en garde) ajoute +2,5 % de dégâts, jusqu'à
  10 fois (+25 %) ; tout est perdu dès qu'il est touché. Son corps chauffe avec la RAGE.
- **PRÉCISION** (SHIN) : un coup du **bout de la lame** (l'adversaire au bout de l'allonge)
  fait +20 % (« BOUT DE LAME ! »).
- **OMBRE INVERSÉE** (DAICHA) : le dash **vers** l'adversaire, à moins de 5 m, le traverse
  et ressort derrière lui, intouchable un instant ; 0,9 s avant le suivant.
- **ROI DES RUINES** (HIBECARES) : plus il est blessé, plus il frappe fort (jusqu'à +30 %
  à 30 % de vie).

Chaque perso porte **sa tenue sur ton avatar Roblox** (R15 ou R6), taillée sur ses vraies
pièces : KAI bandeau, ceinture et bandages ; TARO gants de boxe, short, ceinture de
champion et serviette au cou ; ZEPHYR longue écharpe au vent, protège-tibias ; AKEMI capuche, masque et
brassards ; RYUKEN bandages et gantelet fissuré qui luit ; SHIN katana et fourreau, col ;
DAICHA sphère d'ombre à la main, obi ; HIBECARES poings de pierre, chaînes, bandeau. En modèle
en blocs, chaque perso a sa propre tête (coiffure) et son propre corps (vêtements). Kanji du perso dans le dos, 2 à 4 styles de couleurs chacun (bouton STYLE).

## Combos (L = clic gauche, R = clic droit)

Les 8 persos ont **la même grammaire** : mêmes touches, mêmes effets, chacun avec ses
propres coups (bouton **COMBOS** en jeu : la liste du perso choisi). Pour KAI :

| Touches | Enchaînement | Effet |
|---|---|---|
| L L L L | JAB > CROSS > COUDE > KICK | chute |
| L L R | JAB > CROSS > LANCEUR | envoie en l'air ; **Espace** pour suivre, puis L L R en l'air |
| L R | JAB > COUP AU FOIE | effondrement : le temps de relancer un combo |
| L L L R | … > TALON TOURNOYANT | rebond sur le mur |
| R R | FRAPPE LOURDE > HACHE CÉLESTE | overhead, rebond au sol |
| R L | FRAPPE LOURDE > BALAYAGE | coup bas, chute |
| ↓ + L / ↓ + R | KICK BAS / LANCEUR | KICK BAS s'enchaîne sur CROSS |
| **L R L R** ★ | … > **TORNADE DU DRAGON** | skill |
| **R L R L** ★ | … > **RAFALE DE KI** | skill, rebond mur |
| **L L R R** ★ | … > **POING DU DRAGON** | skill : triple uppercut |
| **R R L R** ★ | … > **POING DU DRAGON** | skill |
| **L L L L R** ★ | … > **CROISSANT DE LUNE** | skill, rebond au sol |
| … touche E | spéciale | après n'importe quel coup, invincible au démarrage |
| … touche R | ultime 1 | après n'importe quel coup ou la spéciale |

### Le rythme (route « propre »)

Un combo se joue **en rythme** : chaque appui **après la sortie du coup d'avant** (dès ses
frames actives, l'impact, la récupération ou les 6 frames de tolérance). Appuyer pendant
l'élan du coup précédent continue le combo mais il n'est plus **propre** (« TROP TÔT »). La
file garde 3 appuis et chacun expire au bout de 10 frames (« APPUI PERDU ») : impossible de
taper toute la route d'avance. Plusieurs boutons à la fois, un appui de trop ou un mauvais
bouton = « SPAM ». **Changer d'avis gagne** : garde, saut ou dash annulent les coups en
attente, et un coup dans le vide oublie les appuis faits pendant son élan. L'ENTRAÎNEUR dit
pourquoi une route n'est pas propre.

### Routes complètes et les 3 ultimes

Chaque route ★ se prolonge par **L** (poursuite) puis **R** (coup de grâce) : 6 routes de
6 appuis par perso.

| Ultime | Comment | KAI | TARO | ZEPHYR | AKEMI |
|---|---|---|---|---|---|
| 1 · ruée | **R** seul, 2 barres | KAIEN RUSH | RUSH DÉVASTATEUR | VENT TRANCHEUR | OMBRES MULTIPLES |
| 2 · éveil | route complète **propre**, 6e au **clic droit**, 3 barres | ÉVEIL ÉCARLATE | UPPERCUT CÉLESTE | DRAGON ASCENDANT | TEMPS SUSPENDU |
| 3 · porte | route complète **propre**, 6e à la **touche R**, 3 barres | 開天 PORTE DES CIEUX | 火嵐 TEMPÊTE DE CROCHETS | 旋風 CYCLONE FURIEUX | 幻舞 DANSE FANTÔME |

| Ultime | RYUKEN | SHIN | DAICHA | HIBECARES |
|---|---|---|---|---|
| 1 · ruée | FUREUR DU POING | DANSE DES COURANTS | DOMAINE OBSCUR | COLOSSE ÉVEILLÉ |
| 2 · éveil | EFFONDREMENT | TEMPÊTE CONTINUE | RIVIÈRE D'OMBRES | CHÂTIMENT |
| 3 · porte | 拳 DERNIER ROUND | 零 ZÉRO HORIZON | 蝕 ÉCLIPSE TOTALE | 崩 RUINES DU MONDE |

Chaque perso a sa propre façon de filmer et son étalonnage, et sa propre scène de K.O. :
RYUKEN zooms brutaux et gros plans sur les poings (rouge brûlant) ; SHIN longues focales,
travellings latéraux, l'iai qui fige le temps et une seule ligne de lame (bleu acier) ;
DAICHA angles penchés, plans en miroir, caméra à l'envers et soleil noir (violet) ;
HIBECARES contre-plongées monumentales, piliers de pierre, débris et secousses (sépia).
TARO, ZEPHYR et AKEMI ont chacun leur mise en scène (planche d'ultimes de Wilhem) : TARO
charge et cogne de face, soulève l'adversaire dans un pilier de feu puis tourne autour de lui
crochet après crochet ; ZEPHYR enchaîne les coups de pied avec des lames de vent, monte avec
sa cible dans un dragon de vent, puis l'enferme dans un cyclone ; AKEMI frappe de partout
avec ses ombres, arrête le temps (noir et blanc) pour frapper au ralenti, puis danse entre
esquives et coups instantanés. KAI garde les siennes (finale de l'éveil selon la route).

Les ruées (**R** seul) ne se ressemblent plus, chacune a sa propre structure :
- **KAI · KAIEN RUSH** : il lance la cible en l'air et la poursuit dans le ciel en se
  téléportant autour d'elle (anneaux de ki à chaque choc), la renvoie au sol, puis, en
  lévitation, l'écrase sous un **rayon de ki** tiré vers le bas.
- **TARO · RUSH DÉVASTATEUR** : il la pousse dans le coin, contre des **cordes de feu**, puis
  DEMPSEY ROLL (il se balance à gauche et à droite, un crochet de chaque côté), filmé comme une
  retransmission de boxe avec les flashs des photographes ; coups au corps, crochet armé, K.O.
  à travers les cordes, le gant levé.
- **ZEPHYR · VENT TRANCHEUR** : il reste loin et lance à chaque coup de pied une **lame de vent**
  en croissant ; les lames se croisent en un vortex qui soulève la cible ; il fonce et la
  traverse d'un seul coup de pied volant.
- **AKEMI · OMBRES MULTIPLES** : elle frappe à chaque fois depuis un nouveau point d'un cercle
  et y laisse **son ombre debout** ; elle rengaine en noir et blanc, et toutes les ombres
  frappent en même temps.
- **RYUKEN · FUREUR DU POING** : il ne lâche pas sa cible. Tenue par le col et pilonnée à bout
  portant (caméra dans le visage de la cible), écrasée au sol, cueillie au rebond, jonglée
  vers le ciel des deux côtés, smashée au sol, puis un **poing géant de ki** la projette à
  travers le pont.
- **SHIN · DANSE DES COURANTS** : un seul plan vu d'en haut pendant qu'il dessine un **huit**
  autour de la cible (une coupe à chaque croisement, un sillage d'eau reste au sol), puis le
  huit se lève en **trombe d'eau** qui avale la cible ; il saute par-dessus et la fend du ciel.
- **DAICHA · DOMAINE OBSCUR** : il ne touche jamais la cible. Son orbe se divise (2, puis 4),
  couronne la cible et plonge dedans orbe par orbe ; 8 orbes sur deux anneaux croisés (vue du
  dessus qui tourne), un vortex d'orbes la soulève, puis toutes fusionnent en **sphère noire**
  qui s'abat sur elle.
- **HIBECARES · COLOSSE ÉVEILLÉ** : peu de coups, tous colossaux. Chaque pas est un séisme
  (une ligne de rochers jaillit jusqu'à la cible), le 1er coup l'envoie rouler, il la suit
  sans se presser, le 2e l'enfonce dans le sol, ses piétinements la font décoller de plus en
  plus haut, le 3e fait le cratère.

Les QTE comptent : l'éveil retire **jusqu'à 30 % de la vie max** (les 4 QTE en rythme réussis),
chaque QTE raté en retire une part (tout raté : 12 %) ; il ne tue que s'il achève (FINAL FINISH).
La finale change selon la route. La porte retire 30 % de la vie max (peut tuer) ; R pile au
sommet : +10 %, raté : −15 %. Les ultimes ne sont ni esquivés ni parés.

### Le coup fatal (touche C)

Le coup du dernier souffle, inspiré des Fatal Blow (Mortal Kombat 11), Rage Art (Tekken) et
de l'Issen de Samurai Shodown : **3 barres**, **ta vie sous 30 %**, **une fois par match**.

- **En plein combo** (sur un coup qui touche) : **−50 % de la vie max** de l'adversaire. Il ne tue **que si l'adversaire est sous la moitié de sa vie**.
- **À froid** (hors combo) : −30 % seulement. Lent à sortir : paré ou esquivé, il est perdu
  (et la jauge avec).
- Un seul QTE, très serré : **C** au sommet de la scène. Raté : le coup perd 40 %.
- En **entraînement**, il est toujours disponible (avec 3 barres) pour s'exercer, sans condition de vie.
- Chaque perso a **sa scène unique**, qui est **son écran de K.O.** quand le coup tue :

| Perso | Coup fatal | La scène |
|---|---|---|
| KAI | 滅 CIEL ÉTEINT | il marche vers sa cible, glisse sur elle, tout devient noir : seuls les éclairs des coups ; la lumière revient sur son dos et un kanji géant |
| TARO | 終 DERNIÈRE CLOCHE | la cloche du dernier round, l'esquive en huit, les crochets, le poing armé en noir et blanc, puis le direct sous les flashs des photographes |
| ZEPHYR | 嵐 CHUTE DE LA LUNE | la cible part dans le ciel, il la rejoint devant une pleine lune et redescend avec elle, talon en avant, dans un cratère |
| AKEMI | 刻 L'INSTANT VOLÉ | le temps s'arrête (gris et immobile), elle tourne autour de la cible en la coupant de partout, rengaine derrière elle… et tout reprend d'un coup |
| RYUKEN | 砕 POING DU MONDE | le cri, le poing qui fume, puis un coup qui traverse la cible, le sol et l'arène jusqu'au mur |
| SHIN | 一閃 ISSEN | un vieux film de sabre en noir et blanc : le duel de loin, la main sur la poignée, rien ne bouge… il est déjà de l'autre côté, une seule ligne rouge traverse l'écran, il rengaine, la cible tombe |
| DAICHA | 虚 NÉANT | un soleil noir s'ouvre et aspire la cible, les orbes tournent autour, il ferme la main et le vide se referme |
| HIBECARES | 墓 TOMBEAU DES ROIS | les ruines surgissent, trois pas font trembler l'arène et enferment la cible dans la pierre, ses poings s'abattent : un tombeau |

### TARO : deux styles (touches & / 1 et é / 2)

- **BOXEUR CLASSIQUE** (& ou 1) : garde de fer, frappe plus lourde, ↓ + E = DROITE DU
  CHAMPION (lente, écrase la garde, met au sol).
- **BOXEUR ESQUIVE** (é ou 2) : plus mobile, ↓ + E = PARADE qui contre, et l'esquive de
  buste + DEMPSEY ROLL ci-dessous.
- On change de style au neutre (pas pendant un coup) ; les boutons du HUD font pareil.

### TARO (style ESQUIVE) : esquive de buste et DEMPSEY ROLL

- **Dash vers l'adversaire = esquive de buste** : TARO plonge sous la garde, les coups hauts
  et moyens passent au-dessus de sa tête (« ESQUIVE ! », un peu de ki). Les coups bas, les
  projectiles et les ultimes le touchent.
- **Pendant l'esquive ou juste après** : **L** lance le **DEMPSEY ROLL**, des crochets en
  huit gauche / droite qui avancent en esquivant à leur départ ; **L** encore (6 crochets
  au plus), puis **R** pour le **CROCHET FINAL** (envoie au mur). **R** directement depuis
  l'esquive : le crochet final seul.
- Le contre : un coup bas, ou garder puis punir la fin du roll.

## Jouer en 1 contre 1 avec un ami (HUB)

Bouton doré **HUB MULTI (H)** en haut à droite, ou la touche **H** : le panneau du hub s'ouvre
aussi tout seul à l'arrivée. On y voit les joueurs du serveur, **DÉFIER** (le défi dure 30 s),
**ACCEPTER / REFUSER** (bandeau quand on te défie), **QUITTER LE COMBAT**, **JOUER** (quand
personne ne combat) et **INVITER UN AMI** (l'invitation Roblox : ton ami arrive sur ton
serveur). Le premier arrivé combat le CPU ; les suivants attendent au hub et regardent.
**Seul sur le serveur, il n'y a personne à défier** : ton ami doit être sur le MÊME serveur
(invitation, ou rejoindre depuis ton profil Roblox).

Le ping des deux joueurs s'affiche sur la ligne d'état. Pour un ami loin (autre région), le
serveur compense un peu sa latence (enchaînements, QTE des cinématiques) et son propre perso
réagit tout de suite à l'écran.

Pour jouer en ligne, la place doit être publiée : dans Roblox Studio, **Fichier > Publier
sur Roblox**, puis dans **Paramètres du jeu > Autorisations**, rendre le jeu public (ou
réservé aux amis). Lance le jeu depuis sa page Roblox, ouvre le HUB et invite ton ami. Pour
essayer à deux en local : **Test > Clients et serveurs**, 2 joueurs.

## Avatars R15 et R6

Par défaut, tu joues **ton avatar Roblox**, dans le type de corps choisi sur ton compte
(R15 ou R6), mis à la taille du jeu (≈ 5,7 studs) et habillé de la tenue de ton perso. Le
bouton APPARENCE passe de l'avatar R15 à l'avatar R6, puis au modèle en blocs. Un corps R6
n'a ni coudes ni genoux : l'animation tourne sur un squelette R15 virtuel aux proportions
du corps R6, puis chaque membre rigide est orienté vers le poing ou le pied correspondant
(`src/shared/Retarget.luau`). Le CPU est un **clone d'ombre** de ton avatar (même type de
corps). Si l'avatar ne peut pas se charger, un corps par défaut porte la tenue et la ligne
d'état dit pourquoi.

## Animation

Moteur d'animation pur (`src/shared/Animator.luau`), testé hors Studio avec la cinématique du
vrai rig : coups en 4 temps (anticipation, impact, contact, retour), pieds plantés par IK,
course sans glissade, corps posé au sol quelle que soit la taille de l'avatar, réactions selon
le coup reçu, regard vers l'adversaire, ressorts, tissus qui ondulent. Chaque perso a sa
garde, sa course et ses coups.

Qualité du mouvement (0.11) :
- **anticipation qui se tend** : le coup arme, puis l'armé continue de se tendre jusqu'au départ
  (jamais une pose figée) ;
- **inertie des membres** : le buste mène, les bras, les poignets, la tête et la jambe qui
  frappe suivent avec un léger retard, dépassent un peu et se posent ; un impact tombe
  instantanément et fouette ; les pieds plantés ne bougent jamais ;
- **espacement d'affichage** : de très près, les deux corps sont dessinés un peu écartés pour ne
  jamais rentrer l'un dans l'autre (affichage seulement : le combat ne change pas) ;
- **garde vivante** : chaque perso a son rythme (TARO sautille, ZEPHYR est léger, SHIN respire
  à peine, HIBECARES souffle lourdement) et transfère son poids d'un pied à l'autre ;
- saut avec poussée des jambes, dash avec élan et freinage, lame de SHIN couchée au sol quand
  il tombe ;
- cinématiques et scènes de K.O. : aucun plan stroboscopique, la caméra glisse lentement dans
  chaque plan, les poses tenues respirent.

Bouton **POSES** : FLUIDE par défaut, ou 12 / 15 / 24 poses par seconde (style anime).

## Armes : l'épée de SHIN, l'orbe de DAICHA

Le katana et l'orbe sont tenus en main (`src/shared/WeaponSpec.luau`). Chaque coup de SHIN est
une vraie coupe en trois temps (armé lame en arrière, impact lame dans le prolongement du bras,
accompagnement) ; chaque coup de DAICHA frappe avec l'orbe devant le poing. En jeu : traînée le
long de la lame / derrière l'orbe, arc propre à chaque coup d'épée (plat, diagonal, vertical,
cercle complet), estocs en trait de lumière, coups lourds qui frappent le sol ; explosion
d'orbe, faisceau pour le coup lourd, vortex d'orbes pour les coups tournoyants ; en garde, un
arc de lumière devant la lame ou des anneaux d'ombre autour de l'orbe, qui flashent au coup
bloqué. Sur un corps R6 (sans poignet), la lame prolonge le bras.

L'orbe de DAICHA **vole autour de lui** (`src/shared/OrbFlight.luau`, pur) : elle tourne
autour de ses épaules au repos, se place devant lui en garde, et s'écarte derrière lui quand il
est touché. En attaque elle se manie **comme un nunchaku**, au bout d'une chaîne d'ombre : elle
tourne autour de sa main à l'armé, fouette en arc jusqu'au bout de la portée à l'impact, continue
son élan vers le bas et revient en orbite ; elle tourbillonne pour les coups tournoyants.

### Chaque perso frappe à sa façon

Chaque coup laisse la marque de son perso : KAI une traînée et un éclat de ki ; TARO une
traînée de feu et un anneau de flammes à l'impact ; ZEPHYR un croissant de vent et une
bourrasque ; AKEMI une fine entaille d'ombre et une croix ; RYUKEN des traînées de chaleur et
une fissure de rage (les coups lourds fendent le sol) ; SHIN l'arc de la lame et une coupe nette ;
DAICHA l'explosion de l'orbe ; HIBECARES la poussière, des débris de pierre et le sol qui
tremble sur les coups lourds.

## Sons

Uniquement les sons fournis avec le client Roblox (`rbxasset://sounds/…`, la liste exacte est
dans `src/shared/SoundPalette.luau`), sans aucun ID d'asset inventé, retravaillés (hauteur,
durée, distorsion, écho, réverbération, égaliseur). Chaque action a un seul son, le même
pour tous (garde, garde brisée, choc, parade, esquive, saut, chute, super, QTE…), et chaque
perso frappe avec sa matière : poings de ki (KAI), gants de cuir (TARO), pieds qui fendent
le vent (ZEPHYR), main-lame de l'ombre (AKEMI), poings qui écrasent (RYUKEN), lame d'eau
(SHIN), ombre en écho (DAICHA), pierre (HIBECARES). Un coup lourd est la version lourde de
la même matière.

## S'entraîner et vérifier

- **ENTRAÎNEUR** : choisis une route de ton perso ; la barre en bas montre les touches,
  s'allume en jaune (« MAINTENANT ! ») quand le prochain appui tombe en rythme, et dit
  pourquoi un combo casse.
- **LABO CINÉ** (solo) : lance chaque cinématique de ton perso directement. Avec **HITBOX**
  activé, le nom du plan et le tick s'affichent.
- Les appuis faits pendant qu'on se fait frapper sont ignorés (sauf les 4 dernières frames,
  pour un reversal), et maintenir la garde au relevé l'emporte.

## Lancer le jeu

```bash
rojo serve
```

Puis, dans Roblox Studio, ouvrir le plugin Rojo et cliquer sur **Connect** : les scripts de
`src/` remplacent ceux de la place. Pour générer une place sans Rojo serve :

```bash
rojo build -o "jeuxcombat.rbxlx"
```

⚠️ Ne modifie pas les scripts directement dans Studio quand Rojo est connecté : Rojo les
écrase avec le contenu de `src/`. Toute modification passe par les fichiers du dépôt.

## Tests hors Studio

La simulation de combat, l'IA, les kits, la mise en scène des cinématiques et l'animation
(`src/shared/`) n'utilisent aucune API Roblox ; elles se testent avec le
[CLI Luau](https://github.com/luau-lang/luau/releases) :

```bash
luau tests/CombatSimulation.test.luau
luau tests/FighterAI.test.luau
luau tests/CinematicDirector.test.luau
luau tests/Animation.test.luau
luau tests/Kits.test.luau             # les 8 kits, leurs passifs, la palette de sons
luau tests/PressQueue.test.luau
luau tests/Fuzz.test.luau            # entrées aléatoires, tous les duels : invariants
luau tests/Cinematography.test.luau  # cadrage de chaque ultime avec le vrai rig
luau tests/Lobby.test.luau           # règles du hub (défis, places)
python3 tools/rigcheck.py check      # construit chaque perso (corps + tenues R15 / R6) hors Studio
luau tests/Balance.luau -a 4 120   # rapport d'équilibrage CPU contre CPU (niveau, matchs)
```

### Planche de poses R6 / R15

Les mêmes poses sur un corps R6 (à gauche) et sur le rig R15 (à droite), vues par la caméra du
jeu :

```bash
luau tests/PoseSheet.luau -a AKEMI 0 > sheet.txt
python3 tools/storyboard.py sheet.txt sheet.png
```

### Storyboard des cinématiques

Planche de ce que voit la caméra, image par image (corps posés par le vrai moteur
d'animation, effets simplifiés) — Python 3 et Pillow :

```bash
luau tests/Storyboard.luau -a TARO Gate - 0 8 > story.txt
python3 tools/storyboard.py story.txt story.png
```

### Clips d'animation (GIF) et mesure du mouvement

Un combat scénarisé joué par la vraie simulation et le vrai moteur d'animation, filmé par la
caméra du jeu, en GIF (`STORY_W` pour la taille ; `ZOOM` 2 = deux fois plus près) :

```bash
luau tests/AnimClip.luau -a SHIN showcase 60 2 1.8 > clip.txt   # KIT SCRIPT POSES/s PAS ZOOM
python3 tools/storyboard.py clip.txt clip.gif
luau tests/AnimQuality.luau -a all    # à-coups, tremblements, corps qui se rentrent dedans
```

## Documents

- `docs/Roblox_Guide_Claude.md` — cahier des charges du projet.
- `docs/JOURNAL.md` — état du projet à transmettre après chaque livraison.
