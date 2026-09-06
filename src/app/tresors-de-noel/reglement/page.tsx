import Link from 'next/link';
import type { Metadata } from 'next';
import Entete from '@/components/tresors/Entete';
import { createClient } from '@/lib/supabase/server';
import { dateFr, lireLots, lireMissions, lireReglages } from '@/lib/tresors/db';
import { euros } from '@/lib/sumup';
import type { SiteSettings } from '@/lib/types';

export const metadata: Metadata = { title: 'Règlement · Les Trésors de Noël de Limetz-Villez' };

export default async function PageReglementTdn() {
  const supabase = await createClient();
  const [{ data: settings }, r, lots, missions] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(), lireReglages(), lireLots(), lireMissions(),
  ]);
  const s = settings as SiteSettings;
  const site = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://cdf-limetzvillez.fr';
  const grand = lots.find((l) => l.grand);
  const nbMissions = missions.length || 12;

  return (
    <main className="tdn-page tdn-reglement" style={{ maxWidth: '44rem' }}>
      <Entete titre="Règlement du jeu" sur={r.titre} />
      <p className="tdn-muted" style={{ marginBottom: '2rem' }}>Version en vigueur au {dateFr(new Date().toISOString())}. Ce règlement est accessible pendant toute la durée de l&apos;opération à l&apos;adresse {site}/tresors-de-noel/reglement.</p>

      <h2>Article 1 · Organisateur</h2>
      <p>Le jeu « {r.titre} » (ci-après « le Jeu ») est organisé par le Comité des Fêtes de Limetz-Villez, association régie par la loi du 1er juillet 1901, dont le siège est situé {s.adresse}, joignable à l&apos;adresse {s.email_contact} (ci-après « l&apos;Organisateur »).</p>

      <h2>Article 2 · Nature et durée du Jeu</h2>
      <p>Le Jeu est une chasse aux trésors se déroulant sur la voie publique de la commune de Limetz-Villez, à l&apos;aide d&apos;une application web accessible depuis un smartphone à l&apos;adresse {site}/tresors-de-noel.</p>
      <p>Le Jeu se déroule du {dateFr(r.jeu_debut, true)} au {dateFr(r.jeu_fin, true)} (heure de Paris). La révélation des lots a lieu lors du {r.marche_texte}, à {r.lieu_revelation}.</p>
      <p>Les inscriptions sont ouvertes avant le début du Jeu et peuvent se poursuivre pendant celui-ci, dans la limite des places disponibles. L&apos;Organisateur se réserve le droit d&apos;écourter, de prolonger, de suspendre ou d&apos;annuler le Jeu, notamment en cas de force majeure, d&apos;intempéries rendant le parcours dangereux ou de dysfonctionnement technique majeur. Dans ce cas, les participants seront informés par e-mail et les participations remboursées si le Jeu ne peut avoir lieu.</p>

      <h2>Article 3 · Conditions de participation</h2>
      <p>Le Jeu est ouvert à toute personne physique. Les mineurs participent sous la responsabilité et avec l&apos;accord d&apos;un représentant légal, qui crée le compte et effectue l&apos;inscription. Les mineurs de moins de 12 ans doivent être accompagnés d&apos;un adulte pendant tout le parcours.</p>
      <p>La participation est <b>individuelle et payante</b> : chaque participant, adulte ou enfant, doit être inscrit nommément. Le tarif est de {euros(r.tarif_adulte_centimes)} par adulte et {euros(r.tarif_enfant_centimes)} par enfant (moins de 18 ans). Un même compte, géré par un responsable majeur, peut regrouper plusieurs participants d&apos;une même famille ou d&apos;un même groupe.</p>
      <p>Le nombre de participants est limité à <b>{r.places_max}</b>. Les inscriptions sont enregistrées dans l&apos;ordre des paiements validés ; une fois ce nombre atteint, les inscriptions sont closes. Les membres du bureau de l&apos;Organisateur et les personnes ayant participé à la conception des énigmes ne peuvent pas participer.</p>

      <h2>Article 4 · Inscription et paiement</h2>
      <p>L&apos;inscription s&apos;effectue en ligne. Le responsable renseigne ses coordonnées (prénom, nom, adresse e-mail, téléphone facultatif), inscrit les participants (prénom, catégorie adulte ou enfant) et règle le montant total par carte bancaire via le prestataire de paiement SumUp. L&apos;Organisateur n&apos;a jamais accès aux données bancaires.</p>
      <p>L&apos;inscription est définitive à réception du paiement. Un e-mail de confirmation est envoyé au responsable. Conformément à l&apos;article L221-28 du Code de la consommation, les prestations de loisirs fournies à une date déterminée ne sont pas soumises au droit de rétractation : <b>aucun remboursement</b> n&apos;est effectué en cas de désistement, de non-participation ou d&apos;abandon en cours de Jeu, sauf annulation du Jeu par l&apos;Organisateur.</p>
      <p>Les sommes perçues financent les lots et l&apos;organisation de l&apos;événement.</p>

      <h2>Article 5 · Déroulement du Jeu</h2>
      <p>Le Jeu comporte {nbMissions} missions correspondant à des lieux du village. Pour chaque mission, le participant se rend sur place, observe le lieu et répond à une question sur l&apos;application. Une bonne réponse valide la mission et débloque la suivante. Les missions se font dans l&apos;ordre.</p>
      <p>Les participants d&apos;un même compte peuvent jouer ensemble sur un seul smartphone : le responsable valide chaque mission pour les participants présents. Chaque participant conserve néanmoins sa progression et sa clé individuelles.</p>
      <p>Des indices, puis une solution de secours, sont proposés pour chaque mission. Leur utilisation n&apos;entraîne aucune pénalité. Le Jeu peut être réalisé en une ou plusieurs fois, à toute heure, pendant la durée du Jeu ; la progression est sauvegardée sur le compte.</p>
      <p>Lorsqu&apos;un participant a validé l&apos;ensemble des missions, une <b>clé virtuelle</b> individuelle (numéro et code secret) est générée sur son compte. Cette clé est strictement personnelle. Aucune clé n&apos;est générée après la clôture du Jeu.</p>

      <h2>Article 6 · Dotations</h2>
      <p><b>Chaque participant ayant obtenu sa clé virtuelle reçoit un lot</b>, dans les conditions de l&apos;article 7. Les lots sont attribués par tirage au sort informatique au moment de la révélation, parmi les lots disponibles, à l&apos;exception du grand trésor.</p>
      <p>Le <b>grand trésor</b> est constitué de {grand?.nom ?? `${r.grand_tresor_montant} ${r.grand_tresor_texte}`}. Il est attribué par tirage au sort, effectué sous le contrôle de l&apos;Organisateur, parmi l&apos;ensemble des clés virtuelles générées avant la clôture du Jeu, et révélé lors de la cérémonie de révélation.</p>
      <p>Les autres lots sont notamment : {lots.filter((l) => !l.grand).map((l) => l.nom).join(', ') || 'places de cinéma, repas, paniers gourmands, bons d’achat, chocolats et cadeaux de Noël'}, dans la limite des stocks disponibles. L&apos;Organisateur se réserve la possibilité de remplacer un lot par un lot de valeur équivalente ou supérieure.</p>
      <p>Les lots ne peuvent être échangés contre leur valeur en espèces ni contre un autre lot. Ils sont nominatifs et non cessibles. Un participant ne peut recevoir qu&apos;un seul lot par clé.</p>

      <h2>Article 7 · Révélation et remise des lots</h2>
      <p>La révélation a lieu lors du {r.marche_texte}, à {r.lieu_revelation}. Le participant, ou son responsable, saisit son numéro de clé et son code secret sur l&apos;écran de la Salle aux Trésors ; le lot lui est alors attribué et affiché. Il le retire immédiatement auprès des bénévoles, sur présentation de l&apos;écran et, sur demande, d&apos;une pièce d&apos;identité du responsable.</p>
      <p>Une clé ne peut être révélée qu&apos;une seule fois. Les participants absents à la révélation peuvent retirer leur lot auprès de l&apos;Organisateur, sur rendez-vous, dans un délai de <b>30 jours</b> suivant la révélation, en présentant leur clé. Passé ce délai, le lot reste acquis à l&apos;Organisateur. Les frais éventuels de déplacement ou d&apos;envoi restent à la charge du gagnant.</p>

      <h2>Article 8 · Comportement et sécurité</h2>
      <p>Le Jeu se déroule sur la voie publique, sans encadrement. Chaque participant, ou le représentant légal d&apos;un mineur, est responsable de sa propre sécurité : respect du Code de la route, prudence aux abords des routes, de la Seine et des cours d&apos;eau, équipement adapté à la météo et à la nuit tombante.</p>
      <p>Les énigmes se résolvent par simple observation. Il est interdit de pénétrer dans une propriété privée, de déplacer, dégrader ou emporter quoi que ce soit, de gêner les riverains ou la circulation. Tout comportement contraire entraîne l&apos;exclusion immédiate, sans remboursement, et engage la responsabilité de son auteur.</p>
      <p>L&apos;Organisateur décline toute responsabilité en cas d&apos;accident, de perte, de vol ou de dommage survenant pendant le parcours. Les participants sont invités à vérifier qu&apos;ils bénéficient d&apos;une assurance responsabilité civile.</p>

      <h2>Article 9 · Fraude</h2>
      <p>Sont notamment interdits : le partage des réponses ou des clés avec des personnes non inscrites, la validation de missions pour des participants absents, l&apos;utilisation de plusieurs comptes, toute tentative d&apos;accès non autorisé à l&apos;application ou de contournement de ses mécanismes. L&apos;Organisateur peut annuler la clé et la participation de tout contrevenant, sans remboursement, et se réserve le droit d&apos;engager des poursuites.</p>
      <p>Les réponses sont vérifiées par le serveur de l&apos;application. Les décisions de l&apos;Organisateur concernant la validité d&apos;une participation, d&apos;une clé ou d&apos;une attribution de lot sont sans appel.</p>

      <h2>Article 10 · Données personnelles</h2>
      <p>Les données collectées (coordonnées du responsable, prénoms et catégories des participants, progression, clés, informations de paiement transmises au prestataire SumUp) sont nécessaires à la gestion des inscriptions, du Jeu et de la remise des lots. Elles sont traitées par l&apos;Organisateur, responsable de traitement, sur la base de l&apos;exécution du contrat d&apos;inscription, et hébergées chez des prestataires établis dans l&apos;Union européenne ou offrant des garanties équivalentes.</p>
      <p>Elles sont conservées jusqu&apos;à trois mois après la révélation, puis supprimées, à l&apos;exception des données comptables conservées pendant la durée légale. Un cookie technique, sans finalité publicitaire, permet de retrouver le compte sur le téléphone utilisé. Conformément au Règlement (UE) 2016/679, vous disposez d&apos;un droit d&apos;accès, de rectification, d&apos;effacement, de limitation et d&apos;opposition, à exercer auprès de {s.email_contact}. Vous pouvez introduire une réclamation auprès de la CNIL.</p>

      <h2>Article 11 · Droit à l&apos;image</h2>
      <p>Des photographies et vidéos peuvent être réalisées lors de la révélation. En participant à cette cérémonie, les participants et leurs représentants légaux autorisent l&apos;Organisateur à les utiliser, sans contrepartie, sur ses supports de communication (site, réseaux sociaux, bulletin municipal) pendant deux ans. Toute personne peut s&apos;y opposer en le signalant sur place ou par e-mail.</p>

      <h2>Article 12 · Propriété intellectuelle</h2>
      <p>Les énigmes, textes, visuels et l&apos;application sont la propriété de l&apos;Organisateur ou de ses partenaires. Toute reproduction ou diffusion, notamment des énigmes et de leurs réponses, est interdite pendant la durée du Jeu.</p>

      <h2>Article 13 · Acceptation et litiges</h2>
      <p>L&apos;inscription au Jeu implique l&apos;acceptation pleine et entière du présent règlement, ainsi que des décisions de l&apos;Organisateur relatives à son application. Toute contestation doit être adressée par écrit à l&apos;Organisateur dans un délai de 15 jours suivant la révélation. Le présent règlement est soumis au droit français ; à défaut d&apos;accord amiable, les tribunaux compétents sont ceux du ressort du siège de l&apos;Organisateur.</p>

      <p style={{ marginTop: '2.5rem' }}><Link href="/tresors-de-noel" className="tdn-btn tdn-btn-ghost">← Retour</Link></p>
    </main>
  );
}
