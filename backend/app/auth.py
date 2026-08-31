import time

import boto3
import httpx
from fastapi import Depends, Header, HTTPException
from jose import jwt
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.models import User

_ISSUER = (
    f"https://cognito-idp.{settings.aws_region}.amazonaws.com/"
    f"{settings.cognito_user_pool_id}"
)
_JWKS_URL = f"{_ISSUER}/.well-known/jwks.json"
_JWKS_TTL_SECONDS = 3600

_jwks_cache: dict | None = None
_jwks_cached_at: float = 0.0


def _get_jwks() -> dict:
    global _jwks_cache, _jwks_cached_at
    if _jwks_cache is None or time.time() - _jwks_cached_at > _JWKS_TTL_SECONDS:
        response = httpx.get(_JWKS_URL, timeout=5)
        response.raise_for_status()
        _jwks_cache = response.json()
        _jwks_cached_at = time.time()
    return _jwks_cache


def _verify_access_token(token: str) -> dict:
    try:
        header = jwt.get_unverified_header(token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid token") from exc

    key = next((k for k in _get_jwks()["keys"] if k["kid"] == header.get("kid")), None)
    if key is None:
        raise HTTPException(status_code=401, detail="Invalid token key")

    try:
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            issuer=_ISSUER,
            # Access tokens carry `client_id`, not `aud` (that's an ID-token
            # thing) — checked manually below instead.
            options={"verify_aud": False},
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc

    if claims.get("token_use") != "access":
        raise HTTPException(status_code=401, detail="Not an access token")
    if claims.get("client_id") != settings.cognito_app_client_id:
        raise HTTPException(status_code=401, detail="Token not issued for this app")

    return claims


def get_current_user(
    authorization: str | None = Header(default=None), db: Session = Depends(get_db)
) -> User:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ")

    claims = _verify_access_token(token)
    sub = claims["sub"]

    user = db.query(User).filter_by(cognito_sub=sub).one_or_none()
    if user is not None:
        return user

    # First request we've seen from this identity — provision the local
    # user record. Email isn't on the access token, so fetch it once via
    # Cognito's GetUser API (authorized by the same access token).
    cognito_client = boto3.client("cognito-idp", region_name=settings.aws_region)
    attrs = cognito_client.get_user(AccessToken=token)["UserAttributes"]
    email = next(a["Value"] for a in attrs if a["Name"] == "email")

    user = User(cognito_sub=sub, email=email)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # A concurrent request for this same brand-new identity won the
        # race and already inserted the row (the app fires several
        # authenticated requests in parallel right after sign-in) - fall
        # back to reading what it created instead of erroring out.
        db.rollback()
        user = db.query(User).filter_by(cognito_sub=sub).one_or_none()
        if user is None:
            raise
        return user
    db.refresh(user)
    return user
