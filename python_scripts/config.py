"""Configuration centralisée : aucune information sensible n'est écrite dans le code.

Les valeurs viennent des variables d'environnement (ou d'un fichier .env
si python-dotenv est installé). Voir .env.example.
"""
import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:  # python-dotenv est optionnel
    pass

# --- Base de données (authentification Windows) ---
DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
DB_SERVER = os.getenv("DB_SERVER", r"localhost\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "BaseInventaire")

CONN_STR = (
    f"DRIVER={{{DB_DRIVER}}};"
    f"SERVER={DB_SERVER};"
    f"DATABASE={DB_NAME};"
    "Trusted_Connection=yes;"
)

# --- Règle de réapprovisionnement ---
# On commande jusqu'à NIVEAU_CIBLE x seuil (et pas seulement jusqu'au seuil,
# sinon le produit retombe en alerte dès la livraison).
NIVEAU_CIBLE = 2

# --- Export CSV ---
EXPORT_DIR = os.getenv("EXPORT_DIR", "exports")

# --- Email (optionnel) : mot de passe d'application Gmail ---
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
ALERT_RECIPIENT = os.getenv("ALERT_RECIPIENT")
