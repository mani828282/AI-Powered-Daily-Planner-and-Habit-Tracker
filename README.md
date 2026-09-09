# AI Planner - Intelligent Daily Companion

A comprehensive mobile application with AI-powered features for task management, habit tracking, goal setting, mood logging, and intelligent insights. Built with Flutter frontend, FastAPI backend, MySQL database, and Google Gemini AI integration.

## 🌟 Features

### 📋 Task Management
- **Smart Task Creation**: Create tasks with natural language input
- **AI-Powered Organization**: Automatic task prioritization and categorization
- **Task Dashboard**: Quick overview of total, pending, and completed tasks
- **Flexible Filtering**: Filter tasks by status (all, pending, completed)
- **Due Dates & Reminders**: Set deadlines and get notified
- **Priority Levels**: High, medium, and low priority tasks
- **Categories**: Organize tasks by custom categories
- **Delete Tasks**: Swipe to delete unwanted tasks

### 🎯 Habit Tracking
- **Habit Creation**: Build positive habits with AI-structured plans
- **Streak Tracking**: Monitor your consistency with visual streak indicators
- **Daily Completion**: Mark habits as complete each day
- **Progress Dashboard**: View total habits, active streaks, and longest streak
- **Motivational Quotes**: Get inspired with context-aware quotes
- **Milestone Celebrations**: Celebrate 7-day, 30-day, and 100-day streaks
- **Habit Analytics**: Track completion rates and patterns
- **Delete Habits**: Remove habits you no longer need

### 🏆 Goal Management
- **AI Goal Decomposition**: Break down big goals into actionable subtasks
- **Progress Tracking**: Visual progress bars for each goal
- **Goal Categories**: Personal, career, health, and more
- **Subtask Management**: Check off subtasks as you complete them
- **Goal Dashboard**: Overview of total, in-progress, and completed goals
- **Target Dates**: Set deadlines for your goals
- **Delete Goals**: Remove goals and their subtasks

### 😊 Mood & Energy Tracking
- **Daily Mood Logging**: Track your emotional state (happy, neutral, sad, stressed, excited)
- **Energy Level Tracking**: Monitor your energy throughout the day
- **Mood History**: View past mood logs with timestamps
- **AI-Powered Insights**: Get personalized insights based on mood patterns
- **Mood Correlations**: Discover connections between moods and activities
- **Delete Mood Logs**: Remove unwanted mood entries
- **Smart Insights Cache**: Efficient data loading with automatic refresh

### 📊 Analytics & Insights
- **Dashboard Overview**: Comprehensive view of all your data
- **Smart Insights**: AI-generated recommendations and patterns
- **Calendar View**: See all your tasks, habits, and goals in one calendar
- **Progress Stats**: Track your productivity metrics
- **Trend Analysis**: Understand your productivity patterns

### 👤 User Profile
- **Profile Management**: Update your name and personal information
- **Profile Picture Upload**: Add and update your profile photo
- **Cross-Platform Support**: Works on web, Android, and iOS
- **Image Persistence**: Profile pictures saved across sessions
- **Secure Authentication**: Phone number-based login system

### 🎨 Premium UI/UX
- **Modern Design**: Beautiful gradient-based interface
- **Smooth Animations**: Polished transitions and micro-interactions
- **Dark Mode Ready**: Eye-friendly color scheme
- **Responsive Layout**: Adapts to different screen sizes
- **Intuitive Navigation**: Easy-to-use bottom navigation
- **Loading States**: Clear feedback during data operations

## 📋 Prerequisites

### Required Software
- **Python 3.9+** - Backend development
- **Flutter SDK 3.0+** - Frontend development
- **MySQL 8.0+** - Database (via XAMPP/phpMyAdmin)
- **VS Code** (recommended) - Development environment

### API Keys
- Google Gemini API key (configured in backend)

## 🚀 Quick Start

### Option 1: Using Setup Scripts (Windows)

1. **Start Database**:
   - Open XAMPP
   - Start MySQL service
   - Import `database_setup.sql` in phpMyAdmin

2. **Run Backend**:
   ```bash
   # Double-click or run:
   setup_backend.bat
   ```

3. **Run Frontend**:
   ```bash
   # Double-click or run:
   setup_frontend.bat
   ```

### Option 2: Manual Setup

#### 1. Database Setup

1. Start XAMPP and ensure MySQL is running
2. Open phpMyAdmin (http://localhost/phpmyadmin)
3. Create a new database named `ai_planner_db`
4. Import `database_setup.sql`
5. (Optional) Run `add_energy_level.sql` for energy tracking feature

#### 2. Backend Setup (FastAPI)

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Mac/Linux
source venv/bin/activate

pip install -r requirements.txt
python main.py
```

Backend will run on: http://localhost:8000
API Docs: http://localhost:8000/docs

#### 3. Frontend Setup (Flutter)

```bash
cd frontend_app
flutter pub get
flutter run
```

## 📱 Using the Application

### First Time Setup

1. **Sign Up**:
   - Open the app
   - Click "Sign Up"
   - Enter your phone number and full name
   - Create a password
   - Verify your phone (code displayed on screen for development)

2. **Login**:
   - Enter your phone number
   - Enter your password
   - You're in!

### Test Account
- **Phone**: `+1234567890`
- **Password**: `Test@123`

### Main Features

1. **Dashboard**: Overview of all your data
2. **Tasks**: Manage your to-do list
3. **Habits**: Track daily habits
4. **Goals**: Set and achieve long-term goals
5. **Mood**: Log your emotional state
6. **Insights**: Get AI-powered recommendations
7. **Calendar**: See everything in one view
8. **Profile**: Manage your account

## 🏗️ Project Structure

```
habit/
├── backend/                    # FastAPI Backend
│   ├── main.py                # Main application with all endpoints
│   ├── config.py              # Configuration management
│   ├── database.py            # Database connection
│   ├── auth.py                # Authentication utilities
│   ├── ai_service.py          # Google Gemini AI integration
│   ├── models.py              # Pydantic models
│   └── requirements.txt       # Python dependencies
│
├── frontend_app/              # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart         # App entry point
│   │   ├── config/
│   │   │   ├── theme.dart    # App theme and colors
│   │   │   └── api_config.dart
│   │   ├── models/           # Data models
│   │   │   ├── task.dart
│   │   │   ├── habit.dart
│   │   │   ├── goal.dart
│   │   │   └── mood.dart
│   │   ├── services/         # API services
│   │   │   ├── auth_service.dart
│   │   │   ├── task_service.dart
│   │   │   ├── habit_service.dart
│   │   │   ├── goal_service.dart
│   │   │   ├── mood_service.dart
│   │   │   └── calendar_service.dart
│   │   └── screens/          # UI screens
│   │       ├── auth/         # Login, signup, splash
│   │       ├── dashboard/    # Main dashboard
│   │       ├── tasks/        # Task management
│   │       ├── habits/       # Habit tracking
│   │       ├── goals/        # Goal management
│   │       ├── mood/         # Mood logging
│   │       ├── insights/     # AI insights
│   │       ├── calendar/     # Calendar view
│   │       └── profile/      # User profile
│   └── pubspec.yaml         # Flutter dependencies
│
├── database_setup.sql        # MySQL database schema
├── add_energy_level.sql      # Energy level feature migration
├── setup_backend.bat         # Backend quick start script
├── setup_frontend.bat        # Frontend quick start script
├── README.md                 # This file
└── QUICKSTART.md            # Quick setup guide
```

## 🔌 API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/verify-phone` - Verify phone number
- `POST /api/auth/login` - User login
- `POST /api/auth/profile-picture` - Upload profile picture
- `PUT /api/auth/profile` - Update profile information

### Tasks
- `POST /api/tasks/create` - Create task
- `GET /api/tasks/list` - Get user tasks
- `PUT /api/tasks/{task_id}` - Update task
- `DELETE /api/tasks/{task_id}` - Delete task
- `PUT /api/tasks/{task_id}/status` - Update task status

### Habits
- `POST /api/habits/create` - Create habit
- `GET /api/habits/list` - Get user habits
- `POST /api/habits/complete` - Mark habit complete
- `GET /api/habits/streaks` - Get habit streaks
- `DELETE /api/habits/{habit_id}` - Delete habit

### Goals
- `POST /api/goals/create` - Create goal with AI decomposition
- `GET /api/goals/list` - Get user goals
- `PUT /api/goals/{goal_id}` - Update goal
- `DELETE /api/goals/{goal_id}` - Delete goal
- `PUT /api/goals/{goal_id}/subtask/{subtask_id}` - Update subtask

### Mood & Analytics
- `POST /api/mood/log` - Log mood and energy
- `GET /api/mood/list` - Get mood history
- `DELETE /api/mood/{mood_id}` - Delete mood log
- `GET /api/mood/insights` - Get AI mood insights
- `POST /api/mood/refresh-correlations` - Refresh insights cache
- `GET /api/analytics/dashboard` - Dashboard data

### Calendar
- `GET /api/calendar/events` - Get all calendar events (tasks, habits, goals, moods)

## 🤖 AI Features

All AI features are powered by Google Gemini API:

1. **Natural Language Processing**: Understands context and intent
2. **Smart Task Creation**: Extracts details from natural language
3. **Habit Recommendations**: Suggests optimal habits based on goals
4. **Goal Decomposition**: Breaks down complex goals into steps
5. **Mood Insights**: Analyzes patterns and provides recommendations
6. **Predictive Analytics**: Forecasts productivity trends
7. **Contextual Suggestions**: Personalized tips and advice

## 🛠️ Development

### Running in Development Mode

**Backend:**
```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Frontend:**
```bash
cd frontend_app
flutter run
```

### Code Quality

- **Flutter Analyze**: All warnings fixed
- **Clean Code**: No unused variables or methods
- **Type Safety**: Proper null handling
- **Error Handling**: Comprehensive error messages

### Database Management
- Access phpMyAdmin: http://localhost/phpmyadmin
- Database name: `ai_planner_db`
- Default user: `root`
- Default password: (empty)

## 🐛 Troubleshooting

### Backend Issues
- **Database connection error**: Ensure MySQL is running in XAMPP
- **Module not found**: Run `pip install -r requirements.txt`
- **Port already in use**: Change port in `main.py` or kill the process using `netstat -ano | findstr :8000`

### Frontend Issues
- **Package errors**: Run `flutter pub get`
- **Build errors**: Run `flutter clean` then `flutter pub get`
- **Connection refused**: Ensure backend is running on localhost:8000
- **Image upload errors**: Check file size and format (JPEG/PNG)

### Common Issues
- **Profile picture not showing**: Clear app data and re-login
- **Insights not updating**: Use "Refresh Insights" button in Insights screen
- **Calendar not loading**: Check if backend is running and database has data

## 📝 Notes

- The app name is **AI Planner** across all platforms (web, Android, iOS)
- Verification codes are displayed on screen during development
- JWT tokens are used for authentication
- Profile pictures are stored in `backend/uploads/profile_pictures/`
- All timestamps are in UTC

## 🔮 Future Enhancements

### Planned Features
- WhatsApp integration via n8n
- Voice commands for task creation
- Team collaboration features
- Calendar sync (Google Calendar, Outlook)
- Wearable device integration
- Advanced analytics dashboards
- Custom AI prompts
- Export data to PDF/CSV
- Recurring tasks and habits
- Habit reminders and notifications

## 📄 License

This project is for educational and development purposes.

## 👥 Contributors

Built with ❤️ by the development team.

## 📞 Support

For issues or questions:
1. Check the API documentation at http://localhost:8000/docs
2. Review the database schema in `database_setup.sql`
3. Check backend logs for error messages
4. See `QUICKSTART.md` for quick setup guide
vercel
1
---

**Tech Stack**: Flutter • FastAPI • MySQL • Google Gemini AI

**Version**: 1.0.0

**Last Updated**: February 2026
