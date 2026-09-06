'use client';
import { useActionState } from 'react';
import { majModuleRoue, type EtatRoue } from '@/app/roue-actions';
import type { ConfigRoue, ModuleAccueil } from '@/lib/roue/types';

/** ISO → valeur datetime-local en heure de Paris. */
function local(iso: string | null) {
  if (!iso) return '';
  const p = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false })
    .formatToParts(new Date(iso)).reduce<Record<string, string>>((a, x) => (a[x.type] = x.value, a), {});
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}

export default function FormModuleRoue({ module: m, config: c }: { module: ModuleAccueil; config: ConfigRoue }) {
  const [etat, action, pending] = useActionState<EtatRoue, FormData>(majModuleRoue, null);
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="panel">
        <h2>Affichage</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
          <input type="checkbox" name="is_active" defaultChecked={m.is_active} style={{ width: 'auto' }} /> Roue activée (prioritaire sur les dates)
        </label>
        <div className="row2">
          <div className="field"><label htmlFor="start_date">Date de début (heure de Paris)</label><input id="start_date" name="start_date" type="datetime-local" defaultValue={local(m.start_date)} /></div>
          <div className="field"><label htmlFor="end_date">Date de fin (heure de Paris)</label><input id="end_date" name="end_date" type="datetime-local" defaultValue={local(m.end_date)} /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>La roue apparaît sur l&apos;accueil si elle est activée ET si la date du jour est dans la période. Laissez une date vide pour ne pas la borner.</p>
      </div>
      <div className="panel">
        <h2>Textes</h2>
        <div className="row2">
          <div className="field"><label htmlFor="titre">Titre</label><input id="titre" name="titre" defaultValue={c.titre} /></div>
          <div className="field"><label htmlFor="periode_texte">Période affichée</label><input id="periode_texte" name="periode_texte" defaultValue={c.periode_texte} /></div>
        </div>
        <div className="field"><label htmlFor="accroche">Accroche</label><input id="accroche" name="accroche" defaultValue={c.accroche} /></div>
        <div className="field"><label htmlFor="message_gagne">Message aux gagnants</label><textarea id="message_gagne" name="message_gagne" rows={2} defaultValue={c.message_gagne} /></div>
        <div className="field"><label htmlFor="message_perdu">Message aux perdants</label><textarea id="message_perdu" name="message_perdu" rows={2} defaultValue={c.message_perdu} /></div>
      </div>
      <div className="panel">
        <h2>Règles du jeu</h2>
        <div className="row2">
          <div className="field"><label htmlFor="participations_par_jour">Participations par jour et par personne</label><input id="participations_par_jour" name="participations_par_jour" type="number" min={1} max={10} defaultValue={c.participations_par_jour} /></div>
          <div className="field"><label htmlFor="taux_gain">Taux de tours gagnants (%)</label><input id="taux_gain" name="taux_gain" type="number" min={0} max={100} defaultValue={c.taux_gain} /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Un tour gagnant n&apos;attribue un lot que s&apos;il en reste en stock : sinon il devient perdant.</p>
      </div>
      <button className="btn btn-k" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer'}</button>
    </form>
  );
}
