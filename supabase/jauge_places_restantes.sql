-- =========================================================
-- Jauge : places restantes d'un événement
-- À exécuter dans Supabase > SQL Editor.
--
-- Règle (alignée sur l'admin) :
--   comptent   : payées (bénévoles inclus), saisies à la main en attente
--                d'encaissement, paiements en ligne en cours (< 30 min)
--   ne comptent pas : échouées, expirées, annulées, remboursées,
--                paiements en ligne abandonnés (> 30 min), exposants
-- =========================================================

drop function if exists public.places_restantes(uuid);

create or replace function public.places_restantes(evt_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    0,
    coalesce(e.places_max, 0)
    - coalesce((
        select sum(r.places)::integer
        from public.reservations r
        where r.evenement_id = e.id
          and not r.exposant
          and (
            r.statut = 'payee'
            or (r.statut = 'en_attente' and r.saisie_par is not null)
            or (r.statut = 'en_attente' and r.saisie_par is null
                and r.created_at > now() - interval '30 minutes')
          )
      ), 0)
  )
  from public.evenements e
  where e.id = evt_id;
$$;

revoke all on function public.places_restantes(uuid) from public;
grant execute on function public.places_restantes(uuid) to anon, authenticated, service_role;

-- Affichage des places restantes sur la carte de l'accueil (case à cocher dans l'admin)
alter table public.evenements
  add column if not exists afficher_places_restantes boolean not null default false;

-- Vérification : places restantes par événement avec billetterie
select e.titre, e.places_max, public.places_restantes(e.id) as restantes
from public.evenements e
where e.billetterie_active = true
order by e.date_debut;
