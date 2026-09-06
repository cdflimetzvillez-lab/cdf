import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import { lireMissions, lireReglages } from '@/lib/tresors/db';
import { euros } from '@/lib/sumup';

export default async function PageRegles() {
  const [r, missions] = await Promise.all([lireReglages(), lireMissions()]);
  const n = missions.length;
  const REGLES = [
    { t: 'Le principe', d: `${n} missions vous attendent dans le village. À chaque lieu, une énigme à résoudre sur votre téléphone. Une bonne réponse débloque la mission suivante.` },
    { t: 'Quand jouer ?', d: `${r.periode_texte}, à toute heure. Le parcours est prévu pour ${r.duree_texte.toLowerCase()}, mais vous pouvez le faire en plusieurs fois : votre progression est sauvegardée.` },
    { t: 'En famille ou entre amis', d: "Chaque participant est inscrit individuellement, mais vous jouez ensemble sur un seul téléphone. Le responsable valide une mission pour tous les participants présents d'un coup." },
    { t: 'La clé virtuelle', d: `Quand un participant termine les ${n} missions, une clé unique est créée dans son compte : un numéro et un code secret. Gardez-la précieusement.` },
    { t: 'Le Marché de Noël', d: `${r.marche_texte}. Rendez-vous à la Salle aux Trésors : saisissez votre clé sur le grand écran et découvrez votre lot. Chaque participant ayant terminé repart avec un trésor.` },
    { t: 'Les indices', d: "Bloqué ? Chaque mission propose des indices, puis une solution de secours. Aucune pénalité : l'important est de terminer." },
    { t: 'Tarifs', d: `${euros(r.tarif_adulte_centimes)} par adulte, ${euros(r.tarif_enfant_centimes)} par enfant. Le montant sert à financer les lots et les animations du Comité des Fêtes.` },
    { t: 'Respect des lieux', d: "Les énigmes se résolvent par l'observation. Rien à déplacer, rien à ouvrir, rien à emporter. Restez sur la voie publique et respectez les riverains." },
  ];
  return (
    <main className="tdn-page">
      <Entete titre="Les règles du jeu" sur="Tout savoir avant de partir" />
      <div className="tdn-regles">
        {REGLES.map((x, i) => (
          <article key={x.t} className="tdn-carte"><div className="tdn-sur">Règle {i + 1}</div><h2>{x.t}</h2><p>{x.d}</p></article>
        ))}
      </div>
      {r.inscriptions_ouvertes && (
        <div className="tdn-cta"><Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Participer à l&apos;aventure</Link></div>
      )}
      <NavTresors />
    </main>
  );
}
