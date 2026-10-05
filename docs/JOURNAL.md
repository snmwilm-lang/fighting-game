# Journal du projet — état à transmettre

## Version 0.18.1 — 5 octobre 2026

Même contenu que la 0.18.0 avec ses deux correctifs (accès développeur dans Studio, onglets du
haut lisibles), sous un nouveau numéro : Wilhem rouvrait un ancien fichier du même nom. La
console écrit « 0.18.1 ready » : c'est le bon fichier. Vérifié par Wilhem dans Studio (capture) :
onglets lisibles, « developer access: YES », plus de cadenas. Son UserId (3288842358, compte
Laveine972) est dans `DevAccess.IDS` : l'accès le suit aussi dans le jeu publié, même de groupe.

Menu plein écran (« il prend pas tout l'écran ») : la toile du menu était une boîte de 1600 × 900
centrée et réduite, avec des bandes vides sur tout écran d'une autre forme (fenêtre de Studio,
écran large, téléphone). Elle prend maintenant tout l'écran (au moins 1600 × 900 unités,
étirée aux proportions de l'écran) ; chaque bloc reste collé à son bord (navigation à gauche,
pages et persos à droite, panneaux en bas, bande noire du haut sur toute la largeur).
v0.18.3 : il restait une bande du décor au-dessus de la barre (la zone des boutons de Roblox,
hors de la zone sûre du menu). Le fond du menu (voile, brume, noir de la barre) est dans un
ScreenGui à part qui couvre tout l'écran : le noir de la barre monte jusqu'en haut, les boutons
de Roblox restent posés dessus ; le contenu du menu reste dans la zone sûre.

## Version 0.18.0 — 5 octobre 2026 · ÉCONOMIE, PERSOS À DÉBLOQUER, SKINS, QUÊTES, CHAMPION

Demande de Wilhem : finaliser l'économie sans refaire l'existant (provocations, classement et
skins conservés), 8 persos gratuits sur 20 (« assez de diversité mais pas les persos trop
stylés »), entraînement gratuit pour tous, présentation des skins, quêtes, titre du champion
de la semaine, audit des menus, accès développeur.

**Économie** (`src/shared/Economy.luau`, pur, testé ; adapté au système existant, pas de second système) :
- PvP : victoire 150, défaite 50 (nul 100, non fixé par Wilhem). Celui qui quitte un match en cours ne touche rien. Les règles anti-farm restent : match de moins de 25 s = rien, même adversaire répété = ×0,25 puis 0, plafond de 2000 pièces par jour (≈ 13 victoires) ;
- `GameModes.COINS` aligné (les deux disent la même chose, test à l'appui) ;
- achats côté serveur seulement, sur le profil chargé (jamais sur un profil par défaut), sauvegarde immédiate ; une demande par 0,5 s ; un achat déjà fait est refusé (pas de double paiement), jamais de solde négatif.

**Persos gratuits et à débloquer** :
- gratuits (proposition, une ligne à changer dans `Economy.FREE`) : KAI (polyvalent ★), TARO (boxeur), ZEPHYR (jambes), RYUKEN (puissance ★), HIBECARES (endurance ★), GORAN (lutteur), ELIAN (soutien), VENOM (usure). Les plus stylés restent à débloquer : AKEMI, SHIN, DAICHA, RAIJIN, YUKINA, ASTER, HIBIKI, KAZAN, KUREN, SYLVA, NOVA, KUROEN — 4000 pièces chacun, gardés pour toujours (`profile.ownedKits`) ;
- le serveur refuse une équipe avec un perso verrouillé (sauf ENTRAÎNEMENT), à la demande, à l'équipe d'un défi entre amis et encore au lancement du 1v1 ; un favori verrouillé redevient KAI ;
- menu : sélection avec voile 🔒 + prix sur les persos verrouillés (et « FREE TRIAL » en entraînement), clic = proposition de déblocage ; bande MES PERSONNAGES avec cadenas et prix ; page PERSONNAGES : état (gratuit / débloqué / verrouillé + prix + solde), DÉBLOQUER avec confirmation, ESSAYER EN ENTRAÎNEMENT. Le solde reste dans la carte profil.

**Entraînement gratuit** : tous les persos y sont jouables (le changement de perso en entraînement existait déjà), ultimes compris ; jouer en entraînement ne débloque rien.

**Skins** (aucun supprimé, aucun recréé) :
- recensement (compté dans le code) : 46 styles « de base » (2 à 5 par perso jouable, plus ceux des boss ASURA et KUROEN SHIN ; ÉVEILLÉ et ÉCLIPSE DIVINE se gagnent en défi), et les 40 skins de boutique de la v0.17.0 ;
- prix unique 2500 pièces ; 8 d'entre eux deviennent des récompenses de quête (non vendus) ; Robux : préparé (bouton R$ dès qu'un id de produit est mis dans `CharacterData.SHOP_PRODUCTS`, aucun inventé) ;
- page PERSONNAGES : aperçu 3D du perso dans le style choisi (le serveur construit le corps du style une fois, partagé par tous), on le fait tourner au doigt / à la souris, il tourne seul sinon ; chaque style avec ses couleurs, son état (GRATUIT, GAGNÉ, BATS ASURA, QUÊTE · condition, ACQUIS, BOUTIQUE) et son bouton (prix avec confirmation, ÉQUIPER, ✓ PORTÉ) ;
- ÉQUIPER : le style porté avec chaque perso est sauvegardé (`profile.equipped`) et utilisé en combat et dans le lobby, seulement s'il est toujours à soi ; purement cosmétique.

**Quêtes** (`src/shared/Quests.luau`, pur, testé ; proposition à valider) : JOUE 10 matchs → KAI INFERNO · 40 matchs → HIBECARES ABYSS · GAGNE 5 matchs en ligne → TARO SAKURA · 25 → ZEPHYR ABYSS · 5 victoires avec RYUKEN → RYUKEN PHANTOM, GORAN → GORAN SAKURA, ELIAN → ELIAN ABYSS, VENOM → VENOM INFERNO. Compteurs dans le profil (sauvegardés), récompense donnée une seule fois par le serveur ; en ligne, seuls les matchs comptés par l'anti-farm avancent ; jamais l'entraînement. Onglet QUÊTES dans SUCCÈS (progression, style offert en couleurs).

**Champion de la semaine** (`src/server/Champions.luau`, pur, testé) : il n'existait PAS de réinitialisation hebdomadaire — le classement est la note Elo de toujours (`JeuxCombat_Classement_v1`), laissé intact. À chaque nouvelle semaine (lundi 0 h UTC), le premier du classement devient champion de la semaine écoulée, écrit une seule fois dans un historique partagé (`JeuxCombat_Champions_v1`, UpdateAsync : une écriture par semaine quel que soit le nombre de serveurs, 104 semaines gardées). Titre WEEKLY CHAMPION (CHAMPION DE LA SEMAINE), donné une fois par semaine gagnée (à la connexion ou tout de suite), impossible à acheter ; affichable : PARAMÈTRES › TITRE AFFICHÉ (le serveur n'accepte qu'un titre possédé), visible sur la carte profil et dans la liste des joueurs du serveur.

**Accès développeur** (`src/server/DevAccess.luau`, côté serveur seulement, testé) : les UserId de `DevAccess.IDS` et le propriétaire du jeu quand il appartient à un compte (game.CreatorId). Jamais les joueurs de test de Studio (UserId négatifs). Tous les persos dans tous les modes et tous les styles, sans rien écrire comme acheté ; PARAMÈTRES › ACCÈS DÉVELOPPEUR (visible seulement pour un développeur) le coupe pour jouer en nouveau joueur, et le remet.

Correctif après le premier essai de Wilhem dans Studio (« pas le full accès ») : une place non publiée a CreatorId 0 (et un jeu de groupe n'a pas de propriétaire joueur), donc personne n'avait l'accès. Maintenant, dans Studio, le compte qui joue SEUL (Play) l'a ; un test à plusieurs joueurs ou un joueur de test (UserId négatif) jamais. La console (Output) écrit à chaque arrivée : nom, UserId, propriétaire de la place, accès oui / non — pour mettre l'UserId de Wilhem dans `DevAccess.IDS` (indispensable si le jeu publié appartient à un groupe).

**Audit des menus** :
- sélection : la colonne des persos (630 px) passait sous le panneau d'options (dernière rangée à moitié cachée) → 582 px ;
- PARAMÈTRES devient une liste qui défile (avec les nouvelles lignes, la page débordait) ;
- page PERSONNAGES réorganisée (aperçu, description, état, styles) sans rien dépasser ;
- fenêtre « Jouer entre amis » : déjà corrigée (centrée dans la zone sûre, au-dessus du menu, bouton INVITER dans un pied fixe) — laissée telle quelle, on y ajoute seulement le titre des joueurs ;
- texte de fin de défi ASURA : guillemet mal fermé corrigé.
- onglets du haut (PLAY, FIGHTERS, RANKING…) : un UIGradient posé sur leurs boutons teintait aussi leur texte, noir sur noir, l'onglet actif vide (capture de Wilhem) → couleur unie.

Tests : Lobby 30 (nouveaux : économie, accès développeur, styles 2500 / quêtes / équipement, quêtes, champion de la semaine, textes en français), toutes les autres suites inchangées.

Problèmes ouverts : rien n'est vérifié dans Roblox Studio (achats réels, DataStore, aperçu 3D des styles, glisser pour tourner sur mobile, champion de la semaine en jeu publié). Sur un petit téléphone, tout le menu est réduit à l'échelle (canevas 1600 × 900) : à regarder en vrai. Les joueurs qui avaient déjà joué gardent leurs pièces mais perdent l'accès aux 12 persos à débloquer (à décider : les offrir aux testeurs ?). À valider par Wilhem : les 8 gratuits, les 8 quêtes et leurs récompenses, le gain d'un nul (100), le plafond de 2000 pièces par jour, ses UserId à mettre dans `DevAccess.IDS` (inutile si le jeu est sur son compte).
Prochaine étape : réglages après retours de Wilhem, prix Robux une fois ses produits créés.

## Version 0.17.0 — 4 octobre 2026 · MAJOR UPDATE : KUROEN

Demandes de Wilhem : supprimer MARION, refaire KAZAN avec deux griffes, créer KUROEN (rushdown
technique, jauge DOMINATION, CRIMSON STEP, ECLIPSE BREAKER, TYRANT'S FIST, EMPEROR RUSH,
ZÉRO ABSOLU : ÉCLIPSE), auditer et rééquilibrer le roster (20 jouables, ASURA boss), nerf de
SHIN, reset des succès pour tout le monde, ASURA « beaucoup plus fort », un nouveau boss
KUROEN SHIN « cassé comme Gogeta » qui donne un skin, des icônes de monnaie, avis sur l'UI de GPT.
Sauvegarde avant la mise à jour : commit `56471c4` (branche poussée ; tag local
`backup/pre-kuroen`, le dépôt distant refuse les tags).

- **MARION supprimée** : kit, pantin (passif Puppet et son coup), poses, corps, tenue, styles,
  sons, thème de cinématique, étalonnage, traductions et test. Rien de partagé n'a été retiré
  (les archétypes de cinématique « dance », les règles de projectile `bind`/`pull` restent).
- **KAZAN refait (griffes)** : plus de chaîne ni de fouet. Deux griffes d'acier, trois longues
  lames par main (`WeaponSpec.KAZAN`, construites comme les armes : elles suivent les mains),
  vambraces, masque de mâchoire. 29 coups renommés et réanimés (griffures alternées, croisées,
  montantes, lourdes, SKULL SPLITTER en overhead), portée moyenne (x1,05 au lieu de x1,25),
  startup -1, 1400 PV, dash 42 ; SHACKLE HOOK (S + E) : une fente, la griffe accroche et
  retient (bind). L'ENTRAVE (dash coupé) est conservée. Cinématiques : il tourne autour de sa
  proie (R), saisit (ÉVEIL), retient dans l'entrave (PORTE), harponne (FATAL). Sons de lames.
  Tests : griffes (2 x 3 lames, chaque griffure balaie vraiment les lames, jamais sous le sol),
  portée sans fouet, crochet qui retient.
- **KUROEN 蝕 · L'EMPEREUR DE L'ÉCLIPSE** (prend la place de MARION : 20 jouables) — voir le
  rapport final pour les statistiques ; mécanique DOMINATION dans `CombatSimulation` (gain sur
  un combo propre de 4 coups, une fois par combo, max 3 ; -1 quand il prend un combo ou après
  6 s sans toucher ; I : EMPEROR STEP, II : annulation technique → technique, III : ZÉRO ABSOLU
  sur R après un coup touché ; chaque usage consomme ; jamais de bonus de dégâts). Aura par
  niveau (braises, fumée rouge et noire, aura noire + anneau rouge), annonces, son.
- **ASURA beaucoup plus fort** (sans toucher ses PV) : armure sur tous ses coups au sol, sa
  deuxième paire de bras suit chaque coup qui touche (+35 %, impact doré), en garde il écrase
  (usure x1,5), jamais de COUNTER HIT contre lui, garde x0,5. IA du boss : 100 % contre LÉGENDE.
- **Nouveau boss KUROEN SHIN 真** (mode CHALLENGE · KUROEN SHIN) : les coups de KUROEN, la
  DOMINATION née en ÉCLIPSE qui revient seule (un niveau / 4 s) et ne se perd jamais, 3000 PV,
  dégâts x1,4, dash invincible (« transmission instantanée »), allure divine blanc et or, son
  propre thème de cinématique. Battu : style ÉCLIPSE DIVINE de KUROEN (verrouillé jusque-là),
  titres GOD SLAYER…, succès GOD SLAYER / TRUE EMPEROR. 100 % contre LÉGENDE.
- **SHIN nerfé** : dégâts x1,10 (1,18), allonge x1,17 (1,22), récupération +3, PRÉCISION +12 %
  à partir de 68 % de l'allonge (+20 % à 62 %).
- **Succès remis à zéro pour tout le monde** : compteurs propres aux succès, remis à zéro par
  une nouvelle saison (`ACHIEVEMENT_SEASON` = 2) sans toucher points, victoires, titres ni styles.
- **Icônes de monnaie** (`assets/icons`, `tools/currency_icons.py`) : pièce 金, cristal de ki 気,
  médaille de rang 位, ticket ofuda 闘 — PNG 512 px à uploader dans Roblox.
- **Correctifs** : un champ retiré par un kit (`invuln = false`, `projectile = false`) faisait
  planter la simulation (normalisé dans `move()`) ; l'IA n'utilise plus un « reversal » qui
  n'est pas invincible ; cadrages des cinématiques KUROEN / KAZAN.
- **KUROEN** : son IA, sans revers invincible, garde au relevé au lieu de contre-attaquer au
  jab (la riposte dépend de la garde du niveau : `(1 - block)^1.1`). Il passait de 93 % à environ 40-58 %.
- **Musique et sons** : la musique générée est supprimée. Le jeu ne joue que de vraies pistes
  libres de droits, posées par Wilhem dans Studio (`ReplicatedStorage › Audio › Music`, slots
  MENU, BATTLE, arènes, ASURA, WRATH, VICTORY, DEFEAT, avec repli vers un slot plus général) et
  des sons (`Audio › SFX`, par action ou par perso). Mode d'emploi : `docs/AUDIO.md`.
- **ASURA encore plus dur, mais battable** (les testeurs le battaient en une quinzaine d'essais) :
  - BURST : le 5e coup d'un combo sur lui le casse ; il se libère et l'attaquant est repoussé. Le BURST se recharge en 10 s, la jauge l'affiche (« BURST PRÊT » / secondes restantes), et l'attaquant peut garder juste après ;
  - il subit 10 % de dégâts en moins et frappe à ×1,4 ;
  - sa seconde vie le remet à 60 % de sa vie, avec une vitesse ×1,3.
- **KUROEN SHIN, broken à sa façon** : INSTINCT DIVIN (`Stats.AutoEvade`). Le premier coup qui
  l'atteint en neutre est esquivé (1 charge, qui revient en 8 s, visible sur sa jauge) et il
  réapparaît dans le dos de l'attaquant. Il faut donc l'appâter, puis frapper. Il subit 10 % de
  dégâts en moins et frappe à ×1,45.
- Les ultimes passent toujours (ni BURST ni esquive contre un ultime) : c'est la voie pour
  battre les boss. Mesure : `tests/BossTeamReport.luau`. L'IA LEGEND, même en équipe de 3,
  perd 18 fois sur 18, mais elle perdait déjà 18 fois sur 18 contre l'ancien ASURA que les
  testeurs battaient : ce chiffre ne dit pas ce qu'un humain peut faire.
- **Monnaies** :
  - barre du menu PIÈCES / CRISTAUX / RANG avec des sprites dessinés (`client/CurrencyIcons`). Les PNG de `assets/icons` remplacent ces dessins dès que leurs ID sont mis dans `CurrencyIcons.IMAGES` ;
  - le serveur donne les PIÈCES : 40 par victoire, 15 par défaite, 10 par vague de SURVIE, 60 par boss battu ;
  - les CRISTAUX valent 25 par succès débloqué.
- **UI, grosse mise à niveau** (inspirée de la capture de Wilhem, code à nous) :
  - onglets du haut lisibles, plus un onglet ACHIEVEMENTS ;
  - ombres portées, reflets brillants, bandes de vitesse sur les cartes de mode ;
  - boutons de gauche qui glissent au survol, avec une barre d'accent ;
  - même cadre pour toutes les pages (en-tête à barre de couleur), podium or / argent / bronze dans le classement.
- **Monnaies partout** :
  - portefeuille plus grand dans la barre du haut ; le compteur défile jusqu'à la nouvelle valeur ;
  - chaque carte de mode affiche ce qu'elle rapporte (sprite et montant), chaque succès ses cristaux ;
  - après un match, « +40 [pièce] » sort du portefeuille (le serveur envoie le gain avec le résultat).
- **Poses du menu** : le héros du lobby et les aperçus de la sélection prennent la garde propre à chaque perso, au lieu de la pose de victoire commune (bras levés). Le héros du lobby ne recevait pas son kit et prenait la garde de KAI.
- Icônes de monnaie : Wilhem a uploadé les 4 PNG ; leurs ID sont dans `CurrencyIcons.IMAGES`, donc les vraies images remplacent les icônes dessinées.
- Pastilles de récompense traduites en français (« WIN +40 » → « VICTOIRE +40 », « +10 / OPPONENT » → « +10 / ADVERSAIRE », « POINTS ELO »), avec un test.
- **Correctif** : à la sélection, un commentaire avalait `BackgroundTransparency` et `Ambient` du ViewportFrame des aperçus.
- **Grande échelle (des dizaines de milliers de joueurs sur beaucoup de serveurs)** :
  - sauvegardes par `SaveQueue` (module pur, testé) :
    - un profil jamais chargé (DataStore en panne) n'est jamais écrit : avant, il écrasait la vraie sauvegarde par un profil vide ;
    - chargement réessayé 4 fois avec attente croissante ;
    - `UpdateAsync` au lieu de `SetAsync` ;
    - une écriture au plus toutes les 7 s par joueur (limite Roblox : 6 s par clé), au plus 8 écritures toutes les 15 s, les plus anciennes d'abord ;
    - écriture immédiate au départ et à la fermeture du serveur (`BindToClose`, rien n'était sauvé avant) ;
    - classement réécrit seulement quand la note change ;
  - snapshots plafonnés à 30 par seconde par joueur (avant, jusqu'à 60 quand il y avait des événements) ;
  - mesuré : un match coûte environ 11 µs par tick (simulation + IA), donc 50 matchs prennent environ 3 % du CPU d'un serveur.
- **Confort** :
  - REJOUER (ou ENTRÉE) après un match solo : même équipe, même niveau, même arène ;
  - la sélection retient la dernière équipe de chaque mode ;
  - les réglages EFFETS / SON / MUSIQUE sont gardés dans le profil.
- Version 0.17.0.

Audit du roster (19 kits + KUROEN) :
- l'esquive de TARO et celle d'AKEMI couvrent bien les coups à plusieurs touches (tout le coup est raté) ;
- le serveur reste l'autorité et limite le débit des entrées ;
- corrigé : le TEMPO de HIBIKI pouvait se relancer sans fin tant qu'il tournait. Désormais, aucune nouvelle chaîne ne compte pendant le TEMPO, ni pendant 300 ticks après (`Cooldown`) ; un test le vérifie ;
- corrigé : `invuln = false` / `projectile = false` dans une surcharge de kit faisaient planter `isInvulnerable` ; c'est normalisé dans `move()` ;
- cinématiques : la prise du FATAL de KUROEN et la RUSH / la PORTE de KUROEN SHIN cachaient une main ; c'est réorienté (`turn`).

Tests : CombatSimulation 126, FighterAI 13, CinematicDirector 871, Animation 40, Kits 129, PressQueue 4, Fuzz 2, Cinematography 310, Lobby 18 (tout passe). Équilibrage CPU contre CPU (`Balance -a 4 120`) : KAI 53, TARO 61, ZEPHYR 42, AKEMI 42, RYUKEN 57, SHIN 39, DAICHA 47, HIBECARES 53, RAIJIN 45, YUKINA 49, VENOM 62, GORAN 53, ASTER 47, HIBIKI 57, KAZAN 47, KUREN 47, SYLVA 47, ELIAN 45, NOVA 48, KUROEN 59 (tous entre 35 et 65 %).

**Détails du corps et pose du favori** :
- tous les corps du modèle de base : poings avec jointures et pouce, bout de chaussure, genoux, à la couleur du membre (gant, pantalon, chaussure). La silhouette carrée est gardée, sans épaules arrondies (Wilhem aime le style carré) ;
- pose du favori dans le menu : quand le favori change, le serveur reconstruit le héros du lobby, et le client l'animait parfois avant que toutes ses articulations soient arrivées (pose cassée). Il attend maintenant le squelette complet (15 articulations, 6 en R6) et le relit s'il était incomplet, comme les persos en combat ;
- outil : `python3 tools/rigcheck.py bodies bodies.png` montre les corps entiers (face et dos).

**Cheveux remodelés** (`RigBuilder.luau`) :
- nouveaux outils : `spike` (pointe en blocs qui s'affinent sur les 4 côtés, puis une pointe en double biseau, pointue sous tous les angles), `lock` (mèche courbée et effilée, en segments), `fringe` (frange) ;
- KAI, RYUKEN (flammes à pointes rouges, base pleine), HIBECARES (sauvage sous le bandeau), ASTER, ELIAN (coiffé en arrière), HIBIKI (carré sous le casque), KUREN (mèche sur l'œil), KUROEN et KUROEN SHIN (crinière), NOVA, SYLVA, YUKINA, et tous les persos à `spikes()` (ASURA, RAIJIN, VENOM, KAZAN) ;
- ZEPHYR garde sa coiffure d'origine (plaques au vent) : Wilhem aimait son style.
- pièces par corps : KAI 115 → 176, les autres +15 à +60 (deux blocs par pointe au lieu de trois pour rester léger) ;
- outils : `python3 tools/rigcheck.py heads heads.png` fait des gros plans des têtes (face, profil, dos). La planche dessine enfin les WedgePart en coins (avant : des cubes). Le nom « KUROEN SHIN » cassait le rendu, c'est corrigé ;
- menu : le grand kanji en filigrane ne s'affiche plus que sur la sélection des persos (dans le lobby, il restait par-dessus le héros).

**QUICK TRASH TALK, les provocations en combat** (`src/shared/Taunts.luau` pur et testé, `src/client/TauntController.luau`) :
- 12 provocations prédéfinies (EZ 😂, BOZO 🤡, TOO SLOW 💀, CRY ABOUT IT 😭, SKILL ISSUE, BRO???, YOU GOOD? 💀, RUN IT BACK, NICE TRY, LOL, SIT DOWN, WHAT WAS THAT?!), plus 3 à débloquer pour montrer le système (battre ASURA, battre KUROEN SHIN, 25 victoires). Ajouter une provocation = une ligne dans `Taunts.LIST`. Aucun système payant ;
- roue de 6 : touche V par défaut (au choix V / B / N / Y / X dans PARAMÈTRES), bouton 💬 sur mobile pendant les matchs. Elle se ferme au choix, sur la touche, sur Échap ou seule après 4 s. Elle n'avale aucune touche : bouger, garder et attaquer continuent, un clic hors de la roue reste une attaque, et la souris verrouillée est seulement libérée le temps de choisir ;
- sécurité : le client n'envoie qu'un NUMÉRO d'emplacement (1 à 6) dans son paquet d'entrée habituel. Le serveur lit la provocation dans le profil SAUVEGARDÉ, vérifie le délai de 5 s sur son horloge et l'envoie à tout le match comme un événement hors simulation (le combat n'est jamais touché, test à l'appui). Un texte forgé, une provocation inconnue ou verrouillée ne peuvent pas passer ; un numéro invalide compte dans l'anti-triche. Pas de texte libre, donc pas de filtrage `TextService` à faire (messages écrits par le jeu) ;
- bulles : `BillboardGui` sur la tête du perso (suit chaque mouvement et chaque pose), petite, noir / rouge / blanc, apparition et disparition animées, 2 s, une seule par perso, masquées pendant les cinématiques ;
- page PROVOCATIONS dans le menu : choisir l'emplacement puis la provocation (échange si elle est déjà sur la roue), verrouillées grisées avec la façon de les gagner, sauvegardé dans le profil ;
- PARAMÈTRES : PROVOCATIONS ADVERSES AFFICHÉES / MASQUÉES (tes propres bulles restent visibles), TOUCHE DE LA ROUE. Les deux sont sauvegardés. Les valeurs des réglages se rafraîchissent à l'ouverture de la page ;
- tests réels (luau) : liste complète, ids uniques, 6 sauvegardées dans l'ordre (doublons, inconnues et verrouillées retirées), délai de 5 s contre le spam, numéros forgés refusés, deux joueurs en même temps, une provocation pendant une attaque ne change rien au combat ;
- à vérifier dans Roblox Studio : la bulle suit un perso rapide, le masquage des adverses, mobile (bouton 💬), la sauvegarde réelle entre deux connexions, l'affichage des emojis.

**UI de GPT intégrée** (autorisée par Wilhem) :
- fusion à 3 sources de son `MenuController`, `HubController` et `MenuTheme` (nouveau) avec notre version : son style partout (barre du haut, navigation, cartes, pages, zones sûres mobiles) ;
- gardé de notre côté : le portefeuille avec les icônes de monnaie dans sa carte profil, REJOUER, la dernière équipe retenue, les réglages sauvegardés, le défi KUROEN SHIN (cartes resserrées pour 4 modes), les cristaux sur ses lignes de succès ;
- icônes de monnaie : le dessin reste sous l'image et n'est masqué qu'une fois l'image vraiment chargée (avant, une image en modération laissait un carré vide) ;
- les pastilles « WIN +40 » des cartes sont retirées (trop présentes).
- la sélection des persos passe au même thème : lignes de vitesse, colonne et panneau d'options avec filets rouges, boutons du thème (FIGHT!, RETOUR, flèches).

**Anti-triche** (`src/server/AntiCheat.luau`, pur, testé dans Lobby). Le serveur jugeait déjà seul les coups, la vie et les K.O., mesurait lui-même le ping et bornait la compensation de latence ; les joueurs n'ont pas de personnage physique. En plus :
- score de suspicion : un paquet que le vrai client n'envoie jamais (types ou valeurs impossibles, action inconnue, numéro de séquence qui recule, flood grossier de plus de 120 paquets rejetés en une seconde) ajoute des points, qui s'effacent avec le temps. À 100 points : expulsion, avec une ligne dans la console serveur. Un vrai joueur n'en approche jamais (un client à 144 Hz qui martèle reste loin du seuil ; le bouton CINE LAB hors entraînement n'est pas puni) ;
- anti-farm :
  - un match de moins de 25 s ne rapporte ni pièces, ni points, ni victoire (alt qui entre puis quitte) ;
  - les mêmes deux joueurs : à partir du 4e match du jour, gains ×0,25 ; à partir du 8e, plus rien. Le compte est dans le profil, donc vu par tous les serveurs ;
  - plafond de 2000 pièces par jour (matchs, survie, boss) ;
  - l'Elo reste à somme nulle.

**CLASSÉ entre serveurs + verrou de session** (`src/server/GlobalQueue.luau`, pur, testé dans Lobby) :
- un joueur CLASSÉ sans adversaire sur son serveur après 6 s est publié dans une file mondiale (MemoryStore, triée par note, rafraîchie toutes les 10 s, périmée après 30 s) ;
- chaque serveur cherche pour ses propres joueurs publiés, seulement s'il est « l'initiateur » de la paire (celui qui attend depuis le plus longtemps). Une paire n'est donc jamais réclamée par deux serveurs ;
- l'adversaire choisi a la même taille d'équipe et la note la plus proche, dans la fenêtre qui s'élargit avec l'attente ;
- la réservation de l'adversaire est atomique, puis un serveur privé est réservé et les deux joueurs y sont téléportés. Le match CLASSÉ démarre quand les deux sont là et que leurs profils sont chargés. Au bout de 40 s sans l'adversaire : message « relance la recherche » ;
- verrou de session : le profil sauvegardé porte le serveur qui le tient (`_session`). Un autre serveur attend qu'il soit libéré : au départ du joueur, ou au bout de 60 s si le serveur est tombé. Plus de doubles écritures lors d'une téléportation.
- Ça ne marche que dans le jeu publié (MemoryStore, téléportation). Dans Studio, la recherche reste sur le serveur. Non testé dans Roblox.

**Masques et détails de tête** (`RigBuilder.luau`, sans toucher aux silhouettes) : VENOM (museau du respirateur, fentes d'aération, couture lumineuse, bagues métal des filtres, sangles), KAZAN (dents du protège-mâchoire, rivets, plaques de joues), NOVA (deux verres ronds cerclés de métal et un pont sur les lunettes), AKEMI (arête du masque sur le nez, pli sous les yeux), HIBIKI (anneau des écouteurs, micro). `rigcheck check` : tous les corps construits.

**Skins de boutique (monétisation préparée)** (`CharacterData.luau`, serveur, menu) :
- 2 skins par perso jouable (40 en tout), tirés de 5 thèmes complets : GOLD (OR), PHANTOM (FANTÔME), INFERNO, SAKURA, ABYSS (ABYSSE), posés sur la tenue du perso (sa couleur de peau gardée). Ils sont dans la liste des styles du perso, comme les autres ;
- prix en pièces : 1500 et 2500. Verrouillés tant qu'ils ne sont pas achetés : le serveur seul vérifie (`CharacterData.canWear`), le changement de style en combat les saute ;
- achat : page PERSONNAGES › STYLES · BOUTIQUE (couleurs du skin, état GRATUIT / À GAGNER / ACQUIS, bouton avec le prix). Le serveur vérifie le prix et les pièces, débite, note le skin dans le profil (`ownedSkins`) et sauvegarde tout de suite ;
- Robux : préparé, pas branché. Un prix en Robux demande un produit développeur créé par Wilhem sur Roblox ; son id va dans `CharacterData.SHOP_PRODUCTS["KAI GOLD"] = id`. Tant que la table est vide (aucun id inventé), aucun `ProcessReceipt` n'est installé. Quand il y en a, le skin n'est accordé qu'une fois écrit dans la sauvegarde (sinon Roblox rappelle plus tard) ;
- test : 2 par perso, verrouillés, prix vérifié, pas de double paiement, pas de dette, aucun id Robux.

**VFX perso par perso** (`src/shared/KitFX.luau` pur et testé, `EffectsController.luau`) :
- chaque perso a un élément, et tout ce qu'il fait le parle : le coup qui part, la marque sur l'adversaire, le dash, ses projectiles, de petites particules autour du corps, les traînées des membres et les éclats d'aura. Les formes et l'accent de l'élément disent qui frappe ; la couleur de ki du style peint le reste (un skin recolore ses effets) ;
- KAI ki (traits, anneaux) · TARO feu (traînée de feu, anneaux, braises) · ZEPHYR vent (croissants, rafales) · AKEMI ombre (entailles, X) · RYUKEN rage (traînées de chaleur, fissures rouges, fumée) · SHIN eau et lame (arcs du katana, ligne nette, sillage d'eau) · DAICHA vide (orbe, sphère noire) · HIBECARES pierre (poussière, éboulis) ;
- nouveaux : RAIJIN foudre (la poussée de lance est un éclair, coup lourd = foudre du ciel, impact en éclair, étincelles au dash, projectile éclair) · YUKINA glace (deux arcs d'éventails croisés, éclats de glace, ligne de givre, flocons qui tombent, projectile éclat qui tourne) · VENOM poison (trois griffures qui gouttent, crachat, éclaboussure et gouttes, nuage toxique) · GORAN titan (pas de lumière : le sol résonne, onde au sol, tremblement) · ASTER gravité (anneaux qui se referment sur le poing, implosion, puits gravitationnel) · HIBIKI son (ondes qui partent devant le coup, anneaux en rafale, pas qui battent la mesure) · KAZAN acier (trois arcs de griffes, marques de griffes, étincelles d'acier, chaîne) · KUREN sang (croissant pourpre, gerbe de gouttes, lance de sang, brume rouge) · SYLVA nature (fouet de liane en vague, feuilles, épines, pétales, piège d'épines) · ELIAN lumière (paume chaude, colonne de lumière, auréole) · NOVA machines (piston et vapeur, pixels qui « glitchent », réacteurs, drones et tirs) · KUROEN éclipse (ki rouge à cœur noir, petit soleil noir) · ASURA (deux coups dorés à la fois) · KUROEN SHIN (blanc et or) ;
- les marques des passifs (gel, poison, soin, miroir, ancre, entrave, domination, drones) prennent l'élément de leur perso ;
- légers : petites particules (≤ 4 par seconde), aucune en mode effets réduits, la moitié des morceaux en réduit ; chaque verbe vérifié au chargement (un verbe sans dessin = erreur) ;
- test « visual identity » (Kits) : chaque perso a son élément, aucun ne partage la paire coup / marque d'un autre, chaque verbe existe, couleurs valides, particules légères et coupées en réduit, chaque lanceur a son propre projectile.
- non vu dans Roblox (pas de rendu des parts ici) : à regarder en jeu et à doser.

Problèmes ouverts : rien n'a été joué dans Roblox Studio (KUROEN, griffes de KAZAN, auras,
nouveau boss, page succès, skins de boutique, VFX par perso).
Prochaine étape : jouer KUROEN contre KAI, TARO, AKEMI, RYUKEN, ZEPHYR, SHIN, GORAN, KAZAN,
HIBIKI en vrai et ajuster.

## Version 0.16.1 — 4 octobre 2026

Retours de Wilhem : « les bras d'ASURA quand il est en idle ou en animation d'ult » ; « une
deuxième vie avec une aura noire » ; « la garde du bas est trop forte » ; « ASURA est encore
trop simple pour les persos à longue allonge comme RAIJIN » ; « augmente l'IA d'ASURA, c'est un
boss, presque sans limite » ; « la première vie, laisse-la comme ça, mais la deuxième il doit
être tellement fort que ça doit seulement le remettre à mi-vie » ; « l'option succès doit
montrer où les voir » ; « un maximum de taf sur les sons, les musiques in game ».

- **Bras d'ASURA dans les ultimes** (`FourArms`) : la deuxième paire ne restait pas figée en
  garde pendant les scènes (debout, bras croisés, kiai, à genoux, projeté) ni pendant les coups
  mis en scène : elle joue maintenant chaque pose (clés `proud`, `crossed`, `flare`, `kneel`)
  et une rafale sur les coups sans données. Les outils (planches, storyboards) dessinent
  enfin ces bras (`tests/WeaponKit.luau`). Test Animation étendu (scènes, jamais à travers le
  corps).
- **SECONDE VIE d'ASURA** (`Stats.SecondLife`) : abattu une fois par match, il se relève à la
  moitié de sa vie dans une **aura noire** (fumée noire, corps assombri, contour rouge sang ;
  onde noire, « ASURA RISES AGAIN ») — et là c'est un monstre : tous ses coups au sol sont
  blindés, dégâts ×1,5, vitesse ×1,25, musique WRATH. Le coup qui l'abat n'est pas annoncé
  comme un K.O. ; le round continue. Tests (CombatSimulation).
- **Contre l'allonge** : quatre bras portent 1,25× plus loin (`Stats.Reach`), son dash avant
  encaisse un coup (COLÈRE D'ASURA), dash 44 ; l'IA du boss charge en dash seulement contre
  un perso qui l'out-range (RAIJIN, SHIN, KAZAN, MARION, ZEPHYR, SYLVA).
- **IA du boss** : réaction 1 image, garde basse parfaite, lit chaque garde basse (overhead)
  et chaque saut, ne lâche jamais un combo, finit toujours en ultime. Réglée à la mesure
  (`tests/BossReport.luau`) : **ASURA gagne 97 % contre l'IA LÉGENDE**, tous persos confondus
  (30 matchs par perso ; RAIJIN 93 %+). Test FighterAI : le boss bat LÉGENDE, et ASURA bat
  la lance de RAIJIN (≥ 5/6).
- **Garde basse moins forte** : AVANT + R = l'**overhead** de chaque perso (son coup de
  marteau), à bloquer debout seulement (comme l'overhead de Street Fighter ou le « dust » de
  Guilty Gear) ; accroupi, la garde s'use 1,5× plus vite ; l'IA ouvre une garde basse avec
  l'overhead. Affiché à la sélection. Tests (20 persos).
- **SUCCÈS** : bouton ACHIEVEMENTS dans le menu (colonne de gauche) → page avec chaque succès,
  **où le gagner** (le mode), la progression (ex. 12 / 50) et ✓ débloqué ; lus du profil
  sauvegardé (`GameModes.ACHIEVEMENTS`, 12 succès). Test (Lobby).
- **Musique in game** (`shared/Music.luau` pur + `client/MusicController.luau`) : aucun
  fichier de musique n'est livré et aucun ID n'est inventé, donc un **séquenceur** joue la
  musique avec les sons du client Roblox (taikos, grosse caisse, caisse claire, charleston,
  pincements accordés à une gamme japonaise, basse, souffles, explosions ; réverbe et écho) :
  un thème par map (TEMPLE gamme in, FROZEN hirajoshi, NEON 150 bpm, VOLCANO phrygien,
  BAMBOO pentatonique majeure, SKY lydien), un thème MENU, ASURA, et WRATH (sa seconde vie,
  164 bpm). Trois niveaux : calme (menu, intro), combat, tension (un perso sous 30 % ou le
  round décisif) ; jingles FIGHT!, K.O., victoire, défaite ; baissée pendant les cinématiques.
  Réglage MUSIC dans SETTINGS. `Music.CUSTOM` : Wilhem peut y mettre plus tard ses propres
  musiques uploadées (un ID par thème), elles remplacent alors le séquenceur.
- **Sons** : COUNTER HIT, la seconde vie, FIGHT!, et les boutons des menus (survol, clic).
- **Bug corrigé : ASURA au mur spammait la même attaque** (facile à contrer). Cause : l'IA du
  boss jouait toujours une de ses 6 routes complètes, dont 2 ouvrent sur SMASH (13 images,
  un contre gratuit) : toujours les mêmes ouvertures. Maintenant, au neutre, il mélange jab,
  coup bas (accroupi) et overhead (avant + R), jamais deux fois la même ouverture de suite,
  jamais un coup lent pour ouvrir (seulement pour punir). Test (FighterAI, mur, garde debout
  et basse : ≥ 3 ouvertures, aucune > 60 %, coups lents ≤ 15 %) — il échouait avant le
  correctif. ASURA bat toujours LÉGENDE à 96 %.
- Version 0.16.1.

Tests : CombatSimulation 117, FighterAI 13, CinematicDirector 832, Animation 39, Kits 129,
PressQueue 4, Fuzz 2, Cinematography 296, Lobby 17. Balance (LEGEND, 120 matchs par duel, avec
l'overhead et la garde basse qui s'use) : moyennes de 39 % (KAZAN) à 62 % (VENOM), tous les
kits entre 35 et 65 %. Boss (`tests/BossReport.luau -a 30`) : ASURA bat l'IA LÉGENDE à 96 %.

Problèmes ouverts : rien n'est vérifié dans Roblox Studio — à écouter en jeu : le volume et
le rendu du séquenceur (les sons du client sont courts et peu nombreux : c'est une musique
de percussions, pas un orchestre) ; l'aura noire ; la page SUCCÈS sur mobile. Prochaine
étape : écouter, régler les volumes ; si Wilhem uploade ses musiques, les mettre dans
`Music.CUSTOM`.

## Version 0.16.0 — 4 octobre 2026

Retours de Wilhem : « passe tout le jeu en anglais ; avec la traduction Roblox ou un réglage
de langue, chacun l'aura dans sa langue » ; « vérifie qu'aucune animation ne soit partagée » ;
« un jeu de combat agréable, plusieurs persos au gameplay différent, avec leurs avantages et
leurs défauts, presque parfait en main, make it cool » ; « prépare différentes maps » ;
« un gros récap et plusieurs tests quand tout est fini ».

- **Le jeu est en anglais** (langue source de la traduction automatique de Roblox) : les 1 352
  textes (coups, persos, descriptions, menus, HUD, hub, cinématiques) ont été réécrits, les
  noms de coups en anglais façon anime (POING DU DRAGON → DRAGON FIST…). Nouveau réglage
  **SETTINGS › LANGUAGE**, gardé avec le profil :
  - AUTO (Roblox) : l'anglais, traduit par Roblox dans la langue du joueur ;
  - ENGLISH : jamais traduit ;
  - FRANÇAIS : le français d'origine du jeu, jamais re-traduit par Roblox.
  `src/shared/Locale.luau` (pur, généré depuis les textes français d'origine : rien n'est
  perdu) traduit les lignes entières, les lignes à trous (« You need 3 ki bars… ») et les
  lignes faites de morceaux ; `src/client/LanguageController.luau` l'applique à chaque texte
  des écrans. À régler une fois dans le Creator Dashboard : Localization › langue source
  anglais et traduction automatique activée (pour AUTO).
- **Aucune animation partagée** : les coups, gardes, courses et victoires étaient propres à
  chaque perso, mais les sauts, dashs, réactions aux coups, chutes, relevés et les poses des
  cinématiques étaient communs à tous, et la garde (bras) était identique chez 16 persos.
  Chaque perso porte maintenant son langage corporel dans toutes ces poses (sa garde, son
  buste, sa tête ; jambes et pieds intacts), RAIJIN garde les deux mains sur sa lance, et
  ASURA a sa propre version de chacun des coups de KAI. Test (Animation) : deux persos ne
  partagent aucune pose (écart d'au moins 5°), pieds au sol, articulations dans leurs limites.
- **Gameplay** :
  - chaque perso a son rythme (récupération après ses coups) : VENOM et HIBIKI enchaînent
    vite, GORAN, HIBECARES, SHIN, RAIJIN, ZEPHYR sont punissables s'ils ratent, etc. ;
  - **forces et faiblesses** calculées depuis les vraies données (PUISSANCE, VITESSE,
    ALLONGE, DÉFENSE, MOBILITÉ de 1 à 5) et affichées en barres à la sélection ; chaque perso
    est le meilleur quelque part et paie ailleurs, et deux persos n'ont jamais le même
    profil (test) ; ZEPHYR (1 350 PV, coups longs à récupérer), KUREN (moins mobile, un peu
    plus fort) et MARION (1 250 PV) retouchés ; TARO et AKEMI inchangés ;
  - **COUNTER HIT** (une lecture, jamais un cadeau — Wilhem : « ça ne doit pas casser les
    combos, ça doit arriver quand tu lis bien le jeu ») : seulement sur un coup lent (10 images
    de démarrage ou plus) lancé à froid depuis le neutre — jamais sur le coup suivant d'un
    enchaînement, jamais sur un jab, jamais pendant un combo ni sur une invincibilité ;
    +15 % de dégâts, un peu plus d'étourdissement, « COUNTER! ». Le CPU LÉGENDE s'en sert
    aussi ; l'IA d'ASURA est un peu plus vive. Tests.
- **6 maps** (`src/shared/Maps.luau`, construites côté client par `src/client/ArenaBuilder.luau`) :
  SCARLET TEMPLE (le temple), FROZEN LAKE (lac gelé, pins, aurore, neige), NEON ROOFTOP
  (toit d'une ville, enseignes néon, pluie), VOLCANO FORGE (basalte, rivière et chutes de
  lave, braises), BAMBOO DOJO (bambous, lanternes, feuilles), CLOUD PALACE (marbre au-dessus
  d'une mer de nuages, îles flottantes). Même sol de combat partout (y = 0, x de -28 à 28) :
  la map ne change que le décor. Choix STAGE à la sélection (RANDOM par défaut, tirée par le
  serveur en ligne) ; chaque joueur voit la map de son propre combat. Tests (Lobby).
- **Bug corrigé (prioritaire) : « Jouer entre amis »** — la fenêtre des joueurs et des
  invitations (`HubController`) était dans un ScreenGui d'ordre 8, sous le menu principal
  (ordre 20, plein écran) : elle s'affichait derrière lui et le menu prenait ses clics
  (boutons DÉFIER / INVITER inaccessibles) ; le bandeau d'un défi reçu était caché de la même
  façon. La fenêtre passe au-dessus du menu (ordre 30), avec un fond assombri qui bloque les
  clics vers le menu (un clic dessus la ferme), une taille relative à l'écran bornée (mobile
  et PC), un en-tête fixe, la liste des joueurs qui défile et un pied fixe avec un grand
  bouton INVITE A FRIEND toujours visible ; elle se remplit dès l'ouverture ; elle reste dans
  la zone sûre de l'écran (jamais sous la barre Roblox ni l'encoche d'un téléphone). Calcul de
  la disposition : 1920×1080, 1366×768, 1024×768, 844×390 et 667×375 → fenêtre entière et
  bouton INVITE visible partout. Le bouton doré
  « PLAYERS ON THE SERVER » n'apparaît plus qu'en combat (le menu a son bouton PLAYERS).
- **Bug corrigé (urgent) : beaucoup de persos portaient le skin de KAI.** En passant le jeu en
  anglais, les noms des styles avaient été traduits (« BRASIER » → « BLAZE »…) mais pas 17 clés
  de la table des styles (`CharacterData`) : le style par défaut de 12 persos était introuvable
  et le jeu retombait sur KAI. Clés réalignées, outil `rigcheck` mis à jour, nouveau test
  (Lobby) : chaque style de chaque perso existe, est bien le sien, et rangé sous son nom.
- **ASURA (boss) : plus massif, pas plus grand, et bien plus fort.** Corps : pectoraux,
  trapèzes, dorsaux, épaulières d'or, biceps et avant-bras épais, gantelets (`RigBuilder`,
  `BODIES.ASURA`) ; la deuxième paire de bras est aussi épaisse que la première (poings plus
  gros). Même taille que les autres : seule la largeur de son corps à toucher grandit
  (`Stats.Bulk` 1,2 → hurtbox plus large, même hauteur, même portée ; caméra des cinématiques
  cadrée en conséquence). Force : 3200 PV (2700), dégâts ×1,35 (×1,2), garde ×0,6 (×0,7),
  marche 18, et un passif **ASURA'S WRATH** (« COLÈRE D'ASURA ») : ses coups lourds au sol
  (Kick, Spin Kick, Hammer, Smash) encaissent un coup sans broncher (règle d'armure de GORAN),
  jamais ses jabs. Bras vérifiés : le test d'Animation pose ses quatre bras dans tous les états
  et tous ses coups, jamais à travers le corps. Tests : CombatSimulation (corps plus large,
  même hauteur, armure sur ses lourds seulement), FighterAI (le boss bat toujours LÉGENDE).
- Version 0.16.0.

Tests : CombatSimulation 114, FighterAI 12, CinematicDirector 832, Animation 39, Kits 128, PressQueue 4,
Fuzz 2 (toutes les paires de kits), Cinematography 296, Lobby 16. Balance (LEGEND, 120 matchs par duel) : moyennes de 38 % (KAZAN) à 63 % (TARO, VENOM), tous les kits entre 35 et 65 %.

Problèmes ouverts : rien n'est vérifié dans Roblox Studio (maps, réglage de langue, barres de
la sélection à regarder en jeu) ; la traduction automatique de Roblox dépend du réglage du
Creator Dashboard. Prochaine étape : jouer chaque map et chaque perso en vrai, ajuster.

## Version 0.15.3 — 4 octobre 2026

Retours de Wilhem : « le souci des combos, c'est injouable… TARO doit pouvoir faire un
uppercut qui fait décoller, un crochet vers le bas qui l'emmène au sol, l'adversaire rebondit…
prends un maximum d'exemples sur internet » ; « au pire supprime le R6 » ; « une ouverture et
une fin propres à chacun, toutes différentes… fais-en beaucoup plus, t'es libre » ; « pourquoi
tous les persos qui invoquent une matière invoquent de la pierre » ; « dans la sélection des
persos, petits problèmes avec les modèles » ; « teste avec 1000 à 10000 personnes » ; « audit,
review, bugs à régler ».

- **Combos à l'anime** (modèle : DBZ FighterZ, Marvel vs Capcom, le « bound » de Tekken —
  lanceur, on suit en l'air, coup vers le bas, rebond au sol une fois par combo, on ramasse,
  coup final). L L R R L R chez les 20 persos : l'uppercut fait décoller, le coup suivant
  (rôle DragonFist) **monte avec la cible** puis la **plante au sol** ; elle **rebondit** ;
  la poursuite plonge sur le rebond et le coup final la retrouve en l'air (`rise`, `homing`
  dans `CombatSimulation` : l'attaquant suit la hauteur de la cible pendant ses coups). Si le
  rebond est déjà pris, le coup garde la cible en l'air au lieu de casser le combo. En l'air,
  un coup « au sol » replie les jambes (`Animator`, AIR_TUCK) au lieu de rester debout dans
  le vide. Tests : CombatSimulation (le combo de TARO, écarts de hauteur), Kits (un seul
  lancer, au plus un rebond par route).
- **Bug corrigé** (trouvé par le Fuzz) : une cible « en l'air » posée au sol sans vitesse
  (après une cinématique, un spike au sol) restait bloquée en Launched ; elle atterrit
  maintenant tout de suite (test).
- **R6 retiré** du menu : APPARENCE alterne modèle en blocs ↔ avatar R15 (le code R6 reste
  pour les outils).
- **Ouvertures et fins des cinématiques** : 20 ouvertures et 20 fins (`GEN.OPEN`, `GEN.END`)
  peintes avec les effets, les poses et la couleur de chaque perso. Chacun des 13 persos
  thématiques a les siennes pour ses 4 ultimes, jamais les mêmes que les autres pour le même
  ultime, et tout est utilisé (nouveau test). Ouvertures : descend du ciel, sort du sol, dos
  tourné puis se retourne, entre à pas lents, se relève d'un genou, apparaît dans la face de
  la cible, charge et dérape, lévite, méditation, frappe le sol, tourbillon, silhouette en noir
  et blanc, l'énergie converge, la cible le cherche, grand saut, kata, sa marque court jusqu'à
  la cible, clones, gros plan qui recule, tempête. Fins : cratère, traversée (la cible tombe
  un temps après), envoyée au ciel, soufflée à l'autre bout, clouée au sol, lui tourne le
  dos, disparaît, plane au-dessus, piétine, salue, la caméra tourne autour, image figée,
  pluie sur la cible, passe à côté, écho du coup, rebonds, dernier kata, sceau, sort du
  cadre, ralenti. Exemples : RAIJIN descend du ciel / traverse ; GORAN saute / fait rebondir ;
  VENOM sort de l'ombre au sol / disparaît. Angles réglés pour les deux mains (`turn`).
- **Matières** : YUKINA, SYLVA, KAZAN (et les épines, le fer) invoquaient les piliers de
  pierre d'HIBECARES. Chacun a sa matière : glace (YUKINA), racines en bois (SYLVA), cage de
  barreaux de fer (KAZAN), épines, éclats de métal ; GORAN fissure le ring au lieu de faire
  sortir des rochers. La pierre reste à HIBECARES (et au sol que brise RYUKEN).
- **Sélection** : chaque modèle est posé à sa vraie hauteur (avant, les grands persos
  s'enfonçaient dans le sol et les petits flottaient), la caméra s'ajuste à sa taille (arme et
  bras d'ASURA compris), et le nom ne cache plus ses jambes.
- **Charge (1000 à 10000 joueurs)** : `luau tests/Load.luau -a 1000 5000 10000` (hors Roblox :
  un serveur Roblox tient au plus quelques centaines de joueurs, des milliers se répartissent
  sur plusieurs serveurs ; l'outil mesure ce que coûte le code d'un serveur). Deux points
  coûtaient N² et sont corrigés :
  - la recherche classée comparait tout le monde à tout le monde : elle trie par cote et
    cherche le voisin le plus proche (10 000 en file : 0,3 ms) ;
  - chaque joueur recevait le nom de tous les joueurs à chaque changement : chacun reçoit
    une vue courte (lui, ses défis, puis 40 noms au plus), au plus deux envois par seconde
    (vues pour 10 000 joueurs : 5,1 s → 83 ms ; 1000 : 7 ms).
  Un combat coûte ~0,01 ms par tick (IA comprise). Test Lobby : 10 000 joueurs appariés
  juste (même file, même taille d'équipe, écart de cote dans la fenêtre) et vues courtes.
- Version 0.15.3.

Tests : CombatSimulation 111, FighterAI 12, CinematicDirector 832 (nouveau : ouvertures et fins
propres à chacun), Animation 38, Kits 128, PressQueue 4, Fuzz 2, Cinematography 296, Lobby 12
(nouveau : 10 000 joueurs). Équilibrage : voir plus bas (en cours au moment du commit).

Problèmes ouverts : rien n'est vérifié dans Roblox Studio (cadrages, matières, aperçus et
charge réelle du réseau restent à voir en jeu) ; la taille max d'un serveur se règle dans les
paramètres du jeu (pas dans le code). Prochaine étape : regarder en jeu les 20 ouvertures et
fins et les combos rebond, ajuster ce qui se lit mal.

## Version 0.15.2 — 4 octobre 2026

Retours de Wilhem : « RAIJIN a une lance, pas une épée, fais-le taper réellement » ; « L L R R
L R a disparu avec plusieurs persos » ; « mets par défaut le modèle classique, R6 et R15 en
option, et affiche les modèles 3D avec une pose pendant la sélection » ; « amélioration globale
de l'UI » ; « les deux autres bras d'ASURA sortent des côtés normalement » ; « les cinématiques
doivent aussi être toutes différentes et cohérentes ».

- **RAIJIN se bat à la lance** : les deux mains sur la hampe (la gauche devant la droite), des
  estocs droits sur l'adversaire qui vont loin (6 à 9 studs de pointe), des coups de hampe et
  des balayages à plat, des coups montants et plongeants. Les angles des bras de chaque pose
  clé sont trouvés hors ligne par `tests/SpearFit.luau` (il cherche les bras qui posent la
  lance sur la ligne du coup, main gauche sur la hampe) et rangés dans `PoseLibrary` (table
  `HOLD` de RAIJIN, sa garde, son accroupi, sa victoire). Nouveau test (Animation) : les
  estocs partent droit, loin, d'une lance ramenée en arrière, et la main gauche tient la hampe.
- **Armes d'un avatar R6** : le bras R6 n'a pas de poignet ; la lance, le katana et les
  éventails suivent maintenant la main du corps R15 virtuel, poignet compris
  (`Retarget.solve` rend aussi les parties virtuelles ; `AnimationController` pilote les
  soudures des pièces de l'arme ; planches et tests font pareil). La pointe de la lance ne
  s'appelle plus « Head » (même nom que la tête du perso).
- **Bras d'ASURA** : la deuxième paire sort maintenant des flancs, sous les vraies épaules
  (plus du dos) ; test : les épaules sont sur les côtés et les bras ne traversent jamais le corps.
- **Combos qui « disparaissaient »** : le combo et l'ultime marchent (simulation : L L R R L R
  passe ses 8 coups chez les 20 persos, `ClipKit` sait maintenant jouer une route comme un
  joueur : `luau tests/AnimClip.luau -a KIT LLRRLR`). Cause probable : le panneau COMBOS ne
  défilait pas ; avec les noms de coups longs des nouveaux persos, les routes complètes
  (dont L L R R L R) passaient sous le bas de l'écran. Le panneau défile, et les routes
  complètes sont en tête, avec leurs premiers coups.
- **Sélection** : le perso en blocs (modèle classique) est l'apparence par défaut ; APPARENCE
  passe ensuite à l'avatar R15 puis R6. L'écran de sélection montre le **modèle 3D** du perso
  (et d'ASURA en face en mode défi) dans sa **pose de victoire**, animée par le vrai Animator
  (le serveur prépare les modèles : `ReplicatedStorage.KitPreviews`).
- **Interface** : chaque bouton du menu grossit un peu au survol et s'enfonce au clic ; les
  pages arrivent avec un petit zoom ; les boutons du combat ont des coins arrondis et
  réagissent au survol ; les panneaux COMBOS et LABO défilent.
- **Cinématiques toutes différentes** : ASURA et les 12 persos de la troisième planche
  partageaient 7 façons de se battre ; 10 nouvelles mises en scène s'y ajoutent
  (`CinematicDirector`, `GEN.strike`), chacune liée à une arme ou un pouvoir :
  - estocs de lance qui avancent d'un pas à chaque coup ;
  - cible figée par la glace ou un sceau de lumière ;
  - traque sortie de l'ombre (devant, puis derrière) ;
  - rythme (la cible saute sur chaque temps) ;
  - pantin tiré d'un côté à l'autre par ses fils ;
  - cible qui tourne au bout d'une chaîne ;
  - pluie venue du ciel ;
  - racines qui soulèvent ;
  - piliers de lumière ;
  - tirs croisés de tous les côtés.
  Chaque perso a 4 ultimes mis en scène de 4 façons différentes, et deux persos n'ont jamais
  la même pour le même ultime (nouveau test, CinematicDirector). Exemples :
  - RAIJIN : estocs / foudre du ciel / piliers d'éclairs / coups de tous côtés ;
  - KAZAN : tourne au bout de la chaîne / crochet lancé droit / saisie / attire.
  Les angles des plans sont réglés pour chaque perso (`turn`).
- Version 0.15.2.

Tests : CombatSimulation 109, FighterAI 12, CinematicDirector 831 (nouveau : mises en scène toutes
différentes), Animation 38 (nouveau : la lance de RAIJIN ; les bras d'ASURA sur les flancs),
Kits 128, PressQueue 4, Fuzz 2, Cinematography 296 (les derniers réglages d'angle de GORAN et
RAIJIN vérifiés sur eux seuls), Lobby 11 ; `rigcheck` : tous les corps se construisent.
Équilibrage inchangé (aucune vie, dégât ni vitesse touchés). **Rien essayé dans Studio.**

### Problèmes ouverts / prochaine étape

- Juger dans Studio l'aperçu 3D de la sélection, la lance de RAIJIN (corps en blocs et avatar
  R6), les bras d'ASURA, les nouvelles cinématiques.
- Les cinématiques des 12 suivent toujours le même déroulé (ouverture, rafale, charge, coup
  final) ; seule la façon de se battre change : une ouverture et une fin propres à chacun
  seraient la suite.

## Version 0.15.1 — 4 octobre 2026

Demandes de Wilhem : « travaille les 4 bras d'ASURA, c'est dégueulasse ; chaque perso est
censé avoir sa propre animation, prends le temps de faire du bon taf » ; « prends tout ton
temps pour toutes tes animations » ; « chaque animation est obligatoirement différente » ;
« tu as géré les animations des armes ? » ; l'écran de sélection façon Street Fighter IV.

- **Les quatre bras d'ASURA refaits** (`src/shared/FourArms.luau`, module pur testé) : chaque
  bras du bas a un bras, un avant-bras et un poing articulés à l'épaule et au coude (deux
  Motor6D, `RigBuilder.addFourArms`), une garde levée façon statue, des frappes, les pistons
  décalés de la GATLING, le blocage et les réactions. Le client applique maintenant aussi la
  torsion de l'avant-bras (`AnimationController`, même ordre que `FourArms.solve`, que vérifient
  les tests : les bras ne traversent jamais le torse ni la tête). La GATLING d'ASURA a ses
  propres poses (elle reprenait celles de TARO).
- **Les 12 nouveaux persos ont leurs propres animations** : chacun de leurs 29 coups a ses
  poses (lance, éventails, griffes, prises, gravité, rythme, fils, chaînes, sang, lianes,
  lumière, gantelets), sur leur propre garde.
- **Armes en main** : la lance de RAIJIN et les deux éventails de YUKINA sont tenus en main
  (`WeaponSpec.RAIJIN`, `WeaponSpec.YUKINA` avec sa paire), sur le corps en blocs comme sur un
  avatar ; les coups balaient vraiment avec l'arme ; les planches `PoseSheet` les dessinent.
  Nouveau test : aucune arme en main (katana, lance, éventails) ne traverse le sol pendant un
  coup au sol (des lames de SHIN s'y enfonçaient : ESTOC, BRISE-GARDE, ENVOL, FENDOIR…).
- **Chaque animation est différente** : les 8 premiers persos empruntaient encore 43 poses
  de KAI (TARO, ZEPHYR, AKEMI, RYUKEN) et rejouaient leur finisher dans leurs ultimes ;
  RYUKEN portait les coups de boxe de TARO. Chacun a maintenant ses propres coups, dans son
  style : TARO (crochet au foie, uppercut court, shovel hook, haymaker, uppercut céleste,
  dernière cloche…), ZEPHYR (circulaire, retourné, coup de pied arrière, ciseaux, hélicoptère,
  hache, salto arrière, grand écart…), AKEMI (roue, vrille, talon furtif, fauche, marque,
  instant volé dans le dos…), RYUKEN en bagarreur (lariat, coup de tête, dropkick, revers
  tournant, genou en clinch, piétinement, marteaux), et des ultimes propres à KAI, SHIN,
  DAICHA, HIBECARES. Les appels et récupérations restés communs (une mise en garde partagée
  par les ultimes d'un perso) deviennent les leurs à partir du coup : anticipation à l'appel,
  continuité du geste à la récupération (`PoseLibrary`, fin du fichier, jambes intactes).
  Nouveau test : aucun coup des 20 persos n'emprunte les poses de son rôle et aucune pose
  clé n'est partagée entre deux coups (`Poses.signature`).
- Son : GORAN a son bruit d'onde de choc (sa technique à distance n'en avait pas).
- Cadrages : le test « les deux mains se lisent dans chaque plan » ne montrait que le premier
  plan fautif ; un script les a tous listés. Les plans où une main en cachait une autre sont
  réorientés (`frameOn`) : DERNIÈRE CLOCHE de TARO, DRAGON ASCENDANT de ZEPHYR, INSTANT VOLÉ
  d'AKEMI, DERNIER ROUND et POING DU MONDE de RYUKEN, VENOM (angles), RAIJIN (ÉVEIL : il tourne
  autour de sa cible) ; et 9 des 12 nouveaux (GORAN, ASTER, HIBIKI, MARION, KAZAN, KUREN,
  SYLVA, ELIAN, NOVA) ont un réglage d'angle par plan (`turn` dans `GEN.add`, appliqué par
  `GEN.frame` à tous les plans générés).
- Version 0.15.1.

Tests : CombatSimulation 109, FighterAI 12, CinematicDirector 830, Animation 37 (3 nouveaux :
chaque coup a sa propre animation, aucune arme sous le sol, les finishers et ultimes ajoutés
au test « jamais deux poings collés »), Kits 128 (son de GORAN), PressQueue 4, Fuzz 2,
Cinematography 296 (le dernier réglage de GORAN vérifié sur GORAN seul), Lobby 11 ;
`rigcheck` : tous les corps se construisent ; `AnimQuality` : pas d'à-coup anormal. **Rien essayé dans Studio.**

Équilibrage : aucune vie, aucun dégât ni aucune vitesse retouchés (seulement des poses) : les
chiffres de la 0.15.0 restent valables.

### Problèmes ouverts / prochaine étape

- Juger dans Studio les nouvelles animations (surtout RYUKEN, ZEPHYR et les ultimes), la lance
  et les éventails tenus en main, les quatre bras d'ASURA.
- TARO reste à 65,1 % au niveau 4 (non retouché à la demande de Wilhem).
- File d'attente commune à tous les serveurs (MemoryStore + téléportation).

## Version 0.15.0 — 4 octobre 2026

Demandes de Wilhem : « fais ASURA, les combats 2-3 en ligne, des plus grands serveurs » ;
« rends tout plus beau » ; les 12 fiches de la troisième planche (RAIJIN, YUKINA, VENOM,
GORAN, ASTER, HIBIKI, MARION, KAZAN, KUREN, SYLVA, ELIAN, NOVA) avec leurs étoiles ; « tu as
fait des cinématiques pour ASURA ? » ; « mets trois losanges en 3v3 (best of 5) et une attaque
gatling à ASURA avec tous ses bras » ; « tu n'as pas fait de modèle à ASURA » ; « n'oublie pas
les modèles 3D de tout le monde » ; la capture du lobby (titre de K.O. resté affiché).

- **12 nouveaux persos** (`MoveData.luau`, `newKit` : chaque rôle de KAI reçoit le coup du kit,
  `<Prefixe><Rôle>`), avec les vies, étoiles, passifs, S + E et ultimes des fiches. KitOrder :
  20 persos. Leurs S + E : LANCE FOUDROYANTE (projectile rapide), MIROIR DE GLACE (renvoie les
  projectiles, `move.reflect`), BRUME TOXIQUE (nuage lent), ÉTREINTE DU TITAN (saisie
  imparable, `move.grab`, rate un adversaire en l'air), ATTRACTION (`projectile.pull`), ONDE
  SONIQUE, FILS CROISÉS (`projectile.bind`), CROCHET DU GEÔLIER (attire), LANCE SANGUINE,
  RACINES VORACES (piège posé au sol : `projectile.trap`, vitesse 0, ralentit), IMPULSION
  VITALE (`move.heal`), SENTINELLE (`move.drone` : un drone qui tire 3 fois, `world.drones`).
- **12 passifs, chacun une vraie mécanique** (`CombatSimulation.luau`, table `PASSIVE`) :
  SURCHARGE (3 coups d'affilée → prochaine technique : allonge ×1,35, +15 %), GEL PROGRESSIF
  (3 givres → −20 % de vitesse 3 s), CONTAMINATION (poison 3 charges max, ne tue jamais),
  ANCRAGE (armure d'un coup sur les gros coups au sol), MASSE VARIABLE (+30 % sur la prochaine
  attaque aérienne), TEMPO (3 coups en rythme → récupérations ×2 pendant 4 s), DOUBLE
  COMMANDE (le pantin frappe de l'autre côté après FILS CROISÉS), ENTRAVE (2 techniques → le
  prochain dash adverse coupé de moitié), PACTE ÉCARLATE (−3 % de vie par technique, jamais
  mortel, +30 %), TERRITOIRE (un piège près d'elle → allonge ×1,2), SECOND SOUFFLE (sous 30 %,
  soin ×3 une fois par manche), INGÉNIERIE (2 drones, un toutes les 9 s). Le HUD affiche leur
  état (`Sim.passiveLabel`, envoyé dans le snapshot), avec bulles (GELÉ !, ANCRAGE !,
  +PV, MIROIR DE GLACE !…), sons et marques à l'écran.
- **Cinématiques** : un réalisateur à thèmes dans `CinematicDirector.luau` (`GEN`, table
  unique pour rester sous la limite de noms locaux) : chaque perso a son étalonnage (orage,
  givre, toxique, titan, cosmos, son, marionnette, fer, sang, sauvage, sacré, tech, et le noir
  et or d'ASURA), ses propres effets (lance-éclair, éclats de glace, griffes, chaînes,
  drones…), sa façon de se battre par ultime (archétypes : estocs de tous côtés, tourne
  autour, à distance, saisies, jongle, attire, et la **gatling** d'ASURA), ses angles, ses
  poses, et des noms de plans à lui ; R, ÉVEIL, PORTE, COUP FATAL et écran de K.O. pour
  chacun. Le cadrage vérifie la ligne de vue (un perso qui tourne autour de sa cible ne la
  cache jamais). Le client dessine chaque effet avec un accessoire existant à la couleur du
  perso (`THEME_FX`) et crée une ColorCorrection par étalonnage (`THEME_GRADES`).
- **ASURA** : ses propres cinématiques (avant, il rejouait celles de KAI : la simulation passe
  maintenant le kit de l'attaquant, `cin.kit`), **GATLING DES QUATRE BRAS** (E au sol : 12
  coups, les deux bras du bas pistonnent en décalé), et son **propre modèle** (crinière noire
  et or, troisième œil, torse nu barré de chaînes d'or, bracelets, hakama, pieds nus, 4 bras).
- **Modèles 3D** : 13 nouveaux corps en blocs (`RigBuilder.BODIES`, coiffures et tenues des
  fiches : la lance de RAIJIN dans le dos, les éventails de YUKINA à la ceinture, le masque et
  les griffes de VENOM, le singlet et la barbe de GORAN, les anneaux d'ASTER, le casque de
  HIBIKI, les fils de MARION, les chaînes de KAZAN, le manteau de KUREN, l'écorce de SYLVA,
  la croix de lumière d'ELIAN, les gantelets et les deux drones de NOVA) et les tenues
  portées sur un avatar Roblox (`OUTFITS`). 2 styles de couleurs chacun (`CharacterData`).
  Gardes, courses, respirations et poses de victoire propres (`PoseLibrary` `thirdKit`,
  `Animator.IDLE_RHYTHM`). Les armes restent portées (lance dans le dos, éventails à la
  ceinture) : une vraie arme en main demanderait ses animations (règle des armes).
- **Manches** : le 1 contre 1 est un vrai **2 manches gagnantes** (avant, un 1v1 passait par
  les équipes et finissait au premier K.O.) ; 2v2 / 3v3 restent des relais : **3 losanges en
  3v3** (un par adversaire mis K.O., jusqu'à 5 manches). `Sim.setLineup`. L'écran de K.O.
  final n'arrive plus en plein relais.
- **Lobby** : le titre « K.O. · … VICTOIRE » ne reste plus affiché au retour au menu (la
  cinématique est fermée au changement de combat) ; la liste des joueurs de Roblox (en haut
  à droite) est masquée (notre liste : H) ; grille de sélection 5 × 4 ; MES PERSONNAGES
  défile ; NOUVEAUTÉS annonce les 12.
- **Écran de sélection façon Street Fighter IV** (référence de Wilhem) : ton perso en grand à
  gauche (son kanji en portrait, son nom en grosses lettres, son badge), l'adversaire à droite
  (CPU, ADVERSAIRE ou ASURA), la colonne de portraits au milieu (4 × 5) sous l'emblème VS, les
  options et COMBAT ! en bas. Pas d'image : aucun ID d'asset.
- **Serveurs** : README, comment monter le nombre max. de joueurs (jusqu'à 100 par place).
- Version 0.15.0.

Tests : CombatSimulation 109 (13 nouveaux : un par passif, le miroir, les manches), FighterAI
12, CinematicDirector 830 (les 20 persos + ASURA), Animation 35, Kits (voir plus bas),
PressQueue 4, Fuzz 2, Cinematography (plan de la rafale de YUKINA corrigé, suite relancée), Lobby 11 ; Kits pas encore relancé sur les 20 persos ; `rigcheck` : tous les corps se
construisent (planche `rigcheck render` vérifiée). **Rien essayé dans Studio.**

Équilibrage (CPU contre CPU, `luau tests/Balance.luau`, moyennes contre tout le plateau) :
niveau 4 (120 matchs par duel) : TARO 65,1, GORAN 61,0, HIBECARES 60,3, VENOM 60,2,
ZEPHYR 55,0, RYUKEN 53,4, KAI 53,2, RAIJIN 52,1, DAICHA 52,1, SHIN 50,7, SYLVA 47,7, KAZAN 45,3,
HIBIKI 44,8, NOVA 44,1, ELIAN 44,0, YUKINA 43,7, ASTER 43,3, AKEMI 41,9, MARION 41,4, KUREN 40,7 %.
Niveau 3 (60 matchs) : entre 39 (MARION) et 62 % (GORAN). TARO dépasse de 0,1 point la limite
de 65 % ; AKEMI et TARO ne sont pas retouchés, à la demande de Wilhem.

### Problèmes ouverts / prochaine étape

- Juger dans Studio les 13 nouveaux corps, leurs effets et leurs étalonnages.
- Vraies armes en main (lance de RAIJIN, éventails de YUKINA) avec des animations d'arme.
- Poses d'attaque propres aux 12 (ils empruntent les gestes des rôles de KAI) et planches
  `PoseSheet` pour chacun.
- File d'attente commune à tous les serveurs (MemoryStore + téléportation).

## Version 0.14.1 — 3 octobre 2026

Retour de Wilhem (avec une image de lobby faite sous ChatGPT) : « un truc similaire à ça ».

- **Nouveau menu (lobby)** sur le modèle de l'image, sans aucun asset image (pas d'ID inventé) :
  barre du haut (logo K.O. 開 sur un coup de pinceau rouge, onglets JOUER / PERSONNAGES /
  CLASSEMENT / PARAMÈTRES, carte de profil avec la photo Roblox du joueur via
  `GetUserThumbnailAsync`, rang, barre vers le rang suivant, points ◆ et victoires) ; colonne
  de gros boutons inclinés à gauche (JOUER, PERSONNAGES, CLASSEMENT, JOUEURS, PARAMÈTRES) ;
  **le perso favori en 3D au centre** (rig construit par le serveur dans
  `workspace.Fighters.Lobby_<id>`, visible seulement par son joueur, en pose de victoire puis
  en garde, caméra en contre-plongée) ; cartes de mode à droite (MODE EN LIGNE, MODE SOLO,
  ÉQUIPES 1V1·2V2·3V3, ENTRAÎNEMENT) ; NOUVEAUTÉS et MES PERSONNAGES en bas (un clic = favori).
  Tout le menu est dans un cadre 1600 × 900 mis à l'échelle de l'écran.
- Pages : MODE SOLO (1V1 IA, SURVIE, CHALLENGE bientôt), MODE EN LIGNE (CLASSÉ, NORMAL, DÉFIER
  UN AMI), sélection des persos (le favori présélectionné), recherche, PERSONNAGES (fiche :
  description, vie, vitesse, passif, ultimes), CLASSEMENT (top 10 des points :
  `OrderedDataStore` « JeuxCombat_Classement_v1 », relu toutes les 60 s ; jeu publié seulement),
  PARAMÈTRES (effets, son, souris bloquée).
- La souris bloquée ne s'applique qu'en combat : au menu, le curseur revient toujours.
- Tests : CombatSimulation 94, FighterAI 11, CinematicDirector 323, Animation 35, PressQueue 4,
  Fuzz 2, Cinematography 114, Lobby 9 (Kits inchangé : 67 sur 68, voir 0.14.0) ; `rigcheck` :
  tous les corps se construisent. Menu non testable hors Studio : **rien essayé dans Studio**.

### Problèmes ouverts / prochaine étape

- Juger le cadrage du héros et la lisibilité du menu dans Studio (plusieurs tailles d'écran).
- CHALLENGE (ASURA) ; recherche entre serveurs si besoin.

## Version 0.14.0 — 3 octobre 2026

Demandes de Wilhem : « un menu à la Street Fighter, sélection du mode : survie, 1v1 IA, joueur,
entraînement ; dans les 1v1 l'option 1, 2 ou 3 persos comme FighterZ ; des games classées et
normales avec recherche d'adversaire ; optimise le multi pour que 150 personnes jouent en même
temps » ; « la fenêtre de défi est grise, on ne voit pas bien la croix ».

- **Plusieurs combats par serveur** (`src/server/init.server.luau` réécrit) : chaque combat
  (`match`) a son monde de simulation, ses deux places (joueur, CPU ou mannequin), son CPU et
  ses rigs dans `workspace.Fighters.Match<id>`. Tous partagent la même arène ; chaque client
  ne dessine que les deux combattants de son combat (les autres sont cachés chez lui :
  `LocalTransparencyModifier`, jamais sur le serveur ; les rigs sont ancrés et sans collision).
  Snapshots et événements ne partent qu'aux joueurs du combat. Le pas de simulation est très
  léger (des dizaines de milliers de combats CPU tournent en quelques minutes dans les tests) ;
  au-delà d'un serveur plein, Roblox en ouvre d'autres. Attribut `MatchId` du joueur.
  `RigBuilder` prend maintenant le look en paramètre (un look par combat, plus de
  `CharacterData` global côté serveur).
- **Menu principal** (`src/client/MenuController.luau`) : écran des modes (liste, description,
  kanji, profil : rang, points, V/D, record SURVIE, joueurs et combats en cours), sélection des
  persos (grille des 8 avec ★, ordre de passage, ÉQUIPE 1 à 3, NIVEAU CPU ou PARTIE NORMAL /
  CLASSÉ / AMI), écran de recherche (chrono, joueurs en file, ANNULER), bandeau de résultat.
  Clavier, souris, tactile, manette ; caméra lente sur l'arène derrière. En combat : ◀ MENU / P.
- **Modes** (`src/shared/GameModes.luau`, pur) : 1 CONTRE 1 · IA (équipe 1-3, niveau),
  1 CONTRE 1 · JOUEUR (NORMAL, CLASSÉ, AMI), SURVIE (vagues de plus en plus fortes : FACILE
  vagues 1-2, NORMAL 3-4, DIFFICILE 5-7, LÉGENDE ensuite ; record sauvegardé), ENTRAÎNEMENT
  (mannequin, labo, ULTIMES : ON), CHALLENGE (verrouillé, « bientôt »). Le serveur valide chaque
  demande (mode, persos, taille d'équipe, niveau, file).
- **Équipes (relais)** dans la simulation : `Sim.setTeams`, un K.O. élimine le perso, le
  suivant entre (événement `TeamSwap`, le serveur reconstruit le rig), le gagnant garde sa vie
  (+20 %, `TeamHealOnKO`) et son ki ; l'équipe vide perd. HUD : ✕ ● ○ sous le nom.
- **Recherche d'adversaire** (`src/server/Matchmaker.luau`, pur) : NORMAL = premier arrivé ;
  CLASSÉ = écart de points ≤ 100, +25 par seconde d'attente (max 800), le plus proche d'abord ;
  Elo K = 32, départ 1000, rangs BRONZE → LÉGENDE. Quitter un 1v1 le donne perdu. Profil
  (points, V/D, record SURVIE) sauvegardé par DataStore (jeu publié seulement).
- **Fenêtre des joueurs / défis** (ex-HUB) : fond opaque, **grosse croix rouge ✕** (44 px, fond
  rouge, contour blanc), état de chaque joueur (AU MENU, RECHERCHE, EN COMBAT…), plus
  d'ouverture automatique ; un défi accepté lance un 1v1 avec l'équipe choisie au menu.
- Tests : Lobby 9 (+4 : demandes du menu, vagues de SURVIE et équipes CPU, recherche NORMAL /
  CLASSÉ qui s'élargit, Elo et rangs), CombatSimulation 94 (+2 : relais), FighterAI 11,
  CinematicDirector 323, Animation 35, Kits 67 sur 68 (équilibre : AKEMI 35 % en LÉGENDE, laissée
  telle quelle à la demande de Wilhem), PressQueue 4, Fuzz 2, Cinematography 114 ;
  `rigcheck` : tous les corps se construisent. Le serveur, le menu et la recherche ne sont pas
  testables hors Studio : **rien n'a été essayé dans Roblox Studio**.

### Problèmes ouverts / prochaine étape

- À vérifier dans Studio (Test › Clients et serveurs, 2 à 3 joueurs) : menu, 1v1 IA en équipe,
  SURVIE, recherche NORMAL entre deux clients, défi d'ami, retour au menu.
- La recherche se fait sur le serveur du joueur (pas encore entre serveurs : MemoryStore +
  TeleportService à faire si les serveurs sont trop vides).
- CHALLENGE (ASURA, KAI à quatre bras) : prochaine étape.
- Toujours : AKEMI 37 % / TARO 65 % en LÉGENDE (laissés tels quels à la demande de Wilhem).

## Version 0.13.7 — 3 octobre 2026

Retours de Wilhem : « quand TARO esquive il prend forcément le dessus, ce n'est pas normal que je
puisse le taper pendant son esquive » ; « pas tous les combos doivent envoyer en l'air plusieurs
fois » ; « laisse AKEMI et TARO comme ça ».

- **TARO (ESQUIVE)** : une esquive comptée esquive maintenant **tout sauf les ultimes** (coups
  bas et projectiles compris) ; il reste baissé 8 images après le dash (`Weave.Duck`), la fin
  du Dempsey Roll comprise ; l'attaquant esquivé reste figé 18 images de plus que lui
  (`SlipAdvantageTicks`) et la fenêtre du DEMPSEY ROLL se rouvre : TARO prend la main (sonde :
  le gros coup esquivé, puis 4 crochets du Dempsey qui touchent).
- **Une seule vraie projection par combo** : un lanceur sur une cible déjà en l'air ne la
  relance plus haut, il la maintient (vitesse plafonnée à `RelaunchVelocity = 20`). Avant, une
  route complète comme FOUDRE de KAI projetait 5 fois. Toutes les routes complètes des 8 persos
  passent encore.
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 48, TARO 65, ZEPHYR 51, AKEMI 37,
  RYUKEN 47, SHIN 49, DAICHA 50, HIBECARES 55 ; DIFFICILE : KAI 50, TARO 59, ZEPHYR 54,
  AKEMI 44, RYUKEN 50, SHIN 49, DAICHA 46, HIBECARES 48. Sur demande de Wilhem, AKEMI et TARO
  ne sont pas retouchés : TARO est à la limite haute (65 %) et AKEMI basse en LÉGENDE ; le test
  d'équilibre de Kits (60 matchs par duel) échoue de justesse (AKEMI 35 % en LÉGENDE).
- Tests : Kits 68 (+8 : une seule projection haute par route complète, 8 persos ; TARO esquive
  un coup bas et prend la main) dont l'équilibre en échec ci-dessus, CombatSimulation 92,
  FighterAI 11, CinematicDirector 323, Animation 35, PressQueue 4, Fuzz 2, Cinematography 114,
  Lobby 5.

### Problèmes ouverts / prochaine étape

- AKEMI / TARO en LÉGENDE (voir plus haut) : à juger en vrai match avant d'y retoucher.
- « Le final de SHIN » : à préciser avec Wilhem.
- Menu façon Street Fighter et modes de jeu.

## Version 0.13.6 — 3 octobre 2026

Retour de Wilhem : « le fatal de SHIN, ce n'est pas le QTE, c'est l'animation en combo : elle
est bloquable ».

- Cause (sonde sur toutes les routes des 8 persos) : après un coup qui projette ou repousse
  (L L L R, R R…), la cible s'envolait pendant le démarrage du coup fatal (14 images après le
  flash), le fatal frappait dans le vide, la cible retombait et punissait la longue récupération.
- Correctif : un ultime lancé **en plein combo** sur une cible encore touchée (étourdie, chiffonnée
  ou projetée) la fige aussi pendant son démarrage (`hitstop` = flash + démarrage) : il touche à
  coup sûr. Lancé à froid, il reste gardable et esquivable. (Les fatals tentés en l'air, après la
  poursuite aérienne, ne partent toujours pas : le coup fatal est au sol.)
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 50, TARO 60, ZEPHYR 49, AKEMI 42,
  RYUKEN 49, SHIN 45, DAICHA 51, HIBECARES 55 ; DIFFICILE : KAI 50, TARO 56, ZEPHYR 55,
  AKEMI 45, RYUKEN 51, SHIN 48, DAICHA 48, HIBECARES 47.
- Tests : Kits 60 (+1 : coup fatal après L L L R, L R et R R contre une garde, 8 persos),
  CombatSimulation 92, FighterAI 11, CinematicDirector 323, Animation 35, PressQueue 4, Fuzz 2,
  Cinematography 114, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- TARO à 60 % en LÉGENDE : à surveiller.
- Menu façon Street Fighter et modes de jeu (en cours).

## Version 0.13.5 — 3 octobre 2026

Retours de Wilhem : « TARO dash en mode ESQUIVE, ça dit qu'il esquive mais il n'esquive pas ;
mets un petit ralenti en noir et blanc, fais comme AKEMI, limité à 3, des esquives à la Dempsey
Roll » ; « l'ISSEN de SHIN, le timing est trop serré » ; « nerf un peu la jauge d'énergie, on a
nos ultimes trop vite » ; « pour la phrase du PERFECT, cherche sur internet des phrases de
moquerie ».

- **TARO (ESQUIVE)** : l'esquive ne couvrait que les 9 images du dash ; le coup adverse, encore
  actif, touchait juste après « ESQUIVE ! ». Un coup esquivé rate maintenant **jusqu'au bout**.
  **3 esquives** (`Weave.Charges = 3`, ●●● à côté de la garde), chacune revient en 7 s
  (`Cooldown = 420`), l'une après l'autre ; sans charge, plus d'esquive. Chaque esquive fige les
  deux combattants 14 images (`SlipFreezeTicks`) et passe l'écran en **noir et blanc** 0,45 s.
- **Coup fatal (ISSEN et les autres)** : fenêtre du QTE C ±4 → ±9 images (±0,15 s).
- **Jauge de ki** : gains ~−35 % (porté 0,28 → 0,18, reçu 0,16 → 0,10, en garde 0,25 → 0,15 et
  0,2 → 0,12, esquive de TARO 12 → 8). Mesure (CPU DIFFICILE, 40 matchs) : premier ultime
  après 12,2 s → 19,2 s de combat ; ultimes par round 1,14 → 0,91.
- **Phrases du PERFECT** prises sur le web : « GIT GUD. » (argot Dark Souls), « FLAWLESS
  VICTORY. », « TOASTY! », « GET OVER HERE… » (Mortal Kombat), « You must defeat Sheng Long to
  stand a chance. » (Ryu), « Handsome fighters never lose battles. » (Vega), « I will meditate
  and then destroy you! » (Dhalsim, Street Fighter II), « Comme voler un bonbon à un bébé… »
  (Walshy, Halo), « You can't beat me. » (LowTierGod) ; plus 5 des nôtres. Sources :
  tvtropes.org (Victory Quote), meme.com (git gud), 3djuegos.com (trash talk).
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 51, TARO 57, ZEPHYR 49, AKEMI 42,
  RYUKEN 49, SHIN 45, DAICHA 50, HIBECARES 57 ; DIFFICILE : KAI 50, TARO 54, ZEPHYR 54,
  AKEMI 46, RYUKEN 51, SHIN 49, DAICHA 50, HIBECARES 46.
- Tests : Kits 59 (+1 : coup esquivé raté jusqu'au bout, 3 charges, plus d'esquive sans
  charge, recharge), CombatSimulation 92, FighterAI 11, CinematicDirector 323, Animation 35,
  PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Menu façon Street Fighter et modes de jeu (en cours), plusieurs combats par serveur.

## Version 0.13.4 — 3 octobre 2026

Retours de Wilhem : « une petite invincibilité quand les persos se relèvent » ; « combos
limités en garde : supprime ça » ; « mets la possibilité de shift lock sans le gros point, pour
éviter de mettre sa souris n'importe où ».

- **Invincibilité au relevé** : déjà intouchable pendant la chute et le relevé, le perso
  l'est encore 0,25 s une fois debout (`WakeInvulnTicks = 15`) : un coup qui attend au
  relevé ne le recolle plus en combo. Il peut garder, bouger ou sauter ; attaquer y met fin.
  Le corps clignote pendant ce temps (champ `wakeInvuln` du snapshot).
- **Limite de chaîne en garde supprimée** (`BlockChainMax` retiré). Pour que la garde tienne
  quand même : toute la chaîne des coups légers (usure ≤ 12) use la garde 2 fois moins. Le
  jab rapide en sortie de garde et les autres réglages de la 0.13.2 restent.
- **Souris bloquée** (Ctrl ou bouton SOURIS) : curseur caché et tenu au centre de l'écran
  (`MouseBehavior.LockCenter`), les clics comptent toujours ; Shift reste le dash.
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 48, TARO 53, ZEPHYR 53, AKEMI 42,
  RYUKEN 50, SHIN 47, DAICHA 51, HIBECARES 55 ; DIFFICILE : KAI 55, TARO 47, ZEPHYR 54,
  AKEMI 51, RYUKEN 50, SHIN 55, DAICHA 45, HIBECARES 43.
- Tests : CombatSimulation 92 (+1 invincibilité au relevé, −1 limite de chaîne ; 10 s de spam
  contre la garde : pas de cassure, ≤ 15 % de dégâts), FighterAI 11, CinematicDirector 323,
  Animation 35, Kits 58, PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Souris bloquée : les boutons du HUD ne sont plus cliquables tant qu'elle l'est (Ctrl pour
  la libérer). Rien n'a été testé dans Studio.
- Suite : menu façon Street Fighter et modes de jeu.

## Version 0.13.3 — 3 octobre 2026

Suite du retour de Wilhem : « les hitbox des ultimes à travailler, surtout quand l'autre joueur
est dans les airs ».

- Cause : la Ruée (R), la Porte, l'Éveil et le coup fatal chargent tout droit (`lunge`) ; contre
  un adversaire en l'air, l'attaquant passait **sous lui** et frappait dans le vide de l'autre
  côté ; et leur hitbox s'arrêtait à 8,5–9 m (ZEPHYR saute à 10).
- Correctif : ces 4 ultimes visent la cible (`track = true` : ils s'arrêtent juste devant elle,
  même si elle est en l'air) et leur hitbox monte à 11 m.
- Mesure (adversaire qui saute à 10 moments différents, 3 distances, 8 persos) : R 5/10 → 10/10
  de près, coup fatal 4/10 → 10/10.
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 50, TARO 54, ZEPHYR 51, AKEMI 49,
  RYUKEN 48, SHIN 46, DAICHA 47, HIBECARES 55 ; DIFFICILE : KAI 48, TARO 50, ZEPHYR 54,
  AKEMI 54, RYUKEN 52, SHIN 46, DAICHA 42, HIBECARES 52.
- Tests : Kits 58 (+1 : R et coup fatal touchent un adversaire qui saute, 8 persos, 3 moments
  du saut), CombatSimulation 92, FighterAI 11, CinematicDirector 323, Animation 35,
  PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- À juger en jeu (rien testé dans Studio) : garde, déplacements, ultimes contre un sauteur.
- Suite : menu façon Street Fighter et modes de jeu.

## Version 0.13.2 — 3 octobre 2026

Retour de Wilhem : « les combos sont trop violents, on a l'impression que bloquer ne sert à
rien ; pendant le blocage les combos doivent être limités ; quand on lâche la garde les coups
légers doivent sortir entre la frame 1 et 3 ; la différence de frames doit permettre
d'intervenir si je bloque et que l'autre me spam ; fluidifier les déplacements gauche-droite
(on reste au même endroit) ; travailler les hitbox des ultimes, surtout en l'air ».

- Mesure avant (KAI qui garde 10 s) : contre un spam de jab, la garde cassait 2 fois et
  ~330 dégâts passaient ; contre L L L R répété, 0 sortie réussie sur 3.
- **Chaîne limitée en garde** : après `BlockChainMax = 2` coups bloqués, l'attaquant ne peut
  plus annuler dans le coup suivant (même en retard) : il doit récupérer, le défenseur a la
  main. Remis à zéro dès qu'un coup touche.
- **Sortie de garde** : pendant la garde et 8 images après (`GuardCancelTicks`), le jab sort
  en **3 images** au lieu de 5 (`GuardCancelStartup`), événement `GuardRelease`.
- **Garde plus solide** : dégâts gratter 15 → 8 %, les petits coups (usure ≤ 10) usent la
  garde 2 fois moins (`LightGuardWear`), elle revient après 0,2 s au lieu de 0,8 s. Les gros
  coups répétés la cassent toujours (~3 s de spam de R, ~21 s de spam de jab).
- Après : contre un spam de jab, 0 dégât, 0 cassure, 10 sorties de garde sur 10 réussies.
- **Déplacements** : gauche + droite tenues ensemble s'annulaient (le perso s'arrêtait net en
  changeant de sens) : la dernière direction pressée gagne maintenant.
- Équilibre (`Balance.luau`, 120 matchs) — LÉGENDE : KAI 50, TARO 52, ZEPHYR 52, AKEMI 48,
  RYUKEN 47, SHIN 46, DAICHA 49, HIBECARES 56 ; DIFFICILE : KAI 49, TARO 48, ZEPHYR 53,
  AKEMI 54, RYUKEN 51, SHIN 49, DAICHA 45, HIBECARES 50.
- Tests : CombatSimulation 92 (+3 : chaîne bloquée limitée, garde contre 10 s de spam, jab
  en 3 images en sortie de garde), FighterAI 11, CinematicDirector 323, Animation 35, Kits 57,
  PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Hitbox des ultimes contre un adversaire en l'air : en cours.
- Je n'ai rien testé dans Studio : la sensation de garde et de déplacement est à juger en jeu.

## Version 0.13.1 — 3 octobre 2026

Retour de Wilhem : « les difficultés, rends-les réelles, genre LÉGENDE c'est vraiment fort ».

- **Mesure** : 7 « joueurs-tricheurs » scriptés (spam de jab, sauts permanents, spam de R, zoner
  qui fuit, tortue, ultime à froid, rush L L R + coup invincible). Avant : LÉGENDE perdait 22 %
  des matchs contre le spam, 25 % contre le zoner, 16 % contre le rush.
- **Lectures** (`read` dans `FighterAI.Levels` : NORMAL 0,35, DIFFICILE 0,8, LÉGENDE 1) : le CPU
  retient ce que fait l'adversaire (pression de près, hauteur de ses coups, zoning, sauts,
  coups invincibles), oublié en ~3 s. Réponses : garde et coup invincible contre le spam,
  ouverture au jab (le plus rapide) au lieu d'un coup lent qui se fait couper ; anti-air
  calculé sur la trajectoire du saut (et garde debout pour RYUKEN, dont la spéciale est une
  charge au sol) ; pas de combo au sol sous un saut ; saut par-dessus les projectiles ;
  garde qui suit la hauteur de chaque coup ; au réveil d'un adversaire qui aime son coup
  invincible, garde puis punition ; pas de punition trop tardive (il calcule la récupération
  restante) ni sur une chaîne qui peut finir en coup invincible. Toujours sans triche : il ne
  voit que l'écran, avec son temps de réaction.
- LÉGENDE : garde 0,88, combos jamais lâchés, routes complètes 75 %, punition 100 %, anti-air
  0,95, décision toutes les 5 images.
- **Bug du CPU contre AKEMI** : avec VOILE D'OMBRE prête, LÉGENDE n'envoyait plus que des jabs
  isolés (« appât »), même pour punir. L'appât ne sert plus qu'au neutre (une fois sur deux), et
  après une esquive le CPU garde le contre. **Le CONTRE-INSTINCT coûte ½ barre de ki**
  (`CounterCost = 50`), comme les suites de FighterZ : sinon chaque esquive = un combo gratuit.
- Résultats (32 matchs par habitude, tous persos) : LÉGENDE gagne 91 à 100 % contre chaque
  tricheur ; DIFFICILE 69 à 100 % ; NORMAL et FACILE restent battables par le spam (niveaux
  débutants). LÉGENDE bat DIFFICILE 100 %, DIFFICILE bat NORMAL 98 %.
- **Animation** : un passage marche → coup bas en une image coupait le fondu dès la 2ᵉ image
  (pied d'appui qui flotte de 0,28, trouvé par le combat CPU du test d'animation). Le fondu
  continue maintenant vers l'étape suivante du même coup. AnimQuality : à-coups ÷ 2 environ sur
  les 8 persos (KAI 41 → 26 en démo, AKEMI 46 → 21), tremblements et interpénétration égaux ou
  moindres (SHIN pire cas 4,4 → 1,5 %).
- Rééquilibrage pour la nouvelle IA : TARO dégâts −6 % ; AKEMI vie 1060 → 1180, dégâts −6 % ;
  RYUKEN +12 % ; SHIN +18 % ; DAICHA +25 % ; HIBECARES vie 1620 → 1580, dégâts −10 %.
  `Balance.luau` 120 matchs — LÉGENDE : KAI 51, TARO 52, ZEPHYR 52, AKEMI 49, RYUKEN 43, SHIN
  48, DAICHA 48, HIBECARES 57 ; DIFFICILE : KAI 54, TARO 49, ZEPHYR 51, AKEMI 54, RYUKEN 50,
  SHIN 49, DAICHA 44, HIBECARES 50.
- Tests : FighterAI 11 (+1 : LÉGENDE bat spam, sauts, zoning et rush ≥ 85 %, FACILE perd
  contre le spam), Kits 57 (contre sans ki refusé, coût du contre), Animation 35,
  CombatSimulation 89, CinematicDirector 323, PressQueue 4, Fuzz 2, Cinematography 114,
  Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Les niveaux restent à juger contre de vrais joueurs (je n'ai rien testé dans Studio).
- Suite : menu façon Street Fighter et modes de jeu, puis CHALLENGE (KAI à 4 bras), équipes de
  1 à 3, parties classées.

## Version 0.13.0 — 3 octobre 2026

Retours de Wilhem : « pour AKEMI, l'esquive une fois toutes les 20 s c'est trop punitif, au
pire fais comme Goku Ultra Instinct sur FighterZ » ; « le coup fatal qui one-shot c'est trop,
fais un % de vie, que si l'adversaire est sous la mi-vie » ; « rééquilibre les dégâts globaux,
ça doit vraiment être du skill vs skill » ; « quand on gagne en perfect, un gros PERFECT pour
le gagnant, une phrase genre looser pour le perdant » ; « review des specs de tous les persos :
certains plus simples à comprendre que d'autres, mais tous équilibrés ».

- **AKEMI, VOILE D'OMBRE façon Ultra Instinct** : 2 esquives d'avance (au lieu d'une toutes
  les 20 s), chacune revient en 18 s, chaque coup porté retire 0,33 s ; juste après une
  esquive, L ou R dans les 14 images = **CONTRE-INSTINCT** : elle réapparaît dans le dos de
  l'attaquant (2,6 m, le côté est verrouillé par `crossed`) et lance son starter. HUD : ●○ et
  secondes à côté de la garde, annonce « CONTRE-INSTINCT ! ». Le CPU contre aussi.
  `Passive = { Charges, Cooldown, HitRefund, CounterWindow, CounterGap }`,
  `Sim.passiveCharges`, champ `passiveCharges` du snapshot.
- **Coup fatal** : plus de one-shot. En plein combo −50 % de la vie max, à froid −30 %, et il
  ne tue que si la cible était **déjà sous la moitié de sa vie** au début de la scène
  (`FinishThreshold = 0.5`, jugé sur `startHp`) ; sinon elle survit et le round continue.
- **Dégâts globaux (skill vs skill)** : le ki monte moins vite (0,5 → 0,28 des dégâts portés,
  0,3 → 0,16 des dégâts reçus), Ruée 22/170 → 16/130, Porte 40 → 30 % de la vie max, Éveil
  35 → 30 %. Part des dégâts mesurée (CPU contre CPU) : coups normaux 41 %, spéciales 16 %,
  fatal 12 %, routes à skill 8 %, Ruée 8 %, Éveil 8 %, Porte 6 % (avant : ultimes 46 %) ;
  un round dure environ 43 s.
- **PERFECT** : victoire sans un coup reçu = gros PERFECT doré pour le gagnant ; le perdant
  voit PERFECT en rouge et une phrase au hasard (« LOOSER… pas un seul coup porté. », « Zéro
  dégât. ZÉRO. »…). Champ `perfect` de RoundEnd.
- **Revue des 8 persos** : note de difficulté (`Difficulty`, affichée ★☆☆ SIMPLE / ★★☆ MOYEN
  / ★★★ TECHNIQUE dans l'annonce du perso et le panneau des combos) : KAI, RYUKEN, HIBECARES
  simples ; TARO, ZEPHYR, SHIN moyens ; AKEMI, DAICHA techniques. Réglages : TARO vie 1600 →
  1560, dégâts −4 % ; ZEPHYR dégâts +5 → +8 % ; AKEMI vie 1100 → 1060, dégâts −12 → −15 % ;
  SHIN vie 1400 → 1450, dégâts −2 → +15 % ; DAICHA vie 1400 → 1500, dégâts +15 % ;
  HIBECARES vie 1800 → 1620.
- Équilibre (`Balance.luau`, 120 matchs par duel) — LÉGENDE : KAI 46, TARO 52, ZEPHYR 47,
  AKEMI 59, RYUKEN 53, SHIN 47, DAICHA 45, HIBECARES 53 ; DIFFICILE : KAI 52, TARO 55,
  ZEPHYR 46, AKEMI 47, RYUKEN 50, SHIN 52, DAICHA 44, HIBECARES 54. Avant ce passage :
  LÉGENDE de 35 % (DAICHA) à 65 % (AKEMI), DIFFICILE de 33 % (DAICHA) à 63 %.
- Tests : CombatSimulation 89 (coup fatal sous la mi-vie, PERFECT), Kits 57 (AKEMI 2 charges,
  contre dans le dos, recharge par coup porté, difficulté 1 à 3), FighterAI 10 (le test du
  blink de DAICHA compte sur 6 graines au lieu d'une), CinematicDirector 323, Animation 35,
  PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe. Sondes `tests/_*.luau`
  supprimées (dont `_fatal.luau`, commité par erreur en 0.12.0).

### Problèmes ouverts / prochaine étape

- AKEMI monte avec le niveau du CPU (59 % en LÉGENDE, 47 % en DIFFICILE) : perso technique,
  à surveiller en vrai match.
- Prochaines demandes, dans l'ordre : vraies difficultés (LÉGENDE vraiment forte), menu façon
  Street Fighter (SURVIE, 1V1 IA, 1V1 JOUEUR, ENTRAÎNEMENT), mode CHALLENGE (KAI à 4 bras),
  équipes de 1 à 3 persos façon FighterZ, parties classées / normales avec recherche
  d'adversaire et serveurs pour 150 joueurs (vérifiable seulement dans le jeu publié).

## Version 0.12.4 — 3 octobre 2026

Retours de Wilhem : « ça explique très mal comment faire l'ultime, je fais les trois touches et
il ne se passe rien » ; « non, juste pouvoir activer les conditions des ultimes, la vie tout
ça » ; « affiche le combo en entier comme avant ».

- **Bouton ULTIMES : ON / OFF** (solo seulement, coupé dès qu'un ami rejoint) : le ki du joueur
  reste plein et sa vie est tenue à 25 % (sous la ligne du dernier souffle) : toutes les
  conditions des ultimes et du coup fatal sont réunies ; l'adversaire n'est pas touché.
  `world.ultimateConditions` = le slot du joueur, champ `ultimateConditions` du snapshot,
  impulsion `ultiConditions`. En entraînement, le coup fatal est en plus toujours prêt.
- **Combo en entier, compact** : `L L [R]` (L / R = clics, [R] [E] [C] = touches du clavier),
  au lieu d'un « R » qu'on confondait avec le clic droit ; cases : CLIC G, CLIC D, TOUCHE R.
- Tests : CombatSimulation 88 (+2 : ULTIMES ON, coup fatal en entraînement) ; CombatSimulation 88, FighterAI 10, CinematicDirector 323, Animation 35, Kits 54, PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

## Version 0.12.3 — 3 octobre 2026

Retour de Wilhem : « on ne voit pas toutes les attaques de l'entraîneur ».

- Le panneau de l'entraîneur (une seule colonne de 19 boutons) dépassait de l'écran. Il a
  maintenant deux colonnes côte à côte (COMBOS ★ ET COUPS / ROUTES COMPLÈTES ET ULTIMES), qui
  défilent si elles sont trop longues, et sa hauteur suit l'écran. Chaque combo montre ses
  touches ET le nom de toutes ses attaques ; ARRÊTER en haut à droite.
- Cases de l'entraîneur : le nom de l'attaque se réduit pour tenir dans la case (il était coupé).
- Tests : CombatSimulation 86, FighterAI 10, CinematicDirector 323, Animation 35, Kits 54, PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe (le HUD n'est pas testable hors Studio).

## Version 0.12.2 — 3 octobre 2026

Retour de Wilhem : « l'entraîneur est bugué, arrange-le, mets-le en deux catégories ; et audite
et règle tous les bugs ».

- **Entraîneur** : le bouton ENTRAÎNEUR ouvre un panneau en deux catégories (COMBOS ★ ET
  COUPS : routes à skill, routes courtes, spéciale ; ROUTES COMPLÈTES ET ULTIMES : 6 routes,
  ultime, coup fatal) au lieu de faire défiler 19 combos ; le combo choisi s'affiche au-dessus
  des cases (le bouton débordait). Bug corrigé : finir un combo court puis continuer affichait
  « RATÉ ». Aide en bas d'écran : C / LB = coup fatal.
- **Audit** :
  - QTE d'un joueur lointain : le « raté » n'était jugé qu'après le coup final (fenêtre de
    latence) ; la pénalité arrivait trop tard et le K.O. pouvait être défait après coup. Les QTE
    en attente sont maintenant jugés ratés juste avant le coup final ; les coups déjà portés
    sont marqués (`step.done`) pour le calcul du K.O.
  - Client : la scène de K.O. d'un round pouvait être sautée si une cinématique annonçait un
    FINAL FINISH que les QTE ratés ont ensuite annulé (`finishEpoch` posé seulement une fois le
    coup final porté).
  - HUD : couleur du titre de l'entraîneur lue avant d'être définie (aurait cassé le HUD),
    trouvé par `luau-analyze` (passé sur tout le code : plus aucune variable inconnue).
  - Fuzz : joue aussi le coup fatal, un combattant à 25 % de vie et un joueur lointain.
- Tests : CombatSimulation 86 (+1 : QTE d'un joueur lointain jugé avant le coup final), FighterAI 10,
  CinematicDirector 323, Animation 35, Kits 54, PressQueue 4, Fuzz 2, Cinematography 114, Lobby 5 : tout passe.

## Version 0.12.1 — 2 octobre 2026

Demande de Wilhem : « dans l'entraîneur mets tous les combos spé ».

- **Entraîneur** (`HUDController:trainerRoutes`) : le bouton ENTRAÎNEUR fait défiler 19 combos
  par perso au lieu des 6 routes complètes : les 5 routes à skill ★, les 6 routes complètes,
  les routes courtes, puis SPÉCIALE (L L E), ULTIME (L L R) et COUP FATAL (L L C). Les routes
  avec saut (↑) restent hors de l'entraîneur (il suit les appuis, pas les sauts). Touche C
  affichée ; la 6e case CLIC D / R et le « pas d'ultime » restent propres aux routes complètes.
- Tests : CombatSimulation 85, FighterAI 10, CinematicDirector 323, Animation 35, Kits 54, PressQueue 4,
  Fuzz 2, Cinematography 114, Lobby 5 : tout passe (l'entraîneur est du client, non testé hors Studio).

## Version 0.12.0 — 2 octobre 2026

Demande de Wilhem : « barre de vie équilibrée, les QTE doivent servir (rater = moins de
dégâts), enlever le combo à 95 % et en créer un qui mérite ses 95 %, gardé comme un autre
skill ; pour SHIN une scène de film japonais en noir et blanc où il traverse l'écran d'un
slash ; c'est aussi l'écran de K.O. ultime, une scène unique pour chaque perso ; inspire-toi
des jeux de combat ». Choix validés : coup du dernier souffle (vie < 30 %), 35 % max pour
l'éveil. La touche F étant la garde, le coup fatal est sur C (manette LB).

- **QTE qui comptent** : ÉVEIL = 35 % de la vie MAX si les 4 QTE sont réussis, chaque raté
  retire 5,75 % (tout raté : 12 %), K.O. seulement s'il achève (plus de K.O. automatique sous
  50 %) ; PORTE : R au sommet +10 %, raté −15 %. `MissShare` / `MissRatio` dans les cinématiques.
- **COUP FATAL** (rôle `Fatal`, un par kit) : 3 barres, sa vie sous `Config.FatalHealth`
  (30 %), une fois par match (gardé d'un round à l'autre) ; en plein combo (cible en hitstun ou
  lancée) −95 % de la vie max, à froid −60 % ; lent (14 frames), paré ou esquivé il est perdu
  avec la jauge ; un QTE C très serré (±4), raté : −40 % du coup. `Sim.fatalReady`, champ
  `fatal` du snapshot, HUD « COUP FATAL PRÊT · C », bouton tactile FATAL, labo (combo, K.O., à
  froid), CPU (le place en plein combo, QTE selon son niveau).
- **8 scènes uniques** (`CinematicDirector`, table `FATAL`), qui sont l'écran de K.O. quand
  le coup tue (pas de scène de K.O. générique) : KAI 滅 CIEL ÉTEINT (écran noir et éclairs,
  façon raging demon), TARO 終 DERNIÈRE CLOCHE (dernier round), ZEPHYR 嵐 CHUTE DE LA LUNE,
  AKEMI 刻 L'INSTANT VOLÉ (temps arrêté), RYUKEN 砕 POING DU MONDE, SHIN 一閃 ISSEN (film de
  sabre en noir et blanc, une ligne rouge), DAICHA 虚 NÉANT (soleil noir), HIBECARES 墓 TOMBEAU
  DES ROIS. Client : `frame.black` (écran noir, chaque coup = un flash).
- Tests : CombatSimulation 85 (+3 coup fatal, éveil réécrit), CinematicDirector 323 (scènes
  fatales placées, uniques, K.O. / nom), Cinematography (cadrage + mains lisibles des coups
  fatals), Animation 35, FighterAI 10 ; Kits 54, PressQueue 4, Fuzz 2, Cinematography 114,
  Lobby 5 : tout passe.
- Équilibre (`Balance.luau -a 4 120`, LÉGENDE) : KAI 49, TARO 59, ZEPHYR 48, AKEMI 51,
  RYUKEN 57, SHIN 44, DAICHA 36, HIBECARES 55 (tous entre 35 et 65 %). DAICHA est au plus bas
  de la fourchette : à surveiller.

### Problèmes ouverts / prochaine étape

- Vérifier en jeu l'écran noir de KAI (flashs au-dessus) et le rythme des scènes.
- Confirmer en jeu que l'orbe de DAICHA vole.

## Version 0.11.3 — 2 octobre 2026

Retour de Wilhem : « les poings sont encore là ». Ce n'était pas que l'angle : plusieurs poses
mettaient vraiment les deux poings ensemble devant le corps.

- **Coup final « double poing »** de KAI (`Finale`, repris par l'ÉVEIL de KAI, TARO et RYUKEN) :
  les deux poings partaient collés (0,7 stud). C'est maintenant un seul poing de ki tendu dans
  la cible, l'autre ramené à la hanche (hikite).
- **DAICHA** (Poussée, Lancer, Finale, et ses trois ultimes) : les deux paumes poussaient
  ensemble ; la main de l'orbe frappe seule, l'autre se retire. Traînées : main gauche.
- **Kiai de KAI** (pose du titre de la PORTE DES CIEUX, capture de Wilhem) : les poings, censés
  être aux hanches, étaient devant la poitrine ; coudes ramenés en arrière, poings aux hanches.
  Les plans de fin de KAI (Ruée, Éveil, Porte) le montrent debout, poings relâchés (StandTall).
- Tests : Animation 35 (+1 : finishers et ultimes frappent d'un seul poing, R15 et avatar) ;
  CombatSimulation 82, FighterAI 10, CinematicDirector 250, Kits 54, PressQueue 4, Fuzz 2, Cinematography 82, Lobby 5 : tout passe. AnimQuality KAI et DAICHA sans hausse d’interpénétration (moyenne ≤ 2,1 %).

## Version 0.11.2 — 2 octobre 2026

Retour de Wilhem : « en fin de cinématique avec un coup de poing, beaucoup de persos ont les
mains jointes » (capture : le titre de la PORTE DES CIEUX de KAI) ; « c'est peut-être l'angle
qui porte à confusion » ; « la position de KAI pendant le kamehameha ».

- **Diagnostic** : en 3D, les mains ne se touchent jamais (mesuré sur R15 et R6, tous les styles,
  FINAL FINISH, scènes de K.O.). C'était l'angle : des plans regardaient le perso dans l'axe des
  bras, un poing cachait l'autre et l'on croyait voir des mains jointes (titre de la Porte de
  KAI : 48 images sur 48).
- **Angles recomposés** (`CinematicDirector`, toujours par `frameOn`) : 23 plans, dont
  porte-after, porte-shatter, eveil-strike1 (CUTS[1]), taro-tempete-liver, zephyr-vent-drift,
  zephyr-cyclone-gust, akemi-temps-tableau3, ryuken-effondrement-body, ryuken-round-guard / cock,
  shin-tempete-still / rise, shin-zero-cuts, daicha-riviere-strike, daicha-eclipse-mirror,
  daicha-eclipse-flash, daicha-domaine-crown, hibecares-colosse-march, hibecares-ruines-fist,
  ko-shin-horizon, ko-shin-leave, ko-zephyr-orbit. Seul reste l'iai de SHIN (ses deux mains sont
  vraiment sur la poignée).
- **Kamehameha de KAI** (fin de la Ruée) : il tirait le rayon vers le sol avec les bras à
  l'horizontale. Nouvelle pose `KiBeamDown` : penché sur la cible, les deux bras tendus vers le
  bas, paumes jointes, jambes repliées ; le rayon part de ses paumes.
- Tests : Cinematography + 1 (aucun plan où un poing cache l'autre, 8 kits, R / Éveil / Porte /
  K.O.), Animation 34 (+1 : bras du rayon vers le bas, paumes jointes, R15 et avatar) ; CombatSimulation 82, FighterAI 10, CinematicDirector 250, Kits 54, PressQueue 4, Fuzz 2, Cinematography 82, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Confirmer en jeu que l'orbe de DAICHA vole (v0.11.1).
- Ajustement IK des contacts (poing arrêté à la surface de l'adversaire).

## Version 0.11.1 — 2 octobre 2026

Retour de Wilhem : « refais le même focus animation / cinématiques ; DAICHA, c'est encore buggé,
l'orbe est collée à sa main ».

- **Orbe collée à la main (bug client)** : `EffectsController` ne libérait l'orbe qu'une fois,
  quand le corps arrivait ; les pièces de tenue (KitShadowOrb, KitOrbCore) répliquent souvent
  après le corps, l'orbe restait donc soudée. Nouveau `attachWeapon`, réessayé toutes les 0,2 s
  tant que l'arme n'est pas là (et de nouveau si la tenue est reconstruite) ; toutes les
  soudures qui la tiennent sont détruites, où qu'elles soient rangées (WeldConstraint, Weld,
  Motor6D). Non vérifiable hors Studio : à confirmer en jeu.
- **Mise en scène propre** (`CinematicDirector`, après chaque image d'une cinématique) :
  - vitesse : un corps qui va plus vite que 0,9 stud par image dans un même plan est dessiné
    avec ses images rémanentes (ghost) : plus aucune téléportation visible (TARO qui tournait
    autour de sa cible par sauts, ZEPHYR, AKEMI et RYUKEN qui changeaient de côté, la cible
    de HIBECARES, les chutes) ;
  - place : au sol, un attaquant ne se colle jamais à moins de 2,8 studs de sa cible.
- Outil `tests/CinematicQuality.luau` (interpénétration, téléportations, à-coups par
  cinématique) ; `CinematicKit` donne aussi les poses. Téléportations visibles : 79 → 0 ;
  interpénétration moyenne TARO Ruée 5,5 % → 2,5 %, RYUKEN Éveil 3,3 % → 1,5 %, Porte 2,2 % → 1,1 %.
- Tests : CinematicDirector 250 (+1 : ni téléportation sans images rémanentes ni attaquant
  collé) ; CombatSimulation 82, FighterAI 10, Animation 33, Kits 54, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 : tout passe.

### Problèmes ouverts / prochaine étape

- Confirmer en jeu que l'orbe vole (et sa chaîne en attaque).
- Ajustement IK des contacts (poing arrêté à la surface de l'adversaire).

## Version 0.11.0 — 2 octobre 2026

Demande de Wilhem : « concentre-toi purement sur les animations, parfois c'est très brouillon,
rends ça plus qualitatif » ; « ensuite la même chose avec les cinématiques et les scènes de
K.O. / victoire » ; « l'orbe noire doit bouger pendant les attaques comme un nunchaku ».

- **Outils pour juger le mouvement** (avant, on ne jugeait que des images fixes) :
  `tests/ClipKit.luau` joue un combat scénarisé (vraie simulation + vrai Animator, caméra du
  jeu), `tests/AnimClip.luau` en fait un GIF (`tools/storyboard.py clip.txt clip.gif`, zoom
  possible), `tests/AnimQuality.luau` mesure les à-coups (articulation qui saute de plus de 28°
  en une image hors impact), les tremblements et l'interpénétration des deux corps.
- **Animator** (pur) :
  - anticipation : l'armé est atteint plus tôt (45 % du démarrage) puis continue de se tendre
    à l'opposé du coup jusqu'au départ (moving hold) au lieu d'une pose figée ;
  - **inertie / follow-through** : ressorts par articulation après le mélange — buste, épaules,
    coudes, poignets, tête, et la jambe libre (coups de pied, sauts, chutes) ; un impact (snap)
    tombe instantanément sur sa pose et fouette au-delà ; les jambes plantées par l'IK ne
    traînent jamais ; une coupure (blink, nouveau round, plan) remet tout à zéro (déplacement
    > 2,5 studs en une image) ;
  - **espacement d'affichage** `Animator.spacing` : à bout portant, chaque corps est dessiné
    jusqu'à 0,42 stud plus loin de l'autre, sans jamais de saut (la séparation affichée croît
    toujours avec la vraie), rien à distance ni au croisement (DAICHA) ; dessin seulement, les
    positions, hitbox et caméra restent celles du serveur ; jamais en cinématique ;
  - garde : un rythme par perso (`IDLE_RHYTHM` : TARO 1,9 Hz, SHIN 0,55 Hz, HIBECARES 0,5 Hz...)
    et un transfert de poids d'un pied à l'autre ;
  - saut : poussée des jambes au décollage ; dash avant : élan, puis freinage accroupi ;
  - les poses de chute, de relevé, de réaction et de saut peuvent être propres à un kit ;
    SHIN : la lame se couche le long du bras au sol, horizontale à genou (avant : plantée à la
    verticale comme un piquet) ;
  - les poses tenues des scènes (victoire, rugissement, iai...) respirent.
- **POSES : FLUIDE par défaut** (`CombatConfig.PoseRate = 60`) : les paliers 12/15/24 ne font
  qu'interpoler entre 3 poses clés, ce qui saccade sur ces corps ; le rythme anime vient des
  maintiens, smears et impacts. Le bouton POSES garde 12/15/24.
- **Orbe de DAICHA en nunchaku** (`OrbFlight`) : à l'armé elle tourne autour de sa main (un
  tour complet s'il a le temps, un demi sinon), fouette en arc jusqu'au point d'impact (la
  chaîne s'allonge), continue son élan vers le bas et revient en orbite ; jamais dans son corps
  ni sous le sol. Chaîne d'ombre (Beam) main-orbe pendant les attaques (client et planches).
- **Cinématiques et K.O.** : plus de montage stroboscopique (champs/contrechamps toutes les
  4-8 images → tous les deux coups ; le dernier coup reste dans le plan d'avant ; HIBECARES
  CHÂTIMENT en un seul plan avec un vrai mouvement continu : soulevée en arc, abattue de
  l'autre côté en accélérant, au lieu de téléporter la cible) ; **caméra vivante**
  (`Director.drift`) : chaque plan composé glisse lentement autour du sujet et avance un peu
  (6°/s, 5 %/s, 1,6 s au plus) ; poses tenues qui respirent.
- Mesures (`AnimQuality`, 8 persos × 3 scénarios) : tremblements 236 → 156, interpénétration
  moyenne 1,6 % → 0,6 % (pire cas 14,8 % → 10,4 %, sur 2 images d'impact), à-coups 839 → 786
  (ceux qui restent sont des démarrages de coups en 2-3 images, voulus). Plus aucun plan de
  moins de 5 images, au plus deux de moins de 9 par cinématique.
- Tests : Animation 33 (+4 : armé qui se tend, inertie qui traîne/dépasse/se pose et impact
  instantané, espacement sans saut, rythme de garde par perso ; + lame de SHIN au sol, orbe
  nunchaku), CinematicDirector 249 (+2 : montage sans stroboscope, caméra jamais figée),
  CombatSimulation 82, FighterAI 10, Kits 54, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅.
  Studio ❌ non exécuté. Combat inchangé (rien dans la simulation).

### Problèmes ouverts / prochaine étape

- Juger en jeu le rendu FLUIDE contre 15/s, et l'espacement à bout portant (les étincelles
  d'impact restent à la position serveur, jusqu'à 0,4 stud de la main dessinée).
- Prochaine étape possible : ajustement IK des contacts (le poing s'arrête à la surface de
  l'adversaire), poses retouchées une à une avec les GIF.

## Version 0.10.4 — 2 octobre 2026

Retour de Wilhem : « les R de KAI, TARO, ZEPHYR et AKEMI, change-les aussi ».

- `CinematicDirector` : les 4 ruées refaites, chacune avec sa structure et son effet à elle :
  - KAI · KAIEN RUSH : lancer, poursuite dans le ciel (téléportations autour de la cible,
    anneau de ki à chaque choc, filmée d'en dessous puis d'au-dessus), smash au sol, charge en
    lévitation et **rayon de ki** vers le bas (`kiBeam`) ;
  - TARO · RUSH DÉVASTATEUR : poussée dans le coin, **cordes de feu** (`ropes`), DEMPSEY ROLL
    (balancement gauche / droite, crochets alternés) filmé comme une retransmission avec les
    flashs, coups au corps, crochet de K.O. à travers les cordes ;
  - ZEPHYR · VENT TRANCHEUR : reste à distance, **lames de vent** (`windBlade`) à chaque coup
    de pied, vortex de lames qui soulève la cible, traversée d'un coup de pied volant ;
  - AKEMI · OMBRES MULTIPLES : frappe depuis un cercle autour de la cible en laissant **son
    ombre** (`afterimage`, copie sombre du corps) à chaque place ; rengainée en noir et blanc ;
    toutes les ombres frappent ensemble.
- Client (`EffectsController`) : `kiBeam`, `windBlade`, `ropes`, `shadowCopy` ;
  `CinematicController` les joue. Storyboard : les nouveaux effets, et l'ombre d'AKEMI dessinée
  comme un corps sombre.
- Test « chaque ruée a sa manière » étendu aux 8 persos (effet propre à chacun, KAI monte la
  cible à plus de 10 studs, ZEPHYR reste à plus de 3 studs jusqu'au coup final).
- **Nerf du E de DAICHA** (TÉLÉPORTATION, « on peut se TP à chaque clic ») : seulement si
  l'adversaire est à 9 studs ou moins (`teleportRange`), 2 s avant la suivante
  (`teleportCooldown`, règle de `CombatSimulation`), invulnérabilité 1-8 (au lieu de 1-12),
  dégâts 70 (au lieu de 76), récupération 32. Un coût en ki a été essayé : le CPU DAICHA
  tombait à 27 %, abandonné. Test Kits : trop loin ou dans les 2 s, pas de téléportation.
- Équilibrage (`Balance.luau -a 4 120`, niveau LÉGENDE, moyennes) : KAI 47 %, TARO 53 %,
  ZEPHYR 48 %, AKEMI 60 %, RYUKEN 57 %, SHIN 45 %, DAICHA 40 %, HIBECARES 51 % ✅.
- Tests : CombatSimulation 82, FighterAI 10, CinematicDirector 247, Animation 28, Kits 54,
  PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Studio ❌ non exécuté.

### Problèmes ouverts / prochaine étape

- Voir en jeu les 8 ruées ; ajuster tailles / durées des effets.

## Version 0.10.3 — 2 octobre 2026

Retours de Wilhem : « l'orbe doit vraiment voler autour de DAICHA, pas coller à sa main » ;
« toutes les cinématiques du R se ressemblent, pousse le travail » ; « je n'ai toujours pas
accès au hub multi » ; « les ultimes et les combos doivent vraiment être différents visuellement ».

- **Orbe de DAICHA qui vole** : `src/shared/OrbFlight.luau` (pur) calcule où est l'orbe à
  chaque instant à partir de la vue du combattant : orbite autour des épaules au repos (plus
  basse accroupi), devant lui en garde, rassemblée près de la main à l'armé, au bout de la
  portée du coup à l'impact (un sursaut par coup des rafales), tourbillon pour les coups
  tournoyants, retour en orbite pendant la récupération, en retrait quand il est touché ou
  qu'il dashe. Le client détache l'orbe de la main (pièces ancrées, traînée conservée) ;
  `WeaponKit`, `PoseSheet` et `Storyboard` la dessinent au même endroit.
- **Les ruées (R) refaites**, une structure par perso (`CinematicDirector`) :
  - RYUKEN · FUREUR DU POING : cible tenue par le col et pilonnée (caméra dans son visage, le
    cadre « cogne » à chaque coup), écrasée au sol (vue du dessus), uppercut au rebond,
    jonglée des deux côtés (vue du sol), smashée, puis la rage se concentre dans le poing
    (zoom) et part en **poing géant de ki** (nouvel effet `rageFist`) ;
  - SHIN · DANSE DES COURANTS : un seul plan vu d'en haut qui tourne lentement pendant qu'il
    dessine un **huit** autour de la cible (coupe à chaque quart, sillage d'eau au sol :
    `wake`), puis une **trombe d'eau** (`waterspout`) avale la cible, il saute par-dessus et
    la fend du ciel en diagonale ; ronds dans l'eau à la fin ;
  - DAICHA · DOMAINE OBSCUR : il ne touche jamais la cible ; son orbe se divise dans sa main,
    couronne la cible et plonge dedans orbe par orbe (`orbs`, `orbDart`), 8 orbes sur deux
    anneaux croisés vus du dessus, vortex qui la soulève (monde à l'envers), fusion en
    sphère noire qui s'abat ;
  - HIBECARES · COLOSSE ÉVEILLÉ : trois coups colossaux seulement ; chaque pas est un séisme
    (ligne de rochers `rockLine` jusqu'à la cible), le 1er coup l'envoie rouler, il la suit
    sans se presser (par-dessus son épaule), le 2e l'enfonce (cratère), les piétinements la
    font décoller de plus en plus haut, le 3e fait le cratère. Les rochers retombent après
    chaque séisme (paramètre `life` de `rocks`) pour ne jamais boucher le cadre.
- **Combos visuellement différents** (`EffectsController.kitSwing / kitHit`) : chaque coup
  laisse la marque de son perso (traînée de ki / feu / vent / ombre / chaleur, anneau de
  flammes, bourrasque, croix d'ombre, fissure de rage, coupe nette, explosion d'orbe, débris
  de pierre et secousse), en plus des arcs d'épée et d'orbe de la 0.10.2.
- **Hub** : bouton doré « HUB MULTI (H) » plus grand, touche **H**, panneau central qui s'ouvre
  tout seul à l'arrivée, avec l'état (seul / en combat / en attente), les joueurs, DÉFIER,
  INVITER, JOUER CONTRE LE CPU et une explication quand on est seul : l'ami doit être sur le
  **même serveur** (invitation Roblox, ou « Test > Clients et serveurs » à 2 dans Studio).
- Outils : `Storyboard` sort la durée de vie / la rotation des effets ; `tools/storyboard.py`
  dessine les nouveaux effets (poing géant, orbes, sillage, trombe, ligne de rochers).
- Tests : CinematicDirector 247 (+1 : chaque ruée a ses effets à elle et sa manière — DAICHA
  reste à plus de 4 studs, RYUKEN jongle à plus de 6 studs, le sol tremble sur au moins 8
  pas / coups de HIBECARES, personne ne traverse sa cible) ; CombatSimulation 82, FighterAI 10,
  Animation 28 (dont l'orbe qui vole : orbite au repos, hors du corps, au bout de la portée à
  l'impact, retour), Kits 53, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Planches des 4 ruées
  regardées avant / après. Studio ❌ non exécuté : les nouveaux effets (poing géant, orbes en
  vol, trombe, lignes de rochers) et le hub restent à voir en jeu. Équilibrage inchangé
  (aucune donnée de combat touchée).

### Problèmes ouverts / prochaine étape

- Voir en jeu les 4 ruées refaites et l'orbe qui vole ; ajuster tailles et durées des effets.
- Hub : à deux, les joueurs doivent être sur le même serveur (pas de matchmaking entre serveurs).
- Prochaine étape possible : le même travail de différenciation sur les éveils / portes si
  Wilhem les trouve encore trop proches.

## Version 0.10.2 — 2 octobre 2026

Retour de Wilhem (avec sa planche « attaques à l'épée / attaques à l'orbe ») : « t'as rien
compris, le clic gauche donne encore des coups de poing, il n'y a pas vraiment d'animation ».

- Cause réelle : le katana sort du poing perpendiculairement à l'avant-bras ; sans poignet
  orienté, bras tendu, **la lame pointait vers le ciel** à chaque impact : on voyait un jab
  tenant un bâton levé. Et le client ne dessinait d'arc que pour les coups lourds, aucune
  traînée sur la lame. Mesuré, pas deviné : nouvel outil `tests/WeaponKit.luau` qui place
  l'arme sur un corps posé, et `PoseSheet` / `Storyboard` dessinent maintenant l'arme.
- `src/shared/WeaponSpec.luau` (pur) : géométrie du katana et de l'orbe, utilisée par le
  RigBuilder et par les tests. Prise du katana inclinée de 20° vers l'avant : poignet à −70°,
  la lame prolonge le bras. Sur un corps R6 (sans poignet), prise alignée sur le bras.
- **SHIN** : tous ses coups réécrits en vraies coupes en trois temps — armé (lame en arrière),
  impact (lame dans le prolongement du bras, à travers la cible), accompagnement (la lame
  continue son arc, joué entre l'impact et le retour en garde) : TRANCHE 1 (plate, de droite à
  gauche), TRANCHE 2 (revers montant), ESTOC, COMBO LAME (grand croissant à deux mains),
  BRISE-GARDE (vertical à deux mains, lame au sol), FENDOIR, montante, percée, fil du courant,
  courant tranchant, PAS DU VENT et COUPE FINALE (iai depuis la hanche), cercles, coupes
  basses, coupes aériennes, piqué. Garde « seigan » (pointe vers les yeux), blocage lame
  dressée, garde basse lame en travers.
- **DAICHA** : frappe avec l'orbe (main gauche, poignet fléchi : l'orbe mène le poing) — jab
  d'orbe, balayage en pas oblique, poussée à deux mains, orbe levé puis abattu, coup lourd
  orbe au centre puis poussé, vortex bras ouverts ; garde : l'orbe tenu en bouclier.
- **Client** (`EffectsController`) : traînée (Trail) le long de la lame / derrière l'orbe,
  allumée de l'armé à l'accompagnement ; pour chaque coup d'épée un arc à sa forme (plat,
  diagonal, vertical, cercle complet) avec un liseré blanc, estocs en trait de lumière,
  coups lourds qui fendent le sol (fissure, étincelles, poussière) ; pour chaque coup d'orbe
  une explosion d'orbe, un faisceau pour le coup lourd et les finales, un vortex d'orbes en
  orbite pour les coups tournoyants ; gardes : arc de lumière devant la lame, anneaux
  d'ombre autour de l'orbe, qui flashent au coup bloqué.
- Tests : Animation 28 (+2 : les coupes de SHIN font voyager la pointe et ne dressent jamais
  la lame à l'impact ; DAICHA mène avec l'orbe — R15, avatar et R6) ; CombatSimulation 82,
  FighterAI 10, CinematicDirector 246, Kits 53, PressQueue 4, Fuzz 2, Cinematography 81,
  Lobby 5 ✅ ; `rigcheck` ✅. Planches armé / impact / suite de SHIN et DAICHA regardées.
  Studio ❌ non exécuté : les effets du client (traînées, arcs, faisceau, gardes) restent à
  voir en jeu. Équilibrage inchangé (aucune donnée de combat touchée).

## Version 0.10.1 — 2 octobre 2026

Retour de Wilhem : « corrige les animations à l'épée et celle à l'orbe d'ombre, pourquoi ils
mettent des coups de poing ? Crées-en de nouvelles, et si le problème est sur d'autres persos,
fais-le partout. »

- Cause : un coup sans pose propre prend celle de son rôle chez KAI. SHIN n'avait que 11 coups
  à lui (17 reprenaient les poings, pieds et ki de KAI), DAICHA 6 (22 repris), HIBECARES 7
  (22 repris, dont les coups de pied retournés et le salto) et AKEMI 4 (ses coups de main
  étaient des poings fermés).
- **74 nouveaux jeux de poses** (`PoseLibrary`, section « weapon kits ») bâtis sur des gabarits
  communs (coup debout, coup bas, coup aérien, saut, salto, tourbillon, rafale, coup final,
  plongeon, poursuite, ultime) où seuls les bras, la rotation des hanches et la fente changent :
  - SHIN : tous ses coups sont des coupes et estocs de la main droite (lame aérienne, piqué,
    percée, croissant en salto, tranche céleste, fil du courant à deux mains, tourbillon,
    fauche, tranche basse, coupe finale en iai) ; ultimes : iai puis la coupe.
  - DAICHA : griffes, paumes et gestes d'ombre, l'orbe dans la main gauche (combo, étreinte,
    ombre montante, distorsion bras ouverts, flèche d'ombre, demi-éclipse, voile, courant
    d'ombres, poussée à deux paumes, chute, griffe basse, piqué, retour au néant) ; ultimes :
    lévitation puis la poussée / la sphère.
  - HIBECARES : poings de pierre, piétinement et chaînes (coup de masse, coude de pierre,
    soulèvement, écrasement, revers de chaîne, balayage du bras, séisme poings au sol, pilier
    de pierre, avalanche, pluie de gravats, charge à l'épaule, effondrement du roi).
  - AKEMI : main-lame pour ses coups de main (paume, genou, percée, envol, estoc, mille
    entailles, triple croc, lames jumelles, tourbillon, lame aérienne, piqué, exécution) ; ses
    coups de pied (salto, talon, fauche, coup bas, genou volant, hache) restent des coups de
    pied.
  - TARO, RYUKEN (poings) et ZEPHYR (pieds) empruntaient à KAI des coups du même type :
    inchangés.
- Traînées (`STRIKE`) de chaque nouveau coup sur la bonne main / le bon pied.
- Tests : Animation 26 (+1 : SHIN, DAICHA, HIBECARES et les coups de main d'AKEMI n'empruntent
  jamais une pose de KAI ; toutes les nouvelles poses passent pieds au sol, limites des
  articulations, R15 et avatar) ; CombatSimulation 82, FighterAI 10, CinematicDirector 246,
  Kits 53, PressQueue 4, Fuzz 2, Cinematography 81, Lobby 5 ✅. Planches R6 / R15 de SHIN,
  DAICHA, AKEMI, HIBECARES regardées. Studio ❌ non exécuté. Équilibrage inchangé (aucune
  donnée de combat touchée).
- Problème ouvert : le storyboard dessine le rig en blocs sans le katana ni l'orbe ; en jeu ils
  sont portés à la main (`RigBuilder`), à confirmer à l'œil.

## Version 0.10.0 — 1er octobre 2026

Demandes de Wilhem : la planche des 4 nouveaux persos (« tiens les nouveaux perso » :
RYUKEN, SHIN, DAICHA, HIBECARES, leurs coups, spéciales et ultimes) ; « comment on dodge avec
TARO ? » (répondu, et aide du style ESQUIVE dans le jeu) ; « les bruitages, sois cohérent » ;
« chaque perso a sa propre tête et son propre corps, pas la base de KAI ; fais-le pour tout
le monde, review total ».

### Les 4 nouveaux persos (les 8 sont jouables : `MoveData.KitOrder`)

| Perso | Rôle | Vie | Passif | S + E |
|---|---|---|---|---|
| RYUKEN 拳 | force, pression | 1500 | **RAGE** : +2,5 % de dégâts par coup porté (max 10), perdue quand il est touché | FRAPPE SISMIQUE (onde basse) |
| SHIN 流 | sabre, allonge +22 % | 1400 | **PRÉCISION** : +20 % au bout de la lame | COURANT TRANCHANT |
| DAICHA 闇 | zoning | 1400 | **OMBRE INVERSÉE** : le dash vers l'adversaire (≤ 5 m) le traverse | SPHÈRE INVERSÉE (lente, énorme) |
| HIBECARES 崩 | endurance | 1800 | **ROI DES RUINES** : jusqu'à +30 % de dégâts à 30 % de vie | MUR DE PIERRE (encaisse à moitié, même les bas, et riposte) |

- Données et mécaniques (`MoveData`, `CombatSimulation`) : chaque kit associe les rôles de
  KAI à ses propres coups (noms de la planche) ; TÉLÉPORTATION de DAICHA (réapparaît derrière),
  CHARGE FRONTALE de RYUKEN, PAS DU VENT de SHIN ; `passiveBonus`, `crossed` (passer de
  l'autre côté remet la poussée à zéro), parade `absorb` / `lows` du MUR DE PIERRE.
- Corps en blocs : **chaque perso a sa propre tête et son propre corps** (`RigBuilder.BODIES`)
  au lieu de la base de KAI : ZEPHYR, AKEMI, RYUKEN, SHIN, DAICHA, HIBECARES (TARO l'avait
  déjà). Tenues sur avatar : gantelet fissuré qui luit (RYUKEN), katana et fourreau (SHIN),
  sphère d'ombre et obi (DAICHA), poings de pierre et chaînes (HIBECARES). Deux styles de
  couleurs chacun.
- Poses R15 / R6 de chaque garde et de chaque coup (coupes de sabre, gestes d'ombre, coups
  lourds, MUR DE PIERRE…) ; 4 poses de mise en scène : `Roar`, `Iai`, `Levitate`, `Colossus`.
  La garde de DAICHA tend la sphère plus bas (en R6, le bras pointait vers le haut).
- **12 ultimes et 4 scènes de K.O.**, chacun avec son langage de caméra et son étalonnage
  (nouveaux : `rage`, `current`, `inverse`, `ruin`) — composés avec `frameOn`, vérifiés au
  storyboard :
  - RYUKEN : zooms brutaux, gros plans sur les poings, un impact à chaque coup —
    FUREUR DU POING, EFFONDREMENT (cratère vu du ciel), 拳 DERNIER ROUND ; K.O. : poings qui
    fument, rugissement, dos tourné.
  - SHIN : longues focales, travellings latéraux, l'iai qui fige le temps, une seule ligne de
    lame — DANSE DES COURANTS, TEMPÊTE CONTINUE, 零 ZÉRO HORIZON (une ligne d'un bout à
    l'autre de l'horizon) ; K.O. : la lame rengainée, le clic qui ride le sol.
  - DAICHA : angles penchés, plans en miroir, caméra à l'envers, soleil noir — DOMAINE
    OBSCUR, RIVIÈRE D'OMBRES, 蝕 ÉCLIPSE TOTALE ; K.O. : l'ombre avale le corps.
  - HIBECARES : contre-plongées monumentales, piliers de pierre, débris, secousses (`quake`)
    — COLOSSE ÉVEILLÉ, CHÂTIMENT (soulevé et écrasé de chaque côté), 崩 RUINES DU MONDE ;
    K.O. : décombres et poussière.
  - Client : effets `rocks`, `debris`, `crack`, `cut`, `eclipse`, `smoke` ; storyboard : les
    nouveaux étalonnages et effets, piliers triés en profondeur avec les corps.
- HUD : jauge de chaque passif (RAGE ×N, OMBRE INVERSÉE prête / recharge, bonus du ROI DES
  RUINES selon la vie, règle de PRÉCISION) via `Sim.passiveGauge` (champ `passive` du
  snapshot) ; annonces « BOUT DE LAME ! », « MUR DE PIERRE ! −N », « OMBRE INVERSÉE ! » ;
  liste des COMBOS avec chaque passif. Effets : ombre et flaque à la téléportation (elle
  n'avait aucun effet), trait net au bout de la lame, débris sur le mur, corps de RYUKEN qui
  chauffe avec la RAGE.
- IA : DAICHA traverse l'adversaire à mi-distance ; HIBECARES lève son mur contre un
  adversaire accroupi (un bas trop rapide pour être vu) et contre les bas qu'il voit venir.

### Bruitages cohérents

- Constat : le manifeste du client Roblox (dépôt public Roblox-Client-Tracker,
  `rbxManifest.txt`) ne contient que **11 sons** ; `swordslash.wav`, `swordlunge.wav`,
  `unsheath.wav` et `electronicpingshort.wav` n'y sont plus. Les sons d'épée (coups lourds,
  élans), de garde, de parade, de super et le « ping » des QTE ne jouaient donc rien : seuls
  les pas, sauts et chutes s'entendaient. De plus, un bruit d'épée servait aux poings et un
  bruit de dégainage à la garde.
- Nouvelle palette (`src/shared/SoundPalette.luau`, pur et testé) : uniquement ces 11 fichiers,
  retravaillés (hauteur, durée coupée en fondu, bus de distorsion / écho / réverbération /
  égaliseur). Un son par action, le même pour tous ; une **matière par perso** (poings de ki,
  gants de cuir, pieds qui fendent le vent, main-lame de l'ombre, poings qui écrasent, lame
  d'eau, ombre en écho, pierre) ; un coup lourd = la version lourde de la même matière ;
  projectile propre à chaque perso ; pas plus lents pour HIBECARES. Aucun ID d'asset.

### Tests

- CombatSimulation 82, FighterAI 10 (+1 : DAICHA traverse, HIBECARES lève le mur),
  CinematicDirector 246 (8 kits, signatures d'étalonnage), Animation 25 (listes étendues aux
  8 kits), Kits 53 (+2 : jauge des passifs ; palette de sons : seulement les sons du client,
  une matière par kit, un son par action), PressQueue 4, Fuzz 2 (tous les duels des 8 kits),
  Cinematography 81 (cadrage de chaque ultime et K.O. avec le vrai rig), Lobby 5 ✅ ;
  `rigcheck` ✅. Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`, LÉGENDE, 120 matchs par duel) : KAI 48 %,
  TARO 53 %, ZEPHYR 48 %, AKEMI 58 %, RYUKEN 56 %, SHIN 45 %, DAICHA 42 %, HIBECARES 51 %
  (aucun sous 35 % ni au-dessus de 65 %). Duels les plus déséquilibrés : DAICHA contre TARO
  35 %, contre KAI 37 %.

### Problèmes ouverts / prochaine étape

- Les sons sont tous des sons du client retravaillés : à écouter en jeu (le vent coupé court
  sert de « whoosh » ; si un son est trop faible, ajuster `SoundPalette`). De vrais SFX de
  Wilhem pourront remplacer les fichiers sans toucher au reste.
- DAICHA est le plus faible des 8 (42 %) : à surveiller en vrai match.
- Avatar : toujours à confirmer en jeu (ligne d'état et Output donnent la raison).
- Prochaine étape : retours de Wilhem sur les 4 nouveaux en jeu (looks, cinématiques, sons).

## Version 0.9.8 — 1er octobre 2026

Retours de Wilhem : « toujours pas possible de jouer avec mon avatar » ; « et le lobby
multi » ; « pour le boxeur, un switch de mode : boxeur qui esquive (contres, Dempsey Roll) et
boxeur classique, sur les touches & et é, seulement TARO » ; « revois les animations des
cinématiques, optimise au max le ping avec deux joueurs de deux régions différentes » ; puis
une planche de 4 nouveaux persos (RYUKEN, SHIN, DAICHA, HIBECARES) — prochaine étape.

### Avatar

- Cause probable : la **mise à niveau des articulations d'avatar** de Roblox, qui remplace
  les Motor6D des corps R15 par des AnimationConstraint. Le serveur refusait alors le corps
  (« articulation Root absente » → modèle en blocs) ou le client attendait des Motor6D qui
  n'arrivaient jamais (corps figé).
- `RigReader.ensureJoints` (partagé) : chaque Motor6D attendu qui manque est reconstruit
  entre les deux mêmes pièces, depuis leurs points d'attache (comme
  `Humanoid:BuildRigFromAttachments`), sinon depuis les repères R6 standard ou les pivots du
  rig KAI mis à l'échelle ; les contraintes remplacées sont retirées. Appelé par le serveur à
  la création du corps et une fois placé ; par le client en secours si un corps n'a toujours
  pas ses Motor6D au bout de 2 s.
- Les erreurs de construction (pcall) sont affichées sur la ligne d'état au lieu d'un
  « chargement… » sans fin ; la ligne d'état garde la raison même en modèle en blocs.
- `tools/rigcheck.py` construit aussi `RigReader` et vérifie : R15 en AnimationConstraint avec
  et sans points d'attache, R15 déjà en Motor6D, R6 sans articulations — 15 / 6 Motor6D
  reconstruits sans déplacer aucune pièce, rien deux fois.

### TARO : deux styles (touches & / 1 et é / 2, ou les boutons du HUD)

| | BOXEUR CLASSIQUE (& / 1) | BOXEUR ESQUIVE (é / 2) |
|---|---|---|
| Garde | **de fer** (−40 % d'usure) | normale |
| Dégâts | +8 % | −5 % |
| Vitesse | marche 15, dash 34 | marche 17, dash 40 |
| ↓ + E | **DROITE DU CHAMPION** (lente, écrase la garde, met au sol) | **PARADE** qui contre |
| Dash vers l'adversaire | dash normal | **esquive de buste**, puis **DEMPSEY ROLL** |
| Pose | garde orthodoxe droite, bras avant tendu | peek-a-boo baissé |

- Changement au neutre (pas pendant un coup), au sol, 0,5 s entre deux ; le style reste d'une
  manche à l'autre ; TARO commence en CLASSIQUE. Événement `Stance` (annonce + son).
- Données : `kit.Stances` (stats, spéciale accroupie, esquive) ; simulation : `stanceOf`,
  `startersOf`, `weaveOf`, multiplicateur `DamageDealt` ; IA : change de style de temps en
  temps, n'utilise le Dempsey qu'en ESQUIVE ; poses `Kits.TARO_CLASSIQUE` (l'Animator prend
  la variante du style d'abord) et `TaroChampion`.

### Lobby multi

- Le client demande le statut du hub à son démarrage (`hello`) ; annonce « X a rejoint le
  serveur · HUB pour le défier » / « X a quitté le serveur » ; la liste s'ouvre seule quand un
  adversaire possible arrive.

### Réseau : deux joueurs de régions différentes

- **Ping** de chaque joueur mesuré par le serveur (`Player:GetNetworkPing`, chaque seconde),
  affiché sur la ligne d'état (« PING VOUS 40 ms / ADV. 180 ms »).
- **Compensation de latence** dans la simulation (`latencyTicks`, plafond
  `MaxLatencyTicks` = 12 ticks = 200 ms aller) : la fenêtre d'enchaînement après un coup
  s'allonge de la latence du joueur (ses combos ne cassent plus à cause du ping) ; un QTE de
  cinématique est jugé au tick que le joueur **voyait** quand il a appuyé (`cinTick` envoyé
  par le client, accepté dans la limite de son aller-retour), et n'est déclaré raté qu'après
  ce délai. Le serveur reste seul juge.
- **Prédiction visuelle** de son propre perso : la marche suit tout de suite la direction
  tenue et est dessinée en avance de la latence ; le serveur corrige par le lissage.
- **Cinématiques** : horloge locale lisse et monotone (au rythme du ralenti, recalée en
  douceur sur le serveur) : un paquet en retard ne fait plus sauter les plans en arrière.
- **Paquets plus légers** : noms, styles, kits et vie max ne partent que quand ils changent
  (ou toutes les 2 s), au lieu de 30 fois par seconde ; `InputTimeout` 0,8 s (un pic de lag
  ne lâche plus la garde).

### Tests

- CombatSimulation 82 (+2 : enchaînement tardif d'un joueur lointain, plafond ; QTE jugé au
  tick vu, refus d'un tick trop ancien) ; Kits 31 (+2 : changement de style, règles du style
  CLASSIQUE) ; Animation 25 (+1 : les deux gardes diffèrent et restent au sol, R15 et R6) ;
  Fuzz : appuis de style aléatoires. FighterAI 9, CinematicDirector 126, PressQueue 4,
  Cinematography 41, Lobby 5 ✅ ; `rigcheck` ✅. Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 42 %, TARO 53 %, ZEPHYR 46 %,
  AKEMI 59 % ; niveau 3 : 51 / 57 / 52 / 40.

### Problèmes ouverts / prochaine étape

- Avatar : à confirmer en jeu ; si ça échoue encore, la ligne d'état et la fenêtre Output
  (« [FightingGame] … ») donnent la raison exacte.
- Garde « au réflexe » toujours plus dure pour le joueur lointain (le serveur est l'arbitre).
- Prochaine étape : les 4 nouveaux persos de la planche (RYUKEN, SHIN, DAICHA, HIBECARES).

## Version 0.9.7 — 1er octobre 2026

Demandes de Wilhem : « le chara design de TARO ressemble trop à celui de KAI » ; « rajoute
des mécaniques de boxeur comme le Dempsey Roll » ; « gère aussi ces animations sur mon avatar
R15 » ; « lance un hub pour que je puisse jouer en 1v1 avec un pote ».

### TARO a son propre look

- Avant : le modèle en blocs de TARO était celui de KAI (cheveux en pics, veste ouverte à
  col, pantalon large, baskets) avec des gants, et sa palette BRASIER était noir / rouge
  comme KAI. Maintenant (`RigBuilder.taroHead` / `taroBody`) : cheveux courts en **mèche
  relevée**, nez scotché, cicatrice au sourcil, protège-dents ; **torse nu** musclé (pecs,
  abdos, trapèzes) avec une **serviette autour du cou** et **火 tatoué dans le dos** ; avant-bras
  bandés, **short de boxe** à bande latérale, **bottines de boxe lacées**. Palettes : BRASIER
  = gants orange, short or, bottines noires, peau mate ; CHAMPION = blanc et or.
- Sur avatar R15 / R6 : en plus des gants, du short et de la ceinture, la serviette au cou.
- **Nouvel outil `tools/rigcheck.py`** (+ `tools/RobloxMock.luau`, une imitation des API
  Roblox utilisées par RigBuilder) : construit chaque perso et chaque style hors Studio
  (modèle en blocs, tenue sur un corps R6 et sur un corps R15), vérifie que chaque pièce est
  attachée, de taille correcte et près du corps (`check`), et dessine une planche de design
  face / dos (`render`). `tools/storyboard.py` accepte maintenant la couleur propre de
  chaque pièce.

### Mécaniques de boxeur (TARO)

- **Esquive de buste** : le dash *vers l'adversaire* de TARO (`kit.Weave`) le fait plonger
  sous la garde ; pendant le dash, les coups qui ne sont pas bas passent au-dessus
  (événement `Slip`, « ESQUIVE ! », +12 de ki la première fois par coup, `SlipMeter`). Les
  coups bas, les projectiles et les ultimes touchent. Le dash arrière n'esquive pas.
- **DEMPSEY ROLL** : pendant l'esquive ou dans les 10 ticks qui suivent, **L** lance
  `TaroDempseyL`, puis L enchaîne `TaroDempseyR`, `TaroDempseyL`… (crochets en huit qui
  avancent, esquive des coups hauts sur leurs 5 premières images, 6 crochets au plus) ;
  **R** : `TaroDempseyFinish` (crochet final, envoie au mur). R directement depuis l'esquive
  = crochet final seul. L sans esquive reste le jab.
- L'ancienne compétence de combo `TaroDempsey` s'appelle maintenant **RAFALE EN HUIT** (route
  « HUIT ») pour ne pas confondre.
- CPU : TARO utilise l'esquive + Dempsey (approche et combos), à tous les niveaux.
- Animations : pose d'esquive propre à TARO (le buste roule en huit pendant le dash, champ
  `weave` du snapshot), poses des deux crochets et du crochet final, traînées des poings.
  Testées en **R15** (rig KAI et avatar aux proportions différentes) et en **R6** (retarget).
- Client : arc blanc au-dessus de la tête au slip, annonce « ESQUIVE ! », son ; la liste des
  COMBOS de TARO explique l'esquive et le Dempsey.

### HUB : 1 contre 1 entre amis

- `src/server/Lobby.luau` (pur, testé) : le premier arrivé combat le CPU, les suivants
  attendent au hub et regardent ; **DÉFIER** (30 s), **ACCEPTER** (le défiant en place 1,
  le défié en 2, les autres retournent au hub), **REFUSER**, **QUITTER LE COMBAT**, **JOUER**
  (si personne ne combat) ; quand un combattant part, le premier joueur du hub prend la place.
- Serveur : le lobby décide qui occupe les places (`sync`), remplace l'ancienne attribution
  automatique (où le 2e joueur entrait d'office en versus). Télécommande `Hub` (actions
  validées, anti-spam 0,4 s), statut envoyé à tous à chaque changement, défis expirés.
- Client `HubController` : bouton **HUB** (en haut à droite), liste des joueurs avec leur
  état, boutons DÉFIER / ACCEPTER, bandeau « X TE DÉFIE » avec compte à rebours,
  **INVITER UN AMI** (invitation Roblox `SocialService:PromptGameInvite`, dans un pcall).
- Pour jouer en ligne, la place doit être **publiée** (Studio : Publier sur Roblox, jeu
  public ou réservé aux amis) — voir le README.

### Tests

- Nouveau `tests/Lobby.test.luau` (5) ; Kits 29 (+3 : esquive de buste et slip, Dempsey Roll
  complet / limite / R seul / jab inchangé, esquive au départ des crochets) ; Animation 24
  (+1 : esquive et Dempsey en R15 et R6, au sol, poing vers l'avant, buste qui roule).
- CombatSimulation 80, FighterAI 9, CinematicDirector 126, PressQueue 4, Fuzz 2,
  Cinematography 41 ✅ ; `python3 tools/rigcheck.py check` : tous les corps construits.
  Studio ❌ non exécuté (le hub et l'invitation ne peuvent se vérifier qu'en jeu).
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 45 %, TARO 52 %, ZEPHYR 44 %,
  AKEMI 58 % ; niveau 3 : 52 / 60 / 49 / 40.

### Problèmes ouverts / prochaine étape

- À vérifier en jeu : le hub à deux joueurs (Test > Clients et serveurs), l'invitation (ne
  marche que sur une place publiée), la lisibilité du nouveau TARO en jeu.
- Plusieurs combats en parallèle sur un même serveur (une seule arène aujourd'hui) et un
  mode classé : à faire si besoin.

## Version 0.9.6 — 1er octobre 2026

Retour de Wilhem : « en R6 tu peux faire mieux, vraiment beaucoup mieux ». Nouvel outil pour
le voir au lieu de le deviner : **planche de poses R6 / R15** (`tests/PoseSheet.luau`), même
moteur que le jeu, corps R6 à gauche et rig R15 à droite, vue de la caméra du jeu.

### Ce que la planche montrait, et les corrections (`Retarget.luau`)

- **Jambes en compas** : un R6 n'a pas de genoux ; le bassin descendait à la hauteur du R15
  (genoux pliés), donc les jambes rigides s'ouvraient en grand V (jusqu'à ~60°). Désormais,
  en garde debout, les jambes gardent `LEG_KEEP` (75 %) de l'écart vers la jambe tendue :
  garde à ~25-35° au lieu de 45-60°. La hauteur est jugée sur tout le corps (la jambe d'appui
  la plus haute) : l'accroupi, le balayage et les coups bas restent aussi bas qu'avant.
- **Bras « zombie » en garde** : les bras rigides suivaient l'avant-bras R15, soit tendus à
  l'horizontale, soit levés vers le visage, et le bras arrière partait sur le côté vers la
  caméra. Nouvelle **garde R6** : bras vers l'adversaire (avant du buste, légèrement rentrés
  vers l'axe), inclinés de `ARM_GUARD_PITCH` (38°) sous l'horizontale ; ils se tendent vers
  le poing à mesure que le bras R15 s'allonge (coup = ~95 % d'allonge, garde = 45-75 %). Un
  poing levé au-dessus de la tête (marteau, victoire) garde sa ligne.
- **Buste** : le torse rigide suit la poitrine à 70 % (`CHEST_SHARE`, avant 50 %) : la
  rotation des coups se voit davantage.
- Contrôlé : les coups de pied et de poing R6 partent bien dans la même direction que le R15
  (mesures sur la planche).

### Tests

- Animation 23 (+1 : pour les 4 kits, en garde et en blocage, chaque bras R6 pointe vers
  l'avant et vers le bas, chaque jambe reste à moins de ~37° de la verticale ; le LowKick R6
  reste plus bas que la garde). Vérifié : ce test échoue avec l'ancien réglage.
- CombatSimulation 80, FighterAI 9, CinematicDirector 126, Kits 26, PressQueue 4, Fuzz 2,
  Cinematography 41 ✅. Studio ❌ non exécuté. Équilibrage inchangé (aucune donnée de combat
  touchée).
- Planche : `luau tests/PoseSheet.luau -a KIT [angle] > sheet.txt` puis
  `python3 tools/storyboard.py sheet.txt sheet.png`.

### Problèmes ouverts / prochaine étape

- À juger en jeu sur de vrais avatars R6 (proportions et accessoires variés).
- Les blocs R6 étant massifs, en vue 3/4 le bras côté caméra masque parfois le buste.
- Prochaine étape : le jeu en ligne et le lobby.

## Version 0.9.5 — 1er octobre 2026

Retours de Wilhem : « en fin de combo l'adversaire finit en l'air, donc les ultimes ne sont
pas dans le bon axe » ; « ralentis le jeu pour les cinématiques, qu'on ressente les coups » ;
puis « refais les scènes de K.O. sur tous les persos, chacun la sienne avec son thème ».

### Ultimes : même ligne, au sol

- `CombatSimulation.startCinematic` : au départ de chaque ultime, la cible (même en l'air,
  jonglée ou à terre) est posée au sol, l'attaquant est placé à `CinematicGap` (2,6 studs)
  devant elle, sur la même ligne, les deux face à face et dans l'arène (contre un mur, c'est
  l'attaquant qui se recale). Vitesses, dash, rebonds et chute en cours sont annulés.
- Client : à l'ouverture d'une cinématique, les positions affichées sautent directement à
  leur place (pas de glissade visible).

### Ralenti des cinématiques

- `CombatConfig` : `CinematicTimeScale` 0,6 (la cinématique avance à 60 % du temps réel),
  `CinematicImpactScale` 0,3 autour du coup final (de 4 ticks avant à 16 après,
  `CinematicImpactTicks`).
- `stepCinematic` avance sur une horloge : les frappes, le coup final et la chute qui suit
  tombent au ralenti ; les QTE sont lus à chaque tick réel (fenêtres un peu plus larges en
  temps réel). Dégâts et ordre des coups inchangés : l'équilibrage ne bouge pas.
- Le snapshot envoie `cinematic.scale` ; `CinematicController` extrapole le tick avec.

### Scènes de K.O. par perso (match gagné ou FINAL FINISH)

| Perso | Déroulé | Étalonnage |
|---|---|---|
| KAI 開 | inchangé : storyboard de Wilhem (main au sol, pieds, visage, dos au couchant) | — |
| TARO 火 | chute N&B au bord du ring, gants frappés au-dessus du corps (étincelles), **le compte de 1 à 8** en plan retransmission, poing levé dans un pilier de feu vu du sol, plan large du champion | feu, caméra portée |
| ZEPHYR 風 | chute vue du ciel, rafale au ras du sol (lames, lignes de vitesse), ZEPHYR **descend du ciel** et atterrit (onde), orbite lente dans l'anneau de vent, la caméra monte vers le ciel | ciel |
| AKEMI 影 | plans fixes : chute, **scène vide**, elle apparaît derrière le corps, rengaine sa lame… et la coupure tombe **après**, elle tourne le dos, disparaît : il ne reste que le corps et son sceau 影 | ombre |

La scène suit le kit du **gagnant** (`view.kit`). Plans réglés au storyboard.

### Tests

- CombatSimulation 80 (+2 : ultime sur cible jonglée contre chaque mur → même ligne au sol,
  écart 2,6, dans l'arène, face à face ; ralenti → plus de ticks réels que la cinématique,
  coup final plus lent que le reste, dégâts identiques). Budgets de ticks des anciens tests
  de cinématique agrandis.
- CinematicDirector 126 (+1 : chaque kit a sa scène de K.O. — plans propres, étalonnage,
  K.O. final, au moins 5 plans ; le test de placement couvre les 4 kits, deux gagnants,
  centre et murs).
- Cinematography : les plans de K.O. de TARO / ZEPHYR / AKEMI sont contrôlés comme des plans
  normaux (seuls les gros plans du storyboard de KAI restent exemptés).
- Kits : le test d'équilibrage joue 60 matchs par duel au lieu de 30 (à 30, AKEMI tombait à
  34 % par simple bruit ; à 120 matchs elle est à 40 %).
- FighterAI 9, Animation 22, Kits 26, PressQueue 4, Fuzz 2, Cinematography 41 ✅.
  Studio ❌ non exécuté.
- Équilibrage (`luau tests/Balance.luau -a 4 120`) : KAI 42 %, TARO 53 %, ZEPHYR 45 %,
  AKEMI 60 % (niveau 3 : 53 / 57 / 50 / 40).

### Problèmes ouverts / prochaine étape

- À juger en jeu : vitesse du ralenti (0,6 / 0,3), lisibilité du compte de TARO.
- Prochaine étape : R6 (« tu peux faire beaucoup mieux »), puis le jeu en ligne et le lobby.

## Version 0.9.4 — 1er octobre 2026

Retour de Wilhem : « toutes les animations cinématiques se ressemblent, chaque perso doit
être différent à 100 % ». C'était vrai : TARO, ZEPHYR et AKEMI partageaient la même ossature
(ouverture « prêt + ruée », fin « élan, impact, suivi », sceau + plan héroïque des portes,
intro « yeux, héros, ruée » et conclusion des éveils, même jeu d'angles). Tout est refait.

### Une identité de mise en scène par perso

| Perso | Caméra | Étalonnage | Signature |
|---|---|---|---|
| KAI 開 | coupes franches, orbites | rouge / sang (crimson, void) | ruée en téléportations, éveil vu des yeux, torii |
| TARO 火 | plans bas, **caméra portée** (balancement constant), champ / contrechamp façon retransmission de boxe | **feu** (orange chaud) | il **marche** sur la cible et la repousse : jamais de ruée ni de téléportation ; pose GloveTap (gants frappés), victoire en champion |
| ZEPHYR 風 | grands mouvements continus (grue, orbite), objectifs larges, peu de coupes | **ciel** (froid, lumineux) | tout est **aérien** : bond depuis le lointain, montée dans le vent, vortex vu de très loin puis de l'intérieur ; pose WindGather ; fin de dos face au ciel |
| AKEMI 影 | **plans fixes**, coupes sèches, souvent **sans elle à l'image** | **ombre** (violet sombre) + noir et blanc | elle disparaît, la cible la cherche du regard ; frappes de nulle part ; temps arrêté, tableaux fixes ; pose Sheathe (lame rengainée) |

Les 9 ultimes de TARO, ZEPHYR et AKEMI ont chacun leur propre déroulé (début, milieu, fin) ;
le timing autoritaire (frappes, QTE, coup final) est inchangé, donc l'équilibrage aussi.

- `CinematicDirector` : nouvelles stagings complètes (l'éveil de ces kits n'utilise plus
  l'intro ni la conclusion de KAI) ; nouveaux champs de frame `grade.fire / sky / shadow` et
  `handheld`.
- `PoseLibrary` : poses GloveTap, WindGather, Sheathe ; `Animator` : une pose mise en scène
  prend d'abord la version du kit (victoire, garde…).
- `CinematicController` : étalonnages feu / ciel / ombre, caméra portée.
- Test : « every character's cinematics are its own » (aucun plan partagé entre deux kits ni
  entre deux ultimes, au moins 5 plans par ultime, chaque kit garde son étalonnage et
  n'utilise jamais celui d'un autre). Les storyboards ont servi à régler chaque plan.

### Tests

CombatSimulation 78, FighterAI 9, CinematicDirector 125, Animation 22, Kits 26, PressQueue 4,
Fuzz 2, Cinematography 41 ✅. Studio ❌ non exécuté.

### Problèmes ouverts

- À juger en jeu : force de la caméra portée de TARO, teintes des trois étalonnages, AKEMI
  « hors champ » (placée au-dessus de la scène pendant ses disparitions).
- Audit Codex : points 3 et suivants toujours non reçus.

## Version 0.9.3 — 1er octobre 2026

Mission de Wilhem : corriger un maximum de bugs, améliorer les animations et **vraiment
améliorer les cinématiques** (« prends le temps qu'il faut, make it cool »). Ensuite : le
jeu en ligne et le lobby. Toujours **rien de lancé dans Studio**.

### Chasse aux bugs

- **Nouveau `tests/Fuzz.test.luau`** : des joueurs aléatoires (appuis en rafale, garde,
  sauts, dashs, ultimes, deux boutons à la fois) sur les 16 duels de kits, en versus et en
  entraînement, plus le CPU contre un joueur aléatoire. À chaque tick : pas de NaN, vie / ki /
  garde dans leurs bornes, personne sous le sol ni hors de l'arène, file d'appuis bornée,
  aucun état bloqué, chaque cinématique se termine. ✅ (aucun bug de simulation trouvé ;
  une « attaque bloquée » signalée était une vraie chaîne de coups, le critère a été affiné.)
- **Nouveau `tests/Cinematography.test.luau`** (41 cas) : chaque ultime des 4 persos (et ses
  versions K.O., au centre et contre le mur) est joué avec la vraie simulation, le vrai
  réalisateur et le **vrai moteur d'animation** (corps posés membre par membre) ; à chaque
  image : caméra hors des corps, sujet à l'écran et lisible.
- Bugs trouvés et corrigés :
  - **caméra dans les corps** sur une grande partie des plans (« windup », poing, gros plan
    des yeux, charge du dragon, plans serrés de l'éveil…) : jusqu'à 20 fois la hauteur de
    l'écran, la caméra à 0,66 stud d'un bras ;
  - **plan « ko-feet » de la scène K.O.** : la caméra était dans le corps du perdant ;
  - corps qui se chevauchaient pendant les tourbillons (TARO, ZEPHYR, AKEMI) ;
  - cible des ruées de kit épinglée au centre après le coup final.

### Cinématiques refaites

- `CinematicDirector` : les plans ne sont plus posés à la main (« tête + décalage ») mais
  **composés** par `frameOn` : angle autour des sujets (relatif au sens de l'attaque),
  plongée / contre-plongée, part de l'écran à remplir, tranche du corps (plein pied, buste),
  distance minimale aux corps. Chaque ultime a été repris plan par plan et vérifié en
  storyboard :
  - ouverture (pose de prêt, plan héroïque en contre-plongée, ruée suivie de côté) ;
  - rafales en **coupes franches** sur un jeu d'angles forts (trois-quarts, moyen,
    plongée verticale, contre-plongée inclinée, large derrière l'attaquant) ;
  - élan en contre-plongée derrière l'attaquant avec **poussée lente** vers les deux ;
  - impact incliné, puis plan large qui suit la cible projetée ;
  - TEMPS SUSPENDU : AKEMI face caméra, la cible figée derrière, les coupures en croix
    au retour du temps.
- Nouveaux procédés côté client : **lignes de vitesse** anime pendant les ruées et les
  rafales, et **impact** (image d'impact contrastée + coup de zoom de la caméra + secousse)
  sur les grosses frappes, une fois par coup.
- Outil **storyboard** : `tests/Storyboard.luau` + `tools/storyboard.py` dessinent la planche
  de ce que voit la caméra (Python 3 + Pillow, pour vérifier une cinématique hors Studio).

### Animations

Revue des poses de KAI (R15) état par état et coup par coup, de face et de profil : pas de
défaut trouvé (les coups de pied paraissaient pliés en vue 3/4, ils sont bien tendus de
profil). Le R6 a été retravaillé en 0.9.1.

### Tests

CombatSimulation 78, FighterAI 9, CinematicDirector 125, Animation 22, Kits 26, PressQueue 4,
**Fuzz 2**, **Cinematography 41** ✅. Compilation et analyse statique ✅. Studio ❌.

### Problèmes ouverts

- Storyboards hors ligne : corps en blocs, effets simplifiés ; le rendu réel (avatars,
  particules, étalonnage) reste à juger en jeu avec le LABO CINÉ.
- Audit Codex : points 3 et suivants toujours non reçus.

### Prochaine étape : en ligne et lobby

À préparer avec Wilhem (proposition dans la réponse) : lieu de rassemblement, file de
matchmaking, arènes de match en serveurs réservés (TeleportService), retour au lobby.

## Version 0.9.2 — 1er octobre 2026

Wilhem a fourni une **planche d'ultimes** (boxeur, combattant au pied, esquiveur) et un
**audit Codex** de la 0.9.0 (commit `8bea7a3`). Le message de l'audit est **coupé après le
point 2** : les points suivants restent à recevoir. Chaque point reçu a été vérifié dans le
code avant correction. Rien lancé dans Studio.

### Audit, point 1 — un 開天 parfait pouvait tuer sans assez de dégâts ✅ corrigé

Confirmé (`judgePrompts`) : au QTE (tick 140), les deux premières frappes (118, 126) sont
déjà dans les PV, mais la décision de K.O. additionnait tout le plan. Avec 800 PV et 775 de
dégâts : K.O. au lieu de 25 PV. La décision compare maintenant les PV restants aux seules
frappes encore à venir. Test : « gate: a perfect gate only KOs if the blows left can
finish » (les 4 kits ; 25 PV exacts restants, K.O. si les dégâts suffisent).

### Audit, point 2 — appuis perdus ou réordonnés ✅ corrigé

Confirmé : le serveur fusionnait les appuis avec `or` (2 clics entre deux ticks = 1) et la
simulation les lisait dans un ordre fixe (lourd puis léger devenait léger d'abord) ; le
client fusionnait aussi entre deux paquets. Nouveau module pur `src/shared/PressQueue.luau` :
le client envoie la liste ordonnée des appuis d'attaque (`presses`), le serveur la valide
(tableau de 8 noms connus au plus), la met en file (6 au plus) et donne **un appui par tick**
à la simulation. Nouveau `tests/PressQueue.test.luau` (4 tests, dont « lourd puis léger dans
un seul paquet joue R puis L »). Plusieurs boutons à la même frame arrivent maintenant à un
tick d'écart : ils restent marqués (« TROP TÔT » / « SPAM ») par la règle du rythme.

### Ultimes selon la planche

| Perso | 1 · R seul | 2 · route + clic droit | 3 · route + R |
|---|---|---|---|
| TARO | RUSH DÉVASTATEUR : charge, coups de face, droite finale | UPPERCUT CÉLESTE : coups au corps, uppercut dans un pilier de feu, finition aérienne | 火嵐 TEMPÊTE DE CROCHETS : tourne autour de la cible, crochet après crochet, anneaux de feu |
| ZEPHYR | VENT TRANCHEUR : un coup de pied toutes les 4 frames, lame de vent sur chacun | DRAGON ASCENDANT : pied montant, montée dans un dragon de vent, coups des deux côtés, vrille puis piqué | 旋風 CYCLONE FURIEUX : vortex qui soulève la cible, rotation de coups de pied |
| AKEMI | OMBRES MULTIPLES : des copies frappent de tous les côtés | TEMPS SUSPENDU : temps arrêté (noir et blanc), esquive, coups au ralenti, coupures en croix | 幻舞 DANSE FANTÔME : esquives et réapparitions, frappes instantanées |

- Mise en scène pure dans `CinematicDirector` (`Director.KIT_ULTIMATES`) ; timing
  autoritaire inchangé (frappes, QTE à 140, coup final) : équilibrage identique. KAI garde
  ses 3 ultimes.
- Nouvel effet client `arc` (lames de vent, crochets, coupures) ; un perso qui tourne autour
  de la cible reste sur la moitié arrière, la caméra devant la voit toujours.
- Corrigé au passage : les traînées d'arc des gros coups (`EffectsController:slash`) ne
  marchaient que pour les coups de KAI ; elles passent par le rôle du coup.

### Tests

CombatSimulation **78**, FighterAI 9, CinematicDirector **125** (+ « TARO, ZEPHYR et AKEMI
jouent leurs propres ultimes » ; les 3 ultimes × 4 persos × 3 positions passent les
contrôles de caméra), Animation 22, Kits 26, **PressQueue 4** ✅. Compilation et analyse
statique ✅. Studio ❌ non exécuté.

### Problèmes ouverts

- Audit : points 3 et suivants non reçus (message coupé).
- Ultimes : poses et effets vérifiés hors ligne seulement (cadrage, pas de rendu) ; à juger
  en jeu avec le LABO CINÉ.

## Version 0.9.1 — 1er octobre 2026

Retours de Wilhem sur la 0.9.0 (vue en jeu) : après le passage de R15 à R6 « ça ne veut
plus vraiment marcher », les animations R6 ne sont pas belles (planche de référence R6
fournie : gardes basses et larges, buste penché, poings levés devant), et un texte qui
apparaît reste à l'infini. Toujours **rien de lancé dans Studio** de mon côté.

### Animation R6 (`src/shared/Retarget.luau`)

- **Torse** : un seul bloc pour le bassin et la poitrine virtuels, tourné à mi-chemin entre
  les deux et accroché à la taille (avant, il suivait toute la torsion de la poitrine : le
  corps entier pivotait sur chaque coup de poing).
- **Bras** : visent le milieu de l'avant-bras virtuel (`ARM_REACH` = 0,7) au lieu du poing.
  Bras tendu : identique ; garde : bras levés devant en diagonale, plus à travers la tête.
- **Jambes** : une jambe pliée ne peut pas se plier en R6. Au sol, elle garde la hauteur du
  pied et s'écarte à l'horizontale (`STANCE_DEPTH` = 0,88, un peu plus bas) : garde large et
  basse, l'accroupi baisse vraiment le corps. En l'air (armés de coups de pied, sauts), elle
  suit le milieu du tibia. Jambe tendue : vise la semelle comme avant.
- Vérifié par rendus hors ligne (garde, accroupi, course, saut, coups des 4 persos) et par un
  nouveau test.

### Passage R15 → R6

Cause probable trouvée côté client (non confirmée en jeu) : si le corps R6 n'était pas
entièrement répliqué quand le client le lisait, le contrôleur d'animation était créé sans
squelette et gardé : corps figé pour toujours. Le client relit maintenant le squelette
toutes les 0,25 s tant qu'il est incomplet. Si le problème persiste, il faut la sortie de la
console (F9) au moment du passage en R6.

### Textes qui restaient affichés

- Le tampon des cinématiques (nom du coup « !! », « RYTHME : … ») ne disparaissait qu'à la
  fin de la cinématique ; un événement arrivé juste après (remote séparé) le laissait à
  l'écran. Il se cache maintenant seul après 1,2 s.
- Annonces et noms de techniques : devenus transparents mais jamais masqués (le contour
  `UIStroke` restait) ; ils sont maintenant cachés après leur fondu.

### Tests

CombatSimulation 77, FighterAI 9, CinematicDirector 124, **Animation 22** (+ « R6 : l'accroupi
baisse le corps, la garde garde les poings hors de la tête », pour les 4 persos), Kits 26 ✅.
Compilation et analyse statique ✅. Studio ❌ non exécuté.

### Prochaine étape proposée

1. Wilhem refait le passage R15 → R6 ; si ça bloque encore, envoyer la console (F9).
2. Dire si la garde R6 doit être encore plus basse ou les bras plus hauts : ce sont deux
   réglages (`Retarget.STANCE_DEPTH`, `Retarget.ARM_REACH`).

## Version 0.9.0 — 1er octobre 2026

Deuxième quête de Wilhem : **R15 et R6**, des combos **ni trop simples ni injouables**
(« le juste milieu »), **4 persos** avec chacun leur style (un boxeur, un perso qui ne frappe
qu'avec les pieds, un perso qui esquive avec un passif mais encaisse peu, le reste libre),
des **coups qui ne partent plus quand on change d'avis**, et un jeu **vraiment équilibré,
compétitif**. Toujours **rien de lancé dans Roblox Studio** : tout est vérifié hors ligne
(tests Luau, analyse statique) ou relu, pas vu en jeu.

### Combos : la règle du rythme

- Un appui ne compte « propre » que s'il est fait **après la sortie du coup d'avant**
  (frames actives, impact, récupération ou 6 frames de tolérance). Tapé pendant l'élan, le
  combo continue mais n'est plus propre (`dirtyReason` = « TROP TÔT ») : plus d'ÉVEIL ni de
  PORTE. Fini de taper toute la route d'avance.
- File de **3 appuis**, chacun expire en **10 frames** (« APPUI PERDU ») ; plusieurs boutons
  à la fois / appui de trop = « SPAM » ; mauvais bouton = « MAUVAIS BOUTON ».
- **Changer d'avis gagne** : garde, saut ou dash vident la file ; un coup dans le vide
  oublie les appuis faits pendant son élan (sauf un appui délibéré dans ses 4 dernières
  frames). Testé au clavier comme à la souris côté simulation (les deux envoient les mêmes
  impulsions).
- L'ENTRAÎNEUR affiche la raison exacte (snapshot `dirtyReason`).

### 4 persos (kits)

Un kit associe chaque **rôle** de KAI (Jab, Cross, Smash, KiChase, Finale, KaienRush…) à
ses propres coups : même grammaire de combos pour tous, l'IA et les cinématiques marchent
pour chacun. `MoveData.Kits`, `MoveData.KitOrder`, `MoveData.MoveKit`.

| Perso | Vie | Identité | S + E |
|---|---|---|---|
| KAI 開 polyvalent | 1550 | équilibré | KIKOHO |
| TARO 火 boxeur | 1600 | que les poings, allonge ×0,94, jab en 4 frames, garde de fer (usure ×0,8) | PARADE (frames 3–12) → CONTRE |
| ZEPHYR 風 jambes | 1450 | que les pieds, allonge ×1,12, dégâts ×1,05, saut le plus haut | LAME DE VENT |
| AKEMI 影 esquive | 1100 | la plus rapide, dégâts ×0,88, dash intouchable 5 frames, passif VOILE D'OMBRE (20 s) | KUNAÏ |

- Chaque kit a ses noms, ses 11 routes, ses 6 routes complètes, ses 3 ultimes et leurs
  cinématiques (couleurs et finales propres), ses poses (garde, course, accroupi, coups,
  victoire) et 2 à 4 styles de couleurs (`CharacterData` : BRASIER / CHAMPION, AZUR /
  TEMPÊTE, OMBRE / LUNE ROUGE en plus des 4 de KAI).
- **Tenues sur l'avatar** (`RigBuilder.applyKit`, R15 et R6) : KAI bandeau + ceinture +
  bandages ; TARO gants de boxe, short, ceinture de champion ; ZEPHYR longue écharpe qui
  flotte, protège-tibias ; AKEMI capuche, masque à nœud flottant, brassards. Kanji dans le
  dos. Sur le modèle en blocs, la tenue du kit s'ajoute au corps de KAI.
- Choix : **T** / bouton PERSO, **G** / bouton ADVERSAIRE (CPU, solo). Serveur : impulsions
  `kit` / `foeKit` validées et limitées (0,5 s), `Sim.setKits`, nouveau match. En versus,
  seulement avant le premier coup du match ou après sa fin.
- HUD : barres de vie à la vie max du perso, kanji / nom / rôle, jauge du passif, liste
  COMBOS, ENTRAÎNEUR et LABO du perso local, annonces « PARADE ! » et « VOILE D'OMBRE ! ».
  Effets (étincelle dorée, image rémanente) et sons (fichiers moteur) de parade / esquive.

### Équilibrage (CPU contre CPU, `luau tests/Balance.luau`)

Taux de victoire de la ligne contre la colonne, chaque duel joué des deux côtés.

| LÉGENDE, 120 matchs | KAI | TARO | ZEPHYR | AKEMI | moyenne |
|---|---|---|---|---|---|
| KAI | — | 43 % | 53 % | 40 % | 45 % |
| TARO | 57 % | — | 48 % | 55 % | 53 % |
| ZEPHYR | 48 % | 52 % | — | 33 % | 44 % |
| AKEMI | 60 % | 45 % | 68 % | — | 57 % |

| DIFFICILE, 200 matchs | KAI | TARO | ZEPHYR | AKEMI | moyenne |
|---|---|---|---|---|---|
| KAI | — | 55 % | 50 % | 56 % | 53 % |
| TARO | 45 % | — | 48 % | 64 % | 53 % |
| ZEPHYR | 51 % | 52 % | — | 56 % | 53 % |
| AKEMI | 44 % | 36 % | 44 % | — | 42 % |

Toutes les moyennes entre 42 et 57 % (test de régression : 35–65 %). AKEMI monte avec le
niveau (perso technique) ; les duels extrêmes (AKEMI–ZEPHYR 68 % en LÉGENDE, TARO–AKEMI
64 % en DIFFICILE) changent de sens selon le niveau : c'est surtout le style du CPU qui
pèse. Leviers utilisés : recharge du passif (le plus fort, l'ÉVEIL étant en %), vie
d'AKEMI, KUNAÏ et PAS DE L'OMBRE affaiblis, esquive seulement au neutre, l'IA « appâte »
le passif avec un jab seul et garde contre les projectiles.

### R6

- `RigReader.rigType` reconnaît un corps R6 (Torso sans UpperTorso), `RigSpec.R6` donne les
  joints R6 standard.
- `src/shared/Retarget.luau` (nouveau, pur) : squelette R15 **virtuel** aux proportions du
  corps R6 ; l'Animator l'anime sans changement (IK, timelines) ; chaque membre R6 rigide est
  orienté de son pivot vers le poing ou la semelle virtuels, tourné comme l'avant-bras / le
  pied ; ancrage au sol avec la géométrie R6.
- Serveur : avatar construit en R15 ou R6 (`CreateHumanoidModelFromDescription`), type par
  défaut lu sur le compte (`GetCharacterAppearanceInfoAsync`, `playerAvatarType`) ;
  APPARENCE : avatar R15 → avatar R6 → modèle. Le clone d'ombre du CPU prend le même type.
- Effets et cinématiques visent les bonnes pièces sur R6 (`RigReader.part`).

### Corrections au passage

- Cinématiques : la caméra ne visait jamais la pièce du corps (une expression `if` ne
  renvoyait qu'une valeur) ; elle retombait sur la position du combattant. Corrigé.
- Panneaux COMBOS / LABO qui recouvraient la 3e rangée de boutons : placés sous la dernière.
- IK du pied : cheville calculée exactement (pied à plat et droit quel que soit l'écart des
  hanches, la flexion et l'inclinaison du bassin).

### Fichiers

Nouveaux : `src/shared/Retarget.luau`, `tests/Kits.test.luau`, `tests/BalanceKit.luau`,
`tests/Balance.luau`. Modifiés : `MoveData`, `CombatSimulation`, `FighterAI`,
`CharacterData`, `PoseLibrary`, `Animator`, `Kinematics`, `RigSpec`, `RigReader`,
`CinematicDirector`, `CombatConfig` (0.9.0), `InputConfig` (T, G), `RigBuilder`,
`init.server`, `init.client`, `AnimationController`, `CinematicController`,
`EffectsController`, `HUDController`, `InputController`, `SoundController`, README,
CLAUDE.md.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` (77) : règle du rythme, changement d'avis, parade, esquive, dash intouchable… | ✅ |
| `luau tests/FighterAI.test.luau` (9) | ✅ |
| `luau tests/CinematicDirector.test.luau` (124) : les 3 ultimes de chaque perso, plans par type | ✅ |
| `luau tests/Animation.test.luau` (21) : gardes et coups de chaque perso (TARO ne frappe pas du pied), R6 (corps standard et mis à l'échelle, combat CPU complet sans enfoncement ni flottement) | ✅ |
| `luau tests/Kits.test.luau` (26) : rôles complets avec les coups propres à chaque kit, stats, allonge de ZEPHYR, garde de fer et PARADE de TARO (et ce qui la bat), VOILE D'OMBRE et dash d'AKEMI, équilibrage 35–65 % | ✅ |
| Compilation et analyse statique Luau de tous les scripts | ✅ |
| Jeu dans Studio (tenues sur de vrais avatars R15/R6, HUD, sons) | ❌ non exécuté |

### Problèmes ouverts

- Rien vu en jeu : tenues taillées par calcul sur les pièces de l'avatar (accessoires et
  cheveux peuvent traverser la capuche d'AKEMI), animation R6 vérifiée seulement hors ligne.
- La taille visible d'une tête R6 classique est estimée (taille de la pièce × échelle du
  mesh) : bandeau / masque à ajuster si besoin.
- `Model:ScaleTo` sur un R6 non parenté, et `GetCharacterAppearanceInfoAsync`, à vérifier
  en jeu (repli : R15).
- Équilibrage mesuré entre CPU, pas entre humains : à recouper avec de vrais matchs.
- Sons toujours provisoires (fichiers du moteur).

### Prochaine étape proposée

1. Wilhem lance la 0.9.0 dans Studio : T pour passer les 4 persos, APPARENCE en R6, une
   route en rythme avec l'ENTRAÎNEUR, la parade de TARO et le passif d'AKEMI.
2. Retours précis (perso, coup, frame) ; tests entre joueurs pour l'équilibrage.
3. Ensuite : SFX du jeu, écran de sélection des persos avant le match.

## Version 0.8.0 — 1er octobre 2026

Mission de Wilhem : **qualité** — graphismes, jouer **son avatar avec le kit KAI**, et une
**vraie amélioration des animations**. Toujours **rien de lancé dans Roblox Studio** : tout
ce qui suit est vérifié hors ligne (tests Luau) ou relu, pas vu en jeu.

### Animation : nouveau moteur, testé hors Studio

L'animation n'est plus une table de poses dans le client : c'est un module pur
(`Animator`) qui tourne aussi dans les tests, avec la cinématique directe (FK) du vrai rig.

| Module | Rôle |
|---|---|
| `src/shared/RigSpec.luau` | Géométrie du rig KAI (pièces, pivots) : une seule source pour le RigBuilder et les tests |
| `src/shared/Kinematics.luau` | Maths pures : transformations au format CFrame, FK, IK de jambe à 2 os, pied qui roule sur le talon / la pointe, ressorts |
| `src/shared/PoseLibrary.luau` | Toutes les poses (déplacées du client) + nouvelles poses |
| `src/shared/Animator.luau` | Timelines, marche, mélanges, ressorts, regard, ancrage au sol |
| `src/shared/RigReader.luau` | Lit les Motor6D d'un rig vivant (KAI ou avatar R15) au format de Kinematics |
| `src/client/AnimationController.luau` | Réécrit : lit le squelette réel, appelle l'Animator, écrit les Motor6D et les tissus |

Ce qui change à l'écran :

- **Coups en 4 temps** : anticipation (la pose de départ est poussée 15 % plus loin puis
  tenue), **frame d'impact** qui dépasse la pose de contact pendant 2 ticks (smear), contact,
  puis récupération et retour en garde avec un léger rebond. Toujours calé sur la frame
  autoritaire du serveur ; « POSES : 12/15/24/s » garde l'effet par paliers de l'anime.
- **Pieds plantés par IK** : garde, accroupi, coups de poing, réactions… les pieds sont posés
  au sol par cinématique inverse, talon levé sur les coups (le pied pivote sur sa pointe).
- **Course sans glissade** : la marche avant devient une course de combattant (phase en
  l'air), la marche arrière un pas chassé ; la phase suit la distance réellement parcourue à
  l'écran, le pied d'appui ne glisse plus (vérifié pour KAI et pour un corps d'avatar).
- **Ancrage au sol pour tout corps** : le point le plus bas (ou les pieds plantés) est posé
  sur le sol à chaque frame, quelle que soit la taille de l'avatar ; plus rien ne flotte ni
  ne traverse le sol (couché, à genoux, balayage…).
- **Réactions selon le coup reçu** : tête rejetée (2 variantes alternées), plié en deux
  (coups au corps, rafales), jambes fauchées (coups bas) ; impact puis vacillement.
- **Nouvelles séquences** : relevé en 3 temps (au sol → un genou → garde), chute avec impact
  et rebond des membres, effondrement en 2 temps (mains au ventre → à genoux), garde brisée
  qui titube, saut en 3 phases selon la vitesse verticale, **atterrissage amorti**, dash
  arrière en petit saut, victoire avec poing levé, pose 開天 PORTE DES CIEUX (manquait).
- **Mouvements secondaires** (ressorts) : inclinaison selon l'accélération, secousse du
  buste à chaque coup reçu, respiration, et **le regard suit l'adversaire** (lève la tête
  vers une cible en l'air, la baisse vers un adversaire au sol).
- **Demi-tour** : quand les combattants se croisent, le corps pivote en quelques frames
  (par le côté caméra) au lieu de se retourner d'un coup.
- **Tissus** : pans de ceinture et du bandeau sur des `Weld` (`TailJoint`) qui ondulent avec
  le mouvement (ressorts), sur KAI et sur le kit posé sur l'avatar.

### Ton avatar avec le kit KAI

- Chargement en cascade, jamais d'échec silencieux : compte (UserId) → identifiant
  d'apparence (`CharacterAppearanceId`, utile en Studio) → 2 essais chacun → avatar **sans
  accessoires** si le corps complet ne se construit pas → **corps R15 par défaut** aux
  couleurs du style → KAI seulement si même ça échoue. Le kit est posé dans tous les cas.
- L'avatar est **mis à la taille de KAI** (≈ 5,7 studs) avec `Model:ScaleTo` quand il est
  trop petit ou trop grand : les hurtboxes de la simulation correspondent au corps affiché.
- Attribut joueur `AvatarStatus` (`CHARGEMENT`, `OK`, `SANS ACCESSOIRES|raison`,
  `DÉFAUT|raison`, `KAI|raison`) : le HUD l'affiche dans la ligne d'état et annonce
  « AVATAR INDISPONIBLE » avec la raison.
- Apparence mise en cache par joueur (changer de style ne recharge plus l'avatar).

### Graphismes

- Arène : plancher en `WoodPlanks` avec zone de combat usée, marches et ruines en `Slate` /
  `Cobblestone`, bannières en `Fabric`, lanternes rondes avec chapeau et lumière qui projette
  des ombres, **cerisiers** (2e plan de profondeur), **braises** qui montent du plancher,
  **brume au sol** (texture moteur `rbxasset://textures/particles/smoke_main.dds`).
- Lumière de coucher de soleil retravaillée, ombres du soleil plus nettes, `SunRays`,
  bloom et étalonnage ajustés ; le corps de KAI **projette maintenant son ombre**.
- Client (`StageController`, nouveau) : lanternes qui vacillent, bannières au vent, **ombre
  de contact** douce sous chaque combattant (rétrécit en l'air), léger flou de profondeur
  sur le décor pendant le combat (coupé pendant les cinématiques).
- **Traînées de mouvement** (`Trail`) sur le poing ou le pied qui frappe, couleur du ki ;
  **lueur de ki** (lumière) pendant les compétences et ultimes, pulsation quand l'ultime est
  prêt.

### Sons (provisoires)

`SoundController` (nouveau) : impacts, garde, garde brisée, sauts, atterrissages, chutes,
relevés, souffle des coups, super flash, QTE, pas de course. **Uniquement des sons livrés
avec le moteur Roblox** (`rbxasset://sounds/...` : `action_jump_land.mp3`, `action_jump.mp3`,
`action_get_up.mp3`, `action_footsteps_plastic.mp3`, `swordslash.wav`, `swordlunge.wav`,
`unsheath.wav`, `electronicpingshort.wav`) : ce sont des fichiers du client Roblox, pas des
ID d'asset. Bouton **SON** pour couper. À remplacer par les SFX du jeu quand Wilhem les fournit.

### Tests

| Test | État |
|---|---|
| `luau tests/Animation.test.luau` (16, nouveau) : chaque coup a ses poses, chaque état a son animation, angles dans les limites, pieds plantés au sol et à plat (KAI **et** un corps d'avatar aux proportions différentes), rien ne traverse le sol, couché = vraiment au sol, **course sans glissade** dans les 2 sens et les 2 orientations, phase en l'air, timelines (impact snappé, retour exact en garde, pas de saut > 75°/frame), anticipation et smear, paliers, réactions selon le coup, atterrissage, regard, ressorts stables, **combat CPU complet de 45 s** sans NaN ni traversée du sol | ✅ |
| `luau tests/CombatSimulation.test.luau` (73) | ✅ |
| `luau tests/FighterAI.test.luau` (9) | ✅ |
| `luau tests/CinematicDirector.test.luau` (33) | ✅ |
| Compilation Luau de tous les scripts | ✅ |
| Jeu dans Studio (rendu, avatar réel, sons, performances) | ❌ non exécuté |

Les tests ont trouvé et fait corriger : pieds qui glissaient au contact du sol (la course
démarre et s'arrête maintenant à vitesse nulle par rapport au sol), torsion du bassin qui
décalait les pieds, bras qui calaient le corps 1 stud au-dessus du sol en position couchée,
pied replié qui traversait le sol (KICK BAS), genou arrière sous le sol (BALAYAGE), cou
au-delà de sa limite pendant les coups.

### Problèmes ouverts

- Rien vu en jeu : poses, vitesse de la course, force des ressorts, ombres et flou de
  profondeur sont à juger dans Studio (le bouton POSES : FLUIDE aide à comparer).
- Sons provisoires (fichiers du moteur), à remplacer.
- `Model:ScaleTo` sur un avatar non parenté à vérifier en jeu (sinon la mise à l'échelle est
  sautée, un avertissement s'affiche).
- La lecture des `CFrame` des pièces juste après l'écriture des `Motor6D` (tissus) peut avoir
  une frame de retard : sans gravité visible.

### Prochaine étape proposée

1. Wilhem lance la 0.8.0 dans Studio : son avatar avec le kit (et la ligne d'état si ça
   échoue), la course, les coups en POSES 15/s puis FLUIDE, les chutes et relevés.
2. Retours visuels précis (« tel coup, telle frame ») : le labo + HITBOX donnent le plan et
   le tick ; les poses se règlent dans `PoseLibrary.luau` et les tests vérifient le reste.
3. Ensuite : kits du roster (proposition 0.7.0) et SFX du jeu.

## Version 0.7.1 — 1er octobre 2026

Précision de Wilhem : « spammer », c'est appuyer sur tous les boutons, pas appuyer vite sur
les bons. Nouvelle règle de route **propre** (ultimes 2 et 3) :

- taper la bonne suite, aussi vite qu'on veut et même entièrement d'avance, reste propre ;
- est du spam : plusieurs boutons sur le même tick, un appui qui déborde de la file, un
  mauvais bouton quand la fenêtre d'enchaînement est ouverte, ou un appui jamais utilisé ;
- la file d'appuis passe de 3 à 6 (une route complète d'avance) ; la règle « 1 appui après
  l'impact » et la tolérance précoce (`CleanEarlyTicks`) sont supprimées.

Tests : 73 (combat, dont « route tapée d'avance très vite = ÉVEIL » et « tous les boutons à
la fois = pas d'ultime »), 9 (IA), 33 (caméra) ✅.

## Version 0.7.0 — 1er octobre 2026

Retours de Wilhem : impossible de placer les combos, cinématiques à déboguer ; l'IA lui a
mis un ultime ; équilibrer les barres de vie ; repenser les persos comme « le perso du
joueur avec un kit » ; à la manette, les appuis faits pendant qu'on se fait frapper sortent
au relevé alors qu'il veut garder. **Toujours rien de lancé dans Roblox Studio.**

### Combos jouables

- **Tolérance tardive** (`LateCancelTicks = 6`) : un appui reçu jusqu'à 6 ticks après la fin
  d'un coup qui a touché enchaîne encore (latence réseau Roblox).
- (0.7.1 : la tolérance précoce est remplacée par la nouvelle définition du spam.)
- Réglages de VENT ASCENDANT, BALAYAGE, TALON FOUDRE, POING DU DRAGON : **les 6 routes
  passent avec 4 à 16 ticks de réaction et un écart de départ de 3 à 4,4** (test permanent).
- **Entraîneur de combo** (HUD) : route choisie, cases des touches, « MAINTENANT ! » quand le
  serveur juge le prochain appui bon (`cancelReady`), et la raison d'un échec.

### Appuis pendant les coups reçus

Pendant l'étourdissement, la chute, le relevé ou la garde, les appuis sont **ignorés** sauf
dans les 4 derniers ticks (`ReversalBufferTicks`, reversal volontaire) ; maintenir la garde
au moment de récupérer **vide** la file d'appuis.

### Cinématiques testables

- Nouvelle **mise en scène pure** `src/shared/CinematicDirector.luau` (positions, poses,
  plans, effets demandés) ; le client ne fait plus qu'exécuter.
- `tests/CinematicDirector.test.luau` rejoue chaque cinématique avec la vraie simulation et
  vérifie chaque frame : caméra au-dessus du sol, hors des corps, dans l'arène, sujet devant
  et **non caché par l'autre combattant** ; au centre et contre les deux murs ; et que chaque
  route d'ÉVEIL a sa propre finale et que le FINAL FINISH contient tous les plans de K.O.
- **Bugs trouvés et corrigés** : « DOS DU GAGNANT » filmait dans le mauvais sens (le gagnant
  hors champ) ; l'orbite de TORNADE passait derrière KAI qui cachait la cible.
- **LABO CINÉ** (solo) : lance n'importe quelle cinématique sans combo
  (`CombatSimulation.debugCinematic`, remote `Debug` validé côté serveur) + aperçu de la scène
  de K.O. ; avec HITBOX, affichage « plan · tick · FOV » pour signaler un plan précis.

### Équilibrage

Vie 1000 → **1500** : une route complète ≈ 20-27 %, KAIEN RUSH ≈ 28 % ; PORTE DES CIEUX
40 % de la vie max (+10 % au QTE) ; ÉVEIL inchangé (−95 % de la vie actuelle).

### Kits sur l'avatar Roblox

KAI devient un **kit** : style de combat + tenue posée sur l'avatar du joueur, dimensionnée
sur ses vraies pièces (bandeau noué, ceinture à nœud et pans, bandages, 開 dans le dos). Quatre
**styles** de la planche : CLASSIQUE, NUIT, SACRÉ, MAUDIT (bouton STYLE ; le CPU prend un autre
style). `CharacterData[slot]` est l'apparence courante d'un slot, changée par le serveur et
synchronisée par le snapshot.

**Proposition pour la suite (à valider)** : un kit par perso du roster de la planche — RYUEN
龍 (vitesse, combos), ZEPHYR 風 (aérien), KARA 花 (technique, portée), DAIGO 岩 (lourd, zone),
SORA 雷 (projectiles), AKEMI 影 (assassin, feintes), TARO 火 (puissance). Chaque kit = son
propre MoveData (routes, 3 ultimes), sa tenue sur l'avatar et ses styles ; écran de sélection
avant le combat.

### Animation

Fondu court (~0,07 s) entre les poses qui ne sont pas des impacts (garde, marche, accroupi,
récupérations) ; impacts et réactions aux coups restent instantanés.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 71 tests | ✅ |
| `luau tests/FighterAI.test.luau` : 9 tests | ✅ |
| `luau tests/CinematicDirector.test.luau` : 33 tests (caméra de chaque cinématique) | ✅ |
| Studio | ❌ non exécuté |

## Version 0.6.0 — 1er octobre 2026

Demandes de Wilhem : l'attaque écarlate doit se mériter (plus de spam) ; un combo combiné
au R qui change la cinématique ; **3 ultimes par perso** (R classique, fin de chaîne, fin
de chaîne + R) ; scène de K.O. d'après ses planches ; cinématiques bien plus travaillées ;
utiliser les personnages Roblox. **Toujours rien de lancé dans Roblox Studio.**

### Les 3 ultimes

| # | Entrée | Coût | Règle |
|---|---|---|---|
| 1 | R seul | 2 barres | KAIEN RUSH (inchangé) |
| 2 | route complète **propre**, 6e = clic droit | 3 barres | ÉVEIL ÉCARLATE : −95 % de la vie actuelle ; < 50 % de la vie max : FINAL FINISH |
| 3 | route complète **propre**, 6e = touche R | 3 barres | 開天 PORTE DES CIEUX : −50 % de la vie max (sans réduction de combo, peut tuer) ; R pile au sommet (±4 ticks) : +10 % |

**Route propre** (`chainClean`) : chaque appui doit arriver quand rien n'attend dans la file
et, en plein combo, quand le coup en cours a déjà sorti toutes ses touches. Tout appui
« sale » (spam, anticipation) verrouille les ultimes 2 et 3 pour ce combo. La route jouée
(`chainKeys`) doit correspondre aux 5 premiers maillons d'une route complète.

**QTE d'ÉVEIL** : 4 appuis en rythme pendant la rafale (les 4 premières touches de la route
jouée), fenêtre ±7 ticks ; trop tôt, mauvaise touche ou raté = échec. Tout réussi =
PARFAIT et +1 barre ; sinon GRAND / BON. Le CPU les réussit selon son niveau.

### Cinématiques (client)

- Plans décrits par des points liés aux **parties du rig** (tête, main, pieds, torse),
  résolus après placement : le cadrage marche sur KAI comme sur n'importe quel avatar.
  Coupes franches entre plans, léger travelling avant, **flou de profondeur** sur le sujet.
- **ÉVEIL** : yeux + kanji, aura en contre-plongée, dash, un angle par coup, puis **finale
  selon la route** : TORNADE (montée en spirale dans des anneaux de ki), RAFALE (barrage de
  poings), DRAGON (charge puis uppercut avec dragon de ki en spirale), FOUDRE (saut dans
  l'orage, plongeon sous les éclairs), MUR (talon qui envoie la cible dans le mur), LUNE
  (croissant géant puis hache depuis la lune) ; onde de choc, titre.
- **PORTE DES CIEUX** : sceau 開 en plongée, torii géant qui surgit, porte qui s'ouvre et
  aspire la cible pendant que KAI marche (vue de dos), monde écarlate, deux coups, gros plan
  sur le poing et gel noir et blanc (QTE R), coup unique, la porte vole en éclats.
- **Scène de K.O.** (FINAL FINISH et K.O. qui gagne le match) d'après les planches : chute au
  ralenti, MAIN AU SOL, SCÈNE 1 (vaincu au premier plan, gagnant debout, angle très bas),
  DÉTAIL PIEDS, ZOOM VISAGE, SCÈNE 2 (bras croisés, légère contre-plongée), DOS DU GAGNANT,
  PLAN LARGE ARÈNE, FONDU NOIR + K.O. Les rigs peuvent être orientés librement et placés en
  profondeur pour composer ces plans.

### Personnages Roblox

Avatar R15 du joueur par défaut ; le CPU / mannequin est un **clone d'ombre** de l'avatar
adverse (corps sombre, contour et voile de la couleur d'énergie). Sans avatar chargeable
(joueurs de test Studio) : R15 Roblox par défaut aux couleurs NUIT. Le bouton APPARENCE
revient à KAI.

### Arène

Bannières rouges à kanji (闘 魂 開 炎), piliers en ruine et gravats en fond, pour les plans
larges.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 64 tests (dont ÉVEIL et PORTE mérités sur chaque route, spam qui verrouille, QTE PARFAIT / spam = BON, bonus et K.O. de la PORTE, R seul = KAIEN RUSH) | ✅ |
| `luau tests/FighterAI.test.luau` : 9 tests (dont LÉGENDE mérite un ultime et réussit le rythme) | ✅ |
| Studio : cinématiques, cadrages, avatars, clone d'ombre | ❌ non exécuté |

## Version 0.5.0 — 1er octobre 2026

Demandes de Wilhem : routes de 6 appuis au lieu de 4 ; enchaîner les 2 derniers coups avec
3 barres déclenche une attaque unique en cinématique qui retire 95 % de la vie ; sous 50 %
c'est un « final finish » avec pose de K.O. au sol et plusieurs points de vue ; travailler
les modèles et les cinématiques. **Toujours rien de lancé dans Roblox Studio.**

Interprétation retenue (à confirmer) : 95 % de la vie **actuelle** de la cible, quel que soit
son total ; sous 50 % de la vie **maximale**, FINAL FINISH (K.O. garanti).

### Nouveautés

- **6 routes complètes de 6 appuis** (`MoveData.FullRoutes`) : TORNADE (L R L R L R),
  RAFALE (R L R L L R), DRAGON (L L R R L R), FOUDRE (R R L R L R), MUR (L L L R L R),
  LUNE (L L L L R R). Les deux derniers maillons : POURSUITE ÉCARLATE (L, bond à tête
  chercheuse qui vise la hauteur et la position de la cible) puis COUP DE GRÂCE (R).
  Dégâts mesurés : 311 à 407, et la route remplit ~la moitié de la jauge.
- **ÉVEIL ÉCARLATE** (champ `awakens` de COUP DE GRÂCE) : avec 300 de ki au moment du 6e
  coup, il le remplace (3 barres consommées, super flash, invincible 1-14). Cinématique
  autoritaire de 220 ticks : 7 coups puis le coup final ; dégâts totaux = 95 % de la vie au
  début de la cinématique (la cible reste à ~5 %), sans réduction de combo.
- **FINAL FINISH** : si la cible a moins de 50 % de sa vie maximale, la cinématique dure
  110 ticks de plus et se termine par un K.O. Le round ne se termine qu'après.
- **Cinématique ÉVEIL ÉCARLATE** (client) : gros plan sur les yeux avec le kanji peint,
  contre-plongée pendant l'éruption d'aura sous un ciel écarlate, travelling du dash, un
  angle de caméra différent à chaque coup (épaule, face, plongée, contre-plongée inclinée,
  trois-quarts), bond dans le ciel vu du sol, plongeon, onde de choc et instant noir et
  blanc. FINAL FINISH : chute au ralenti en noir et blanc, plan au ras du sol à l'impact,
  plongée sur le corps face contre terre, puis KAI bras croisés dos à l'adversaire tombé ;
  titres « FINAL FINISH » et « K.O. ».
- **Modèle de KAI** : cou, oreilles, nez, mâchoire, yeux avec paupières encrées, pupilles et
  reflets ; frange et 6 mèches de couronne ; débardeur à encolure, lignes de pectoraux et
  d'abdos ; gilet à col montant doublé de rouge, ourlet évasé, **kanji 開 dans le dos** ;
  deltoïdes et biceps arrondis ; bandages à bandes ; pantalon large avec plis et revers ;
  baskets avec embout, bande, talon et lacets ; ceinture épaisse à gros nœud.
- **IA** : DIFFICILE et LÉGENDE jouent aussi les routes de 6 appuis (donc l'ÉVEIL quand
  leur jauge est pleine).
- Mécaniques ajoutées : `homing` (bond vers la cible) et `track` (suivi horizontal des coups
  multi-touches) pour que les routes tiennent quelle que soit la trajectoire de la cible.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 48 tests (dont les 6 routes complètes jouées comme un joueur, ÉVEIL = −95 % exact, FINAL FINISH = K.O. après la cinématique, pas d'ÉVEIL sans 3 barres) | ✅ |
| `luau tests/FighterAI.test.luau` : 8 tests | ✅ |
| Compilation + analyse Luau | ✅ |
| Studio : modèle, cinématiques, angles de caméra | ❌ non exécuté — angles et poses estimés sans rendu |

## Version 0.4.0 — 1er octobre 2026

Demandes de Wilhem : plus de diversité, skills spéciaux en alternant clic gauche / clic
droit, meilleures animations, possibilité d'utiliser les rigs Roblox, et correction « quand
j'active l'IA, je tape tout seul ». **Toujours rien de lancé dans Roblox Studio.**

### Nouveautés

- **Skills par alternance** (★, nom annoncé à l'écran) : L R L R → TORNADE DU DRAGON
  (4 touches, lance) ; R L R L → RAFALE DE KI (7 coups, rebond mur) ; L L R R et
  R R L R → POING DU DRAGON (triple uppercut) ; L L L L R → CROISSANT DE LUNE (saltos, rebond
  au sol). Nouveaux maillons : PAUME DE KI (L R L), VENT ASCENDANT (R L R), TALON FOUDRE
  (R R L). Dégâts mesurés : 245 à 303 contre 202 pour la chaîne simple.
- **Coups multi-touches** (`hits`, `hitInterval`) : lancement / rebonds seulement sur la
  dernière touche ; un coup multi-touches ne s'annule qu'une fois toutes ses touches sorties ;
  le jonglage compte les coups, pas les touches.
- **KIKOHO** (S + E) : boule de ki, une à la fois, détection balayée (pas de traversée entre
  deux ticks), blocable, annulée par une boule adverse (clash).
- **File d'appuis** : seul le prochain appui vieillit, et pas pendant le démarrage / l'actif
  du coup en cours — taper L R L R d'avance donne exactement la route.
- **IA** : sous pression, le CPU restait en garde après chaque coup reçu ou bloqué (jusqu'à
  90 %) et ne contre-attaquait presque jamais, surtout en FACILE (premier mode CPU de la
  touche M). Maintenant : punition une fois par coup adverse en récupération,
  reversal invincible (E) et contre-attaque à la sortie d'étourdissement ou au réveil,
  boules de ki à distance, routes ★ en DIFFICILE / LÉGENDE, agressivité relevée. Mesure
  (4 min de pression continue d'un joueur qui ne fait qu'attaquer) : le CPU rend 74 à 81
  touches en FACILE, ~110 en NORMAL / DIFFICILE, ~200 en LÉGENDE.
- **Animations** : démarrage interpolé (par paliers) de la garde vers l'anticipation,
  impact net, retour progressif en garde ; deux poses alternées pour les coups multi-touches ;
  marche arrière ; deux réactions aux coups en alternance ; pose de kiai à l'intro ; poses
  pour tous les nouveaux coups.
- **Rigs Roblox** : bouton APPARENCE pour jouer avec son propre avatar R15
  (`Players:CreateHumanoidModelFromDescription`). Les 15 articulations R15 ont les mêmes noms
  que celles de KAI : les mêmes poses s'appliquent. Repli automatique sur KAI si l'avatar ne
  se charge pas (joueurs de test d'un serveur local Studio). Le R6 n'est pas utilisé : il
  n'a pas de coudes ni de genoux.

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` : 39 tests (dont les 5 skills, multi-touches, KIKOHO, clash, garde de la boule) | ✅ |
| `luau tests/FighterAI.test.luau` : 8 tests (dont « sous pression, chaque niveau rend des coups » et « zoning à distance ») | ✅ |
| Compilation + analyse Luau de tous les scripts | ✅ |
| Studio, avatar R15, rendu des poses et des effets | ❌ non exécuté |

### Problèmes ouverts

- Avatars R15 : accessoires très grands ou avatars Rthro à vérifier visuellement ; les
  hurtboxes restent celles de KAI (identiques pour tous).
- Le reste des problèmes ouverts de la 0.3.0 ci-dessous tient toujours.

## Version 0.3.0 — 1er octobre 2026

**Phase :** à la demande de Wilhem, au-dessus de la 0.2.0 : arbre de combos clic gauche /
clic droit, jauge de ki, compétence spéciale (E), ultime (R) avec cinématique, mannequin
CPU à 4 niveaux. **Rien n'a encore été lancé dans Roblox Studio** (ni la 0.2.0 ni la 0.3.0) :
un rapport de test est attendu avant la suite.

### Architecture réseau retenue

Prototype **classique** : `RemoteEvent` + simulation autoritaire côté serveur à 60 Hz
(boucle à pas fixe sur `Heartbeat`, rattrapage limité à 8 ticks). Le client envoie des
inputs validés et affiche des snapshots (30/s) avec une légère extrapolation. **Pas de
prédiction client ni de rollback** : le joueur ressent la latence réseau sur ses propres
actions. Input Action System et Server Authority n'ont pas été vérifiés (pas d'accès à
Studio) ; à réévaluer avant la phase 7. Le CPU tourne sur le serveur et envoie les mêmes
inputs qu'un joueur : il obéit aux mêmes règles.

### Fichiers

| Chemin Rojo | Instance dans Studio | Rôle |
|---|---|---|
| `src/shared/CombatConfig.luau` | ReplicatedStorage.Shared.CombatConfig | Valeurs globales (ticks, vitesses, garde, ki, rounds) |
| `src/shared/MoveData.luau` | …Shared.MoveData | Frame data, routes de combo, script de la cinématique |
| `src/shared/CombatSimulation.luau` | …Shared.CombatSimulation | Simulation pure : mouvement, coups, garde, combos, ki, ultime, rounds |
| `src/shared/FighterAI.luau` | …Shared.FighterAI | CPU pur (4 niveaux), produit des inputs |
| `src/shared/CharacterData.luau` | …Shared.CharacterData | KAI 開, skins CLASSIQUE (P1) et NUIT (P2) |
| `src/shared/InputConfig.luau` | …Shared.InputConfig | Bindings clavier/souris/manette |
| `src/server/init.server.luau` | ServerScriptService.Server | Slots, modes du mannequin, validation, boucle 60 Hz, snapshots, événements |
| `src/server/ArenaBuilder.luau` | Server.ArenaBuilder | Arène « Temple écarlate » + éclairage |
| `src/server/RigBuilder.luau` | Server.RigBuilder | Rig R15 en blocs de KAI (15 Motor6D) |
| `src/client/init.client.luau` | StarterPlayerScripts.Client | Affichage, interpolation, branchements |
| `src/client/InputController.luau` | Client.InputController | Adaptateur d'inputs (clavier, souris, manette, tactile) |
| `src/client/AnimationController.luau` | Client.AnimationController | Seul écrivain des Motor6D ; poses par paliers |
| `src/client/EffectsController.luau` | Client.EffectsController | VFX : étincelles, smears, bouclier, impact frames, afterimages, aura, debug hitbox |
| `src/client/CinematicController.luau` | Client.CinematicController | Cut-in du super flash, cinématique de l'ultime, retour caméra garanti |
| `src/client/CameraController.luau` | Client.CameraController | Caméra latérale, secousse, zoom d'impact |
| `src/client/HUDController.luau` | Client.HUDController | Vie, garde, ki, chrono, combos, annonces, panneau COMBOS |
| `tests/CombatSimulation.test.luau` | — | 30 tests de la simulation |
| `tests/FighterAI.test.luau` | — | 6 tests du CPU |
| `tests/TestKit.luau` | — | Aides de test |

### Conventions

- X = gauche/droite, Y = hauteur, Z verrouillé à 0. 1 tick = 1/60 s.
- Un coup dure `startup + active + recovery` ticks, la frame 1 étant le tick où il démarre.
  La hitbox existe pour `startup < frame ≤ startup + active` et ne touche qu'une fois.
- Le hitstop et le super flash gèlent les combattants (frames, stun) : aucune fenêtre
  n'avance pendant le gel.
- Les appuis sont mis en file (3 max, 12 ticks de vie, gelés pendant le hitstop) et joués
  dans l'ordre tapé.
- L'orientation est verrouillée pendant les attaques, stuns, dashs et sauts.
- Hurtbox, hitbox et pushbox sont séparées et purement logiques (pas de `Touched`).
- Le client ne décide jamais d'un coup, de la vie, du ki ni d'un KO. La cinématique est un
  script autoritaire (coups à des ticks fixes) ; le client ne fait que la mettre en scène.

### Gameplay

**Combos** (L = clic gauche, R = clic droit) — un coup s'enchaîne si le précédent a touché
ou a été bloqué :

| Touches | Route | Effet |
|---|---|---|
| L L L L | JAB > CROSS > COUDE > KICK | chute |
| L L R | JAB > CROSS > LANCEUR | lance ; Espace = super saut, puis L L R aérien (KICK AÉRIEN > DOUBLE KICK > MÉTÉORE) |
| L R | JAB > COUP AU FOIE | effondrement (52 ticks) pour relancer un combo |
| L L L R | JAB > CROSS > COUDE > TALON TOURNOYANT | rebond au mur |
| R R | FRAPPE LOURDE > HACHE CÉLESTE | overhead, rebond au sol |
| R L | FRAPPE LOURDE > BALAYAGE | coup bas, chute |
| ↓L / ↓R | KICK BAS / LANCEUR | KICK BAS > CROSS > … |
| tout normal > E | RISING STRIKE | spéciale invincible (frames 1-10), lance |
| tout coup > R | KAIEN RUSH | ultime, 2 barres |

Règles anti-boucle : réduction ×0,9 par coup déjà pris (min ×0,4 ; ×0,5 pour l'ultime),
6 coups aériens maximum, un seul effondrement / rebond sol / rebond mur par combo.

**Ki** : 3 barres (300). Gain : 50 % des dégâts infligés, 30 % des dégâts reçus, 25 % / 20 %
sur garde. Conservé entre les rounds, remis à 0 à chaque nouveau match. Plein en
entraînement après chaque combo.

**Ultime KAIEN RUSH** (touche R, 2 barres) : super flash de 40 ticks (cut-in), ruée
invincible ; si ça touche : cinématique de 150 ticks, 11 coups + coup final (dégâts réduits
×0,5 au minimum), adversaire projeté. Le chrono est en pause et le round ne peut se finir
qu'après la cinématique. Bloqué ou raté : pas de cinématique, longue récupération.

**Garde (F)** : 15 % des dégâts (jamais de KO en garde), jauge de garde, GUARD BREAK à 0.
Garde basse (F + S) contre les coups bas, debout contre les overheads.

**Mannequin** (touche M ou bouton) : IMMOBILE → GARDE → CPU FACILE → NORMAL → DIFFICILE →
LÉGENDE. Les modes CPU jouent en règles versus (rounds, chrono). Le CPU perçoit avec un
délai (24 / 16 / 10 / 6 ticks), garde par réaction et par anticipation, contre les sauts
avec la spéciale, punit les coups ratés, choisit des routes de combo selon son niveau et
utilise l'ultime (NORMAL et au-dessus).

Résultats hors ligne CPU contre CPU (3 matchs de 4 min par duel) : LÉGENDE bat FACILE 15-0,
NORMAL 13-0, DIFFICILE 7-1 ; DIFFICILE bat NORMAL 11-0 ; NORMAL bat FACILE 11-0.

| Coup | Startup | Actif | Récup. | Dégâts | Hitstun | Garde | Propriétés |
|---|---|---|---|---|---|---|---|
| JAB | 5 | 3 | 9 | 45 | 17 | Mid | |
| CROSS | 6 | 3 | 11 | 55 | 19 | Mid | |
| COUDE | 6 | 3 | 13 | 60 | 21 | Mid | |
| KICK | 8 | 4 | 18 | 80 | 24 | Mid | lance (chute) |
| COUP AU FOIE | 9 | 3 | 16 | 70 | 22 | Mid | effondrement |
| LANCEUR | 8 | 4 | 22 | 70 | 26 | Mid | lance, saut-cancel |
| TALON TOURNOYANT | 10 | 3 | 22 | 95 | 26 | Mid | lance, rebond mur |
| FRAPPE LOURDE | 13 | 4 | 22 | 110 | 26 | Mid | grosse usure de garde |
| HACHE CÉLESTE | 12 | 4 | 20 | 90 | 28 | High | rebond sol |
| BALAYAGE | 9 | 4 | 20 | 60 | 22 | Low | chute |
| KICK BAS | 5 | 3 | 10 | 35 | 16 | Low | |
| KICK AÉRIEN | 6 | 6 | 10 | 55 | 20 | High | |
| DOUBLE KICK | 6 | 4 | 12 | 55 | 20 | High | |
| MÉTÉORE | 9 | 5 | 14 | 80 | 24 | High | smash vers le sol, rebond |
| RISING STRIKE | 9 | 5 | 26 | 100 | 30 | Mid | lance, saut-cancel, invincible 1-10 |
| KAIEN RUSH | 8 | 10 | 36 | 30 (+ cinématique) | 40 | Mid | invincible 1-12, 2 barres |

Vie : 1000. Route la plus forte mesurée : L L L E puis R ≈ 480 dégâts (2 barres). Toutes
ces valeurs sont des points de départ à régler en jeu.

### Direction artistique appliquée

Planches « KAI 開 » et roster de Wilhem : noir / blanc / rouge, gilet sans manches ouvert,
débardeur blanc, ceinture rouge, bandages, pantalon large, cheveux noirs en pointes à
mèches rouges. P2 = skin NUIT (bleu). Contour encre via `Highlight`. Poses par paliers
(12/15/24/s ou fluide). Étincelles manga, smears par coup lourd, bouclier bleu/violet,
impact frames noir/blanc/rouge, afterimages (dash et téléportations de l'ultime), aura de
ki, cut-in diagonal du super, bandes cinéma, plans de caméra coupés « à l'anime ».
Bouton EFFETS : réduit flashs et secousses (réduit par défaut sur mobile).

### Tests

| Test | État |
|---|---|
| `luau tests/CombatSimulation.test.luau` (30 tests : chaque route de combo, file d'appuis, garde haute/basse, ki, ultime et cinématique, rebonds, effondrement, saut-cancel, invincibilité, rounds, KO, timeout, double KO…) | ✅ passés |
| `luau tests/FighterAI.test.luau` (6 tests : chaque niveau inflige des dégâts, matchs complets sans erreur, hiérarchie des niveaux, garde, routes et ultime, déterminisme) | ✅ passés |
| Compilation + analyse Luau de tous les scripts | ✅ |
| Jeu dans Studio (solo, CPU, 2 clients, manette, tactile, téléphone) | ❌ non exécuté |
| Rendu visuel (rig, poses, cinématique, cut-in, HUD) | ❌ non vérifié, valeurs à ajuster |

### Problèmes ouverts / risques

- Aucune prédiction client : délai entrée → action égal au ping + jusqu'à 33 ms.
- Poses, angles caméra de la cinématique et ornements estimés sans rendu : à retoucher.
- Pas de sons (aucun ID d'asset inventé) : prévoir des SFX fournis par Wilhem.
- `UserInputService.PreferredInput` (texte d'aide) à confirmer dans le Studio utilisé.
- Sur mobile, la rangée de boutons du HUD peut déborder sur petit écran.

### Prochaine étape proposée

1. Wilhem teste dans Studio (entraînement, chaque niveau CPU, puis 2 clients) et renvoie le
   rapport : Output complet, captures, courte vidéo de la cinématique.
2. Corrections de poses / ressenti / équilibrage, puis SFX.
3. Ensuite, d'après le roster : sélection de personnage (RYUEN, ZEPHYR, KARA, DAIGO, SORA,
   AKEMI, TARO) et environnements (ville néon, cascade, torii de nuit).
