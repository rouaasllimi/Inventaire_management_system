import pyodbc

# Connexion à la base de données
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=localhost\\SQLEXPRESS;'  
    'DATABASE=BaseInventaire;'
    'Trusted_Connection=yes;'
)

cursor = conn.cursor()

try:
    # 1. Demander à l'utilisateur l'ID du produit et la quantité
    id_produit = int(input("Product ID: "))
    quantite_vendue = int(input("Quantity to sell: "))

    # 2. Vérifier le stock actuel
    cursor.execute("""
        SELECT COALESCE(SUM(quantite_variation), 0)
        FROM mouvements_stock
        WHERE id_produit = ?
    """, (id_produit,))
    stock_actuel = cursor.fetchone()[0]

    if stock_actuel < quantite_vendue:
        print(f"Insufficient stock! Current stock: {stock_actuel}")
    else:
        # 3. Insérer le mouvement de vente
        cursor.execute("""
            INSERT INTO mouvements_stock (id_produit, quantite_variation, type_mouvement)
            VALUES (?, ?, 'VENTE')
        """, (id_produit, -quantite_vendue))

        conn.commit()
        print(f"Sale successful. New stock: {stock_actuel - quantite_vendue}")

except Exception as e:
    conn.rollback()
    print(f"Error: {e}")

finally:
    cursor.close()
    conn.close()