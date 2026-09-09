from fastapi import FastAPI, Depends, HTTPException, status, Header, Body, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import Optional, List
from datetime import datetime, date, timedelta, time
import logging
import json

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from config import settings
from database import Database, get_db
from auth import (
    hash_password, verify_password, create_access_token, 
    decode_access_token, generate_verification_code, 
    get_verification_expiry, format_phone_number
)
from ai_service import ai_service
from voice_service import voice_service
from correlation_service import correlation_service
from insights_cache_service import insights_cache_service
from models import (
    TokenResponse, UserRegister, PhoneVerification, UserLogin,
    ChangePasswordRequest, UserUpdate, SupportRequest, TaskCreate, TaskUpdate,
    TaskResponse, HabitCreate, HabitUpdate, HabitResponse, HabitCompletion, MoodLog, MoodResponse,
    DailyReport, DashboardData, AIPrioritizeRequest, AIHabitSuggestionRequest, WhatsAppMessage,
    WebhookResponse, CorrelationInsight, CorrelationResponse, SmartInsightsResponse,
    GoalCreate, GoalUpdate, SubtaskCreate, SubtaskResponse, GoalResponse,
    BadHabitAppCreate, BadHabitAppUpdate, BadHabitAppResponse, UsageLogCreate, UsageLogResponse, MessageResponse
)

import asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="AI-Powered Daily Planner & Habit Tracker API"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# GZIP compression middleware (70-90% smaller responses!)
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
import os

app.add_middleware(GZipMiddleware, minimum_size=1000)

# Try to create local uploads directory, fallback to /tmp if read-only (like on Vercel)
try:
    UPLOAD_DIR = "uploads/profile_pictures"
    STATIC_DIR = "uploads"
    os.makedirs(UPLOAD_DIR, exist_ok=True)
except OSError:
    UPLOAD_DIR = "/tmp/uploads/profile_pictures"
    STATIC_DIR = "/tmp/uploads"
    os.makedirs(UPLOAD_DIR, exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


# ---------------------------------------------------------------------------
# Auto-migration: ensure start_date / start_time / end_date columns exist
# Runs once on every cold start; safe to re-run (idempotent).
# ---------------------------------------------------------------------------
def _run_auto_migration():
    """Add missing date columns to tasks and goals tables if they don't exist."""
    migration_steps = [
        ("tasks",  "start_date",  "ALTER TABLE tasks ADD COLUMN start_date DATE NULL AFTER due_date"),
        ("tasks",  "start_time",  "ALTER TABLE tasks ADD COLUMN start_time TIME NULL AFTER start_date"),
        ("tasks",  "end_date",    "ALTER TABLE tasks ADD COLUMN end_date DATE NULL AFTER start_time"),
        ("goals",  "start_date",  "ALTER TABLE goals ADD COLUMN start_date DATE NULL AFTER target_date"),
        ("goals",  "end_date",    "ALTER TABLE goals ADD COLUMN end_date DATE NULL AFTER start_date"),
    ]
    try:
        for table, column, ddl in migration_steps:
            try:
                Database.execute_query(ddl)
                logger.info(f"✅ Auto-migration: added {table}.{column}")
            except Exception as col_err:
                err_msg = str(col_err)
                if "Duplicate column name" in err_msg or "already exists" in err_msg:
                    logger.info(f"⚠ Auto-migration: {table}.{column} already exists — skipped")
                else:
                    logger.error(f"❌ Auto-migration failed for {table}.{column}: {col_err}")
        logger.info("✅ Auto-migration check complete")
    except Exception as e:
        logger.error(f"❌ Auto-migration error: {e}")

try:
    _run_auto_migration()
except Exception as e:
    logger.error(f"❌ Auto-migration could not run: {e}")


# Dependency to get current user from token
async def get_current_user(authorization: Optional[str] = Header(None)):
    """Extract and validate user from JWT token"""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing"
        )
    
    try:
        scheme, token = authorization.split()
        if scheme.lower() != 'bearer':
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication scheme"
            )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format"
        )
    
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    # Fetch user from database
    query = "SELECT * FROM users WHERE user_id = %s AND is_active = TRUE"
    users = Database.execute_query(query, (user_id,), fetch=True)
    
    if not users:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return users[0]

# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@app.post("/api/auth/register", response_model=TokenResponse)
async def register_user(user_data: UserRegister):
    """Register a new user and auto-login"""
    try:
        # Format phone number
        phone = format_phone_number(user_data.phone_number)
        
        # Check if user already exists
        check_query = "SELECT user_id FROM users WHERE phone_number = %s"
        existing = Database.execute_query(check_query, (phone,), fetch=True)
        
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        # Hash password
        password_hash = hash_password(user_data.password)
        
        # Insert user (Verified by default since we removed SMS verification)
        insert_query = """
            INSERT INTO users (phone_number, email, full_name, password_hash, 
                             phone_verified, verification_code, verification_expires)
            VALUES (%s, %s, %s, %s, TRUE, NULL, NULL)
        """
        user_id = Database.execute_query(
            insert_query,
            (phone, user_data.email, user_data.full_name, password_hash)
        )
        
        # Create access token
        token = create_access_token({"user_id": user_id})
        
        return TokenResponse(
            access_token=token,
            user_id=user_id,
            phone_number=phone,
            full_name=user_data.full_name
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

@app.post("/api/auth/verify-phone", response_model=TokenResponse)
async def verify_phone(verification: PhoneVerification):
    """Verify phone number with code"""
    try:
        phone = format_phone_number(verification.phone_number)
        
        # Get user
        query = """
            SELECT * FROM users 
            WHERE phone_number = %s AND verification_code = %s
            AND verification_expires > NOW()
        """
        users = Database.execute_query(query, (phone, verification.verification_code), fetch=True)
        
        if not users:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code"
            )
        
        user = users[0]
        
        # Update user as verified
        update_query = """
            UPDATE users 
            SET phone_verified = TRUE, verification_code = NULL, 
                verification_expires = NULL, last_login = NOW()
            WHERE user_id = %s
        """
        Database.execute_query(update_query, (user['user_id'],))
        
        # Create access token
        token = create_access_token({"user_id": user['user_id']})
        
        return TokenResponse(
            access_token=token,
            user_id=user['user_id'],
            phone_number=user['phone_number'],
            full_name=user['full_name'],
            profile_picture=user.get('profile_picture')
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Verification failed"
        )

@app.post("/api/auth/login", response_model=TokenResponse)
async def login_user(login_data: UserLogin):
    """Login user"""
    try:
        phone = format_phone_number(login_data.phone_number)
        
        # Get user
        query = "SELECT * FROM users WHERE phone_number = %s AND is_active = TRUE"
        users = Database.execute_query(query, (phone,), fetch=True)
        
        if not users:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        user = users[0]
        
        # Check if phone is verified
        if not user['phone_verified']:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Phone number not verified"
            )
        
        # Verify password
        if not verify_password(login_data.password, user['password_hash']):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # Update last login
        update_query = "UPDATE users SET last_login = NOW() WHERE user_id = %s"
        Database.execute_query(update_query, (user['user_id'],))
        
        # Create token
        token = create_access_token({"user_id": user['user_id']})
        
        return TokenResponse(
            access_token=token,
            user_id=user['user_id'],
            phone_number=user['phone_number'],
            full_name=user['full_name'],
            profile_picture=user.get('profile_picture')
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )

@app.put("/api/auth/profile", response_model=MessageResponse)
async def update_profile(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update user profile"""
    try:
        user_id = current_user['user_id']
        updates = []
        params = []
        
        if user_update.full_name:
            updates.append("full_name = %s")
            params.append(user_update.full_name)
            
        if user_update.email:
            updates.append("email = %s")
            params.append(user_update.email)
            
        if not updates:
            return MessageResponse(message="No changes provided")
            
        query = f"UPDATE users SET {', '.join(updates)} WHERE user_id = %s"
        params.append(user_id)
        
        Database.execute_query(query, tuple(params))
        
        return MessageResponse(message="Profile updated successfully")
        
    except Exception as e:
        logger.error(f"Profile update error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update profile"
        )

@app.post("/api/auth/profile-picture", response_model=MessageResponse)
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """Upload profile picture"""
    try:
        user_id = current_user['user_id']
        
        logger.info(f"Uploading profile picture. Content-Type: {file.content_type}, Filename: {file.filename}")

        # Verify file is an image
        if not file.content_type.startswith('image/'):
            logger.error(f"Invalid content type: {file.content_type}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File must be an image. Received: {file.content_type}"
            )
            
        # Create file path
        # Use simple extension derivation or default to .jpg
        ext = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
        filename = f"{user_id}_{int(datetime.now().timestamp())}.{ext}"
        file_path = f"{UPLOAD_DIR}/{filename}"
        
        # Save file
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
            
        # Create URL (assuming server runs on same host/port)
        # In production, this should be a full URL or relative path handled by frontend
        # For this setup: /static/profile_pictures/filename
        image_url = f"/static/profile_pictures/{filename}"
        
        # Update database
        query = "UPDATE users SET profile_picture = %s WHERE user_id = %s"
        Database.execute_query(query, (image_url, user_id))
        
        return MessageResponse(
            message="Profile picture uploaded successfully",
            data={"profile_picture": image_url}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Profile picture upload error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload profile picture"
        )



@app.post("/api/support", response_model=MessageResponse)
async def submit_support_request(
    request: SupportRequest,
    current_user: dict = Depends(get_current_user)
):
    """Submit a help & support request"""
    try:
        # Log the request
        logger.info(f"SUPPORT REQUEST from User {current_user['user_id']}:")
        logger.info(f"Subject: {request.subject}")
        logger.info(f"Message: {request.message}")
        logger.info(f"Contact Email: {request.email}")
        
        # Admin email to forward to
        admin_email = "maharabdulrehman5@gmail.com"
        
        # SIMULATE EMAIL SENDING (for now)
        # In a real production app, you would use:
        # 1. SMTP with a dedicated account (e.g., SendGrid, AWS SES, or Gmail App Password)
        # 2. Asynchronous background task (Celery/FastAPI BackgroundTasks) to avoid blocking
        
        email_content = f"""
        To: {admin_email}
        From: {request.email}
        Subject: Support Request: {request.subject}
        
        User ID: {current_user['user_id']} ({current_user.get('full_name', 'Unknown')})
        
        Message:
        {request.message}
        """
        
        logger.info("="*50)
        logger.info(f"📧 SENDING EMAIL TO {admin_email}...")
        logger.info(email_content)
        logger.info("="*50)
        
        # Code needed for ACTUAL sending (requires configuration):
        """
        import smtplib
        from email.mime.text import MIMEText
        
        sender_email = "your-app-email@gmail.com"
        sender_password = "your-app-password" 
        
        msg = MIMEText(request.message)
        msg['Subject'] = f"Support: {request.subject}"
        msg['From'] = sender_email
        msg['To'] = admin_email
        msg['Reply-To'] = request.email
        
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
            server.login(sender_email, sender_password)
            server.send_message(msg)
        """
        
        return MessageResponse(message="Support request submitted successfully")
    except Exception as e:
        logger.error(f"Support request error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to submit support request"
        )

@app.post("/api/auth/change-password", response_model=MessageResponse)
async def change_password(
    password_data: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):
    """Change user password"""
    try:
        # Verify old password
        if not verify_password(password_data.old_password, current_user['password_hash']):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect old password"
            )
        
        # Hash new password
        new_hash = hash_password(password_data.new_password)
        
        # Update password
        query = "UPDATE users SET password_hash = %s WHERE user_id = %s"
        Database.execute_query(query, (new_hash, current_user['user_id']))
        
        return MessageResponse(message="Password changed successfully")
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Password change error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to change password"
        )

@app.delete("/api/auth/account", response_model=MessageResponse)
async def delete_account(current_user: dict = Depends(get_current_user)):
    """Delete user account and all data"""
    try:
        # Delete user (cascading deletes handled by DB constraints if set, otherwise we might need manual cleanup)
        # Assuming DB foreign keys are set to ON DELETE CASCADE for all related tables
        query = "DELETE FROM users WHERE user_id = %s"
        Database.execute_query(query, (current_user['user_id'],))
        
        return MessageResponse(message="Account deleted successfully")
    
    except Exception as e:
        logger.error(f"Account deletion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete account"
        )

# ============================================================================
# TASK MANAGEMENT ENDPOINTS
# ============================================================================

@app.post("/api/tasks/create", response_model=TaskResponse)
async def create_task(task_data: TaskCreate, current_user: dict = Depends(get_current_user)):
    """Create a new task using the exact text the user provided — no AI rewriting"""
    logger.info(f"CREATING TASK: user_id={current_user['user_id']}, input={task_data.user_input}, manual_due={task_data.due_date}, manual_time={task_data.due_time}")
    try:
        # Use user's exact input as the title — no AI transformation
        if task_data.user_input and not task_data.title:
            title = task_data.user_input.strip()
            description = task_data.description  # None unless explicitly provided
            priority = task_data.priority or 'medium'
            category = task_data.category
            due_date = task_data.due_date
            due_time = task_data.due_time
            ai_generated = False
            ai_tags = []
            logger.info(f"TASK CREATED (no AI): title='{title}'")
        else:
            title = task_data.title
            description = task_data.description
            priority = task_data.priority or 'medium'
            category = task_data.category
            due_date = task_data.due_date
            due_time = task_data.due_time
            ai_generated = False
            ai_tags = []
        
        # Determine start/end dates — use provided values or fall back to due_date
        task_start_date = task_data.start_date
        task_start_time = task_data.start_time
        task_end_date = task_data.end_date
        # Keep due_date in sync with end_date for backward compatibility
        if task_end_date and not due_date:
            due_date = task_end_date
        
        # Insert task
        insert_query = """
            INSERT INTO tasks (user_id, title, description, original_input, priority, 
                             category, due_date, due_time, start_date, start_time, end_date,
                             ai_generated, ai_tags,
                             reminder_enabled, reminder_minutes_before)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        task_id = Database.execute_query(
            insert_query,
            (current_user['user_id'], title, description, task_data.user_input,
             priority, category, due_date, due_time,
             task_start_date, task_start_time, task_end_date,
             ai_generated, 
             json.dumps(ai_tags) if ai_tags else None,
             task_data.reminder_enabled, task_data.reminder_minutes_before)
        )
        
        # Fetch created task
        fetch_query = "SELECT * FROM tasks WHERE task_id = %s"
        task = Database.execute_query(fetch_query, (task_id,), fetch=True)[0]
        
        # Convert due_time and start_time from timedelta to time if needed
        if task.get('due_time') and isinstance(task['due_time'], timedelta):
            total_seconds = int(task['due_time'].total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            task['due_time'] = time(hour=hours, minute=minutes)
        if task.get('start_time') and isinstance(task['start_time'], timedelta):
            total_seconds = int(task['start_time'].total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            task['start_time'] = time(hour=hours, minute=minutes)
        
        return TaskResponse(**task)
    
    except Exception as e:
        logger.error(f"Task creation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create task"
        )

@app.post("/api/tasks/parse-preview")
async def parse_task_preview(
    user_input: str = Body(..., embed=True),
    current_user: dict = Depends(get_current_user)
):
    """Parse natural language input and return structured task data (preview only, doesn't create task)"""
    try:
        ai_result = await ai_service.parse_task_from_text(user_input)
        
        return {
            "title": ai_result.get('title'),
            "description": ai_result.get('description'),
            "priority": ai_result.get('priority', 'medium'),
            "category": ai_result.get('category'),
            "due_date": ai_result.get('due_date'),
            "due_time": ai_result.get('due_time'),
            "tags": ai_result.get('tags', []),
            "confidence": ai_result.get('confidence', 'high')
        }
    except Exception as e:
        logger.error(f"Task parsing preview error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to parse task input"
        )


@app.get("/api/tasks/list", response_model=List[TaskResponse])
async def list_tasks(
    status: Optional[str] = None,
    category: Optional[str] = None,
    date: Optional[str] = None,  # Filter by date (YYYY-MM-DD) — shows tasks for that specific day
    current_user: dict = Depends(get_current_user)
):
    """Get user's tasks with optional filters. When 'date' is provided, returns tasks for that date."""
    try:
        query = "SELECT * FROM tasks WHERE user_id = %s"
        params = [current_user['user_id']]
        
        if status:
            query += " AND status = %s"
            params.append(status)
        
        if category:
            query += " AND category = %s"
            params.append(category)
        
        if date:
            # Show tasks that start on this date.
            # Also include old tasks (before migration) that have due_date on this date.
            query += " AND (start_date = %s OR (start_date IS NULL AND due_date = %s))"
            params.append(date)
            params.append(date)
        
        query += " ORDER BY due_date ASC, ai_priority_score DESC"
        
        tasks = Database.execute_query(query, tuple(params), fetch=True)
        
        # Convert due_time and start_time from timedelta to time for all tasks
        for task in tasks:
            if task.get('due_time') and isinstance(task['due_time'], timedelta):
                total_seconds = int(task['due_time'].total_seconds())
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                task['due_time'] = time(hour=hours, minute=minutes)
            if task.get('start_time') and isinstance(task['start_time'], timedelta):
                total_seconds = int(task['start_time'].total_seconds())
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                task['start_time'] = time(hour=hours, minute=minutes)
        
        return [TaskResponse(**task) for task in tasks]
    
    except Exception as e:
        logger.error(f"Task list error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to fetch tasks"
        )

@app.get("/api/tasks/suggestions")
async def get_task_suggestions(current_user: dict = Depends(get_current_user)):
    """Get AI-powered task suggestions for the day"""
    try:
        # Fetch pending tasks
        query = "SELECT * FROM tasks WHERE user_id = %s AND status = 'pending' ORDER BY created_at DESC"
        tasks = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        if not tasks:
            return {"suggestions": []}
        
        # Determine time of day
        hour = datetime.now().hour
        if hour < 12:
            time_of_day = "morning"
        elif hour < 18:
            time_of_day = "afternoon"
        else:
            time_of_day = "evening"
        
        # Get AI suggestions
        suggestions = await ai_service.suggest_daily_tasks(tasks, time_of_day)
        
        return {"suggestions": suggestions, "time_of_day": time_of_day}
    
    except Exception as e:
        logger.error(f"Task suggestions error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate task suggestions"
        )

@app.put("/api/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    task_update: TaskUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update a task"""
    try:
        # Build update query dynamically
        updates = []
        params = []
        
        if task_update.title is not None:
            updates.append("title = %s")
            params.append(task_update.title)
        if task_update.description is not None:
            updates.append("description = %s")
            params.append(task_update.description)
        if task_update.priority is not None:
            updates.append("priority = %s")
            params.append(task_update.priority)
        if task_update.status is not None:
            updates.append("status = %s")
            params.append(task_update.status)
            if task_update.status == 'completed':
                updates.append("completed_at = NOW()")
        if task_update.category is not None:
            updates.append("category = %s")
            params.append(task_update.category)
        if task_update.due_date is not None:
            updates.append("due_date = %s")
            params.append(task_update.due_date)
        if task_update.due_time is not None:
            updates.append("due_time = %s")
            params.append(task_update.due_time)
        if task_update.start_date is not None:
            updates.append("start_date = %s")
            params.append(task_update.start_date)
        if task_update.start_time is not None:
            updates.append("start_time = %s")
            params.append(task_update.start_time)
        if task_update.end_date is not None:
            updates.append("end_date = %s")
            params.append(task_update.end_date)
            # Keep due_date in sync with end_date
            updates.append("due_date = %s")
            params.append(task_update.end_date)
        
        if not updates:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update"
            )
        
        params.extend([task_id, current_user['user_id']])
        
        update_query = f"""
            UPDATE tasks 
            SET {', '.join(updates)}
            WHERE task_id = %s AND user_id = %s
        """
        
        Database.execute_query(update_query, tuple(params))
        
        # Fetch updated task
        fetch_query = "SELECT * FROM tasks WHERE task_id = %s"
        task = Database.execute_query(fetch_query, (task_id,), fetch=True)
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Task not found"
            )
        
        # Convert due_time and start_time from timedelta to time if needed
        task_data = task[0]
        if task_data.get('due_time') and isinstance(task_data['due_time'], timedelta):
            total_seconds = int(task_data['due_time'].total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            task_data['due_time'] = time(hour=hours, minute=minutes)
        if task_data.get('start_time') and isinstance(task_data['start_time'], timedelta):
            total_seconds = int(task_data['start_time'].total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            task_data['start_time'] = time(hour=hours, minute=minutes)
        
        return TaskResponse(**task_data)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Task update error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update task"
        )

@app.delete("/api/tasks/{task_id}", response_model=MessageResponse)
async def delete_task(task_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a task"""
    try:
        query = "DELETE FROM tasks WHERE task_id = %s AND user_id = %s"
        Database.execute_query(query, (task_id, current_user['user_id']))
        
        return MessageResponse(message="Task deleted successfully")
    
    except Exception as e:
        logger.error(f"Task deletion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete task"
        )

@app.post("/api/tasks/ai-organize", response_model=List[TaskResponse])
async def ai_organize_tasks(
    request: AIPrioritizeRequest,
    current_user: dict = Depends(get_current_user)
):
    """Use AI to prioritize and organize tasks"""
    try:
        # Get tasks to prioritize
        if request.task_ids:
            placeholders = ','.join(['%s'] * len(request.task_ids))
            query = f"""
                SELECT * FROM tasks 
                WHERE task_id IN ({placeholders}) AND user_id = %s AND status = 'pending'
            """
            params = request.task_ids + [current_user['user_id']]
        else:
            query = "SELECT * FROM tasks WHERE user_id = %s AND status = 'pending'"
            params = [current_user['user_id']]
        
        tasks = Database.execute_query(query, tuple(params), fetch=True)
        
        if not tasks:
            return []
        
        # Use AI to prioritize
        prioritized_tasks = await ai_service.prioritize_tasks(tasks)
        
        # Update AI priority scores in database
        for task in prioritized_tasks:
            update_query = """
                UPDATE tasks SET ai_priority_score = %s WHERE task_id = %s
            """
            Database.execute_query(
                update_query,
                (task.get('ai_priority_score', 50), task['task_id'])
            )
        
        return [TaskResponse(**task) for task in prioritized_tasks]
    
    except Exception as e:
        logger.error(f"AI organize error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to organize tasks"
        )

# ============================================================================
# HABIT TRACKING ENDPOINTS
# ============================================================================

@app.post("/api/habits/create", response_model=HabitResponse)
async def create_habit(
    habit_data: HabitCreate,
    current_user: dict = Depends(get_current_user)
):
    """Create a new habit using the exact name the user typed — no AI rewriting"""
    try:
        # Always use the user's exact input — no AI name/description modification
        name = habit_data.name.strip()
        description = habit_data.description
        category = habit_data.category
        frequency_details = habit_data.frequency_details
        icon = '⭐'
        color = '#4CAF50'
        ai_suggested = False
        logger.info(f"HABIT CREATED (no AI): name='{name}'")
        
        # Insert habit
        insert_query = """
            INSERT INTO habits (user_id, name, description, category, frequency,
                              frequency_details, target_count, reminder_time, 
                              icon, color, ai_suggested)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        habit_id = Database.execute_query(
            insert_query,
            (current_user['user_id'], name, description, category,
             habit_data.frequency, json.dumps(frequency_details) if frequency_details else None,
             habit_data.target_count, habit_data.reminder_time, icon, color, ai_suggested)
        )
        
        # Fetch created habit
        fetch_query = "SELECT * FROM habits WHERE habit_id = %s"
        habit = Database.execute_query(fetch_query, (habit_id,), fetch=True)[0]
        
        # Convert timedelta to time for reminder_time
        if habit.get('reminder_time') and isinstance(habit['reminder_time'], timedelta):
            total_seconds = int(habit['reminder_time'].total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            seconds = total_seconds % 60
            habit['reminder_time'] = time(hours, minutes, seconds)
        
        return HabitResponse(**habit)
    
    except Exception as e:
        logger.error(f"Habit creation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create habit"
        )

@app.get("/api/habits/list", response_model=List[HabitResponse])
async def list_habits(current_user: dict = Depends(get_current_user)):
    """Get user's habits with today's completion status"""
    try:
        query = """
            SELECT 
                h.*,
                CASE 
                    WHEN hc.completion_date = CURDATE() THEN TRUE 
                    ELSE FALSE 
                END as completed_today
            FROM habits h
            LEFT JOIN habit_completions hc 
                ON h.habit_id = hc.habit_id 
                AND hc.completion_date = CURDATE()
                AND hc.user_id = h.user_id
            WHERE h.user_id = %s AND h.is_active = TRUE
            ORDER BY h.created_at DESC
        """
        habits = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        # Convert timedelta to time for reminder_time
        for habit in habits:
            if habit.get('reminder_time') and isinstance(habit['reminder_time'], timedelta):
                total_seconds = int(habit['reminder_time'].total_seconds())
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                seconds = total_seconds % 60
                habit['reminder_time'] = time(hours, minutes, seconds)
        
        return [HabitResponse(**habit) for habit in habits]
    
    except Exception as e:
        logger.error(f"Habit list error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch habits"
        )

@app.post("/api/habits/complete", response_model=MessageResponse)
async def complete_habit(
    completion: HabitCompletion,
    current_user: dict = Depends(get_current_user)
):
    """Mark a habit as completed for a date"""
    try:
        completion_date = completion.completion_date or date.today()
        
        # Convert mood integer to enum string
        mood_enum = None
        if completion.mood_at_completion:
            mood_map = {
                1: 'very_bad',
                2: 'bad',
                3: 'neutral',
                4: 'good',
                5: 'very_good'
            }
            mood_enum = mood_map.get(completion.mood_at_completion)
        
        # Insert completion
        insert_query = """
            INSERT INTO habit_completions (habit_id, user_id, completion_date, 
                                          completion_time, notes, mood_at_completion, energy_level)
            VALUES (%s, %s, %s, NOW(), %s, %s, %s)
            ON DUPLICATE KEY UPDATE 
                completion_time = NOW(), notes = %s, mood_at_completion = %s, energy_level = %s
        """
        Database.execute_query(
            insert_query,
            (completion.habit_id, current_user['user_id'], completion_date,
             completion.notes, mood_enum, completion.energy_level,
             completion.notes, mood_enum, completion.energy_level)
        )
        
        
        # Update habit statistics
        # Calculate current streak
        streak_query = """
            SELECT completion_date FROM habit_completions
            WHERE habit_id = %s AND user_id = %s
            ORDER BY completion_date DESC
            LIMIT 100
        """
        completions = Database.execute_query(
            streak_query,
            (completion.habit_id, current_user['user_id']),
            fetch=True
        )
        
        current_streak = 0
        if completions:
            current_date = date.today()
            for comp in completions:
                if comp['completion_date'] == current_date or comp['completion_date'] == current_date - timedelta(days=current_streak):
                    current_streak += 1
                    current_date = comp['completion_date']
                else:
                    break
        
        # Also create a mood log entry if mood was provided
        if completion.mood_at_completion and mood_enum:
            try:
                mood_log_query = """
                    INSERT INTO mood_logs (user_id, log_date, log_time, mood_level, 
                                         energy_level, notes, activities)
                    VALUES (%s, %s, NOW(), %s, %s, %s, NULL)
                    ON DUPLICATE KEY UPDATE
                        log_time = NOW(), mood_level = %s, energy_level = %s, 
                        notes = CONCAT(COALESCE(notes, ''), ' | ', %s)
                """
                mood_notes = f"Logged during habit completion: {completion.notes or 'No notes'}"
                Database.execute_query(
                    mood_log_query,
                    (current_user['user_id'], completion_date, mood_enum, 
                     completion.energy_level or 3, mood_notes,
                     mood_enum, completion.energy_level or 3, mood_notes)
                )
                logger.info(f"Mood log created for user {current_user['user_id']} during habit completion")
                
                # Invalidate insights cache so new mood appears immediately
                logger.info(f"🔍 About to invalidate cache for user {current_user['user_id']}")
                try:
                    await insights_cache_service.invalidate_cache(current_user['user_id'])
                    logger.info(f"✅ Invalidated insights cache for user {current_user['user_id']} after habit mood log")
                except Exception as cache_error:
                    logger.error(f"❌ Error invalidating cache: {cache_error}")
                    import traceback
                    logger.error(traceback.format_exc())
                    
            except Exception as e:
                # Don't fail habit completion if mood logging fails
                logger.error(f"Error creating mood log during habit completion: {e}")
        
        # Update habit
        update_query = """
            UPDATE habits 
            SET current_streak = %s,
                longest_streak = GREATEST(longest_streak, %s),
                total_completions = total_completions + 1
            WHERE habit_id = %s
        """
        Database.execute_query(
            update_query,
            (current_streak, current_streak, completion.habit_id)
        )
        
        # Invalidate insights cache (if not already done during mood logging)
        if not (completion.mood_at_completion and mood_enum):
            try:
                await insights_cache_service.invalidate_cache(current_user['user_id'])
                logger.info(f"Invalidated insights cache for user {current_user['user_id']} after habit completion")
            except Exception as cache_error:
                logger.error(f"Error invalidating cache: {cache_error}")
        
        return MessageResponse(
            message="Habit completed successfully",
            data={"current_streak": current_streak}
        )
    
    except Exception as e:
        logger.error(f"Habit completion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to complete habit"
        )

@app.get("/api/habits/streaks", response_model=List[dict])
async def get_habit_streaks(current_user: dict = Depends(get_current_user)):
    """Get all habit streaks"""
    try:
        query = """
            SELECT habit_id, name, current_streak, longest_streak, total_completions
            FROM habits
            WHERE user_id = %s AND is_active = TRUE
            ORDER BY current_streak DESC
        """
        streaks = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        return streaks
    
    except Exception as e:
        logger.error(f"Streaks fetch error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch streaks"
        )

@app.put("/api/habits/{habit_id}", response_model=HabitResponse)
async def update_habit(
    habit_id: int,
    habit_update: HabitUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update a habit"""
    try:
        # Build update query dynamically
        updates = []
        params = []
        
        if habit_update.name is not None:
            updates.append("name = %s")
            params.append(habit_update.name)
        if habit_update.description is not None:
            updates.append("description = %s")
            params.append(habit_update.description)
        if habit_update.category is not None:
            updates.append("category = %s")
            params.append(habit_update.category)
        if habit_update.frequency is not None:
            updates.append("frequency = %s")
            params.append(habit_update.frequency.value)
        if habit_update.frequency_details is not None:
            updates.append("frequency_details = %s")
            params.append(json.dumps(habit_update.frequency_details))
        if habit_update.target_count is not None:
            updates.append("target_count = %s")
            params.append(habit_update.target_count)
        if habit_update.reminder_enabled is not None:
            updates.append("reminder_enabled = %s")
            params.append(habit_update.reminder_enabled)
        if habit_update.reminder_time is not None:
            updates.append("reminder_time = %s")
            params.append(habit_update.reminder_time)
            
        if not updates:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update"
            )
            
        params.extend([habit_id, current_user['user_id']])
        
        update_query = f"""
            UPDATE habits 
            SET {', '.join(updates)}
            WHERE habit_id = %s AND user_id = %s
        """
        
        Database.execute_query(update_query, tuple(params))
        
        # Fetch updated habit
        fetch_query = "SELECT * FROM habits WHERE habit_id = %s AND user_id = %s"
        habit = Database.execute_query(fetch_query, (habit_id, current_user['user_id']), fetch=True)
        
        if not habit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Habit not found"
            )
            
        return HabitResponse(**habit[0])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Habit update error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update habit"
        )

@app.delete("/api/habits/{habit_id}", response_model=MessageResponse)
async def delete_habit(habit_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a habit and all its completion history"""
    try:
        # Delete habit (completions will be cascade deleted due to foreign key)
        query = "DELETE FROM habits WHERE habit_id = %s AND user_id = %s"
        Database.execute_query(query, (habit_id, current_user['user_id']))
        
        return MessageResponse(message="Habit deleted successfully")
    
    except Exception as e:
        logger.error(f"Habit deletion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete habit"
        )


# ============================================================================
# MOOD & ENERGY TRACKING
# ============================================================================

@app.post("/api/mood/log", response_model=MoodResponse)
async def log_mood(mood_data: MoodLog, current_user: dict = Depends(get_current_user)):
    """Log mood and energy level"""
    try:
        today = date.today()
        
        # Convert mood_level from int (1-5) to enum string
        mood_map = {
            1: 'very_bad',
            2: 'bad',
            3: 'neutral',
            4: 'good',
            5: 'very_good'
        }
        mood_level_str = mood_map.get(mood_data.mood_level, 'neutral')
        
        # Insert or update mood log
        insert_query = """
            INSERT INTO mood_logs (user_id, log_date, log_time, mood_level, 
                                 energy_level, notes, activities)
            VALUES (%s, %s, NOW(), %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                log_time = NOW(), mood_level = %s, energy_level = %s, 
                notes = %s, activities = %s
        """
        Database.execute_query(
            insert_query,
            (current_user['user_id'], today, mood_level_str, mood_data.energy_level,
             mood_data.notes, json.dumps(mood_data.activities) if mood_data.activities else None,
             mood_level_str, mood_data.energy_level, mood_data.notes,
             json.dumps(mood_data.activities) if mood_data.activities else None)
        )
        
        # Fetch the log
        fetch_query = """
            SELECT * FROM mood_logs 
            WHERE user_id = %s AND log_date = %s
        """
        mood = Database.execute_query(fetch_query, (current_user['user_id'], today), fetch=True)[0]
        
        # Convert mood_level to int if it's a string (for backwards compatibility)
        if isinstance(mood['mood_level'], str):
            mood_map = {'very_bad': 1, 'bad': 2, 'neutral': 3, 'good': 4, 'very_good': 5}
            mood['mood_level'] = mood_map.get(mood['mood_level'], 3)
        
        # Invalidate insights cache so new mood appears immediately
        logger.info(f"🔍 About to invalidate cache for user {current_user['user_id']} after mood log")
        try:
            await insights_cache_service.invalidate_cache(current_user['user_id'])
            logger.info(f"✅ Invalidated insights cache for user {current_user['user_id']} after mood log")
        except Exception as cache_error:
            logger.error(f"❌ Error invalidating cache: {cache_error}")
            import traceback
            logger.error(traceback.format_exc())
        
        return MoodResponse(**mood)
    
    except Exception as e:
        logger.error(f"Mood log error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to log mood"
        )

@app.get("/api/mood/insights", response_model=dict)
async def get_mood_insights(current_user: dict = Depends(get_current_user)):
    """Get AI-powered mood insights"""
    try:
        # Get last 30 days of mood logs
        query = """
            SELECT * FROM mood_logs
            WHERE user_id = %s
            ORDER BY log_date DESC
            LIMIT 30
        """
        mood_logs = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        if not mood_logs:
            return {"message": "Start logging your mood to get insights!"}
        
        # Use AI to analyze patterns
        insights = await ai_service.analyze_mood_patterns(mood_logs)
        
        if not insights or not isinstance(insights, dict):
            return {"insight": "Keep logging your mood to unlock deeper insights!"}
        
        return insights

    
    except Exception as e:
        logger.error(f"Mood insights error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate insights"
        )

@app.get("/api/mood/list", response_model=List[dict])
async def get_mood_logs(current_user: dict = Depends(get_current_user)):
    """Get user's mood log history"""
    try:
        query = """
            SELECT * FROM mood_logs
            WHERE user_id = %s
            ORDER BY log_date DESC, log_time DESC
            LIMIT 30
        """
        mood_logs = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        # Process logs to ensure mood_level is int
        mood_map = {'very_bad': 1, 'bad': 2, 'neutral': 3, 'good': 4, 'very_good': 5}
        for log in mood_logs:
            if isinstance(log.get('mood_level'), str):
                log['mood_level'] = mood_map.get(log['mood_level'], 3)
                
        return mood_logs
    
    except Exception as e:
        logger.error(f"Mood logs fetch error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch mood logs"
        )


@app.delete("/api/mood/{mood_id}", response_model=MessageResponse)
async def delete_mood_log(mood_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a mood log entry"""
    try:
        query = "DELETE FROM mood_logs WHERE mood_id = %s AND user_id = %s"
        Database.execute_query(query, (mood_id, current_user['user_id']))
        
        # Invalidate cache so insights are rebuilt next time
        try:
            await insights_cache_service.invalidate_cache(current_user['user_id'])
            logger.info(f"✅ Invalidated insights cache for user {current_user['user_id']} after mood deletion")
        except Exception as cache_error:
            logger.error(f"❌ Error invalidating cache: {cache_error}")
        
        return MessageResponse(message="Mood log deleted successfully")
    
    except Exception as e:
        logger.error(f"Mood log deletion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete mood log"
        )


# ============================================================================
# GOALS & AI FEATURES
# ============================================================================

@app.post("/api/goals/create", response_model=GoalResponse)
async def create_goal(goal_data: GoalCreate, current_user: dict = Depends(get_current_user)):
    """Create a goal with AI decomposition"""
    try:
        # Use AI to correct spelling if AI decomposition is enabled
        title = goal_data.title
        description = goal_data.description
        
        if goal_data.ai_decompose:
            try:
                correction_prompt = f"""Correct any spelling or grammar errors in this goal:
Title: "{goal_data.title}"
Description: "{goal_data.description or 'Not provided'}"

Return ONLY a JSON object with corrected values:
{{"title": "Corrected Title", "description": "Corrected description or null"}}"""
                
                response_text = await ai_service._generate_content(correction_prompt)
                json_text = ai_service._extract_json(response_text)
                corrected = json.loads(json_text)
                title = corrected.get('title', goal_data.title)
                description = corrected.get('description') or goal_data.description
                logger.info(f"✏️ AI corrected: '{goal_data.title}' -> '{title}'")
            except Exception as e:
                logger.error(f"Failed to correct goal: {e}")
                # Use original values if correction fails
                title = goal_data.title
                description = goal_data.description
        # Insert goal with corrected title
        # Sync end_date with target_date for backward compatibility
        goal_end_date = goal_data.end_date or goal_data.target_date
        
        insert_query = """
            INSERT INTO goals (user_id, title, description, category, target_date,
                             start_date, end_date, ai_decomposed)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        goal_id = Database.execute_query(
            insert_query,
            (current_user['user_id'], title, description,
             goal_data.category, goal_data.target_date,
             goal_data.start_date, goal_end_date, goal_data.ai_decompose)
        )
        
        # If AI decomposition requested, create subtasks
        subtasks = []
        if goal_data.ai_decompose:
            ai_subtasks = await ai_service.decompose_goal(
                title,  # Use corrected title
                description,
                str(goal_data.target_date) if goal_data.target_date else None
            )
            
            # Insert subtasks
            for subtask in ai_subtasks:
                subtask_query = """
                    INSERT INTO task_subtasks (goal_id, user_id, title, description, 
                                              order_index, due_date)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """
                due_date = None
                if subtask.get('estimated_days_from_start'):
                    due_date = date.today() + timedelta(days=subtask['estimated_days_from_start'])
                
                Database.execute_query(
                    subtask_query,
                    (goal_id, current_user['user_id'], subtask['title'],
                     subtask.get('description'), subtask.get('order_index', 0), due_date)
                )
            
            # Fetch subtasks
            subtasks_query = "SELECT * FROM task_subtasks WHERE goal_id = %s ORDER BY order_index"
            subtasks = Database.execute_query(subtasks_query, (goal_id,), fetch=True)
        
        # Fetch goal
        fetch_query = "SELECT * FROM goals WHERE goal_id = %s"
        goal = Database.execute_query(fetch_query, (goal_id,), fetch=True)[0]
        
        goal['subtasks'] = subtasks
        return GoalResponse(**goal)
    
    except Exception as e:
        logger.error(f"Goal creation error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create goal"
        )

@app.get("/api/goals/list", response_model=List[GoalResponse])
async def list_goals(current_user: dict = Depends(get_current_user)):
    """Get user's goals"""
    try:
        query = "SELECT * FROM goals WHERE user_id = %s ORDER BY created_at DESC"
        goals = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        # Fetch subtasks for each goal
        for goal in goals:
            subtasks_query = "SELECT * FROM task_subtasks WHERE goal_id = %s ORDER BY order_index"
            goal['subtasks'] = Database.execute_query(
                subtasks_query,
                (goal['goal_id'],),
                fetch=True
            )
            logger.info(f"📋 Goal '{goal['title']}' has {len(goal['subtasks'])} subtasks")
            # Calculate progress metrics from subtasks
            goal['total_subtasks'] = len(goal['subtasks'])
            goal['completed_subtasks'] = sum(1 for s in goal['subtasks'] if s.get('completed'))
            if goal['total_subtasks'] > 0:
                goal['progress_percentage'] = (goal['completed_subtasks'] / goal['total_subtasks']) * 100
        
        return [GoalResponse(**goal) for goal in goals]
    
    except Exception as e:
        logger.error(f"Goals list error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch goals"
        )

@app.delete("/api/goals/{goal_id}", response_model=MessageResponse)
async def delete_goal(goal_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a goal and all its subtasks"""
    try:
        # Delete goal (subtasks will be cascade deleted due to foreign key)
        query = "DELETE FROM goals WHERE goal_id = %s AND user_id = %s"
        Database.execute_query(query, (goal_id, current_user['user_id']))
        
        return MessageResponse(message="Goal deleted successfully")
    
    except Exception as e:
        logger.error(f"Goal deletion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete goal"
        )


@app.get("/api/goals/suggestions")
async def get_goal_suggestions(current_user: dict = Depends(get_current_user)):
    """Get AI-powered personalized goal suggestions"""
    try:
        # Fetch user's goals
        query = "SELECT * FROM goals WHERE user_id = %s ORDER BY created_at DESC"
        goals = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        # Fetch subtasks for each goal to calculate progress
        for goal in goals:
            subtasks_query = "SELECT * FROM task_subtasks WHERE goal_id = %s ORDER BY order_index"
            subtasks = Database.execute_query(
                subtasks_query,
                (goal['goal_id'],),
                fetch=True
            )
            goal['subtasks'] = subtasks
            goal['total_subtasks'] = len(subtasks)
            goal['completed_subtasks'] = sum(1 for s in subtasks if s.get('status') == 'completed')
        
        # Get AI suggestions
        suggestion = await ai_service.suggest_goal_tips(goals)
        
        return suggestion
    
    except Exception as e:
        logger.error(f"Goal suggestions error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate goal suggestions"
        )


@app.put("/api/goals/subtask/{subtask_id}/toggle")
async def toggle_subtask(
    subtask_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Toggle subtask completion status — enforces sequential order"""
    try:
        # Fetch the target subtask (order_index + goal_id + current status)
        query = """
            SELECT subtask_id, goal_id, order_index, completed
            FROM task_subtasks
            WHERE subtask_id = %s AND user_id = %s
        """
        result = Database.execute_query(query, (subtask_id, current_user['user_id']), fetch=True)

        if not result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subtask not found"
            )

        subtask = result[0]
        current_completed = bool(subtask['completed'])
        new_status = not current_completed

        # Enforce sequential order: only check when marking as COMPLETE
        if new_status:
            order_check_query = """
                SELECT COUNT(*) as incomplete_count
                FROM task_subtasks
                WHERE goal_id = %s
                  AND order_index < %s
                  AND completed = FALSE
            """
            check_result = Database.execute_query(
                order_check_query,
                (subtask['goal_id'], subtask['order_index']),
                fetch=True
            )
            incomplete_before = check_result[0]['incomplete_count'] if check_result else 0
            if incomplete_before > 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Complete the previous steps first before marking this one done."
                )

        update_query = """
            UPDATE task_subtasks
            SET completed = %s, completed_at = %s
            WHERE subtask_id = %s AND user_id = %s
        """
        Database.execute_query(
            update_query,
            (new_status, datetime.now() if new_status else None, subtask_id, current_user['user_id'])
        )

        return {"success": True, "completed": new_status}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Subtask toggle error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to toggle subtask"
        )

@app.post("/api/ai/suggest-habits", response_model=List[dict])
async def suggest_habits(
    request: AIHabitSuggestionRequest,
    current_user: dict = Depends(get_current_user)
):
    """Get AI habit suggestions"""
    try:
        # Get user's current habits
        habits_query = "SELECT name, category FROM habits WHERE user_id = %s AND is_active = TRUE"
        current_habits = Database.execute_query(habits_query, (current_user['user_id'],), fetch=True)
        
        # Get user's goals
        goals_query = "SELECT title FROM goals WHERE user_id = %s AND status = 'active'"
        goals = Database.execute_query(goals_query, (current_user['user_id'],), fetch=True)
        
        user_profile = {
            "current_habits": [h['name'] for h in current_habits],
            "goals": request.goals or [g['title'] for g in goals],
            "interests": request.interests or []
        }
        
        suggestions = await ai_service.suggest_habits(user_profile)
        return suggestions
    
    except Exception as e:
        logger.error(f"Habit suggestion error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate suggestions"
        )

@app.get("/api/ai/predictions", response_model=dict)
async def get_predictions(current_user: dict = Depends(get_current_user)):
    """Get AI predictions and analytics"""
    try:
        # Gather historical data
        thirty_days_ago = date.today() - timedelta(days=30)
        
        # Task completion rate
        task_query = """
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM tasks
            WHERE user_id = %s AND created_at >= %s
        """
        task_stats = Database.execute_query(
            task_query,
            (current_user['user_id'], thirty_days_ago),
            fetch=True
        )[0]
        
        task_completion_rate = 0
        if task_stats['total'] > 0:
            task_completion_rate = (task_stats['completed'] / task_stats['total']) * 100
        
        # Habit adherence rate
        habit_query = """
            SELECT COUNT(DISTINCT h.habit_id) as total_habits
            FROM habits h
            WHERE h.user_id = %s AND h.is_active = TRUE
        """
        habit_stats = Database.execute_query(habit_query, (current_user['user_id'],), fetch=True)[0]
        
        completion_query = """
            SELECT COUNT(*) as completions
            FROM habit_completions
            WHERE user_id = %s AND completion_date >= %s
        """
        completions = Database.execute_query(
            completion_query,
            (current_user['user_id'], thirty_days_ago),
            fetch=True
        )[0]
        
        expected_completions = habit_stats['total_habits'] * 30
        habit_adherence_rate = 0
        if expected_completions > 0:
            habit_adherence_rate = (completions['completions'] / expected_completions) * 100
        
        # Average mood
        mood_query = """
            SELECT mood_level FROM mood_logs
            WHERE user_id = %s AND log_date >= %s
        """
        moods = Database.execute_query(mood_query, (current_user['user_id'], thirty_days_ago), fetch=True)
        
        historical_data = {
            "task_completion_rate": round(task_completion_rate, 2),
            "habit_adherence_rate": round(habit_adherence_rate, 2),
            "avg_mood": moods[0]['mood_level'] if moods else 'neutral',
            "streak_trends": [],
            "productivity_patterns": {}
        }
        
        predictions = await ai_service.predict_performance(historical_data)
        return predictions
    
    except Exception as e:
        logger.error(f"Predictions error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate predictions"
        )

# ============================================================================
# ANALYTICS & CORRELATION INSIGHTS
# ============================================================================

@app.get("/api/analytics/mood-habit-correlation")
async def get_mood_habit_correlation(
    days: int = 30,
    current_user: dict = Depends(get_current_user)
):
    """
    Get mood-habit correlation data and patterns
    
    Query Parameters:
    - days: Number of days to analyze (default: 30)
    """
    try:
        correlation_data = await correlation_service.calculate_mood_habit_correlation(
            current_user['user_id'],
            days
        )
        
        return correlation_data
    
    except Exception as e:
        logger.error(f"Correlation analysis error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to calculate correlations"
        )

@app.get("/api/analytics/smart-insights", response_model=SmartInsightsResponse)
async def get_smart_insights(
    days: int = 30,
    force_refresh: bool = False,
    current_user: dict = Depends(get_current_user)
):
    """
    Get AI-powered smart insights from mood-habit correlations
    
    This endpoint combines correlation data with AI-generated insights
    to provide actionable recommendations.
    
    Features:
    - 24-hour caching for instant loading
    - 25-second timeout protection
    - Graceful degradation to basic insights
    - Automatic fallback on failures
    """
    user_id = current_user['user_id']
    
    try:
        # Check cache first (unless force refresh)
        if not force_refresh:
            cached_insights = await insights_cache_service.get_cached_insights(user_id, days)
            if cached_insights:
                logger.info(f"Serving cached insights for user {user_id}")
                return SmartInsightsResponse(**cached_insights)
        
        # Calculate correlations
        correlation_data = await correlation_service.calculate_mood_habit_correlation(
            user_id,
            days
        )
        
        # No data case
        if not correlation_data.get("has_data"):
            no_data_response = {
                "habit_correlations": [],
                "weekday_patterns": {},
                "statistics": {},
                "ai_insights": {
                    "insights": [],
                    "summary": "Not enough data yet. Keep logging your mood and completing habits!",
                    "motivation": "Start your journey today! 🌟"
                },
                "days_analyzed": days,
                "mood_logs_count": 0,
                "total_habit_completions": 0
            }
            return SmartInsightsResponse(**no_data_response)
        
        # Generate AI insights with timeout protection
        try:
            async with asyncio.timeout(25):  # 25 second timeout
                ai_insights = await ai_service.generate_correlation_insights(correlation_data)
        except asyncio.TimeoutError:
            logger.warning(f"AI insights generation timed out for user {user_id}, using basic insights")
            # Fallback to basic insights without AI
            ai_insights = _generate_basic_insights_fallback(correlation_data)
        except Exception as ai_error:
            logger.error(f"AI insights generation failed: {ai_error}, using basic insights")
            # Fallback to basic insights on any AI error
            ai_insights = _generate_basic_insights_fallback(correlation_data)
        
        # Build response
        response_data = {
            "habit_correlations": correlation_data.get("habit_correlations", []),
            "weekday_patterns": correlation_data.get("weekday_patterns", {}),
            "statistics": correlation_data.get("statistics", {}),
            "ai_insights": ai_insights,
            "days_analyzed": days,
            "mood_logs_count": correlation_data.get("mood_logs_count", 0),
            "total_habit_completions": correlation_data.get("total_habit_completions", 0)
        }
        
        # Cache the results for future requests
        await insights_cache_service.cache_insights(
            user_id,
            response_data,
            correlation_data,
            days
        )
        
        return SmartInsightsResponse(**response_data)
    
    except Exception as e:
        logger.error(f"Smart insights error: {e}")
        # Try to return cached data as last resort
        try:
            cached_insights = await insights_cache_service.get_cached_insights(user_id, days)
            if cached_insights:
                logger.info(f"Returning stale cache due to error for user {user_id}")
                return SmartInsightsResponse(**cached_insights)
        except:
            pass
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate smart insights. Please try again later."
        )


def _generate_basic_insights_fallback(correlation_data: dict) -> dict:
    """
    Generate basic insights without AI when AI generation fails or times out
    This ensures users always get some insights even if AI is unavailable
    """
    insights = []
    stats = correlation_data.get("statistics", {})
    habit_correlations = correlation_data.get("habit_correlations", [])
    
    # Add positive correlation insight if available
    positive_habits = [c for c in habit_correlations if c.get('correlation_type') == 'positive']
    if positive_habits:
        top_habit = positive_habits[0]
        insights.append({
            "type": "positive_correlation",
            "habit_name": top_habit['habit_name'],
            "title": f"✨ {top_habit['habit_name']} Boosts Your Mood",
            "message": f"You tend to feel better on days when you complete {top_habit['habit_name']}. "
                      f"Your average mood is {top_habit['avg_mood_with_habit']}/5 on days with this habit "
                      f"versus {top_habit['avg_mood_without_habit']}/5 without it.",
            "recommendation": "Keep up this habit to maintain positive mood. Try to be consistent, especially on challenging days.",
            "icon": "✨",
            "strength": top_habit.get('strength', 'moderate')
        })
    
    # Add general habits impact insight
    if stats.get('avg_mood_with_habits', 0) > stats.get('avg_mood_without_habits', 0):
        insights.append({
            "type": "general",
            "habit_name": None,
            "title": "🌟 Habits Improve Your Well-being",
            "message": f"Your mood is generally better on days when you complete habits "
                      f"({stats['avg_mood_with_habits']:.1f}/5) compared to days without habits "
                      f"({stats['avg_mood_without_habits']:.1f}/5).",
            "recommendation": "Stay consistent with your habit routine. Even completing one habit per day can make a difference.",
            "icon": "🌟",
            "strength": "moderate"
        })
    
    # Add overall mood insight
    avg_mood = stats.get('avg_mood', 0)
    if avg_mood > 0:
        mood_label = "excellent" if avg_mood >= 4.5 else "great" if avg_mood >= 4 else "good" if avg_mood >= 3.5 else "moderate"
        insights.append({
            "type": "general",
            "habit_name": None,
            "title": f"😊 Your Overall Mood is {mood_label.title()}",
            "message": f"Over the past {correlation_data.get('days_analyzed', 30)} days, "
                      f"your average mood has been {avg_mood:.1f}/5. Keep tracking to build better habits!",
            "recommendation": "Continue logging your mood daily to understand your emotional patterns better.",
            "icon": "😊" if avg_mood >= 4 else "🙂" if avg_mood >= 3 else "😐",
            "strength": "moderate"
        })
    
    return {
        "insights": insights,
        "summary": f"You've logged {correlation_data.get('mood_logs_count', 0)} moods and "
                  f"{correlation_data.get('total_habit_completions', 0)} habit completions. "
                  f"Your data shows that habits are making a positive difference in your well-being!",
        "motivation": "Keep building positive habits to improve your mood. You're making great progress! 💪",
        "generated_at": datetime.now().isoformat(),
        "days_analyzed": correlation_data.get('days_analyzed', 30)
    }

@app.post("/api/analytics/refresh-correlations", response_model=MessageResponse)
async def refresh_correlations(current_user: dict = Depends(get_current_user)):
    """
    Manually trigger correlation recalculation
    
    This endpoint forces a fresh calculation of all correlations
    and updates the cache.
    """
    try:
        # Recalculate correlations
        correlation_data = await correlation_service.calculate_mood_habit_correlation(
            current_user['user_id'],
            days=30
        )
        
        # Invalidate insights cache so new data is fetched
        await insights_cache_service.invalidate_cache(current_user['user_id'])
        
        if not correlation_data.get("has_data"):
            return MessageResponse(
                message="Not enough data to calculate correlations yet.",
                success=False
            )
        
        # Cache the results in database
        for corr in correlation_data.get("habit_correlations", []):
            cache_query = """
                INSERT INTO habit_mood_correlations 
                (user_id, habit_id, correlation_type, correlation_score, 
                 mood_level_affected, pattern_description, sample_size,
                 avg_mood_with_habit, avg_mood_without_habit)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    correlation_type = VALUES(correlation_type),
                    correlation_score = VALUES(correlation_score),
                    mood_level_affected = VALUES(mood_level_affected),
                    pattern_description = VALUES(pattern_description),
                    sample_size = VALUES(sample_size),
                    avg_mood_with_habit = VALUES(avg_mood_with_habit),
                    avg_mood_without_habit = VALUES(avg_mood_without_habit),
                    last_calculated = CURRENT_TIMESTAMP
            """
            
            pattern_desc = f"{corr['strength']} {corr['correlation_type']} correlation"
            
            Database.execute_query(
                cache_query,
                (
                    current_user['user_id'],
                    corr['habit_id'],
                    corr['correlation_type'],
                    corr['mood_difference'],
                    corr['most_common_mood_with_habit'],
                    pattern_desc,
                    corr['sample_size'],
                    corr['avg_mood_with_habit'],
                    corr['avg_mood_without_habit']
                )
            )
        
        return MessageResponse(
            message="Correlations refreshed successfully!",
            data={
                "habits_analyzed": len(correlation_data.get("habit_correlations", [])),
                "days_analyzed": 30
            }
        )
    
    except Exception as e:
        logger.error(f"Refresh correlations error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to refresh correlations"
        )

# ============================================================================
# CALENDAR EVENTS
# ============================================================================

@app.get("/api/calendar/events")
async def get_calendar_events(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Get all calendar events (tasks, habits, goals, moods) for a date range
    
    Returns all historical data with actual dates for complete calendar view
    """
    try:
        # Default to 1 year before and after today
        if not start_date:
            start_date = date.today() - timedelta(days=365)
        if not end_date:
            end_date = date.today() + timedelta(days=365)
        
        events = []
        
        # 1. Tasks with due dates
        tasks_query = """
            SELECT task_id, title, due_date, status, priority, category
            FROM tasks
            WHERE user_id = %s 
              AND due_date BETWEEN %s AND %s
            ORDER BY due_date
        """
        tasks = Database.execute_query(
            tasks_query, 
            (current_user['user_id'], start_date, end_date), 
            fetch=True
        )
        for task in tasks:
            events.append({
                "type": "task",
                "date": task['due_date'].isoformat(),
                "title": task['title'],
                "status": task['status'],
                "priority": task['priority'],
                "category": task['category'],
                "id": task['task_id']
            })
        
        # 2. Habit completions (ACTUAL completion dates from database)
        habits_query = """
            SELECT hc.completion_date, h.name, h.category, h.habit_id
            FROM habit_completions hc
            JOIN habits h ON hc.habit_id = h.habit_id
            WHERE hc.user_id = %s 
              AND hc.completion_date BETWEEN %s AND %s
            ORDER BY hc.completion_date
        """
        habit_completions = Database.execute_query(
            habits_query,
            (current_user['user_id'], start_date, end_date),
            fetch=True
        )
        for completion in habit_completions:
            events.append({
                "type": "habit",
                "date": completion['completion_date'].isoformat(),
                "title": completion['name'],
                "category": completion['category'],
                "id": completion['habit_id']
            })
        
        # 3. Goals with target dates
        goals_query = """
            SELECT goal_id, title, target_date, status, category
            FROM goals
            WHERE user_id = %s 
              AND target_date IS NOT NULL
              AND target_date BETWEEN %s AND %s
            ORDER BY target_date
        """
        goals = Database.execute_query(
            goals_query,
            (current_user['user_id'], start_date, end_date),
            fetch=True
        )
        for goal in goals:
            events.append({
                "type": "goal",
                "date": goal['target_date'].isoformat(),
                "title": goal['title'],
                "status": goal['status'],
                "category": goal['category'],
                "id": goal['goal_id']
            })
        
        # 4. Mood logs
        moods_query = """
            SELECT log_date, mood_level, energy_level, notes
            FROM mood_logs
            WHERE user_id = %s 
              AND log_date BETWEEN %s AND %s
            ORDER BY log_date
        """
        moods = Database.execute_query(
            moods_query,
            (current_user['user_id'], start_date, end_date),
            fetch=True
        )
        for mood in moods:
            events.append({
                "type": "mood",
                "date": mood['log_date'].isoformat(),
                "mood_level": mood['mood_level'],
                "energy_level": mood['energy_level'],
                "notes": mood.get('notes', '')
            })
        
        logger.info(f"Calendar events: {len(events)} total events for user {current_user['user_id']}")
        
        return {
            "events": events,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "total_count": len(events)
        }
    
    except Exception as e:
        logger.error(f"Calendar events error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch calendar events"
        )

# ============================================================================
# DASHBOARD
# ============================================================================

@app.get("/api/dashboard")
async def get_dashboard_data(current_user: dict = Depends(get_current_user)):
    """Get dashboard statistics"""
    try:
        today = date.today()
        
        # Get today's tasks count
        task_query = """
            SELECT COUNT(*) as count
            FROM tasks
            WHERE user_id = %s AND status = 'pending'
        """
        tasks_result = Database.execute_query(task_query, (current_user['user_id'],), fetch=True)
        today_tasks = tasks_result[0]['count'] if tasks_result else 0
        
        # Get active habits count
        habit_query = """
            SELECT COUNT(*) as count
            FROM habits
            WHERE user_id = %s AND is_active = TRUE
        """
        habits_result = Database.execute_query(habit_query, (current_user['user_id'],), fetch=True)
        today_habits = habits_result[0]['count'] if habits_result else 0
        
        # Get active streaks (habits with current_streak > 0)
        streak_query = """
            SELECT COUNT(*) as count
            FROM habits
            WHERE user_id = %s AND is_active = TRUE AND current_streak > 0
        """
        streak_result = Database.execute_query(streak_query, (current_user['user_id'],), fetch=True)
        active_streaks = streak_result[0]['count'] if streak_result else 0
        
        # Get longest streak for display
        longest_streak_query = """
            SELECT COALESCE(MAX(current_streak), 0) as max_streak
            FROM habits
            WHERE user_id = %s AND is_active = TRUE
        """
        longest_result = Database.execute_query(longest_streak_query, (current_user['user_id'],), fetch=True)
        longest_streak = longest_result[0]['max_streak'] if longest_result else 0
        
        # Calculate completion rate (simplified: completed tasks / total tasks in last 7 days)
        completion_query = """
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM tasks
            WHERE user_id = %s AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        """
        completion_result = Database.execute_query(completion_query, (current_user['user_id'],), fetch=True)
        total = completion_result[0]['total'] if completion_result else 0
        completed = completion_result[0]['completed'] if completion_result else 0
        completion_rate = round((completed / total * 100) if total > 0 else 0)
        
        
        # Simple insight message (removed slow AI call)
        insight_message = "Great progress! Keep up the good work!"
        
        # Get upcoming tasks
        upcoming_query = """
            SELECT task_id, title, due_date, priority
            FROM tasks
            WHERE user_id = %s AND status = 'pending' AND due_date >= %s
            ORDER BY due_date ASC, ai_priority_score DESC
            LIMIT 3
        """
        upcoming_tasks = Database.execute_query(
            upcoming_query,
            (current_user['user_id'], today),
            fetch=True
        )
        
        return {
            "today_tasks": today_tasks,
            "today_habits": today_habits,
            "active_streaks": active_streaks,
            "longest_streak": longest_streak,
            "completion_rate": completion_rate,
            "ai_insight": insight_message,
            "upcoming_tasks": upcoming_tasks or []
        }
    
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch dashboard data"
        )

# ============================================================================
# ANALYTICS & REPORTS
# ============================================================================

@app.get("/api/analytics/daily", response_model=DailyReport)
async def get_daily_report(
    report_date: Optional[date] = None,
    current_user: dict = Depends(get_current_user)
):
    """Get daily report"""
    try:
        report_date = report_date or date.today()
        
        # Get tasks for the day
        task_query = """
            SELECT COUNT(*) as total,
                   SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM tasks
            WHERE user_id = %s AND due_date = %s
        """
        task_stats = Database.execute_query(
            task_query,
            (current_user['user_id'], report_date),
            fetch=True
        )[0]
        
        # Get habits for the day
        habit_query = """
            SELECT COUNT(DISTINCT h.habit_id) as total
            FROM habits h
            WHERE h.user_id = %s AND h.is_active = TRUE
        """
        total_habits = Database.execute_query(habit_query, (current_user['user_id'],), fetch=True)[0]['total']
        
        completion_query = """
            SELECT COUNT(*) as completed
            FROM habit_completions
            WHERE user_id = %s AND completion_date = %s
        """
        completed_habits = Database.execute_query(
            completion_query,
            (current_user['user_id'], report_date),
            fetch=True
        )[0]['completed']
        
        # Get mood
        mood_query = """
            SELECT mood_level, energy_level FROM mood_logs
            WHERE user_id = %s AND log_date = %s
        """
        mood = Database.execute_query(mood_query, (current_user['user_id'], report_date), fetch=True)
        
        # Get streaks
        streaks_query = """
            SELECT name, current_streak FROM habits
            WHERE user_id = %s AND is_active = TRUE AND current_streak > 0
            ORDER BY current_streak DESC
            LIMIT 5
        """
        streaks = Database.execute_query(streaks_query, (current_user['user_id'],), fetch=True)
        
        # Calculate completion rate
        total_items = (task_stats['total'] or 0) + total_habits
        completed_items = (task_stats['completed'] or 0) + completed_habits
        completion_rate = (completed_items / total_items * 100) if total_items > 0 else 0
        
        # Generate AI summary
        user_data = {
            "tasks_completed": task_stats['completed'] or 0,
            "total_tasks": task_stats['total'] or 0,
            "habits_completed": completed_habits,
            "total_habits": total_habits,
            "mood": mood[0]['mood_level'] if mood else 'Not logged',
            "energy": mood[0]['energy_level'] if mood else 'Not logged',
            "streaks": [{"name": s['name'], "days": s['current_streak']} for s in streaks]
        }
        
        ai_summary = await ai_service.generate_daily_report(user_data)
        
        return DailyReport(
            date=report_date,
            tasks_completed=task_stats['completed'] or 0,
            total_tasks=task_stats['total'] or 0,
            habits_completed=completed_habits,
            total_habits=total_habits,
            completion_rate=round(float(completion_rate), 2),  # type: ignore
            mood_average=mood[0]['mood_level'] if mood else None,
            energy_average=mood[0]['energy_level'] if mood else None,
            ai_summary=ai_summary,
            streaks=[{"name": s['name'], "days": s['current_streak']} for s in streaks]
        )
    
    except Exception as e:
        logger.error(f"Daily report error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate daily report"
        )

@app.get("/api/analytics/dashboard", response_model=DashboardData)
async def get_dashboard(current_user: dict = Depends(get_current_user)):
    """Get dashboard data"""
    try:
        today = date.today()
        
        # Today's tasks
        today_tasks_query = """
            SELECT COUNT(*) as count FROM tasks
            WHERE user_id = %s AND due_date = %s AND status != 'completed'
        """
        today_tasks = Database.execute_query(
            today_tasks_query,
            (current_user['user_id'], today),
            fetch=True
        )[0]['count']
        
        # Today's habits
        habits_query = """
            SELECT COUNT(*) as count FROM habits
            WHERE user_id = %s AND is_active = TRUE
        """
        today_habits = Database.execute_query(habits_query, (current_user['user_id'],), fetch=True)[0]['count']
        
        # Active streaks
        streaks_query = """
            SELECT COUNT(*) as count FROM habits
            WHERE user_id = %s AND is_active = TRUE AND current_streak > 0
        """
        active_streaks = Database.execute_query(streaks_query, (current_user['user_id'],), fetch=True)[0]['count']
        
        # Completion rate (last 7 days)
        seven_days_ago = today - timedelta(days=7)
        completion_query = """
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM tasks
            WHERE user_id = %s AND created_at >= %s
        """
        completion_stats = Database.execute_query(
            completion_query,
            (current_user['user_id'], seven_days_ago),
            fetch=True
        )[0]
        
        completion_rate = 0
        if completion_stats['total'] > 0:
            completion_rate = (completion_stats['completed'] / completion_stats['total']) * 100
        
        # Recent insights
        insights_query = """
            SELECT * FROM ai_insights
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 5
        """
        insights = Database.execute_query(insights_query, (current_user['user_id'],), fetch=True)
        
        # Upcoming tasks
        upcoming_query = """
            SELECT * FROM tasks
            WHERE user_id = %s AND status = 'pending' AND due_date >= %s
            ORDER BY due_date ASC, ai_priority_score DESC
            LIMIT 5
        """
        upcoming = Database.execute_query(upcoming_query, (current_user['user_id'], today), fetch=True)
        
        return DashboardData(
            today_tasks=today_tasks,
            today_habits=today_habits,
            active_streaks=active_streaks,
            completion_rate=round(completion_rate, 2),
            recent_insights=insights,
            upcoming_tasks=upcoming,
            mood_trend=None
        )
    
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to load dashboard"
        )

# ============================================================================
# n8n WEBHOOK PLACEHOLDERS
# ============================================================================

@app.post("/api/webhooks/sendSummary", response_model=WebhookResponse)
async def webhook_send_summary(user_id: int):
    """
    Placeholder for n8n: Send daily summary to WhatsApp
    This will be triggered by n8n workflow
    """
    try:
        # In the future, this will:
        # 1. Generate daily summary for user
        # 2. Return it to n8n
        # 3. n8n will send it via WhatsApp
        
        return WebhookResponse(
            success=True,
            message="Summary endpoint ready for n8n integration",
            data={"user_id": user_id}
        )
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return WebhookResponse(success=False, message=str(e))

@app.post("/api/webhooks/receiveWhatsAppMessage", response_model=WebhookResponse)
async def webhook_receive_message(message: WhatsAppMessage):
    """
    Placeholder for n8n: Receive WhatsApp message
    n8n will call this when user sends a message
    """
    try:
        # Log the message
        log_query = """
            INSERT INTO whatsapp_logs (phone_number, message_type, message_content, 
                                      webhook_payload, processed)
            VALUES (%s, 'incoming', %s, %s, FALSE)
        """
        Database.execute_query(
            log_query,
            (message.phone_number, message.message, json.dumps(message.dict()))
        )
        
        # In the future, this will:
        # 1. Parse the message
        # 2. Execute the command (add task, show habits, etc.)
        # 3. Return response to n8n
        # 4. n8n sends response via WhatsApp
        
        return WebhookResponse(
            success=True,
            message="Message received and logged",
            data={"response": "Command processing will be implemented with n8n"}
        )
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return WebhookResponse(success=False, message=str(e))

@app.post("/api/webhooks/syncTaskToUser", response_model=WebhookResponse)
async def webhook_sync_task(user_id: int, task_data: dict):
    """
    Placeholder for n8n: Sync task created via WhatsApp
    """
    try:
        return WebhookResponse(
            success=True,
            message="Task sync endpoint ready for n8n integration",
            data={"user_id": user_id}
        )
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return WebhookResponse(success=False, message=str(e))

@app.post("/api/webhooks/triggerDailyReport", response_model=WebhookResponse)
async def webhook_trigger_report(user_id: int):
    """
    Placeholder for n8n: Trigger daily report generation
    """
    try:
        return WebhookResponse(
            success=True,
            message="Daily report trigger ready for n8n integration",
            data={"user_id": user_id}
        )
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return WebhookResponse(success=False, message=str(e))

# ============================================================================
# HEALTH CHECK
# ============================================================================

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Test database connection
        Database.execute_query("SELECT 1", fetch=True)
        db_status = "connected"
    except:
        db_status = "disconnected"
    
    return {
        "status": "healthy",
        "database": db_status,
        "ai_service": "configured"
    }

# ============================================================================
# GOALS ENDPOINTS
# ============================================================================

@app.get("/api/goals/list", response_model=List[GoalResponse])
async def list_goals(current_user: dict = Depends(get_current_user)):
    """Get user's goals with progress tracking"""
    try:
        query = """
            SELECT g.*, 
                   COUNT(DISTINCT ts.subtask_id) as total_subtasks,
                   COUNT(DISTINCT CASE WHEN ts.status = 'completed' THEN ts.subtask_id END) as completed_subtasks
            FROM goals g
            LEFT JOIN task_subtasks ts ON g.goal_id = ts.goal_id
            WHERE g.user_id = %s
            GROUP BY g.goal_id
            ORDER BY g.created_at DESC
        """
        goals = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        result = []
        for goal in goals:
            # Calculate progress
            total = goal.get('total_subtasks', 0)
            completed = goal.get('completed_subtasks', 0)
            progress = (completed / total * 100) if total > 0 else 0
            
            # Determine status indicator
            status_indicator = "on_track"
            estimated_days = None
            
            if goal.get('target_date'):
                days_remaining = (goal['target_date'] - date.today()).days
                if total > 0 and completed > 0:
                    days_passed = (date.today() - goal['created_at'].date()).days if goal.get('created_at') else 1
                    velocity = completed / max(int(days_passed), 1)
                    estimated_days = int((total - completed) / velocity) if velocity > 0 else None
                    
                    if estimated_days and days_remaining > 0:
                        if estimated_days < days_remaining * 0.8:
                            status_indicator = "ahead"
                        elif estimated_days > days_remaining:
                            status_indicator = "falling_behind"
            
            goal_response = GoalResponse(
                **goal,
                total_subtasks=total,
                completed_subtasks=completed,
                progress_percentage=round(progress, 2),
                status_indicator=status_indicator,
                estimated_days_remaining=estimated_days
            )
            result.append(goal_response)
        
        return result
    except Exception as e:
        logger.error(f"Goals list error: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch goals")

@app.post("/api/goals/create", response_model=GoalResponse)
async def create_goal(goal_data: GoalCreate, current_user: dict = Depends(get_current_user)):
    """Create a new goal"""
    try:
        query = """
            INSERT INTO goals (user_id, title, description, category, target_date)
            VALUES (%s, %s, %s, %s, %s)
        """
        goal_id = Database.execute_query(
            query,
            (current_user['user_id'], goal_data.title, goal_data.description,
             goal_data.category, goal_data.target_date)
        )
        
        # Fetch created goal
        fetch_query = "SELECT * FROM goals WHERE goal_id = %s"
        goal = Database.execute_query(fetch_query, (goal_id,), fetch=True)[0]
        
        return GoalResponse(
            **goal, 
            total_subtasks=0, 
            completed_subtasks=0,
            status_indicator="on_track",
            estimated_days_remaining=None
        )
    except Exception as e:
        logger.error(f"Goal creation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to create goal")

@app.put("/api/goals/{goal_id}", response_model=GoalResponse)
async def update_goal(goal_id: int, goal_update: GoalUpdate, current_user: dict = Depends(get_current_user)):
    """Update a goal"""
    try:
        updates = []
        params = []
        
        if goal_update.title is not None:
            updates.append("title = %s")
            params.append(goal_update.title)
        if goal_update.description is not None:
            updates.append("description = %s")
            params.append(goal_update.description)
        if goal_update.category is not None:
            updates.append("category = %s")
            params.append(goal_update.category)
        if goal_update.target_date is not None:
            updates.append("target_date = %s")
            params.append(goal_update.target_date)
        if goal_update.status is not None:
            updates.append("status = %s")
            params.append(goal_update.status)
            if goal_update.status == 'completed':
                updates.append("completed_at = NOW()")
        
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        params.extend([goal_id, current_user['user_id']])
        query = f"UPDATE goals SET {', '.join(updates)} WHERE goal_id = %s AND user_id = %s"
        Database.execute_query(query, tuple(params))
        
        # Fetch updated goal
        fetch_query = "SELECT * FROM goals WHERE goal_id = %s"
        goal = Database.execute_query(fetch_query, (goal_id,), fetch=True)[0]
        
        return GoalResponse(
            **goal, 
            total_subtasks=0, 
            completed_subtasks=0,
            status_indicator="on_track",
            estimated_days_remaining=None
        )
    except Exception as e:
        logger.error(f"Goal update error: {e}")
        raise HTTPException(status_code=500, detail="Failed to update goal")

@app.delete("/api/goals/{goal_id}")
async def delete_goal(goal_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a goal"""
    try:
        query = "DELETE FROM goals WHERE goal_id = %s AND user_id = %s"
        Database.execute_query(query, (goal_id, current_user['user_id']))
        return {"message": "Goal deleted successfully"}
    except Exception as e:
        logger.error(f"Goal deletion error: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete goal")

@app.post("/api/goals/{goal_id}/subtask", response_model=SubtaskResponse)
async def add_subtask(goal_id: int, subtask_data: SubtaskCreate, current_user: dict = Depends(get_current_user)):
    """Add a subtask to a goal"""
    try:
        query = """
            INSERT INTO task_subtasks (goal_id, user_id, title, description, order_index, due_date)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        subtask_id = Database.execute_query(
            query,
            (goal_id, current_user['user_id'], subtask_data.title,
             subtask_data.description, subtask_data.order_index, subtask_data.due_date)
        )
        
        fetch_query = "SELECT * FROM task_subtasks WHERE subtask_id = %s"
        subtask = Database.execute_query(fetch_query, (subtask_id,), fetch=True)[0]
        
        return SubtaskResponse(**subtask)
    except Exception as e:
        logger.error(f"Subtask creation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to add subtask")

@app.post("/api/goals/subtask/{subtask_id}/toggle")
async def toggle_subtask(subtask_id: int, current_user: dict = Depends(get_current_user)):
    """Toggle subtask completion with milestone detection"""
    try:
        # Get current status
        fetch_query = "SELECT * FROM task_subtasks WHERE subtask_id = %s AND user_id = %s"
        subtask = Database.execute_query(fetch_query, (subtask_id, current_user['user_id']), fetch=True)[0]
        
        new_status = 'completed' if subtask['status'] != 'completed' else 'pending'
        
        # Update status
        update_query = """
            UPDATE task_subtasks 
            SET status = %s, completed_at = %s 
            WHERE subtask_id = %s
        """
        completed_at = datetime.now() if new_status == 'completed' else None
        Database.execute_query(update_query, (new_status, completed_at, subtask_id))
        
        # Calculate progress and check for milestones
        goal_id = subtask['goal_id']
        progress_query = """
            SELECT COUNT(*) as total, 
                   SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed
            FROM task_subtasks WHERE goal_id = %s
        """
        progress = Database.execute_query(progress_query, (goal_id,), fetch=True)[0]
        
        total = progress['total']
        completed = progress['completed']
        percentage = (completed / total * 100) if total > 0 else 0
        
        # Update goal progress
        Database.execute_query(
            "UPDATE goals SET progress_percentage = %s WHERE goal_id = %s",
            (percentage, goal_id)
        )
        
        # Check for milestones
        milestone_reached = False
        celebration_message = ""
        
        milestones = [25, 50, 75, 100]
        for milestone in milestones:
            if abs(float(percentage) - milestone) < 1:  # Within 1% of milestone
                milestone_reached = True
                messages = {
                    25: "Great start! You're 25% done! 🌟",
                    50: "Halfway there! Keep going! 🎯",
                    75: "Almost done! You've got this! 🚀",
                    100: "Goal achieved! Celebrate! 🎉"
                }
                celebration_message = messages[milestone]
                break
        
        return {
            "success": True,
            "subtask": SubtaskResponse(**Database.execute_query(fetch_query, (subtask_id, current_user['user_id']), fetch=True)[0]),
            "progress_percentage": round(percentage, 2),
            "milestone_reached": milestone_reached,
            "celebration_message": celebration_message
        }
    except Exception as e:
        logger.error(f"Subtask toggle error: {e}")
        raise HTTPException(status_code=500, detail="Failed to toggle subtask")

@app.delete("/api/goals/subtask/{subtask_id}")
async def delete_subtask(subtask_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a subtask"""
    try:
        query = "DELETE FROM task_subtasks WHERE subtask_id = %s AND user_id = %s"
        Database.execute_query(query, (subtask_id, current_user['user_id']))
        return {"message": "Subtask deleted successfully"}
    except Exception as e:
        logger.error(f"Subtask deletion error: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete subtask")

@app.post("/api/goals/{goal_id}/breakdown")
async def breakdown_goal(goal_id: int, current_user: dict = Depends(get_current_user)):
    """Use AI to suggest subtasks for a goal"""
    try:
        # Get goal details
        query = "SELECT * FROM goals WHERE goal_id = %s AND user_id = %s"
        goal = Database.execute_query(query, (goal_id, current_user['user_id']), fetch=True)[0]
        
        # Get AI suggestions
        subtasks = await ai_service.breakdown_goal_into_subtasks(
            goal['title'],
            goal.get('description')
        )
        
        return {"subtasks": subtasks}
    except Exception as e:
        logger.error(f"Goal breakdown error: {e}")
        raise HTTPException(status_code=500, detail="Failed to breakdown goal")

# ==================== VOICE ENDPOINTS ====================

@app.post("/api/voice/transcribe")
async def transcribe_voice(
    file: UploadFile = File(...),
    language: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Transcribe audio file to text using Whisper"""
    import tempfile
    import os
    
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav', mode='wb') as temp_file:
            content = await file.read()
            temp_file.write(content)  # type: ignore
            temp_path = temp_file.name
        
        try:
            # Transcribe audio
            result = await voice_service.transcribe_audio(temp_path, language)
            return {
                "success": True,
                "transcription": result['text'],
                "language": result.get('language'),
                "duration": result.get('duration')
            }
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/voice/classify")
async def classify_voice_intent(
    transcription: str = Body(..., embed=True),
    context: Optional[str] = Body(None, embed=True),
    current_user: dict = Depends(get_current_user)
):
    """Classify intent from transcription"""
    try:
        result = await voice_service.classify_intent(transcription, context)
        return {
            "success": True,
            **result
        }
    except Exception as e:
        logger.error(f"Classification error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/voice/process")
async def process_voice_command(
    file: UploadFile = File(...),
    context: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    preview_only: bool = Form(False),
    current_user: dict = Depends(get_current_user)
):
    """
    Complete voice processing pipeline with multi-intent support:
    1. Transcribe audio (auto-detect language from 99+ supported languages)
    2. Extract multiple entities and classify intents
    3. Create tasks/goals/habits automatically (batch creation)
    
    Returns:
        {
            "success": true,
            "transcription": "original text",
            "language": "detected language",
            "items_created": {
                "tasks": [id1, id2, ...],
                "goals": [id1, ...],
                "habits": [id1, ...]
            },
            "total_count": 5
        }
    """
    import tempfile
    import os
    
    try:
        # Step 1: Transcribe audio with auto-language detection
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav', mode='wb') as temp_file:
            content = await file.read()
            temp_file.write(content)  # type: ignore
            temp_path = temp_file.name
        
        try:
            transcription_result = await voice_service.transcribe_audio(temp_path, language)
            transcription = transcription_result['text']
            detected_language = transcription_result['language']
            logger.info(f"Transcription ({detected_language}): {transcription}")
            
            # Step 2: Process voice command and extract multiple entities
            processing_result = await voice_service.process_voice_command(transcription, context)
            items = processing_result['items']
            
            logger.info(f"Extracted {len(items)} items from voice command")
            
            if preview_only:
                return {
                    "success": True,
                    "transcription": transcription,
                    "language": detected_language,
                    "parsed_items": items,
                    "total_count": len(items)
                }
            
            # Step 3: Create all items in database (batch processing)
            created_items = {
                'tasks': [],
                'goals': [],
                'habits': []
            }
            
            for item in items:
                intent = item['intent']
                data = item['data']
                confidence = item.get('confidence', 'medium')
                
                try:
                    if intent == 'task':
                        # Create task
                        task_data = {
                            'title': data.get('title', transcription[:100]),
                            'description': data.get('description', ''),
                            'priority': data.get('priority', 'medium'),
                            'category': data.get('category', 'general'),
                            'due_date': data.get('due_date'),
                            'due_time': data.get('due_time'),
                            'estimated_duration': data.get('estimated_duration', 30),
                            'ai_tags': data.get('tags', ['voice-created']),
                            'ai_generated': True
                        }
                        
                        query = """
                            INSERT INTO tasks (user_id, title, description, priority, category,
                                             due_date, due_time, estimated_duration, ai_tags, ai_generated, status)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending')
                        """
                        task_id = Database.execute_query(
                            query,
                            (
                                current_user['user_id'],
                                task_data['title'],
                                task_data['description'],
                                task_data['priority'],
                                task_data['category'],
                                task_data['due_date'],
                                task_data['due_time'],
                                task_data['estimated_duration'],
                                json.dumps(task_data['ai_tags']),
                                task_data['ai_generated']
                            )
                        )
                        created_items['tasks'].append(task_id)
                        logger.info(f"Created task #{task_id}: {task_data['title']}")
                        
                    elif intent == 'goal':
                        # Create goal
                        goal_data = {
                            'title': data.get('title', transcription[:100]),
                            'description': data.get('description', ''),
                            'category': data.get('category', 'personal'),
                            'target_date': data.get('target_date'),
                        }
                        
                        query = """
                            INSERT INTO goals (user_id, title, description, category,
                                             target_date, status)
                            VALUES (%s, %s, %s, %s, %s, 'active')
                        """
                        goal_id = Database.execute_query(
                            query,
                            (
                                current_user['user_id'],
                                goal_data['title'],
                                goal_data['description'],
                                goal_data['category'],
                                goal_data['target_date'],
                            )
                        )
                        created_items['goals'].append(goal_id)
                        logger.info(f"Created goal #{goal_id}: {goal_data['title']}")
                        
                    elif intent == 'habit':
                        # Create habit
                        habit_data = {
                            'name': data.get('name', transcription[:100]),
                            'description': data.get('description', ''),
                            'category': data.get('category', 'personal'),
                            'frequency': data.get('frequency', 'daily'),
                            'target_count': data.get('target_count', 1)
                        }
                        
                        query = """
                            INSERT INTO habits (user_id, name, description, category,
                                              frequency, target_count, current_streak, longest_streak)
                            VALUES (%s, %s, %s, %s, %s, %s, 0, 0)
                        """
                        habit_id = Database.execute_query(
                            query,
                            (
                                current_user['user_id'],
                                habit_data['name'],
                                habit_data['description'],
                                habit_data['category'],
                                habit_data['frequency'],
                                habit_data['target_count']
                            )
                        )
                        created_items['habits'].append(habit_id)
                        logger.info(f"Created habit #{habit_id}: {habit_data['name']}")
                        
                except Exception as item_error:
                    logger.error(f"Failed to create {intent}: {item_error}")
                    # Continue with other items even if one fails
                    continue
            
            total_count = sum(len(v) for v in created_items.values())
            
            return {
                "success": True,
                "transcription": transcription,
                "language": detected_language,
                "items_created": created_items,
                "total_count": total_count,
                "message": f"Successfully created {total_count} item(s) from voice command"
            }
            
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        logger.error(f"Voice processing error: {e}")
        raise HTTPException(status_code=500, detail=str(e))




@app.get("/api/notifications/settings")
async def get_notification_settings(current_user: dict = Depends(get_current_user)):
    """Get user's notification preferences"""
    try:
        query = """
            SELECT notification_type, scheduled_time, enabled
            FROM notification_schedule
            WHERE user_id = %s
            ORDER BY scheduled_time
        """
        
        settings = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        return {
            "settings": settings or [],
            "has_schedule": bool(settings)
        }
        
    except Exception as e:
        logger.error(f"Error getting notification settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/notifications/settings")
async def update_notification_settings(
    settings: dict = Body(...),
    current_user: dict = Depends(get_current_user)
):
    """
    Update notification preferences
    Body: {
        "morning_enabled": true,
        "midday_enabled": false,
        "evening_enabled": true,
        "morning_time": "08:00:00",
        "evening_time": "18:00:00"
    }
    """
    try:
        user_id = current_user['user_id']
        
        # Update each notification type
        for notif_type in ['morning', 'midday', 'evening']:
            enabled_key = f"{notif_type}_enabled"
            time_key = f"{notif_type}_time"
            
            if enabled_key in settings:
                query = """
                    UPDATE notification_schedule
                    SET enabled = %s
                    WHERE user_id = %s AND notification_type = %s
                """
                Database.execute_query(query, (settings[enabled_key], user_id, notif_type))
            
            if time_key in settings:
                query = """
                    UPDATE notification_schedule
                    SET scheduled_time = %s
                    WHERE user_id = %s AND notification_type = %s
                """
                Database.execute_query(query, (settings[time_key], user_id, notif_type))
        
        return {"message": "Notification settings updated successfully"}
        
    except Exception as e:
        logger.error(f"Error updating notification settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/notifications/history")
async def get_notification_history(
    limit: int = 20,
    current_user: dict = Depends(get_current_user)
):
    """Get notification history"""
    try:
        query = """
            SELECT 
                notification_id,
                notification_type,
                title,
                message,
                priority,
                sent_at,
                opened,
                opened_at,
                action_taken
            FROM notification_history
            WHERE user_id = %s
            ORDER BY sent_at DESC
            LIMIT %s
        """
        
        history = Database.execute_query(query, (current_user['user_id'], limit), fetch=True)
        
        return {
            "history": history or [],
            "total": len(history) if history else 0
        }
        
    except Exception as e:
        logger.error(f"Error getting notification history: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/notifications/patterns")
async def get_user_patterns(current_user: dict = Depends(get_current_user)):
    """Get learned user patterns"""
    try:
        query = """
            SELECT pattern_type, pattern_data, confidence_score, sample_size, last_updated
            FROM user_patterns
            WHERE user_id = %s
        """
        
        patterns = Database.execute_query(query, (current_user['user_id'],), fetch=True)
        
        # Parse JSON data
        for pattern in (patterns or []):
            if pattern.get('pattern_data'):
                import json
                pattern['pattern_data'] = json.loads(pattern['pattern_data'])
        
        return {
            "patterns": patterns or [],
            "has_patterns": bool(patterns)
        }
        
    except Exception as e:
        logger.error(f"Error getting user patterns: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/debug/tables")
async def debug_tables():
    """List all tables in the connected database"""
    try:
        # Get database name
        db_name = Database.execute_query("SELECT DATABASE() as db", fetch=True)[0]['db']
        
        # Get tables
        tables = Database.execute_query("SHOW TABLES", fetch=True)
        
        # Get connection info
        from config import settings
        connection_info = f"{settings.DB_USER}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
        
        return {
            "connected_to_db": db_name,
            "connection_settings": connection_info,
            "tables": [list(t.values())[0] for t in tables],
            "count": len(tables)
        }
    except Exception as e:
        return {"error": str(e)}

# ============================================================================
# VOICE PROCESSING ENDPOINTS
# ============================================================================

@app.post("/voice/transcribe")
async def transcribe_voice(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    current_user: dict = Depends(get_current_user)
):
    """Transcribe an uploaded audio file using Groq Whisper"""
    import tempfile, os
    tmp_path = None
    try:
        # Save upload to a temp file
        suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name

        result = await voice_service.transcribe_audio(tmp_path, language=language)
        return result
    except Exception as e:
        logger.error(f"Transcription endpoint error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)


@app.post("/voice/classify")
async def classify_voice_intent(
    body: dict = Body(...),
    current_user: dict = Depends(get_current_user)
):
    """Classify intent from a transcription string"""
    transcription = body.get("transcription", "")
    context = body.get("context")
    if not transcription:
        raise HTTPException(status_code=400, detail="transcription is required")
    try:
        result = await voice_service.classify_intent(transcription, context=context)
        return result
    except Exception as e:
        logger.error(f"Intent classification endpoint error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/voice/process")
async def process_voice(
    file: UploadFile = File(...),
    context: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    current_user: dict = Depends(get_current_user)
):
    """
    Full voice pipeline: upload audio → transcribe → classify intent(s) → return structured items.
    This is the primary endpoint called by the Flutter app when the user stops recording.
    """
    import tempfile, os
    tmp_path = None
    try:
        # Save uploaded audio to a temp file
        suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name

        # Step 1: Transcribe
        transcription_result = await voice_service.transcribe_audio(tmp_path, language=language)
        transcription_text = transcription_result.get("text", "")
        detected_language = transcription_result.get("language", "unknown")

        if not transcription_text.strip():
            return {
                "items": [],
                "transcription": "",
                "language": detected_language,
                "message": "No speech detected in the recording."
            }

        # Step 2: Process / classify intents (handles multiple items in one utterance)
        result = await voice_service.process_voice_command(transcription_text, context=context)
        
        items_created = {"tasks": [], "goals": [], "habits": []}
        user_id = current_user['user_id']
        
        for item in result.get("items", []):
            intent = item.get("intent")
            data = item.get("data", {})
            
            if intent == "task":
                # For tasks, automatically enable reminders if time is detected
                due_time = data.get("due_time")
                reminder_enabled = True if due_time else False
                reminder_mins = 30 if due_time else None
                
                # Check for existing reminder fields in AI data, but override with our 30-min logic
                # if user specifically asked for something else in voice, AI might have it
                # but following user request: "send notification that this task comes after 30 minutes"
                
                insert_q = """
                    INSERT INTO tasks (user_id, title, description, original_input, priority, 
                                     category, due_date, due_time, ai_generated, 
                                     reminder_enabled, reminder_minutes_before)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """
                task_id = Database.execute_query(
                    insert_q,
                    (user_id, data.get("title"), data.get("description"), transcription_text,
                     data.get("priority", "medium"), data.get("category", "general"),
                     data.get("due_date"), due_time, True, 
                     reminder_enabled, reminder_mins)
                )
                
                # Fetch and add to created items
                fetch_q = "SELECT * FROM tasks WHERE task_id = %s"
                task = Database.execute_query(fetch_q, (task_id,), fetch=True)[0]
                # Convert due_time and start_time
                if task.get('due_time') and isinstance(task['due_time'], timedelta):
                    total_seconds = int(task['due_time'].total_seconds())
                    task['due_time'] = time(hour=total_seconds // 3600, minute=(total_seconds % 3600) // 60)
                if task.get('start_time') and isinstance(task['start_time'], timedelta):
                    total_seconds = int(task['start_time'].total_seconds())
                    task['start_time'] = time(hour=total_seconds // 3600, minute=(total_seconds % 3600) // 60)
                items_created["tasks"].append(task)
                
            elif intent == "goal":
                insert_q = """
                    INSERT INTO goals (user_id, title, description, category, target_date, is_smart)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """
                goal_id = Database.execute_query(
                    insert_q,
                    (user_id, data.get("title"), data.get("description"),
                     data.get("category", "general"), data.get("target_date"),
                     data.get("is_smart", False))
                )
                fetch_q = "SELECT * FROM goals WHERE goal_id = %s"
                goal = Database.execute_query(fetch_q, (goal_id,), fetch=True)[0]
                items_created["goals"].append(goal)
                
            elif intent == "habit":
                insert_q = """
                    INSERT INTO habits (user_id, name, description, category, frequency, target_count)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """
                habit_id = Database.execute_query(
                    insert_q,
                    (user_id, data.get("name"), data.get("description"),
                     data.get("category", "general"), data.get("frequency", "daily"),
                     data.get("target_count", 1))
                )
                fetch_q = "SELECT * FROM habits WHERE habit_id = %s"
                habit = Database.execute_query(fetch_q, (habit_id,), fetch=True)[0]
                items_created["habits"].append(habit)

            elif intent == "bad_habit":
                # Handle app limits (Bad Habits)
                app_name = data.get("app_name")
                package_name = data.get("package_name")
                limit_mins = data.get("daily_limit_minutes", 30)

                # Try to guess package name if missing
                if not package_name and app_name:
                    package_name = f"com.{app_name.lower().replace(' ', '')}.android"

                # Check if already tracking
                check_q = "SELECT id FROM bad_habit_apps WHERE user_id=%s AND package_name=%s"
                existing = Database.execute_query(check_q, (user_id, package_name), fetch=True)
                
                if not existing:
                    insert_q = """
                        INSERT INTO bad_habit_apps (user_id, app_name, package_name, daily_limit_minutes)
                        VALUES (%s, %s, %s, %s)
                    """
                    new_id = Database.execute_query(
                        insert_q,
                        (user_id, app_name, package_name, limit_mins)
                    )
                    fetch_q = "SELECT * FROM bad_habit_apps WHERE id = %s"
                    bad_habit = Database.execute_query(fetch_q, (new_id,), fetch=True)[0]
                    if "bad_habits" not in items_created:
                        items_created["bad_habits"] = []
                    items_created["bad_habits"].append(bad_habit)

        # Build response
        response = {
            "items_created": items_created,
            "total_count": sum(len(v) for v in items_created.values()),
            "transcription": transcription_text,
            "language": detected_language,
            "message": f"Successfully processed voice command and created {sum(len(v) for v in items_created.values())} items."
        }
        return response

    except Exception as e:
        logger.error(f"Voice process endpoint error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)




# ============================================================================
# BAD HABIT / SCREEN TIME TRACKING ENDPOINTS
# ============================================================================

@app.post("/api/bad-habits/apps", response_model=BadHabitAppResponse)
async def add_bad_habit_app(
    app_data: BadHabitAppCreate,
    current_user: dict = Depends(get_current_user)
):
    """Add an app to track for screen time / bad habit management"""
    try:
        user_id = current_user['user_id']

        # Check if already tracking this package
        check_q = "SELECT id FROM bad_habit_apps WHERE user_id=%s AND package_name=%s"
        existing = Database.execute_query(check_q, (user_id, app_data.package_name), fetch=True)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You are already tracking this app"
            )

        insert_q = """
            INSERT INTO bad_habit_apps (user_id, app_name, package_name, daily_limit_minutes)
            VALUES (%s, %s, %s, %s)
        """
        new_id = Database.execute_query(
            insert_q,
            (user_id, app_data.app_name, app_data.package_name, app_data.daily_limit_minutes)
        )

        fetch_q = "SELECT * FROM bad_habit_apps WHERE id=%s"
        row = Database.execute_query(fetch_q, (new_id,), fetch=True)[0]
        return BadHabitAppResponse(**row)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Add bad habit app error: {e}")
        raise HTTPException(status_code=500, detail="Failed to add app")


@app.get("/api/bad-habits/apps", response_model=List[BadHabitAppResponse])
async def list_bad_habit_apps(current_user: dict = Depends(get_current_user)):
    """List all tracked apps for the current user"""
    try:
        q = "SELECT * FROM bad_habit_apps WHERE user_id=%s ORDER BY created_at DESC"
        rows = Database.execute_query(q, (current_user['user_id'],), fetch=True)
        return [BadHabitAppResponse(**r) for r in rows]
    except Exception as e:
        logger.error(f"List bad habit apps error: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch apps")


@app.put("/api/bad-habits/apps/{app_id}", response_model=BadHabitAppResponse)
async def update_bad_habit_app(
    app_id: int,
    update_data: BadHabitAppUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update daily limit or active status of a tracked app"""
    try:
        user_id = current_user['user_id']
        updates, params = [], []

        if update_data.daily_limit_minutes is not None:
            updates.append("daily_limit_minutes=%s")
            params.append(update_data.daily_limit_minutes)
        if update_data.is_active is not None:
            updates.append("is_active=%s")
            params.append(update_data.is_active)

        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")

        params.extend([app_id, user_id])
        Database.execute_query(
            f"UPDATE bad_habit_apps SET {', '.join(updates)} WHERE id=%s AND user_id=%s",
            tuple(params)
        )

        row = Database.execute_query(
            "SELECT * FROM bad_habit_apps WHERE id=%s AND user_id=%s",
            (app_id, user_id), fetch=True
        )
        if not row:
            raise HTTPException(status_code=404, detail="App not found")
        return BadHabitAppResponse(**row[0])

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update bad habit app error: {e}")
        raise HTTPException(status_code=500, detail="Failed to update app")


@app.delete("/api/bad-habits/apps/{app_id}", response_model=MessageResponse)
async def delete_bad_habit_app(
    app_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Remove an app from tracking"""
    try:
        Database.execute_query(
            "DELETE FROM bad_habit_apps WHERE id=%s AND user_id=%s",
            (app_id, current_user['user_id'])
        )
        return MessageResponse(message="App removed from tracking")
    except Exception as e:
        logger.error(f"Delete bad habit app error: {e}")
        raise HTTPException(status_code=500, detail="Failed to remove app")


@app.post("/api/bad-habits/log-usage", response_model=MessageResponse)
async def log_app_usage(
    log_data: UsageLogCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    Called by the Flutter WorkManager background task.
    Logs today's usage for a tracked app and checks if limit is exceeded.
    Uses INSERT ... ON DUPLICATE KEY UPDATE so it's safe to call repeatedly.
    """
    try:
        user_id = current_user['user_id']
        log_date = log_data.usage_date or date.today()

        # Fetch the daily limit for this app
        app_row = Database.execute_query(
            "SELECT daily_limit_minutes FROM bad_habit_apps WHERE user_id=%s AND package_name=%s AND is_active=TRUE",
            (user_id, log_data.package_name), fetch=True
        )
        if not app_row:
            raise HTTPException(status_code=404, detail="App not tracked or inactive")

        daily_limit = app_row[0]['daily_limit_minutes']
        limit_exceeded = log_data.minutes_used >= daily_limit

        # Upsert: insert or update if already logged today
        upsert_q = """
            INSERT INTO app_usage_logs (user_id, package_name, usage_date, minutes_used, limit_exceeded)
            VALUES (%s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                minutes_used = VALUES(minutes_used),
                limit_exceeded = VALUES(limit_exceeded)
        """
        Database.execute_query(
            upsert_q,
            (user_id, log_data.package_name, log_date, log_data.minutes_used, limit_exceeded)
        )

        return MessageResponse(
            message="Usage logged",
            data={"limit_exceeded": limit_exceeded, "daily_limit_minutes": daily_limit}
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Log usage error: {e}")
        raise HTTPException(status_code=500, detail="Failed to log usage")


@app.get("/api/bad-habits/usage-today")
async def get_today_usage(current_user: dict = Depends(get_current_user)):
    """
    Returns today's usage for all tracked apps, enriched with limit info.
    This is the main data source for the Digital tab UI.
    """
    try:
        user_id = current_user['user_id']
        today = date.today()

        query = """
            SELECT
                bha.id,
                bha.app_name,
                bha.package_name,
                bha.daily_limit_minutes,
                bha.is_active,
                COALESCE(aul.minutes_used, 0) AS minutes_used,
                COALESCE(aul.limit_exceeded, FALSE) AS limit_exceeded
            FROM bad_habit_apps bha
            LEFT JOIN app_usage_logs aul
                ON bha.user_id = aul.user_id
                AND bha.package_name = aul.package_name
                AND aul.usage_date = %s
            WHERE bha.user_id = %s AND bha.is_active = TRUE
            ORDER BY bha.created_at DESC
        """
        rows = Database.execute_query(query, (today, user_id), fetch=True)

        result = []
        for r in rows:
            usage_pct = min(100, round((r['minutes_used'] / r['daily_limit_minutes']) * 100))
            result.append({
                "id": r['id'],
                "app_name": r['app_name'],
                "package_name": r['package_name'],
                "daily_limit_minutes": r['daily_limit_minutes'],
                "minutes_used": r['minutes_used'],
                "minutes_remaining": max(0, r['daily_limit_minutes'] - r['minutes_used']),
                "usage_percentage": usage_pct,
                "limit_exceeded": bool(r['limit_exceeded']),
            })

        return {"date": str(today), "apps": result}

    except Exception as e:
        logger.error(f"Get today usage error: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch usage data")


@app.get("/api/bad-habits/streak")
async def get_clean_streak(current_user: dict = Depends(get_current_user)):
    """
    'Clean day' = a day where all tracked apps stayed under their limit.
    Returns the current consecutive clean streak and total clean days.
    """
    try:
        user_id = current_user['user_id']

        # Get all days that had at least one limit_exceeded = TRUE
        exceeded_q = """
            SELECT DISTINCT usage_date
            FROM app_usage_logs
            WHERE user_id=%s AND limit_exceeded=TRUE
            ORDER BY usage_date DESC
        """
        exceeded_dates = {
            r['usage_date']
            for r in Database.execute_query(exceeded_q, (user_id,), fetch=True)
        }

        # Get all distinct logged dates
        all_dates_q = """
            SELECT DISTINCT usage_date
            FROM app_usage_logs
            WHERE user_id=%s
            ORDER BY usage_date DESC
        """
        all_dates = [
            r['usage_date']
            for r in Database.execute_query(all_dates_q, (user_id,), fetch=True)
        ]

        # Count current consecutive clean streak from today backward
        current_streak_count: int = 0
        check_date = date.today()
        for d in all_dates:
            if d != check_date:
                break
            if d not in exceeded_dates:
                current_streak_count += 1  # type: ignore
                check_date = d - timedelta(days=1)
            else:
                break

        total_clean = sum(1 for d in all_dates if d not in exceeded_dates)

        return {
            "current_streak": current_streak_count,
            "total_clean_days": total_clean,
            "total_logged_days": len(all_dates),
        }

    except Exception as e:
        logger.error(f"Get streak error: {e}")
        raise HTTPException(status_code=500, detail="Failed to calculate streak")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
