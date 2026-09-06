import Accueil from '@/components/tresors/Accueil';
import { compteCourant, lireReglages } from '@/lib/tresors/db';

export default async function PageTresors() {
  const [reglages, compte] = await Promise.all([lireReglages(), compteCourant()]);
  return <Accueil reglages={reglages} connecte={!!compte} />;
}
