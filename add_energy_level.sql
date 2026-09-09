-- Add energy_level column to habit_completions table
ALTER TABLE habit_completions 
ADD COLUMN energy_level INT CHECK (energy_level BETWEEN 1 AND 5) 
AFTER mood_at_completion;
