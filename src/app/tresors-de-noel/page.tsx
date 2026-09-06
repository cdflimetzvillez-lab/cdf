import Accueil from '@/components/tresors/Accueil';
import { compteCourant, jeuOuvert, lireReglages, placesPrises } from '@/lib/tresors/db';

export default async function PageTresors() {
  const [reglages, compte] = await Promise.all([lireReglages(), compteCourant()]);
  const ouvert = jeuOuvert(reglages);
  const prises = ouvert ? 0 : await placesPrises();
  return <Accueil reglages={reglages} connecte={!!compte} phase={ouvert ? 'jeu' : 'reservation'} placesRestantes={Math.max(reglages.places_max - prises, 0)} />;
}
