import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageLettre({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord · le {d.getDate()} {MOIS[d.getMonth()]} {d.getFullYear()}</div>
        <p className="lettre" style={{ marginTop: 22 }}>{c.lettre_reponse}</p>
        <div className="bas">
          <div />
          <div className="sceau">Bureau<br />du Père Noël<br />★</div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
