import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { lireReglagesPn, lireStatsPn, listerCommandes } from '@/lib/pere-noel/db';
import { creditsHeygen } from '@/lib/pere-noel/ia';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN } from '@/lib/pere-noel/types';
import BasculeModulePn from '@/components/pere-noel/BasculeModulePn';
import BoutonVerifier from '@/components/pere-noel/BoutonVerifier';

export const maxDuration = 60;

const PILL: Record<string, string> = { a_faire: 'new', relecture: 'new', audio: 'on', video: 'on', terminee: 'done', erreur: 'off' };

export default async function AdminPereNoel() {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) return null;
  const [r, s, commandes, credits] = await Promise.all([lireReglagesPn(), lireStatsPn(), listerCommandes(), creditsHeygen()]);
  const pret = !!r.image_url && !!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && !!process.env.HEYGEN_API_KEY && !!process.env.ELEVENLABS_API_KEY && !!process.env.ANTHROPIC_API_KEY;
  const coutUsd = (s.secondes_video * COUT_HEYGEN_USD_PAR_SEC).toFixed(2);

  return (
    <>
      <div className="adm-h">
        <div><h1>Le Père Noël te répond</h1><p>Vidéos personnalisées du Père Noël, générées à la commande.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/pere-noel" target="_blank">↗ Page publique</Link>
          <BoutonVerifier />
        </div>
      </div>

      <BasculeModulePn actif={r.module_actif} />

      {!pret && (
        <div className="msg ko">
          Configuration incomplète :
          {!r.image_url && ' image du Père Noël manquante ·'}
          {!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && ' voix ElevenLabs manquante ·'}
          {!process.env.ANTHROPIC_API_KEY && ' ANTHROPIC_API_KEY ·'}
          {!process.env.ELEVENLABS_API_KEY && ' ELEVENLABS_API_KEY ·'}
          {!process.env.HEYGEN_API_KEY && ' HEYGEN_API_KEY ·'}
          {' '}<Link href="/admin/pere-noel/reglages">ouvrir les réglages</Link>
        </div>
      )}

      <div className="kpi">
        <div><b>{s.commandes}</b><span>Commandes payées</span></div>
        <div><b>{euros(s.ca_centimes)}</b><span>Encaissé</span></div>
        <div><b>{s.a_generer + s.a_relire}</b><span>À traiter</span></div>
        <div><b>{s.en_cours}</b><span>En génération</span></div>
        <div><b>{s.livrees}</b><span>Livrées</span></div>
        <div><b>{s.en_erreur}</b><span>En erreur</span></div>
        <div><b>{credits ?? '—'}</b><span>Crédits HeyGen restants</span></div>
        <div><b>{coutUsd} $</b><span>Coût vidéo estimé</span></div>
        <div><b>{commandes.filter((c) => c.statut === 'payee' && c.envoi_postal && !c.expedie_le).length}</b><span>Courriers à poster</span></div>
      </div>

      <div className="panel">
        <h2>État</h2>
        <p>Commandes : <span className={`pill ${r.commandes_ouvertes ? 'on' : 'off'}`}>{r.commandes_ouvertes ? 'ouvertes' : 'fermées'}</span>
          {' '}· Génération : <span className={`pill ${r.generation_auto ? 'on' : 'off'}`}>{r.generation_auto ? 'automatique au paiement' : 'manuelle (bouton Générer)'}</span>
          {' '}· Relecture du script : <span className={`pill ${r.relecture_script ? 'on' : 'off'}`}>{r.relecture_script ? 'oui' : 'non'}</span>
          {' '}· Prix : <b>{euros(r.prix_centimes)}</b></p>
        <p style={{ marginTop: '.5rem', color: '#6b6560', fontSize: '.9rem' }}>
          Les vidéos en cours chez HeyGen sont vérifiées à chaque ouverture de cette page, quand la famille ouvre son espace, et par le bouton « Vérifier ». Une génération complète prend 3 à 8 minutes.
        </p>
      </div>

      <div className="panel">
        <h2>Commandes ({commandes.length})</h2>
        {commandes.length === 0 ? <p style={{ color: '#6b6560' }}>Aucune commande pour le moment. Faites une commande de test avec le bouton en haut.</p> : (
          <div className="tbl-wrap">
            <table className="tbl">
              <thead><tr><th>Réf.</th><th>Enfant</th><th>Parent</th><th>Paiement</th><th>Génération</th><th>Date</th><th></th></tr></thead>
              <tbody>
                {commandes.map((c) => (
                  <tr key={c.id}>
                    <td><code>{c.reference}</code>{c.test && <span className="pill new" style={{ marginLeft: 6 }}>test</span>}{c.envoi_postal && <span className={`pill ${c.expedie_le ? 'done' : 'new'}`} style={{ marginLeft: 6 }} title={c.expedie_le ? 'Courrier expédié' : 'Courrier à expédier'}>📮</span>}</td>
                    <td><b>{c.enfant_prenom}</b>{c.age ? `, ${c.age} ans` : ''}</td>
                    <td>{c.parent_prenom}<br /><small style={{ color: '#6b6560' }}>{c.email}</small></td>
                    <td><span className={`pill ${c.statut === 'payee' ? 'done' : c.statut === 'en_attente' ? 'new' : 'off'}`}>{c.statut === 'payee' ? (c.test ? 'test' : euros(c.montant_centimes)) : c.statut}</span></td>
                    <td><span className={`pill ${PILL[c.gen_statut] ?? 'off'}`}>{LIBELLE_GEN[c.gen_statut]}</span>{c.gen_statut === 'erreur' && <div style={{ fontSize: '.75rem', color: '#B8322E', maxWidth: 220 }}>{c.erreur?.slice(0, 120)}</div>}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{new Date(c.created_at).toLocaleDateString('fr-FR')}</td>
                    <td><Link className="btn btn-w btn-sm" href={`/admin/pere-noel/${c.id}`}>Ouvrir</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
