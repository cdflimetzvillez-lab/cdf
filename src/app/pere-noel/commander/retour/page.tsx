import Link from 'next/link';
import { synchroniserCommandePn } from '@/app/pere-noel-actions';
import { euros } from '@/lib/sumup';

export const maxDuration = 60;

export default async function PageRetour({ searchParams }: { searchParams: Promise<{ ref?: string }> }) {
  const { ref } = await searchParams;
  const cmd = ref ? await synchroniserCommandePn(ref) : null;

  if (!cmd) {
    return <main className="pn-page pn-centre"><h1 className="pn-titre">Commande introuvable</h1><Link href="/pere-noel" className="pn-btn ghost">Retour</Link></main>;
  }
  if (cmd.statut === 'payee') {
    return (
      <main className="pn-page pn-centre">
        <div className="pn-ok">✓</div>
        <h1 className="pn-titre">La lettre de {cmd.enfant_prenom} est partie pour le Pôle Nord</h1>
        <p className="pn-l clair">Le Père Noël enregistre sa réponse. Vous recevrez un email dès que la vidéo est prête.</p>
        <div className="pn-cardn" style={{ textAlign: 'left' }}><b>Votre espace personnel</b><small>Vidéo, téléchargement, lettre écrite et certificat vous y attendent. Le lien vous a aussi été envoyé par email.</small></div>
        <Link href={`/pere-noel/ma-video/${cmd.token}`} className="pn-btn or">Ouvrir mon espace</Link>
        <p className="pn-mini pn-muted" style={{ marginTop: 14 }}>{cmd.test ? 'Commande de test' : euros(cmd.montant_centimes)} · réf. {cmd.reference}</p>
        <div className="pn-avis" style={{ textAlign: 'left' }}><b>Un conseil :</b> ne montrez pas la vidéo à {cmd.enfant_prenom} tout de suite. Le soir, dans le noir, sur la télé, l&apos;effet est décuplé.</div>
      </main>
    );
  }
  if (cmd.statut === 'en_attente') {
    return (
      <main className="pn-page pn-centre">
        <h1 className="pn-titre">Paiement en cours de vérification</h1>
        <p className="pn-l clair">Cela peut prendre quelques secondes.</p>
        <Link href={`/pere-noel/commander/retour?ref=${cmd.reference}`} className="pn-btn or">Actualiser</Link>
      </main>
    );
  }
  return (
    <main className="pn-page pn-centre">
      <h1 className="pn-titre">Paiement non abouti</h1>
      <p className="pn-l clair">Le paiement a échoué ou a expiré. Rien n&apos;a été débité, vous pouvez recommencer.</p>
      <Link href="/pere-noel/commander" className="pn-btn or">Recommencer</Link>
    </main>
  );
}
