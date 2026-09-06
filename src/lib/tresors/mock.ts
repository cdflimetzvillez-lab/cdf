import type { Compte, Lot, Mission, Partenaire, StatsAdmin, Cle } from './types';

export const TARIFS = { adulte: 8, enfant: 5 } as const;

export const EVENEMENT = {
  titre: 'Les Trésors de Noël de Limetz-Villez',
  accroche: 'Parcourez le village. Résolvez les mystères. Retrouvez votre clé.',
  periode: 'Du 6 au 20 décembre 2026',
  marche: 'Marché de Noël, samedi 20 décembre 2026',
  duree: 'Environ 1h30 à 2h',
  nbMissions: 12,
};

export const COMPTE_DEMO: Compte = {
  id: 'c1',
  prenom: 'Jérémy',
  nom: 'Peloso',
  email: 'jeremy@exemple.fr',
  telephone: '06 12 34 56 78',
  participants: [
    { id: 'p1', prenom: 'Jérémy', categorie: 'adulte', inscrit: true },
    { id: 'p2', prenom: 'Lucas', categorie: 'enfant', inscrit: true },
    { id: 'p3', prenom: 'Emma', categorie: 'enfant', inscrit: true },
  ],
};

/** Progression initiale de la démo : Jérémy et Lucas en sont à la mission 8, Emma à la 6. */
export const PROGRESSION_DEMO: Record<string, number[]> = {
  p1: [1, 2, 3, 4, 5, 6, 7],
  p2: [1, 2, 3, 4, 5, 6, 7],
  p3: [1, 2, 3, 4, 5],
};

export const MISSIONS: Mission[] = [
  {
    numero: 1, titre: "L'appel de la mairie", lieu: 'Place de la Mairie',
    accroche: "Tout commence là où le village se rassemble.",
    blocs: [
      { type: 'texte', contenu: "Un mot a été glissé sous la porte de la mairie : « Les cadeaux sont partis. Le premier indice attend là où l'on affiche les nouvelles du village. »" },
      { type: 'image', src: '/tresors/mairie.svg', alt: 'La mairie de Limetz-Villez' },
    ],
    question: { type: 'texte', intitule: "Quel mot est écrit en lettres dorées sur la plaque du panneau d'affichage ?", reponses: ['liberté', 'liberte'] },
    indices: ['Le panneau est à gauche de la porte principale.', "C'est le premier mot de la devise de la République."],
    solutionSecours: 'Liberté',
  },
  {
    numero: 2, titre: 'Les cloches muettes', lieu: 'Église Saint-Martin',
    accroche: 'Les cloches se sont tues cette nuit-là.',
    blocs: [
      { type: 'texte', contenu: "Le sonneur jure avoir vu une ombre rouge grimper au clocher. Regardez bien la façade." },
      { type: 'audio', titre: 'Témoignage du sonneur', duree: '0:42' },
    ],
    question: { type: 'choix', intitule: "Combien de vitraux comptez-vous sur la façade ?", options: ['1', '2', '3', '4'], bonneReponse: 2 },
    indices: ['Levez les yeux au-dessus du porche.', 'Ne comptez que les vitraux visibles depuis la place.'],
  },
  {
    numero: 3, titre: 'Le pont des murmures', lieu: 'Pont sur la Seine',
    accroche: "L'eau a emporté un secret.",
    blocs: [{ type: 'texte', contenu: "Sur le pont, une plaque rappelle une date. Le lutin l'a soulignée à la craie rouge." }],
    question: { type: 'code', intitule: 'Quelle année est gravée sur la plaque ?', reponses: ['1932'], longueur: 4 },
    indices: ['La plaque est côté amont.', "L'année commence par 19."],
    solutionSecours: '1932',
  },
  {
    numero: 4, titre: "Le lavoir gelé", lieu: 'Ancien lavoir',
    accroche: 'Un reflet dans la glace.',
    blocs: [{ type: 'texte', contenu: "Le lavoir a gelé pour la première fois depuis vingt ans. Sous la glace, on distingue des lettres." }],
    question: { type: 'texte', intitule: 'Quel animal est sculpté sur la poutre du lavoir ?', reponses: ['cygne', 'un cygne'] },
    indices: ['Regardez la poutre centrale.', "C'est un grand oiseau blanc."],
  },
  {
    numero: 5, titre: 'La boulangerie endormie', lieu: 'Rue de la Boulangerie',
    accroche: "L'odeur du pain chaud a disparu.",
    blocs: [
      { type: 'texte', contenu: "La boulangère a retrouvé une trace de sucre glace devant sa vitrine. Le lutin y a laissé un chiffre." },
      { type: 'video', titre: 'Message de la boulangère', duree: '0:35' },
    ],
    question: { type: 'code', intitule: "Quel numéro figure sur l'enseigne ?", reponses: ['14'], longueur: 2 },
    indices: ['Le numéro est en fer forgé.', 'Il est entre 10 et 20.'],
  },
  {
    numero: 6, titre: 'Le chêne des souvenirs', lieu: 'Parc communal',
    accroche: 'Un arbre qui a tout vu.',
    blocs: [{ type: 'texte', contenu: "Au pied du grand chêne, une plaque commémorative. Le lutin y a laissé une clé de lecture." }],
    question: { type: 'choix', intitule: 'En quelle saison le chêne a-t-il été planté ?', options: ['Printemps', 'Été', 'Automne', 'Hiver'], bonneReponse: 0 },
    indices: ['La plaque mentionne un mois.', 'Ce mois est mars.'],
  },
  {
    numero: 7, titre: "L'école des étoiles", lieu: 'École communale',
    accroche: 'Les enfants ont dessiné le coupable.',
    blocs: [{ type: 'texte', contenu: "Sur la grille de l'école, un dessin d'enfant montre un traîneau. Comptez les rennes." }],
    question: { type: 'code', intitule: 'Combien de rennes tirent le traîneau ?', reponses: ['8'], longueur: 1 },
    indices: ['Le dessin est près du portail bleu.', 'Le nombre est pair.'],
  },
  {
    numero: 8, titre: 'Le secret du lutin disparu', lieu: 'Rue de la Mairie',
    accroche: 'Le lutin rouge est passé devant un lieu que les habitants connaissent bien…',
    blocs: [
      { type: 'texte', contenu: "Un habitant l'a vu s'arrêter sous l'horloge, hésiter, puis griffonner quelque chose. Depuis, plus aucune trace de lui." },
      { type: 'image', src: '/tresors/horloge.svg', alt: "L'horloge du village", legende: "L'horloge, place de la Mairie" },
    ],
    question: { type: 'code', intitule: "Quel nombre apparaît sous l'horloge ?", reponses: ['1887'], longueur: 4 },
    indices: ["Regardez au-dessus de l'entrée.", 'Cherchez un nombre à quatre chiffres.'],
    solutionSecours: '1887',
  },
  {
    numero: 9, titre: 'Le cimetière des sapins', lieu: 'Chemin des Vignes',
    accroche: 'Des aiguilles sur le chemin.',
    blocs: [{ type: 'texte', contenu: "Une traînée d'aiguilles de sapin mène à une borne kilométrique. Le lutin a effacé un chiffre." }],
    question: { type: 'texte', intitule: 'Vers quelle commune pointe la borne ?', reponses: ['bonnières', 'bonnieres', 'bonnières-sur-seine'] },
    indices: ["C'est la commune voisine, de l'autre côté de la Seine.", 'Son nom commence par B.'],
  },
  {
    numero: 10, titre: 'La fontaine qui chante', lieu: 'Fontaine du village',
    accroche: "L'eau murmure un nombre.",
    blocs: [{ type: 'texte', contenu: "Le lutin a jeté une pièce dans la fontaine. Sur le rebord, il a gravé une énigme : « Je suis le nombre de jets, multiplié par le nombre de bassins. »" }],
    question: { type: 'code', intitule: 'Quel est ce nombre ?', reponses: ['6'], longueur: 1 },
    indices: ['Comptez les jets : il y en a 3.', 'Il y a 2 bassins.'],
  },
  {
    numero: 11, titre: 'La grange aux lanternes', lieu: 'Rue des Granges',
    accroche: 'Une lumière qui ne devrait pas être là.',
    blocs: [
      { type: 'texte', contenu: "Une grange restée éclairée toute la nuit. Sur la porte, des lanternes de couleurs différentes forment un message." },
      { type: 'audio', titre: 'Le chant des lanternes', duree: '0:28' },
    ],
    question: { type: 'choix', intitule: 'Quelle lanterne est allumée en dernier ?', options: ['La bleue', 'La rouge', 'La dorée', 'La verte'], bonneReponse: 2 },
    indices: ["Écoutez l'ordre des notes.", "C'est la couleur de Noël la plus précieuse."],
  },
  {
    numero: 12, titre: 'Le retour des cadeaux', lieu: 'Salle des fêtes',
    accroche: 'Le dernier mystère.',
    blocs: [{ type: 'texte', contenu: "Tous les indices mènent ici. Sur la porte de la salle des fêtes, un cadenas à mots. Assemblez les premières lettres des lieux de vos missions 1, 4 et 8." }],
    question: { type: 'texte', intitule: 'Quel mot ouvre le cadenas ?', reponses: ['mlr', 'm l r', 'm-l-r'], placeholder: 'Trois lettres' },
    indices: ['Mairie, Lavoir, Rue de la Mairie…', 'Prenez la première lettre de chaque mot.'],
    solutionSecours: 'MLR',
  },
];

export const LOTS: Lot[] = [
  { id: 'l1', nom: "500 € de bons d'achat", valeur: '500 €', partenaire: 'Commerçants de Limetz-Villez', stock: 1, attribues: 1, reveles: 0, grand: true },
  { id: 'l2', nom: '100 € de carte cadeau', valeur: '100 €', partenaire: 'Intermarché Bonnières', stock: 3, attribues: 3, reveles: 2 },
  { id: 'l3', nom: 'Repas pour deux', valeur: '60 €', partenaire: 'Restaurant Le Vieux Pont', stock: 5, attribues: 5, reveles: 3 },
  { id: 'l4', nom: '2 places de cinéma', valeur: '24 €', partenaire: 'Cinéma Le Grand Écran', stock: 20, attribues: 20, reveles: 14 },
  { id: 'l5', nom: 'Entrées parc de loisirs', valeur: '45 €', partenaire: 'Parc des Loisirs de la Vallée', stock: 8, attribues: 8, reveles: 5 },
  { id: 'l6', nom: 'Panier gourmand', valeur: '35 €', partenaire: 'La Ferme des Coteaux', stock: 15, attribues: 15, reveles: 9 },
  { id: 'l7', nom: 'Bon chez un commerçant', valeur: '20 €', partenaire: 'Fleuriste Au Jardin de Villez', stock: 25, attribues: 25, reveles: 16 },
  { id: 'l8', nom: 'Ballotin de chocolats', valeur: '15 €', partenaire: 'Chocolaterie Marquet', stock: 40, attribues: 40, reveles: 25 },
  { id: 'l9', nom: 'Petit cadeau de Noël', valeur: '8 €', partenaire: 'Comité des Fêtes', stock: 60, attribues: 30, reveles: 18 },
];

export const PARTENAIRES: Partenaire[] = [
  { id: 'pa1', nom: 'Commerçants de Limetz-Villez', type: 'Collectif', lots: 1 },
  { id: 'pa2', nom: 'Intermarché Bonnières', type: 'Grande surface', lots: 3 },
  { id: 'pa3', nom: 'Restaurant Le Vieux Pont', type: 'Restaurant', lots: 5 },
  { id: 'pa4', nom: 'Cinéma Le Grand Écran', type: 'Loisirs', lots: 20 },
  { id: 'pa5', nom: 'Parc des Loisirs de la Vallée', type: 'Loisirs', lots: 8 },
  { id: 'pa6', nom: 'La Ferme des Coteaux', type: 'Producteur', lots: 15 },
  { id: 'pa7', nom: 'Fleuriste Au Jardin de Villez', type: 'Commerce', lots: 25 },
  { id: 'pa8', nom: 'Chocolaterie Marquet', type: 'Commerce', lots: 40 },
];

export const STATS_ADMIN: StatsAdmin = {
  inscrits: 243, ca: 1614, commences: 198, termines: 147, clesGenerees: 147, clesRevelees: 92,
};

export const PARTICIPANTS_ADMIN = [
  { id: 'a1', prenom: 'Jérémy', nom: 'Peloso', categorie: 'adulte', progression: 7, cle: '—', statut: 'en cours' },
  { id: 'a2', prenom: 'Lucas', nom: 'Peloso', categorie: 'enfant', progression: 7, cle: '—', statut: 'en cours' },
  { id: 'a3', prenom: 'Emma', nom: 'Peloso', categorie: 'enfant', progression: 5, cle: '—', statut: 'en cours' },
  { id: 'a4', prenom: 'Camille', nom: 'Durand', categorie: 'adulte', progression: 12, cle: '012', statut: 'terminé' },
  { id: 'a5', prenom: 'Noah', nom: 'Durand', categorie: 'enfant', progression: 12, cle: '013', statut: 'terminé' },
  { id: 'a6', prenom: 'Sophie', nom: 'Martin', categorie: 'adulte', progression: 0, cle: '—', statut: 'inscrit' },
  { id: 'a7', prenom: 'Théo', nom: 'Bernard', categorie: 'enfant', progression: 12, cle: '041', statut: 'révélé' },
  { id: 'a8', prenom: 'Inès', nom: 'Lefèvre', categorie: 'adulte', progression: 3, cle: '—', statut: 'en cours' },
];

export const CLES_ADMIN: (Cle & { prenom: string; lot: string })[] = [
  { numero: '012', code: 'NOEL-3F7A', participantId: 'a4', revelee: false, prenom: 'Camille', lot: '2 places de cinéma' },
  { numero: '013', code: 'NOEL-9Q2L', participantId: 'a5', revelee: false, prenom: 'Noah', lot: 'Ballotin de chocolats' },
  { numero: '041', code: 'NOEL-K7M4', participantId: 'a7', revelee: true, prenom: 'Théo', lot: 'Panier gourmand' },
  { numero: '084', code: 'NOEL-8K4P', participantId: 'p1', revelee: false, prenom: 'Jérémy', lot: "500 € de bons d'achat" },
];

/** Clés reconnues par l'écran de révélation (démo). */
export const CLES_REVELATION: Record<string, { code: string; lot: Lot }> = {
  '084': { code: 'NOEL-8K4P', lot: LOTS[0] },
  '012': { code: 'NOEL-3F7A', lot: LOTS[3] },
  '013': { code: 'NOEL-9Q2L', lot: LOTS[7] },
  '041': { code: 'NOEL-K7M4', lot: LOTS[5] },
};
