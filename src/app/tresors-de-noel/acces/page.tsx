import Entete from '@/components/tresors/Entete';
import FormAcces from '@/components/tresors/FormAcces';

export default async function PageAcces({ searchParams }: { searchParams: Promise<{ erreur?: string }> }) {
  const { erreur } = await searchParams;
  return (
    <main className="tdn-page">
      <Entete titre="Retrouver mon compte" sur="Accès" />
      <section className="tdn-carte">
        {erreur && <p className="tdn-erreur">Ce lien d&apos;accès n&apos;est plus valide. Demandez-en un nouveau.</p>}
        <p className="tdn-muted" style={{ marginBottom: '1rem' }}>
          Saisissez l&apos;adresse e-mail utilisée à l&apos;inscription. Vous recevrez un lien pour retrouver votre aventure sur n&apos;importe quel téléphone.
        </p>
        <FormAcces />
      </section>
    </main>
  );
}
