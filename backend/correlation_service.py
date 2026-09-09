"""
Correlation Service for Mood & Habit Pattern Recognition

This module analyzes the relationship between user mood logs and habit completions
to identify patterns and provide intelligent insights.
"""

import logging
from typing import Dict, List, Optional, Tuple
from datetime import datetime, date, timedelta
from collections import defaultdict
import statistics

from database import Database

logger = logging.getLogger(__name__)


class CorrelationService:
    """Service for calculating mood-habit correlations and patterns"""
    
    def __init__(self):
        self.mood_map = {
            'very_bad': 1,
            'bad': 2,
            'neutral': 3,
            'good': 4,
            'very_good': 5
        }
        self.reverse_mood_map = {v: k for k, v in self.mood_map.items()}
    
    def _normalize_mood_level(self, mood_level) -> int:
        """Convert mood level to integer if it's a string"""
        if isinstance(mood_level, str):
            return self.mood_map.get(mood_level, 3)
        return mood_level
    
    def _get_mood_label(self, mood_level: int) -> str:
        """Convert integer mood level to label"""
        labels = {1: 'Very Bad', 2: 'Bad', 3: 'Neutral', 4: 'Good', 5: 'Very Good'}
        return labels.get(mood_level, 'Neutral')
    
    async def calculate_mood_habit_correlation(
        self, 
        user_id: int, 
        days: int = 30
    ) -> Dict:
        """
        Calculate correlation between mood levels and habit completions
        
        Returns:
            Dict containing correlation data, patterns, and statistics
        """
        try:
            start_date = date.today() - timedelta(days=days)
            
            # Fetch mood logs for the period
            mood_query = """
                SELECT log_date, mood_level, energy_level
                FROM mood_logs
                WHERE user_id = %s AND log_date >= %s
                ORDER BY log_date DESC
            """
            mood_logs = Database.execute_query(
                mood_query, 
                (user_id, start_date), 
                fetch=True
            )
            
            # Fetch habit completions for the period (only for active habits)
            habit_query = """
                SELECT hc.completion_date, hc.habit_id, h.name as habit_name
                FROM habit_completions hc
                JOIN habits h ON hc.habit_id = h.habit_id
                WHERE hc.user_id = %s 
                  AND hc.completion_date >= %s
                  AND h.is_active = TRUE
                ORDER BY hc.completion_date DESC
            """
            habit_completions = Database.execute_query(
                habit_query,
                (user_id, start_date),
                fetch=True
            )
            
            if not mood_logs or not habit_completions:
                return {
                    "has_data": False,
                    "message": "Not enough data to calculate correlations. Keep logging your mood and completing habits!"
                }
            
            # Organize data by date
            mood_by_date = {}
            for log in mood_logs:
                mood_level = self._normalize_mood_level(log['mood_level'])
                mood_by_date[log['log_date']] = {
                    'mood_level': mood_level,
                    'energy_level': log.get('energy_level', 5)
                }
            
            # Organize habits by date
            habits_by_date = defaultdict(list)
            for completion in habit_completions:
                habits_by_date[completion['completion_date']].append({
                    'habit_id': completion['habit_id'],
                    'habit_name': completion['habit_name']
                })
            
            # Calculate correlations for each habit
            habit_correlations = await self._calculate_habit_correlations(
                mood_by_date,
                habits_by_date,
                user_id
            )
            
            # Find day-of-week patterns
            weekday_patterns = self._analyze_weekday_patterns(mood_by_date, habits_by_date)
            
            # Calculate overall statistics
            stats = self._calculate_statistics(mood_by_date, habits_by_date)
            
            return {
                "has_data": True,
                "habit_correlations": habit_correlations,
                "weekday_patterns": weekday_patterns,
                "statistics": stats,
                "days_analyzed": days,
                "mood_logs_count": len(mood_logs),
                "total_habit_completions": len(habit_completions)
            }
            
        except Exception as e:
            logger.error(f"Error calculating correlations: {e}")
            return {
                "has_data": False,
                "error": str(e)
            }
    
    async def _calculate_habit_correlations(
        self,
        mood_by_date: Dict,
        habits_by_date: Dict,
        user_id: int
    ) -> List[Dict]:
        """Calculate correlation for each habit"""
        
        # Get all unique habits
        all_habits = {}
        for habits_list in habits_by_date.values():
            for habit in habits_list:
                all_habits[habit['habit_id']] = habit['habit_name']
        
        correlations = []
        
        for habit_id, habit_name in all_habits.items():
            # Collect data points: days with mood logs
            mood_with_habit = []
            mood_without_habit = []
            
            for log_date, mood_data in mood_by_date.items():
                habit_completed = any(
                    h['habit_id'] == habit_id 
                    for h in habits_by_date.get(log_date, [])
                )
                
                if habit_completed:
                    mood_with_habit.append(mood_data['mood_level'])
                else:
                    mood_without_habit.append(mood_data['mood_level'])
            
            # Need at least 2 data points for meaningful correlation
            if len(mood_with_habit) < 2:
                continue
            
            # Calculate average mood with and without habit
            avg_mood_with = statistics.mean(mood_with_habit)
            avg_mood_without = statistics.mean(mood_without_habit) if mood_without_habit else avg_mood_with
            
            mood_difference = avg_mood_with - avg_mood_without
            
            # Determine correlation strength and type
            correlation_type, strength = self._determine_correlation_type(mood_difference)
            
            # Calculate completion rate
            total_days = len(mood_by_date)
            completion_rate = (len(mood_with_habit) / total_days) * 100
            
            correlations.append({
                "habit_id": habit_id,
                "habit_name": habit_name,
                "correlation_type": correlation_type,
                "strength": strength,
                "avg_mood_with_habit": round(avg_mood_with, 2),
                "avg_mood_without_habit": round(avg_mood_without, 2),
                "mood_difference": round(mood_difference, 2),
                "completion_rate": round(completion_rate, 1),
                "sample_size": len(mood_with_habit),
                "most_common_mood_with_habit": self._get_mood_label(round(avg_mood_with))
            })
        
        # Sort by absolute mood difference (strongest correlations first)
        correlations.sort(key=lambda x: abs(x['mood_difference']), reverse=True)
        
        return correlations
    
    def _determine_correlation_type(self, mood_difference: float) -> Tuple[str, str]:
        """Determine correlation type and strength based on mood difference"""
        abs_diff = abs(mood_difference)
        
        if abs_diff >= 1.5:
            strength = "strong"
        elif abs_diff >= 0.8:
            strength = "moderate"
        elif abs_diff >= 0.3:
            strength = "weak"
        else:
            strength = "negligible"
        
        if mood_difference > 0.3:
            correlation_type = "positive"
        elif mood_difference < -0.3:
            correlation_type = "negative"
        else:
            correlation_type = "neutral"
        
        return correlation_type, strength
    
    def _analyze_weekday_patterns(
        self,
        mood_by_date: Dict,
        habits_by_date: Dict
    ) -> Dict:
        """Analyze mood and habit patterns by day of week"""
        
        weekday_moods = defaultdict(list)
        weekday_habit_counts = defaultdict(int)
        weekday_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        
        for log_date, mood_data in mood_by_date.items():
            weekday = log_date.weekday()  # 0 = Monday, 6 = Sunday
            weekday_moods[weekday].append(mood_data['mood_level'])
            weekday_habit_counts[weekday] += len(habits_by_date.get(log_date, []))
        
        patterns = []
        for weekday in range(7):
            if weekday in weekday_moods and weekday_moods[weekday]:
                avg_mood = statistics.mean(weekday_moods[weekday])
                avg_habits = weekday_habit_counts[weekday] / len(weekday_moods[weekday])
                
                patterns.append({
                    "day": weekday_names[weekday],
                    "avg_mood": round(avg_mood, 2),
                    "mood_label": self._get_mood_label(round(avg_mood)),
                    "avg_habits_completed": round(avg_habits, 1),
                    "sample_size": len(weekday_moods[weekday])
                })
        
        # Find best and worst days
        if patterns:
            best_day = max(patterns, key=lambda x: x['avg_mood'])
            worst_day = min(patterns, key=lambda x: x['avg_mood'])
            most_productive = max(patterns, key=lambda x: x['avg_habits_completed'])
            
            return {
                "daily_patterns": patterns,
                "best_mood_day": best_day['day'],
                "worst_mood_day": worst_day['day'],
                "most_productive_day": most_productive['day']
            }
        
        return {"daily_patterns": []}
    
    def _calculate_statistics(
        self,
        mood_by_date: Dict,
        habits_by_date: Dict
    ) -> Dict:
        """Calculate overall statistics"""
        
        all_moods = [data['mood_level'] for data in mood_by_date.values()]
        all_energy = [data['energy_level'] for data in mood_by_date.values()]
        
        # Calculate days with habits vs without
        days_with_habits = sum(1 for d in mood_by_date.keys() if d in habits_by_date)
        days_without_habits = len(mood_by_date) - days_with_habits
        
        # Mood on days with habits vs without
        mood_with_habits = [
            mood_by_date[d]['mood_level'] 
            for d in mood_by_date.keys() 
            if d in habits_by_date
        ]
        mood_without_habits = [
            mood_by_date[d]['mood_level'] 
            for d in mood_by_date.keys() 
            if d not in habits_by_date
        ]
        
        return {
            "avg_mood": round(statistics.mean(all_moods), 2),
            "avg_energy": round(statistics.mean(all_energy), 2),
            "mood_std_dev": round(statistics.stdev(all_moods), 2) if len(all_moods) > 1 else 0,
            "days_with_habits": days_with_habits,
            "days_without_habits": days_without_habits,
            "avg_mood_with_habits": round(statistics.mean(mood_with_habits), 2) if mood_with_habits else 0,
            "avg_mood_without_habits": round(statistics.mean(mood_without_habits), 2) if mood_without_habits else 0,
            "overall_correlation": round(
                statistics.mean(mood_with_habits) - statistics.mean(mood_without_habits), 2
            ) if mood_with_habits and mood_without_habits else 0
        }
    
    async def find_positive_correlations(self, user_id: int, min_strength: str = "weak") -> List[Dict]:
        """Find habits that positively correlate with good mood"""
        
        correlation_data = await self.calculate_mood_habit_correlation(user_id)
        
        if not correlation_data.get("has_data"):
            return []
        
        strength_order = {"negligible": 0, "weak": 1, "moderate": 2, "strong": 3}
        min_strength_value = strength_order.get(min_strength, 1)
        
        positive_correlations = [
            corr for corr in correlation_data.get("habit_correlations", [])
            if corr['correlation_type'] == 'positive' 
            and strength_order.get(corr['strength'], 0) >= min_strength_value
        ]
        
        return positive_correlations
    
    async def find_negative_correlations(self, user_id: int) -> List[Dict]:
        """Find habits that are missed during low mood days"""
        
        correlation_data = await self.calculate_mood_habit_correlation(user_id)
        
        if not correlation_data.get("has_data"):
            return []
        
        negative_correlations = [
            corr for corr in correlation_data.get("habit_correlations", [])
            if corr['correlation_type'] == 'negative'
        ]
        
        return negative_correlations


# Singleton instance
correlation_service = CorrelationService()
