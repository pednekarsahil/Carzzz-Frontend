"""
PARTNER ROUTES MODULE - Car Rental Platform

partner_routes.py 

This module defines all API endpoints for the partner (vendor) system in a car rental platform.
It handles partner authentication, car management, order creation, and review functionality.

ARCHITECTURE:
- FastAPI Router with dependency injection for authentication
- MongoDB for data persistence (orders, partnercars, partners collections)
- Socket.io integration for real-time updates
- Pydantic models for request validation

KEY FEATURES:
1. Authentication Flow:
   - Firebase authentication for social login
   - OTP-based registration verification
   - Traditional email/password login
   - Token verification endpoints

2. Car Management (Partner Protected):
   - Add new cars with pricing (daily, hourly, half-day rates)
   - Update car details and status
   - Delete cars
   - Status management (available/rented/maintenance)

3. Order System:
   - Create orders after successful payment
   - Validate car availability and booking conflicts
   - Update car status to 'rented' automatically
   - Track partner earnings and total rentals
   - Real-time socket events for status updates

4. Review System:
   - Riders can add reviews (authentication required)
   - Public access to view car reviews

5. Public Endpoints:
   - Browse all available cars (no auth needed)
   - OTP send/verify for registration

SECURITY:
- authenticate_partner: Validates partner JWT tokens
- authenticate: Validates rider JWT tokens
- All sensitive endpoints protected with appropriate middleware

DATABASE OPERATIONS:
- Partner: Register, login, dashboard stats
- Cars: CRUD operations with location and pricing
- Orders: Create with conflict detection
- Reviews: Add/retrieve with rating and comments

SOCKET EVENTS:
- car_status_updated: Broadcast when car status changes
- car_rented: Notify when a car is rented

ENDPOINT CATEGORIES:
- Public (No Auth): /send-otp, /verify-otp, /register, /login, /verify-token, /cars
- Partner Protected: /dashboard, /cars (POST), /cars/{id} (PUT/DELETE), /cars/{id}/status
- Rider Protected: /cars/{id}/review (POST)
- Mixed Auth: /create-order (both riders and partners can create orders)

FILES:
- Controllers: partner_controller.py (business logic)
- Middleware: partner_middleware.py, auth_middleware.py (authentication)

USAGE:
This router is mounted on a FastAPI app instance with base path /partners.
Socket.io instance is injected via set_io_for_partner() function.

DEPENDENCIES:
- fastapi: APIRouter, Request, Depends
- pydantic: BaseModel for request validation
- bson: ObjectId for MongoDB operations
- datetime: For timestamp handling
- logging: For error tracking
"""

from fastapi import APIRouter, Request, Depends
from fastapi.responses import JSONResponse
from typing import Optional
from pydantic import BaseModel
from datetime import datetime
import logging

from ..controllers import partner_controller
from middleware.partner_middleware import authenticate_partner
from middleware.auth_middleware import authenticate

logger = logging.getLogger(__name__)

router = APIRouter()
sio = None

def set_io_for_partner(socket_instance):
    """Set Socket.io instance for partner controller"""
    global sio
    sio = socket_instance
    partner_controller.set_io(socket_instance)

# =============================================
# REQUEST MODELS
# =============================================

class SendOTPRequest(BaseModel):
    businessEmail: str

class VerifyOTPRequest(BaseModel):
    businessEmail: str
    otp: str

class RegisterPartnerRequest(BaseModel):
    fullname: str
    businessEmail: str
    businessName: str
    phoneNumber: str
    businessAddress: str
    businessType: str
    password: str
    agreedToTerms: bool

class PartnerLoginRequest(BaseModel):
    businessEmail: str
    password: str

class AddCarRequest(BaseModel):
    model: str
    registrationNumber: Optional[str] = ""
    type: str
    fuelType: str
    dailyRate: float
    hourlyRate: Optional[float] = None
    halfDayRate: Optional[float] = None
    minRentalHours: Optional[int] = 1
    maxRentalHours: Optional[int] = 72
    location: dict
    description: Optional[str] = ""
    images: Optional[list] = []
    features: Optional[list] = []
    offer: Optional[dict] = None

class UpdateStatusRequest(BaseModel):
    status: str

class ReviewRequest(BaseModel):
    rating: float
    comment: str

class PartnerFirebaseAuthRequest(BaseModel):
    firebaseToken: str
    email: Optional[str] = None
    fullname: Optional[str] = None
    googlePicture: Optional[str] = None

# =============================================
# PUBLIC ROUTES (No authentication required)
# =============================================

@router.post("/auth/firebase")
async def partner_firebase_auth(request: Request, data: PartnerFirebaseAuthRequest):
    """Authenticate partner with Firebase token"""
    request._body = data.dict()
    return await partner_controller.partner_firebase_auth(request)

@router.post("/send-otp")
async def send_otp(request: Request, data: SendOTPRequest):
    """Send OTP for partner registration"""
    return await partner_controller.send_partner_otp(request)

@router.post("/verify-otp")
async def verify_otp(request: Request, data: VerifyOTPRequest):
    """Verify partner OTP"""
    return await partner_controller.verify_partner_otp(request)

@router.post("/register")
async def register_partner(request: Request, data: RegisterPartnerRequest):
    """Register new partner"""
    request._body = data.dict()
    return await partner_controller.register_partner(request)

@router.post("/login")
async def login_partner(request: Request, data: PartnerLoginRequest):
    """Partner login"""
    request._body = data.dict()
    return await partner_controller.partner_login(request)

@router.post("/verify-token")
async def verify_token(request: Request):
    """Verify partner token"""
    return await partner_controller.verify_partner_token(request)

@router.get("/cars")
async def get_all_cars(request: Request):
    """Get all available cars (for riders)"""
    return await partner_controller.get_all_cars(request)

# =============================================
# PROTECTED ROUTES (Partner authentication required)
# =============================================

@router.get("/dashboard")
async def get_dashboard(request: Request, user: dict = Depends(authenticate_partner)):
    """Get partner dashboard data"""
    request.state.user = user
    return await partner_controller.get_partner_dashboard(request)

@router.post("/cars")
async def add_car(request: Request, data: AddCarRequest, user: dict = Depends(authenticate_partner)):
    """Add new car for partner"""
    request.state.user = user
    request._body = data.dict()
    return await partner_controller.add_partner_car(request)

@router.put("/cars/{car_id}")
async def update_car(request: Request, car_id: str, data: dict, user: dict = Depends(authenticate_partner)):
    """Update car details"""
    request.state.user = user
    request._body = data
    return await partner_controller.update_partner_car(request, car_id)

@router.delete("/cars/{car_id}")
async def delete_car(request: Request, car_id: str, user: dict = Depends(authenticate_partner)):
    """Delete car"""
    request.state.user = user
    return await partner_controller.delete_partner_car(request, car_id)

@router.put("/cars/{car_id}/status")
async def update_car_status(request: Request, car_id: str, data: UpdateStatusRequest, user: dict = Depends(authenticate_partner)):
    """Update car status"""
    request.state.user = user
    request._body = data.dict()
    return await partner_controller.update_car_status(request, car_id)

# =============================================
# REVIEW ROUTES (Rider authentication required)
# =============================================

@router.get("/cars/{car_id}/reviews")
async def get_car_reviews(request: Request, car_id: str):
    """Get all reviews for a car"""
    return await partner_controller.get_car_reviews(request, car_id)

@router.post("/cars/{car_id}/review")
async def add_car_review(request: Request, car_id: str, data: ReviewRequest, user: dict = Depends(authenticate)):
    """Add a review for a car"""
    request.state.user = user
    request._body = data.dict()
    return await partner_controller.add_car_review(request, car_id)

# =============================================
# NOTE: /create-order endpoint is handled by order_routes.py
# The order_routes.py file contains the complete order creation logic
# including car hold system, availability checks, and order confirmation
# =============================================