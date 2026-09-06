import Link from 'next/link';
import { redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import SelecteurParticipant from '@/components/tresors/SelecteurParticipant';
import { contexteJoueur, lireMissions, lireReglages } from '@/lib/tresors/db';

export default async function PageAventure() {
  const ctx = await contexteJoueur();
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

  const faites = actif.missionsValidees.length;
  const termine = missions.length > 0 && missions.every((m) => actif.missionsValidees.includes(m.id));
  const mission = missions.find((m) => !actif.missionsValidees.includes(m.id));

  return (
    <main className="tdn-page">
      <Entete titre={`Bonjour ${actif.participant.prenom}`} sur="Mon aventure" />

      <section className="tdn-carte tdn-progression">
        <div className="tdn-sur">Progression</div>
        <div className="tdn-compteur"><b>{faites}</b> / {missions.length} missions</div>
        <div className="tdn-barre"><i style={{ width: `${(faites / Math.max(missions.length, 1)) * 100}%` }} /></div>
        <div className="tdn-switch">
          {ctx.progressions.length > 1 && <span className="tdn-sur">Participant actif</span>}
          <SelecteurParticipant progressions={ctx.progressions} actifId={actif.participant.id} />
        </div>
      </section>

      {!actif.participant.paye ? (
        <section className="tdn-carte tdn-mission-carte">
          <div className="tdn-sur">Paiement en attente</div>
          <p>La participation de {actif.participant.prenom} n&apos;est pas encore réglée.</p>
          <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or tdn-btn-large">Régler depuis mon compte</Link>
        </section>
      ) : !r.jeu_actif ? (
        <section className="tdn-carte tdn-mission-carte">
          <div className="tdn-sur">Patience…</div>
          <p>Le jeu ouvrira bientôt. {r.periode_texte}.</p>
        </section>
      ) : termine ? (
        <section className="tdn-carte tdn-mission-carte tdn-or">
          <div className="tdn-sur">Aventure terminée</div>
          <h2 className="tdn-titre-fee">Les {missions.length} mystères sont résolus</h2>
          <p>Votre clé virtuelle vous attend.</p>
          <Link href="/tresors-de-noel/cle" className="tdn-btn tdn-btn-nuit tdn-btn-large">Voir ma clé</Link>
        </section>
      ) : mission && (
        <section className="tdn-carte tdn-mission-carte">
          <div className="tdn-sur">Mission {mission.numero}</div>
          <h2 className="tdn-titre-fee">« {mission.titre} »</h2>
          {mission.lieu && <p className="tdn-lieu">📍 {mission.lieu}</p>}
          {mission.accroche && <p>{mission.accroche}</p>}
          <Link href={`/tresors-de-noel/mission/${mission.numero}`} className="tdn-btn tdn-btn-or tdn-btn-large">Découvrir l&apos;énigme</Link>
        </section>
      )}

      <section className="tdn-carte">
        <h2>Parcours</h2>
        <ol className="tdn-parcours">
          {missions.map((m) => {
            const ok = actif.missionsValidees.includes(m.id);
            const courante = mission?.id === m.id;
            return (
              <li key={m.id} className={ok ? 'ok' : courante ? 'now' : ''}>
                <span className="tdn-etape-n">{ok ? '✓' : m.numero}</span>
                <div><b>{m.titre}</b><small>{m.lieu}</small></div>
                {ok && <Link href={`/tresors-de-noel/mission/${m.numero}`} className="tdn-mini-lien">Revoir</Link>}
              </li>
            );
          })}
        </ol>
      </section>
      <NavTresors />
    </main>
  );
}
