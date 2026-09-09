-- AI-Powered Daily Planner & Habit Tracker Database Schema
-- Database: ai_planner_db

USE ai_planner_db;

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS whatsapp_logs;
DROP TABLE IF EXISTS analytics_cache;
DROP TABLE IF EXISTS reminders;
DROP TABLE IF EXISTS ai_insights;
DROP TABLE IF EXISTS habit_completions;
DROP TABLE IF EXISTS task_subtasks;
DROP TABLE IF EXISTS goals;
DROP TABLE IF EXISTS mood_logs;
DROP TABLE IF EXISTS habits;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS users;

-- Users Table
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    phone_verified BOOLEAN DEFAULT FALSE,
    verification_code VARCHAR(6),
    verification_expires DATETIME,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(255),
    password_hash VARCHAR(255) NOT NULL,
    profile_picture VARCHAR(500),
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_phone (phone_number),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tasks Table
CREATE TABLE tasks (
    task_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    original_input TEXT,
    priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
    status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    category VARCHAR(100),
    due_date DATE,
    due_time TIME,
    estimated_duration INT COMMENT 'Duration in minutes',
    ai_generated BOOLEAN DEFAULT FALSE,
    ai_priority_score DECIMAL(5,2),
    ai_tags JSON COMMENT 'AI-generated tags',
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_status (user_id, status),
    INDEX idx_due_date (due_date),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Habits Table
CREATE TABLE habits (
    habit_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    frequency ENUM('daily', 'weekly', 'custom') DEFAULT 'daily',
    frequency_details JSON COMMENT 'Days of week, times per week, etc.',
    target_count INT DEFAULT 1 COMMENT 'How many times per frequency period',
    reminder_time TIME,
    icon VARCHAR(50),
    color VARCHAR(20),
    ai_suggested BOOLEAN DEFAULT FALSE,
    ai_reason TEXT COMMENT 'Why AI suggested this habit',
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    total_completions INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_active (user_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Habit Completions Table
CREATE TABLE habit_completions (
    completion_id INT AUTO_INCREMENT PRIMARY KEY,
    habit_id INT NOT NULL,
    user_id INT NOT NULL,
    completion_date DATE NOT NULL,
    completion_time TIME,
    notes TEXT,
    mood_at_completion ENUM('very_bad', 'bad', 'neutral', 'good', 'very_good'),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (habit_id) REFERENCES habits(habit_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_habit_date (habit_id, completion_date),
    INDEX idx_user_date (user_id, completion_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mood Logs Table
CREATE TABLE mood_logs (
    mood_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    log_date DATE NOT NULL,
    log_time TIME,
    mood_level ENUM('very_bad', 'bad', 'neutral', 'good', 'very_good') NOT NULL,
    energy_level INT CHECK (energy_level BETWEEN 1 AND 10),
    notes TEXT,
    activities JSON COMMENT 'What user was doing',
    ai_insights TEXT COMMENT 'AI-generated insights about this mood',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_date (user_id, log_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Goals Table
CREATE TABLE goals (
    goal_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    target_date DATE,
    status ENUM('active', 'completed', 'abandoned') DEFAULT 'active',
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    ai_decomposed BOOLEAN DEFAULT FALSE,
    ai_milestones JSON COMMENT 'AI-generated milestones',
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Task Subtasks Table (for AI-decomposed goals)
CREATE TABLE task_subtasks (
    subtask_id INT AUTO_INCREMENT PRIMARY KEY,
    goal_id INT NOT NULL,
    user_id INT NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    order_index INT DEFAULT 0,
    status ENUM('pending', 'in_progress', 'completed') DEFAULT 'pending',
    due_date DATE,
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (goal_id) REFERENCES goals(goal_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_goal (goal_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- AI Insights Table
CREATE TABLE ai_insights (
    insight_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    insight_type ENUM('productivity', 'mood', 'habit', 'prediction', 'recommendation') NOT NULL,
    title VARCHAR(255),
    content TEXT NOT NULL,
    confidence_score DECIMAL(5,2) COMMENT 'AI confidence 0-100',
    related_entity_type ENUM('task', 'habit', 'goal', 'mood', 'general'),
    related_entity_id INT,
    metadata JSON COMMENT 'Additional AI metadata',
    is_read BOOLEAN DEFAULT FALSE,
    valid_until DATE COMMENT 'When this insight expires',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_type (user_id, insight_type),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reminders Table
CREATE TABLE reminders (
    reminder_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    entity_type ENUM('task', 'habit', 'goal') NOT NULL,
    entity_id INT NOT NULL,
    reminder_time DATETIME NOT NULL,
    message TEXT,
    is_sent BOOLEAN DEFAULT FALSE,
    ai_optimized BOOLEAN DEFAULT FALSE COMMENT 'Whether AI adjusted the time',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_time (user_id, reminder_time),
    INDEX idx_pending (is_sent, reminder_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Analytics Cache Table
CREATE TABLE analytics_cache (
    cache_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    cache_type ENUM('daily', 'weekly', 'monthly', 'custom') NOT NULL,
    cache_date DATE NOT NULL,
    data JSON NOT NULL COMMENT 'Cached analytics data',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_type_date (user_id, cache_type, cache_date),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- WhatsApp Logs Table (for n8n integration)
CREATE TABLE whatsapp_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    phone_number VARCHAR(20),
    message_type ENUM('incoming', 'outgoing') NOT NULL,
    message_content TEXT,
    webhook_payload JSON,
    processed BOOLEAN DEFAULT FALSE,
    response_sent BOOLEAN DEFAULT FALSE,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_user (user_id),
    INDEX idx_processed (processed, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Habit-Mood Correlations Cache Table
CREATE TABLE habit_mood_correlations (
    correlation_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    habit_id INT NOT NULL,
    correlation_type ENUM('positive', 'negative', 'neutral') NOT NULL,
    correlation_score DECIMAL(5,3) COMMENT 'Correlation coefficient -1 to 1',
    mood_level_affected VARCHAR(50),
    pattern_description TEXT,
    sample_size INT COMMENT 'Number of data points used',
    avg_mood_with_habit DECIMAL(4,2),
    avg_mood_without_habit DECIMAL(4,2),
    last_calculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (habit_id) REFERENCES habits(habit_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_habit (user_id, habit_id),
    INDEX idx_user_type (user_id, correlation_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert a test user (password: Test@123)
INSERT INTO users (phone_number, phone_verified, email, full_name, password_hash) 
VALUES (
    '+1234567890', 
    TRUE, 
    'test@example.com', 
    'Test User',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5aeJEcHDqq3Iu'
);
