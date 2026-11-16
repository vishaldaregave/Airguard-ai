"""
AIRGUARD AI — Authentication & Security Core
JWT-based user authentication, token verification, and strict tenant isolation.
Guarantees:
- Client-supplied user IDs are never trusted without cryptographic authentication.
- Cryptographic verification of JWT tokens.
- Immediate rejection of impersonation attempts (403 Forbidden).
- Rejection of missing, expired, or malformed tokens (401 Unauthorized).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, Optional
import jwt
from fastapi import Header, HTTPException, status

from app.core.config import settings

logger = logging.getLogger(__name__)


def create_access_token(
    user_id: str,
    custom_claims: Optional[Dict[str, Any]] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Generate a signed HMAC-SHA256 JWT access token for a given user identifier.
    """
    now = datetime.now(timezone.utc)
    delta = expires_delta or timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    expire = now + delta

    payload: Dict[str, Any] = {
        "sub": user_id,
        "user_id": user_id,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "iss": "airguard-ai-auth",
    }
    if custom_claims:
        payload.update(custom_claims)

    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def verify_jwt_token(token: str) -> Dict[str, Any]:
    """
    Cryptographically verify JWT token signature and expiration.
    Supports Firebase ID tokens if firebase-admin is available.
    """
    try:
        # 1. Standard HMAC-SHA256 decode
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require": ["exp", "iat", "sub"]},
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired. Please authenticate again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        # Check if Firebase verification is configured
        if settings.FIREBASE_CREDENTIALS_PATH:
            try:
                import firebase_admin.auth as fb_auth
                fb_payload = fb_auth.verify_id_token(token)
                return fb_payload
            except Exception:
                pass

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_authenticated_user(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    x_user_id: Optional[str] = Header(None, alias="X-User-ID"),
) -> str:
    """
    Derives authenticated user identity strictly on the backend.
    Never trusts client-supplied X-User-ID as proof of identity.
    Validates Bearer JWT token and verifies authorization.
    Rejects impersonation if X-User-ID conflicts with token identity.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required: Missing Authorization header. Bearer token required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    parts = authorization.strip().split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization header format. Expected 'Bearer <token>'.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = parts[1]
    payload = verify_jwt_token(token)
    authenticated_user = payload.get("sub") or payload.get("user_id") or payload.get("uid")

    if not authenticated_user or not str(authenticated_user).strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token payload does not contain a valid user identity.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    authenticated_user = str(authenticated_user).strip()

    # Impersonation Check: If client supplied an X-User-ID header, it MUST match the token
    if x_user_id and x_user_id.strip():
        claimed_user = x_user_id.strip()
        if claimed_user != authenticated_user:
            logger.warning(
                "SECURITY ALERT: User impersonation detected! Authenticated: '%s', Claimed X-User-ID: '%s'",
                authenticated_user,
                claimed_user,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: Identity mismatch. Authenticated as '{authenticated_user}' but requested X-User-ID was '{claimed_user}'. Impersonation is prohibited.",
            )

    return authenticated_user
