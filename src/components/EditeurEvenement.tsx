'use client';
import { useActionState, useState } from 'react';
import Link from 'next/link';
import { enregistrerEvenement, type ActionState } from '@/app/actions';
import ChampImage from '@/components/ChampImage';
import ChampDocuments, { type Document } from '@/components/ChampDocuments';
import type { Evenement, Creneau, InfoBloc, FaqItem } from '@/lib/types';

type Props = {
  evenement: Partial<Evenement> | null;
  creneaux: Creneau[];
  infos: InfoBloc[];
  faq: FaqItem[];
  documents?: Document[];
};

const VIDE_CRENEAU = { heure: '', titre: '', description: '', scene: '' };
const VIDE_INFO = { titre: '', lignes: '' };
const VIDE_FAQ = { question: '', reponse: '' };

export default function EditeurEvenement({ evenement, creneaux, infos, faq, documents = [] }: Props) {
  const [state, action, pending] = useActionState<ActionState, FormData>(enregistrerEvenement, null);
  const e = evenement ?? {};

  const [lsCreneaux, setCreneaux] = useState(
    creneaux.length ? creneaux.map((c) => ({
      heure: c.heure, titre: c.titre, description: c.description ?? '', scene: c.scene ?? '',
    })) : [VIDE_CRENEAU]
  );
  const [lsInfos, setInfos] = useState(
    infos.length ? infos.map((i) => ({ titre: i.titre, lignes: i.lignes.join('\n') })) : [VIDE_INFO]
  );
  const [lsFaq, setFaq] = useState(
    faq.length ? faq.map((f) => ({ question: f.question, reponse: f.reponse })) : [VIDE_FAQ]
  );
  const [couleur, setCouleur] = useState(e.couleur ?? '#FF3D7F');

  return (
    <form action={action}>
      {state?.ok && <div className="msg ok">{state.ok}</div>}
      {state?.error && <div className="msg ko">{state.error}</div>}
      <input type="hidden" name="id" value={e.id ?? ''} />

      {/* ---------- Identité ---------- */}
      <div className="panel">
        <h2>Identité de l&apos;événement</h2>
        <div className="row2">
          <div className="field">
            <label htmlFor="titre">Titre *</label>
            <input id="titre" name="titre" required defaultValue={e.titre ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="slug">Adresse de la page (laisser vide = auto)</label>
            <input id="slug" name="slug" defaultValue={e.slug ?? ''} placeholder="fete-de-la-musique" />
          </div>
        </div>
        <div className="field">
          <label htmlFor="chapo">Accroche (affichée sur l&apos;affiche et en haut de page)</label>
          <textarea id="chapo" name="chapo" rows={2} defaultValue={e.chapo ?? ''} />
        </div>
        <div className="field">
          <label htmlFor="description">Texte d&apos;introduction du programme</label>
          <textarea id="description" name="description" rows={3} defaultValue={e.description ?? ''} />
        </div>
      </div>

      {/* ---------- Quand & où ---------- */}
      <div className="panel">
        <h2>Quand et où</h2>
        <div className="row3">
          <div className="field">
            <label htmlFor="date_debut">Date *</label>
            <input id="date_debut" name="date_debut" type="date" required
              defaultValue={e.date_debut ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="date_fin">Date de fin (si plusieurs jours)</label>
            <input id="date_fin" name="date_fin" type="date"
              defaultValue={e.date_fin ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="heure_debut">Heure de début</label>
            <input id="heure_debut" name="heure_debut" defaultValue={e.heure_debut ?? ''} placeholder="18h" />
          </div>
          <div className="field">
            <label htmlFor="heure_fin">Heure de fin</label>
            <input id="heure_fin" name="heure_fin" defaultValue={e.heure_fin ?? ''} placeholder="minuit" />
          </div>
        </div>
        <div className="row3">
          <div className="field">
            <label htmlFor="lieu">Lieu</label>
            <input id="lieu" name="lieu" defaultValue={e.lieu ?? ''} placeholder="Place de l'Église" />
          </div>
          <div className="field">
            <label htmlFor="adresse">Adresse complète</label>
            <input id="adresse" name="adresse" defaultValue={e.adresse ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="tarif">Tarif</label>
            <input id="tarif" name="tarif" defaultValue={e.tarif ?? 'Entrée libre'} />
          </div>
        </div>
      </div>

      {/* ---------- Apparence ---------- */}
      <div className="panel">
        <h2>Apparence</h2>
        <div className="row3">
          <div className="field">
            <label htmlFor="couleur">Couleur principale</label>
            <input id="couleur" name="couleur" type="color" value={couleur}
              onChange={(ev) => setCouleur(ev.target.value)} style={{ height: 46, padding: 4 }} />
          </div>
          <div className="field">
            <label htmlFor="couleur_sombre">Couleur foncée (détails)</label>
            <input id="couleur_sombre" name="couleur_sombre" type="color"
              defaultValue={e.couleur_sombre ?? '#C42A5F'} style={{ height: 46, padding: 4 }} />
          </div>
          <div className="field">
            <label htmlFor="saison">Saison</label>
            <select id="saison" name="saison" defaultValue={e.saison ?? 'ete'}>
              <option value="printemps">Printemps</option>
              <option value="ete">Été</option>
              <option value="automne">Automne</option>
              <option value="hiver">Hiver</option>
            </select>
          </div>
        </div>
        <div className="row2">
          <ChampImage
            name="image_url"
            label="Image de fond du bandeau"
            valeurInitiale={e.image_url ?? null}
            aide="Remplace les rayons colorés. Format paysage, 1600px de large minimum."
          />
          <div className="field">
            <label htmlFor="position">Ordre d&apos;affichage</label>
            <input id="position" name="position" type="number" defaultValue={e.position ?? 0} />
          </div>
        </div>
        <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center', fontWeight: 600 }}>
          <input type="checkbox" name="publie" defaultChecked={e.publie ?? false}
            style={{ width: 20, height: 20 }} />
          Publier cet événement sur le site
        </label>
      </div>

      {/* ---------- Billetterie ---------- */}
      <div className="panel">
        <h2>Billetterie en ligne</h2>
        <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center', fontWeight: 600 }}>
          <input type="checkbox" name="billetterie_active"
            defaultChecked={e.billetterie_active ?? false}
            style={{ width: 20, height: 20 }} />
          Activer la réservation avec paiement SumUp
        </label>
        <p style={{ color: '#6b6560', fontSize: '.85rem', margin: '.6rem 0 1.2rem' }}>
          Si désactivée, le lien externe ci-dessous est utilisé à la place.
        </p>

        <div className="row3">
          <div className="field">
            <label htmlFor="prix_euros">Prix par place (€)</label>
            <input id="prix_euros" name="prix_euros" type="number" step="0.01" min="0"
              defaultValue={((e.prix_centimes ?? 0) / 100).toFixed(2)} />
          </div>
          <div className="field">
            <label htmlFor="places_max">Jauge totale (vide = illimitée)</label>
            <input id="places_max" name="places_max" type="number" min="1"
              defaultValue={e.places_max ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="places_par_reservation">Places max par réservation</label>
            <input id="places_par_reservation" name="places_par_reservation"
              type="number" min="1" defaultValue={e.places_par_reservation ?? 10} />
          </div>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="cloture_reservations">Clôture des réservations</label>
            <input id="cloture_reservations" name="cloture_reservations" type="date"
              defaultValue={e.cloture_reservations ?? ''} />
          </div>
          <div className="field">
            <label htmlFor="lien_reservation">Lien externe (si billetterie désactivée)</label>
            <input id="lien_reservation" name="lien_reservation"
              defaultValue={e.lien_reservation ?? ''}
              placeholder="https://... ou mailto:..." />
          </div>
          <div className="field">
            <label htmlFor="libelle_reservation">Texte du bouton</label>
            <input id="libelle_reservation" name="libelle_reservation"
              defaultValue={e.libelle_reservation ?? 'Réserver'} />
          </div>
        </div>
      </div>

      {/* ---------- Documents ---------- */}
      <div className="panel">
        <h2>Affiches et documents</h2>
        <p style={{ color: '#6b6560', fontSize: '.88rem', marginBottom: '1.2rem' }}>
          Affiche de l&apos;événement, menu de la soirée, plan d&apos;accès, photos des
          éditions précédentes. Images et PDF acceptés.
        </p>
        <ChampDocuments documentsInitiaux={documents} />
      </div>

      {/* ---------- Programme ---------- */}
      <div className="panel">
        <h2>Programme (créneaux horaires)</h2>
        {lsCreneaux.map((c, i) => (
          <div className="repeat-item" key={i}>
            <div className="row2">
              <div className="field">
                <label>Heure</label>
                <input name="cr_heure" defaultValue={c.heure} placeholder="19h30" />
              </div>
              <div className="field">
                <label>Titre</label>
                <input name="cr_titre" defaultValue={c.titre} placeholder="Les Berges" />
              </div>
            </div>
            <div className="field">
              <label>Description</label>
              <input name="cr_desc" defaultValue={c.description} />
            </div>
            <div className="field">
              <label>Scène / lieu</label>
              <input name="cr_scene" defaultValue={c.scene} placeholder="Scène du lavoir" />
            </div>
            <button type="button" className="btn btn-w btn-sm"
              onClick={() => setCreneaux(lsCreneaux.filter((_, j) => j !== i))}>
              Retirer ce créneau
            </button>
          </div>
        ))}
        <button type="button" className="btn btn-y btn-sm"
          onClick={() => setCreneaux([...lsCreneaux, { ...VIDE_CRENEAU }])}>
          + Ajouter un créneau
        </button>
      </div>

      {/* ---------- Infos pratiques ---------- */}
      <div className="panel">
        <h2>Infos pratiques</h2>
        {lsInfos.map((b, i) => (
          <div className="repeat-item" key={i}>
            <div className="field">
              <label>Titre du bloc</label>
              <input name="inf_titre" defaultValue={b.titre} placeholder="Accès & parking" />
            </div>
            <div className="field">
              <label>Lignes (une par ligne)</label>
              <textarea name="inf_lignes" rows={4} defaultValue={b.lignes} />
            </div>
            <button type="button" className="btn btn-w btn-sm"
              onClick={() => setInfos(lsInfos.filter((_, j) => j !== i))}>
              Retirer ce bloc
            </button>
          </div>
        ))}
        <button type="button" className="btn btn-y btn-sm"
          onClick={() => setInfos([...lsInfos, { ...VIDE_INFO }])}>
          + Ajouter un bloc
        </button>
      </div>

      {/* ---------- FAQ ---------- */}
      <div className="panel">
        <h2>Questions fréquentes</h2>
        {lsFaq.map((f, i) => (
          <div className="repeat-item" key={i}>
            <div className="field">
              <label>Question</label>
              <input name="faq_q" defaultValue={f.question} />
            </div>
            <div className="field">
              <label>Réponse</label>
              <textarea name="faq_r" rows={3} defaultValue={f.reponse} />
            </div>
            <button type="button" className="btn btn-w btn-sm"
              onClick={() => setFaq(lsFaq.filter((_, j) => j !== i))}>
              Retirer
            </button>
          </div>
        ))}
        <button type="button" className="btn btn-y btn-sm"
          onClick={() => setFaq([...lsFaq, { ...VIDE_FAQ }])}>
          + Ajouter une question
        </button>
      </div>

      <div style={{ display: 'flex', gap: '.8rem', flexWrap: 'wrap', marginBottom: '3rem' }}>
        <button className="btn btn-k" disabled={pending}>
          {pending ? 'Enregistrement…' : 'Enregistrer'}
        </button>
        <Link className="btn btn-w" href="/admin/evenements">Retour à la liste</Link>
        {e.slug && (
          <Link className="btn btn-y" href={`/evenements/${e.slug}`} target="_blank">
            Voir la page
          </Link>
        )}
      </div>
    </form>
  );
}
