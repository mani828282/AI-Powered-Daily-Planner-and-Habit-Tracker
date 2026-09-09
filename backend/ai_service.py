import httpx
from config import settings
import json
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

class AIService:
    def __init__(self):
        self.api_key = settings.GROQ_API_KEY
        self.base_url = settings.GROQ_BASE_URL
        self.model = settings.AI_MODEL
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    async def _generate_content(self, prompt: str) -> str:
        """Make API call to Groq and return the response text"""
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "user", "content": prompt}
                        ]
                    }
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            logger.error(f"Groq API error: {e}")
            raise
    
    def _extract_json(self, text: str) -> str:
        """Extract JSON from markdown code blocks if present"""
        text = text.strip()
        if "```json" in text:
            start = text.find("```json") + 7
            end = text.find("```", start)
            return text[start:end].strip()
        elif "```" in text:
            start = text.find("```") + 3
            end = text.find("```", start)
            return text[start:end].strip()
        return text
    
    async def parse_task_from_text(self, user_input: str, user_context: Dict = None) -> Dict:
        """
        Parse natural language input into structured task data with enhanced AI understanding
        """
        current_time = datetime.now()
        
        prompt = f"""You are an elite AI task management assistant with deep understanding of human language, context, and productivity principles. Your role is to transform ANY form of user input—whether it's a quick note, a detailed description, or casual speech—into a perfectly structured, actionable task.

**CRITICAL INSTRUCTIONS:**
1. UNDERSTAND THE INTENT: Look beyond the literal words. Understand what the user really wants to accomplish.
2. ENHANCE & IMPROVE: Don't just copy the user's words. Make the task title professional, clear, and action-oriented.
3. ADD VALUE: Provide a helpful description with context, steps, or tips that make the task easier to complete.
4. BE INTELLIGENT: Infer priority, category, timing, and other details from context clues in the language.
5. HANDLE AMBIGUITY: If something is unclear, make the best reasonable assumption and note it in the description.

**USER INPUT:** "{user_input}"

**CURRENT CONTEXT:**
- Date: {current_time.strftime('%A, %B %d, %Y')}
- Time: {current_time.strftime('%I:%M %p')}
- Day of week: {current_time.strftime('%A')}

**YOUR TASK:**
Transform this input into a well-structured task by extracting and inferring the following information:

**1. TITLE (Required)**
- Create a clear, professional, action-oriented title
- Start with a strong action verb (Complete, Schedule, Review, Purchase, etc.)
- Be specific but concise (5-10 words ideal)
- Improve vague language (e.g., "stuff" → "items", "thing" → specific object)
- Examples:
  * "buy milk" → "Purchase Fresh Milk and Dairy Products"
  * "call mom" → "Call Mom to Check In"
  * "fix bug" → "Debug and Fix Login Authentication Issue"

**2. DESCRIPTION (Required)**
- Write 1-2 SHORT sentences maximum
- Be concise and action-focused
- NO detailed steps, tips, or lengthy explanations
- Keep it simple and to the point
- Examples:
  * For "buy groceries": "Purchase weekly groceries and household essentials."
  * For "prepare presentation": "Create slide deck for client meeting with key metrics and roadmap."

**3. PRIORITY (Required)**
Intelligently determine priority based on:
- **URGENT**: Words like "ASAP", "urgent", "emergency", "critical", "immediately", "now"
- **HIGH**: Due today/tomorrow, important verbs (pay, submit, complete), financial tasks, health-related, deadlines
- **MEDIUM**: Due this week, routine work tasks, scheduled appointments, follow-ups
- **LOW**: Someday/maybe items, nice-to-have tasks, entertainment, optional activities

Priority indicators in language:
- "need to", "must", "have to" = HIGH
- "should", "want to" = MEDIUM  
- "might", "could", "maybe" = LOW
- Time pressure words = increase priority
- Consequence words ("or else", "before", "deadline") = increase priority

**4. CATEGORY (Required)**
Choose the BEST fit from these categories:
- **work**: Professional tasks, meetings, projects, emails, reports
- **personal**: Personal errands, self-care, hobbies, personal development
- **health**: Exercise, medical appointments, mental health, nutrition, wellness
- **finance**: Bills, budgeting, investments, taxes, banking, shopping
- **shopping**: Groceries, household items, gifts, online orders
- **learning**: Courses, reading, skill development, research, studying
- **social**: Friends, family, events, calls, messages, relationships
- **home**: Cleaning, maintenance, repairs, organization, gardening
- **creative**: Writing, art, music, design, content creation
- **general**: Anything that doesn't fit above categories

**5. DUE DATE (YYYY-MM-DD format or null)**
Parse time references intelligently:
- "today" = {current_time.strftime('%Y-%m-%d')}
- "tomorrow" = {(current_time.replace(hour=0, minute=0, second=0, microsecond=0) + __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')}
- "next week" = {(current_time + __import__('datetime').timedelta(days=7)).strftime('%Y-%m-%d')}
- "this weekend" = next Saturday
- "Monday", "Tuesday", etc. = next occurrence of that day
- "in 3 days" = calculate exact date
- "by Friday" = that Friday
- "end of month" = last day of current month
- "next month" = first day of next month
- Specific dates: "Jan 15", "15th", "1/15" = parse to YYYY-MM-DD
- If no time reference: null

**6. DUE TIME (HH:MM in 24-hour format or null)**
Parse time references:
- "morning" = 09:00
- "noon" / "midday" = 12:00
- "afternoon" = 14:00
- "evening" = 18:00
- "night" = 20:00
- "at 3pm" = 15:00
- "at 3:30" = 15:30
- "9am" = 09:00
- If no specific time: null

**7. ESTIMATED_DURATION (minutes)**
Provide realistic estimates based on task type:
- Quick tasks (calls, emails, simple purchases): 15-30 min
- Medium tasks (meetings, errands, cooking): 30-90 min
- Large tasks (projects, deep work, major shopping): 90-240 min
- Very large tasks (full-day activities): 240-480 min
Consider: complexity, travel time, preparation time

**8. TAGS (Array of 2-5 relevant tags)**
Generate helpful, searchable tags:
- Include task type (e.g., "urgent", "recurring", "quick-win")
- Include domain (e.g., "groceries", "fitness", "coding")
- Include context (e.g., "home", "office", "online")
- Include tools/resources needed (e.g., "phone", "laptop", "car")
- Make tags lowercase and concise

**EXAMPLES OF EXCELLENT TRANSFORMATIONS:**

Input: "buy milk tomorrow"
Output: {{
  "title": "Purchase Fresh Milk and Dairy Products",
  "description": "Buy fresh milk and dairy essentials from the grocery store.",
  "priority": "medium",
  "category": "shopping",
  "due_date": "{(current_time + __import__('datetime').timedelta(days=1)).strftime('%Y-%m-%d')}",
  "due_time": null,
  "estimated_duration": 30,
  "tags": ["groceries", "dairy", "essentials", "shopping"]
}}

Input: "urgent - submit expense report by friday 5pm"
Output: {{
  "title": "Submit Monthly Expense Report to Finance",
  "description": "Compile receipts and submit expense report via company portal.",
  "priority": "urgent",
  "category": "work",
  "due_date": "[next Friday's date]",
  "due_time": "17:00",
  "estimated_duration": 90,
  "tags": ["urgent", "finance", "deadline", "reimbursement", "paperwork"]
}}

Input: "workout"
Output: {{
  "title": "Complete Daily Workout Session",
  "description": "30-45 minute workout with cardio, strength training, and stretching.",
  "priority": "medium",
  "category": "health",
  "due_date": "{current_time.strftime('%Y-%m-%d')}",
  "due_time": null,
  "estimated_duration": 45,
  "tags": ["fitness", "health", "exercise", "daily", "wellness"]
}}

**EDGE CASES TO HANDLE:**
- Vague input ("do stuff") → Create a reasonable task and note ambiguity in description
- Multiple tasks in one input → Focus on the primary task, mention others in description
- Incomplete information → Make intelligent assumptions and note them
- Conflicting information → Prioritize the most recent or specific detail
- Casual/slang language → Translate to professional language
- Typos/errors → Correct them in the output

**OUTPUT FORMAT:**
Return ONLY a valid JSON object with these exact fields:
{{
  "title": "string",
  "description": "string",
  "priority": "low" | "medium" | "high" | "urgent",
  "category": "string",
  "due_date": "YYYY-MM-DD" | null,
  "due_time": "HH:MM" | null,
  "estimated_duration": number,
  "tags": ["string", "string", ...]
}}

**CRITICAL RULES:**
- NO additional text outside the JSON
- NO explanations or comments
- ALL fields must be present
- Dates must be valid and in correct format
- Times must be in 24-hour format
- Priority must be one of the four exact values
- Tags must be an array of strings
- Description must be helpful and actionable

Generate the task now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            logger.info(f"🤖 AI raw response: {response_text[:500]}")  # Log first 500 chars
            json_text = self._extract_json(response_text)
            logger.info(f"📝 Extracted JSON: {json_text[:300]}")  # Log extracted JSON
            result = json.loads(json_text)
            result['ai_generated'] = True
            return result
        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing error: {e}")
            logger.error(f"Failed to parse: {json_text[:500] if 'json_text' in locals() else 'N/A'}")
            logger.error(f"Original response: {response_text[:500] if 'response_text' in locals() else 'N/A'}")
            return {
                "title": user_input[:200],
                "description": "Task created from user input.",
                "priority": "medium",
                "category": "general",
                "due_date": None,
                "due_time": None,
                "estimated_duration": 30,
                "tags": ["ai-generated"],
                "ai_generated": False
            }
        except Exception as e:
            logger.error(f"Error parsing task: {e}")
            logger.error(f"Response text: {response_text[:500] if 'response_text' in locals() else 'N/A'}")
            return {
                "title": user_input[:200],
                "description": "Task created from user input.",
                "priority": "medium",
                "category": "general",
                "due_date": None,
                "due_time": None,
                "estimated_duration": 30,
                "tags": ["ai-generated"],
                "ai_generated": False
            }
    
    async def structure_habit(self, habit_name: str, user_goals: List[str] = None) -> Dict:
        """
        AI structures a habit with enhanced recommendations and motivation
        """
        prompt = f"""You are a world-class habit formation expert and behavioral psychologist. Your expertise includes habit stacking, behavioral design, motivation psychology, and sustainable behavior change. Transform this habit into an optimized, motivating, and achievable routine.

**USER'S HABIT INPUT:** "{habit_name}"
**USER'S GOALS:** {user_goals if user_goals else "Not specified - infer from habit name"}

**YOUR MISSION:**
Create a comprehensive habit structure that maximizes the user's chance of success and long-term adherence.

**CRITICAL PRINCIPLES TO APPLY:**
1. **Make it Specific**: Vague habits fail. Make the name and description crystal clear about WHAT, WHEN, and HOW.
2. **Make it Motivating**: Use positive, empowering language. Focus on benefits, not obligations.
3. **Make it Achievable**: Start small. Better to succeed at a small habit than fail at an ambitious one.
4. **Make it Measurable**: Clear success criteria so the user knows when they've completed it.
5. **Make it Rewarding**: Highlight immediate and long-term benefits to maintain motivation.

**REQUIRED OUTPUT STRUCTURE:**

**1. NAME (Enhanced & Motivating)**
- Improve the user's wording to be more specific and inspiring
- Use action-oriented, positive language
- Include the key benefit or outcome when possible
- Examples:
  * "exercise" → "Morning Energizing Workout"
  * "read" → "Daily Reading for Personal Growth"
  * "meditate" → "Mindful Meditation for Inner Peace"
  * "drink water" → "Hydration Habit for Optimal Health"

**2. DESCRIPTION (Compelling & Detailed)**
Write 3-4 sentences that:
- Explain WHAT the habit involves (specific actions)
- Highlight WHY it's beneficial (immediate + long-term benefits)
- Provide HOW to do it successfully (practical tips)
- Include motivation and encouragement
- Mention potential obstacles and how to overcome them

Example: "Start your day with 20-30 minutes of energizing exercise to boost your mood, energy, and overall health. This could include jogging, yoga, strength training, or any physical activity you enjoy. Regular morning exercise has been proven to improve focus, reduce stress, and increase productivity throughout the day. Even on busy mornings, a quick 10-minute session is better than skipping entirely."

**3. CATEGORY**
Choose the BEST fit:
- **health**: Physical health, fitness, nutrition, sleep, medical
- **productivity**: Work habits, time management, focus, organization
- **learning**: Reading, studying, skill development, education
- **fitness**: Exercise, sports, physical training, movement
- **mindfulness**: Meditation, reflection, gratitude, mental health
- **social**: Relationships, communication, networking, family time
- **creative**: Art, writing, music, design, creative expression
- **finance**: Budgeting, saving, investing, financial planning
- **personal**: Self-care, grooming, personal development, hobbies
- **professional**: Career development, networking, skill building

**4. FREQUENCY**
Determine the optimal frequency:
- **"daily"**: For habits that benefit from daily repetition (exercise, meditation, reading, etc.)
- **"weekly"**: For habits that are better done a few times per week (deep cleaning, meal prep, etc.)

Consider:
- Habit type and typical best practices
- Sustainability (daily habits are harder to maintain)
- User's likely schedule and commitments
- Scientific research on habit formation

**5. FREQUENCY_DETAILS**
Provide smart recommendations:
{{
  "days_of_week": [0, 1, 2, 3, 4, 5, 6] for daily, or specific days [1, 3, 5] for weekly (0=Monday, 6=Sunday),
  "times_per_week": null for daily, or number (e.g., 3) for weekly,
  "recommended_time": "morning" | "afternoon" | "evening" | "night"
}}

**Time of Day Recommendations:**
- **morning** (6-10 AM): Exercise, meditation, planning, learning, creative work
- **afternoon** (12-5 PM): Meetings, errands, social activities, light exercise
- **evening** (5-9 PM): Family time, hobbies, relaxation, meal prep, reflection
- **night** (9 PM-12 AM): Reading, journaling, wind-down routines, preparation for next day

**6. TARGET_COUNT**
How many times per frequency period should this be done?
- Daily habits: Usually 1 (once per day)
- Weekly habits: 2-5 times per week (be realistic)

**7. RECOMMENDED_REMINDER_TIME**
Suggest the BEST time in "HH:MM" format (24-hour):
- Consider the recommended_time (morning/afternoon/evening)
- Choose a time when most people are available
- Avoid very early (before 6 AM) or very late (after 10 PM) unless appropriate
- Examples:
  * Morning habits: "07:00" or "08:00"
  * Afternoon habits: "14:00" or "15:00"
  * Evening habits: "18:00" or "19:00"
  * Night habits: "21:00"

**8. ICON**
Choose a single, highly relevant emoji:
- 🏃 Running, jogging, cardio
- 🧘 Meditation, yoga, mindfulness
- 📚 Reading, learning, studying
- 💧 Hydration, water intake
- 🥗 Healthy eating, nutrition
- 💪 Strength training, fitness
- 😴 Sleep, rest, recovery
- ✍️ Writing, journaling
- 🎨 Creative activities
- 🧠 Mental work, focus
- ❤️ Self-care, wellness
- 🌅 Morning routines
- 🌙 Evening routines

**9. COLOR**
Choose a hex color that matches the habit's vibe:
- Health/Fitness: #4CAF50 (green), #2196F3 (blue)
- Mindfulness/Calm: #9C27B0 (purple), #00BCD4 (cyan)
- Energy/Active: #FF9800 (orange), #F44336 (red)
- Learning/Growth: #3F51B5 (indigo), #009688 (teal)
- Creative: #E91E63 (pink), #FF5722 (deep orange)

**10. MOTIVATION**
Write 1-2 powerful sentences explaining:
- The transformative impact of this habit
- Scientific or experiential benefits
- How it contributes to overall well-being or success
- Inspiring, encouraging tone

Example: "Consistent morning exercise has been shown to increase energy levels by up to 20%, improve mood, and enhance cognitive function throughout the day. By making this a daily habit, you're investing in your long-term health, happiness, and productivity."

**EXAMPLE OUTPUT:**

Input: "exercise"
Output: {{
  "name": "Morning Energizing Workout",
  "description": "Start your day with 20-30 minutes of physical activity to boost energy, mood, and overall health. Choose activities you enjoy—running, yoga, strength training, or dancing. Regular morning exercise improves focus, reduces stress, and sets a positive tone for the entire day. Even on busy mornings, a quick 10-minute session is valuable.",
  "category": "fitness",
  "frequency": "daily",
  "frequency_details": {{
    "days_of_week": [0, 1, 2, 3, 4, 5, 6],
    "times_per_week": null,
    "recommended_time": "morning"
  }},
  "target_count": 1,
  "recommended_reminder_time": "07:00",
  "icon": "🏃",
  "color": "#4CAF50",
  "motivation": "Daily exercise is one of the most powerful habits for improving both physical and mental health. By committing to this habit, you're building strength, energy, and resilience that will benefit every area of your life."
}}

**OUTPUT REQUIREMENTS:**
- Return ONLY valid JSON
- NO additional text or explanations
- ALL fields must be present and properly formatted
- Be specific, motivating, and actionable
- Focus on user success and long-term adherence

Generate the habit structure now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            return json.loads(json_text)
        except Exception as e:
            logger.error(f"Error structuring habit: {e}")
            return {
                "name": habit_name,
                "description": f"Build a consistent {habit_name} routine to improve your daily life and achieve your goals.",
                "category": "general",
                "frequency": "daily",
                "frequency_details": {"recommended_time": "morning"},
                "target_count": 1,
                "recommended_reminder_time": "09:00",
                "icon": "⭐",
                "color": "#4CAF50",
                "motivation": "Every small step towards building this habit brings you closer to your goals."
            }
    
    async def generate_daily_report(self, user_data: Dict) -> str:
        """
        Generate personalized, motivational daily report
        """
        prompt = f"""You are a supportive, insightful personal coach who knows how to motivate and encourage people. Generate a warm, personalized daily report that celebrates achievements and provides gentle, constructive guidance.

**USER'S DAY DATA:**
- Tasks completed: {user_data.get('tasks_completed', 0)} out of {user_data.get('total_tasks', 0)}
- Habits completed: {user_data.get('habits_completed', 0)} out of {user_data.get('total_habits', 0)}
- Active streaks: {user_data.get('streaks', [])}
- Mood today: {user_data.get('mood', 'Not logged')}
- Energy level: {user_data.get('energy', 'Not logged')}

**YOUR TASK:**
Write a brief, encouraging daily report (3-5 sentences) that:

1. **CELEBRATES WINS** (even small ones):
   - Acknowledge completed tasks and habits
   - Highlight streaks and consistency
   - Use specific numbers and achievements
   - Be genuinely enthusiastic about progress

2. **PROVIDES PERSPECTIVE** on incomplete items:
   - Be gentle and understanding, not judgmental
   - Reframe incomplete tasks as opportunities for tomorrow
   - Remind them that progress > perfection
   - Normalize having off days

3. **OFFERS ONE ACTIONABLE INSIGHT**:
   - Give specific, practical advice
   - Relate to their mood/energy if logged
   - Suggest a small next step
   - Keep it simple and achievable

4. **ENDS WITH MOTIVATION**:
   - Inspiring but not cliché
   - Personal and relevant to their data
   - Forward-looking and hopeful
   - Warm and supportive tone

**TONE GUIDELINES:**
- Warm, friendly, and personal (like a supportive friend)
- Enthusiastic about wins, gentle about misses
- Use "you" and "your" to make it personal
- Include relevant emojis (1-2) for warmth
- Avoid: being preachy, using clichés, being overly formal

**EXAMPLES:**

Example 1 (Good day):
"Fantastic work today! 🎉 You completed 8 out of 10 tasks and maintained your 5-day meditation streak—that's real consistency. Your mood and energy levels show you're in a great flow state. Tomorrow, try tackling your highest-priority task first thing in the morning to maintain this momentum. You're building incredible habits!"

Example 2 (Mixed day):
"You completed 3 out of 7 tasks today, and that's progress worth celebrating! 💪 Life gets busy, and the fact that you're still showing up matters. Your 12-day exercise streak is impressive—don't let one slower day discourage you. Tomorrow, focus on just your top 2 priorities and build from there. Small consistent steps lead to big results!"

Example 3 (Tough day):
"Today was challenging with only 1 task completed, but you still logged your mood and checked in—that takes courage. 🌟 Even on difficult days, you're staying engaged with your goals. Your body and mind might be telling you to rest and recharge. Tomorrow is a fresh start: pick one small, achievable task to rebuild your momentum. You've got this!"

**CRITICAL RULES:**
- Return ONLY the report text (3-5 sentences)
- NO JSON, NO formatting, just plain text
- Be specific to their actual data
- Balance celebration with gentle guidance
- End on an encouraging, forward-looking note

Generate the daily report now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            return response_text.strip()
        except Exception as e:
            logger.error(f"Error generating report: {e}")
            return "Great effort today! Every step forward counts. Keep building those positive habits and remember that consistency beats perfection. You're making real progress! 🌟"
    
    async def prioritize_tasks(self, tasks: List[Dict]) -> List[Dict]:
        """
        AI prioritizes tasks with sophisticated understanding
        """
        if not tasks:
            return []
        
        tasks_summary = "\n".join([
            f"{i+1}. \"{t['title']}\" | Due: {t.get('due_date', 'No date')} {t.get('due_time', '')} | Priority: {t.get('priority', 'medium')} | Category: {t.get('category', 'general')}"
            for i, t in enumerate(tasks[:20])
        ])
        
        current_date = datetime.now()
        
        prompt = f"""You are an expert productivity consultant and time management specialist. Your job is to intelligently prioritize tasks based on multiple factors, helping users focus on what truly matters.

**CURRENT CONTEXT:**
- Today: {current_date.strftime('%A, %B %d, %Y')}
- Time: {current_date.strftime('%I:%M %p')}

**TASKS TO PRIORITIZE:**
{tasks_summary}

**YOUR MISSION:**
Assign each task an AI priority score (0-100) using sophisticated multi-factor analysis.

**PRIORITIZATION FACTORS:**

**1. TIME URGENCY (40% weight)**
- **Overdue** (due date passed): 90-100 points
- **Due today**: 80-95 points
- **Due tomorrow**: 70-85 points
- **Due this week**: 50-70 points
- **Due next week**: 30-50 points
- **Due later/no date**: 10-30 points

**2. STATED PRIORITY (30% weight)**
- **urgent**: +30 points
- **high**: +20 points
- **medium**: +10 points
- **low**: +5 points

**3. TASK TYPE IMPORTANCE (20% weight)**
High-impact task types (add points):
- Financial (bills, taxes, payments): +15
- Health/Medical: +15
- Work deadlines/submissions: +12
- Important meetings/calls: +10
- Learning/Development: +8
- Routine maintenance: +5

**4. WORKLOAD DISTRIBUTION (10% weight)**
- Avoid clustering too many high-priority tasks on one day
- Spread workload reasonably across available time
- Consider estimated duration if available

**SMART PRIORITIZATION RULES:**
1. **Overdue tasks** should almost always be top priority (85-100)
2. **Financial/Health tasks** get boosted priority regardless of due date
3. **Quick wins** (short duration, high impact) should rank higher
4. **Batch similar tasks** by giving them close scores
5. **Balance urgency with importance** (Eisenhower Matrix principle)
6. **Consider dependencies** if mentioned in descriptions

**REASONING QUALITY:**
Your reasoning should be:
- Specific to the task details
- Clear about which factors drove the score
- Actionable (help user understand WHY this priority)
- Concise (one sentence, 10-15 words)

**EXAMPLE REASONING:**
- "Overdue bill payment - financial obligation requires immediate attention"
- "Due tomorrow with high priority - time-sensitive work deliverable"
- "Health appointment today - cannot be rescheduled, critical timing"
- "Low priority, no deadline - can be deferred to next week"
- "Quick task, high impact - easy win to build momentum"

**OUTPUT FORMAT:**
Return a JSON array with objects for each task:
[
  {{
    "title": "exact task title from input",
    "ai_priority_score": 85,
    "reasoning": "Brief explanation of score"
  }},
  ...
]

**CRITICAL REQUIREMENTS:**
- Return ONLY valid JSON array
- Include ALL tasks from the input
- Scores must be 0-100 integers
- Titles must EXACTLY match input (for matching)
- Reasoning must be one clear sentence
- Distribute scores across the full range (don't cluster around 50)

Generate the prioritized task list now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            prioritized = json.loads(json_text)
            
            score_map = {item['title']: item['ai_priority_score'] for item in prioritized}
            for task in tasks:
                task['ai_priority_score'] = score_map.get(task['title'], 50)
            
            tasks.sort(key=lambda x: x.get('ai_priority_score', 50), reverse=True)
            return tasks
        except Exception as e:
            logger.error(f"Error prioritizing tasks: {e}")
            return tasks
    
    async def suggest_habits(self, user_profile: Dict) -> List[Dict]:
        """
        Suggest personalized habits with deep understanding
        """
        prompt = f"""You are a personal development coach and behavioral psychologist specializing in habit formation and sustainable behavior change. Analyze the user's profile and suggest 3 highly personalized, achievable habits that will genuinely improve their life.

**USER PROFILE:**
- Current habits: {user_profile.get('current_habits', [])}
- Goals: {user_profile.get('goals', [])}
- Interests: {user_profile.get('interests', [])}

**YOUR MISSION:**
Suggest 3 new habits that are:
1. **Complementary**: Work well with existing habits (habit stacking opportunities)
2. **Goal-aligned**: Directly support their stated goals
3. **Realistic**: Achievable given their current lifestyle
4. **High-impact**: Maximum benefit for minimal effort
5. **Personalized**: Tailored to their specific situation, not generic advice

**HABIT SUGGESTION PRINCIPLES:**

**1. START SMALL**
- Suggest the MINIMUM viable version of the habit
- "Read 1 page" not "Read 30 minutes"
- "Do 5 pushups" not "Full workout"
- "Meditate 2 minutes" not "Meditate 20 minutes"
- Users can always do more, but starting small ensures consistency

**2. STACK ON EXISTING HABITS**
- Look for natural connections to current habits
- "After your morning coffee, do X"
- "Before your evening walk, do Y"
- Leverage existing routines as triggers

**3. ADDRESS GAPS**
- What's missing from their current routine?
- Physical health? Mental health? Social connection?
- Learning? Creativity? Rest?
- Suggest habits that fill important gaps

**4. MATCH THEIR GOALS**
- If goal is "lose weight" → nutrition/exercise habits
- If goal is "learn Spanish" → daily practice habits
- If goal is "reduce stress" → mindfulness/relaxation habits
- Be specific and directly relevant

**FOR EACH HABIT, PROVIDE:**

**name**: Clear, specific habit name (not generic)
- Good: "5-Minute Morning Stretching Routine"
- Bad: "Exercise"

**reason**: WHY you're suggesting this (2-3 sentences)
- Explain the connection to their goals/current habits
- Highlight the specific benefit for THEM
- Mention how it complements what they're already doing
- Be personal and specific, not generic

**category**: Best-fit category
- health, productivity, learning, fitness, mindfulness, social, creative, finance, personal, professional

**frequency**: "daily" or "weekly"
- Daily for habits that benefit from consistency
- Weekly for habits that need more time or are less frequent

**expected_benefit**: What they'll gain (1-2 sentences)
- Be specific and realistic
- Mention both short-term and long-term benefits
- Use concrete outcomes, not vague promises
- Examples:
  * "Improved flexibility and reduced back pain within 2 weeks. Better posture and energy throughout the day."
  * "Expanded vocabulary and improved pronunciation. Noticeable progress in conversations within 30 days."

**EXAMPLE OUTPUT:**

User has: ["Morning coffee", "Evening walk"]
User goals: ["Improve fitness", "Learn new skills"]

[
  {{
    "name": "5-Minute Post-Coffee Stretching",
    "reason": "Since you already have a morning coffee routine, adding a quick 5-minute stretch right after creates a natural habit stack. This addresses your fitness goal with minimal time investment and helps wake up your body for the day. It's the perfect bridge between your coffee and starting work.",
    "category": "fitness",
    "frequency": "daily",
    "expected_benefit": "Improved flexibility, reduced stiffness, and better energy levels throughout the morning. You'll notice less back pain and better posture within 2 weeks of consistent practice."
  }},
  {{
    "name": "15-Minute Skill-Building Before Evening Walk",
    "reason": "Your evening walk is already a consistent habit. Adding 15 minutes of focused learning right before it creates accountability and a natural transition. This directly supports your goal to learn new skills while leveraging your existing routine as a reward mechanism.",
    "category": "learning",
    "frequency": "daily",
    "expected_benefit": "Steady progress on your chosen skill with 7+ hours of practice per month. The consistency will lead to noticeable improvement within 30 days, and the pre-walk timing ensures you actually do it."
  }},
  {{
    "name": "Weekly Fitness Challenge",
    "reason": "To complement your daily routines and push your fitness goal further, a weekly challenge (like trying a new workout class or hiking a new trail) adds variety and prevents plateaus. It's ambitious enough to be exciting but infrequent enough to be sustainable.",
    "category": "fitness",
    "frequency": "weekly",
    "expected_benefit": "Increased strength, endurance, and motivation. Trying new activities keeps fitness fun and helps you discover what you enjoy most. Expect to feel stronger and more confident within a month."
  }}
]

**CRITICAL REQUIREMENTS:**
- Return ONLY valid JSON array
- Exactly 3 habit suggestions
- ALL fields must be present for each habit
- Be specific and personal, not generic
- Ensure habits are actually achievable
- Make clear connections to user's profile

Generate the 3 personalized habit suggestions now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            return json.loads(json_text)
        except Exception as e:
            logger.error(f"Error suggesting habits: {e}")
            return []
    
    async def analyze_mood_patterns(self, mood_logs: List[Dict]) -> Dict:
        """
        Deep analysis of mood patterns with actionable insights
        """
        if not mood_logs:
            return {"insight": "Start logging your mood daily to unlock personalized insights about your emotional patterns and well-being trends!"}
        
        mood_summary = "\n".join([
            f"- {log.get('log_date', 'N/A')}: Mood={log.get('mood_level', 'N/A')}/5, Energy={log.get('energy_level', 'N/A')}/5, Notes: {(log.get('notes') or 'None')[:50]}"
            for log in mood_logs[:30]
        ])

        
        prompt = f"""You are a wellness psychologist and data analyst specializing in emotional intelligence and behavioral patterns. Analyze the user's mood and energy logs to provide deep, actionable insights.

**MOOD & ENERGY DATA (Last 30 days):**
{mood_summary}

**ANALYSIS FRAMEWORK:**

**1. OVERALL TREND**
Determine if mood is:
- **"improving"**: Clear upward trajectory, more good days than bad recently
- **"stable"**: Consistent levels, no major changes
- **"declining"**: Downward trend, more low mood days recently

Look for:
- Week-over-week changes
- Recent patterns vs. earlier patterns
- Consistency of highs and lows

**2. TEMPORAL PATTERNS**
Identify patterns by:
- **Day of week**: Which days are best/worst?
- **Time periods**: Beginning vs. end of week
- **Streaks**: Consecutive good or bad days

**3. MOOD-ENERGY CORRELATION**
Analyze the relationship:
- Do high mood days have high energy?
- Are there low-mood but high-energy days? (stressed/anxious)
- Are there high-mood but low-energy days? (content/relaxed)
- What's the typical pattern?

**4. ACTIONABLE RECOMMENDATIONS**
Provide 2-3 specific, practical suggestions:
- Based on identified patterns
- Addressing low points
- Leveraging high points
- Concrete actions, not vague advice

**OUTPUT FORMAT:**
{{
  "overall_trend": "improving" | "stable" | "declining",
  "peak_days": ["Monday", "Friday"] or "No clear pattern",
  "low_days": ["Wednesday"] or "No clear pattern",
  "energy_correlation": "Detailed 2-3 sentence analysis of mood-energy relationship",
  "recommendations": [
    "Specific actionable recommendation 1",
    "Specific actionable recommendation 2",
    "Specific actionable recommendation 3"
  ],
  "insight_summary": "2-3 sentence summary of key findings and what they mean for the user"
}}

**EXAMPLE OUTPUT:**

{{
  "overall_trend": "improving",
  "peak_days": ["Friday", "Saturday"],
  "low_days": ["Monday", "Tuesday"],
  "energy_correlation": "Your mood and energy levels are strongly correlated—when you feel good emotionally, you also have high physical energy. However, on Mondays and Tuesdays, both tend to dip, suggesting the start of your work week is particularly draining.",
  "recommendations": [
    "Schedule lighter workloads or enjoyable activities on Monday mornings to ease into the week",
    "Protect your Friday and Saturday high-energy periods for important tasks or activities you've been postponing",
    "Consider a Sunday evening routine to mentally prepare for Monday and reduce the weekly dip"
  ],
  "insight_summary": "Your mood is trending upward overall, which is excellent progress! The main pattern to address is the Monday-Tuesday slump. By adjusting your weekly schedule and adding a Sunday prep routine, you can smooth out these dips and maintain more consistent well-being throughout the week."
}}

**CRITICAL REQUIREMENTS:**
- Return ONLY valid JSON
- Be specific and personal to their data
- Recommendations must be actionable (not "be happier")
- Identify real patterns, don't make them up
- If no clear pattern exists, say so honestly
- Use empathetic, supportive language

Generate the mood pattern analysis now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            return json.loads(json_text)
        except Exception as e:
            logger.error(f"Error analyzing mood: {e}")
            return {"insight": "Keep logging your mood consistently to unlock deeper insights about your emotional patterns and well-being!"}
    
    async def decompose_goal(self, goal_title: str, goal_description: str = None, target_date: str = None) -> List[Dict]:
        """
        Break down goals into achievable, highly specific subtasks tailored exactly to the goal.
        """
        current_date = datetime.now()

        prompt = f"""You are a world-class goal achievement coach and domain expert. Your ONLY job is to create a highly specific, deeply actionable step-by-step roadmap for this EXACT goal.

**GOAL:**
- Title: "{goal_title}"
- Description: {goal_description or "Not provided"}
- Target date: {target_date or "Not specified"}
- Current date: {current_date.strftime('%Y-%m-%d')}

**CRITICAL RULES — READ CAREFULLY:**

1. **BE 100% SPECIFIC TO THIS EXACT GOAL.** Every single step must be uniquely tailored to "{goal_title}". Steps that could apply to any other goal are WRONG.

2. **STRICTLY FORBIDDEN generic titles** — NEVER use any of these:
   "Research and Plan", "Set Up Foundation", "Start Initial Work", "Review and Refine",
   "Complete and Celebrate", "Build Core Skills", "Execute the Plan", "Monitor Progress",
   "Take Action", "Get Started", "Initial Setup", "Final Steps"

3. **Name the SPECIFIC thing being done** — include exact tools, platforms, content, skills, or milestones unique to "{goal_title}".

4. **Logical sequence** — each step must build on the previous one.

5. **2–3 milestones** marked as `"milestone": true` for major phase completions.

**SUBTASK FORMAT** — each must have all 5 fields:
- "title": Specific, action-oriented (name the exact activity) — 6-12 words
- "description": 2-3 sentences: what to do, which tools/resources, what success looks like
- "order_index": 0-based integer sequence
- "estimated_days_from_start": realistic integer (days from today)
- "milestone": true or false

**EXAMPLE showing required specificity:**

Goal: "Learn Spanish to conversational level"

BAD step: {{"title": "Research and Plan Approach", "description": "Research the best ways to achieve the goal.", ...}}

GOOD steps:
[
  {{"title": "Complete Duolingo Spanish Tree Sections 1-3 (A1 Vocabulary)", "description": "Spend 20 min/day on Duolingo completing the first 3 sections: greetings, numbers, food, and present tense. Aim for a 30-day streak. These sections cover 300+ core words.", "order_index": 0, "estimated_days_from_start": 30, "milestone": true}},
  {{"title": "Study Spanish Grammar with 'Grammar in Use' Chapters 1-10", "description": "Work through the first 10 chapters covering ser/estar, present tense conjugations, and gender agreement. Do 1 chapter every 3 days and complete all exercises.", "order_index": 1, "estimated_days_from_start": 60, "milestone": false}},
  {{"title": "Hold 10-Minute Daily Conversations on iTalki", "description": "Book 3 sessions per week with an iTalki community tutor. Focus on introducing yourself, describing your day, and ordering food. Record sessions to review pronunciation.", "order_index": 2, "estimated_days_from_start": 90, "milestone": true}}
]

**NOW CREATE 5-8 HIGHLY SPECIFIC STEPS FOR: "{goal_title}"**

Return ONLY a valid JSON array — no extra text, no markdown fences, no explanations.
"""

        try:
            logger.info(f"🤖 Attempting to decompose goal: '{goal_title}'")
            response_text = await self._generate_content(prompt)
            logger.info(f"✅ AI response received, extracting JSON...")
            json_text = self._extract_json(response_text)
            result = json.loads(json_text)
            logger.info(f"✅ Successfully decomposed goal into {len(result)} subtasks")
            return result
        except Exception as e:
            logger.error(f"Error decomposing goal '{goal_title}': {e}")
            logger.error(f"Full error details:", exc_info=True)
            # Fallback subtasks reference the actual goal title
            short_title = goal_title[:60]
            return [
                {"title": f"Define Clear Success Criteria for '{short_title}'", "description": f"Write down exactly what it means to have achieved '{short_title}'. List 3 measurable milestones and the specific resources required to reach each one.", "order_index": 0, "estimated_days_from_start": 3, "milestone": False},
                {"title": f"Acquire Essential Tools and Materials for '{short_title}'", "description": f"Identify and obtain every specific tool, platform, course, or resource you need to work on '{short_title}'. Set up your environment so you are fully ready to begin.", "order_index": 1, "estimated_days_from_start": 7, "milestone": False},
                {"title": f"Complete the Core First Phase of '{short_title}'", "description": f"Execute the first concrete, hands-on steps toward '{short_title}'. Build the foundation or produce your first tangible output. Do not skip to later steps.", "order_index": 2, "estimated_days_from_start": 21, "milestone": True},
                {"title": f"Reach the 50% Progress Milestone for '{short_title}'", "description": f"Complete half the total work required for '{short_title}'. Evaluate what is working, what needs adjustment, and update your approach based on what you have learned.", "order_index": 3, "estimated_days_from_start": 40, "milestone": False},
                {"title": f"Finalise and Validate the Completed '{short_title}'", "description": f"Finish all remaining tasks for '{short_title}'. Verify the outcome meets the success criteria you defined at the start. Document lessons learned and decide on next steps.", "order_index": 4, "estimated_days_from_start": 60, "milestone": True}
            ]


    async def predict_performance(self, historical_data: Dict) -> Dict:
        """
        Predict future performance with data-driven insights
        """
        prompt = f"""You are a performance analyst and predictive modeling expert. Analyze historical data to forecast future performance and provide actionable recommendations.

**HISTORICAL PERFORMANCE DATA:**
- Task completion rate (last 30 days): {historical_data.get('task_completion_rate', 0)}%
- Habit adherence rate: {historical_data.get('habit_adherence_rate', 0)}%
- Average mood: {historical_data.get('avg_mood', 'neutral')}
- Streak trends: {historical_data.get('streak_trends', [])}
- Productivity patterns: {historical_data.get('productivity_patterns', {})}

**ANALYSIS FRAMEWORK:**

**1. TREND ANALYSIS**
- Is performance improving, stable, or declining?
- What's driving the trends?
- Are there cyclical patterns?

**2. PREDICTIVE MODELING**
Based on current trends, forecast next week's:
- Task completion rate (be realistic)
- Habit adherence rate
- Confidence level in predictions (0-100)

**3. RISK IDENTIFICATION**
What could derail progress?
- Burnout indicators
- Declining patterns
- Overcommitment signs
- External factors

**4. OPPORTUNITY SPOTTING**
What's working well?
- Strong habits to leverage
- Productive periods to maximize
- Positive trends to amplify

**5. ACTIONABLE RECOMMENDATIONS**
Provide 2-3 specific actions to:
- Maintain strengths
- Address weaknesses
- Improve predicted outcomes

**OUTPUT FORMAT:**
{{
  "next_week_forecast": {{
    "task_completion": 75,
    "habit_adherence": 85,
    "confidence": 80
  }},
  "risk_factors": [
    "Specific risk with explanation",
    "Another potential issue"
  ],
  "opportunities": [
    "Positive trend to leverage",
    "Strength to build on"
  ],
  "recommendations": [
    "Specific action to improve performance",
    "Another concrete recommendation",
    "Third actionable suggestion"
  ],
  "summary": "2-3 sentence overview of analysis and key takeaways"
}}

**EXAMPLE:**
{{
  "next_week_forecast": {{
    "task_completion": 78,
    "habit_adherence": 82,
    "confidence": 75
  }},
  "risk_factors": [
    "Task completion has declined 10% over the past week, suggesting possible burnout or overcommitment",
    "Mood scores are trending downward, which typically precedes drops in productivity"
  ],
  "opportunities": [
    "Your morning habits have 95% adherence—this is a strong foundation to build on",
    "Weekend productivity is 20% higher than weekdays, indicating potential for schedule optimization"
  ],
  "recommendations": [
    "Reduce your daily task load by 20% for the next week to prevent burnout and improve completion rates",
    "Schedule your most important tasks on weekends when your productivity naturally peaks",
    "Add a 10-minute morning planning session to your existing strong morning routine"
  ],
  "summary": "Your overall performance is solid but showing early signs of strain. By slightly reducing your workload and better aligning tasks with your natural productivity rhythms, you can maintain high performance while avoiding burnout. Your strong morning habits are a major asset to leverage."
}}

**CRITICAL REQUIREMENTS:**
- Return ONLY valid JSON
- Predictions must be realistic (not overly optimistic)
- Confidence should reflect data quality
- Recommendations must be specific and actionable
- Be honest about risks while remaining encouraging

Generate the performance prediction now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            return json.loads(json_text)
        except Exception as e:
            logger.error(f"Error predicting performance: {e}")
            return {
                "summary": "Keep up the great work! Continue building your habits consistently and you'll see continued progress.",
                "recommendations": ["Maintain your current routine", "Track your progress daily", "Celebrate small wins"]
            }
    
    async def generate_correlation_insights(self, correlation_data: Dict) -> Dict:
        """
        Generate deep insights from mood-habit correlations
        """
        if not correlation_data.get("has_data"):
            return {
                "insights": [],
                "summary": "Not enough data yet. Keep logging your mood and completing habits for at least 2 days to unlock personalized insights about how your habits affect your emotional well-being!",
                "motivation": "Every day of data you log brings you closer to understanding yourself better. Keep going!"
            }
        
        habit_correlations = correlation_data.get("habit_correlations", [])
        weekday_patterns = correlation_data.get("weekday_patterns", {})
        stats = correlation_data.get("statistics", {})
        
        # Check if we have enough data for meaningful insights
        total_completions = correlation_data.get("total_habit_completions", 0)
        mood_logs_count = correlation_data.get("mood_logs_count", 0)
        
        # If we have data but no correlations, generate general insights
        if total_completions >= 2 and mood_logs_count >= 2 and len(habit_correlations) == 0:
            # Generate general insights based on overall statistics
            general_insights = []
            
            # Overall mood insight
            avg_mood = stats.get('avg_mood', 0)
            if avg_mood > 0:
                mood_label = "excellent" if avg_mood >= 4.5 else "great" if avg_mood >= 4 else "good" if avg_mood >= 3.5 else "moderate" if avg_mood >= 3 else "challenging"
                general_insights.append({
                    "type": "general",
                    "habit_name": None,
                    "title": f"Your Overall Mood is {mood_label.title()}",
                    "message": f"Over the past {correlation_data.get('days_analyzed', 30)} days, your average mood has been {avg_mood:.1f}/5. This shows you're tracking your emotional well-being consistently!",
                    "recommendation": "Continue logging your mood daily to build a comprehensive picture of your emotional patterns.",
                    "icon": "😊" if avg_mood >= 4 else "🙂" if avg_mood >= 3 else "😐",
                    "strength": "moderate"
                })
            
            # Habit completion insight
            if total_completions > 0:
                general_insights.append({
                    "type": "general",
                    "habit_name": None,
                    "title": "Building Your Habit Foundation",
                    "message": f"You've logged {total_completions} habit completions! To unlock deeper insights about how specific habits affect your mood, try to complete habits and log your mood on the same days.",
                    "recommendation": "Make it a routine: complete a habit, then immediately log how you're feeling. This creates the data connections we need for personalized insights.",
                    "icon": "💪",
                    "strength": "moderate"
                })
            
            return {
                "insights": general_insights,
                "summary": f"You're building great tracking habits with {mood_logs_count} mood logs and {total_completions} habit completions! To unlock specific habit-mood correlations, try logging your mood on the same days you complete your habits.",
                "motivation": "You're on the right track! Keep logging consistently and you'll soon discover which habits boost your mood the most.",
                "generated_at": datetime.now().isoformat(),
                "days_analyzed": correlation_data.get('days_analyzed', 30)
            }
        
        # Not enough data at all
        if total_completions < 2 or mood_logs_count < 2:
            return {
                "insights": [],
                "summary": f"You have {total_completions} habit completion(s) logged and {mood_logs_count} mood log(s). Keep completing your habits and logging your mood for at least 2 days to unlock personalized insights about how your habits affect your emotional well-being!",
                "motivation": "Every habit you complete and every mood you log brings you closer to understanding yourself better. Keep going!",
                "generated_at": datetime.now().isoformat(),
                "days_analyzed": correlation_data.get('days_analyzed', 30)
            }
        
        correlations_summary = "\n".join([
            f"- {corr['habit_name']}: {corr['correlation_type']} correlation ({corr['strength']}), "
            f"avg mood with habit: {corr['avg_mood_with_habit']}/5, "
            f"avg mood without: {corr['avg_mood_without_habit']}/5, "
            f"completion rate: {corr['completion_rate']}%"
            for corr in habit_correlations[:10]
        ])
        
        weekday_summary = ""
        if weekday_patterns.get("daily_patterns"):
            weekday_summary = f"""
Best mood day: {weekday_patterns.get('best_mood_day', 'N/A')}
Worst mood day: {weekday_patterns.get('worst_mood_day', 'N/A')}
Most productive day: {weekday_patterns.get('most_productive_day', 'N/A')}
"""
        
        prompt = f"""You are a personal wellness coach and behavioral psychologist specializing in mood-habit correlations and emotional intelligence. Analyze this data to provide deeply personalized, actionable insights.

**CORRELATION DATA:**
{correlations_summary}

**WEEKDAY PATTERNS:**
{weekday_summary}

**OVERALL STATISTICS:**
- Average mood: {stats.get('avg_mood', 'N/A')}/5
- Average mood with habits: {stats.get('avg_mood_with_habits', 'N/A')}/5
- Average mood without habits: {stats.get('avg_mood_without_habits', 'N/A')}/5
- Days analyzed: {correlation_data.get('days_analyzed', 30)}

**YOUR MISSION:**
Generate insights that are:
1. **Personal**: Speak directly to THIS user's specific patterns
2. **Actionable**: Provide clear next steps
3. **Encouraging**: Highlight positives, be gentle with negatives
4. **Evidence-based**: Grounded in the actual data
5. **Engaging**: Use emojis and warm language

**INSIGHT GENERATION RULES:**

**1. PRIORITIZE STRONGEST PATTERNS**
- Focus on correlations with "strong" or "moderate" strength
- Ignore weak correlations unless they're surprising
- Highlight the top 3-5 most impactful findings

**2. INSIGHT TYPES TO INCLUDE:**

**Positive Correlations** (habits that boost mood):
- Celebrate these wins!
- Encourage consistency
- Suggest doubling down on what works

**Negative Correlations** (habits associated with lower mood):
- Be gentle and non-judgmental
- Explore possible reasons
- Suggest modifications, not elimination
- Could be reverse causality (low mood → skip habit)

**Weekday Patterns**:
- Identify best/worst days
- Suggest schedule optimizations
- Explain possible causes

**General Patterns**:
- Overall impact of habits on mood
- Consistency insights
- Motivation boosters

**3. INSIGHT STRUCTURE:**
Each insight object must have:
- **type**: "positive_correlation", "negative_correlation", "weekday_pattern", or "general"
- **habit_name**: Name of habit (null for general insights)
- **title**: Catchy, specific title (5-8 words)
- **message**: Clear explanation (2-3 sentences) that:
  * States the pattern clearly
  * Explains what it means
  * Provides context or possible reasons
- **recommendation**: Specific action to take (1-2 sentences)
- **icon**: Relevant emoji
- **strength**: "strong", "moderate", or "weak"

**4. SUMMARY & MOTIVATION:**
- **summary**: 2-3 sentence overview of ALL patterns
- **motivation**: Encouraging message (1-2 sentences) to keep user engaged

**EXAMPLE OUTPUT:**

{{
  "insights": [
    {{
      "type": "positive_correlation",
      "habit_name": "Morning Jog",
      "title": "🏃 Morning Exercise Supercharges Your Mood",
      "message": "You consistently log 'Good' or 'Very Good' moods on days when you complete your Morning Jog habit. This habit has a strong positive impact on your emotional well-being, with your average mood being 4.2/5 on jog days versus 3.1/5 on non-jog days. The endorphins and sense of accomplishment from morning exercise are clearly working for you!",
      "recommendation": "Prioritize this habit, especially on days when you're feeling low. Even a short 10-minute jog can shift your mood significantly. Consider making this your non-negotiable daily habit.",
      "icon": "🏃",
      "strength": "strong"
    }},
    {{
      "type": "weekday_pattern",
      "habit_name": null,
      "title": "📅 Monday Blues Are Real for You",
      "message": "Your mood data shows a consistent dip on Mondays, with an average mood of 2.8/5 compared to 4.1/5 on Fridays. This is a common pattern related to the transition from weekend to work week. Your energy levels also drop on Mondays, suggesting the start of the week is particularly challenging.",
      "recommendation": "Schedule lighter workloads or enjoyable activities on Monday mornings. Consider a Sunday evening routine to mentally prepare for the week. Protect your Friday high-energy periods for important tasks.",
      "icon": "📅",
      "strength": "moderate"
    }},
    {{
      "type": "general",
      "habit_name": null,
      "title": "✨ Habits Are Your Mood Boosters",
      "message": "On days when you complete at least one habit, your average mood is 3.8/5 compared to 2.9/5 on days with no habits completed. This 31% improvement shows that your habit routine is a powerful tool for emotional well-being. The consistency and sense of achievement from completing habits directly contributes to feeling better.",
      "recommendation": "Even on tough days, try to complete at least one small habit. It's not just about the habit itself—it's about the positive momentum and self-efficacy it creates. Start with your easiest habit to build momentum.",
      "icon": "✨",
      "strength": "strong"
    }}
  ],
  "summary": "Your data reveals powerful connections between your habits and emotional well-being. Morning exercise is your strongest mood booster, while Mondays consistently challenge you. The good news? Completing even one habit per day significantly improves your mood. Focus on maintaining your exercise routine and adding a Monday morning ritual to smooth out the weekly dips.",
  "motivation": "You're building incredible self-awareness through this data! These insights show you have the tools to actively improve your mood—keep logging and keep building those positive habits. You're doing great! 🌟",
  "generated_at": "{datetime.now().isoformat()}",
  "days_analyzed": {correlation_data.get('days_analyzed', 30)}
}}

**CRITICAL REQUIREMENTS:**
- Return ONLY valid JSON
- 3-5 insights (focus on quality over quantity)
- Be specific and personal to their data
- Use warm, encouraging language
- Include relevant emojis
- Recommendations must be actionable
- If data shows negative patterns, be gentle but honest

Generate the correlation insights now:"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            result = json.loads(json_text)
            
            result['generated_at'] = datetime.now().isoformat()
            result['days_analyzed'] = correlation_data.get('days_analyzed', 30)
            
            return result
        except Exception as e:
            logger.error(f"Error generating correlation insights: {e}")
            return self._generate_basic_insights(habit_correlations, stats)
    
    def _generate_basic_insights(self, habit_correlations: List[Dict], stats: Dict) -> Dict:
        """Generate basic insights without AI when API fails"""
        insights = []
        
        positive_habits = [c for c in habit_correlations if c['correlation_type'] == 'positive']
        if positive_habits:
            top_habit = positive_habits[0]
            insights.append({
                "type": "positive_correlation",
                "habit_name": top_habit['habit_name'],
                "title": f"✨ {top_habit['habit_name']} Boosts Your Mood",
                "message": f"You tend to feel better on days when you complete {top_habit['habit_name']}. This habit has a {top_habit['strength']} positive impact on your emotional well-being.",
                "recommendation": "Keep up this habit to maintain positive mood. Try to be consistent, especially on days when you're feeling low.",
                "icon": "✨",
                "strength": top_habit['strength']
            })
        
        if stats.get('avg_mood_with_habits', 0) > stats.get('avg_mood_without_habits', 0):
            insights.append({
                "type": "general",
                "habit_name": None,
                "title": "🌟 Habits Improve Your Well-being",
                "message": "Your mood is generally better on days when you complete habits. This shows that your habit routine is contributing positively to your emotional state.",
                "recommendation": "Stay consistent with your habit routine. Even completing one habit per day can make a difference in how you feel.",
                "icon": "🌟",
                "strength": "moderate"
            })
        
        return {
            "insights": insights,
            "summary": "Keep building positive habits to improve your mood and well-being. Your data shows that habits are making a positive difference!",
            "motivation": "You're making great progress! Every habit counts towards better emotional health. Keep going! 💪",
            "generated_at": datetime.now().isoformat()
        }
    
    async def suggest_daily_tasks(self, tasks: List[Dict], time_of_day: str = "morning") -> List[Dict]:
        """
        Suggest top 3 tasks to work on based on priority, deadlines, and time of day
        """
        if not tasks or len(tasks) == 0:
            return []
        
        # Simple intelligent sorting without AI call for speed
        now = datetime.now()
        scored_tasks = []
        
        for task in tasks:
            score = 0
            
            # Priority scoring
            priority_scores = {'urgent': 100, 'high': 75, 'medium': 50, 'low': 25}
            score += priority_scores.get(task.get('priority', 'medium'), 50)
            
            # Deadline scoring
            if task.get('due_date'):
                try:
                    due_date = datetime.fromisoformat(str(task['due_date']))
                    days_until_due = (due_date - now).days
                    if days_until_due < 0:
                        score += 150  # Overdue!
                    elif days_until_due == 0:
                        score += 120  # Due today
                    elif days_until_due == 1:
                        score += 90   # Due tomorrow
                    elif days_until_due <= 3:
                        score += 60   # Due this week
                except:
                    pass
            
            # Time of day preferences
            category = task.get('category', '').lower()
            if time_of_day == 'morning':
                if category in ['work', 'learning', 'health']:
                    score += 20
            elif time_of_day == 'afternoon':
                if category in ['work', 'creative']:
                    score += 20
            elif time_of_day == 'evening':
                if category in ['personal', 'social', 'home']:
                    score += 20
            
            scored_tasks.append({
                'task': task,
                'score': score,
                'reason': self._generate_suggestion_reason(task, days_until_due if task.get('due_date') else None)
            })
        
        # Sort by score and return top 3
        scored_tasks.sort(key=lambda x: x['score'], reverse=True)
        return scored_tasks[:3]
    
    def _generate_suggestion_reason(self, task: Dict, days_until_due: Optional[int]) -> str:
        """Generate a human-readable reason for suggesting this task"""
        reasons = []
        
        priority = task.get('priority', 'medium')
        if priority in ['urgent', 'high']:
            reasons.append(f"{priority.capitalize()} priority")
        
        if days_until_due is not None:
            if days_until_due < 0:
                reasons.append("Overdue!")
            elif days_until_due == 0:
                reasons.append("Due today")
            elif days_until_due == 1:
                reasons.append("Due tomorrow")
            elif days_until_due <= 3:
                reasons.append(f"Due in {days_until_due} days")
        
        if not reasons:
            reasons.append("Good time to tackle this")
        
        return " • ".join(reasons)
    
    async def breakdown_goal_into_subtasks(self, goal_title: str, goal_description: str = None) -> List[Dict]:
        """
        Use AI to break down a goal into actionable subtasks
        """
        prompt = f"""You are an expert productivity coach helping users break down their goals into actionable subtasks.

**GOAL:** {goal_title}
{f"**DESCRIPTION:** {goal_description}" if goal_description else ""}

**YOUR TASK:**
Break this goal into 4-6 clear, actionable subtasks that will help achieve this goal.

**REQUIREMENTS:**
1. Each subtask should be specific and actionable
2. Start each subtask with an action verb
3. Order subtasks logically (what should be done first, second, etc.)
4. Make subtasks achievable and measurable
5. Consider dependencies between subtasks

**OUTPUT FORMAT:**
Return ONLY a JSON array of subtasks. Each subtask should have:
- title: Clear, action-oriented title (e.g., "Research available options")
- description: Brief explanation of what this involves (1-2 sentences)
- order_index: Number indicating order (0, 1, 2, etc.)

Example output:
[
  {{"title": "Research available options", "description": "Look into different approaches and gather information about best practices.", "order_index": 0}},
  {{"title": "Create initial plan", "description": "Draft a detailed plan based on research findings.", "order_index": 1}}
]

Generate the subtasks now:"""

        try:
            response_text = await self._generate_content(prompt)
            text = response_text.strip()
            
            # Extract JSON from response
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
            
            subtasks = json.loads(text)
            return subtasks
        except Exception as e:
            logger.error(f"Goal breakdown error: {e}")
            # Return default subtasks if AI fails
            return [
                {"title": "Research and gather information", "description": "Learn about the best approaches to achieve this goal.", "order_index": 0},
                {"title": "Create an action plan", "description": "Outline the specific steps needed.", "order_index": 1},
                {"title": "Start with first step", "description": "Begin working on the initial action item.", "order_index": 2},
                {"title": "Review and adjust", "description": "Evaluate progress and make necessary changes.", "order_index": 3}
            ]
    
    async def suggest_goal_tips(self, goals: List[Dict]) -> Dict:
        """
        Generate AI-powered personalized goal suggestions based on user's current goals and progress
        """
        if not goals or len(goals) == 0:
            return {
                "suggestion": "Start by creating your first goal! AI will help break it down into actionable steps.",
                "type": "getting_started",
                "actionable": True
            }
        
        # Prepare goals summary for AI
        goals_summary = "\n".join([
            f"- {g['title']} ({g.get('progress_percentage', 0):.0f}% complete, {g.get('completed_subtasks', 0)}/{g.get('total_subtasks', 0)} subtasks done)"
            for g in goals[:5]  # Limit to top 5 goals
        ])
        
        completed_count = sum(1 for g in goals if g.get('progress_percentage', 0) == 100)
        in_progress_count = len(goals) - completed_count
        
        prompt = f"""You are a motivational goal achievement coach providing personalized, actionable advice.

**USER'S CURRENT GOALS:**
{goals_summary}

**STATISTICS:**
- Total active goals: {len(goals)}
- Completed goals: {completed_count}
- In progress: {in_progress_count}

Generate ONE specific, personalized, actionable tip (1-2 sentences max).

Return ONLY a JSON object:
{{
  "suggestion": "Your specific tip",
  "type": "progress" | "motivation" | "strategy" | "celebration",
  "actionable": true
}}"""
        
        try:
            response_text = await self._generate_content(prompt)
            json_text = self._extract_json(response_text)
            result = json.loads(json_text)
            return result
        except Exception as e:
            logger.error(f"Error generating goal tips: {e}")
            # Fallback suggestions
            if completed_count > 0:
                return {
                    "suggestion": f"Great progress! You've completed {completed_count} {'goal' if completed_count == 1 else 'goals'}. Keep up the momentum!",
                    "type": "celebration",
                    "actionable": True
                }
            else:
                return {
                    "suggestion": "Focus on completing one subtask at a time. Small steps lead to big achievements!",
                    "type": "strategy",
                    "actionable": True
                }

# Singleton instance
ai_service = AIService()
ai_service = AIService()
