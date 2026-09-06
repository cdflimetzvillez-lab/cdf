'use client';
import { useState } from 'react';
import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import { TARIFS } from '@/lib/tresors/mock';
import type { Categorie } from '@/lib/tresors/types';

type Ligne = { id: number; prenom: string; categorie: Categorie };

/** Parcours d'inscription en 3 étapes : responsable → participants → récapitulatif/paiement. */
export default function PageInscription() {
  const [etape, setEtape] = useState(1);
  const [resp, setResp] = useState({ prenom: '', nom: '', email: '', telephone: '' });
  const [lignes, setLignes] = useState<Ligne[]>([{ id: 1, prenom: '', categorie: 'adulte' }]);
  const [paye, setPaye] = useState(false);

  const total = lignes.reduce((s, l) => s + TARIFS[l.categorie], 0);
  const respOk = resp.prenom && resp.nom && resp.email.includes('@');
  const lignesOk = lignes.length > 0 && lignes.every((l) => l.prenom.trim());

  const maj = (id: number, patch: Partial<Ligne>) =>
    setLignes((ls) => ls.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  if (paye) {
    return (
      <main className="tdn-page tdn-centre">
        <div className="tdn-succes">✓</div>
        <h1 className="tdn-titre-fee">Inscription confirmée</h1>
        <p className="tdn-p">
          {lignes.length} participant{lignes.length > 1 ? 's' : ''} inscrit{lignes.length > 1 ? 's' : ''}.
          Un e-mail de confirmation a été envoyé à {resp.email}.
        </p>
        <p className="tdn-p tdn-muted">Démo : la suite utilise le compte de démonstration.</p>
        <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Commencer l&apos;aventure</Link>
      </main>
    );
  }

  return (
    <main className="tdn-page">
      <Entete titre="Inscription" sur={`Étape ${etape} sur 3`} />
      <div className="tdn-stepper" aria-hidden="true">
        {[1, 2, 3].map((n) => <span key={n} className={n <= etape ? 'on' : ''} />)}
      </div>

      {etape === 1 && (
        <section className="tdn-carte">
          <h2>Le responsable</h2>
          <p className="tdn-muted">La personne qui gère le compte et reçoit les e-mails.</p>
          <div className="tdn-champ"><label htmlFor="prenom">Prénom</label>
            <input id="prenom" autoComplete="given-name" value={resp.prenom} onChange={(e) => setResp({ ...resp, prenom: e.target.value })} /></div>
          <div className="tdn-champ"><label htmlFor="nom">Nom</label>
            <input id="nom" autoComplete="family-name" value={resp.nom} onChange={(e) => setResp({ ...resp, nom: e.target.value })} /></div>
          <div className="tdn-champ"><label htmlFor="email">E-mail</label>
            <input id="email" type="email" inputMode="email" autoComplete="email" value={resp.email} onChange={(e) => setResp({ ...resp, email: e.target.value })} /></div>
          <div className="tdn-champ"><label htmlFor="tel">Téléphone (optionnel)</label>
            <input id="tel" type="tel" inputMode="tel" autoComplete="tel" value={resp.telephone} onChange={(e) => setResp({ ...resp, telephone: e.target.value })} /></div>
          <button className="tdn-btn tdn-btn-or tdn-btn-large" disabled={!respOk} onClick={() => setEtape(2)}>Continuer</button>
        </section>
      )}

      {etape === 2 && (
        <section className="tdn-carte">
          <h2>Les participants</h2>
          <p className="tdn-muted">Chaque participant reçoit sa propre clé à la fin. Adulte {TARIFS.adulte} €, enfant {TARIFS.enfant} €.</p>
          {lignes.map((l, i) => (
            <div key={l.id} className="tdn-ligne-part">
              <div className="tdn-champ" style={{ flex: 1 }}>
                <label htmlFor={`p${l.id}`}>Participant {i + 1}</label>
                <input id={`p${l.id}`} placeholder="Prénom" value={l.prenom} onChange={(e) => maj(l.id, { prenom: e.target.value })} />
              </div>
              <div className="tdn-toggle" role="radiogroup" aria-label="Catégorie">
                <button type="button" className={l.categorie === 'adulte' ? 'on' : ''} onClick={() => maj(l.id, { categorie: 'adulte' })}>Adulte</button>
                <button type="button" className={l.categorie === 'enfant' ? 'on' : ''} onClick={() => maj(l.id, { categorie: 'enfant' })}>Enfant</button>
              </div>
              {lignes.length > 1 && (
                <button type="button" className="tdn-suppr" aria-label="Supprimer" onClick={() => setLignes((ls) => ls.filter((x) => x.id !== l.id))}>✕</button>
              )}
            </div>
          ))}
          <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setLignes((ls) => [...ls, { id: Date.now(), prenom: '', categorie: 'enfant' }])}>
            + Ajouter un participant
          </button>
          <div className="tdn-actions">
            <button className="tdn-btn tdn-btn-ghost" onClick={() => setEtape(1)}>Retour</button>
            <button className="tdn-btn tdn-btn-or" disabled={!lignesOk} onClick={() => setEtape(3)}>Continuer</button>
          </div>
        </section>
      )}

      {etape === 3 && (
        <section className="tdn-carte">
          <h2>Récapitulatif</h2>
          <p className="tdn-muted">Responsable : {resp.prenom} {resp.nom} · {resp.email}</p>
          <ul className="tdn-recap">
            {lignes.map((l) => (
              <li key={l.id}><span>{l.prenom} <small>({l.categorie})</small></span><b>{TARIFS[l.categorie]} €</b></li>
            ))}
            <li className="tdn-recap-total"><span>Total</span><b>{total} €</b></li>
          </ul>
          <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={() => setPaye(true)}>Payer {total} € (démo)</button>
          <p className="tdn-muted tdn-mini">Paiement sécurisé. Aucune somme n&apos;est prélevée dans cette maquette.</p>
          <button className="tdn-lien" onClick={() => setEtape(2)}>Modifier les participants</button>
        </section>
      )}
    </main>
  );
}
