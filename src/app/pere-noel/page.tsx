import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { euros } from '@/lib/sumup';

export default async function PageAccueilPn() {
  const r = await lireReglagesPn();
  const flocons = [12, 30, 48, 66, 84];

  return (
    <main className="pn-page">
      <div className="pn-hero">
        {r.image_url
          // eslint-disable-next-line @next/next/no-img-element
          ? <img src={r.image_url} alt="Le Père Noël dans son atelier" />
          : <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#9FB0D6' }}>Image du Père Noël à définir</div>}
        {flocons.map((x, i) => <i key={x} className="pn-flocon" style={{ left: `${x}%`, top: `${(i * 17) % 40}%`, animationDuration: `${6 + i}s`, animationDelay: `${i * .7}s` }} />)}
        <div className="sous">« Bonjour Léa, j&apos;ai bien reçu ta lettre… »</div>
      </div>

      <h1 className="pn-titre">{r.accroche}</h1>
      <p className="pn-l clair">
        Pas un message tout fait avec un prénom collé dessus : une vraie réponse à ce que votre enfant a écrit.
        Sa lettre, son doudou, ses fiertés de l&apos;année, tout y est. À télécharger et à garder pour toujours.
      </p>

      <div className="pn-cardn"><b>{euros(r.prix_centimes)}</b> la vidéo personnalisée<small>Livrée {r.delai_texte}. Lettre écrite du Père Noël et certificat d&apos;enfant sage inclus.</small></div>

      {r.commandes_ouvertes
        ? <Link href="/pere-noel/commander" className="pn-btn or">Écrire au Père Noël</Link>
        : <p className="pn-cardn pn-centre">Les commandes ouvriront bientôt.</p>}

      <div className="pn-avis"><b>Comment ça marche ?</b> Vous remplissez la lettre avec votre enfant (5 minutes). Le Père Noël enregistre sa réponse. Vous recevez un lien par email avec la vidéo à télécharger.</div>

      <ul className="pn-etapes" style={{ marginTop: 18 }}>
        <li className="ok"><span>1</span><div>Vous racontez : prénom, sa lettre, ses fiertés, un petit secret que seul le Père Noël pouvait connaître.</div></li>
        <li className="ok"><span>2</span><div>Le Père Noël répond, en vidéo, avec ses mots à lui et le prénom de votre enfant.</div></li>
        <li className="ok"><span>3</span><div>Vous téléchargez la vidéo, imprimez la lettre et le certificat. Magie garantie le soir de Noël.</div></li>
      </ul>

      <div className="pn-faq" style={{ marginTop: 22 }}>
        <details><summary>Le Père Noël dit vraiment le prénom ?</summary><p>Oui. Vous pouvez même indiquer comment il se prononce pour éviter toute erreur.</p></details>
        <details><summary>Combien de temps dure la vidéo ?</summary><p>Environ une minute quinze, en format vertical plein écran, idéale sur un téléphone ou la télé du salon.</p></details>
        <details><summary>Et si quelque chose ne va pas ?</summary><p>Un détail inexact, un prénom mal prononcé : écrivez-nous depuis votre espace, nous refaisons la vidéo.</p></details>
        <details><summary>Où va l&apos;argent ?</summary><p>C&apos;est une action du Comité des Fêtes : les bénéfices financent les événements de l&apos;année.</p></details>
      </div>
    </main>
  );
}
