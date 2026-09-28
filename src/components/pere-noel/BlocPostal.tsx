'use client';
import Link from 'next/link';
import { useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { marquerExpedie } from '@/app/pere-noel-actions';
import type { CommandePn } from '@/lib/pere-noel/types';

export default function BlocPostal({ c }: { c: CommandePn }) {
  const [pending, start] = useTransition();
  const router = useRouter();
  const docsPrets = !!c.lettre_reponse;
  return (
    <div className="panel" style={{ borderLeft: `10px solid ${c.expedie_le ? '#9BD44F' : '#FFD400'}` }}>
      <h2>📮 Impression et envoi postal {c.expedie_le ? <span className="pill done">expédié le {new Date(c.expedie_le).toLocaleDateString('fr-FR')}</span> : <span className="pill new">à préparer</span>}</h2>
      <div className="row2">
        <div>
          <p style={{ fontFamily: 'monospace', whiteSpace: 'pre-line', background: '#fff', border: '1px solid #e2ddd6', padding: '.8rem', lineHeight: 1.5 }}>
            {[c.adresse_nom, c.adresse_ligne1, c.adresse_ligne2, `${c.adresse_cp ?? ''} ${c.adresse_ville ?? ''}`.trim()].filter(Boolean).join('\n')}
          </p>
          <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.5rem' }}>Lettre en A4 portrait, certificat en A4 paysage. Imprimez depuis les liens, puis marquez comme expédié.</p>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '.6rem', alignItems: 'flex-start' }}>
          <Link className={`btn btn-w btn-sm${docsPrets ? '' : ' disabled'}`} href={docsPrets ? `/pere-noel/ma-video/${c.token}/lettre` : '#'} target="_blank">🖨 Imprimer la lettre</Link>
          <Link className={`btn btn-w btn-sm${docsPrets ? '' : ' disabled'}`} href={docsPrets ? `/pere-noel/ma-video/${c.token}/certificat` : '#'} target="_blank">🖨 Imprimer le certificat</Link>
          {c.expedie_le
            ? <button className="btn btn-w btn-sm" disabled={pending} onClick={() => start(async () => { await marquerExpedie(c.id, false); router.refresh(); })}>Annuler « expédié »</button>
            : <button className="btn btn-y btn-sm" disabled={pending || !docsPrets} onClick={() => start(async () => { await marquerExpedie(c.id, true); router.refresh(); })}>✓ Marquer comme expédié</button>}
          {!docsPrets && <span style={{ fontSize: '.8rem', color: '#6b6560' }}>Les documents apparaissent une fois le script généré.</span>}
        </div>
      </div>
    </div>
  );
}
