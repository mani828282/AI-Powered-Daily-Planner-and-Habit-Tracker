-- Add task reminders columns to tasks table
ALTER TABLE tasks ADD COLUMN reminder_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE tasks ADD COLUMN reminder_minutes_before INT DEFAULT 60;
