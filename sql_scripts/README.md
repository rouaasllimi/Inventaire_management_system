# Système de gestion d'inventaire avec alertes de stock bas

Un projet complet de gestion de stock qui suit les produits, les mouvements, et alerte automatiquement lorsque le niveau de stock passe sous un seuil critique.  
L'ensemble inclut une base de données relationnelle, des scripts Python pour les ventes et l'automatisation, et un tableau de bord Power BI.

---

## Fonctionnalités

- Base de données relationnelle SQL Server avec 4 tables : `fournisseurs`, `produits`, `mouvements_stock`, `commandes`
- Script Python de caisse : enregistrer une vente (décrémente le stock et journalise le mouvement)
- Export quotidien automatique des produits en alerte au format CSV
- Envoi optionnel du CSV par email (via Gmail SMTP)
- Tableau de bord Power BI dynamique connecté à la base de données :
  - État des stocks avec alertes visuelles (rouge/vert)
  - Nombre de produits en alerte
  - Stock par fournisseur
  - Performance fournisseurs (commandes livrées/en attente)
  - Liste de réapprovisionnement suggérée

---

## Technologies utilisées

- **Base de données** : Microsoft SQL Server 2022 (Express/Developer)
- **Langage de requêtes** : T‑SQL
- **Scripts** : Python 3 (pyodbc, csv, smtplib, email)
- **Automatisation** : Windows Task Scheduler (ou cron)
- **Dataviz** : Power BI Desktop (DAX)

---

## Structure du projet
├── sql_scripts/
│ ├── create_tables.sql # Création des tables et insertion des données de test
│ └── queries_phase2.sql # Requêtes : stock actuel, alertes, réapprovisionnement
├── python_scripts/
│ ├── vendres.py # CLI pour vendre un produit
│ └── alerte_stock.py # Script d'export CSV + envoi email automatique
├── dashboard/
│ ├── Inventaire_Dashboard.pbix # Fichier Power BI
│ └── dashboard_screenshot.png # Aperçu du tableau de bord
└── README.md

---

##  Mise en route

### Prérequis

- SQL Server (Express ou Developer) avec SSMS
- Python 3 et les bibliothèques : `pip install pyodbc`
- Power BI Desktop (optionnel, pour visualiser le fichier `.pbix`)
- Pour l'email : un compte Gmail avec un mot de passe d'application (si l'envoi est activé)

### 1. Base de données

1. Ouvrir SSMS et exécuter le script `sql_scripts/create_tables.sql` qui :
   - Crée la base `BaseInventaire`
   - Crée les tables `fournisseurs`, `produits`, `mouvements_stock`, `commandes`
   - Insère un jeu de données fictif mais réaliste
2. Exécuter éventuellement `queries_phase2.sql` pour tester les vues d'alerte.

### 2. Scripts Python
### 2. Scripts Python

- **vendres.py** – Interface en ligne de commande pour vendre un produit. Vérifie le stock disponible, insère un mouvement `VENTE` et affiche le nouveau stock.
- **alerte_stock.py** – Interroge la base de données pour identifier les produits sous le seuil de réapprovisionnement, exporte la liste en CSV horodaté et l’envoie par email 