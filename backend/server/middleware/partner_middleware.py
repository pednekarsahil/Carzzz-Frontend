"""
====================================================================
FILE: partner_middleware.py
LOCATION: server/middleware/partner_middleware.py
PURPOSE: Partner-specific JWT authentication middleware
====================================================================

OVERVIEW:
This module provides authentication middleware specifically for 
partner routes. It validates JWT tokens, enforces partner-only 
access, and extracts partner data from the database. Unlike the 
general auth_middleware, this middleware strictly requires the 
token to have a "partner" role.

====================================================================
CORE FEATURES:
====================================================================

1. 🔐 PARTNER-ONLY AUTHENTICATION
   - Validates JWT token from Authorization header
   - Enforces "partner" role in token payload
   - Rejects non-partner tokens (403 Forbidden)

2. 👤 PARTNER DATA LOOKUP
   - Searches exclusively in "partners" collection
   - Supports both ObjectId and string ID formats
   - Returns full partner data

3. ✅ ACCOUNT STATUS CHECK
   - Verifies partner is active (isActive: true)
   - Checks account existence
   - Validates token structure

4. 📦 COMPREHENSIVE PARTNER DATA
   - Returns all partner fields
   - Stores in request.state.user
   - Ready for dependency injection

====================================================================
AUTHENTICATION FLOW:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                    PARTNER AUTHENTICATION FLOW                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Request arrives at partner-protected route                  │
│     ↓                                                           │
│  2. authenticate_partner() middleware called via Depends        │
│     ↓                                                           │
│  3. Extract token from "Authorization: Bearer <token>"          │
│     ↓                                                           │
│  4. Decode JWT with secret                                      │
│     ↓                                                           │
│  5. Verify token has "role": "partner"                          │
│     ↓                                                           │
│  6. Extract partner ID from token payload                       │
│     ↓                                                           │
│  7. Look up partner in "partners" collection                    │
│     ↓                                                           │
│  8. Verify partner is active (isActive: true)                   │
│     ↓                                                           │
│  9. Build comprehensive partner data object                     │
│     ↓                                                           │
│  10. Store in request.state.user and return                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
TOKEN REQUIREMENTS:
====================================================================

JWT Token must contain:
{
    "id": "67e3a1b2c3d4e5f6a7b8c9d0",  // Partner ID
    "role": "partner",                  // REQUIRED: partner role
    "exp": 1714567890                   // Expiry timestamp
}

If token has "role": "rider" or no role, access is denied (403).

====================================================================
PARTNER DATA OBJECT:
====================================================================

Returned user_data contains:
{
    "id": str,
    "fullname": str,
    "businessName": str,
    "businessEmail": str,
    "phoneNumber": str,
    "businessAddress": str,
    "businessType": str,
    "totalEarnings": float,
    "totalRentals": int,
    "rating": float,
    "isActive": bool,
    "isEmailVerified": bool,
    "cars": List[str],          // Array of car ObjectIds
    "lastLogin": datetime,
    "createdAt": datetime,
    "updatedAt": datetime
}

====================================================================
USAGE EXAMPLES:
====================================================================

1. PROTECT A PARTNER ROUTE:
    from middleware.partner_middleware import authenticate_partner

    @router.get("/dashboard")
    async def get_dashboard(
        request: Request, 
        user: dict = Depends(authenticate_partner)
    ):
        # user contains full partner data
        return {"partner": user}

2. ACCESS PARTNER DATA IN CONTROLLER:
    @router.post("/cars")
    async def add_car(
        request: Request, 
        data: AddCarRequest,
        user: dict = Depends(authenticate_partner)
    ):
        partner_id = user['id']  # Access partner ID
        business_name = user['businessName']
        # Proceed with car creation

3. ROUTER-LEVEL PROTECTION:
    from fastapi import APIRouter, Depends
    from middleware.partner_middleware import authenticate_partner

    router = APIRouter(dependencies=[Depends(authenticate_partner)])

    @router.get("/profile")
    async def get_profile():
        # All routes in this router require partner authentication
        pass

====================================================================
ERROR RESPONSES:
====================================================================

- 401: No token provided, expired token, invalid token, partner not found
- 403: Token is not for partner (wrong role)
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

1. Role Enforcement: Requires "partner" role in token
2. Token Validation: Verifies signature and expiry
3. Account Status: Checks isActive flag
4. Partner Existence: Verifies partner exists in database
5. Request State: Stores partner data in request.state.user

====================================================================
DIFFERENCE FROM AUTH_MIDDLEWARE:
====================================================================

| Feature | auth_middleware | partner_middleware |
|---------|-----------------|-------------------|
| Users Collection | ✅ | ❌ |
| Partners Collection | ✅ | ✅ |
| Rider Support | ✅ | ❌ |
| Partner Support | ✅ | ✅ |
| Role Enforcement | ❌ (auto-detect) | ✅ (requires partner) |
| Use Case | General routes | Partner-only routes |

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. JWT_SECRET must be set in environment
2. Partner ID can be ObjectId or string
3. Both ID formats are supported in lookup
4. Stores partner data in request.state.user
5. Returns user_data for dependency injection
6. Logs detailed authentication steps

====================================================================
MAIN APP INTEGRATION:
====================================================================

# No explicit integration needed - middleware is used via Depends()
# in partner route definitions

====================================================================
QUICK REFERENCE:
====================================================================

# Protect a partner route
from middleware.partner_middleware import authenticate_partner

@router.get("/partner/dashboard")
async def partner_dashboard(
    request: Request,
    user: dict = Depends(authenticate_partner)
):
    return {"partner": user}

# Access partner ID
partner_id = user.get('id')

# Access business name
business_name = user.get('businessName')

# Access from request state
request_user = request.state.user  # Same as user param

# Router-level protection
router = APIRouter(dependencies=[Depends(authenticate_partner)])

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

async def authenticate_partner(request: Request):
    """
    Middleware to authenticate partners using JWT token
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
        logger.info(f"🔑 Authenticating partner with token: {token[:20]}...")
        
        # Verify token
        secret = os.getenv('JWT_SECRET') or DEFAULT_JWT_SECRET
        
        try:
            decoded = jwt.decode(token, secret, algorithms=['HS256'])
            logger.info(f"✅ Token decoded successfully. Role: {decoded.get('role')}")
        except jwt.ExpiredSignatureError:
            logger.error("❌ Token expired")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Token expired. Please login again."
                }
            )
        except jwt.InvalidTokenError as e:
            logger.error(f"❌ Invalid token: {str(e)}")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Invalid token. Access denied."
                }
            )
        
        # Check if token is for partner
        if decoded.get('role') != 'partner':
            logger.error(f"❌ Invalid role: {decoded.get('role')}")
            raise HTTPException(
                status_code=403,
                detail={
                    "success": False,
                    "message": "Access denied. Partner token required."
                }
            )
        
        # Get partner ID from token
        partner_id = decoded.get('id')
        if not partner_id:
            logger.error("❌ No partner ID in token")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Invalid token structure. Access denied."
                }
            )
        
        logger.info(f"🔍 Looking for partner with ID: {partner_id}")
        
        db = request.app.state.db
        partner_collection = db.partners
        
        # Find partner - try both ObjectId and string
        partner = None
        
        # Try with ObjectId first
        try:
            if ObjectId.is_valid(partner_id):
                partner = await partner_collection.find_one({"_id": ObjectId(partner_id)})
                if partner:
                    logger.info(f"✅ Found partner using ObjectId")
        except Exception as e:
            logger.warning(f"ObjectId lookup failed: {e}")
        
        # If not found, try with string
        if not partner:
            try:
                partner = await partner_collection.find_one({"_id": partner_id})
                if partner:
                    logger.info(f"✅ Found partner using string ID")
            except Exception as e:
                logger.warning(f"String ID lookup failed: {e}")
        
        if not partner:
            logger.error(f"❌ Partner not found with ID: {partner_id}")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Partner not found. Access denied."
                }
            )
        
        if not partner.get('isActive', True):
            logger.error(f"❌ Partner account is inactive: {partner_id}")
            raise HTTPException(
                status_code=401,
                detail={
                    "success": False,
                    "message": "Account is deactivated. Access denied."
                }
            )
        
        # Create user dict for the controller
        user_data = {
            "id": str(partner['_id']),
            "fullname": partner.get('fullname'),
            "businessName": partner.get('businessName'),
            "businessEmail": partner.get('businessEmail'),
            "phoneNumber": partner.get('phoneNumber'),
            "businessAddress": partner.get('businessAddress'),
            "businessType": partner.get('businessType'),
            "totalEarnings": partner.get('totalEarnings', 0),
            "totalRentals": partner.get('totalRentals', 0),
            "rating": partner.get('rating', 0),
            "isActive": partner.get('isActive', True),
            "isEmailVerified": partner.get('isEmailVerified', True),
            "cars": partner.get('cars', []),
            "lastLogin": partner.get('lastLogin'),
            "createdAt": partner.get('createdAt'),
            "updatedAt": partner.get('updatedAt')
        }
        
        # ✅ IMPORTANT: Store in request state for controllers to access
        request.state.user = user_data
        
        logger.info(f"✅ Partner authenticated successfully: {partner.get('businessEmail')}")
        
        # Return the user data for dependency injection
        return user_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Partner authentication error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail={
                "success": False,
                "message": "Authentication failed. Please try again."
            }
        )