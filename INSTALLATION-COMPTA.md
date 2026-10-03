# Module comptabilité : installation

Nouveaux fichiers : supabase/comptabilite.sql, src/app/compta-actions.ts, src/lib/compta/, src/components/compta/,
src/app/admin/(protected)/compta/. Fichiers modifiés : src/app/admin/(protected)/layout.tsx, src/components/NavAdmin.tsx.

1. Supabase, projet du CDF : exécuter supabase/comptabilite.sql dans l'éditeur SQL.
   Le script s'arrête de lui-même s'il est lancé sur un autre projet et ne supprime aucune donnée.
2. Déployer le site.
3. Admin, menu Comptabilité. Le premier affichage importe les ventes déjà payées sur le site
   (billetterie, Trésors de Noël, Père Noël vidéo) depuis le 1er janvier 2026.
4. Soldes de départ : Saisie, « Saisie libre », journal AN, date du 1er janvier.
   Débit 512000 pour la banque, débit 530000 pour la caisse, crédit 110000 pour le total.
5. Frais de paiement : Ventes du site, colonne Réglages. Tant que le taux est à 0, aucun frais n'est écrit.
   Le taux ne s'applique qu'aux ventes importées après le réglage.
6. Trésorières : elles voient désormais Trésorerie (lecture seule) et Comptabilité (saisie comprise).
   Le plan comptable, les exercices et les réglages d'import restent réservés aux admins.

Fonctionnement : une écriture validée ne se supprime pas, elle s'annule par une écriture inverse
depuis la fiche de la pièce. Un exercice clôturé n'accepte plus d'écriture.
