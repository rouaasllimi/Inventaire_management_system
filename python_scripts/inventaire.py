"""Couche d'accès aux données : toute la logique métier passe par ici.

Utilisée par app.py (Streamlit), vendres.py (CLI) et alerte_stock.py (export).
Chaque opération d'écriture s'exécute dans UNE transaction : tout est validé
(commit) ou tout est annulé (rollback).
"""
from contextlib import contextmanager

import pyodbc

import config


# --------------------------------------------------------------------------
# Erreurs métier
# --------------------------------------------------------------------------
class InventaireError(Exception):
    """Erreur métier de base."""


class ProduitIntrouvable(InventaireError):
    pass


class CommandeIntrouvable(InventaireError):
    pass


class StockInsuffisant(InventaireError):
    def __init__(self, disponible):
        super().__init__(f"Stock insuffisant (disponible : {disponible})")
        self.disponible = disponible


# --------------------------------------------------------------------------
# Requêtes (basées sur la vue vw_stock_actuel de create_tables.sql)
# --------------------------------------------------------------------------
SQL_STOCK = "SELECT * FROM dbo.vw_stock_actuel ORDER BY produit"

SQL_SUGGESTIONS = f"""
    SELECT id_produit, produit, fournisseur,
           stock_actuel, en_commande, seuil_reapprovisionnement,
           {config.NIVEAU_CIBLE} * seuil_reapprovisionnement
               - (stock_actuel + en_commande) AS quantite_a_commander,
           CAST(({config.NIVEAU_CIBLE} * seuil_reapprovisionnement
               - (stock_actuel + en_commande)) * prix_unitaire AS DECIMAL(10,2)) AS cout_estime
    FROM dbo.vw_stock_actuel
    WHERE stock_actuel + en_commande < seuil_reapprovisionnement
    ORDER BY fournisseur, produit
"""

SQL_COMMANDES_EN_ATTENTE = """
    SELECT c.id AS id_commande, p.nom AS produit, f.nom AS fournisseur,
           c.quantite_commandee, c.date_commande,
           DATEADD(DAY, f.delai_livraison_jours, c.date_commande) AS livraison_estimee
    FROM dbo.commandes c
    JOIN dbo.produits p     ON p.id = c.id_produit
    JOIN dbo.fournisseurs f ON f.id = c.id_fournisseur
    WHERE c.statut = 'En attente'
    ORDER BY c.date_commande, c.id
"""


# --------------------------------------------------------------------------
# Connexion
# --------------------------------------------------------------------------
@contextmanager
def connexion():
    """Ouvre une connexion : commit si tout va bien, rollback en cas d'erreur."""
    conn = pyodbc.connect(config.CONN_STR)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def requete(sql, params=()):
    """Exécute un SELECT et renvoie (noms_colonnes, lignes_sous_forme_de_tuples)."""
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        colonnes = [c[0] for c in cur.description]
        lignes = [tuple(r) for r in cur.fetchall()]
    return colonnes, lignes


# --------------------------------------------------------------------------
# Opérations d'écriture (transactionnelles)
# --------------------------------------------------------------------------
def vendre(id_produit, quantite):
    """Enregistre une vente et renvoie le nouveau stock.

    Le stock est lu avec WITH (UPDLOCK, HOLDLOCK) : le verrou est conservé
    jusqu'au commit, donc deux ventes simultanées du même produit sont
    sérialisées et le stock ne peut pas devenir négatif.
    """
    if quantite <= 0:
        raise ValueError("La quantité doit être strictement positive.")

    with connexion() as conn:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM dbo.produits WHERE id = ?", (id_produit,))
        if cur.fetchone() is None:
            raise ProduitIntrouvable(f"Produit {id_produit} introuvable.")

        cur.execute(
            """SELECT COALESCE(SUM(quantite_variation), 0)
               FROM dbo.mouvements_stock WITH (UPDLOCK, HOLDLOCK)
               WHERE id_produit = ?""",
            (id_produit,),
        )
        stock = cur.fetchone()[0]
        if stock < quantite:
            raise StockInsuffisant(stock)

        cur.execute(
            """INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement)
               VALUES (?, ?, 'VENTE')""",
            (id_produit, -quantite),
        )
    return stock - quantite


def entree_stock(id_produit, quantite):
    """Entrée de stock hors commande (ex. retour client, inventaire)."""
    if quantite <= 0:
        raise ValueError("La quantité doit être strictement positive.")
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement)
               VALUES (?, ?, 'ENTREE')""",
            (id_produit, quantite),
        )


def creer_commande(id_produit, quantite):
    """Crée un bon de commande 'En attente' auprès du fournisseur du produit."""
    if quantite <= 0:
        raise ValueError("La quantité doit être strictement positive.")
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO dbo.commandes (id_produit, id_fournisseur, quantite_commandee)
               SELECT id, id_fournisseur, ? FROM dbo.produits WHERE id = ?""",
            (quantite, id_produit),
        )
        if cur.rowcount != 1:
            raise ProduitIntrouvable(f"Produit {id_produit} introuvable.")


def commander_suggestions():
    """Crée un bon de commande pour chaque produit suggéré. Renvoie le nombre créé."""
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(SQL_SUGGESTIONS)
        suggestions = cur.fetchall()
        for s in suggestions:
            cur.execute(
                """INSERT INTO dbo.commandes (id_produit, id_fournisseur, quantite_commandee)
                   SELECT id, id_fournisseur, ? FROM dbo.produits WHERE id = ?""",
                (int(s.quantite_a_commander), int(s.id_produit)),
            )
    return len(suggestions)


def recevoir_commande(id_commande):
    """Marque une commande comme livrée ET ajoute l'ENTREE de stock correspondante.

    Les deux écritures sont dans la même transaction : on ne peut pas se
    retrouver avec une commande 'Livré' sans stock ajouté (ou l'inverse).
    """
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(
            """SELECT id_produit, quantite_commandee
               FROM dbo.commandes WITH (UPDLOCK, ROWLOCK)
               WHERE id = ? AND statut = 'En attente'""",
            (id_commande,),
        )
        cmd = cur.fetchone()
        if cmd is None:
            raise CommandeIntrouvable(f"Commande {id_commande} introuvable ou déjà traitée.")

        cur.execute(
            """INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement)
               VALUES (?, ?, 'ENTREE')""",
            (cmd.id_produit, cmd.quantite_commandee),
        )
        cur.execute("UPDATE dbo.commandes SET statut = 'Livré' WHERE id = ?", (id_commande,))
    return cmd.id_produit, cmd.quantite_commandee


def annuler_commande(id_commande):
    with connexion() as conn:
        cur = conn.cursor()
        cur.execute(
            "UPDATE dbo.commandes SET statut = 'Annulé' WHERE id = ? AND statut = 'En attente'",
            (id_commande,),
        )
        if cur.rowcount != 1:
            raise CommandeIntrouvable(f"Commande {id_commande} introuvable ou déjà traitée.")
