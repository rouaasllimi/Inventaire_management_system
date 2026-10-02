/* =====================================================================
   BaseInventaire - Requêtes d'analyse
   Prérequis : avoir exécuté create_tables.sql (crée la vue vw_stock_actuel)
   Chaque requête est indépendante : sélectionnez-la et exécutez-la.
   ===================================================================== */

USE BaseInventaire1;
GO

-- ---------------------------------------------------------------------
-- 1. Stock actuel par produit
-- ---------------------------------------------------------------------
SELECT id_produit, produit, sku, fournisseur,
       stock_actuel, seuil_reapprovisionnement, en_commande, statut_stock
FROM dbo.vw_stock_actuel
ORDER BY produit;


-- ---------------------------------------------------------------------
-- 2. Alertes de stock faible
--    Un produit est en alerte si stock < seuil.
--    On affiche aussi ce qui est déjà commandé pour éviter les doublons.
-- ---------------------------------------------------------------------
SELECT id_produit, produit, fournisseur,
       stock_actuel, seuil_reapprovisionnement,
       seuil_reapprovisionnement - stock_actuel AS manque,
       en_commande,
       CASE WHEN stock_actuel + en_commande >= seuil_reapprovisionnement
            THEN 'Couvert par commande en cours'
            ELSE 'À commander' END AS action
FROM dbo.vw_stock_actuel
WHERE stock_actuel < seuil_reapprovisionnement
ORDER BY manque DESC;


-- ---------------------------------------------------------------------
-- 3. Bons de commande suggérés
--    Règle : on commande si (stock + commandes en attente) < seuil.
--    Quantité = remonter jusqu'à un niveau cible de 2 x seuil,
--    sinon on retombe en alerte juste après la livraison.
-- ---------------------------------------------------------------------
SELECT id_produit, produit, fournisseur, email_contact,
       delai_livraison_jours,
       DATEADD(DAY, delai_livraison_jours, CAST(GETDATE() AS DATE)) AS livraison_estimee,
       stock_actuel, en_commande, seuil_reapprovisionnement,
       2 * seuil_reapprovisionnement - (stock_actuel + en_commande) AS quantite_a_commander,
       CAST((2 * seuil_reapprovisionnement - (stock_actuel + en_commande))
            * prix_unitaire AS DECIMAL(10,2)) AS cout_estime
FROM dbo.vw_stock_actuel
WHERE stock_actuel + en_commande < seuil_reapprovisionnement
ORDER BY fournisseur, produit;


-- ---------------------------------------------------------------------
-- 4. Meilleures ventes (quantités et chiffre d'affaires)
-- ---------------------------------------------------------------------
SELECT p.nom AS produit,
       -SUM(ms.quantite_variation)                   AS quantite_vendue,
       -SUM(ms.quantite_variation) * p.prix_unitaire AS chiffre_affaires
FROM dbo.mouvements_stock ms
JOIN dbo.produits p ON p.id = ms.id_produit
WHERE ms.type_mouvement = 'VENTE'
GROUP BY p.nom, p.prix_unitaire
ORDER BY chiffre_affaires DESC;


-- ---------------------------------------------------------------------
-- 5. Tendance des ventes par semaine
-- ---------------------------------------------------------------------
SELECT DATEPART(YEAR, ms.date_creation) AS annee,
       DATEPART(ISO_WEEK, ms.date_creation) AS semaine,
       MIN(CAST(ms.date_creation AS DATE)) AS debut_periode,
       -SUM(ms.quantite_variation) AS unites_vendues,
       -SUM(ms.quantite_variation * p.prix_unitaire) AS chiffre_affaires
FROM dbo.mouvements_stock ms
JOIN dbo.produits p ON p.id = ms.id_produit
WHERE ms.type_mouvement = 'VENTE'
GROUP BY DATEPART(YEAR, ms.date_creation), DATEPART(ISO_WEEK, ms.date_creation)
ORDER BY annee, semaine;


-- ---------------------------------------------------------------------
-- 6. Jours de stock restants (couverture)
--    Ventes moyennes par jour = unités vendues / nombre de jours
--    entre la première et la dernière vente de la base.
-- ---------------------------------------------------------------------
WITH periode AS (
    SELECT DATEDIFF(DAY, MIN(date_creation), MAX(date_creation)) + 1 AS nb_jours
    FROM dbo.mouvements_stock
    WHERE type_mouvement = 'VENTE'
),
ventes AS (
    SELECT id_produit, -SUM(quantite_variation) AS unites_vendues
    FROM dbo.mouvements_stock
    WHERE type_mouvement = 'VENTE'
    GROUP BY id_produit
)
SELECT v.produit, v.stock_actuel, v.delai_livraison_jours,
       CAST(COALESCE(x.unites_vendues, 0) * 1.0 / pe.nb_jours AS DECIMAL(10,2)) AS ventes_par_jour,
       CAST(v.stock_actuel / NULLIF(COALESCE(x.unites_vendues, 0) * 1.0 / pe.nb_jours, 0)
            AS DECIMAL(10,1)) AS jours_restants,
       CASE WHEN v.stock_actuel / NULLIF(COALESCE(x.unites_vendues, 0) * 1.0 / pe.nb_jours, 0)
                 < v.delai_livraison_jours
            THEN 'Rupture avant livraison !' ELSE 'OK' END AS risque
FROM dbo.vw_stock_actuel v
LEFT JOIN ventes x ON x.id_produit = v.id_produit
CROSS JOIN periode pe
ORDER BY jours_restants;


-- ---------------------------------------------------------------------
-- 7. Performance fournisseurs (commandes livrées / en attente)
-- ---------------------------------------------------------------------
SELECT f.nom AS fournisseur,
       f.delai_livraison_jours,
       COUNT(c.id)                                         AS total_commandes,
       SUM(CASE WHEN c.statut = 'Livré'      THEN 1 ELSE 0 END) AS livrees,
       SUM(CASE WHEN c.statut = 'En attente' THEN 1 ELSE 0 END) AS en_attente
FROM dbo.fournisseurs f
LEFT JOIN dbo.commandes c ON c.id_fournisseur = f.id
GROUP BY f.nom, f.delai_livraison_jours
ORDER BY total_commandes DESC;
