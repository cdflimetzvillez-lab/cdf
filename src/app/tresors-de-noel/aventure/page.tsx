import type { ReactNode } from 'react';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import NavTresors from '@/components/tresors/NavTresors';
import SelecteurParticipant from '@/components/tresors/SelecteurParticipant';
import CarteParcours, { type EtapeCarte } from '@/components/tresors/CarteParcours';
import CentrerEtape from '@/components/tresors/CentrerEtape';
import { contexteJoueur, dateFr, jeuOuvert, lireMissions, lireReglages } from '@/lib/tresors/db';

/**
 * « Mon aventure » : la progression est une carte du village. Le chemin relie les missions,
 * le lutin avance d'étape en étape et le village s'illumine au fil des missions validées.
 * ?bravo=N (posé par l'écran de mission après une bonne réponse) joue l'animation « mission accomplie ».
 */
export default async function PageAventure({ searchParams }: { searchParams: Promise<{ bravo?: string }> }) {
  const [{ bravo }, ctx] = await Promise.all([searchParams, contexteJoueur()]);
  if (!ctx) redirect('/tresors-de-noel/acces');
  const [missions, r] = await Promise.all([lireMissions(), lireReglages()]);
  const actif = ctx.actif;

  if (!actif) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Aucun participant</h1>
        <p className="tdn-p">Ajoutez des participants depuis votre compte.</p>
        <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or">Mon compte</Link>
        <NavTresors />
      </main>
    );
  }

  const prenom = actif.participant.prenom;
  const validees = new Set(actif.missionsValidees);
  const faites = missions.filter((m) => validees.has(m.id)).length;
  const termine = missions.length > 0 && faites === missions.length;
  const jouable = actif.participant.paye && jeuOuvert(r);
  const mission = missions.find((m) => !validees.has(m.id));

  const etapes: EtapeCarte[] = missions.map((m) => ({
    numero: m.numero,
    titre: m.titre,
    etat: validees.has(m.id) ? 'faite' : jouable && m.id === mission?.id ? 'courante' : 'verrou',
  }));
  const numeroBravo = Number(bravo);

  // Fiche du bas : ce qu'il y a à faire maintenant.
  let fiche: ReactNode;
  if (!actif.participant.paye) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Paiement en attente</p>
          <h2 className="tdn-map-ftitre">La participation de {prenom} n&apos;est pas encore réglée</h2>
        </div>
        <Link href="/tresors-de-noel/compte" className="tdn-map-jouer">Régler</Link>
      </>
    );
  } else if (termine) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Aventure terminée</p>
          <h2 className="tdn-map-ftitre">Le coffre est ouvert</h2>
          <p className="tdn-map-flieu">Les {missions.length} mystères sont résolus</p>
        </div>
        <Link href="/tresors-de-noel/cle" className="tdn-map-jouer">Voir ma clé</Link>
      </>
    );
  } else if (!jouable) {
    const cloture = !!r.jeu_fin && new Date() > new Date(r.jeu_fin);
    fiche = cloture ? (
      <div>
        <p className="tdn-map-fnum">Jeu terminé</p>
        <h2 className="tdn-map-ftitre">L&apos;aventure s&apos;est achevée le {dateFr(r.jeu_fin)}</h2>
      </div>
    ) : (
      <div>
        <p className="tdn-map-fnum">Votre place est réservée</p>
        <h2 className="tdn-map-ftitre">L&apos;aventure commence le {dateFr(r.jeu_debut)}</h2>
        <p className="tdn-map-flieu">{r.periode_texte}</p>
      </div>
    );
  } else if (mission) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Mission {mission.numero}</p>
          <h2 className="tdn-map-ftitre">« {mission.titre} »</h2>
          {mission.lieu && <p className="tdn-map-flieu">📍 {mission.lieu}</p>}
        </div>
        <Link href={`/tresors-de-noel/mission/${mission.numero}`} className="tdn-map-jouer">Jouer</Link>
      </>
    );
  } else {
    fiche = (
      <div>
        <p className="tdn-map-fnum">Bientôt</p>
        <h2 className="tdn-map-ftitre">Les missions arrivent</h2>
      </div>
    );
  }

  return (
    <main className="tdn-map-page">
      <header className="tdn-map-entete">
        <div className="tdn-map-ligne">
          <h1 className="tdn-map-bonjour">Bonjour {prenom}</h1>
          <span className="tdn-map-score" aria-label={`${faites} missions validées sur ${missions.length}`}>
            <b aria-hidden="true">✦</b> {faites} / {missions.length}
          </span>
        </div>
        <SelecteurParticipant progressions={ctx.progressions} actifId={actif.participant.id} />
      </header>

      <div className="tdn-map">
        <CarteParcours etapes={etapes} faites={faites} termine={termine} jouable={jouable}
          bravo={Number.isInteger(numeroBravo) && numeroBravo > 0 ? numeroBravo : null} />
      </div>

      <div className="tdn-map-bas">
        <section className="tdn-map-fiche">{fiche}</section>
      </div>

      <CentrerEtape cle={`${actif.participant.id}-${faites}`} />
      <NavTresors />
    </main>
  );
}
