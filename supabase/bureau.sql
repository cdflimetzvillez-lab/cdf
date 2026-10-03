-- =====================================================================
-- CDF Limetz-Villez : accès du bureau (postes et modules)
-- Fichier : supabase/bureau.sql
-- À exécuter dans l'éditeur SQL du projet Supabase du CDF (pas WayPilot).
-- Script relançable : il ne supprime aucune donnée.
-- =====================================================================

-- 0. Garde-fou : est-on dans le bon projet ?
do $$
begin
  if to_regclass('public.admins') is null
     or to_regprocedure('public.is_admin()') is null
     or to_regprocedure('public.is_staff()') is null
     or to_regclass('public.reservations') is null then
    raise exception 'Mauvais projet Supabase : admins, is_admin(), is_staff() ou reservations introuvable. Ouvre le projet du CDF.';
  end if;
end $$;


-- 1. Postes du bureau et modules accordés à chacun
create table if not exists public.bureau_postes (
  cle         text primary key check (cle ~ '^[a-z0-9-]{2,40}$'),
  libelle     text not null,
  modules     text[] not null default '{}',
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

insert into public.bureau_postes (cle, libelle, position, modules) values
  ('president', 'Président', 1,
    array['tableau','evenements','reservations','demandes','tresorerie','compta','tresors','pere-noel','roue','theme','partenaires','association','parametres','maintenance']),
  ('vice-president', 'Vice-président', 2,
    array['tableau','evenements','reservations','demandes','tresorerie','compta','tresors','pere-noel','roue','theme','partenaires','association']),
  ('tresorier', 'Trésorier', 3, array['tableau','tresorerie','compta']),
  ('tresorier-adjoint', 'Trésorier adjoint', 4, array['tableau','tresorerie','compta']),
  ('secretaire', 'Secrétaire', 5, array['tableau','evenements','reservations','demandes','association','partenaires']),
  ('secretaire-adjoint', 'Secrétaire adjoint', 6, array['tableau','evenements','demandes']),
  ('membre', 'Membre du bureau', 7, array['tableau'])
on conflict (cle) do nothing;


-- 2. Membres : poste et état du compte
alter table public.admins add column if not exists role text;
alter table public.admins add column if not exists poste text references public.bureau_postes(cle) on delete set null;
alter table public.admins add column if not exists actif boolean not null default true;

-- Le rôle accepte désormais « membre » (accès selon le poste), en plus de admin et tresorier.
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.admins'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%role%'
  loop
    execute format('alter table public.admins drop constraint %I', c.conname);
  end loop;
  alter table public.admins
    add constraint admins_role_check check (role in ('admin', 'tresorier', 'membre'));
end $$;

-- Les trésorières existantes prennent le poste Trésorier (mêmes accès qu'avant, plus le tableau de bord).
update public.admins set poste = 'tresorier' where role = 'tresorier' and poste is null;


-- 3. Fonctions de droits
-- Administrateur : accès complet. Un compte désactivé ne l'est plus.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admins a
    where a.id = auth.uid() and a.actif and coalesce(a.role, 'admin') = 'admin'
  );
$$;

-- Finances : administrateur, ou membre dont le poste donne la trésorerie ou la comptabilité.
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.admins a
    left join public.bureau_postes p on p.cle = a.poste
    where a.id = auth.uid() and a.actif
      and (coalesce(a.role, 'admin') = 'admin'
           or (a.role = 'tresorier' and a.poste is null)
           or coalesce(p.modules, '{}') && array['tresorerie', 'compta'])
  );
$$;

-- Membre du bureau : tout compte actif déclaré dans admins.
create or replace function public.est_membre_bureau()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where a.id = auth.uid() and a.actif);
$$;


-- 4. Règles d'accès
alter table public.bureau_postes enable row level security;
grant select, insert, update, delete on public.bureau_postes to authenticated, service_role;

drop policy if exists bureau_postes_lecture on public.bureau_postes;
create policy bureau_postes_lecture on public.bureau_postes for select to authenticated
  using ((select public.est_membre_bureau()));
drop policy if exists bureau_postes_ecriture on public.bureau_postes;
create policy bureau_postes_ecriture on public.bureau_postes for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Chaque membre peut lire sa propre fiche (nécessaire à la connexion).
drop policy if exists admins_lit_sa_fiche on public.admins;
create policy admins_lit_sa_fiche on public.admins for select to authenticated
  using (id = auth.uid());

-- Images et documents du site : dépôt ouvert aux membres du bureau, plus seulement aux administrateurs.
drop policy if exists bureau_depose_medias on storage.objects;
create policy bureau_depose_medias on storage.objects for insert to authenticated
  with check (bucket_id = 'medias' and (select public.est_membre_bureau()));
drop policy if exists bureau_retire_medias on storage.objects;
create policy bureau_retire_medias on storage.objects for delete to authenticated
  using (bucket_id = 'medias' and (select public.est_membre_bureau()));

-- Recharge le schéma côté API.
notify pgrst, 'reload schema';
