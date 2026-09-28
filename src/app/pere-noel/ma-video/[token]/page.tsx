import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import { rafraichirDepuisEspace } from '@/app/pere-noel-actions';

export const maxDuration = 60;

export default async function PageMaVideo({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  let c = await commandeParToken(token);
  if (!c) notFound();
  if (c.gen_statut === 'video') { await rafraichirDepuisEspace(c.id); c = (await commandeParToken(token))!; }

  const prete = c.gen_statut === 'terminee' && c.video_url;
  const nomFichier = `Pere-Noel-${c.enfant_prenom.replace(/[^a-zA-Z0-9À-ÿ]/g, '')}.mp4`;
  const urlTelechargement = !c.video_url ? '#'
    : c.video_url.includes('vercel-storage.com') ? `${c.video_url}?download=1`
    : `${c.video_url}${c.video_url.includes('?') ? '&' : '?'}download=${encodeURIComponent(nomFichier)}`;
  const docsPrets = !!c.lettre_reponse;

  return (
    <main className="pn-page">
      <h1 className="pn-titre">La réponse du Père Noël à {c.enfant_prenom}</h1>

      {c.statut !== 'payee' && (
        <div className="pn-cardn"><b>Paiement non confirmé</b><small>Cette commande n&apos;a pas encore été réglée. Si vous venez de payer, patientez quelques instants puis actualisez.</small></div>
      )}

      {prete ? (
        <>
          <div className="pn-video"><video controls playsInline preload="metadata" src={c.video_url!} /></div>
          <a className="pn-btn or" href={urlTelechargement} download={nomFichier}>Télécharger la vidéo (MP4)</a>
          <p className="pn-mini pn-muted pn-centre" style={{ marginTop: 8 }}>Pensez à la télécharger et à la sauvegarder : elle reste disponible ici jusqu&apos;au 31 janvier.</p>
        </>
      ) : c.statut === 'payee' && (
        <div className="pn-cardn">
          <b>Le Père Noël prépare sa réponse…</b>
          <small>Vous recevrez un email dès que la vidéo est prête. Vous pouvez aussi revenir sur cette page plus tard.</small>
          <ul className="pn-etapes" style={{ marginTop: 10 }}>
            <li className="ok"><span>✓</span><div>Lettre reçue au Pôle Nord</div></li>
            <li className={c.script ? 'ok' : 'now'}><span>{c.script ? '✓' : '…'}</span><div>Le Père Noël lit la lettre et prépare sa réponse</div></li>
            <li className={c.audio_url ? 'ok' : c.script ? 'now' : ''}><span>{c.audio_url ? '✓' : '…'}</span><div>Il enregistre sa voix</div></li>
            <li className={c.gen_statut === 'video' ? 'now' : ''}><span>…</span><div>Les lutins montent la vidéo</div></li>
          </ul>
        </div>
      )}

      <div className="pn-carte" style={{ marginTop: 18 }}>
        <h2>À imprimer</h2>
        <p className="pn-l">{docsPrets ? 'La lettre écrite du Père Noël et le certificat d\u2019enfant sage sont prêts.' : 'La lettre écrite et le certificat seront disponibles dès que le Père Noël aura préparé sa réponse.'}</p>
        <div className="pn-row">
          <Link className={`pn-btn sec${docsPrets ? '' : ' disabled'}`} aria-disabled={!docsPrets} href={docsPrets ? `/pere-noel/ma-video/${c.token}/lettre` : '#'}>La lettre</Link>
          <Link className={`pn-btn sec${docsPrets ? '' : ' disabled'}`} aria-disabled={!docsPrets} href={docsPrets ? `/pere-noel/ma-video/${c.token}/certificat` : '#'}>Le certificat</Link>
        </div>
      </div>

      <div className="pn-cardn"><b>Quelque chose ne va pas ?</b><small>Prénom mal prononcé, détail inexact : répondez à l&apos;email de confirmation en indiquant la référence {c.reference}, nous refaisons la vidéo.</small></div>
      <div className="pn-avis"><b>Un conseil :</b> ne montrez pas la vidéo tout de suite. Le soir, dans le noir, sur la télé du salon, l&apos;effet est décuplé.</div>
    </main>
  );
}
