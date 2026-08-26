"""
====================================================================
FILE: user_model.py
LOCATION: server/rider/models/user_model.py
PURPOSE: MongoDB schema definition for rider/user accounts
====================================================================

OVERVIEW:
This module defines the data structure for rider (end user) accounts
using Pydantic models. It supports both traditional email/password
registration and Firebase/Google Sign-In accounts with comprehensive
validation and type safety.

====================================================================
MODEL HIERARCHY:
====================================================================

Base Models (Pydantic):
    ├── PyObjectId          → Custom ObjectId validator for MongoDB
    ├── UserBase            → Core user fields (non-sensitive)
    ├── UserCreate          → Input validation for new users
    ├── UserInDB            → Database representation (with password)
    └── UserResponse        → API response format (no password)

Aliases:
    User = UserInDB         → Backward compatibility

====================================================================
FIELD DESCRIPTIONS:
====================================================================

USER FIELDS:
- fullname (str)          → User's full name (2-100 chars)
- email (EmailStr)        → Validated email address (RFC 5322)
- dob (str)               → Date of birth (YYYY-MM-DD format)
- password (str)          → Bcrypt hashed password (min 6 chars)
- isActive (bool)         → Account active status (default: True)
- isEmailVerified (bool)  → Email verification status (default: False)
- isFirebaseAccount (bool) → Indicates Firebase login (default: False)
- firebaseUid (str)       → Firebase user UID (optional)
- firebasePicture (str)   → Google profile picture URL (default: "")
- lastLogin (datetime)    → Last login timestamp (default: now)
- createdAt (datetime)    → Account creation timestamp (default: now)
- updatedAt (datetime)    → Last update timestamp (default: now)

====================================================================
VALIDATION RULES:
====================================================================

1. fullname: 2-100 characters
2. email: Valid email format (EmailStr)
3. dob: String format (YYYY-MM-DD) - validated in controller
4. password: Minimum 6 characters (only in UserCreate)
5. isActive: Boolean (default: True)
6. isEmailVerified: Boolean (default: False)
7. isFirebaseAccount: Boolean (default: False)
8. firebaseUid: Optional string
9. firebasePicture: String (default: "")

====================================================================
USAGE EXAMPLES:
====================================================================

1. CREATE A NEW USER (Traditional):
    from models.user_model import UserCreate

    new_user = UserCreate(
        fullname="John Doe",
        email="john@example.com",
        password="securepassword123",
        dob="1990-01-15",
        isEmailVerified=True
    )

    # Hash password before storing
    user_data = new_user.dict(by_alias=True)
    user_data['password'] = pwd_context.hash(user_data['password'])
    result = await user_collection.insert_one(user_data)

2. CREATE A FIREBASE USER:
    new_user = UserCreate(
        fullname="Jane Smith",
        email="jane@gmail.com",
        password=hashlib.sha256(os.urandom(20)).hexdigest(),  # Random
        dob="1995-05-20",
        isFirebaseAccount=True,
        isEmailVerified=True,
        firebaseUid="abc123def456",
        firebasePicture="https://lh3.googleusercontent.com/..."
    )

3. CONVERT TO RESPONSE (No password):
    from models.user_model import UserResponse
    user_response = UserResponse(
        id=str(result.inserted_id),
        **user_data
    )
    # Note: password is automatically excluded

4. RETRIEVE AND VALIDATE:
    user_data = await user_collection.find_one({"_id": user_id})
    user_obj = UserInDB(**user_data)  # Validates structure

====================================================================
DATABASE STORAGE FORMAT (MongoDB):
====================================================================

{
    "_id": ObjectId("67e3a1b2c3d4e5f6a7b8c9d0"),
    "fullname": "John Doe",
    "email": "john@example.com",
    "password": "$2b$12$...hashed...",  // Bcrypt hashed
    "dob": "1990-01-15",
    "isActive": true,
    "isEmailVerified": true,
    "isFirebaseAccount": false,
    "firebaseUid": null,
    "firebasePicture": "",
    "lastLogin": ISODate("2026-03-25T14:30:00Z"),
    "createdAt": ISODate("2026-01-15T10:00:00Z"),
    "updatedAt": ISODate("2026-03-25T14:30:00Z")
}

// Firebase Account Example:
{
    "_id": ObjectId("67e3a1b2c3d4e5f6a7b8c9d1"),
    "fullname": "Jane Smith",
    "email": "jane@gmail.com",
    "password": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
    "dob": "1995-05-20",
    "isActive": true,
    "isEmailVerified": true,
    "isFirebaseAccount": true,
    "firebaseUid": "abc123def456",
    "firebasePicture": "https://lh3.googleusercontent.com/...",
    "lastLogin": ISODate("2026-03-25T14:30:00Z"),
    "createdAt": ISODate("2026-03-20T10:00:00Z"),
    "updatedAt": ISODate("2026-03-25T14:30:00Z")
}

====================================================================
RELATED FILES:
====================================================================

- server/rider/controllers/auth_controller.py → Uses this model
- server/rider/routes/auth_routes.py → API route definitions
- server/rider/controllers/user_controller.py → User profile management

====================================================================
DEPENDENCIES:
====================================================================

- pydantic (BaseModel, Field, EmailStr, validator)
- bson (ObjectId for MongoDB)
- datetime (datetime, timezone handling)
- typing (Optional, type hints)

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. Password Handling: Never return password in API responses
2. ObjectId Conversion: Automatic str conversion via json_encoders
3. Field Aliases: "_id" maps to "id" in responses
4. Firebase Accounts: Random password, no login via email/password
5. Email Validation: Uses pydantic.EmailStr (RFC 5322)
6. DOB Format: String YYYY-MM-DD (validation in controller)
7. Alias: User = UserInDB for backward compatibility

====================================================================
MONGODB INDEXES RECOMMENDED:
====================================================================

- email (unique)           → Fast login & lookup
- isActive (boolean)       → Filter active/inactive users
- isFirebaseAccount (boolean) → Filter by account type
- firebaseUid (string)     → Firebase user lookup
- lastLogin (descending)   → Recent login tracking
- createdAt (descending)   → Newest users

====================================================================
QUERY EXAMPLES:
====================================================================

# Find user by email (login)
db.users.find({ "email": "john@example.com" })

# Find active users
db.users.find({ "isActive": true })

# Find Firebase users
db.users.find({ "isFirebaseAccount": true })

# Find users by Firebase UID
db.users.find({ "firebaseUid": "abc123def456" })

# Update last login
db.users.updateOne(
    { "_id": ObjectId("67e3a1b2c3d4e5f6a7b8c9d0") },
    { "$set": { "lastLogin": new Date() } }
)

====================================================================
SECURITY CONSIDERATIONS:
====================================================================

1. Password Field: Never included in UserResponse
2. Password Hashing: Bcrypt before storage (in controller)
3. Email Verification: Field tracking verification status
4. Account Deactivation: isActive flag for soft delete
5. Firebase Accounts: No password login, marked with flag
6. Password Reset: Requires OTP verification first

====================================================================
USER TYPES:
====================================================================

This model represents RIDERS (end users) of the platform.
For PARTNERS (business owners), see server/partner/models/partner_model.py

| Type | Model Location | Purpose |
|------|---------------|---------|
| Rider | rider/models/user_model.py | End users who rent cars |
| Partner | partner/models/partner_model.py | Business owners who list cars |

====================================================================
"""

from typing import Optional
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

class UserBase(BaseModel):
    fullname: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    dob: str
    isActive: bool = True
    isEmailVerified: bool = False
    isFirebaseAccount: bool = False
    firebaseUid: Optional[str] = None
    firebasePicture: str = ""

class UserCreate(UserBase):
    password: str = Field(..., min_length=6)

class UserInDB(UserBase):
    id: str = Field(alias="_id")
    password: str
    lastLogin: datetime = Field(default_factory=datetime.utcnow)
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

class UserResponse(UserBase):
    id: str
    createdAt: datetime
    updatedAt: datetime

# ADD THIS LINE - Alias UserInDB as User for backward compatibility
User = UserInDB