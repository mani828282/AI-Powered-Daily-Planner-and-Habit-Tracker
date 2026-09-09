# 📐 System Architecture: AI-Powered Daily Planner and Habit Tracker

This document provides an overview of the system architecture, design decisions, and data flow for the **AI-Powered Daily Planner and Habit Tracker** project.

---

## 1. High-Level Architecture

The system is built as a modular client-server application consisting of three main layers:

```
┌────────────────────────────────────────────────────────┐
│               1. Frontend (Flutter)                    │
│   - Cross-Platform UI (Android, iOS, Web)              │
│   - Provider State Management                          │
│   - Voice Input & Audio Recording                      │
└───────────────────────────┬────────────────────────────┘
                            │ REST API (JSON / HTTPS)
                            ▼
┌────────────────────────────────────────────────────────┐
│               2. Backend (FastAPI)                     │
│   - Asynchronous Request Handling                      │
│   - JWT User Authentication & Security                 │
│   - AI & NLP Service (Task & Goal Parsing)             │
│   - Correlation Service (Mood vs Habit Analysis)       │
│   - Voice Processing Service (Audio to Text)           │
└───────────────────────────┬────────────────────────────┘
                            │ SQL Queries / Pooling
                            ▼
┌────────────────────────────────────────────────────────┐
│               3. Database (MySQL)                      │
│   - Normalized Relational Tables                       │
│   - Foreign Key Constraints & Data Integrity           │
│   - Indexed Search on Users, Dates, and Tasks          │
└────────────────────────────────────────────────────────┘
```

---

## 2. Core Modules & Data Flow

### 2.1 Natural Language Processing (NLP) Module
* **How it works**: When a user inputs natural text like *"Submit final project report by Thursday at 2 PM with urgent priority"*, the backend NLP service parses the sentence:
  1. Identifies the action and subject (`title`: "Submit final project report").
  2. Extracts temporal terms (`due_date`: current week Thursday 14:00).
  3. Maps importance keywords to standard levels (`priority`: "High").
  4. Categorizes the activity (`category`: "Academic" or "Work").
* **Result**: Returns a structured JSON object directly saved to the database.

### 2.2 Voice Input (Speech-to-Intent)
* **How it works**: 
  1. The Flutter mobile/web client captures voice audio via the device microphone.
  2. The audio buffer is sent to the backend `/api/voice/process-voice-command` endpoint.
  3. The voice service transcribes the speech into text and routes it to the NLP parser.
  4. Automatically executes the action (creates a task, logs a mood, or marks a habit complete).

### 2.3 Habit & Mood Correlation Engine
* **How it works**:
  1. Retrieves the user's logged moods and energy levels (rated 1 to 5) over the past 30 days.
  2. Cross-references this data with habit completion timestamps.
  3. Calculates the completion percentage for habits on high-energy days vs. low-energy days.
  4. Identifies positive patterns to provide motivational insights and personalized tips.

### 2.4 Goal Decomposition
* **How it works**:
  1. The user creates a high-level goal (e.g., *"Learn Flutter App Development"*).
  2. The system breaks down the goal into 3 to 6 logical subtasks.
  3. The user can check off subtasks individually, and the progress bar updates automatically.

---

## 3. Database Schema Overview

The database uses a clean relational structure:

* **`users`**: Stores user authentication details, hashed passwords, phone numbers, and profile info.
* **`tasks`**: Stores individual tasks with priority, status (`pending`, `completed`), due dates, and categories.
* **`habits`**: Tracks habits, frequencies (daily/weekly), target days, and active flags.
* **`habit_completions`**: Junction table recording every time a habit is marked complete on a specific date.
* **`goals` & `goal_subtasks`**: One-to-many relationship tracking parent goals and their subtasks.
* **`mood_logs`**: Records daily user mood labels and energy scores (1-5) with timestamps.

---

## 4. Security & Best Practices

* **Password Security**: Passwords are never stored in plain text; they are encrypted using industry-standard hashing algorithms (Bcrypt).
* **Stateless Authentication**: Uses JSON Web Tokens (JWT) signed with HMAC-SHA256 for secure, stateless user sessions.
* **Input Validation**: All incoming requests are validated with strict Pydantic schemas to prevent malformed data and injection attacks.
* **Environment Configuration**: Database credentials and sensitive keys are managed via environment variables (`.env`).
