from backend.routers.auth import router as auth_router
from backend.routers.shops import router as shops_router
from backend.routers.customers import router as customers_router
from backend.routers.transactions import router as transactions_router
from backend.routers.scans import router as scans_router
from backend.routers.dashboard import router as dashboard_router
from backend.routers.reminders import router as reminders_router
from backend.routers.reports import router as reports_router
from backend.routers.debug import router as debug_router

__all__ = [
    "auth_router",
    "shops_router",
    "customers_router",
    "transactions_router",
    "scans_router",
    "dashboard_router",
    "reminders_router",
    "reports_router",
    "debug_router",
]
