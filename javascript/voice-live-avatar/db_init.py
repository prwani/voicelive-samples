import sqlite3
import os

# Database file path
DB_PATH = os.path.join(os.path.dirname(__file__), 'payment_db.sqlite')

def init_database():
    """Initialize the SQLite database and create the customer_payment_details table."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create table with simple SQL query
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS customer_payment_details (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            policy_number TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            amount_due REAL NOT NULL,
            payment_date TEXT NOT NULL,
            payment_status TEXT NOT NULL
        )
    ''')
    
    conn.commit()
    conn.close()
    print(f"Database initialized at {DB_PATH}")

if __name__ == "__main__":
    init_database()
