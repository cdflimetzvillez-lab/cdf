import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';

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
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
        <h1>Certificat d&apos;enfant sage</h1>
        <p style={{ textAlign: 'center', margin: 0 }}>décerné à</p>
        <div className="prenom">{c.enfant_prenom}</div>
        <p style={{ textAlign: 'center' }}>{mention}</p>
        <p style={{ textAlign: 'center', fontSize: 15, color: '#6B5E4C' }}>Le Père Noël atteste que {c.enfant_prenom} est inscrit{fem ? 'e' : ''} sur la liste des enfants sages de l&apos;année {annee}.</p>
        <div className="bas">
          <div style={{ fontSize: 14, color: '#6B5E4C' }}>Fait au Pôle Nord,<br />le {d.getDate()} {MOIS[d.getMonth()]} {annee}</div>
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
