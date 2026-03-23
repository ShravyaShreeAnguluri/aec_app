import secrets
from datetime import datetime, timedelta

def generate_reset_token():
    return secrets.token_urlsafe(32)

def reset_token_expiry(minutes: int = 15):
    return datetime.utcnow() + timedelta(minutes=minutes)
