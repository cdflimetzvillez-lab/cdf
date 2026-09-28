'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { genererCommande, marquerPayee, refaireVideo, regenererScript, renvoyerEmailVideo, supprimerCommande, verifierCommande } from '@/app/pere-noel-actions';
import type { CommandePn } from '@/lib/pere-noel/types';

export default function ActionsCommande({ c }: { c: CommandePn }) {
  const [pending, start] = useTransition();
  const [confirm, setConfirm] = useState(false);
  const router = useRouter();
  const run = (fn: () => Promise<unknown>) => start(async () => { await fn(); router.refresh(); });
  const payee = c.statut === 'payee';

  return (
    <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', opacity: pending ? .6 : 1 }}>
      {!payee && <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => marquerPayee(c.id))}>Marquer comme payée</button>}
      {payee && (c.gen_statut === 'a_faire' || c.gen_statut === 'erreur') && (
        <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => genererCommande(c.id))}>{c.gen_statut === 'erreur' ? '↻ Reprendre la génération' : '▶ Générer'}</button>
      )}
      {payee && c.gen_statut === 'video' && <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => verifierCommande(c.id))}>↻ Vérifier chez HeyGen</button>}
      {payee && c.script && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => regenererScript(c.id))}>Réécrire le script</button>}
      {payee && c.audio_url && c.gen_statut !== 'audio' && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => refaireVideo(c.id))}>Refaire la vidéo (même script)</button>}
      {payee && c.video_url && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => renvoyerEmailVideo(c.id))}>Renvoyer l’email</button>}
      {!confirm
        ? <button className="btn btn-w btn-sm" disabled={pending} onClick={() => setConfirm(true)}>Supprimer</button>
        : <button className="btn btn-danger btn-sm" disabled={pending} onClick={() => start(() => supprimerCommande(c.id))}>Confirmer la suppression</button>}
      {pending && <span style={{ fontSize: '.85rem', color: '#6b6560', alignSelf: 'center' }}>En cours, cela peut prendre jusqu’à une minute…</span>}
    </div>
  );
}
