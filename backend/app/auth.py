import bcrypt
import hashlib

def hash_password(password: str) -> str:
    # SHA-256 pre-hash bypasses bcrypt's 72-byte limit
    pre_hashed = hashlib.sha256(password.encode('utf-8')).hexdigest().encode('utf-8')
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(pre_hashed, salt).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    pre_hashed = hashlib.sha256(plain_password.encode('utf-8')).hexdigest().encode('utf-8')
    return bcrypt.checkpw(pre_hashed, hashed_password.encode('utf-8'))