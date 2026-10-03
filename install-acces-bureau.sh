#!/usr/bin/env bash
# Accès du bureau (postes et modules) et menu latéral par catégories.
# Script cumulatif : contient aussi les réservations manuelles, les exposants, la jauge et l'écart,
# la création d'événement depuis la saisie et le thème de l'accueil. Il donne le même résultat
# que tu aies lancé ou non les scripts précédents.
# À exécuter à la racine du projet :  bash install-acces-bureau.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d "src/app/admin/(protected)/compta" ]; then
  echo "Lance ce script à la racine du repo, après l'installation du module comptabilité."; exit 1
fi
echo "Installation : accès du bureau et menu par catégories…"
mkdir -p 'supabase'
cat > 'supabase/bureau.sql' <<'EOF_BUREAU_FICHIER'
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
EOF_BUREAU_FICHIER
echo "  ✓ supabase/bureau.sql"
mkdir -p 'supabase'
cat > 'supabase/comptabilite.sql' <<'EOF_BUREAU_FICHIER'
-- =====================================================================
-- CDF Limetz-Villez : module comptabilité
-- Fichier : supabase/comptabilite.sql
-- À exécuter dans l'éditeur SQL du projet Supabase du CDF (pas WayPilot).
-- Script relançable : il ne supprime aucune donnée et sert aussi de mise à jour.
-- Tous les montants sont en centimes, comme dans le reste du site.
-- =====================================================================

-- 0. Garde-fou : est-on dans le bon projet ?
do $$
begin
  if to_regprocedure('public.is_staff()') is null
     or to_regprocedure('public.is_admin()') is null
     or to_regclass('public.reservations') is null
     or to_regclass('public.pn_commandes') is null
     or to_regclass('public.tdn_commandes') is null then
    raise exception 'Mauvais projet Supabase : is_staff(), reservations, pn_commandes ou tdn_commandes introuvable. Ouvre le projet du CDF.';
  end if;
end $$;


-- Réservations saisies à la main dans l'admin : paiement en espèces ou par chèque.
-- mode_paiement vide = paiement en ligne (SumUp).
alter table public.reservations add column if not exists mode_paiement text;
alter table public.reservations add column if not exists paiement_ref text;
alter table public.reservations add column if not exists saisie_par text;
alter table public.reservations alter column email drop not null;
-- Réservation d'un exposant (stand), saisie par un admin.
alter table public.reservations add column if not exists exposant boolean not null default false;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'reservations_mode_paiement_check') then
    alter table public.reservations
      add constraint reservations_mode_paiement_check check (mode_paiement in ('especes', 'cheque'));
  end if;
end $$;


-- Suivi par événement. Une réservation saisie à la main compte dans la jauge dès la saisie ;
-- tant qu'elle n'est pas payée, son montant apparaît en écart à encaisser.
-- Les colonnes d'origine sont inchangées, trois colonnes sont ajoutées à la fin.
do $$
declare
  v_invoker boolean;
begin
  -- On conserve le réglage de sécurité actuel de la vue.
  select c.reloptions::text ~ 'security_invoker=(true|on)' into v_invoker
  from pg_class c where c.oid = to_regclass('public.suivi_billetterie');

  create or replace view public.suivi_billetterie as
  select e.id,
         e.titre,
         e.slug,
         e.date_debut,
         e.places_max,
         e.prix_centimes,
         coalesce(sum(r.places) filter (where r.statut = 'payee'), 0::bigint) as places_vendues,
         coalesce(sum(r.montant_centimes) filter (where r.statut = 'payee'), 0::bigint) as recette_centimes,
         count(r.id) filter (where r.statut = 'payee') as nb_reservations,
         count(r.id) filter (where r.statut = 'en_attente') as nb_en_attente,
         coalesce(sum(r.places) filter (where r.statut = 'en_attente' and r.saisie_par is not null), 0::bigint) as places_a_encaisser,
         coalesce(sum(r.montant_centimes) filter (where r.statut = 'en_attente' and r.saisie_par is not null), 0::bigint) as a_encaisser_centimes,
         count(r.id) filter (where r.exposant and r.statut in ('payee', 'en_attente')) as nb_exposants
  from public.evenements e
  left join public.reservations r on r.evenement_id = e.id
  where e.billetterie_active = true
     or exists (select 1 from public.reservations x where x.evenement_id = e.id and x.saisie_par is not null)
  group by e.id;

  if v_invoker then
    alter view public.suivi_billetterie set (security_invoker = true);
  end if;
end $$;
-- La vue ne sert qu'à l'admin : pas d'accès pour les visiteurs non connectés.
revoke all on public.suivi_billetterie from anon;
grant select on public.suivi_billetterie to authenticated, service_role;

-- Formules proposées aux exposants d'un événement (tailles d'emplacement, options).
create table if not exists public.formules_exposants (
  id             uuid primary key default gen_random_uuid(),
  evenement_id   uuid not null references public.evenements(id) on delete cascade,
  libelle        text not null,
  prix_centimes  integer not null check (prix_centimes >= 0),
  position       integer not null default 0,
  created_at     timestamptz not null default now()
);
alter table public.formules_exposants enable row level security;
grant select, insert, update, delete on public.formules_exposants to authenticated, service_role;
drop policy if exists formules_exposants_lecture on public.formules_exposants;
create policy formules_exposants_lecture on public.formules_exposants for select to authenticated
  using ((select public.is_staff()));
drop policy if exists formules_exposants_ecriture on public.formules_exposants;
create policy formules_exposants_ecriture on public.formules_exposants for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));


-- =====================================================================
-- 1. TABLES
-- =====================================================================

create table if not exists public.compta_exercices (
  id          uuid primary key default gen_random_uuid(),
  libelle     text not null unique,
  date_debut  date not null,
  date_fin    date not null,
  cloture     boolean not null default false,
  cloture_le  timestamptz,
  created_at  timestamptz not null default now(),
  check (date_fin > date_debut)
);

create table if not exists public.compta_comptes (
  numero    text primary key check (numero ~ '^[1-7][0-9]{5}$'),
  intitule  text not null,
  type      text not null check (type in ('bilan', 'tresorerie', 'charge', 'produit')),
  actif     boolean not null default true
);

create table if not exists public.compta_journaux (
  code               text primary key check (code ~ '^[A-Z]{2}$'),
  libelle            text not null,
  compte_tresorerie  text references public.compta_comptes(numero)
);

-- Codes événement (analytique). Peuvent être liés aux événements du site.
create table if not exists public.compta_evenements (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique,
  libelle            text not null,
  date_evenement     date,
  statut             text not null default 'en_cours' check (statut in ('a_venir', 'en_cours', 'termine')),
  site_evenement_id  uuid unique references public.evenements(id) on delete set null,
  site_event_id      uuid unique references public.events(id) on delete set null,
  created_at         timestamptz not null default now()
);

-- Budget prévisionnel : un montant par événement et par compte.
create table if not exists public.compta_budgets (
  id                   uuid primary key default gen_random_uuid(),
  compta_evenement_id  uuid not null references public.compta_evenements(id) on delete cascade,
  compte_numero        text not null references public.compta_comptes(numero),
  montant_centimes     integer not null check (montant_centimes >= 0),
  unique (compta_evenement_id, compte_numero)
);

create table if not exists public.compta_ecritures (
  id                  uuid primary key default gen_random_uuid(),
  exercice_id         uuid not null references public.compta_exercices(id),
  journal_code        text not null references public.compta_journaux(code),
  numero              integer not null,
  piece               text generated always as (journal_code || '-' || lpad(numero::text, 4, '0')) stored,
  date_piece          date not null,
  libelle             text not null,
  source              text not null default 'manuel' check (source in ('manuel', 'site', 'annulation')),
  source_table        text,
  source_id           uuid,
  source_statut       text,
  verifie_le          timestamptz,
  contrepassee_par    uuid references public.compta_ecritures(id),
  justificatif_chemin text,
  cree_par            uuid,
  cree_par_nom        text,
  created_at          timestamptz not null default now(),
  unique (exercice_id, journal_code, numero)
);

-- Une vente du site ne peut être importée qu'une seule fois.
create unique index if not exists compta_ecritures_source_uniq
  on public.compta_ecritures (source_table, source_id) where source_table is not null;
create index if not exists compta_ecritures_date_idx on public.compta_ecritures (date_piece);

create table if not exists public.compta_lignes (
  id                   uuid primary key default gen_random_uuid(),
  ecriture_id          uuid not null references public.compta_ecritures(id) on delete cascade,
  position             smallint not null,
  compte_numero        text not null references public.compta_comptes(numero),
  compta_evenement_id  uuid references public.compta_evenements(id),
  libelle              text,
  debit_centimes       integer not null default 0 check (debit_centimes >= 0),
  credit_centimes      integer not null default 0 check (credit_centimes >= 0),
  pointe_le            timestamptz,
  check ((debit_centimes > 0) <> (credit_centimes > 0))
);
create index if not exists compta_lignes_ecriture_idx on public.compta_lignes (ecriture_id);
create index if not exists compta_lignes_compte_idx on public.compta_lignes (compte_numero);
create index if not exists compta_lignes_evenement_idx on public.compta_lignes (compta_evenement_id);

-- Réglages de l'import des ventes du site, une ligne par table source.
create table if not exists public.compta_sources (
  cle                  text primary key,
  libelle              text not null,
  actif                boolean not null default true,
  journal_code         text not null references public.compta_journaux(code),
  compte_produit       text not null references public.compta_comptes(numero),
  compte_tresorerie    text not null references public.compta_comptes(numero),
  compte_frais         text not null references public.compta_comptes(numero),
  compta_evenement_id  uuid references public.compta_evenements(id),
  taux_frais           numeric(5,2) not null default 0 check (taux_frais >= 0 and taux_frais < 100),
  frais_fixe_centimes  integer not null default 0 check (frais_fixe_centimes >= 0),
  importer_depuis      date not null default date '2026-01-01'
);

-- Paiements hors ligne : journal et compte d'encaissement par mode.
create table if not exists public.compta_modes_paiement (
  mode               text primary key,
  libelle            text not null,
  journal_code       text not null references public.compta_journaux(code),
  compte_tresorerie  text not null references public.compta_comptes(numero)
);

create table if not exists public.compta_rapprochements (
  id                     uuid primary key default gen_random_uuid(),
  compte_numero          text not null references public.compta_comptes(numero),
  date_releve            date not null,
  solde_releve_centimes  integer not null,
  valide_par_nom         text,
  created_at             timestamptz not null default now(),
  unique (compte_numero, date_releve)
);


-- =====================================================================
-- 2. DONNÉES DE DÉPART
-- =====================================================================

insert into public.compta_comptes (numero, intitule, type) values
  ('110000', 'Report à nouveau', 'bilan'),
  ('120000', 'Résultat de l''exercice', 'bilan'),
  ('511200', 'Chèques à encaisser', 'tresorerie'),
  ('512000', 'Banque', 'tresorerie'),
  ('517000', 'Encaissements en ligne (SumUp)', 'tresorerie'),
  ('517100', 'Encaissements en ligne (Stripe)', 'tresorerie'),
  ('530000', 'Caisse', 'tresorerie'),
  ('604000', 'Prestations d''animation', 'charge'),
  ('606300', 'Petit matériel et décoration', 'charge'),
  ('606800', 'Autres fournitures', 'charge'),
  ('607000', 'Achats de boissons et alimentation', 'charge'),
  ('613000', 'Locations de matériel', 'charge'),
  ('616000', 'Assurance', 'charge'),
  ('623400', 'Cadeaux et lots', 'charge'),
  ('623600', 'Imprimés et affiches', 'charge'),
  ('626000', 'Internet et services en ligne', 'charge'),
  ('627000', 'Services bancaires', 'charge'),
  ('627800', 'Frais de paiement en ligne', 'charge'),
  ('651600', 'Droits d''auteur (SACEM)', 'charge'),
  ('706000', 'Billetterie des manifestations', 'produit'),
  ('706100', 'Emplacements exposants', 'produit'),
  ('706200', 'Vidéos du Père Noël', 'produit'),
  ('707000', 'Buvette et restauration', 'produit'),
  ('708800', 'Tombolas et jeux', 'produit'),
  ('740000', 'Subventions', 'produit'),
  ('754100', 'Dons manuels', 'produit'),
  ('756000', 'Cotisations', 'produit')
on conflict (numero) do nothing;

insert into public.compta_journaux (code, libelle, compte_tresorerie) values
  ('BQ', 'Banque', '512000'),
  ('CA', 'Caisse', '530000'),
  ('CH', 'Chèques à encaisser', '511200'),
  ('SU', 'Ventes du site (SumUp)', '517000'),
  ('ST', 'Ventes du site (Stripe)', '517100'),
  ('OD', 'Opérations diverses', null),
  ('AN', 'À-nouveaux', null)
on conflict (code) do nothing;

insert into public.compta_exercices (libelle, date_debut, date_fin) values
  ('2026', date '2026-01-01', date '2026-12-31')
on conflict (libelle) do nothing;

insert into public.compta_evenements (code, libelle, date_evenement, statut) values
  ('TRES',  'Trésors de Noël',        null, 'en_cours'),
  ('PNOEL', 'Le Père Noël te répond', null, 'en_cours'),
  ('ROUE',  'Roue de la Rentrée',     null, 'termine')
on conflict (code) do nothing;

insert into public.compta_modes_paiement (mode, libelle, journal_code, compte_tresorerie) values
  ('especes', 'Espèces', 'CA', '530000'),
  ('cheque',  'Chèque',  'CH', '511200')
on conflict (mode) do nothing;

-- Sources de ventes. "orders" (ancienne billetterie Stripe) est désactivée par défaut.
insert into public.compta_sources (cle, libelle, actif, journal_code, compte_produit, compte_tresorerie, compte_frais, compta_evenement_id) values
  ('reservations',  'Billetterie du site',         true,  'SU', '706000', '517000', '627800', null),
  ('orders',        'Billetterie (Stripe)',        false, 'ST', '706000', '517100', '627800', null),
  ('tdn_commandes', 'Trésors de Noël',             true,  'SU', '708800', '517000', '627800', (select id from public.compta_evenements where code = 'TRES')),
  ('pn_commandes',  'Le Père Noël te répond',      true,  'SU', '706200', '517000', '627800', (select id from public.compta_evenements where code = 'PNOEL'))
on conflict (cle) do nothing;


-- =====================================================================
-- 3. FONCTIONS INTERNES (non appelables depuis le site)
-- =====================================================================

-- Exercice correspondant à une date. Crée l'année civile si elle n'existe pas.
create or replace function public.compta__exercice(p_date date)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
  v_clos boolean;
  v_annee integer := extract(year from p_date)::integer;
begin
  select id, cloture into v_id, v_clos
  from compta_exercices
  where p_date between date_debut and date_fin
  order by date_debut
  limit 1;

  if v_id is null then
    insert into compta_exercices (libelle, date_debut, date_fin)
    values (v_annee::text, make_date(v_annee, 1, 1), make_date(v_annee, 12, 31))
    returning id into v_id;
    v_clos := false;
  end if;

  if v_clos then
    raise exception 'L''exercice est clôturé pour la date du %.', to_char(p_date, 'DD/MM/YYYY');
  end if;
  return v_id;
end $$;

-- Enregistre une écriture équilibrée et ses lignes.
-- p_lignes : [{"compte":"606300","debit":4890,"credit":0,"evenement_id":"uuid ou null","libelle":"facultatif"}, ...]
create or replace function public.compta__ecrire(
  p_journal text,
  p_date date,
  p_libelle text,
  p_lignes jsonb,
  p_source text default 'manuel',
  p_source_table text default null,
  p_source_id uuid default null,
  p_source_statut text default null,
  p_justificatif text default null,
  p_auteur text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_exercice uuid;
  v_numero integer;
  v_id uuid;
  v_debit bigint;
  v_credit bigint;
  v_nom text;
begin
  if p_date is null then
    raise exception 'La date est obligatoire.';
  end if;
  if coalesce(btrim(p_libelle), '') = '' then
    raise exception 'Le libellé est obligatoire.';
  end if;
  if not exists (select 1 from compta_journaux where code = p_journal) then
    raise exception 'Journal inconnu : %.', p_journal;
  end if;
  if p_lignes is null or jsonb_typeof(p_lignes) <> 'array' or jsonb_array_length(p_lignes) < 2 then
    raise exception 'Une écriture comporte au moins deux lignes.';
  end if;

  select coalesce(sum(coalesce((l ->> 'debit')::integer, 0)), 0),
         coalesce(sum(coalesce((l ->> 'credit')::integer, 0)), 0)
    into v_debit, v_credit
  from jsonb_array_elements(p_lignes) as l;

  if v_debit <> v_credit then
    raise exception 'Écriture déséquilibrée : débit % et crédit % (en centimes).', v_debit, v_credit;
  end if;
  if v_debit = 0 then
    raise exception 'Le montant de l''écriture est nul.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_lignes) as l
    left join compta_comptes c on c.numero = l ->> 'compte'
    where c.numero is null or not c.actif
  ) then
    raise exception 'Une ligne utilise un compte inconnu ou inactif.';
  end if;

  v_exercice := compta__exercice(p_date);

  -- Numérotation continue par journal et par exercice.
  perform pg_advisory_xact_lock(hashtext('compta:' || v_exercice::text || ':' || p_journal));
  select coalesce(max(numero), 0) + 1 into v_numero
  from compta_ecritures
  where exercice_id = v_exercice and journal_code = p_journal;

  v_nom := coalesce(
    p_auteur,
    (select a.nom from admins a
      where a.id = auth.uid() or lower(a.email) = lower(auth.jwt() ->> 'email')
      limit 1),
    'Inconnu'
  );

  insert into compta_ecritures (
    exercice_id, journal_code, numero, date_piece, libelle,
    source, source_table, source_id, source_statut,
    justificatif_chemin, cree_par, cree_par_nom
  ) values (
    v_exercice, p_journal, v_numero, p_date, btrim(p_libelle),
    p_source, p_source_table, p_source_id, p_source_statut,
    nullif(btrim(p_justificatif), ''), auth.uid(), v_nom
  )
  returning id into v_id;

  insert into compta_lignes (
    ecriture_id, position, compte_numero, compta_evenement_id, libelle, debit_centimes, credit_centimes
  )
  select v_id,
         t.ord::smallint,
         t.l ->> 'compte',
         nullif(t.l ->> 'evenement_id', '')::uuid,
         nullif(btrim(t.l ->> 'libelle'), ''),
         coalesce((t.l ->> 'debit')::integer, 0),
         coalesce((t.l ->> 'credit')::integer, 0)
  from jsonb_array_elements(p_lignes) with ordinality as t(l, ord);

  return v_id;
end $$;

-- Retrouve (ou crée) le code événement comptable d'un événement du site.
create or replace function public.compta__evenement_site(p_evenement_id uuid, p_event_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
  v_titre text;
  v_slug text;
  v_date date;
  v_code text;
begin
  if p_evenement_id is not null then
    select id into v_id from compta_evenements where site_evenement_id = p_evenement_id;
    if v_id is not null then return v_id; end if;
    select titre, slug, date_debut into v_titre, v_slug, v_date from evenements where id = p_evenement_id;
  elsif p_event_id is not null then
    select id into v_id from compta_evenements where site_event_id = p_event_id;
    if v_id is not null then return v_id; end if;
    select title, slug, (starts_at at time zone 'Europe/Paris')::date into v_titre, v_slug, v_date from events where id = p_event_id;
  else
    return null;
  end if;

  if v_titre is null then
    return null;
  end if;

  v_code := upper(left(regexp_replace(coalesce(v_slug, v_titre), '[^a-zA-Z0-9]+', '', 'g'), 10));
  if v_code = '' then v_code := 'EVT'; end if;
  if exists (select 1 from compta_evenements where code = v_code) then
    v_code := left(v_code, 6) || '-' || upper(substr(md5(coalesce(p_evenement_id, p_event_id)::text), 1, 3));
  end if;

  insert into compta_evenements (code, libelle, date_evenement, site_evenement_id, site_event_id)
  values (v_code, v_titre, v_date, p_evenement_id, p_event_id)
  returning id into v_id;
  return v_id;
end $$;

-- Écriture d'une vente du site : recette au brut, frais de paiement en charge si un taux est réglé.
-- p_mode (especes, cheque) : encaissement hors ligne, sur le compte du mode et sans frais.
-- p_compte_produit : compte de produit particulier (exposants), sinon celui de la source.
drop function if exists public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text);
drop function if exists public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text, text);

create or replace function public.compta__ecrire_vente(
  p_cle text,
  p_source_id uuid,
  p_date date,
  p_libelle text,
  p_montant integer,
  p_evenement uuid,
  p_statut text,
  p_mode text default null,
  p_compte_produit text default null
)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  s compta_sources%rowtype;
  m compta_modes_paiement%rowtype;
  v_journal text;
  v_tresorerie text;
  v_produit text;
  v_libelle text := p_libelle;
  v_hors_ligne boolean := false;
  v_frais integer := 0;
  v_evt uuid;
  v_lignes jsonb;
begin
  select * into s from compta_sources where cle = p_cle;
  if not found or not s.actif or coalesce(p_montant, 0) <= 0 then
    return false;
  end if;

  -- Vente datée d'un exercice clôturé : on ne touche à rien.
  if exists (select 1 from compta_exercices where p_date between date_debut and date_fin and cloture) then
    return false;
  end if;

  v_evt := coalesce(p_evenement, s.compta_evenement_id);
  v_journal := s.journal_code;
  v_tresorerie := s.compte_tresorerie;
  v_produit := s.compte_produit;
  if p_compte_produit is not null
     and exists (select 1 from compta_comptes where numero = p_compte_produit and actif) then
    v_produit := p_compte_produit;
  end if;

  if p_mode is not null then
    select * into m from compta_modes_paiement where mode = p_mode;
    if found then
      v_hors_ligne := true;
      v_journal := m.journal_code;
      v_tresorerie := m.compte_tresorerie;
      v_libelle := p_libelle || ' (' || lower(m.libelle) || ')';
    end if;
  end if;

  if not v_hors_ligne and (s.taux_frais > 0 or s.frais_fixe_centimes > 0) then
    v_frais := least(round(p_montant * s.taux_frais / 100.0)::integer + s.frais_fixe_centimes, p_montant - 1);
  end if;

  v_lignes := jsonb_build_array(
    jsonb_build_object('compte', v_tresorerie, 'debit', p_montant, 'credit', 0),
    jsonb_build_object('compte', v_produit, 'debit', 0, 'credit', p_montant, 'evenement_id', v_evt)
  );
  if v_frais > 0 then
    v_lignes := v_lignes || jsonb_build_array(
      jsonb_build_object('compte', s.compte_frais, 'debit', v_frais, 'credit', 0, 'evenement_id', v_evt, 'libelle', 'Frais de paiement'),
      jsonb_build_object('compte', v_tresorerie, 'debit', 0, 'credit', v_frais, 'libelle', 'Frais de paiement')
    );
  end if;

  perform compta__ecrire(v_journal, p_date, v_libelle, v_lignes, 'site', p_cle, p_source_id, p_statut, null, 'Import site');
  return true;
end $$;


-- =====================================================================
-- 4. FONCTIONS APPELÉES PAR LE SITE (RPC)
-- =====================================================================

-- Saisie d'une écriture par un admin ou une trésorière.
create or replace function public.compta_saisir_ecriture(
  p_journal text,
  p_date date,
  p_libelle text,
  p_lignes jsonb,
  p_justificatif text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  return compta__ecrire(p_journal, p_date, p_libelle, p_lignes, 'manuel', null, null, null, p_justificatif, null);
end $$;

-- Ajout ou remplacement du justificatif d'une écriture.
create or replace function public.compta_joindre_justificatif(p_ecriture_id uuid, p_chemin text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  update compta_ecritures set justificatif_chemin = nullif(btrim(p_chemin), '') where id = p_ecriture_id;
  if not found then
    raise exception 'Écriture introuvable.';
  end if;
end $$;

-- Annulation d'une écriture par une écriture inverse (aucune suppression).
create or replace function public.compta_contrepasser(p_ecriture_id uuid, p_date date default null, p_motif text default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  e compta_ecritures%rowtype;
  v_lignes jsonb;
  v_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  select * into e from compta_ecritures where id = p_ecriture_id for update;
  if not found then
    raise exception 'Écriture introuvable.';
  end if;
  if e.contrepassee_par is not null then
    raise exception 'La pièce % est déjà annulée.', e.piece;
  end if;
  if e.source = 'annulation' then
    raise exception 'Une écriture d''annulation ne s''annule pas.';
  end if;

  select jsonb_agg(jsonb_build_object(
           'compte', l.compte_numero,
           'debit', l.credit_centimes,
           'credit', l.debit_centimes,
           'evenement_id', l.compta_evenement_id,
           'libelle', l.libelle) order by l.position)
    into v_lignes
  from compta_lignes l
  where l.ecriture_id = e.id;

  v_id := compta__ecrire(
    e.journal_code,
    coalesce(p_date, (now() at time zone 'Europe/Paris')::date),
    'Annulation de ' || e.piece || coalesce(' : ' || nullif(btrim(p_motif), ''), ''),
    v_lignes, 'annulation', null, null, null, null, null
  );

  update compta_ecritures set contrepassee_par = v_id, verifie_le = now() where id = e.id;
  return v_id;
end $$;

-- Import des ventes payées du site (statut payee). Renvoie le nombre d'écritures créées.
create or replace function public.compta_importer_ventes()
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  s compta_sources%rowtype;
  r record;
  v_n integer := 0;
begin
  -- auth.uid() nul = appel serveur (service_role ou tâche planifiée). Le rôle anon n'a pas le droit d'exécuter.
  if auth.uid() is not null and not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;

  -- Billetterie du site (table reservations)
  select * into s from compta_sources where cle = 'reservations';
  if found and s.actif then
    for r in
      select res.id, res.reference, res.montant_centimes, res.paye_le, res.statut, res.evenement_id, res.places,
             res.mode_paiement, res.exposant, coalesce(ev.titre, 'Billetterie') as titre
      from reservations res
      left join evenements ev on ev.id = res.evenement_id
      where res.paye_le is not null
        and res.statut = 'payee'
        and coalesce(res.montant_centimes, 0) > 0
        and (res.paye_le at time zone 'Europe/Paris')::date >= s.importer_depuis
        and not exists (select 1 from compta_ecritures ce where ce.source_table = 'reservations' and ce.source_id = res.id)
      order by res.paye_le
    loop
      if compta__ecrire_vente(
           'reservations', r.id, (r.paye_le at time zone 'Europe/Paris')::date,
           r.titre
             || case when r.exposant then ', exposant' else ', ' || coalesce(r.places, 1) || ' place(s)' end
             || coalesce(', réf. ' || r.reference, ''),
           r.montant_centimes, compta__evenement_site(r.evenement_id, null), r.statut, r.mode_paiement,
           case when r.exposant then '706100' end) then
        v_n := v_n + 1;
      end if;
    end loop;
  end if;

  -- Ancienne billetterie Stripe (table orders)
  select * into s from compta_sources where cle = 'orders';
  if found and s.actif then
    for r in
      select o.id, o.total_cents, o.paid_at, o.status::text as statut, o.event_id,
             coalesce(ev.title, 'Billetterie') as titre
      from orders o
      left join events ev on ev.id = o.event_id
      where o.paid_at is not null
        and coalesce(o.total_cents, 0) > 0
        and (o.paid_at at time zone 'Europe/Paris')::date >= s.importer_depuis
        and not exists (select 1 from compta_ecritures ce where ce.source_table = 'orders' and ce.source_id = o.id)
      order by o.paid_at
    loop
      if compta__ecrire_vente(
           'orders', r.id, (r.paid_at at time zone 'Europe/Paris')::date,
           r.titre || ', commande ' || upper(left(r.id::text, 8)),
           r.total_cents, compta__evenement_site(null, r.event_id), r.statut) then
        v_n := v_n + 1;
      end if;
    end loop;
  end if;

  -- Trésors de Noël (table tdn_commandes)
  select * into s from compta_sources where cle = 'tdn_commandes';
  if found and s.actif then
    for r in
      select c.id, c.reference, c.montant_centimes, c.paye_le, c.statut,
             coalesce(cardinality(c.participant_ids), 0) as nb
      from tdn_commandes c
      where c.paye_le is not null
        and c.statut = 'payee'
        and coalesce(c.montant_centimes, 0) > 0
        and (c.paye_le at time zone 'Europe/Paris')::date >= s.importer_depuis
        and not exists (select 1 from compta_ecritures ce where ce.source_table = 'tdn_commandes' and ce.source_id = c.id)
      order by c.paye_le
    loop
      if compta__ecrire_vente(
           'tdn_commandes', r.id, (r.paye_le at time zone 'Europe/Paris')::date,
           'Trésors de Noël, ' || r.nb || ' inscription(s)' || coalesce(', réf. ' || r.reference, ''),
           r.montant_centimes, null, r.statut) then
        v_n := v_n + 1;
      end if;
    end loop;
  end if;

  -- Le Père Noël te répond (table pn_commandes, hors commandes de test)
  select * into s from compta_sources where cle = 'pn_commandes';
  if found and s.actif then
    for r in
      select c.id, c.reference, c.montant_centimes, c.paye_le, c.statut
      from pn_commandes c
      where c.paye_le is not null
        and c.statut = 'payee'
        and coalesce(c.test, false) = false
        and coalesce(c.montant_centimes, 0) > 0
        and (c.paye_le at time zone 'Europe/Paris')::date >= s.importer_depuis
        and not exists (select 1 from compta_ecritures ce where ce.source_table = 'pn_commandes' and ce.source_id = c.id)
      order by c.paye_le
    loop
      if compta__ecrire_vente(
           'pn_commandes', r.id, (r.paye_le at time zone 'Europe/Paris')::date,
           'Le Père Noël te répond' || coalesce(', réf. ' || r.reference, ''),
           r.montant_centimes, null, r.statut) then
        v_n := v_n + 1;
      end if;
    end loop;
  end if;

  return v_n;
end $$;

-- Ventes importées à contrôler : statut changé depuis l'import (remboursement, annulation, suppression)
-- ou vente qui n'est pas au statut payee.
create or replace function public.compta_ventes_a_verifier()
returns table (
  ecriture_id uuid,
  piece text,
  date_piece date,
  libelle text,
  source_table text,
  montant_centimes bigint,
  statut_importe text,
  statut_actuel text
)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  return query
  select ce.id, ce.piece, ce.date_piece, ce.libelle, ce.source_table,
         (select coalesce(sum(l.debit_centimes), 0) from compta_lignes l where l.ecriture_id = ce.id and l.position = 1),
         ce.source_statut,
         cur.statut
  from compta_ecritures ce
  left join lateral (
    select res.statut from reservations res where ce.source_table = 'reservations' and res.id = ce.source_id
    union all
    select o.status::text from orders o where ce.source_table = 'orders' and o.id = ce.source_id
    union all
    select t.statut from tdn_commandes t where ce.source_table = 'tdn_commandes' and t.id = ce.source_id
    union all
    select p.statut from pn_commandes p where ce.source_table = 'pn_commandes' and p.id = ce.source_id
  ) cur on true
  where ce.source_table is not null
    and ce.verifie_le is null
    and ce.contrepassee_par is null
    and (cur.statut is distinct from ce.source_statut
         or (ce.source_table <> 'orders' and cur.statut <> 'payee'))
  order by ce.date_piece desc;
end $$;

-- Classe une vente signalée sans l'annuler (ex. changement de statut sans remboursement).
create or replace function public.compta_marquer_verifie(p_ecriture_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  update compta_ecritures ce
     set verifie_le = now(),
         source_statut = coalesce((
           select x.statut from (
             select res.statut from reservations res where ce.source_table = 'reservations' and res.id = ce.source_id
             union all
             select o.status::text from orders o where ce.source_table = 'orders' and o.id = ce.source_id
             union all
             select t.statut from tdn_commandes t where ce.source_table = 'tdn_commandes' and t.id = ce.source_id
             union all
             select p.statut from pn_commandes p where ce.source_table = 'pn_commandes' and p.id = ce.source_id
           ) x limit 1), ce.source_statut)
   where ce.id = p_ecriture_id;
end $$;

-- Pointage des lignes de trésorerie pour le rapprochement bancaire.
create or replace function public.compta_pointer(p_ligne_ids uuid[], p_pointe boolean default true)
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_n integer;
begin
  if not public.is_staff() then
    raise exception 'Accès refusé.';
  end if;
  update compta_lignes l
     set pointe_le = case when p_pointe then now() else null end
   where l.id = any(p_ligne_ids)
     and exists (select 1 from compta_comptes c where c.numero = l.compte_numero and c.type = 'tresorerie');
  get diagnostics v_n = row_count;
  return v_n;
end $$;


-- =====================================================================
-- 5. VUES DE CONSULTATION (respectent les droits de la personne connectée)
-- =====================================================================

-- Journaux et grand livre : une ligne par ligne d'écriture.
create or replace view public.compta_v_lignes
with (security_invoker = true) as
select l.id,
       l.ecriture_id,
       e.exercice_id,
       e.journal_code,
       e.numero,
       e.piece,
       e.date_piece,
       coalesce(l.libelle, e.libelle) as libelle,
       l.position,
       l.compte_numero,
       c.intitule as compte_intitule,
       c.type as compte_type,
       l.compta_evenement_id,
       ev.code as evenement_code,
       l.debit_centimes,
       l.credit_centimes,
       l.pointe_le,
       e.source,
       e.contrepassee_par,
       e.justificatif_chemin,
       e.cree_par_nom,
       e.created_at
from public.compta_lignes l
join public.compta_ecritures e on e.id = l.ecriture_id
join public.compta_comptes c on c.numero = l.compte_numero
left join public.compta_evenements ev on ev.id = l.compta_evenement_id;

-- Balance par exercice. Le compte de résultat se lit sur les types charge et produit.
create or replace view public.compta_v_balance
with (security_invoker = true) as
select e.exercice_id,
       c.numero,
       c.intitule,
       c.type,
       sum(l.debit_centimes)::bigint as debit_centimes,
       sum(l.credit_centimes)::bigint as credit_centimes,
       (sum(l.debit_centimes) - sum(l.credit_centimes))::bigint as solde_centimes
from public.compta_lignes l
join public.compta_ecritures e on e.id = l.ecriture_id
join public.compta_comptes c on c.numero = l.compte_numero
group by e.exercice_id, c.numero, c.intitule, c.type;

-- Budget par événement et par compte : prévu et réalisé.
create or replace view public.compta_v_budget_detail
with (security_invoker = true) as
select coalesce(b.compta_evenement_id, r.compta_evenement_id) as compta_evenement_id,
       c.numero as compte_numero,
       c.intitule as compte_intitule,
       c.type as compte_type,
       coalesce(b.montant_centimes, 0)::bigint as prevu_centimes,
       coalesce(r.realise_centimes, 0)::bigint as realise_centimes
from public.compta_budgets b
full join (
  select l.compta_evenement_id,
         l.compte_numero,
         sum(case when cc.type = 'produit' then l.credit_centimes - l.debit_centimes
                  else l.debit_centimes - l.credit_centimes end) as realise_centimes
  from public.compta_lignes l
  join public.compta_comptes cc on cc.numero = l.compte_numero
  where l.compta_evenement_id is not null and cc.type in ('charge', 'produit')
  group by l.compta_evenement_id, l.compte_numero
) r on r.compta_evenement_id = b.compta_evenement_id and r.compte_numero = b.compte_numero
join public.compta_comptes c on c.numero = coalesce(b.compte_numero, r.compte_numero);

-- Budget par événement : totaux.
create or replace view public.compta_v_budgets
with (security_invoker = true) as
select ev.id,
       ev.code,
       ev.libelle,
       ev.statut,
       ev.date_evenement,
       coalesce(sum(d.prevu_centimes)   filter (where d.compte_type = 'produit'), 0)::bigint as recettes_prevues_centimes,
       coalesce(sum(d.realise_centimes) filter (where d.compte_type = 'produit'), 0)::bigint as recettes_realisees_centimes,
       coalesce(sum(d.prevu_centimes)   filter (where d.compte_type = 'charge'), 0)::bigint as depenses_prevues_centimes,
       coalesce(sum(d.realise_centimes) filter (where d.compte_type = 'charge'), 0)::bigint as depenses_realisees_centimes
from public.compta_evenements ev
left join public.compta_v_budget_detail d on d.compta_evenement_id = ev.id
group by ev.id, ev.code, ev.libelle, ev.statut, ev.date_evenement;


-- =====================================================================
-- 6. DROITS
-- =====================================================================

alter table public.compta_exercices      enable row level security;
alter table public.compta_comptes        enable row level security;
alter table public.compta_journaux       enable row level security;
alter table public.compta_evenements     enable row level security;
alter table public.compta_budgets        enable row level security;
alter table public.compta_ecritures      enable row level security;
alter table public.compta_lignes         enable row level security;
alter table public.compta_sources        enable row level security;
alter table public.compta_rapprochements enable row level security;
alter table public.compta_modes_paiement enable row level security;

-- Accès par l'API pour les personnes connectées (les policies ci-dessous filtrent ensuite).
grant select, insert, update, delete on
  public.compta_exercices, public.compta_comptes, public.compta_journaux, public.compta_evenements,
  public.compta_budgets, public.compta_ecritures, public.compta_lignes, public.compta_sources,
  public.compta_rapprochements, public.compta_modes_paiement
  to authenticated, service_role;
grant select on
  public.compta_v_lignes, public.compta_v_balance, public.compta_v_budget_detail, public.compta_v_budgets
  to authenticated, service_role;

-- Lecture : admins et trésorières, sur toutes les tables du module.
drop policy if exists compta_lecture on public.compta_exercices;
create policy compta_lecture on public.compta_exercices for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_comptes;
create policy compta_lecture on public.compta_comptes for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_journaux;
create policy compta_lecture on public.compta_journaux for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_evenements;
create policy compta_lecture on public.compta_evenements for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_budgets;
create policy compta_lecture on public.compta_budgets for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_ecritures;
create policy compta_lecture on public.compta_ecritures for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_lignes;
create policy compta_lecture on public.compta_lignes for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_sources;
create policy compta_lecture on public.compta_sources for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_modes_paiement;
create policy compta_lecture on public.compta_modes_paiement for select to authenticated using ((select public.is_staff()));
drop policy if exists compta_lecture on public.compta_rapprochements;
create policy compta_lecture on public.compta_rapprochements for select to authenticated using ((select public.is_staff()));

-- Écriture par admins et trésorières : événements, budgets, rapprochements.
drop policy if exists compta_ecriture_staff on public.compta_evenements;
create policy compta_ecriture_staff on public.compta_evenements for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));
drop policy if exists compta_ecriture_staff on public.compta_budgets;
create policy compta_ecriture_staff on public.compta_budgets for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));
drop policy if exists compta_ecriture_staff on public.compta_rapprochements;
create policy compta_ecriture_staff on public.compta_rapprochements for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

-- Écriture réservée aux admins : plan comptable, journaux, exercices, réglages d'import.
drop policy if exists compta_ecriture_admin on public.compta_comptes;
create policy compta_ecriture_admin on public.compta_comptes for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists compta_ecriture_admin on public.compta_journaux;
create policy compta_ecriture_admin on public.compta_journaux for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists compta_ecriture_admin on public.compta_exercices;
create policy compta_ecriture_admin on public.compta_exercices for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists compta_ecriture_admin on public.compta_modes_paiement;
create policy compta_ecriture_admin on public.compta_modes_paiement for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists compta_ecriture_admin on public.compta_sources;
create policy compta_ecriture_admin on public.compta_sources for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Écritures et lignes : aucune modification directe, tout passe par les fonctions de la partie 4.

-- Fonctions internes : inaccessibles depuis le site.
revoke all on function public.compta__exercice(date) from public, anon, authenticated;
revoke all on function public.compta__ecrire(text, date, text, jsonb, text, text, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.compta__evenement_site(uuid, uuid) from public, anon, authenticated;
revoke all on function public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text, text, text) from public, anon, authenticated;

-- Fonctions du site : personnes connectées uniquement (le contrôle admin ou trésorière est dans la fonction).
revoke all on function public.compta_saisir_ecriture(text, date, text, jsonb, text) from public, anon;
revoke all on function public.compta_joindre_justificatif(uuid, text) from public, anon;
revoke all on function public.compta_contrepasser(uuid, date, text) from public, anon;
revoke all on function public.compta_importer_ventes() from public, anon;
revoke all on function public.compta_ventes_a_verifier() from public, anon;
revoke all on function public.compta_marquer_verifie(uuid) from public, anon;
revoke all on function public.compta_pointer(uuid[], boolean) from public, anon;
grant execute on function public.compta_saisir_ecriture(text, date, text, jsonb, text) to authenticated, service_role;
grant execute on function public.compta_joindre_justificatif(uuid, text) to authenticated, service_role;
grant execute on function public.compta_contrepasser(uuid, date, text) to authenticated, service_role;
grant execute on function public.compta_importer_ventes() to authenticated, service_role;
grant execute on function public.compta_ventes_a_verifier() to authenticated, service_role;
grant execute on function public.compta_marquer_verifie(uuid) to authenticated, service_role;
grant execute on function public.compta_pointer(uuid[], boolean) to authenticated, service_role;


-- =====================================================================
-- 7. JUSTIFICATIFS (stockage privé)
-- =====================================================================

insert into storage.buckets (id, name, public)
values ('compta-justificatifs', 'compta-justificatifs', false)
on conflict (id) do nothing;

drop policy if exists compta_justificatifs_lecture on storage.objects;
create policy compta_justificatifs_lecture on storage.objects for select to authenticated
  using (bucket_id = 'compta-justificatifs' and (select public.is_staff()));
drop policy if exists compta_justificatifs_depot on storage.objects;
create policy compta_justificatifs_depot on storage.objects for insert to authenticated
  with check (bucket_id = 'compta-justificatifs' and (select public.is_staff()));


-- Recharge le schéma côté API pour que les nouvelles tables soient visibles tout de suite.
notify pgrst, 'reload schema';


-- =====================================================================
-- 8. APRÈS L'INSTALLATION (à lancer séparément, au besoin)
-- Les points a, b et d se font aussi depuis l'écran Comptabilité du site.
-- =====================================================================

-- a) Premier import des ventes déjà payées sur le site :
--    select public.compta_importer_ventes();

-- b) Frais de paiement : renseigner le taux réel du contrat SumUp (exemple 1,75 %) :
--    update public.compta_sources set taux_frais = 1.75 where journal_code = 'SU';

-- c) Activer l'ancienne billetterie Stripe si elle contient de vraies ventes :
--    update public.compta_sources set actif = true where cle = 'orders';

-- d) Soldes de départ au 1er janvier (exemple : 3 950,00 en banque, 250,00 en caisse) :
--    select public.compta__ecrire(p_journal => 'AN', p_date => date '2026-01-01', p_libelle => 'Soldes à l''ouverture', p_auteur => 'Ouverture', p_lignes =>
--      '[{"compte":"512000","debit":395000},{"compte":"530000","debit":25000},{"compte":"110000","credit":420000}]'::jsonb);
EOF_BUREAU_FICHIER
echo "  ✓ supabase/comptabilite.sql"
cat > 'INSTALLATION-COMPTA.md' <<'EOF_BUREAU_FICHIER'
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

## Réservations saisies à la main (espèces, chèque)

Admin, Réservations, « + Ajouter un participant » : nom, places, montant (modifiable, 0 pour une invitation),
paiement en espèces, par chèque ou pas encore payé. Le bouton « Encaisser » d'une réservation en attente
enregistre le paiement plus tard. Mise à jour de la base : réexécuter supabase/comptabilite.sql.

En comptabilité, les espèces vont en caisse (530000, journal CA) et les chèques en chèques à encaisser
(511200, journal CH), sans frais de paiement. Quand les chèques sont déposés à la banque :
Saisie, virement interne, de 511200 vers 512000. Idem pour un dépôt d'espèces, de 530000 vers 512000.

## Exposants (marché de Noël et autres)

Admin, Réservations, « + Ajouter un participant ou un exposant », onglet Exposant. Tous les événements sont proposés,
même sans billetterie en ligne. Les formules (tailles d'emplacement, options) se créent en bas du même panneau,
événement par événement ; sans formule, l'emplacement est à prix libre. Un exposant compte pour une présence au pointage.
En comptabilité, ses recettes vont au compte 706100, Emplacements exposants.
Mise à jour de la base : réexécuter supabase/comptabilite.sql.


## Accès du bureau

Admin, « Accès du bureau » (administrateurs uniquement) : création des comptes des membres, poste de chacun,
et grille des modules accordés à chaque poste. Le menu latéral n'affiche que les modules du membre connecté.
Mise à jour de la base : exécuter supabase/bureau.sql. Tant que ce n'est pas fait, le site fonctionne comme avant
(administrateurs et trésorières).

Les accès sont vérifiés côté serveur, page par page et action par action. Les règles de la base restent
réservées aux administrateurs, sauf la trésorerie et la comptabilité, ouvertes aux postes qui ont ces modules.
EOF_BUREAU_FICHIER
echo "  ✓ INSTALLATION-COMPTA.md"
mkdir -p 'src/app'
cat > 'src/app/actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { createClient, requireAdmin } from '@/lib/supabase/server';

export type ActionState = { ok?: string; error?: string } | null;

/* ============ PUBLIC : envoi d'une demande ============ */
export async function envoyerDemande(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim();
  const type = String(fd.get('type') ?? 'autre');
  const message = String(fd.get('message') ?? '').trim();
  const telephone = String(fd.get('telephone') ?? '').trim();
  const evenement_id = (fd.get('evenement_id') as string) || null;

  if (!nom || !email) return { error: 'Le nom et l\'email sont obligatoires.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { error: 'Email invalide.' };

  const supabase = await createClient();
  const { error } = await supabase.from('demandes').insert({
    nom, email, type, message: message || null,
    telephone: telephone || null, evenement_id,
  });
  if (error) return { error: "L'envoi a échoué. Réessayez ou écrivez-nous directement." };

  // Notification email (optionnelle : nécessite RESEND_API_KEY)
  if (process.env.RESEND_API_KEY && process.env.CONTACT_EMAIL) {
    try {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'Site du Comité <noreply@comitedesfetes-limetzvillez.fr>',
          to: [process.env.CONTACT_EMAIL],
          subject: `Nouvelle demande — ${type}`,
          text: `${nom} (${email}${telephone ? ' / ' + telephone : ''})\nType : ${type}\n\n${message}`,
        }),
      });
    } catch { /* la demande est enregistrée, l'email est un bonus */ }
  }

  return { ok: 'Message envoyé. Le comité vous répond sous quelques jours.' };
}

/* ============ ADMIN : réglages du site ============ */
export async function majReglages(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin('parametres');
  if (!isAdmin) return { error: 'Accès refusé.' };

  const champs = ['hero_kicker','hero_titre_1','hero_titre_accent','hero_titre_2','hero_texte',
    'hero_couleur','logo_url','logo_blanc_url','email_contact','facebook_url','adresse',
    'asso_titre','asso_texte','benevoles_titre','benevoles_texte'] as const;

  const payload: Record<string, string | null> = {};
  champs.forEach((c) => {
    const v = String(fd.get(c) ?? '').trim();
    payload[c] = v === '' ? null : v;
  });

  const { error } = await supabase.from('site_settings').update(payload).eq('id', 1);
  if (error) return { error: error.message };

  revalidatePath('/'); revalidatePath('/admin/parametres');
  return { ok: 'Réglages enregistrés.' };
}

/* ============ ADMIN : chiffres clés ============ */
export async function majStats(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin('association');
  if (!isAdmin) return { error: 'Accès refusé.' };

  const valeurs = fd.getAll('stat_valeur').map(String);
  const libelles = fd.getAll('stat_libelle').map(String);

  await supabase.from('stats').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  const lignes = valeurs
    .map((v, i) => ({ valeur: v.trim(), libelle: (libelles[i] ?? '').trim(), position: i + 1 }))
    .filter((l) => l.valeur && l.libelle);

  if (lignes.length) {
    const { error } = await supabase.from('stats').insert(lignes);
    if (error) return { error: error.message };
  }
  revalidatePath('/'); revalidatePath('/admin/association');
  return { ok: 'Chiffres clés mis à jour.' };
}

/* ============ ADMIN : événement ============ */
export async function enregistrerEvenement(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin('evenements');
  if (!isAdmin) return { error: 'Accès refusé.' };

  const id = String(fd.get('id') ?? '');
  const titre = String(fd.get('titre') ?? '').trim();
  if (!titre) return { error: 'Le titre est obligatoire.' };

  const slug = (String(fd.get('slug') ?? '').trim() || titre)
    .toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  const data = {
    slug, titre,
    sous_titre: String(fd.get('sous_titre') ?? '').trim() || null,
    chapo: String(fd.get('chapo') ?? '').trim() || null,
    description: String(fd.get('description') ?? '').trim() || null,
    couleur: String(fd.get('couleur') ?? '#FF3D7F'),
    couleur_sombre: String(fd.get('couleur_sombre') ?? '#C42A5F'),
    date_debut: String(fd.get('date_debut') ?? ''),
    date_fin: String(fd.get('date_fin') ?? '') || null,
    heure_debut: String(fd.get('heure_debut') ?? '').trim() || null,
    heure_fin: String(fd.get('heure_fin') ?? '').trim() || null,
    lieu: String(fd.get('lieu') ?? '').trim() || null,
    adresse: String(fd.get('adresse') ?? '').trim() || null,
    tarif: String(fd.get('tarif') ?? 'Entrée libre'),
    lien_reservation: String(fd.get('lien_reservation') ?? '').trim() || null,
    libelle_reservation: String(fd.get('libelle_reservation') ?? '').trim() || 'Réserver',
    billetterie_active: fd.get('billetterie_active') === 'on',
    prix_centimes: Math.round(Number(fd.get('prix_euros') ?? 0) * 100),
    places_max: fd.get('places_max') ? Number(fd.get('places_max')) : null,
    places_par_reservation: Number(fd.get('places_par_reservation') ?? 10),
    cloture_reservations: String(fd.get('cloture_reservations') ?? '') || null,
    saison: String(fd.get('saison') ?? 'ete'),
    image_url: String(fd.get('image_url') ?? '').trim() || null,
    publie: fd.get('publie') === 'on',
    position: Number(fd.get('position') ?? 0),
  };

  let evenementId = id;
  if (id) {
    const { error } = await supabase.from('evenements').update(data).eq('id', id);
    if (error) return { error: error.message };
  } else {
    const { data: cree, error } = await supabase.from('evenements').insert(data).select('id').single();
    if (error) return { error: error.message };
    evenementId = cree.id;
  }

  // --- créneaux ---
  await supabase.from('creneaux').delete().eq('evenement_id', evenementId);
  const heures = fd.getAll('cr_heure').map(String);
  const ctitres = fd.getAll('cr_titre').map(String);
  const cdesc = fd.getAll('cr_desc').map(String);
  const cscene = fd.getAll('cr_scene').map(String);
  const creneaux = heures
    .map((h, i) => ({
      evenement_id: evenementId, heure: h.trim(), titre: (ctitres[i] ?? '').trim(),
      description: (cdesc[i] ?? '').trim() || null, scene: (cscene[i] ?? '').trim() || null,
      position: i + 1,
    }))
    .filter((c) => c.heure && c.titre);
  if (creneaux.length) await supabase.from('creneaux').insert(creneaux);

  // --- blocs d'infos ---
  await supabase.from('infos').delete().eq('evenement_id', evenementId);
  const iTitres = fd.getAll('inf_titre').map(String);
  const iLignes = fd.getAll('inf_lignes').map(String);
  const infos = iTitres
    .map((t, i) => ({
      evenement_id: evenementId, titre: t.trim(),
      lignes: (iLignes[i] ?? '').split('\n').map((l) => l.trim()).filter(Boolean),
      position: i + 1,
    }))
    .filter((b) => b.titre && b.lignes.length);
  if (infos.length) await supabase.from('infos').insert(infos);

  // --- FAQ ---
  await supabase.from('faq').delete().eq('evenement_id', evenementId);
  const qs = fd.getAll('faq_q').map(String);
  const rs = fd.getAll('faq_r').map(String);
  const faq = qs
    .map((q, i) => ({
      evenement_id: evenementId, question: q.trim(),
      reponse: (rs[i] ?? '').trim(), position: i + 1,
    }))
    .filter((f) => f.question && f.reponse);
  if (faq.length) await supabase.from('faq').insert(faq);

  // --- tarifs ---
  await supabase.from('tarifs').delete().eq('evenement_id', evenementId);
  const tLibelles = fd.getAll('tarif_libelle').map(String);
  const tPrix     = fd.getAll('tarif_prix').map(String);
  const tDescr    = fd.getAll('tarif_description').map(String);
  const tarifs = tLibelles
    .map((libelle, i) => ({
      evenement_id: evenementId,
      libelle: libelle.trim(),
      description: (tDescr[i] ?? '').trim() || null,
      prix_centimes: Math.round(Number(tPrix[i] ?? 0) * 100),
      position: i + 1,
    }))
    .filter((t) => t.libelle);
  if (tarifs.length) await supabase.from('tarifs').insert(tarifs);

  // --- documents (affiches, menus, photos) ---
  await supabase.from('documents').delete().eq('evenement_id', evenementId);
  const dUrls     = fd.getAll('doc_url').map(String);
  const dTitres   = fd.getAll('doc_titre').map(String);
  const dLegendes = fd.getAll('doc_legende').map(String);
  const dTypes    = fd.getAll('doc_type').map(String);
  const dAffiches = fd.getAll('doc_affiche').map(String);
  console.log('[docs] urls=', dUrls.length, 'affiches=', dAffiches);
  const documents = dUrls
    .map((url, i) => ({
      evenement_id: evenementId,
      url,
      titre: (dTitres[i] ?? '').trim() || null,
      legende: (dLegendes[i] ?? '').trim() || null,
      type: dTypes[i] === 'pdf' ? 'pdf' : 'image',
      est_affiche: dAffiches[i] === '1',
      position: i + 1,
    }))
    .filter((d) => d.url);
  if (documents.length) await supabase.from('documents').insert(documents);

  revalidatePath('/');
  revalidatePath(`/evenements/${slug}`);
  revalidatePath('/admin/evenements');
  return { ok: 'Événement enregistré.' };
}

export async function supprimerEvenement(id: string) {
  const { supabase, isAdmin } = await requireAdmin('evenements');
  if (!isAdmin) return;
  await supabase.from('evenements').delete().eq('id', id);
  revalidatePath('/'); revalidatePath('/admin/evenements');
}

export async function basculerPublication(id: string, publie: boolean) {
  const { supabase, isAdmin } = await requireAdmin('evenements');
  if (!isAdmin) return;
  await supabase.from('evenements').update({ publie }).eq('id', id);
  revalidatePath('/'); revalidatePath('/admin/evenements');
}

/* ============ ADMIN : demandes ============ */
export async function changerStatutDemande(id: string, statut: string) {
  const { supabase, isAdmin } = await requireAdmin('demandes');
  if (!isAdmin) return;
  await supabase.from('demandes').update({ statut }).eq('id', id);
  revalidatePath('/admin/demandes');
}

export async function supprimerDemande(id: string) {
  const { supabase, isAdmin } = await requireAdmin('demandes');
  if (!isAdmin) return;
  await supabase.from('demandes').delete().eq('id', id);
  revalidatePath('/admin/demandes');
}


/* =========================================================
   PARTENAIRES (logos sur l'accueil)
   ========================================================= */
export async function enregistrerPartenaire(_prev: { ok?: string; erreur?: string } | null, fd: FormData) {
  const { supabase, isAdmin } = await requireAdmin('partenaires');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const id = String(fd.get('id') ?? '');
  const data = {
    nom: String(fd.get('nom') ?? '').trim(),
    logo_url: String(fd.get('logo_url') ?? '').trim(),
    site_url: String(fd.get('site_url') ?? '').trim() || null,
    actif: fd.get('actif') === 'on',
    position: Number(fd.get('position') ?? 0),
  };
  if (!data.nom) return { erreur: 'Nom obligatoire.' };
  if (!data.logo_url) return { erreur: 'Ajoutez un logo.' };
  const { error } = id ? await supabase.from('partenaires').update(data).eq('id', id) : await supabase.from('partenaires').insert(data);
  if (error) return { erreur: error.message };
  revalidatePath('/'); revalidatePath('/admin/partenaires');
  return { ok: 'Partenaire enregistré.' };
}

export async function supprimerPartenaire(id: string) {
  const { supabase, isAdmin } = await requireAdmin('partenaires');
  if (!isAdmin) return;
  await supabase.from('partenaires').delete().eq('id', id);
  revalidatePath('/'); revalidatePath('/admin/partenaires');
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/actions.ts"
mkdir -p 'src/app/admin/(protected)/association'
cat > 'src/app/admin/(protected)/association/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import FormStats from '@/components/FormStats';
import type { Stat } from '@/lib/types';

export default async function Association() {
  const { supabase } = await requireAdmin('association');
  const { data } = await supabase.from('stats').select('*').order('position');

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Association</h1>
          <p>
            Les chiffres  clés de la page d&apos;accueil. Le texte de présentation se modifie
            dans <Link href="/admin/parametres" style={{ textDecoration: 'underline' }}>
            Réglages du site</Link>.
          </p>
        </div>
      </div>
      <FormStats stats={(data ?? []) as Stat[]} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/association/page.tsx"
mkdir -p 'src/app/admin/(protected)/bureau'
cat > 'src/app/admin/(protected)/bureau/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import GestionBureau, { type MembreBureau, type PosteBureau } from '@/components/bureau/GestionBureau';

export const dynamic = 'force-dynamic';

export default async function AdminBureau() {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) {
    return <div className="panel"><h2>Réservé aux administrateurs</h2></div>;
  }

  const db = createAdminClient();
  const [{ data: postes, error }, { data: membres }] = await Promise.all([
    db.from('bureau_postes').select('cle, libelle, modules, position').order('position'),
    db.from('admins').select('*').order('nom'),
  ]);

  if (error) {
    return (
      <div className="panel">
        <h2>Module non installé</h2>
        <p style={{ marginBottom: '.8rem' }}>
          Exécute le fichier <code>supabase/bureau.sql</code> dans l&apos;éditeur SQL du projet Supabase du CDF, puis recharge cette page.
        </p>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>{error.message}</p>
      </div>
    );
  }

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Accès du bureau</h1>
          <p>Qui a accès à l&apos;administration, et quels modules voit chaque poste.</p>
        </div>
      </div>
      <GestionBureau
        membres={(membres ?? []) as MembreBureau[]}
        postes={(postes ?? []) as PosteBureau[]}
        moi={user.id}
      />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/bureau/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/ventes'
cat > 'src/app/admin/(protected)/compta/ventes/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import Entete, { SansExercice } from '@/components/compta/Entete';
import { BoutonImport, BoutonsVente } from '@/components/compta/ActionsVente';
import { FormSource } from '@/components/compta/FormsPlan';

type Source = {
  cle: string; libelle: string; actif: boolean; journal_code: string; compte_produit: string;
  taux_frais: number; frais_fixe_centimes: number; compta_evenements: { code: string } | null;
};
type AVerifier = {
  ecriture_id: string; piece: string; date_piece: string; libelle: string;
  montant_centimes: number; statut_importe: string | null; statut_actuel: string | null;
};
type EcritureSite = {
  id: string; piece: string; date_piece: string; libelle: string; source_table: string;
  contrepassee_par: string | null; compta_lignes: { position: number; debit_centimes: number }[];
};

export default async function Ventes({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase, isAdmin } = await requireAdmin();

  // Import à chaque ouverture : une vente déjà importée n'est jamais reprise.
  const { data: importees, error: erreurImport } = await supabase.rpc('compta_importer_ventes');

  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const [{ data: src }, { data: verif }, ecritures] = await Promise.all([
    supabase.from('compta_sources').select('*, compta_evenements(code)').order('libelle'),
    supabase.rpc('compta_ventes_a_verifier'),
    lireTout<EcritureSite>((de, a) =>
      supabase.from('compta_ecritures')
        .select('id, piece, date_piece, libelle, source_table, contrepassee_par, compta_lignes(position, debit_centimes)')
        .eq('exercice_id', exercice.id).eq('source', 'site')
        .order('date_piece', { ascending: false }).order('numero', { ascending: false }).range(de, a)
    ),
  ]);

  const sources = (src ?? []) as Source[];
  const aVerifier = (verif ?? []) as AVerifier[];
  const debit = (e: EcritureSite, position: number) =>
    e.compta_lignes.find((l) => l.position === position)?.debit_centimes ?? 0;

  // Totaux par source, hors ventes annulées. Ligne 1 = montant brut, ligne 3 = frais de paiement.
  const stats = new Map<string, { nb: number; brut: number; frais: number }>();
  for (const e of ecritures) {
    if (e.contrepassee_par) continue;
    const s = stats.get(e.source_table) ?? { nb: 0, brut: 0, frais: 0 };
    s.nb += 1;
    s.brut += debit(e, 1);
    s.frais += debit(e, 3);
    stats.set(e.source_table, s);
  }
  const total = [...stats.values()].reduce((t, s) => ({ nb: t.nb + s.nb, brut: t.brut + s.brut, frais: t.frais + s.frais }), { nb: 0, brut: 0, frais: 0 });

  return (
    <>
      <Entete titre="Ventes du site" exercices={exercices} exercice={exercice}>
        <BoutonImport />
      </Entete>
      {erreurImport
        ? <div className="cpt-msg ko">L&apos;import a échoué : {erreurImport.message}</div>
        : (
          <p className="cpt-info">
            {(importees as number) > 0 ? `${importees} nouvelle(s) vente(s) importée(s) à l'instant. ` : 'Journal à jour. '}
            Les ventes payées sur le site génèrent leurs écritures toutes seules, sans ressaisie.
          </p>
        )}

      <div className="cpt-panneau">
        <h2>À vérifier</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Date</th><th>Pièce</th><th>Vente</th><th className="n">Montant</th><th>Statut à l&apos;import</th><th>Statut actuel</th><th>Action</th></tr>
            </thead>
            <tbody>
              {aVerifier.map((v) => (
                <tr key={v.ecriture_id}>
                  <td className="fixe">{dateFr(v.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${v.ecriture_id}`}>{v.piece}</Link></td>
                  <td>{v.libelle}</td>
                  <td className="n">{montant(v.montant_centimes)}</td>
                  <td>{v.statut_importe ?? ''}</td>
                  <td><span className="cpt-etat jaune">{v.statut_actuel ?? 'vente supprimée'}</span></td>
                  <td><BoutonsVente id={v.ecriture_id} piece={v.piece} /></td>
                </tr>
              ))}
              {aVerifier.length === 0 && <tr><td colSpan={7}>Rien à vérifier : aucune vente importée n&apos;a changé de statut.</td></tr>}
            </tbody>
          </table>
        </div>
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Une vente remboursée ou annulée après son import apparaît ici. « Annuler la vente » passe l&apos;écriture inverse,
          « Ignorer » la laisse au journal.
        </p>
      </div>

      <div className="cpt-panneau">
        <h2>Sources importées, exercice {exercice.libelle}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Source</th><th>Journal</th><th>Compte</th><th>Évt</th>
                <th className="n">Ventes</th><th className="n">Brut</th><th className="n">Frais</th>
                <th>{isAdmin ? 'Réglages' : 'Import'}</th>
              </tr>
            </thead>
            <tbody>
              {sources.map((s) => {
                const st = stats.get(s.cle) ?? { nb: 0, brut: 0, frais: 0 };
                return (
                  <tr key={s.cle}>
                    <td>{s.libelle}</td>
                    <td className="fixe">{s.journal_code}</td>
                    <td className="fixe">{s.compte_produit}</td>
                    <td className="fixe">{s.compta_evenements?.code ?? 'selon la vente'}</td>
                    <td className="n">{st.nb}</td>
                    <td className="n">{montant(st.brut)}</td>
                    <td className="n">{montant(st.frais)}</td>
                    <td>
                      {isAdmin
                        ? <FormSource cle={s.cle} actif={s.actif} taux={Number(s.taux_frais)} fixe={montant(s.frais_fixe_centimes)} />
                        : <span className={`cpt-etat ${s.actif ? 'vert' : ''}`}>{s.actif ? 'Actif' : 'Inactif'}</span>}
                    </td>
                  </tr>
                );
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4}>Totaux</td>
                <td className="n">{total.nb}</td><td className="n">{montant(total.brut)}</td><td className="n">{montant(total.frais)}</td><td></td>
              </tr>
            </tfoot>
          </table>
        </div>
        <ul className="cpt-regles" style={{ marginTop: 10 }}>
          <li>Vente payée : débit du compte d&apos;encaissement, crédit du compte de produit, au montant brut.</li>
          <li>Frais de paiement : calculés avec le taux réglé ici, portés en charge dans la même pièce. À 0, aucun frais n&apos;est écrit.</li>
          <li>Un changement de taux ne s&apos;applique qu&apos;aux ventes importées ensuite.</li>
          <li>
            Réservation payée en espèces ou par chèque : encaissée en caisse (530000) ou en chèques à encaisser (511200), sans frais.
            La remise des chèques en banque se saisit en virement interne, de 511200 vers 512000.
          </li>
          <li>Réservation d&apos;un exposant : portée au compte 706100, Emplacements exposants, au lieu de la billetterie.</li>
        </ul>
      </div>

      <div className="cpt-panneau">
        <h2>Dernières ventes importées</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Date</th><th>Pièce</th><th>Vente</th><th className="n">Brut</th><th className="n">Frais</th></tr></thead>
            <tbody>
              {ecritures.slice(0, 15).map((e) => (
                <tr key={e.id} className={e.contrepassee_par ? 'annulee' : ''}>
                  <td className="fixe">{dateFr(e.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${e.id}`}>{e.piece}</Link></td>
                  <td>{e.libelle}{e.contrepassee_par ? ' (annulée)' : ''}</td>
                  <td className="n">{montant(debit(e, 1))}</td>
                  <td className="n">{montant(debit(e, 3))}</td>
                </tr>
              ))}
              {ecritures.length === 0 && <tr><td colSpan={5}>Aucune vente importée sur cet exercice.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/ventes/page.tsx"
mkdir -p 'src/app/admin/(protected)/demandes'
cat > 'src/app/admin/(protected)/demandes/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import LigneDemande from '@/components/LigneDemande';
import type { Demande } from '@/lib/types';

export default async function Demandes() {
  const { supabase } = await requireAdmin('demandes');
  const { data } = await supabase.from('demandes')
    .select('*').order('created_at', { ascending: false });
  const demandes = (data ?? []) as Demande[];
  const nouvelles = demandes.filter((d) => d.statut === 'nouveau').length;

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Demandes reçues</h1>
          <p>
            {demandes.length} demande{demandes.length > 1 ? 's' : ''} au total
            {nouvelles > 0 && `, dont ${nouvelles} à traiter`}.
          </p>
        </div>
      </div>

      <div className="panel">
        <table className="tbl">
          <thead>
            <tr>
              <th>Contact</th><th>Type</th><th>Message</th><th>Reçue le</th>
              <th>Statut</th><th></th>
            </tr>
          </thead>
          <tbody>
            {demandes.map((d) => <LigneDemande key={d.id} demande={d} />)}
            {demandes.length === 0 && (
              <tr><td colSpan={6} style={{ color: '#6b6560' }}>Aucune demande pour le moment.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/demandes/page.tsx"
mkdir -p 'src/app/admin/(protected)/evenements/[id]'
cat > 'src/app/admin/(protected)/evenements/[id]/page.tsx' <<'EOF_BUREAU_FICHIER'
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import EditeurEvenement from '@/components/EditeurEvenement';
import type { Evenement, Creneau, InfoBloc, FaqItem } from '@/lib/types';

export default async function PageEditeur(
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { supabase } = await requireAdmin('evenements');

  if (id === 'nouveau') {
    return (
      <>
        <div className="adm-h">
          <div>
            <h1>Nouvel événement</h1>
            <p>Il restera en brouillon tant que vous ne cochez pas « publier ».</p>
          </div>
        </div>
        <EditeurEvenement evenement={null} creneaux={[]} infos={[]} faq={[]} />
      </>
    );
  }

  const { data: evt } = await supabase.from('evenements').select('*').eq('id', id).maybeSingle();
  if (!evt) notFound();

  const [{ data: creneaux }, { data: infos }, { data: faq }, { data: documents }, { data: tarifs }] =
    await Promise.all([
      supabase.from('creneaux').select('*').eq('evenement_id', id).order('position'),
      supabase.from('infos').select('*').eq('evenement_id', id).order('position'),
      supabase.from('faq').select('*').eq('evenement_id', id).order('position'),
      supabase.from('documents').select('*').eq('evenement_id', id).order('position'),
      supabase.from('tarifs').select('*').eq('evenement_id', id).order('position'),
    ]);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>{(evt as Evenement).titre}</h1>
          <p>Modifiez le contenu, le programme et les infos pratiques de cette page.</p>
        </div>
      </div>
      <EditeurEvenement
        evenement={evt as Evenement}
        creneaux={(creneaux ?? []) as Creneau[]}
        infos={(infos ?? []) as InfoBloc[]}
        faq={(faq ?? []) as FaqItem[]}
        documents={(documents ?? []).map((d: any) => ({
          url: d.url, titre: d.titre ?? '', legende: d.legende ?? '',
          type: d.type, est_affiche: d.est_affiche,
        }))}
        tarifs={(tarifs ?? []).map((t: any) => ({
          libelle: t.libelle,
          description: t.description ?? '',
          prix_euros: (t.prix_centimes / 100).toFixed(2),
        }))}
      />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/evenements/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/evenements'
cat > 'src/app/admin/(protected)/evenements/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import LigneEvenement from '@/components/LigneEvenement';
import type { Evenement } from '@/lib/types';

export default async function ListeEvenements() {
  const { supabase } = await requireAdmin('evenements');
  const { data } = await supabase.from('evenements').select('*').order('position');
  const evts = (data ?? []) as Evenement[];

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Événements</h1>
          <p>Créez, modifiez, publiez ou dépubliez les rendez-vous de la saison.</p>
        </div>
        <Link className="btn btn-k btn-sm" href="/admin/evenements/nouveau">+ Nouvel événement</Link>
      </div>

      <div className="panel">
        <table className="tbl">
          <thead>
            <tr>
              <th></th><th>Titre</th><th>Date</th><th>Lieu</th><th>Statut</th><th></th>
            </tr>
          </thead>
          <tbody>
            {evts.map((e) => (
              <LigneEvenement key={e.id} evenement={e} dateLisible={dateLongue(e.date_debut)} />
            ))}
            {evts.length === 0 && (
              <tr><td colSpan={6} style={{ color: '#6b6560' }}>Aucun événement.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/evenements/page.tsx"
mkdir -p 'src/app/admin/(protected)'
cat > 'src/app/admin/(protected)/layout.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { moduleDuChemin, premiereChemin } from '@/lib/bureau/modules';
import NavAdmin from '@/components/NavAdmin';
import Deconnexion from '@/components/Deconnexion';

export const dynamic = 'force-dynamic';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, membre, superAdmin, modules, posteLibelle } = await requireAdmin();

  // La page de login a son propre rendu : elle est exclue via son layout imbriqué.
  if (!user) redirect('/admin/login');
  if (!membre) {
    return (
      <div className="adm-main">
        <div className="panel">
          <h2>Compte non autorisé</h2>
          <p style={{ marginBottom: '1rem' }}>
            Votre compte ({user.email}) n&apos;a pas accès à l&apos;administration, ou son accès a été désactivé.
            Un administrateur peut l&apos;ajouter dans « Accès du bureau ».
          </p>
          <Deconnexion />
        </div>
      </div>
    );
  }

  // Chaque membre ne voit que les modules confiés à son poste.
  if (!superAdmin) {
    const path = (await headers()).get('x-pathname') ?? '';
    const module = moduleDuChemin(path);
    if (path && (!module || !modules.includes(module))) {
      const accueil = premiereChemin(modules);
      if (accueil && accueil !== path) redirect(accueil);
      return (
        <div className="adm-main">
          <div className="panel">
            <h2>Aucun module accessible</h2>
            <p style={{ marginBottom: '1rem' }}>
              Votre poste ne donne accès à aucun module pour le moment. Un administrateur peut le régler dans « Accès du bureau ».
            </p>
            <Deconnexion />
          </div>
        </div>
      );
    }
  }

  return (
    <div className="adm">
      <aside className="adm-side">
        <div className="brand">Comité des Fêtes<br />{superAdmin ? 'Back-office' : posteLibelle ?? 'Bureau'}</div>
        <NavAdmin modules={modules} />
        <div className="sep">
          <Link href="/" target="_blank" style={{ fontSize: '.8rem' }}>↗ Voir le site</Link>
          <Deconnexion />
        </div>
      </aside>
      <main className="adm-main">{children}</main>
    </div>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/layout.tsx"
mkdir -p 'src/app/admin/(protected)/maintenance'
cat > 'src/app/admin/(protected)/maintenance/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import PanneauMaintenance from '@/components/PanneauMaintenance';

export const dynamic = 'force-dynamic';

export default async function AdminMaintenance() {
  const { supabase } = await requireAdmin('maintenance');
  const { data } = await supabase
    .from('site_settings')
    .select('maintenance_active, maintenance_titre, maintenance_message, maintenance_retour, maintenance_depuis')
    .eq('id', 1)
    .single();

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Mode maintenance</h1>
          <p>
            Coupe le site public et affiche une page d&apos;attente.
            Le back-office reste accessible.
          </p>
        </div>
      </div>
      <PanneauMaintenance reglages={data as any} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/maintenance/page.tsx"
mkdir -p 'src/app/admin/(protected)'
cat > 'src/app/admin/(protected)/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import type { Evenement, Demande } from '@/lib/types';

export default async function Dashboard() {
  const { supabase, modules } = await requireAdmin('tableau');
  // Les demandes contiennent des coordonnées : elles ne s'affichent qu'aux membres qui gèrent ce module.
  const voitDemandes = modules.includes('demandes');
  const gereEvenements = modules.includes('evenements');

  const [{ data: evts }, { data: demandes }, { count: nouvelles }] = await Promise.all([
    supabase.from('evenements').select('*').order('date_debut'),
    voitDemandes
      ? supabase.from('demandes').select('*').order('created_at', { ascending: false }).limit(6)
      : Promise.resolve({ data: [] as Demande[] }),
    voitDemandes
      ? supabase.from('demandes').select('id', { count: 'exact', head: true }).eq('statut', 'nouveau')
      : Promise.resolve({ count: 0 }),
  ]);

  const evenements = (evts ?? []) as Evenement[];
  const aujourdhui = new Date().toISOString().slice(0, 10);
  const aVenir = evenements.filter((e) => e.date_debut >= aujourdhui);
  const prochain = aVenir[0];

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Tableau de bord</h1>
          <p>Vue d&apos;ensemble du site et des demandes reçues.</p>
        </div>
        {gereEvenements && (
          <Link className="btn btn-k btn-sm" href="/admin/evenements/nouveau">
            + Nouvel événement
          </Link>
        )}
      </div>

      <div className="kpi">
        <div><b>{evenements.length}</b><span>Événements</span></div>
        <div><b>{evenements.filter((e) => e.publie).length}</b><span>Publiés</span></div>
        <div><b>{aVenir.length}</b><span>À venir</span></div>
        {voitDemandes && <div><b>{nouvelles ?? 0}</b><span>Demandes non traitées</span></div>}
      </div>

      {prochain && (
        <div className="panel" style={{ borderLeft: `10px solid ${prochain.couleur}` }}>
          <h2>Prochain événement</h2>
          <p style={{ fontSize: '1.3rem', fontFamily: 'Anton, sans-serif', textTransform: 'uppercase' }}>
            {prochain.titre}
          </p>
          <p style={{ color: '#6b6560', marginTop: '.3rem' }}>
            {dateLongue(prochain.date_debut)} · {prochain.lieu} ·{' '}
            {prochain.publie ? 'publié' : 'brouillon'}
          </p>
          <div style={{ marginTop: '1rem', display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
            {gereEvenements && <Link className="btn btn-y btn-sm" href={`/admin/evenements/${prochain.id}`}>Modifier</Link>}
            <Link className="btn btn-w btn-sm" href={`/evenements/${prochain.slug}`} target="_blank">
              Voir la page
            </Link>
          </div>
        </div>
      )}

      {voitDemandes && (
      <div className="panel">
        <h2>Dernières demandes</h2>
        {(!demandes || demandes.length === 0) && (
          <p style={{ color: '#6b6560' }}>Aucune demande pour le moment.</p>
        )}
        {demandes && demandes.length > 0 && (
          <table className="tbl">
            <thead>
              <tr><th>Nom</th><th>Type</th><th>Reçue le</th><th>Statut</th></tr>
            </thead>
            <tbody>
              {(demandes as Demande[]).map((d) => (
                <tr key={d.id}>
                  <td><strong>{d.nom}</strong><br /><span style={{ color: '#6b6560' }}>{d.email}</span></td>
                  <td>{d.type}</td>
                  <td>{new Date(d.created_at).toLocaleDateString('fr-FR')}</td>
                  <td>
                    <span className={`pill ${d.statut === 'nouveau' ? 'new' : 'done'}`}>{d.statut}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <div style={{ marginTop: '1.2rem' }}>
          <Link className="btn btn-k btn-sm" href="/admin/demandes">Toutes les demandes</Link>
        </div>
      </div>
      )}
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/page.tsx"
mkdir -p 'src/app/admin/(protected)/parametres'
cat > 'src/app/admin/(protected)/parametres/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import FormReglages from '@/components/FormReglages';
import type { SiteSettings } from '@/lib/types';

export default async function Parametres() {
  const { supabase } = await requireAdmin('parametres');
  const { data } = await supabase.from('site_settings').select('*').eq('id', 1).single();

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Réglages du site</h1>
          <p>Textes de la page d&apos;accueil, couleurs, logo et coordonnées.</p>
        </div>
      </div>
      <FormReglages settings={data as SiteSettings} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/parametres/page.tsx"
mkdir -p 'src/app/admin/(protected)/partenaires'
cat > 'src/app/admin/(protected)/partenaires/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import GestionPartenaires from '@/components/GestionPartenaires';
import type { Partenaire } from '@/lib/types';

export default async function AdminPartenaires() {
  const { supabase } = await requireAdmin('partenaires');
  const { data } = await supabase.from('partenaires').select('*').order('position');
  return (
    <>
      <div className="adm-h">
        <div><h1>Partenaires</h1><p>Logos affichés sous le programme sur la page d&apos;accueil. La barre défile automatiquement à partir de 5 logos.</p></div>
      </div>
      <GestionPartenaires partenaires={(data ?? []) as Partenaire[]} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/partenaires/page.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel/[id]'
cat > 'src/app/admin/(protected)/pere-noel/[id]/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { commandeParId } from '@/lib/pere-noel/db';
import { verifierVideo } from '@/lib/pere-noel/pipeline';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN, LIBELLE_SAGESSE } from '@/lib/pere-noel/types';
import ActionsCommande from '@/components/pere-noel/ActionsCommande';
import FormScript from '@/components/pere-noel/FormScript';
import BlocPostal from '@/components/pere-noel/BlocPostal';

export const maxDuration = 60;

export default async function AdminCommandePn({ params }: { params: Promise<{ id: string }> }) {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) return null;
  const { id } = await params;
  let c = await commandeParId(id);
  if (!c) notFound();
  if (c.gen_statut === 'video') c = await verifierVideo(c.id);

  const ligne = (k: string, v?: string | number | null) => v ? <tr><th style={{ width: 180 }}>{k}</th><td style={{ whiteSpace: 'pre-line' }}>{v}</td></tr> : null;
  const etapes = [
    { l: 'Paiement', ok: c.statut === 'payee' },
    { l: 'Script (Claude)', ok: !!c.script },
    { l: 'Audio (ElevenLabs)', ok: !!c.audio_url },
    { l: 'Vidéo lancée (HeyGen)', ok: !!c.heygen_video_id || !!c.video_url },
    { l: 'Vidéo récupérée', ok: !!c.video_url },
    { l: 'Email envoyé', ok: c.email_envoye },
  ];
  const modifiable = ['a_faire', 'relecture', 'terminee', 'erreur'].includes(c.gen_statut) && c.statut === 'payee';

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>{c.enfant_prenom}{c.age ? `, ${c.age} ans` : ''}</h1>
          <p><code>{c.reference}</code> · {c.test ? 'commande de test' : euros(c.montant_centimes)} · {new Date(c.created_at).toLocaleString('fr-FR')}
            {' '}· <span className={`pill ${c.gen_statut === 'terminee' ? 'done' : c.gen_statut === 'erreur' ? 'off' : 'new'}`}>{LIBELLE_GEN[c.gen_statut]}</span></p>
        </div>
        <Link className="btn btn-w btn-sm" href="/admin/pere-noel">← Commandes</Link>
      </div>

      {c.erreur && c.gen_statut === 'erreur' && <div className="msg ko">Erreur : {c.erreur}</div>}
      {c.erreur && c.gen_statut !== 'erreur' && <div className="msg ko" style={{ background: '#FBEFD2' }}>Dernier incident (réessai automatique) : {c.erreur}</div>}

      <div className="panel">
        <h2>Actions</h2>
        <ActionsCommande c={c} />
      </div>

      <div className="row2">
        <div className="panel">
          <h2>Avancement</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {etapes.map((e) => <li key={e.l} style={{ padding: '.4rem 0', borderBottom: '1px solid #e2ddd6' }}><span className={`pill ${e.ok ? 'done' : 'off'}`}>{e.ok ? '✓' : '…'}</span> {e.l}</li>)}
          </ul>
          {c.heygen_video_id && <p style={{ marginTop: '.6rem', fontSize: '.8rem', color: '#6b6560' }}>HeyGen : <code>{c.heygen_video_id}</code></p>}
          {c.duree_sec && <p style={{ fontSize: '.85rem' }}>Durée : {c.duree_sec} s · coût HeyGen ≈ {(c.duree_sec * COUT_HEYGEN_USD_PAR_SEC).toFixed(2)} $</p>}
          <p style={{ marginTop: '.6rem' }}><Link href={`/pere-noel/ma-video/${c.token}`} target="_blank" className="btn btn-w btn-sm">↗ Espace famille</Link></p>
        </div>
        <div className="panel">
          <h2>Résultat</h2>
          {c.video_url ? (
            <>
              <video controls playsInline src={c.video_url} style={{ width: '100%', maxWidth: 260, borderRadius: 12, background: '#000', display: 'block' }} />
              <p style={{ marginTop: '.6rem' }}><a className="btn btn-w btn-sm" href={c.video_url} target="_blank" rel="noreferrer">Ouvrir le MP4</a></p>
            </>
          ) : c.audio_url ? (
            <><p style={{ color: '#6b6560', fontSize: '.9rem' }}>Audio prêt, vidéo en attente.</p><audio controls src={c.audio_url} style={{ width: '100%' }} /></>
          ) : <p style={{ color: '#6b6560' }}>Rien de généré pour l’instant.</p>}
        </div>
      </div>

      {c.envoi_postal && <BlocPostal c={c} />}

      {c.script ? <FormScript c={c} modifiable={modifiable} /> : (
        <div className="panel"><h2>Script du Père Noël</h2><p style={{ color: '#6b6560' }}>Pas encore écrit. Cliquez sur « Générer » : Claude rédige le script à partir des réponses des parents{' '}
          (il apparaîtra ici pour relecture si l’option est activée dans les réglages).</p></div>
      )}

      <div className="panel">
        <h2>Réponses des parents</h2>
        <div className="tbl-wrap"><table className="tbl"><tbody>
          {ligne('Parent', `${c.parent_prenom} · ${c.email}`)}
          {ligne('Enfant', `${c.enfant_prenom}${c.prononciation ? ` (se prononce « ${c.prononciation} »)` : ''}${c.age ? `, ${c.age} ans` : ''}${c.genre ? `, ${c.genre}` : ''}`)}
          {ligne('Sagesse', LIBELLE_SAGESSE[c.sagesse])}
          {ligne('Lettre', c.lettre)}
          {ligne('Cadeaux demandés', c.cadeaux)}
          {ligne('Fierté', c.fierte)}
          {ligne('Doudou / passion', c.passion)}
          {ligne('Effort à encourager', c.effort)}
          {ligne('À saluer', c.salut)}
          {ligne(`Message secret (${c.ton_secret})`, c.secret)}
          {ligne('Paiement', c.statut === 'payee' ? `payée le ${c.paye_le ? new Date(c.paye_le).toLocaleString('fr-FR') : '—'}${c.transaction_code ? ` · ${c.transaction_code}` : ''}` : c.statut)}
        </tbody></table></div>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel'
cat > 'src/app/admin/(protected)/pere-noel/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { lireReglagesPn, lireStatsPn, listerCommandes } from '@/lib/pere-noel/db';
import { creditsHeygen } from '@/lib/pere-noel/ia';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN } from '@/lib/pere-noel/types';
import BasculeModulePn from '@/components/pere-noel/BasculeModulePn';
import BoutonVerifier from '@/components/pere-noel/BoutonVerifier';

export const maxDuration = 60;

const PILL: Record<string, string> = { a_faire: 'new', relecture: 'new', audio: 'on', video: 'on', terminee: 'done', erreur: 'off' };

export default async function AdminPereNoel() {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) return null;
  const [r, s, commandes, credits] = await Promise.all([lireReglagesPn(), lireStatsPn(), listerCommandes(), creditsHeygen()]);
  const pret = !!r.image_url && !!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && !!process.env.HEYGEN_API_KEY && !!process.env.ELEVENLABS_API_KEY && !!process.env.ANTHROPIC_API_KEY;
  const coutUsd = (s.secondes_video * COUT_HEYGEN_USD_PAR_SEC).toFixed(2);

  return (
    <>
      <div className="adm-h">
        <div><h1>Le Père Noël te répond</h1><p>Vidéos personnalisées du Père Noël, générées à la commande.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/pere-noel" target="_blank">↗ Page publique</Link>
          <BoutonVerifier />
        </div>
      </div>

      <BasculeModulePn actif={r.module_actif} />

      {!pret && (
        <div className="msg ko">
          Configuration incomplète :
          {!r.image_url && ' image du Père Noël manquante ·'}
          {!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && ' voix ElevenLabs manquante ·'}
          {!process.env.ANTHROPIC_API_KEY && ' ANTHROPIC_API_KEY ·'}
          {!process.env.ELEVENLABS_API_KEY && ' ELEVENLABS_API_KEY ·'}
          {!process.env.HEYGEN_API_KEY && ' HEYGEN_API_KEY ·'}
          {' '}<Link href="/admin/pere-noel/reglages">ouvrir les réglages</Link>
        </div>
      )}

      <div className="kpi">
        <div><b>{s.commandes}</b><span>Commandes payées</span></div>
        <div><b>{euros(s.ca_centimes)}</b><span>Encaissé</span></div>
        <div><b>{s.a_generer + s.a_relire}</b><span>À traiter</span></div>
        <div><b>{s.en_cours}</b><span>En génération</span></div>
        <div><b>{s.livrees}</b><span>Livrées</span></div>
        <div><b>{s.en_erreur}</b><span>En erreur</span></div>
        <div><b>{credits ?? '—'}</b><span>Crédits HeyGen restants</span></div>
        <div><b>{coutUsd} $</b><span>Coût vidéo estimé</span></div>
        <div><b>{commandes.filter((c) => c.statut === 'payee' && c.envoi_postal && !c.expedie_le).length}</b><span>Courriers à poster</span></div>
      </div>

      <div className="panel">
        <h2>État</h2>
        <p>Commandes : <span className={`pill ${r.commandes_ouvertes ? 'on' : 'off'}`}>{r.commandes_ouvertes ? 'ouvertes' : 'fermées'}</span>
          {' '}· Génération : <span className={`pill ${r.generation_auto ? 'on' : 'off'}`}>{r.generation_auto ? 'automatique au paiement' : 'manuelle (bouton Générer)'}</span>
          {' '}· Relecture du script : <span className={`pill ${r.relecture_script ? 'on' : 'off'}`}>{r.relecture_script ? 'oui' : 'non'}</span>
          {' '}· Prix : <b>{euros(r.prix_centimes)}</b></p>
        <p style={{ marginTop: '.5rem', color: '#6b6560', fontSize: '.9rem' }}>
          Les vidéos en cours chez HeyGen sont vérifiées à chaque ouverture de cette page, quand la famille ouvre son espace, et par le bouton « Vérifier ». Une génération complète prend 3 à 8 minutes.
        </p>
      </div>

      <div className="panel">
        <h2>Commandes ({commandes.length})</h2>
        {commandes.length === 0 ? <p style={{ color: '#6b6560' }}>Aucune commande pour le moment. Faites une commande de test avec le bouton en haut.</p> : (
          <div className="tbl-wrap">
            <table className="tbl">
              <thead><tr><th>Réf.</th><th>Enfant</th><th>Parent</th><th>Paiement</th><th>Génération</th><th>Date</th><th></th></tr></thead>
              <tbody>
                {commandes.map((c) => (
                  <tr key={c.id}>
                    <td><code>{c.reference}</code>{c.test && <span className="pill new" style={{ marginLeft: 6 }}>test</span>}{c.envoi_postal && <span className={`pill ${c.expedie_le ? 'done' : 'new'}`} style={{ marginLeft: 6 }} title={c.expedie_le ? 'Courrier expédié' : 'Courrier à expédier'}>📮</span>}</td>
                    <td><b>{c.enfant_prenom}</b>{c.age ? `, ${c.age} ans` : ''}</td>
                    <td>{c.parent_prenom}<br /><small style={{ color: '#6b6560' }}>{c.email}</small></td>
                    <td><span className={`pill ${c.statut === 'payee' ? 'done' : c.statut === 'en_attente' ? 'new' : 'off'}`}>{c.statut === 'payee' ? (c.test ? 'test' : euros(c.montant_centimes)) : c.statut}</span></td>
                    <td><span className={`pill ${PILL[c.gen_statut] ?? 'off'}`}>{LIBELLE_GEN[c.gen_statut]}</span>{c.gen_statut === 'erreur' && <div style={{ fontSize: '.75rem', color: '#B8322E', maxWidth: 220 }}>{c.erreur?.slice(0, 120)}</div>}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{new Date(c.created_at).toLocaleDateString('fr-FR')}</td>
                    <td><Link className="btn btn-w btn-sm" href={`/admin/pere-noel/${c.id}`}>Ouvrir</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/page.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel/reglages'
cat > 'src/app/admin/(protected)/pere-noel/reglages/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import FormReglagesPn from '@/components/pere-noel/FormReglagesPn';

export default async function AdminReglagesPn() {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) return null;
  const r = await lireReglagesPn();
  const cles = {
    anthropic: !!process.env.ANTHROPIC_API_KEY,
    elevenlabs: !!process.env.ELEVENLABS_API_KEY,
    heygen: !!process.env.HEYGEN_API_KEY,
    voixEnv: process.env.ELEVENLABS_VOICE_ID ?? '',
  };
  return (
    <>
      <div className="adm-h"><div><h1>Réglages du Père Noël</h1><p>Prix, ouverture, image, voix et consignes du script.</p></div></div>
      <FormReglagesPn r={r} cles={cles} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/reglages/page.tsx"
mkdir -p 'src/app/admin/(protected)/pointage/[id]'
cat > 'src/app/admin/(protected)/pointage/[id]/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import PointageListe from '@/components/PointageListe';

export const dynamic = 'force-dynamic';

export default async function Pointage(
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { supabase } = await requireAdmin('reservations');

  const { data: evt } = await supabase
    .from('evenements')
    .select('id, titre, date_debut, lieu, heure_debut, couleur')
    .eq('id', id)
    .maybeSingle();

  if (!evt) notFound();

  const { data: resas } = await supabase
    .from('reservations')
    .select('id, nom, email, telephone, commentaire, places, places_arrivees, code_billet, reference')
    .eq('evenement_id', id)
    .eq('statut', 'payee')
    .order('nom');

  return (
    <div className="ptg-page" style={{ ['--evt' as string]: evt.couleur }}>
      <header className="ptg-entete">
        <Link href="/admin/reservations" className="ptg-retour">← Réservations</Link>
        <h1>{evt.titre}</h1>
        <p>
          {dateLongue(evt.date_debut)}
          {evt.heure_debut && ` · ${evt.heure_debut}`}
          {evt.lieu && ` · ${evt.lieu}`}
        </p>
      </header>

      <PointageListe reservations={(resas ?? []) as any} />
    </div>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/pointage/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/reservations'
cat > 'src/app/admin/(protected)/reservations/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import ListeReservations from '@/components/ListeReservations';
import ExportCsv from '@/components/ExportCsv';
import VerifierSumUp from '@/components/VerifierSumUp';
import FormReservationManuelle from '@/components/FormReservationManuelle';

export const dynamic = 'force-dynamic';

export default async function Reservations({
  searchParams,
}: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin('reservations');

  // Tous les événements : un exposant peut être saisi sur un événement sans billetterie.
  const [{ data: evenements }, { data: suivi }, { data: tarifs }, { data: formules }] = await Promise.all([
    supabase.from('evenements')
      .select('id, titre, slug, places_max, prix_centimes, billetterie_active')
      .order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
    supabase.from('tarifs').select('id, evenement_id, libelle, prix_centimes').order('position'),
    supabase.from('formules_exposants').select('id, evenement_id, libelle, prix_centimes').order('position'),
  ]);

  let requete = supabase
    .from('reservations')
    .select('*, evenements(titre, slug), reservation_lignes(libelle, prix_centimes, quantite)')
    .order('created_at', { ascending: false });
  if (evt) requete = requete.eq('evenement_id', evt);

  const { data: resas } = await requete;
  const liste = resas ?? [];

  const payees = liste.filter((r) => r.statut === 'payee');
  const exposants = liste.filter((r) => r.exposant);
  // Saisies à la main pas encore payées : la place est prise, le montant reste à encaisser.
  const aEncaisser = liste.filter((r) => r.statut === 'en_attente' && r.saisie_par);
  const ecart = aEncaisser.reduce((s, r) => s + r.montant_centimes, 0);
  const placesAEncaisser = aEncaisser.reduce((s, r) => s + r.places, 0);
  const recette = payees.reduce((s, r) => s + r.montant_centimes, 0);
  const placesVendues = payees.reduce((s, r) => s + r.places, 0);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Réservations</h1>
          <p>Suivi des paiements (SumUp, espèces, chèques), pointage et liste d&apos;émargement.</p>
        </div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <VerifierSumUp nb={liste.filter((r) => r.statut === 'en_attente' && r.checkout_id).length} />
          <ExportCsv reservations={liste} evenements={evenements ?? []} />
        </div>
      </div>

      <FormReservationManuelle
        evenements={evenements ?? []} tarifs={tarifs ?? []} formules={formules ?? []} evenementInitial={evt}
      />

      <div className="kpi">
        <div><b>{placesVendues + placesAEncaisser}</b><span>Places réservées</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div>
          <b style={ecart > 0 ? { color: 'var(--evt-dark)' } : undefined}>{ecart > 0 ? `− ${euros(ecart)}` : euros(0)}</b>
          <span>Écart à encaisser</span>
        </div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
        {exposants.length > 0 && (
          <div><b>{exposants.length}</b><span>Exposants</span></div>
        )}
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead>
              <tr>
                <th>Événement</th><th>Réservées</th><th>Jauge</th>
                <th>Encaissé</th><th>Écart</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(suivi as any[]).map((s) => {
                // Jauge : places payées + places saisies à la main en attente de paiement.
                const attente = Number(s.places_a_encaisser ?? 0);
                const reservees = Number(s.places_vendues) + attente;
                const du = Number(s.a_encaisser_centimes ?? 0);
                return (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc">
                    <strong>{s.titre}</strong>
                    {Number(s.nb_exposants ?? 0) > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>
                        dont {s.nb_exposants} exposant{s.nb_exposants > 1 ? 's' : ''}
                      </div>
                    )}
                  </td>
                  <td data-l="Réservées">
                    {reservees}
                    {attente > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {attente} à encaisser</div>
                    )}
                  </td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{reservees} / {s.places_max}
                          <div className="jauge">
                            <span style={{
                              width: `${Math.min(100, (reservees / s.places_max) * 100)}%`,
                            }} />
                          </div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Encaissé">{euros(s.recette_centimes)}</td>
                  <td data-l="Écart">
                    {du > 0
                      ? <strong style={{ color: 'var(--evt-dark)' }}>− {euros(du)}</strong>
                      : euros(0)}
                  </td>
                  <td className="actions">
                    <Link className="btn btn-y btn-sm" href={`/admin/pointage/${s.id}`}>
                      Pointer
                    </Link>{' '}
                    <Link className="btn btn-w btn-sm" href={`/admin/reservations?evt=${s.id}`}>
                      Détail
                    </Link>
                  </td>
                </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel">
        <h2>
          {evt
            ? `Réservations — ${evenements?.find((e) => e.id === evt)?.titre ?? ''}`
            : 'Toutes les réservations'}
          {evt && <> · <Link href="/admin/reservations" style={{ fontSize: '.8rem' }}>tout voir</Link></>}
        </h2>

        <ListeReservations reservations={liste as any[]} />
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/reservations/page.tsx"
mkdir -p 'src/app/admin/(protected)/roue'
cat > 'src/app/admin/(protected)/roue/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import CarteRoue from '@/components/roue/CarteRoue';
import FormModuleRoue from '@/components/roue/FormModuleRoue';
import GestionLotsRoue from '@/components/roue/GestionLotsRoue';
import TableGagnants from '@/components/roue/TableGagnants';
import TestRoue from '@/components/roue/TestRoue';
import { configRoue, roueVisible } from '@/lib/roue/db';
import { purgerGainsAdmin } from '@/app/roue-actions';
import type { LotRoue, ModuleAccueil, ParticipationRoue, StatsRoue } from '@/lib/roue/types';

export default async function AdminRoue({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = 'apercu' } = await searchParams;
  const { supabase } = await requireAdmin('roue');
  await purgerGainsAdmin();
  const [{ data: module }, { data: stats }, { data: lots }, { data: gagnants }, { data: attribs }] = await Promise.all([
    supabase.from('homepage_modules').select('*').eq('module_key', 'roue_rentree').maybeSingle(),
    supabase.from('roue_stats').select('*').single(),
    supabase.from('roue_lots').select('*').order('position'),
    supabase.from('roue_participations').select('*, roue_lots(nom)').eq('gagne', true).order('created_at', { ascending: false }),
    supabase.from('roue_participations').select('lot_id').not('lot_id', 'is', null).is('annulee_le', null),
  ]);
  const m = module as ModuleAccueil | null;
  if (!m) {
    return <div className="panel"><h2>Module absent</h2><p>Exécutez <code>supabase/roue.sql</code> dans Supabase pour créer la Roue de la Rentrée.</p></div>;
  }
  const pris: Record<string, number> = {};
  for (const a of attribs ?? []) pris[a.lot_id!] = (pris[a.lot_id!] ?? 0) + 1;

  return (
    <>
      <div className="adm-h">
        <div><h1>🎡 Roue de la Rentrée</h1><p>Jeu événementiel intégré à la page d&apos;accueil.</p></div>
      </div>
      <CarteRoue module={m} visible={roueVisible(m)} stats={(stats ?? {}) as Partial<StatsRoue>} onglet={onglet} />

      {onglet === 'apercu' && <TestRoue config={configRoue(m)} />}
      {onglet === 'parametres' && <FormModuleRoue module={m} config={configRoue(m)} />}
      {onglet === 'lots' && <GestionLotsRoue lots={(lots ?? []) as LotRoue[]} pris={pris} />}
      {onglet === 'gagnants' && <TableGagnants lignes={(gagnants ?? []) as ParticipationRoue[]} />}
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/roue/page.tsx"
mkdir -p 'src/app/admin/(protected)/theme'
cat > 'src/app/admin/(protected)/theme/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { getThemes } from '@/lib/theme/db';
import { themeDuJour } from '@/lib/theme/types';
import GestionThemes from '@/components/theme/GestionThemes';

export const dynamic = 'force-dynamic';

export default async function AdminTheme() {
  const { isAdmin } = await requireAdmin('theme');
  if (!isAdmin) return <div className="panel"><h2>Accès réservé aux admins</h2></div>;

  const themes = await getThemes();
  const enLigne = themeDuJour(themes);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Thème de l&apos;accueil</h1>
          <p>Habille la page d&apos;accueil le temps d&apos;un mois ou d&apos;une fête, puis revient à la normale tout seul.</p>
        </div>
      </div>
      <div className={`msg ${enLigne ? 'ok' : ''}`} style={enLigne ? undefined : { background: '#fff' }}>
        {enLigne
          ? `En ligne en ce moment : ${enLigne.nom}.`
          : 'Aucun thème en ligne : la page d\u2019accueil a son apparence habituelle.'}
      </div>
      <GestionThemes themes={themes} annee={new Date().getFullYear()} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/theme/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresorerie'
cat > 'src/app/admin/(protected)/tresorerie/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import ExportCsv from '@/components/ExportCsv';
import ListeReservationsLecture from '@/components/ListeReservationsLecture';

export const dynamic = 'force-dynamic';

export default async function Tresorerie({ searchParams }: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  const [{ data: evenements }, { data: suivi }] = await Promise.all([
    supabase.from('evenements').select('id, titre, slug, places_max, prix_centimes').order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
  ]);

  let requete = supabase
    .from('reservations')
    .select('*, evenements(titre, slug), reservation_lignes(libelle, prix_centimes, quantite)')
    .order('created_at', { ascending: false });
  if (evt) requete = requete.eq('evenement_id', evt);
  const { data: resas } = await requete;
  const liste = resas ?? [];

  const payees = liste.filter((r) => r.statut === 'payee');
  const recette = payees.reduce((s, r) => s + r.montant_centimes, 0);
  const placesVendues = payees.reduce((s, r) => s + r.places, 0);
  // Saisies à la main pas encore payées : la place est prise, le montant reste à encaisser.
  const aEncaisser = liste.filter((r) => r.statut === 'en_attente' && r.saisie_par);
  const ecart = aEncaisser.reduce((s, r) => s + r.montant_centimes, 0);
  const placesAEncaisser = aEncaisser.reduce((s, r) => s + r.places, 0);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Trésorerie</h1>
          <p>Consultation des réservations et des recettes : SumUp, espèces, chèques (lecture seule).</p>
        </div>
        <ExportCsv reservations={liste} evenements={evenements ?? []} />
      </div>

      <div className="kpi">
        <div><b>{placesVendues + placesAEncaisser}</b><span>Places réservées</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div>
          <b style={ecart > 0 ? { color: 'var(--evt-dark)' } : undefined}>{ecart > 0 ? `− ${euros(ecart)}` : euros(0)}</b>
          <span>Écart à encaisser</span>
        </div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead><tr><th>Événement</th><th>Réservées</th><th>Jauge</th><th>Encaissé</th><th>Écart</th><th></th></tr></thead>
            <tbody>
              {(suivi as any[]).map((s) => {
                // Jauge : places payées + places saisies à la main en attente de paiement.
                const attente = Number(s.places_a_encaisser ?? 0);
                const reservees = Number(s.places_vendues) + attente;
                const du = Number(s.a_encaisser_centimes ?? 0);
                return (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc">
                    <strong>{s.titre}</strong>
                    {Number(s.nb_exposants ?? 0) > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {s.nb_exposants} exposant{s.nb_exposants > 1 ? 's' : ''}</div>
                    )}
                  </td>
                  <td data-l="Réservées">
                    {reservees}
                    {attente > 0 && <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {attente} à encaisser</div>}
                  </td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{reservees} / {s.places_max}
                          <div className="jauge"><span style={{ width: `${Math.min(100, (reservees / s.places_max) * 100)}%` }} /></div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Encaissé">{euros(s.recette_centimes)}</td>
                  <td data-l="Écart">
                    {du > 0 ? <strong style={{ color: 'var(--evt-dark)' }}>− {euros(du)}</strong> : euros(0)}
                  </td>
                  <td className="actions">
                    <Link className="btn btn-w btn-sm" href={`/admin/tresorerie?evt=${s.id}`}>Détail</Link>
                  </td>
                </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel">
        <h2>
          {evt ? `Réservations — ${evenements?.find((e) => e.id === evt)?.titre ?? ''}` : 'Toutes les réservations'}
          {evt && <> · <Link href="/admin/tresorerie" style={{ fontSize: '.8rem' }}>tout voir</Link></>}
        </h2>
        <ListeReservationsLecture reservations={liste as any[]} />
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresorerie/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/cles'
cat > 'src/app/admin/(protected)/tresors/cles/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { annulerTirage } from '@/app/tresors-actions';
import TableCles from '@/components/tresors/TableCles';
import type { Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: cles }, { data: lots }, { data: reg }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
    supabase.from('tdn_reglages').select('tirage_cle_id, tirage_le').eq('id', 1).single(),
  ]);
  const gagnante = reg?.tirage_cle_id ? (cles ?? []).find((c) => c.id === reg.tirage_cle_id) : null;
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées. Attribuez ici le grand trésor à une clé précise.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${reg?.tirage_le ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Tirage du grand trésor</h2>
        {reg?.tirage_le ? (
          <p>Effectué le {new Date(reg.tirage_le).toLocaleString('fr-FR')} · clé gagnante <b className="mono">n° {gagnante ? String(gagnante.numero).padStart(3, '0') : '?'}</b>.</p>
        ) : (
          <p>Pas encore effectué. Toutes les clés générées participent. Le résultat est enregistré et verrouillé dès le clic sur « Lancer le tirage ».</p>
        )}
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', marginTop: '1rem' }}>
          <Link className="btn btn-k btn-sm" href="/tresors-de-noel/tirage" target="_blank">↗ Ouvrir l&apos;écran du tirage</Link>
          {reg?.tirage_le && (
            <form action={async () => { 'use server'; await annulerTirage(); }}>
              <button className="btn btn-w btn-sm">Annuler le tirage</button>
            </form>
          )}
        </div>
      </div>
      <TableCles lignes={lignes} lots={(lots ?? []) as Lot[]} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/cles/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/lots'
cat > 'src/app/admin/(protected)/tresors/lots/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import GestionLots from '@/components/tresors/GestionLots';
import type { Lot, Partenaire } from '@/lib/tresors/types';

export default async function AdminLots() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: lots }, { data: partenaires }, { data: attribs }] = await Promise.all([
    supabase.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position'),
    supabase.from('tdn_partenaires').select('*').order('nom'),
    supabase.from('tdn_cles').select('lot_id, revelee_le').not('lot_id', 'is', null),
  ]);
  const compte: Record<string, { attribues: number; reveles: number }> = {};
  for (const a of attribs ?? []) {
    const c = (compte[a.lot_id!] ??= { attribues: 0, reveles: 0 });
    c.attribues++; if (a.revelee_le) c.reveles++;
  }
  return (
    <>
      <div className="adm-h"><div><h1>Lots et partenaires</h1><p>Les lots sont attribués au moment de la révélation, dans la limite du stock. Le « grand trésor » ne se tire pas au sort : attribuez-le à une clé depuis l&apos;onglet Clés.</p></div></div>
      <GestionLots lots={(lots ?? []) as Lot[]} partenaires={(partenaires ?? []) as Partenaire[]} compte={compte} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/lots/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/missions/[id]'
cat > 'src/app/admin/(protected)/tresors/missions/[id]/page.tsx' <<'EOF_BUREAU_FICHIER'
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import EditeurMission from '@/components/tresors/EditeurMission';
import type { Mission } from '@/lib/tresors/types';

export default async function AdminMission({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase } = await requireAdmin('tresors');
  let mission: Mission | null = null;
  if (id !== 'nouvelle') {
    const { data } = await supabase.from('tdn_missions').select('*').eq('id', id).maybeSingle();
    if (!data) notFound();
    mission = data as Mission;
  } else {
    const { data: max } = await supabase.from('tdn_missions').select('numero').order('numero', { ascending: false }).limit(1).maybeSingle();
    return <EditeurMission mission={null} numeroSuivant={(max?.numero ?? 0) + 1} />;
  }
  return <EditeurMission mission={mission} numeroSuivant={mission.numero} />;
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/missions/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/missions'
cat > 'src/app/admin/(protected)/tresors/missions/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import type { Mission } from '@/lib/tresors/types';

export default async function AdminMissions() {
  const { supabase } = await requireAdmin('tresors');
  const { data } = await supabase.from('tdn_missions').select('*').order('numero');
  const missions = (data ?? []) as Mission[];
  return (
    <>
      <div className="adm-h">
        <div><h1>Missions</h1><p>Énigmes, réponses acceptées et indices.</p></div>
        <Link className="btn btn-k btn-sm" href="/admin/tresors/missions/nouvelle">+ Nouvelle mission</Link>
      </div>
      <div className="panel">
        <table className="tbl">
          <thead><tr><th>#</th><th>Titre</th><th>Lieu</th><th>Type</th><th>Réponse</th><th>Indices</th><th>État</th><th></th></tr></thead>
          <tbody>
            {missions.map((m) => (
              <tr key={m.id}>
                <td>{m.numero}</td><td><b>{m.titre}</b></td><td>{m.lieu}</td><td>{m.question_type}</td>
                <td className="mono">{m.question_type === 'choix' ? m.options[m.bonne_reponse ?? 0] : m.reponses[0]}</td>
                <td>{m.indices.length}{m.solution_secours ? ' + secours' : ''}</td>
                <td><span className={`pill ${m.publie ? 'on' : 'off'}`}>{m.publie ? 'publiée' : 'brouillon'}</span></td>
                <td><Link className="btn btn-y btn-sm" href={`/admin/tresors/missions/${m.id}`}>Modifier</Link></td>
              </tr>
            ))}
            {missions.length === 0 && <tr><td colSpan={8}>Aucune mission. Exécutez <code>supabase/tresors.sql</code> ou créez-en une.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/missions/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors'
cat > 'src/app/admin/(protected)/tresors/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import BasculeModuleTdn from '@/components/tresors/BasculeModuleTdn';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import type { Stats } from '@/lib/tresors/types';

export default async function AdminTresors() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: stats }, { data: reglages }, { count: nbMissions }, { count: nbLots }] = await Promise.all([
    supabase.from('tdn_stats').select('*').single(),
    supabase.from('tdn_reglages').select('*').eq('id', 1).single(),
    supabase.from('tdn_missions').select('id', { count: 'exact', head: true }),
    supabase.from('tdn_lots').select('id', { count: 'exact', head: true }),
  ]);
  const s = (stats ?? {}) as Partial<Stats>;

  return (
    <>
      <div className="adm-h">
        <div><h1>Trésors de Noël</h1><p>Chasse aux trésors du Marché de Noël.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel" target="_blank">↗ Page du jeu</Link>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel/reglement" target="_blank">↗ Règlement</Link>
          <Link className="btn btn-y btn-sm" href="/tresors-de-noel/revelation" target="_blank">↗ Écran de révélation</Link>
        </div>
      </div>

      <BasculeModuleTdn actif={reglages?.module_actif !== false} />
      <div className="kpi">
        <div><b>{s.inscrits ?? 0} / {reglages?.places_max ?? '—'}</b><span>Places réservées</span></div>
        <div><b>{euros(s.ca_centimes ?? 0)}</b><span>Chiffre d&apos;affaires</span></div>
        <div><b>{s.commences ?? 0}</b><span>Ont commencé</span></div>
        <div><b>{s.termines ?? 0}</b><span>Ont terminé</span></div>
        <div><b>{s.cles_generees ?? 0}</b><span>Clés générées</span></div>
        <div><b>{s.cles_revelees ?? 0}</b><span>Clés révélées</span></div>
      </div>

      <div className="row2">
        <div className="panel">
          <h2>État</h2>
          <p>Inscriptions : <span className={`pill ${reglages?.inscriptions_ouvertes ? 'on' : 'off'}`}>{reglages?.inscriptions_ouvertes ? 'ouvertes' : 'fermées'}</span></p>
          <p style={{ marginTop: '.5rem' }}>Jeu : <span className={`pill ${reglages?.jeu_actif ? 'on' : 'off'}`}>{reglages?.jeu_actif ? 'activé' : 'désactivé'}</span> · du {reglages?.jeu_debut ? new Date(reglages.jeu_debut).toLocaleDateString('fr-FR') : '—'} au {reglages?.jeu_fin ? new Date(reglages.jeu_fin).toLocaleDateString('fr-FR') : '—'}</p>
          <p style={{ marginTop: '.5rem' }}>{nbMissions ?? 0} missions · {nbLots ?? 0} lots</p>
          <Link className="btn btn-y btn-sm" href="/admin/tresors/reglages" style={{ marginTop: '1rem' }}>Modifier les réglages</Link>
        </div>
        <div className="panel">
          <h2>Raccourcis</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '.6rem', alignItems: 'flex-start' }}>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/missions/nouvelle">+ Nouvelle mission</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/lots">Gérer les lots</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/cles">Attribuer le grand trésor</Link>
          </div>
        </div>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/participants'
cat > 'src/app/admin/(protected)/tresors/participants/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import TableParticipants from '@/components/tresors/TableParticipants';

export default async function AdminParticipants() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: parts }, { data: prog }, { data: cles }, { count: nbMissions }] = await Promise.all([
    supabase.from('tdn_participants').select('*, tdn_comptes(prenom, nom, email, telephone)').order('created_at', { ascending: false }),
    supabase.from('tdn_progressions').select('participant_id'),
    supabase.from('tdn_cles').select('participant_id, numero, revelee_le'),
    supabase.from('tdn_missions').select('id', { count: 'exact', head: true }).eq('publie', true),
  ]);
  const progression: Record<string, number> = {};
  for (const p of prog ?? []) progression[p.participant_id] = (progression[p.participant_id] ?? 0) + 1;
  const lignes = (parts ?? []).map((p) => {
    const c = (cles ?? []).find((k) => k.participant_id === p.id);
    const compte = p.tdn_comptes as { prenom: string; nom: string; email: string; telephone: string | null } | null;
    return {
      id: p.id, prenom: p.prenom, categorie: p.categorie, paye: p.paye,
      responsable: compte ? `${compte.prenom} ${compte.nom}` : '', email: compte?.email ?? '', telephone: compte?.telephone ?? '',
      progression: progression[p.id] ?? 0, cle: c?.numero ?? null,
      statut: !p.paye ? 'non payé' : c?.revelee_le ? 'révélé' : c ? 'terminé' : (progression[p.id] ?? 0) > 0 ? 'en cours' : 'inscrit',
    };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Participants</h1><p>{lignes.filter((l) => l.paye).length} inscrits payés sur {lignes.length}.</p></div></div>
      <TableParticipants lignes={lignes} nbMissions={nbMissions ?? 0} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/participants/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/reglages'
cat > 'src/app/admin/(protected)/tresors/reglages/page.tsx' <<'EOF_BUREAU_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import FormReglagesTdn from '@/components/tresors/FormReglagesTdn';
import type { Reglages } from '@/lib/tresors/types';

export default async function AdminReglagesTdn() {
  const { supabase } = await requireAdmin('tresors');
  const { data } = await supabase.from('tdn_reglages').select('*').eq('id', 1).single();
  return (
    <>
      <div className="adm-h"><div><h1>Réglages du jeu</h1><p>Textes, tarifs et ouverture.</p></div></div>
      <FormReglagesTdn r={data as Reglages} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/reglages/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/bureau-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { randomBytes } from 'crypto';
import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { MODULES_ATTRIBUABLES } from '@/lib/bureau/modules';

export type EtatBureau = { ok?: string; erreur?: string; motDePasse?: string } | null;

const REFUS = { erreur: 'Réservé aux administrateurs.' };
/** Valeur de la liste des postes qui désigne un administrateur (accès complet). */
const ADMIN = 'admin';

function rafraichir() {
  revalidatePath('/admin', 'layout');
}

/** Mot de passe provisoire lisible, à transmettre au membre. */
function motDePasseProvisoire() {
  return randomBytes(9).toString('base64url');
}

function fiche(poste: string) {
  return poste === ADMIN ? { role: 'admin', poste: null } : { role: 'membre', poste };
}

/* ------------------------------------------------------------------ */
/* Membres                                                             */
/* ------------------------------------------------------------------ */

/** Crée le compte d'un membre (ou rattache un compte existant) et lui attribue un poste. */
export async function creerMembre(_prev: EtatBureau, fd: FormData): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const poste = String(fd.get('poste') ?? '');
  if (nom.length < 2) return { erreur: 'Le nom est obligatoire.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (!poste) return { erreur: 'Choisis un poste.' };

  const db = createAdminClient();
  const { data: deja } = await db.from('admins').select('id').ilike('email', email).maybeSingle();
  if (deja) return { erreur: 'Cette adresse a déjà un accès.' };

  const motDePasse = motDePasseProvisoire();
  let id: string | null = null;

  const { data: cree, error } = await db.auth.admin.createUser({ email, password: motDePasse, email_confirm: true });
  if (cree?.user) {
    id = cree.user.id;
  } else {
    // Le compte de connexion existe peut-être déjà : on le retrouve et on lui donne un nouveau mot de passe.
    for (let page = 1; page <= 20 && !id; page++) {
      const { data: liste } = await db.auth.admin.listUsers({ page, perPage: 200 });
      const trouve = liste?.users.find((u) => u.email?.toLowerCase() === email);
      if (trouve) id = trouve.id;
      if (!liste || liste.users.length < 200) break;
    }
    if (!id) return { erreur: error?.message ?? 'Création du compte impossible.' };
    await db.auth.admin.updateUserById(id, { password: motDePasse });
  }

  const { error: errFiche } = await db.from('admins').insert({ id, email, nom, actif: true, ...fiche(poste) });
  if (errFiche) {
    return {
      erreur: /poste|actif|bureau_postes|role/.test(errFiche.message)
        ? 'La base n\u2019est pas à jour : exécute supabase/bureau.sql dans Supabase, puis réessaie.'
        : errFiche.message,
    };
  }

  rafraichir();
  return { ok: `Accès créé pour ${nom} (${email}).`, motDePasse };
}

/** Change le poste d'un membre, ou le passe administrateur. */
export async function changerPoste(id: string, poste: string): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id && poste !== ADMIN) return { erreur: 'Tu ne peux pas retirer ton propre accès administrateur.' };

  const { error } = await createAdminClient().from('admins').update(fiche(poste)).eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Poste mis à jour.' };
}

export async function basculerMembre(id: string, actif: boolean): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id) return { erreur: 'Tu ne peux pas désactiver ton propre compte.' };

  const { error } = await createAdminClient().from('admins').update({ actif }).eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: actif ? 'Accès réactivé.' : 'Accès désactivé.' };
}

/** Génère un nouveau mot de passe provisoire pour un membre. */
export async function nouveauMotDePasse(id: string): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const motDePasse = motDePasseProvisoire();
  const { error } = await createAdminClient().auth.admin.updateUserById(id, { password: motDePasse });
  if (error) return { erreur: error.message };
  return { ok: 'Nouveau mot de passe généré.', motDePasse };
}

/** Retire définitivement l'accès d'un membre, ainsi que son compte de connexion. */
export async function supprimerMembre(id: string): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id) return { erreur: 'Tu ne peux pas supprimer ton propre compte.' };

  const db = createAdminClient();
  const { error } = await db.from('admins').delete().eq('id', id);
  if (error) return { erreur: error.message };
  await db.auth.admin.deleteUser(id); // sans effet si le compte de connexion a déjà disparu
  rafraichir();
  return { ok: 'Accès supprimé.' };
}

/* ------------------------------------------------------------------ */
/* Postes et modules                                                   */
/* ------------------------------------------------------------------ */

/** Accorde ou retire un module à un poste. */
export async function basculerAcces(poste: string, module: string, accorde: boolean): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;
  if (!MODULES_ATTRIBUABLES.some((m) => m.cle === module)) return { erreur: 'Module inconnu.' };

  const db = createAdminClient();
  const { data } = await db.from('bureau_postes').select('modules').eq('cle', poste).maybeSingle();
  if (!data) return { erreur: 'Poste introuvable.' };
  const actuels = (data.modules as string[]) ?? [];
  const modules = accorde ? [...new Set([...actuels, module])] : actuels.filter((m) => m !== module);

  const { error } = await db.from('bureau_postes').update({ modules }).eq('cle', poste);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Accès mis à jour.' };
}

export async function ajouterPoste(_prev: EtatBureau, fd: FormData): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const libelle = String(fd.get('libelle') ?? '').trim();
  if (libelle.length < 2) return { erreur: 'Le nom du poste est obligatoire.' };
  const cle = libelle.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
  if (cle.length < 2 || cle === ADMIN) return { erreur: 'Nom de poste invalide.' };

  const db = createAdminClient();
  const { count } = await db.from('bureau_postes').select('cle', { count: 'exact', head: true });
  const { error } = await db.from('bureau_postes').insert({ cle, libelle, modules: ['tableau'], position: (count ?? 0) + 1 });
  if (error) return { erreur: error.message.includes('duplicate') ? 'Ce poste existe déjà.' : error.message };
  rafraichir();
  return { ok: `Poste « ${libelle} » ajouté.` };
}

export async function supprimerPoste(cle: string): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const db = createAdminClient();
  const { count } = await db.from('admins').select('id', { count: 'exact', head: true }).eq('poste', cle);
  if ((count ?? 0) > 0) return { erreur: 'Ce poste est encore attribué à un membre : change d\u2019abord son poste.' };
  const { error } = await db.from('bureau_postes').delete().eq('cle', cle);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Poste supprimé.' };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/bureau-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/compta-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { enCentimes, estDateIso } from '@/lib/compta/format';
import type { LigneSaisie, Retour } from '@/lib/compta/types';

const REFUS = { erreur: 'Accès refusé.' };

function rafraichir() {
  revalidatePath('/admin/compta', 'layout');
}

/* ------------------------------------------------------------------ */
/* Écritures                                                           */
/* ------------------------------------------------------------------ */

/** Enregistre une écriture équilibrée (contrôles refaits côté base). */
export async function saisirEcriture(p: {
  journal: string;
  date: string;
  libelle: string;
  lignes: LigneSaisie[];
  justificatif?: string | null;
}): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  if (!estDateIso(p.date)) return { erreur: 'Date invalide.' };

  const { data, error } = await supabase.rpc('compta_saisir_ecriture', {
    p_journal: p.journal,
    p_date: p.date,
    p_libelle: p.libelle,
    p_lignes: p.lignes,
    p_justificatif: p.justificatif ?? null,
  });
  if (error) return { erreur: error.message };

  const { data: e } = await supabase.from('compta_ecritures').select('piece').eq('id', data).maybeSingle();
  rafraichir();
  return { ok: `Pièce ${e?.piece ?? ''} enregistrée.`, id: data as string };
}

/** Annule une pièce par une écriture inverse. */
export async function contrepasser(id: string, motif?: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { data, error } = await supabase.rpc('compta_contrepasser', {
    p_ecriture_id: id,
    p_date: null,
    p_motif: motif?.trim() || null,
  });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Pièce annulée par une écriture inverse.', id: data as string };
}

export async function joindreJustificatif(id: string, chemin: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_joindre_justificatif', { p_ecriture_id: id, p_chemin: chemin });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Justificatif joint.' };
}

/* ------------------------------------------------------------------ */
/* Ventes du site                                                      */
/* ------------------------------------------------------------------ */

export async function importerVentes(): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { data, error } = await supabase.rpc('compta_importer_ventes');
  if (error) return { erreur: error.message };
  rafraichir();
  const n = (data as number) ?? 0;
  return { ok: n === 0 ? 'Aucune nouvelle vente à importer.' : `${n} vente(s) importée(s).` };
}

export async function marquerVerifie(id: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_marquer_verifie', { p_ecriture_id: id });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Vente classée.' };
}

/** Réglages d'une source de ventes (admin). */
export async function reglerSource(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const cle = String(fd.get('cle') ?? '');
  const taux = parseFloat(String(fd.get('taux_frais') ?? '0').replace(',', '.'));
  const fixe = enCentimes(String(fd.get('frais_fixe') ?? '0') || '0');
  if (!Number.isFinite(taux) || taux < 0 || taux >= 100) return { erreur: 'Taux de frais invalide.' };
  if (fixe === null) return { erreur: 'Frais fixe invalide.' };

  const { error } = await supabase
    .from('compta_sources')
    .update({ actif: fd.get('actif') === 'on', taux_frais: taux, frais_fixe_centimes: fixe })
    .eq('cle', cle);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Réglages enregistrés.' };
}

/* ------------------------------------------------------------------ */
/* Rapprochement bancaire                                              */
/* ------------------------------------------------------------------ */

export async function pointerLignes(ids: string[], pointe: boolean): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_pointer', { p_ligne_ids: ids, p_pointe: pointe });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Pointage enregistré.' };
}

export async function validerRapprochement(compte: string, date: string, soldeCentimes: number): Promise<Retour> {
  const { supabase, isStaff, user } = await requireAdmin();
  if (!isStaff || !user) return REFUS;
  if (!estDateIso(date)) return { erreur: 'Date de relevé invalide.' };
  const { data: moi } = await supabase.from('admins').select('nom').eq('id', user.id).maybeSingle();
  const { error } = await supabase.from('compta_rapprochements').upsert(
    {
      compte_numero: compte,
      date_releve: date,
      solde_releve_centimes: soldeCentimes,
      valide_par_nom: moi?.nom ?? user.email ?? null,
    },
    { onConflict: 'compte_numero,date_releve' }
  );
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Rapprochement validé.' };
}

/* ------------------------------------------------------------------ */
/* Événements et budgets                                               */
/* ------------------------------------------------------------------ */

export async function enregistrerEvenement(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const id = String(fd.get('id') ?? '');
  const code = String(fd.get('code') ?? '').trim().toUpperCase();
  const libelle = String(fd.get('libelle') ?? '').trim();
  const date = String(fd.get('date_evenement') ?? '');
  const statut = String(fd.get('statut') ?? 'en_cours');
  if (!/^[A-Z0-9-]{2,12}$/.test(code)) return { erreur: 'Code : 2 à 12 lettres, chiffres ou tirets.' };
  if (!libelle) return { erreur: 'Le libellé est obligatoire.' };

  const ligne = { code, libelle, date_evenement: estDateIso(date) ? date : null, statut };
  const { error } = id
    ? await supabase.from('compta_evenements').update(ligne).eq('id', id)
    : await supabase.from('compta_evenements').insert(ligne);
  if (error) return { erreur: error.message.includes('duplicate') ? 'Ce code existe déjà.' : error.message };
  rafraichir();
  return { ok: id ? 'Événement modifié.' : 'Événement créé.' };
}

/**
 * Crée un événement à la volée depuis l'écran de saisie (événement passé ou absent du site).
 * Le code est déduit du libellé ; il reste modifiable dans « Budgets par événement ».
 */
export async function creerEvenementRapide(libelleSaisi: string, date: string): Promise<{
  erreur?: string;
  evenement?: { id: string; code: string; libelle: string; date_evenement: string | null; statut: 'a_venir' | 'en_cours' | 'termine' };
}> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const libelle = libelleSaisi.trim();
  if (libelle.length < 2) return { erreur: 'Le nom de l\u2019événement est obligatoire.' };
  if (date && !estDateIso(date)) return { erreur: 'Date invalide.' };

  // Code : lettres et chiffres du libellé, sans accents, 10 caractères au plus.
  const base =
    libelle.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) || 'EVT';
  const { data: pris } = await supabase.from('compta_evenements').select('code').like('code', `${base.slice(0, 8)}%`);
  const codes = new Set((pris ?? []).map((e) => e.code));
  let code = base;
  for (let n = 2; codes.has(code); n++) code = `${base.slice(0, 8)}-${n}`;

  const jour = new Date().toISOString().slice(0, 10);
  const statut = !date ? 'en_cours' : date < jour ? 'termine' : 'a_venir';
  const { data, error } = await supabase
    .from('compta_evenements')
    .insert({ code, libelle, date_evenement: date || null, statut })
    .select('id, code, libelle, date_evenement, statut')
    .single();
  if (error || !data) return { erreur: error?.message ?? 'Création impossible.' };
  rafraichir();
  return { evenement: data };
}

/** Fixe le montant prévu d'un compte pour un événement (0 retire la ligne). */
export async function enregistrerBudget(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const evt = String(fd.get('compta_evenement_id') ?? '');
  const compte = String(fd.get('compte_numero') ?? '');
  const centimes = enCentimes(String(fd.get('montant') ?? ''));
  if (!evt || !compte) return { erreur: 'Événement et compte obligatoires.' };
  if (centimes === null) return { erreur: 'Montant invalide.' };

  const { error } =
    centimes === 0
      ? await supabase.from('compta_budgets').delete().eq('compta_evenement_id', evt).eq('compte_numero', compte)
      : await supabase
          .from('compta_budgets')
          .upsert(
            { compta_evenement_id: evt, compte_numero: compte, montant_centimes: centimes },
            { onConflict: 'compta_evenement_id,compte_numero' }
          );
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Budget enregistré.' };
}

/* ------------------------------------------------------------------ */
/* Plan comptable et exercices (admin)                                 */
/* ------------------------------------------------------------------ */

export async function enregistrerCompte(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const numero = String(fd.get('numero') ?? '').trim();
  const intitule = String(fd.get('intitule') ?? '').trim();
  const type = String(fd.get('type') ?? '');
  if (!/^[1-7][0-9]{5}$/.test(numero)) return { erreur: 'Numéro de compte : 6 chiffres, classe 1 à 7.' };
  if (!intitule) return { erreur: 'L\u2019intitulé est obligatoire.' };
  if (!['bilan', 'tresorerie', 'charge', 'produit'].includes(type)) return { erreur: 'Type de compte invalide.' };

  const { error } = await supabase.from('compta_comptes').upsert({ numero, intitule, type }, { onConflict: 'numero' });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: `Compte ${numero} enregistré.` };
}

export async function basculerCompte(numero: string, actif: boolean): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const { error } = await supabase.from('compta_comptes').update({ actif }).eq('numero', numero);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Compte mis à jour.' };
}

export async function creerExercice(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const libelle = String(fd.get('libelle') ?? '').trim();
  const debut = String(fd.get('date_debut') ?? '');
  const fin = String(fd.get('date_fin') ?? '');
  if (!libelle || !estDateIso(debut) || !estDateIso(fin) || fin <= debut) {
    return { erreur: 'Libellé et dates obligatoires, la fin après le début.' };
  }
  const { data: chevauche } = await supabase
    .from('compta_exercices').select('libelle').lte('date_debut', fin).gte('date_fin', debut).limit(1);
  if (chevauche && chevauche.length > 0) return { erreur: `Ces dates chevauchent l\u2019exercice ${chevauche[0].libelle}.` };

  const { error } = await supabase.from('compta_exercices').insert({ libelle, date_debut: debut, date_fin: fin });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: `Exercice ${libelle} créé.` };
}

/** Clôture ou réouverture d'un exercice. Un exercice clôturé refuse toute nouvelle écriture. */
export async function basculerExercice(id: string, cloture: boolean): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const { error } = await supabase
    .from('compta_exercices')
    .update({ cloture, cloture_le: cloture ? new Date().toISOString() : null })
    .eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: cloture ? 'Exercice clôturé.' : 'Exercice rouvert.' };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/compta-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/maintenance-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';

export type EtatMaintenance = { ok?: string; erreur?: string } | null;

/** Active ou coupe le mode maintenance. */
export async function basculerMaintenance(actif: boolean) {
  const { supabase, isAdmin } = await requireAdmin('maintenance');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const { error } = await supabase
    .from('site_settings')
    .update({
      maintenance_active: actif,
      maintenance_depuis: actif ? new Date().toISOString() : null,
    })
    .eq('id', 1);

  if (error) return { erreur: error.message };

  revalidatePath('/', 'layout');
  return { ok: actif ? 'Site coupé.' : 'Site remis en ligne.' };
}

/** Enregistre les textes affichés pendant la coupure. */
export async function majTextesMaintenance(
  _prev: EtatMaintenance, fd: FormData
): Promise<EtatMaintenance> {
  const { supabase, isAdmin } = await requireAdmin('maintenance');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const titre = String(fd.get('maintenance_titre') ?? '').trim();
  if (!titre) return { erreur: 'Le titre ne peut pas être vide.' };

  const { error } = await supabase
    .from('site_settings')
    .update({
      maintenance_titre: titre,
      maintenance_message: String(fd.get('maintenance_message') ?? '').trim(),
      maintenance_retour: String(fd.get('maintenance_retour') ?? '').trim() || null,
    })
    .eq('id', 1);

  if (error) return { erreur: error.message };

  revalidatePath('/', 'layout');
  revalidatePath('/admin/maintenance');
  return { ok: 'Textes enregistrés.' };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/maintenance-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import MenuButton from '@/components/MenuButton';
import RetourHaut from '@/components/RetourHaut';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import RoueRentree from '@/components/roue/RoueRentree';
import BandeauPartenaires from '@/components/BandeauPartenaires';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { getThemes } from '@/lib/theme/db';
import { themeDuJour, variablesTheme } from '@/lib/theme/types';
import { BlocTheme, Neige, PastilleTheme } from '@/components/theme/ThemeAccueil';
import { dateCourte, dateLongue, horaires, periode, texteSur } from '@/lib/format';
import type { Partenaire, SiteSettings, Stat, Evenement } from '@/lib/types';

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const [{ data: settings }, { data: stats }, { data: evenements }, wheelConfig, { data: partenaires }, { data: tdn }, { data: pn }, themes] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    supabase.from('stats').select('*').order('position'),
    supabase.from('evenements').select('*').eq('publie', true).order('position'),
    getWheelConfig(),
    supabase.from('partenaires').select('*').eq('actif', true).order('position'),
    supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    getThemes(),
  ]);
  // Module événementiel : rendu côté serveur uniquement si actif et dans la période.
  const showWheel = roueVisible(wheelConfig);

  const s = settings as SiteSettings;
  const evts = (evenements ?? []) as Evenement[];

  // Thème du moment (Octobre Rose, Noël...) : actif et dans sa période, sinon rien ne change.
  const theme = themeDuJour(themes);
  const styleTheme = theme ? (variablesTheme(theme) as React.CSSProperties) : undefined;
  const annonces = evts.map((e) => `${dateCourte(e.date_debut)} · ${e.titre}`);

  return (
    <>
      <MenuButton tresors={tdn?.module_actif === true} pereNoel={pn?.module_actif === true} />
      <RetourHaut />

      <header className={`hero${theme ? ' th' : ''}`} style={styleTheme ?? { ['--evt' as string]: s.hero_couleur }}>
        {theme && <Neige theme={theme} />}
        <div className="hero-inner">
          <div className="logo-badge">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              className="hero-logo"
              src={s.logo_url || '/logo-cdf.png'}
              alt="Comité des Fêtes de Limetz-Villez"
            />
          </div>
          {theme && <PastilleTheme theme={theme} />}
          <div style={{ marginBottom: '2.4rem' }}>
            <span className="kicker mono">{theme?.etiquette || s.hero_kicker}</span>
          </div>
          <h1>
            {s.hero_titre_1} <span className="jaune">{s.hero_titre_accent}</span>
            <br />
            <span className="cyan">{s.hero_titre_2}</span>
          </h1>
          <p className="hero-tag">{s.hero_texte}</p>
          <div className="hero-cta">
            <a className="btn btn-y" href="#evenements">Voir le programme</a>
            <a className="btn btn-w" href="#benevoles">Devenir bénévole</a>
          </div>
        </div>

        <a className="scroll-hint" href="#evenements">
          <span>Faire défiler</span>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3"
               strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </a>
      </header>

      {theme ? (
        <>
          <div className="th-bandeau" style={styleTheme}>
            <Marquee items={theme.bandeau ? [theme.bandeau, ...annonces] : annonces} />
          </div>
          <BlocTheme theme={theme} style={styleTheme} />
        </>
      ) : (
        <Marquee items={annonces} />
      )}

      {showWheel && <RoueRentree config={configRoue(wheelConfig)} />}

      <section id="evenements">
        <div className="wrap">
          <div className="head">
            <h2>Le programme</h2>
            <p>Nos rendez-vous de l&apos;année. Cliquez pour les horaires, le lieu et les inscriptions.</p>
          </div>
          <div className="grid">
            {evts.map((e, i) => {
              const fg = texteSur(e.couleur);
              return (
                <Link
                  key={e.id}
                  href={`/evenements/${e.slug}`}
                  className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                  style={{ background: e.couleur, color: fg }}
                >
                  <span className="num">{String(i + 1).padStart(2, '0')}</span>
                  <div>
                    <div className="when">
                      {periode(e.date_debut, e.date_fin)}{horaires(e.heure_debut, e.heure_fin) && ` · ${horaires(e.heure_debut, e.heure_fin)}`}
                    </div>
                    <h3>{e.titre}</h3>
                    <p>{e.chapo}</p>
                  </div>
                  <span className="price">{e.tarif}</span>
                </Link>
              );
            })}
          </div>
        </div>
        <BandeauPartenaires partenaires={(partenaires ?? []) as Partenaire[]} />
      </section>

      <section className="about" id="association">
        <div className="wrap">
          <div className="head"><h2>{s.asso_titre}</h2></div>
          <div className="about-grid">
            <div>
              {s.asso_texte.split('\n\n').map((p, i) => <p key={i}>{p}</p>)}
            </div>
            <div className="stats">
              {(stats as Stat[] ?? []).map((st) => (
                <div className="stat" key={st.id}>
                  <b>{st.valeur}</b>
                  <span>{st.libelle}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="join" id="benevoles">
        <div className="mono" style={{ marginBottom: '1rem' }}>On a besoin de bras</div>
        <h2>{s.benevoles_titre}</h2>
        <p>{s.benevoles_texte}</p>
        <a className="btn btn-y" href={`mailto:${s.email_contact}`}>Nous contacter</a>
      </section>

      <Footer settings={s} evenements={evts} />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/pere-noel-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { commandeParId, lireReglagesPn, majCommande, referencePn } from '@/lib/pere-noel/db';
import { emailConfirmation, emailVideoPrete } from '@/lib/pere-noel/emails';
import { avancerCommande, traiterFile, verifierVideo } from '@/lib/pere-noel/pipeline';
import type { CommandePn, Sagesse, TonSecret } from '@/lib/pere-noel/types';

export type Etat = { ok?: string; erreur?: string } | null;

const emailValide = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const txt = (fd: FormData, k: string, max = 1200) => String(fd.get(k) ?? '').trim().slice(0, max) || null;

/* =========================================================
   COMMANDE PUBLIQUE + PAIEMENT SUMUP
   ========================================================= */
export async function commander(_prev: Etat, fd: FormData): Promise<Etat> {
  const r = await lireReglagesPn();
  const { isAdmin } = await requireAdmin('pere-noel');
  const modeTest = fd.get('test') === '1' && isAdmin;
  if (!r.commandes_ouvertes && !modeTest) return { erreur: 'Les commandes ne sont pas ouvertes pour le moment.' };

  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const enfant = txt(fd, 'enfant_prenom', 40);
  if (!enfant) return { erreur: 'Le prénom de l’enfant est obligatoire.' };
  if (!emailValide(email)) return { erreur: 'Adresse email invalide.' };
  const age = Number(fd.get('age'));
  const sagesse = (['presque', 'tres_sage', 'le_plus_sage'].includes(String(fd.get('sagesse'))) ? String(fd.get('sagesse')) : 'tres_sage') as Sagesse;
  const ton = (['rigolo', 'tendre', 'serieux'].includes(String(fd.get('ton_secret'))) ? String(fd.get('ton_secret')) : 'rigolo') as TonSecret;
  const genreBrut = String(fd.get('genre') ?? '');
  const genre = genreBrut === 'fille' || genreBrut === 'garcon' ? genreBrut : null;
  const lettre = txt(fd, 'lettre', 1500);
  if (!lettre && !txt(fd, 'cadeaux', 300)) return { erreur: 'Écrivez au moins la lettre de l’enfant ou ce qu’il demande.' };

  const envoiPostal = r.envoi_postal_actif && fd.get('envoi_postal') === 'on';
  const adresse = {
    adresse_nom: txt(fd, 'adresse_nom', 80), adresse_ligne1: txt(fd, 'adresse_ligne1', 120), adresse_ligne2: txt(fd, 'adresse_ligne2', 120),
    adresse_cp: txt(fd, 'adresse_cp', 10), adresse_ville: txt(fd, 'adresse_ville', 80),
  };
  if (envoiPostal && (!adresse.adresse_nom || !adresse.adresse_ligne1 || !adresse.adresse_cp || !adresse.adresse_ville)) {
    return { erreur: 'Adresse postale incomplète (nom, adresse, code postal et ville).' };
  }

  const db = createAdminClient();
  const reference = referencePn();
  const montant = modeTest ? 0 : r.prix_centimes + (envoiPostal ? r.prix_postal_centimes : 0);
  const { data: cmd, error } = await db.from('pn_commandes').insert({
    reference, test: modeTest,
    parent_prenom: txt(fd, 'parent_prenom', 60) ?? '', email,
    enfant_prenom: enfant, prononciation: txt(fd, 'prononciation', 60),
    age: Number.isFinite(age) && age > 0 && age < 18 ? age : null, genre, sagesse,
    lettre, cadeaux: txt(fd, 'cadeaux', 300), fierte: txt(fd, 'fierte', 300), passion: txt(fd, 'passion', 300),
    effort: txt(fd, 'effort', 200), salut: txt(fd, 'salut', 120), secret: txt(fd, 'secret', 500), ton_secret: ton,
    envoi_postal: envoiPostal, ...(envoiPostal ? adresse : {}),
    montant_centimes: montant,
    statut: montant === 0 ? 'payee' : 'en_attente', paye_le: montant === 0 ? new Date().toISOString() : null,
  }).select('*').single();
  if (error || !cmd) { console.error('[pn commander]', error); return { erreur: 'Impossible d’enregistrer la commande.' }; }

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  if (montant === 0) {
    await emailConfirmation(cmd as CommandePn, r);
    redirect(`/pere-noel/commander/retour?ref=${reference}`);
  }

  let url: string | undefined;
  try {
    const checkout = await creerCheckout({
      reference, montantCentimes: montant,
      description: `${reference} · Vidéo du Père Noël pour ${enfant}${envoiPostal ? ' + envoi postal' : ''}`,
      emailClient: email, urlRetour: `${base}/pere-noel/commander/retour?ref=${reference}`,
    });
    await db.from('pn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[pn commander] SumUp', e);
    await db.from('pn_commandes').update({ statut: 'echouee' }).eq('id', cmd.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez dans quelques minutes.' };
  }
  if (!url) return { erreur: 'Le paiement n’a pas pu être initialisé.' };
  redirect(url);
}

/** Synchronise une commande avec SumUp (retour de paiement ou webhook). Déclenche l'email et, si activé, la génération. */
export async function synchroniserCommandePn(reference?: string, checkoutId?: string): Promise<CommandePn | null> {
  const db = createAdminClient();
  const req = db.from('pn_commandes').select('*');
  const { data: cmd } = await (reference ? req.eq('reference', reference) : req.eq('checkout_id', checkoutId!)).maybeSingle();
  if (!cmd) return null;
  if (cmd.statut === 'payee' || !cmd.checkout_id) return cmd as CommandePn;

  try {
    const checkout = await lireCheckout(cmd.checkout_id);
    const corr: Record<string, string> = { PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente' };
    const statut = corr[checkout.status] ?? 'en_attente';
    if (statut === cmd.statut) return cmd as CommandePn;
    const { data: maj } = await db.from('pn_commandes').update({
      statut,
      transaction_code: checkout.transaction_code ?? checkout.transactions?.[0]?.transaction_code ?? null,
      paye_le: statut === 'payee' ? new Date().toISOString() : null,
    }).eq('id', cmd.id).select('*').single();
    if (statut === 'payee' && maj) {
      const r = await lireReglagesPn();
      await emailConfirmation(maj as CommandePn, r);
      if (r.generation_auto) avancerCommande(maj.id).catch((e) => console.error('[pn auto]', e));
    }
    return (maj ?? cmd) as CommandePn;
  } catch (e) {
    console.error('[synchroniserCommandePn]', e);
    return cmd as CommandePn;
  }
}

/** Depuis l'espace famille : si la vidéo est en cours chez HeyGen, on vérifie à chaque visite. */
export async function rafraichirDepuisEspace(id: string) {
  const c = await commandeParId(id);
  if (c && c.gen_statut === 'video') await verifierVideo(id);
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) throw new Error('Accès refusé.');
}
const chemins = () => { revalidatePath('/admin/pere-noel', 'layout'); revalidatePath('/pere-noel', 'layout'); revalidatePath('/'); };

export async function basculerModulePn(actif: boolean) {
  await admin();
  await createAdminClient().from('pn_reglages').update({ module_actif: actif }).eq('id', 1);
  chemins();
}

export async function majReglagesPn(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const num = (k: string, def: number) => { const v = Number(fd.get(k)); return Number.isFinite(v) ? v : def; };
  const expr = String(fd.get('expressivite') ?? 'medium');
  const { error } = await createAdminClient().from('pn_reglages').update({
    titre: String(fd.get('titre') ?? '').trim() || 'Le Père Noël te répond',
    accroche: String(fd.get('accroche') ?? '').trim(),
    prix_centimes: Math.round(num('prix', 12.9) * 100),
    delai_texte: String(fd.get('delai_texte') ?? '').trim() || 'sous 48 h',
    commandes_ouvertes: fd.get('commandes_ouvertes') === 'on',
    generation_auto: fd.get('generation_auto') === 'on',
    relecture_script: fd.get('relecture_script') === 'on',
    image_url: String(fd.get('image_url') ?? '').trim() || null,
    video_demo_url: String(fd.get('video_demo_url') ?? '').trim() || null,
    envoi_postal_actif: fd.get('envoi_postal_actif') === 'on',
    prix_postal_centimes: Math.round(num('prix_postal', 4.9) * 100),
    voice_id: String(fd.get('voice_id') ?? '').trim() || null,
    modele_voix: String(fd.get('modele_voix') ?? '').trim() || 'eleven_multilingual_v2',
    stabilite: num('stabilite', 0.45), similarite: num('similarite', 0.75), style_voix: num('style_voix', 0.3), vitesse: num('vitesse', 0.92),
    expressivite: ['low', 'medium', 'high'].includes(expr) ? expr : 'medium',
    motion_prompt: String(fd.get('motion_prompt') ?? '').trim(),
    duree_cible_sec: Math.min(120, Math.max(30, Math.round(num('duree_cible_sec', 75)))),
    consignes_script: String(fd.get('consignes_script') ?? '').trim(),
    updated_at: new Date().toISOString(),
  }).eq('id', 1);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Réglages enregistrés.' };
}

/** Lance ou reprend la génération (script, audio, vidéo). */
export async function genererCommande(id: string) {
  await admin();
  await avancerCommande(id);
  chemins();
}

/** Valide (ou modifie) le script puis enchaîne audio et vidéo. */
export async function validerScript(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const id = String(fd.get('id') ?? '');
  const script = String(fd.get('script') ?? '').trim();
  const lettre = String(fd.get('lettre_reponse') ?? '').trim();
  const mention = String(fd.get('certificat_mention') ?? '').trim();
  if (!id || script.length < 50) return { erreur: 'Script trop court.' };
  await majCommande(id, { script, lettre_reponse: lettre || null, certificat_mention: mention || null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'audio', erreur: null });
  const c = await avancerCommande(id, { ignorerRelecture: true });
  chemins();
  return c.gen_statut === 'erreur' ? { erreur: c.erreur ?? 'Erreur de génération.' } : { ok: 'Script validé, audio et vidéo lancés.' };
}

/** Régénère le script (le précédent est écrasé), retour en relecture. */
export async function regenererScript(id: string) {
  await admin();
  await majCommande(id, { script: null, lettre_reponse: null, certificat_mention: null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'a_faire', erreur: null });
  await avancerCommande(id);
  chemins();
}

/** Repart de zéro côté vidéo en gardant le script (ex. artefact HeyGen). */
export async function refaireVideo(id: string) {
  await admin();
  await majCommande(id, { heygen_video_id: null, video_url: null, duree_sec: null, email_envoye: false, gen_statut: 'audio', erreur: null });
  await avancerCommande(id, { ignorerRelecture: true });
  chemins();
}

export async function verifierCommande(id: string) {
  await admin();
  await verifierVideo(id);
  chemins();
}

export async function verifierToutes() {
  await admin();
  const res = await traiterFile(10);
  chemins();
  return res;
}

export async function renvoyerEmailVideo(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (c?.video_url) { const ok = await emailVideoPrete(c); if (ok) await majCommande(id, { email_envoye: true }); }
  chemins();
}

export async function marquerPayee(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (!c || c.statut === 'payee') return;
  await majCommande(id, { statut: 'payee', paye_le: new Date().toISOString() });
  const r = await lireReglagesPn();
  await emailConfirmation({ ...c, statut: 'payee' }, r);
  chemins();
}

export async function marquerExpedie(id: string, expedie: boolean) {
  await admin();
  await majCommande(id, { expedie_le: expedie ? new Date().toISOString() : null });
  chemins();
}

export async function supprimerCommande(id: string) {
  await admin();
  await createAdminClient().from('pn_commandes').delete().eq('id', id);
  chemins();
  redirect('/admin/pere-noel');
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/pere-noel-actions.ts"
mkdir -p 'src/app/pere-noel/commander'
cat > 'src/app/pere-noel/commander/page.tsx' <<'EOF_BUREAU_FICHIER'
import Link from 'next/link';
import FormCommande from '@/components/pere-noel/FormCommande';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';

export default async function PageCommander({ searchParams }: { searchParams: Promise<{ test?: string }> }) {
  const [r, { isAdmin }, sp] = await Promise.all([lireReglagesPn(), requireAdmin('pere-noel'), searchParams]);
  const test = sp.test === '1' && isAdmin;
  if (!r.commandes_ouvertes && !test) {
    return (
      <main className="pn-page pn-centre">
        <h1 className="pn-titre">Les commandes ne sont pas ouvertes</h1>
        <p className="pn-l clair">Revenez bientôt, le Père Noël prépare son atelier.</p>
        <Link href="/pere-noel" className="pn-btn ghost">Retour</Link>
      </main>
    );
  }
  return (
    <main className="pn-page">
      <FormCommande prix={r.prix_centimes} test={test} postal={{ actif: r.envoi_postal_actif, prix: r.prix_postal_centimes }} />
    </main>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/pere-noel/commander/page.tsx"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/layout.tsx' <<'EOF_BUREAU_FICHIER'
import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';
import Ciel from '@/components/pere-noel/Ciel';
import './pere-noel.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglagesPn();
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://www.cdf-limetzvillez.fr';
  const titre = r.titre;
  const description = `${r.accroche} Une vraie réponse à sa lettre, en vidéo, avec son prénom. Lettre écrite et certificat d'enfant sage inclus. Une action du Comité des Fêtes.`;
  const images = r.image_url ? [{ url: r.image_url, width: 1080, height: 1920, alt: 'Le Père Noël dans son atelier' }] : [];
  return {
    metadataBase: new URL(base),
    title: `${titre} · Comité des Fêtes`,
    description,
    openGraph: { type: 'website', url: `${base}/pere-noel`, siteName: 'Comité des Fêtes de Limetz-Villez', title: titre, description, images, locale: 'fr_FR' },
    twitter: { card: 'summary_large_image', title: titre, description, images: images.map((i) => i.url) },
  };
}

export default async function PereNoelLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglagesPn();
  if (!r.module_actif) {
    const { isAdmin } = await requireAdmin('pere-noel');
    if (!isAdmin) {
      return (
        <div className="pn">
          <Ciel />
          <main className="pn-page pn-centre" style={{ paddingTop: '20vh' }}>
            <h1 className="pn-titre">{r.titre}</h1>
            <p className="pn-l clair">Ce service n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="pn-btn ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return (
    <div className="pn">
      <Ciel />
      <div className="pn-head">
        <Link href="/pere-noel" className="logo">✦ {r.titre}</Link>
        <Link href="/" className="cdf">Une action du Comité des Fêtes</Link>
      </div>
      {children}
      <div className="pn-foot">Une action du Comité des Fêtes. Les bénéfices financent les événements de l&apos;année. Aucune donnée d&apos;enfant n&apos;est publiée.</div>
    </div>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/pere-noel/layout.tsx"
mkdir -p 'src/app'
cat > 'src/app/pointage-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';

/** Fixe le nombre de personnes arrivées sur une réservation. */
export async function majArrivees(id: string, arrivees: number) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const { data: resa } = await supabase
    .from('reservations')
    .select('places')
    .eq('id', id)
    .maybeSingle();

  if (!resa) return { erreur: 'Réservation introuvable.' };

  const valeur = Math.max(0, Math.min(arrivees, resa.places));

  const { error } = await supabase
    .from('reservations')
    .update({
      places_arrivees: valeur,
      scanne_le: valeur > 0 ? new Date().toISOString() : null,
    })
    .eq('id', id);

  if (error) return { erreur: error.message };

  revalidatePath('/admin/pointage/[id]', 'page');
  revalidatePath('/admin/reservations');
  return { ok: true, arrivees: valeur };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/pointage-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/reservation-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout, genererReference } from '@/lib/sumup';
import { billetHtml, billetTexte, alerteReservationHtml } from '@/lib/emails';

export type EtatResa = { erreur?: string } | null;

/** Champs de l'événement rapatriés avec la réservation, pour l'email. */
const CHAMPS_EVT =
  '*, evenements(titre, slug, date_debut, date_fin, lieu, adresse, heure_debut, heure_fin, couleur)';

/* =========================================================
   PUBLIC — créer une réservation et partir en paiement
   ========================================================= */
export async function reserver(_prev: EtatResa, fd: FormData): Promise<EtatResa> {
  const evenementId = String(fd.get('evenement_id') ?? '');
  const nom         = String(fd.get('nom') ?? '').trim();
  const email       = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone   = String(fd.get('telephone') ?? '').trim();
  const commentaire = String(fd.get('commentaire') ?? '').trim();
  // lignes de tarif : id + quantité, en parallèle
  const tarifIds  = fd.getAll('tarif_id').map(String);
  const tarifQtes = fd.getAll('tarif_qte').map((v) => Number(v) || 0);
  const places    = tarifQtes.reduce((s, q) => s + q, 0);

  if (!nom || nom.length < 2) return { erreur: 'Merci d\u2019indiquer votre nom.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse email invalide.' };
  if (telephone.replace(/[\s.\-()]/g, '').length < 10)
    return { erreur: 'Merci d\u2019indiquer un numéro de téléphone valide.' };
  if (places < 1) return { erreur: 'Choisissez au moins une place.' };

  const db = createAdminClient();

  const { data: evt } = await db
    .from('evenements')
    .select('id, titre, slug, prix_centimes, places_max, places_par_reservation, billetterie_active, cloture_reservations')
    .eq('id', evenementId)
    .maybeSingle();

  if (!evt || !evt.billetterie_active) return { erreur: 'La billetterie est fermée pour cet événement.' };
  if (places > evt.places_par_reservation)
    return { erreur: `Maximum ${evt.places_par_reservation} places par réservation.` };

  if (evt.cloture_reservations && new Date(evt.cloture_reservations) < new Date())
    return { erreur: 'Les réservations sont closes pour cet événement.' };

  // Jauge
  if (evt.places_max !== null) {
    const { data: restantes } = await db.rpc('places_restantes', { evt_id: evt.id });
    if (typeof restantes === 'number' && restantes < places) {
      return {
        erreur: restantes === 0
          ? 'Complet — il ne reste plus de place.'
          : `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}.`,
      };
    }
  }

  // Prix recalculés côté serveur : jamais de confiance au formulaire.
  const { data: grille } = await db
    .from('tarifs')
    .select('id, libelle, prix_centimes')
    .eq('evenement_id', evt.id);

  const lignes: { libelle: string; prix_centimes: number; quantite: number }[] = [];
  let montant = 0;

  tarifIds.forEach((id, i) => {
    const q = tarifQtes[i] ?? 0;
    if (q <= 0) return;
    const t = (grille ?? []).find((x) => x.id === id);
    // « defaut » = événement sans grille, on prend le prix unique
    const libelle = t?.libelle ?? 'Place';
    const prix = t ? t.prix_centimes : evt.prix_centimes;
    lignes.push({ libelle, prix_centimes: prix, quantite: q });
    montant += prix * q;
  });

  if (lignes.length === 0) return { erreur: 'Choisissez au moins une place.' };

  const reference = genererReference();

  // 1. Réservation en attente
  const { data: resa, error: errResa } = await db
    .from('reservations')
    .insert({
      evenement_id: evt.id,
      nom, email,
      telephone: telephone || null,
      commentaire: commentaire || null,
      places,
      montant_centimes: montant,
      reference,
      statut: 'en_attente',
    })
    .select('id')
    .single();

  if (errResa || !resa) {
    console.error('[reserver] insert', errResa);
    return { erreur: 'Impossible de créer la réservation. Réessayez dans un instant.' };
  }

  // 1 bis. Détail des tarifs
  await db.from('reservation_lignes').insert(
    lignes.map((l) => ({ reservation_id: resa.id, ...l }))
  );

  // 2. Checkout SumUp
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let urlPaiement: string | undefined;

  try {
    const checkout = await creerCheckout({
      reference,
      montantCentimes: montant,
      description: `${reference} · ${nom} · ${evt.titre} · ${places} place${places > 1 ? 's' : ''}`,
      emailClient: email,
      urlRetour: `${base}/evenements/${evt.slug}/reservation?ref=${reference}`,
    });

    await db.from('reservations')
      .update({ checkout_id: checkout.id })
      .eq('id', resa.id);

    urlPaiement = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[reserver] SumUp', e);
    await db.from('reservations')
      .update({ statut: 'echouee' })
      .eq('id', resa.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez plus tard.' };
  }

  if (!urlPaiement) return { erreur: 'Le paiement n\u2019a pas pu être initialisé.' };

  redirect(urlPaiement);
}

/* =========================================================
   Vérification au retour de paiement
   ========================================================= */
export async function verifierPaiement(reference: string) {
  const db = createAdminClient();

  const { data: resa } = await db
    .from('reservations')
    .select(CHAMPS_EVT)
    .eq('reference', reference)
    .maybeSingle();

  if (!resa) return null;
  if (resa.statut === 'payee' || !resa.checkout_id) return resa;

  try {
    const checkout = await lireCheckout(resa.checkout_id);

    const correspondance: Record<string, string> = {
      PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente',
    };
    const nouveau = correspondance[checkout.status] ?? 'en_attente';

    if (nouveau !== resa.statut) {
      const { data: maj } = await db
        .from('reservations')
        .update({
          statut: nouveau,
          transaction_code: checkout.transaction_code
            ?? checkout.transactions?.[0]?.transaction_code
            ?? null,
          paye_le: nouveau === 'payee' ? new Date().toISOString() : null,
        })
        .eq('id', resa.id)
        .select(CHAMPS_EVT)
        .single();

      if (nouveau === 'payee') await envoyerBillet(maj);
      return maj ?? resa;
    }
  } catch (e) {
    console.error('[verifierPaiement]', e);
  }

  return resa;
}

/* =========================================================
   Emails — billet au client et alerte au comité.
   Silencieux si RESEND_API_KEY n'est pas configurée :
   la réservation reste valide, seul l'envoi est désactivé.
   ========================================================= */
export async function envoyerBillet(resa: any, alerterComite = true) {
  if (!process.env.RESEND_API_KEY || !resa) return;

  const evt = resa.evenements ?? {};
  const from = process.env.RESEND_FROM_EMAIL
    ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const urlSite = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://cdf-limetzvillez.fr';

  const donnees = {
    nom: resa.nom,
    places: resa.places,
    montant_centimes: resa.montant_centimes,
    code_billet: resa.code_billet,
    reference: resa.reference,
    commentaire: resa.commentaire,
    evenement: {
      titre: evt.titre ?? 'Comité des Fêtes',
      date_debut: evt.date_debut,
      date_fin: evt.date_fin,
      heure_debut: evt.heure_debut,
      heure_fin: evt.heure_fin,
      lieu: evt.lieu,
      adresse: evt.adresse,
      couleur: evt.couleur,
      slug: evt.slug,
    },
  };

  const envoyer = (corps: Record<string, unknown>) =>
    fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(corps),
    });

  // --- billet au client (les réservations saisies à la main peuvent ne pas avoir d'e-mail) ---
  if (resa.email) {
    try {
      const r = await envoyer({
        from,
        to: [resa.email],
        reply_to: process.env.CONTACT_EMAIL,
        subject: `Votre billet — ${donnees.evenement.titre}`,
        html: billetHtml(donnees, urlSite),
        text: billetTexte(donnees),
      });
      if (!r.ok) console.error('[envoyerBillet] client', r.status, await r.text());
    } catch (e) {
      console.error('[envoyerBillet] client', e);
    }
  }

  // --- alerte au comité ---
  if (alerterComite && process.env.CONTACT_EMAIL) {
    try {
      const r = await envoyer({
        from,
        to: [process.env.CONTACT_EMAIL],
        reply_to: resa.email ?? undefined,
        subject: `Réservation : ${resa.nom} — ${donnees.evenement.titre}`,
        html: alerteReservationHtml(donnees),
      });
      if (!r.ok) console.error('[envoyerBillet] comité', r.status, await r.text());
    } catch (e) {
      console.error('[envoyerBillet] comité', e);
    }
  }
}

/* =========================================================
   ADMIN
   ========================================================= */
export async function marquerScanne(id: string) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;
  await supabase.from('reservations')
    .update({ scanne_le: new Date().toISOString() })
    .eq('id', id);
  revalidatePath('/admin/reservations');
}

export async function changerStatutResa(id: string, statut: string): Promise<{ erreur?: string } | void> {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;

  const maj: Record<string, unknown> = { statut };
  if (statut === 'payee') {
    const { data: resa } = await supabase
      .from('reservations').select('paye_le, checkout_id').eq('id', id).maybeSingle();
    if (resa && !resa.paye_le) {
      // Sans paiement en ligne, le mode (espèces ou chèque) doit être indiqué.
      if (!resa.checkout_id) {
        return { erreur: 'Paiement hors ligne : utilise le bouton « Encaisser » pour indiquer espèces ou chèque.' };
      }
      maj.paye_le = new Date().toISOString();
    }
  }

  const { error } = await supabase.from('reservations').update(maj).eq('id', id);
  if (error) return { erreur: error.message };
  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
}

export async function supprimerReservation(id: string) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;
  await supabase.from('reservations').delete().eq('id', id);
  revalidatePath('/admin/reservations');
}

/** Admin : force une vérification auprès de SumUp pour une réservation (ou toutes celles en attente). */
export async function verifierSumUpAdmin(reference?: string): Promise<{ verifiees: number; changees: number; erreur?: string }> {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { verifiees: 0, changees: 0, erreur: 'Accès refusé.' };
  let refs: string[] = [];
  if (reference) refs = [reference];
  else {
    const { data } = await supabase.from('reservations').select('reference').eq('statut', 'en_attente').not('checkout_id', 'is', null);
    refs = (data ?? []).map((r) => r.reference);
  }
  let changees = 0;
  for (const ref of refs) {
    const db = createAdminClient();
    const { data: avant } = await db.from('reservations').select('statut').eq('reference', ref).maybeSingle();
    const apres = await verifierPaiement(ref);
    if (apres && avant && apres.statut !== avant.statut) changees++;
  }
  revalidatePath('/admin/reservations');
  return { verifiees: refs.length, changees };
}

/* =========================================================
   ADMIN — réservation saisie à la main, paiement hors ligne
   ========================================================= */
export type EtatManuel = { ok?: string; erreur?: string } | null;

const MODES_HORS_LIGNE = ['especes', 'cheque'];

/** « 25 », « 25,5 » ou « 25.50 » -> centimes. null si la saisie est invalide. */
function centimes(saisie: string): number | null {
  const propre = saisie.replace(/[\s\u00a0\u202f€]/g, '').replace(',', '.');
  if (!/^\d+(\.\d{1,2})?$/.test(propre)) return null;
  return Math.round(parseFloat(propre) * 100);
}

/** Explique l'erreur quand les colonnes de paiement n'ont pas encore été créées. */
function erreurBase(message: string): string {
  return /mode_paiement|paiement_ref|saisie_par|exposant/.test(message)
    ? 'La base n\u2019est pas à jour : exécute supabase/comptabilite.sql dans Supabase, puis réessaie.'
    : message;
}

/**
 * Ajoute un participant ou un exposant depuis l'admin,
 * payé en espèces, par chèque, ou pas encore payé.
 */
export async function ajouterReservationManuelle(_prev: EtatManuel, fd: FormData): Promise<EtatManuel> {
  const { supabase, isAdmin, user } = await requireAdmin('reservations');
  if (!isAdmin || !user) return { erreur: 'Accès refusé.' };

  const evenementId = String(fd.get('evenement_id') ?? '');
  const nom         = String(fd.get('nom') ?? '').trim();
  const email       = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone   = String(fd.get('telephone') ?? '').trim();
  const commentaire = String(fd.get('commentaire') ?? '').trim();
  const exposant    = fd.get('type') === 'exposant';
  const paiement    = String(fd.get('paiement') ?? 'attente'); // especes | cheque | attente
  const paiementRef = String(fd.get('paiement_ref') ?? '').trim();
  const montantTxt  = String(fd.get('montant') ?? '').trim();
  const tarifIds    = fd.getAll('tarif_id').map(String);
  const tarifQtes   = fd.getAll('tarif_qte').map((v) => Math.max(0, Math.floor(Number(v) || 0)));
  const quantite    = tarifQtes.reduce((s, q) => s + q, 0);
  // Un exposant compte pour une seule présence au pointage, quelles que soient ses formules.
  const places      = exposant ? 1 : quantite;
  const rien        = exposant ? 'Choisis au moins une formule.' : 'Indique au moins une place.';

  if (nom.length < 2) return { erreur: 'Le nom est obligatoire.' };
  if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (quantite < 1) return { erreur: rien };
  if (paiement !== 'attente' && !MODES_HORS_LIGNE.includes(paiement)) return { erreur: 'Mode de paiement invalide.' };

  const db = createAdminClient();

  const { data: evt } = await db
    .from('evenements').select('id, titre, prix_centimes, places_max').eq('id', evenementId).maybeSingle();
  if (!evt) return { erreur: 'Événement introuvable.' };

  // Jauge : bloquante, sauf dépassement demandé explicitement. Elle ne concerne pas les exposants.
  if (!exposant && evt.places_max !== null && fd.get('depasser') !== 'on') {
    const { data: restantes } = await db.rpc('places_restantes', { evt_id: evt.id });
    if (typeof restantes === 'number' && restantes < places) {
      return {
        erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Coche « Autoriser le dépassement de la jauge » pour l\u2019ajouter quand même.`,
      };
    }
  }

  // Participants : grille de tarifs de l'événement. Exposants : formules exposants.
  const { data: grille } = await db
    .from(exposant ? 'formules_exposants' : 'tarifs')
    .select('id, libelle, prix_centimes')
    .eq('evenement_id', evt.id);
  const lignes: { libelle: string; prix_centimes: number; quantite: number }[] = [];
  let montant = 0;
  tarifIds.forEach((id, i) => {
    const q = tarifQtes[i] ?? 0;
    if (q <= 0) return;
    const t = (grille ?? []).find((x) => x.id === id);
    // Sans grille : prix unique de l'événement, ou emplacement à prix libre pour un exposant.
    const prix = t ? t.prix_centimes : exposant ? 0 : evt.prix_centimes ?? 0;
    lignes.push({ libelle: t?.libelle ?? (exposant ? 'Emplacement' : 'Place'), prix_centimes: prix, quantite: q });
    montant += prix * q;
  });
  if (lignes.length === 0) return { erreur: rien };

  // Montant encaissé : celui du formulaire s'il a été modifié (tarif spécial, invitation à 0).
  if (montantTxt !== '') {
    const saisi = centimes(montantTxt);
    if (saisi === null) return { erreur: 'Montant invalide.' };
    montant = saisi;
  }

  const { data: moi } = await supabase.from('admins').select('nom').eq('id', user.id).maybeSingle();
  const paye = paiement !== 'attente';

  const { data: resa, error } = await db
    .from('reservations')
    .insert({
      evenement_id: evt.id,
      nom,
      email: email || null,
      telephone: telephone || null,
      commentaire: commentaire || null,
      places,
      montant_centimes: montant,
      reference: genererReference(),
      statut: paye ? 'payee' : 'en_attente',
      paye_le: paye ? new Date().toISOString() : null,
      mode_paiement: paye ? paiement : null,
      paiement_ref: paye && paiementRef ? paiementRef : null,
      saisie_par: moi?.nom ?? user.email ?? 'Admin',
      // La colonne n'est envoyée que pour un exposant : les participants ne dépendent pas d'elle.
      ...(exposant ? { exposant: true } : {}),
    })
    .select(CHAMPS_EVT)
    .single();

  if (error || !resa) {
    console.error('[ajouterReservationManuelle]', error);
    return { erreur: erreurBase(error?.message ?? 'Impossible de créer la réservation.') };
  }

  await db.from('reservation_lignes').insert(lignes.map((l) => ({ reservation_id: resa.id, ...l })));

  // Le billet d'entrée n'a pas de sens pour un exposant.
  if (!exposant && paye && email && fd.get('envoyer_billet') === 'on') await envoyerBillet(resa, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  const quoi = exposant ? 'exposant ajouté' : `ajouté, ${places} place${places > 1 ? 's' : ''}`;
  return {
    ok: `${nom} : ${quoi}, code ${resa.code_billet}. ${paye ? 'Paiement enregistré.' : 'Paiement en attente.'}`,
  };
}

/** Enregistre le paiement en espèces ou par chèque d'une réservation non payée. */
export async function encaisserReservation(id: string, mode: string, ref?: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  if (!MODES_HORS_LIGNE.includes(mode)) return { erreur: 'Mode de paiement invalide.' };

  const db = createAdminClient();
  const { data: resa } = await db.from('reservations').select('id, statut').eq('id', id).maybeSingle();
  if (!resa) return { erreur: 'Réservation introuvable.' };
  if (resa.statut === 'payee') return { erreur: 'Cette réservation est déjà payée.' };

  const { data: maj, error } = await db
    .from('reservations')
    .update({
      statut: 'payee',
      paye_le: new Date().toISOString(),
      mode_paiement: mode,
      paiement_ref: ref?.trim() || null,
    })
    .eq('id', id)
    .select(CHAMPS_EVT)
    .single();
  if (error) return { erreur: erreurBase(error.message) };

  if (maj?.email && !maj.exposant) await envoyerBillet(maj, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  return { ok: true };
}

/* =========================================================
   ADMIN — formules proposées aux exposants d'un événement
   ========================================================= */
export async function ajouterFormuleExposant(evenementId: string, libelle: string, prix: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const nom = libelle.trim();
  const prixCentimes = centimes(prix.trim() || '0');
  if (!evenementId) return { erreur: 'Choisis un événement.' };
  if (nom.length < 2) return { erreur: 'Le libellé de la formule est obligatoire.' };
  if (prixCentimes === null) return { erreur: 'Prix invalide.' };

  const db = createAdminClient();
  const { count } = await db
    .from('formules_exposants').select('id', { count: 'exact', head: true }).eq('evenement_id', evenementId);
  const { error } = await db.from('formules_exposants').insert({
    evenement_id: evenementId, libelle: nom, prix_centimes: prixCentimes, position: (count ?? 0) + 1,
  });
  if (error) {
    return {
      erreur: /formules_exposants/.test(error.message)
        ? 'La base n\u2019est pas à jour : exécute supabase/comptabilite.sql dans Supabase, puis réessaie.'
        : error.message,
    };
  }
  revalidatePath('/admin/reservations');
  return { ok: true };
}

/** Retire une formule. Les réservations déjà saisies gardent leur détail. */
export async function supprimerFormuleExposant(id: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const { error } = await createAdminClient().from('formules_exposants').delete().eq('id', id);
  if (error) return { erreur: error.message };
  revalidatePath('/admin/reservations');
  return { ok: true };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/reservation-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/roue-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { createHash } from 'crypto';
import { cookies, headers } from 'next/headers';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { NB_SEGMENTS, SEGMENTS_GAGNANTS, type LotRoue } from '@/lib/roue/types';

export type EtatRoue = { ok?: string; erreur?: string; annule?: string } | null;

const COOKIE = 'roue_joueur';
const MAX_PAR_IP = 15; // garde-fou contre les cookies effacés en boucle

function jourParis() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
}

function codeGagnant() {
  const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 5; i++) s += a[Math.floor(Math.random() * a.length)];
  return `RR-${s}`;
}

async function joueurId() {
  const jar = await cookies();
  let id = jar.get(COOKIE)?.value;
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) {
    id = crypto.randomUUID();
    jar.set(COOKIE, id, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: 60 * 60 * 24 * 90, path: '/' });
  }
  return id;
}

async function ipHash() {
  const h = await headers();
  const ip = (h.get('x-forwarded-for') ?? '').split(',')[0].trim() || h.get('x-real-ip') || '';
  return ip ? createHash('sha256').update(ip + (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').slice(0, 8)).digest('hex').slice(0, 32) : null;
}

/** Tirage : taux de gain, puis lot pondéré parmi ceux qui ont encore du stock. Ne modifie rien en base. */
async function tirer(tauxGain: number) {
  const db = createAdminClient();
  let lot: LotRoue | null = null;
  if (Math.random() * 100 < tauxGain) {
    const { data: lots } = await db.from('roue_lots').select('*').eq('actif', true).gt('stock', 0);
    const { data: attribs } = await db.from('roue_participations').select('lot_id').not('lot_id', 'is', null).is('annulee_le', null);
    const pris: Record<string, number> = {};
    for (const a of attribs ?? []) pris[a.lot_id!] = (pris[a.lot_id!] ?? 0) + 1;
    const dispo = ((lots ?? []) as LotRoue[]).filter((l) => l.stock - (pris[l.id] ?? 0) > 0);
    const total = dispo.reduce((s, l) => s + Math.max(l.poids, 0), 0);
    if (total > 0) {
      let r = Math.random() * total;
      for (const l of dispo) { r -= Math.max(l.poids, 0); if (r <= 0) { lot = l; break; } }
      lot ??= dispo[dispo.length - 1];
    }
  }
  const gagne = !!lot;
  const pool = gagne ? SEGMENTS_GAGNANTS : Array.from({ length: NB_SEGMENTS }, (_, i) => i).filter((i) => !SEGMENTS_GAGNANTS.includes(i));
  return { lot, gagne, segment: pool[Math.floor(Math.random() * pool.length)] };
}

export type ResultatTour =
  | { statut: 'ok'; participationId: string; gagne: boolean; segment: number; lot?: { nom: string; description: string | null }; code?: string }
  | { statut: 'deja_joue'; message: string }
  | { statut: 'ferme'; message: string }
  | { statut: 'erreur'; message: string };

const DELAI_RECLAMATION_MIN = 30;

/** Annule les gains non réclamés depuis plus de 30 min : le lot retourne dans le stock. */
async function purgerGainsNonReclames() {
  const db = createAdminClient();
  const limite = new Date(Date.now() - DELAI_RECLAMATION_MIN * 60 * 1000).toISOString();
  await db.from('roue_participations')
    .update({ lot_id: null, annulee_le: new Date().toISOString(), motif_annulation: 'Non réclamé : coordonnées non renseignées dans les 30 minutes' })
    .eq('gagne', true).is('reclame_le', null).is('annulee_le', null).lt('created_at', limite);
}

/** Le joueur a-t-il déjà utilisé ses tours du jour ? (pour ne pas rouvrir le pop-up) */
export async function statutJoueur(): Promise<{ peutJouer: boolean }> {
  const module = await getWheelConfig();
  if (!roueVisible(module)) return { peutJouer: false };
  const jar = await cookies();
  const id = jar.get(COOKIE)?.value;
  if (!id) return { peutJouer: true };
  const db = createAdminClient();
  const { count } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('joueur_id', id).eq('jour', jourParis());
  return { peutJouer: (count ?? 0) < configRoue(module).participations_par_jour };
}

/** Un tour de roue. Tout est décidé ici : le navigateur ne fait qu'animer. */
export async function jouer(): Promise<ResultatTour> {
  const module = await getWheelConfig();
  if (!roueVisible(module)) return { statut: 'ferme', message: 'La roue n’est pas disponible pour le moment.' };
  const cfg = configRoue(module);
  const db = createAdminClient();
  await purgerGainsNonReclames();
  const id = await joueurId();
  const ip = await ipHash();
  const jour = jourParis();

  const { count: dejaJoueur } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('joueur_id', id).eq('jour', jour);
  if ((dejaJoueur ?? 0) >= cfg.participations_par_jour) {
    return { statut: 'deja_joue', message: cfg.participations_par_jour > 1 ? `Vous avez déjà joué ${cfg.participations_par_jour} fois aujourd’hui. À demain !` : 'Vous avez déjà joué aujourd’hui. Revenez demain !' };
  }
  if (ip) {
    const { count: dejaIp } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('ip_hash', ip).eq('jour', jour);
    if ((dejaIp ?? 0) >= MAX_PAR_IP) return { statut: 'deja_joue', message: 'Trop de participations depuis cette connexion aujourd’hui.' };
  }

  // Un joueur qui a déjà gagné son quota de lots continue de jouer, mais ne peut plus gagner.
  let tauxGain = cfg.taux_gain;
  if (cfg.lots_max_par_joueur > 0) {
    const { count: dejaGagne } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('joueur_id', id).eq('gagne', true);
    if ((dejaGagne ?? 0) >= cfg.lots_max_par_joueur) tauxGain = 0;
  }
  const { lot, gagne, segment } = await tirer(tauxGain);

  let code: string | null = null;
  let inserted: { id: string } | null = null;
  for (let essai = 0; essai < 5 && !inserted; essai++) {
    code = gagne ? codeGagnant() : null;
    const { data, error } = await db.from('roue_participations').insert({ joueur_id: id, ip_hash: ip, jour, gagne, lot_id: lot?.id ?? null, code }).select('id').single();
    if (!error && data) inserted = data;
    else if (error?.code !== '23505') { console.error('[roue] insert', error); return { statut: 'erreur', message: 'Impossible d’enregistrer votre participation.' }; }
  }
  if (!inserted) return { statut: 'erreur', message: 'Réessayez dans un instant.' };

  return gagne
    ? { statut: 'ok', participationId: inserted.id, gagne: true, segment, lot: { nom: lot!.nom, description: lot!.description }, code: code! }
    : { statut: 'ok', participationId: inserted.id, gagne: false, segment };
}

const normTel = (t: string) => t.replace(/[\s.\-()]/g, '').replace(/^\+33/, '0');

/**
 * Le gagnant laisse ses coordonnées. Si la même personne (e-mail ou téléphone) a déjà
 * réclamé un gain aujourd'hui depuis un autre appareil, ce gain est annulé et le lot remis en jeu.
 */
export async function reclamer(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const participationId = String(fd.get('participation_id') ?? '');
  const prenom = String(fd.get('prenom') ?? '').trim();
  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone = normTel(String(fd.get('telephone') ?? ''));
  if (!prenom || !nom) return { erreur: 'Indiquez votre prénom et votre nom.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (telephone.length < 10) return { erreur: 'Numéro de téléphone invalide.' };
  const id = await joueurId();
  const db = createAdminClient();

  const { data: part } = await db.from('roue_participations').select('id, jour, gagne, reclame_le, annulee_le').eq('id', participationId).eq('joueur_id', id).eq('gagne', true).maybeSingle();
  if (!part) return { erreur: 'Participation introuvable.' };
  if (part.reclame_le) return { ok: 'Vos coordonnées sont déjà enregistrées.' };
  if (part.annulee_le) return { annule: 'Ce gain a expiré : les coordonnées devaient être renseignées dans les 30 minutes. Le lot est remis en jeu, revenez demain !' };

  // Même personne, même jour, déjà réclamé ?
  const { data: doublon } = await db.from('roue_participations').select('id')
    .eq('jour', part.jour).neq('id', part.id).not('reclame_le', 'is', null)
    .or(`email.eq.${email},telephone.eq.${telephone}`).limit(1).maybeSingle();

  const maintenant = new Date().toISOString();
  if (doublon) {
    await db.from('roue_participations').update({
      prenom, nom, email, telephone, reclame_le: maintenant, lot_id: null,
      annulee_le: maintenant, motif_annulation: 'Doublon : a déjà joué aujourd’hui sur un autre appareil',
    }).eq('id', part.id);
    return { annule: 'Vous avez déjà joué aujourd’hui sur un autre appareil. Ce lot est remis en jeu : la participation est limitée à une par jour et par personne. Revenez demain !' };
  }

  const { error } = await db.from('roue_participations').update({ prenom, nom, email, telephone, reclame_le: maintenant }).eq('id', part.id);
  if (error) return { erreur: 'Enregistrement impossible.' };
  return { ok: 'C’est noté ! Gardez votre code précieusement.' };
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { supabase, isAdmin } = await requireAdmin('roue');
  if (!isAdmin) throw new Error('Accès refusé.');
  return supabase;
}
const rafraichir = () => { revalidatePath('/'); revalidatePath('/admin/roue', 'layout'); };

export async function basculerRoue(active: boolean): Promise<EtatRoue> {
  const sb = await admin();
  const { error } = await sb.from('homepage_modules').update({ is_active: active }).eq('module_key', 'roue_rentree');
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: active ? '✓ La Roue de la Rentrée est activée.' : '✓ La Roue de la Rentrée a été désactivée.' };
}

/** Convertit un datetime-local (heure de Paris) en ISO. */
function isoParis(v: string) {
  if (!v) return null;
  // datetime-local sans fuseau : on le considère en heure de Paris.
  const d = new Date(v);
  const paris = new Date(d.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const decalage = d.getTime() - paris.getTime();
  return new Date(d.getTime() + decalage).toISOString();
}

export async function majModuleRoue(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const sb = await admin();
  const config = {
    titre: String(fd.get('titre') ?? '').trim(),
    accroche: String(fd.get('accroche') ?? '').trim(),
    periode_texte: String(fd.get('periode_texte') ?? '').trim(),
    participations_par_jour: Math.max(1, Number(fd.get('participations_par_jour') ?? 1)),
    lots_max_par_joueur: Math.max(0, Number(fd.get('lots_max_par_joueur') ?? 1)),
    taux_gain: Math.min(100, Math.max(0, Number(fd.get('taux_gain') ?? 12))),
    pancarte: String(fd.get('pancarte') ?? '').trim().slice(0, 40),
    message_gagne: String(fd.get('message_gagne') ?? '').trim(),
    message_perdu: String(fd.get('message_perdu') ?? '').trim(),
  };
  const { error } = await sb.from('homepage_modules').update({
    is_active: fd.get('is_active') === 'on',
    start_date: isoParis(String(fd.get('start_date') ?? '')),
    end_date: isoParis(String(fd.get('end_date') ?? '')),
    config,
  }).eq('module_key', 'roue_rentree');
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Paramètres enregistrés.' };
}

export async function enregistrerLotRoue(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = {
    nom: String(fd.get('nom') ?? '').trim(),
    description: String(fd.get('description') ?? '').trim() || null,
    stock: Math.max(0, Number(fd.get('stock') ?? 1)),
    poids: Math.max(0, Number(fd.get('poids') ?? 1)),
    actif: fd.get('actif') === 'on',
    position: Number(fd.get('position') ?? 0),
  };
  if (!data.nom) return { erreur: 'Nom du lot obligatoire.' };
  const { error } = id ? await sb.from('roue_lots').update(data).eq('id', id) : await sb.from('roue_lots').insert(data);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Lot enregistré.' };
}

export async function supprimerLotRoue(id: string) {
  const sb = await admin();
  await sb.from('roue_lots').delete().eq('id', id);
  rafraichir();
}

/** Tour d'essai depuis l'admin : même tirage, rien n'est enregistré, aucun stock consommé. */
export async function jouerTest(): Promise<ResultatTour> {
  await admin();
  const cfg = configRoue(await getWheelConfig());
  const { lot, gagne, segment } = await tirer(cfg.taux_gain);
  return gagne
    ? { statut: 'ok', participationId: 'test', gagne: true, segment, lot: { nom: lot!.nom, description: lot!.description }, code: 'RR-TEST' }
    : { statut: 'ok', participationId: 'test', gagne: false, segment };
}

/** Appelé par la page admin pour appliquer la purge avant affichage. */
export async function purgerGainsAdmin() { await admin(); await purgerGainsNonReclames(); }

export async function marquerRetire(id: string, retire: boolean) {
  const sb = await admin();
  await sb.from('roue_participations').update({ retire_le: retire ? new Date().toISOString() : null }).eq('id', id);
  rafraichir();
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/roue-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/theme-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { CLE_MODULE, getThemes } from '@/lib/theme/db';
import { COULEUR_VALIDE, MOTIFS, type MotifTheme, type ThemeAccueil } from '@/lib/theme/types';

export type EtatThemeForm = { ok?: string; erreur?: string } | null;

const DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Enregistre la liste complète des thèmes (la ligne du module est créée au premier usage). */
async function ecrire(themes: ThemeAccueil[]): Promise<string | null> {
  const db = createAdminClient();
  const { data: ligne } = await db.from('homepage_modules').select('id').eq('module_key', CLE_MODULE).maybeSingle();
  const { error } = ligne
    ? await db.from('homepage_modules').update({ config: { themes } }).eq('id', ligne.id)
    : await db.from('homepage_modules').insert({ module_key: CLE_MODULE, is_active: true, config: { themes } });
  if (error) return error.message;
  revalidatePath('/');
  revalidatePath('/admin/theme');
  return null;
}

/** Ajoute un thème ou modifie celui dont l'identifiant est fourni. */
export async function enregistrerTheme(_prev: EtatThemeForm, fd: FormData): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin('theme');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const texte = (cle: string, max: number) => String(fd.get(cle) ?? '').trim().slice(0, max);
  const id = texte('id', 60);
  const theme: ThemeAccueil = {
    id: id || `t-${Date.now().toString(36)}`,
    nom: texte('nom', 40),
    couleur: texte('couleur', 7),
    motif: (texte('motif', 10) in MOTIFS ? texte('motif', 10) : 'aucun') as MotifTheme,
    etiquette: texte('etiquette', 60),
    bandeau: texte('bandeau', 80),
    titre: texte('titre', 90),
    texte: texte('texte', 400),
    bouton: texte('bouton', 30),
    lien: texte('lien', 300),
    debut: texte('debut', 10),
    fin: texte('fin', 10),
    actif: fd.get('actif') === 'on',
  };

  if (theme.nom.length < 2) return { erreur: 'Le nom du thème est obligatoire.' };
  if (!COULEUR_VALIDE.test(theme.couleur)) return { erreur: 'Couleur invalide : format attendu #RRGGBB.' };
  if (!DATE.test(theme.debut) || !DATE.test(theme.fin)) return { erreur: 'Les deux dates sont obligatoires.' };
  if (theme.fin < theme.debut) return { erreur: 'La date de fin est avant la date de début.' };
  if (theme.lien && !/^(https?:\/\/|\/)/.test(theme.lien)) {
    return { erreur: 'Le lien doit commencer par https:// ou par / pour une page du site.' };
  }

  const themes = await getThemes();
  const suite = themes.some((t) => t.id === theme.id)
    ? themes.map((t) => (t.id === theme.id ? theme : t))
    : [...themes, theme];
  suite.sort((a, b) => a.debut.localeCompare(b.debut));

  const erreur = await ecrire(suite);
  if (erreur) return { erreur };
  return { ok: id ? `Thème « ${theme.nom} » modifié.` : `Thème « ${theme.nom} » ajouté.` };
}

export async function basculerTheme(id: string, actif: boolean): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin('theme');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const themes = await getThemes();
  const erreur = await ecrire(themes.map((t) => (t.id === id ? { ...t, actif } : t)));
  return erreur ? { erreur } : { ok: actif ? 'Thème activé.' : 'Thème désactivé.' };
}

export async function supprimerTheme(id: string): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin('theme');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const themes = await getThemes();
  const erreur = await ecrire(themes.filter((t) => t.id !== id));
  return erreur ? { erreur } : { ok: 'Thème supprimé.' };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/theme-actions.ts"
mkdir -p 'src/app'
cat > 'src/app/tresors-actions.ts' <<'EOF_BUREAU_FICHIER'
'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { COOKIE_ACTIF, COOKIE_TOKEN, compteCourant, jeuOuvert, lireMissions, lireReglages, placesPrises } from '@/lib/tresors/db';
import type { Categorie, Cle, Lot, Mission, Bloc } from '@/lib/tresors/types';
import { numeroCle } from '@/lib/tresors/types';

export type Etat = { ok?: string; erreur?: string } | null;

const UN_AN = 60 * 60 * 24 * 365;
const normaliser = (s: string) => s.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ');
const emailValide = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);

async function poserCookieToken(token: string) {
  const jar = await cookies();
  jar.set(COOKIE_TOKEN, token, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: UN_AN, path: '/' });
}

function genererCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 4; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return `NOEL-${s}`;
}

function referenceCommande() {
  const bloc = () => Math.random().toString(36).slice(2, 8).toUpperCase();
  return `TDN-${bloc()}-${bloc().slice(0, 4)}`;
}

/* =========================================================
   INSCRIPTION + PAIEMENT SUMUP
   ========================================================= */
export async function inscrire(_prev: Etat, fd: FormData): Promise<Etat> {
  const reglages = await lireReglages();
  if (!reglages.inscriptions_ouvertes) return { erreur: 'Les inscriptions sont fermées.' };

  const prenom = String(fd.get('prenom') ?? '').trim();
  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone = String(fd.get('telephone') ?? '').trim();
  const prenoms = fd.getAll('participant_prenom').map((v) => String(v).trim());
  const categories = fd.getAll('participant_categorie').map((v) => String(v) as Categorie);

  if (!prenom || !nom) return { erreur: 'Prénom et nom du responsable obligatoires.' };
  if (!emailValide(email)) return { erreur: 'Adresse e-mail invalide.' };
  const lignes = prenoms.map((p, i) => ({ prenom: p, categorie: categories[i] === 'adulte' ? 'adulte' : 'enfant' as Categorie })).filter((l) => l.prenom);
  if (lignes.length === 0) return { erreur: 'Ajoutez au moins un participant.' };
  const restantes = reglages.places_max - (await placesPrises());
  if (restantes <= 0) return { erreur: 'Complet : toutes les places ont été réservées.' };
  if (lignes.length > restantes) return { erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Réduisez le nombre de participants.` };

  const db = createAdminClient();

  // Compte : réutilise celui du cookie si présent, sinon crée.
  const existant = await compteCourant();
  let compteId: string;
  if (existant) {
    compteId = existant.id;
  } else {
    const { data, error } = await db.from('tdn_comptes').insert({ prenom, nom, email, telephone: telephone || null }).select('*').single();
    if (error || !data) { console.error('[inscrire] compte', error); return { erreur: 'Impossible de créer le compte.' }; }
    compteId = data.id;
    await poserCookieToken(data.token);
  }
  const { data: participants, error: errP } = await db
    .from('tdn_participants')
    .insert(lignes.map((l) => ({ compte_id: compteId, prenom: l.prenom, categorie: l.categorie, paye: false })))
    .select('id, categorie');
  if (errP || !participants) { console.error('[inscrire] participants', errP); return { erreur: 'Impossible d’enregistrer les participants.' }; }

  const montant = participants.reduce((s, p) => s + (p.categorie === 'adulte' ? reglages.tarif_adulte_centimes : reglages.tarif_enfant_centimes), 0);
  const reference = referenceCommande();
  const ids = participants.map((p) => p.id);

  const { data: cmd, error: errC } = await db.from('tdn_commandes')
    .insert({ compte_id: compteId, reference, montant_centimes: montant, participant_ids: ids, statut: 'en_attente' })
    .select('id').single();
  if (errC || !cmd) { console.error('[inscrire] commande', errC); return { erreur: 'Impossible de créer la commande.' }; }

  // Gratuit (tarifs à 0) : validation directe.
  if (montant === 0) {
    await db.from('tdn_commandes').update({ statut: 'payee', paye_le: new Date().toISOString() }).eq('id', cmd.id);
    await db.from('tdn_participants').update({ paye: true }).in('id', ids);
    redirect('/tresors-de-noel/inscription/retour?ref=' + reference);
  }

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let url: string | undefined;
  try {
    const checkout = await creerCheckout({
      reference,
      montantCentimes: montant,
      description: `${reference} · Trésors de Noël · ${lignes.length} participant${lignes.length > 1 ? 's' : ''}`,
      emailClient: email,
      urlRetour: `${base}/tresors-de-noel/inscription/retour?ref=${reference}`,
    });
    await db.from('tdn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[inscrire] SumUp', e);
    await db.from('tdn_commandes').update({ statut: 'echouee' }).eq('id', cmd.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez plus tard.' };
  }
  if (!url) return { erreur: 'Le paiement n’a pas pu être initialisé.' };
  redirect(url);
}

/** Synchronise une commande avec SumUp (retour de paiement ou webhook). */
export async function synchroniserCommande(reference?: string, checkoutId?: string) {
  const db = createAdminClient();
  const req = db.from('tdn_commandes').select('*');
  const { data: cmd } = await (reference ? req.eq('reference', reference) : req.eq('checkout_id', checkoutId!)).maybeSingle();
  if (!cmd) return null;
  if (cmd.statut === 'payee' || !cmd.checkout_id) return cmd;

  try {
    const checkout = await lireCheckout(cmd.checkout_id);
    const corr: Record<string, string> = { PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente' };
    const statut = corr[checkout.status] ?? 'en_attente';
    if (statut === cmd.statut) return cmd;
    const { data: maj } = await db.from('tdn_commandes').update({
      statut,
      transaction_code: checkout.transaction_code ?? checkout.transactions?.[0]?.transaction_code ?? null,
      paye_le: statut === 'payee' ? new Date().toISOString() : null,
    }).eq('id', cmd.id).select('*').single();
    if (statut === 'payee') await db.from('tdn_participants').update({ paye: true }).in('id', cmd.participant_ids);
    return maj ?? cmd;
  } catch (e) {
    console.error('[synchroniserCommande]', e);
    return cmd;
  }
}

/** Relance un paiement pour les participants non payés du compte courant. */
export async function payerEnAttente(): Promise<Etat> {
  const compte = await compteCourant();
  if (!compte) return { erreur: 'Non connecté.' };
  const reglages = await lireReglages();
  const db = createAdminClient();
  const { data: parts } = await db.from('tdn_participants').select('id, categorie').eq('compte_id', compte.id).eq('paye', false);
  if (!parts || parts.length === 0) return { erreur: 'Rien à payer.' };
  const restantes = reglages.places_max - (await placesPrises());
  if (parts.length > restantes) return { erreur: restantes <= 0 ? 'Complet : toutes les places ont été réservées.' : `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}.` };
  const montant = parts.reduce((s, p) => s + (p.categorie === 'adulte' ? reglages.tarif_adulte_centimes : reglages.tarif_enfant_centimes), 0);
  const reference = referenceCommande();
  const ids = parts.map((p) => p.id);
  const { data: cmd } = await db.from('tdn_commandes').insert({ compte_id: compte.id, reference, montant_centimes: montant, participant_ids: ids }).select('id').single();
  if (!cmd) return { erreur: 'Impossible de créer la commande.' };
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let url: string | undefined;
  try {
    const checkout = await creerCheckout({ reference, montantCentimes: montant, description: `${reference} · Trésors de Noël`, emailClient: compte.email,
      urlRetour: `${base}/tresors-de-noel/inscription/retour?ref=${reference}` });
    await db.from('tdn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) { console.error('[payerEnAttente]', e); return { erreur: 'Paiement indisponible.' }; }
  if (!url) return { erreur: 'Paiement indisponible.' };
  redirect(url);
}

/* =========================================================
   ACCÈS AU COMPTE (jeton par e-mail)
   ========================================================= */
export async function envoyerLienAcces(_prev: Etat, fd: FormData): Promise<Etat> {
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  if (!emailValide(email)) return { erreur: 'Adresse e-mail invalide.' };
  const db = createAdminClient();
  const { data: comptes } = await db.from('tdn_comptes').select('token, prenom').ilike('email', email);
  const generique = { ok: 'Si un compte existe avec cette adresse, un lien d’accès vient d’être envoyé.' };
  if (!comptes || comptes.length === 0 || !process.env.RESEND_API_KEY) return generique;

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  const from = process.env.RESEND_FROM_EMAIL ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const lien = `${base}/api/tresors/acces?token=${comptes[0].token}`;
  try {
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from, to: [email], subject: 'Votre accès aux Trésors de Noël',
        html: `<p>Bonjour ${comptes[0].prenom},</p><p>Voici votre lien pour retrouver votre aventure et vos clés :</p><p><a href="${lien}">${lien}</a></p><p>Ce lien est personnel, ne le partagez pas.</p><p>Comité des Fêtes de Limetz-Villez</p>`,
        text: `Bonjour ${comptes[0].prenom},\n\nVotre lien d'accès : ${lien}\n\nComité des Fêtes de Limetz-Villez`,
      }),
    });
  } catch (e) { console.error('[envoyerLienAcces]', e); }
  return generique;
}

export async function deconnecter() {
  const jar = await cookies();
  jar.delete(COOKIE_TOKEN);
  jar.delete(COOKIE_ACTIF);
  redirect('/tresors-de-noel');
}

export async function choisirParticipant(id: string) {
  const jar = await cookies();
  jar.set(COOKIE_ACTIF, id, { httpOnly: true, sameSite: 'lax', maxAge: UN_AN, path: '/' });
  revalidatePath('/tresors-de-noel', 'layout');
}

export async function ajouterParticipant(_prev: Etat, fd: FormData): Promise<Etat> {
  const compte = await compteCourant();
  if (!compte) return { erreur: 'Non connecté.' };
  const prenom = String(fd.get('prenom') ?? '').trim();
  const categorie: Categorie = fd.get('categorie') === 'adulte' ? 'adulte' : 'enfant';
  if (!prenom) return { erreur: 'Prénom obligatoire.' };
  const db = createAdminClient();
  await db.from('tdn_participants').insert({ compte_id: compte.id, prenom, categorie, paye: false });
  revalidatePath('/tresors-de-noel', 'layout');
  return { ok: `${prenom} ajouté. Réglez sa participation pour l’activer.` };
}

export async function supprimerParticipant(id: string) {
  const compte = await compteCourant();
  if (!compte) return;
  const db = createAdminClient();
  // On ne supprime que les participants non payés du compte courant.
  await db.from('tdn_participants').delete().eq('id', id).eq('compte_id', compte.id).eq('paye', false);
  revalidatePath('/tresors-de-noel', 'layout');
}

/* =========================================================
   JEU — validation d'une réponse (côté serveur)
   ========================================================= */
export async function validerReponse(missionId: string, reponse: string, participantIds: string[]): Promise<{ ok: boolean; termines: string[]; erreur?: string }> {
  const compte = await compteCourant();
  if (!compte) return { ok: false, termines: [], erreur: 'Non connecté.' };
  const reglages = await lireReglages();
  if (!jeuOuvert(reglages)) return { ok: false, termines: [], erreur: 'Le jeu n’est pas ouvert pour le moment.' };

  const db = createAdminClient();
  const { data: mission } = await db.from('tdn_missions').select('*').eq('id', missionId).single();
  if (!mission) return { ok: false, termines: [], erreur: 'Mission introuvable.' };
  const m = mission as Mission;

  const bon = m.question_type === 'choix'
    ? Number(reponse) === m.bonne_reponse
    : m.reponses.map(normaliser).includes(normaliser(reponse));
  if (!bon) return { ok: false, termines: [] };

  // Participants autorisés : payés et appartenant au compte.
  const { data: parts } = await db.from('tdn_participants').select('id').eq('compte_id', compte.id).eq('paye', true).in('id', participantIds);
  const ids = (parts ?? []).map((p) => p.id);
  if (ids.length === 0) return { ok: true, termines: [], erreur: 'Aucun participant valide sélectionné.' };

  await db.from('tdn_progressions').upsert(ids.map((participant_id) => ({ participant_id, mission_id: missionId })), { onConflict: 'participant_id,mission_id', ignoreDuplicates: true });

  // Clés pour ceux qui viennent de terminer.
  const missions = await lireMissions();
  const total = missions.length;
  const { data: prog } = await db.from('tdn_progressions').select('participant_id, mission_id').in('participant_id', ids);
  const idsMissions = new Set(missions.map((x) => x.id));
  const termines: string[] = [];
  for (const id of ids) {
    const faites = (prog ?? []).filter((p) => p.participant_id === id && idsMissions.has(p.mission_id)).length;
    if (faites >= total) {
      const { data: existante } = await db.from('tdn_cles').select('id').eq('participant_id', id).maybeSingle();
      if (!existante) {
        // Code unique : on retente en cas de collision.
        for (let essai = 0; essai < 5; essai++) {
          const { error } = await db.from('tdn_cles').insert({ participant_id: id, code: genererCode() });
          if (!error) break;
        }
        termines.push(id);
      }
    }
  }
  revalidatePath('/tresors-de-noel', 'layout');
  return { ok: true, termines };
}

/* =========================================================
   RÉVÉLATION (écran du Marché de Noël)
   ========================================================= */
export async function reveler(numero: string, code: string): Promise<{ lot?: Lot; prenom?: string; dejaRevelee?: boolean; erreur?: string }> {
  const n = Number(numero.trim());
  const c = code.trim().toUpperCase();
  if (!n || !c) return { erreur: 'Clé incomplète.' };
  const db = createAdminClient();
  const { data: cle } = await db.from('tdn_cles').select('*, tdn_participants(prenom)').eq('numero', n).eq('code', c).maybeSingle();
  if (!cle) return { erreur: 'Clé inconnue. Vérifiez le numéro et le code secret.' };

  let lotId: string | null = cle.lot_id;
  if (!lotId) {
    // Attribution : un lot non « grand » avec du stock restant, tiré au sort.
    const { data: lots } = await db.from('tdn_lots').select('id, stock').eq('grand', false);
    const { data: attribs } = await db.from('tdn_cles').select('lot_id').not('lot_id', 'is', null);
    const compte: Record<string, number> = {};
    for (const a of attribs ?? []) compte[a.lot_id!] = (compte[a.lot_id!] ?? 0) + 1;
    const dispo: string[] = [];
    for (const l of lots ?? []) for (let i = (compte[l.id] ?? 0); i < l.stock; i++) dispo.push(l.id);
    if (dispo.length === 0) return { erreur: 'Plus aucun lot disponible. Adressez-vous aux bénévoles.' };
    lotId = dispo[Math.floor(Math.random() * dispo.length)];
  }
  const dejaRevelee = !!cle.revelee_le;
  await db.from('tdn_cles').update({ lot_id: lotId, revelee_le: cle.revelee_le ?? new Date().toISOString() }).eq('id', cle.id);
  const { data: lot } = await db.from('tdn_lots').select('*, tdn_partenaires(nom)').eq('id', lotId).single();
  return { lot: lot as Lot, prenom: (cle as { tdn_participants?: { prenom: string } }).tdn_participants?.prenom, dejaRevelee };
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { supabase, isAdmin } = await requireAdmin('tresors');
  if (!isAdmin) throw new Error('Accès refusé.');
  return supabase;
}
const chemins = () => { revalidatePath('/admin/tresors', 'layout'); revalidatePath('/tresors-de-noel', 'layout'); };

function isoParisTdn(v: string) {
  if (!v) return null;
  const d = new Date(v);
  const paris = new Date(d.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  return new Date(d.getTime() + (d.getTime() - paris.getTime())).toISOString();
}

export async function majReglagesTdn(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const { error } = await sb.from('tdn_reglages').update({
    titre: String(fd.get('titre') ?? '').trim(),
    accroche: String(fd.get('accroche') ?? '').trim(),
    periode_texte: String(fd.get('periode_texte') ?? '').trim(),
    marche_texte: String(fd.get('marche_texte') ?? '').trim(),
    duree_texte: String(fd.get('duree_texte') ?? '').trim(),
    tarif_adulte_centimes: Math.round(Number(fd.get('tarif_adulte') ?? 0) * 100),
    tarif_enfant_centimes: Math.round(Number(fd.get('tarif_enfant') ?? 0) * 100),
    inscriptions_ouvertes: fd.get('inscriptions_ouvertes') === 'on',
    jeu_actif: fd.get('jeu_actif') === 'on',
    places_max: Math.max(0, Number(fd.get('places_max') ?? 300)),
    jeu_debut: isoParisTdn(String(fd.get('jeu_debut') ?? '')),
    jeu_fin: isoParisTdn(String(fd.get('jeu_fin') ?? '')),
    grand_tresor_montant: String(fd.get('grand_tresor_montant') ?? '').trim(),
    grand_tresor_texte: String(fd.get('grand_tresor_texte') ?? '').trim(),
    lieu_revelation: String(fd.get('lieu_revelation') ?? '').trim(),
  }).eq('id', 1);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Réglages enregistrés.' };
}

const lignes = (v: FormDataEntryValue | null) => String(v ?? '').split('\n').map((s) => s.trim()).filter(Boolean);

export async function enregistrerMission(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const question_type = String(fd.get('question_type') ?? 'texte');
  let blocs: Bloc[] = [];
  try { blocs = JSON.parse(String(fd.get('blocs') ?? '[]')); } catch { return { erreur: 'Contenu (blocs) invalide.' }; }
  const options = lignes(fd.get('options'));
  const data = {
    numero: Number(fd.get('numero') ?? 0),
    titre: String(fd.get('titre') ?? '').trim(),
    lieu: String(fd.get('lieu') ?? '').trim() || null,
    accroche: String(fd.get('accroche') ?? '').trim() || null,
    blocs,
    question_type,
    intitule: String(fd.get('intitule') ?? '').trim(),
    reponses: lignes(fd.get('reponses')),
    options,
    bonne_reponse: question_type === 'choix' ? Number(fd.get('bonne_reponse') ?? 0) : null,
    longueur: question_type === 'code' ? Number(fd.get('longueur') ?? 4) || null : null,
    placeholder: String(fd.get('placeholder') ?? '').trim() || null,
    indices: lignes(fd.get('indices')),
    solution_secours: String(fd.get('solution_secours') ?? '').trim() || null,
    publie: fd.get('publie') === 'on',
  };
  if (!data.titre || !data.numero) return { erreur: 'Numéro et titre obligatoires.' };
  if (question_type !== 'choix' && data.reponses.length === 0) return { erreur: 'Indiquez au moins une réponse acceptée.' };
  if (question_type === 'choix' && options.length < 2) return { erreur: 'Au moins deux options pour un choix multiple.' };

  const { error } = id
    ? await sb.from('tdn_missions').update(data).eq('id', id)
    : await sb.from('tdn_missions').insert(data);
  if (error) return { erreur: error.code === '23505' ? 'Ce numéro de mission existe déjà.' : error.message };
  chemins();
  if (!id) redirect('/admin/tresors/missions');
  return { ok: 'Mission enregistrée.' };
}

export async function supprimerMission(id: string) {
  const sb = await admin();
  await sb.from('tdn_missions').delete().eq('id', id);
  chemins();
  redirect('/admin/tresors/missions');
}

export async function enregistrerLot(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = {
    nom: String(fd.get('nom') ?? '').trim(),
    valeur: String(fd.get('valeur') ?? '').trim() || null,
    partenaire_id: String(fd.get('partenaire_id') ?? '') || null,
    stock: Number(fd.get('stock') ?? 1),
    grand: fd.get('grand') === 'on',
    position: Number(fd.get('position') ?? 0),
  };
  if (!data.nom) return { erreur: 'Nom du lot obligatoire.' };
  const { error } = id ? await sb.from('tdn_lots').update(data).eq('id', id) : await sb.from('tdn_lots').insert(data);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Lot enregistré.' };
}
export async function supprimerLot(id: string) { const sb = await admin(); await sb.from('tdn_lots').delete().eq('id', id); chemins(); }

export async function enregistrerPartenaire(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = { nom: String(fd.get('nom') ?? '').trim(), type: String(fd.get('type') ?? '').trim() || null };
  if (!data.nom) return { erreur: 'Nom obligatoire.' };
  const { error } = id ? await sb.from('tdn_partenaires').update(data).eq('id', id) : await sb.from('tdn_partenaires').insert(data);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Partenaire enregistré.' };
}
export async function supprimerPartenaire(id: string) { const sb = await admin(); await sb.from('tdn_partenaires').delete().eq('id', id); chemins(); }

/** Attribue (ou retire) un lot à une clé, marque révélée / non révélée. */
export async function majCle(id: string, patch: { lot_id?: string | null; revelee?: boolean }) {
  const sb = await admin();
  const data: Partial<Cle> = {};
  if ('lot_id' in patch) data.lot_id = patch.lot_id ?? null;
  if ('revelee' in patch) data.revelee_le = patch.revelee ? new Date().toISOString() : null;
  await sb.from('tdn_cles').update(data).eq('id', id);
  chemins();
}

export async function marquerPaye(participantId: string, paye: boolean) {
  const sb = await admin();
  await sb.from('tdn_participants').update({ paye }).eq('id', participantId);
  chemins();
}

export async function supprimerParticipantAdmin(id: string) {
  const sb = await admin();
  await sb.from('tdn_participants').delete().eq('id', id);
  chemins();
}

export { numeroCle };


/* =========================================================
   TIRAGE DU GRAND TRÉSOR (écran admin)
   ========================================================= */
export type ResultatTirage = { ok: true; cleId: string; numero: number; prenom: string; famille: string; deja: boolean } | { ok: false; erreur: string };

/** Tire au sort une clé parmi toutes les clés générées, attribue le lot « grand trésor » et verrouille le résultat. */
export async function tirerGrandTresor(): Promise<ResultatTirage> {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single();
  const lireGagnant = async (id: string) => {
    const { data: c } = await db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').eq('id', id).single();
    const p = c?.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { cleId: c!.id, numero: c!.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  };
  if (r?.tirage_cle_id) return { ok: true, ...(await lireGagnant(r.tirage_cle_id)), deja: true };

  const { data: cles } = await db.from('tdn_cles').select('id');
  if (!cles || cles.length === 0) return { ok: false, erreur: 'Aucune clé générée : personne n’a terminé le jeu.' };
  const { data: grand } = await db.from('tdn_lots').select('id').eq('grand', true).order('position').limit(1).maybeSingle();
  if (!grand) return { ok: false, erreur: 'Aucun lot marqué « grand trésor » dans les lots.' };

  const gagnante = cles[Math.floor(Math.random() * cles.length)];
  const maintenant = new Date().toISOString();
  // Verrou : on n’écrit que si aucun tirage n’a été enregistré entre-temps.
  const { data: maj } = await db.from('tdn_reglages').update({ tirage_cle_id: gagnante.id, tirage_le: maintenant }).eq('id', 1).is('tirage_cle_id', null).select('tirage_cle_id').maybeSingle();
  if (!maj) { const { data: r2 } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single(); return { ok: true, ...(await lireGagnant(r2!.tirage_cle_id!)), deja: true }; }
  await db.from('tdn_cles').update({ lot_id: grand.id }).eq('id', gagnante.id);
  chemins();
  return { ok: true, ...(await lireGagnant(gagnante.id)), deja: false };
}

/** Annule le tirage (retire le grand trésor de la clé) pour pouvoir le relancer. */
export async function annulerTirage() {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single();
  if (r?.tirage_cle_id) await db.from('tdn_cles').update({ lot_id: null, revelee_le: null }).eq('id', r.tirage_cle_id);
  await db.from('tdn_reglages').update({ tirage_cle_id: null, tirage_le: null }).eq('id', 1);
  chemins();
}

/** Interrupteur général : retire le module du menu et des pages publiques (les données sont conservées). */
export async function basculerModuleTdn(actif: boolean) {
  const sb = await admin();
  await sb.from('tdn_reglages').update({ module_actif: actif }).eq('id', 1);
  chemins();
  revalidatePath('/');
  revalidatePath('/evenements', 'layout');
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/tresors-actions.ts"
mkdir -p 'src/app/tresors-de-noel'
cat > 'src/app/tresors-de-noel/layout.tsx' <<'EOF_BUREAU_FICHIER'
import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglages } from '@/lib/tresors/db';
import { requireAdmin } from '@/lib/supabase/server';
import './tresors.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglages();
  return { title: `${r.titre} · Comité des Fêtes`, description: `${r.accroche} Une chasse aux trésors grandeur nature dans le village.` };
}

export default async function TresorsLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglages();
  if (r.module_actif === false) {
    const { isAdmin } = await requireAdmin('tresors');
    if (!isAdmin) {
      return (
        <div className="tdn">
          <main className="tdn-page tdn-centre" style={{ justifyContent: 'center' }}>
            <h1 className="tdn-titre-fee">Les Trésors de Noël</h1>
            <p className="tdn-p">Ce jeu n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="tdn-btn tdn-btn-ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return <div className="tdn">{children}</div>;
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/tresors-de-noel/layout.tsx"
mkdir -p 'src/app/tresors-de-noel/tirage'
cat > 'src/app/tresors-de-noel/tirage/page.tsx' <<'EOF_BUREAU_FICHIER'
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import Tirage from '@/components/tresors/Tirage';
import { lireReglages } from '@/lib/tresors/db';

/** Écran grand format du tirage du grand trésor. Réservé aux administrateurs connectés. */
export default async function PageTirage() {
  const { user, isAdmin } = await requireAdmin('tresors');
  if (!user || !isAdmin) redirect('/admin/login');
  const db = createAdminClient();
  const [r, { data: cles }] = await Promise.all([
    lireReglages(),
    db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').order('numero'),
  ]);
  const liste = (cles ?? []).map((c) => {
    const p = c.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  });
  return <Tirage cles={liste} lot={`${r.grand_tresor_texte} de ${r.grand_tresor_montant}`} tirageFait={!!r.tirage_cle_id} />;
}
EOF_BUREAU_FICHIER
echo "  ✓ src/app/tresors-de-noel/tirage/page.tsx"
mkdir -p 'src/components'
cat > 'src/components/ExportCsv.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useState } from 'react';

type Props = {
  reservations: any[];
  evenements?: { id: string; titre: string }[];
};

const echappe = (v: any) => `"${String(v ?? '').replace(/"/g, '""')}"`;

function telecharger(nom: string, lignes: string[][]) {
  // BOM UTF-8 pour qu'Excel affiche correctement les accents
  const csv = '\uFEFF' + lignes.map((l) => l.map(echappe).join(';')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = nom;
  a.click();
  URL.revokeObjectURL(url);
}

const slugifie = (s: string) =>
  s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
   .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export default function ExportCsv({ reservations, evenements = [] }: Props) {
  const [ouvert, setOuvert] = useState(false);

  /** Liste d'émargement : une ligne par réservation payée, triée par nom. */
  function listeEmargement(resas: any[], titreEvt: string) {
    const payees = resas
      .filter((r) => r.statut === 'payee')
      .sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));

    const total = payees.reduce((s, r) => s + r.places, 0);

    const lignes: string[][] = [
      [`LISTE D'ÉMARGEMENT — ${titreEvt}`],
      [`${payees.length} réservations · ${total} personnes`],
      [`Éditée le ${new Date().toLocaleDateString('fr-FR')}`],
      [],
      ['Nom', 'Places', 'Code billet', 'Téléphone', 'Email', 'Remarque', 'Présent (à cocher)'],
      ...payees.map((r) => [
        r.nom, String(r.places), r.code_billet,
        r.telephone ?? '', r.email ?? '', r.commentaire ?? '', '',
      ]),
      [],
      ['TOTAL', String(total), '', '', '', '', ''],
    ];

    telecharger(`emargement-${slugifie(titreEvt)}.csv`, lignes);
  }

  /** Export comptable : toutes les réservations, tous statuts. */
  function exportComplet(resas: any[], nom: string) {
    const lignes: string[][] = [
      ['Référence', 'Type', 'Date réservation', 'Nom', 'Email', 'Téléphone',
       'Événement', 'Places', 'Montant €', 'Statut', 'Code billet',
       'Pointé', 'Paiement', 'Transaction SumUp', 'N° chèque', 'Détail', 'Remarque'],
      ...resas.map((r) => [
        r.reference,
        r.exposant ? 'Exposant' : 'Participant',
        new Date(r.created_at).toLocaleDateString('fr-FR'),
        r.nom, r.email ?? '', r.telephone ?? '',
        r.evenements?.titre ?? '',
        String(r.places),
        (r.montant_centimes / 100).toFixed(2).replace('.', ','),
        r.statut, r.code_billet,
        r.scanne_le ? 'oui' : 'non',
        r.mode_paiement === 'especes' ? 'Espèces' : r.mode_paiement === 'cheque' ? 'Chèque' : r.statut === 'payee' ? 'SumUp' : '',
        r.transaction_code ?? '',
        r.paiement_ref ?? '',
        (r.reservation_lignes ?? []).map((l: any) => `${l.quantite} x ${l.libelle}`).join(', '),
        r.commentaire ?? '',
      ]),
    ];
    telecharger(`reservations-${nom}.csv`, lignes);
  }

  const parEvenement = evenements
    .map((e) => ({
      ...e,
      resas: reservations.filter((r) => r.evenement_id === e.id),
    }))
    .filter((e) => e.resas.length > 0);

  return (
    <div className="export-zone">
      <button
        className="btn btn-k btn-sm"
        onClick={() => setOuvert(!ouvert)}
        disabled={reservations.length === 0}
      >
        Exporter ▾
      </button>

      {ouvert && (
        <div className="export-menu">
          <div className="export-titre">Liste d&apos;émargement</div>
          <p className="export-aide">
            Réservations payées uniquement, triées par nom, avec une colonne
            à cocher. À imprimer pour l&apos;entrée.
          </p>
          {parEvenement.map((e) => (
            <button
              key={e.id}
              className="export-item"
              onClick={() => { listeEmargement(e.resas, e.titre); setOuvert(false); }}
            >
              {e.titre}
              <span>{e.resas.filter((r) => r.statut === 'payee').length} payées</span>
            </button>
          ))}
          {parEvenement.length === 0 && (
            <p className="export-aide">Aucune réservation.</p>
          )}

          <div className="export-titre" style={{ marginTop: '1rem' }}>
            Export comptable
          </div>
          <p className="export-aide">
            Toutes les réservations, tous statuts, avec le mode de paiement et les références SumUp.
          </p>
          <button
            className="export-item"
            onClick={() => { exportComplet(reservations, 'tous'); setOuvert(false); }}
          >
            Toutes les réservations
            <span>{reservations.length} lignes</span>
          </button>
          {parEvenement.map((e) => (
            <button
              key={`c-${e.id}`}
              className="export-item"
              onClick={() => { exportComplet(e.resas, slugifie(e.titre)); setOuvert(false); }}
            >
              {e.titre}
              <span>{e.resas.length} lignes</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/ExportCsv.tsx"
mkdir -p 'src/components'
cat > 'src/components/FormReservationManuelle.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useActionState, useEffect, useMemo, useState, useTransition } from 'react';
import {
  ajouterReservationManuelle, ajouterFormuleExposant, supprimerFormuleExposant, type EtatManuel,
} from '@/app/reservation-actions';

type Evt = { id: string; titre: string; prix_centimes: number | null; places_max: number | null; billetterie_active: boolean | null };
type Tarif = { id: string; evenement_id: string; libelle: string; prix_centimes: number };
type TypeSaisie = 'participant' | 'exposant';

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const enSaisie = (c: number) => (c / 100).toFixed(2).replace('.', ',');
const champ = { padding: '.5rem', border: '2px solid var(--noir)', fontFamily: 'inherit' } as const;

/**
 * Ajout par un admin d'un participant (billetterie) ou d'un exposant (formules d'emplacement),
 * avec paiement en espèces, par chèque ou à venir.
 */
export default function FormReservationManuelle({
  evenements, tarifs, formules, evenementInitial,
}: { evenements: Evt[]; tarifs: Tarif[]; formules: Tarif[]; evenementInitial?: string }) {
  const [ouvert, setOuvert] = useState(false);
  const [type, setType] = useState<TypeSaisie>('participant');
  const [evenementId, setEvenementId] = useState('');
  const [qtes, setQtes] = useState<Record<string, number>>({});
  const [montantSaisi, setMontantSaisi] = useState<string | null>(null);
  const [paiement, setPaiement] = useState('attente');
  const [etat, action, pending] = useActionState<EtatManuel, FormData>(ajouterReservationManuelle, null);

  // Gestion des formules exposants
  const [nouveauLibelle, setNouveauLibelle] = useState('');
  const [nouveauPrix, setNouveauPrix] = useState('');
  const [erreurFormule, setErreurFormule] = useState('');
  const [enCours, start] = useTransition();

  const exposant = type === 'exposant';
  // Participants : événements avec billetterie. Exposants : tous les événements.
  const choix = useMemo(
    () => (exposant ? evenements : evenements.filter((e) => e.billetterie_active)),
    [evenements, exposant]
  );
  const evt =
    choix.find((e) => e.id === evenementId) ??
    choix.find((e) => e.id === evenementInitial) ??
    (exposant ? choix.find((e) => /march/i.test(e.titre)) : undefined) ??
    choix[0];

  const lignes = useMemo(() => {
    if (!evt) return [];
    const grille = (exposant ? formules : tarifs).filter((t) => t.evenement_id === evt.id);
    if (grille.length > 0) return grille.map((t) => ({ id: t.id, libelle: t.libelle, prix: t.prix_centimes }));
    // Sans grille : prix unique de l'événement, ou emplacement à prix libre pour un exposant.
    return [{ id: 'defaut', libelle: exposant ? 'Emplacement' : 'Place', prix: exposant ? 0 : evt.prix_centimes ?? 0 }];
  }, [tarifs, formules, evt, exposant]);
  const formulesEvt = exposant && evt ? formules.filter((f) => f.evenement_id === evt.id) : [];

  const total = lignes.reduce((s, l) => s + l.prix * (qtes[l.id] ?? 0), 0);
  const quantite = lignes.reduce((s, l) => s + (qtes[l.id] ?? 0), 0);

  const vider = () => { setQtes({}); setMontantSaisi(null); };

  // Après un ajout réussi : formulaire vide, même événement.
  useEffect(() => { if (etat?.ok) vider(); }, [etat]);

  if (evenements.length === 0) return null;

  if (!ouvert) {
    return (
      <div style={{ marginBottom: '1.6rem' }}>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        <button type="button" className="btn btn-k btn-sm" onClick={() => setOuvert(true)}>
          + Ajouter un participant ou un exposant
        </button>
      </div>
    );
  }

  return (
    <div className="panel">
      <h2>{exposant ? 'Ajouter un exposant' : 'Ajouter un participant'}</h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', marginBottom: '1.1rem' }}>
        <button type="button" className={`btn btn-sm ${exposant ? 'btn-w' : 'btn-k'}`}
          onClick={() => { setType('participant'); setEvenementId(''); vider(); }}>
          Participant
        </button>
        <button type="button" className={`btn btn-sm ${exposant ? 'btn-k' : 'btn-w'}`}
          onClick={() => { setType('exposant'); setEvenementId(''); vider(); }}>
          Exposant
        </button>
      </div>

      {!evt ? (
        <p style={{ color: '#6b6560', marginBottom: '1rem' }}>
          Aucun événement avec billetterie activée. Pour un exposant, choisis « Exposant ».
        </p>
      ) : (
        <form action={action}>
          <input type="hidden" name="type" value={type} />
          <div className="field">
            <label htmlFor="rm-evt">Événement</label>
            <select id="rm-evt" name="evenement_id" value={evt.id}
              onChange={(e) => { setEvenementId(e.target.value); vider(); }}>
              {choix.map((e) => <option key={e.id} value={e.id}>{e.titre}</option>)}
            </select>
          </div>

          <div className="row3">
            <div className="field">
              <label htmlFor="rm-nom">{exposant ? 'Nom ou structure' : 'Nom et prénom'}</label>
              <input id="rm-nom" name="nom" required minLength={2} autoComplete="off" />
            </div>
            <div className="field">
              <label htmlFor="rm-tel">Téléphone (facultatif)</label>
              <input id="rm-tel" name="telephone" type="tel" autoComplete="off" />
            </div>
            <div className="field">
              <label htmlFor="rm-email">E-mail (facultatif)</label>
              <input id="rm-email" name="email" type="email" autoComplete="off" />
            </div>
          </div>

          <div className="field">
            <label>{exposant ? 'Formules' : 'Places'}</label>
            <table className="tbl" style={{ maxWidth: 560 }}>
              <tbody>
                {lignes.map((l) => (
                  <tr key={l.id}>
                    <td>{l.libelle}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{l.id === 'defaut' && exposant ? 'prix libre' : euros(l.prix)}</td>
                    <td style={{ width: 110 }}>
                      <input type="hidden" name="tarif_id" value={l.id} />
                      <input
                        name="tarif_qte" type="number" min={0} max={99} inputMode="numeric"
                        aria-label={`Quantité ${l.libelle}`}
                        value={qtes[l.id] ?? 0}
                        onChange={(e) => setQtes((q) => ({ ...q, [l.id]: Math.max(0, Math.floor(Number(e.target.value) || 0)) }))}
                        style={{ ...champ, width: 90 }}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="row3">
            <div className="field">
              <label htmlFor="rm-montant">
                {exposant ? 'Montant' : `Montant (${quantite} place${quantite > 1 ? 's' : ''})`}
              </label>
              <input id="rm-montant" name="montant" inputMode="decimal"
                value={montantSaisi ?? enSaisie(total)} onChange={(e) => setMontantSaisi(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="rm-paiement">Paiement</label>
              <select id="rm-paiement" name="paiement" value={paiement} onChange={(e) => setPaiement(e.target.value)}>
                <option value="especes">Espèces</option>
                <option value="cheque">Chèque</option>
                <option value="attente">Pas encore payé</option>
              </select>
            </div>
            {paiement === 'cheque' && (
              <div className="field">
                <label htmlFor="rm-ref">N° du chèque (facultatif)</label>
                <input id="rm-ref" name="paiement_ref" autoComplete="off" />
              </div>
            )}
          </div>
          {montantSaisi !== null && (
            <p style={{ fontSize: '.8rem', color: '#6b6560', margin: '-.4rem 0 .9rem' }}>
              Montant modifié à la main, tarif normal {euros(total)}.{' '}
              <button type="button" onClick={() => setMontantSaisi(null)}
                style={{ background: 'none', border: 'none', textDecoration: 'underline', cursor: 'pointer', fontFamily: 'inherit', fontSize: 'inherit', padding: 0 }}>
                Revenir au tarif normal
              </button>
            </p>
          )}

          <div className="field">
            <label htmlFor="rm-com">{exposant ? 'Activité, produits vendus, remarque' : 'Remarque (facultatif)'}</label>
            <input id="rm-com" name="commentaire" autoComplete="off" />
          </div>

          {!exposant && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '.5rem', marginBottom: '1.1rem', fontSize: '.9rem' }}>
              {paiement !== 'attente' && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" name="envoyer_billet" defaultChecked style={{ width: 'auto' }} />
                  Envoyer le billet par e-mail (si une adresse est saisie)
                </label>
              )}
              {evt.places_max != null && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" name="depasser" style={{ width: 'auto' }} />
                  Autoriser le dépassement de la jauge
                </label>
              )}
            </div>
          )}

          <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
            <button className="btn btn-k btn-sm" disabled={pending || quantite < 1}>
              {pending ? 'Enregistrement…' : exposant ? "Ajouter l'exposant" : 'Ajouter la réservation'}
            </button>
            <button type="button" className="btn btn-w btn-sm" onClick={() => setOuvert(false)}>Fermer</button>
          </div>
        </form>
      )}

      {exposant && evt && (
        <div style={{ marginTop: '1.6rem', paddingTop: '1.2rem', borderTop: '2px solid var(--noir)' }}>
          <h2 style={{ fontSize: '1rem' }}>Formules exposants de « {evt.titre} »</h2>
          {erreurFormule && <div className="msg ko">{erreurFormule}</div>}
          <table className="tbl" style={{ maxWidth: 560, marginBottom: '1rem' }}>
            <tbody>
              {formulesEvt.map((f) => (
                <tr key={f.id}>
                  <td>{f.libelle}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>{euros(f.prix_centimes)}</td>
                  <td style={{ width: 110 }}>
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => start(async () => {
                        const r = await supprimerFormuleExposant(f.id);
                        setErreurFormule(r.erreur ?? '');
                      })}>
                      Retirer
                    </button>
                  </td>
                </tr>
              ))}
              {formulesEvt.length === 0 && (
                <tr><td colSpan={3} style={{ color: '#6b6560' }}>Aucune formule : l&apos;emplacement est à prix libre.</td></tr>
              )}
            </tbody>
          </table>
          <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <input aria-label="Libellé de la formule" placeholder="Ex. Emplacement 3 m, Table, Électricité"
              value={nouveauLibelle} onChange={(e) => setNouveauLibelle(e.target.value)}
              style={{ ...champ, flex: '2 1 220px', minWidth: 0 }} />
            <input aria-label="Prix de la formule" placeholder="Prix €" inputMode="decimal"
              value={nouveauPrix} onChange={(e) => setNouveauPrix(e.target.value)}
              style={{ ...champ, flex: '0 1 110px', minWidth: 0 }} />
            <button type="button" className="btn btn-y btn-sm" disabled={enCours}
              onClick={() => start(async () => {
                const r = await ajouterFormuleExposant(evt.id, nouveauLibelle, nouveauPrix);
                setErreurFormule(r.erreur ?? '');
                if (r.ok) { setNouveauLibelle(''); setNouveauPrix(''); }
              })}>
              Ajouter la formule
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/FormReservationManuelle.tsx"
mkdir -p 'src/components'
cat > 'src/components/LigneReservation.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useEffect, useState, useTransition } from 'react';
import {
  marquerScanne, changerStatutResa, supprimerReservation, verifierSumUpAdmin, encaisserReservation,
} from '@/app/reservation-actions';
import Confirmation from '@/components/Confirmation';

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);

const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée',
  expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};
const MODES: Record<string, string> = { especes: 'Espèces', cheque: 'Chèque' };
/** Statuts depuis lesquels un paiement en espèces ou par chèque peut être enregistré. */
const ENCAISSABLES = ['en_attente', 'echouee', 'expiree'];

export default function LigneReservation({ resa }: { resa: any }) {
  const [pending, start] = useTransition();
  const [confirme, setConfirme] = useState(false);
  const [verif, setVerif] = useState('');
  const [statut, setStatut] = useState<string>(resa.statut);
  const [encaisse, setEncaisse] = useState(false);
  const [mode, setMode] = useState('especes');
  const [ref, setRef] = useState('');

  // Le statut peut changer côté serveur (encaissement, vérification SumUp).
  useEffect(() => { setStatut(resa.statut); }, [resa.statut]);

  return (
    <>
      <tr style={{ opacity: pending ? .5 : 1 }}>
        <td data-l="Acheteur" className="bloc">
          <strong>{resa.nom}</strong>
          {resa.exposant && <> <span className="pill done">Exposant</span></>}
          {resa.email && (
            <><br /><a href={`mailto:${resa.email}`} style={{ color: '#6b6560', fontSize: '.8rem' }}>
              {resa.email}
            </a></>
          )}
          {resa.telephone && (
            <><br /><span style={{ color: '#6b6560', fontSize: '.8rem' }}>{resa.telephone}</span></>
          )}
          {resa.commentaire && (
            <><br /><span style={{ color: '#8a7f6f', fontSize: '.78rem', fontStyle: 'italic' }}>
              {resa.commentaire}
            </span></>
          )}
          {resa.saisie_par && (
            <><br /><span style={{ color: '#6b6560', fontSize: '.72rem' }}>Saisie par {resa.saisie_par}</span></>
          )}
        </td>
        <td data-l="Événement" style={{ fontSize: '.85rem' }}>{resa.evenements?.titre}</td>
        <td data-l="Places">
          {resa.exposant ? '' : resa.places}
          {(resa.exposant ? resa.reservation_lignes?.length > 0 : resa.reservation_lignes?.length > 1) && (
            <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
              {resa.reservation_lignes.map((l: any, i: number) => (
                <div key={i}>{l.quantite}× {l.libelle}</div>
              ))}
            </div>
          )}
        </td>
        <td data-l="Montant">
          {euros(resa.montant_centimes)}
          {resa.mode_paiement && (
            <div style={{ marginTop: '.3rem' }}>
              <span className="pill new">{MODES[resa.mode_paiement] ?? resa.mode_paiement}</span>
              {resa.paiement_ref && (
                <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>n° {resa.paiement_ref}</div>
              )}
            </div>
          )}
        </td>
        <td data-l="Billet">
          <code style={{ fontSize: '.8rem', fontWeight: 700 }}>{resa.code_billet}</code>
          {resa.statut === 'payee' && (
            <div style={{ marginTop: '.3rem' }}>
              {resa.scanne_le
                ? <span className="pill done">Entré</span>
                : <button
                    className="pill off" style={{ cursor: 'pointer', fontFamily: 'inherit' }}
                    onClick={() => start(() => { marquerScanne(resa.id); })}
                  >
                    Pointer
                  </button>}
            </div>
          )}
        </td>
        <td data-l="Statut">
          <select
            value={statut}
            onChange={(e) => {
              const nouveau = e.target.value;
              setStatut(nouveau);
              setVerif('');
              start(async () => {
                const r = await changerStatutResa(resa.id, nouveau);
                if (r?.erreur) { setVerif(r.erreur); setStatut(resa.statut); }
              });
            }}
            style={{ padding: '.35rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
          >
            {Object.entries(LIBELLES).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
        </td>
        <td className="actions">
          {ENCAISSABLES.includes(resa.statut) && (
            <button className="btn btn-k btn-sm" style={{ marginRight: '.4rem' }} onClick={() => setEncaisse((v) => !v)}>
              Encaisser
            </button>
          )}
          {resa.statut === 'en_attente' && resa.checkout_id && (
            <button className="btn btn-y btn-sm" title="Interroger SumUp et mettre le statut à jour" style={{ marginRight: '.4rem' }}
              onClick={() => start(async () => { const r = await verifierSumUpAdmin(resa.reference); setVerif(r.changees ? 'Statut mis à jour' : 'Toujours en attente côté SumUp'); })}>
              Vérifier SumUp
            </button>
          )}
          <button className="btn btn-w btn-sm" onClick={() => setConfirme(true)}>Suppr.</button>
          {verif && <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.3rem' }}>{verif}</div>}
        </td>
      </tr>

      {encaisse && ENCAISSABLES.includes(resa.statut) && (
        <tr>
          <td colSpan={7} style={{ background: '#FFF6D6' }}>
            <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'center' }}>
              <strong style={{ fontSize: '.9rem' }}>Encaisser {euros(resa.montant_centimes)} de {resa.nom}</strong>
              <select
                aria-label="Mode de paiement" value={mode} onChange={(e) => setMode(e.target.value)}
                style={{ padding: '.45rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
              >
                <option value="especes">Espèces</option>
                <option value="cheque">Chèque</option>
              </select>
              {mode === 'cheque' && (
                <input
                  aria-label="Numéro du chèque" placeholder="N° du chèque (facultatif)" value={ref}
                  onChange={(e) => setRef(e.target.value)}
                  style={{ padding: '.45rem .6rem', border: '2px solid var(--noir)', fontFamily: 'inherit', minWidth: 180 }}
                />
              )}
              <button
                className="btn btn-k btn-sm" disabled={pending}
                onClick={() => start(async () => {
                  const r = await encaisserReservation(resa.id, mode, mode === 'cheque' ? ref : '');
                  if (r.erreur) setVerif(r.erreur);
                  else { setEncaisse(false); setVerif('Paiement enregistré'); }
                })}
              >
                Valider le paiement
              </button>
              <button className="btn btn-w btn-sm" onClick={() => setEncaisse(false)}>Annuler</button>
            </div>
          </td>
        </tr>
      )}

      <Confirmation
        ouvert={confirme}
        danger
        titre="Supprimer cette réservation ?"
        message={`La réservation de ${resa.nom} (${resa.reference}) sera définitivement effacée.`}
        detail={resa.mode_paiement
          ? 'Le paiement a été reçu en main propre : pense à rendre la somme si besoin.'
          : 'Cela ne rembourse pas le paiement : le remboursement se fait depuis votre compte SumUp.'}
        libelleConfirmer="Supprimer"
        onAnnuler={() => setConfirme(false)}
        onConfirmer={() => {
          setConfirme(false);
          start(() => { supprimerReservation(resa.id); });
        }}
      />
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/LigneReservation.tsx"
mkdir -p 'src/components'
cat > 'src/components/ListeReservationsLecture.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useMemo, useState } from 'react';

const euros = (c: number) => new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const fmt = (iso: string) => new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Europe/Paris' }).format(new Date(iso));
const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée', expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};
const CLASSE: Record<string, string> = { payee: 'on', en_attente: 'new', remboursee: 'off', annulee: 'off', echouee: 'off', expiree: 'off' };
const norm = (s: unknown) => String(s ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

export default function ListeReservationsLecture({ reservations }: { reservations: any[] }) {
  const [q, setQ] = useState('');
  const liste = useMemo(() => {
    const t = norm(q).trim();
    if (!t) return reservations;
    return reservations.filter((r) =>
      [r.nom, r.email, r.telephone, r.reference, r.code_billet, r.evenements?.titre].some((v) => norm(v).includes(t)),
    );
  }, [q, reservations]);

  return (
    <>
      <div style={{ display: 'flex', gap: '.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
        <input type="search" placeholder="Rechercher un nom, e-mail, téléphone, code billet…" value={q} onChange={(e) => setQ(e.target.value)}
          style={{ flex: 1, minWidth: 200, padding: '.6rem .8rem', border: '2px solid var(--noir)', fontFamily: 'inherit', fontSize: '.9rem' }} />
        <span style={{ fontSize: '.78rem', color: '#6b6560', whiteSpace: 'nowrap' }}>{liste.length} / {reservations.length}</span>
      </div>

      <table className="tbl cartes compact">
        <thead><tr><th>Date</th><th>Acheteur</th><th>Événement</th><th>Places</th><th>Montant</th><th>Billet</th><th>Statut</th></tr></thead>
        <tbody>
          {liste.map((r) => (
            <tr key={r.id}>
              <td data-l="Date">{fmt(r.created_at)}</td>
              <td data-l="Acheteur" className="bloc">
                <strong>{r.nom}</strong>{r.exposant && <> <span className="pill done">Exposant</span></>}<br />
                <span style={{ color: '#6b6560', fontSize: '.8rem' }}>{[r.email, r.telephone].filter(Boolean).join(' · ')}</span>
              </td>
              <td data-l="Événement" style={{ fontSize: '.85rem' }}>{r.evenements?.titre}</td>
              <td data-l="Places">
                {r.exposant ? '' : r.places}
                {(r.exposant ? r.reservation_lignes?.length > 0 : r.reservation_lignes?.length > 1) && (
                  <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
                    {r.reservation_lignes.map((l: any, i: number) => <div key={i}>{l.quantite}× {l.libelle}</div>)}
                  </div>
                )}
              </td>
              <td data-l="Montant">
                {euros(r.montant_centimes)}
                {r.mode_paiement && (
                  <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
                    {r.mode_paiement === 'especes' ? 'Espèces' : 'Chèque'}{r.paiement_ref ? ` n° ${r.paiement_ref}` : ''}
                  </div>
                )}
              </td>
              <td data-l="Billet"><code style={{ fontSize: '.8rem', fontWeight: 700 }}>{r.code_billet}</code>{r.scanne_le && <> <span className="pill done">Entré</span></>}</td>
              <td data-l="Statut"><span className={`pill ${CLASSE[r.statut] ?? 'off'}`}>{LIBELLES[r.statut] ?? r.statut}</span></td>
            </tr>
          ))}
          {liste.length === 0 && <tr><td colSpan={7} style={{ color: '#6b6560' }}>{q ? 'Aucun résultat.' : 'Aucune réservation.'}</td></tr>}
        </tbody>
      </table>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/ListeReservationsLecture.tsx"
mkdir -p 'src/components'
cat > 'src/components/NavAdmin.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { CATEGORIES, MODULES, moduleDuChemin } from '@/lib/bureau/modules';
import './nav-admin.css';

/** Menu de l'admin, rangé par catégories et limité aux modules accordés au membre connecté. */
export default function NavAdmin({ modules }: { modules: string[] }) {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);

  const liens = MODULES.filter((m) => modules.includes(m.cle));
  const actif = moduleDuChemin(path);
  const courant = liens.find((l) => l.cle === actif)?.libelle ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {CATEGORIES.map((c) => {
          const groupe = liens.filter((l) => l.categorie === c.cle);
          if (groupe.length === 0) return null;
          return (
            <div key={c.cle} className="adm-groupe">
              {c.libelle && <div className="adm-cat">{c.libelle}</div>}
              {groupe.map((l) => (
                <Link key={l.chemin} href={l.chemin} className={l.cle === actif ? 'on' : ''}>
                  {l.libelle}
                </Link>
              ))}
            </div>
          );
        })}
      </div>
    </nav>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/NavAdmin.tsx"
mkdir -p 'src/components/bureau'
cat > 'src/components/bureau/GestionBureau.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { Fragment, useActionState, useState, useTransition } from 'react';
import {
  ajouterPoste, basculerAcces, basculerMembre, changerPoste, creerMembre,
  nouveauMotDePasse, supprimerMembre, supprimerPoste, type EtatBureau,
} from '@/app/bureau-actions';
import { CATEGORIES, MODULES_ATTRIBUABLES } from '@/lib/bureau/modules';

export type MembreBureau = {
  id: string; email: string; nom: string | null; role: string | null; poste: string | null; actif: boolean | null;
};
export type PosteBureau = { cle: string; libelle: string; modules: string[]; position: number };

const select = { padding: '.4rem', border: '2px solid var(--noir)', fontFamily: 'inherit', background: '#fff' } as const;

export default function GestionBureau({ membres, postes, moi }: { membres: MembreBureau[]; postes: PosteBureau[]; moi: string }) {
  const [retour, setRetour] = useState<EtatBureau>(null);
  const [enCours, start] = useTransition();
  const [etatMembre, actionMembre, envoiMembre] = useActionState<EtatBureau, FormData>(creerMembre, null);
  const [etatPoste, actionPoste, envoiPoste] = useActionState<EtatBureau, FormData>(ajouterPoste, null);

  const lancer = (action: () => Promise<EtatBureau>) => start(async () => setRetour(await action()));
  // Cases de la grille : cochées tout de suite à l'écran, sans attendre la réponse du serveur.
  const [local, setLocal] = useState<Record<string, boolean>>({});
  function basculer(poste: string, module: string, accorde: boolean) {
    const cle = `${poste}:${module}`;
    setLocal((v) => ({ ...v, [cle]: accorde }));
    start(async () => {
      const r = await basculerAcces(poste, module, accorde);
      setRetour(r);
      if (r?.erreur) setLocal((v) => { const { [cle]: _retire, ...reste } = v; return reste; });
    });
  }
  // Un ancien compte sans rôle est un administrateur.
  const valeurPoste = (m: MembreBureau) => ((m.role ?? 'admin') === 'admin' ? 'admin' : m.poste ?? '');
  const utilise = (cle: string) => membres.some((m) => m.poste === cle);
  const provisoire = etatMembre?.motDePasse ? etatMembre : retour?.motDePasse ? retour : null;

  return (
    <>
      {provisoire?.motDePasse && (
        <div className="msg ok">
          {provisoire.ok} Mot de passe provisoire :{' '}
          <code style={{ fontSize: '1.05rem', background: '#fff', padding: '.15rem .45rem', border: '2px solid var(--noir)', userSelect: 'all' }}>
            {provisoire.motDePasse}
          </code>
          <br />
          <span style={{ fontWeight: 400, fontSize: '.85rem' }}>
            Note-le maintenant et transmets-le au membre : il ne sera plus affiché. Connexion sur /admin/login.
          </span>
        </div>
      )}
      {retour?.erreur && <div className="msg ko">{retour.erreur}</div>}

      <div className="panel">
        <h2>Membres ({membres.length})</h2>
        <table className="tbl cartes compact">
          <thead><tr><th>Nom</th><th>E-mail</th><th>Poste</th><th>État</th><th></th></tr></thead>
          <tbody>
            {membres.map((m) => {
              const actif = m.actif !== false;
              return (
                <tr key={m.id} style={{ opacity: enCours ? .6 : 1 }}>
                  <td data-l="Nom" className="bloc"><strong>{m.nom || 'Sans nom'}</strong>{m.id === moi && ' (toi)'}</td>
                  <td data-l="E-mail" style={{ fontSize: '.85rem' }}>{m.email}</td>
                  <td data-l="Poste">
                    <select aria-label={`Poste de ${m.nom ?? m.email}`} value={valeurPoste(m)} style={select}
                      onChange={(e) => lancer(() => changerPoste(m.id, e.target.value))}>
                      {valeurPoste(m) === '' && <option value="">À attribuer</option>}
                      <option value="admin">Administrateur (tout)</option>
                      {postes.map((p) => <option key={p.cle} value={p.cle}>{p.libelle}</option>)}
                    </select>
                  </td>
                  <td data-l="État"><span className={`pill ${actif ? 'on' : 'off'}`}>{actif ? 'Actif' : 'Désactivé'}</span></td>
                  <td className="actions">
                    <button type="button" className="btn btn-y btn-sm" disabled={enCours}
                      onClick={() => {
                        if (window.confirm(`Générer un nouveau mot de passe pour ${m.nom ?? m.email} ? L'ancien ne fonctionnera plus.`)) {
                          lancer(() => nouveauMotDePasse(m.id));
                        }
                      }}>
                      Mot de passe
                    </button>{' '}
                    {m.id !== moi && (
                      <>
                        <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                          onClick={() => lancer(() => basculerMembre(m.id, !actif))}>
                          {actif ? 'Désactiver' : 'Réactiver'}
                        </button>{' '}
                        <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                          onClick={() => {
                            if (window.confirm(`Supprimer définitivement l'accès de ${m.nom ?? m.email} ?`)) {
                              lancer(() => supprimerMembre(m.id));
                            }
                          }}>
                          Suppr.
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <form action={actionMembre} className="panel">
        <h2>Ajouter un membre</h2>
        {etatMembre?.erreur && <div className="msg ko">{etatMembre.erreur}</div>}
        <div className="row3">
          <div className="field"><label htmlFor="bm-nom">Nom et prénom</label><input id="bm-nom" name="nom" required minLength={2} autoComplete="off" /></div>
          <div className="field"><label htmlFor="bm-email">E-mail (identifiant de connexion)</label><input id="bm-email" name="email" type="email" required autoComplete="off" /></div>
          <div className="field">
            <label htmlFor="bm-poste">Poste</label>
            <select id="bm-poste" name="poste" required defaultValue="">
              <option value="" disabled>Choisir un poste</option>
              {postes.map((p) => <option key={p.cle} value={p.cle}>{p.libelle}</option>)}
              <option value="admin">Administrateur (tout)</option>
            </select>
          </div>
        </div>
        <button className="btn btn-k btn-sm" disabled={envoiMembre}>{envoiMembre ? 'Création…' : "Créer l'accès"}</button>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.9rem' }}>
          Un mot de passe provisoire s&apos;affiche après la création, à transmettre au membre.
        </p>
      </form>

      <div className="panel">
        <h2>Modules par poste</h2>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginBottom: '1rem' }}>
          Coche les modules que chaque poste peut utiliser. Le changement s&apos;applique tout de suite, à la prochaine page ouverte par le membre.
          Les administrateurs ont tout, y compris cet écran.
        </p>
        <div className="tbl-wrap">
          <table className="tbl" style={{ minWidth: 220 + postes.length * 110 }}>
            <thead>
              <tr>
                <th>Module</th>
                {postes.map((p) => (
                  <th key={p.cle} style={{ textAlign: 'center' }}>
                    {p.libelle}
                    {!utilise(p.cle) && (
                      <>
                        {' '}
                        <button type="button" aria-label={`Supprimer le poste ${p.libelle}`} title="Supprimer ce poste" disabled={enCours}
                          onClick={() => { if (window.confirm(`Supprimer le poste « ${p.libelle} » ?`)) lancer(() => supprimerPoste(p.cle)); }}
                          style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '.8rem', color: '#6b6560' }}>
                          ✕
                        </button>
                      </>
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {CATEGORIES.map((c) => {
                const groupe = MODULES_ATTRIBUABLES.filter((m) => m.categorie === c.cle);
                if (groupe.length === 0) return null;
                return (
                  <Fragment key={c.cle}>
                    {c.libelle && (
                      <tr><td colSpan={postes.length + 1} style={{ background: '#f4f1ec', fontWeight: 700, fontSize: '.8rem' }}>{c.libelle}</td></tr>
                    )}
                    {groupe.map((m) => (
                      <tr key={m.cle}>
                        <td>{m.libelle}</td>
                        {postes.map((p) => (
                          <td key={p.cle} style={{ textAlign: 'center' }}>
                            <input type="checkbox" aria-label={`${m.libelle} pour ${p.libelle}`}
                              checked={local[`${p.cle}:${m.cle}`] ?? p.modules.includes(m.cle)} style={{ width: 18, height: 18 }}
                              onChange={(e) => basculer(p.cle, m.cle, e.target.checked)} />
                          </td>
                        ))}
                      </tr>
                    ))}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        </div>

        <form action={actionPoste} style={{ marginTop: '1.4rem' }}>
          {etatPoste?.ok && <div className="msg ok">{etatPoste.ok}</div>}
          {etatPoste?.erreur && <div className="msg ko">{etatPoste.erreur}</div>}
          <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <div className="field" style={{ flex: '1 1 240px', marginBottom: 0 }}>
              <label htmlFor="bp-libelle">Nouveau poste</label>
              <input id="bp-libelle" name="libelle" placeholder="Ex. Responsable buvette" maxLength={40} required />
            </div>
            <button className="btn btn-y btn-sm" disabled={envoiPoste}>Ajouter le poste</button>
          </div>
        </form>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/bureau/GestionBureau.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/FormSaisie.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useMemo, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import { creerEvenementRapide, saisirEcriture } from '@/app/compta-actions';
import { enCentimes, montant, montantOuVide } from '@/lib/compta/format';
import { ACCEPT_JUSTIFICATIF, envoyerJustificatif } from '@/components/compta/envoi';
import type { Compte, EvenementCompta, Journal, LigneSaisie, Retour } from '@/lib/compta/types';

type Props = {
  comptes: Compte[];
  journaux: Journal[];
  evenements: EvenementCompta[];
  dateDefaut: string;
};

type Mode = 'guidee' | 'libre';
type TypeOp = 'depense' | 'recette' | 'virement';
type LigneLibre = { cle: number; compte: string; evenement: string; debit: string; credit: string };

const ligneVide = (cle: number): LigneLibre => ({ cle, compte: '', evenement: '', debit: '', credit: '' });

/** Valeur de la liste « Événement » qui ouvre la création d'un événement. */
const NOUVEAU = '__nouveau';

export default function FormSaisie({ comptes, journaux, evenements: evenementsInitiaux, dateDefaut }: Props) {
  // Événements créés depuis cet écran, visibles tout de suite dans les listes.
  const [ajoutes, setAjoutes] = useState<EvenementCompta[]>([]);
  const evenements = useMemo(
    () => [...evenementsInitiaux, ...ajoutes.filter((a) => !evenementsInitiaux.some((e) => e.id === a.id))]
      .sort((a, b) => a.code.localeCompare(b.code)),
    [evenementsInitiaux, ajoutes]
  );
  const [creation, setCreation] = useState(false);
  const [nomEvt, setNomEvt] = useState('');
  const [dateEvt, setDateEvt] = useState('');
  const [erreurEvt, setErreurEvt] = useState('');

  const actifs = useMemo(() => comptes.filter((c) => c.actif), [comptes]);
  const tresos = actifs.filter((c) => c.type === 'tresorerie');
  const charges = actifs.filter((c) => c.type === 'charge');
  const produits = actifs.filter((c) => c.type === 'produit');
  const intitule = (n: string) => comptes.find((c) => c.numero === n)?.intitule ?? '';
  const codeEvt = (id?: string | null) => evenements.find((e) => e.id === id)?.code ?? '';
  const banque = tresos.find((c) => c.numero === '512000')?.numero ?? tresos[0]?.numero ?? '';

  const [mode, setMode] = useState<Mode>('guidee');
  const [type, setType] = useState<TypeOp>('depense');
  const [date, setDate] = useState(dateDefaut);
  const [libelle, setLibelle] = useState('');
  const [montantTxt, setMontantTxt] = useState('');
  const [compte, setCompte] = useState('');
  const [treso, setTreso] = useState(banque);
  const [tresoVers, setTresoVers] = useState(tresos.find((c) => c.numero !== banque)?.numero ?? '');
  const [evenement, setEvenement] = useState('');
  const [journalLibre, setJournalLibre] = useState('OD');
  const [lignesLibres, setLignesLibres] = useState<LigneLibre[]>([ligneVide(1), ligneVide(2)]);
  const [fichier, setFichier] = useState<File | null>(null);
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  const compteur = useRef(3);
  const inputFichier = useRef<HTMLInputElement>(null);

  const liste = type === 'depense' ? charges : produits;
  const compteEff = liste.some((c) => c.numero === compte) ? compte : liste[0]?.numero ?? '';
  const journalDe = (numero: string) => journaux.find((j) => j.compte_tresorerie === numero)?.code;

  // Lignes de l'écriture et journal, selon le mode de saisie.
  const { lignes, journal, invalide } = useMemo(() => {
    if (mode === 'libre') {
      let invalide = false;
      const lignes: LigneSaisie[] = [];
      for (const l of lignesLibres) {
        if (!l.compte && !l.debit && !l.credit) continue;
        const d = l.debit.trim() ? enCentimes(l.debit) : 0;
        const c = l.credit.trim() ? enCentimes(l.credit) : 0;
        if (!l.compte || d === null || c === null || (d > 0) === (c > 0)) invalide = true;
        lignes.push({ compte: l.compte, debit: d ?? 0, credit: c ?? 0, evenement_id: l.evenement || null });
      }
      return { lignes, journal: journalLibre, invalide };
    }

    const m = enCentimes(montantTxt) ?? 0;
    const evt = evenement || null;
    if (type === 'depense') {
      return {
        lignes: [
          { compte: compteEff, debit: m, credit: 0, evenement_id: evt },
          { compte: treso, debit: 0, credit: m },
        ] as LigneSaisie[],
        journal: journalDe(treso) ?? 'OD',
        invalide: false,
      };
    }
    if (type === 'recette') {
      return {
        lignes: [
          { compte: treso, debit: m, credit: 0 },
          { compte: compteEff, debit: 0, credit: m, evenement_id: evt },
        ] as LigneSaisie[],
        journal: journalDe(treso) ?? 'OD',
        invalide: false,
      };
    }
    const codes = [journalDe(treso), journalDe(tresoVers)];
    return {
      lignes: [
        { compte: tresoVers, debit: m, credit: 0 },
        { compte: treso, debit: 0, credit: m },
      ] as LigneSaisie[],
      journal: codes.includes('BQ') ? 'BQ' : codes.find(Boolean) ?? 'OD',
      invalide: treso === tresoVers,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, type, montantTxt, compteEff, treso, tresoVers, evenement, journalLibre, lignesLibres, journaux]);

  const totalDebit = lignes.reduce((s, l) => s + l.debit, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit, 0);
  const equilibree = !invalide && lignes.length >= 2 && totalDebit === totalCredit && totalDebit > 0;

  function majLigne(cle: number, champ: keyof Omit<LigneLibre, 'cle'>, valeur: string) {
    setLignesLibres((ls) => ls.map((l) => (l.cle === cle ? { ...l, [champ]: valeur } : l)));
  }

  function creerEvenement() {
    setErreurEvt('');
    start(async () => {
      const r = await creerEvenementRapide(nomEvt, dateEvt);
      if (r.erreur || !r.evenement) {
        setErreurEvt(r.erreur ?? 'Création impossible.');
        return;
      }
      setAjoutes((l) => [...l, r.evenement!]);
      setEvenement(r.evenement.id); // sélectionné d'office en saisie guidée
      setCreation(false);
      setNomEvt('');
      setDateEvt('');
    });
  }

  function valider() {
    setRetour(null);
    if (!date) return setRetour({ erreur: 'La date est obligatoire.' });
    if (!libelle.trim()) return setRetour({ erreur: 'Le libellé est obligatoire.' });
    if (!equilibree) {
      return setRetour({
        erreur: mode === 'libre'
          ? 'Écriture déséquilibrée ou ligne incomplète : chaque ligne porte un compte et un seul montant.'
          : type === 'virement' && treso === tresoVers
            ? 'Choisis deux comptes de trésorerie différents.'
            : 'Montant invalide.',
      });
    }

    start(async () => {
      let chemin: string | null = null;
      if (fichier) {
        try {
          chemin = await envoyerJustificatif(fichier, date.slice(0, 4));
        } catch (e: any) {
          setRetour({ erreur: e?.message ?? "L'envoi du justificatif a échoué." });
          return;
        }
      }
      const r = await saisirEcriture({ journal, date, libelle, lignes, justificatif: chemin });
      setRetour(r);
      if (r?.ok) {
        setLibelle('');
        setMontantTxt('');
        setFichier(null);
        if (inputFichier.current) inputFichier.current.value = '';
        setLignesLibres([ligneVide(compteur.current++), ligneVide(compteur.current++)]);
      }
    });
  }

  const optionsCompte = (liste: Compte[]) =>
    liste.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>);

  return (
    <>
      {retour?.ok && (
        <div className="cpt-msg ok">
          {retour.ok}{' '}
          {retour.id && <Link href={`/admin/compta/piece/${retour.id}`}>Voir la pièce</Link>}
        </div>
      )}
      {retour?.erreur && <div className="cpt-msg ko">{retour.erreur}</div>}

      <div className="cpt-panneau">
        <div className="cpt-outils" style={{ marginBottom: 10 }}>
          <button type="button" className={`cpt-btn${mode === 'guidee' ? ' p' : ''}`} onClick={() => setMode('guidee')}>
            Saisie guidée
          </button>
          <button type="button" className={`cpt-btn${mode === 'libre' ? ' p' : ''}`} onClick={() => setMode('libre')}>
            Saisie libre
          </button>
        </div>

        <div className="cpt-champs">
          {mode === 'guidee' ? (
            <div className="cpt-champ">
              <label htmlFor="s-type">Type</label>
              <select id="s-type" value={type} onChange={(e) => setType(e.target.value as TypeOp)}>
                <option value="depense">Dépense</option>
                <option value="recette">Recette</option>
                <option value="virement">Virement interne</option>
              </select>
            </div>
          ) : (
            <div className="cpt-champ">
              <label htmlFor="s-journal">Journal</label>
              <select id="s-journal" value={journalLibre} onChange={(e) => setJournalLibre(e.target.value)}>
                {journaux.map((j) => <option key={j.code} value={j.code}>{j.code}, {j.libelle}</option>)}
              </select>
            </div>
          )}
          <div className="cpt-champ">
            <label htmlFor="s-date">Date</label>
            <input id="s-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </div>
          <div className="cpt-champ l2">
            <label htmlFor="s-libelle">Libellé</label>
            <input id="s-libelle" type="text" value={libelle} maxLength={160} onChange={(e) => setLibelle(e.target.value)} />
          </div>

          {mode === 'guidee' && (
            <>
              <div className="cpt-champ">
                <label htmlFor="s-montant">Montant</label>
                <input id="s-montant" className="n" type="text" inputMode="decimal" placeholder="0,00"
                  value={montantTxt} onChange={(e) => setMontantTxt(e.target.value)} />
              </div>
              {type === 'virement' ? (
                <>
                  <div className="cpt-champ">
                    <label htmlFor="s-de">Depuis</label>
                    <select id="s-de" value={treso} onChange={(e) => setTreso(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-vers">Vers</label>
                    <select id="s-vers" value={tresoVers} onChange={(e) => setTresoVers(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                </>
              ) : (
                <>
                  <div className="cpt-champ">
                    <label htmlFor="s-treso">{type === 'depense' ? 'Payé par' : 'Encaissé sur'}</label>
                    <select id="s-treso" value={treso} onChange={(e) => setTreso(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-compte">{type === 'depense' ? 'Compte de charge' : 'Compte de produit'}</label>
                    <select id="s-compte" value={compteEff} onChange={(e) => setCompte(e.target.value)}>{optionsCompte(liste)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-evt">Événement</label>
                    <select id="s-evt" value={creation ? NOUVEAU : evenement}
                      onChange={(e) => {
                        if (e.target.value === NOUVEAU) { setCreation(true); return; }
                        setCreation(false);
                        setEvenement(e.target.value);
                      }}>
                      <option value="">Aucun, fonctionnement général</option>
                      {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}, {e.libelle}</option>)}
                      <option value={NOUVEAU}>+ Nouvel événement (absent de la liste)</option>
                    </select>
                  </div>
                </>
              )}
            </>
          )}

          <div className="cpt-champ l2">
            <label htmlFor="s-fichier">Justificatif (PDF ou photo)</label>
            <input id="s-fichier" ref={inputFichier} type="file" accept={ACCEPT_JUSTIFICATIF}
              onChange={(e) => setFichier(e.target.files?.[0] ?? null)} />
          </div>
        </div>

        {creation && (
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid #C9D0D8' }}>
            <h2>Nouvel événement</h2>
            {erreurEvt && <div className="cpt-msg ko">{erreurEvt}</div>}
            <div className="cpt-ligne">
              <div className="cpt-champ" style={{ flex: '2 1 220px' }}>
                <label htmlFor="s-nevt">Nom de l&apos;événement</label>
                <input id="s-nevt" type="text" value={nomEvt} maxLength={80} placeholder="Ex. Brocante de mai 2026"
                  onChange={(e) => setNomEvt(e.target.value)} />
              </div>
              <div className="cpt-champ">
                <label htmlFor="s-devt">Date (facultatif)</label>
                <input id="s-devt" type="date" value={dateEvt} onChange={(e) => setDateEvt(e.target.value)} />
              </div>
              <button type="button" className="cpt-btn p" disabled={pending} onClick={creerEvenement}>
                Créer l&apos;événement
              </button>
              <button type="button" className="cpt-btn" onClick={() => { setCreation(false); setErreurEvt(''); }}>
                Annuler
              </button>
            </div>
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
              Pour un événement passé ou qui n&apos;est pas sur le site. Il apparaît ensuite dans la liste et dans les budgets.
            </p>
          </div>
        )}
      </div>

      <div className="cpt-panneau">
        <h2>Lignes de l&apos;écriture, journal {journal}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr>
                <th>Compte</th>
                {mode === 'guidee' && <th>Intitulé</th>}
                <th>Évt</th>
                <th className="n">Débit</th>
                <th className="n">Crédit</th>
                {mode === 'libre' && <th></th>}
              </tr>
            </thead>
            <tbody>
              {mode === 'guidee'
                ? lignes.map((l, i) => (
                    <tr key={i}>
                      <td className="fixe">{l.compte}</td>
                      <td>{intitule(l.compte)}</td>
                      <td>{codeEvt(l.evenement_id)}</td>
                      <td className="n">{montantOuVide(l.debit)}</td>
                      <td className="n">{montantOuVide(l.credit)}</td>
                    </tr>
                  ))
                : lignesLibres.map((l) => (
                    <tr key={l.cle}>
                      <td>
                        <select aria-label="Compte" value={l.compte} onChange={(e) => majLigne(l.cle, 'compte', e.target.value)}>
                          <option value="">Choisir un compte</option>
                          {optionsCompte(actifs)}
                        </select>
                      </td>
                      <td>
                        <select aria-label="Événement" value={l.evenement} onChange={(e) => majLigne(l.cle, 'evenement', e.target.value)}>
                          <option value="">Aucun</option>
                          {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
                        </select>
                      </td>
                      <td>
                        <input aria-label="Débit" className="n" type="text" inputMode="decimal" value={l.debit}
                          onChange={(e) => majLigne(l.cle, 'debit', e.target.value)} />
                      </td>
                      <td>
                        <input aria-label="Crédit" className="n" type="text" inputMode="decimal" value={l.credit}
                          onChange={(e) => majLigne(l.cle, 'credit', e.target.value)} />
                      </td>
                      <td>
                        <button type="button" className="cpt-btn mini" aria-label="Retirer la ligne"
                          disabled={lignesLibres.length <= 2}
                          onClick={() => setLignesLibres((ls) => ls.filter((x) => x.cle !== l.cle))}>
                          Retirer
                        </button>
                      </td>
                    </tr>
                  ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={mode === 'guidee' ? 3 : 2}>Totaux</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
                {mode === 'libre' && <td></td>}
              </tr>
            </tfoot>
          </table>
        </div>

        {equilibree
          ? <p className="cpt-ok">Écriture équilibrée.</p>
          : <p className="cpt-ko">Écriture incomplète ou déséquilibrée.</p>}

        <div className="cpt-outils" style={{ marginTop: 10 }}>
          <button type="button" className="cpt-btn p" disabled={pending} onClick={valider}>
            {pending ? 'Enregistrement…' : "Valider l'écriture"}
          </button>
          {mode === 'libre' && (
            <>
              <button type="button" className="cpt-btn"
                onClick={() => setLignesLibres((ls) => [...ls, ligneVide(compteur.current++)])}>
                Ajouter une ligne
              </button>
              <button type="button" className="cpt-btn" onClick={() => setCreation(true)}>
                Nouvel événement
              </button>
            </>
          )}
        </div>
      </div>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/compta/FormSaisie.tsx"
mkdir -p 'src/components'
cat > 'src/components/nav-admin.css' <<'EOF_BUREAU_FICHIER'
/* Menu latéral de l'admin : catégories, liens plus serrés et défilement si le menu dépasse l'écran. */
.adm-cat{font-family:'DM Mono',monospace;font-size:.6rem;letter-spacing:.16em;text-transform:uppercase;
  color:#8a8179;padding:.9rem .9rem .25rem;}
.adm-groupe{display:flex;flex-direction:column;gap:.15rem;}
.adm-side .adm-nav-liens a{padding:.5rem .9rem;}

@media (min-width:901px){
  .adm-side .adm-nav{flex:1;min-height:0;overflow-y:auto;margin-right:-.6rem;padding-right:.6rem;}
  .adm-side .brand{margin-bottom:.9rem;}
}
@media (max-width:900px){
  .adm-nav.ouvert .adm-nav-liens{max-height:65vh;overflow-y:auto;}
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/nav-admin.css"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/GestionThemes.tsx' <<'EOF_BUREAU_FICHIER'
'use client';
import { useActionState, useEffect, useState, useTransition } from 'react';
import { basculerTheme, enregistrerTheme, supprimerTheme, type EtatThemeForm } from '@/app/theme-actions';
import {
  COULEUR_VALIDE, MODELES, MOTIFS, dateTheme, etatTheme, variablesTheme,
  type MotifTheme, type ThemeAccueil,
} from '@/lib/theme/types';
import { BlocTheme, Neige, PastilleTheme } from '@/components/theme/ThemeAccueil';

const ETATS = {
  en_ligne: { libelle: 'En ligne', classe: 'on' },
  programme: { libelle: 'Programmé', classe: 'new' },
  passe: { libelle: 'Passé', classe: 'off' },
  desactive: { libelle: 'Désactivé', classe: 'off' },
} as const;

const vide = (annee: number): ThemeAccueil => ({
  id: '', nom: '', couleur: '#F591BC', motif: 'aucun', etiquette: '', bandeau: '',
  titre: '', texte: '', bouton: 'En savoir plus', lien: '',
  debut: `${annee}-01-01`, fin: `${annee}-01-31`, actif: true,
});

/** Liste des thèmes programmés, formulaire d'ajout ou de modification, et aperçu. */
export default function GestionThemes({ themes, annee }: { themes: ThemeAccueil[]; annee: number }) {
  const [t, setT] = useState<ThemeAccueil>(vide(annee));
  const [modele, setModele] = useState('');
  const [message, setMessage] = useState('');
  const [etat, action, pending] = useActionState<EtatThemeForm, FormData>(enregistrerTheme, null);
  const [enCours, start] = useTransition();
  const maj = <K extends keyof ThemeAccueil>(cle: K, valeur: ThemeAccueil[K]) => setT((x) => ({ ...x, [cle]: valeur }));

  // Après un enregistrement réussi : retour à un formulaire vide.
  useEffect(() => {
    if (etat?.ok) { setT(vide(annee)); setModele(''); }
  }, [etat, annee]);

  function choisirModele(cle: string) {
    setModele(cle);
    const m = MODELES[cle];
    if (!m) return;
    const { du, au, ...reste } = m;
    setT((x) => ({ ...x, ...reste, debut: `${annee}-${du}`, fin: `${annee}-${au}` }));
  }

  const couleurOk = COULEUR_VALIDE.test(t.couleur);
  const apercu = couleurOk ? t : { ...t, couleur: '#F591BC' };
  const style = variablesTheme(apercu) as React.CSSProperties;

  return (
    <>
      <div className="panel">
        <h2>Thèmes programmés</h2>
        {message && <div className="msg ko">{message}</div>}
        <table className="tbl cartes compact">
          <thead><tr><th>Thème</th><th>Couleur</th><th>Période</th><th>État</th><th></th></tr></thead>
          <tbody>
            {themes.map((x) => {
              const e = ETATS[etatTheme(x)];
              return (
                <tr key={x.id} style={{ opacity: enCours ? .6 : 1 }}>
                  <td data-l="Thème" className="bloc"><strong>{x.nom}</strong></td>
                  <td data-l="Couleur"><i className="th-pt" style={{ background: x.couleur }} /></td>
                  <td data-l="Période">du {dateTheme(x.debut)} au {dateTheme(x.fin)}</td>
                  <td data-l="État"><span className={`pill ${e.classe}`}>{e.libelle}</span></td>
                  <td className="actions">
                    <button type="button" className="btn btn-y btn-sm" onClick={() => { setT(x); setModele(''); }}>Modifier</button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => start(async () => { const r = await basculerTheme(x.id, !x.actif); setMessage(r?.erreur ?? ''); })}>
                      {x.actif ? 'Désactiver' : 'Activer'}
                    </button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => {
                        if (!window.confirm(`Supprimer le thème « ${x.nom} » ?`)) return;
                        start(async () => { const r = await supprimerTheme(x.id); setMessage(r?.erreur ?? ''); });
                      }}>
                      Suppr.
                    </button>
                  </td>
                </tr>
              );
            })}
            {themes.length === 0 && (
              <tr><td colSpan={5} style={{ color: '#6b6560' }}>Aucun thème. Choisis un modèle ci-dessous pour commencer.</td></tr>
            )}
          </tbody>
        </table>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.9rem' }}>
          Un thème s&apos;affiche du premier au dernier jour inclus, puis se retire tout seul. Si deux thèmes se chevauchent,
          le plus récemment commencé s&apos;affiche.
        </p>
      </div>

      <form action={action} className="panel">
        <h2>{t.id ? `Modifier « ${t.nom} »` : 'Ajouter un thème'}</h2>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
        <input type="hidden" name="id" value={t.id} />

        {!t.id && (
          <div className="field">
            <label htmlFor="th-modele">Partir d&apos;un modèle</label>
            <select id="th-modele" value={modele} onChange={(e) => choisirModele(e.target.value)}>
              <option value="">Thème personnalisé</option>
              {Object.entries(MODELES).map(([cle, m]) => <option key={cle} value={cle}>{m.nom}</option>)}
            </select>
          </div>
        )}

        <div className="row3">
          <div className="field">
            <label htmlFor="th-nom">Nom du thème</label>
            <input id="th-nom" name="nom" value={t.nom} maxLength={40} required onChange={(e) => maj('nom', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-debut">Du</label>
            <input id="th-debut" name="debut" type="date" value={t.debut} required onChange={(e) => maj('debut', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-fin">Au (inclus)</label>
            <input id="th-fin" name="fin" type="date" value={t.fin} required onChange={(e) => maj('fin', e.target.value)} />
          </div>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="th-couleur">Couleur du haut de page</label>
            <div style={{ display: 'flex', gap: '.5rem' }}>
              <input type="color" aria-label="Choisir la couleur" value={couleurOk ? t.couleur : '#F591BC'}
                onChange={(e) => maj('couleur', e.target.value.toUpperCase())}
                style={{ width: 56, padding: 2, flex: 'none' }} />
              <input id="th-couleur" name="couleur" value={t.couleur} maxLength={7} required
                onChange={(e) => maj('couleur', e.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="th-motif">Motif</label>
            <select id="th-motif" name="motif" value={t.motif} onChange={(e) => maj('motif', e.target.value as MotifTheme)}>
              {Object.entries(MOTIFS).map(([cle, libelle]) => <option key={cle} value={cle}>{libelle}</option>)}
            </select>
          </div>
          <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}>
            <input type="checkbox" name="actif" checked={t.actif} onChange={(e) => maj('actif', e.target.checked)} style={{ width: 'auto' }} />
            Thème activé
          </label>
        </div>

        <div className="row2">
          <div className="field">
            <label htmlFor="th-etiquette">Étiquette au-dessus du titre</label>
            <input id="th-etiquette" name="etiquette" value={t.etiquette} maxLength={60}
              placeholder="Octobre Rose · Limetz-Villez" onChange={(e) => maj('etiquette', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-bandeau">Message du bandeau défilant</label>
            <input id="th-bandeau" name="bandeau" value={t.bandeau} maxLength={80} onChange={(e) => maj('bandeau', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label htmlFor="th-titre">Titre du bloc de message (facultatif)</label>
          <input id="th-titre" name="titre" value={t.titre} maxLength={90} onChange={(e) => maj('titre', e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="th-texte">Texte du bloc de message (facultatif)</label>
          <textarea id="th-texte" name="texte" rows={3} value={t.texte} maxLength={400} onChange={(e) => maj('texte', e.target.value)} />
        </div>
        <div className="row2">
          <div className="field">
            <label htmlFor="th-bouton">Texte du bouton</label>
            <input id="th-bouton" name="bouton" value={t.bouton} maxLength={30} onChange={(e) => maj('bouton', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-lien">Lien du bouton (vide = pas de bouton)</label>
            <input id="th-lien" name="lien" value={t.lien} maxLength={300} placeholder="https://… ou /evenements/…"
              onChange={(e) => maj('lien', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>Aperçu</label>
          <div className="th-apercu" style={style}>
            <div className="th-apercu-hero">
              <Neige theme={apercu} />
              <PastilleTheme theme={{ ...apercu, nom: apercu.nom || 'Nom du thème' }} />
              <div><span className="kicker mono">{apercu.etiquette || 'Saison · Limetz-Villez'}</span></div>
              <h3>Toute <span className="a1">l&apos;année</span><br /><span className="a2">on fait la fête</span></h3>
            </div>
            <div className="th-bandeau">
              <div className="marquee"><div><span>{apercu.bandeau || 'Message du bandeau'}</span><span>Prochains événements</span></div></div>
            </div>
            <BlocTheme theme={apercu} />
          </div>
        </div>

        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          <button className="btn btn-k btn-sm" disabled={pending}>
            {pending ? 'Enregistrement…' : t.id ? 'Enregistrer les modifications' : 'Ajouter le thème'}
          </button>
          {t.id && (
            <button type="button" className="btn btn-w btn-sm" onClick={() => { setT(vide(annee)); setModele(''); }}>
              Annuler la modification
            </button>
          )}
        </div>
      </form>
    </>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/theme/GestionThemes.tsx"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/ThemeAccueil.tsx' <<'EOF_BUREAU_FICHIER'
import type { ThemeAccueil } from '@/lib/theme/types';
import './theme.css';

/** Motif du thème : ruban de sensibilisation ou étoile. Les flocons sont un fond, voir Neige. */
export function Motif({ theme }: { theme: ThemeAccueil }) {
  if (theme.motif === 'ruban') {
    const trace = 'M13 86 L40 32 C47 17 40 8 30 8 C20 8 13 17 20 32 L47 86';
    return (
      <svg className="th-motif" viewBox="0 0 60 92" aria-hidden="true" focusable="false">
        <path d={trace} fill="none" stroke="#141014" strokeWidth="17" strokeLinejoin="round" />
        <path d={trace} fill="none" stroke={theme.couleur} strokeWidth="10" strokeLinejoin="round" />
      </svg>
    );
  }
  if (theme.motif === 'etoile' || theme.motif === 'flocons') {
    return <span className="th-etoile" aria-hidden="true">✷</span>;
  }
  return null;
}

/** Fond de flocons du haut de page. */
export function Neige({ theme }: { theme: ThemeAccueil }) {
  return theme.motif === 'flocons' ? <div className="th-neige" aria-hidden="true" /> : null;
}

/** Pastille inclinée portant le nom du thème. */
export function PastilleTheme({ theme }: { theme: ThemeAccueil }) {
  return (
    <div className="th-pastille">
      <Motif theme={theme} />
      <b>{theme.nom}</b>
    </div>
  );
}

/** Bloc de message sous le bandeau défilant. Rien n'est affiché sans titre ni texte. */
export function BlocTheme({ theme, style }: { theme: ThemeAccueil; style?: React.CSSProperties }) {
  if (!theme.titre && !theme.texte) return null;
  const externe = /^https?:\/\//.test(theme.lien);
  return (
    <section className="th-bloc" style={style} aria-label={theme.nom}>
      <div className="th-bloc-in">
        <Motif theme={theme} />
        <div>
          {theme.titre && <h2>{theme.titre}</h2>}
          {theme.texte && <p>{theme.texte}</p>}
          {theme.lien && (
            <a className="btn btn-k" href={theme.lien} {...(externe ? { target: '_blank', rel: 'noreferrer' } : {})}>
              {theme.bouton || 'En savoir plus'}
            </a>
          )}
        </div>
      </div>
    </section>
  );
}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/theme/ThemeAccueil.tsx"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/theme.css' <<'EOF_BUREAU_FICHIER'
/* Habillage de la page d'accueil par un thème (Octobre Rose, Noël...). */

/* ---------- Haut de page ---------- */
.hero.th::before{background:repeating-conic-gradient(from 0deg at 50% 42%,
  var(--th-rayon) 0deg 7deg, transparent 7deg 14deg);}
.hero.th h1 .jaune{color:var(--th-a1);}
.hero.th h1 .cyan{color:var(--th-a2);}
.hero.th .hero-tag,.hero.th .scroll-hint{color:var(--th-texte);}
.hero.th .kicker{color:var(--th-clair);}

.th-pastille{position:absolute;top:0;right:0;z-index:4;display:flex;align-items:center;gap:.6rem;
  background:var(--creme);color:var(--noir);border:3px solid var(--noir);box-shadow:5px 5px 0 var(--noir);
  padding:.55rem .9rem;transform:rotate(4deg);text-align:left;}
.th-pastille b{font-family:'Anton',sans-serif;font-weight:400;text-transform:uppercase;
  font-size:1.15rem;line-height:.95;max-width:9ch;}
.th-motif{flex:none;width:30px;height:46px;}
.th-etoile{flex:none;font-size:2.1rem;line-height:1;color:var(--th);}

.th-neige{position:absolute;inset:0;z-index:2;pointer-events:none;opacity:.9;
  background-image:radial-gradient(#fff 2px,transparent 2.5px),radial-gradient(#fff 1.5px,transparent 2px),
    radial-gradient(#fff 3px,transparent 3.5px);
  background-size:90px 110px,60px 70px,150px 130px;background-position:10px 20px,40px 60px,70px 10px;}

/* ---------- Bandeau défilant ---------- */
.th-bandeau .marquee{color:var(--th-clair);border-color:var(--th);}
.th-bandeau .marquee span::after{color:#fff;}

/* ---------- Bloc de message ---------- */
.th-bloc{padding:2.6rem 2rem;background:var(--th-pale);border-bottom:3px solid var(--noir);}
.th-bloc-in{max-width:820px;margin:0 auto;display:flex;gap:1.4rem;align-items:flex-start;}
.th-bloc .th-motif{width:46px;height:70px;}
.th-bloc .th-etoile{font-size:3rem;}
.th-bloc h2{font-size:clamp(1.7rem,4.4vw,2.6rem);line-height:.98;margin-bottom:.7rem;}
.th-bloc p{font-size:1.02rem;line-height:1.55;max-width:58ch;margin-bottom:1.2rem;}
.th-bloc p:last-child{margin-bottom:0;}

@media (max-width:760px){
  /* Sur mobile, la pastille se place sous le logo au lieu du coin. */
  .th-pastille{position:relative;display:inline-flex;margin:0 auto 1.6rem;}
  .th-bloc{padding:2rem 1.2rem;}
  .th-bloc-in{flex-direction:column;gap:.8rem;}
}

/* ---------- Aperçu dans l'admin ---------- */
.th-apercu{border:3px solid var(--noir);overflow:hidden;background:var(--creme);}
.th-apercu-hero{position:relative;background:var(--th);padding:1.6rem 1rem 2rem;text-align:center;overflow:hidden;}
.th-apercu-hero::before{content:"";position:absolute;inset:-60% -30%;
  background:repeating-conic-gradient(from 0deg at 50% 42%,var(--th-rayon) 0deg 7deg,transparent 7deg 14deg);}
.th-apercu-hero > *{position:relative;z-index:3;}
.th-apercu-hero .th-neige{position:absolute;z-index:2;}
.th-apercu-hero .th-pastille{position:relative;display:inline-flex;margin-bottom:1rem;}
.th-apercu-hero .kicker{color:var(--th-clair);font-size:.62rem;}
.th-apercu-hero h3{font-size:clamp(1.8rem,6vw,3rem);line-height:.88;color:var(--creme);
  text-shadow:4px 4px 0 var(--noir);margin-top:1rem;}
.th-apercu-hero h3 .a1{color:var(--th-a1);}
.th-apercu-hero h3 .a2{color:var(--th-a2);}
.th-apercu .marquee div{animation:none;font-size:.9rem;padding:.5rem 0;}
.th-apercu .th-bloc{padding:1.2rem 1rem;}
.th-apercu .th-bloc h2{font-size:1.3rem;}
.th-apercu .th-bloc p{font-size:.9rem;}
.th-pt{display:inline-block;width:22px;height:22px;border:2px solid var(--noir);vertical-align:middle;}
EOF_BUREAU_FICHIER
echo "  ✓ src/components/theme/theme.css"
mkdir -p 'src/lib/bureau'
cat > 'src/lib/bureau/modules.ts' <<'EOF_BUREAU_FICHIER'
/** Modules du back-office : clé, libellé du menu, chemin et catégorie. */
export const MODULES = [
  { cle: 'tableau',      libelle: 'Tableau de bord',       chemin: '/admin',              categorie: 'general' },
  { cle: 'evenements',   libelle: 'Événements',            chemin: '/admin/evenements',   categorie: 'evenements' },
  { cle: 'reservations', libelle: 'Réservations',          chemin: '/admin/reservations', categorie: 'evenements' },
  { cle: 'demandes',     libelle: 'Demandes reçues',       chemin: '/admin/demandes',     categorie: 'evenements' },
  { cle: 'tresorerie',   libelle: 'Trésorerie',            chemin: '/admin/tresorerie',   categorie: 'finances' },
  { cle: 'compta',       libelle: 'Comptabilité',          chemin: '/admin/compta',       categorie: 'finances' },
  { cle: 'tresors',      libelle: 'Trésors de Noël',       chemin: '/admin/tresors',      categorie: 'animations' },
  { cle: 'pere-noel',    libelle: 'Père Noël vidéo',       chemin: '/admin/pere-noel',    categorie: 'animations' },
  { cle: 'roue',         libelle: 'Roue de la Rentrée',    chemin: '/admin/roue',         categorie: 'animations' },
  { cle: 'theme',        libelle: 'Thème de l\u2019accueil', chemin: '/admin/theme',      categorie: 'site' },
  { cle: 'partenaires',  libelle: 'Partenaires',           chemin: '/admin/partenaires',  categorie: 'site' },
  { cle: 'association',  libelle: 'Association',           chemin: '/admin/association',  categorie: 'site' },
  { cle: 'parametres',   libelle: 'Réglages du site',      chemin: '/admin/parametres',   categorie: 'site' },
  { cle: 'maintenance',  libelle: 'Maintenance',           chemin: '/admin/maintenance',  categorie: 'site' },
  // Réservé aux administrateurs : ne peut pas être confié à un poste.
  { cle: 'bureau',       libelle: 'Accès du bureau',       chemin: '/admin/bureau',       categorie: 'bureau' },
] as const;

export type ModuleCle = (typeof MODULES)[number]['cle'];

export const CATEGORIES: { cle: string; libelle: string }[] = [
  { cle: 'general', libelle: '' },
  { cle: 'evenements', libelle: 'Événements' },
  { cle: 'finances', libelle: 'Finances' },
  { cle: 'animations', libelle: 'Animations' },
  { cle: 'site', libelle: 'Site' },
  { cle: 'bureau', libelle: 'Bureau' },
];

/** Modules qu'un administrateur peut confier à un poste. */
export const MODULES_ATTRIBUABLES = MODULES.filter((m) => m.cle !== 'bureau');
export const TOUS_LES_MODULES: ModuleCle[] = MODULES.map((m) => m.cle);

/** Chemins rattachés à un autre module que celui de leur préfixe. */
const CHEMINS_ANNEXES: { prefixe: string; cle: ModuleCle }[] = [
  { prefixe: '/admin/pointage', cle: 'reservations' },
];

/** Module dont dépend une page de l'admin, d'après son chemin. null si la page est inconnue. */
export function moduleDuChemin(chemin: string): ModuleCle | null {
  if (chemin === '/admin' || chemin === '/admin/') return 'tableau';
  const annexe = CHEMINS_ANNEXES.find((a) => chemin.startsWith(a.prefixe));
  if (annexe) return annexe.cle;
  const trouve = MODULES.find((m) => m.chemin !== '/admin' && (chemin === m.chemin || chemin.startsWith(`${m.chemin}/`)));
  return trouve?.cle ?? null;
}

/** Première page accessible, pour rediriger un membre qui n'a pas accès à la page demandée. */
export function premiereChemin(modules: readonly string[]): string | null {
  return MODULES.find((m) => modules.includes(m.cle))?.chemin ?? null;
}

/** Les deux modules dont les données sont protégées en base par is_staff(). */
export const MODULES_FINANCES: ModuleCle[] = ['tresorerie', 'compta'];
EOF_BUREAU_FICHIER
echo "  ✓ src/lib/bureau/modules.ts"
mkdir -p 'src/lib/supabase'
cat > 'src/lib/supabase/server.ts' <<'EOF_BUREAU_FICHIER'
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { createAdminClient } from '@/lib/supabase/admin';
import { MODULES_FINANCES, TOUS_LES_MODULES, type ModuleCle } from '@/lib/bureau/modules';

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export type RoleAdmin = 'admin' | 'tresorier' | 'membre';

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (list: CookieToSet[]) => {
          try {
            list.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // appelé depuis un Server Component : le middleware rafraîchit
          }
        },
      },
    }
  );
}

type Membre = {
  role: RoleAdmin;
  nom: string | null;
  poste: string | null;
  posteLibelle: string | null;
  modules: string[];
};

/**
 * Fiche du membre connecté : rôle, poste et modules accordés à ce poste.
 * Tant que supabase/bureau.sql n'a pas été exécuté, on retombe sur l'ancien fonctionnement
 * (admin = tout, trésorier = trésorerie et comptabilité).
 */
async function lireMembre(supabase: Awaited<ReturnType<typeof createClient>>, userId: string): Promise<Membre | null> {
  try {
    const db = createAdminClient();
    const { data, error } = await db
      .from('admins').select('role, nom, poste, actif').eq('id', userId).maybeSingle();
    if (!error) {
      if (!data || data.actif === false) return null;
      const role = ((data.role as RoleAdmin | null) ?? 'admin');
      if (role === 'admin') {
        return { role, nom: data.nom, poste: null, posteLibelle: 'Administrateur', modules: [...TOUS_LES_MODULES] };
      }
      const { data: poste } = data.poste
        ? await db.from('bureau_postes').select('libelle, modules').eq('cle', data.poste).maybeSingle()
        : { data: null };
      // Un ancien compte « trésorier » sans poste garde au minimum ses deux modules.
      const modules = (poste?.modules as string[] | undefined) ?? (role === 'tresorier' ? [...MODULES_FINANCES] : []);
      return { role, nom: data.nom, poste: data.poste, posteLibelle: poste?.libelle ?? null, modules };
    }
  } catch {
    // clé de service absente ou base pas encore à jour : ancien fonctionnement ci-dessous
  }

  const { data } = await supabase.from('admins').select('id, role').eq('id', userId).maybeSingle();
  if (!data) return null;
  const role = ((data.role as RoleAdmin | null) ?? 'admin');
  return {
    role, nom: null, poste: null, posteLibelle: null,
    modules: role === 'admin' ? [...TOUS_LES_MODULES] : [...MODULES_FINANCES],
  };
}

/**
 * Vérifie l'utilisateur courant et ses droits.
 *
 * Sans argument (comptabilité, trésorerie, layout) :
 * - isAdmin : administrateur uniquement
 * - isStaff : administrateur, ou membre ayant la trésorerie ou la comptabilité
 *
 * Avec un module : isAdmin et isStaff valent vrai si le poste du membre donne accès à ce module.
 * Le client renvoyé peut alors écrire dans les tables du module, les règles de la base
 * restant réservées aux administrateurs. Toujours passer le module de la page ou de l'action :
 * c'est ce contrôle, côté serveur, qui cloisonne les modules entre eux.
 */
export async function requireAdmin(module?: ModuleCle) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const rien = {
    supabase, user: user ?? null, isAdmin: false, isStaff: false, superAdmin: false, membre: false,
    role: null as RoleAdmin | null, poste: null as string | null, posteLibelle: null as string | null,
    nom: null as string | null, modules: [] as string[],
  };
  if (!user) return rien;

  const m = await lireMembre(supabase, user.id);
  if (!m) return rien;

  const superAdmin = m.role === 'admin';
  const base = {
    user, superAdmin, membre: true, role: m.role, poste: m.poste, posteLibelle: m.posteLibelle,
    nom: m.nom, modules: m.modules,
  };

  if (!module) {
    const finances = superAdmin || m.modules.some((x) => (MODULES_FINANCES as string[]).includes(x));
    return { ...base, supabase, isAdmin: superAdmin, isStaff: finances };
  }

  // « bureau » n'est jamais attribuable à un poste.
  const acces = superAdmin || (module !== 'bureau' && m.modules.includes(module));
  // Trésorerie et comptabilité : la base contrôle déjà via is_staff(), on garde le client du membre.
  const elever = acces && !superAdmin && !(MODULES_FINANCES as string[]).includes(module);
  return {
    ...base,
    supabase: elever ? (createAdminClient() as unknown as typeof supabase) : supabase,
    isAdmin: acces,
    isStaff: acces,
  };
}
EOF_BUREAU_FICHIER
echo "  ✓ src/lib/supabase/server.ts"
mkdir -p 'src/lib/theme'
cat > 'src/lib/theme/db.ts' <<'EOF_BUREAU_FICHIER'
import 'server-only';
import { createAdminClient } from '@/lib/supabase/admin';
import type { ThemeAccueil } from './types';

/** Les thèmes sont rangés dans homepage_modules, comme la Roue de la Rentrée. */
export const CLE_MODULE = 'theme_accueil';

export async function getThemes(): Promise<ThemeAccueil[]> {
  try {
    const { data } = await createAdminClient()
      .from('homepage_modules').select('config').eq('module_key', CLE_MODULE).maybeSingle();
    const themes = (data?.config as { themes?: ThemeAccueil[] } | null)?.themes;
    return Array.isArray(themes) ? themes : [];
  } catch {
    // Un souci de lecture ne doit jamais empêcher la page d'accueil de s'afficher.
    return [];
  }
}
EOF_BUREAU_FICHIER
echo "  ✓ src/lib/theme/db.ts"
mkdir -p 'src/lib/theme'
cat > 'src/lib/theme/types.ts' <<'EOF_BUREAU_FICHIER'
import { texteSur } from '@/lib/format';

export type MotifTheme = 'ruban' | 'flocons' | 'etoile' | 'aucun';

/** Un thème d'habillage de la page d'accueil, affiché entre deux dates. */
export interface ThemeAccueil {
  id: string;
  nom: string;
  /** Couleur du haut de page, au format #RRGGBB. */
  couleur: string;
  motif: MotifTheme;
  /** Étiquette noire au-dessus du titre. */
  etiquette: string;
  /** Message ajouté au bandeau défilant. */
  bandeau: string;
  /** Bloc de message sous le bandeau (facultatif). */
  titre: string;
  texte: string;
  bouton: string;
  lien: string;
  /** Dates incluses, au format AAAA-MM-JJ. */
  debut: string;
  fin: string;
  actif: boolean;
}

export const MOTIFS: Record<MotifTheme, string> = {
  ruban: 'Ruban',
  flocons: 'Flocons',
  etoile: 'Étoile',
  aucun: 'Aucun',
};

type Modele = Omit<ThemeAccueil, 'id' | 'debut' | 'fin' | 'actif'> & { du: string; au: string };

/** Thèmes prêts à l'emploi : ils pré-remplissent le formulaire, tout reste modifiable. */
export const MODELES: Record<string, Modele> = {
  'octobre-rose': {
    nom: 'Octobre Rose', couleur: '#F591BC', motif: 'ruban',
    etiquette: 'Octobre Rose · Limetz-Villez',
    bandeau: 'Octobre Rose · Le village se met au rose',
    titre: 'En octobre, le village se met au rose',
    texte: 'Le Comité des Fêtes s\u2019associe à Octobre Rose, le mois de sensibilisation au dépistage du cancer du sein.',
    bouton: 'En savoir plus', lien: '', du: '10-01', au: '10-31',
  },
  movember: {
    nom: 'Movember', couleur: '#2F6FD0', motif: 'etoile',
    etiquette: 'Movember · Limetz-Villez',
    bandeau: 'Movember · Le village se mobilise',
    titre: 'En novembre, on en parle',
    texte: 'Le Comité des Fêtes relaie Movember, le mois de sensibilisation à la santé masculine.',
    bouton: 'En savoir plus', lien: '', du: '11-01', au: '11-30',
  },
  telethon: {
    nom: 'Téléthon', couleur: '#F7B500', motif: 'etoile',
    etiquette: 'Téléthon · Limetz-Villez',
    bandeau: 'Téléthon · Le village se mobilise',
    titre: 'Le village se mobilise pour le Téléthon',
    texte: 'Retrouvez les animations organisées au profit du Téléthon.',
    bouton: 'En savoir plus', lien: '', du: '12-01', au: '12-07',
  },
  noel: {
    nom: 'Noël', couleur: '#C8102E', motif: 'flocons',
    etiquette: 'Noël au village · Limetz-Villez',
    bandeau: 'Joyeux Noël',
    titre: '', texte: '', bouton: '', lien: '', du: '12-08', au: '12-26',
  },
  'fete-nationale': {
    nom: 'Fête nationale', couleur: '#1F4FA8', motif: 'etoile',
    etiquette: '14 juillet · Limetz-Villez',
    bandeau: 'Bonne fête nationale',
    titre: '', texte: '', bouton: '', lien: '', du: '07-10', au: '07-14',
  },
};

export const COULEUR_VALIDE = /^#[0-9a-fA-F]{6}$/;

/** Date du jour à Paris, au format AAAA-MM-JJ. */
export function jourParis(maintenant = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(maintenant);
}

export type EtatTheme = 'en_ligne' | 'programme' | 'passe' | 'desactive';

export function etatTheme(t: ThemeAccueil, jour = jourParis()): EtatTheme {
  if (!t.actif) return 'desactive';
  if (jour < t.debut) return 'programme';
  if (jour > t.fin) return 'passe';
  return 'en_ligne';
}

/** Thème à afficher aujourd'hui : actif et dans sa période. Le plus récemment commencé l'emporte. */
export function themeDuJour(themes: ThemeAccueil[], jour = jourParis()): ThemeAccueil | null {
  return (
    themes
      .filter((t) => etatTheme(t, jour) === 'en_ligne' && COULEUR_VALIDE.test(t.couleur))
      .sort((a, b) => b.debut.localeCompare(a.debut))[0] ?? null
  );
}

/** Version foncée et saturée d'une couleur (#RRGGBB), pour un titre lisible sur fond clair. */
export function foncer(hex: string): string {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d > 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
  }
  h = Math.round(h * 60 + 360) % 360;
  const l0 = (max + min) / 2;
  const s0 = d === 0 ? 0 : d / (1 - Math.abs(2 * l0 - 1));
  // Même teinte, saturation soutenue, luminosité ramenée à 38 %.
  return `hsl(${h} ${Math.round(Math.max(s0, 0.7) * 100)}% 38%)`;
}

/**
 * Variables CSS de l'habillage, déduites de la couleur du thème :
 * texte clair ou foncé selon le fond, accents et rayons assortis.
 */
export function variablesTheme(t: ThemeAccueil): Record<string, string> {
  const fondClair = texteSur(t.couleur) === '#141014';
  return {
    '--evt': t.couleur,
    '--th': t.couleur,
    '--th-texte': fondClair ? '#141014' : '#FFF8EC',
    '--th-a1': fondClair ? '#FFFFFF' : '#FFD400',
    '--th-a2': fondClair ? foncer(t.couleur) : '#FFFFFF',
    '--th-rayon': fondClair ? 'rgba(255,255,255,.55)' : 'rgba(255,255,255,.2)',
    '--th-clair': `color-mix(in srgb, ${t.couleur} 45%, #ffffff)`,
    '--th-pale': `color-mix(in srgb, ${t.couleur} 16%, #ffffff)`,
  };
}

/** Date AAAA-MM-JJ -> « 1er octobre », « 31 octobre ». */
export function dateTheme(iso: string): string {
  const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const [a, m, j] = iso.split('-').map(Number);
  if (!a || !m || !j) return iso;
  return `${j === 1 ? '1er' : j} ${MOIS[m - 1]} ${a}`;
}
EOF_BUREAU_FICHIER
echo "  ✓ src/lib/theme/types.ts"
mkdir -p 'src/lib'
cat > 'src/lib/types.ts' <<'EOF_BUREAU_FICHIER'
export type Saison = 'printemps' | 'ete' | 'automne' | 'hiver';

export interface SiteSettings {
  id: number;
  hero_kicker: string;
  hero_titre_1: string;
  hero_titre_accent: string;
  hero_titre_2: string;
  hero_texte: string;
  hero_couleur: string;
  logo_url: string | null;
  logo_blanc_url: string | null;
  email_contact: string;
  facebook_url: string | null;
  adresse: string;
  asso_titre: string;
  asso_texte: string;
  benevoles_titre: string;
  benevoles_texte: string;
}

export interface Stat { id: string; valeur: string; libelle: string; position: number; }

export interface Evenement {
  id: string;
  slug: string;
  titre: string;
  sous_titre: string | null;
  chapo: string | null;
  description: string | null;
  couleur: string;
  couleur_sombre: string;
  date_debut: string;
  date_fin: string | null;
  heure_debut: string | null;
  heure_fin: string | null;
  lieu: string | null;
  adresse: string | null;
  tarif: string;
  lien_reservation: string | null;
  libelle_reservation: string;
  billetterie_active: boolean;
  prix_centimes: number;
  places_max: number | null;
  places_par_reservation: number;
  cloture_reservations: string | null;
  saison: Saison;
  image_url: string | null;
  publie: boolean;
  position: number;
}

export interface Creneau {
  id: string; evenement_id: string; heure: string; titre: string;
  description: string | null; scene: string | null; position: number;
}

export interface InfoBloc {
  id: string; evenement_id: string; titre: string; lignes: string[]; position: number;
}

export interface FaqItem {
  id: string; evenement_id: string | null; question: string; reponse: string; position: number;
}

export interface Demande {
  id: string; evenement_id: string | null; nom: string; email: string;
  telephone: string | null; type: string; message: string | null;
  statut: 'nouveau' | 'traite' | 'refuse'; created_at: string;
}

export interface Reservation {
  id: string;
  evenement_id: string;
  nom: string;
  /** Vide pour certaines réservations saisies à la main. */
  email: string | null;
  telephone: string | null;
  commentaire: string | null;
  places: number;
  montant_centimes: number;
  reference: string;
  checkout_id: string | null;
  transaction_code: string | null;
  statut: 'en_attente' | 'payee' | 'echouee' | 'expiree' | 'remboursee' | 'annulee';
  paye_le: string | null;
  code_billet: string;
  scanne_le: string | null;
  created_at: string;
  /** Paiement hors ligne ; vide = paiement en ligne (SumUp). */
  mode_paiement: 'especes' | 'cheque' | null;
  paiement_ref: string | null;
  /** Nom de l'admin pour une réservation saisie à la main. */
  saisie_par: string | null;
  /** Réservation d'un exposant (formules d'emplacement) plutôt que d'un participant. */
  exposant: boolean;
}

export type Partenaire = {
  id: string;
  nom: string;
  logo_url: string;
  site_url: string | null;
  actif: boolean;
  position: number;
};
EOF_BUREAU_FICHIER
echo "  ✓ src/lib/types.ts"

echo
echo "Terminé : 60 fichiers écrits."
echo "Étapes suivantes :"
echo "  1. git add -A && git commit -m 'Accès du bureau et menu par catégories' && git push && vercel --prod"
echo "  2. Dans Supabase, projet CDF : exécuter supabase/comptabilite.sql puis supabase/bureau.sql"
echo "  3. Admin, Accès du bureau : créer les membres et régler les modules par poste"
