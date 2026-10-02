# 📦 Système de gestion d'inventaire avec alertes de stock

Projet complet de gestion de stock : base de données relationnelle, application web, automatisation des alertes et tableau de bord Power BI. Il suit les produits et leurs mouvements, signale les stocks faibles et aide à décider **quoi commander, en quelle quantité et auprès de qui**.

<!-- TODO : ajouter une capture ou un GIF de l'application Streamlit -->
![Application Streamlit](docs/app_screenshot.png)

<!-- TODO : ajouter la capture du tableau de bord Power BI -->
![Tableau de bord Power BI](dashboard/dashboard_screenshot.png)

---

## Fonctionnalités

- **Base SQL Server** avec 4 tables (`fournisseurs`, `produits`, `mouvements_stock`, `commandes`) et une vue `vw_stock_actuel` réutilisée partout
- **Application Streamlit** :
  - tableau de bord (stock, produits en alerte, valeur du stock)
  - enregistrement des ventes
  - bons de commande suggérés, avec création en un clic
  - suivi des commandes : réception (ajoute automatiquement le stock) ou annulation
- **Script de caisse en ligne de commande** (`vendres.py`) : vente atomique, sans risque de stock négatif
- **Alerte quotidienne** (`alerte_stock.py`) : export CSV des produits à commander et envoi optionnel par email
- **Tableau de bord Power BI** connecté à la base : alertes visuelles, stock par produit, suivi des commandes fournisseurs

---

## Règles métier

| Règle | Détail |
|---|---|
| Stock actuel | Somme des mouvements de stock du produit (`ENTREE` positif, `VENTE` et `SORTIE` négatifs) |
| Produit en alerte | Stock actuel **<** seuil de réapprovisionnement |
| Rupture | Stock actuel ≤ 0 |
| Produit à commander | Stock **+ commandes en attente** < seuil (un produit déjà commandé n'est pas recommandé deux fois) |
| Quantité suggérée | De quoi atteindre un niveau cible de **2 × le seuil** (paramètre `NIVEAU_CIBLE` dans `config.py`), pour éviter de retomber en alerte dès la livraison |
| Réception d'une commande | Passe la commande à `Livré` **et** ajoute le mouvement `ENTREE` dans une même transaction |

---

## Choix techniques

- **Journal de mouvements plutôt qu'une colonne « stock »** : on conserve tout l'historique (traçabilité, audit, analyses de ventes) et le stock ne peut pas se désynchroniser.
- **Transactions et verrous** : la vente lit le stock avec `WITH (UPDLOCK, HOLDLOCK)` dans la même transaction que l'insertion. Deux ventes simultanées du même produit sont sérialisées, le stock ne devient jamais négatif.
- **Contraintes en base** (`CHECK`) : statuts valides, quantités positives, signe cohérent avec le type de mouvement.
- **Une seule source de vérité** : la vue `vw_stock_actuel` est utilisée par l'application, le script d'alerte, les requêtes d'analyse et Power BI.
- **Aucun secret dans le code** : identifiants email via variables d'environnement (`.env`, ignoré par Git).
- **Logique métier centralisée** dans `inventaire.py`, partagée par l'application et les scripts.

---

## Technologies

- **Base de données** : Microsoft SQL Server 2022 (Express / Developer), T‑SQL (CTE, vues, `OUTER APPLY`, fonctions de date)
- **Python 3** : `pyodbc`, `pandas`, `streamlit`, `smtplib`, `csv`
- **Dataviz** : Power BI Desktop (DAX)
- **Automatisation** : Planificateur de tâches Windows (ou cron)

---

## Structure du projet

```
├── sql_scripts/
│   ├── create_tables.sql        # Tables, contraintes, index, vue et données de test
│   └── queries.sql              # 7 requêtes d'analyse (alertes, commandes, ventes, couverture...)
├── python_scripts/
│   ├── config.py                # Configuration (variables d'environnement)
│   ├── inventaire.py            # Accès aux données et logique métier
│   ├── app.py                   # Application Streamlit
│   ├── vendres.py               # Caisse en ligne de commande
│   ├── alerte_stock.py          # Export CSV + email
│   └── requirements.txt
├── dashboard/
│   ├── Inventaire_Dashboard.pbix
│   └── dashboard_screenshot.png
├── docs/
│   └── app_screenshot.png
├── .env.example
├── .gitignore
└── README.md
```

---

## Mise en route

### Prérequis

- SQL Server (Express ou Developer) et SSMS
- [ODBC Driver 17 for SQL Server](https://learn.microsoft.com/fr-fr/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Python 3.9+
- Power BI Desktop (optionnel, pour ouvrir le fichier `.pbix`)

### 1. Base de données

Ouvrir `sql_scripts/create_tables.sql` dans SSMS et l'exécuter. Le script crée la base `BaseInventaire`, les tables, la vue et un jeu de données fictif. Il peut être relancé à tout moment, mais **il réinitialise les données**.

### 2. Environnement Python

```bash
pip install -r python_scripts/requirements.txt
```

Copier `.env.example` en `.env` et l'adapter (nom du serveur, et paramètres email si besoin). Par défaut : `localhost\SQLEXPRESS` avec l'authentification Windows.

### 3. Lancer l'application

```bash
streamlit run python_scripts/app.py
```

---

## Utilisation

### Vendre un produit en ligne de commande

```bash
python python_scripts/vendres.py
```

### Générer l'alerte de stock

```bash
python python_scripts/alerte_stock.py
```

Le CSV `reorder_AAAA-MM-JJ.csv` est créé dans le dossier `exports/`. Les produits déjà couverts par une commande en attente en sont exclus. L'email n'est envoyé que si `SMTP_USER`, `SMTP_PASSWORD` et `ALERT_RECIPIENT` sont renseignés dans `.env` (utiliser un **mot de passe d'application** Gmail).

**Planification quotidienne (Windows)** : Planificateur de tâches → Créer une tâche de base → action « Démarrer un programme » → `python` avec l'argument `chemin\vers\python_scripts\alerte_stock.py`.

---

## Tableau de bord Power BI

Le fichier `dashboard/Inventaire_Dashboard.pbix` se connecte à la base `BaseInventaire`. Il contient :

- l'état des stocks avec mise en forme conditionnelle (rouge sous le seuil)
- le nombre de produits en alerte
- le stock par produit
- les commandes fournisseurs livrées / en attente
- la liste de réapprovisionnement suggérée

---

## Pistes d'amélioration

- Quantité suggérée basée sur les ventes moyennes et le délai de livraison du fournisseur
- Authentification et gestion des rôles dans l'application
- Tests automatisés de la couche `inventaire.py`
- Déploiement (Docker, SQL Server hébergé)
