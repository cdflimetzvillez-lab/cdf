'use client';
import { useState } from 'react';
import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import { useTresors } from '@/lib/tresors/store';
import { EVENEMENT } from '@/lib/tresors/mock';
import type { Categorie } from '@/lib/tresors/types';

export default function PageCompte() {
  const { compte, progressions, participantActifId, setParticipantActif, ajouterParticipant, supprimerParticipant, reinitialiser } = useTresors();
  const [prenom, setPrenom] = useState('');
  const [categorie, setCategorie] = useState<Categorie>('enfant');

  return (
    <main className="tdn-page">
      <Entete titre="Mon compte" sur={`${compte.prenom} ${compte.nom}`} />

      <section className="tdn-carte">
        <h2>Participants</h2>
        <ul className="tdn-participants">
          {compte.participants.map((p) => {
            const prog = progressions[p.id]?.missionsValidees.length ?? 0;
            const cle = progressions[p.id]?.cle;
            const actif = p.id === participantActifId;
            return (
              <li key={p.id} className={actif ? 'on' : ''}>
                <button type="button" className="tdn-part-sel" onClick={() => setParticipantActif(p.id)} aria-pressed={actif}>
                  <span className="tdn-avatar">{p.prenom[0]}</span>
                  <span className="tdn-part-info">
                    <b>{p.prenom}</b>
                    <small>{p.categorie === 'adulte' ? 'Adulte' : 'Enfant'} · {p.inscrit ? 'Inscrit' : 'En attente de paiement'}</small>
                    <span className="tdn-barre tdn-barre-mini"><i style={{ width: `${(prog / EVENEMENT.nbMissions) * 100}%` }} /></span>
                    <small>{prog} / {EVENEMENT.nbMissions} missions{cle && ` · Clé n° ${cle.numero}`}</small>
                  </span>
                  {actif && <span className="tdn-pastille">Actif</span>}
                </button>
                {compte.participants.length > 1 && (
                  <button type="button" className="tdn-suppr" aria-label={`Retirer ${p.prenom}`} onClick={() => supprimerParticipant(p.id)}>✕</button>
                )}
              </li>
            );
          })}
        </ul>

        <div className="tdn-ligne-part" style={{ marginTop: '1rem' }}>
          <div className="tdn-champ" style={{ flex: 1 }}>
            <label htmlFor="np">Ajouter un participant</label>
            <input id="np" placeholder="Prénom" value={prenom} onChange={(e) => setPrenom(e.target.value)} />
          </div>
          <div className="tdn-toggle">
            <button type="button" className={categorie === 'adulte' ? 'on' : ''} onClick={() => setCategorie('adulte')}>Adulte</button>
            <button type="button" className={categorie === 'enfant' ? 'on' : ''} onClick={() => setCategorie('enfant')}>Enfant</button>
          </div>
        </div>
        <button className="tdn-btn tdn-btn-ghost" disabled={!prenom.trim()}
          onClick={() => { ajouterParticipant({ prenom: prenom.trim(), categorie, inscrit: false }); setPrenom(''); }}>
          + Ajouter (paiement à régler)
        </button>
      </section>

      <section className="tdn-carte">
        <h2>Responsable</h2>
        <p>{compte.prenom} {compte.nom}</p>
        <p className="tdn-muted">{compte.email} · {compte.telephone}</p>
      </section>

      <div className="tdn-cta">
        <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Aller à mon aventure</Link>
      </div>
      <p style={{ textAlign: 'center', marginTop: '2rem' }}>
        <button className="tdn-lien" onClick={reinitialiser}>Réinitialiser la démo</button>
      </p>
      <NavTresors />
    </main>
  );
}
