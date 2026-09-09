from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List, Dict, Any
from datetime import datetime, date, time
from enum import Enum

# Enums
class PriorityEnum(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"

class TaskStatusEnum(str, Enum):
    pending = "pending"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"

class FrequencyEnum(str, Enum):
    daily = "daily"
    weekly = "weekly"
    custom = "custom"

class MoodEnum(str, Enum):
    very_bad = "very_bad"
    bad = "bad"
    neutral = "neutral"
    good = "good"
    very_good = "very_good"

class GoalStatusEnum(str, Enum):
    active = "active"
    completed = "completed"
    abandoned = "abandoned"

# Auth Models
class UserRegister(BaseModel):
    phone_number: str
    email: Optional[EmailStr] = None
    full_name: str
    password: str = Field(min_length=6)

class PhoneVerification(BaseModel):
    phone_number: str
    verification_code: str

class UserLogin(BaseModel):
    phone_number: str
    password: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6)

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    phone_number: str
    full_name: str
    profile_picture: Optional[str] = None

class SupportRequest(BaseModel):
    subject: str
    message: str
    email: EmailStr

# Task Models
class TaskCreate(BaseModel):
    user_input: Optional[str] = None  # Natural language input
    # Or structured input
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[PriorityEnum] = None
    category: Optional[str] = None
    due_date: Optional[date] = None
    due_time: Optional[time] = None
    # New mandatory date fields (enforced in UI)
    start_date: Optional[date] = None
    start_time: Optional[time] = None
    end_date: Optional[date] = None
    reminder_enabled: Optional[bool] = False
    reminder_minutes_before: Optional[int] = 30

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[PriorityEnum] = None
    status: Optional[TaskStatusEnum] = None
    category: Optional[str] = None
    due_date: Optional[date] = None
    due_time: Optional[time] = None
    start_date: Optional[date] = None
    start_time: Optional[time] = None
    end_date: Optional[date] = None
    reminder_enabled: Optional[bool] = None
    reminder_minutes_before: Optional[int] = None

class TaskResponse(BaseModel):
    task_id: int
    user_id: int
    title: str
    description: Optional[str]
    priority: str
    status: str
    category: Optional[str]
    due_date: Optional[date]
    due_time: Optional[time]
    start_date: Optional[date] = None
    start_time: Optional[time] = None
    end_date: Optional[date] = None
    reminder_enabled: Optional[bool] = False
    reminder_minutes_before: Optional[int] = 30
    ai_generated: bool
    ai_priority_score: Optional[float]
    created_at: datetime
    
    class Config:
        from_attributes = True

# Habit Models
class HabitCreate(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    frequency: FrequencyEnum = FrequencyEnum.daily
    frequency_details: Optional[Dict] = None
    target_count: int = 1
    reminder_enabled: Optional[bool] = False
    reminder_time: Optional[time] = None

class HabitUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    frequency: Optional[FrequencyEnum] = None
    frequency_details: Optional[Dict] = None
    target_count: Optional[int] = None
    reminder_enabled: Optional[bool] = None
    reminder_time: Optional[time] = None

class HabitResponse(BaseModel):
    habit_id: int
    user_id: int
    name: str
    description: Optional[str]
    category: Optional[str]
    frequency: str
    current_streak: int
    longest_streak: int
    total_completions: int
    reminder_enabled: Optional[bool] = False
    reminder_time: Optional[time] = None
    ai_suggested: bool
    created_at: datetime
    completed_today: bool = False
    
    class Config:
        from_attributes = True

class HabitCompletion(BaseModel):
    habit_id: int
    completion_date: Optional[date] = None
    notes: Optional[str] = None
    mood_at_completion: Optional[int] = Field(None, ge=1, le=5)  # 1-5 integer for mood
    energy_level: Optional[int] = Field(None, ge=1, le=5)  # 1-5 integer for energy

# Mood Models
class MoodLog(BaseModel):
    mood_level: int = Field(ge=1, le=5)  # Changed from MoodEnum to int
    energy_level: int = Field(ge=1, le=10)
    notes: Optional[str] = None
    activities: Optional[List[str]] = None

class MoodResponse(BaseModel):
    mood_id: int
    user_id: int
    log_date: date
    mood_level: int  # Changed from str to int
    energy_level: int
    notes: Optional[str] = None
    activities: Optional[str] = None  # JSON string from database
    ai_insights: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Analytics Models
class DailyReport(BaseModel):
    date: date
    tasks_completed: int
    total_tasks: int
    habits_completed: int
    total_habits: int
    completion_rate: float
    mood_average: Optional[str]
    energy_average: Optional[float]
    ai_summary: str
    streaks: List[Dict]

class WeeklyReport(BaseModel):
    week_start: date
    week_end: date
    total_tasks_completed: int
    total_habits_completed: int
    daily_breakdown: List[Dict]
    top_categories: List[Dict]
    ai_insights: str

class DashboardData(BaseModel):
    today_tasks: int
    today_habits: int
    active_streaks: int
    completion_rate: float
    recent_insights: List[Dict]
    upcoming_tasks: List[Dict]
    mood_trend: Optional[str]

# AI Request Models
class AIPrioritizeRequest(BaseModel):
    task_ids: Optional[List[int]] = None  # If None, prioritize all pending tasks

class AIHabitSuggestionRequest(BaseModel):
    goals: Optional[List[str]] = None
    interests: Optional[List[str]] = None

# n8n Webhook Models
class WhatsAppMessage(BaseModel):
    phone_number: str
    message: str
    timestamp: Optional[datetime] = None

class WebhookResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Dict] = None

# Generic Response
class MessageResponse(BaseModel):
    message: str
    success: bool = True
    data: Optional[Any] = None

# Correlation Models
class CorrelationInsight(BaseModel):
    type: str  # positive_correlation, negative_correlation, weekday_pattern, general
    habit_name: Optional[str]
    title: str
    message: str
    recommendation: str
    icon: str
    strength: str  # weak, moderate, strong

class CorrelationResponse(BaseModel):
    has_data: bool
    insights: List[CorrelationInsight]
    summary: str
    motivation: Optional[str]
    days_analyzed: int
    generated_at: str
    
    class Config:
        from_attributes = True

class SmartInsightsResponse(BaseModel):
    habit_correlations: List[Dict]
    weekday_patterns: Dict
    statistics: Dict
    ai_insights: Dict
    days_analyzed: int
    mood_logs_count: int
    total_habit_completions: int

# Goal Models
class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    description: Optional[str] = None
    category: Optional[str] = None
    target_date: Optional[date] = None
    # New mandatory date fields (enforced in UI)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    ai_decompose: bool = False

class GoalUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    target_date: Optional[date] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: Optional[GoalStatusEnum] = None

class SubtaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    description: Optional[str] = None
    order_index: Optional[int] = 0
    due_date: Optional[date] = None

class SubtaskResponse(BaseModel):
    subtask_id: int
    goal_id: int
    user_id: int
    title: str
    description: Optional[str]
    order_index: int
    status: str
    due_date: Optional[date]
    completed_at: Optional[datetime]
    created_at: datetime
    
    class Config:
        from_attributes = True

class GoalResponse(BaseModel):
    goal_id: int
    user_id: int
    title: str
    description: Optional[str]
    category: Optional[str]
    target_date: Optional[date]
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    status: str
    progress_percentage: float
    ai_decomposed: bool
    completed_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    # Computed fields for progress tracking
    total_subtasks: int = 0
    completed_subtasks: int = 0
    status_indicator: str = "on_track"  # on_track, falling_behind, ahead
    estimated_days_remaining: Optional[int] = None
    subtasks: Optional[List[Dict]] = []  # List of subtasks for this goal
    
    class Config:
        from_attributes = True

# ============================================================================
# BAD HABIT / SCREEN TIME TRACKING MODELS
# ============================================================================

class BadHabitAppCreate(BaseModel):
    app_name: str = Field(min_length=1, max_length=100)
    package_name: str = Field(min_length=1, max_length=200)
    daily_limit_minutes: int = Field(default=30, ge=1, le=720)

class BadHabitAppUpdate(BaseModel):
    daily_limit_minutes: Optional[int] = Field(None, ge=1, le=720)
    is_active: Optional[bool] = None

class BadHabitAppResponse(BaseModel):
    id: int
    user_id: int
    app_name: str
    package_name: str
    daily_limit_minutes: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class UsageLogCreate(BaseModel):
    package_name: str
    minutes_used: int = Field(ge=0)
    usage_date: Optional[date] = None  # defaults to today on server

class UsageLogResponse(BaseModel):
    id: int
    user_id: int
    package_name: str
    usage_date: date
    minutes_used: int
    limit_exceeded: bool
    created_at: datetime
    # Enriched fields joined from bad_habit_apps
    app_name: Optional[str] = None
    daily_limit_minutes: Optional[int] = None

    class Config:
        from_attributes = True

