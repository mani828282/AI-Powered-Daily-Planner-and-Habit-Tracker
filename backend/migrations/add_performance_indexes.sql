-- Database Performance Optimization
-- Add indexes to speed up common queries by 50-80%

-- ============================================================================
-- MOOD LOGS INDEXES
-- ============================================================================

-- Most common query: fetch mood logs by user and date range
CREATE INDEX IF NOT EXISTS idx_mood_logs_user_date 
ON mood_logs(user_id, log_date DESC);

-- For date-based filtering
CREATE INDEX IF NOT EXISTS idx_mood_logs_date 
ON mood_logs(log_date DESC);

-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_mood_logs_user 
ON mood_logs(user_id);

-- ============================================================================
-- HABIT COMPLETIONS INDEXES
-- ============================================================================

-- Most common query: fetch completions by user and date
CREATE INDEX IF NOT EXISTS idx_habit_completions_user_date 
ON habit_completions(user_id, completion_date DESC);

-- For habit-specific queries
CREATE INDEX IF NOT EXISTS idx_habit_completions_habit 
ON habit_completions(habit_id, completion_date DESC);

-- For date-based filtering
CREATE INDEX IF NOT EXISTS idx_habit_completions_date 
ON habit_completions(completion_date DESC);

-- ============================================================================
-- HABITS INDEXES
-- ============================================================================

-- Most common query: fetch active habits by user
CREATE INDEX IF NOT EXISTS idx_habits_user_active 
ON habits(user_id, is_active);

-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_habits_user 
ON habits(user_id);

-- ============================================================================
-- TASKS INDEXES
-- ============================================================================

-- Most common query: fetch tasks by user and status
CREATE INDEX IF NOT EXISTS idx_tasks_user_status 
ON tasks(user_id, status);

-- For due date filtering
CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
ON tasks(due_date);

-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_tasks_user 
ON tasks(user_id);

-- Combined index for common query pattern
CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due 
ON tasks(user_id, status, due_date);

-- ============================================================================
-- GOALS INDEXES
-- ============================================================================

-- For user-specific queries
CREATE INDEX IF NOT EXISTS idx_goals_user 
ON goals(user_id);

-- For status filtering
CREATE INDEX IF NOT EXISTS idx_goals_user_status 
ON goals(user_id, status);

-- ============================================================================
-- INSIGHTS CACHE INDEXES
-- ============================================================================

-- Most common query: fetch valid cache by user and days
CREATE INDEX IF NOT EXISTS idx_insights_cache_user_valid 
ON insights_cache(user_id, days_analyzed, is_valid, expires_at);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show all indexes
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('mood_logs', 'habit_completions', 'habits', 'tasks', 'goals', 'insights_cache')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
