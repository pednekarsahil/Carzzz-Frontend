"""
====================================================================
FILE: order_model.py
LOCATION: server/partner/models/order_model.py
PURPOSE: MongoDB schema definition for car rental orders
====================================================================

OVERVIEW:
This module defines the data structure for car rental orders 
using Pydantic models. It ensures data validation, type safety,
and consistent structure for all order-related database operations.

====================================================================
MODEL HIERARCHY:
====================================================================

Base Models (Pydantic):
    ├── RentalDetails        → Nested rental information
    ├── OrderBase           → Core order fields
    ├── OrderCreate         → Input validation for new orders
    ├── OrderInDB           → Database representation (with ObjectId)
    └── OrderResponse       → API response format

====================================================================
FIELD DESCRIPTIONS:
====================================================================

ORDER FIELDS:
- userId (str)            → ID of the rider/user placing order
- userType (str)          → 'rider' or 'partner' (handled in controller)
- carId (str)             → ID of the car being rented
- carModel (str)          → Car model name (denormalized for performance)
- amount (float)          → Final amount paid after discounts
- originalPrice (float)   → Original price before discount
- discountPercentage (float) → Percentage discount applied (default: 0)
- platformFee (float)     → Platform service fee (default: 50)
- paymentId (str)         → Razorpay payment ID
- razorpayOrderId (str)   → Razorpay order ID (optional)
- status (str)            → pending | confirmed | completed | cancelled
- rentalDetails (object)  → Nested rental information
- handoverDate (datetime) → When car was handed over (optional)
- bookingDate (datetime)  → When booking was created (default: now)
- createdAt (datetime)    → Record creation timestamp
- updatedAt (datetime)    → Record update timestamp

RENTAL DETAILS FIELDS:
- rentalType (str)        → hourly | halfday | custom | fullday
- startDateTime (datetime) → Rental start date/time
- endDateTime (datetime)  → Rental end date/time
- rentalHours (int)       → Total rental hours (for hourly/custom)
- calculatedPrice (float) → Price calculated from rates
- hourlyRate (float)      → Per-hour rate (optional)
- halfDayRate (float)     → Half-day rate (optional)
- dailyRate (float)       → Per-day rate (required)

====================================================================
VALIDATION RULES:
====================================================================

1. rentalType must be one of: hourly, halfday, custom, fullday
2. status must be one of: pending, confirmed, completed, cancelled
3. discountPercentage default: 0 (range: 0-100)
4. platformFee default: 50 (₹)
5. All prices are in Indian Rupees (₹)
6. Dates stored in UTC, converted on display

====================================================================
USAGE EXAMPLES:
====================================================================

1. CREATE A NEW ORDER:
    from models.order_model import OrderCreate, RentalDetails

    rental_details = RentalDetails(
        rentalType="fullday",
        startDateTime=datetime(2026, 3, 25, 10, 0),
        endDateTime=datetime(2026, 3, 26, 10, 0),
        calculatedPrice=199.0,
        dailyRate=250.0
    )

    new_order = OrderCreate(
        userId="user_123",
        carId="car_456",
        carModel="Honda Activa",
        amount=199.0,
        originalPrice=250.0,
        discountPercentage=20,
        platformFee=50,
        paymentId="pay_xyz789",
        razorpayOrderId="order_xyz789",
        status="confirmed",
        rentalDetails=rental_details
    )

2. STORE IN MONGODB:
    order_data = new_order.dict(by_alias=True)
    result = await order_collection.insert_one(order_data)

3. CONVERT TO RESPONSE:
    from models.order_model import OrderResponse
    order_response = OrderResponse(
        id=str(result.inserted_id),
        **order_data
    )

====================================================================
DATABASE STORAGE FORMAT (MongoDB):
====================================================================

{
    "_id": ObjectId("67e3a1b2c3d4e5f6a7b8c9d0"),
    "userId": "user_123",
    "carId": "car_456",
    "carModel": "Honda Activa",
    "amount": 199.0,
    "originalPrice": 250.0,
    "discountPercentage": 20.0,
    "platformFee": 50.0,
    "paymentId": "pay_xyz789",
    "razorpayOrderId": "order_xyz789",
    "status": "confirmed",
    "rentalDetails": {
        "rentalType": "fullday",
        "startDateTime": ISODate("2026-03-25T10:00:00Z"),
        "endDateTime": ISODate("2026-03-26T10:00:00Z"),
        "rentalHours": 24,
        "calculatedPrice": 199.0,
        "hourlyRate": null,
        "halfDayRate": null,
        "dailyRate": 250.0
    },
    "handoverDate": null,
    "bookingDate": ISODate("2026-03-24T15:30:00Z"),
    "createdAt": ISODate("2026-03-24T15:30:00Z"),
    "updatedAt": ISODate("2026-03-24T15:30:00Z")
}

====================================================================
RELATED FILES:
====================================================================

- server/partner/controllers/order_controller.py  → Uses this model
- server/partner/controllers/partner_controller.py → References orders
- server/routes/order_routes.py                  → API route definitions

====================================================================
DEPENDENCIES:
====================================================================

- pydantic (BaseModel, Field, validation)
- bson (ObjectId for MongoDB)
- datetime (datetime, timezone handling)
- typing (Optional, type hints)

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. ObjectId conversion: Automatic str conversion via json_encoders
2. Field aliases: "_id" maps to "id" in responses
3. Default values: status="pending", platformFee=50
4. Rental types: Standardized strings for frontend consistency
5. All timestamps: UTC format for consistency
6. Denormalization: carModel stored for quick access (no join needed)

====================================================================
MONGODB INDEXES RECOMMENDED:
====================================================================

- userId (for querying user orders)
- carId (for checking availability)
- status (for filtering order status)
- rentalDetails.startDateTime (for date range queries)
- rentalDetails.endDateTime (for date range queries)
- Composite: {carId: 1, status: 1} (for availability checks)
- Composite: {userId: 1, status: 1} (for user order history)

====================================================================
QUERY EXAMPLES:
====================================================================

# Get all orders for a user
db.orders.find({ "userId": "user_123" })

# Get confirmed orders for a car
db.orders.find({ 
    "carId": "car_456", 
    "status": "confirmed" 
})

# Check overlapping bookings
db.orders.find({
    "carId": "car_456",
    "status": { "$in": ["pending", "confirmed"] },
    "rentalDetails.startDateTime": { "$lt": end_date },
    "rentalDetails.endDateTime": { "$gt": start_date }
})

# Get today's orders
db.orders.find({
    "createdAt": { "$gte": ISODate("2026-03-25T00:00:00Z") }
})

====================================================================
"""

from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field
from bson import ObjectId

class RentalDetails(BaseModel):
    rentalType: str = Field(..., pattern='^(hourly|halfday|custom|fullday)$')
    startDateTime: datetime
    endDateTime: datetime
    rentalHours: Optional[int] = None
    calculatedPrice: float
    hourlyRate: Optional[float] = None
    halfDayRate: Optional[float] = None
    dailyRate: float

class OrderBase(BaseModel):
    userId: str
    carId: str
    carModel: str
    amount: float
    originalPrice: float
    discountPercentage: float = 0
    platformFee: float = 50
    paymentId: str
    razorpayOrderId: Optional[str] = None
    status: str = Field("pending", pattern='^(pending|confirmed|completed|cancelled)$')
    rentalDetails: RentalDetails
    handoverDate: Optional[datetime] = None
    bookingDate: datetime = Field(default_factory=datetime.utcnow)

class OrderCreate(OrderBase):
    pass

class OrderInDB(OrderBase):
    id: str = Field(alias="_id")
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

class OrderResponse(OrderBase):
    id: str
    createdAt: datetime
    updatedAt: datetime

    # Alias for backward compatibility
Order = OrderInDB