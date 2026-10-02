"""Exporte les produits à commander en CSV et l'envoie par email (si configuré).

À planifier chaque jour avec le Planificateur de tâches Windows (ou cron).
Les produits déjà couverts par une commande en attente sont exclus.
"""
import csv
import smtplib
from datetime import date
from email.message import EmailMessage
from pathlib import Path

import config
from inventaire import SQL_SUGGESTIONS, requete

ENTETE = ["ID Produit", "Produit", "Fournisseur", "Stock actuel",
          "Déjà commandé", "Seuil", "Quantité à commander", "Coût estimé"]


def exporter_csv(lignes):
    dossier = Path(config.EXPORT_DIR)
    dossier.mkdir(parents=True, exist_ok=True)
    chemin = dossier / f"reorder_{date.today()}.csv"
    # utf-8-sig + ';' : s'ouvre correctement dans Excel en version française
    with open(chemin, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f, delimiter=";")
        writer.writerow(ENTETE)
        writer.writerows(lignes)
    return chemin


def envoyer_email(chemin, nb_produits):
    if not (config.SMTP_USER and config.SMTP_PASSWORD and config.ALERT_RECIPIENT):
        print("Email non configuré (SMTP_USER / SMTP_PASSWORD / ALERT_RECIPIENT) : envoi ignoré.")
        return

    msg = EmailMessage()
    msg["Subject"] = f"Alerte stock - {date.today()}"
    msg["From"] = config.SMTP_USER
    msg["To"] = config.ALERT_RECIPIENT
    msg.set_content(f"{nb_produits} produit(s) à réapprovisionner au {date.today()}. Voir pièce jointe.")
    msg.add_attachment(chemin.read_bytes(), maintype="text", subtype="csv", filename=chemin.name)

    with smtplib.SMTP_SSL(config.SMTP_HOST, config.SMTP_PORT) as smtp:
        smtp.login(config.SMTP_USER, config.SMTP_PASSWORD)
        smtp.send_message(msg)
    print("Email envoyé.")


def main():
    _, lignes = requete(SQL_SUGGESTIONS)
    if not lignes:
        print("Aucun produit à commander.")
        return

    # Colonnes de SQL_SUGGESTIONS dans l'ordre de ENTETE
    chemin = exporter_csv(lignes)
    print(f"CSV exporté : {chemin} ({len(lignes)} produit(s))")
    envoyer_email(chemin, len(lignes))


if __name__ == "__main__":
    main()
