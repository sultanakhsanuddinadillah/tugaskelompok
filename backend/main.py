from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
import sqlite3
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

app = FastAPI()

# KONFIGURASI CORS: Agar aplikasi Flutter (Web/Mobile) bisa mengakses server ini
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- DATABASE SETUP ---
def get_db_connection():
    # Membuat file database bernama merchant_db.db
    conn = sqlite3.connect('merchant_db.db')
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    # Tabel untuk User (Login & Register)
    conn.execute('''CREATE TABLE IF NOT EXISTS users 
                    (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT)''')
    
    # Tabel untuk Transaksi Pendapatan
    conn.execute('''CREATE TABLE IF NOT EXISTS transactions 
                    (id INTEGER PRIMARY KEY AUTOINCREMENT, item_name TEXT, amount REAL, date TEXT)''')
    
    # Tabel untuk Profil Toko
    conn.execute('''CREATE TABLE IF NOT EXISTS store_profile 
                    (id INTEGER PRIMARY KEY, store_name TEXT, address TEXT)''')
    
    # Tabel untuk Master Barang (Produk yang dijual)
    conn.execute('''CREATE TABLE IF NOT EXISTS products 
                    (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, price REAL)''')
    conn.commit()
    conn.close()

# Jalankan inisialisasi database saat server mulai
init_db()

# --- DATA MODELS (Pydantic) ---
class User(BaseModel):
    username: str
    password: str

class Transaction(BaseModel):
    id: int | None = None
    item_name: str
    amount: float
    date: str

class StoreProfile(BaseModel):
    store_name: str
    address: str

class Product(BaseModel):
    id: int | None = None
    name: str
    price: float

# --- API AUTHENTICATION ---
@app.post("/register")
async def register(user: User):
    try:
        conn = get_db_connection()
        conn.execute('INSERT INTO users (username, password) VALUES (?, ?)', (user.username, user.password))
        conn.commit()
        return {"message": "Registrasi Berhasil"}
    except:
        raise HTTPException(status_code=400, detail="Username sudah digunakan")

@app.post("/login")
async def login(user: User):
    conn = get_db_connection()
    res = conn.execute('SELECT * FROM users WHERE username = ? AND password = ?', 
                       (user.username, user.password)).fetchone()
    if res:
        return {"message": "Login Berhasil"}
    raise HTTPException(status_code=401, detail="Username atau Password salah")

# --- API PRODUK (MASTER BARANG) ---
@app.get("/products", response_model=List[Product])
async def get_products():
    conn = get_db_connection()
    rows = conn.execute('SELECT * FROM products').fetchall()
    return [dict(row) for row in rows]

@app.post("/products")
async def add_product(p: Product):
    try:
        conn = get_db_connection()
        conn.execute('INSERT INTO products (name, price) VALUES (?, ?)', (p.name, p.price))
        conn.commit()
        return {"message": "Produk berhasil ditambah"}
    except:
        raise HTTPException(status_code=400, detail="Produk sudah ada")

@app.delete("/products/{p_id}")
async def delete_product(p_id: int):
    conn = get_db_connection()
    conn.execute('DELETE FROM products WHERE id = ?', (p_id,))
    conn.commit()
    return {"message": "Produk dihapus"}

# --- API TRANSAKSI (PENDAPATAN) ---
@app.get("/transactions", response_model=List[Transaction])
async def get_transactions():
    conn = get_db_connection()
    rows = conn.execute('SELECT * FROM transactions ORDER BY date DESC, id DESC').fetchall()
    return [dict(row) for row in rows]

@app.post("/transactions")
async def add_transaction(t: Transaction):
    conn = get_db_connection()
    conn.execute('INSERT INTO transactions (item_name, amount, date) VALUES (?, ?, ?)', 
                 (t.item_name, t.amount, t.date))
    conn.commit()
    return {"message": "Transaksi dicatat"}

@app.delete("/transactions/{t_id}")
async def delete_transaction(t_id: int):
    conn = get_db_connection()
    conn.execute('DELETE FROM transactions WHERE id = ?', (t_id,))
    conn.commit()
    return {"message": "Transaksi dihapus"}

# --- API LAPORAN & GRAFIK ---
@app.get("/monthly-report")
async def get_monthly_report():
    conn = get_db_connection()
    # Mengelompokkan pendapatan berdasarkan Tahun-Bulan untuk grafik
    query = """SELECT strftime('%Y-%m', date) as month, SUM(amount) as total 
               FROM transactions GROUP BY month ORDER BY month ASC"""
    rows = conn.execute(query).fetchall()
    return [dict(row) for row in rows]

# --- API PROFIL TOKO ---
@app.get("/profile")
async def get_profile():
    conn = get_db_connection()
    res = conn.execute('SELECT * FROM store_profile WHERE id = 1').fetchone()
    if res: return dict(res)
    return {"store_name": "Toko Baru", "address": "-"}

@app.post("/profile")
async def update_profile(p: StoreProfile):
    conn = get_db_connection()
    conn.execute('INSERT OR REPLACE INTO store_profile (id, store_name, address) VALUES (1, ?, ?)', 
                 (p.store_name, p.address))
    conn.commit()
    return {"message": "Profil diupdate"}

# Menjalankan server
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)