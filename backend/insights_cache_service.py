"""
Insights Cache Service
Handles caching of AI-generated insights to improve performance and reliability
"""

import logging
import json
from typing import Dict, Optional
from datetime import datetime, timedelta
from database import Database

logger = logging.getLogger(__name__)


class InsightsCacheService:
    """Service for managing insights cache"""
    
    CACHE_DURATION_HOURS = 24
    
    async def get_cached_insights(
        self, 
        user_id: int, 
        days: int = 30
    ) -> Optional[Dict]:
        """
        Retrieve cached insights if valid
        
        Args:
            user_id: User ID
            days: Number of days analyzed
            
        Returns:
            Cached insights dict or None if not found/expired
        """
        try:
            query = """
                SELECT insights_data, correlation_data, created_at
                FROM insights_cache
                WHERE user_id = %s 
                  AND days_analyzed = %s
                  AND is_valid = TRUE
                  AND expires_at > NOW()
                ORDER BY created_at DESC
                LIMIT 1
            """
            
            result = Database.execute_query(
                query,
                (user_id, days),
                fetch=True
            )
            
            if result:
                cache_entry = result[0]
                insights_data = cache_entry['insights_data']
                
                # Parse JSON if it's a string
                if isinstance(insights_data, str):
                    insights_data = json.loads(insights_data)
                
                logger.info(f"Cache hit for user {user_id}, age: {datetime.now() - cache_entry['created_at']}")
                return insights_data
            
            logger.info(f"Cache miss for user {user_id}")
            return None
            
        except Exception as e:
            logger.error(f"Error retrieving cached insights: {e}")
            return None
    
    async def cache_insights(
        self,
        user_id: int,
        insights_data: Dict,
        correlation_data: Dict,
        days: int = 30
    ) -> bool:
        """
        Cache insights for future use
        
        Args:
            user_id: User ID
            insights_data: Complete insights response
            correlation_data: Raw correlation data
            days: Number of days analyzed
            
        Returns:
            True if cached successfully
        """
        try:
            expires_at = datetime.now() + timedelta(hours=self.CACHE_DURATION_HOURS)
            
            # Invalidate old cache entries for this user/days combination
            await self.invalidate_cache(user_id, days)
            
            query = """
                INSERT INTO insights_cache 
                (user_id, insights_data, correlation_data, days_analyzed, expires_at)
                VALUES (%s, %s, %s, %s, %s)
            """
            
            Database.execute_query(
                query,
                (
                    user_id,
                    json.dumps(insights_data),
                    json.dumps(correlation_data),
                    days,
                    expires_at
                )
            )
            
            logger.info(f"Cached insights for user {user_id}, expires at {expires_at}")
            return True
            
        except Exception as e:
            logger.error(f"Error caching insights: {e}")
            return False
    
    async def invalidate_cache(
        self,
        user_id: int,
        days: Optional[int] = None
    ) -> bool:
        """
        Invalidate cached insights for a user
        
        Args:
            user_id: User ID
            days: Optional specific days to invalidate, or all if None
            
        Returns:
            True if invalidated successfully
        """
        try:
            if days is not None:
                query = """
                    UPDATE insights_cache
                    SET is_valid = FALSE
                    WHERE user_id = %s AND days_analyzed = %s
                """
                params = (user_id, days)
            else:
                query = """
                    UPDATE insights_cache
                    SET is_valid = FALSE
                    WHERE user_id = %s
                """
                params = (user_id,)
            
            Database.execute_query(query, params)
            logger.info(f"Invalidated cache for user {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error invalidating cache: {e}")
            return False
    
    async def cleanup_expired_cache(self) -> int:
        """
        Clean up expired cache entries
        
        Returns:
            Number of entries deleted
        """
        try:
            query = """
                DELETE FROM insights_cache
                WHERE expires_at < NOW() OR is_valid = FALSE
            """
            
            rows_affected = Database.execute_query(query)
            logger.info(f"Cleaned up {rows_affected} expired cache entries")
            return rows_affected
            
        except Exception as e:
            logger.error(f"Error cleaning up cache: {e}")
            return 0


# Singleton instance
insights_cache_service = InsightsCacheService()
