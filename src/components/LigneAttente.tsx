'use client';
import { useState, useTransition } from 'react';
import Confirmation from '@/components/Confirmation';
import { changerStatutAttente, supprimerAttente } from '@/app/actions';
import type { ListeAttente } from '@/lib/types';

export default function LigneAttente({ ligne, rang }: { ligne: ListeAttente; rang: number }) {
  const [pending, start] = useTransition();
  const [confirme, setConfirme] = useState(false);
  const l = ligne;
  const termine = l.statut === 'converti' || l.statut === 'annule';

  return (
    <tr style={{ opacity: pending ? .5 : termine ? .55 : 1 }}>
      <td style={{ fontFamily: 'DM Mono, monospace', fontSize: '.8rem' }}>{rang}</td>
      <td>
        <strong>{l.nom}</strong><br />
        <a href={`mailto:${l.email}`} style={{ color: '#6b6560', fontSize: '.82rem' }}>{l.email}</a>
        {l.telephone && <><br /><a href={`tel:${l.telephone}`} style={{ color: '#6b6560', fontSize: '.82rem' }}>{l.telephone}</a></>}
      </td>
      <td><strong>{l.places}</strong></td>
      <td style={{ maxWidth: 280, fontSize: '.85rem' }}>{l.message}</td>
      <td style={{ whiteSpace: 'nowrap', fontSize: '.85rem' }}>
        {new Date(l.created_at).toLocaleDateString('fr-FR')}{' '}
        {new Date(l.created_at).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
      </td>
      <td>
        <select
          defaultValue={l.statut}
          onChange={(e) => start(() => { changerStatutAttente(l.id, e.target.value); })}
          style={{ padding: '.35rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
        >
          <option value="en_attente">En attente</option>
          <option value="contacte">Contacté</option>
          <option value="converti">A réservé</option>
          <option value="annule">Ne souhaite plus</option>
        </select>
      </td>
      <td style={{ textAlign: 'right' }}>
        <button className="btn btn-w btn-sm" onClick={() => setConfirme(true)}>Suppr.</button>
        <Confirmation
          ouvert={confirme}
          danger
          titre="Retirer de la liste d'attente ?"
          message={`${l.nom} sera définitivement retiré de la liste.`}
          libelleConfirmer="Retirer"
          onAnnuler={() => setConfirme(false)}
          onConfirmer={() => { setConfirme(false); start(() => { supprimerAttente(l.id); }); }}
        />
      </td>
    </tr>
  );
}
