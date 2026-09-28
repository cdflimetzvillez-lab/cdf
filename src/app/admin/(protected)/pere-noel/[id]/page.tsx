import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { commandeParId } from '@/lib/pere-noel/db';
import { verifierVideo } from '@/lib/pere-noel/pipeline';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN, LIBELLE_SAGESSE } from '@/lib/pere-noel/types';
import ActionsCommande from '@/components/pere-noel/ActionsCommande';
import FormScript from '@/components/pere-noel/FormScript';

export const maxDuration = 60;

export default async function AdminCommandePn({ params }: { params: Promise<{ id: string }> }) {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return null;
  const { id } = await params;
  let c = await commandeParId(id);
  if (!c) notFound();
  if (c.gen_statut === 'video') c = await verifierVideo(c.id);

  const ligne = (k: string, v?: string | number | null) => v ? <tr><th style={{ width: 180 }}>{k}</th><td style={{ whiteSpace: 'pre-line' }}>{v}</td></tr> : null;
  const etapes = [
    { l: 'Paiement', ok: c.statut === 'payee' },
    { l: 'Script (Claude)', ok: !!c.script },
    { l: 'Audio (ElevenLabs)', ok: !!c.audio_url },
    { l: 'Vidéo lancée (HeyGen)', ok: !!c.heygen_video_id || !!c.video_url },
    { l: 'Vidéo récupérée', ok: !!c.video_url },
    { l: 'Email envoyé', ok: c.email_envoye },
  ];
  const modifiable = ['a_faire', 'relecture', 'terminee', 'erreur'].includes(c.gen_statut) && c.statut === 'payee';

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>{c.enfant_prenom}{c.age ? `, ${c.age} ans` : ''}</h1>
          <p><code>{c.reference}</code> · {c.test ? 'commande de test' : euros(c.montant_centimes)} · {new Date(c.created_at).toLocaleString('fr-FR')}
            {' '}· <span className={`pill ${c.gen_statut === 'terminee' ? 'done' : c.gen_statut === 'erreur' ? 'off' : 'new'}`}>{LIBELLE_GEN[c.gen_statut]}</span></p>
        </div>
        <Link className="btn btn-w btn-sm" href="/admin/pere-noel">← Commandes</Link>
      </div>

      {c.erreur && c.gen_statut === 'erreur' && <div className="msg ko">Erreur : {c.erreur}</div>}
      {c.erreur && c.gen_statut !== 'erreur' && <div className="msg ko" style={{ background: '#FBEFD2' }}>Dernier incident (réessai automatique) : {c.erreur}</div>}

      <div className="panel">
        <h2>Actions</h2>
        <ActionsCommande c={c} />
      </div>

      <div className="row2">
        <div className="panel">
          <h2>Avancement</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {etapes.map((e) => <li key={e.l} style={{ padding: '.4rem 0', borderBottom: '1px solid #e2ddd6' }}><span className={`pill ${e.ok ? 'done' : 'off'}`}>{e.ok ? '✓' : '…'}</span> {e.l}</li>)}
          </ul>
          {c.heygen_video_id && <p style={{ marginTop: '.6rem', fontSize: '.8rem', color: '#6b6560' }}>HeyGen : <code>{c.heygen_video_id}</code></p>}
          {c.duree_sec && <p style={{ fontSize: '.85rem' }}>Durée : {c.duree_sec} s · coût HeyGen ≈ {(c.duree_sec * COUT_HEYGEN_USD_PAR_SEC).toFixed(2)} $</p>}
          <p style={{ marginTop: '.6rem' }}><Link href={`/pere-noel/ma-video/${c.token}`} target="_blank" className="btn btn-w btn-sm">↗ Espace famille</Link></p>
        </div>
        <div className="panel">
          <h2>Résultat</h2>
          {c.video_url ? (
            <>
              <video controls playsInline src={c.video_url} style={{ width: '100%', maxWidth: 260, borderRadius: 12, background: '#000', display: 'block' }} />
              <p style={{ marginTop: '.6rem' }}><a className="btn btn-w btn-sm" href={c.video_url} target="_blank" rel="noreferrer">Ouvrir le MP4</a></p>
            </>
          ) : c.audio_url ? (
            <><p style={{ color: '#6b6560', fontSize: '.9rem' }}>Audio prêt, vidéo en attente.</p><audio controls src={c.audio_url} style={{ width: '100%' }} /></>
          ) : <p style={{ color: '#6b6560' }}>Rien de généré pour l’instant.</p>}
        </div>
      </div>

      {c.script ? <FormScript c={c} modifiable={modifiable} /> : (
        <div className="panel"><h2>Script du Père Noël</h2><p style={{ color: '#6b6560' }}>Pas encore écrit. Cliquez sur « Générer » : Claude rédige le script à partir des réponses des parents{' '}
          (il apparaîtra ici pour relecture si l’option est activée dans les réglages).</p></div>
      )}

      <div className="panel">
        <h2>Réponses des parents</h2>
        <div className="tbl-wrap"><table className="tbl"><tbody>
          {ligne('Parent', `${c.parent_prenom} · ${c.email}`)}
          {ligne('Enfant', `${c.enfant_prenom}${c.prononciation ? ` (se prononce « ${c.prononciation} »)` : ''}${c.age ? `, ${c.age} ans` : ''}${c.genre ? `, ${c.genre}` : ''}`)}
          {ligne('Sagesse', LIBELLE_SAGESSE[c.sagesse])}
          {ligne('Lettre', c.lettre)}
          {ligne('Cadeaux demandés', c.cadeaux)}
          {ligne('Fierté', c.fierte)}
          {ligne('Doudou / passion', c.passion)}
          {ligne('Effort à encourager', c.effort)}
          {ligne('À saluer', c.salut)}
          {ligne(`Message secret (${c.ton_secret})`, c.secret)}
          {ligne('Paiement', c.statut === 'payee' ? `payée le ${c.paye_le ? new Date(c.paye_le).toLocaleString('fr-FR') : '—'}${c.transaction_code ? ` · ${c.transaction_code}` : ''}` : c.statut)}
        </tbody></table></div>
      </div>
    </>
  );
}
