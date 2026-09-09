# AI Planner - Quick Start Guide

Get your AI-powered daily planner running in **10 minutes**! ⚡

## Prerequisites Checklist
- [ ] XAMPP installed and MySQL running
- [ ] Python 3.9+ installed
- [ ] Flutter SDK installed
- [ ] VS Code or any code editor

## 🚀 Setup Steps

### 1. Database Setup (5 minutes)

1. **Start XAMPP** and ensure MySQL is running
2. Open **phpMyAdmin**: http://localhost/phpmyadmin
3. Click **"New"** to create a database
4. Name it: `ai_planner_db`
5. Click on the database
6. Go to **"SQL"** tab
7. Copy entire contents of `database_setup.sql`
8. Paste and click **"Go"**
9. ✅ You should see **"11 tables created"**
10. (Optional) Run `add_energy_level.sql` for energy tracking feature

### 2. Backend Setup (2 minutes)

**Option A - Automated (Recommended):**
```bash
# Double-click this file:
setup_backend.bat
```

**Option B - Manual:**
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

✅ **Verify**: Open http://localhost:8000 
- You should see: `{"app":"AI-Powered Daily Planner","version":"1.0.0","status":"running"}`
- API Docs: http://localhost:8000/docs

### 3. Frontend Setup (2 minutes)

**Option A - Automated (Recommended):**
```bash
# Double-click this file:
setup_frontend.bat
```

**Option B - Manual:**
```bash
cd frontend_app
flutter pub get
flutter run
```

✅ **Verify**: App should launch on your emulator/device

## 📱 Test the App

### Quick Test Flow

1. **Launch App** → See beautiful splash screen with "AI Planner"
2. **Click "Next"** → Go to login screen
3. **Click "Sign Up"**
4. **Fill registration form:**
   - Full Name: Your Name
   - Phone: +1234567890 (or any number)
   - Password: Test@123 (min 8 chars)
5. **Get verification code** (displayed on screen for development)
6. **Enter code** → Automatically logged in
7. **Explore the Dashboard!**

### Test with Pre-created Account
- **Phone**: `+1234567890`
- **Password**: `Test@123`

## ✨ Features to Try

### 📋 Tasks
1. Go to **Tasks** tab
2. Click **"+"** button
3. Enter task: "Buy groceries tomorrow"
4. See task dashboard with stats
5. Mark tasks as complete
6. Swipe to delete

### 🎯 Habits
1. Go to **Habits** tab
2. Click **"+"** button
3. Create habit: "Morning exercise"
4. Mark as complete daily
5. Watch your streak grow!
6. See motivational quotes

### 🏆 Goals
1. Go to **Goals** tab
2. Click **"+"** button
3. Enter goal: "Learn Flutter"
4. AI breaks it into subtasks
5. Check off subtasks
6. Track progress

### 😊 Mood Tracking
1. Go to **Mood** tab
2. Select your mood (happy, neutral, sad, stressed, excited)
3. Rate your energy level
4. View mood history
5. Get AI insights

### 📊 Insights
1. Go to **Insights** tab
2. View AI-generated recommendations
3. See mood correlations
4. Get productivity tips
5. Refresh insights anytime

### 📅 Calendar
1. Go to **Calendar** tab
2. See all tasks, habits, and goals
3. Click on any date
4. View events for that day

### 👤 Profile
1. Open drawer menu
2. Click **Edit** icon
3. Update your name
4. Upload profile picture
5. See changes across the app

## ✅ Verify Everything Works

### Backend Check
- [ ] http://localhost:8000 shows app info
- [ ] http://localhost:8000/docs shows Swagger UI
- [ ] http://localhost:8000/health shows database connected
- [ ] Backend terminal shows "Application startup complete"

### Frontend Check
- [ ] App launches without errors
- [ ] Can navigate between all tabs
- [ ] Login/signup works
- [ ] Dashboard displays stats
- [ ] Can create tasks, habits, goals
- [ ] Profile picture upload works

### Database Check
- [ ] phpMyAdmin shows `ai_planner_db`
- [ ] 11 tables visible (users, tasks, habits, goals, moods, etc.)
- [ ] Test user exists in users table
- [ ] Data appears when you create items

## 🐛 Common Issues & Fixes

### "Database connection error"
**Fix**: Start MySQL in XAMPP Control Panel

### "Port 8000 already in use"
**Fix**: 
```bash
# Find and kill the process
netstat -ano | findstr :8000
taskkill /PID <process_id> /F
```

### "Module not found" (Backend)
**Fix**: 
```bash
cd backend
venv\Scripts\activate
pip install -r requirements.txt
```

### "Flutter command not found"
**Fix**: Install Flutter SDK and add to PATH
- Download: https://flutter.dev
- Add to PATH: `C:\flutter\bin`

### "Package errors" (Frontend)
**Fix**:
```bash
cd frontend_app
flutter clean
flutter pub get
```

### Profile picture not showing
**Fix**: 
- Check `backend/uploads/profile_pictures/` folder exists
- Re-login to the app
- Try uploading again

### Insights not updating
**Fix**: Click "Refresh Insights" button in Insights screen

## 🎯 Next Steps

1. ✅ **Explore all features** - Tasks, Habits, Goals, Mood, Insights, Calendar
2. ✅ **Test AI features** - Create tasks with natural language
3. ✅ **Upload profile picture** - Personalize your account
4. ✅ **Track your mood** - Get AI-powered insights
5. ✅ **Set goals** - Let AI break them down
6. 📖 **Read README.md** - Full feature documentation
7. 🔧 **Check API docs** - http://localhost:8000/docs

## 📊 What You Get

### Core Features
- ✅ Task management with dashboard
- ✅ Habit tracking with streaks
- ✅ Goal setting with AI decomposition
- ✅ Mood & energy logging
- ✅ AI-powered insights
- ✅ Calendar view
- ✅ Profile management
- ✅ Profile picture upload

### AI Features
- ✅ Natural language task parsing
- ✅ Smart goal decomposition
- ✅ Mood pattern analysis
- ✅ Personalized recommendations
- ✅ Productivity insights

### UI/UX
- ✅ Modern gradient design
- ✅ Smooth animations
- ✅ Responsive layout
- ✅ Intuitive navigation
- ✅ Beautiful dashboards

## 📞 Support

### Getting Help
- **Backend logs**: Check terminal running `python main.py`
- **Frontend logs**: Check terminal running `flutter run`
- **Database**: Check phpMyAdmin at http://localhost/phpmyadmin
- **API docs**: http://localhost:8000/docs
- **Full documentation**: See README.md

### Useful Commands

**Backend:**
```bash
cd backend
venv\Scripts\activate
python main.py
```

**Frontend:**
```bash
cd frontend_app
flutter run
flutter clean  # If issues occur
flutter pub get
```

**Database:**
- Access: http://localhost/phpmyadmin
- Database: `ai_planner_db`
- User: `root`
- Password: (empty)

## 🎉 You're All Set!

Your **AI Planner** is now running! Start organizing your life with AI-powered insights.

---

**Total setup time: ~10 minutes** ⚡

**Tech Stack**: Flutter • FastAPI • MySQL • Google Gemini AI

**Version**: 1.0.0
