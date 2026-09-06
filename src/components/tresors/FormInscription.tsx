'use client';
import { useActionState, useState } from 'react';
import { inscrire, type Etat } from '@/app/tresors-actions';
import { euros } from '@/lib/sumup';
import type { Categorie } from '@/lib/tresors/types';

type Ligne = { id: number; prenom: string; categorie: Categorie };

/** Inscription en 3 écrans dans un seul formulaire : responsable → participants → récapitulatif/paiement. */
export default function FormInscription({ tarifAdulte, tarifEnfant }: { tarifAdulte: number; tarifEnfant: number }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(inscrire, null);
  const [etape, setEtape] = useState(1);
  const [resp, setResp] = useState({ prenom: '', nom: '', email: '', telephone: '' });
  const [lignes, setLignes] = useState<Ligne[]>([{ id: 1, prenom: '', categorie: 'adulte' }]);
  const tarif = (c: Categorie) => (c === 'adulte' ? tarifAdulte : tarifEnfant);
  const total = lignes.reduce((s, l) => s + tarif(l.categorie), 0);
  const respOk = resp.prenom && resp.nom && resp.email.includes('@');
  const lignesOk = lignes.length > 0 && lignes.every((l) => l.prenom.trim());
  const maj = (id: number, patch: Partial<Ligne>) => setLignes((ls) => ls.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  return (
    <form action={action}>
      <div className="tdn-stepper" aria-hidden="true">{[1, 2, 3].map((n) => <span key={n} className={n <= etape ? 'on' : ''} />)}</div>
      {etat?.erreur && <p className="tdn-erreur" role="alert">{etat.erreur}</p>}

      <section className="tdn-carte" hidden={etape !== 1}>
        <h2>Le responsable</h2>
        <p className="tdn-muted">La personne qui gère le compte et reçoit les e-mails.</p>
        <div className="tdn-champ"><label htmlFor="prenom">Prénom</label>
          <input id="prenom" name="prenom" autoComplete="given-name" value={resp.prenom} onChange={(e) => setResp({ ...resp, prenom: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="nom">Nom</label>
          <input id="nom" name="nom" autoComplete="family-name" value={resp.nom} onChange={(e) => setResp({ ...resp, nom: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="email">E-mail</label>
          <input id="email" name="email" type="email" inputMode="email" autoComplete="email" value={resp.email} onChange={(e) => setResp({ ...resp, email: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="tel">Téléphone (optionnel)</label>
          <input id="tel" name="telephone" type="tel" inputMode="tel" autoComplete="tel" value={resp.telephone} onChange={(e) => setResp({ ...resp, telephone: e.target.value })} /></div>
        <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" disabled={!respOk} onClick={() => setEtape(2)}>Continuer</button>
      </section>

      <section className="tdn-carte" hidden={etape !== 2}>
        <h2>Les participants</h2>
        <p className="tdn-muted">Chaque participant reçoit sa propre clé à la fin. Adulte {euros(tarifAdulte)}, enfant {euros(tarifEnfant)}.</p>
        {lignes.map((l, i) => (
          <div key={l.id} className="tdn-ligne-part">
            <div className="tdn-champ" style={{ flex: 1 }}>
              <label htmlFor={`p${l.id}`}>Participant {i + 1}</label>
              <input id={`p${l.id}`} name="participant_prenom" placeholder="Prénom" value={l.prenom} onChange={(e) => maj(l.id, { prenom: e.target.value })} />
              <input type="hidden" name="participant_categorie" value={l.categorie} />
            </div>
            <div className="tdn-toggle" role="radiogroup" aria-label="Catégorie">
              <button type="button" className={l.categorie === 'adulte' ? 'on' : ''} onClick={() => maj(l.id, { categorie: 'adulte' })}>Adulte</button>
              <button type="button" className={l.categorie === 'enfant' ? 'on' : ''} onClick={() => maj(l.id, { categorie: 'enfant' })}>Enfant</button>
            </div>
            {lignes.length > 1 && <button type="button" className="tdn-suppr" aria-label="Supprimer" onClick={() => setLignes((ls) => ls.filter((x) => x.id !== l.id))}>✕</button>}
          </div>
        ))}
        <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setLignes((ls) => [...ls, { id: Date.now(), prenom: '', categorie: 'enfant' }])}>+ Ajouter un participant</button>
        <div className="tdn-actions">
          <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setEtape(1)}>Retour</button>
          <button type="button" className="tdn-btn tdn-btn-or" disabled={!lignesOk} onClick={() => setEtape(3)}>Continuer</button>
        </div>
      </section>

      <section className="tdn-carte" hidden={etape !== 3}>
        <h2>Récapitulatif</h2>
        <p className="tdn-muted">Responsable : {resp.prenom} {resp.nom} · {resp.email}</p>
        <ul className="tdn-recap">
          {lignes.map((l) => <li key={l.id}><span>{l.prenom} <small>({l.categorie})</small></span><b>{euros(tarif(l.categorie))}</b></li>)}
          <li className="tdn-recap-total"><span>Total</span><b>{euros(total)}</b></li>
        </ul>
        <button type="submit" className="tdn-btn tdn-btn-or tdn-btn-large" disabled={pending}>
          {pending ? 'Redirection vers le paiement…' : `Payer ${euros(total)}`}
        </button>
        <p className="tdn-muted tdn-mini">Paiement sécurisé par SumUp. Vous serez redirigé vers la page de paiement.</p>
        <button type="button" className="tdn-lien" onClick={() => setEtape(2)}>Modifier les participants</button>
      </section>
    </form>
  );
}
