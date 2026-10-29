-- =========================================================
-- Liste d'attente par événement (quand l'événement est complet)
-- À exécuter dans Supabase > SQL Editor.
-- =========================================================

-- Option par événement : proposer la liste d'attente quand c'est complet
alter table public.evenements
  add column if not exists liste_attente_active boolean not null default false;

create table if not exists public.liste_attente (
  id            uuid primary key default gen_random_uuid(),
  evenement_id  uuid not null references public.evenements(id) on delete cascade,
  nom           text not null,
  email         text not null,
  telephone     text,
  places        integer not null default 1 check (places between 1 and 50),
  message       text,
  statut        text not null default 'en_attente',  -- en_attente | contacte | converti | annule
  created_at    timestamptz not null default now()
);
create index if not exists idx_liste_attente_evt on public.liste_attente(evenement_id, statut, created_at);

alter table public.liste_attente enable row level security;

drop policy if exists "public s'inscrit liste attente" on public.liste_attente;
drop policy if exists "admin lit liste attente" on public.liste_attente;
drop policy if exists "admin modifie liste attente" on public.liste_attente;
drop policy if exists "admin supprime liste attente" on public.liste_attente;

create policy "public s'inscrit liste attente" on public.liste_attente for insert with check (true);
create policy "admin lit liste attente"        on public.liste_attente for select using (public.is_admin());
create policy "admin modifie liste attente"    on public.liste_attente for update using (public.is_admin()) with check (public.is_admin());
create policy "admin supprime liste attente"   on public.liste_attente for delete using (public.is_admin());

notify pgrst, 'reload schema';
