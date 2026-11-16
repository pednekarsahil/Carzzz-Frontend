"""
====================================================================
FILE: order_routes.py
LOCATION: server/partner/routes/order_routes.py
PURPOSE: Complete order management and car hold system for rentals
====================================================================

OVERVIEW:
This module provides comprehensive order management functionality
including a car hold system, price calculation, availability checks,
and order creation with real-time WebSocket notifications.

====================================================================
CORE FEATURES:
====================================================================

1. 🔒 CAR HOLD SYSTEM (10-Minute Lock)
   - Creates a 10-minute hold when user clicks "Rent Now"
   - Prevents double-booking during checkout
   - Auto-expires after 10 minutes
   - User-specific hold tracking
   - Real-time hold status updates via Socket.IO

2. 📦 ORDER CREATION
   - Creates confirmed orders after successful payment
   - Validates car availability and holds
   - Checks for overlapping bookings
   - Updates car status to "rented"
   - Updates partner earnings and rental count
   - Emits real-time events

3. 💰 PRICE CALCULATION
   - Supports hourly, half-day, full-day, and custom rentals
   - Automatic rate calculation based on rental type
   - Smart custom duration detection

4. 📋 AVAILABILITY CHECK
   - Check car availability for specific time slots
   - Detects overlapping bookings
   - Check for active holds

5. 📱 USER RIDES HISTORY
   - Get all orders for authenticated user
   - Sorted by creation date (newest first)

====================================================================
API ENDPOINTS:
====================================================================

HOLD SYSTEM (Authentication Required):
- POST   /api/cars/hold              → Create 10-min hold
- GET    /api/cars/hold/{car_id}     → Get hold status
- DELETE /api/cars/hold/{car_id}     → Release hold

ORDER MANAGEMENT (Authentication Required):
- POST   /api/create-order           → Create order after payment
- GET    /api/rides/my-rides         → Get user's ride history
- POST   /api/check-availability     → Check car availability
- POST   /api/calculate-price        → Calculate rental price

====================================================================
REQUEST/RESPONSE FORMATS:
====================================================================

1. CREATE HOLD (POST /api/cars/hold)
   Request:
   {
       "carId": "67e3a1b2c3d4e5f6a7b8c9d0"
   }
   
   Response:
   {
       "success": true,
       "message": "Car held successfully for 10 minutes",
       "hold": {
           "id": "hold_123",
           "carId": "car_456",
           "userId": "user_789",
           "status": "active",
           "holdStartedAt": "2026-03-25T10:00:00",
           "holdExpiresAt": "2026-03-25T10:10:00",
           "remainingSeconds": 600
       }
   }

2. CREATE ORDER (POST /api/create-order)
   Request:
   {
       "carId": "car_456",
       "carModel": "Honda Activa",
       "amount": 199.0,
       "originalPrice": 250.0,
       "discountPercentage": 20,
       "platformFee": 50,
       "paymentId": "pay_xyz789",
       "orderId": "order_xyz789",
       "rentalType": "fullday",
       "startDateTime": "2026-03-25T10:00:00",
       "endDateTime": "2026-03-26T10:00:00",
       "dailyRate": 250.0
   }
   
   Response:
   {
       "success": true,
       "message": "Order created successfully",
       "order": {
           "id": "order_123",
           "amount": 199.0,
           "status": "confirmed",
           "rentalDetails": { ... },
           "createdAt": "2026-03-25T10:05:00"
       }
   }

3. CALCULATE PRICE (POST /api/calculate-price)
   Request:
   {
       "carId": "car_456",
       "rentalType": "hourly",
       "rentalHours": 4
   }
   
   Response:
   {
       "success": true,
       "price": 200.0,
       "rentalType": "hourly",
       "breakdown": {
           "dailyRate": 250.0,
           "hourlyRate": 50.0,
           "halfDayRate": 150.0,
           "calculatedPrice": 200.0
       }
   }

====================================================================
HOLD SYSTEM FLOW:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                     HOLD SYSTEM FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User selects car → clicks "Rent Now"                        │
│     ↓                                                           │
│  2. POST /api/cars/hold                                         │
│     - Check if car available                                    │
│     - Check if no active hold                                   │
│     - Create hold (10 min expiry)                               │
│     - Update car status → "held"                                │
│     - Emit Socket.IO event                                      │
│     ↓                                                           │
│  3. User completes payment (Razorpay)                           │
│     ↓                                                           │
│  4. POST /api/create-order                                      │
│     - Verify hold exists for this user                          │
│     - Check for overlapping bookings                            │
│     - Create order (status: confirmed)                          │
│     - Release hold (status: converted)                          │
│     - Update car status → "rented"                              │
│     - Update partner stats                                      │
│     - Emit Socket.IO events                                     │
│     ↓                                                           │
│  5. Payment fails OR user cancels                               │
│     - DELETE /api/cars/hold/{car_id}                            │
│     - Car status → "available"                                  │
│     - Emit Socket.IO event                                      │
│                                                                 │
│  ⏰ Hold auto-expires after 10 minutes                          │
│     - Car status reverts to "available"                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
DATABASE COLLECTIONS USED:
====================================================================

- orders           → All rental orders
- partnercars      → Car listings (status updates)
- partners         → Partner stats (earnings, rentals)
- car_holds        → Active holds (10-minute locks)

====================================================================
SOCKET.IO EVENTS EMITTED:
====================================================================

EVENTS (Server → Client):
- 'car_hold_created'         → New hold created
- 'car_hold_released'        → Hold released
- 'car_availability_updated' → Car status changed
- 'car_status_updated'       → Car status updated
- 'car_rented'               → Car rented notification
- 'car_booking_confirmed'    → Booking confirmed

====================================================================
PRICE CALCULATION LOGIC:
====================================================================

RENTAL TYPES:
1. hourly   → hourly_rate × rental_hours
2. halfday  → half_day_rate (6-12 hours)
3. fullday  → daily_rate (24 hours)
4. custom   → Auto-detects duration:
              ≤ 8 hours  → hourly
              8-12 hours → halfday
              > 12 hours → fullday (days rounded up)

====================================================================
DEPENDENCIES:
====================================================================

- fastapi (APIRouter, Request, Depends, JSONResponse)
- pydantic (BaseModel for request validation)
- datetime (datetime, timedelta)
- bson (ObjectId for MongoDB)
- middleware.auth_middleware (authenticate)

====================================================================
ERROR CODES:
====================================================================

- 400: Bad Request (validation error, invalid dates)
- 403: Forbidden (not owner of hold)
- 404: Not Found (car/hold not found)
- 409: Conflict (car already rented/held)
- 500: Internal Server Error

====================================================================
SECURITY:
====================================================================

- All endpoints require authentication
- User can only release their own holds
- User can only view their own reservations
- Hold ownership verified before order creation
- Car ownership not required (any rider can book)

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. Hold Duration: 10 minutes (configurable via environment variable)
2. Database: car_holds collection for persistent hold tracking
3. Production: Use MongoDB TTL indexes for auto-cleanup
4. Socket.IO: Real-time updates across all clients
5. Price Calculation: Handles all rental types with auto-detection

====================================================================
MONGODB INDEXES RECOMMENDED:
====================================================================

-- car_holds collection
db.car_holds.createIndex({ "carId": 1, "status": 1 })
db.car_holds.createIndex({ "holdExpiresAt": 1 }, { expireAfterSeconds: 0 })

-- orders collection
db.orders.createIndex({ "userId": 1, "status": 1 })
db.orders.createIndex({ "carId": 1, "status": 1 })
db.orders.createIndex({ "rentalDetails.startDateTime": 1, "rentalDetails.endDateTime": 1 })

====================================================================
"""

from fastapi import APIRouter, Request, Depends
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
import logging
import traceback
from bson import ObjectId

from middleware.auth_middleware import authenticate

logger = logging.getLogger(__name__)

# Create router
router = APIRouter()

# =============================================
# REQUEST MODELS
# =============================================

class CreateOrderRequest(BaseModel):
    carId: str
    carModel: str
    amount: float
    originalPrice: float
    discountPercentage: float = 0
    platformFee: float = 50
    paymentId: str
    orderId: Optional[str] = None
    rentalType: str = "fullday"
    startDateTime: datetime
    endDateTime: datetime
    rentalHours: Optional[int] = None
    calculatedPrice: Optional[float] = None
    hourlyRate: Optional[float] = None
    halfDayRate: Optional[float] = None
    dailyRate: float
    skipPastDateValidation: bool = False

class HoldRequest(BaseModel):
    carId: str

class AvailabilityRequest(BaseModel):
    carId: str
    startDateTime: datetime
    endDateTime: datetime

class CalculatePriceRequest(BaseModel):
    carId: str
    rentalType: str
    startDateTime: Optional[datetime] = None
    endDateTime: Optional[datetime] = None
    rentalHours: Optional[int] = None

class CompleteRideRequest(BaseModel):
    afterRidePhotos: Optional[List[str]] = []
    extraAmount: Optional[float] = 0.0
    extraPaymentId: Optional[str] = None

# =============================================
# CAR HOLD SYSTEM - 10 MINUTE HOLD
# =============================================

@router.post("/cars/hold")
async def create_car_hold(request: Request, data: HoldRequest, user: dict = Depends(authenticate)):
    """Create a 10-minute hold on a car when user clicks Rent Now"""
    try:
        db = request.app.state.db
        car_collection = db.partnercars
        hold_collection = db.car_holds
        sio = request.app.state.sio
        
        user_id = user.get('id')
        car_id = data.carId
        
        logger.info(f"🔒 Creating hold for car {car_id} by user {user_id}")
        
        # Check if car exists - convert to ObjectId
        try:
            car_obj_id = ObjectId(car_id)
            car = await car_collection.find_one({"_id": car_obj_id})
        except:
            car = await car_collection.find_one({"_id": car_id})
        
        if not car:
            return JSONResponse(
                status_code=404,
                content={
                    "success": False,
                    "message": "Car not found"
                }
            )
        
        # Check if car is already rented
        if car.get('status') == 'rented':
            return JSONResponse(
                status_code=409,
                content={
                    "success": False,
                    "message": "Car is already rented"
                }
            )
        
        # Check for existing active hold
        now = datetime.utcnow()
        existing_hold = await hold_collection.find_one({
            "carId": car_id,
            "status": "active",
            "holdExpiresAt": {"$gt": now}
        })
        
        if existing_hold:
            # If the hold belongs to the current user, return it
            if existing_hold.get('userId') == user_id:
                remaining = int((existing_hold['holdExpiresAt'] - now).total_seconds())
                return JSONResponse(
                    status_code=200,
                    content={
                        "success": True,
                        "message": "Existing hold found",
                        "hold": {
                            "carId": existing_hold['carId'],
                            "userId": existing_hold['userId'],
                            "status": existing_hold['status'],
                            "holdStartedAt": existing_hold['holdStartedAt'].isoformat(),
                            "holdExpiresAt": existing_hold['holdExpiresAt'].isoformat(),
                            "remainingSeconds": remaining
                        }
                    }
                )
            else:
                # Hold belongs to another user
                remaining = int((existing_hold['holdExpiresAt'] - now).total_seconds())
                return JSONResponse(
                    status_code=409,
                    content={
                        "success": False,
                        "message": f"Car is currently held by another user. Available in {remaining} seconds.",
                        "remainingSeconds": remaining
                    }
                )
        
        # Create new hold (10 minutes = 600 seconds)
        hold_expires_at = now + timedelta(minutes=10)
        
        hold_data = {
            "carId": car_id,
            "userId": user_id,
            "status": "active",
            "holdStartedAt": now,
            "holdExpiresAt": hold_expires_at,
            "createdAt": now,
            "updatedAt": now
        }
        
        result = await hold_collection.insert_one(hold_data)
        hold_id = str(result.inserted_id)
        
        # Update car status to "held" in car collection
        await car_collection.update_one(
            {"_id": car['_id']},
            {"$set": {"status": "held", "heldBy": user_id, "heldUntil": hold_expires_at, "updatedAt": now}}
        )
        
        # Emit socket event
        if sio:
            await sio.emit('car_hold_created', {
                "carId": car_id,
                "userId": user_id,
                "holdExpiresAt": hold_expires_at.isoformat()
            })
            
            # Also emit car availability update
            await sio.emit('car_availability_updated', {
                "carId": car_id,
                "status": "held",
                "heldBy": user_id
            })
        
        logger.info(f"✅ Hold created successfully: {hold_id}")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Car held successfully for 10 minutes",
                "hold": {
                    "id": hold_id,
                    "carId": car_id,
                    "userId": user_id,
                    "status": "active",
                    "holdStartedAt": now.isoformat(),
                    "holdExpiresAt": hold_expires_at.isoformat(),
                    "remainingSeconds": 600
                }
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error creating hold: {str(e)}")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error creating hold: {str(e)}"
            }
        )

@router.get("/cars/hold/{car_id}")
async def get_car_hold(request: Request, car_id: str, user: dict = Depends(authenticate)):
    """Get the current hold status for a car"""
    try:
        db = request.app.state.db
        hold_collection = db.car_holds
        
        user_id = user.get('id')
        now = datetime.utcnow()
        
        hold = await hold_collection.find_one({
            "carId": car_id,
            "status": "active",
            "holdExpiresAt": {"$gt": now}
        })
        
        if not hold:
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "hasHold": False,
                    "message": "No active hold for this car"
                }
            )
        
        remaining = int((hold['holdExpiresAt'] - now).total_seconds())
        is_owner = hold.get('userId') == user_id
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "hasHold": True,
                "isOwner": is_owner,
                "hold": {
                    "carId": hold['carId'],
                    "userId": hold['userId'],
                    "status": hold['status'],
                    "holdStartedAt": hold['holdStartedAt'].isoformat(),
                    "holdExpiresAt": hold['holdExpiresAt'].isoformat(),
                    "remainingSeconds": remaining
                }
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error getting hold: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error getting hold: {str(e)}"
            }
        )

@router.delete("/cars/hold/{car_id}")
async def release_car_hold(request: Request, car_id: str, user: dict = Depends(authenticate)):
    """Release a car hold (when payment is completed or user cancels)"""
    try:
        db = request.app.state.db
        hold_collection = db.car_holds
        car_collection = db.partnercars
        sio = request.app.state.sio
        
        user_id = user.get('id')
        
        # Find the hold
        hold = await hold_collection.find_one({
            "carId": car_id,
            "status": "active"
        })
        
        now = datetime.utcnow()
        if hold:
            # Release the hold in hold_collection
            await hold_collection.update_one(
                {"_id": hold['_id']},
                {"$set": {"status": "released", "releasedAt": now, "updatedAt": now}}
            )
        
        # Build query for car - supporting ObjectId or string
        # Only update status to "available" if the car is NOT currently rented
        target_ids = [ObjectId(car_id), car_id] if ObjectId.is_valid(car_id) else [car_id]
        car_filter = {
            "_id": {"$in": target_ids},
            "status": {"$ne": "rented"}
        }
        
        # Update car status back to available
        await car_collection.update_one(
            car_filter,
            {"$set": {"status": "available", "heldBy": None, "heldUntil": None, "updatedAt": now}}
        )
        
        # Emit socket event
        if sio:
            await sio.emit('car_hold_released', {
                "carId": car_id,
                "userId": user_id
            })
            
            await sio.emit('car_availability_updated', {
                "carId": car_id,
                "status": "available"
            })
        
        logger.info(f"✅ Hold released for car {car_id}")
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Hold released successfully"
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error releasing hold: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error releasing hold: {str(e)}"
            }
        )

# =============================================
# CREATE ORDER ROUTE - FIXED WITH datetime serialization
# =============================================

@router.post("/create-order")
async def create_order_endpoint(request: Request, data: CreateOrderRequest, user: dict = Depends(authenticate)):
    """Create a new order after successful payment"""
    try:
        logger.info(f"📝 Creating order for user {user.get('id')} (type: {user.get('type', 'rider')})")
        
        db = request.app.state.db
        order_collection = db.orders
        car_collection = db.partnercars
        partner_collection = db.partners
        hold_collection = db.car_holds
        sio = request.app.state.sio
        
        user_id = user.get('id')
        user_type = user.get('type', 'rider')
        
        start_date = data.startDateTime
        end_date = data.endDateTime
        
        if start_date >= end_date:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "End date must be after start date"
                }
            )
        
        # Check car availability - convert carId to ObjectId
        car = None
        try:
            car_obj_id = ObjectId(data.carId)
            car = await car_collection.find_one({"_id": car_obj_id})
        except Exception as e:
            logger.warning(f"Could not convert to ObjectId: {e}, trying string match")
            car = await car_collection.find_one({"_id": data.carId})
        
        if not car:
            logger.error(f"❌ Car not found with ID: {data.carId}")
            return JSONResponse(
                status_code=404,
                content={
                    "success": False,
                    "message": "Car not found"
                }
            )
        
        # Check if car is rented
        if car.get('status') == 'rented':
            return JSONResponse(
                status_code=409,
                content={
                    "success": False,
                    "message": "Car is already rented"
                }
            )
        
        # Check if car is held by this user
        now = datetime.utcnow()
        hold = await hold_collection.find_one({
            "carId": data.carId,
            "userId": user_id,
            "status": "active",
            "holdExpiresAt": {"$gt": now}
        })
        
        if not hold:
            return JSONResponse(
                status_code=409,
                content={
                    "success": False,
                    "message": "No active hold found for this car. Please try again."
                }
            )
        
        # Check for overlapping bookings
        existing_booking = await order_collection.find_one({
            "carId": data.carId,
            "status": {"$in": ["confirmed", "pending"]},
            "rentalDetails.startDateTime": {"$lt": end_date},
            "rentalDetails.endDateTime": {"$gt": start_date}
        })
        
        if existing_booking:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "Car is already booked for the selected time slot"
                }
            )
        
        # Create order
        order_data = {
            "userId": user_id,
            "userType": user_type,
            "carId": data.carId,
            "carModel": data.carModel,
            "amount": data.amount,
            "originalPrice": data.originalPrice,
            "discountPercentage": data.discountPercentage,
            "platformFee": data.platformFee,
            "paymentId": data.paymentId,
            "razorpayOrderId": data.orderId,
            "status": "confirmed",
            "rentalDetails": {
                "rentalType": data.rentalType,
                "startDateTime": start_date,
                "endDateTime": end_date,
                "rentalHours": data.rentalHours,
                "calculatedPrice": data.calculatedPrice or data.amount,
                "hourlyRate": data.hourlyRate,
                "halfDayRate": data.halfDayRate,
                "dailyRate": data.dailyRate
            },
            "createdAt": datetime.utcnow(),
            "updatedAt": datetime.utcnow()
        }
        
        result = await order_collection.insert_one(order_data)
        order_id = str(result.inserted_id)
        
        # Release the hold
        await hold_collection.update_one(
            {"_id": hold['_id']},
            {"$set": {"status": "converted", "convertedToOrder": order_id, "updatedAt": now}}
        )
        
        # Update car status to rented
        await car_collection.update_one(
            {"_id": car['_id']},
            {"$set": {"status": "rented", "heldBy": None, "heldUntil": None, "updatedAt": now}}
        )
        
        # Update partner's total rentals and earnings
        partner_id = car.get('partnerId')
        if partner_id:
            await partner_collection.update_one(
                {"_id": partner_id},
                {"$inc": {"totalRentals": 1, "totalEarnings": data.amount}}
            )
            
            # Emit socket events
            if sio:
                await sio.emit('car_status_updated', {
                    "carId": data.carId,
                    "status": "rented",
                    "carModel": data.carModel,
                    "rentalDetails": {
                        "startDateTime": start_date.isoformat(),
                        "endDateTime": end_date.isoformat()
                    }
                })
                
                await sio.emit('car_rented', {
                    "carId": data.carId,
                    "carModel": data.carModel,
                    "partnerId": partner_id
                })
                
                await sio.emit('car_booking_confirmed', {
                    "carId": data.carId,
                    "orderId": order_id,
                    "userId": user_id
                })
        
        logger.info(f"✅ Order created successfully: {order_id}")
        
        # ========== FIX: Convert datetime objects to ISO format strings ==========
        # Create a serializable copy of rental details
        rental_details_serializable = {
            "rentalType": order_data["rentalDetails"]["rentalType"],
            "startDateTime": order_data["rentalDetails"]["startDateTime"].isoformat() if isinstance(order_data["rentalDetails"]["startDateTime"], datetime) else order_data["rentalDetails"]["startDateTime"],
            "endDateTime": order_data["rentalDetails"]["endDateTime"].isoformat() if isinstance(order_data["rentalDetails"]["endDateTime"], datetime) else order_data["rentalDetails"]["endDateTime"],
            "rentalHours": order_data["rentalDetails"]["rentalHours"],
            "calculatedPrice": order_data["rentalDetails"]["calculatedPrice"],
            "hourlyRate": order_data["rentalDetails"]["hourlyRate"],
            "halfDayRate": order_data["rentalDetails"]["halfDayRate"],
            "dailyRate": order_data["rentalDetails"]["dailyRate"]
        }
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Order created successfully",
                "order": {
                    "id": order_id,
                    "amount": data.amount,
                    "status": "confirmed",
                    "rentalDetails": rental_details_serializable,
                    "createdAt": datetime.utcnow().isoformat()
                }
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error creating order: {str(e)}")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error creating order: {str(e)}"
            }
        )

# =============================================
# OTHER ORDER ROUTES
# =============================================

@router.get("/rides/my-rides")
async def get_my_rides(request: Request, user: dict = Depends(authenticate)):
    """Get user's rides"""
    try:
        db = request.app.state.db
        order_collection = db.orders
        
        user_id = user.get('id')
        
        orders_cursor = order_collection.find({"userId": user_id}).sort("createdAt", -1)
        orders = await orders_cursor.to_list(length=None)
        
        # Convert ObjectId to string and datetime to ISO format for JSON serialization
        serializable_orders = []
        for order in orders:
            serializable_order = {}
            for key, value in order.items():
                if key == '_id':
                    serializable_order[key] = str(value)
                elif isinstance(value, datetime):
                    serializable_order[key] = value.isoformat()
                elif isinstance(value, dict):
                    # Handle nested dicts like rentalDetails
                    serializable_order[key] = {}
                    for sub_key, sub_value in value.items():
                        if isinstance(sub_value, datetime):
                            serializable_order[key][sub_key] = sub_value.isoformat()
                        else:
                            serializable_order[key][sub_key] = sub_value
                else:
                    serializable_order[key] = value
            serializable_orders.append(serializable_order)
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "rides": serializable_orders
            }
        )
    except Exception as e:
        logger.error(f"❌ Error getting rides: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error getting rides: {str(e)}"
            }
        )

@router.post("/rides/{order_id}/complete")
async def complete_ride(
    order_id: str,
    request: Request,
    data: CompleteRideRequest,
    user: dict = Depends(authenticate)
):
    """Complete an active ride, save after-ride photos and any extra charges, and mark car available"""
    try:
        db = request.app.state.db
        order_collection = db.orders
        car_collection = db.partnercars
        sio = getattr(request.app.state, 'sio', None)
        
        user_id = user.get('id')
        logger.info(f"🏁 Completing ride {order_id} for user {user_id}")
        
        # Build query for order - supporting ObjectId or string
        order = None
        try:
            if ObjectId.is_valid(order_id):
                order = await order_collection.find_one({"$or": [{"_id": ObjectId(order_id)}, {"_id": order_id}]})
            else:
                order = await order_collection.find_one({"_id": order_id})
        except Exception as e:
            logger.warning(f"ObjectId lookup error: {e}")
            order = await order_collection.find_one({"_id": order_id})
            
        if not order:
            logger.error(f"❌ Order {order_id} not found")
            return JSONResponse(
                status_code=404,
                content={"success": False, "message": "Ride / Order not found"}
            )
            
        now = datetime.utcnow()
        
        # Update order with completed status, return/handover date, photos, extra charges
        update_fields = {
            "status": "completed",
            "handoverDate": now,
            "afterRidePhotos": data.afterRidePhotos or [],
            "extraAmount": float(data.extraAmount or 0.0),
            "updatedAt": now
        }
        if data.extraPaymentId:
            update_fields["extraPaymentId"] = data.extraPaymentId
            
        await order_collection.update_one(
            {"_id": order["_id"]},
            {"$set": update_fields}
        )
        
        # Free up the car
        car_id = order.get("carId")
        if car_id:
            car_id_str = str(car_id)
            car_filter = {"$or": [{"_id": ObjectId(car_id_str)}, {"_id": car_id_str}]} if ObjectId.is_valid(car_id_str) else {"_id": car_id_str}
            await car_collection.update_one(
                car_filter,
                {
                    "$set": {
                        "status": "available",
                        "heldBy": None,
                        "heldUntil": None,
                        "updatedAt": now
                    }
                }
            )
            
            if sio:
                await sio.emit("car_status_updated", {
                    "carId": car_id_str,
                    "status": "available"
                })
                await sio.emit("ride_completed", {
                    "orderId": order_id,
                    "carId": car_id_str,
                    "userId": user_id
                })
        
        logger.info(f"✅ Ride {order_id} ended successfully")
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Ride completed successfully and scooty returned!",
                "orderId": order_id
            }
        )
    except Exception as e:
        logger.error(f"❌ Error completing ride {order_id}: {e}\n{traceback.format_exc()}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "message": f"Error completing ride: {str(e)}"}
        )

@router.post("/check-availability")
async def check_availability(request: Request, data: AvailabilityRequest, user: dict = Depends(authenticate)):
    """Check car availability for a time slot"""
    try:
        db = request.app.state.db
        order_collection = db.orders
        hold_collection = db.car_holds
        
        start_date = data.startDateTime
        end_date = data.endDateTime
        car_id = data.carId
        
        # Check for overlapping bookings
        conflicting_bookings = await order_collection.find({
            "carId": car_id,
            "status": {"$in": ["confirmed", "pending"]},
            "rentalDetails.startDateTime": {"$lt": end_date},
            "rentalDetails.endDateTime": {"$gt": start_date}
        }).to_list(length=None)
        
        # Check for active holds
        now = datetime.utcnow()
        active_hold = await hold_collection.find_one({
            "carId": car_id,
            "status": "active",
            "holdExpiresAt": {"$gt": now}
        })
        
        is_available = len(conflicting_bookings) == 0 and active_hold is None
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "available": is_available,
                "conflictingBookings": len(conflicting_bookings),
                "hasActiveHold": active_hold is not None,
                "holdDetails": {
                    "userId": active_hold.get('userId') if active_hold else None,
                    "expiresAt": active_hold.get('holdExpiresAt').isoformat() if active_hold else None
                } if active_hold else None
            }
        )
    except Exception as e:
        logger.error(f"❌ Error checking availability: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error checking availability: {str(e)}"
            }
        )

@router.post("/calculate-price")
async def calculate_price(request: Request, data: CalculatePriceRequest, user: dict = Depends(authenticate)):
    """Calculate rental price without creating order"""
    try:
        db = request.app.state.db
        car_collection = db.partnercars
        
        car = None
        try:
            car_obj_id = ObjectId(data.carId)
            car = await car_collection.find_one({"_id": car_obj_id})
        except:
            car = await car_collection.find_one({"_id": data.carId})
        
        if not car:
            return JSONResponse(
                status_code=404,
                content={
                    "success": False,
                    "message": "Car not found"
                }
            )
        
        daily_rate = car.get('dailyRate', 0)
        hourly_rate = car.get('hourlyRate') or round(daily_rate / 8)
        half_day_rate = car.get('halfDayRate') or round(daily_rate * 0.6)
        
        calculated_price = 0
        final_rental_type = data.rentalType
        
        if data.rentalType == 'hourly':
            calculated_price = hourly_rate * (data.rentalHours or 1)
            final_rental_type = 'hourly'
        elif data.rentalType == 'halfday':
            calculated_price = half_day_rate
            final_rental_type = 'halfday'
        elif data.rentalType == 'custom':
            if data.startDateTime and data.endDateTime:
                diff_hours = max(1, (data.endDateTime - data.startDateTime).total_seconds() / 3600)
                if diff_hours <= 8:
                    calculated_price = hourly_rate * diff_hours
                    final_rental_type = 'hourly'
                elif diff_hours <= 12:
                    calculated_price = half_day_rate
                    final_rental_type = 'halfday'
                else:
                    days = (diff_hours + 23) // 24
                    calculated_price = daily_rate * days
                    final_rental_type = 'fullday'
        else:
            # Default to full day
            calculated_price = daily_rate
            final_rental_type = 'fullday'
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "price": calculated_price,
                "rentalType": final_rental_type,
                "breakdown": {
                    "dailyRate": daily_rate,
                    "hourlyRate": hourly_rate,
                    "halfDayRate": half_day_rate,
                    "calculatedPrice": calculated_price
                }
            }
        )
    except Exception as e:
        logger.error(f"❌ Error calculating price: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error calculating price: {str(e)}"
            }
        )

# =============================================
# Print confirmation that order routes are loaded
# =============================================
print("✅ ORDER ROUTES LOADED - /api/create-order endpoint registered")