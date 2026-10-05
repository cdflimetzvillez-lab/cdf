import Hotte from './Hotte';
import { enLettres, montantGrandTresor, nombreGrandTresor, type Reglages } from '@/lib/tresors/types';

/** Visuel de la carte cadeau mise en jeu, dessinée dans la hotte. Mettre '' pour revenir aux paquets cadeaux. */
const VISUEL_CARTE = '/tresors/carte-cadeau.webp';

/**
 * Bloc « Le grand trésor » : hotte, description, montant (« 3 × 100 € ») et principe du tirage
 * (les cartes sont mêlées aux autres lots à la révélation, une seule carte par compte).
 * Commun aux deux pages d'accueil du jeu : réservation (avant l'ouverture) et jeu ouvert.
 */
export default function GrandTresor({ reglages: r }: { reglages: Reglages }) {
  // Une ou plusieurs cartes identiques, tirées au sort à la révélation avec les autres lots.
  const nombre = nombreGrandTresor(r);
  const montant = montantGrandTresor(r);
  return (
    <section className="tdn-section tdn-tresor" id="tresor">
      <Hotte className="tdn-hotte" etiquette={montant} cartes={nombre} visuelCarte={VISUEL_CARTE} />
      <h2 className="tdn-h2">Le grand trésor</h2>
      <p className="tdn-quoi">{r.grand_tresor_texte}</p>
      <div className={`tdn-montant${nombre > 1 ? ' tdn-montant-multi' : ''}`}>{montant}</div>
      {nombre > 1 ? (
        <p className="tdn-comment">Les {enLettres(nombre)} cartes sont glissées parmi les lots de la révélation. Chaque clé ouvre un trésor tiré au sort : ce sera peut-être l&apos;une d&apos;elles. Une seule carte par compte.</p>
      ) : (
        <p className="tdn-comment">Il est glissé parmi les lots de la révélation. Chaque clé ouvre un trésor tiré au sort : ce sera peut-être celui-là.</p>
      )}
      <p className="tdn-autres">…et de nombreux autres lots, un pour chaque participant qui termine l&apos;aventure.</p>
    </section>
  );
}
