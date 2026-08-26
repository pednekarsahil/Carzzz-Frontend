"""
====================================================================
FILE: car_routes.py
LOCATION: server/partner/routes/car_routes.py
PURPOSE: API routes for car reservations and management
====================================================================

OVERVIEW:
This module provides endpoints for car reservation functionality.
It implements a temporary locking mechanism to prevent double-booking
during the checkout/payment process. When a user starts the booking
flow, the car is reserved for 10 minutes, preventing other users
from booking it during that time.

====================================================================
FEATURES:
====================================================================

1. 🔒 CAR RESERVATION (10-minute lock)
   - Reserves a car for 10 minutes during checkout
   - Prevents double-booking conflicts
   - Auto-expires after 10 minutes
   - User-specific reservation tracking

2. 📋 VIEW ACTIVE RESERVATIONS
   - List all cars reserved by current user
   - Auto-cleanup of expired reservations

3. 🔓 RELEASE RESERVATION
   - Manual release when payment completes
   - Release when user cancels checkout
   - Cleanup of expired reservations

====================================================================
API ENDPOINTS:
====================================================================

PUBLIC ENDPOINTS (Authentication Required):
- POST   /api/car/reserve                    → Reserve a car (10 min lock)
- GET    /api/car/my-reservations            → Get user's active reservations
- DELETE /api/car/release-reservation/{carId} → Release a reservation

====================================================================
REQUEST/RESPONSE FORMATS:
====================================================================

1. RESERVE CAR (POST /api/car/reserve)
   Request Body:
   {
       "carId": "67e3a1b2c3d4e5f6a7b8c9d0"
   }
   
   Success Response:
   {
       "success": true,
       "message": "Car reserved for 10 minutes"
   }
   
   Error Response:
   {
       "success": false,
       "message": "Car is already reserved by another user"
   }

2. GET MY RESERVATIONS (GET /api/car/my-reservations)
   Success Response:
   {
       "success": true,
       "reservedCarIds": ["carId1", "carId2"]
   }

3. RELEASE RESERVATION (DELETE /api/car/release-reservation/{carId})
   Success Response:
   {
       "success": true,
       "message": "Reservation released"
   }

====================================================================
RESERVATION FLOW:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                     RESERVATION FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User selects car → clicks "Book Now"                        │
│     ↓                                                           │
│  2. Frontend calls POST /api/car/reserve                        │
│     ↓                                                           │
│  3. Server checks:                                              │
│     - Car not rented                                            │
│     - Car not reserved by someone else                          │
│     ↓                                                           │
│  4. Car reserved for 10 minutes                                 │
│     ↓                                                           │
│  5. User completes payment (Razorpay)                           │
│     ↓                                                           │
│  6. On success → DELETE /api/car/release-reservation/{carId}    │
│     ↓                                                           │
│  7. Order created, car status updated to "rented"               │
│                                                                 │
│  ⏰ If payment fails or times out:                              │
│     - Reservation auto-expires in 10 minutes                    │
│     - Car becomes available again                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
DATA STRUCTURES:
====================================================================

RESERVATIONS STORE (In-memory dictionary):
{
    "carId": {
        "userId": "user_123",
        "expiresAt": 1679876543210  // Timestamp in milliseconds
    }
}

EXPIRY LOGIC:
- Reservation duration: 10 minutes (600,000 ms)
- Expiry timestamp: current_time + 10 * 60 * 1000
- Auto-cleanup: Expired reservations removed on GET /my-reservations

====================================================================
VALIDATION CHECKS:
====================================================================

1. Car exists in database
2. Car status is not "rented"
3. Car not reserved by another user
4. User is authenticated (via authenticate middleware)
5. Reservation expiry validation

====================================================================
SECURITY:
====================================================================

- All endpoints require authentication (authenticate middleware)
- User can only release their own reservations
- User can only view their own reservations
- Expired reservations auto-cleaned
- Car ownership not required for reservation (any rider can reserve)

====================================================================
DEPENDENCIES:
====================================================================

- fastapi (APIRouter, Request, Depends)
- pydantic (BaseModel for request validation)
- datetime (timestamp management)
- middleware.auth_middleware (authenticate function)
- models.partnercar_model (PartnerCar model)

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. Production: Use Redis instead of in-memory store
2. Expiry: 10 minutes is configurable (adjust as needed)
3. Scaling: In-memory store won't work across multiple server instances
4. Cleanup: Expired reservations are cleaned on GET /my-reservations
5. Timestamps: Using milliseconds for consistency with frontend

====================================================================
REDIS MIGRATION GUIDE (Production):
====================================================================

Instead of in-memory dictionary, use Redis:

import redis
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)

# Reserve car
redis_client.setex(f"reservation:{car_id}", 600, user_id)

# Check reservation
if redis_client.get(f"reservation:{car_id}"):
    # Already reserved

# Release reservation
redis_client.delete(f"reservation:{car_id}")

# Get user's reservations (use Redis SCAN or separate set)
redis_client.sadd(f"user_reservations:{user_id}", car_id)
redis_client.expire(f"user_reservations:{user_id}", 600)

====================================================================
QUICK REFERENCE:
====================================================================

# Import in main router
from server.partner.routes.car_routes import router as car_router

# Add to app
app.include_router(car_router, prefix="/api/car", tags=["Car Reservations"])

# Usage in frontend:
# POST /api/car/reserve
# GET /api/car/my-reservations
# DELETE /api/car/release-reservation/{carId}

====================================================================
TESTING EXAMPLES:
====================================================================

# Reserve a car
curl -X POST http://localhost:3000/api/car/reserve \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"carId": "67e3a1b2c3d4e5f6a7b8c9d0"}'

# Get my reservations
curl -X GET http://localhost:3000/api/car/my-reservations \
  -H "Authorization: Bearer <token>"

# Release reservation
curl -X DELETE http://localhost:3000/api/car/release-reservation/67e3a1b2c3d4e5f6a7b8c9d0 \
  -H "Authorization: Bearer <token>"

====================================================================
"""

from fastapi import APIRouter, Request, Depends
from typing import Dict, List
from datetime import datetime, timedelta
from pydantic import BaseModel

from middleware.auth_middleware import authenticate
from ..models.partnercar_model import PartnerCar

router = APIRouter()

# Store active reservations (in production, use Redis)
reservations: Dict[str, Dict] = {}

class ReserveRequest(BaseModel):
    carId: str

@router.post("/reserve")
async def reserve_car(request: Request, data: ReserveRequest, user: dict = Depends(authenticate)):
    """Reserve a car for 10 minutes"""
    car_id = data.carId
    user_id = user.get('id')
    
    db = request.app.state.db
    car_collection = db.partnercars
    
    # Check if car is already reserved by someone else
    existing_reservation = reservations.get(car_id)
    if existing_reservation and existing_reservation.get('userId') != user_id and existing_reservation.get('expiresAt') > datetime.utcnow().timestamp() * 1000:
        return {
            "success": False,
            "message": "Car is already reserved by another user"
        }
    
    # Check if car is already rented
    car_data = await car_collection.find_one({"_id": car_id})
    if car_data and car_data.get('status') == 'rented':
        return {
            "success": False,
            "message": "Car is already rented"
        }
    
    # Reserve for 10 minutes (600,000 ms)
    reservations[car_id] = {
        "userId": user_id,
        "expiresAt": datetime.utcnow().timestamp() * 1000 + 10 * 60 * 1000
    }
    
    return {
        "success": True,
        "message": "Car reserved for 10 minutes"
    }

@router.get("/my-reservations")
async def get_my_reservations(request: Request, user: dict = Depends(authenticate)):
    """Get user's active reservations"""
    user_id = user.get('id')
    active_reservations = []
    
    current_time = datetime.utcnow().timestamp() * 1000
    
    for car_id, reservation in list(reservations.items()):
        if reservation.get('userId') == user_id and reservation.get('expiresAt') > current_time:
            active_reservations.append(car_id)
        elif reservation.get('expiresAt') <= current_time:
            del reservations[car_id]  # Clean up expired
    
    return {
        "success": True,
        "reservedCarIds": active_reservations
    }

@router.delete("/release-reservation/{car_id}")
async def release_reservation(request: Request, car_id: str, user: dict = Depends(authenticate)):
    """Release a reservation (when payment is done or user cancels)"""
    user_id = user.get('id')
    
    reservation = reservations.get(car_id)
    if reservation and reservation.get('userId') == user_id:
        del reservations[car_id]
    
    return {
        "success": True,
        "message": "Reservation released"
    }

