#!/usr/bin/env bash
# Réservations saisies à la main (espèces, chèque) et prise en compte en comptabilité.
# À exécuter à la racine du projet :  bash maj-reservations-manuelles.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Lance ce script à la racine du repo (package.json et src/app introuvables)."; exit 1
fi
if [ ! -d "src/app/admin/(protected)/compta" ]; then
  echo "Le module comptabilité est introuvable : lance d'abord bash install-compta.sh"; exit 1
fi
echo "Mise à jour : réservations manuelles…"
cat > 'INSTALLATION-COMPTA.md' <<'EOF_RESA_FICHIER'
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
EOF_RESA_FICHIER
echo "  ✓ INSTALLATION-COMPTA.md"
mkdir -p 'supabase'
cat > 'supabase/comptabilite.sql' <<'EOF_RESA_FICHIER'
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
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'reservations_mode_paiement_check') then
    alter table public.reservations
      add constraint reservations_mode_paiement_check check (mode_paiement in ('especes', 'cheque'));
  end if;
end $$;


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
drop function if exists public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text);

create or replace function public.compta__ecrire_vente(
  p_cle text,
  p_source_id uuid,
  p_date date,
  p_libelle text,
  p_montant integer,
  p_evenement uuid,
  p_statut text,
  p_mode text default null
)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  s compta_sources%rowtype;
  m compta_modes_paiement%rowtype;
  v_journal text;
  v_tresorerie text;
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
    jsonb_build_object('compte', s.compte_produit, 'debit', 0, 'credit', p_montant, 'evenement_id', v_evt)
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
             res.mode_paiement, coalesce(ev.titre, 'Billetterie') as titre
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
           r.titre || ', ' || coalesce(r.places, 1) || ' place(s)' || coalesce(', réf. ' || r.reference, ''),
           r.montant_centimes, compta__evenement_site(r.evenement_id, null), r.statut, r.mode_paiement) then
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
revoke all on function public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text, text) from public, anon, authenticated;

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
EOF_RESA_FICHIER
echo "  ✓ supabase/comptabilite.sql"
mkdir -p 'src/lib'
cat > 'src/lib/types.ts' <<'EOF_RESA_FICHIER'
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
}

export type Partenaire = {
  id: string;
  nom: string;
  logo_url: string;
  site_url: string | null;
  actif: boolean;
  position: number;
};
EOF_RESA_FICHIER
echo "  ✓ src/lib/types.ts"
mkdir -p 'src/app'
cat > 'src/app/reservation-actions.ts' <<'EOF_RESA_FICHIER'
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
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('reservations')
    .update({ scanne_le: new Date().toISOString() })
    .eq('id', id);
  revalidatePath('/admin/reservations');
}

export async function changerStatutResa(id: string, statut: string): Promise<{ erreur?: string } | void> {
  const { supabase, isAdmin } = await requireAdmin();
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
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('reservations').delete().eq('id', id);
  revalidatePath('/admin/reservations');
}

/** Admin : force une vérification auprès de SumUp pour une réservation (ou toutes celles en attente). */
export async function verifierSumUpAdmin(reference?: string): Promise<{ verifiees: number; changees: number; erreur?: string }> {
  const { supabase, isAdmin } = await requireAdmin();
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
  return /mode_paiement|paiement_ref|saisie_par/.test(message)
    ? 'La base n\u2019est pas à jour : exécute supabase/comptabilite.sql dans Supabase, puis réessaie.'
    : message;
}

/** Ajoute un participant depuis l'admin, payé en espèces, par chèque, ou pas encore payé. */
export async function ajouterReservationManuelle(_prev: EtatManuel, fd: FormData): Promise<EtatManuel> {
  const { supabase, isAdmin, user } = await requireAdmin();
  if (!isAdmin || !user) return { erreur: 'Accès refusé.' };

  const evenementId = String(fd.get('evenement_id') ?? '');
  const nom         = String(fd.get('nom') ?? '').trim();
  const email       = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone   = String(fd.get('telephone') ?? '').trim();
  const commentaire = String(fd.get('commentaire') ?? '').trim();
  const paiement    = String(fd.get('paiement') ?? 'attente'); // especes | cheque | attente
  const paiementRef = String(fd.get('paiement_ref') ?? '').trim();
  const montantTxt  = String(fd.get('montant') ?? '').trim();
  const tarifIds    = fd.getAll('tarif_id').map(String);
  const tarifQtes   = fd.getAll('tarif_qte').map((v) => Math.max(0, Math.floor(Number(v) || 0)));
  const places      = tarifQtes.reduce((s, q) => s + q, 0);

  if (nom.length < 2) return { erreur: 'Le nom est obligatoire.' };
  if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (places < 1) return { erreur: 'Indique au moins une place.' };
  if (paiement !== 'attente' && !MODES_HORS_LIGNE.includes(paiement)) return { erreur: 'Mode de paiement invalide.' };

  const db = createAdminClient();

  const { data: evt } = await db
    .from('evenements').select('id, titre, prix_centimes, places_max').eq('id', evenementId).maybeSingle();
  if (!evt) return { erreur: 'Événement introuvable.' };

  // Jauge : bloquante, sauf dépassement demandé explicitement.
  if (evt.places_max !== null && fd.get('depasser') !== 'on') {
    const { data: restantes } = await db.rpc('places_restantes', { evt_id: evt.id });
    if (typeof restantes === 'number' && restantes < places) {
      return {
        erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Coche « Autoriser le dépassement de la jauge » pour l\u2019ajouter quand même.`,
      };
    }
  }

  const { data: grille } = await db.from('tarifs').select('id, libelle, prix_centimes').eq('evenement_id', evt.id);
  const lignes: { libelle: string; prix_centimes: number; quantite: number }[] = [];
  let montant = 0;
  tarifIds.forEach((id, i) => {
    const q = tarifQtes[i] ?? 0;
    if (q <= 0) return;
    const t = (grille ?? []).find((x) => x.id === id);
    const prix = t ? t.prix_centimes : evt.prix_centimes ?? 0;
    lignes.push({ libelle: t?.libelle ?? 'Place', prix_centimes: prix, quantite: q });
    montant += prix * q;
  });
  if (lignes.length === 0) return { erreur: 'Indique au moins une place.' };

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
    })
    .select(CHAMPS_EVT)
    .single();

  if (error || !resa) {
    console.error('[ajouterReservationManuelle]', error);
    return { erreur: erreurBase(error?.message ?? 'Impossible de créer la réservation.') };
  }

  await db.from('reservation_lignes').insert(lignes.map((l) => ({ reservation_id: resa.id, ...l })));

  if (paye && email && fd.get('envoyer_billet') === 'on') await envoyerBillet(resa, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  return {
    ok: `${nom} ajouté, ${places} place${places > 1 ? 's' : ''}, code billet ${resa.code_billet}. ${paye ? 'Paiement enregistré.' : 'Paiement en attente.'}`,
  };
}

/** Enregistre le paiement en espèces ou par chèque d'une réservation non payée. */
export async function encaisserReservation(id: string, mode: string, ref?: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin();
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

  if (maj?.email) await envoyerBillet(maj, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  return { ok: true };
}
EOF_RESA_FICHIER
echo "  ✓ src/app/reservation-actions.ts"
mkdir -p 'src/app/admin/(protected)/reservations'
cat > 'src/app/admin/(protected)/reservations/page.tsx' <<'EOF_RESA_FICHIER'
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
  const { supabase } = await requireAdmin();

  const [{ data: evenements }, { data: suivi }, { data: tarifs }] = await Promise.all([
    supabase.from('evenements')
      .select('id, titre, slug, places_max, prix_centimes')
      .eq('billetterie_active', true).order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
    supabase.from('tarifs').select('id, evenement_id, libelle, prix_centimes').order('position'),
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

      <FormReservationManuelle evenements={evenements ?? []} tarifs={tarifs ?? []} evenementInitial={evt} />

      <div className="kpi">
        <div><b>{placesVendues}</b><span>Places vendues</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead>
              <tr>
                <th>Événement</th><th>Vendues</th><th>Jauge</th>
                <th>Recette</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(suivi as any[]).map((s) => (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc"><strong>{s.titre}</strong></td>
                  <td data-l="Vendues">{s.places_vendues}</td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{s.places_vendues} / {s.places_max}
                          <div className="jauge">
                            <span style={{
                              width: `${Math.min(100, (s.places_vendues / s.places_max) * 100)}%`,
                            }} />
                          </div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Recette">{euros(s.recette_centimes)}</td>
                  <td className="actions">
                    <Link className="btn btn-y btn-sm" href={`/admin/pointage/${s.id}`}>
                      Pointer
                    </Link>{' '}
                    <Link className="btn btn-w btn-sm" href={`/admin/reservations?evt=${s.id}`}>
                      Détail
                    </Link>
                  </td>
                </tr>
              ))}
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
EOF_RESA_FICHIER
echo "  ✓ src/app/admin/(protected)/reservations/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresorerie'
cat > 'src/app/admin/(protected)/tresorerie/page.tsx' <<'EOF_RESA_FICHIER'
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
    supabase.from('evenements').select('id, titre, slug, places_max, prix_centimes').eq('billetterie_active', true).order('date_debut'),
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
        <div><b>{placesVendues}</b><span>Places vendues</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead><tr><th>Événement</th><th>Vendues</th><th>Jauge</th><th>Recette</th><th></th></tr></thead>
            <tbody>
              {(suivi as any[]).map((s) => (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc"><strong>{s.titre}</strong></td>
                  <td data-l="Vendues">{s.places_vendues}</td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{s.places_vendues} / {s.places_max}
                          <div className="jauge"><span style={{ width: `${Math.min(100, (s.places_vendues / s.places_max) * 100)}%` }} /></div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Recette">{euros(s.recette_centimes)}</td>
                  <td className="actions">
                    <Link className="btn btn-w btn-sm" href={`/admin/tresorerie?evt=${s.id}`}>Détail</Link>
                  </td>
                </tr>
              ))}
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
EOF_RESA_FICHIER
echo "  ✓ src/app/admin/(protected)/tresorerie/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/ventes'
cat > 'src/app/admin/(protected)/compta/ventes/page.tsx' <<'EOF_RESA_FICHIER'
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
EOF_RESA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/ventes/page.tsx"
mkdir -p 'src/components'
cat > 'src/components/FormReservationManuelle.tsx' <<'EOF_RESA_FICHIER'
'use client';
import { useActionState, useEffect, useMemo, useState } from 'react';
import { ajouterReservationManuelle, type EtatManuel } from '@/app/reservation-actions';

type Evt = { id: string; titre: string; prix_centimes: number | null; places_max: number | null };
type Tarif = { id: string; evenement_id: string; libelle: string; prix_centimes: number };

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const enSaisie = (c: number) => (c / 100).toFixed(2).replace('.', ',');

/** Ajout d'un participant par un admin : paiement en espèces, par chèque ou à venir. */
export default function FormReservationManuelle({
  evenements, tarifs, evenementInitial,
}: { evenements: Evt[]; tarifs: Tarif[]; evenementInitial?: string }) {
  const [ouvert, setOuvert] = useState(false);
  const [evenementId, setEvenementId] = useState(
    evenements.some((e) => e.id === evenementInitial) ? evenementInitial! : evenements[0]?.id ?? ''
  );
  const [qtes, setQtes] = useState<Record<string, number>>({});
  const [montantSaisi, setMontantSaisi] = useState<string | null>(null);
  const [paiement, setPaiement] = useState('especes');
  const [etat, action, pending] = useActionState<EtatManuel, FormData>(ajouterReservationManuelle, null);

  const evt = evenements.find((e) => e.id === evenementId);
  // Sans grille de tarifs, une seule ligne au prix de l'événement.
  const lignes = useMemo(() => {
    const grille = tarifs.filter((t) => t.evenement_id === evenementId);
    return grille.length > 0
      ? grille.map((t) => ({ id: t.id, libelle: t.libelle, prix: t.prix_centimes }))
      : [{ id: 'defaut', libelle: 'Place', prix: evt?.prix_centimes ?? 0 }];
  }, [tarifs, evenementId, evt]);

  const total = lignes.reduce((s, l) => s + l.prix * (qtes[l.id] ?? 0), 0);
  const places = lignes.reduce((s, l) => s + (qtes[l.id] ?? 0), 0);

  // Après un ajout réussi : on repart d'un formulaire vide, sur le même événement.
  useEffect(() => {
    if (etat?.ok) {
      setQtes({});
      setMontantSaisi(null);
    }
  }, [etat]);

  if (evenements.length === 0) return null;

  if (!ouvert) {
    return (
      <div style={{ marginBottom: '1.6rem' }}>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        <button type="button" className="btn btn-k btn-sm" onClick={() => setOuvert(true)}>
          + Ajouter un participant
        </button>
      </div>
    );
  }

  return (
    <div className="panel">
      <h2>Ajouter un participant</h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <form action={action}>
        <div className="field">
          <label htmlFor="rm-evt">Événement</label>
          <select
            id="rm-evt" name="evenement_id" value={evenementId}
            onChange={(e) => { setEvenementId(e.target.value); setQtes({}); setMontantSaisi(null); }}
          >
            {evenements.map((e) => <option key={e.id} value={e.id}>{e.titre}</option>)}
          </select>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="rm-nom">Nom et prénom</label>
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
          <label>Places</label>
          <table className="tbl" style={{ maxWidth: 520 }}>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td>{l.libelle}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>{euros(l.prix)}</td>
                  <td style={{ width: 110 }}>
                    <input type="hidden" name="tarif_id" value={l.id} />
                    <input
                      name="tarif_qte" type="number" min={0} max={99} inputMode="numeric"
                      aria-label={`Nombre de places ${l.libelle}`}
                      value={qtes[l.id] ?? 0}
                      onChange={(e) => setQtes((q) => ({ ...q, [l.id]: Math.max(0, Math.floor(Number(e.target.value) || 0)) }))}
                      style={{ width: 90, padding: '.5rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="rm-montant">Montant ({places} place{places > 1 ? 's' : ''})</label>
            <input
              id="rm-montant" name="montant" inputMode="decimal"
              value={montantSaisi ?? enSaisie(total)}
              onChange={(e) => setMontantSaisi(e.target.value)}
            />
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
          <label htmlFor="rm-com">Remarque (facultatif)</label>
          <input id="rm-com" name="commentaire" autoComplete="off" />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '.5rem', marginBottom: '1.1rem', fontSize: '.9rem' }}>
          {paiement !== 'attente' && (
            <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
              <input type="checkbox" name="envoyer_billet" defaultChecked style={{ width: 'auto' }} />
              Envoyer le billet par e-mail (si une adresse est saisie)
            </label>
          )}
          {evt?.places_max != null && (
            <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
              <input type="checkbox" name="depasser" style={{ width: 'auto' }} />
              Autoriser le dépassement de la jauge
            </label>
          )}
        </div>

        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          <button className="btn btn-k btn-sm" disabled={pending || places < 1}>
            {pending ? 'Enregistrement…' : 'Ajouter la réservation'}
          </button>
          <button type="button" className="btn btn-w btn-sm" onClick={() => setOuvert(false)}>Fermer</button>
        </div>
      </form>
    </div>
  );
}
EOF_RESA_FICHIER
echo "  ✓ src/components/FormReservationManuelle.tsx"
mkdir -p 'src/components'
cat > 'src/components/LigneReservation.tsx' <<'EOF_RESA_FICHIER'
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
          {resa.places}
          {resa.reservation_lignes?.length > 1 && (
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
EOF_RESA_FICHIER
echo "  ✓ src/components/LigneReservation.tsx"
mkdir -p 'src/components'
cat > 'src/components/ListeReservationsLecture.tsx' <<'EOF_RESA_FICHIER'
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
                <strong>{r.nom}</strong><br />
                <span style={{ color: '#6b6560', fontSize: '.8rem' }}>{[r.email, r.telephone].filter(Boolean).join(' · ')}</span>
              </td>
              <td data-l="Événement" style={{ fontSize: '.85rem' }}>{r.evenements?.titre}</td>
              <td data-l="Places">
                {r.places}
                {r.reservation_lignes?.length > 1 && (
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
EOF_RESA_FICHIER
echo "  ✓ src/components/ListeReservationsLecture.tsx"
mkdir -p 'src/components'
cat > 'src/components/ExportCsv.tsx' <<'EOF_RESA_FICHIER'
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
      ['Référence', 'Date réservation', 'Nom', 'Email', 'Téléphone',
       'Événement', 'Places', 'Montant €', 'Statut', 'Code billet',
       'Pointé', 'Paiement', 'Transaction SumUp', 'N° chèque', 'Remarque'],
      ...resas.map((r) => [
        r.reference,
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
EOF_RESA_FICHIER
echo "  ✓ src/components/ExportCsv.tsx"

echo
echo "Terminé : 11 fichiers écrits."
echo "Étapes suivantes :"
echo "  1. Réexécuter supabase/comptabilite.sql dans l'éditeur SQL du projet Supabase du CDF"
echo "  2. git add -A && git commit -m 'Réservations manuelles : espèces et chèques' && git push && vercel --prod"
