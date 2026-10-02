# app.py - Interface Streamlit pour la gestion des stocks
import pandas as pd
import streamlit as st

import config
from inventaire import (SQL_COMMANDES_EN_ATTENTE, SQL_STOCK, SQL_SUGGESTIONS,
                        InventaireError, StockInsuffisant, annuler_commande,
                        commander_suggestions, creer_commande, entree_stock,
                        recevoir_commande, requete, vendre)

st.set_page_config(page_title="Gestion des stocks", page_icon="📦", layout="wide")
st.title("📦 Gestion des stocks")

STATUTS = {"Rupture": "🔴 Rupture", "Stock faible": "🟠 Stock faible", "OK": "🟢 OK"}


def charger(sql, decimaux=()):
    colonnes, lignes = requete(sql)
    df = pd.DataFrame(lignes, columns=colonnes)
    for col in decimaux:
        df[col] = df[col].astype(float)
    return df


def flash(message, type_="success"):
    """Mémorise un message, puis recharge la page pour afficher les données à jour."""
    st.session_state["flash"] = (type_, message)
    st.rerun()


if "flash" in st.session_state:
    type_, message = st.session_state.pop("flash")
    getattr(st, type_)(message)

try:
    df = charger(SQL_STOCK, decimaux=["prix_unitaire"])
    suggestions = charger(SQL_SUGGESTIONS, decimaux=["cout_estime"])
    commandes = charger(SQL_COMMANDES_EN_ATTENTE)
except Exception as e:
    st.error(f"Impossible de se connecter à la base de données : {e}")
    st.stop()

tab1, tab2, tab3, tab4 = st.tabs(
    ["📊 Tableau de bord", "🛒 Vendre", "📋 À commander", "🚚 Commandes en cours"])

# --- Tableau de bord ---
with tab1:
    en_alerte = df[df["stock_actuel"] < df["seuil_reapprovisionnement"]]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Produits", len(df))
    c2.metric("Produits en alerte", len(en_alerte))
    c3.metric("Stock total", int(df["stock_actuel"].sum()))
    c4.metric("Valeur du stock", f"{(df['stock_actuel'] * df['prix_unitaire']).sum():,.2f} €")

    affichage = df[["produit", "fournisseur", "stock_actuel", "seuil_reapprovisionnement",
                    "en_commande", "prix_unitaire", "statut_stock"]].copy()
    affichage["statut_stock"] = affichage["statut_stock"].map(STATUTS)
    affichage.columns = ["Produit", "Fournisseur", "Stock", "Seuil",
                         "En commande", "Prix", "Statut"]
    st.dataframe(affichage, use_container_width=True, hide_index=True)
    st.bar_chart(df.set_index("produit")["stock_actuel"])

# --- Vente ---
with tab2:
    st.subheader("Enregistrer une vente")
    nom = st.selectbox("Produit", df["produit"], key="vente_produit")
    ligne = df[df["produit"] == nom].iloc[0]
    st.caption(f"Stock actuel : {int(ligne['stock_actuel'])}")
    qte = st.number_input("Quantité vendue", min_value=1, step=1, key="vente_qte")
    if st.button("Vendre"):
        try:
            nouveau = vendre(int(ligne["id_produit"]), int(qte))
            flash(f"Vente enregistrée. Nouveau stock : {nouveau}")
        except StockInsuffisant as e:
            st.error(f"Stock insuffisant (disponible : {e.disponible})")
        except InventaireError as e:
            st.error(str(e))

# --- Liste à commander ---
with tab3:
    st.subheader("Bons de commande suggérés")
    st.caption(f"Règle : on commande si stock + commandes en cours < seuil, "
               f"jusqu'à {config.NIVEAU_CIBLE} x le seuil.")
    if suggestions.empty:
        st.success("Aucun produit à commander.")
    else:
        tableau = suggestions[["produit", "fournisseur", "stock_actuel", "en_commande",
                               "seuil_reapprovisionnement", "quantite_a_commander",
                               "cout_estime"]].copy()
        tableau.columns = ["Produit", "Fournisseur", "Stock", "En commande",
                           "Seuil", "Quantité à commander", "Coût estimé"]
        st.dataframe(tableau, use_container_width=True, hide_index=True)
        st.metric("Coût total estimé", f"{tableau['Coût estimé'].sum():,.2f} €")

        col_a, col_b = st.columns(2)
        if col_a.button("✅ Créer tous les bons de commande"):
            n = commander_suggestions()
            flash(f"{n} bon(s) de commande créé(s).")
        col_b.download_button("⬇️ Télécharger en CSV",
                              tableau.to_csv(index=False, sep=";").encode("utf-8-sig"),
                              file_name="reapprovisionnement.csv", mime="text/csv")

    with st.expander("Créer une commande manuelle"):
        nom_c = st.selectbox("Produit", df["produit"], key="cmd_produit")
        qte_c = st.number_input("Quantité", min_value=1, step=1, key="cmd_qte")
        if st.button("Commander"):
            id_p = int(df[df["produit"] == nom_c].iloc[0]["id_produit"])
            creer_commande(id_p, int(qte_c))
            flash(f"Commande créée : {int(qte_c)} x {nom_c}.")

# --- Commandes en cours ---
with tab4:
    st.subheader("Commandes en attente de livraison")
    if commandes.empty:
        st.info("Aucune commande en attente.")
    else:
        st.dataframe(commandes, use_container_width=True, hide_index=True)
        options = {f"#{r.id_commande} - {r.produit} ({r.quantite_commandee} u., {r.fournisseur})":
                   int(r.id_commande) for r in commandes.itertuples()}
        choix = st.selectbox("Commande", list(options), key="cmd_choix")
        col_a, col_b = st.columns(2)
        if col_a.button("📥 Marquer comme reçue (ajoute au stock)"):
            try:
                _, q = recevoir_commande(options[choix])
                flash(f"Commande reçue : {q} unités ajoutées au stock.")
            except InventaireError as e:
                st.error(str(e))
        if col_b.button("❌ Annuler la commande"):
            try:
                annuler_commande(options[choix])
                flash("Commande annulée.", "warning")
            except InventaireError as e:
                st.error(str(e))

    with st.expander("Entrée de stock hors commande"):
        nom_e = st.selectbox("Produit", df["produit"], key="entree_produit")
        qte_e = st.number_input("Quantité reçue", min_value=1, step=1, key="entree_qte")
        if st.button("Ajouter au stock"):
            id_p = int(df[df["produit"] == nom_e].iloc[0]["id_produit"])
            entree_stock(id_p, int(qte_e))
            flash(f"{int(qte_e)} unités ajoutées.")

st.sidebar.button("🔄 Actualiser")
