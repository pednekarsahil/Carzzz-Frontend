"""
====================================================================
FILE: partner_model.py
LOCATION: server/partner/models/partner_model.py
PURPOSE: MongoDB schema definition for business partners
====================================================================

OVERVIEW:
This module defines the data structure for partner accounts using 
Pydantic models. Partners are businesses (car rentals, car repair 
shops, tour operators, etc.) who list their vehicles on the platform.
It includes validation, type safety, and consistent structure for 
all partner-related database operations.

====================================================================
MODEL HIERARCHY:
====================================================================

Base Models (Pydantic):
    ├── PyObjectId          → Custom ObjectId validator for MongoDB
    ├── PartnerBase         → Core partner fields (no sensitive data)
    ├── PartnerCreate       → Input validation for new partners
    ├── PartnerInDB         → Database representation (with password)
    └── PartnerResponse     → API response format (no password)

Aliases:
    Partner = PartnerInDB   → Backward compatibility

====================================================================
FIELD DESCRIPTIONS:
====================================================================

PARTNER FIELDS:
- fullname (str)          → Partner's full name (2-100 chars)
- businessName (str)      → Registered business name (2-100 chars)
- businessEmail (EmailStr) → Business email (validated format)
- phoneNumber (str)       → 10-digit phone number (pattern validation)
- businessAddress (str)   → Complete business address
- businessType (str)      → Type of business (car rental, repair, etc.)
- password (str)          → Bcrypt hashed password (min 6 chars)
- isActive (bool)         → Account active status (default: True)
- isEmailVerified (bool)  → Email verification status (default: False)
- agreedToTerms (bool)    → Terms acceptance (default: False)
- totalEarnings (float)   → Lifetime earnings in INR (default: 0)
- totalRentals (int)      → Total cars rented count (default: 0)
- rating (float)          → Average partner rating (default: 0)
- cars (List[str])        → Array of car ObjectIds (default: [])
- lastLogin (datetime)    → Last login timestamp (default: now)
- createdAt (datetime)    → Account creation timestamp (default: now)
- updatedAt (datetime)    → Last update timestamp (default: now)

FIREBASE FIELDS (Added in controller, not in model):
- firebaseUid (str)       → Firebase user UID
- firebasePicture (str)   → Google profile picture URL
- isFirebaseAccount (bool) → Indicates Firebase login

====================================================================
VALIDATION RULES:
====================================================================

1. fullname: 2-100 characters
2. businessName: 2-100 characters
3. businessEmail: Valid email format (EmailStr)
4. phoneNumber: Exactly 10 digits (regex: ^[0-9]{10}$)
5. password: Minimum 6 characters (only in PartnerCreate)
6. isActive: Boolean (default: True)
7. isEmailVerified: Boolean (default: False)
8. agreedToTerms: Boolean (default: False)
9. totalEarnings: Float (default: 0)
10. totalRentals: Integer (default: 0)
11. rating: Float (default: 0)

====================================================================
USAGE EXAMPLES:
====================================================================

1. CREATE A NEW PARTNER:
    from models.partner_model import PartnerCreate

    new_partner = PartnerCreate(
        fullname="Rajesh Kumar",
        businessName="R K Motors",
        businessEmail="rajesh@rkmotors.com",
        phoneNumber="9876543210",
        businessAddress="123, MG Road, Delhi",
        businessType="car Rental",
        password="securepassword123",
        isActive=True,
        isEmailVerified=True,
        agreedToTerms=True
    )

2. STORE IN MONGODB:
    partner_data = new_partner.dict(by_alias=True)
    # Hash password before storing
    partner_data['password'] = hash_password(partner_data['password'])
    result = await partner_collection.insert_one(partner_data)

3. CONVERT TO RESPONSE (No password):
    from models.partner_model import PartnerResponse
    partner_response = PartnerResponse(
        id=str(result.inserted_id),
        **partner_data
    )
    # Note: password is automatically excluded

4. GET PARTNER DATA:
    partner = await partner_collection.find_one({"_id": partner_id})
    partner_obj = PartnerInDB(**partner)  # Validates structure

====================================================================
DATABASE STORAGE FORMAT (MongoDB):
====================================================================

{
    "_id": ObjectId("67e3a1b2c3d4e5f6a7b8c9d0"),
    "fullname": "Rajesh Kumar",
    "businessName": "R K Motors",
    "businessEmail": "rajesh@rkmotors.com",
    "phoneNumber": "9876543210",
    "businessAddress": "123, MG Road, Delhi",
    "businessType": "car Rental",
    "password": "$2b$12$...hashed...",  // Bcrypt hashed
    "isActive": true,
    "isEmailVerified": true,
    "agreedToTerms": true,
    "totalEarnings": 12580.0,
    "totalRentals": 42,
    "rating": 4.5,
    "cars": [
        ObjectId("67e3a1b2c3d4e5f6a7b8c9d1"),
        ObjectId("67e3a1b2c3d4e5f6a7b8c9d2")
    ],
    "lastLogin": ISODate("2026-03-25T14:30:00Z"),
    "createdAt": ISODate("2026-01-15T10:00:00Z"),
    "updatedAt": ISODate("2026-03-25T14:30:00Z"),
    // Firebase fields (added by controller):
    "firebaseUid": "abc123def456",
    "firebasePicture": "https://lh3.googleusercontent.com/...",
    "isFirebaseAccount": true
}

====================================================================
BUSINESS TYPES SUPPORTED:
====================================================================

Common business types (from frontend):
- car Rental
- car Repair
- car Store
- Tour Operator
- car Accessories
- Other

====================================================================
RELATED FILES:
====================================================================

- server/partner/controllers/partner_controller.py → Uses this model
- server/partner/models/partnercar_model.py → Referenced by cars array
- server/routes/partner_routes.py → API route definitions

====================================================================
DEPENDENCIES:
====================================================================

- pydantic (BaseModel, Field, EmailStr, validator)
- bson (ObjectId for MongoDB)
- datetime (datetime, timezone handling)
- typing (Optional, List, type hints)

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. Password handling: Never return password in API responses
2. ObjectId conversion: Automatic str conversion via json_encoders
3. Field aliases: "_id" maps to "id" in responses
4. Default values: Active, 0 earnings, 0 rentals
5. Email validation: Uses pydantic.EmailStr (RFC 5322)
6. Phone validation: Exactly 10 digits (Indian format)
7. Denormalization: cars array contains ObjectId references
8. Alias: Partner = PartnerInDB for backward compatibility

====================================================================
MONGODB INDEXES RECOMMENDED:
====================================================================

- businessEmail (unique)    → Fast login & lookup
- businessName (unique)     → Prevent duplicate business names
- isActive (boolean)        → Filter active/inactive partners
- businessType (string)     → Filter by business category
- rating (descending)       → Top-rated partners
- totalEarnings (descending)→ Top-earning partners
- Composite: {businessType: 1, rating: -1} → Filtered sorting

====================================================================
QUERY EXAMPLES:
====================================================================

# Find partner by email (login)
db.partners.find({ "businessEmail": "rajesh@rkmotors.com" })

# Find all active partners
db.partners.find({ "isActive": true })

# Find top earning partners
db.partners.find().sort({ "totalEarnings": -1 }).limit(10)

# Get partner with their cars (using $lookup aggregation)
db.partners.aggregate([
    { "$match": { "_id": ObjectId("67e3a1b2...") } },
    { "$lookup": {
        "from": "partnercars",
        "localField": "cars",
        "foreignField": "_id",
        "as": "carDetails"
    }}
])

# Find partners by business type
db.partners.find({ "businessType": "car Rental" })

====================================================================
SECURITY CONSIDERATIONS:
====================================================================

1. Password field: Never included in PartnerResponse
2. Password hashing: Bcrypt before storage (in controller)
3. Email verification: Field tracking verification status
4. Account deactivation: isActive flag for soft delete
5. Terms agreement: tracked for legal compliance
6. Firebase accounts: No password stored, marked with flag

====================================================================
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, EmailStr, validator
from bson import ObjectId

class PyObjectId(ObjectId):
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid objectid")
        return ObjectId(v)

    @classmethod
    def __modify_schema__(cls, field_schema):
        field_schema.update(type="string")

class PartnerBase(BaseModel):
    fullname: str = Field(..., min_length=2, max_length=100)
    businessName: str = Field(..., min_length=2, max_length=100)
    businessEmail: EmailStr
    phoneNumber: str = Field(..., pattern=r'^[0-9]{10}$')
    businessAddress: str
    businessType: str
    isActive: bool = True
    isEmailVerified: bool = False
    agreedToTerms: bool = False
    totalEarnings: float = 0
    totalRentals: int = 0
    rating: float = 0

class PartnerCreate(PartnerBase):
    password: str = Field(..., min_length=6)

class PartnerInDB(PartnerBase):
    id: str = Field(alias="_id")
    password: str
    cars: List[str] = []
    lastLogin: datetime = Field(default_factory=datetime.utcnow)
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

class PartnerResponse(PartnerBase):
    id: str
    createdAt: datetime
    updatedAt: datetime

# ADD THIS LINE - Alias PartnerInDB as Partner for backward compatibility
Partner = PartnerInDB


