-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jun 25, 2026 at 12:31 PM
-- Server version: 10.4.27-MariaDB
-- PHP Version: 7.4.33

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `ai_planner_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `ai_insights`
--

CREATE TABLE `ai_insights` (
  `insight_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `insight_type` enum('productivity','mood','habit','prediction','recommendation') NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `content` text NOT NULL,
  `confidence_score` decimal(5,2) DEFAULT NULL COMMENT 'AI confidence 0-100',
  `related_entity_type` enum('task','habit','goal','mood','general') DEFAULT NULL,
  `related_entity_id` int(11) DEFAULT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Additional AI metadata' CHECK (json_valid(`metadata`)),
  `is_read` tinyint(1) DEFAULT 0,
  `valid_until` date DEFAULT NULL COMMENT 'When this insight expires',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `analytics_cache`
--

CREATE TABLE `analytics_cache` (
  `cache_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `cache_type` enum('daily','weekly','monthly','custom') NOT NULL,
  `cache_date` date NOT NULL,
  `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT 'Cached analytics data' CHECK (json_valid(`data`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `expires_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `app_usage_logs`
--

CREATE TABLE `app_usage_logs` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `package_name` varchar(200) NOT NULL,
  `usage_date` date NOT NULL,
  `minutes_used` int(11) NOT NULL DEFAULT 0,
  `limit_exceeded` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `bad_habit_apps`
--

CREATE TABLE `bad_habit_apps` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `app_name` varchar(100) NOT NULL,
  `package_name` varchar(200) NOT NULL,
  `daily_limit_minutes` int(11) NOT NULL DEFAULT 30,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `goals`
--

CREATE TABLE `goals` (
  `goal_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(500) NOT NULL,
  `description` text DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `target_date` date DEFAULT NULL,
  `status` enum('active','completed','abandoned') DEFAULT 'active',
  `progress_percentage` decimal(5,2) DEFAULT 0.00,
  `ai_decomposed` tinyint(1) DEFAULT 0,
  `ai_milestones` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'AI-generated milestones' CHECK (json_valid(`ai_milestones`)),
  `completed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `goal_subtasks`
--

CREATE TABLE `goal_subtasks` (
  `subtask_id` int(11) NOT NULL,
  `goal_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `is_completed` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `completed_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `habits`
--

CREATE TABLE `habits` (
  `habit_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `frequency` enum('daily','weekly','custom') DEFAULT 'daily',
  `frequency_details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Days of week, times per week, etc.' CHECK (json_valid(`frequency_details`)),
  `target_count` int(11) DEFAULT 1 COMMENT 'How many times per frequency period',
  `reminder_time` time DEFAULT NULL,
  `icon` varchar(50) DEFAULT NULL,
  `color` varchar(20) DEFAULT NULL,
  `ai_suggested` tinyint(1) DEFAULT 0,
  `ai_reason` text DEFAULT NULL COMMENT 'Why AI suggested this habit',
  `current_streak` int(11) DEFAULT 0,
  `longest_streak` int(11) DEFAULT 0,
  `total_completions` int(11) DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `habit_completions`
--

CREATE TABLE `habit_completions` (
  `completion_id` int(11) NOT NULL,
  `habit_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `completion_date` date NOT NULL,
  `completion_time` time DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `mood_at_completion` enum('very_bad','bad','neutral','good','very_good') DEFAULT NULL,
  `energy_level` int(11) DEFAULT NULL CHECK (`energy_level` between 1 and 5),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `habit_mood_correlations`
--

CREATE TABLE `habit_mood_correlations` (
  `correlation_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `habit_id` int(11) NOT NULL,
  `correlation_type` enum('positive','negative','neutral') DEFAULT NULL,
  `correlation_score` decimal(5,3) DEFAULT NULL,
  `mood_level_affected` varchar(50) DEFAULT NULL,
  `pattern_description` text DEFAULT NULL,
  `sample_size` int(11) DEFAULT NULL,
  `avg_mood_with_habit` decimal(4,2) DEFAULT NULL,
  `avg_mood_without_habit` decimal(4,2) DEFAULT NULL,
  `last_calculated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `insights_cache`
--

CREATE TABLE `insights_cache` (
  `cache_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `insights_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`insights_data`)),
  `correlation_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`correlation_data`)),
  `days_analyzed` int(11) DEFAULT 30,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `expires_at` timestamp NULL DEFAULT NULL,
  `is_valid` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `locations`
--

CREATE TABLE `locations` (
  `location_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `address` text DEFAULT NULL,
  `latitude` decimal(10,8) NOT NULL,
  `longitude` decimal(11,8) NOT NULL,
  `radius_meters` int(11) DEFAULT 200,
  `category` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `location_events`
--

CREATE TABLE `location_events` (
  `event_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `location_id` int(11) NOT NULL,
  `event_type` enum('enter','dwell','exit') NOT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  `dwell_duration_seconds` int(11) DEFAULT 0,
  `notification_sent` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `location_links`
--

CREATE TABLE `location_links` (
  `link_id` int(11) NOT NULL,
  `location_id` int(11) NOT NULL,
  `item_type` enum('task','goal','habit') NOT NULL,
  `item_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mood_logs`
--

CREATE TABLE `mood_logs` (
  `mood_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `log_date` date NOT NULL,
  `log_time` time DEFAULT NULL,
  `mood_level` enum('very_bad','bad','neutral','good','very_good') NOT NULL,
  `energy_level` int(11) DEFAULT NULL CHECK (`energy_level` between 1 and 10),
  `notes` text DEFAULT NULL,
  `activities` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'What user was doing' CHECK (json_valid(`activities`)),
  `ai_insights` text DEFAULT NULL COMMENT 'AI-generated insights about this mood',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notification_history`
--

CREATE TABLE `notification_history` (
  `notification_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `location_id` int(11) DEFAULT NULL,
  `notification_type` varchar(50) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `context_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`context_data`)),
  `sent_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `opened_at` timestamp NULL DEFAULT NULL,
  `action_taken` varchar(50) DEFAULT NULL,
  `action_taken_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notification_schedule`
--

CREATE TABLE `notification_schedule` (
  `schedule_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `notification_type` varchar(50) NOT NULL,
  `scheduled_time` time NOT NULL,
  `enabled` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `reminders`
--

CREATE TABLE `reminders` (
  `reminder_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `entity_type` enum('task','habit','goal') NOT NULL,
  `entity_id` int(11) NOT NULL,
  `reminder_time` datetime NOT NULL,
  `message` text DEFAULT NULL,
  `is_sent` tinyint(1) DEFAULT 0,
  `ai_optimized` tinyint(1) DEFAULT 0 COMMENT 'Whether AI adjusted the time',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `sent_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `tasks`
--

CREATE TABLE `tasks` (
  `task_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(500) NOT NULL,
  `description` text DEFAULT NULL,
  `original_input` text DEFAULT NULL,
  `priority` enum('low','medium','high','urgent') DEFAULT 'medium',
  `status` enum('pending','in_progress','completed','cancelled') DEFAULT 'pending',
  `category` varchar(100) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `due_time` time DEFAULT NULL,
  `estimated_duration` int(11) DEFAULT NULL COMMENT 'Duration in minutes',
  `ai_generated` tinyint(1) DEFAULT 0,
  `ai_priority_score` decimal(5,2) DEFAULT NULL,
  `ai_tags` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'AI-generated tags' CHECK (json_valid(`ai_tags`)),
  `completed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `reminder_enabled` tinyint(1) DEFAULT 0,
  `reminder_minutes_before` int(11) DEFAULT 30
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `task_subtasks`
--

CREATE TABLE `task_subtasks` (
  `subtask_id` int(11) NOT NULL,
  `goal_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(500) NOT NULL,
  `description` text DEFAULT NULL,
  `order_index` int(11) DEFAULT 0,
  `status` enum('pending','in_progress','completed') DEFAULT 'pending',
  `completed` tinyint(1) DEFAULT 0,
  `due_date` date DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `phone_verified` tinyint(1) DEFAULT 0,
  `verification_code` varchar(6) DEFAULT NULL,
  `verification_expires` datetime DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `profile_picture` varchar(500) DEFAULT NULL,
  `timezone` varchar(50) DEFAULT 'UTC',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_patterns`
--

CREATE TABLE `user_patterns` (
  `pattern_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `pattern_type` varchar(50) NOT NULL,
  `pattern_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`pattern_data`)),
  `confidence_score` float DEFAULT 0,
  `sample_size` int(11) DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `whatsapp_logs`
--

CREATE TABLE `whatsapp_logs` (
  `log_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `phone_number` varchar(20) DEFAULT NULL,
  `message_type` enum('incoming','outgoing') NOT NULL,
  `message_content` text DEFAULT NULL,
  `webhook_payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`webhook_payload`)),
  `processed` tinyint(1) DEFAULT 0,
  `response_sent` tinyint(1) DEFAULT 0,
  `error_message` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `processed_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ai_insights`
--
ALTER TABLE `ai_insights`
  ADD PRIMARY KEY (`insight_id`),
  ADD KEY `idx_user_type` (`user_id`,`insight_type`),
  ADD KEY `idx_created` (`created_at`);

--
-- Indexes for table `analytics_cache`
--
ALTER TABLE `analytics_cache`
  ADD PRIMARY KEY (`cache_id`),
  ADD UNIQUE KEY `unique_user_type_date` (`user_id`,`cache_type`,`cache_date`),
  ADD KEY `idx_expires` (`expires_at`);

--
-- Indexes for table `app_usage_logs`
--
ALTER TABLE `app_usage_logs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_user_app_date` (`user_id`,`package_name`,`usage_date`);

--
-- Indexes for table `bad_habit_apps`
--
ALTER TABLE `bad_habit_apps`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `goals`
--
ALTER TABLE `goals`
  ADD PRIMARY KEY (`goal_id`),
  ADD KEY `idx_user_status` (`user_id`,`status`),
  ADD KEY `idx_goal_location` (`location_id`);

--
-- Indexes for table `goal_subtasks`
--
ALTER TABLE `goal_subtasks`
  ADD PRIMARY KEY (`subtask_id`),
  ADD KEY `idx_goal_subtasks` (`goal_id`);

--
-- Indexes for table `habits`
--
ALTER TABLE `habits`
  ADD PRIMARY KEY (`habit_id`),
  ADD KEY `idx_user_active` (`user_id`,`is_active`),
  ADD KEY `idx_habit_location` (`location_id`);

--
-- Indexes for table `habit_completions`
--
ALTER TABLE `habit_completions`
  ADD PRIMARY KEY (`completion_id`),
  ADD UNIQUE KEY `unique_habit_date` (`habit_id`,`completion_date`),
  ADD KEY `idx_user_date` (`user_id`,`completion_date`);

--
-- Indexes for table `habit_mood_correlations`
--
ALTER TABLE `habit_mood_correlations`
  ADD PRIMARY KEY (`correlation_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `habit_id` (`habit_id`);

--
-- Indexes for table `insights_cache`
--
ALTER TABLE `insights_cache`
  ADD PRIMARY KEY (`cache_id`),
  ADD KEY `idx_user_valid` (`user_id`,`is_valid`,`expires_at`),
  ADD KEY `idx_expires` (`expires_at`);

--
-- Indexes for table `locations`
--
ALTER TABLE `locations`
  ADD PRIMARY KEY (`location_id`),
  ADD KEY `idx_user_location` (`user_id`,`is_active`),
  ADD KEY `idx_coordinates` (`latitude`,`longitude`);

--
-- Indexes for table `location_events`
--
ALTER TABLE `location_events`
  ADD PRIMARY KEY (`event_id`),
  ADD KEY `idx_user_events` (`user_id`,`timestamp`),
  ADD KEY `idx_location_events` (`location_id`,`timestamp`),
  ADD KEY `idx_notification_sent` (`notification_sent`,`timestamp`);

--
-- Indexes for table `location_links`
--
ALTER TABLE `location_links`
  ADD PRIMARY KEY (`link_id`),
  ADD UNIQUE KEY `unique_location_item` (`location_id`,`item_type`,`item_id`),
  ADD KEY `idx_location_item` (`location_id`,`item_type`,`item_id`),
  ADD KEY `idx_item_location` (`item_type`,`item_id`);

--
-- Indexes for table `mood_logs`
--
ALTER TABLE `mood_logs`
  ADD PRIMARY KEY (`mood_id`),
  ADD KEY `idx_user_date` (`user_id`,`log_date`);

--
-- Indexes for table `notification_history`
--
ALTER TABLE `notification_history`
  ADD PRIMARY KEY (`notification_id`),
  ADD KEY `idx_user_notifications` (`user_id`,`sent_at`),
  ADD KEY `idx_location_notifications` (`location_id`,`sent_at`),
  ADD KEY `idx_notification_type` (`notification_type`,`sent_at`);

--
-- Indexes for table `notification_schedule`
--
ALTER TABLE `notification_schedule`
  ADD PRIMARY KEY (`schedule_id`),
  ADD UNIQUE KEY `unique_user_schedule` (`user_id`,`notification_type`);

--
-- Indexes for table `reminders`
--
ALTER TABLE `reminders`
  ADD PRIMARY KEY (`reminder_id`),
  ADD KEY `idx_user_time` (`user_id`,`reminder_time`),
  ADD KEY `idx_pending` (`is_sent`,`reminder_time`);

--
-- Indexes for table `tasks`
--
ALTER TABLE `tasks`
  ADD PRIMARY KEY (`task_id`),
  ADD KEY `idx_user_status` (`user_id`,`status`),
  ADD KEY `idx_due_date` (`due_date`),
  ADD KEY `idx_priority` (`priority`),
  ADD KEY `idx_tasks_due_date` (`due_date`),
  ADD KEY `idx_task_location` (`location_id`);

--
-- Indexes for table `task_subtasks`
--
ALTER TABLE `task_subtasks`
  ADD PRIMARY KEY (`subtask_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `idx_goal` (`goal_id`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `phone_number` (`phone_number`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_phone` (`phone_number`),
  ADD KEY `idx_email` (`email`);

--
-- Indexes for table `user_patterns`
--
ALTER TABLE `user_patterns`
  ADD PRIMARY KEY (`pattern_id`),
  ADD UNIQUE KEY `unique_user_pattern` (`user_id`,`pattern_type`);

--
-- Indexes for table `whatsapp_logs`
--
ALTER TABLE `whatsapp_logs`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_processed` (`processed`,`created_at`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ai_insights`
--
ALTER TABLE `ai_insights`
  MODIFY `insight_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `analytics_cache`
--
ALTER TABLE `analytics_cache`
  MODIFY `cache_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `app_usage_logs`
--
ALTER TABLE `app_usage_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `bad_habit_apps`
--
ALTER TABLE `bad_habit_apps`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `goals`
--
ALTER TABLE `goals`
  MODIFY `goal_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `goal_subtasks`
--
ALTER TABLE `goal_subtasks`
  MODIFY `subtask_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `habits`
--
ALTER TABLE `habits`
  MODIFY `habit_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `habit_completions`
--
ALTER TABLE `habit_completions`
  MODIFY `completion_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `habit_mood_correlations`
--
ALTER TABLE `habit_mood_correlations`
  MODIFY `correlation_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `insights_cache`
--
ALTER TABLE `insights_cache`
  MODIFY `cache_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `locations`
--
ALTER TABLE `locations`
  MODIFY `location_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `location_events`
--
ALTER TABLE `location_events`
  MODIFY `event_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `location_links`
--
ALTER TABLE `location_links`
  MODIFY `link_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mood_logs`
--
ALTER TABLE `mood_logs`
  MODIFY `mood_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notification_history`
--
ALTER TABLE `notification_history`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notification_schedule`
--
ALTER TABLE `notification_schedule`
  MODIFY `schedule_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `reminders`
--
ALTER TABLE `reminders`
  MODIFY `reminder_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tasks`
--
ALTER TABLE `tasks`
  MODIFY `task_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `task_subtasks`
--
ALTER TABLE `task_subtasks`
  MODIFY `subtask_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_patterns`
--
ALTER TABLE `user_patterns`
  MODIFY `pattern_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `whatsapp_logs`
--
ALTER TABLE `whatsapp_logs`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `ai_insights`
--
ALTER TABLE `ai_insights`
  ADD CONSTRAINT `ai_insights_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `analytics_cache`
--
ALTER TABLE `analytics_cache`
  ADD CONSTRAINT `analytics_cache_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `app_usage_logs`
--
ALTER TABLE `app_usage_logs`
  ADD CONSTRAINT `app_usage_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `bad_habit_apps`
--
ALTER TABLE `bad_habit_apps`
  ADD CONSTRAINT `bad_habit_apps_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `goals`
--
ALTER TABLE `goals`
  ADD CONSTRAINT `goals_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `goals_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE SET NULL;

--
-- Constraints for table `goal_subtasks`
--
ALTER TABLE `goal_subtasks`
  ADD CONSTRAINT `goal_subtasks_ibfk_1` FOREIGN KEY (`goal_id`) REFERENCES `goals` (`goal_id`) ON DELETE CASCADE;

--
-- Constraints for table `habits`
--
ALTER TABLE `habits`
  ADD CONSTRAINT `habits_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `habits_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE SET NULL;

--
-- Constraints for table `habit_completions`
--
ALTER TABLE `habit_completions`
  ADD CONSTRAINT `habit_completions_ibfk_1` FOREIGN KEY (`habit_id`) REFERENCES `habits` (`habit_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `habit_completions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `habit_mood_correlations`
--
ALTER TABLE `habit_mood_correlations`
  ADD CONSTRAINT `habit_mood_correlations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `habit_mood_correlations_ibfk_2` FOREIGN KEY (`habit_id`) REFERENCES `habits` (`habit_id`) ON DELETE CASCADE;

--
-- Constraints for table `insights_cache`
--
ALTER TABLE `insights_cache`
  ADD CONSTRAINT `insights_cache_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `locations`
--
ALTER TABLE `locations`
  ADD CONSTRAINT `locations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `location_events`
--
ALTER TABLE `location_events`
  ADD CONSTRAINT `location_events_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `location_events_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE CASCADE;

--
-- Constraints for table `location_links`
--
ALTER TABLE `location_links`
  ADD CONSTRAINT `location_links_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE CASCADE;

--
-- Constraints for table `mood_logs`
--
ALTER TABLE `mood_logs`
  ADD CONSTRAINT `mood_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `notification_history`
--
ALTER TABLE `notification_history`
  ADD CONSTRAINT `notification_history_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `notification_history_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE SET NULL;

--
-- Constraints for table `notification_schedule`
--
ALTER TABLE `notification_schedule`
  ADD CONSTRAINT `notification_schedule_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `reminders`
--
ALTER TABLE `reminders`
  ADD CONSTRAINT `reminders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `tasks`
--
ALTER TABLE `tasks`
  ADD CONSTRAINT `tasks_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `tasks_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE SET NULL;

--
-- Constraints for table `task_subtasks`
--
ALTER TABLE `task_subtasks`
  ADD CONSTRAINT `task_subtasks_ibfk_1` FOREIGN KEY (`goal_id`) REFERENCES `goals` (`goal_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `task_subtasks_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `user_patterns`
--
ALTER TABLE `user_patterns`
  ADD CONSTRAINT `user_patterns_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `whatsapp_logs`
--
ALTER TABLE `whatsapp_logs`
  ADD CONSTRAINT `whatsapp_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
