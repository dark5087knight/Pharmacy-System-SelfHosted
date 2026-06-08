import uuid

def to_uuid(id_str: str, prefix: str = "") -> uuid.UUID:
    """
    Convert string to UUID. If not a valid UUID, generate a deterministic 
    UUID based on the string and namespace prefix.
    """
    if not id_str:
        return uuid.uuid4()
    try:
        return uuid.UUID(id_str)
    except ValueError:
        # Generate a deterministic UUID based on the string and prefix
        namespace = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
        return uuid.uuid5(namespace, f"{prefix}:{id_str}")
