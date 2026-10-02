"""Caisse en ligne de commande : enregistre une vente de façon atomique."""
from inventaire import InventaireError, vendre


def lire_entier(message):
    while True:
        try:
            valeur = int(input(message))
            if valeur > 0:
                return valeur
        except ValueError:
            pass
        print("Veuillez saisir un nombre entier strictement positif.")


def main():
    id_produit = lire_entier("ID du produit : ")
    quantite = lire_entier("Quantité à vendre : ")
    try:
        nouveau_stock = vendre(id_produit, quantite)
        print(f"Vente enregistrée. Nouveau stock : {nouveau_stock}")
    except InventaireError as e:
        print(f"Vente refusée : {e}")
    except Exception as e:
        print(f"Erreur inattendue : {e}")


if __name__ == "__main__":
    main()
