from typing import Optional

class PharmaException(Exception):
    """Base exception for all application-level errors."""
    def __init__(self, message: str, code: str, field: Optional[str] = None, status_code: int = 400):
        self.message = message
        self.code = code
        self.field = field
        self.status_code = status_code
        super().__init__(message)

class NotFoundException(PharmaException):
    def __init__(self, message: str, field: Optional[str] = None):
        super().__init__(message, code="NOT_FOUND", field=field, status_code=404)

class AuthException(PharmaException):
    def __init__(self, message: str, field: Optional[str] = None):
        super().__init__(message, code="UNAUTHORIZED", field=field, status_code=401)

class PermissionException(PharmaException):
    def __init__(self, message: str, field: Optional[str] = None):
        super().__init__(message, code="FORBIDDEN", field=field, status_code=403)

class ValidationException(PharmaException):
    def __init__(self, message: str, field: Optional[str] = None):
        super().__init__(message, code="VALIDATION_ERROR", field=field, status_code=400)

class PlanLimitException(PharmaException):
    def __init__(self, message: str, field: Optional[str] = None):
        super().__init__(message, code="PLAN_LIMIT_EXCEEDED", field=field, status_code=403)
