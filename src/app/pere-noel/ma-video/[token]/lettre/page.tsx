import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { DocLettre } from '@/components/pere-noel/Documents';

export default async function PageLettre({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  return (
    <div className="pn-doc">
      <style>{'@page{size:A4 portrait;margin:12mm}'}</style>
      <DocLettre prenom={c.enfant_prenom} texte={c.lettre_reponse!} date={d} />
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
      <p className="pn-mini pn-muted pn-centre" style={{ marginTop: 10 }}>Format A4 portrait. Dans la fenêtre d&apos;impression, choisissez « Enregistrer en PDF » pour le garder.</p>
    </div>
  );
}
