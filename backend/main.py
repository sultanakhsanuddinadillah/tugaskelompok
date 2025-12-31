from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import sqlite3
import re
from collections import Counter
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Konfigurasi CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- DATABASE SETUP ---
def get_db_connection():
    conn = sqlite3.connect('merchant_db.db', timeout=20)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    try:
        with conn:
            conn.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT)')
            conn.execute('CREATE TABLE IF NOT EXISTS transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, item_name TEXT, amount REAL, date TEXT)')
            conn.execute('CREATE TABLE IF NOT EXISTS store_profile (id INTEGER PRIMARY KEY, store_name TEXT, address TEXT)')
            conn.execute('CREATE TABLE IF NOT EXISTS products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, price REAL)')
    finally:
        conn.close()

init_db()

# --- MODELS ---
class User(BaseModel):
    username: str
    password: str
    store_name: Optional[str] = None

class Transaction(BaseModel):
    id: Optional[int] = None
    item_name: str
    amount: float
    date: str

class Product(BaseModel):
    id: Optional[int] = None
    name: str
    price: float

# --- API AUTH & PROFILE ---
@app.post("/register")
async def register(user: User):
    conn = get_db_connection()
    try:
        with conn:
            conn.execute('INSERT INTO users (username, password) VALUES (?, ?)', (user.username, user.password))
            conn.execute('INSERT OR REPLACE INTO store_profile (id, store_name, address) VALUES (1, ?, ?)', (user.store_name or "Toko Baru", "-"))
        return {"message": "Sukses"}
    except: raise HTTPException(status_code=400, detail="Username sudah ada")
    finally: conn.close()

@app.post("/login")
async def login(user: User):
    conn = get_db_connection()
    res = conn.execute('SELECT * FROM users WHERE username=? AND password=?', (user.username, user.password)).fetchone()
    conn.close()
    if res: return {"message": "Sukses"}
    raise HTTPException(status_code=401, detail="Gagal")

@app.get("/profile")
async def get_profile():
    conn = get_db_connection()
    res = conn.execute('SELECT * FROM store_profile WHERE id=1').fetchone()
    conn.close()
    return dict(res) if res else {"store_name": "Toko Saya", "address": "-"}

@app.post("/profile")
async def update_profile(p: dict):
    conn = get_db_connection()
    with conn: conn.execute('INSERT OR REPLACE INTO store_profile (id, store_name, address) VALUES (1, ?, ?)', (p.get('store_name'), p.get('address')))
    conn.close()
    return {"message": "Sukses"}

# --- API PRODUK & TRANSAKSI ---
@app.get("/products")
async def get_products():
    conn = get_db_connection()
    rows = conn.execute('SELECT * FROM products').fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/products")
async def add_product(p: Product):
    conn = get_db_connection()
    with conn: conn.execute('INSERT INTO products (name, price) VALUES (?, ?)', (p.name, p.price))
    conn.close()
    return {"message": "Sukses"}

@app.delete("/products/{p_id}")
async def delete_product(p_id: int):
    conn = get_db_connection()
    with conn: conn.execute('DELETE FROM products WHERE id=?', (p_id,))
    conn.close()
    return {"message": "Sukses"}

@app.get("/transactions")
async def get_transactions():
    conn = get_db_connection()
    rows = conn.execute('SELECT * FROM transactions ORDER BY date DESC').fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.post("/transactions")
async def add_transaction(t: Transaction):
    conn = get_db_connection()
    with conn: conn.execute('INSERT INTO transactions (item_name, amount, date) VALUES (?, ?, ?)', (t.item_name, t.amount, t.date))
    conn.close()
    return {"message": "Sukses"}

@app.put("/transactions/{t_id}")
async def update_transaction(t_id: int, t: Transaction):
    conn = get_db_connection()
    with conn: conn.execute('UPDATE transactions SET item_name=?, amount=?, date=? WHERE id=?', (t.item_name, t.amount, t.date, t_id))
    conn.close()
    return {"message": "Sukses"}

@app.delete("/transactions/{t_id}")
async def delete_transaction(t_id: int):
    conn = get_db_connection()
    with conn: conn.execute('DELETE FROM transactions WHERE id=?', (t_id,))
    conn.close()
    return {"message": "Sukses"}

# --- ANALISIS ---
@app.get("/top-products")
async def get_top_products():
    conn = get_db_connection()
    rows = conn.execute('SELECT item_name FROM transactions').fetchall()
    conn.close()
    counter = Counter()
    for r in rows:
        items = r['item_name'].split(', ')
        for i in items:
            m = re.search(r'^(.*?) \(x(\d+)\)', i)
            if m: counter[m.group(1).strip()] += int(m.group(2))
    return [{"name": k, "count": v} for k, v in counter.most_common()]

@app.get("/monthly-report")
async def get_monthly_report():
    conn = get_db_connection()
    rows = conn.execute("SELECT strftime('%Y-%m', date) as month, SUM(amount) as total FROM transactions GROUP BY month").fetchall()
    conn.close()
    return [dict(r) for r in rows]