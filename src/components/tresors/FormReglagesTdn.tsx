'use client';
import { useActionState } from 'react';
import { majReglagesTdn, type Etat } from '@/app/tresors-actions';
import type { Reglages } from '@/lib/tresors/types';

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
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="inscriptions_ouvertes" defaultChecked={r.inscriptions_ouvertes} style={{ width: 'auto' }} /> Inscriptions ouvertes</label>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="jeu_actif" defaultChecked={r.jeu_actif} style={{ width: 'auto' }} /> Jeu actif (les réponses peuvent être validées)</label>
      </div>
      <button className="btn btn-k" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer'}</button>
    </form>
  );
}
