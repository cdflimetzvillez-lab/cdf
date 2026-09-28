-- =========================================================
-- LE PÈRE NOËL TE RÉPOND — tables du module (préfixe pn_)
-- À exécuter une fois dans l'éditeur SQL de Supabase.
-- Les médias (image du Père Noël, audios, vidéos) vont dans le
-- bucket public « medias » déjà utilisé par le site, dossier pere-noel/.
-- =========================================================

create table if not exists pn_reglages (
  id                 int primary key default 1 check (id = 1),
  module_actif       boolean not null default false,
  commandes_ouvertes boolean not null default false,
  titre              text not null default 'Le Père Noël te répond',
  accroche           text not null default 'Ton enfant écrit au Père Noël. Le Père Noël lui répond en vidéo.',
  prix_centimes      int  not null default 1290,
  delai_texte        text not null default 'sous 48 h',
  generation_auto    boolean not null default false,   -- lancer la génération dès le paiement
  relecture_script   boolean not null default true,    -- l'admin relit le script avant l'audio/vidéo
  image_url          text,                              -- image du Père Noël (portrait 9:16)
  video_demo_url     text,                              -- vidéo de démonstration (page d'accueil)
  voice_id           text,                              -- voix ElevenLabs
  modele_voix        text not null default 'eleven_multilingual_v2',
  stabilite          numeric not null default 0.45,
  similarite         numeric not null default 0.75,
  style_voix         numeric not null default 0.30,
  vitesse            numeric not null default 0.92,
  expressivite       text not null default 'medium',   -- low | medium | high (HeyGen)
  motion_prompt      text not null default 'Le Père Noël parle chaleureusement face caméra, légers mouvements de tête, sourire, clignements naturels, les mains restent hors du cadre.',
  duree_cible_sec    int not null default 75,
  consignes_script   text not null default '',
  updated_at         timestamptz not null default now()
);
insert into pn_reglages (id) values (1) on conflict (id) do nothing;

create table if not exists pn_commandes (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  reference         text unique not null,
  token             text unique not null default encode(gen_random_bytes(16), 'hex'),
  test              boolean not null default false,

  -- parent
  parent_prenom     text not null default '',
  email             text not null,

  -- enfant
  enfant_prenom     text not null,
  prononciation     text,
  age               int,
  genre             text,                 -- fille | garcon | null
  sagesse           text not null default 'tres_sage',   -- presque | tres_sage | le_plus_sage
  lettre            text,
  cadeaux           text,
  fierte            text,
  passion           text,
  effort            text,
  salut             text,
  secret            text,
  ton_secret        text not null default 'rigolo',      -- rigolo | tendre | serieux

  -- paiement
  montant_centimes  int not null default 0,
  checkout_id       text,
  statut            text not null default 'en_attente',  -- en_attente | payee | echouee | expiree
  transaction_code  text,
  paye_le           timestamptz,

  -- génération
  gen_statut        text not null default 'a_faire',     -- a_faire | relecture | audio | video | terminee | erreur
  script            text,
  lettre_reponse    text,
  certificat_mention text,
  audio_url         text,
  heygen_video_id   text,
  video_url         text,
  duree_sec         int,
  erreur            text,
  livre_le          timestamptz,
  email_envoye      boolean not null default false
);
create index if not exists pn_commandes_statut_idx on pn_commandes (statut, gen_statut);
create index if not exists pn_commandes_checkout_idx on pn_commandes (checkout_id);

-- Sécurité : tout passe par le serveur (service role). Lecture publique des réglages uniquement.
alter table pn_reglages enable row level security;
alter table pn_commandes enable row level security;
drop policy if exists pn_reglages_lecture on pn_reglages;
create policy pn_reglages_lecture on pn_reglages for select using (true);

-- Statistiques pour le tableau de bord
create or replace view pn_stats as
select
  count(*) filter (where statut = 'payee' and not test)                              as commandes,
  coalesce(sum(montant_centimes) filter (where statut = 'payee' and not test), 0)   as ca_centimes,
  count(*) filter (where statut = 'payee' and gen_statut = 'a_faire')                as a_generer,
  count(*) filter (where statut = 'payee' and gen_statut = 'relecture')              as a_relire,
  count(*) filter (where statut = 'payee' and gen_statut in ('audio','video'))        as en_cours,
  count(*) filter (where statut = 'payee' and gen_statut = 'terminee')               as livrees,
  count(*) filter (where statut = 'payee' and gen_statut = 'erreur')                 as en_erreur,
  coalesce(sum(duree_sec) filter (where gen_statut = 'terminee'), 0)                 as secondes_video
from pn_commandes;
