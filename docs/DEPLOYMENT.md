# Production Deployment & Infrastructure Guide

This document outlines the production deployment architecture, container configuration, and cloud infrastructure setup for the **NeuroPlan** backend and data persistence layers.

---

## 🏗️ Architecture Overview

The production environment consists of:
- **Application Layer**: Asynchronous FastAPI service running under Uvicorn with multi-worker concurrency.
- **Persistence Layer**: Cloud-managed MySQL 8.4 instance configured with TLS 1.3 encryption and automated pooling.
- **Edge Layer**: SSL/TLS termination, reverse proxy, and CDN routing.
- **Client Deployment**: Cross-platform Flutter engine compiled for Android (APK), iOS, and Web (Wasm/CanvasKit).

---

## ⚙️ Environment Configuration

Set the following environment variables in your production environment (e.g., Render, Railway, AWS ECS, or Docker):

| Variable | Description | Example / Format |
| :--- | :--- | :--- |
| `DB_HOST` | Database host endpoint | `mysql-prod.internal.cloud.com` |
| `DB_PORT` | Database connection port | `3306` or `18217` |
| `DB_USER` | Authorized database user | `app_user` |
| `DB_PASSWORD` | Secure user password | `[Secret]` |
| `DB_NAME` | Primary database name | `ai_planner_db` |
| `DB_SSL` | Force SSL connection | `True` |
| `SECRET_KEY` | Cryptographic secret for JWT HMAC-SHA256 | `[Random 64-char hex string]` |
| `ALGORITHM` | JWT signing algorithm | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Session token lifespan | `10080` (7 days) |
| `AI_MODEL` | Machine learning inference engine ID | `llama-3.1-8b-instant` |

---

## 🚀 Cloud Deployment (Render / Containerized Web Service)

### 1. Build and Run Configuration
* **Runtime**: Python 3.10+
* **Build Command**: `pip install -r requirements.txt`
* **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
* **Root Directory**: `backend`

### 2. Database Migration & Schema Seeding
Before launching the service, execute the schema initialization:
```bash
python migrate.py
```
This verifies:
- Relational table definitions and foreign key constraints
- Auto-indexing on `(user_id, log_date)` for $O(\log n)$ temporal correlation queries
- Schema migrations for energy and mood indexing

---

## 📱 Mobile & Web Client Build

### Android Production Build:
```bash
cd frontend_app
flutter clean
flutter pub get
flutter build apk --release
```
The compiled APK will be generated at `frontend_app/build/app/outputs/flutter-apk/app-release.apk`.

### Web Client Production Build:
```bash
cd frontend_app
flutter build web --release --web-renderer canvaskit
```
Host the static assets inside `frontend_app/build/web` on Vercel, Netlify, or AWS S3/CloudFront.
