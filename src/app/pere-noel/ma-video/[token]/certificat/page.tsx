import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { Coin, Sceau } from '@/components/pere-noel/Ornement';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageCertificat({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  const annee = d.getFullYear();
  const mention = c.certificat_mention || `pour son année ${annee}, remarquée depuis le ciel pour sa gentillesse et son courage.`;
  const fem = c.genre === 'fille';

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-cadre">
          <div className="etoiles-doc" />
          <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
          <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
          <h1>Certificat d&apos;enfant sage</h1>
          <div className="filet">✦ ✦ ✦</div>
          <p style={{ textAlign: 'center', margin: 0, fontStyle: 'italic' }}>décerné à</p>
          <div className="prenom">{c.enfant_prenom}</div>
          <p className="mention">{mention}</p>
          <p style={{ textAlign: 'center', fontSize: 16, color: '#6B5E4C', margin: '0 auto', maxWidth: '46ch' }}>
            Le Père Noël atteste que {c.enfant_prenom} est inscrit{fem ? 'e' : ''} sur la grande liste des enfants sages de l&apos;année {annee}, et qu&apos;{fem ? 'elle' : 'il'} peut en être fi{fem ? 'ère' : 'er'}.
          </p>
          <div className="bas">
            <div className="date">Fait au Pôle Nord,<br />le {d.getDate()} {MOIS[d.getMonth()]} {annee}<div className="signature" style={{ textAlign: 'left', marginTop: 8 }}>Le Père Noël</div></div>
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
