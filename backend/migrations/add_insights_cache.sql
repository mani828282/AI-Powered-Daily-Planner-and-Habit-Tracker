-- Migration: Add insights cache table
-- Purpose: Cache AI-generated insights to improve performance and reliability
-- Created: 2026-02-04

CREATE TABLE IF NOT EXISTS insights_cache (
    cache_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    insights_data JSON NOT NULL,
    correlation_data JSON NOT NULL,
    days_analyzed INT DEFAULT 30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_valid BOOLEAN DEFAULT TRUE,
    
    INDEX idx_user_valid (user_id, is_valid, expires_at),
    INDEX idx_expires (expires_at),
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add comment
ALTER TABLE insights_cache COMMENT = 'Caches AI-generated insights to reduce API calls and improve performance';
