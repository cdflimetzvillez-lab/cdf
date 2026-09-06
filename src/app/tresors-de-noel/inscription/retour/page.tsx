import Link from 'next/link';
import { synchroniserCommande } from '@/app/tresors-actions';
import { euros } from '@/lib/sumup';

export default async function PageRetour({ searchParams }: { searchParams: Promise<{ ref?: string }> }) {
  const { ref } = await searchParams;
  const cmd = ref ? await synchroniserCommande(ref) : null;

  if (!cmd) {
    return <main className="tdn-page tdn-centre"><h1 className="tdn-titre-fee">Commande introuvable</h1><Link href="/tresors-de-noel" className="tdn-btn tdn-btn-ghost">Retour</Link></main>;
  }
  if (cmd.statut === 'payee') {
    return (
      <main className="tdn-page tdn-centre">
        <div className="tdn-succes">✓</div>
        <h1 className="tdn-titre-fee">Inscription confirmée</h1>
        <p className="tdn-p">{cmd.participant_ids.length} participant{cmd.participant_ids.length > 1 ? 's' : ''} inscrit{cmd.participant_ids.length > 1 ? 's' : ''} · {euros(cmd.montant_centimes)} · réf. {cmd.reference}</p>
        <p className="tdn-p tdn-muted tdn-mini">Votre accès est enregistré sur ce téléphone. Pour le retrouver ailleurs, demandez un lien d&apos;accès par e-mail depuis la page « Retrouver mon compte ».</p>
        <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Commencer l&apos;aventure</Link>
      </main>
    );
  }
  if (cmd.statut === 'en_attente') {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Paiement en cours de vérification</h1>
        <p className="tdn-p">Cela peut prendre quelques secondes.</p>
        <Link href={`/tresors-de-noel/inscription/retour?ref=${cmd.reference}`} className="tdn-btn tdn-btn-or">Actualiser</Link>
      </main>
    );
  }
  return (
    <main className="tdn-page tdn-centre">
      <h1 className="tdn-titre-fee">Paiement non abouti</h1>
      <p className="tdn-p">Le paiement a échoué ou a expiré. Vos participants sont conservés : vous pouvez relancer le paiement depuis votre compte.</p>
      <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or">Aller à mon compte</Link>
    </main>
  );
}
