# BREAKFRAMEZ — Boutique et monétisation (guide pour Wilhem)

Tout est prêt dans le code, mais **aucun achat en Robux n'est possible tant que tu n'as pas créé
les Game Pass et les Developer Products sur Roblox et collé leurs IDs**. Aucun ID n'a été inventé :
chaque `id = 0` du fichier de configuration est un emplacement à remplir. Tant qu'un ID vaut 0,
l'article affiche « BIENTÔT » et le serveur refuse de lancer son achat.

## 1. Ce qui existe dans le jeu

### Page BOUTIQUE (menu de gauche, « SHOP »)

Quatre onglets : **À LA UNE**, **COSMÉTIQUES**, **BOUTIQUE**, **GAME PASS**.

- À gauche, l'article choisi en grand :
  - un style en 3D (à faire tourner) ;
  - la plaque du titre ;
  - la bulle de l'emote ;
  - les couleurs animées de l'aura ;
  - les avantages d'un pass.
- Dessous : son état et ses boutons :
  - ACHETER (pièces, avec confirmation) ;
  - R$ (fenêtre d'achat de Roblox) ;
  - ÉQUIPER / RETIRER.
- À droite, la grille des articles :
  - prix ;
  - statut : POSSÉDÉ, ÉQUIPÉ, verrouillé, BIENTÔT ;
  - badges POPULAIRE / MEILLEURE OFFRE.
- Notification (cloche) après chaque achat.
- Le solde de pièces et le multiplicateur de pièces actif sont affichés en haut.
- PC, mobile (la page suit la largeur de l'écran) et manette (chaque carte et bouton se sélectionne).

### Game Pass (permanents)

| Pass | Prix proposé | Avantages |
|---|---|---|
| **VIP** | 299 R$ | Badge [VIP] dans le lobby, pseudo doré, aura VIP GOLD (cosmétique), +25 % de pièces des combats |
| **DOUBLE REWARDS** | 199 R$ | ×2 pièces des combats, jamais sur les achats en Robux |
| **SUPPORTER** | 99 R$ | Badge [SUPPORTER], titre SUPPORTER, emote exclusive « RESPECT 🤝 » |

**Règle de cumul.**
- Les bonus s'additionnent sur la récompense de base, avec un plafond de **×2,25** : VIP + DOUBLE = 1 + 0,25 + 1.
- Ils ne s'appliquent qu'aux **pièces des combats** : en ligne, survie, défis.
- Ils ne s'appliquent jamais :
  - aux packs de pièces ;
  - aux quêtes ;
  - à l'Elo ;
  - aux points de la semaine ;
  - au combat lui-même.

**Aucun pass ne donne d'avantage compétitif.**
- Le test « store » vérifie qu'un pass ne contient que des champs cosmétiques ou de pièces.

**Vérification.**
- Les pass sont vérifiés par le serveur à chaque connexion (`UserOwnsGamePassAsync`), donc restaurés automatiquement.
- Ils sont aussi donnés tout de suite après un achat en jeu (`PromptGamePassPurchaseFinished`).
- Si Roblox ne répond pas, le dernier état confirmé (gardé dans le profil) reste.

### Developer Products

- Packs de pièces : 1 000 (99 R$), 3 000 (249 R$), 7 500 (499 R$), prix proposés.
- Les 8 styles GOLD (KAI, AKEMI, SHIN, RAIJIN, VENOM, HIBIKI, KUREN, NOVA) à 149 R$. Ils restent aussi achetables en pièces.

### Cosmétiques (en pièces)

- **Skins** : les 40 styles de la boutique. Ceux de quête restent gagnés par les quêtes.
- **Titres** : INTOUCHABLE, ARTISTE DU COMBO, AU FRAME PRÈS, SANS PITIÉ, BOSS FINAL, BRISEUR. SUPPORTER s'obtient avec le pass.
- **Emotes** : 4 provocs pour la roue, plus RESPECT avec SUPPORTER.
- **Auras** : 5 couleurs (Givre, Braise, Ombre, Sakura, Néant), plus VIP GOLD avec VIP.
  - Elles recolorent les particules d'aura du perso en combat.
  - Tout le monde les voit.
  - Purement visuel.
- **Animations de victoire** : 3 emplacements « BIENTÔT ».
  - Elles ne sont pas faites, donc ni vendues ni équipables.
  - Les remplacer par de vraies animations quand elles existeront.

Pas de loot box. Le code refuserait d'ailleurs un article payant aléatoire (`random = true`) aux joueurs dont la politique Roblox l'interdit (PolicyService).

## 2. Sécurité (ce que fait le serveur)

- Le client ne fait que demander ; le serveur vérifie tout (prix, possession, ID) et lance lui-même la fenêtre d'achat Roblox.
- **Un seul `ProcessReceipt`** pour tous les produits. Chaque reçu (PurchaseId) est écrit dans le profil, dans la même sauvegarde que ce qu'il donne.
- Le serveur ne répond « accordé » (`PurchaseGranted`) **qu'une fois le profil écrit**. Sinon il répond `NotProcessedYet`, et Roblox redemande plus tard.
- Un reçu déjà vu n'est jamais redonné : nouvel essai de Roblox, autre serveur, reconnexion.
- Une déconnexion pendant l'achat ne perd rien et ne donne rien deux fois.
- Aucun achat sur un profil pas encore chargé.
- Les 200 derniers reçus sont gardés par profil.
- Paquets falsifiés : l'anti-triche compte la suspicion comme pour le reste du menu.

## 3. Ce que tu dois faire sur Roblox (Creator Dashboard)

1. Publier le jeu (Fichier › Publier sur Roblox) s'il ne l'est pas.
2. Aller sur **create.roblox.com › Créations › ton expérience › Monétisation**.
3. **Passes** › *Créer un pass*, une fois par pass :
   - pour VIP, DOUBLE REWARDS et SUPPORTER : nom, image (une image de toi, pas inventée par moi), description ;
   - puis *Ventes* › activer « En vente » et mettre le prix (299 / 199 / 99, ou ce que tu veux) ;
   - l'ID du pass est dans l'URL de sa page, ou via le menu « … › Copier l'ID de l'élément ».
4. **Developer Products** › *Créer un Developer Product*, une fois par produit :
   - les 3 packs de pièces, puis les 8 styles GOLD si tu veux les vendre en Robux ;
   - pour chacun : nom, prix ;
   - puis copier l'ID.
5. Ouvrir `src/shared/StoreConfig.luau` et remplacer chaque `id = 0` par le vrai numéro (sans guillemets).
   - Exemple : `key = "VIP", id = 123456789, robux = 299`.
   - Mettre `robux =` égal au prix réel : c'est seulement le prix affiché dans le menu.
   - Un article que tu ne veux pas vendre en Robux : laisse `id = 0`, il reste « BIENTÔT ».
6. Synchroniser avec Rojo, puis republier.
7. **Paramètres de l'expérience › Sécurité** : activer « Activer l'accès de Studio aux services API ». Sinon les sauvegardes, et donc les achats, ne marchent pas dans Studio.

## 4. Tester avant le lancement

**Tests automatiques (faits par moi, hors Roblox)** : `luau tests/Lobby.test.luau`. Ils couvrent :
- cumul et plafond des bonus, pas de bonus sur les packs ;
- reçus rejoués 5 fois ;
- profil rechargé (reconnexion, autre serveur) ;
- sauvegarde échouée puis nouvel essai ;
- reçu inconnu ou vide ;
- registre limité ;
- achat de cosmétique sans assez de pièces, en double, article BIENTÔT ou réservé à un pass ;
- équiper un article non possédé, retirer ;
- aura VIP perdue avec le pass ;
- profil falsifié ;
- emote du pass liée au pass ;
- textes en français ;
- configuration cohérente : pas d'ID en double, prix présents, styles existants, pas d'article aléatoire.

**Tests à faire par toi dans Roblox Studio.** Je ne peux pas les faire : Roblox seul traite les vrais achats.

1. Avec les vrais IDs collés, lance *Play* dans Studio.
   - Les achats y sont des **achats de test** : la fenêtre dit « test purchase », aucun Robux n'est débité.
   - Le serveur écrit dans l'Output `[FightingGame] <nom> bought <produit> (<id du reçu>)`.
2. Achète un pack de pièces : le solde monte une fois, une notification apparaît.
3. Achète VIP : badge [VIP], pseudo doré dans le lobby (H), aura VIP GOLD dans COSMÉTIQUES › AURAS, « PIÈCES DE COMBAT x1.25 » en haut de la boutique.
4. Quitte et relance *Play* : pièces, pass, cosmétiques et équipements sont toujours là.
5. Achète un titre, une emote et une aura en pièces, équipe-les, puis retire-les.
6. Teste sur téléphone avec l'émulateur de Studio (Test › Appareil), puis à la manette.
7. Dans le jeu publié, avec un compte de test : un vrai achat d'un petit produit, puis vérifier qu'il reste après reconnexion.
   - Ce sont de vrais Robux : teste avec le produit le moins cher.

**Limite connue** : dans Studio sans l'accès API, les sauvegardes échouent, donc le serveur refuse les achats (« ta sauvegarde n'est pas encore chargée »). C'est voulu : ne jamais prendre de Robux sans pouvoir sauvegarder.

## 5. Ajouter un article plus tard

Tout se fait dans `src/shared/StoreConfig.luau` :

- **Game Pass** : une entrée dans `PASSES`.
  - Une `key` stable : ne jamais la changer une fois vendue.
  - `coinBonus` pour un bonus de pièces, `badge`, `title`, `taunt` pour les cosmétiques.
- **Produit** : une entrée dans `PRODUCTS`, avec `coins` ou `style`.
- **Cosmétique** :
  - une entrée dans `ITEMS` (kind TITLE / EMOTE / VFX / VICTORY) ;
  - pour une emote, ajouter aussi sa provoc dans `Taunts.LIST` avec `unlock = { item = "<id>" }` ;
  - ajouter son nom en français dans `Locale.luau`.
- Relancer `luau tests/Lobby.test.luau`.
