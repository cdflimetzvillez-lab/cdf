'use client';
import { useActionState, useState } from 'react';
import Link from 'next/link';
import { enregistrerMission, supprimerMission, type Etat } from '@/app/tresors-actions';
import type { Bloc, Mission, QuestionType } from '@/lib/tresors/types';

const BLOC_VIDE: Record<Bloc['type'], Bloc> = {
  texte: { type: 'texte', contenu: '' },
  image: { type: 'image', src: '', alt: '' },
  audio: { type: 'audio', titre: '', duree: '' },
  video: { type: 'video', titre: '', duree: '' },
};

export default function EditeurMission({ mission: m, numeroSuivant }: { mission: Mission | null; numeroSuivant: number }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(enregistrerMission, null);
  const [type, setType] = useState<QuestionType>(m?.question_type ?? 'texte');
  const [blocs, setBlocs] = useState<Bloc[]>(m?.blocs ?? [{ type: 'texte', contenu: '' }]);

  const majBloc = (i: number, patch: Partial<Bloc>) => setBlocs((bs) => bs.map((b, j) => (j === i ? { ...b, ...patch } as Bloc : b)));
  const bouger = (i: number, d: -1 | 1) => setBlocs((bs) => { const c = [...bs]; const j = i + d; if (j < 0 || j >= c.length) return bs; [c[i], c[j]] = [c[j], c[i]]; return c; });

  return (
    <form action={action}>
      <input type="hidden" name="id" value={m?.id ?? ''} />
      <input type="hidden" name="blocs" value={JSON.stringify(blocs)} />
      <div className="adm-h">
        <div><h1>{m ? `Mission ${m.numero}` : 'Nouvelle mission'}</h1><p>{m?.titre ?? 'Créer une énigme.'}</p></div>
        <div style={{ display: 'flex', gap: '.6rem' }}>
          <Link className="btn btn-w btn-sm" href="/admin/tresors/missions">← Liste</Link>
          <button className="btn btn-k btn-sm" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer'}</button>
        </div>
      </div>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div className="panel">
        <h2>Identité</h2>
        <div className="row3">
          <div className="field"><label htmlFor="numero">Numéro (ordre)</label><input id="numero" name="numero" type="number" min={1} defaultValue={numeroSuivant} required /></div>
          <div className="field" style={{ gridColumn: 'span 2' }}><label htmlFor="titre">Titre</label><input id="titre" name="titre" defaultValue={m?.titre ?? ''} required /></div>
        </div>
        <div className="row2">
          <div className="field"><label htmlFor="lieu">Lieu</label><input id="lieu" name="lieu" defaultValue={m?.lieu ?? ''} /></div>
          <div className="field"><label htmlFor="accroche">Accroche (dashboard)</label><input id="accroche" name="accroche" defaultValue={m?.accroche ?? ''} /></div>
        </div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
          <input type="checkbox" name="publie" defaultChecked={m?.publie ?? true} style={{ width: 'auto' }} /> Publiée (visible dans le parcours)
        </label>
      </div>

      <div className="panel">
        <h2>Contenu de la mission</h2>
        {blocs.map((b, i) => (
          <div key={i} style={{ border: '2px solid #e2ddd6', padding: '1rem', marginBottom: '.8rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '.6rem' }}>
              <span className="pill">{b.type}</span>
              <span style={{ display: 'flex', gap: '.4rem' }}>
                <button type="button" className="btn btn-w btn-sm" onClick={() => bouger(i, -1)}>↑</button>
                <button type="button" className="btn btn-w btn-sm" onClick={() => bouger(i, 1)}>↓</button>
                <button type="button" className="btn btn-w btn-sm" onClick={() => setBlocs((bs) => bs.filter((_, j) => j !== i))}>✕</button>
              </span>
            </div>
            {b.type === 'texte' && <div className="field"><label>Texte</label><textarea rows={3} value={b.contenu} onChange={(e) => majBloc(i, { contenu: e.target.value })} /></div>}
            {b.type === 'image' && (
              <div className="row3">
                <div className="field"><label>URL de l&apos;image</label><input value={b.src} onChange={(e) => majBloc(i, { src: e.target.value })} placeholder="https://… (vide = illustration par défaut)" /></div>
                <div className="field"><label>Texte alternatif</label><input value={b.alt} onChange={(e) => majBloc(i, { alt: e.target.value })} /></div>
                <div className="field"><label>Légende</label><input value={b.legende ?? ''} onChange={(e) => majBloc(i, { legende: e.target.value })} /></div>
              </div>
            )}
            {(b.type === 'audio' || b.type === 'video') && (
              <div className="row2">
                <div className="field"><label>Titre</label><input value={b.titre} onChange={(e) => majBloc(i, { titre: e.target.value })} /></div>
                <div className="field"><label>Durée affichée</label><input value={b.duree} onChange={(e) => majBloc(i, { duree: e.target.value })} placeholder="0:42" /></div>
              </div>
            )}
          </div>
        ))}
        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          {(['texte', 'image', 'audio', 'video'] as const).map((t) => (
            <button key={t} type="button" className="btn btn-w btn-sm" onClick={() => setBlocs((bs) => [...bs, { ...BLOC_VIDE[t] }])}>+ {t}</button>
          ))}
        </div>
      </div>

      <div className="panel">
        <h2>Question</h2>
        <div className="row2">
          <div className="field"><label htmlFor="question_type">Type</label>
            <select id="question_type" name="question_type" value={type} onChange={(e) => setType(e.target.value as QuestionType)}>
              <option value="texte">Réponse libre (texte)</option>
              <option value="code">Code (chiffres / lettres courts)</option>
              <option value="choix">Choix multiple</option>
            </select></div>
          <div className="field"><label htmlFor="intitule">Intitulé de la question</label><input id="intitule" name="intitule" defaultValue={m?.intitule ?? ''} required /></div>
        </div>
        {type !== 'choix' && (
          <div className="row2">
            <div className="field"><label htmlFor="reponses">Réponses acceptées (une par ligne, insensible aux accents et majuscules)</label>
              <textarea id="reponses" name="reponses" rows={3} defaultValue={(m?.reponses ?? []).join('\n')} /></div>
            <div>
              {type === 'code' && <div className="field"><label htmlFor="longueur">Longueur du code</label><input id="longueur" name="longueur" type="number" min={1} max={12} defaultValue={m?.longueur ?? 4} /></div>}
              {type === 'texte' && <div className="field"><label htmlFor="placeholder">Texte d&apos;aide dans le champ</label><input id="placeholder" name="placeholder" defaultValue={m?.placeholder ?? ''} /></div>}
            </div>
          </div>
        )}
        {type === 'choix' && (
          <div className="row2">
            <div className="field"><label htmlFor="options">Options (une par ligne)</label>
              <textarea id="options" name="options" rows={4} defaultValue={(m?.options ?? []).join('\n')} /></div>
            <div className="field"><label htmlFor="bonne_reponse">Numéro de la bonne option (1 = première ligne)</label>
              <input id="bonne_reponse" name="bonne_reponse_1" type="number" min={1} defaultValue={(m?.bonne_reponse ?? 0) + 1}
                onChange={(e) => { const h = e.currentTarget.form?.elements.namedItem('bonne_reponse') as HTMLInputElement; if (h) h.value = String(Number(e.target.value) - 1); }} />
              <input type="hidden" name="bonne_reponse" defaultValue={m?.bonne_reponse ?? 0} /></div>
          </div>
        )}
      </div>

      <div className="panel">
        <h2>Indices</h2>
        <div className="row2">
          <div className="field"><label htmlFor="indices">Indices (un par ligne, révélés dans l&apos;ordre)</label>
            <textarea id="indices" name="indices" rows={4} defaultValue={(m?.indices ?? []).join('\n')} /></div>
          <div className="field"><label htmlFor="solution_secours">Solution de secours (facultatif)</label>
            <input id="solution_secours" name="solution_secours" defaultValue={m?.solution_secours ?? ''} /></div>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem' }}>
        <button className="btn btn-k" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer la mission'}</button>
        {m && (
          <button type="button" className="btn btn-w btn-sm" onClick={() => { if (confirm('Supprimer cette mission ? Les progressions associées seront perdues.')) supprimerMission(m.id); }}>
            Supprimer
          </button>
        )}
      </div>
    </form>
  );
}
