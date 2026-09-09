# ⚡ NeuroPlan Quick Start Guide

This guide provides streamlined instructions for bootstrapping the **NeuroPlan** microservice backend, database persistence layer, and Flutter cross-platform client locally for development and evaluation.

---

## 📋 Prerequisites Checklist

Ensure the following environments are installed:
- **Python 3.10+**: [python.org](https://www.python.org/)
- **Flutter SDK 3.0+**: [flutter.dev](https://flutter.dev/)
- **MySQL 8.0+** (or XAMPP/Docker): [mysql.com](https://www.mysql.com/)
- **Git**: [git-scm.com](https://git-scm.com/)

---

## 🛠️ Step-by-Step Initialization

### Step 1: Database Provisioning

1. Start your local MySQL service (via XAMPP Control Panel, native service, or Docker).
2. Create and import the normalized relational schema:

```bash
# Log in to MySQL and provision the database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS ai_planner_db;"

# Import the Third Normal Form (3NF) relational tables
mysql -u root -p ai_planner_db < database_setup.sql
```

*(Alternatively, use phpMyAdmin: create `ai_planner_db` and import `database_setup.sql` via the Import tab).*

---

### Step 2: Backend Microservice Launch (FastAPI)

1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```

2. Create and activate a Python virtual environment:
   ```bash
   # Windows (PowerShell)
   python -m venv venv
   .\venv\Scripts\activate

   # macOS / Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install production dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Launch the asynchronous ASGI server:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

✅ **Verification**:
- API Health Status: [http://localhost:8000/](http://localhost:8000/)
- Interactive OpenAPI Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)

---

### Step 3: Flutter Cross-Platform Client Launch

1. In a new terminal, navigate to `frontend_app`:
   ```bash
   cd frontend_app
   ```

2. Retrieve Flutter packages:
   ```bash
   flutter pub get
   ```

3. Launch the application:
   ```bash
   # Web browser (Chrome)
   flutter run -d chrome

   # Connected Android / iOS device or emulator
   flutter run
   ```

---

## 🧪 Verification & Default Credentials

During development and testing, you can use the built-in test account:
- **Phone Number**: `+1234567890`
- **Password**: `Test@123`

To create a new account, use the **Sign Up** interface. The local development environment auto-displays verification tokens on-screen for seamless onboarding.
