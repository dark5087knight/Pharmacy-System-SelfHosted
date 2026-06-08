# Aggregate all models here to register them with Base.metadata and facilitate clean imports
from app.shared.database import Base
from app.pharmacy.models import PharmacySettings, Branch
from app.staff.models import Permission, Role, UserRole, Staff
from app.inventory.models import MedicineCategory, Medicine, StockMovement
from app.customers.models import Customer
from app.prescriptions.models import Prescription, PrescriptionItem
from app.sales.models import Sale, SaleItem, Payment
from app.procurement.models import PurchaseOrder, PurchaseOrderItem
from app.suppliers.models import Supplier
from app.notifications.models import Notification
from app.audit.models import Activity, AuditLog
