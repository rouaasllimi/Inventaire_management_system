CREATE DATABASE BaseInventaire;


USE BaseInventaire;


-- Fournisseurs
CREATE TABLE fournisseurs (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nom NVARCHAR(100) NOT NULL,
    email_contact NVARCHAR(150),
    delai_livraison_jours INT
);

-- Produits
CREATE TABLE produits (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nom NVARCHAR(100) NOT NULL,
    sku NVARCHAR(50) UNIQUE,
    seuil_reapprovisionnement INT DEFAULT 10,
    prix_unitaire DECIMAL(10,2),
    id_fournisseur INT REFERENCES fournisseurs(id)
);

-- Mouvements de stock (journal des transactions)
CREATE TABLE mouvements_stock (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_produit INT NOT NULL REFERENCES produits(id),
    quantite_variation INT NOT NULL,
    type_mouvement NVARCHAR(10) NOT NULL CHECK (type_mouvement IN ('ENTREE', 'SORTIE', 'VENTE')),
    date_creation DATETIME2 DEFAULT GETDATE()
);

-- Commandes (bons de commande aux fournisseurs)
CREATE TABLE commandes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_produit INT NOT NULL REFERENCES produits(id),
    quantite_commandee INT NOT NULL,
    date_commande DATE DEFAULT GETDATE(),
    id_fournisseur INT REFERENCES fournisseurs(id),
    statut NVARCHAR(20) DEFAULT 'En attente'
);
GO

-- Insertion des fournisseurs
INSERT INTO fournisseurs (nom, email_contact, delai_livraison_jours)
VALUES ('Global Supplies', 'orders@globalsupplies.com', 5),
       ('TechParts Co.', 'sales@techparts.com', 3),
       ('Metro Wholesale', 'sales@metrowholesale.com', 7),
       ('FastParts LLC', 'orders@fastparts.com', 2),
       ('EcoSupply', 'contact@ecosupply.com', 10)

-- Insertion des produits (sans la colonne sku)
INSERT INTO produits (nom, seuil_reapprovisionnement, prix_unitaire, id_fournisseur)
VALUES 
('Widget A', 15, 9.99, 1),
('Gadget B', 10, 24.99, 2),
('Bolt M6', 50, 0.15, 1),
('Sensor Pro X', 12, 45.00, 3),
('LED Panel 60W', 8, 29.95, 4),
('USB-C Cable 2m', 25, 6.49, 1),
('Aluminium Frame', 5, 14.00, 2),
('Thermal Paste', 30, 3.99, 5),
('Mounting Bracket', 10, 0.89, 1),
('Power Supply 500W', 6, 54.99, 4);
-- Stock initial (mouvements ENTREE)
INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES 
(1, 20, 'ENTREE', '2026-05-10'),
(2, 8, 'ENTREE', '2026-05-10'),
(3, 200, 'ENTREE', '2026-05-10'),
(4, 20, 'ENTREE', '2026-05-10'),
(5, 10, 'ENTREE', '2026-05-12'),
(6, 40, 'ENTREE', '2026-05-13'),
(7, 6, 'ENTREE', '2026-05-14'),
(8, 50, 'ENTREE', '2026-05-15'),
(9, 15, 'ENTREE', '2026-05-16'),
(10, 8, 'ENTREE', '2026-05-17');

-- Réapprovisionnements supplémentaires
INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES 
(1, 10, 'ENTREE', '2026-05-18'),
(2, 12, 'ENTREE', '2026-05-19'),
(3, 100, 'ENTREE', '2026-05-20');

-- Ventes
INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
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
-- USB-C Cable (seuil 25)
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

-- Ajustements de stock (dommages, retours fournisseur)
INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement, date_creation)
VALUES 
(6, -1, 'SORTIE', '2026-05-23'),  
(8, -3, 'SORTIE', '2026-05-26'),    
(3, -5, 'SORTIE', '2026-05-22'); 

-- Commandes fournisseurs (historique)
INSERT INTO commandes (id_produit, quantite_commandee, date_commande, id_fournisseur, statut)
VALUES 
(1, 20, '2026-05-11', 1, 'Livré'),
(2, 15, '2026-05-12', 2, 'Livré'),
(4, 25, '2026-05-09', 3, 'Livré'),
(7, 6, '2026-05-14', 2, 'Livré'),
(9, 15, '2026-05-16', 1, 'Livré'),
(10, 8, '2026-05-17', 4, 'Livré'),
(5, 10, '2026-05-24', 4, 'En attente'),
(4, 20, '2026-05-25', 3, 'En attente'),
(2, 10, '2026-05-26', 2, 'En attente');