"""
====================================================================
FILE: server.py
LOCATION: server/server.py
PURPOSE: Main server entry point for carrzz application
====================================================================

OVERVIEW:
This is the main server file that initializes and configures the 
entire FastAPI application. It sets up MongoDB connection, Socket.IO
for real-time communication, CORS, routing, and middleware. This is
the central hub that ties together all components of the application.

====================================================================
CORE FEATURES:
====================================================================

1. 🚀 FASTAPI APPLICATION
   - Modern async web framework
   - Automatic OpenAPI documentation
   - Lifespan context manager for startup/shutdown

2. 📊 MONGODB CONNECTION
   - Async Motor driver
   - Connection pooling
   - Database state management

3. 🔌 SOCKET.IO (Real-time Communication)
   - WebSocket support with auto-reconnection
   - Partner authentication via JWT
   - Room-based messaging (partner_{id}, rider_{id})
   - Real-time car status updates
   - Live notifications

4. 🔐 AUTHENTICATION & MIDDLEWARE
   - CORS configuration
   - Request logging
   - Error handling (404, 500)
   - Health check endpoint

5. 📦 ROUTE INTEGRATION
   - Rider authentication routes
   - Partner routes
   - Order routes
   - Car routes

====================================================================
SERVER ARCHITECTURE:
====================================================================

┌─────────────────────────────────────────────────────────────────┐
│                         SERVER.PY                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  FastAPI Application                     │   │
│  │  ├── Lifespan Manager (startup/shutdown)                │   │
│  │  ├── CORS Middleware                                    │   │
│  │  ├── Request Logging Middleware                         │   │
│  │  ├── Error Handlers (404, 500)                          │   │
│  │  └── Root & Health Endpoints                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    MongoDB (Motor)                       │   │
│  │  ├── Connection String from environment                 │   │
│  │  ├── Connection Pool                                    │   │
│  │  └── Stored in app.state.db                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Socket.IO (WebSocket)                  │   │
│  │  ├── AsyncServer with CORS                              │   │
│  │  ├── Authentication via JWT (partner_join)              │   │
│  │  ├── Room Management (partner/ rider rooms)             │   │
│  │  ├── Real-time Events                                   │   │
│  │  └── ASGIApp mounted on /socket.io                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      ROUTES                              │   │
│  │  ├── /api          → Auth Routes (rider)                │   │
│  │  ├── /api/partner  → Partner Routes                     │   │
│  │  ├── /api          → Order Routes                       │   │
│  │  └── /api/cars     → Car Routes                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

====================================================================
SOCKET.IO EVENTS:
====================================================================

CLIENT → SERVER:
- connect             → Client connects
- partner_join        → Partner authenticates and joins room
- join_rider_room     → Rider joins their room
- disconnect          → Client disconnects

SERVER → CLIENT (Emitted by controllers):
- partner_joined      → Partner joined successfully
- car_status_updated  → Car status changed
- car_rented          → Car was rented
- car_hold_created    → Car hold created
- car_hold_released   → Car hold released
- car_booking_confirmed → Booking confirmed
- car_review_added    → New review added
- new_car_added       → New car listing added
- error               → Error message

====================================================================
SOCKET.IO ROOMS:
====================================================================

- partner_{partner_id}  → Partner-specific room
- rider_{rider_id}      → Rider-specific room

====================================================================
DEPENDENCIES:
====================================================================

Environment Variables Required:
- MONGODB_URI        → MongoDB connection string
- JWT_SECRET         → Secret for JWT tokens
- PORT               → Server port (default: 3000)
- NODE_ENV           → development/production
- EMAIL_USER         → Gmail email (for OTP)
- EMAIL_PASS         → Gmail app password (for OTP)

Python Packages:
- fastapi            → Web framework
- uvicorn            → ASGI server
- motor              → Async MongoDB driver
- socketio           → WebSocket/Real-time
- python-jose/jwt    → JWT handling
- python-dotenv      → Environment variables
- bson               → MongoDB ObjectId

====================================================================
MAIN APP INTEGRATION:
====================================================================

# Run the server
python server/server.py

# Or with uvicorn directly
uvicorn server.server:app --host 0.0.0.0 --port 3000 --reload

====================================================================
API ENDPOINTS:
====================================================================

ROOT ENDPOINTS:
- GET  /           → API information
- GET  /health     → Health check

AUTH ROUTES (/api):
- POST /signup
- POST /login
- POST /verify-token
- POST /auth/firebase
- POST /send-otp
- POST /verify-otp
- POST /reset-password-otp

PARTNER ROUTES (/api/partner):
- POST /register
- POST /login
- POST /auth/firebase
- GET  /dashboard
- POST /cars
- PUT  /cars/{id}
- DELETE /cars/{id}
- PUT  /cars/{id}/status

ORDER ROUTES (/api):
- POST /create-order
- GET  /rides/my-rides
- POST /check-availability
- POST /calculate-price
- POST /cars/hold
- GET  /cars/hold/{id}
- DELETE /cars/hold/{id}

CAR ROUTES (/api/cars):
- POST /reserve
- GET  /my-reservations
- DELETE /release-reservation/{id}

====================================================================
ERROR HANDLING:
====================================================================

- 404: Route not found (with custom response)
- 500: Internal server error (with stack trace in development)
- All errors return JSON with success: false

====================================================================
DEVELOPMENT NOTES:
====================================================================

1. MongoDB connection tested on startup
2. Socket.IO mounted AFTER initialization in lifespan
3. CORS allows all origins (configurable for production)
4. Request logging for all endpoints
5. Health check endpoint for monitoring
6. Environment variables loaded from .env file

====================================================================
PRODUCTION DEPLOYMENT:
====================================================================

# With environment variables
export MONGODB_URI="mongodb://..."
export JWT_SECRET="your-secret"
export PORT=3000
python server/server.py

# Or using Docker
docker build -t carrzz-server .
docker run -p 3000:3000 -e MONGODB_URI="..." carrzz-server

====================================================================
"""

import os
import sys
import asyncio
import logging
import jwt
import json
from datetime import datetime
from contextlib import asynccontextmanager

from dotenv import load_dotenv
load_dotenv()

DEFAULT_JWT_SECRET = "your_super_secret_jwt_key_change_this_in_production_123456789"
if not os.getenv("JWT_SECRET"):
    os.environ["JWT_SECRET"] = DEFAULT_JWT_SECRET

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
from motor.motor_asyncio import AsyncIOMotorClient
import socketio
from socketio import ASGIApp

# Import routes
from rider.routes.auth_routes import router as auth_router
from partner.routes.partner_routes import router as partner_router, set_io_for_partner
from partner.routes.order_routes import router as order_router
from partner.routes.car_routes import router as car_router

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global variables
db_client = None
db = None
sio = None
connected_partners = {}

# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_client, db, sio, connected_partners
    
    # Startup
    logger.info("Starting up...")
    
    # Connect to MongoDB
    mongodb_uri = os.getenv('MONGODB_URI')
    raw_db_name = os.getenv('DATABASE_NAME', '')
    database_name = raw_db_name.strip().strip("'").strip('"').strip() if raw_db_name else ''

    try:
        db_client = AsyncIOMotorClient(mongodb_uri)
        # If no explicit valid DATABASE_NAME is set, try to get from default database in URI or fallback to 'bikerzzz'
        if not database_name:
            try:
                default_db = db_client.get_default_database()
                if default_db is not None and default_db.name:
                    database_name = default_db.name.strip().strip("'").strip('"').strip()
            except Exception:
                pass

        if not database_name:
            database_name = 'bikerzzz'

        # Use sanitized environment variable for database name
        db = db_client[database_name]
        await db_client.admin.command('ping')
        logger.info(f"✅ MongoDB connected successfully to database: {database_name}")
    except Exception as e:
        logger.error(f"❌ MongoDB connection error: {str(e)}")
        sys.exit(1)
    
    # Initialize Socket.IO with optional Redis client manager for scaling
    redis_url = os.getenv("REDIS_URL")
    client_manager = None
    if redis_url:
        try:
            client_manager = socketio.AsyncRedisManager(redis_url)
            logger.info("✅ Redis client manager configured for Socket.IO scaling")
        except Exception as e:
            logger.warning(f"⚠️ Redis connection failed, falling back to in-memory manager: {e}")

    sio = socketio.AsyncServer(
        cors_allowed_origins="*",
        async_mode='asgi',
        client_manager=client_manager,
        logger=True,
        engineio_logger=True,
        ping_timeout=60,
        ping_interval=25
    )
    
    # Socket.IO authentication events - ALWAYS ACCEPT CONNECTIONS
    @sio.event
    async def connect(sid, environ, auth):
        """Handle connection - Always accept, authenticate via partner_join"""
        try:
            logger.info(f"🔌 New socket connection: {sid}")
            
            # Get token from query string for logging
            query_string = environ.get('QUERY_STRING', '')
            token = None
            
            if 'token=' in query_string:
                for param in query_string.split('&'):
                    if param.startswith('token='):
                        token = param.split('=')[1]
                        break
            
            if token:
                logger.info(f"🔑 Token received: {token[:20]}...")
                try:
                    secret = os.getenv('JWT_SECRET')
                    if secret:
                        decoded = jwt.decode(token, secret, algorithms=['HS256'])
                        logger.info(f"📝 Token decoded - role: {decoded.get('role')}, id: {decoded.get('id')}")
                except Exception as e:
                    logger.warning(f"⚠️ Token decode failed: {e}")
            else:
                logger.info(f"ℹ️ No token provided, will authenticate via partner_join")
            
            # ALWAYS ACCEPT - We'll authenticate via partner_join event
            return True
            
        except Exception as e:
            logger.error(f"❌ Socket connection error: {str(e)}")
            import traceback
            traceback.print_exc()
            return True
    
    @sio.event
    async def disconnect(sid):
        """Handle disconnection"""
        try:
            session = await sio.get_session(sid)
            partner_id = session.get('partner_id') if session else None
            
            if partner_id and partner_id in connected_partners:
                del connected_partners[partner_id]
                
            logger.info(f"🔌 Socket disconnected: {sid}, partner: {partner_id}")
        except Exception as e:
            logger.error(f"❌ Disconnect error: {str(e)}")
    
    @sio.event
    async def partner_join(sid, data):
        """Handle partner joining their room - Authenticate here"""
        try:
            logger.info(f"📡 Partner join request from {sid}: {data}")
            
            # Parse data if it's a string
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except json.JSONDecodeError:
                    data = {}
            
            token = data.get('token') if isinstance(data, dict) else None
            
            if not token:
                session = await sio.get_session(sid)
                token = session.get('token') if session else None
            
            if not token:
                logger.error(f"❌ No token provided for partner_join: {sid}")
                await sio.emit('error', {'message': 'No token provided'}, room=sid)
                return
            
            secret = os.getenv('JWT_SECRET')
            if not secret:
                logger.error(f"❌ JWT_SECRET not set")
                await sio.emit('error', {'message': 'Server configuration error'}, room=sid)
                return
            
            try:
                decoded = jwt.decode(token, secret, algorithms=['HS256'])
                role = decoded.get('role')
                partner_id = decoded.get('id')
                
                logger.info(f"📝 Decoded token - role: {role}, partner_id: {partner_id}")
                
                if role != 'partner':
                    logger.error(f"❌ Invalid role for socket: {role}")
                    await sio.emit('error', {'message': 'Invalid role'}, room=sid)
                    return
                
                if not partner_id:
                    logger.error(f"❌ No partner ID in token")
                    await sio.emit('error', {'message': 'No partner ID'}, room=sid)
                    return
                
                await sio.save_session(sid, {
                    'partner_id': partner_id,
                    'role': 'partner',
                    'token': token
                })
                
                connected_partners[partner_id] = sid
                
                room = f"partner_{partner_id}"
                sio.enter_room(sid, room)
                logger.info(f"✅ Partner {partner_id} joined room: {room}")
                
                await sio.emit('partner_joined', {
                    'status': 'success',
                    'room': room,
                    'partnerId': partner_id
                }, room=sid)
                
            except jwt.ExpiredSignatureError:
                logger.error(f"❌ Socket token expired: {sid}")
                await sio.emit('error', {'message': 'Token expired'}, room=sid)
            except jwt.InvalidTokenError as e:
                logger.error(f"❌ Socket invalid token: {sid} - {str(e)}")
                await sio.emit('error', {'message': f'Invalid token: {str(e)}'}, room=sid)
                
        except Exception as e:
            logger.error(f"❌ Error in partner_join: {str(e)}")
            await sio.emit('error', {'message': str(e)}, room=sid)
    
    @sio.event
    async def join_rider_room(sid, data):
        """Handle rider joining their room"""
        try:
            logger.info(f"📡 Rider join request from {sid}: {data}")
            
            # Parse data if it's a string
            if isinstance(data, str):
                try:
                    data = json.loads(data)
                except json.JSONDecodeError:
                    logger.warning(f"⚠️ Failed to parse join_rider_room data: {data}")
                    data = {}
            
            # Get user_id if data is a dict
            user_id = data.get('userId') if isinstance(data, dict) else None
            
            if user_id:
                sio.enter_room(sid, f"rider_{user_id}")
                logger.info(f"✅ Rider {user_id} joined their room")
            else:
                logger.warning(f"⚠️ No user_id in join_rider_room data from {sid}: {data}")
                
        except Exception as e:
            logger.error(f"❌ Error in join_rider_room: {str(e)}")
            import traceback
            traceback.print_exc()
    
    # Set IO instance for partner routes
    set_io_for_partner(sio)
    
    # Store in app state
    app.state.db = db
    app.state.db_client = db_client
    app.state.sio = sio
    app.state.connected_partners = connected_partners
    
    # =============================================
    # CRITICAL FIX: Mount Socket.IO app inside lifespan AFTER sio is initialized
    # =============================================
    socket_app = ASGIApp(sio, socketio_path="")
    app.mount("/socket.io", socket_app)
    logger.info("✅ Socket.IO mounted successfully on /socket.io")
    
    yield
    
    # Shutdown
    logger.info("Shutting down gracefully...")
    if db_client:
        db_client.close()
        logger.info("Database connection closed")

# Create FastAPI app
app = FastAPI(
    title="carrzz API Server",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"{datetime.now().isoformat()} - {request.method} {request.url.path}")
    response = await call_next(request)
    return response

# Include routes
app.include_router(auth_router, prefix="/api", tags=["Authentication"])
app.include_router(partner_router, prefix="/api/partner", tags=["Partner"])
app.include_router(order_router, prefix="/api", tags=["Orders"])
app.include_router(car_router, prefix="/api/cars", tags=["Cars"])

# Root route
@app.get("/")
async def root():
    return {
        "message": "carrzz API Server",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "POST /api/signup": "Register a new rider",
            "POST /api/login": "Login existing rider",
            "POST /api/verify-token": "Verify JWT token",
            "POST /api/auth/firebase": "Authenticate with Firebase token",
            "POST /api/send-otp": "Send OTP for email verification",
            "POST /api/verify-otp": "Verify OTP code",
            "POST /api/partner/register": "Register new partner",
            "POST /api/partner/login": "Partner login",
            "GET /api/partner/cars": "Get all cars",
            "POST /api/create-order": "Create a new order",
            "POST /api/cars/hold": "Create a 10-minute hold on a car",
            "GET /api/cars/hold/{car_id}": "Get hold status for a car",
            "DELETE /api/cars/hold/{car_id}": "Release a car hold"
        }
    }

# Health check endpoint
@app.get("/health")
async def health_check():
    db_status = "connected" if db_client else "disconnected"
    try:
        if db_client:
            await db_client.admin.command('ping')
            db_status = "connected"
    except:
        db_status = "disconnected"
    
    return {
        "status": "healthy",
        "uptime": None,
        "timestamp": datetime.now().isoformat(),
        "mongodb": db_status
    }

# 404 handler
@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=404,
        content={
            "success": False,
            "message": f"Route {request.method} {request.url.path} not found"
        }
    )

# Global error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "Internal server error",
            "error": str(exc) if os.getenv('NODE_ENV') == 'development' else None
        }
    )

if __name__ == "__main__":
    port = int(os.getenv('PORT', 3000))
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=port,
        reload=os.getenv('NODE_ENV') == 'development'
    )