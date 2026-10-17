# Décisions de production

Tenu par l'agent `production` (`.claude/agents/production.md`).

Une ligne par décision qui engage la suite :
- la date ;
- la décision ;
- pourquoi ;
- ce qui a été écarté ;
- qui l'a prise.

Les décisions de Wilhem priment : on ne les défait jamais sans lui demander.

| Date | Décision | Pourquoi | Écarté | Qui |
|---|---|---|---|---|
| 15/10/2026 | Un effet du pack VFX ne s'affiche que si tous ses assets ont un ID ; sinon l'effet du jeu reste | Le jeu ne casse jamais pendant l'import | Tout basculer d'un coup | Claude |
| 15/10/2026 | Le KIKOHO de KAI reste la boule faite d'après les dessins de Wilhem | Ses dessins (v0.34 à v0.35) | La boule du pack | Wilhem (dessins) |
| 15/10/2026 | Le Red Kamehameha ne coule qu'à l'intérieur du rayon KAIENHA, dont la silhouette reste celle du dessin | « change-le seulement si ça le mérite » | Des bandes plus larges que le rayon | Wilhem |
| 15/10/2026 | Le PERFECT, l'aura FATAL, le super flash et le K.O. gardent leurs effets du jeu | « jamais par-dessus le combat », aura Tekken validée, cinématiques | Ceux du pack | Wilhem |
| 15/10/2026 | La voix « K.O. » seulement sur le coup qui met K.O. | « le son qui dit KO doit venir que sur les KO » | Sur les explosions des cinématiques | Wilhem |
| 15/10/2026 | Les meshes du pack sont facultatifs : un mesh absent donne une pièce vide, et ses effets surtout faits de mesh gardent ceux du jeu | Les textures arrivent avant les meshes | Attendre les 14 meshes pour tout allumer | Claude |
| 16/10/2026 | Les planches d'impact de Wilhem (HITSPARK, IMPACT_BURST) sont au cœur de chaque coup, sous la signature du perso ; une signature qui en a déjà une garde la sienne | « pq t'as pas mis les sprites des impacts » : 16 persos sur 22 n'en montraient aucune | Remplacer les signatures des persos par l'impact commun | Wilhem (demande), Claude (forme) |
| 16/10/2026 | Une texture qui ne charge pas est laissée de côté, le pack reste allumé ; un perso ne repasse aux effets du jeu que s'il en perd beaucoup (plus de 20 %, au moins 3) | Un seul ID mal lu éteignait tout le pack pour tous les persos | Éteindre la famille au premier échec (v0.36.1) | Claude |
| 16/10/2026 | La routine et chaque livraison envoient la place à Wilhem, sans exception | « il doit push la place à chaque fois » | La place seulement quand c'est pratique | Wilhem |
| 17/10/2026 | Le FATAL FINISHER de NOVA s'appelle « FATAL ERROR » (ERREUR FATALE), pas « ZERO HOUR » | « ZERO » est déjà dans 4 noms (ZERO HORIZON de SHIN, ABSOLUTE ZERO de YUKINA, ZERO ABSOLU : ECLIPSE de KUROEN et TRUE ECLIPSE de KUROEN SHIN) : il reste à la famille de KUROEN. « FATAL ERROR » dit son identité (glitch, pixels, 終焉 PROGRAMMED EXTINCTION) et joue avec le COUP FATAL. Une ligne de `MoveData` et une de `Locale` pour le changer | « ZERO HOUR » (routine du 16/10, jamais arrivé dans le dépôt), TERMINAL VELOCITY, LAUNCH SEQUENCE | Claude (production) ; Wilhem peut le renommer |
| 17/10/2026 | La scène de NOVA : ses drones deviennent un rail de huit anneaux devant son gantelet, compte 3-2-1-0, un seul tir, la cible « bugue » puis s'effondre sur place | Ses quatre ultimes ont déjà les drones qui tirent de partout (R), le laser orbital (ÉVEIL), les missiles (PORTE), la mitrailleuse (FATAL) ; RAIJIN et RYUKEN envoient déjà la cible dans le mur, KAI a le rayon géant. Le compte reprend la légende sur le côté de l'écran (celle de RYUKEN), avec des chiffres seuls : rien à traduire | Un mécha (idée de la fiche VFX : il faudrait un mesh qui n'existe pas), le laser orbital, la cible projetée au mur | Claude (production) |
| 17/10/2026 | Tout FATAL FINISHER passe un test commun (Cinematography) : ses propres plans (6 au moins, pas de stroboscope), un nom unique qui n'est pas celui d'un coup d'un autre perso, le K.O. avec son nom après le coup, la cible à terre à la fin, des sons de la liste du `SoundController` présents dans `SoundPalette` | Les 18 premiers le respectaient sans test ; KUROEN et les bosses suivront la même règle | Un test par perso seulement | Claude (production) |
