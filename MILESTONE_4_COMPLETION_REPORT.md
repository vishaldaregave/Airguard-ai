# AIRGUARD AI — MILESTONE 4 COMPLETION REPORT
## Smart Environmental Alert & Notification Engine

**Repository:** `D:\Development\Airgaurd-ai`  
**Execution Timestamp:** November 2026  
**Status:** COMPLETE & VERIFIED  
**Git Commit Hash:** `5c53cb10fb8513158f6aafbf6aaf8fc53fa651af`  

---

### Executive Summary

Milestone 4 implements a deterministic, scientifically rigorous, location-aware environmental alert and notification engine for AIRGUARD AI. It monitors real-time environmental observations and calibrated short-term forecasts to protect user health without alarm fatigue, data hallucination, or false positives.

All backend components (FastAPI, SQLAlchemy, Pydantic v2, Google Firebase Cloud Messaging architecture) and frontend clients (Flutter Riverpod, Material 3 Dark theme, interactive threshold sliders, quiet hours configuration, and alert inbox) are fully operational and verified through automated test suites (71 backend pytest unit/integration tests and 13 Flutter widget/flow tests, 0 analyzer issues).

---

### 1. Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │    Station Observations / Forecast     │
                      └──────────────────┬─────────────────────┘
                                         │
                                         ▼
                 ┌──────────────────────────────────────────────────┐
                 │       Deterministic Alert Engine                 │
                 │ ──────────────────────────────────────────────── │
                 │ 1. Demo Fixture Exclusion (STRICT)               │
                 │ 2. Invalid CPCB AQI Suppression                  │
                 │ 3. Stale Data Rejection (>6h)                    │
                 │ 4. Threshold Triggers (AQI, PM2.5, PM10)         │
                 │ 5. Sudden Deterioration Detector (Spike)         │
                 │ 6. Validated Forecast Warning Horizon (+1h..+6h) │
                 │ 7. Quiet Hours Suppression Gate                  │
                 │ 8. State Tracker (Cooldown, Escalation, Recovery)│
                 └───────────────────────┬──────────────────────────┘
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
             ┌───────────────────────┐       ┌───────────────────────┐
             │ SQLite / DB History   │       │ Firebase FCM Service  │
             │ (AlertRecord Storage) │       │ (Live / MOCK Fallback)│
             └───────────────────────┘       └───────────┬───────────┘
                                                         │
                                                         ▼
                                             ┌───────────────────────┐
                                             │ Flutter Mobile Client │
                                             │ • Real-time Badge     │
                                             │ • Filterable Inbox    │
                                             │ • Detail Modal Sheet  │
                                             │ • Preferences Sliders │
                                             └───────────────────────┘
```

---

### 2. Scientific & Deterministic Alert Logic

The alert engine (`backend/app/engine/alert_engine.py`) strictly relies on deterministic domain rules. No LLM or generative hallucination determines whether an alert is triggered.

#### A. Environmental Guardrails & Suppression
1. **DEMO_FIXTURE Exclusion:** Observations flagged with `dataSourceType == 'DEMO_FIXTURE'` or `is_synthetic` are strictly rejected. No test fixtures can ever produce user-facing push alerts.
2. **Invalid CPCB AQI Calculation Suppression:** CPCB AQI calculation requires at least 3 valid pollutant sub-indices, with at least one being PM2.5 or PM10. If `status != VALID` or `overall_aqi is None`, official AQI alerts are strictly suppressed.
3. **Data Stale Check:** Telemetry older than 6 hours (`ALERT_STALE_DATA_HOURS = 6.0`) is rejected for real-time safety warnings, preventing obsolete pollution alerts.
4. **Distinction of Provenance:** Every alert carries `is_forecast: bool`, `horizon_hours: Optional[int]`, `trigger_reason`, and `source_provenance`. Forecasts are visibly and structurally separated from current observations. Only validated horizons (`+1h`, `+3h`, `+6h`) with `status == "ACTIVE"` and acceptable validation status produce warnings.

#### B. Thresholds & Spike Detection
- **CPCB AQI Alert:** Triggers if `overall_aqi >= user_pref.aqi_threshold` (Default: 200).
- **PM2.5 Alert:** Triggers if `pm25 >= user_pref.pm25_threshold` (Default: 60 µg/m³, CPCB 24h standard).
- **PM10 Alert:** Triggers if `pm10 >= user_pref.pm10_threshold` (Default: 100 µg/m³, CPCB 24h standard).
- **Sudden Deterioration (Spike):** Triggers if AQI rises by $\ge 40$ points or PM2.5 increases by $\ge 50\%$ within $\le 3$ hours relative to prior observations.

#### C. Smart State Management (De-duplication, Cooldown, Escalation, Recovery)
Managed per `(user_id, station_id, alert_type)` in `AlertStateTracker`:
- **Duplicate Suppression & Cooldown:** Default cooldown is 180 minutes. Identical conditions during cooldown are suppressed to eliminate notification spam.
- **Escalation Bypass:** If the environmental index worsens significantly during cooldown (AQI delta $\ge +50$ or severity escalates e.g. from `DANGER` to `CRITICAL`), the cooldown is immediately bypassed to deliver an escalation warning.
- **Hysteresis Recovery Notification:** When a monitored parameter was previously in an active alert state and subsequent verified observation drops safely below the threshold (with a 5% hysteresis safety margin), a recovery notification is generated and the tracker is cleared.
- **Quiet Hours Gate:** When `quiet_hours_enabled == True`, alerts occurring during the user's configured quiet window (e.g. 22:00 to 07:00) are flagged with `is_quiet_hours_suppressed = True`. They are recorded in the history log without sounding push notifications.

---

### 3. API Endpoints Specification

All endpoints are mounted under `/api/v1/alerts` and enforce tenant isolation via `X-User-ID` header (falling back to authenticated or default user):

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/alerts` | Paginated alert inbox list with optional filtering (`unread_only`, `severity`, `limit`, `offset`) |
| `GET` | `/api/v1/alerts/preferences` | Retrieve user notification thresholds, quiet hours, and station preferences |
| `PUT` | `/api/v1/alerts/preferences` | Update notification thresholds, toggles, quiet hours, and preferred station |
| `POST` | `/api/v1/alerts/device/register` | Register FCM push device token (`fcm_token`, `device_type`) |
| `DELETE` | `/api/v1/alerts/device/unregister` | Revoke/unregister FCM push token |
| `PATCH` | `/api/v1/alerts/{alert_id}/read` | Mark individual alert as read |
| `POST` | `/api/v1/alerts/evaluate` | Evaluates environmental observation against user preferences and triggers notifications |

---

### 4. Firebase Cloud Messaging (FCM) Integration

- **Security & Decoupling:** Server-side notification dispatching implemented in `backend/app/services/fcm_service.py`. No Firebase private service account keys or administrative credentials exist in client Flutter code or in git repository.
- **Graceful Mock Fallback:**
  - If `FIREBASE_CREDENTIALS_PATH` points to a valid Google Service Account JSON file, the engine initializes the official `firebase_admin` SDK and dispatches messages to APNs/FCM gateways.
  - If credentials are not provided in the environment, the service safely falls back to a mock delivery pipeline that logs structured delivery attempts, generates unique delivery IDs, and flags all responses with:
  ```json
  {
    "delivery_status": "MOCK_DELIVERED",
    "is_live_verified": false
  }
  ```
- **Live Verification Status:** **UNVERIFIED (Mock Delivery Active)**. As per strict instructions, no production server credentials were committed to source control or fabricated.

---

### 5. Flutter User Experience & Architecture

1. **State Management:** Fully integrated with Riverpod (`alertControllerProvider`, `AlertState`).
2. **Dashboard Integration:** Live notification bell in the top AppBar displaying dynamic unread badge with real-time count.
3. **Alert Inbox Screen (`alert_inbox_screen.dart`):**
   - Filter chips for `ALL`, `UNREAD`, `CRITICAL`, `DANGER`, `WARNING`.
   - Distinct visual badges for `OBSERVED` vs `FORECAST (+Nh)` warnings.
   - Severity-coded accent ribbons and cards (Dark Material 3 palette).
   - Tap-to-read updates and quick access to notification settings.
4. **Notification Settings Screen (`alert_preferences_screen.dart`):**
   - Interactive sliders for CPCB AQI (50–400), PM2.5 (20–250 µg/m³), and PM10 (40–350 µg/m³).
   - Behavior switches for Sudden Deterioration Warnings, Forecast-Based Warnings, and Recovery Notifications.
   - Quiet Hours selector with start and end hour dropdown selectors.
   - Location preference dropdown allowing binding alerts to specific regional stations or all nearby stations.
5. **Alert Detail Sheet (`alert_detail_sheet.dart`):**
   - Explains trigger provenance, observed metric vs user threshold, timestamp, and evidence-based non-clinical practical precautions.

---

### 6. Automated Verification & Quality Assurance

#### A. Backend Unit & Integration Tests (Pytest)
Command: `pytest backend/tests`
- **Result:** **71 passed in 11.21s**
- **Test Modules:**
  - `test_alert_engine.py`: AQI threshold trigger, PM2.5/PM10 triggers, CPCB validity enforcement, stale observation suppression, demo fixture rejection, duplicate cooldown suppression, escalation bypass, hysteresis recovery, quiet hours handling, and forecast horizon checks.
  - `test_alert_api.py`: Preference persistence & validation, device token registration/unregistration, alert inbox pagination, alert mark-as-read, user tenant isolation.
  - `test_cpcb_aqi.py`: CPCB deterministic standard validation.
  - `test_forecasting.py`: Autoregressive Ridge model validation.
  - `test_history_and_forecast_api.py`: Historical metrics & forecasts.
  - `test_pipeline_api.py` & `test_providers.py`: Data ingestion pipelines.
  - `test_quality.py`: Gas conversions and data hygiene.

#### B. Flutter Test Suite
Command: `flutter test`
- **Result:** **13 passed, 0 failures**
- **Test Modules:**
  - `test/alert_flow_test.dart`: Alert domain serialization, preference encoding/decoding, inbox filter chip rendering, detail bottom sheet, preference sliders and quiet hours.
  - `test/widget_test.dart`: Complete dashboard smoke test, forecasting cards, AI atmospheric explainer, and alert bell navigation.

#### C. Static Analysis
Command: `flutter analyze`
- **Result:** **0 issues found**

---

### 7. Constraints & Limitations

1. **FCM Live Gateway Verification:** The Firebase Cloud Messaging implementation includes the complete SDK initialization, token management, and error handling architecture. In the local development environment lacking external Google Cloud service credentials, it operates in authenticated mock mode with `is_live_verified: false`.
2. **Push Token Native Handshake:** Device tokens are mocked in widget testing and HTTP test clients; native iOS APNs and Android Google Play Services registration require signing and deployment on physical devices.

---

### 8. Milestone Conclusion & Git State

- **Milestone 4 Status:** COMPLETE & VERIFIED
- **Git Commit Hash:** `5c53cb10fb8513158f6aafbf6aaf8fc53fa651af`
- **Clean Test Status:** 71/71 Backend Pytest Passed, 13/13 Flutter Tests Passed, 0 Flutter Analyze Issues.
