#!/usr/bin/env bash
# Trésors de Noël : le bloc « Le grand trésor » (3 × 100 €) s'affiche aussi sur la page d'accueil quand le jeu est ouvert.
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/GrandTresor.tsx' <<'EOF_PN_FICHIER'
import Hotte from './Hotte';
import { enLettres, montantGrandTresor, nombreGrandTresor, type Reglages } from '@/lib/tresors/types';

/**
 * Bloc « Le grand trésor » : hotte, description, montant (« 3 × 100 € ») et principe du tirage.
 * Commun aux deux pages d'accueil du jeu : réservation (avant l'ouverture) et jeu ouvert.
 */
export default function GrandTresor({ reglages: r }: { reglages: Reglages }) {
  // Un ou plusieurs lots identiques, une clé gagnante par lot.
  const nombre = nombreGrandTresor(r);
  const montant = montantGrandTresor(r);
  return (
    <section className="tdn-section tdn-tresor" id="tresor">
      <Hotte className="tdn-hotte" etiquette={montant} />
      <h2 className="tdn-h2">Le grand trésor</h2>
      <p className="tdn-quoi">{r.grand_tresor_texte}</p>
      <div className={`tdn-montant${nombre > 1 ? ' tdn-montant-multi' : ''}`}>{montant}</div>
      {nombre > 1 ? (
        <p className="tdn-comment">Il se cache dans {enLettres(nombre)} des clés remises lors de la révélation. Toutes les clés ouvrent un trésor : {enLettres(nombre)} d&apos;entre elles, tirées au sort, ouvrent celui-là.</p>
      ) : (
        <p className="tdn-comment">Il se cache dans l&apos;une des clés remises lors de la révélation. Toutes les clés ouvrent un trésor : l&apos;une d&apos;elles ouvre celui-là.</p>
      )}
      <p className="tdn-autres">…et de nombreux autres lots, un pour chaque participant qui termine l&apos;aventure.</p>
    </section>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/GrandTresor.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Landing.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import GrandTresor from './GrandTresor';
import type { Reglages } from '@/lib/tresors/types';

const ETAPES = [
  { n: 1, t: 'Je crée mon compte', d: 'Un responsable, une adresse e-mail.' },
  { n: 2, t: "J'inscris les participants", d: 'Adultes et enfants. Au moins un adulte inscrit pour inscrire des enfants.' },
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
          <p className="tdn-mini" style={{ marginTop: '1rem' }}><a href="#tresor" className="tdn-lien">Découvrir le grand trésor ↓</a></p>
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

      <GrandTresor reglages={r} />

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
        <Link href="/tresors-de-noel/reglement">Règlement</Link>
        <Link href="/">← Retour au site</Link>
      </footer>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Landing.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/LandingReservation.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import Traineau from './Traineau';
import GrandTresor from './GrandTresor';
import { euros } from '@/lib/sumup';
import type { Reglages } from '@/lib/tresors/types';

const dateLongue = (iso: string | null) => iso ? new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }).format(new Date(iso)) : '';

/** Page d'attente avant l'ouverture du jeu : réservation payante, places limitées, grand trésor. */
export default function LandingReservation({ reglages: r, connecte, placesRestantes }: { reglages: Reglages; connecte: boolean; placesRestantes: number }) {
  const complet = placesRestantes <= 0;
  const pct = r.places_max > 0 ? Math.round((placesRestantes / r.places_max) * 100) : 0;
  const debut = dateLongue(r.jeu_debut);

  const cta = connecte
    ? <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or">Voir mon compte</Link>
    : complet || !r.inscriptions_ouvertes
      ? <span className="tdn-btn tdn-btn-ghost" aria-disabled="true">{complet ? 'Complet' : 'Réservations fermées'}</span>
      : <Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Réserver mes places</Link>;

  return (
    <main className="tdn-landing tdn-resa">
      <section className="tdn-hero">
        <div className="tdn-etoiles" aria-hidden="true" />
        <Neige flocons={40} />
        <div className="tdn-halo" aria-hidden="true" />
        <Traineau className="tdn-traineau tdn-traineau-boucle" />
        <div className="tdn-hero-inner">
          <div className="tdn-sur">Comité des Fêtes de Limetz-Villez présente</div>
          <h1 className="tdn-titre-fee">{r.titre}</h1>
          <p className="tdn-hero-accroche">Les cadeaux du Père Noël ont disparu. Le village a besoin de vous.</p>
          <p className="tdn-hero-texte">
            Une chasse aux trésors grandeur nature dans les rues de Limetz-Villez : des énigmes à résoudre en famille,
            une clé virtuelle à retrouver, et un trésor garanti pour chaque participant qui termine l&apos;aventure.
          </p>
          <div className="tdn-bientot"><b>!</b> {debut ? `Le jeu commence le ${debut}` : 'Ouverture prochaine'} · places limitées</div>
          <div className="tdn-cta">
            {cta}
            <a href="#tresor" className="tdn-btn tdn-btn-ghost">Découvrir le grand trésor</a>
          </div>
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

      <GrandTresor reglages={r} />

      <section className="tdn-section">
        <div className="tdn-raisons">
          <div className="tdn-raison tdn-raison-or">
            <span className="tdn-resume-ico" aria-hidden="true">⏳</span>
            <h3>Les places sont comptées</h3>
            <p>Pour que chaque famille profite du village sans embouteillage aux énigmes, le nombre de participants est limité à {r.places_max}. Une fois complet, c&apos;est complet.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🗝</span>
            <h3>Un trésor par participant</h3>
            <p>Vous jouez ensemble, sur un seul téléphone. Mais chaque participant, adulte ou enfant, termine avec sa propre clé et son propre trésor.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🏘</span>
            <h3>Quand vous voulez</h3>
            <p>{r.periode_texte}. {r.duree_texte} de balade dans le village, à faire en une ou plusieurs fois.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🎄</span>
            <h3>La révélation</h3>
            <p>{r.marche_texte}. Saisissez votre clé sur le grand écran de la Salle aux Trésors et découvrez votre cadeau.</p>
          </div>
        </div>
      </section>

      <section className="tdn-section" id="reservation">
        <div className="tdn-carte tdn-carte-resa">
          <span className="tdn-sceau" aria-hidden="true">✦</span>
          <h2 className="tdn-titre-fee">Réservez vos places</h2>
          <p className="tdn-muted tdn-centre-txt">Inscription en ligne, paiement sécurisé. Votre accès au jeu est créé tout de suite{debut ? `, l'aventure s'ouvre le ${debut}` : ''}.</p>
          <div className="tdn-tarifs">
            <div><span>Adulte</span><b>{euros(r.tarif_adulte_centimes)}</b></div>
            <div><span>Enfant</span><b>{euros(r.tarif_enfant_centimes)}</b></div>
          </div>
          <p className="tdn-jauge-txt">{complet ? <b>Complet</b> : <><b>Il reste {placesRestantes} place{placesRestantes > 1 ? 's' : ''}</b> sur {r.places_max}</>}</p>
          <div className="tdn-barre" aria-hidden="true"><i style={{ width: `${pct}%` }} /></div>
          <div className="tdn-cta" style={{ marginTop: '1.4rem' }}>{cta}</div>
          <p className="tdn-muted tdn-mini tdn-centre-txt" style={{ marginTop: '1rem' }}>
            Un compte pour toute la famille, une clé et un trésor par participant. Au moins un adulte doit être inscrit pour pouvoir inscrire des enfants. Les participations financent les lots et l&apos;organisation du Comité des Fêtes.
            {' '}<Link href="/tresors-de-noel/reglement" className="tdn-lien">Règlement du jeu</Link>
          </p>
        </div>
      </section>

      <footer className="tdn-pied">
        <span>Comité des Fêtes de Limetz-Villez</span>
        <Link href="/tresors-de-noel/reglement">Règlement</Link>
        <Link href="/">← Retour au site</Link>
      </footer>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/LandingReservation.tsx"

git add -A && git commit -m "Trésors de Noël : grand trésor affiché aussi quand le jeu est ouvert" && git push
vercel --prod
