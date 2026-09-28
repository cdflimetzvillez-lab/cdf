# Le Père Noël te répond — installation

Fichiers à copier à la racine du repo (mêmes chemins). Fichiers modifiés :
src/components/MenuButton.tsx, src/components/NavAdmin.tsx, src/app/page.tsx,
src/app/evenements/[slug]/page.tsx, src/app/api/sumup/webhook/route.ts, .env.example.
Tout le reste est nouveau.

1. Supabase : exécuter supabase/pere_noel.sql dans l'éditeur SQL (tables pn_reglages, pn_commandes, vue pn_stats).
   Les médias utilisent le bucket public « medias » existant, dossier pere-noel/.
2. Vercel, variables d'environnement :
   ANTHROPIC_API_KEY, ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID (MDLAMJ0jxkpYkjXbmG4t),
   HEYGEN_API_KEY, CRON_SECRET (chaîne aléatoire). Redéployer.
3. Admin → 🎅 Père Noël vidéo → Réglages : charger l'image du Père Noël (portrait 9:16), vérifier la voix, enregistrer.
   Laisser « génération manuelle » et « relecture du script » cochés pour les premiers tests.
4. Admin → « + Commande de test » : le formulaire s'ouvre en mode test (sans paiement).
   Ouvrir la commande → Générer → relire le script → Valider → attendre 3 à 8 min → Vérifier.
   Sans crédits HeyGen, tout s'arrête proprement à l'étape vidéo avec le message d'erreur HeyGen.
5. Quand c'est bon : Réglages → « Commandes ouvertes » + activer le module (bouton en haut du tableau de bord).

Cron : vercel.json appelle /api/pere-noel/cron toutes les heures (sur le plan Hobby, Vercel le limite à une fois par jour).
En pratique les vidéos sont vérifiées à chaque ouverture de l'admin (toutes les 60 s tant que la page est ouverte)
et quand une famille ouvre son espace, donc le cron n'est qu'un filet de sécurité.
