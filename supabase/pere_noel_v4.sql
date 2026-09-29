-- Lecture publique des réglages Trésors de Noël (pour afficher ou masquer le lien du menu aux visiteurs)
drop policy if exists tdn_reglages_lecture on tdn_reglages;
create policy tdn_reglages_lecture on tdn_reglages for select using (true);
