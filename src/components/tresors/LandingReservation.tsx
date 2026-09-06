import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import Traineau from './Traineau';
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

      <section className="tdn-section tdn-tresor" id="tresor">
        <div className="tdn-coffre-scene tdn-coffre-fixe" aria-hidden="true">
          <div className="tdn-lumiere-or tdn-lumiere-locale" />
          <div className="tdn-coffre ouvert"><i className="tdn-coffre-couvercle" /><i className="tdn-coffre-corps" /><i className="tdn-coffre-lueur" /></div>
        </div>
        <h2 className="tdn-h2">Le grand trésor</h2>
        <div className="tdn-montant">{r.grand_tresor_montant}</div>
        <p className="tdn-quoi">{r.grand_tresor_texte}</p>
        <p className="tdn-comment">Il se cache dans l&apos;une des clés remises lors de la révélation. Toutes les clés ouvrent un trésor : l&apos;une d&apos;elles ouvre celui-là.</p>
        <p className="tdn-autres">…et de nombreux autres lots, un pour chaque participant qui termine l&apos;aventure.</p>
      </section>

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
            Un compte pour toute la famille, une clé et un trésor par participant. Les participations financent les lots et l&apos;organisation du Comité des Fêtes.
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
