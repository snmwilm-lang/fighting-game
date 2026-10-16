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
