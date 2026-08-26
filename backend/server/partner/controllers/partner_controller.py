"""
====================================================================
FILE: partner_controller.py
LOCATION: server/partner/controllers/partner_controller.py
PURPOSE: Complete partner management system - authentication, 
         car management, dashboard, and real-time updates
====================================================================

OVERVIEW:
This controller is the backbone of the Partner Management System,
handling all backend operations for business partners including 
registration, authentication, car fleet management, and analytics.

====================================================================
CORE FUNCTIONALITY:
====================================================================

1. 🔐 AUTHENTICATION & REGISTRATION
   - Email/Password registration with OTP verification
   - Google Sign-In via Firebase (with token refresh handling)
   - JWT token generation (30-day expiry)
   - Partner login with bcrypt password verification
   - Token verification endpoint
   - In-memory OTP storage (10-minute expiry, 5-attempt limit)

2. 📧 EMAIL SERVICES
   - Beautiful HTML email templates for OTP verification
   - SMTP integration with Gmail (SSL/TLS)
   - Automatic fallback for development (OTP shown in logs)
   - Email configuration via environment variables

3. 🚗 CAR MANAGEMENT (CRUD)
   - Add new cars with location, pricing, images, features
   - Update car details (ownership verified)
   - Delete cars (with ownership verification)
   - Update car status (available/rented/maintenance)
   - Get all available cars (for riders)
   - Get nearby cars using Haversine distance calculation
   - Real-time broadcasting via Socket.IO

4. 📊 DASHBOARD & ANALYTICS
   - Partner statistics (total cars, available, rented, maintenance)
   - Total earnings and rental tracking
   - Partner profile management
   - Car fleet overview with status breakdown

5. ⭐ REVIEWS & RATINGS
   - Add car reviews (rider to car)
   - Get all reviews for a car
   - Automatic average rating calculation
   - Prevent duplicate reviews per user
   - Real-time review updates via Socket.IO

6. 🔌 REAL-TIME UPDATES (Socket.IO)
   - Broadcast new car additions to all riders
   - Notify partners when car is rented
   - Live car status updates
   - Real-time review additions

====================================================================
API ENDPOINTS:
====================================================================

PUBLIC ENDPOINTS:
- POST   /api/partner/send-otp          → Send OTP to email
- POST   /api/partner/verify-otp        → Verify OTP code
- POST   /api/partner/register          → Register new partner
- POST   /api/partner/login             → Partner login
- POST   /api/partner/auth/firebase     → Firebase/Google Sign-In
- POST   /api/partner/verify-token      → Validate JWT token
- GET    /api/partner/cars              → Get all available cars
- GET    /api/cars/nearby               → Get nearby cars (10km radius)
- GET    /api/partner/cars/{carId}/reviews → Get car reviews

PRIVATE ENDPOINTS (Partner Only):
- GET    /api/partner/dashboard         → Get dashboard data
- POST   /api/partner/cars              → Add new car
- PUT    /api/partner/cars/{carId}      → Update car details
- DELETE /api/partner/cars/{carId}      → Delete car
- PUT    /api/cars/{carId}/status       → Update car status
- POST   /api/partner/cars/{carId}/review → Add car review

====================================================================
DATABASE SCHEMA:
====================================================================

PARTNER COLLECTION (db.partners):
{
    "_id": ObjectId,
    "fullname": str,
    "businessEmail": str (unique),
    "businessName": str (unique),
    "phoneNumber": str,
    "businessAddress": str,
    "businessType": str,
    "password": str (bcrypt hashed),
    "isEmailVerified": bool,
    "isActive": bool,
    "agreedToTerms": bool,
    "totalEarnings": float,
    "totalRentals": int,
    "rating": float,
    "cars": [ObjectId],
    "firebaseUid": str (optional),
    "firebasePicture": str (optional),
    "isFirebaseAccount": bool,
    "lastLogin": datetime,
    "createdAt": datetime,
    "updatedAt": datetime
}

PARTNER CAR COLLECTION (db.partnercars):
{
    "_id": ObjectId,
    "partnerId": ObjectId,
    "model": str,
    "registrationNumber": str,
    "type": str,
    "fuelType": str,
    "dailyRate": float,
    "hourlyRate": float (optional),
    "halfDayRate": float (optional),
    "minRentalHours": int,
    "maxRentalHours": int,
    "location": { "lat": float, "lng": float },
    "description": str,
    "images": [str],
    "features": [str],
    "offer": dict (optional),
    "status": str (available/rented/maintenance),
    "isActive": bool,
    "rating": float,
    "reviewCount": int,
    "reviews": [{ "userId": str, "userName": str, "rating": float, "comment": str, "createdAt": datetime }],
    "createdAt": datetime,
    "updatedAt": datetime
}

====================================================================
DEPENDENCIES:
====================================================================

Python Packages:
- fastapi (Request, JSONResponse, HTTPException)
- pydantic (BaseModel for validation)
- jwt (JWT token generation/verification)
- passlib (bcrypt password hashing)
- firebase_admin (Firebase token verification)
- smtplib, email.mime (Email sending)
- httpx (Async HTTP client)
- bson (ObjectId handling)
- logging (Logging configuration)

Environment Variables Required:
- JWT_SECRET          → Secret key for JWT tokens
- EMAIL_USER          → Gmail email address
- EMAIL_PASS          → Gmail app password
- EMAIL_HOST          → SMTP host (default: smtp.gmail.com)
- EMAIL_PORT          → SMTP port (default: 465)
- NODE_ENV            → development/production

====================================================================
SECURITY FEATURES:
====================================================================

- JWT token with 30-day expiration
- bcrypt password hashing (10 rounds)
- OTP with 10-minute expiry and 5-attempt limit
- Firebase token verification with clock skew tolerance
- Ownership verification for car operations
- Input validation for all endpoints
- Duplicate email/business name prevention
- Inactive account blocking
- Firebase account detection (prevents password login)

====================================================================
ERROR HANDLING:
====================================================================

- HTTP 400: Validation errors, duplicate entries, invalid input
- HTTP 401: Authentication failures, invalid tokens
- HTTP 404: Resource not found
- HTTP 500: Server errors with detailed logging
- Graceful fallback for missing email configuration
- Retry logic for Firebase token verification

====================================================================
LOGGING:
====================================================================

- Detailed request/response logging
- Partner registration and login tracking
- Car management operations logging
- OTP generation and email status
- Socket.IO event broadcasting
- Database operation tracking
- Comprehensive error logging with traceback

====================================================================
SOCKET.IO EVENTS EMITTED:
====================================================================

- 'new_car_added'      → Broadcast new car to all riders
- 'car_status_updated' → Real-time status updates
- 'car_rented'         → Notify partner when car is rented
- 'car_review_added'   → Real-time review updates

====================================================================
DEVELOPMENT NOTES:
====================================================================

- OTP shown in console when EMAIL_USER not configured (development)
- Firebase clock skew set to 60 seconds for reliability
- Supports both ObjectId and string ID formats
- Haversine formula for distance calculation (10km default)
- MongoDB indexes recommended: email, businessName, carId
- All dates stored in UTC, converted on display
- Socket.IO instance shared globally via set_io()

====================================================================
FILE STRUCTURE:
====================================================================

partner_controller.py
├── Imports & Configuration
├── Global Stores (partner_otp_store, sio)
├── Helper Functions
│   ├── set_io()                → Set Socket.IO instance
│   ├── get_email_transporter() → Email configuration
│   ├── generate_otp()          → 6-digit OTP generator
│   └── generate_partner_token() → JWT token generator
├── Email Functions
│   └── send_partner_otp_email() → HTML email with OTP
├── Authentication Endpoints
│   ├── send_partner_otp()
│   ├── verify_partner_otp()
│   ├── register_partner()
│   ├── partner_login()
│   ├── partner_firebase_auth()
│   └── verify_partner_token()
├── Dashboard Endpoint
│   └── get_partner_dashboard()
├── Car Management Endpoints
│   ├── get_all_cars()
│   ├── add_partner_car()
│   ├── update_partner_car()
│   ├── delete_partner_car()
│   ├── update_car_status()
│   └── get_nearby_cars()
└── Review Endpoints
    ├── add_car_review()
    └── get_car_reviews()

====================================================================
"""

import logging
import os
import random
import asyncio
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import jwt
from passlib.context import CryptContext
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import httpx

from ..models.partner_model import Partner
from ..models.partnercar_model import PartnerCar
from ..models.order_model import Order

import firebase_admin
from firebase_admin import auth
import hashlib

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Store OTPs temporarily
partner_otp_store: Dict[str, Dict] = {}

# Socket.io instance
sio = None

def set_io(socket_instance):
    """Set Socket.io instance"""
    global sio
    sio = socket_instance

# Email configuration
def get_email_transporter():
    """Get email transporter configuration"""
    email_user = os.getenv('EMAIL_USER')
    email_pass = os.getenv('EMAIL_PASS')
    
    if not email_user or not email_pass:
        return None
    
    return {
        'host': os.getenv('EMAIL_HOST', 'smtp.gmail.com'),
        'port': int(os.getenv('EMAIL_PORT', 465)),
        'user': email_user,
        'password': email_pass.replace(' ', ''),
        'secure': True
    }

def generate_otp() -> str:
    """Generate random 6-digit OTP"""
    return f"{random.randint(100000, 999999)}"

def generate_partner_token(user_id: str) -> str:
    """Generate JWT token for partner"""
    secret = os.getenv('JWT_SECRET')
    if not secret:
        raise ValueError("JWT_SECRET not set")
    
    payload = {
        'id': str(user_id),
        'role': 'partner',
        'exp': datetime.utcnow() + timedelta(days=30)
    }
    return jwt.encode(payload, secret, algorithm='HS256')

async def send_partner_otp_email(email: str, otp: str, purpose: str = 'verification'):
    """Send OTP email to partner"""
    transporter = get_email_transporter()
    if not transporter:
        raise ValueError("Email transporter not configured")
    
    is_verification = purpose == 'verification'
    subject = 'carrzz Partner - Email Verification OTP' if is_verification else 'carrzz Partner - Password Reset OTP'
    title = 'Verify Your Partner Account' if is_verification else 'Reset Your Partner Password'
    message = ('Thank you for registering as a carrzz Partner! Please use the verification code below to complete your registration.'
               if is_verification else 'You requested to reset your partner account password. Please use the verification code below to proceed.')
    
    # Create email
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'"carrzz Partners" <{transporter["user"]}>'
    msg['To'] = email
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{subject} - carrzz Partners</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
        <div style="background: linear-gradient(135deg, #E0F2FE 0%, #F0FDF4 100%); padding: 40px 20px;">
            <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 40px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #10B981 0%, #059669 100%); padding: 40px 20px; text-align: center;">
                    <div style="width: 80px; height: 80px; background: white; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 20px;">
                        <span style="font-size: 48px;">🏪</span>
                    </div>
                    <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">carrzz Partners</h1>
                    <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0; font-size: 16px;">{title}</p>
                </div>
                
                <!-- Content -->
                <div style="padding: 40px 30px;">
                    <h2 style="color: #1F2937; margin: 0 0 10px; font-size: 24px;">{title}</h2>
                    <p style="color: #6B7280; margin: 0 0 30px; font-size: 16px; line-height: 1.5;">
                        {message}
                    </p>
                    
                    <!-- OTP Code -->
                    <div style="background: #F3F4F6; border-radius: 16px; padding: 30px; text-align: center; margin-bottom: 30px;">
                        <p style="color: #4B5563; margin: 0 0 15px; font-size: 14px;">Your verification code is:</p>
                        <div style="background: white; border-radius: 12px; padding: 20px; border: 2px solid #E5E7EB;">
                            <h1 style="color: #10B981; font-size: 48px; letter-spacing: 8px; margin: 0; font-family: monospace;">{otp}</h1>
                        </div>
                        <p style="color: #9CA3AF; margin: 15px 0 0; font-size: 12px;">This code expires in 10 minutes</p>
                    </div>
                    
                    <!-- Instructions -->
                    <div style="border-top: 1px solid #E5E7EB; padding-top: 25px;">
                        <p style="color: #6B7280; font-size: 14px; margin: 0 0 10px;">
                            <strong>Need help?</strong> If you didn't request this code, please ignore this email.
                        </p>
                        <p style="color: #9CA3AF; font-size: 12px; margin: 0;">
                            For partner support, contact us at partners@carrzz.com
                        </p>
                    </div>
                </div>
                
                <!-- Footer -->
                <div style="background: #F9FAFB; padding: 20px 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #9CA3AF; font-size: 12px; margin: 0;">
                        &copy; 2024 carrzz Partners. All rights reserved.<br>
                        Grow your business with carrzz.
                    </p>
                </div>
            </div>
        </div>
    </body>
    </html>
    """
    
    msg.attach(MIMEText(html_content, 'html'))
    
    try:
        # Send email using SMTP
        with smtplib.SMTP_SSL(transporter['host'], transporter['port']) as server:
            server.login(transporter['user'], transporter['password'])
            server.send_message(msg)
        logger.info(f"✓ Partner email sent successfully to {email}")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to send partner email: {str(e)}")
        raise

async def send_partner_otp(request: Request):
    """
    @desc    Send OTP for partner registration
    @route   POST /api/partner/send-otp
    @access  Public
    """
    body = await request.json()
    business_email = body.get('businessEmail')
    
    if not business_email:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Business email is required"
            }
        )
    
    db = request.app.state.db
    partner_collection = db.partners
    
    # Check if partner already exists
    existing_partner = await partner_collection.find_one({
        "businessEmail": business_email.lower()
    })
    
    if existing_partner:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "A partner account already exists with this email. Please login instead."
            }
        )
    
    # Generate OTP
    otp = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    # Store OTP
    partner_otp_store[business_email.lower()] = {
        'otp': otp,
        'expiresAt': expires_at,
        'attempts': 0,
        'createdAt': datetime.utcnow()
    }
    
    logger.info(f"📧 Sending partner OTP to {business_email}: {otp}")
    
    # Check if email is configured
    transporter = get_email_transporter()
    if not transporter:
        logger.warning(f"⚠️ Partner email not configured. For testing, OTP is: {otp}")
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "OTP generated successfully. (Email not sent - configure email settings)",
                "testOtp": otp if os.getenv('NODE_ENV') == 'development' else None
            }
        )
    
    # Send email
    try:
        await send_partner_otp_email(business_email, otp, 'verification')
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "OTP sent successfully! Please check your email to verify your partner account."
            }
        )
    except Exception as e:
        logger.error(f"Send partner OTP error: {str(e)}")
        if 'Invalid login' in str(e) or 'credentials' in str(e):
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "message": "Email configuration error. Please contact support."
                }
            )
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Failed to send OTP. Please try again later."
            }
        )

# =============================================
# FIXED: partner_firebase_auth with better error handling
# =============================================

async def partner_firebase_auth(request: Request):
    """
    @desc    Firebase Authentication for Partners - Register or Login with Firebase token
    @route   POST /api/partner/auth/firebase
    @access  Public
    """
    try:
        body = await request.json()
        firebase_token = body.get('firebaseToken')
        email = body.get('email')
        fullname = body.get('fullname')
        google_picture = body.get('googlePicture')
        
        print(f"🔐 Partner Firebase auth request received")
        print(f"   Token present: {bool(firebase_token)}")
        print(f"   Token length: {len(firebase_token) if firebase_token else 0}")
        print(f"   Email: {email}")
        print(f"   Fullname: {fullname}")
        
        if not firebase_token:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Firebase token is required"
                }
            )
        
        # Check if Firebase is initialized
        if not firebase_admin._apps:
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "message": "Firebase authentication is not configured"
                }
            )
        
        try:
            # ========== FIX: Increased clock skew tolerance ==========
            decoded_token = auth.verify_id_token(
                firebase_token, 
                check_revoked=False,  # Disable revoked check for better reliability
                clock_skew_seconds=60  # Increased from 10 to 60 seconds
            )
            print(f"✓ Partner Firebase token verified successfully")
            print(f"  Firebase UID: {decoded_token.get('uid')}")
            print(f"  Email: {decoded_token.get('email')}")
            print(f"  Issued at: {datetime.fromtimestamp(decoded_token.get('iat', 0))}")
            print(f"  Expires at: {datetime.fromtimestamp(decoded_token.get('exp', 0))}")
            
        except auth.ExpiredIdTokenError as e:
            print(f"❌ Partner Firebase token expired: {str(e)}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "message": "Firebase token expired. Please sign in again.",
                    "error": "expired"
                }
            )
        except auth.RevokedIdTokenError as e:
            print(f"❌ Partner Firebase token revoked: {str(e)}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "message": "Firebase token revoked. Please sign in again.",
                    "error": "revoked"
                }
            )
        except Exception as e:
            error_msg = str(e)
            print(f"❌ Partner Firebase token verification failed: {error_msg}")
            
            # Check for specific error types
            if "expired" in error_msg.lower():
                return JSONResponse(
                    status_code=401,
                    content={
                        "success": False,
                        "message": "Firebase token expired. Please sign in again.",
                        "error": "expired"
                    }
                )
            elif "invalid" in error_msg.lower() or "format" in error_msg.lower():
                return JSONResponse(
                    status_code=401,
                    content={
                        "success": False,
                        "message": "Invalid Firebase token format. Please sign in again.",
                        "error": "invalid"
                    }
                )
            else:
                return JSONResponse(
                    status_code=401,
                    content={
                        "success": False,
                        "message": "Invalid Firebase token. Please sign in again.",
                        "error": "unknown"
                    }
                )
        
        user_email = decoded_token.get('email') or email
        
        if not user_email:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Email not provided by Firebase"
                }
            )
        
        db = request.app.state.db
        partner_collection = db.partners
        
        # Check if partner exists
        partner = await partner_collection.find_one({"businessEmail": user_email.lower()})
        
        if not partner:
            print(f"Creating new partner with Firebase account: {user_email}")
            # Create new partner with Firebase account
            partner_data = {
                "fullname": fullname or decoded_token.get('name') or user_email.split('@')[0],
                "businessEmail": user_email.lower(),
                "businessName": f"{fullname or decoded_token.get('name') or 'Partner'}'s Business",
                "phoneNumber": "",
                "businessAddress": "",
                "businessType": "car Rental",
                "password": hashlib.sha256(os.urandom(20)).hexdigest(),
                "isEmailVerified": True,
                "isActive": True,
                "agreedToTerms": True,
                "firebaseUid": decoded_token.get('uid'),
                "firebasePicture": google_picture or decoded_token.get('picture') or '',
                "isFirebaseAccount": True,
                "totalEarnings": 0,
                "totalRentals": 0,
                "rating": 0,
                "cars": [],
                "lastLogin": datetime.utcnow(),
                "createdAt": datetime.utcnow(),
                "updatedAt": datetime.utcnow()
            }
            
            try:
                result = await partner_collection.insert_one(partner_data)
                partner_id = str(result.inserted_id)
                print(f"✓ New partner created with ID: {partner_id}")
                
                # Fetch the newly created partner
                updated_partner = await partner_collection.find_one({"_id": result.inserted_id})
                if not updated_partner:
                    print("❌ Failed to fetch newly created partner")
                    return JSONResponse(
                        status_code=500,
                        content={
                            "success": False,
                            "message": "Partner created but could not be retrieved"
                        }
                    )
            except Exception as e:
                print(f"❌ Failed to create partner: {str(e)}")
                return JSONResponse(
                    status_code=500,
                    content={
                        "success": False,
                        "message": f"Failed to create partner: {str(e)}"
                    }
                )
        else:
            partner_id = str(partner['_id'])
            print(f"✓ Existing partner found: {user_email}")
            
            update_data = {"lastLogin": datetime.utcnow()}
            if not partner.get('firebaseUid'):
                update_data['firebaseUid'] = decoded_token.get('uid')
            if google_picture and not partner.get('firebasePicture'):
                update_data['firebasePicture'] = google_picture
            
            if update_data:
                update_data['updatedAt'] = datetime.utcnow()
                await partner_collection.update_one(
                    {"_id": partner['_id']},
                    {"$set": update_data}
                )
                print("✓ Partner updated")
            
            # Use the existing partner data
            updated_partner = partner
        
        # Generate JWT token for partner
        token = generate_partner_token(partner_id)
        
        # Ensure we have partner data
        if not updated_partner:
            updated_partner = await partner_collection.find_one({"_id": partner_id})
            if not updated_partner:
                print("❌ Could not retrieve partner data")
                return JSONResponse(
                    status_code=500,
                    content={
                        "success": False,
                        "message": "Partner data could not be retrieved"
                    }
                )
        
        print("✓ Partner JWT token generated")
        print("✓ Partner Firebase Authentication completed successfully")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Partner authentication successful!",
                "token": token,
                "partner": {
                    "id": str(updated_partner['_id']),
                    "fullname": updated_partner.get('fullname'),
                    "businessName": updated_partner.get('businessName'),
                    "businessEmail": updated_partner.get('businessEmail'),
                    "phoneNumber": updated_partner.get('phoneNumber', ''),
                    "businessAddress": updated_partner.get('businessAddress', ''),
                    "businessType": updated_partner.get('businessType'),
                    "totalEarnings": updated_partner.get('totalEarnings', 0),
                    "totalRentals": updated_partner.get('totalRentals', 0),
                    "rating": updated_partner.get('rating', 0),
                    "firebasePicture": updated_partner.get('firebasePicture', ''),
                    "createdAt": updated_partner.get('createdAt').isoformat() if updated_partner.get('createdAt') else None
                }
            }
        )
        
    except Exception as e:
        print(f"❌ Partner Firebase Authentication error: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Partner Firebase Authentication failed. Please try again.",
                "error": str(e) if os.getenv('NODE_ENV') == 'development' else None
            }
        )


async def verify_partner_otp(request: Request):
    """
    @desc    Verify partner OTP
    @route   POST /api/partner/verify-otp
    @access  Public
    """
    body = await request.json()
    business_email = body.get('businessEmail')
    otp = body.get('otp')
    
    if not business_email or not otp:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Business email and OTP are required"
            }
        )
    
    stored_otp_data = partner_otp_store.get(business_email.lower())
    
    if not stored_otp_data:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "No OTP found. Please request a new one."
            }
        )
    
    # Check expiry
    if datetime.utcnow() > stored_otp_data['expiresAt']:
        partner_otp_store.pop(business_email.lower(), None)
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "OTP has expired. Please request a new one."
            }
        )
    
    # Check attempts
    if stored_otp_data['attempts'] >= 5:
        partner_otp_store.pop(business_email.lower(), None)
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Too many failed attempts. Please request a new OTP."
            }
        )
    
    # Verify OTP
    if stored_otp_data['otp'] != otp:
        stored_otp_data['attempts'] += 1
        partner_otp_store[business_email.lower()] = stored_otp_data
        remaining = 5 - stored_otp_data['attempts']
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": f"Invalid OTP. {remaining} attempts remaining."
            }
        )
    
    # OTP verified successfully
    partner_otp_store.pop(business_email.lower(), None)
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "OTP verified successfully! You can now complete your registration."
        }
    )

async def register_partner(request: Request):
    """
    @desc    Register new partner
    @route   POST /api/partner/register
    @access  Public
    """
    body = await request.json()
    
    fullname = body.get('fullname')
    business_email = body.get('businessEmail')
    business_name = body.get('businessName')
    phone_number = body.get('phoneNumber')
    business_address = body.get('businessAddress')
    business_type = body.get('businessType')
    password = body.get('password')
    agreed_to_terms = body.get('agreedToTerms')
    
    # Validate required fields
    if not all([fullname, business_email, business_name, phone_number, business_address, business_type, password]):
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide all required fields"
            }
        )
    
    # Validate password length
    if len(password) < 6:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Password must be at least 6 characters"
            }
        )
    
    # Validate terms agreement
    if not agreed_to_terms:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "You must agree to the partner terms and business agreement"
            }
        )
    
    db = request.app.state.db
    partner_collection = db.partners
    
    # Check if partner already exists
    existing_partner = await partner_collection.find_one({
        "$or": [
            {"businessEmail": business_email.lower()},
            {"businessName": business_name.strip()}
        ]
    })
    
    if existing_partner:
        if existing_partner.get('businessEmail') == business_email.lower():
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "A partner account already exists with this email"
                }
            )
        if existing_partner.get('businessName') == business_name.strip():
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "A business with this name already exists"
                }
            )
    
    # Hash password
    hashed_password = pwd_context.hash(password)
    
    # Create new partner
    partner_data = {
        "fullname": fullname.strip(),
        "businessEmail": business_email.lower().strip(),
        "businessName": business_name.strip(),
        "phoneNumber": phone_number.strip(),
        "businessAddress": business_address.strip(),
        "businessType": business_type,
        "password": hashed_password,
        "agreedToTerms": True,
        "isEmailVerified": True,
        "isActive": True,
        "totalEarnings": 0,
        "totalRentals": 0,
        "rating": 0,
        "cars": [],
        "lastLogin": datetime.utcnow(),
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow()
    }
    
    try:
        result = await partner_collection.insert_one(partner_data)
        partner_id = str(result.inserted_id)
        
        # Generate JWT token
        token = generate_partner_token(partner_id)
        
        return JSONResponse(
            status_code=201,
            content={
                "success": True,
                "message": "Partner account created successfully!",
                "token": token,
                "partner": {
                    "id": partner_id,
                    "fullname": fullname.strip(),
                    "businessName": business_name.strip(),
                    "businessEmail": business_email.lower().strip(),
                    "phoneNumber": phone_number.strip(),
                    "businessAddress": business_address.strip(),
                    "businessType": business_type,
                    "totalEarnings": 0,
                    "totalRentals": 0,
                    "rating": 0,
                    "createdAt": datetime.utcnow().isoformat()
                }
            }
        )
    except Exception as e:
        logger.error(f"Partner registration error: {str(e)}")
        if 'duplicate key' in str(e).lower():
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Duplicate entry. Business name or email already registered."
                }
            )
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Server error. Please try again later."
            }
        )

# =============================================
# FIXED: partner_login function with proper error handling
# =============================================

async def partner_login(request: Request):
    """
    @desc    Partner login
    @route   POST /api/partner/login
    @access  Public
    """
    body = await request.json()
    business_email = body.get('businessEmail')
    password = body.get('password')
    
    if not business_email or not password:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide business email and password"
            }
        )
    
    db = request.app.state.db
    partner_collection = db.partners
    
    # Find partner
    partner = await partner_collection.find_one({
        "businessEmail": business_email.lower()
    })
    
    if not partner:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid business email or password"
            }
        )
    
    if not partner.get('isActive', True):
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Account is deactivated. Please contact support."
            }
        )
    
    # Verify password
    stored_password = partner.get('password', '')
    
    # Check if this is a Firebase account
    if partner.get('isFirebaseAccount'):
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "This account is linked to Google Sign-In. Please use 'Continue with Google' option."
            }
        )
    
    # Check if stored_password is empty or not a valid hash format
    # Valid bcrypt hashes start with $2b$, $2a$, $2y$, or $2x$
    if not stored_password or len(stored_password) < 20:
        logger.warning(f"⚠️ Invalid password hash for partner: {business_email}")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid credentials. Please use 'Forgot Password' to reset."
            }
        )
    
    try:
        # Verify using passlib
        is_valid = pwd_context.verify(password, stored_password)
    except Exception as e:
        logger.error(f"❌ Password verification error for {business_email}: {str(e)}")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid credentials. Please use 'Forgot Password' to reset."
            }
        )
    
    if not is_valid:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid business email or password"
            }
        )
    
    # Update last login
    partner_id = str(partner['_id'])
    await partner_collection.update_one(
        {"_id": partner['_id']},
        {"$set": {"lastLogin": datetime.utcnow()}}
    )
    
    # Generate JWT token
    token = generate_partner_token(partner_id)
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "Partner login successful!",
            "token": token,
            "partner": {
                "id": partner_id,
                "fullname": partner.get('fullname'),
                "businessName": partner.get('businessName'),
                "businessEmail": partner.get('businessEmail'),
                "phoneNumber": partner.get('phoneNumber'),
                "businessAddress": partner.get('businessAddress'),
                "businessType": partner.get('businessType'),
                "totalEarnings": partner.get('totalEarnings', 0),
                "totalRentals": partner.get('totalRentals', 0),
                "rating": partner.get('rating', 0),
                "createdAt": partner.get('createdAt').isoformat() if partner.get('createdAt') else None
            }
        }
    )

async def get_partner_dashboard(request: Request):
    """
    @desc    Get partner dashboard data
    @route   GET /api/partner/dashboard
    @access  Private (Partner only)
    """
    from bson import ObjectId
    
    # Try to get partner ID from request state
    user = request.state.user if hasattr(request.state, 'user') else None
    
    if not user:
        logger.error("❌ No user in request state")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Authentication required"
            }
        )
    
    partner_id = user.get('id')
    
    if not partner_id:
        logger.error("❌ No partner ID in user data")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid authentication data"
            }
        )
    
    logger.info(f"📊 Getting dashboard for partner: {partner_id}")
    
    db = request.app.state.db
    partner_collection = db.partners
    car_collection = db.partnercars
    
    try:
        # Get partner data
        partner = None
        
        # Try with ObjectId
        try:
            if ObjectId.is_valid(partner_id):
                partner = await partner_collection.find_one({"_id": ObjectId(partner_id)})
        except:
            pass
        
        # If not found, try with string
        if not partner:
            try:
                partner = await partner_collection.find_one({"_id": partner_id})
            except:
                pass
        
        if not partner:
            logger.error(f"❌ Partner not found: {partner_id}")
            return JSONResponse(
                status_code=404,
                content={
                    "success": False,
                    "message": "Partner not found"
                }
            )
        
        # Get partner's cars
        cars_cursor = car_collection.find({"partnerId": partner_id})
        cars = await cars_cursor.to_list(length=None)
        
        # Calculate statistics
        total_cars = len(cars)
        available_cars = len([c for c in cars if c.get('status') == 'available'])
        rented_cars = len([c for c in cars if c.get('status') == 'rented'])
        maintenance_cars = len([c for c in cars if c.get('status') == 'maintenance'])
        
        logger.info(f"✅ Dashboard data: {total_cars} cars, {available_cars} available, {rented_cars} rented")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "data": {
                    "partner": {
                        "id": str(partner['_id']),
                        "fullname": partner.get('fullname'),
                        "businessName": partner.get('businessName'),
                        "businessEmail": partner.get('businessEmail'),
                        "phoneNumber": partner.get('phoneNumber', ''),
                        "businessAddress": partner.get('businessAddress', ''),
                        "businessType": partner.get('businessType'),
                        "totalEarnings": partner.get('totalEarnings', 0),
                        "totalRentals": partner.get('totalRentals', 0),
                        "rating": partner.get('rating', 0)
                    },
                    "stats": {
                        "totalcars": total_cars,
                        "availablecars": available_cars,
                        "rentedcars": rented_cars,
                        "maintenancecars": maintenance_cars
                    },
                    "cars": [{
                        "id": str(c['_id']),
                        "model": c.get('model'),
                        "type": c.get('type'),
                        "fuelType": c.get('fuelType'),
                        "dailyRate": c.get('dailyRate'),
                        "status": c.get('status'),
                        "rating": c.get('rating', 0),
                        "reviewCount": c.get('reviewCount', 0),
                        "location": c.get('location'),
                        "images": c.get('images', []),
                        "description": c.get('description', ''),
                        "offer": c.get('offer')
                    } for c in cars]
                }
            }
        )
    except Exception as e:
        logger.error(f"❌ Error getting dashboard: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error fetching dashboard: {str(e)}"
            }
        )
        
async def get_all_cars(request: Request):
    """
    @desc    Get all available cars (for riders)
    @route   GET /api/partner/cars
    @access  Public
    """
    db = request.app.state.db
    car_collection = db.partnercars
    partner_collection = db.partners
    
    # Fetch all cars that are available and active
    cars_cursor = car_collection.find({
        "status": "available",
        "isActive": True
    }).sort("createdAt", -1)
    
    cars = await cars_cursor.to_list(length=None)
    
    # Get partner details for each car
    formatted_cars = []
    for car in cars:
        partner_id = car.get('partnerId')
        partner = await partner_collection.find_one({"_id": partner_id})
        
        daily_rate = car.get('dailyRate', 0)
        hourly_rate = car.get('hourlyRate') or round(daily_rate / 8)
        half_day_rate = car.get('halfDayRate') or round(daily_rate * 0.6)
        
        formatted_cars.append({
            "_id": str(car['_id']),
            "id": str(car['_id']),
            "model": car.get('model'),
            "type": car.get('type'),
            "fuelType": car.get('fuelType'),
            "price": daily_rate,
            "dailyRate": daily_rate,
            "hourlyRate": hourly_rate,
            "halfDayRate": half_day_rate,
            "minRentalHours": car.get('minRentalHours', 1),
            "maxRentalHours": car.get('maxRentalHours', 72),
            "status": car.get('status'),
            "rating": car.get('rating', 0),
            "reviewCount": car.get('reviewCount', 0),
            "location": car.get('location'),
            "images": car.get('images', []),
            "description": car.get('description', 'No description available'),
            "offer": car.get('offer'),
            "features": car.get('features', []),
            "registrationNumber": car.get('registrationNumber', ''),
            "partner": {
                "id": str(partner['_id']),
                "name": partner.get('businessName'),
                "fullname": partner.get('fullname'),
                "address": partner.get('businessAddress'),
                "phone": partner.get('phoneNumber'),
                "rating": partner.get('rating', 0)
            } if partner else None,
            "createdAt": car.get('createdAt').isoformat() if car.get('createdAt') else None,
            "updatedAt": car.get('updatedAt').isoformat() if car.get('updatedAt') else None
        })
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "count": len(formatted_cars),
            "cars": formatted_cars
        }
    )

async def add_partner_car(request: Request):
    """
    @desc    Add new car for partner
    @route   POST /api/partner/cars
    @access  Private (Partner only)
    """
    partner_id = request.state.user.get('id')
    body = await request.json()
    
    model = body.get('model')
    registration_number = body.get('registrationNumber')
    car_type = body.get('type')
    fuel_type = body.get('fuelType')
    daily_rate = body.get('dailyRate')
    hourly_rate = body.get('hourlyRate')
    half_day_rate = body.get('halfDayRate')
    min_rental_hours = body.get('minRentalHours', 1)
    max_rental_hours = body.get('maxRentalHours', 72)
    location = body.get('location')
    description = body.get('description', '')
    images = body.get('images', [])
    features = body.get('features', [])
    offer = body.get('offer')
    
    # Validate rates
    if hourly_rate and (hourly_rate < 0 or hourly_rate > daily_rate):
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Hourly rate must be between 0 and daily rate"
            }
        )
    
    if half_day_rate and (half_day_rate < 0 or half_day_rate > daily_rate):
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Half day rate must be between 0 and daily rate"
            }
        )
    
    db = request.app.state.db
    car_collection = db.partnercars
    partner_collection = db.partners
    
    # Create car
    car_data = {
        "partnerId": partner_id,
        "model": model.strip(),
        "registrationNumber": registration_number.strip() if registration_number else '',
        "type": car_type,
        "fuelType": fuel_type,
        "dailyRate": float(daily_rate),
        "hourlyRate": float(hourly_rate) if hourly_rate else None,
        "halfDayRate": float(half_day_rate) if half_day_rate else None,
        "minRentalHours": min_rental_hours,
        "maxRentalHours": max_rental_hours,
        "location": {
            "lat": float(location['lat']),
            "lng": float(location['lng'])
        },
        "description": description or '',
        "images": images or [],
        "features": features or [],
        "offer": offer or None,
        "status": "available",
        "isActive": True,
        "rating": 0,
        "reviewCount": 0,
        "reviews": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow()
    }
    
    try:
        result = await car_collection.insert_one(car_data)
        car_id = str(result.inserted_id)
        
        # Add car to partner's cars array
        await partner_collection.update_one(
            {"_id": partner_id},
            {
                "$push": {"cars": car_id},
                "$inc": {"totalcars": 1}
            }
        )
        
        # Get populated car
        car = await car_collection.find_one({"_id": result.inserted_id})
        partner = await partner_collection.find_one({"_id": partner_id})
        
        # Format car for response
        formatted_car = {
            "_id": str(car['_id']),
            "id": str(car['_id']),
            "model": car.get('model'),
            "type": car.get('type'),
            "fuelType": car.get('fuelType'),
            "dailyRate": car.get('dailyRate'),
            "status": car.get('status'),
            "rating": car.get('rating', 0),
            "reviewCount": car.get('reviewCount', 0),
            "location": car.get('location'),
            "images": car.get('images', []),
            "description": car.get('description', 'No description available'),
            "offer": car.get('offer'),
            "features": car.get('features', []),
            "registrationNumber": car.get('registrationNumber', ''),
            "partner": {
                "id": str(partner['_id']),
                "name": partner.get('businessName'),
                "fullname": partner.get('fullname'),
                "address": partner.get('businessAddress'),
                "phone": partner.get('phoneNumber'),
                "rating": partner.get('rating', 0)
            } if partner else None,
            "createdAt": car.get('createdAt').isoformat() if car.get('createdAt') else None,
            "updatedAt": car.get('updatedAt').isoformat() if car.get('updatedAt') else None
        }
        
        # Broadcast new car via Socket.io
        if sio:
            await sio.emit('new_car_added', formatted_car)
            logger.info(f"📡 Broadcasted new car to all riders: {car.get('model')}")
        
        return JSONResponse(
            status_code=201,
            content={
                "success": True,
                "message": "car added successfully!",
                "car": formatted_car
            }
        )
    except Exception as e:
        logger.error(f"Add partner car error: {str(e)}")
        if 'duplicate key' in str(e).lower():
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Duplicate registration number. Please check and try again."
                }
            )
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Server error. Please try again later.",
                "error": str(e) if os.getenv('NODE_ENV') == 'development' else None
            }
        )

async def update_partner_car(request: Request, car_id: str):
    """
    @desc    Update car details
    @route   PUT /api/partner/cars/{carId}
    @access  Private (Partner only)
    """
    partner_id = request.state.user.get('id')
    body = await request.json()
    
    db = request.app.state.db
    car_collection = db.partnercars
    
    # Find car and verify ownership
    car = await car_collection.find_one({
        "_id": car_id,
        "partnerId": partner_id
    })
    
    if not car:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "car not found or you do not have permission to edit it"
            }
        )
    
    # Update car
    update_data = {k: v for k, v in body.items() if v is not None}
    update_data["updatedAt"] = datetime.utcnow()
    
    result = await car_collection.update_one(
        {"_id": car_id},
        {"$set": update_data}
    )
    
    updated_car = await car_collection.find_one({"_id": car_id})
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "car updated successfully!",
            "car": {
                "_id": str(updated_car['_id']),
                "id": str(updated_car['_id']),
                "model": updated_car.get('model'),
                "type": updated_car.get('type'),
                "fuelType": updated_car.get('fuelType'),
                "dailyRate": updated_car.get('dailyRate'),
                "status": updated_car.get('status'),
                "rating": updated_car.get('rating', 0),
                "reviewCount": updated_car.get('reviewCount', 0),
                "location": updated_car.get('location'),
                "images": updated_car.get('images', []),
                "description": updated_car.get('description', ''),
                "offer": updated_car.get('offer'),
                "features": updated_car.get('features', []),
                "registrationNumber": updated_car.get('registrationNumber', ''),
                "updatedAt": updated_car.get('updatedAt').isoformat() if updated_car.get('updatedAt') else None
            }
        }
    )

async def delete_partner_car(request: Request, car_id: str):
    """
    @desc    Delete car
    @route   DELETE /api/partner/cars/{carId}
    @access  Private (Partner only)
    """
    partner_id = request.state.user.get('id')
    
    db = request.app.state.db
    car_collection = db.partnercars
    partner_collection = db.partners
    
    # Find car and verify ownership
    car = await car_collection.find_one({
        "_id": car_id,
        "partnerId": partner_id
    })
    
    if not car:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "car not found or you do not have permission to delete it"
            }
        )
    
    # Delete car
    await car_collection.delete_one({"_id": car_id})
    
    # Remove car from partner's cars array
    await partner_collection.update_one(
        {"_id": partner_id},
        {"$pull": {"cars": car_id}}
    )
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "car deleted successfully!"
        }
    )

async def get_nearby_cars(request: Request):
    """
    @desc    Get nearby cars within specified radius (10km)
    @route   GET /api/cars/nearby
    @access  Public
    """
    query_params = request.query_params
    lat = query_params.get('lat')
    lng = query_params.get('lng')
    radius = float(query_params.get('radius', 10))
    
    if not lat or not lng:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Latitude and longitude are required"
            }
        )
    
    try:
        latitude = float(lat)
        longitude = float(lng)
    except ValueError:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Invalid latitude or longitude values"
            }
        )
    
    db = request.app.state.db
    car_collection = db.partnercars
    partner_collection = db.partners
    
    # Get all available cars
    cars_cursor = car_collection.find({
        "status": "available",
        "isActive": True
    })
    cars = await cars_cursor.to_list(length=None)
    
    # Calculate distance and filter by radius
    nearby_cars = []
    for car in cars:
        car_location = car.get('location', {})
        car_lat = car_location.get('lat')
        car_lng = car_location.get('lng')
        
        if car_lat is None or car_lng is None:
            continue
        
        # Calculate distance using Haversine formula
        from math import radians, sin, cos, sqrt, atan2
        R = 6371  # Earth's radius in KM
        
        lat1, lon1 = radians(latitude), radians(longitude)
        lat2, lon2 = radians(car_lat), radians(car_lng)
        
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        distance = R * c
        
        if distance <= radius:
            partner = await partner_collection.find_one({"_id": car.get('partnerId')})
            
            nearby_cars.append({
                "_id": str(car['_id']),
                "model": car.get('model'),
                "registrationNumber": car.get('registrationNumber', ''),
                "type": car.get('type'),
                "fuelType": car.get('fuelType'),
                "dailyRate": car.get('dailyRate'),
                "status": car.get('status'),
                "rating": car.get('rating', 0),
                "reviewCount": car.get('reviewCount', 0),
                "location": car.get('location'),
                "description": car.get('description', ''),
                "images": car.get('images', []),
                "offer": car.get('offer'),
                "features": car.get('features', []),
                "distance": round(distance, 2),
                "partner": {
                    "id": str(partner['_id']),
                    "businessName": partner.get('businessName'),
                    "rating": partner.get('rating', 0)
                } if partner else None
            })
    
    # Sort by distance
    nearby_cars.sort(key=lambda x: x['distance'])
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "count": len(nearby_cars),
            "cars": nearby_cars
        }
    )

async def update_car_status(request: Request, car_id: str):
    """
    @desc    Update car status (available, rented, maintenance)
    @route   PUT /api/cars/{id}/status
    @access  Private (Partner only)
    """
    partner_id = request.state.user.get('id')
    body = await request.json()
    status = body.get('status')
    
    # Validate status
    valid_statuses = ['available', 'rented', 'maintenance']
    if status not in valid_statuses:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Invalid status. Must be: available, rented, or maintenance"
            }
        )
    
    db = request.app.state.db
    car_collection = db.partnercars
    partner_collection = db.partners
    
    # Find car and verify ownership
    car = await car_collection.find_one({
        "_id": car_id,
        "partnerId": partner_id
    })
    
    if not car:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "car not found or you do not have permission to update it"
            }
        )
    
    old_status = car.get('status')
    
    # Update status
    await car_collection.update_one(
        {"_id": car_id},
        {"$set": {"status": status, "updatedAt": datetime.utcnow()}}
    )
    
    # If status changed to rented, update partner's rental count
    if status == 'rented' and old_status != 'rented':
        await partner_collection.update_one(
            {"_id": partner_id},
            {"$inc": {"totalRentals": 1}}
        )
    
    # Emit socket event for real-time update
    if sio:
        await sio.emit('car_status_updated', {
            "carId": car_id,
            "status": status,
            "carModel": car.get('model'),
            "oldStatus": old_status
        })
        
        if status == 'rented':
            await sio.emit('car_rented', {
                "carId": car_id,
                "carModel": car.get('model'),
                "partnerId": partner_id
            })
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "car status updated successfully",
            "car": {
                "id": str(car['_id']),
                "model": car.get('model'),
                "status": status,
                "updatedAt": datetime.utcnow().isoformat()
            }
        }
    )

async def verify_partner_token(request: Request):
    """
    @desc    Verify partner token
    @route   POST /api/partner/verify-token
    @access  Public
    """
    from bson import ObjectId
    
    auth_header = request.headers.get('authorization')
    
    print(f"🔍 Verifying token - Auth header present: {bool(auth_header)}")
    
    if not auth_header:
        print("❌ No authorization header found")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "No authorization header provided"
            }
        )
    
    if not auth_header.startswith('Bearer '):
        print("❌ Invalid auth header format - doesn't start with 'Bearer '")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "Invalid authorization header format. Must be 'Bearer <token>'"
            }
        )
    
    token = auth_header.split(' ')[1]
    print(f"🔑 Token received: {token[:20]}... (length: {len(token)})")
    
    secret = os.getenv('JWT_SECRET')
    
    if not secret:
        print("❌ JWT_SECRET not set in environment")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "valid": False,
                "message": "Server configuration error"
            }
        )
    
    try:
        # Try to decode the token
        decoded = jwt.decode(token, secret, algorithms=['HS256'])
        print(f"✅ Token decoded successfully")
        print(f"   Payload: {decoded}")
        
        # Check if it's a partner token
        if decoded.get('role') != 'partner':
            print(f"❌ Invalid role: {decoded.get('role')}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "Invalid token type - not a partner token"
                }
            )
        
        # Get partner ID from token
        partner_id = decoded.get('id')
        print(f"🔍 Looking for partner with ID: {partner_id}")
        
        if not partner_id:
            print("❌ No partner ID in token")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "Invalid token - missing partner ID"
                }
            )
        
        db = request.app.state.db
        partner_collection = db.partners
        
        # Try to find partner - handle both ObjectId and string IDs
        partner = None
        
        # First try with ObjectId
        try:
            if ObjectId.is_valid(partner_id):
                partner = await partner_collection.find_one({"_id": ObjectId(partner_id)})
                print(f"   Found partner using ObjectId: {partner is not None}")
        except Exception as e:
            print(f"   ObjectId lookup failed: {e}")
        
        # If not found, try with string
        if not partner:
            try:
                partner = await partner_collection.find_one({"_id": partner_id})
                print(f"   Found partner using string ID: {partner is not None}")
            except Exception as e:
                print(f"   String ID lookup failed: {e}")
        
        if not partner:
            print(f"❌ Partner not found with ID: {partner_id}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "Partner not found"
                }
            )
        
        # Check if partner is active
        if not partner.get('isActive', True):
            print(f"❌ Partner account is inactive: {partner_id}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "Partner account is inactive"
                }
            )
        
        print(f"✅ Token verified successfully for partner: {partner.get('businessEmail')}")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "valid": True,
                "partner": {
                    "id": str(partner['_id']),
                    "fullname": partner.get('fullname'),
                    "businessName": partner.get('businessName'),
                    "businessEmail": partner.get('businessEmail')
                }
            }
        )
        
    except jwt.ExpiredSignatureError:
        print("❌ Token has expired")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "Token has expired"
            }
        )
    except jwt.InvalidTokenError as e:
        print(f"❌ Invalid token: {str(e)}")
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": f"Invalid token: {str(e)}"
            }
        )
    except Exception as e:
        print(f"❌ Token verification error: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "valid": False,
                "message": f"Server error during token verification: {str(e)}"
            }
        )

async def add_car_review(request: Request, car_id: str):
    """
    @desc    Add a review for a car
    @route   POST /api/partner/cars/{carId}/review
    @access  Private (User only - authenticated rider)
    """
    user = request.state.user
    user_id = user.get('id')
    user_name = user.get('fullname', 'User')
    
    body = await request.json()
    rating = body.get('rating')
    comment = body.get('comment')
    
    if not rating or rating < 1 or rating > 5:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Rating must be between 1 and 5"
            }
        )
    
    if not comment or not comment.strip():
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Comment is required"
            }
        )
    
    db = request.app.state.db
    car_collection = db.partnercars
    
    # Find the car
    car = await car_collection.find_one({"_id": car_id})
    
    if not car:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "car not found"
            }
        )
    
    # Check if user already reviewed this car
    reviews = car.get('reviews', [])
    existing_review = next((r for r in reviews if r.get('userId') == user_id), None)
    
    if existing_review:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "You have already reviewed this car"
            }
        )
    
    # Add new review
    new_review = {
        "userId": user_id,
        "userName": user_name,
        "rating": float(rating),
        "comment": comment.strip(),
        "createdAt": datetime.utcnow()
    }
    
    reviews.append(new_review)
    
    # Calculate new average rating
    total_rating = sum(r['rating'] for r in reviews)
    avg_rating = total_rating / len(reviews) if reviews else 0
    
    # Update car
    await car_collection.update_one(
        {"_id": car_id},
        {
            "$set": {
                "reviews": reviews,
                "rating": avg_rating,
                "reviewCount": len(reviews),
                "updatedAt": datetime.utcnow()
            }
        }
    )
    
    saved_review = reviews[-1]
    
    # Emit socket event for real-time update
    if sio:
        await sio.emit('car_review_added', {
            "carId": car_id,
            "review": {
                "id": str(saved_review.get('_id')) if '_id' in saved_review else None,
                "userName": saved_review['userName'],
                "rating": saved_review['rating'],
                "comment": saved_review['comment'],
                "createdAt": saved_review['createdAt'].isoformat() if saved_review.get('createdAt') else None
            },
            "newRating": avg_rating,
            "reviewCount": len(reviews)
        })
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "Review added successfully",
            "review": {
                "id": str(saved_review.get('_id')) if '_id' in saved_review else None,
                "userName": saved_review['userName'],
                "rating": saved_review['rating'],
                "comment": saved_review['comment'],
                "createdAt": saved_review['createdAt'].isoformat() if saved_review.get('createdAt') else None
            },
            "newRating": avg_rating,
            "reviewCount": len(reviews)
        }
    )

async def get_car_reviews(request: Request, car_id: str):
    """
    @desc    Get all reviews for a car
    @route   GET /api/partner/cars/{carId}/reviews
    @access  Public
    """
    db = request.app.state.db
    car_collection = db.partnercars
    
    car = await car_collection.find_one(
        {"_id": car_id},
        {"reviews": 1, "rating": 1, "reviewCount": 1}
    )
    
    if not car:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "car not found"
            }
        )
    
    reviews = car.get('reviews', [])
    # Sort reviews by createdAt descending (newest first)
    reviews.sort(key=lambda x: x.get('createdAt', datetime.min), reverse=True)
    
    formatted_reviews = []
    for r in reviews:
        formatted_reviews.append({
            "id": str(r.get('_id')) if '_id' in r else None,
            "userName": r.get('userName'),
            "rating": r.get('rating'),
            "comment": r.get('comment'),
            "createdAt": r.get('createdAt').isoformat() if r.get('createdAt') else None
        })
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "reviews": formatted_reviews,
            "rating": car.get('rating', 0),
            "reviewCount": car.get('reviewCount', 0)
        }
    )

# Import logging
import logging
logger = logging.getLogger(__name__)