import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import type { Reglages } from '@/lib/tresors/types';

const ETAPES = [
  { n: 1, t: 'Je crée mon compte', d: 'Un responsable, une adresse e-mail.' },
  { n: 2, t: "J'inscris les participants", d: 'Adultes et enfants, autant que vous voulez.' },
  { n: 3, t: 'Je règle les participations', d: 'Paiement sécurisé en ligne.' },
  { n: 4, t: 'Je résous les énigmes dans le village', d: 'Les missions, ensemble ou séparément.' },
  { n: 5, t: 'Je récupère ma clé virtuelle', d: 'Une clé unique par participant.' },
];

export default function Landing({ reglages: r, connecte }: { reglages: Reglages; connecte: boolean }) {
  const RESUME = [
    { i: '🧭', t: 'Jeu autonome', d: 'Aucun bénévole nécessaire, tout se passe sur votre téléphone.' },
    { i: '🗓', t: 'Quand vous voulez', d: r.periode_texte },
    { i: '📱', t: 'Smartphone obligatoire', d: 'Un téléphone connecté par groupe suffit.' },
    { i: '⏱', t: r.duree_texte, d: 'À votre rythme, en une ou plusieurs fois.' },
    { i: '🏘', t: 'Parcours dans le village', d: 'Des lieux de Limetz-Villez à découvrir.' },
    { i: '👤', t: 'Participation individuelle', d: 'Chaque participant a sa propre clé.' },
    { i: '🎁', t: 'Lot garanti', d: 'Pour chaque participant qui termine.' },
  ];
  const ctaPrincipal = connecte
    ? <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Reprendre mon aventure</Link>
    : r.inscriptions_ouvertes
      ? <Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Participer à l&apos;aventure</Link>
      : <span className="tdn-btn tdn-btn-ghost" aria-disabled="true">Inscriptions fermées</span>;

  return (
    <main className="tdn-landing">
      <section className="tdn-hero">
        <div className="tdn-etoiles" aria-hidden="true" />
        <Neige flocons={30} />
        <div className="tdn-hero-inner">
          <div className="tdn-sur">Comité des Fêtes de Limetz-Villez</div>
          <h1 className="tdn-titre-fee">{r.titre}</h1>
          <p className="tdn-hero-accroche">Une aventure grandeur nature au cœur du village.</p>
          <p className="tdn-hero-texte">
            Résolvez les énigmes, explorez Limetz-Villez et retrouvez votre clé virtuelle.
            Chaque participant qui termine l&apos;aventure repart avec un trésor.
          </p>
          <div className="tdn-cta">
            {ctaPrincipal}
            <Link href="/tresors-de-noel/regles" className="tdn-btn tdn-btn-ghost">Découvrir les règles</Link>
          </div>
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

      <section className="tdn-section">
        <ul className="tdn-resume">
          {RESUME.map((x) => (
            <li key={x.t}><span className="tdn-resume-ico" aria-hidden="true">{x.i}</span><b>{x.t}</b><small>{x.d}</small></li>
          ))}
        </ul>
      </section>

      <section className="tdn-section">
        <h2 className="tdn-h2">Comment ça marche ?</h2>
        <ol className="tdn-etapes">
          {ETAPES.map((e) => (
            <li key={e.n}><span className="tdn-etape-n">{e.n}</span><div><b>{e.t}</b><small>{e.d}</small></div></li>
          ))}
          <li className="tdn-etape-speciale">
            <span className="tdn-etape-n">🎁</span>
            <div><b>Je révèle mon trésor au Marché de Noël</b><small>{r.marche_texte}. Saisissez votre clé sur l&apos;écran de la Salle aux Trésors.</small></div>
          </li>
        </ol>
        <div className="tdn-cta" style={{ marginTop: '2rem' }}>{ctaPrincipal}</div>
      </section>

      <footer className="tdn-pied">
        <span>Comité des Fêtes de Limetz-Villez</span>
        <Link href="/">← Retour au site</Link>
      </footer>
    </main>
  );
}
