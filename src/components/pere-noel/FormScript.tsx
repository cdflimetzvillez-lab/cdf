'use client';
import { useActionState } from 'react';
import { validerScript, type Etat } from '@/app/pere-noel-actions';
import type { CommandePn } from '@/lib/pere-noel/types';

export default function FormScript({ c, modifiable }: { c: CommandePn; modifiable: boolean }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(validerScript, null);
  const mots = (c.script ?? '').split(/\s+/).filter(Boolean).length;
  return (
    <form action={action} className="panel">
      <h2>Script du Père Noël <small style={{ fontWeight: 'normal', color: '#6b6560' }}>· {mots} mots ≈ {Math.round(mots / 140 * 60)} s</small></h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <input type="hidden" name="id" value={c.id} />
      <div className="field"><label htmlFor="script">Ce que dit le Père Noël (lu par la voix)</label>
        <textarea id="script" name="script" rows={12} defaultValue={c.script ?? ''} readOnly={!modifiable} /></div>
      <div className="field"><label htmlFor="lettre_reponse">Lettre écrite (imprimable)</label>
        <textarea id="lettre_reponse" name="lettre_reponse" rows={8} defaultValue={c.lettre_reponse ?? ''} readOnly={!modifiable} /></div>
      <div className="field"><label htmlFor="certificat_mention">Mention du certificat</label>
        <input id="certificat_mention" name="certificat_mention" defaultValue={c.certificat_mention ?? ''} readOnly={!modifiable} /></div>
      {modifiable && (
        <button className="btn btn-y btn-sm" type="submit" disabled={pending}>
          {pending ? 'Audio et vidéo en cours de lancement…' : c.gen_statut === 'relecture' ? '✓ Valider et lancer audio + vidéo' : 'Enregistrer et relancer audio + vidéo'}
        </button>
      )}
      {!modifiable && <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Le script est figé pendant la génération. Utilisez « Réécrire le script » ou « Refaire la vidéo » pour repartir.</p>}
    </form>
  );
}
