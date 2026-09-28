-- Ajout : vidéo de démonstration sur la page d'accueil
alter table pn_reglages add column if not exists video_demo_url text;
