import pyodbc
import csv
from datetime import date
import os

# 1. Connexion à la base de données
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=localhost\\SQLEXPRESS;'  
    'DATABASE=BaseInventaire;'
    'Trusted_Connection=yes;'
)
cursor = conn.cursor()

# 2. Requête pour les produits en stock faible
query = """
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
        s.id,
        s.nom,
        f.nom AS fournisseur,
        s.qte_stock,
        s.seuil_reapprovisionnement,
        (s.seuil_reapprovisionnement - s.qte_stock) AS manque
    FROM stock_actuel s
    JOIN fournisseurs f ON s.id_fournisseur = f.id
    WHERE s.qte_stock < s.seuil_reapprovisionnement
    ORDER BY f.nom, s.nom;
"""

cursor.execute(query)
rows = cursor.fetchall()

# 3. Écrire le CSV directement sur le Bureau
desktop_path = os.path.join(os.path.expanduser("~"), "Desktop")
filename = os.path.join(desktop_path, f"reorder_{date.today()}.csv")

with open(filename, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    # En-tête
    writer.writerow(['ID Produit', 'Produit', 'Fournisseur', 'Stock Actuel', 'Seuil', 'Manque'])
    # Données
    for row in rows:
        writer.writerow(row)

print(f"CSV exporté sur le Bureau : {filename}")

# 4. Envoyer le CSV par email
import smtplib
from email.message import EmailMessage

sender = "------@gmail.com"
password = "*********"      
recipient = "------@gmail.com"

msg = EmailMessage()
msg['Subject'] = f"Alerte Stock - {date.today()}"
msg['From'] = sender
msg['To'] = recipient
msg.set_content(f"Liste des produits à réapprovisionner du {date.today()}.")

with open(filename, 'rb') as f:
    msg.add_attachment(f.read(), maintype='application', subtype='octet-stream', filename=os.path.basename(filename))
    
with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
    smtp.login(sender, password)
    smtp.send_message(msg)
    print("Email envoyé.")

cursor.close()
conn.close()