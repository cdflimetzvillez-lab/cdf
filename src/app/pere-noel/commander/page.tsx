import Link from 'next/link';
import FormCommande from '@/components/pere-noel/FormCommande';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';

export default async function PageCommander({ searchParams }: { searchParams: Promise<{ test?: string }> }) {
  const [r, { isAdmin }, sp] = await Promise.all([lireReglagesPn(), requireAdmin(), searchParams]);
  const test = sp.test === '1' && isAdmin;
  if (!r.commandes_ouvertes && !test) {
    return (
      <main className="pn-page pn-centre">
        <h1 className="pn-titre">Les commandes ne sont pas ouvertes</h1>
        <p className="pn-l clair">Revenez bientôt, le Père Noël prépare son atelier.</p>
        <Link href="/pere-noel" className="pn-btn ghost">Retour</Link>
      </main>
    );
  }
  return (
    <main className="pn-page">
      <FormCommande prix={r.prix_centimes} test={test} postal={{ actif: r.envoi_postal_actif, prix: r.prix_postal_centimes }} />
    </main>
  );
}
