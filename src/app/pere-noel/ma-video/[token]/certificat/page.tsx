import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { DocCertificat } from '@/components/pere-noel/Documents';

export default async function PageCertificat({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  const mention = c.certificat_mention || `pour son année ${d.getFullYear()}, remarquée depuis le ciel pour sa gentillesse et son courage.`;
  return (
    <div className="pn-doc">
      <style>{'@page{size:A4 landscape;margin:10mm}'}</style>
      <DocCertificat prenom={c.enfant_prenom} mention={mention} genre={c.genre} date={d} />
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
      <p className="pn-mini pn-muted pn-centre" style={{ marginTop: 10 }}>Format A4 paysage. Dans la fenêtre d&apos;impression, choisissez « Enregistrer en PDF » pour le garder.</p>
    </div>
  );
}
