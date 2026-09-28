import { Coin, Sceau } from '@/components/pere-noel/Ornement';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
const dateLongue = (d: Date) => `le ${d.getDate()} ${MOIS[d.getMonth()]} ${d.getFullYear()}`;

/** Lettre du Père Noël : A4 portrait à l'impression. */
export function DocLettre({ prenom, texte, date, exemple = false }: { prenom: string; texte: string; date: Date; exemple?: boolean }) {
  const corps = texte.replace(/\n*\s*Le Père Noël\s*$/i, '').trim();
  return (
    <div className={`pn-doc-feuille pn-a4-portrait${exemple ? ' pn-exemple' : ''}`}>
      <div className="pn-doc-cadre">
        <div className="etoiles-doc" />
        <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
        {exemple && <div className="pn-filigrane">Exemple</div>}
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
        <div className="filet">✦</div>
        <div className="date" style={{ textAlign: 'right' }}>Pôle Nord, {dateLongue(date)}</div>
        <p className="lettre">{corps}</p>
        <div className="bas">
          <div className="signature">Le Père Noël</div>
          <Sceau />
        </div>
        <div className="pn-doc-pied">Pour {prenom}, avec toute l&apos;affection du Pôle Nord</div>
      </div>
    </div>
  );
}

/** Certificat d'enfant sage : A4 paysage à l'impression, dimensions fluides à l'écran. */
export function DocCertificat({ prenom, mention, genre, date, exemple = false }: { prenom: string; mention: string; genre: 'fille' | 'garcon' | null; date: Date; exemple?: boolean }) {
  const fem = genre === 'fille';
  const annee = date.getFullYear();
  return (
    <div className={`pn-doc-feuille pn-a4-paysage${exemple ? ' pn-exemple' : ''}`}>
      <div className="pn-doc-cadre pn-cert">
        <div className="etoiles-doc" />
        <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
        {exemple && <div className="pn-filigrane">Exemple</div>}
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
        <h1>Certificat d&apos;enfant sage</h1>
        <div className="filet">✦ ✦ ✦</div>
        <p className="decerne">décerné à</p>
        <div className="prenom">{prenom}</div>
        <p className="mention">{mention}</p>
        <p className="atteste">
          Le Père Noël atteste que {prenom} est inscrit{fem ? 'e' : ''} sur la grande liste des enfants sages de l&apos;année {annee}, et qu&apos;{fem ? 'elle' : 'il'} peut en être fi{fem ? 'ère' : 'er'}.
        </p>
        <div className="bas">
          <div className="date">Fait au Pôle Nord,<br />{dateLongue(date)}<div className="signature" style={{ textAlign: 'left' }}>Le Père Noël</div></div>
          <Sceau />
        </div>
      </div>
    </div>
  );
}

export const EXEMPLE_LETTRE = `Ma chère Léa,

J'ai bien reçu ta lettre, et je dois te dire qu'elle m'a fait sourire dans ma barbe ! Tu as appris à faire du vélo sans les petites roues cette année : je t'ai vue tomber, et remonter tout de suite. Ça, c'est du courage.

Tu me demandes si Rudolph a froid au nez. Eh bien oui, un petit peu… mais c'est justement pour ça qu'il brille !

J'ai bien noté ta liste, et je ferai de mon mieux. En attendant, continue de dormir dans ton lit comme une grande, et fais un gros bisou à Mamie Jacqueline de ma part.

À très bientôt, la nuit de Noël.

Le Père Noël`;
export const EXEMPLE_MENTION = 'pour son courage à vélo, sa tendresse avec Caramel et son sourire qui réchauffe même le Pôle Nord.';
