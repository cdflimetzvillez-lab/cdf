'use client';
import { useActionState } from 'react';
import { majReglagesTdn, type Etat } from '@/app/tresors-actions';
import type { Reglages } from '@/lib/tresors/types';

function local(iso: string | null) {
  if (!iso) return '';
  const p = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false })
    .formatToParts(new Date(iso)).reduce<Record<string, string>>((a, x) => (a[x.type] = x.value, a), {});
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}

export default function FormReglagesTdn({ r }: { r: Reglages }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(majReglagesTdn, null);
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="panel">
        <h2>Textes</h2>
        <div className="field"><label htmlFor="titre">Titre de l&apos;événement</label><input id="titre" name="titre" defaultValue={r.titre} /></div>
        <div className="field"><label htmlFor="accroche">Accroche</label><input id="accroche" name="accroche" defaultValue={r.accroche} /></div>
        <div className="row3">
          <div className="field"><label htmlFor="periode_texte">Période du jeu</label><input id="periode_texte" name="periode_texte" defaultValue={r.periode_texte} /></div>
          <div className="field"><label htmlFor="marche_texte">Marché de Noël (révélation)</label><input id="marche_texte" name="marche_texte" defaultValue={r.marche_texte} /></div>
          <div className="field"><label htmlFor="duree_texte">Durée annoncée</label><input id="duree_texte" name="duree_texte" defaultValue={r.duree_texte} /></div>
        </div>
      </div>
      <div className="panel">
        <h2>Tarifs et ouverture</h2>
        <div className="row2">
          <div className="field"><label htmlFor="tarif_adulte">Tarif adulte (€)</label><input id="tarif_adulte" name="tarif_adulte" type="number" step="0.5" min={0} defaultValue={r.tarif_adulte_centimes / 100} /></div>
          <div className="field"><label htmlFor="tarif_enfant">Tarif enfant (€)</label><input id="tarif_enfant" name="tarif_enfant" type="number" step="0.5" min={0} defaultValue={r.tarif_enfant_centimes / 100} /></div>
        </div>
        <div className="field"><label htmlFor="places_max">Nombre de places (participants payés maximum)</label><input id="places_max" name="places_max" type="number" min={0} defaultValue={r.places_max} /></div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="inscriptions_ouvertes" defaultChecked={r.inscriptions_ouvertes} style={{ width: 'auto' }} /> Réservations ouvertes</label>
      </div>
      <div className="panel">
        <h2>Période du jeu</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="jeu_actif" defaultChecked={r.jeu_actif} style={{ width: 'auto' }} /> Jeu activé (interrupteur général)</label>
        <div className="row2">
          <div className="field"><label htmlFor="jeu_debut">Début du jeu (heure de Paris)</label><input id="jeu_debut" name="jeu_debut" type="datetime-local" defaultValue={local(r.jeu_debut)} /></div>
          <div className="field"><label htmlFor="jeu_fin">Fin du jeu</label><input id="jeu_fin" name="jeu_fin" type="datetime-local" defaultValue={local(r.jeu_fin)} /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Avant le début : la page du jeu affiche la réservation des places. Pendant : le jeu. Après la fin : plus aucune mission ne peut être validée.</p>
      </div>
      <div className="panel">
        <h2>Grand trésor et révélation</h2>
        <div className="row2">
          <div className="field"><label htmlFor="grand_tresor_montant">Montant affiché</label><input id="grand_tresor_montant" name="grand_tresor_montant" defaultValue={r.grand_tresor_montant} /></div>
          <div className="field"><label htmlFor="grand_tresor_texte">Description</label><input id="grand_tresor_texte" name="grand_tresor_texte" defaultValue={r.grand_tresor_texte} /></div>
        </div>
        <div className="field"><label htmlFor="lieu_revelation">Lieu de la révélation (règlement)</label><input id="lieu_revelation" name="lieu_revelation" defaultValue={r.lieu_revelation} /></div>
      </div>
      <button className="btn btn-k" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer'}</button>
    </form>
  );
}
