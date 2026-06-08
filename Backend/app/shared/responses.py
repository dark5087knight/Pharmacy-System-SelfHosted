from typing import Any, Optional, List, Dict
from pydantic import BaseModel

class ResponseMeta(BaseModel):
    page: Optional[int] = None
    per_page: Optional[int] = None
    total: Optional[int] = None
    total_pages: Optional[int] = None

class ErrorItem(BaseModel):
    code: str
    field: Optional[str] = None
    message: str

class ApiResponse(BaseModel):
    success: bool
    data: Optional[Any] = None
    meta: Optional[ResponseMeta] = None
    errors: Optional[List[ErrorItem]] = None

def success_response(data: Any = None, meta: Optional[ResponseMeta] = None) -> Dict[str, Any]:
    return {
        "success": True,
        "data": data,
        "meta": meta.model_dump(exclude_none=True) if meta else None,
        "errors": None
    }

def error_response(errors: List[ErrorItem] | List[Dict[str, Any]]) -> Dict[str, Any]:
    formatted_errors = []
    for err in errors:
        if isinstance(err, BaseModel):
            formatted_errors.append(err.model_dump(exclude_none=True))
        else:
            formatted_errors.append(err)
            
    return {
        "success": False,
        "data": None,
        "meta": None,
        "errors": formatted_errors
    }
