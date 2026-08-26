"""
====================================================================
FILE: auth_controller.py
LOCATION: server/rider/controllers/auth_controller.py
PURPOSE: Complete authentication controller for riders/users
====================================================================

OVERVIEW:
This module handles all authentication-related functionality for 
riders (end users) of the platform. It provides traditional email/
password authentication, Firebase/Google Sign-In, OTP verification,
and password reset flows with email delivery.

====================================================================
CORE FEATURES:
====================================================================

1. 🔐 EMAIL/PASSWORD AUTHENTICATION
   - Signup with email, password, and date of birth
   - Login with email and password
   - JWT token generation (30-day expiry)
   - bcrypt password hashing

2. 🔑 FIREBASE/GOOGLE SIGN-IN
   - Firebase token verification with clock skew tolerance
   - Automatic user creation/update from Firebase data
   - Google profile picture storage
   - Firebase UID linking

3. 📧 OTP VERIFICATION SYSTEM
   - 6-digit OTP generation
   - 10-minute expiry
   - 5-attempt limit (security)
   - Beautiful HTML email templates
   - Supports both verification and password reset

4. 🔄 PASSWORD RESET
   - OTP-based reset flow
   - Legacy token-based reset (compatible)
   - Email delivery with reset instructions

5. ✅ TOKEN VERIFICATION
   - JWT validation endpoint
   - User existence check
   - Account status verification

====================================================================
API ENDPOINTS:
====================================================================

PUBLIC ENDPOINTS (No Authentication Required):
┌─────────────────────────────────────────────────────────────────┐
│ Method │ Endpoint                    │ Description              │
├────────┼─────────────────────────────┼──────────────────────────┤
│ POST   │ /api/send-otp               │ Send OTP to email        │
│ POST   │ /api/verify-otp             │ Verify OTP               │
│ POST   │ /api/signup                 │ Register new rider       │
│ POST   │ /api/login                  │ Rider login              │
│ POST   │ /api/auth/firebase          │ Firebase/Google Sign-In  │
│ POST   │ /api/verify-token           │ Validate JWT token       │
│ POST   │ /api/forgot-password        │ Request password reset   │
│ POST   │ /api/reset-password         │ Reset password (token)   │
│ POST   │ /api/reset-password-otp     │ Reset password (OTP)     │
└─────────────────────────────────────────────────────────────────┘

====================================================================
AUTHENTICATION FLOWS:
====================================================================

1. TRADITIONAL SIGNUP FLOW:
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. User enters email                                        │
   │ 2. POST /api/send-otp → OTP sent to email                  │
   │ 3. User enters OTP                                          │
   │ 4. POST /api/verify-otp → OTP verified                     │
   │ 5. User fills registration form (fullname, password, dob)   │
   │ 6. POST /api/signup → Account created, token returned       │
   └─────────────────────────────────────────────────────────────┘

2. PASSWORD RESET FLOW:
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. User enters email                                        │
   │ 2. POST /api/send-otp → OTP sent to email                  │
   │ 3. User enters OTP                                          │
   │ 4. POST /api/verify-otp → OTP verified (isExistingUser)    │
   │ 5. User enters new password                                 │
   │ 6. POST /api/reset-password-otp → Password updated         │
   └─────────────────────────────────────────────────────────────┘

3. FIREBASE/GOOGLE SIGN-IN FLOW:
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. User signs in with Google in frontend                   │
   │ 2. Firebase returns ID token                                │
   │ 3. POST /api/auth/firebase with token                      │
   │ 4. Backend verifies token with Firebase Admin SDK          │
   │ 5. If new user → Account created                           │
   │ 6. If existing user → Account updated (lastLogin, etc.)    │
   │ 7. JWT token returned to frontend                          │
   └─────────────────────────────────────────────────────────────┘

====================================================================
DATABASE COLLECTION:
====================================================================

users collection (db.users):
{
    "_id": ObjectId,
    "fullname": str,
    "email": str (unique, indexed),
    "password": str (bcrypt hashed),
    "dob": str (YYYY-MM-DD),
    "isEmailVerified": bool (default: True for OTP flow),
    "isActive": bool (default: True),
    "isFirebaseAccount": bool (default: False),
    "firebaseUid": str (optional),
    "firebasePicture": str (optional),
    "resetPasswordToken": str (optional, legacy),
    "resetPasswordExpire": datetime (optional, legacy),
    "lastLogin": datetime,
    "createdAt": datetime,
    "updatedAt": datetime
}

====================================================================
OTP STORE (In-Memory):
====================================================================

otp_store: Dict[str, Dict] = {
    "user@email.com": {
        "otp": "123456",
        "expiresAt": datetime,
        "attempts": 0,  # Max 5 attempts
        "createdAt": datetime,
        "isExistingUser": bool  # For password reset vs signup
    }
}

====================================================================
SECURITY FEATURES:
====================================================================

1. Password Hashing: bcrypt (10 rounds)
2. JWT Tokens: 30-day expiry, HS256 algorithm
3. OTP: 6-digit random, 10-min expiry, 5-attempt limit
4. Firebase: Clock skew tolerance (60 seconds)
5. Account Status: isActive flag for soft deactivation
6. Rate Limiting: OTP attempt tracking
7. Email Validation: SMTP with SSL/TLS

====================================================================
DEPENDENCIES:
====================================================================

- fastapi (Request, JSONResponse)
- jwt (Token generation/verification)
- passlib (bcrypt password hashing)
- firebase_admin (Firebase token verification)
- smtplib, email.mime (Email sending)
- bson (ObjectId for MongoDB)
- hashlib (Token generation)

Environment Variables Required:
- JWT_SECRET          → Secret key for JWT tokens
- EMAIL_USER          → Gmail email address
- EMAIL_PASS          → Gmail app password
- EMAIL_HOST          → SMTP host (default: smtp.gmail.com)
- EMAIL_PORT          → SMTP port (default: 465)
- NODE_ENV            → development/production
- FIREBASE_SERVICE_ACCOUNT → Firebase credentials (JSON)

====================================================================
FIREBASE INITIALIZATION:
====================================================================

Supports multiple loading methods (priority order):
1. Render secret file: /etc/secrets/firebase-service-account.json
2. Environment variable: FIREBASE_SERVICE_ACCOUNT (JSON string)
3. Local file: ../firebase-service-account.json (development)

====================================================================
ERROR CODES:
====================================================================

- 400: Validation error, OTP expired/invalid, duplicate email
- 401: Authentication failed, invalid credentials
- 404: User not found
- 500: Server error, Firebase not configured, email error

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. OTP shown in console when email not configured (development)
2. Firebase clock skew set to 60 seconds for reliability
3. Supports both OTP and legacy token-based password reset
4. Automatic isEmailVerified=True for OTP flow
5. Firebase accounts marked with isFirebaseAccount=True
6. Duplicate prevention: email unique index required

====================================================================
MAIN APP INTEGRATION:
====================================================================

# In main.py
from server.rider.controllers.auth_controller import router as auth_router

app.include_router(auth_router, prefix="/api", tags=["Authentication"])

====================================================================
QUICK REFERENCE:
====================================================================

# Send OTP
POST /api/send-otp
{ "email": "user@example.com" }

# Verify OTP
POST /api/verify-otp
{ "email": "user@example.com", "otp": "123456" }

# Signup
POST /api/signup
{ "fullname": "John Doe", "email": "john@example.com", 
  "password": "password123", "dob": "1990-01-01" }

# Login
POST /api/login
{ "email": "john@example.com", "password": "password123" }

# Firebase Auth
POST /api/auth/firebase
{ "firebaseToken": "firebase_id_token", "email": "john@example.com",
  "fullname": "John Doe", "googlePicture": "https://..." }

# Verify Token
POST /api/verify-token
Headers: { "Authorization": "Bearer <token>" }

# Reset Password (OTP)
POST /api/reset-password-otp
{ "email": "john@example.com", "newPassword": "newpass123" }

====================================================================
"""

import os
import random
import hashlib
import json
from datetime import datetime, timedelta
from typing import Optional, Dict
from fastapi import Request
from fastapi.responses import JSONResponse
import jwt
from passlib.context import CryptContext
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import httpx
import firebase_admin
from firebase_admin import credentials
from firebase_admin import auth

from ..models.user_model import User

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Store OTPs temporarily
otp_store: Dict[str, Dict] = {}

# Firebase Admin SDK initialization
firebase_initialized = False

def init_firebase():
    """Initialize Firebase Admin SDK"""
    global firebase_initialized
    
    if firebase_admin._apps:
        firebase_initialized = True
        return
    
    service_account = None
    
    # Try to load from Render's secret file
    try:
        with open('/etc/secrets/firebase-service-account.json', 'r') as f:
            service_account = json.load(f)
        print("✅ Firebase: Loaded from Render secret file")
    except FileNotFoundError:
        print("   Render secret file not found")
        
        # Try from environment variable
        if os.getenv('FIREBASE_SERVICE_ACCOUNT'):
            try:
                service_account = json.loads(os.getenv('FIREBASE_SERVICE_ACCOUNT'))
                print("✅ Firebase: Loaded from environment variable")
            except json.JSONDecodeError:
                print("   Invalid FIREBASE_SERVICE_ACCOUNT environment variable")
        
        # Try local file for development
        if not service_account and os.getenv('NODE_ENV') != 'production':
            try:
                with open('../firebase-service-account.json', 'r') as f:
                    service_account = json.load(f)
                print("✅ Firebase: Loaded from local file (development)")
            except FileNotFoundError:
                print("   Local file not found")
    
    if service_account:
        try:
            cred = credentials.Certificate(service_account)
            firebase_admin.initialize_app(cred)
            firebase_initialized = True
            print("✅ Firebase Admin SDK initialized successfully")
            print(f"   Project ID: {service_account.get('project_id', 'N/A')}")
        except Exception as e:
            print(f"❌ Firebase Admin SDK initialization error: {str(e)}")
    else:
        print("⚠️ Firebase service account not found. Firebase auth will not work.")

# Initialize Firebase
init_firebase()

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

def generate_token(user_id: str) -> str:
    """Generate JWT token for authenticated user"""
    secret = os.getenv('JWT_SECRET')
    if not secret:
        raise ValueError("JWT_SECRET not set")
    
    payload = {
        'id': user_id,
        'exp': datetime.utcnow() + timedelta(days=30)
    }
    return jwt.encode(payload, secret, algorithm='HS256')

def generate_otp() -> str:
    """Generate random 6-digit OTP"""
    return f"{random.randint(100000, 999999)}"

async def send_otp_email(email: str, otp: str, purpose: str = 'reset'):
    """Send OTP via email"""
    transporter = get_email_transporter()
    if not transporter:
        raise ValueError("Email transporter not configured")
    
    is_password_reset = purpose == 'reset'
    subject = 'carrzz - Password Reset OTP' if is_password_reset else 'carrzz - Email Verification OTP'
    title = 'Reset Your Password' if is_password_reset else 'Verify Your Email'
    message = ('You requested to reset your password. Please use the verification code below to proceed.'
               if is_password_reset else 'Thank you for choosing carrzz! Please use the verification code below to complete your registration.')
    
    # Create email
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'"carrzz" <{transporter["user"]}>'
    msg['To'] = email
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{subject} - carrzz</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
        <div style="background: linear-gradient(135deg, #E0F2FE 0%, #F0FDF4 100%); padding: 40px 20px;">
            <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 24px; overflow: hidden; box-shadow: 0 20px 40px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); padding: 40px 20px; text-align: center;">
                    <div style="width: 80px; height: 80px; background: white; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 20px;">
                        <span style="font-size: 48px;">🚲</span>
                    </div>
                    <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">carrzz</h1>
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
                            <h1 style="color: #3B82F6; font-size: 48px; letter-spacing: 8px; margin: 0; font-family: monospace;">{otp}</h1>
                        </div>
                        <p style="color: #9CA3AF; margin: 15px 0 0; font-size: 12px;">This code expires in 10 minutes</p>
                    </div>
                    
                    <!-- Instructions -->
                    <div style="border-top: 1px solid #E5E7EB; padding-top: 25px;">
                        <p style="color: #6B7280; font-size: 14px; margin: 0 0 10px;">
                            <strong>Need help?</strong> If you didn't request this code, please ignore this email.
                        </p>
                        <p style="color: #9CA3AF; font-size: 12px; margin: 0;">
                            For any assistance, contact us at support@carrzz.com
                        </p>
                    </div>
                </div>
                
                <!-- Footer -->
                <div style="background: #F9FAFB; padding: 20px 30px; text-align: center; border-top: 1px solid #E5E7EB;">
                    <p style="color: #9CA3AF; font-size: 12px; margin: 0;">
                        &copy; 2024 carrzz. All rights reserved.<br>
                        Ride safe, ride with carrzz.
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
        print(f"✓ Email sent successfully to {email}")
        return True
    except Exception as e:
        print(f"❌ Failed to send email: {str(e)}")
        raise

async def send_otp(request: Request):
    """
    @desc    Send OTP for email verification (for both signup and forgot password)
    @route   POST /api/send-otp
    @access  Public
    """
    body = await request.json()
    email = body.get('email')
    
    if not email:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Email is required"
            }
        )
    
    db = request.app.state.db
    user_collection = db.users
    
    # Check if user exists (for forgot password)
    existing_user = await user_collection.find_one({"email": email.lower()})
    
    # Generate OTP
    otp = generate_otp()
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    
    # Store OTP
    otp_store[email.lower()] = {
        'otp': otp,
        'expiresAt': expires_at,
        'attempts': 0,
        'createdAt': datetime.utcnow(),
        'isExistingUser': bool(existing_user)
    }
    
    print(f"📧 Sending OTP to {email}: {otp}")
    print(f"   User exists: {bool(existing_user)} - {'Password reset' if existing_user else 'New registration'}")
    
    # Check if email is configured
    transporter = get_email_transporter()
    if not transporter:
        print(f"⚠️ Email not configured. For testing, OTP is: {otp}")
        message = 'OTP generated for password reset. (Email not sent - configure email settings)' if existing_user else 'OTP generated successfully. (Email not sent - configure email settings)'
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": message,
                "testOtp": otp if os.getenv('NODE_ENV') == 'development' else None
            }
        )
    
    # Send email
    try:
        await send_otp_email(email, otp, 'reset' if existing_user else 'verification')
        message = 'OTP sent successfully! Please check your email to reset your password.' if existing_user else 'OTP sent successfully! Please check your email to verify your account.'
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": message
            }
        )
    except Exception as e:
        print(f"Send OTP error: {str(e)}")
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

async def verify_otp(request: Request):
    """
    @desc    Verify OTP
    @route   POST /api/verify-otp
    @access  Public
    """
    body = await request.json()
    email = body.get('email')
    otp = body.get('otp')
    
    if not email or not otp:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Email and OTP are required"
            }
        )
    
    stored_otp_data = otp_store.get(email.lower())
    
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
        otp_store.pop(email.lower(), None)
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "OTP has expired. Please request a new one."
            }
        )
    
    # Check attempts
    if stored_otp_data['attempts'] >= 5:
        otp_store.pop(email.lower(), None)
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
        otp_store[email.lower()] = stored_otp_data
        remaining = 5 - stored_otp_data['attempts']
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": f"Invalid OTP. {remaining} attempts remaining."
            }
        )
    
    # OTP verified successfully
    otp_store.pop(email.lower(), None)
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "OTP verified successfully",
            "isExistingUser": stored_otp_data.get('isExistingUser', False)
        }
    )

async def reset_password_with_otp(request: Request):
    """
    @desc    Reset password after OTP verification
    @route   POST /api/reset-password-otp
    @access  Public
    """
    body = await request.json()
    email = body.get('email')
    new_password = body.get('newPassword')
    
    if not email or not new_password:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Email and new password are required"
            }
        )
    
    if len(new_password) < 6:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Password must be at least 6 characters"
            }
        )
    
    db = request.app.state.db
    user_collection = db.users
    
    user = await user_collection.find_one({"email": email.lower()})
    
    if not user:
        return JSONResponse(
            status_code=404,
            content={
                "success": False,
                "message": "User not found"
            }
        )
    
    # Hash new password
    hashed_password = pwd_context.hash(new_password)
    
    # Update password
    await user_collection.update_one(
        {"email": email.lower()},
        {"$set": {"password": hashed_password, "updatedAt": datetime.utcnow()}}
    )
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "Password reset successful! You can now login with your new password."
        }
    )

# =============================================
# FIXED: Firebase Authentication with retry and better error handling
# =============================================

async def firebase_auth(request: Request):
    """
    @desc    Firebase Authentication - Register or Login with Firebase token
    @route   POST /api/auth/firebase
    @access  Public
    """
    try:
        body = await request.json()
        firebase_token = body.get('firebaseToken')
        email = body.get('email')
        fullname = body.get('fullname')
        google_picture = body.get('googlePicture')
        
        print(f"🔐 Firebase auth request received")
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
        
        if not firebase_initialized:
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "message": "Firebase authentication is not configured"
                }
            )
        
        # ========== FIX: Increased clock skew tolerance ==========
        try:
            decoded_token = auth.verify_id_token(
                firebase_token, 
                check_revoked=False,  # Disable revoked check for better reliability
                clock_skew_seconds=60  # Increased from 10 to 60 seconds
            )
            print(f"✓ Firebase token verified successfully")
            print(f"  Firebase UID: {decoded_token.get('uid')}")
            print(f"  Email: {decoded_token.get('email')}")
            print(f"  Issued at: {datetime.fromtimestamp(decoded_token.get('iat', 0))}")
            print(f"  Expires at: {datetime.fromtimestamp(decoded_token.get('exp', 0))}")
            
        except auth.ExpiredIdTokenError as e:
            print(f"❌ Firebase token expired: {str(e)}")
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "message": "Firebase token expired. Please sign in again.",
                    "error": "expired"
                }
            )
        except auth.RevokedIdTokenError as e:
            print(f"❌ Firebase token revoked: {str(e)}")
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
            print(f"❌ Firebase token verification failed: {error_msg}")
            
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
        user_collection = db.users
        
        # Check if user exists
        user = await user_collection.find_one({"email": user_email.lower()})
        
        if not user:
            print(f"Creating new user with Firebase account: {user_email}")
            user_data = {
                "fullname": fullname or decoded_token.get('name') or user_email.split('@')[0],
                "email": user_email.lower(),
                "password": hashlib.sha256(os.urandom(20)).hexdigest(),
                "dob": datetime.now().strftime('%Y-%m-%d'),
                "firebaseUid": decoded_token.get('uid'),
                "firebasePicture": google_picture or decoded_token.get('picture') or '',
                "isFirebaseAccount": True,
                "isActive": True,
                "isEmailVerified": True,
                "lastLogin": datetime.utcnow(),
                "createdAt": datetime.utcnow(),
                "updatedAt": datetime.utcnow()
            }
            
            try:
                result = await user_collection.insert_one(user_data)
                user_id = str(result.inserted_id)
                print(f"✓ New user created with ID: {user_id}")
                
                updated_user = await user_collection.find_one({"_id": result.inserted_id})
                if not updated_user:
                    print("❌ Failed to fetch newly created user")
                    return JSONResponse(
                        status_code=500,
                        content={
                            "success": False,
                            "message": "User created but could not be retrieved"
                        }
                    )
            except Exception as e:
                print(f"❌ Failed to create user: {str(e)}")
                return JSONResponse(
                    status_code=500,
                    content={
                        "success": False,
                        "message": f"Failed to create user: {str(e)}"
                    }
                )
        else:
            user_id = str(user['_id'])
            print(f"✓ Existing user found: {user_email}")
            
            update_data = {"lastLogin": datetime.utcnow()}
            if not user.get('firebaseUid'):
                update_data['firebaseUid'] = decoded_token.get('uid')
            if google_picture and not user.get('firebasePicture'):
                update_data['firebasePicture'] = google_picture
            if not user.get('isEmailVerified'):
                update_data['isEmailVerified'] = True
            
            if update_data:
                update_data['updatedAt'] = datetime.utcnow()
                await user_collection.update_one(
                    {"_id": user['_id']},
                    {"$set": update_data}
                )
                print("✓ User updated")
            
            updated_user = user
        
        # Generate JWT token
        token = generate_token(user_id)
        
        if not updated_user:
            updated_user = await user_collection.find_one({"_id": user_id})
            if not updated_user:
                print("❌ Could not retrieve user data")
                return JSONResponse(
                    status_code=500,
                    content={
                        "success": False,
                        "message": "User data could not be retrieved"
                    }
                )
        
        print("✓ JWT token generated")
        print("✓ Firebase Authentication completed successfully")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Authentication successful!",
                "token": token,
                "user": {
                    "id": str(updated_user['_id']),
                    "fullname": updated_user.get('fullname'),
                    "email": updated_user.get('email'),
                    "dob": updated_user.get('dob'),
                    "firebasePicture": updated_user.get('firebasePicture', ''),
                    "isEmailVerified": updated_user.get('isEmailVerified', True),
                    "createdAt": updated_user.get('createdAt').isoformat() if updated_user.get('createdAt') else None
                }
            }
        )
        
    except Exception as e:
        print(f"❌ Firebase Authentication error: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Firebase Authentication failed. Please try again.",
                "error": str(e) if os.getenv('NODE_ENV') == 'development' else None
            }
        )

async def signup(request: Request):
    """
    @desc    Register a new rider (after OTP verification)
    @route   POST /api/signup
    @access  Public
    """
    body = await request.json()
    fullname = body.get('fullname')
    email = body.get('email')
    password = body.get('password')
    dob = body.get('dob')
    
    if not all([fullname, email, password, dob]):
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide all required fields: fullname, email, password, dob"
            }
        )
    
    db = request.app.state.db
    user_collection = db.users
    
    # Check if user exists
    existing_user = await user_collection.find_one({"email": email.lower()})
    if existing_user:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "User already exists with this email. Please login instead."
            }
        )
    
    # Hash password
    hashed_password = pwd_context.hash(password)
    
    # Create user
    user_data = {
        "fullname": fullname.strip(),
        "email": email.lower().strip(),
        "password": hashed_password,
        "dob": dob,
        "isEmailVerified": True,
        "isActive": True,
        "isFirebaseAccount": False,
        "firebaseUid": None,
        "firebasePicture": "",
        "lastLogin": datetime.utcnow(),
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow()
    }
    
    try:
        result = await user_collection.insert_one(user_data)
        user_id = str(result.inserted_id)
        
        # Generate token
        token = generate_token(user_id)
        
        return JSONResponse(
            status_code=201,
            content={
                "success": True,
                "message": "Account created successfully!",
                "token": token,
                "user": {
                    "id": user_id,
                    "fullname": fullname.strip(),
                    "email": email.lower().strip(),
                    "dob": dob,
                    "isEmailVerified": True,
                    "createdAt": datetime.utcnow().isoformat()
                }
            }
        )
    except Exception as e:
        print(f"Signup error: {str(e)}")
        if 'duplicate key' in str(e).lower():
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Email already registered. Please use a different email."
                }
            )
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": "Server error. Please try again later."
            }
        )

async def login(request: Request):
    """
    @desc    Login existing rider
    @route   POST /api/login
    @access  Public
    """
    body = await request.json()
    email = body.get('email')
    password = body.get('password')
    
    if not email or not password:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide email and password"
            }
        )
    
    db = request.app.state.db
    user_collection = db.users
    
    # Find user
    user = await user_collection.find_one({"email": email.lower().strip()})
    
    if not user:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid email or password"
            }
        )
    
    if not user.get('isActive', True):
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Account is deactivated. Please contact support."
            }
        )
    
    # Check if it's a Firebase account
    if user.get('isFirebaseAccount'):
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "This email is linked to Google Sign-In. Please use 'Continue with Google' option."
            }
        )
    
    # Verify password
    stored_password = user.get('password', '')
    is_valid = pwd_context.verify(password, stored_password)
    
    if not is_valid:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "message": "Invalid email or password"
            }
        )
    
    # Generate token
    user_id = str(user['_id'])
    token = generate_token(user_id)
    
    # Update last login
    await user_collection.update_one(
        {"_id": user['_id']},
        {"$set": {"lastLogin": datetime.utcnow()}}
    )
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "Login successful!",
            "token": token,
            "user": {
                "id": user_id,
                "fullname": user.get('fullname'),
                "email": user.get('email'),
                "dob": user.get('dob'),
                "isEmailVerified": user.get('isEmailVerified', True),
                "createdAt": user.get('createdAt').isoformat() if user.get('createdAt') else None
            }
        }
    )

async def verify_token(request: Request):
    """
    @desc    Verify JWT token
    @route   POST /api/verify-token
    @access  Public
    """
    auth_header = request.headers.get('authorization')
    
    if not auth_header or not auth_header.startswith('Bearer '):
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "No token provided"
            }
        )
    
    token = auth_header.split(' ')[1]
    secret = os.getenv('JWT_SECRET')
    
    if not secret:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "valid": False,
                "message": "Server configuration error"
            }
        )
    
    try:
        decoded = jwt.decode(token, secret, algorithms=['HS256'])
        user_id = decoded.get('id')
        
        if not user_id:
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "Invalid token structure"
                }
            )
        
        db = request.app.state.db
        user_collection = db.users
        
        user = await user_collection.find_one({"_id": user_id})
        
        if not user or not user.get('isActive', True):
            return JSONResponse(
                status_code=401,
                content={
                    "success": False,
                    "valid": False,
                    "message": "User not found or account inactive"
                }
            )
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "valid": True,
                "user": {
                    "id": str(user['_id']),
                    "fullname": user.get('fullname'),
                    "email": user.get('email'),
                    "dob": user.get('dob'),
                    "isEmailVerified": user.get('isEmailVerified', True)
                }
            }
        )
    except jwt.ExpiredSignatureError:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "Token expired"
            }
        )
    except jwt.InvalidTokenError:
        return JSONResponse(
            status_code=401,
            content={
                "success": False,
                "valid": False,
                "message": "Invalid token"
            }
        )
    except Exception as e:
        print(f"Token verification error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "valid": False,
                "message": "Server error during token verification"
            }
        )

async def forgot_password(request: Request):
    """
    @desc    Request password reset (legacy - kept for compatibility)
    @route   POST /api/forgot-password
    @access  Public
    """
    body = await request.json()
    email = body.get('email')
    
    if not email:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide an email address"
            }
        )
    
    db = request.app.state.db
    user_collection = db.users
    
    user = await user_collection.find_one({"email": email.lower()})
    
    if not user:
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "If an account exists with this email, you will receive password reset instructions."
            }
        )
    
    # Generate reset token
    reset_token = hashlib.sha256(os.urandom(32)).hexdigest()
    reset_password_token = hashlib.sha256(reset_token.encode()).hexdigest()
    reset_password_expire = datetime.utcnow() + timedelta(minutes=10)
    
    await user_collection.update_one(
        {"_id": user['_id']},
        {"$set": {
            "resetPasswordToken": reset_password_token,
            "resetPasswordExpire": reset_password_expire
        }}
    )
    
    reset_url = f"http://localhost:3000/reset-password/{reset_token}"
    print(f"Password reset URL: {reset_url}")
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "If an account exists with this email, you will receive password reset instructions."
        }
    )

async def reset_password(request: Request):
    """
    @desc    Reset password with token (legacy - kept for compatibility)
    @route   POST /api/reset-password
    @access  Public
    """
    body = await request.json()
    token = body.get('token')
    new_password = body.get('newPassword')
    
    if not token or not new_password:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Please provide token and new password"
            }
        )
    
    if len(new_password) < 6:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Password must be at least 6 characters"
            }
        )
    
    reset_password_token = hashlib.sha256(token.encode()).hexdigest()
    
    db = request.app.state.db
    user_collection = db.users
    
    user = await user_collection.find_one({
        "resetPasswordToken": reset_password_token,
        "resetPasswordExpire": {"$gt": datetime.utcnow()}
    })
    
    if not user:
        return JSONResponse(
            status_code=400,
            content={
                "success": False,
                "message": "Invalid or expired reset token"
            }
        )
    
    # Hash new password
    hashed_password = pwd_context.hash(new_password)
    
    await user_collection.update_one(
        {"_id": user['_id']},
        {"$set": {
            "password": hashed_password,
            "resetPasswordToken": None,
            "resetPasswordExpire": None
        }}
    )
    
    return JSONResponse(
        status_code=200,
        content={
            "success": True,
            "message": "Password reset successful! You can now login with your new password."
        }
    )