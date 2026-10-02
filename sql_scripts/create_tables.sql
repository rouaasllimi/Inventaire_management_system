/* =====================================================================
   BaseInventaire - Création de la base, des tables, des vues et des
   données de test.
   Ce script peut être ré-exécuté : il recrée les tables à chaque fois.
   ATTENTION : toutes les données existantes seront supprimées.
   ===================================================================== */

IF DB_ID('BaseInventaire') IS NULL
    CREATE DATABASE BaseInventaire;
GO

USE BaseInventaire;
GO

-- ---------------------------------------------------------------------
-- 0. Nettoyage (ordre inverse des dépendances)
-- ---------------------------------------------------------------------
DROP VIEW  IF EXISTS dbo.vw_stock_actuel;
DROP TABLE IF EXISTS dbo.commandes;
DROP TABLE IF EXISTS dbo.mouvements_stock;
DROP TABLE IF EXISTS dbo.produits;
DROP TABLE IF EXISTS dbo.fournisseurs;
GO

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

-- Fournisseurs
CREATE TABLE dbo.fournisseurs (
    id                    INT IDENTITY(1,1) PRIMARY KEY,
    nom                   NVARCHAR(100) NOT NULL,
    email_contact         NVARCHAR(150),
    delai_livraison_jours INT CHECK (delai_livraison_jours >= 0)
);

-- Produits
CREATE TABLE dbo.produits (
    id                        INT IDENTITY(1,1) PRIMARY KEY,
    nom                       NVARCHAR(100) NOT NULL,
    sku                       NVARCHAR(50)  NOT NULL UNIQUE,
    seuil_reapprovisionnement INT NOT NULL DEFAULT 10
                              CHECK (seuil_reapprovisionnement >= 0),
    prix_unitaire             DECIMAL(10,2) CHECK (prix_unitaire >= 0),
    id_fournisseur            INT NOT NULL REFERENCES dbo.fournisseurs(id)
);

-- Mouvements de stock (journal des transactions : le stock = somme des mouvements)
CREATE TABLE dbo.mouvements_stock (
    id                 INT IDENTITY(1,1) PRIMARY KEY,
    id_produit         INT NOT NULL REFERENCES dbo.produits(id),
    quantite_variation INT NOT NULL CHECK (quantite_variation <> 0),
    type_mouvement     NVARCHAR(10) NOT NULL
                       CHECK (type_mouvement IN ('ENTREE', 'SORTIE', 'VENTE')),
    date_creation      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    -- Cohérence du signe : une entrée est positive, une vente/sortie négative
    CONSTRAINT CK_mouvement_signe CHECK (
        (type_mouvement = 'ENTREE' AND quantite_variation > 0) OR
        (type_mouvement IN ('VENTE', 'SORTIE') AND quantite_variation < 0)
    )
);

-- Commandes (bons de commande aux fournisseurs)
CREATE TABLE dbo.commandes (
    id                 INT IDENTITY(1,1) PRIMARY KEY,
    id_produit         INT NOT NULL REFERENCES dbo.produits(id),
    id_fournisseur     INT NOT NULL REFERENCES dbo.fournisseurs(id),
    quantite_commandee INT NOT NULL CHECK (quantite_commandee > 0),
    date_commande      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    statut             NVARCHAR(20) NOT NULL DEFAULT 'En attente'
                       CHECK (statut IN ('En attente', 'Livré', 'Annulé'))
);
GO

-- Index sur les clés étrangères (accélère les jointures et le calcul du stock)
CREATE INDEX IX_mouvements_produit ON dbo.mouvements_stock (id_produit) INCLUDE (quantite_variation, type_mouvement, date_creation);
CREATE INDEX IX_commandes_produit  ON dbo.commandes (id_produit, statut) INCLUDE (quantite_commandee);
CREATE INDEX IX_produits_fournisseur ON dbo.produits (id_fournisseur);
GO

-- ---------------------------------------------------------------------
-- 2. Vue réutilisable : stock actuel + commandes en attente
--    (utilisée par queries.sql, app.py, alerte_stock.py et Power BI)
-- ---------------------------------------------------------------------
CREATE VIEW dbo.vw_stock_actuel AS
SELECT
    p.id                        AS id_produit,
    p.nom                       AS produit,
    p.sku,
    p.prix_unitaire,
    p.seuil_reapprovisionnement,
    f.id                        AS id_fournisseur,
    f.nom                       AS fournisseur,
    f.email_contact,
    f.delai_livraison_jours,
    s.stock_actuel,
    c.en_commande,
    CASE
        WHEN s.stock_actuel <= 0                                THEN 'Rupture'
        WHEN s.stock_actuel < p.seuil_reapprovisionnement       THEN 'Stock faible'
        ELSE 'OK'
    END AS statut_stock
FROM dbo.produits p
JOIN dbo.fournisseurs f ON f.id = p.id_fournisseur
OUTER APPLY (
    SELECT COALESCE(SUM(ms.quantite_variation), 0) AS stock_actuel
    FROM dbo.mouvements_stock ms
    WHERE ms.id_produit = p.id
) s
OUTER APPLY (
    SELECT COALESCE(SUM(co.quantite_commandee), 0) AS en_commande
    FROM dbo.commandes co
    WHERE co.id_produit = p.id AND co.statut = 'En attente'
) c;
GO

-- ---------------------------------------------------------------------
-- 3. Données de test
-- ---------------------------------------------------------------------

INSERT INTO dbo.fournisseurs (nom, email_contact, delai_livraison_jours)
VALUES ('Global Supplies', 'orders@globalsupplies.com', 5),
       ('TechParts Co.',   'sales@techparts.com',       3),
       ('Metro Wholesale', 'sales@metrowholesale.com',  7),
       ('FastParts LLC',   'orders@fastparts.com',      2),
       ('EcoSupply',       'contact@ecosupply.com',    10);

INSERT INTO dbo.produits (nom, sku, seuil_reapprovisionnement, prix_unitaire, id_fournisseur)
VALUES
('Widget A',          'WGT-A-001',  15,  9.99, 1),
('Gadget B',          'GDG-B-002',  10, 24.99, 2),
('Bolt M6',           'BLT-M6-003', 50,  0.15, 1),
('Sensor Pro X',      'SNS-PX-004', 12, 45.00, 3),
('LED Panel 60W',     'LED-60-005',  8, 29.95, 4),
('USB-C Cable 2m',    'USB-C2-006', 25,  6.49, 1),
('Aluminium Frame',   'ALU-FR-007',  5, 14.00, 2),
('Thermal Paste',     'THP-001-008',30,  3.99, 5),
('Mounting Bracket',  'MNT-BR-009', 10,  0.89, 1),
('Power Supply 500W', 'PSU-500-010', 6, 54.99, 4);

-- Stock initial
INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES
(1, 20,  'ENTREE', '2026-05-10'),
(2, 8,   'ENTREE', '2026-05-10'),
(3, 200, 'ENTREE', '2026-05-10'),
(4, 20,  'ENTREE', '2026-05-10'),
(5, 10,  'ENTREE', '2026-05-12'),
(6, 40,  'ENTREE', '2026-05-13'),
(7, 6,   'ENTREE', '2026-05-14'),
(8, 50,  'ENTREE', '2026-05-15'),
(9, 15,  'ENTREE', '2026-05-16'),
(10, 8,  'ENTREE', '2026-05-17');

-- Réapprovisionnements supplémentaires
INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES
(1, 10,  'ENTREE', '2026-05-18'),
(2, 12,  'ENTREE', '2026-05-19'),
(3, 100, 'ENTREE', '2026-05-20');

-- Ventes
INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES
-- Widget A (seuil 15)
(1, -2, 'VENTE', '2026-05-18'),
(1, -3, 'VENTE', '2026-05-20'),
(1, -5, 'VENTE', '2026-05-22'),
(1, -4, 'VENTE', '2026-05-25'),
(1, -2, 'VENTE', '2026-05-27'),
-- Gadget B (seuil 10)
(2, -7, 'VENTE', '2026-05-20'),
(2, -4, 'VENTE', '2026-05-23'),
(2, -3, 'VENTE', '2026-05-26'),
-- Bolt M6 (seuil 50)
(3, -20, 'VENTE', '2026-05-19'),
(3, -15, 'VENTE', '2026-05-21'),
(3, -10, 'VENTE', '2026-05-24'),
(3, -30, 'VENTE', '2026-05-26'),
-- Sensor Pro X (seuil 12)
(4, -5, 'VENTE', '2026-05-15'),
(4, -4, 'VENTE', '2026-05-18'),
(4, -6, 'VENTE', '2026-05-22'),
-- LED Panel 60W (seuil 8)
(5, -2, 'VENTE', '2026-05-17'),
(5, -1, 'VENTE', '2026-05-20'),
(5, -3, 'VENTE', '2026-05-24'),
-- USB-C Cable 2m (seuil 25)
(6, -10, 'VENTE', '2026-05-18'),
(6, -12, 'VENTE', '2026-05-22'),
-- Aluminium Frame (seuil 5)
(7, -1, 'VENTE', '2026-05-20'),
(7, -2, 'VENTE', '2026-05-25'),
-- Thermal Paste (seuil 30)
(8, -15, 'VENTE', '2026-05-21'),
(8, -10, 'VENTE', '2026-05-25'),
-- Mounting Bracket (seuil 10)
(9, -8, 'VENTE', '2026-05-23'),
-- Power Supply 500W (seuil 6)
(10, -1, 'VENTE', '2026-05-20'),
(10, -2, 'VENTE', '2026-05-26');

-- Ajustements de stock (casse, retours fournisseur)
INSERT INTO dbo.mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES
(6, -1, 'SORTIE', '2026-05-23'),
(8, -3, 'SORTIE', '2026-05-26'),
(3, -5, 'SORTIE', '2026-05-22');

-- Commandes fournisseurs (historique) : id_fournisseur = fournisseur du produit
INSERT INTO dbo.commandes (id_produit, quantite_commandee, date_commande, id_fournisseur, statut)
VALUES
(1, 20, '2026-05-11', 1, 'Livré'),
(2, 15, '2026-05-12', 2, 'Livré'),
(4, 25, '2026-05-09', 3, 'Livré'),
(7, 6,  '2026-05-14', 2, 'Livré'),
(9, 15, '2026-05-16', 1, 'Livré'),
(10, 8, '2026-05-17', 4, 'Livré'),
(5, 10, '2026-05-24', 4, 'En attente'),
(4, 20, '2026-05-25', 3, 'En attente'),
(2, 10, '2026-05-26', 2, 'En attente');
GO

-- Vérification rapide
SELECT * FROM dbo.vw_stock_actuel ORDER BY produit;
GO
