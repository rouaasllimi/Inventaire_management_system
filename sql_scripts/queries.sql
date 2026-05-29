
1. Stock actuel par produit

SELECT 
    p.id AS id_produit,
    p.nom,
    COALESCE(SUM(ms.quantite_variation), 0) AS stock_actuel,
    p.seuil_reapprovisionnement,
    p.prix_unitaire,
    f.nom AS nom_fournisseur
FROM produits p
LEFT JOIN mouvements_stock ms ON p.id = ms.id_produit
LEFT JOIN fournisseurs f ON p.id_fournisseur = f.id
GROUP BY p.id, p.nom, p.seuil_reapprovisionnement, p.prix_unitaire, f.nom
ORDER BY p.nom;
2. Produits en dessous du seuil de réapprovisionnement (alerte de stock faible)
WITH stock_actuel AS (
    SELECT 
        p.id,
        p.nom,
        p.seuil_reapprovisionnement,
        COALESCE(SUM(ms.quantite_variation), 0) AS qte_stock
    FROM produits p
    LEFT JOIN mouvements_stock ms ON p.id = ms.id_produit
    GROUP BY p.id, p.nom, p.seuil_reapprovisionnement
)
SELECT 
    id AS id_produit,
    nom,
    qte_stock AS stock_actuel,
    seuil_reapprovisionnement,
    (seuil_reapprovisionnement - qte_stock) AS manque
FROM stock_actuel
WHERE qte_stock < seuil_reapprovisionnement
ORDER BY manque DESC;


3. Liste de bons de commande suggérés (quoi commander, en quelle quantité, auprès de quel fournisseur)
sql
WITH stock_actuel AS (
    SELECT 
        p.id,
        p.nom,
        p.seuil_reapprovisionnement,
        p.id_fournisseur,
        COALESCE(SUM(ms.quantite_variation), 0) AS qte_stock
    FROM produits p
    LEFT JOIN mouvements_stock ms ON p.id = ms.id_produit
    GROUP BY p.id, p.nom, p.seuil_reapprovisionnement, p.id_fournisseur
)
SELECT 
    s.id AS id_produit,
    s.nom AS produit,
    f.nom AS fournisseur,
    f.email_contact,
    f.delai_livraison_jours,
    s.qte_stock AS stock_actuel,
    s.seuil_reapprovisionnement,
    (s.seuil_reapprovisionnement - s.qte_stock) AS quantite_suggeree,
    -- Optionally, add a buffer (e.g. 20% extra)
    CEILING((s.seuil_reapprovisionnement - s.qte_stock) * 1.2) AS quantite_avec_marge
FROM stock_actuel s
JOIN fournisseurs f ON s.id_fournisseur = f.id
WHERE s.qte_stock < s.seuil_reapprovisionnement
ORDER BY f.nom, s.nom;