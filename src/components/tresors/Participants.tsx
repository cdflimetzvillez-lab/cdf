'use client';
import { useActionState, useState, useTransition } from 'react';
import { ajouterParticipant, choisirParticipant, payerEnAttente, supprimerParticipant, type Etat } from '@/app/tresors-actions';
import { euros } from '@/lib/sumup';
import type { Categorie, Progression } from '@/lib/tresors/types';
import { numeroCle } from '@/lib/tresors/types';

type Props = { progressions: Progression[]; actifId: string | null; nbMissions: number; tarifAdulte: number; tarifEnfant: number; inscriptionsOuvertes: boolean };

export default function Participants({ progressions, actifId, nbMissions, tarifAdulte, tarifEnfant, inscriptionsOuvertes }: Props) {
  const [etat, action, pending] = useActionState<Etat, FormData>(ajouterParticipant, null);
  // Règle : au moins un adulte sur le compte pour pouvoir ajouter des enfants (revérifiée côté serveur).
  const aUnAdulte = progressions.some((p) => p.participant.categorie === 'adulte');
  const [choix, setCategorie] = useState<Categorie>(aUnAdulte ? 'enfant' : 'adulte');
  const categorie: Categorie = aUnAdulte ? choix : 'adulte';
  const [, start] = useTransition();
  const [erreurPaiement, setErreurPaiement] = useState('');
  const [erreurRetrait, setErreurRetrait] = useState('');
  const nonPayes = progressions.filter((p) => !p.participant.paye);
  const montant = nonPayes.reduce((s, p) => s + (p.participant.categorie === 'adulte' ? tarifAdulte : tarifEnfant), 0);

  return (
    <section className="tdn-carte">
      <h2>Participants</h2>
      <ul className="tdn-participants">
        {progressions.map(({ participant: p, missionsValidees, cle }) => {
          const actif = p.id === actifId;
          return (
            <li key={p.id} className={actif ? 'on' : ''}>
              <button type="button" className="tdn-part-sel" aria-pressed={actif} onClick={() => start(() => choisirParticipant(p.id))}>
                <span className="tdn-avatar">{p.prenom[0]}</span>
                <span className="tdn-part-info">
                  <b>{p.prenom}</b>
                  <small>{p.categorie === 'adulte' ? 'Adulte' : 'Enfant'} · {p.paye ? 'Inscrit' : 'En attente de paiement'}</small>
                  <span className="tdn-barre tdn-barre-mini"><i style={{ width: `${(missionsValidees.length / Math.max(nbMissions, 1)) * 100}%` }} /></span>
                  <small>{missionsValidees.length} / {nbMissions} missions{cle && ` · Clé n° ${numeroCle(cle.numero)}`}</small>
                </span>
                {actif && <span className="tdn-pastille">Actif</span>}
              </button>
              {!p.paye && (
                <button type="button" className="tdn-suppr" aria-label={`Retirer ${p.prenom}`} onClick={() => start(async () => { const r = await supprimerParticipant(p.id); setErreurRetrait(r?.erreur ?? ''); })}>✕</button>
              )}
            </li>
          );
        })}
      </ul>
      {erreurRetrait && <p className="tdn-erreur" role="alert">{erreurRetrait}</p>}

      {nonPayes.length > 0 && (
        <div className="tdn-indice" style={{ marginTop: '1rem' }}>
          <div className="tdn-sur">Paiement en attente</div>
          <p>{nonPayes.map((p) => p.participant.prenom).join(', ')} · {euros(montant)}</p>
          {erreurPaiement && <p className="tdn-erreur">{erreurPaiement}</p>}
          <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" style={{ marginTop: '.6rem' }}
            onClick={() => start(async () => { const r = await payerEnAttente(); if (r?.erreur) setErreurPaiement(r.erreur); })}>
            Payer {euros(montant)}
          </button>
        </div>
      )}

      {inscriptionsOuvertes && (
        <form action={action} style={{ marginTop: '1.2rem' }}>
          {etat?.ok && <p className="tdn-indice">{etat.ok}</p>}
          {etat?.erreur && <p className="tdn-erreur">{etat.erreur}</p>}
          <div className="tdn-ligne-part">
            <div className="tdn-champ" style={{ flex: 1 }}>
              <label htmlFor="np">Ajouter un participant</label>
              <input id="np" name="prenom" placeholder="Prénom" required />
              <input type="hidden" name="categorie" value={categorie} />
            </div>
            <div className="tdn-toggle">
              <button type="button" className={categorie === 'adulte' ? 'on' : ''} onClick={() => setCategorie('adulte')}>Adulte</button>
              <button type="button" className={categorie === 'enfant' ? 'on' : ''} disabled={!aUnAdulte}
                title={aUnAdulte ? undefined : 'Ajoutez d’abord un adulte'} onClick={() => setCategorie('enfant')}>Enfant</button>
            </div>
          </div>
          {!aUnAdulte && <p className="tdn-regle-adulte"><b>Au moins un adulte</b> doit être inscrit pour pouvoir ajouter des enfants.</p>}
          <button className="tdn-btn tdn-btn-ghost" disabled={pending}>+ Ajouter ({euros(categorie === 'adulte' ? tarifAdulte : tarifEnfant)})</button>
        </form>
      )}
    </section>
  );
}
