'use client';
import { useActionState } from 'react';
import { majReglagesPn, type Etat } from '@/app/pere-noel-actions';
import ChampImage from '@/components/ChampImage';
import type { ReglagesPn } from '@/lib/pere-noel/types';

type Cles = { anthropic: boolean; elevenlabs: boolean; heygen: boolean; voixEnv: string };

export default function FormReglagesPn({ r, cles }: { r: ReglagesPn; cles: Cles }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(majReglagesPn, null);
  const ok = (b: boolean) => <span className={`pill ${b ? 'done' : 'off'}`}>{b ? 'présente' : 'absente'}</span>;
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div className="panel">
        <h2>Clés API (variables d’environnement Vercel)</h2>
        <p style={{ fontSize: '.9rem' }}>ANTHROPIC_API_KEY {ok(cles.anthropic)} · ELEVENLABS_API_KEY {ok(cles.elevenlabs)} · HEYGEN_API_KEY {ok(cles.heygen)}</p>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.4rem' }}>Les clés ne se saisissent pas ici : ajoutez-les dans Vercel puis redéployez.</p>
      </div>

      <div className="panel">
        <h2>Textes et prix</h2>
        <div className="field"><label htmlFor="titre">Titre</label><input id="titre" name="titre" defaultValue={r.titre} /></div>
        <div className="field"><label htmlFor="accroche">Accroche (page d’accueil)</label><input id="accroche" name="accroche" defaultValue={r.accroche} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="prix">Prix (€)</label><input id="prix" name="prix" type="number" step="0.1" min={0} defaultValue={r.prix_centimes / 100} /></div>
          <div className="field"><label htmlFor="delai_texte">Délai annoncé</label><input id="delai_texte" name="delai_texte" defaultValue={r.delai_texte} /></div>
        </div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="commandes_ouvertes" defaultChecked={r.commandes_ouvertes} style={{ width: 'auto' }} /> Commandes ouvertes au public</label>
      </div>

      <div className="panel">
        <h2>Génération</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="generation_auto" defaultChecked={r.generation_auto} style={{ width: 'auto' }} /> Lancer la génération automatiquement dès le paiement</label>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="relecture_script" defaultChecked={r.relecture_script} style={{ width: 'auto' }} /> Relire et valider le script avant l’audio et la vidéo (conseillé au début)</label>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Génération manuelle = rien ne part chez HeyGen tant que vous n’avez pas cliqué « Générer » sur la commande. Utile tant que le compte HeyGen n’a pas de crédits.</p>
        <div className="field"><label htmlFor="duree_cible_sec">Durée cible de la vidéo (secondes, 30 à 120)</label><input id="duree_cible_sec" name="duree_cible_sec" type="number" min={30} max={120} defaultValue={r.duree_cible_sec} /></div>
        <div className="field"><label htmlFor="consignes_script">Consignes supplémentaires pour l’écriture du script (facultatif)</label>
          <textarea id="consignes_script" name="consignes_script" rows={3} defaultValue={r.consignes_script} placeholder="Ex. : mentionner que le Père Noël passera aussi par le village le 20 décembre." /></div>
      </div>

      <div className="panel">
        <h2>Le Père Noël (image)</h2>
        <ChampImage name="image_url" label="Portrait du Père Noël, format vertical 9:16, bouche bien visible" valeurInitiale={r.image_url} dossier="pere-noel" aide="C’est cette image qui est animée par HeyGen pour chaque vidéo." />
        <div className="field"><label htmlFor="video_demo_url">Vidéo de démonstration (URL du MP4, affichée sur la page d’accueil)</label>
          <input id="video_demo_url" name="video_demo_url" defaultValue={r.video_demo_url ?? ''} placeholder="https://…vercel-storage.com/pere-noel/demo.mp4" />
          <p style={{ color: '#6b6560', fontSize: '.8rem', marginTop: '.3rem' }}>Déposez le MP4 dans Vercel → Storage → cdf-blob → Manage Blobs → Upload, puis collez ici l’URL du fichier. L’image ci-dessus sert d’affiche avant lecture.</p></div>
        <div className="field"><label htmlFor="expressivite">Expressivité HeyGen</label>
          <select id="expressivite" name="expressivite" defaultValue={r.expressivite}><option value="low">Faible (sobre)</option><option value="medium">Moyenne (conseillé)</option><option value="high">Forte (rires, gestes, risque d’artefacts)</option></select></div>
        <div className="field"><label htmlFor="motion_prompt">Consigne de mouvement (HeyGen)</label><textarea id="motion_prompt" name="motion_prompt" rows={2} defaultValue={r.motion_prompt} /></div>
      </div>

      <div className="panel">
        <h2>La voix (ElevenLabs)</h2>
        <div className="field"><label htmlFor="voice_id">Voice ID</label><input id="voice_id" name="voice_id" defaultValue={r.voice_id ?? ''} placeholder={cles.voixEnv ? `Par défaut : ${cles.voixEnv} (variable ELEVENLABS_VOICE_ID)` : 'Ex. : MDLAMJ0jxkpYkjXbmG4t'} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="modele_voix">Modèle</label>
            <select id="modele_voix" name="modele_voix" defaultValue={r.modele_voix}><option value="eleven_multilingual_v2">Multilingual v2 (stable)</option><option value="eleven_v3">Eleven v3 (plus expressif)</option><option value="eleven_turbo_v2_5">Turbo v2.5 (rapide, moins cher)</option></select></div>
          <div className="field"><label htmlFor="vitesse">Vitesse (0,7 à 1,2)</label><input id="vitesse" name="vitesse" type="number" step="0.01" min={0.7} max={1.2} defaultValue={r.vitesse} /></div>
        </div>
        <div className="row3">
          <div className="field"><label htmlFor="stabilite">Stabilité (0 à 1)</label><input id="stabilite" name="stabilite" type="number" step="0.05" min={0} max={1} defaultValue={r.stabilite} /></div>
          <div className="field"><label htmlFor="similarite">Similarité (0 à 1)</label><input id="similarite" name="similarite" type="number" step="0.05" min={0} max={1} defaultValue={r.similarite} /></div>
          <div className="field"><label htmlFor="style_voix">Style (0 à 1)</label><input id="style_voix" name="style_voix" type="number" step="0.05" min={0} max={1} defaultValue={r.style_voix} /></div>
        </div>
      </div>

      <button className="btn btn-y" type="submit" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer les réglages'}</button>
    </form>
  );
}
