-- Option « impression et envoi postal » + exemples
alter table pn_reglages add column if not exists envoi_postal_actif boolean not null default true;
alter table pn_reglages add column if not exists prix_postal_centimes int not null default 490;
alter table pn_commandes add column if not exists envoi_postal boolean not null default false;
alter table pn_commandes add column if not exists adresse_nom text;
alter table pn_commandes add column if not exists adresse_ligne1 text;
alter table pn_commandes add column if not exists adresse_ligne2 text;
alter table pn_commandes add column if not exists adresse_cp text;
alter table pn_commandes add column if not exists adresse_ville text;
alter table pn_commandes add column if not exists expedie_le timestamptz;
