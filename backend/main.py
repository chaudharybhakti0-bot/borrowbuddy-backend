"""
BorrowBuddy Backend - FastAPI Application
Campus peer-to-peer item rental platform

Fixes applied:
1. SQLite persistence — data survives restarts
2. Domain-based filtering — users only see items from their college domain
"""

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date
import uuid
import os
import shutil
import sqlite3
import json
from pathlib import Path
from contextlib import contextmanager

# ─── App Setup ────────────────────────────────────────────────────────────────

app = FastAPI(title="BorrowBuddy API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

security = HTTPBearer()

DB_PATH = "borrowbuddy.db"

# ─── Database Setup ───────────────────────────────────────────────────────────

@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    with get_db() as conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            college TEXT,
            domain TEXT,           -- extracted from email e.g. "imsec.ac.in"
            avatar TEXT,
            verified INTEGER DEFAULT 0,
            rating REAL DEFAULT 0.0,
            listed INTEGER DEFAULT 0,
            bookings INTEGER DEFAULT 0,
            reviews_count INTEGER DEFAULT 0,
            saved_items TEXT DEFAULT '[]',
            created_at TEXT,
            token TEXT UNIQUE
        );

        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            domain TEXT NOT NULL,  -- same as owner's domain
            name TEXT NOT NULL,
            category TEXT,
            description TEXT,
            brand TEXT,
            size TEXT,
            color TEXT,
            condition TEXT,
            price_per_day REAL,
            deposit REAL,
            min_days INTEGER DEFAULT 1,
            max_days INTEGER DEFAULT 7,
            late_fee REAL,
            images TEXT DEFAULT '[]',
            rating REAL DEFAULT 0.0,
            review_count INTEGER DEFAULT 0,
            available INTEGER DEFAULT 1,
            booked_dates TEXT DEFAULT '[]',
            created_at TEXT,
            FOREIGN KEY(owner_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS bookings (
            id TEXT PRIMARY KEY,
            item_id TEXT NOT NULL,
            borrower_id TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            start_date TEXT,
            end_date TEXT,
            duration_days INTEGER,
            price_per_day REAL,
            subtotal REAL,
            deposit REAL,
            total REAL,
            pickup_location TEXT,
            status TEXT DEFAULT 'pending_confirmation',
            pickup_photos TEXT DEFAULT '[]',
            return_photos TEXT DEFAULT '[]',
            created_at TEXT,
            FOREIGN KEY(item_id) REFERENCES items(id),
            FOREIGN KEY(borrower_id) REFERENCES users(id)
        );

        CREATE TABLE IF NOT EXISTS reviews (
            id TEXT PRIMARY KEY,
            item_id TEXT,
            booking_id TEXT,
            reviewer_id TEXT,
            reviewer_name TEXT,
            rating INTEGER,
            comment TEXT,
            created_at TEXT
        );

        CREATE TABLE IF NOT EXISTS notifications (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            message TEXT,
            type TEXT,
            read INTEGER DEFAULT 0,
            created_at TEXT
        );
        """)


def extract_domain(email: str) -> str:
    """Extract domain from email. e.g. 'rahul@imsec.ac.in' → 'imsec.ac.in'"""
    return email.strip().lower().split("@")[-1]


def seed_data():
    """Seed initial data only if DB is empty."""
    with get_db() as conn:
        count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        if count > 0:
            return  # Already seeded, skip

        users = [
            ("user_anshika", "Anshika Chopra", "anshika.chopra@abes.ac.in", "+91 98765 43210", "ABES Engineering College", "abes.ac.in", None, 1, 4.8, 8, 12, 15, "token_anshika"),
            ("user_rahul",   "Rahul Sharma",   "rahul.sharma@abes.ac.in",   "+91 87654 32109", "ABES Engineering College", "abes.ac.in", None, 1, 4.6, 5,  8, 10, "token_rahul"),
            ("user_chanchal","Chanchal Gupta", "chanchal.gupta@abes.ac.in", "+91 76543 21098", "ABES Engineering College", "abes.ac.in", None, 1, 4.9, 3,  6,  8, "token_chanchal"),
            ("user_priya",   "Priya Singh",    "priya.singh@abes.ac.in",    "+91 65432 10987", "ABES Engineering College", "abes.ac.in", None, 1, 4.7, 2,  9, 12, "token_priya"),
        ]
        conn.executemany("""
            INSERT OR IGNORE INTO users
            (id, name, email, phone, college, domain, avatar, verified, rating, listed, bookings, reviews_count, saved_items, created_at, token)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,'[]','2025-01-01',?)
        """, users)

        items = [
            ("item_001", "user_chanchal", "abes.ac.in", "Black Party Dress",    "Clothes",     "Elegant black party dress.", "Zara",    "M",    "Black",     "Excellent", 50,  200, 1, 7, 50,  '["dress.png"]',      4.5, 56, 1, '[{"start":"2026-04-05","end":"2026-04-09"},{"start":"2026-04-21","end":"2026-04-24"}]', "2025-03-01"),
            ("item_002", "user_rahul",    "abes.ac.in", "PS5 Controller",        "Electronics", "Sony DualSense wireless controller.", "Sony", None, "White",  "Good",      80,  500, 1, 3, 100, '["controller.png"]', 4.5, 32, 1, '[]', "2025-03-05"),
            ("item_003", "user_anshika",  "abes.ac.in", "Engineering Books Set", "Books",       "2nd year engineering books set.",    "Various", None, None, "Good",      20,  100, 1,14, 20,  '["books.png"]',      4.2, 18, 1, '[]', "2025-03-10"),
            ("item_004", "user_priya",    "abes.ac.in", "Hiking Backpack",       "Accessories", "60L trekking backpack with rain cover.", "Quechua", "60L", "Green", "Excellent", 30, 150, 1, 7, 30, '["backpack.png"]', 4.8, 24, 1, '[]', "2025-03-12"),
            ("item_005", "user_rahul",    "abes.ac.in", "Canon EOS R5 Camera",   "Electronics", "Professional mirrorless camera, 45MP.", "Canon", None, "Black", "Excellent", 120, 2000, 1, 5, 200, '["camera.png"]', 4.9, 41, 1, '[{"start":"2026-04-05","end":"2026-04-09"}]', "2025-03-15"),
            ("item_006", "user_chanchal", "abes.ac.in", "Formal Blazer",         "Clothes",     "Navy blue formal blazer.", "Arrow", "L", "Navy Blue", "Good", 40, 300, 1, 3, 50, '["blazer.png"]', 4.3, 12, 1, '[]', "2025-03-20"),
        ]
        conn.executemany("""
            INSERT OR IGNORE INTO items
            (id, owner_id, domain, name, category, description, brand, size, color, condition,
             price_per_day, deposit, min_days, max_days, late_fee, images, rating, review_count,
             available, booked_dates, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, items)

        bookings = [
            ("booking_001", "item_001", "user_anshika",  "user_chanchal", "2026-04-10", "2026-04-12", 3,  50,  150, 200,  350, "Girls Hostel Block B", "active",          "[]", "[]", "2026-04-08"),
            ("booking_002", "item_005", "user_anshika",  "user_rahul",    "2026-04-08", "2026-04-09", 2, 120,  240, 2000, 2240, "Canteen",              "pending_pickup",  "[]", "[]", "2026-04-06"),
        ]
        conn.executemany("""
            INSERT OR IGNORE INTO bookings
            (id, item_id, borrower_id, owner_id, start_date, end_date, duration_days,
             price_per_day, subtotal, deposit, total, pickup_location, status,
             pickup_photos, return_photos, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, bookings)

        conn.execute("""
            INSERT OR IGNORE INTO reviews
            (id, item_id, booking_id, reviewer_id, reviewer_name, rating, comment, created_at)
            VALUES ('review_001','item_001','booking_001','user_priya','Priya S.',5,
            'The dress was in perfect condition. Very helpful!','2026-03-20')
        """)

        conn.executemany("""
            INSERT OR IGNORE INTO notifications (id, user_id, title, message, type, read, created_at)
            VALUES (?,?,?,?,?,0,?)
        """, [
            ("notif_001", "user_anshika", "Booking Confirmed", "Your booking for Black Party Dress has been confirmed.", "booking", "2026-04-08"),
            ("notif_002", "user_anshika", "Return Reminder",   "Reminder: Canon EOS R5 Camera is due for return tomorrow.", "reminder", "2026-04-08"),
        ])


# ─── Startup ──────────────────────────────────────────────────────────────────

init_db()
seed_data()

# ─── Auth Helpers ─────────────────────────────────────────────────────────────

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE token = ?", (token,)).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return dict(row)


def row_to_item(row) -> dict:
    d = dict(row)
    d["images"] = json.loads(d.get("images") or "[]")
    d["booked_dates"] = json.loads(d.get("booked_dates") or "[]")
    return d


def row_to_booking(row) -> dict:
    d = dict(row)
    d["pickup_photos"] = json.loads(d.get("pickup_photos") or "[]")
    d["return_photos"] = json.loads(d.get("return_photos") or "[]")
    return d


# ─── Schemas ──────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    name: str
    email: str
    phone: str
    college: str
    password: str

class ItemCreateRequest(BaseModel):
    name: str
    category: str
    description: str
    brand: str
    size: Optional[str] = None
    color: Optional[str] = None
    condition: str
    price_per_day: float
    deposit: float
    min_days: int = 1
    max_days: int = 7

class BookingCreateRequest(BaseModel):
    item_id: str
    start_date: str
    end_date: str
    pickup_location: str

class ReviewCreateRequest(BaseModel):
    booking_id: str
    rating: int
    comment: str

# ─── Auth Routes ──────────────────────────────────────────────────────────────

@app.post("/api/auth/register")
def register(req: RegisterRequest):
    domain = extract_domain(req.email)
    user_id = f"user_{uuid.uuid4().hex[:8]}"
    token = f"token_{uuid.uuid4().hex}"
    with get_db() as conn:
        existing = conn.execute("SELECT id FROM users WHERE email = ?", (req.email,)).fetchone()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")
        conn.execute("""
            INSERT INTO users (id, name, email, phone, college, domain, verified,
                               rating, listed, bookings, reviews_count, saved_items, created_at, token)
            VALUES (?,?,?,?,?,?,0,0.0,0,0,0,'[]',?,?)
        """, (user_id, req.name, req.email, req.phone, req.college, domain,
              str(date.today()), token))
    return {"token": token, "user": {"id": user_id, "name": req.name, "email": req.email,
                                      "college": req.college, "domain": domain}}


@app.post("/api/auth/login")
def login(req: LoginRequest):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (req.email,)).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    user = dict(row)
    return {"token": user["token"], "user": {k: v for k, v in user.items() if k != "token"}}

# ─── User Routes ──────────────────────────────────────────────────────────────

@app.get("/api/users/me")
def get_me(current_user=Depends(get_current_user)):
    return {k: v for k, v in current_user.items() if k != "token"}


@app.get("/api/users/{user_id}")
def get_user(user_id: str):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    u = dict(row)
    return {"id": u["id"], "name": u["name"], "college": u["college"],
            "avatar": u["avatar"], "verified": u["verified"],
            "rating": u["rating"], "listed": u["listed"],
            "reviews_count": u["reviews_count"]}


@app.put("/api/users/me")
def update_profile(name: str = None, phone: str = None, college: str = None,
                   current_user=Depends(get_current_user)):
    updates = {}
    if name:    updates["name"]    = name
    if phone:   updates["phone"]   = phone
    if college: updates["college"] = college
    if updates:
        set_clause = ", ".join(f"{k}=?" for k in updates)
        with get_db() as conn:
            conn.execute(f"UPDATE users SET {set_clause} WHERE id=?",
                         (*updates.values(), current_user["id"]))
    return {**current_user, **updates}

# ─── Items Routes ─────────────────────────────────────────────────────────────

@app.get("/api/items")
def list_items(category: Optional[str] = None, q: Optional[str] = None,
               skip: int = 0, limit: int = 20,
               current_user=Depends(get_current_user)):
    """
    ── DOMAIN FILTER ──────────────────────────────────────────────────────
    Users only see items listed by people with the SAME email domain.
    e.g. a user with @imsec.ac.in only sees items from other @imsec.ac.in users.
    ───────────────────────────────────────────────────────────────────────
    """
    user_domain = current_user["domain"]
    query = "SELECT items.*, users.name as owner_name, users.verified as owner_verified FROM items JOIN users ON items.owner_id = users.id WHERE items.domain = ?"
    params: list = [user_domain]

    if category and category.lower() != "all":
        query += " AND LOWER(items.category) = ?"
        params.append(category.lower())
    if q:
        query += " AND (LOWER(items.name) LIKE ? OR LOWER(items.description) LIKE ?)"
        params += [f"%{q.lower()}%", f"%{q.lower()}%"]

    query += " LIMIT ? OFFSET ?"
    params += [limit, skip]

    with get_db() as conn:
        rows = conn.execute(query, params).fetchall()
        total = conn.execute(
            "SELECT COUNT(*) FROM items WHERE domain = ?", (user_domain,)
        ).fetchone()[0]

    return {"items": [row_to_item(r) for r in rows], "total": total}


@app.get("/api/items/featured")
def featured_items(current_user=Depends(get_current_user)):
    """Top rated items from the same domain only."""
    user_domain = current_user["domain"]
    with get_db() as conn:
        rows = conn.execute("""
            SELECT items.*, users.name as owner_name FROM items
            JOIN users ON items.owner_id = users.id
            WHERE items.domain = ?
            ORDER BY items.rating DESC LIMIT 6
        """, (user_domain,)).fetchall()
    return {"items": [row_to_item(r) for r in rows]}


@app.get("/api/items/{item_id}")
def get_item(item_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("""
            SELECT items.*, users.name as owner_name, users.verified as owner_verified,
                   users.rating as owner_rating
            FROM items JOIN users ON items.owner_id = users.id
            WHERE items.id = ?
        """, (item_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Item not found")
        item = row_to_item(row)

        # Domain check — can't view items from other colleges
        if item.get("domain") != current_user["domain"]:
            raise HTTPException(status_code=403, detail="Item not available for your college")

        reviews = conn.execute(
            "SELECT * FROM reviews WHERE item_id = ?", (item_id,)
        ).fetchall()

    item["reviews"] = [dict(r) for r in reviews]
    return item


@app.post("/api/items")
def create_item(req: ItemCreateRequest, current_user=Depends(get_current_user)):
    item_id = f"item_{uuid.uuid4().hex[:8]}"
    domain = current_user["domain"]
    with get_db() as conn:
        conn.execute("""
            INSERT INTO items (id, owner_id, domain, name, category, description, brand,
                               size, color, condition, price_per_day, deposit, min_days,
                               max_days, late_fee, images, booked_dates, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'[]','[]',?)
        """, (item_id, current_user["id"], domain, req.name, req.category, req.description,
              req.brand, req.size, req.color, req.condition, req.price_per_day,
              req.deposit, req.min_days, req.max_days, req.price_per_day, str(date.today())))
        conn.execute("UPDATE users SET listed = listed + 1 WHERE id = ?", (current_user["id"],))
    return {"id": item_id, "domain": domain, "name": req.name, "message": "Item listed successfully"}


@app.post("/api/items/{item_id}/images")
async def upload_item_image(item_id: str, file: UploadFile = File(...),
                             current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Item not found")
        item = dict(row)
        if item["owner_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not the owner")
        ext = Path(file.filename).suffix
        filename = f"{item_id}_{uuid.uuid4().hex[:6]}{ext}"
        path = UPLOAD_DIR / filename
        with open(path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        images = json.loads(item["images"] or "[]")
        images.append(f"/uploads/{filename}")
        conn.execute("UPDATE items SET images = ? WHERE id = ?",
                     (json.dumps(images), item_id))
    return {"image_url": f"/uploads/{filename}"}


@app.delete("/api/items/{item_id}")
def delete_item(item_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Item not found")
        if dict(row)["owner_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not the owner")
        conn.execute("DELETE FROM items WHERE id = ?", (item_id,))
    return {"message": "Item deleted"}


@app.get("/api/users/me/items")
def my_items(current_user=Depends(get_current_user)):
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM items WHERE owner_id = ?",
                            (current_user["id"],)).fetchall()
    return {"items": [row_to_item(r) for r in rows]}

# ─── Bookings Routes ──────────────────────────────────────────────────────────

@app.post("/api/bookings")
def create_booking(req: BookingCreateRequest, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM items WHERE id = ?", (req.item_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Item not found")
        item = row_to_item(row)

        if item["owner_id"] == current_user["id"]:
            raise HTTPException(status_code=400, detail="Cannot book your own item")
        if item.get("domain") != current_user["domain"]:
            raise HTTPException(status_code=403, detail="Item not available for your college")

        start = datetime.strptime(req.start_date, "%Y-%m-%d").date()
        end   = datetime.strptime(req.end_date,   "%Y-%m-%d").date()
        if end <= start:
            raise HTTPException(status_code=400, detail="End date must be after start date")

        duration = (end - start).days
        if duration < item["min_days"]:
            raise HTTPException(status_code=400, detail=f"Minimum rental is {item['min_days']} day(s)")
        if duration > item["max_days"]:
            raise HTTPException(status_code=400, detail=f"Maximum rental is {item['max_days']} day(s)")

        for bd in item["booked_dates"]:
            bd_start = datetime.strptime(bd["start"], "%Y-%m-%d").date()
            bd_end   = datetime.strptime(bd["end"],   "%Y-%m-%d").date()
            if not (end <= bd_start or start >= bd_end):
                raise HTTPException(status_code=400, detail="Item is not available on selected dates")

        subtotal = duration * item["price_per_day"]
        total    = subtotal + item["deposit"]
        booking_id = f"booking_{uuid.uuid4().hex[:8]}"

        conn.execute("""
            INSERT INTO bookings (id, item_id, borrower_id, owner_id, start_date, end_date,
                                  duration_days, price_per_day, subtotal, deposit, total,
                                  pickup_location, status, pickup_photos, return_photos, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,'pending_confirmation','[]','[]',?)
        """, (booking_id, req.item_id, current_user["id"], item["owner_id"],
              req.start_date, req.end_date, duration, item["price_per_day"],
              subtotal, item["deposit"], total, req.pickup_location, str(date.today())))

        # Block the dates
        booked = item["booked_dates"]
        booked.append({"start": req.start_date, "end": req.end_date})
        conn.execute("UPDATE items SET booked_dates = ? WHERE id = ?",
                     (json.dumps(booked), req.item_id))
        conn.execute("UPDATE users SET bookings = bookings + 1 WHERE id = ?",
                     (current_user["id"],))

        # Notification for owner
        notif_id = f"notif_{uuid.uuid4().hex[:8]}"
        conn.execute("""
            INSERT INTO notifications (id, user_id, title, message, type, read, created_at)
            VALUES (?,?,?,?,?,0,?)
        """, (notif_id, item["owner_id"], "New Booking Request",
              f"{current_user['name']} wants to borrow '{item['name']}'",
              "booking", str(date.today())))

    return {"id": booking_id, "total": total, "status": "pending_confirmation",
            "message": "Booking created successfully"}


@app.get("/api/bookings/my")
def my_bookings(current_user=Depends(get_current_user)):
    with get_db() as conn:
        rows = conn.execute("""
            SELECT bookings.*, items.name as item_name, users.name as owner_name
            FROM bookings
            JOIN items ON bookings.item_id = items.id
            JOIN users ON bookings.owner_id = users.id
            WHERE bookings.borrower_id = ?
        """, (current_user["id"],)).fetchall()
    return {"bookings": [row_to_booking(r) for r in rows]}


@app.get("/api/bookings/rentals")
def my_rentals(current_user=Depends(get_current_user)):
    with get_db() as conn:
        rows = conn.execute("""
            SELECT bookings.*, items.name as item_name, users.name as borrower_name
            FROM bookings
            JOIN items ON bookings.item_id = items.id
            JOIN users ON bookings.borrower_id = users.id
            WHERE bookings.owner_id = ?
        """, (current_user["id"],)).fetchall()
    return {"bookings": [row_to_booking(r) for r in rows]}


@app.get("/api/bookings/{booking_id}")
def get_booking(booking_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("""
            SELECT bookings.*, items.name as item_name,
                   owner.name as owner_name, borrower.name as borrower_name
            FROM bookings
            JOIN items ON bookings.item_id = items.id
            JOIN users AS owner    ON bookings.owner_id    = owner.id
            JOIN users AS borrower ON bookings.borrower_id = borrower.id
            WHERE bookings.id = ?
        """, (booking_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Booking not found")
    b = row_to_booking(row)
    if b["borrower_id"] != current_user["id"] and b["owner_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied")
    return b


@app.put("/api/bookings/{booking_id}/status")
def update_booking_status(booking_id: str, new_status: str,
                           current_user=Depends(get_current_user)):
    valid_transitions = {
        "pending_confirmation": ["confirmed", "rejected"],
        "confirmed":            ["active", "cancelled"],
        "active":               ["completed", "disputed"],
        "pending_pickup":       ["active"],
    }
    with get_db() as conn:
        row = conn.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Booking not found")
        booking = dict(row)
        allowed = valid_transitions.get(booking["status"], [])
        if new_status not in allowed:
            raise HTTPException(status_code=400, detail=f"Cannot transition to {new_status}")
        conn.execute("UPDATE bookings SET status = ? WHERE id = ?", (new_status, booking_id))
    return {"id": booking_id, "status": new_status}


@app.post("/api/bookings/{booking_id}/pickup-photos")
async def upload_pickup_photos(booking_id: str, files: List[UploadFile] = File(...),
                                current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Booking not found")
        booking = dict(row)
        photos = json.loads(booking["pickup_photos"] or "[]")
        urls = []
        for file in files:
            ext = Path(file.filename).suffix
            filename = f"pickup_{booking_id}_{uuid.uuid4().hex[:6]}{ext}"
            path = UPLOAD_DIR / filename
            with open(path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            url = f"/uploads/{filename}"
            photos.append(url)
            urls.append(url)
        conn.execute("UPDATE bookings SET pickup_photos = ?, status = 'active' WHERE id = ?",
                     (json.dumps(photos), booking_id))
    return {"urls": urls}

# ─── Reviews Routes ───────────────────────────────────────────────────────────

@app.post("/api/reviews")
def create_review(req: ReviewCreateRequest, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM bookings WHERE id = ?", (req.booking_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Booking not found")
        booking = dict(row)
        if booking["borrower_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Only borrower can review")
        if booking["status"] != "completed":
            raise HTTPException(status_code=400, detail="Can only review completed bookings")

        review_id = f"review_{uuid.uuid4().hex[:8]}"
        conn.execute("""
            INSERT INTO reviews (id, item_id, booking_id, reviewer_id, reviewer_name, rating, comment, created_at)
            VALUES (?,?,?,?,?,?,?,?)
        """, (review_id, booking["item_id"], req.booking_id,
              current_user["id"], current_user["name"],
              req.rating, req.comment, str(date.today())))

        # Recalculate item rating
        rows = conn.execute("SELECT AVG(rating), COUNT(*) FROM reviews WHERE item_id = ?",
                            (booking["item_id"],)).fetchone()
        conn.execute("UPDATE items SET rating = ?, review_count = ? WHERE id = ?",
                     (rows[0], rows[1], booking["item_id"]))
        conn.execute("UPDATE users SET reviews_count = reviews_count + 1 WHERE id = ?",
                     (current_user["id"],))

    return {"id": review_id, "message": "Review submitted"}


@app.get("/api/items/{item_id}/reviews")
def item_reviews(item_id: str):
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM reviews WHERE item_id = ?", (item_id,)).fetchall()
    return {"reviews": [dict(r) for r in rows]}

# ─── Saved Items ──────────────────────────────────────────────────────────────

@app.post("/api/saved/{item_id}")
def save_item(item_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT saved_items FROM users WHERE id = ?", (current_user["id"],)).fetchone()
        saved = json.loads(row["saved_items"] or "[]")
        if item_id not in saved:
            saved.append(item_id)
            conn.execute("UPDATE users SET saved_items = ? WHERE id = ?",
                         (json.dumps(saved), current_user["id"]))
    return {"saved": True}


@app.delete("/api/saved/{item_id}")
def unsave_item(item_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT saved_items FROM users WHERE id = ?", (current_user["id"],)).fetchone()
        saved = json.loads(row["saved_items"] or "[]")
        if item_id in saved:
            saved.remove(item_id)
            conn.execute("UPDATE users SET saved_items = ? WHERE id = ?",
                         (json.dumps(saved), current_user["id"]))
    return {"saved": False}


@app.get("/api/saved")
def get_saved_items(current_user=Depends(get_current_user)):
    with get_db() as conn:
        row = conn.execute("SELECT saved_items FROM users WHERE id = ?", (current_user["id"],)).fetchone()
        saved_ids = json.loads(row["saved_items"] or "[]")
        if not saved_ids:
            return {"items": []}
        placeholders = ",".join("?" * len(saved_ids))
        rows = conn.execute(f"""
            SELECT items.*, users.name as owner_name FROM items
            JOIN users ON items.owner_id = users.id
            WHERE items.id IN ({placeholders})
        """, saved_ids).fetchall()
    return {"items": [row_to_item(r) for r in rows]}

# ─── Notifications ────────────────────────────────────────────────────────────

@app.get("/api/notifications")
def get_notifications(current_user=Depends(get_current_user)):
    with get_db() as conn:
        rows = conn.execute("""
            SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC
        """, (current_user["id"],)).fetchall()
    return {"notifications": [dict(r) for r in rows]}


@app.put("/api/notifications/{notif_id}/read")
def mark_read(notif_id: str, current_user=Depends(get_current_user)):
    with get_db() as conn:
        conn.execute("UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?",
                     (notif_id, current_user["id"]))
    return {"success": True}

# ─── Categories ───────────────────────────────────────────────────────────────

@app.get("/api/categories")
def get_categories():
    return {"categories": [
        {"id": "clothes",     "name": "Clothes",     "icon": "👗"},
        {"id": "electronics", "name": "Electronics", "icon": "🎮"},
        {"id": "books",       "name": "Books",       "icon": "📚"},
        {"id": "accessories", "name": "Accessories", "icon": "🎒"},
        {"id": "sports",      "name": "Sports",      "icon": "⚽"},
        {"id": "tools",       "name": "Tools",       "icon": "🔧"},
        {"id": "music",       "name": "Music",       "icon": "🎸"},
        {"id": "other",       "name": "Other",       "icon": "📦"},
    ]}

# ─── Earnings ─────────────────────────────────────────────────────────────────

@app.get("/api/earnings")
def get_earnings(current_user=Depends(get_current_user)):
    with get_db() as conn:
        completed = conn.execute("""
            SELECT COALESCE(SUM(subtotal),0) as total, COUNT(*) as count
            FROM bookings WHERE owner_id = ? AND status = 'completed'
        """, (current_user["id"],)).fetchone()
        pending = conn.execute("""
            SELECT COALESCE(SUM(subtotal),0) as total
            FROM bookings WHERE owner_id = ? AND status IN ('active','confirmed')
        """, (current_user["id"],)).fetchone()
    return {
        "total_earned":      completed["total"],
        "pending":           pending["total"],
        "completed_rentals": completed["count"],
        "monthly_breakdown": []
    }

# ─── Health ───────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "version": "2.0.0", "db": DB_PATH}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)