"""
====================================================================
FILE: auth_routes.py
LOCATION: server/rider/routes/auth_routes.py
PURPOSE: Complete authentication routes for riders/users
====================================================================

OVERVIEW:
This module defines all authentication-related API endpoints for 
riders (end users) of the platform. It provides a clean routing 
layer that connects HTTP requests to controller functions with 
request validation using Pydantic models.

====================================================================
ROUTE CATEGORIES:
====================================================================

1. 🔓 PUBLIC ROUTES (No authentication required)
   - User registration (signup)
   - User login
   - Token verification
   - Password reset (legacy + OTP)
   - Firebase/Google Sign-In
   - OTP send/verify

====================================================================
API ENDPOINTS:
====================================================================

PUBLIC ENDPOINTS (No Auth Required):
┌─────────────────────────────────────────────────────────────────┐
│ Method │ Endpoint                    │ Description              │
├────────┼─────────────────────────────┼──────────────────────────┤
│ POST   │ /api/signup                 │ Register new rider       │
│ POST   │ /api/login                  │ Rider login              │
│ POST   │ /api/verify-token           │ Validate JWT token       │
│ POST   │ /api/forgot-password        │ Request password reset   │
│ POST   │ /api/reset-password         │ Reset password (legacy)  │
│ POST   │ /api/auth/firebase          │ Firebase/Google Sign-In  │
│ POST   │ /api/send-otp               │ Send OTP to email        │
│ POST   │ /api/verify-otp             │ Verify OTP               │
│ POST   │ /api/reset-password-otp     │ Reset password (OTP)     │
└─────────────────────────────────────────────────────────────────┘

====================================================================
REQUEST MODELS (Pydantic Validation):
====================================================================

SIGNUP REQUEST:
{
    "fullname": str (2-100 chars),
    "email": EmailStr (RFC 5322 compliant),
    "password": str (min 6 chars),
    "dob": str (YYYY-MM-DD)
}

LOGIN REQUEST:
{
    "email": EmailStr,
    "password": str
}

FIREBASE AUTH REQUEST:
{
    "firebaseToken": str (required),
    "email": str (optional),
    "fullname": str (optional),
    "googlePicture": str (optional)
}

OTP REQUESTS:
{
    "email": EmailStr,
    "otp": str (6 digits, for verify)
}

PASSWORD RESET OTP:
{
    "email": EmailStr,
    "newPassword": str (min 6 chars)
}

LEGACY PASSWORD RESET:
{
    "token": str,
    "newPassword": str (min 6 chars)
}

====================================================================
ROUTE FLOW:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                    REQUEST FLOW                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. HTTP Request arrives at endpoint                            │
│     ↓                                                           │
│  2. FastAPI routes to appropriate function                      │
│     ↓                                                           │
│  3. Request data validated via Pydantic model                   │
│     ↓                                                           │
│  4. Request body forwarded to controller                        │
│     (request._body = data.dict())                               │
│     ↓                                                           │
│  5. Controller function processes the request                   │
│     ↓                                                           │
│  6. JSONResponse returned to client                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
AUTHENTICATION FLOWS:
====================================================================

1. TRADITIONAL SIGNUP FLOW:
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. POST /api/send-otp (email) → OTP sent                  │
   │ 2. POST /api/verify-otp (email, otp) → Verified           │
   │ 3. POST /api/signup (fullname, email, password, dob)      │
   │    → Account created, token returned                        │
   └─────────────────────────────────────────────────────────────┘

2. PASSWORD RESET FLOW (OTP):
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. POST /api/send-otp (email) → OTP sent                  │
   │ 2. POST /api/verify-otp (email, otp) → Verified           │
   │ 3. POST /api/reset-password-otp (email, newPassword)      │
   │    → Password updated                                       │
   └─────────────────────────────────────────────────────────────┘

3. FIREBASE/GOOGLE SIGN-IN FLOW:
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. User signs in with Google in frontend                   │
   │ 2. Firebase returns ID token                                │
   │ 3. POST /api/auth/firebase (firebaseToken, email, ...)    │
   │    → Token verified, user created/updated, JWT returned     │
   └─────────────────────────────────────────────────────────────┘

4. LOGIN FLOW (Traditional):
   ┌─────────────────────────────────────────────────────────────┐
   │ 1. POST /api/login (email, password)                       │
   │ 2. Password verified with bcrypt                           │
   │ 3. Last login updated                                       │
   │ 4. JWT token returned                                       │
   └─────────────────────────────────────────────────────────────┘

====================================================================
DEPENDENCIES:
====================================================================

- fastapi (APIRouter, Request)
- pydantic (BaseModel, EmailStr, Field)
- typing (Optional)

Controllers:
- ..controllers.auth_controller

====================================================================
VALIDATION RULES:
====================================================================

1. Email: Must be valid email format (EmailStr)
2. Password: Minimum 6 characters
3. Fullname: 2-100 characters
4. OTP: Exactly 6 digits
5. Token: Required for legacy reset

====================================================================
ERROR HANDLING:
====================================================================

All routes delegate error handling to their respective controller
functions. Common error responses:

- 400: Validation error (invalid input, OTP expired/invalid)
- 401: Authentication failed, invalid credentials
- 404: User not found
- 500: Server error, email config error, Firebase error

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. Request Forwarding: All routes set request._body to forward 
   validated data to controller functions
2. Route Prefix: All routes are prefixed with "/api"
3. OTP Flow: Recommended for signup and password reset
4. Legacy Support: Token-based reset kept for compatibility
5. Firebase: Google Sign-In with Firebase integration

====================================================================
MAIN APP INTEGRATION:
====================================================================

# In main.py
from server.rider.routes.auth_routes import router as auth_router

# Include router
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

# Signup (after OTP verification)
POST /api/signup
{ "fullname": "John Doe", "email": "john@example.com", 
  "password": "password123", "dob": "1990-01-15" }

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

# Reset Password (OTP flow)
POST /api/reset-password-otp
{ "email": "john@example.com", "newPassword": "newpass123" }

====================================================================
"""

from fastapi import APIRouter, Request
from pydantic import BaseModel, EmailStr, Field
from typing import Optional

from ..controllers import auth_controller

router = APIRouter()

# =============================================
# REQUEST MODELS
# =============================================

class SignupRequest(BaseModel):
    fullname: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6)
    dob: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    newPassword: str = Field(..., min_length=6)

class FirebaseAuthRequest(BaseModel):
    firebaseToken: str
    email: Optional[str] = None
    fullname: Optional[str] = None
    googlePicture: Optional[str] = None

class SendOTPRequest(BaseModel):
    email: EmailStr

class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)

class ResetPasswordOTPRequest(BaseModel):
    email: EmailStr
    newPassword: str = Field(..., min_length=6)

# =============================================
# ROUTES
# =============================================

@router.post("/signup")
async def signup(request: Request, data: SignupRequest):
    """Register a new rider"""
    request._body = data.dict()
    return await auth_controller.signup(request)

@router.post("/login")
async def login(request: Request, data: LoginRequest):
    """Login existing rider"""
    request._body = data.dict()
    return await auth_controller.login(request)

@router.post("/verify-token")
async def verify_token(request: Request):
    """Verify JWT token"""
    return await auth_controller.verify_token(request)

@router.post("/forgot-password")
async def forgot_password(request: Request, data: ForgotPasswordRequest):
    """Request password reset (legacy)"""
    request._body = data.dict()
    return await auth_controller.forgot_password(request)

@router.post("/reset-password")
async def reset_password(request: Request, data: ResetPasswordRequest):
    """Reset password with token (legacy)"""
    request._body = data.dict()
    return await auth_controller.reset_password(request)

@router.post("/auth/firebase")
async def firebase_auth(request: Request, data: FirebaseAuthRequest):
    """Authenticate with Firebase token"""
    request._body = data.dict()
    return await auth_controller.firebase_auth(request)

@router.post("/send-otp")
async def send_otp(request: Request, data: SendOTPRequest):
    """Send OTP for email verification"""
    request._body = data.dict()
    return await auth_controller.send_otp(request)

@router.post("/verify-otp")
async def verify_otp(request: Request, data: VerifyOTPRequest):
    """Verify OTP code"""
    request._body = data.dict()
    return await auth_controller.verify_otp(request)

@router.post("/reset-password-otp")
async def reset_password_otp(request: Request, data: ResetPasswordOTPRequest):
    """Reset password after OTP verification"""
    request._body = data.dict()
    return await auth_controller.reset_password_with_otp(request)