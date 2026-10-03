#!/usr/bin/env bash
# Installation du module Comptabilité dans le repo cdf.
# À exécuter à la racine du projet :  bash install-compta.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Lance ce script à la racine du repo (package.json et src/app introuvables)."; exit 1
fi
echo "Installation du module Comptabilité…"
cat > 'INSTALLATION-COMPTA.md' <<'EOF_COMPTA_FICHIER'
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
EOF_COMPTA_FICHIER
echo "  ✓ INSTALLATION-COMPTA.md"
mkdir -p 'supabase'
cat > 'supabase/comptabilite.sql' <<'EOF_COMPTA_FICHIER'
-- =====================================================================
-- CDF Limetz-Villez : module comptabilité
-- Fichier : supabase/comptabilite.sql
-- À exécuter dans l'éditeur SQL du projet Supabase du CDF (pas WayPilot).
-- Script relançable : il ne supprime aucune donnée.
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
  ('SU', 'Ventes du site (SumUp)', '517000'),
  ('ST', 'Ventes du site (Stripe)', '517100'),
  ('OD', 'Opérations diverses', null),
  ('AN', 'À-nouveaux', null)
on conflict (code) do nothing;

insert into public.compta_exercices (libelle, date_debut, date_fin) values
  ('2026', date '2026-01-01', date '2026-12-31')
on conflict (libelle) do nothing;

insert into public.compta_evenements (code, libelle, date_evenement, statut) values
  ('TOMB',  'Grande Tombola de Noël', date '2026-12-20', 'en_cours'),
  ('ARBRE', 'Arbre de Noël',          date '2026-12-20', 'en_cours'),
  ('TRES',  'Trésors de Noël',        null,              'en_cours'),
  ('PNOEL', 'Le Père Noël te répond', null,              'en_cours'),
  ('NAN',   'Tombola du Nouvel An',   date '2026-12-31', 'a_venir'),
  ('ROUE',  'Roue de la Rentrée',     null,              'termine')
on conflict (code) do nothing;

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
create or replace function public.compta__ecrire_vente(
  p_cle text,
  p_source_id uuid,
  p_date date,
  p_libelle text,
  p_montant integer,
  p_evenement uuid,
  p_statut text
)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  s compta_sources%rowtype;
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

  if s.taux_frais > 0 or s.frais_fixe_centimes > 0 then
    v_frais := least(round(p_montant * s.taux_frais / 100.0)::integer + s.frais_fixe_centimes, p_montant - 1);
  end if;

  v_lignes := jsonb_build_array(
    jsonb_build_object('compte', s.compte_tresorerie, 'debit', p_montant, 'credit', 0),
    jsonb_build_object('compte', s.compte_produit, 'debit', 0, 'credit', p_montant, 'evenement_id', v_evt)
  );
  if v_frais > 0 then
    v_lignes := v_lignes || jsonb_build_array(
      jsonb_build_object('compte', s.compte_frais, 'debit', v_frais, 'credit', 0, 'evenement_id', v_evt, 'libelle', 'Frais de paiement'),
      jsonb_build_object('compte', s.compte_tresorerie, 'debit', 0, 'credit', v_frais, 'libelle', 'Frais de paiement')
    );
  end if;

  perform compta__ecrire(s.journal_code, p_date, p_libelle, v_lignes, 'site', p_cle, p_source_id, p_statut, null, 'Import site');
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

-- Import des ventes payées du site. Renvoie le nombre d'écritures créées.
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
             coalesce(ev.titre, 'Billetterie') as titre
      from reservations res
      left join evenements ev on ev.id = res.evenement_id
      where res.paye_le is not null
        and coalesce(res.montant_centimes, 0) > 0
        and (res.paye_le at time zone 'Europe/Paris')::date >= s.importer_depuis
        and not exists (select 1 from compta_ecritures ce where ce.source_table = 'reservations' and ce.source_id = res.id)
      order by res.paye_le
    loop
      if compta__ecrire_vente(
           'reservations', r.id, (r.paye_le at time zone 'Europe/Paris')::date,
           r.titre || ', ' || coalesce(r.places, 1) || ' place(s)' || coalesce(', réf. ' || r.reference, ''),
           r.montant_centimes, compta__evenement_site(r.evenement_id, null), r.statut) then
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

-- Ventes importées dont le statut a changé depuis l'import (remboursement, annulation, suppression).
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
    and cur.statut is distinct from ce.source_statut
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

-- Accès par l'API pour les personnes connectées (les policies ci-dessous filtrent ensuite).
grant select, insert, update, delete on
  public.compta_exercices, public.compta_comptes, public.compta_journaux, public.compta_evenements,
  public.compta_budgets, public.compta_ecritures, public.compta_lignes, public.compta_sources,
  public.compta_rapprochements
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
drop policy if exists compta_ecriture_admin on public.compta_sources;
create policy compta_ecriture_admin on public.compta_sources for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Écritures et lignes : aucune modification directe, tout passe par les fonctions de la partie 4.

-- Fonctions internes : inaccessibles depuis le site.
revoke all on function public.compta__exercice(date) from public, anon, authenticated;
revoke all on function public.compta__ecrire(text, date, text, jsonb, text, text, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.compta__evenement_site(uuid, uuid) from public, anon, authenticated;
revoke all on function public.compta__ecrire_vente(text, uuid, date, text, integer, uuid, text) from public, anon, authenticated;

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
EOF_COMPTA_FICHIER
echo "  ✓ supabase/comptabilite.sql"
mkdir -p 'src/lib/compta'
cat > 'src/lib/compta/types.ts' <<'EOF_COMPTA_FICHIER'
export type TypeCompte = 'bilan' | 'tresorerie' | 'charge' | 'produit';

export interface Exercice {
  id: string;
  libelle: string;
  date_debut: string;
  date_fin: string;
  cloture: boolean;
  cloture_le: string | null;
}

export interface Compte {
  numero: string;
  intitule: string;
  type: TypeCompte;
  actif: boolean;
}

export interface Journal {
  code: string;
  libelle: string;
  compte_tresorerie: string | null;
}

export interface EvenementCompta {
  id: string;
  code: string;
  libelle: string;
  date_evenement: string | null;
  statut: 'a_venir' | 'en_cours' | 'termine';
}

/** Une ligne de la vue compta_v_lignes (journaux, grand livre). */
export interface LigneVue {
  id: string;
  ecriture_id: string;
  exercice_id: string;
  journal_code: string;
  numero: number;
  piece: string;
  date_piece: string;
  libelle: string;
  position: number;
  compte_numero: string;
  compte_intitule: string;
  compte_type: TypeCompte;
  compta_evenement_id: string | null;
  evenement_code: string | null;
  debit_centimes: number;
  credit_centimes: number;
  pointe_le: string | null;
  source: 'manuel' | 'site' | 'annulation';
  contrepassee_par: string | null;
  justificatif_chemin: string | null;
  cree_par_nom: string | null;
  created_at: string;
}

/** Une ligne de la vue compta_v_balance. */
export interface LigneBalance {
  exercice_id: string;
  numero: string;
  intitule: string;
  type: TypeCompte;
  debit_centimes: number;
  credit_centimes: number;
  solde_centimes: number;
}

/** Ligne envoyée à la fonction compta_saisir_ecriture (montants en centimes). */
export interface LigneSaisie {
  compte: string;
  debit: number;
  credit: number;
  evenement_id?: string | null;
  libelle?: string | null;
}

export type Retour = { ok?: string; erreur?: string; id?: string } | null;

export const LIBELLE_TYPE: Record<TypeCompte, string> = {
  bilan: 'Bilan',
  tresorerie: 'Trésorerie',
  charge: 'Charge',
  produit: 'Produit',
};

export const LIBELLE_STATUT_EVT: Record<EvenementCompta['statut'], string> = {
  a_venir: 'À venir',
  en_cours: 'En cours',
  termine: 'Terminé',
};
EOF_COMPTA_FICHIER
echo "  ✓ src/lib/compta/types.ts"
mkdir -p 'src/lib/compta'
cat > 'src/lib/compta/format.ts' <<'EOF_COMPTA_FICHIER'
const NOMBRE = new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** 123456 centimes -> « 1 234,56 ». */
export function montant(centimes: number | null | undefined): string {
  return NOMBRE.format((centimes ?? 0) / 100);
}

/** Comme montant(), mais chaîne vide pour zéro (colonnes débit et crédit). */
export function montantOuVide(centimes: number | null | undefined): string {
  return centimes ? montant(centimes) : '';
}

/** Solde d'un compte : montant suivi de D (débiteur) ou C (créditeur). */
export function solde(centimes: number): string {
  if (!centimes) return '0,00';
  return `${montant(Math.abs(centimes))} ${centimes > 0 ? 'D' : 'C'}`;
}

/** « 1 234,56 », « 1234.5 » ou « 48,9 » -> centimes. Renvoie null si la saisie est invalide. */
export function enCentimes(saisie: string): number | null {
  const propre = saisie.replace(/[\s\u00a0\u202f€]/g, '').replace(',', '.');
  if (!/^\d+(\.\d{1,2})?$/.test(propre)) return null;
  return Math.round(parseFloat(propre) * 100);
}

/** 2026-10-03 -> 03/10/2026. */
export function dateFr(iso: string | null | undefined): string {
  if (!iso) return '';
  const [a, m, j] = iso.slice(0, 10).split('-');
  return `${j}/${m}/${a}`;
}

/** Date du jour à Paris, au format AAAA-MM-JJ. */
export function aujourdhui(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(new Date());
}

export function estDateIso(v: string | undefined | null): v is string {
  return !!v && /^\d{4}-\d{2}-\d{2}$/.test(v);
}
EOF_COMPTA_FICHIER
echo "  ✓ src/lib/compta/format.ts"
mkdir -p 'src/lib/compta'
cat > 'src/lib/compta/db.ts' <<'EOF_COMPTA_FICHIER'
import type { createClient } from '@/lib/supabase/server';
import { aujourdhui } from '@/lib/compta/format';
import type { Compte, EvenementCompta, Exercice, Journal } from '@/lib/compta/types';

type Db = Awaited<ReturnType<typeof createClient>>;
type Reponse = PromiseLike<{ data: any[] | null; error: { message: string } | null }>;

/**
 * Lit toutes les lignes d'une requête par paquets de 1000
 * (limite par défaut de l'API Supabase).
 */
export async function lireTout<T = any>(requete: (de: number, a: number) => Reponse): Promise<T[]> {
  const PAS = 1000;
  const tout: T[] = [];
  for (let de = 0; ; de += PAS) {
    const { data, error } = await requete(de, de + PAS - 1);
    if (error) throw new Error(error.message);
    tout.push(...((data ?? []) as T[]));
    if (!data || data.length < PAS) break;
  }
  return tout;
}

/** Exercice demandé, sinon celui qui contient la date du jour, sinon le plus récent. */
export async function contexte(supabase: Db, exId?: string) {
  const { data } = await supabase.from('compta_exercices').select('*').order('date_debut');
  const exercices = (data ?? []) as Exercice[];
  const jour = aujourdhui();
  const exercice =
    exercices.find((e) => e.id === exId) ??
    exercices.find((e) => e.date_debut <= jour && jour <= e.date_fin) ??
    exercices[exercices.length - 1] ??
    null;
  return { exercices, exercice };
}

/** Plan comptable, journaux et codes événement. */
export async function referentiel(supabase: Db) {
  const [{ data: comptes }, { data: journaux }, { data: evenements }] = await Promise.all([
    supabase.from('compta_comptes').select('*').order('numero'),
    supabase.from('compta_journaux').select('*').order('code'),
    supabase.from('compta_evenements').select('id, code, libelle, date_evenement, statut').order('code'),
  ]);
  return {
    comptes: (comptes ?? []) as Compte[],
    journaux: (journaux ?? []) as Journal[],
    evenements: (evenements ?? []) as EvenementCompta[],
  };
}

/** Ajoute ?ex= aux liens quand un exercice autre que l'exercice courant est affiché. */
export function suffixeEx(ex?: string, premier = true): string {
  return ex ? `${premier ? '?' : '&'}ex=${ex}` : '';
}
EOF_COMPTA_FICHIER
echo "  ✓ src/lib/compta/db.ts"
mkdir -p 'src/app'
cat > 'src/app/compta-actions.ts' <<'EOF_COMPTA_FICHIER'
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
EOF_COMPTA_FICHIER
echo "  ✓ src/app/compta-actions.ts"
mkdir -p 'src/app/admin/(protected)'
cat > 'src/app/admin/(protected)/layout.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import NavAdmin from '@/components/NavAdmin';
import Deconnexion from '@/components/Deconnexion';

export const dynamic = 'force-dynamic';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, isStaff, role } = await requireAdmin();

  // La page de login a son propre rendu : elle est exclue via son layout imbriqué.
  if (!user) redirect('/admin/login');
  if (!isStaff) {
    return (
      <div className="adm-main">
        <div className="panel">
          <h2>Compte non autorisé</h2>
          <p style={{ marginBottom: '1rem' }}>
            Votre compte ({user.email}) n&apos;est pas déclaré comme administrateur.
            Ajoutez-le dans la table <code>admins</code> de Supabase.
          </p>
          <Deconnexion />
        </div>
      </div>
    );
  }

  // Un trésorier ne voit que l'espace trésorerie (lecture seule) et la comptabilité.
  if (!isAdmin) {
    const path = (await headers()).get('x-pathname') ?? '';
    const autorise = path.startsWith('/admin/tresorerie') || path.startsWith('/admin/compta');
    if (path && !autorise) redirect('/admin/tresorerie');
  }

  return (
    <div className="adm">
      <aside className="adm-side">
        <div className="brand">Comité des Fêtes<br />{isAdmin ? 'Back-office' : 'Trésorerie'}</div>
        <NavAdmin role={role ?? 'admin'} />
        <div className="sep">
          <Link href="/" target="_blank" style={{ fontSize: '.8rem' }}>↗ Voir le site</Link>
          <Deconnexion />
        </div>
      </aside>
      <main className="adm-main">{children}</main>
    </div>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/layout.tsx"
mkdir -p 'src/components'
cat > 'src/components/NavAdmin.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS_ADMIN = [
  { href: '/admin', label: 'Tableau de bord' },
  { href: '/admin/evenements', label: 'Événements' },
  { href: '/admin/reservations', label: 'Réservations' },
  { href: '/admin/tresorerie', label: 'Trésorerie' },
  { href: '/admin/compta', label: 'Comptabilité' },
  { href: '/admin/demandes', label: 'Demandes reçues' },
  { href: '/admin/tresors', label: 'Trésors de Noël' },
  { href: '/admin/pere-noel', label: '🎅 Père Noël vidéo' },
  { href: '/admin/roue', label: '🎡 Roue de la Rentrée' },
  { href: '/admin/partenaires', label: 'Partenaires' },
  { href: '/admin/association', label: 'Association' },
  { href: '/admin/parametres', label: 'Réglages du site' },
  { href: '/admin/maintenance', label: 'Maintenance' },
];

const LIENS_TRESORIER = [
  { href: '/admin/tresorerie', label: 'Trésorerie (lecture seule)' },
  { href: '/admin/compta', label: 'Comptabilité' },
];

export default function NavAdmin({ role = 'admin' }: { role?: 'admin' | 'tresorier' }) {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);
  const LIENS = role === 'tresorier' ? LIENS_TRESORIER : LIENS_ADMIN;
  const estActif = (href: string) => (href === '/admin' ? path === '/admin' : path.startsWith(href));
  const courant = LIENS.find((l) => estActif(l.href))?.label ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {LIENS.map((l) => (
          <Link key={l.href} href={l.href} className={estActif(l.href) ? 'on' : ''}>
            {l.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/NavAdmin.tsx"
mkdir -p 'src/app/admin/(protected)/compta'
cat > 'src/app/admin/(protected)/compta/compta.css' <<'EOF_COMPTA_FICHIER'
/* Module comptabilité : présentation sobre, type logiciel de gestion. */
.cpt{font-family:"Segoe UI",system-ui,-apple-system,"Helvetica Neue",Arial,sans-serif;font-size:14px;line-height:1.45;color:#1D2630;}
.cpt h1,.cpt h2,.cpt h3{font-family:inherit;text-transform:none;letter-spacing:0;font-weight:600;}
.cpt h1{font-size:20px;}
.cpt h2{font-size:14px;margin-bottom:8px;}
.cpt a{color:#1F5FA8;}

.cpt-nav{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px;padding-bottom:12px;border-bottom:1px solid #C9D0D8;}
.cpt-nav a{padding:6px 10px;border:1px solid #C9D0D8;border-radius:3px;background:#fff;color:#1D2630;text-decoration:none;font-size:13px;}
.cpt-nav a.on{background:#1F5FA8;border-color:#1F5FA8;color:#fff;}

.cpt-titre{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:8px;margin-bottom:10px;}
.cpt-outils{display:flex;flex-wrap:wrap;gap:6px;align-items:center;}
.cpt-info{color:#5B6876;font-size:13px;margin-bottom:10px;}
.cpt-ok{color:#1E7B45;font-size:13px;font-weight:600;margin-top:8px;}
.cpt-ko{color:#B3261E;font-size:13px;font-weight:600;margin-top:8px;}
.cpt-msg{padding:8px 10px;border:1px solid #C9D0D8;border-radius:3px;margin-bottom:10px;font-size:13px;font-weight:600;}
.cpt-msg.ok{background:#E3F3E9;border-color:#9CCDB0;color:#17603A;}
.cpt-msg.ko{background:#FBE6E4;border-color:#E3A8A3;color:#8E1D17;}

.cpt-panneau{background:#fff;border:1px solid #C9D0D8;border-radius:3px;padding:10px;margin-bottom:10px;min-width:0;}
.cpt-cols{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px;}
.cpt-cols .cpt-panneau{margin-bottom:0;}

.cpt-btn{font:inherit;font-size:13px;padding:6px 11px;border:1px solid #C9D0D8;border-radius:3px;background:#E4E8ED;color:#1D2630;cursor:pointer;display:inline-block;text-decoration:none;line-height:1.4;}
.cpt a.cpt-btn{color:#1D2630;}
.cpt-btn:hover{background:#D8DEE5;}
.cpt-btn:disabled{opacity:.55;cursor:not-allowed;}
.cpt-btn.p,.cpt a.cpt-btn.p{background:#1F5FA8;border-color:#1F5FA8;color:#fff;}
.cpt-btn.p:hover{background:#1A5190;}
.cpt-btn.mini{padding:3px 8px;font-size:12px;}
.cpt-btn:focus-visible,.cpt input:focus-visible,.cpt select:focus-visible{outline:2px solid #1F5FA8;outline-offset:1px;}

.cpt-defile{overflow-x:auto;-webkit-overflow-scrolling:touch;}
.cpt-grille{width:100%;border-collapse:collapse;font-size:13px;font-variant-numeric:tabular-nums;}
.cpt-grille th,.cpt-grille td{border:1px solid #C9D0D8;padding:5px 7px;text-align:left;vertical-align:top;}
.cpt-grille thead th{background:#E4E8ED;font-weight:600;white-space:nowrap;}
.cpt-grille tbody tr:nth-child(even) td{background:#F6F7F9;}
.cpt-grille tfoot td{background:#E4E8ED;font-weight:600;}
.cpt-grille .n{text-align:right;white-space:nowrap;}
.cpt-grille .fixe{white-space:nowrap;}
.cpt-grille tr.groupe td{background:#EEF1F4;font-weight:600;}
.cpt-grille tr.annulee td{color:#7A8794;}
.cpt-grille input[type=checkbox]{width:16px;height:16px;}
.cpt-grille td input[type=text],.cpt-grille td select{width:100%;min-width:90px;font:inherit;font-size:13px;padding:4px 6px;border:1px solid #C9D0D8;border-radius:3px;background:#fff;color:#1D2630;}
.cpt-grille td input.n{text-align:right;min-width:80px;}

.cpt-champs{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;}
.cpt-filtres{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:10px;align-items:end;}
.cpt-champ.l2{grid-column:span 2;}
.cpt-champ label,.cpt-champ .etq{display:block;font-size:12px;color:#5B6876;margin-bottom:2px;}
.cpt-champ input,.cpt-champ select{width:100%;font:inherit;font-size:14px;padding:6px 7px;border:1px solid #C9D0D8;border-radius:3px;background:#fff;color:#1D2630;}
.cpt-champ input.n{text-align:right;}
.cpt-champ input[type=checkbox]{width:auto;}
.cpt-ligne{display:flex;flex-wrap:wrap;gap:8px;align-items:end;}
.cpt-ligne .cpt-champ{flex:1 1 140px;}
.cpt-regles{padding-left:18px;font-size:13px;}
.cpt-regles li{margin-bottom:3px;}
.cpt-etat{display:inline-block;padding:1px 7px;border:1px solid #C9D0D8;border-radius:10px;font-size:12px;background:#F6F7F9;white-space:nowrap;}
.cpt-etat.vert{background:#E3F3E9;border-color:#9CCDB0;color:#17603A;}
.cpt-etat.rouge{background:#FBE6E4;border-color:#E3A8A3;color:#8E1D17;}
.cpt-etat.jaune{background:#FFF4CC;border-color:#E3CE7A;color:#6A5200;}

@media (max-width:860px){
  .cpt-cols{grid-template-columns:1fr;}
  .cpt-champs,.cpt-filtres{grid-template-columns:1fr 1fr;}
  .cpt-champ.l2{grid-column:1 / -1;}
  .cpt-grille.large{min-width:720px;}
}
@media print{
  .adm-side,.cpt-nav,.cpt-outils,.cpt-filtres{display:none !important;}
  .adm-main{padding:0;max-width:none;}
  .cpt-panneau{border:0;padding:0;}
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/compta.css"
mkdir -p 'src/app/admin/(protected)/compta'
cat > 'src/app/admin/(protected)/compta/layout.tsx' <<'EOF_COMPTA_FICHIER'
import { Suspense } from 'react';
import { requireAdmin } from '@/lib/supabase/server';
import NavCompta from '@/components/compta/NavCompta';
import './compta.css';

export const dynamic = 'force-dynamic';

export default async function LayoutCompta({ children }: { children: React.ReactNode }) {
  const { supabase } = await requireAdmin();

  // Tant que le script SQL n'a pas été exécuté, on l'indique au lieu de planter.
  const { error } = await supabase.from('compta_exercices').select('id').limit(1);
  if (error) {
    return (
      <div className="cpt">
        <div className="cpt-panneau">
          <h2>Module comptabilité non installé</h2>
          <p className="cpt-info">
            Exécute le fichier <code>supabase/comptabilite.sql</code> dans l&apos;éditeur SQL du projet Supabase du CDF,
            puis recharge cette page.
          </p>
          <p className="cpt-ko">{error.message}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="cpt">
      <Suspense fallback={<div className="cpt-nav" />}>
        <NavCompta />
      </Suspense>
      {children}
    </div>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/layout.tsx"
mkdir -p 'src/app/admin/(protected)/compta'
cat > 'src/app/admin/(protected)/compta/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, suffixeEx } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';

export default async function ComptaAccueil({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();

  // Les ventes payées sur le site entrent au journal à chaque ouverture du tableau de bord.
  await supabase.rpc('compta_importer_ventes');

  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const [{ data: bal }, { data: aVerifier }, { count: sansJustificatif }, { count: nonPointees }, { data: dernieres }] =
    await Promise.all([
      supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero'),
      supabase.rpc('compta_ventes_a_verifier'),
      supabase.from('compta_ecritures').select('id', { count: 'exact', head: true })
        .eq('exercice_id', exercice.id).eq('source', 'manuel').neq('journal_code', 'AN')
        .is('justificatif_chemin', null).is('contrepassee_par', null),
      supabase.from('compta_v_lignes').select('id', { count: 'exact', head: true })
        .eq('exercice_id', exercice.id).eq('compte_numero', '512000').is('pointe_le', null),
      supabase.from('compta_ecritures')
        .select('id, piece, date_piece, libelle, cree_par_nom, compta_lignes(debit_centimes)')
        .eq('exercice_id', exercice.id).order('created_at', { ascending: false }).order('date_piece', { ascending: false })
        .order('numero', { ascending: false }).limit(8),
    ]);

  const balance = (bal ?? []) as LigneBalance[];
  const tresorerie = balance.filter((l) => l.type === 'tresorerie');
  const totalTresorerie = tresorerie.reduce((s, l) => s + l.solde_centimes, 0);
  const produits = balance.filter((l) => l.type === 'produit').reduce((s, l) => s - l.solde_centimes, 0);
  const charges = balance.filter((l) => l.type === 'charge').reduce((s, l) => s + l.solde_centimes, 0);
  const resultat = produits - charges;
  const nbAVerifier = ((aVerifier ?? []) as unknown[]).length;
  const s = suffixeEx(ex);

  return (
    <>
      <Entete titre="Tableau de bord" exercices={exercices} exercice={exercice}>
        <Link className="cpt-btn p" href={`/admin/compta/saisie${s}`}>Nouvelle écriture</Link>
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}.
        Statut : {exercice.cloture ? 'clôturé' : 'ouvert'}.
      </p>

      <div className="cpt-cols">
        <div className="cpt-panneau">
          <h2>Trésorerie</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Solde</th></tr></thead>
              <tbody>
                {tresorerie.map((l) => (
                  <tr key={l.numero}>
                    <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${l.numero}${suffixeEx(ex, false)}`}>{l.numero}</Link></td>
                    <td>{l.intitule}</td>
                    <td className="n">{montant(l.solde_centimes)}</td>
                  </tr>
                ))}
                {tresorerie.length === 0 && <tr><td colSpan={3}>Aucun mouvement de trésorerie sur cet exercice.</td></tr>}
              </tbody>
              <tfoot><tr><td colSpan={2}>Total</td><td className="n">{montant(totalTresorerie)}</td></tr></tfoot>
            </table>
          </div>
        </div>

        <div className="cpt-panneau">
          <h2>Résultat de l&apos;exercice</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Classe</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                <tr><td>7</td><td>Produits</td><td className="n">{montant(produits)}</td></tr>
                <tr><td>6</td><td>Charges</td><td className="n">{montant(charges)}</td></tr>
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>{resultat >= 0 ? 'Excédent' : 'Déficit'}</td><td className="n">{montant(Math.abs(resultat))}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>À traiter</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Nature</th><th>Détail</th><th>Écran</th></tr></thead>
            <tbody>
              <tr>
                <td>Ventes à vérifier</td>
                <td>{nbAVerifier === 0 ? 'Rien à signaler' : `${nbAVerifier} vente(s) dont le statut a changé depuis l'import`}</td>
                <td><Link href={`/admin/compta/ventes${s}`}>Ventes du site</Link></td>
              </tr>
              <tr>
                <td>Pièces sans justificatif</td>
                <td>{(sansJustificatif ?? 0) === 0 ? 'Rien à signaler' : `${sansJustificatif} écriture(s) saisie(s) sans pièce jointe`}</td>
                <td><Link href={`/admin/compta/journaux?sj=1&du=${exercice.date_debut}${suffixeEx(ex, false)}`}>Journaux</Link></td>
              </tr>
              <tr>
                <td>Rapprochement bancaire</td>
                <td>{(nonPointees ?? 0) === 0 ? 'Rien à signaler' : `${nonPointees} ligne(s) de banque non pointée(s)`}</td>
                <td><Link href={`/admin/compta/rapprochement${s}`}>Rapprochement</Link></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Dernières pièces enregistrées</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Date</th><th>Pièce</th><th>Libellé</th><th className="n">Montant</th><th>Saisie</th></tr></thead>
            <tbody>
              {((dernieres ?? []) as any[]).map((e) => (
                <tr key={e.id}>
                  <td className="fixe">{dateFr(e.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${e.id}`}>{e.piece}</Link></td>
                  <td>{e.libelle}</td>
                  <td className="n">{montant((e.compta_lignes ?? []).reduce((t: number, l: any) => t + l.debit_centimes, 0))}</td>
                  <td>{e.cree_par_nom}</td>
                </tr>
              ))}
              {(dernieres ?? []).length === 0 && <tr><td colSpan={5}>Aucune écriture pour le moment.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/balance'
cat > 'src/app/admin/(protected)/compta/balance/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, suffixeEx } from '@/lib/compta/db';
import { dateFr, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

export default async function Balance({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();
  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const { data } = await supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero');
  const lignes = (data ?? []) as LigneBalance[];

  const debiteur = (l: LigneBalance) => Math.max(l.solde_centimes, 0);
  const crediteur = (l: LigneBalance) => Math.max(-l.solde_centimes, 0);
  const tDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const tCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);
  const tSoldeD = lignes.reduce((s, l) => s + debiteur(l), 0);
  const tSoldeC = lignes.reduce((s, l) => s + crediteur(l), 0);
  const equilibree = tDebit === tCredit && tSoldeD === tSoldeC;

  return (
    <>
      <Entete titre="Balance" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`balance-${exercice.libelle}`}
          entetes={['Compte', 'Intitulé', 'Débit', 'Crédit', 'Solde débiteur', 'Solde créditeur']}
          lignes={lignes.map((l) => [
            l.numero, l.intitule, montant(l.debit_centimes), montant(l.credit_centimes),
            montantOuVide(debiteur(l)), montantOuVide(crediteur(l)),
          ])}
        />
        <Imprimer />
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}, à-nouveaux inclus.
      </p>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr>
                <th>Compte</th><th>Intitulé</th><th className="n">Débit</th><th className="n">Crédit</th>
                <th className="n">Solde débiteur</th><th className="n">Solde créditeur</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.numero}>
                  <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${l.numero}${suffixeEx(ex, false)}`}>{l.numero}</Link></td>
                  <td>{l.intitule}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                  <td className="n">{montantOuVide(debiteur(l))}</td>
                  <td className="n">{montantOuVide(crediteur(l))}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={6}>Aucune écriture sur cet exercice.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={2}>Totaux</td>
                <td className="n">{montant(tDebit)}</td>
                <td className="n">{montant(tCredit)}</td>
                <td className="n">{montant(tSoldeD)}</td>
                <td className="n">{montant(tSoldeC)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      {lignes.length > 0 && (equilibree
        ? <p className="cpt-ok">Balance équilibrée.</p>
        : <p className="cpt-ko">Balance déséquilibrée : à signaler, cela ne devrait jamais arriver.</p>)}
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/balance/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/budgets'
cat > 'src/app/admin/(protected)/compta/budgets/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { referentiel } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import { LIBELLE_STATUT_EVT } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import { FormBudget, FormEvenement } from '@/components/compta/FormsBudget';

type Synthese = {
  id: string; code: string; libelle: string; statut: 'a_venir' | 'en_cours' | 'termine'; date_evenement: string | null;
  recettes_prevues_centimes: number; recettes_realisees_centimes: number;
  depenses_prevues_centimes: number; depenses_realisees_centimes: number;
};
type Detail = {
  compte_numero: string; compte_intitule: string; compte_type: 'charge' | 'produit';
  prevu_centimes: number; realise_centimes: number;
};

export default async function Budgets({ searchParams }: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  const [{ data: syn }, { comptes, evenements }] = await Promise.all([
    supabase.from('compta_v_budgets').select('*').order('code'),
    referentiel(supabase),
  ]);
  const lignes = (syn ?? []) as Synthese[];
  const choisi = evenements.find((e) => e.id === evt) ?? null;

  let detail: Detail[] = [];
  if (choisi) {
    const { data } = await supabase.from('compta_v_budget_detail').select('*')
      .eq('compta_evenement_id', choisi.id).order('compte_numero');
    detail = (data ?? []) as Detail[];
  }

  const t = lignes.reduce(
    (s, l) => ({
      rp: s.rp + l.recettes_prevues_centimes, rr: s.rr + l.recettes_realisees_centimes,
      dp: s.dp + l.depenses_prevues_centimes, dr: s.dr + l.depenses_realisees_centimes,
    }),
    { rp: 0, rr: 0, dp: 0, dr: 0 }
  );
  const recettes = detail.filter((d) => d.compte_type === 'produit');
  const depenses = detail.filter((d) => d.compte_type === 'charge');
  const somme = (ls: Detail[], k: 'prevu_centimes' | 'realise_centimes') => ls.reduce((s, l) => s + l[k], 0);

  return (
    <>
      <Entete titre="Budgets par événement">
        <ExportCsvCompta
          nom="budgets-par-evenement"
          entetes={['Code', 'Événement', 'Recettes prévues', 'Recettes réalisées', 'Dépenses prévues', 'Dépenses réalisées', 'Résultat prévu', 'Résultat réalisé']}
          lignes={lignes.map((l) => [
            l.code, l.libelle, montant(l.recettes_prevues_centimes), montant(l.recettes_realisees_centimes),
            montant(l.depenses_prevues_centimes), montant(l.depenses_realisees_centimes),
            montant(l.recettes_prevues_centimes - l.depenses_prevues_centimes),
            montant(l.recettes_realisees_centimes - l.depenses_realisees_centimes),
          ])}
        />
      </Entete>
      <p className="cpt-info">
        Chaque ligne de charge ou de produit peut porter un code événement. Le réalisé vient directement des écritures.
      </p>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Code</th><th>Événement</th><th>Statut</th>
                <th className="n">Recettes prévues</th><th className="n">Recettes réalisées</th>
                <th className="n">Dépenses prévues</th><th className="n">Dépenses réalisées</th>
                <th className="n">Résultat prévu</th><th className="n">Résultat réalisé</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe"><Link href={`/admin/compta/budgets?evt=${l.id}`}>{l.code}</Link></td>
                  <td>{l.libelle}{l.date_evenement ? `, ${dateFr(l.date_evenement)}` : ''}</td>
                  <td className="fixe">{LIBELLE_STATUT_EVT[l.statut]}</td>
                  <td className="n">{montant(l.recettes_prevues_centimes)}</td>
                  <td className="n">{montant(l.recettes_realisees_centimes)}</td>
                  <td className="n">{montant(l.depenses_prevues_centimes)}</td>
                  <td className="n">{montant(l.depenses_realisees_centimes)}</td>
                  <td className="n">{montant(l.recettes_prevues_centimes - l.depenses_prevues_centimes)}</td>
                  <td className="n">{montant(l.recettes_realisees_centimes - l.depenses_realisees_centimes)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={9}>Aucun événement.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={3}>Totaux</td>
                <td className="n">{montant(t.rp)}</td><td className="n">{montant(t.rr)}</td>
                <td className="n">{montant(t.dp)}</td><td className="n">{montant(t.dr)}</td>
                <td className="n">{montant(t.rp - t.dp)}</td><td className="n">{montant(t.rr - t.dr)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {choisi ? (
        <>
          <div className="cpt-panneau">
            <h2>Détail de {choisi.code}, {choisi.libelle}</h2>
            <div className="cpt-defile">
              <table className="cpt-grille">
                <thead>
                  <tr><th>Compte</th><th>Poste</th><th className="n">Prévu</th><th className="n">Réalisé</th><th className="n">Reste</th></tr>
                </thead>
                <tbody>
                  <tr className="groupe"><td colSpan={5}>Recettes</td></tr>
                  {recettes.map((d) => (
                    <tr key={d.compte_numero}>
                      <td className="fixe"><Link href={`/admin/compta/journaux?evt=${choisi.id}`}>{d.compte_numero}</Link></td>
                      <td>{d.compte_intitule}</td>
                      <td className="n">{montant(d.prevu_centimes)}</td>
                      <td className="n">{montant(d.realise_centimes)}</td>
                      <td className="n">{montant(d.prevu_centimes - d.realise_centimes)}</td>
                    </tr>
                  ))}
                  {recettes.length === 0 && <tr><td colSpan={5}>Aucune recette prévue ni réalisée.</td></tr>}
                  <tr className="groupe"><td colSpan={5}>Dépenses</td></tr>
                  {depenses.map((d) => (
                    <tr key={d.compte_numero}>
                      <td className="fixe"><Link href={`/admin/compta/journaux?evt=${choisi.id}`}>{d.compte_numero}</Link></td>
                      <td>{d.compte_intitule}</td>
                      <td className="n">{montant(d.prevu_centimes)}</td>
                      <td className="n">{montant(d.realise_centimes)}</td>
                      <td className="n">{montant(d.prevu_centimes - d.realise_centimes)}</td>
                    </tr>
                  ))}
                  {depenses.length === 0 && <tr><td colSpan={5}>Aucune dépense prévue ni réalisée.</td></tr>}
                </tbody>
                <tfoot>
                  <tr>
                    <td colSpan={2}>Résultat</td>
                    <td className="n">{montant(somme(recettes, 'prevu_centimes') - somme(depenses, 'prevu_centimes'))}</td>
                    <td className="n">{montant(somme(recettes, 'realise_centimes') - somme(depenses, 'realise_centimes'))}</td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div className="cpt-panneau">
            <h2>Fixer un montant prévu</h2>
            <FormBudget evenementId={choisi.id} comptes={comptes} />
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>Un montant à 0 retire la ligne du budget.</p>
          </div>

          <div className="cpt-panneau">
            <h2>Modifier l&apos;événement</h2>
            <FormEvenement evenement={choisi} />
          </div>
        </>
      ) : (
        <p className="cpt-info">Clique sur un code pour voir le détail poste par poste et saisir le prévisionnel.</p>
      )}

      <div className="cpt-panneau">
        <h2>Nouvel événement</h2>
        <FormEvenement />
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/budgets/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/grand-livre'
cat > 'src/app/admin/(protected)/compta/grand-livre/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { dateFr, estDateIso, montant, montantOuVide, solde } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

type Params = { ex?: string; c?: string; du?: string; au?: string };

export default async function GrandLivre({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { comptes }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  const compte = comptes.find((c) => c.numero === sp.c) ?? comptes.find((c) => c.numero === '512000') ?? comptes[0];
  if (!compte) return <SansExercice />;
  const du = estDateIso(sp.du) ? sp.du : exercice.date_debut;
  const au = estDateIso(sp.au) ? sp.au : exercice.date_fin;

  const toutes = await lireTout<LigneVue>((de, a) =>
    supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).eq('compte_numero', compte.numero).lte('date_piece', au)
      .order('date_piece').order('journal_code').order('numero').order('position').range(de, a)
  );

  // Solde reporté : tout ce qui précède la période affichée.
  const report = toutes.filter((l) => l.date_piece < du).reduce((s, l) => s + l.debit_centimes - l.credit_centimes, 0);
  let cumul = report;
  const lignes = toutes.filter((l) => l.date_piece >= du).map((l) => {
    cumul += l.debit_centimes - l.credit_centimes;
    return { ...l, cumul };
  });
  const totalDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);

  return (
    <>
      <Entete titre="Grand livre" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`grand-livre-${compte.numero}-${du}-${au}`}
          entetes={['Date', 'Pièce', 'Libellé', 'Événement', 'Débit', 'Crédit', 'Solde']}
          lignes={lignes.map((l) => [
            dateFr(l.date_piece), l.piece, l.libelle, l.evenement_code ?? '',
            montantOuVide(l.debit_centimes), montantOuVide(l.credit_centimes), solde(l.cumul),
          ])}
        />
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ l2">
          <label htmlFor="g-c">Compte</label>
          <select id="g-c" name="c" defaultValue={compte.numero}>
            {comptes.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="g-du">Du</label>
          <input id="g-du" name="du" type="date" defaultValue={du} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="g-au">Au</label>
          <input id="g-au" name="au" type="date" defaultValue={au} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <h2>{compte.numero}, {compte.intitule}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Date</th><th>Pièce</th><th>Libellé</th><th>Évt</th><th className="n">Débit</th><th className="n">Crédit</th><th className="n">Solde</th></tr>
            </thead>
            <tbody>
              <tr className="groupe">
                <td className="fixe">{dateFr(du)}</td><td></td><td>Solde reporté</td><td></td><td></td><td></td>
                <td className="n">{solde(report)}</td>
              </tr>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe">{dateFr(l.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                  <td>{l.libelle}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                  <td className="n">{solde(l.cumul)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={7}>Aucun mouvement sur cette période.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4}>Total de la période</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
                <td className="n">{solde(cumul)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="cpt-info">Solde suivi de D pour débiteur, C pour créditeur.</p>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/grand-livre/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/journaux'
cat > 'src/app/admin/(protected)/compta/journaux/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { aujourdhui, dateFr, estDateIso, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

type Params = { ex?: string; j?: string; du?: string; au?: string; evt?: string; sj?: string };

export default async function Journaux({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { journaux, evenements }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  // Par défaut : le mois en cours, ou tout l'exercice s'il est passé.
  const jour = aujourdhui();
  const dansExercice = exercice.date_debut <= jour && jour <= exercice.date_fin;
  const du = estDateIso(sp.du) ? sp.du : dansExercice ? `${jour.slice(0, 8)}01` : exercice.date_debut;
  const au = estDateIso(sp.au) ? sp.au : exercice.date_fin;
  const journal = journaux.some((j) => j.code === sp.j) ? sp.j! : '';
  const evt = evenements.some((e) => e.id === sp.evt) ? sp.evt! : '';
  const sansJustificatif = sp.sj === '1';

  const lignes = await lireTout<LigneVue>((de, a) => {
    let q = supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).gte('date_piece', du).lte('date_piece', au);
    if (journal) q = q.eq('journal_code', journal);
    if (evt) q = q.eq('compta_evenement_id', evt);
    if (sansJustificatif) {
      q = q.eq('source', 'manuel').neq('journal_code', 'AN').is('justificatif_chemin', null).is('contrepassee_par', null);
    }
    return q.order('date_piece').order('journal_code').order('numero').order('position').range(de, a);
  });

  const totalDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);
  const nbPieces = new Set(lignes.map((l) => l.ecriture_id)).size;

  return (
    <>
      <Entete titre="Journaux" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`journal-${journal || 'tous'}-${du}-${au}`}
          entetes={['Date', 'Journal', 'Pièce', 'Compte', 'Intitulé', 'Libellé', 'Événement', 'Débit', 'Crédit']}
          lignes={lignes.map((l) => [
            dateFr(l.date_piece), l.journal_code, l.piece, l.compte_numero, l.compte_intitule, l.libelle,
            l.evenement_code ?? '', montantOuVide(l.debit_centimes), montantOuVide(l.credit_centimes),
          ])}
        />
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ">
          <label htmlFor="f-j">Journal</label>
          <select id="f-j" name="j" defaultValue={journal}>
            <option value="">Tous les journaux</option>
            {journaux.map((j) => <option key={j.code} value={j.code}>{j.code}, {j.libelle}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-du">Du</label>
          <input id="f-du" name="du" type="date" defaultValue={du} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-au">Au</label>
          <input id="f-au" name="au" type="date" defaultValue={au} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-evt">Événement</label>
          <select id="f-evt" name="evt" defaultValue={evt}>
            <option value="">Tous</option>
            {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-sj">Justificatif</label>
          <select id="f-sj" name="sj" defaultValue={sansJustificatif ? '1' : ''}>
            <option value="">Toutes les pièces</option>
            <option value="1">Saisies sans justificatif</option>
          </select>
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Date</th><th>Pièce</th><th>Compte</th><th>Intitulé</th><th>Libellé</th><th>Évt</th>
                <th className="n">Débit</th><th className="n">Crédit</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id} className={l.contrepassee_par ? 'annulee' : ''}>
                  <td className="fixe">{dateFr(l.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                  <td className="fixe">{l.compte_numero}</td>
                  <td>{l.compte_intitule}</td>
                  <td>{l.libelle}{l.contrepassee_par ? ' (annulée)' : ''}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={8}>Aucune écriture sur cette période.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={6}>Totaux de la période</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="cpt-info">
        {nbPieces} pièce(s), {lignes.length} ligne(s), du {dateFr(du)} au {dateFr(au)}.
        {evt && ' Seules les lignes portant ce code événement sont affichées.'}
      </p>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/journaux/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/piece/[id]'
cat > 'src/app/admin/(protected)/compta/piece/[id]/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { dateFr, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import ActionsPiece from '@/components/compta/ActionsPiece';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ORIGINE: Record<string, string> = { manuel: 'Saisie', site: 'Import du site', annulation: 'Annulation' };

export default async function Piece({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const { supabase } = await requireAdmin();

  const { data: e } = await supabase.from('compta_ecritures').select('*').eq('id', id).maybeSingle();
  if (!e) notFound();

  const [{ data: lg }, { data: annulation }, justificatif] = await Promise.all([
    supabase.from('compta_v_lignes').select('*').eq('ecriture_id', id).order('position'),
    e.contrepassee_par
      ? supabase.from('compta_ecritures').select('id, piece').eq('id', e.contrepassee_par).maybeSingle()
      : Promise.resolve({ data: null }),
    e.justificatif_chemin
      ? supabase.storage.from('compta-justificatifs').createSignedUrl(e.justificatif_chemin, 3600)
      : Promise.resolve({ data: null }),
  ]);

  const lignes = (lg ?? []) as LigneVue[];
  const total = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const lien = (justificatif.data as { signedUrl?: string } | null)?.signedUrl ?? null;

  return (
    <>
      <Entete titre={`Pièce ${e.piece}`}>
        <Link className="cpt-btn" href={`/admin/compta/journaux?j=${e.journal_code}&du=${e.date_piece}&au=${e.date_piece}`}>
          Retour au journal
        </Link>
      </Entete>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille">
            <tbody>
              <tr><th style={{ width: 160 }}>Date</th><td>{dateFr(e.date_piece)}</td></tr>
              <tr><th>Journal</th><td>{e.journal_code}</td></tr>
              <tr><th>Libellé</th><td>{e.libelle}</td></tr>
              <tr><th>Origine</th><td>{ORIGINE[e.source] ?? e.source}, par {e.cree_par_nom ?? 'inconnu'}, le {dateFr(e.created_at)}</td></tr>
              <tr>
                <th>Justificatif</th>
                <td>{lien ? <a href={lien} target="_blank" rel="noreferrer">Ouvrir le justificatif</a> : 'Aucun'}</td>
              </tr>
              {annulation && (
                <tr>
                  <th>État</th>
                  <td>
                    <span className="cpt-etat rouge">Annulée</span>{' '}
                    par la pièce <Link href={`/admin/compta/piece/${annulation.id}`}>{annulation.piece}</Link>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Lignes</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Compte</th><th>Intitulé</th><th>Libellé</th><th>Évt</th><th className="n">Débit</th><th className="n">Crédit</th></tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe">{l.compte_numero}</td>
                  <td>{l.compte_intitule}</td>
                  <td>{l.libelle}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr><td colSpan={4}>Totaux</td><td className="n">{montant(total)}</td><td className="n">{montant(total)}</td></tr>
            </tfoot>
          </table>
        </div>
      </div>

      <ActionsPiece
        id={e.id}
        piece={e.piece}
        annee={String(e.date_piece).slice(0, 4)}
        annulable={e.source !== 'annulation' && !e.contrepassee_par}
        aJustificatif={!!e.justificatif_chemin}
      />
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/piece/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/plan'
cat > 'src/app/admin/(protected)/compta/plan/page.tsx' <<'EOF_COMPTA_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, referentiel, suffixeEx } from '@/lib/compta/db';
import { dateFr, solde } from '@/lib/compta/format';
import { LIBELLE_TYPE, type LigneBalance } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import { BasculeCompte, BasculeExercice, FormCompte, FormExercice } from '@/components/compta/FormsPlan';

export default async function Plan({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase, isAdmin } = await requireAdmin();
  const [{ exercices, exercice }, { comptes, journaux }] = await Promise.all([
    contexte(supabase, ex),
    referentiel(supabase),
  ]);

  const { data: bal } = exercice
    ? await supabase.from('compta_v_balance').select('numero, solde_centimes').eq('exercice_id', exercice.id)
    : { data: [] };
  const soldes = new Map(((bal ?? []) as Pick<LigneBalance, 'numero' | 'solde_centimes'>[]).map((l) => [l.numero, l.solde_centimes]));

  return (
    <>
      <Entete titre="Plan comptable et exercices" exercices={exercices} exercice={exercice} />

      <div className="cpt-panneau">
        <h2>Plan comptable{exercice ? `, soldes de l'exercice ${exercice.libelle}` : ''}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Compte</th><th>Intitulé</th><th>Type</th><th className="n">Solde</th><th>État</th>{isAdmin && <th></th>}</tr>
            </thead>
            <tbody>
              {comptes.map((c) => (
                <tr key={c.numero}>
                  <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${c.numero}${suffixeEx(ex, false)}`}>{c.numero}</Link></td>
                  <td>{c.intitule}</td>
                  <td className="fixe">{LIBELLE_TYPE[c.type]}</td>
                  <td className="n">{soldes.has(c.numero) ? solde(soldes.get(c.numero)!) : ''}</td>
                  <td><span className={`cpt-etat ${c.actif ? 'vert' : ''}`}>{c.actif ? 'Actif' : 'Inactif'}</span></td>
                  {isAdmin && <td><BasculeCompte numero={c.numero} actif={c.actif} /></td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {isAdmin && (
          <div style={{ marginTop: 10 }}>
            <FormCompte />
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
              Saisir un numéro existant renomme le compte. Un compte désactivé reste dans les états mais n&apos;est plus proposé à la saisie.
            </p>
          </div>
        )}
      </div>

      <div className="cpt-panneau">
        <h2>Journaux</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Code</th><th>Libellé</th><th>Compte de trésorerie</th></tr></thead>
            <tbody>
              {journaux.map((j) => (
                <tr key={j.code}><td className="fixe">{j.code}</td><td>{j.libelle}</td><td className="fixe">{j.compte_tresorerie ?? ''}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Exercices</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Exercice</th><th>Du</th><th>Au</th><th>État</th>{isAdmin && <th></th>}</tr></thead>
            <tbody>
              {exercices.map((e) => (
                <tr key={e.id}>
                  <td className="fixe">{e.libelle}</td>
                  <td className="fixe">{dateFr(e.date_debut)}</td>
                  <td className="fixe">{dateFr(e.date_fin)}</td>
                  <td>
                    <span className={`cpt-etat ${e.cloture ? 'rouge' : 'vert'}`}>
                      {e.cloture ? `Clôturé le ${dateFr(e.cloture_le)}` : 'Ouvert'}
                    </span>
                  </td>
                  {isAdmin && <td><BasculeExercice id={e.id} libelle={e.libelle} cloture={e.cloture} /></td>}
                </tr>
              ))}
              {exercices.length === 0 && <tr><td colSpan={isAdmin ? 5 : 4}>Aucun exercice.</td></tr>}
            </tbody>
          </table>
        </div>
        {isAdmin && <div style={{ marginTop: 10 }}><FormExercice /></div>}
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Un exercice clôturé n&apos;accepte plus aucune écriture. Les soldes de départ du suivant se saisissent dans le journal AN (saisie libre).
        </p>
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/plan/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/rapprochement'
cat > 'src/app/admin/(protected)/compta/rapprochement/page.tsx' <<'EOF_COMPTA_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { aujourdhui, dateFr, enCentimes, estDateIso, montant } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import Imprimer from '@/components/compta/Imprimer';
import { BoutonValiderRapprochement, TablePointage } from '@/components/compta/TablePointage';

type Params = { ex?: string; c?: string; date?: string; solde?: string };

/** Les lignes déjà pointées restent affichées 45 jours pour pouvoir corriger une erreur. */
const JOURS_VISIBLES = 45;

export default async function Rapprochement({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { comptes }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  const tresos = comptes.filter((c) => c.type === 'tresorerie');
  const compte = tresos.find((c) => c.numero === sp.c) ?? tresos.find((c) => c.numero === '512000') ?? tresos[0];
  if (!compte) return <SansExercice />;

  const jour = aujourdhui();
  const parDefaut = jour > exercice.date_fin ? exercice.date_fin : jour < exercice.date_debut ? exercice.date_debut : jour;
  const date = estDateIso(sp.date) ? sp.date : parDefaut;
  const soldeReleve = sp.solde?.trim() ? enCentimes(sp.solde.replace(/^-/, '')) : null;
  const soldeSigne = soldeReleve !== null && sp.solde?.trim().startsWith('-') ? -soldeReleve : soldeReleve;

  const lignes = await lireTout<LigneVue>((de, a) =>
    supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).eq('compte_numero', compte.numero).lte('date_piece', date)
      .order('date_piece').order('journal_code').order('numero').order('position').range(de, a)
  );

  const soldeComptable = lignes.reduce((s, l) => s + l.debit_centimes - l.credit_centimes, 0);
  const nonPointees = lignes.filter((l) => !l.pointe_le);
  const debitsNonPointes = nonPointees.reduce((s, l) => s + l.debit_centimes, 0);
  const creditsNonPointes = nonPointees.reduce((s, l) => s + l.credit_centimes, 0);
  const soldeTheorique = soldeComptable - debitsNonPointes + creditsNonPointes;
  const ecart = soldeSigne === null ? null : soldeSigne - soldeTheorique;

  const limite = new Date(`${date}T12:00:00Z`);
  limite.setUTCDate(limite.getUTCDate() - JOURS_VISIBLES);
  const depuis = limite.toISOString().slice(0, 10);
  const affichees = lignes.filter((l) => !l.pointe_le || l.date_piece >= depuis);

  const { data: historique } = await supabase.from('compta_rapprochements').select('*')
    .eq('compte_numero', compte.numero).order('date_releve', { ascending: false }).limit(6);

  return (
    <>
      <Entete titre="Rapprochement bancaire" exercices={exercices} exercice={exercice}>
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ">
          <label htmlFor="r-c">Compte</label>
          <select id="r-c" name="c" defaultValue={compte.numero}>
            {tresos.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="r-date">Relevé au</label>
          <input id="r-date" name="date" type="date" defaultValue={date} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="r-solde">Solde du relevé</label>
          <input id="r-solde" name="solde" className="n" type="text" inputMode="decimal" placeholder="0,00" defaultValue={sp.solde ?? ''} />
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <h2>Écritures de {compte.numero}, {compte.intitule}, jusqu&apos;au {dateFr(date)}</h2>
        <TablePointage
          lignes={affichees.map((l) => ({
            id: l.id, ecriture_id: l.ecriture_id, date_piece: l.date_piece, piece: l.piece, libelle: l.libelle,
            debit_centimes: l.debit_centimes, credit_centimes: l.credit_centimes, pointe: !!l.pointe_le,
          }))}
        />
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Coche chaque ligne présente sur le relevé de la banque. Les lignes pointées depuis plus de {JOURS_VISIBLES} jours ne sont plus affichées.
        </p>
      </div>

      <div className="cpt-panneau">
        <h2>État de rapprochement au {dateFr(date)}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th></th><th className="n">Montant</th></tr></thead>
            <tbody>
              <tr><td>Solde comptable du compte {compte.numero}</td><td className="n">{montant(soldeComptable)}</td></tr>
              <tr><td>Plus : paiements émis non encore débités</td><td className="n">{montant(creditsNonPointes)}</td></tr>
              <tr><td>Moins : encaissements non encore crédités</td><td className="n">{montant(debitsNonPointes)}</td></tr>
              <tr><td>Solde attendu sur le relevé</td><td className="n">{montant(soldeTheorique)}</td></tr>
              <tr><td>Solde du relevé saisi</td><td className="n">{soldeSigne === null ? 'à saisir' : montant(soldeSigne)}</td></tr>
            </tbody>
            <tfoot>
              <tr><td>Écart</td><td className="n">{ecart === null ? '' : montant(ecart)}</td></tr>
            </tfoot>
          </table>
        </div>
        {ecart === null && <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>Saisis le solde figurant sur le relevé puis clique sur Afficher.</p>}
        {ecart === 0 && <p className="cpt-ok">Écart nul. Le rapprochement peut être validé.</p>}
        {ecart !== null && ecart !== 0 && <p className="cpt-ko">Écart de {montant(ecart)} € : une ligne manque, est en trop ou est mal pointée.</p>}
        <BoutonValiderRapprochement compte={compte.numero} date={date} solde={soldeSigne} possible={ecart === 0} />
      </div>

      <div className="cpt-panneau">
        <h2>Rapprochements validés</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Relevé au</th><th className="n">Solde du relevé</th><th>Validé par</th><th>Le</th></tr></thead>
            <tbody>
              {((historique ?? []) as any[]).map((h) => (
                <tr key={h.id}>
                  <td className="fixe">{dateFr(h.date_releve)}</td>
                  <td className="n">{montant(h.solde_releve_centimes)}</td>
                  <td>{h.valide_par_nom}</td>
                  <td className="fixe">{dateFr(h.created_at)}</td>
                </tr>
              ))}
              {(historique ?? []).length === 0 && <tr><td colSpan={4}>Aucun rapprochement validé pour ce compte.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/rapprochement/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/resultat'
cat > 'src/app/admin/(protected)/compta/resultat/page.tsx' <<'EOF_COMPTA_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { contexte } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

export default async function Resultat({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();
  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const { data } = await supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero');
  const lignes = (data ?? []) as LigneBalance[];
  const charges = lignes.filter((l) => l.type === 'charge').map((l) => ({ ...l, montant: l.solde_centimes }));
  const produits = lignes.filter((l) => l.type === 'produit').map((l) => ({ ...l, montant: -l.solde_centimes }));
  const totalCharges = charges.reduce((s, l) => s + l.montant, 0);
  const totalProduits = produits.reduce((s, l) => s + l.montant, 0);
  const resultat = totalProduits - totalCharges;
  const total = Math.max(totalCharges, totalProduits);

  return (
    <>
      <Entete titre="Compte de résultat" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`compte-de-resultat-${exercice.libelle}`}
          entetes={['Nature', 'Compte', 'Intitulé', 'Montant']}
          lignes={[
            ...charges.map((l) => ['Charge', l.numero, l.intitule, montant(l.montant)]),
            ...produits.map((l) => ['Produit', l.numero, l.intitule, montant(l.montant)]),
            [resultat >= 0 ? 'Excédent' : 'Déficit', '', '', montant(Math.abs(resultat))],
          ]}
        />
        <Imprimer />
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}.
        {exercice.cloture ? ' Exercice clôturé.' : ' Situation provisoire, exercice en cours.'}
      </p>

      <div className="cpt-cols">
        <div className="cpt-panneau">
          <h2>Charges</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                {charges.map((l) => (
                  <tr key={l.numero}><td className="fixe">{l.numero}</td><td>{l.intitule}</td><td className="n">{montant(l.montant)}</td></tr>
                ))}
                {charges.length === 0 && <tr><td colSpan={3}>Aucune charge.</td></tr>}
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>Total des charges</td><td className="n">{montant(totalCharges)}</td></tr>
                {resultat > 0 && <tr><td colSpan={2}>Excédent</td><td className="n">{montant(resultat)}</td></tr>}
                <tr><td colSpan={2}>Total</td><td className="n">{montant(total)}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>

        <div className="cpt-panneau">
          <h2>Produits</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                {produits.map((l) => (
                  <tr key={l.numero}><td className="fixe">{l.numero}</td><td>{l.intitule}</td><td className="n">{montant(l.montant)}</td></tr>
                ))}
                {produits.length === 0 && <tr><td colSpan={3}>Aucun produit.</td></tr>}
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>Total des produits</td><td className="n">{montant(totalProduits)}</td></tr>
                {resultat < 0 && <tr><td colSpan={2}>Déficit</td><td className="n">{montant(-resultat)}</td></tr>}
                <tr><td colSpan={2}>Total</td><td className="n">{montant(total)}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>

      <p className={resultat >= 0 ? 'cpt-ok' : 'cpt-ko'}>
        {resultat >= 0 ? 'Excédent' : 'Déficit'} de l&apos;exercice : {montant(Math.abs(resultat))} €
      </p>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/resultat/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/saisie'
cat > 'src/app/admin/(protected)/compta/saisie/page.tsx' <<'EOF_COMPTA_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, referentiel } from '@/lib/compta/db';
import { aujourdhui } from '@/lib/compta/format';
import Entete from '@/components/compta/Entete';
import FormSaisie from '@/components/compta/FormSaisie';

export default async function Saisie() {
  const { supabase } = await requireAdmin();
  const [{ exercice }, { comptes, journaux, evenements }] = await Promise.all([
    contexte(supabase),
    referentiel(supabase),
  ]);

  return (
    <>
      <Entete titre="Saisie d'une écriture" />
      {exercice?.cloture && (
        <div className="cpt-msg ko">L&apos;exercice {exercice.libelle} est clôturé : les écritures datées de cet exercice seront refusées.</div>
      )}
      <FormSaisie comptes={comptes} journaux={journaux} evenements={evenements} dateDefaut={aujourdhui()} />
      <p className="cpt-info">
        Saisie ouverte aux admins et aux trésorières. Une écriture validée ne se supprime pas : elle s&apos;annule par une écriture inverse,
        depuis la fiche de la pièce.
      </p>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/saisie/page.tsx"
mkdir -p 'src/app/admin/(protected)/compta/ventes'
cat > 'src/app/admin/(protected)/compta/ventes/page.tsx' <<'EOF_COMPTA_FICHIER'
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
EOF_COMPTA_FICHIER
echo "  ✓ src/app/admin/(protected)/compta/ventes/page.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/ActionsPiece.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { contrepasser, joindreJustificatif } from '@/app/compta-actions';
import { ACCEPT_JUSTIFICATIF, envoyerJustificatif } from '@/components/compta/envoi';
import type { Retour } from '@/lib/compta/types';

type Props = {
  id: string;
  piece: string;
  annee: string;
  annulable: boolean;
  aJustificatif: boolean;
};

/** Actions sur une pièce : annulation par écriture inverse, ajout du justificatif. */
export default function ActionsPiece({ id, piece, annee, annulable, aJustificatif }: Props) {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  const input = useRef<HTMLInputElement>(null);

  function annuler() {
    const motif = window.prompt(`Annuler la pièce ${piece} par une écriture inverse ?\nMotif (facultatif) :`, '');
    if (motif === null) return;
    start(async () => {
      const r = await contrepasser(id, motif);
      setRetour(r);
      if (r?.ok) router.refresh();
    });
  }

  function joindre(fichier: File | undefined) {
    if (!fichier) return;
    start(async () => {
      try {
        const chemin = await envoyerJustificatif(fichier, annee);
        const r = await joindreJustificatif(id, chemin);
        setRetour(r);
        if (r?.ok) router.refresh();
      } catch (e: any) {
        setRetour({ erreur: e?.message ?? "L'envoi a échoué." });
      } finally {
        if (input.current) input.current.value = '';
      }
    });
  }

  return (
    <>
      {retour?.ok && <div className="cpt-msg ok">{retour.ok}</div>}
      {retour?.erreur && <div className="cpt-msg ko">{retour.erreur}</div>}
      <div className="cpt-outils">
        <button type="button" className="cpt-btn" disabled={pending} onClick={() => input.current?.click()}>
          {aJustificatif ? 'Remplacer le justificatif' : 'Joindre un justificatif'}
        </button>
        <input ref={input} type="file" accept={ACCEPT_JUSTIFICATIF} hidden onChange={(e) => joindre(e.target.files?.[0])} />
        {annulable && (
          <button type="button" className="cpt-btn" disabled={pending} onClick={annuler}>
            Annuler cette pièce
          </button>
        )}
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/ActionsPiece.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/ActionsVente.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { contrepasser, importerVentes, marquerVerifie } from '@/app/compta-actions';
import type { Retour } from '@/lib/compta/types';

/** Bouton « Relancer l'import » des ventes du site. */
export function BoutonImport() {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  return (
    <>
      {retour?.ok && <span className="cpt-etat vert">{retour.ok}</span>}
      {retour?.erreur && <span className="cpt-etat rouge">{retour.erreur}</span>}
      <button
        type="button"
        className="cpt-btn"
        disabled={pending}
        onClick={() => start(async () => { const r = await importerVentes(); setRetour(r); router.refresh(); })}
      >
        {pending ? 'Import en cours…' : "Relancer l'import"}
      </button>
    </>
  );
}

/** Actions sur une vente dont le statut a changé depuis l'import. */
export function BoutonsVente({ id, piece }: { id: string; piece: string }) {
  const router = useRouter();
  const [erreur, setErreur] = useState('');
  const [pending, start] = useTransition();

  const lancer = (action: () => Promise<Retour>) =>
    start(async () => {
      const r = await action();
      if (r?.erreur) setErreur(r.erreur);
      else router.refresh();
    });

  return (
    <div className="cpt-outils">
      <button type="button" className="cpt-btn mini p" disabled={pending}
        onClick={() => {
          if (window.confirm(`Annuler la pièce ${piece} par une écriture inverse ?`)) {
            lancer(() => contrepasser(id, 'vente remboursée ou annulée'));
          }
        }}>
        Annuler la vente
      </button>
      <button type="button" className="cpt-btn mini" disabled={pending} onClick={() => lancer(() => marquerVerifie(id))}>
        Ignorer
      </button>
      {erreur && <span className="cpt-etat rouge">{erreur}</span>}
    </div>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/ActionsVente.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/ChoixExercice.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import type { Exercice } from '@/lib/compta/types';

/** Liste déroulante de l'exercice affiché. Conserve les autres filtres de la page. */
export default function ChoixExercice({ exercices, courant }: { exercices: Exercice[]; courant: string }) {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  if (exercices.length < 2) return null;

  return (
    <select
      aria-label="Exercice"
      value={courant}
      onChange={(e) => {
        const p = new URLSearchParams(params.toString());
        p.set('ex', e.target.value);
        // Les dates d'un autre exercice n'ont plus de sens.
        p.delete('du');
        p.delete('au');
        router.push(`${path}?${p.toString()}`);
      }}
      style={{ font: 'inherit', fontSize: 13, padding: '5px 7px', border: '1px solid #C9D0D8', borderRadius: 3, background: '#fff' }}
    >
      {exercices.map((e) => (
        <option key={e.id} value={e.id}>
          Exercice {e.libelle}{e.cloture ? ' (clôturé)' : ''}
        </option>
      ))}
    </select>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/ChoixExercice.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/Entete.tsx' <<'EOF_COMPTA_FICHIER'
import { Suspense } from 'react';
import ChoixExercice from '@/components/compta/ChoixExercice';
import type { Exercice } from '@/lib/compta/types';

type Props = {
  titre: string;
  exercices?: Exercice[];
  exercice?: Exercice | null;
  children?: React.ReactNode;
};

/** Titre de page, choix de l'exercice et boutons d'action. */
export default function Entete({ titre, exercices, exercice, children }: Props) {
  return (
    <div className="cpt-titre">
      <h1>{titre}</h1>
      <div className="cpt-outils">
        {exercices && exercice && (
          <Suspense fallback={null}>
            <ChoixExercice exercices={exercices} courant={exercice.id} />
          </Suspense>
        )}
        {children}
      </div>
    </div>
  );
}

export function SansExercice() {
  return (
    <div className="cpt-panneau">
      <h2>Aucun exercice</h2>
      <p className="cpt-info">Crée un exercice dans « Plan et exercices » pour commencer.</p>
    </div>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/Entete.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/ExportCsvCompta.tsx' <<'EOF_COMPTA_FICHIER'
'use client';

type Props = {
  nom: string;
  entetes: string[];
  lignes: (string | number | null)[][];
  libelle?: string;
};

const echappe = (v: string | number | null) => `"${String(v ?? '').replace(/"/g, '""')}"`;

/** Export CSV (séparateur point-virgule, BOM UTF-8 pour Excel). */
export default function ExportCsvCompta({ nom, entetes, lignes, libelle = 'Exporter en CSV' }: Props) {
  function telecharger() {
    const csv = '\uFEFF' + [entetes, ...lignes].map((l) => l.map(echappe).join(';')).join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `${nom}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
  return (
    <button type="button" className="cpt-btn" onClick={telecharger} disabled={lignes.length === 0}>
      {libelle}
    </button>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/ExportCsvCompta.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/FormSaisie.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useMemo, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import { saisirEcriture } from '@/app/compta-actions';
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

export default function FormSaisie({ comptes, journaux, evenements, dateDefaut }: Props) {
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
                    <select id="s-evt" value={evenement} onChange={(e) => setEvenement(e.target.value)}>
                      <option value="">Aucun, fonctionnement général</option>
                      {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}, {e.libelle}</option>)}
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
            <button type="button" className="cpt-btn"
              onClick={() => setLignesLibres((ls) => [...ls, ligneVide(compteur.current++)])}>
              Ajouter une ligne
            </button>
          )}
        </div>
      </div>
    </>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/FormSaisie.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/FormsBudget.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useActionState } from 'react';
import { enregistrerBudget, enregistrerEvenement } from '@/app/compta-actions';
import type { Compte, EvenementCompta, Retour } from '@/lib/compta/types';

function Message({ etat }: { etat: Retour }) {
  if (etat?.ok) return <div className="cpt-msg ok">{etat.ok}</div>;
  if (etat?.erreur) return <div className="cpt-msg ko">{etat.erreur}</div>;
  return null;
}

/** Création ou modification d'un code événement. */
export function FormEvenement({ evenement }: { evenement?: EvenementCompta | null }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerEvenement, null);
  const p = evenement ? 'em' : 'en'; // deux formulaires peuvent cohabiter sur la page
  return (
    <form action={action} key={evenement?.id ?? 'nouveau'}>
      <Message etat={etat} />
      <input type="hidden" name="id" value={evenement?.id ?? ''} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '0 1 120px' }}>
          <label htmlFor={`${p}-code`}>Code</label>
          <input id={`${p}-code`} name="code" defaultValue={evenement?.code ?? ''} maxLength={12} required />
        </div>
        <div className="cpt-champ" style={{ flex: '2 1 200px' }}>
          <label htmlFor={`${p}-libelle`}>Libellé</label>
          <input id={`${p}-libelle`} name="libelle" defaultValue={evenement?.libelle ?? ''} required />
        </div>
        <div className="cpt-champ">
          <label htmlFor={`${p}-date`}>Date</label>
          <input id={`${p}-date`} name="date_evenement" type="date" defaultValue={evenement?.date_evenement ?? ''} />
        </div>
        <div className="cpt-champ">
          <label htmlFor={`${p}-statut`}>Statut</label>
          <select id={`${p}-statut`} name="statut" defaultValue={evenement?.statut ?? 'en_cours'}>
            <option value="a_venir">À venir</option>
            <option value="en_cours">En cours</option>
            <option value="termine">Terminé</option>
          </select>
        </div>
        <button className="cpt-btn p" disabled={pending}>{evenement ? 'Enregistrer' : "Créer l'événement"}</button>
      </div>
    </form>
  );
}

/** Montant prévu d'un compte pour un événement. Un montant à 0 retire la ligne. */
export function FormBudget({ evenementId, comptes }: { evenementId: string; comptes: Compte[] }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerBudget, null);
  const postes = comptes.filter((c) => c.actif && (c.type === 'charge' || c.type === 'produit'));
  return (
    <form action={action}>
      <Message etat={etat} />
      <input type="hidden" name="compta_evenement_id" value={evenementId} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '2 1 240px' }}>
          <label htmlFor="b-compte">Poste</label>
          <select id="b-compte" name="compte_numero" required>
            <optgroup label="Recettes">
              {postes.filter((c) => c.type === 'produit').map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
            </optgroup>
            <optgroup label="Dépenses">
              {postes.filter((c) => c.type === 'charge').map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
            </optgroup>
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="b-montant">Montant prévu</label>
          <input id="b-montant" name="montant" className="n" type="text" inputMode="decimal" placeholder="0,00" required />
        </div>
        <button className="cpt-btn p" disabled={pending}>Enregistrer le prévu</button>
      </div>
    </form>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/FormsBudget.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/FormsPlan.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useActionState, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import {
  basculerCompte, basculerExercice, creerExercice, enregistrerCompte, reglerSource,
} from '@/app/compta-actions';
import type { Retour } from '@/lib/compta/types';

function Message({ etat }: { etat: Retour }) {
  if (etat?.ok) return <div className="cpt-msg ok">{etat.ok}</div>;
  if (etat?.erreur) return <div className="cpt-msg ko">{etat.erreur}</div>;
  return null;
}

export function FormCompte() {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerCompte, null);
  return (
    <form action={action}>
      <Message etat={etat} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '0 1 120px' }}>
          <label htmlFor="c-numero">Numéro</label>
          <input id="c-numero" name="numero" inputMode="numeric" maxLength={6} placeholder="606400" required />
        </div>
        <div className="cpt-champ" style={{ flex: '2 1 220px' }}>
          <label htmlFor="c-intitule">Intitulé</label>
          <input id="c-intitule" name="intitule" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="c-type">Type</label>
          <select id="c-type" name="type" defaultValue="charge">
            <option value="charge">Charge</option>
            <option value="produit">Produit</option>
            <option value="tresorerie">Trésorerie</option>
            <option value="bilan">Bilan</option>
          </select>
        </div>
        <button className="cpt-btn p" disabled={pending}>Ajouter ou renommer</button>
      </div>
    </form>
  );
}

export function BasculeCompte({ numero, actif }: { numero: string; actif: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <button type="button" className="cpt-btn mini" disabled={pending}
      onClick={() => start(async () => { await basculerCompte(numero, !actif); router.refresh(); })}>
      {actif ? 'Désactiver' : 'Réactiver'}
    </button>
  );
}

export function FormExercice() {
  const [etat, action, pending] = useActionState<Retour, FormData>(creerExercice, null);
  return (
    <form action={action}>
      <Message etat={etat} />
      <div className="cpt-ligne">
        <div className="cpt-champ">
          <label htmlFor="x-libelle">Libellé</label>
          <input id="x-libelle" name="libelle" placeholder="2027" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="x-debut">Début</label>
          <input id="x-debut" name="date_debut" type="date" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="x-fin">Fin</label>
          <input id="x-fin" name="date_fin" type="date" required />
        </div>
        <button className="cpt-btn p" disabled={pending}>Créer l&apos;exercice</button>
      </div>
    </form>
  );
}

export function BasculeExercice({ id, libelle, cloture }: { id: string; libelle: string; cloture: boolean }) {
  const router = useRouter();
  const [erreur, setErreur] = useState('');
  const [pending, start] = useTransition();
  return (
    <>
      <button type="button" className="cpt-btn mini" disabled={pending}
        onClick={() => {
          const question = cloture
            ? `Rouvrir l'exercice ${libelle} ?`
            : `Clôturer l'exercice ${libelle} ? Plus aucune écriture ne pourra y être ajoutée.`;
          if (!window.confirm(question)) return;
          start(async () => {
            const r = await basculerExercice(id, !cloture);
            if (r?.erreur) setErreur(r.erreur);
            router.refresh();
          });
        }}>
        {cloture ? 'Rouvrir' : 'Clôturer'}
      </button>
      {erreur && <span className="cpt-etat rouge">{erreur}</span>}
    </>
  );
}

/** Réglages d'une source de ventes du site (admin). */
export function FormSource({ cle, actif, taux, fixe }: { cle: string; actif: boolean; taux: number; fixe: string }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(reglerSource, null);
  return (
    <form action={action}>
      <input type="hidden" name="cle" value={cle} />
      <div className="cpt-ligne" style={{ alignItems: 'center' }}>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          <input type="checkbox" name="actif" defaultChecked={actif} /> Actif
        </label>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          Frais %
          <input name="taux_frais" className="n" type="text" inputMode="decimal" defaultValue={String(taux).replace('.', ',')}
            style={{ width: 64, minWidth: 0 }} />
        </label>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          + fixe
          <input name="frais_fixe" className="n" type="text" inputMode="decimal" defaultValue={fixe}
            style={{ width: 64, minWidth: 0 }} />
        </label>
        <button className="cpt-btn mini" disabled={pending}>Enregistrer</button>
        {etat?.ok && <span className="cpt-etat vert">{etat.ok}</span>}
        {etat?.erreur && <span className="cpt-etat rouge">{etat.erreur}</span>}
      </div>
    </form>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/FormsPlan.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/Imprimer.tsx' <<'EOF_COMPTA_FICHIER'
'use client';

export default function Imprimer({ libelle = 'Imprimer' }: { libelle?: string }) {
  return (
    <button type="button" className="cpt-btn" onClick={() => window.print()}>
      {libelle}
    </button>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/Imprimer.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/NavCompta.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';

const BASE = '/admin/compta';
const ONGLETS = [
  { href: BASE, label: 'Tableau de bord' },
  { href: `${BASE}/saisie`, label: 'Saisie' },
  { href: `${BASE}/ventes`, label: 'Ventes du site' },
  { href: `${BASE}/journaux`, label: 'Journaux' },
  { href: `${BASE}/grand-livre`, label: 'Grand livre' },
  { href: `${BASE}/balance`, label: 'Balance' },
  { href: `${BASE}/resultat`, label: 'Compte de résultat' },
  { href: `${BASE}/budgets`, label: 'Budgets par événement' },
  { href: `${BASE}/rapprochement`, label: 'Rapprochement bancaire' },
  { href: `${BASE}/plan`, label: 'Plan et exercices' },
];

export default function NavCompta() {
  const path = usePathname();
  const ex = useSearchParams().get('ex');
  const suffixe = ex ? `?ex=${ex}` : '';

  const actif = (href: string) => {
    if (href === BASE) return path === BASE;
    if (href === `${BASE}/journaux` && path.startsWith(`${BASE}/piece`)) return true;
    return path.startsWith(href);
  };

  return (
    <nav className="cpt-nav" aria-label="Menu de la comptabilité">
      {ONGLETS.map((o) => (
        <Link key={o.href} href={`${o.href}${suffixe}`} className={actif(o.href) ? 'on' : ''}>
          {o.label}
        </Link>
      ))}
    </nav>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/NavCompta.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/TablePointage.tsx' <<'EOF_COMPTA_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { pointerLignes, validerRapprochement } from '@/app/compta-actions';
import { dateFr, montantOuVide } from '@/lib/compta/format';
import type { Retour } from '@/lib/compta/types';

export type LignePointage = {
  id: string;
  ecriture_id: string;
  date_piece: string;
  piece: string;
  libelle: string;
  debit_centimes: number;
  credit_centimes: number;
  pointe: boolean;
};

/** Écritures d'un compte de trésorerie avec case à cocher de pointage. */
export function TablePointage({ lignes }: { lignes: LignePointage[] }) {
  const router = useRouter();
  // Coche affichée tout de suite, sans attendre la réponse du serveur.
  const [local, setLocal] = useState<Record<string, boolean>>({});
  const [erreur, setErreur] = useState('');
  const [, start] = useTransition();

  function basculer(id: string, pointe: boolean) {
    setLocal((v) => ({ ...v, [id]: pointe }));
    setErreur('');
    start(async () => {
      const r = await pointerLignes([id], pointe);
      if (r?.erreur) {
        setErreur(r.erreur);
        setLocal((v) => { const { [id]: _retire, ...reste } = v; return reste; });
      }
      router.refresh();
    });
  }

  return (
    <>
      {erreur && <div className="cpt-msg ko">{erreur}</div>}
      <div className="cpt-defile">
        <table className="cpt-grille">
          <thead>
            <tr><th>Pointé</th><th>Date</th><th>Pièce</th><th>Libellé</th><th className="n">Débit</th><th className="n">Crédit</th></tr>
          </thead>
          <tbody>
            {lignes.map((l) => (
              <tr key={l.id}>
                <td>
                  <input type="checkbox" aria-label={`Pointer ${l.piece}`} checked={local[l.id] ?? l.pointe}
                    onChange={(e) => basculer(l.id, e.target.checked)} />
                </td>
                <td className="fixe">{dateFr(l.date_piece)}</td>
                <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                <td>{l.libelle}</td>
                <td className="n">{montantOuVide(l.debit_centimes)}</td>
                <td className="n">{montantOuVide(l.credit_centimes)}</td>
              </tr>
            ))}
            {lignes.length === 0 && <tr><td colSpan={6}>Aucune écriture à pointer jusqu&apos;à cette date.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}

/** Enregistre le rapprochement quand l'écart est nul. */
export function BoutonValiderRapprochement({ compte, date, solde, possible }: {
  compte: string; date: string; solde: number | null; possible: boolean;
}) {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  return (
    <div className="cpt-outils" style={{ marginTop: 10 }}>
      <button type="button" className="cpt-btn p" disabled={!possible || pending || solde === null}
        onClick={() => start(async () => {
          if (solde === null) return;
          const r = await validerRapprochement(compte, date, solde);
          setRetour(r);
          if (r?.ok) router.refresh();
        })}>
        Valider le rapprochement
      </button>
      {retour?.ok && <span className="cpt-etat vert">{retour.ok}</span>}
      {retour?.erreur && <span className="cpt-etat rouge">{retour.erreur}</span>}
    </div>
  );
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/TablePointage.tsx"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/envoi.ts' <<'EOF_COMPTA_FICHIER'
'use client';
import { createClient } from '@/lib/supabase/client';

const TAILLE_MAX = 10 * 1024 * 1024; // 10 Mo
const TYPES = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic'];
export const ACCEPT_JUSTIFICATIF = '.pdf,image/jpeg,image/png,image/webp,image/heic';

/** Envoie un justificatif dans le stockage privé et renvoie son chemin. */
export async function envoyerJustificatif(fichier: File, annee: string): Promise<string> {
  if (fichier.type && !TYPES.includes(fichier.type)) {
    throw new Error('Formats acceptés : PDF, JPG, PNG, WebP ou HEIC.');
  }
  if (fichier.size > TAILLE_MAX) {
    throw new Error(`Fichier trop lourd (${(fichier.size / 1024 / 1024).toFixed(1)} Mo). Maximum 10 Mo.`);
  }
  const ext = fichier.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || 'pdf';
  const chemin = `${annee}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const { error } = await createClient().storage.from('compta-justificatifs').upload(chemin, fichier, { upsert: false });
  if (error) {
    throw new Error(
      error.message.includes('row-level security')
        ? 'Envoi refusé : droits insuffisants sur le stockage des justificatifs.'
        : "L'envoi du justificatif a échoué. Réessaie."
    );
  }
  return chemin;
}
EOF_COMPTA_FICHIER
echo "  ✓ src/components/compta/envoi.ts"

echo
echo "Terminé : 33 fichiers écrits."
echo "Étapes suivantes :"
echo "  1. Exécuter supabase/comptabilite.sql dans l'éditeur SQL du projet Supabase du CDF"
echo "  2. git add -A && git commit -m 'Module comptabilité' && git push && vercel --prod"
echo "  3. Admin, menu Comptabilité : saisir les soldes de départ (voir INSTALLATION-COMPTA.md)"
