import Link from 'next/link';
import ExportCles from '@/components/tresors/ExportCles';
import { CLES_ADMIN, LOTS, MISSIONS, PARTENAIRES, PARTICIPANTS_ADMIN, STATS_ADMIN } from '@/lib/tresors/mock';

/** Maquette admin des Trésors de Noël (données fictives, pas de backend). */
export default function AdminTresors() {
  const s = STATS_ADMIN;
  const pill = (statut: string) =>
    statut === 'révélé' || statut === 'terminé' ? 'done' : statut === 'en cours' ? 'new' : 'off';

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Trésors de Noël</h1>
          <p>Chasse aux trésors du Marché de Noël. Maquette avec données fictives.</p>
        </div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel" target="_blank">↗ Page du jeu</Link>
          <Link className="btn btn-y btn-sm" href="/tresors-de-noel/revelation" target="_blank">↗ Écran de révélation</Link>
          <ExportCles />
        </div>
      </div>

      <div className="kpi">
        <div><b>{s.inscrits}</b><span>Participants inscrits</span></div>
        <div><b>{s.ca.toLocaleString('fr-FR')} €</b><span>Chiffre d&apos;affaires</span></div>
        <div><b>{s.commences}</b><span>Ont commencé</span></div>
        <div><b>{s.termines}</b><span>Ont terminé</span></div>
        <div><b>{s.clesGenerees}</b><span>Clés générées</span></div>
        <div><b>{s.clesRevelees}</b><span>Clés révélées</span></div>
      </div>

      <div className="panel">
        <h2>Participants</h2>
        <table className="tbl">
          <thead><tr><th>Prénom</th><th>Nom</th><th>Catégorie</th><th>Progression</th><th>Clé</th><th>Statut</th></tr></thead>
          <tbody>
            {PARTICIPANTS_ADMIN.map((p) => (
              <tr key={p.id}>
                <td>{p.prenom}</td><td>{p.nom}</td><td>{p.categorie}</td>
                <td>{p.progression} / {MISSIONS.length}</td><td className="mono">{p.cle}</td>
                <td><span className={`pill ${pill(p.statut)}`}>{p.statut}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
        <p style={{ marginTop: '.8rem', color: '#6b6560', fontSize: '.85rem' }}>8 affichés sur {s.inscrits}.</p>
      </div>

      <div className="panel">
        <h2>Lots</h2>
        <table className="tbl">
          <thead><tr><th>Nom</th><th>Valeur</th><th>Partenaire</th><th>Stock</th><th>Attribué</th><th>Révélé</th></tr></thead>
          <tbody>
            {LOTS.map((l) => (
              <tr key={l.id}>
                <td>{l.grand && <span className="pill new" style={{ marginRight: '.5rem' }}>Grand</span>}{l.nom}</td>
                <td>{l.valeur}</td><td>{l.partenaire}</td><td>{l.stock}</td><td>{l.attribues}</td><td>{l.reveles}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="row2">
        <div className="panel">
          <h2>Missions, réponses et indices</h2>
          <table className="tbl">
            <thead><tr><th>#</th><th>Titre</th><th>Type</th><th>Réponse</th><th>Indices</th></tr></thead>
            <tbody>
              {MISSIONS.map((m) => (
                <tr key={m.numero}>
                  <td>{m.numero}</td><td>{m.titre}</td><td>{m.question.type}</td>
                  <td className="mono">{m.question.type === 'choix' ? m.question.options[m.question.bonneReponse] : m.question.reponses[0]}</td>
                  <td>{m.indices.length}{m.solutionSecours ? ' + secours' : ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div>
          <div className="panel">
            <h2>Partenaires</h2>
            <table className="tbl">
              <thead><tr><th>Nom</th><th>Type</th><th>Lots</th></tr></thead>
              <tbody>{PARTENAIRES.map((p) => <tr key={p.id}><td>{p.nom}</td><td>{p.type}</td><td>{p.lots}</td></tr>)}</tbody>
            </table>
          </div>
          <div className="panel">
            <h2>Clés</h2>
            <table className="tbl">
              <thead><tr><th>N°</th><th>Code</th><th>Participant</th><th>Lot</th><th>Révélée</th></tr></thead>
              <tbody>
                {CLES_ADMIN.map((c) => (
                  <tr key={c.numero}>
                    <td className="mono">{c.numero}</td><td className="mono">{c.code}</td><td>{c.prenom}</td><td>{c.lot}</td>
                    <td><span className={`pill ${c.revelee ? 'done' : 'off'}`}>{c.revelee ? 'oui' : 'non'}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </>
  );
}
