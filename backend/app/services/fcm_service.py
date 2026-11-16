"""
AIRGUARD AI — Firebase Cloud Messaging (FCM) Service
Handles server-side notification dispatch with token lifecycle and mock fallback.

Strict Requirements:
- No Firebase server credentials in Flutter.
- No secrets committed to Git.
- When Firebase credentials/SDK are unavailable, uses mock delivery,
  explicitly recording delivery status as UNVERIFIED.
- Failure handling and retry logic for transient transport errors.
"""

from __future__ import annotations

import logging
import os
import time
from typing import Any, Dict, List, Optional
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)


class FCMDeliveryResult(BaseModel):
    """Result of an FCM delivery attempt."""
    success_count: int = 0
    failure_count: int = 0
    delivery_status: str  # "DELIVERED", "MOCK_DELIVERED", "FAILED", "NO_TOKENS"
    is_live_verified: bool = False
    details: List[Dict[str, Any]] = []
    error_message: Optional[str] = None


class FCMService:
    """
    Firebase Cloud Messaging Service.
    Supports real delivery when firebase-admin SDK + credentials are configured,
    and structured mock delivery with retry tracking when credentials are absent.
    """

    def __init__(self) -> None:
        self.credentials_path = settings.FIREBASE_CREDENTIALS_PATH
        self.project_id = settings.FIREBASE_PROJECT_ID
        self._initialized = False
        self._is_live = False
        self._initialize_sdk()

    def _initialize_sdk(self) -> None:
        """Attempt to initialize firebase-admin if installed and credentials exist."""
        if not self.credentials_path or not os.path.exists(self.credentials_path):
            logger.info(
                "FCM: Firebase credentials path not found or unset (%s). Operating in MOCK mode (UNVERIFIED).",
                self.credentials_path,
            )
            self._is_live = False
            return

        try:
            import firebase_admin
            from firebase_admin import credentials

            if not firebase_admin._apps:
                cred = credentials.Certificate(self.credentials_path)
                options = {"projectId": self.project_id} if self.project_id else None
                firebase_admin.initialize_app(cred, options=options)
            self._is_live = True
            self._initialized = True
            logger.info("FCM: Real Firebase Admin SDK successfully initialized.")
        except Exception as e:
            logger.warning(
                "FCM: Failed to initialize real Firebase Admin SDK: %s. Falling back to MOCK mode.",
                str(e),
            )
            self._is_live = False

    @property
    def is_live(self) -> bool:
        """Returns True if live Firebase delivery is verified and active."""
        return self._is_live

    def send_multicast(
        self,
        tokens: List[str],
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
        max_retries: int = 2,
    ) -> FCMDeliveryResult:
        """
        Send notification to multiple device tokens.
        Includes retry logic for transient errors and records delivery status.
        """
        if not tokens:
            return FCMDeliveryResult(
                success_count=0,
                failure_count=0,
                delivery_status="NO_TOKENS",
                is_live_verified=False,
                error_message="No active registration tokens found for user devices",
            )

        sanitized_data = {k: str(v) for k, v in (data or {}).items()}

        if self._is_live:
            return self._send_live_multicast(tokens, title, body, sanitized_data, max_retries)
        else:
            return self._send_mock_multicast(tokens, title, body, sanitized_data)

    def _send_live_multicast(
        self,
        tokens: List[str],
        title: str,
        body: str,
        data: Dict[str, str],
        max_retries: int,
    ) -> FCMDeliveryResult:
        """Send via firebase_admin multicast message with retry."""
        import firebase_admin.messaging as messaging

        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data,
            tokens=tokens,
        )

        last_error = None
        for attempt in range(max_retries + 1):
            try:
                response = messaging.send_multicast(message)
                details = []
                for idx, resp in enumerate(response.responses):
                    details.append({
                        "token": tokens[idx][:8] + "...",
                        "success": resp.success,
                        "message_id": resp.message_id if resp.success else None,
                        "error": str(resp.exception) if not resp.success else None,
                    })
                return FCMDeliveryResult(
                    success_count=response.success_count,
                    failure_count=response.failure_count,
                    delivery_status="DELIVERED" if response.success_count > 0 else "FAILED",
                    is_live_verified=True,
                    details=details,
                )
            except Exception as e:
                last_error = e
                logger.warning("FCM: Send attempt %d failed: %s", attempt + 1, str(e))
                if attempt < max_retries:
                    time.sleep(0.5 * (2**attempt))

        return FCMDeliveryResult(
            success_count=0,
            failure_count=len(tokens),
            delivery_status="FAILED",
            is_live_verified=True,
            error_message=f"Live FCM delivery failed after {max_retries + 1} attempts: {str(last_error)}",
        )

    def _send_mock_multicast(
        self,
        tokens: List[str],
        title: str,
        body: str,
        data: Dict[str, str],
    ) -> FCMDeliveryResult:
        """
        Mock multicast dispatch for environments without live Firebase credentials.
        Clearly marks delivery as UNVERIFIED to uphold scientific & operational honesty.
        """
        logger.info(
            "[MOCK FCM DISPATCH - UNVERIFIED DELIVERY] To %d devices | Title: '%s' | Body: '%s' | Data: %s",
            len(tokens),
            title,
            body,
            data,
        )
        details = [
            {
                "token": tok[:10] + "...",
                "success": True,
                "message_id": f"mock_msg_{int(time.time())}_{idx}",
                "mode": "MOCK_UNVERIFIED",
            }
            for idx, tok in enumerate(tokens)
        ]

        return FCMDeliveryResult(
            success_count=len(tokens),
            failure_count=0,
            delivery_status="MOCK_DELIVERED",
            is_live_verified=False,
            details=details,
            error_message="Live Firebase credentials not configured. Simulated mock dispatch.",
        )


# Global singleton instance
fcm_service = FCMService()
