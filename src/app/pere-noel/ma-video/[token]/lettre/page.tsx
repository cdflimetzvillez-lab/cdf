import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { Coin, Sceau } from '@/components/pere-noel/Ornement';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageLettre({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  // La signature « Le Père Noël » est rendue à part, en écriture manuscrite.
  const corps = c.lettre_reponse!.replace(/\n*\s*Le Père Noël\s*$/i, '').trim();

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-cadre">
          <div className="etoiles-doc" />
          <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
          <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
          <div className="filet">✦</div>
          <div className="date" style={{ textAlign: 'right' }}>Pôle Nord, le {d.getDate()} {MOIS[d.getMonth()]} {d.getFullYear()}</div>
          <p className="lettre">{corps}</p>
          <div className="bas">
            <div className="signature">Le Père Noël</div>
            <Sceau />
          </div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
