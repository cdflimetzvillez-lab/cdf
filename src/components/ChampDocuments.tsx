'use client';
import { useRef, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export type Document = {
  url: string;
  titre: string;
  legende: string;
  type: 'image' | 'pdf';
};

const TAILLE_MAX = 8 * 1024 * 1024; // 8 Mo
const TYPES_IMAGE = ['image/jpeg', 'image/png', 'image/webp', 'image/avif'];
const TYPES = [...TYPES_IMAGE, 'application/pdf'];

export default function ChampDocuments({
  documentsInitiaux = [],
}: { documentsInitiaux?: Document[] }) {
  const [docs, setDocs] = useState<Document[]>(documentsInitiaux);
  const [envoi, setEnvoi] = useState(false);
  const [erreur, setErreur] = useState('');
  const [survol, setSurvol] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  async function envoyer(fichiers: FileList) {
    setErreur('');
    setEnvoi(true);
    const supabase = createClient();
    const ajouts: Document[] = [];

    for (const fichier of Array.from(fichiers)) {
      if (!TYPES.includes(fichier.type)) {
        setErreur(`${fichier.name} : format non accepté (JPG, PNG, WebP ou PDF).`);
        continue;
      }
      if (fichier.size > TAILLE_MAX) {
        setErreur(`${fichier.name} : trop lourd (max 8 Mo).`);
        continue;
      }

      try {
        const ext = fichier.name.split('.').pop()?.toLowerCase() ?? 'jpg';
        const nom = `documents/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

        const { error } = await supabase.storage
          .from('medias')
          .upload(nom, fichier, { cacheControl: '31536000', upsert: false });
        if (error) throw error;

        const { data } = supabase.storage.from('medias').getPublicUrl(nom);
        ajouts.push({
          url: data.publicUrl,
          titre: fichier.name.replace(/\.[^.]+$/, ''),
          legende: '',
          type: fichier.type === 'application/pdf' ? 'pdf' : 'image',
        });
      } catch (e: any) {
        console.error('[documents]', e);
        setErreur(
          e?.message?.includes('row-level security')
            ? "Envoi refusé : vérifiez les droits du bucket « medias »."
            : `${fichier.name} : l'envoi a échoué.`
        );
      }
    }

    setDocs((d) => [...d, ...ajouts]);
    setEnvoi(false);
  }

  function modifier(i: number, champ: 'titre' | 'legende', valeur: string) {
    setDocs((d) => d.map((doc, j) => (j === i ? { ...doc, [champ]: valeur } : doc)));
  }

  function deplacer(i: number, sens: -1 | 1) {
    const j = i + sens;
    if (j < 0 || j >= docs.length) return;
    setDocs((d) => {
      const copie = [...d];
      [copie[i], copie[j]] = [copie[j], copie[i]];
      return copie;
    });
  }

  return (
    <div>
      {docs.map((doc, i) => (
        <div key={doc.url} className="doc-ligne">
          <input type="hidden" name="doc_url" value={doc.url} />
          <input type="hidden" name="doc_type" value={doc.type} />

          <div className="doc-vignette">
            {doc.type === 'pdf' ? (
              <span className="doc-pdf">PDF</span>
            ) : (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={doc.url} alt="" />
            )}
          </div>

          <div className="doc-champs">
            <div className="field" style={{ marginBottom: '.5rem' }}>
              <label>Titre</label>
              <input name="doc_titre" value={doc.titre}
                onChange={(e) => modifier(i, 'titre', e.target.value)}
                placeholder="Affiche de la soirée" />
            </div>
            <div className="field" style={{ marginBottom: 0 }}>
              <label>Légende (facultatif)</label>
              <input name="doc_legende" value={doc.legende}
                onChange={(e) => modifier(i, 'legende', e.target.value)}
                placeholder="Menu complet, tarifs inclus" />
            </div>
          </div>

          <div className="doc-actions">
            <button type="button" onClick={() => deplacer(i, -1)}
              disabled={i === 0} aria-label="Monter">↑</button>
            <button type="button" onClick={() => deplacer(i, 1)}
              disabled={i === docs.length - 1} aria-label="Descendre">↓</button>
            <a href={doc.url} target="_blank" rel="noreferrer" aria-label="Ouvrir">↗</a>
            <button type="button" className="doc-suppr"
              onClick={() => setDocs((d) => d.filter((_, j) => j !== i))}
              aria-label="Retirer">✕</button>
          </div>
        </div>
      ))}

      <div
        className={`img-zone${survol ? ' survol' : ''}${envoi ? ' envoi' : ''}`}
        onClick={() => !envoi && inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setSurvol(true); }}
        onDragLeave={() => setSurvol(false)}
        onDrop={(e) => {
          e.preventDefault(); setSurvol(false);
          if (e.dataTransfer.files?.length) envoyer(e.dataTransfer.files);
        }}
        role="button" tabIndex={0}
        onKeyDown={(e) => e.key === 'Enter' && inputRef.current?.click()}
      >
        {envoi ? <span>Envoi en cours…</span> : (
          <>
            <strong>Ajouter des documents</strong>
            <span>Affiche, menu, plan… JPG, PNG ou PDF · 8 Mo max · plusieurs à la fois</span>
          </>
        )}
      </div>

      <input ref={inputRef} type="file" multiple accept={TYPES.join(',')}
        style={{ display: 'none' }}
        onChange={(e) => {
          if (e.target.files?.length) envoyer(e.target.files);
          e.target.value = '';
        }} />

      {erreur && <div className="msg ko" style={{ marginTop: '.6rem' }}>{erreur}</div>}
    </div>
  );
}
