"""
FILE: partnercar_model.py
PURPOSE: Partner car model schema for MongoDB - defines structure of partner cars
LOCATION: server/partner/models/partnercar_model.py
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from bson import ObjectId

class Location(BaseModel):
    lat: float
    lng: float

class Review(BaseModel):
    userId: str
    userName: str
    rating: float = Field(..., ge=1, le=5)
    comment: str
    createdAt: datetime = Field(default_factory=datetime.utcnow)

class Offer(BaseModel):
    discountPercentage: float = 0
    validUntil: Optional[datetime] = None

class PartnerCarBase(BaseModel):
    partnerId: str
    model: str
    registrationNumber: str
    type: str = Field(..., pattern='^(Car|Sports Car|Super Car|Electric)$')
    fuelType: str = Field(..., pattern='^(Petrol|Diesel|Electric|None|CNG)$')
    dailyRate: float = Field(..., gt=0)
    hourlyRate: Optional[float] = Field(None, gt=0)
    halfDayRate: Optional[float] = Field(None, gt=0)
    minRentalHours: int = Field(1, ge=1, le=24)
    maxRentalHours: int = Field(72, ge=1, le=720)
    status: str = Field("available", pattern='^(available|rented|maintenance)$')
    rating: float = 0
    reviewCount: int = 0
    location: Location
    description: str = ""
    reviews: List[Review] = []
    images: List[str] = []
    offer: Optional[Offer] = None
    features: List[str] = []
    isActive: bool = True

class PartnerCarCreate(PartnerCarBase):
    pass

class PartnerCarInDB(PartnerCarBase):
    id: str = Field(alias="_id")
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}

class PartnerCarResponse(PartnerCarBase):
    id: str
    createdAt: datetime
    updatedAt: datetime

   # Alias for backward compatibility
PartnerCar = PartnerCarInDB