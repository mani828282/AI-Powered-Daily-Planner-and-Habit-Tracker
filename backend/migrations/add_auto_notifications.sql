-- Automatic Time-Based Notifications - Database Schema
-- Creates tables for smart notification system

-- ============================================================================
-- NOTIFICATION SCHEDULE TABLE
-- Stores user's notification preferences and schedule
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_schedule (
    schedule_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'morning', 'midday', 'evening', 'deadline'
    scheduled_time TIME NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_type (user_id, notification_type)
);

-- Default notification times for new users
-- Will be inserted when user grants notification permission

-- ============================================================================
-- NOTIFICATION HISTORY TABLE
-- Logs all notifications sent to users
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_history (
    notification_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    context_data JSON, -- Stores context used to generate notification
    priority VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high'
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    opened BOOLEAN DEFAULT FALSE,
    opened_at TIMESTAMP NULL,
    action_taken VARCHAR(50), -- 'completed_task', 'completed_habit', 'dismissed', 'ignored'
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_sent (user_id, sent_at),
    INDEX idx_type (notification_type)
);

-- ============================================================================
-- USER PATTERNS TABLE
-- Stores learned patterns about user behavior
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_patterns (
    pattern_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    pattern_type VARCHAR(50) NOT NULL, -- 'habit_completion_time', 'task_completion_time', 'active_hours'
    pattern_data JSON NOT NULL, -- Flexible storage for different pattern types
    confidence_score DECIMAL(3,2) DEFAULT 0.00, -- 0.00 to 1.00
    sample_size INT DEFAULT 0, -- Number of data points used
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_pattern (user_id, pattern_type)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Fast lookup of active schedules
CREATE INDEX idx_schedule_enabled ON notification_schedule(enabled, scheduled_time);

-- Fast lookup of recent notifications
CREATE INDEX idx_history_recent ON notification_history(user_id, sent_at DESC);

-- Fast pattern lookups
CREATE INDEX idx_patterns_user ON user_patterns(user_id, pattern_type);

-- ============================================================================
-- SAMPLE DATA STRUCTURE EXAMPLES
-- ============================================================================

-- Example notification_schedule entry:
-- {
--   "schedule_id": 1,
--   "user_id": 2,
--   "notification_type": "morning",
--   "scheduled_time": "08:00:00",
--   "enabled": true
-- }

-- Example notification_history entry:
-- {
--   "notification_id": 1,
--   "user_id": 2,
--   "notification_type": "morning",
--   "title": "Good morning, rehman! ☀️",
--   "message": "You have 3 tasks and 2 habits pending today.",
--   "context_data": {
--     "pending_tasks": 3,
--     "pending_habits": 2,
--     "overdue_tasks": 0,
--     "streak_at_risk": false
--   },
--   "priority": "medium",
--   "sent_at": "2026-02-07 08:00:00",
--   "opened": false
-- }

-- Example user_patterns entry:
-- {
--   "pattern_id": 1,
--   "user_id": 2,
--   "pattern_type": "habit_completion_time",
--   "pattern_data": {
--     "average_time": "18:30:00",
--     "most_common_hour": 18,
--     "completion_days": ["monday", "wednesday", "friday"],
--     "completion_rate": 0.75
--   },
--   "confidence_score": 0.85,
--   "sample_size": 20
-- }

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check tables created
SELECT TABLE_NAME, TABLE_ROWS 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME IN ('notification_schedule', 'notification_history', 'user_patterns');

-- Check indexes
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('notification_schedule', 'notification_history', 'user_patterns')
ORDER BY TABLE_NAME, INDEX_NAME;
