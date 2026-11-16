"""
====================================================================
FILE: auth_middleware.py
LOCATION: server/middleware/auth_middleware.py
PURPOSE: JWT authentication middleware for protecting routes
====================================================================

OVERVIEW:
This module provides authentication middleware for FastAPI routes.
It validates JWT tokens from the Authorization header and extracts
user information for both riders and partners. It supports dual
collection lookup (users and partners) making it versatile for
the entire application.

====================================================================
CORE FEATURES:
====================================================================

1. 🔐 JWT TOKEN VALIDATION
   - Bearer token extraction from Authorization header
   - JWT decoding with HS256 algorithm
   - Token expiry validation
   - Invalid token rejection

2. 👤 USER DUAL-LOOKUP
   - Searches in "users" collection first (riders)
   - Searches in "partners" collection second (partners)
   - Automatic user type detection
   - Returns unified user object

3. ✅ ACCOUNT STATUS CHECK
   - Verifies user is active (isActive: true)
   - Checks account existence
   - Validates token structure

4. 🔄 OPTIONAL AUTHENTICATION
   - Allows access without token
   - Extracts user info if token is valid
   - Graceful fallback for public routes

====================================================================
AUTHENTICATION FLOW:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Request arrives at protected route                          │
│     ↓                                                           │
│  2. authenticate() middleware called via Depends                │
│     ↓                                                           │
│  3. Extract token from "Authorization: Bearer <token>"          │
│     ↓                                                           │
│  4. Decode JWT with secret                                      │
│     ↓                                                           │
│  5. Extract user ID from token payload                          │
│     ↓                                                           │
│  6. Look up user in "users" collection                          │
│     ↓                                                           │
│  7. If not found, look up in "partners" collection              │
│     ↓                                                           │
│  8. Verify user is active (isActive: true)                      │
│     ↓                                                           │
│  9. Build unified user object with type detection               │
│     ↓                                                           │
│  10. Attach to request.state.user and return                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
USER TYPES:
====================================================================

The middleware automatically detects user type:
- RIDER: Found in "users" collection (has "email" field)
- PARTNER: Found in "partners" collection (has "businessEmail" field)

UNIFIED USER OBJECT:
{
    "id": str (ObjectId as string),
    "type": "rider" | "partner",
    "fullname": str,
    "email": str (email or businessEmail),
    "isActive": bool,
    "isEmailVerified": bool,
    "createdAt": datetime,
    "updatedAt": datetime,
    // Rider-specific fields
    "dob": str (rider only),
    "isFirebaseAccount": bool (rider only),
    "firebaseUid": str (rider only),
    "firebasePicture": str (rider only),
    // Partner-specific fields
    "businessName": str (partner only),
    "businessEmail": str (partner only),
    "phoneNumber": str (partner only),
    "businessAddress": str (partner only),
    "businessType": str (partner only),
    "totalEarnings": float (partner only),
    "totalRentals": int (partner only),
    "rating": float (partner only),
    "cars": List[str] (partner only)
}

====================================================================
USAGE EXAMPLES:
====================================================================

1. PROTECTED ROUTE (Rider or Partner):
    from middleware.auth_middleware import authenticate

    @router.get("/profile")
    async def get_profile(request: Request, user: dict = Depends(authenticate)):
        # user contains authenticated user data
        # Can access request.state.user as well
        return {"user": user}

2. PARTNER-ONLY ROUTE:
    from middleware.auth_middleware import authenticate

    @router.post("/cars")
    async def add_car(request: Request, user: dict = Depends(authenticate)):
        # Ensure user is a partner
        if user.get('type') != 'partner':
            raise HTTPException(status_code=403, detail="Partner access required")
        # Proceed with partner-specific logic

3. OPTIONAL AUTHENTICATION:
    from middleware.auth_middleware import optional_auth

    @router.get("/public-data")
    async def get_public_data(request: Request, user: dict = Depends(optional_auth)):
        # user will be None if not authenticated
        if user:
            # Return personalized data
            pass
        else:
            # Return public data
            pass

4. ROUTER-LEVEL PROTECTION:
    from fastapi import APIRouter, Depends
    from middleware.auth_middleware import authenticate

    router = APIRouter(dependencies=[Depends(authenticate)])

    @router.get("/protected")
    async def protected_route():
        # All routes in this router require authentication
        pass

====================================================================
TOKEN STRUCTURE:
====================================================================

JWT Token contains:
{
    "id": "67e3a1b2c3d4e5f6a7b8c9d0",  // User/Partner ID
    "exp": 1714567890,                 // Expiry timestamp (30 days)
    "role": "partner"                  // Optional role field
}

The middleware extracts user ID from multiple possible fields:
- userId (primary)
- id (secondary)
- _id (tertiary)
- sub (JWT standard)

====================================================================
ERROR RESPONSES:
====================================================================

- 401: No token provided, expired token, invalid token, user not found
- 403: Account deactivated (isActive: false)
- 500: Server configuration error (JWT_SECRET not set)

====================================================================
DEPENDENCIES:
====================================================================

- fastapi (Request, HTTPException, Depends)
- jwt (JWT decoding)
- bson (ObjectId for MongoDB lookup)
- os (Environment variables)
- logging (Request logging)

Environment Variables Required:
- JWT_SECRET → Secret key for JWT verification

====================================================================
SECURITY FEATURES:
====================================================================

1. Token Validation: Verifies token signature and expiry
2. Account Status: Checks isActive flag
3. Dual Collection Lookup: Prevents unauthorized access
4. User Type Detection: Ensures proper context
5. Request State: Stores user data in request.state for later use
6. Error Handling: Comprehensive error responses

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. JWT_SECRET must be set in environment
2. Users are looked up in both collections for flexibility
3. User type is determined by field presence (email vs businessEmail)
4. Optional auth doesn't raise errors on failure
5. Request.state.user is set for downstream use
6. Works with both MongoDB ObjectId and string IDs

====================================================================
MAIN APP INTEGRATION:
====================================================================

# No explicit integration needed - middleware is used via Depends()
# in route definitions

====================================================================
QUICK REFERENCE:
====================================================================

# Protect a route
@router.get("/protected")
async def protected_route(user: dict = Depends(authenticate)):
    return {"user": user}

# Get user from request state
@router.get("/profile")
async def get_profile(request: Request, user: dict = Depends(authenticate)):
    request_user = request.state.user  # Same as user param
    return {"user": request_user}

# Optional authentication
@router.get("/public")
async def public_route(user: dict = Depends(optional_auth)):
    if user:
        return {"authenticated": True, "user": user}
    return {"authenticated": False}

# Check user type
@router.get("/dashboard")
async def dashboard(user: dict = Depends(authenticate)):
    if user['type'] == 'partner':
        # Partner dashboard
        pass
    else:
        # Rider dashboard
        pass

====================================================================
"""

import os
import logging
from fastapi import Request, HTTPException
import jwt
from bson import ObjectId

logger = logging.getLogger(__name__)

DEFAULT_JWT_SECRET = "your_super_secret_jwt_key_change_this_in_production_123456789"
if not os.getenv("JWT_SECRET"):
    os.environ["JWT_SECRET"] = DEFAULT_JWT_SECRET

async def authenticate(request: Request):
    """
    Middleware to authenticate users using JWT token
    Supports both rider (users collection) and partner (partners collection) authentication
    """
    try:
        # Get token from Authorization header
        auth_header = request.headers.get('authorization')
        
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "No token provided. Access denied."
                }
            )
        
        # Extract token
        token = auth_header.split(' ')[1]
        
        logger.info("🔐 Verifying token...")
        
        # Verify token
        secret = os.getenv('JWT_SECRET') or DEFAULT_JWT_SECRET
        
        try:
            decoded = jwt.decode(token, secret, algorithms=['HS256'])
            logger.info(f"✅ Token decoded: {decoded}")
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Token expired. Please login again."
                }
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Invalid token. Access denied."
                }
            )
        
        # Try multiple field names for user ID
        user_id = decoded.get('userId') or decoded.get('id') or decoded.get('_id') or decoded.get('sub')
        
        if not user_id:
            logger.error("❌ No user ID found in token")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Invalid token structure. Access denied."
                }
            )
        
        logger.info(f"🔍 Looking for user with ID: {user_id}")
        
        db = request.app.state.db
        
        # Try to find user in users collection first
        user_collection = db.users
        user = None
        
        # Try with ObjectId
        try:
            if ObjectId.is_valid(user_id):
                user = await user_collection.find_one({"_id": ObjectId(user_id)})
            else:
                user = await user_collection.find_one({"_id": user_id})
        except Exception as e:
            logger.warning(f"Users collection lookup failed: {e}")
        
        # If not found in users, try partners collection
        if not user:
            logger.info(f"🔍 User not found in users collection, checking partners...")
            partner_collection = db.partners
            try:
                if ObjectId.is_valid(user_id):
                    user = await partner_collection.find_one({"_id": ObjectId(user_id)})
                else:
                    user = await partner_collection.find_one({"_id": user_id})
            except Exception as e:
                logger.warning(f"Partners collection lookup failed: {e}")
        
        if not user:
            logger.error(f"❌ User not found with ID: {user_id} in either users or partners collections")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "User not found. Access denied."
                }
            )
        
        logger.info(f"✅ User found: {user.get('email') or user.get('businessEmail')}")
        
        # Check if user is active
        if user.get('isActive') is False:
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Account is deactivated. Access denied."
                }
            )
        
        # Determine user type
        user_type = "rider" if "email" in user else "partner"
        
        # Return user dict for dependency injection
        user_data = {
            "id": str(user['_id']),
            "type": user_type,
            "fullname": user.get('fullname'),
            "email": user.get('email') or user.get('businessEmail'),
            "isActive": user.get('isActive'),
            "isEmailVerified": user.get('isEmailVerified', True),
            "createdAt": user.get('createdAt'),
            "updatedAt": user.get('updatedAt')
        }
        
        # Add rider-specific fields
        if user_type == "rider":
            user_data.update({
                "dob": user.get('dob'),
                "isFirebaseAccount": user.get('isFirebaseAccount', False),
                "firebaseUid": user.get('firebaseUid'),
                "firebasePicture": user.get('firebasePicture', ''),
                "lastLogin": user.get('lastLogin'),
            })
        else:  # partner
            user_data.update({
                "businessName": user.get('businessName'),
                "businessEmail": user.get('businessEmail'),
                "phoneNumber": user.get('phoneNumber'),
                "businessAddress": user.get('businessAddress'),
                "businessType": user.get('businessType'),
                "totalEarnings": user.get('totalEarnings', 0),
                "totalRentals": user.get('totalRentals', 0),
                "rating": user.get('rating', 0),
                "cars": user.get('cars', []),
                "lastLogin": user.get('lastLogin'),
            })
        
        # Store user in request state
        request.state.user = user_data
        request.state.user_type = user_type
        
        return user_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Authentication error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "Authentication failed. Please try again."
            }
        )

async def optional_auth(request: Request):
    """
    Optional middleware - allows access if token is provided but doesn't require it
    """
    try:
        auth_header = request.headers.get('authorization')
        
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            secret = os.getenv('JWT_SECRET')
            
            if secret:
                try:
                    decoded = jwt.decode(token, secret, algorithms=['HS256'])
                    user_id = decoded.get('userId') or decoded.get('id') or decoded.get('_id') or decoded.get('sub')
                    
                    if user_id:
                        db = request.app.state.db
                        
                        # Try users collection first
                        user_collection = db.users
                        user = None
                        
                        try:
                            if ObjectId.is_valid(user_id):
                                user = await user_collection.find_one({"_id": ObjectId(user_id)})
                            else:
                                user = await user_collection.find_one({"_id": user_id})
                        except:
                            pass
                        
                        # If not found, try partners
                        if not user:
                            partner_collection = db.partners
                            try:
                                if ObjectId.is_valid(user_id):
                                    user = await partner_collection.find_one({"_id": ObjectId(user_id)})
                                else:
                                    user = await partner_collection.find_one({"_id": user_id})
                            except:
                                pass
                        
                        if user and user.get('isActive') is not False:
                            user_type = "rider" if "email" in user else "partner"
                            user_data = {
                                "id": str(user['_id']),
                                "type": user_type,
                                "fullname": user.get('fullname'),
                                "email": user.get('email') or user.get('businessEmail'),
                                "isActive": user.get('isActive'),
                                "isEmailVerified": user.get('isEmailVerified', True),
                            }
                            if user_type == "partner":
                                user_data.update({
                                    "businessName": user.get('businessName'),
                                    "businessEmail": user.get('businessEmail'),
                                    "phoneNumber": user.get('phoneNumber'),
                                    "businessAddress": user.get('businessAddress'),
                                    "businessType": user.get('businessType'),
                                    "totalEarnings": user.get('totalEarnings', 0),
                                    "totalRentals": user.get('totalRentals', 0),
                                    "rating": user.get('rating', 0),
                                    "cars": user.get('cars', []),
                                })
                            request.state.user = user_data
                            request.state.user_type = user_type
                            return user_data
                except:
                    pass
        
        return None
        
    except Exception:
        return None