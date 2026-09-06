import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import { EVENEMENT, TARIFS } from '@/lib/tresors/mock';

const REGLES = [
  { t: 'Le principe', d: `${EVENEMENT.nbMissions} missions vous attendent dans le village. À chaque lieu, une énigme à résoudre sur votre téléphone. Une bonne réponse débloque la mission suivante.` },
  { t: 'Quand jouer ?', d: `${EVENEMENT.periode}, à toute heure. Le parcours est prévu pour ${EVENEMENT.duree.toLowerCase()}, mais vous pouvez le faire en plusieurs fois : votre progression est sauvegardée.` },
  { t: 'En famille ou entre amis', d: "Chaque participant est inscrit individuellement, mais vous jouez ensemble sur un seul téléphone. Le responsable valide une mission pour tous les participants présents d'un coup." },
  { t: 'La clé virtuelle', d: "Quand un participant termine les 12 missions, une clé unique est créée dans son compte : un numéro et un code secret. Gardez-la précieusement." },
  { t: 'Le Marché de Noël', d: `${EVENEMENT.marche}. Rendez-vous à la Salle aux Trésors : saisissez votre clé sur le grand écran et découvrez votre lot. Chaque participant ayant terminé repart avec un trésor.` },
  { t: 'Les indices', d: "Bloqué ? Chaque mission propose deux indices, puis une solution de secours. Aucune pénalité : l'important est de terminer." },
  { t: 'Tarifs', d: `${TARIFS.adulte} € par adulte, ${TARIFS.enfant} € par enfant. Le montant sert à financer les lots et les animations du Comité des Fêtes.` },
  { t: 'Respect des lieux', d: "Les énigmes se résolvent par l'observation. Rien à déplacer, rien à ouvrir, rien à emporter. Restez sur la voie publique et respectez les riverains." },
];

export default function PageRegles() {
  return (
    <main className="tdn-page">
      <Entete titre="Les règles du jeu" sur="Tout savoir avant de partir" />
      <div className="tdn-regles">
        {REGLES.map((r, i) => (
          <article key={r.t} className="tdn-carte">
            <div className="tdn-sur">Règle {i + 1}</div>
            <h2>{r.t}</h2>
            <p>{r.d}</p>
          </article>
        ))}
      </div>
      <div className="tdn-cta">
        <Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Participer à l&apos;aventure</Link>
      </div>
      <NavTresors />
    </main>
  );
}
