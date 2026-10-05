-- =========================================================
-- Trésors de Noël v2
--   1. Grand trésor à plusieurs lots : 3 cartes cadeaux multi-enseignes de 100 €,
--      3 clés gagnantes différentes tirées au sort.
--   2. (Aucune table à modifier pour la règle « au moins un adulte pour inscrire
--      des enfants » : elle est appliquée par l'application.)
-- À exécuter une fois dans Supabase > SQL Editor (projet du CDF). Rejouable sans risque.
-- =========================================================

-- Nombre de lots du grand trésor = nombre de clés tirées au sort.
alter table public.tdn_reglages add column if not exists grand_tresor_nombre integer not null default 1;
-- Clés gagnantes du tirage, dans l'ordre de sortie (tirage_cle_id reste la première, et sert de verrou).
alter table public.tdn_reglages add column if not exists tirage_cle_ids uuid[] not null default '{}';

-- Reprise d'un éventuel tirage déjà enregistré à l'ancien format (une seule clé).
update public.tdn_reglages
   set tirage_cle_ids = array[tirage_cle_id]::uuid[]
 where tirage_cle_id is not null and tirage_cle_ids = '{}';

-- Nouveau grand trésor : 3 cartes cadeaux multi-enseignes de 100 €.
update public.tdn_reglages
   set grand_tresor_nombre  = 3,
       grand_tresor_montant = '100 €',
       grand_tresor_texte   = '3 cartes cadeaux multi-enseignes'
 where id = 1;

-- Lot « grand trésor » : c'est lui qui s'affiche quand une clé gagnante est saisie à la révélation.
update public.tdn_lots
   set nom = 'Carte cadeau multi-enseignes de 100 €', valeur = '100 €', stock = 3
 where grand = true;

insert into public.tdn_lots (nom, valeur, stock, grand, position)
select 'Carte cadeau multi-enseignes de 100 €', '100 €', 3, true, 0
 where not exists (select 1 from public.tdn_lots where grand = true);

-- Contrôle facultatif : comptes ayant déjà des enfants inscrits sans aucun adulte
-- (inscriptions antérieures à la nouvelle règle). Décommenter pour lister.
-- select c.prenom, c.nom, c.email, count(*) as enfants, bool_or(p.paye) as au_moins_un_paye
--   from public.tdn_comptes c
--   join public.tdn_participants p on p.compte_id = c.id
--  group by c.id, c.prenom, c.nom, c.email
-- having bool_and(p.categorie = 'enfant');
