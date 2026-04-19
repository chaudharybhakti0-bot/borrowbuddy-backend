"""
BorrowBuddy Backend - FastAPI Application
Campus peer-to-peer item rental platform
"""

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime, date, timedelta
import uuid
import os
import shutil
from pathlib import Path

# ─── App Setup ────────────────────────────────────────────────────────────────

app = FastAPI(title="BorrowBuddy API", version="1.0.0")

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

# ─── In-Memory Database (replace with PostgreSQL/Firebase in production) ──────

users_db: dict = {}
items_db: dict = {}
bookings_db: dict = {}
reviews_db: dict = {}
notifications_db: dict = {}

# Seed data
def seed_data():
    u1 = "user_anshika"
    u2 = "user_rahul"
    u3 = "user_chanchal"
    u4 = "user_priya"

    users_db[u1] = {
        "id": u1, "name": "Anshika Chopra", "email": "anshika.chopra@abes.ac.in",
        "phone": "+91 98765 43210", "college": "ABES Engineering College",
        "avatar": None, "verified": True, "rating": 4.8,
        "listed": 8, "bookings": 12, "reviews_count": 15,
        "saved_items": [], "created_at": "2025-01-01",
        # Simple token for demo
        "token": "token_anshika"
    }
    users_db[u2] = {
        "id": u2, "name": "Rahul Sharma", "email": "rahul.sharma@abes.ac.in",
        "phone": "+91 87654 32109", "college": "ABES Engineering College",
        "avatar": None, "verified": True, "rating": 4.6,
        "listed": 5, "bookings": 8, "reviews_count": 10,
        "saved_items": [], "created_at": "2025-01-15",
        "token": "token_rahul"
    }
    users_db[u3] = {
        "id": u3, "name": "Chanchal Gupta", "email": "chanchal.gupta@abes.ac.in",
        "phone": "+91 76543 21098", "college": "ABES Engineering College",
        "avatar": None, "verified": True, "rating": 4.9,
        "listed": 3, "bookings": 6, "reviews_count": 8,
        "saved_items": [], "created_at": "2025-02-01",
        "token": "token_chanchal"
    }
    users_db[u4] = {
        "id": u4, "name": "Priya Singh", "email": "priya.singh@abes.ac.in",
        "phone": "+91 65432 10987", "college": "ABES Engineering College",
        "avatar": None, "verified": True, "rating": 4.7,
        "listed": 2, "bookings": 9, "reviews_count": 12,
        "saved_items": [], "created_at": "2025-02-15",
        "token": "token_priya"
    }

    # Token → user_id map
    tokens_db["token_anshika"] = u1
    tokens_db["token_rahul"] = u2
    tokens_db["token_chanchal"] = u3
    tokens_db["token_priya"] = u4

    items = [
        {
            "id": "item_001", "owner_id": u3, "name": "Black Party Dress",
            "category": "Clothes", "description": "Elegant black party dress perfect for special occasions. Made with premium quality fabric, this dress features a flattering silhouette and comfortable fit. Ideal for evening events, parties, and formal gatherings.",
            "brand": "Zara", "size": "M", "color": "Black", "condition": "Excellent",
            "price_per_day": 50, "deposit": 200, "min_days": 1, "max_days": 7,
            "late_fee": 50, "images": ["dress.png"],
            "rating": 4.5, "review_count": 56, "available": True,
            "booked_dates": [
                {"start": "2026-04-05", "end": "2026-04-09"},
                {"start": "2026-04-21", "end": "2026-04-24"}
            ],
            "created_at": "2025-03-01"
        },
        {
            "id": "item_002", "owner_id": u2, "name": "PS5 Controller",
            "category": "Electronics", "description": "Sony DualSense wireless controller for PlayStation 5. Works perfectly with all PS5 games. Includes USB-C charging cable.",
            "brand": "Sony", "size": None, "color": "White", "condition": "Good",
            "price_per_day": 80, "deposit": 500, "min_days": 1, "max_days": 3,
            "late_fee": 100, "images": ["controller.png"],
            "rating": 4.5, "review_count": 32, "available": True,
            "booked_dates": [],
            "created_at": "2025-03-05"
        },
        {
            "id": "item_003", "owner_id": u1, "name": "Engineering Books Set",
            "category": "Books", "description": "Complete set of 2nd year engineering books including Data Structures, DBMS, OS, and Computer Networks.",
            "brand": "Various", "size": None, "color": None, "condition": "Good",
            "price_per_day": 20, "deposit": 100, "min_days": 1, "max_days": 14,
            "late_fee": 20, "images": ["books.png"],
            "rating": 4.2, "review_count": 18, "available": True,
            "booked_dates": [],
            "created_at": "2025-03-10"
        },
        {
            "id": "item_004", "owner_id": u4, "name": "Hiking Backpack",
            "category": "Accessories", "description": "60L trekking backpack with rain cover. Multiple compartments, padded back support, and hydration sleeve.",
            "brand": "Quechua", "size": "60L", "color": "Green", "condition": "Excellent",
            "price_per_day": 30, "deposit": 150, "min_days": 1, "max_days": 7,
            "late_fee": 30, "images": ["backpack.png"],
            "rating": 4.8, "review_count": 24, "available": True,
            "booked_dates": [],
            "created_at": "2025-03-12"
        },
        {
            "id": "item_005", "owner_id": u2, "name": "Canon EOS R5 Camera",
            "category": "Electronics", "description": "Professional mirrorless camera with 45MP full-frame sensor. Includes 24-105mm lens, 2 batteries, and camera bag.",
            "brand": "Canon", "size": None, "color": "Black", "condition": "Excellent",
            "price_per_day": 120, "deposit": 2000, "min_days": 1, "max_days": 5,
            "late_fee": 200, "images": ["camera.png"],
            "rating": 4.9, "review_count": 41, "available": True,
            "booked_dates": [
                {"start": "2026-04-05", "end": "2026-04-09"}
            ],
            "created_at": "2025-03-15"
        },
        {
            "id": "item_006", "owner_id": u3, "name": "Formal Blazer",
            "category": "Clothes", "description": "Navy blue formal blazer, perfect for interviews and presentations.",
            "brand": "Arrow", "size": "L", "color": "Navy Blue", "condition": "Good",
            "price_per_day": 40, "deposit": 300, "min_days": 1, "max_days": 3,
            "late_fee": 50, "images": ["blazer.png"],
            "rating": 4.3, "review_count": 12, "available": True,
            "booked_dates": [],
            "created_at": "2025-03-20"
        },
    ]
    for item in items:
        items_db[item["id"]] = item

    # Seed bookings
    bookings = [
        {
            "id": "booking_001", "item_id": "item_001", "borrower_id": u1,
            "owner_id": u3, "start_date": "2026-04-10", "end_date": "2026-04-12",
            "duration_days": 3, "price_per_day": 50, "subtotal": 150,
            "deposit": 200, "total": 350, "pickup_location": "Girls Hostel Block B",
            "status": "active", "pickup_photos": [], "return_photos": [],
            "created_at": "2026-04-08"
        },
        {
            "id": "booking_002", "item_id": "item_005", "borrower_id": u1,
            "owner_id": u2, "start_date": "2026-04-08", "end_date": "2026-04-09",
            "duration_days": 2, "price_per_day": 120, "subtotal": 240,
            "deposit": 2000, "total": 2240, "pickup_location": "Canteen",
            "status": "pending_pickup", "pickup_photos": [], "return_photos": [],
            "created_at": "2026-04-06"
        },
    ]
    for b in bookings:
        bookings_db[b["id"]] = b

    # Seed reviews
    reviews_db["review_001"] = {
        "id": "review_001", "item_id": "item_001", "booking_id": "booking_001",
        "reviewer_id": u4, "reviewer_name": "Priya S.", "rating": 5,
        "comment": "The dress was in perfect condition and fit beautifully. Chanchal was very helpful!",
        "created_at": "2026-03-20"
    }

    # Seed notifications
    notifications_db["notif_001"] = {
        "id": "notif_001", "user_id": u1, "title": "Booking Confirmed",
        "message": "Your booking for Black Party Dress has been confirmed.",
        "type": "booking", "read": False, "created_at": "2026-04-08"
    }
    notifications_db["notif_002"] = {
        "id": "notif_002", "user_id": u1, "title": "Return Reminder",
        "message": "Reminder: Canon EOS R5 Camera is due for return tomorrow.",
        "type": "reminder", "read": False, "created_at": "2026-04-08"
    }

tokens_db: dict = {}
seed_data()

# ─── Auth Helpers ─────────────────────────────────────────────────────────────

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    user_id = tokens_db.get(token)
    if not user_id or user_id not in users_db:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return users_db[user_id]

# ─── Schemas ──────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email: str
    password: str  # In production: hashed

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
    # Check duplicate email
    for u in users_db.values():
        if u["email"] == req.email:
            raise HTTPException(status_code=400, detail="Email already registered")
    user_id = f"user_{uuid.uuid4().hex[:8]}"
    token = f"token_{uuid.uuid4().hex}"
    user = {
        "id": user_id, "name": req.name, "email": req.email,
        "phone": req.phone, "college": req.college,
        "avatar": None, "verified": False, "rating": 0.0,
        "listed": 0, "bookings": 0, "reviews_count": 0,
        "saved_items": [], "created_at": str(date.today()),
        "token": token
    }
    users_db[user_id] = user
    tokens_db[token] = user_id
    return {"token": token, "user": {k: v for k, v in user.items() if k != "token"}}

@app.post("/api/auth/login")
def login(req: LoginRequest):
    for user in users_db.values():
        if user["email"] == req.email:
            # Demo: any password works for seeded users
            return {"token": user["token"], "user": {k: v for k, v in user.items() if k != "token"}}
    raise HTTPException(status_code=401, detail="Invalid email or password")

# ─── User Routes ──────────────────────────────────────────────────────────────

@app.get("/api/users/me")
def get_me(current_user=Depends(get_current_user)):
    return {k: v for k, v in current_user.items() if k != "token"}

@app.get("/api/users/{user_id}")
def get_user(user_id: str):
    user = users_db.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Return public profile only
    return {
        "id": user["id"], "name": user["name"], "college": user["college"],
        "avatar": user["avatar"], "verified": user["verified"],
        "rating": user["rating"], "listed": user["listed"],
        "reviews_count": user["reviews_count"]
    }

@app.put("/api/users/me")
def update_profile(name: str = None, phone: str = None, college: str = None,
                   current_user=Depends(get_current_user)):
    if name: current_user["name"] = name
    if phone: current_user["phone"] = phone
    if college: current_user["college"] = college
    return {k: v for k, v in current_user.items() if k != "token"}

# ─── Items Routes ─────────────────────────────────────────────────────────────

@app.get("/api/items")
def list_items(category: Optional[str] = None, q: Optional[str] = None,
               skip: int = 0, limit: int = 20):
    items = list(items_db.values())
    if category and category.lower() != "all":
        items = [i for i in items if i["category"].lower() == category.lower()]
    if q:
        q_lower = q.lower()
        items = [i for i in items if q_lower in i["name"].lower() or q_lower in i["description"].lower()]
    # Attach owner info
    result = []
    for item in items[skip:skip+limit]:
        owner = users_db.get(item["owner_id"], {})
        result.append({**item, "owner_name": owner.get("name", "Unknown"), "owner_verified": owner.get("verified", False)})
    return {"items": result, "total": len(items)}

@app.get("/api/items/featured")
def featured_items():
    items = sorted(items_db.values(), key=lambda x: x["rating"], reverse=True)[:6]
    result = []
    for item in items:
        owner = users_db.get(item["owner_id"], {})
        result.append({**item, "owner_name": owner.get("name", "Unknown")})
    return {"items": result}

@app.get("/api/items/{item_id}")
def get_item(item_id: str):
    item = items_db.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    owner = users_db.get(item["owner_id"], {})
    reviews = [r for r in reviews_db.values() if r["item_id"] == item_id]
    return {**item, "owner_name": owner.get("name", "Unknown"),
            "owner_verified": owner.get("verified", False),
            "owner_rating": owner.get("rating", 0),
            "reviews": reviews}

@app.post("/api/items")
def create_item(req: ItemCreateRequest, current_user=Depends(get_current_user)):
    item_id = f"item_{uuid.uuid4().hex[:8]}"
    item = {
        "id": item_id, "owner_id": current_user["id"],
        "name": req.name, "category": req.category,
        "description": req.description, "brand": req.brand,
        "size": req.size, "color": req.color, "condition": req.condition,
        "price_per_day": req.price_per_day, "deposit": req.deposit,
        "min_days": req.min_days, "max_days": req.max_days,
        "late_fee": req.price_per_day, "images": [],
        "rating": 0.0, "review_count": 0, "available": True,
        "booked_dates": [], "created_at": str(date.today())
    }
    items_db[item_id] = item
    current_user["listed"] = current_user.get("listed", 0) + 1
    return item

@app.post("/api/items/{item_id}/images")
async def upload_item_image(item_id: str, file: UploadFile = File(...),
                             current_user=Depends(get_current_user)):
    item = items_db.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item["owner_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Not the owner")
    ext = Path(file.filename).suffix
    filename = f"{item_id}_{uuid.uuid4().hex[:6]}{ext}"
    path = UPLOAD_DIR / filename
    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    item["images"].append(f"/uploads/{filename}")
    return {"image_url": f"/uploads/{filename}"}

@app.delete("/api/items/{item_id}")
def delete_item(item_id: str, current_user=Depends(get_current_user)):
    item = items_db.get(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item["owner_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Not the owner")
    del items_db[item_id]
    return {"message": "Item deleted"}

@app.get("/api/users/me/items")
def my_items(current_user=Depends(get_current_user)):
    items = [i for i in items_db.values() if i["owner_id"] == current_user["id"]]
    return {"items": items}

# ─── Bookings Routes ──────────────────────────────────────────────────────────

@app.post("/api/bookings")
def create_booking(req: BookingCreateRequest, current_user=Depends(get_current_user)):
    item = items_db.get(req.item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item["owner_id"] == current_user["id"]:
        raise HTTPException(status_code=400, detail="Cannot book your own item")
    
    start = datetime.strptime(req.start_date, "%Y-%m-%d").date()
    end = datetime.strptime(req.end_date, "%Y-%m-%d").date()
    if end <= start:
        raise HTTPException(status_code=400, detail="End date must be after start date")
    
    duration = (end - start).days
    if duration < item["min_days"]:
        raise HTTPException(status_code=400, detail=f"Minimum rental is {item['min_days']} day(s)")
    if duration > item["max_days"]:
        raise HTTPException(status_code=400, detail=f"Maximum rental is {item['max_days']} day(s)")
    
    # Check conflicts
    for bd in item.get("booked_dates", []):
        bd_start = datetime.strptime(bd["start"], "%Y-%m-%d").date()
        bd_end = datetime.strptime(bd["end"], "%Y-%m-%d").date()
        if not (end <= bd_start or start >= bd_end):
            raise HTTPException(status_code=400, detail="Item is not available on selected dates")
    
    subtotal = duration * item["price_per_day"]
    total = subtotal + item["deposit"]
    
    booking_id = f"booking_{uuid.uuid4().hex[:8]}"
    booking = {
        "id": booking_id, "item_id": req.item_id, "borrower_id": current_user["id"],
        "owner_id": item["owner_id"], "start_date": req.start_date, "end_date": req.end_date,
        "duration_days": duration, "price_per_day": item["price_per_day"],
        "subtotal": subtotal, "deposit": item["deposit"], "total": total,
        "pickup_location": req.pickup_location, "status": "pending_confirmation",
        "pickup_photos": [], "return_photos": [], "created_at": str(date.today())
    }
    bookings_db[booking_id] = booking
    
    # Block dates
    item["booked_dates"].append({"start": req.start_date, "end": req.end_date})
    current_user["bookings"] = current_user.get("bookings", 0) + 1
    
    # Create notification for owner
    notif_id = f"notif_{uuid.uuid4().hex[:8]}"
    notifications_db[notif_id] = {
        "id": notif_id, "user_id": item["owner_id"],
        "title": "New Booking Request",
        "message": f"{current_user['name']} wants to borrow '{item['name']}'",
        "type": "booking", "read": False, "created_at": str(date.today())
    }
    return booking

@app.get("/api/bookings/my")
def my_bookings(current_user=Depends(get_current_user)):
    """Bookings where I am the borrower"""
    my = [b for b in bookings_db.values() if b["borrower_id"] == current_user["id"]]
    result = []
    for b in my:
        item = items_db.get(b["item_id"], {})
        owner = users_db.get(b["owner_id"], {})
        result.append({**b, "item_name": item.get("name", ""), "owner_name": owner.get("name", "")})
    return {"bookings": result}

@app.get("/api/bookings/rentals")
def my_rentals(current_user=Depends(get_current_user)):
    """Bookings where I am the owner (my items being rented)"""
    my = [b for b in bookings_db.values() if b["owner_id"] == current_user["id"]]
    result = []
    for b in my:
        item = items_db.get(b["item_id"], {})
        borrower = users_db.get(b["borrower_id"], {})
        result.append({**b, "item_name": item.get("name", ""), "borrower_name": borrower.get("name", "")})
    return {"bookings": result}

@app.get("/api/bookings/{booking_id}")
def get_booking(booking_id: str, current_user=Depends(get_current_user)):
    booking = bookings_db.get(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking["borrower_id"] != current_user["id"] and booking["owner_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied")
    item = items_db.get(booking["item_id"], {})
    owner = users_db.get(booking["owner_id"], {})
    borrower = users_db.get(booking["borrower_id"], {})
    return {**booking, "item_name": item.get("name", ""),
            "owner_name": owner.get("name", ""), "borrower_name": borrower.get("name", "")}

@app.put("/api/bookings/{booking_id}/status")
def update_booking_status(booking_id: str, new_status: str,
                           current_user=Depends(get_current_user)):
    booking = bookings_db.get(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    valid_transitions = {
        "pending_confirmation": ["confirmed", "rejected"],
        "confirmed": ["active", "cancelled"],
        "active": ["completed", "disputed"],
        "pending_pickup": ["active"],
    }
    allowed = valid_transitions.get(booking["status"], [])
    if new_status not in allowed:
        raise HTTPException(status_code=400, detail=f"Cannot transition to {new_status}")
    
    booking["status"] = new_status
    return booking

@app.post("/api/bookings/{booking_id}/pickup-photos")
async def upload_pickup_photos(booking_id: str, files: List[UploadFile] = File(...),
                                current_user=Depends(get_current_user)):
    booking = bookings_db.get(booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    urls = []
    for file in files:
        ext = Path(file.filename).suffix
        filename = f"pickup_{booking_id}_{uuid.uuid4().hex[:6]}{ext}"
        path = UPLOAD_DIR / filename
        with open(path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        url = f"/uploads/{filename}"
        booking["pickup_photos"].append(url)
        urls.append(url)
    booking["status"] = "active"
    return {"urls": urls}

# ─── Reviews Routes ───────────────────────────────────────────────────────────

@app.post("/api/reviews")
def create_review(req: ReviewCreateRequest, current_user=Depends(get_current_user)):
    booking = bookings_db.get(req.booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking["borrower_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Only borrower can review")
    if booking["status"] != "completed":
        raise HTTPException(status_code=400, detail="Can only review completed bookings")
    
    review_id = f"review_{uuid.uuid4().hex[:8]}"
    review = {
        "id": review_id, "item_id": booking["item_id"],
        "booking_id": req.booking_id, "reviewer_id": current_user["id"],
        "reviewer_name": current_user["name"], "rating": req.rating,
        "comment": req.comment, "created_at": str(date.today())
    }
    reviews_db[review_id] = review
    
    # Update item rating
    item = items_db.get(booking["item_id"])
    if item:
        reviews = [r for r in reviews_db.values() if r["item_id"] == item["id"]]
        item["rating"] = sum(r["rating"] for r in reviews) / len(reviews)
        item["review_count"] = len(reviews)
    
    current_user["reviews_count"] = current_user.get("reviews_count", 0) + 1
    return review

@app.get("/api/items/{item_id}/reviews")
def item_reviews(item_id: str):
    reviews = [r for r in reviews_db.values() if r["item_id"] == item_id]
    return {"reviews": reviews}

# ─── Saved Items ──────────────────────────────────────────────────────────────

@app.post("/api/saved/{item_id}")
def save_item(item_id: str, current_user=Depends(get_current_user)):
    if item_id not in current_user["saved_items"]:
        current_user["saved_items"].append(item_id)
    return {"saved": True}

@app.delete("/api/saved/{item_id}")
def unsave_item(item_id: str, current_user=Depends(get_current_user)):
    if item_id in current_user["saved_items"]:
        current_user["saved_items"].remove(item_id)
    return {"saved": False}

@app.get("/api/saved")
def get_saved_items(current_user=Depends(get_current_user)):
    saved = [items_db[i] for i in current_user["saved_items"] if i in items_db]
    result = []
    for item in saved:
        owner = users_db.get(item["owner_id"], {})
        result.append({**item, "owner_name": owner.get("name", "")})
    return {"items": result}

# ─── Notifications ────────────────────────────────────────────────────────────

@app.get("/api/notifications")
def get_notifications(current_user=Depends(get_current_user)):
    notifs = [n for n in notifications_db.values() if n["user_id"] == current_user["id"]]
    notifs.sort(key=lambda x: x["created_at"], reverse=True)
    return {"notifications": notifs}

@app.put("/api/notifications/{notif_id}/read")
def mark_read(notif_id: str, current_user=Depends(get_current_user)):
    notif = notifications_db.get(notif_id)
    if notif and notif["user_id"] == current_user["id"]:
        notif["read"] = True
    return {"success": True}

# ─── Categories ───────────────────────────────────────────────────────────────

@app.get("/api/categories")
def get_categories():
    return {"categories": [
        {"id": "clothes", "name": "Clothes", "icon": "👗"},
        {"id": "electronics", "name": "Electronics", "icon": "🎮"},
        {"id": "books", "name": "Books", "icon": "📚"},
        {"id": "accessories", "name": "Accessories", "icon": "🎒"},
        {"id": "sports", "name": "Sports", "icon": "⚽"},
        {"id": "tools", "name": "Tools", "icon": "🔧"},
        {"id": "music", "name": "Music", "icon": "🎸"},
        {"id": "other", "name": "Other", "icon": "📦"},
    ]}

# ─── Earnings ─────────────────────────────────────────────────────────────────

@app.get("/api/earnings")
def get_earnings(current_user=Depends(get_current_user)):
    completed = [b for b in bookings_db.values()
                 if b["owner_id"] == current_user["id"] and b["status"] == "completed"]
    total = sum(b["subtotal"] for b in completed)
    pending_bookings = [b for b in bookings_db.values()
                        if b["owner_id"] == current_user["id"] and b["status"] in ("active", "confirmed")]
    pending = sum(b["subtotal"] for b in pending_bookings)
    return {
        "total_earned": total,
        "pending": pending,
        "completed_rentals": len(completed),
        "monthly_breakdown": []  # Would be computed from dates in production
    }

# ─── Health ───────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "version": "1.0.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
