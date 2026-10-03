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
