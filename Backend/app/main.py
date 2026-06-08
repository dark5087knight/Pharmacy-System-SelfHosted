from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from sqlalchemy import text

from app.shared.database import engine
from app.shared.exceptions import PharmaException
from app.shared.responses import error_response
from app.config import settings

# Import all routers
from app.auth.router import router as auth_router
from app.staff.router import router as staff_router
from app.inventory.router import router as inventory_router
from app.suppliers.router import router as suppliers_router
from app.customers.router import router as customers_router
from app.prescriptions.router import router as prescriptions_router
from app.sales.router import router as sales_router
from app.procurement.router import router as procurement_router
from app.reports.router import router as reports_router
from app.notifications.router import router as notifications_router
from app.audit.router import router as audit_router
from app.pharmacy.router import router as pharmacy_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verify database connection on startup
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        print("Successfully connected to the PostgreSQL database.")
    except Exception as e:
        print(f"Database connection failed on startup: {e}")
    yield
    # Dispose connection pool on shutdown
    await engine.dispose()
    print("Database connections disposed.")

app = FastAPI(
    title="PharmaCloud Unified Backend API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8787",
        "http://127.0.0.1:8787",
        "http://localhost:8788",
        "http://127.0.0.1:8788",
    ],

    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(PharmaException)
async def pharma_exception_handler(request: Request, exc: PharmaException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.message}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)}
    )


# Register routers at root level for backward compatibility
app.include_router(auth_router)
app.include_router(staff_router)
app.include_router(inventory_router)
app.include_router(suppliers_router)
app.include_router(customers_router)
app.include_router(prescriptions_router)
app.include_router(sales_router)
app.include_router(procurement_router)
app.include_router(reports_router)
app.include_router(notifications_router)
app.include_router(audit_router)
app.include_router(pharmacy_router)

@app.get("/health")
async def health_check():
    return {"status": "ok"}
