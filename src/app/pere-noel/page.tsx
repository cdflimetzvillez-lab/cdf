import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { euros } from '@/lib/sumup';
import DemoVideo from '@/components/pere-noel/DemoVideo';

export default async function PageAccueilPn() {
  const r = await lireReglagesPn();

  return (
    <main className="pn-page">
      <p className="pn-sur">Une lettre · une réponse · un souvenir pour toujours</p>
      <h1 className="pn-titre pn-centre" style={{ marginTop: 4 }}>{r.accroche}</h1>
      <div className="pn-ornement">✦</div>

      {r.video_demo_url
        ? <DemoVideo src={r.video_demo_url} poster={r.image_url} />
        : r.image_url
          // eslint-disable-next-line @next/next/no-img-element
          ? <div className="pn-demo" style={{ cursor: 'default' }}><img src={r.image_url} alt="Le Père Noël dans son atelier" /></div>
          : null}

      <p className="pn-l clair pn-centre" style={{ marginTop: 18 }}>
        Pas un message tout fait avec un prénom collé dessus : une vraie réponse à ce que votre enfant a écrit.
        Sa lettre, son doudou, ses fiertés de l&apos;année, un secret que seul le Père Noël pouvait connaître… tout y est.
      </p>

      <div className="pn-cardn pn-centre"><b>{euros(r.prix_centimes)}</b> la vidéo personnalisée<small>Livrée {r.delai_texte}. Lettre écrite du Père Noël et certificat d&apos;enfant sage inclus, à imprimer.</small></div>

      {r.commandes_ouvertes
        ? <Link href="/pere-noel/commander" className="pn-btn or">✦ Écrire au Père Noël</Link>
        : <div className="pn-cardn pn-centre">Les commandes ouvriront bientôt.</div>}

      <div className="pn-ornement" style={{ marginTop: 26 }}>Comment ça marche</div>
      <ul className="pn-etapes">
        <li className="ok"><span>1</span><div>Vous racontez : prénom, sa lettre, ses fiertés, un petit secret. Cinq minutes, avec lui ou en cachette.</div></li>
        <li className="ok"><span>2</span><div>Le Père Noël lui répond en vidéo, avec ses mots à lui, en prononçant son prénom.</div></li>
        <li className="ok"><span>3</span><div>Vous téléchargez la vidéo, imprimez la lettre et le certificat. Magie garantie le soir de Noël.</div></li>
      </ul>

      <div className="pn-avis"><b>Un conseil :</b> ne montrez pas la vidéo tout de suite. Le soir, dans le noir, sur la télé du salon, l&apos;effet est décuplé.</div>

      <div className="pn-faq" style={{ marginTop: 22 }}>
        <details><summary>Le Père Noël dit vraiment le prénom ?</summary><p>Oui. Vous pouvez même indiquer comment il se prononce pour éviter toute erreur.</p></details>
        <details><summary>Combien de temps dure la vidéo ?</summary><p>Environ une minute quinze, en format vertical plein écran, idéale sur un téléphone ou la télé du salon.</p></details>
        <details><summary>Et si quelque chose ne va pas ?</summary><p>Un détail inexact, un prénom mal prononcé : écrivez-nous depuis votre espace, nous refaisons la vidéo.</p></details>
        <details><summary>Où va l&apos;argent ?</summary><p>C&apos;est une action du Comité des Fêtes : les bénéfices financent les événements de l&apos;année.</p></details>
      </div>
    </main>
  );
}
