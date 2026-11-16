
# ============================================================
# FILE: order_controller.py
# LOCATION: server/partner/controllers/order_controller.py
# PURPOSE: Handle car rental order creation after payment
# 
# DETAILS:
# - Creates confirmed orders after successful Razorpay payment
# - Validates car availability with overlapping booking checks
# - Automatically updates car status to "rented"
# - Tracks partner earnings and total rentals
# - Emits real-time WebSocket events (car_status_updated, car_rented)
# - Supports multiple rental types: full-day, hourly, half-day
# - Stores complete rental details with timestamps
# - Prevents double-booking with conflict detection
# - Handles both rider and partner user types
# 
# DEPENDENCIES:
# - FastAPI (Request, JSONResponse)
# - MongoDB (bson.ObjectId)
# - Python datetime for date handling
# - Socket.IO for real-time notifications
# 
# INPUT: POST /api/orders/create with payment details
# OUTPUT: Success/Error response with order ID and details
# 
# DATABASE COLLECTIONS USED:
# - orders (create new order)
# - partnercars (check/update car status)
# - partners (update partner stats)
# ============================================================

import logging
from datetime import datetime, timedelta
from fastapi import Request
from fastapi.responses import JSONResponse
from bson import ObjectId

logger = logging.getLogger(__name__)

async def create_order(request: Request):
    """
    Create a new order after successful payment
    Supports both riders and partners
    """
    try:
        body = await request.json()
        user = request.state.user
        
        user_id = user.get('id')
        user_type = user.get('type', 'rider')
        
        db = request.app.state.db
        order_collection = db.orders
        car_collection = db.partnercars
        partner_collection = db.partners
        sio = request.app.state.sio
        
        car_id = body.get('carId')
        car_model = body.get('carModel')
        amount = body.get('amount')
        original_price = body.get('originalPrice', amount)
        discount_percentage = body.get('discountPercentage', 0)
        platform_fee = body.get('platformFee', 50)
        payment_id = body.get('paymentId')
        order_id = body.get('orderId')
        rental_type = body.get('rentalType', 'fullday')
        start_date = datetime.fromisoformat(body.get('startDateTime'))
        end_date = datetime.fromisoformat(body.get('endDateTime'))
        rental_hours = body.get('rentalHours')
        calculated_price = body.get('calculatedPrice', amount)
        hourly_rate = body.get('hourlyRate')
        half_day_rate = body.get('halfDayRate')
        daily_rate = body.get('dailyRate')
        
        logger.info(f"📝 Creating order for user {user_id} (type: {user_type})")
        
        if start_date >= end_date:
            return JSONResponse(
                status_code=400,
                content={
                    "success": False,
                    "message": "End date must be after start date"
                }
            )
        
        # Check car availability
        car_filter = {"$or": [{"_id": ObjectId(car_id)}, {"_id": car_id}]} if (isinstance(car_id, str) and ObjectId.is_valid(car_id)) else {"_id": car_id}
        car = await car_collection.find_one(car_filter)
        if not car:
            return JSONResponse(
                status_code=404,
                content={
                    "success": False,
                    "message": "Car not found"
                }
            )
        
        # Check for overlapping bookings
        existing_booking = await order_collection.find_one({
            "carId": car_id,
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
            "carId": car_id,
            "carModel": car_model,
            "amount": amount,
            "originalPrice": original_price,
            "discountPercentage": discount_percentage,
            "platformFee": platform_fee,
            "paymentId": payment_id,
            "razorpayOrderId": order_id,
            "status": "confirmed",
            "rentalDetails": {
                "rentalType": rental_type,
                "startDateTime": start_date,
                "endDateTime": end_date,
                "rentalHours": rental_hours,
                "calculatedPrice": calculated_price or amount,
                "hourlyRate": hourly_rate,
                "halfDayRate": half_day_rate,
                "dailyRate": daily_rate
            },
            "createdAt": datetime.utcnow(),
            "updatedAt": datetime.utcnow()
        }
        
        result = await order_collection.insert_one(order_data)
        order_id_str = str(result.inserted_id)
        
        # Update car status to rented
        if car:
            await car_collection.update_one(
                {"_id": car["_id"]},
                {"$set": {"status": "rented", "updatedAt": datetime.utcnow()}}
            )
            
            # Update partner's total rentals and earnings
            partner_id = car.get('partnerId')
            if partner_id:
                await partner_collection.update_one(
                    {"_id": partner_id},
                    {"$inc": {"totalRentals": 1, "totalEarnings": amount}}
                )
                
                # Emit socket events
                if sio:
                    await sio.emit('car_status_updated', {
                        "carId": car_id,
                        "status": "rented",
                        "carModel": car_model,
                        "rentalDetails": {
                            "startDateTime": start_date.isoformat(),
                            "endDateTime": end_date.isoformat()
                        }
                    })
                    
                    await sio.emit('car_rented', {
                        "carId": car_id,
                        "carModel": car_model,
                        "partnerId": partner_id
                    })
        
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Order created successfully",
                "order": {
                    "id": order_id_str,
                    "amount": amount,
                    "status": "confirmed",
                    "rentalDetails": order_data["rentalDetails"],
                    "createdAt": datetime.utcnow().isoformat()
                }
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error creating order: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Error creating order: {str(e)}"
            }
        )