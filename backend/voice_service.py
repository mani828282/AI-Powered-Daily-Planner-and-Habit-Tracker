import httpx
import logging
from typing import Dict, Optional
from config import settings
import json

logger = logging.getLogger(__name__)

class VoiceService:
    def __init__(self):
        self.api_key = settings.GROQ_API_KEY
        self.base_url = settings.GROQ_BASE_URL
        self.headers = {
            "Authorization": f"Bearer {self.api_key}"
        }
    
    async def transcribe_audio(self, audio_file_path: str, language: Optional[str] = None) -> Dict:
        """
        Transcribe audio file using Groq Whisper API with auto-language detection.
        Supports 99+ languages automatically.
        
        Args:
            audio_file_path: Path to audio file
            language: Optional language code (e.g., 'en', 'ur', 'ar'). If None, auto-detects.
        
        Returns:
            Dict with transcription text, detected language, and metadata
        """
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                with open(audio_file_path, 'rb') as audio_file:
                    files = {
                        'file': ('audio.wav', audio_file, 'audio/wav')
                    }
                    data = {
                        'model': 'whisper-large-v3-turbo',
                        'response_format': 'verbose_json'  # Get language detection info
                    }
                    # Only specify language if provided, otherwise auto-detect
                    if language:
                        data['language'] = language
                    
                    response = await client.post(
                        f"{self.base_url}/audio/transcriptions",
                        headers=self.headers,
                        files=files,
                        data=data
                    )
                    response.raise_for_status()
                    result = response.json()
                    
                    detected_language = result.get('language', 'unknown')
                    transcription_text = result.get('text', '')
                    
                    logger.info(f"Transcription successful (language: {detected_language}): {transcription_text[:100]}")
                    return {
                        'text': transcription_text,
                        'language': detected_language,
                        'duration': result.get('duration')
                    }
        except Exception as e:
            logger.error(f"Transcription error: {e}")
            raise Exception(f"Failed to transcribe audio: {str(e)}")
        return {} # Explicit return for linter
    
    async def classify_intent(self, transcription: str, context: Optional[str] = None) -> Dict:
        """
        Use Llama 3.1 to classify intent and extract structured data
        
        Args:
            transcription: Transcribed text from audio
            context: Optional context (e.g., 'tasks', 'goals', 'habits')
        
        Returns:
            Dict with intent type and extracted data
        """
        context_hint = f"The user is currently on the {context} page." if context else ""
        
        prompt = f"""You are an intelligent assistant that analyzes voice transcriptions and determines the user's intent. Your job is to classify whether the user wants to create a TASK, GOAL, or HABIT, and extract relevant information.

**VOICE TRANSCRIPTION:** "{transcription}"

**CONTEXT:** {context_hint}

**YOUR MISSION:**
Analyze the transcription and determine:
1. **Intent Type**: Is this a task, goal, or habit?
2. **Extract Data**: Parse relevant fields based on the type

**CLASSIFICATION RULES:**

**TASK** - One-time actions with deadlines
- Keywords: "do", "complete", "finish", "buy", "call", "send", "submit", "today", "tomorrow", "by Friday"
- Examples: "buy groceries tomorrow", "call mom at 5pm", "submit report by Friday"

**GOAL** - Long-term objectives with milestones
- Keywords: "achieve", "learn", "become", "improve", "master", "get", "reach", "want to"
- Examples: "learn Spanish", "lose 10kg", "save $5000", "become a developer"

**HABIT** - Recurring activities
- Keywords: "every day", "daily", "weekly", "routine", "regularly", "habit", "practice"
- Examples: "exercise every morning", "read daily", "meditate for 10 minutes"

**BAD_HABIT** - Digital limits and app usage tracking
- Keywords: "limit", "screen time", "restrict", "stop using", "less of", "reduce", "minutes on", "hours on"
- Examples: "limit Instagram to 30 minutes", "reduce screen time on Facebook", "restrict TikTok"

**CONTEXT-BASED CLASSIFICATION:**
- If context is "tasks" and intent is ambiguous, default to TASK
- If context is "goals" and intent is ambiguous, default to GOAL
- If context is "habits" and intent is ambiguous, default to HABIT
- If no context and ambiguous, use best judgment based on keywords

**EXTRACTION GUIDELINES:**

For **TASK**:
- title: Clear, action-oriented title
- description: Brief 1-2 sentence description
- priority: low, medium, high, urgent (based on urgency words)
- category: work, personal, health, finance, shopping, learning, social, home, creative, general
- due_date: YYYY-MM-DD format if mentioned (parse "today", "tomorrow", "Monday", etc.)
- due_time: HH:MM format if mentioned

For **GOAL**:
- title: Clear goal statement
- description: What the goal involves
- category: health, career, finance, learning, personal, fitness, creative, social
- target_date: YYYY-MM-DD if mentioned
- is_smart: true if goal seems specific, measurable, achievable

For **HABIT**:
- name: Clear habit name
- description: What the habit involves
- category: health, productivity, learning, fitness, mindfulness, social, creative, finance, personal
- frequency: daily or weekly
- target_count: How many times per frequency period

For **BAD_HABIT**:
- app_name: Name of the app (e.g., "Instagram")
- package_name: Android package name if you can guess it (e.g., "com.instagram.android"), otherwise null
- daily_limit_minutes: Integer number of minutes for the limit

**OUTPUT FORMAT:**
Return ONLY valid JSON:
{{
  "intent": "task" | "goal" | "habit" | "bad_habit",
  "confidence": "high" | "medium" | "low",
  "data": {{
    // Fields based on intent type
  }}
}}

**EXAMPLES:**

Input: "buy milk and eggs tomorrow"
Output: {{
  "intent": "task",
  "confidence": "high",
  "data": {{
    "title": "Buy Milk and Eggs",
    "description": "Purchase milk and eggs from grocery store.",
    "priority": "medium",
    "category": "shopping",
    "due_date": "2026-01-29",
    "due_time": null
  }}
}}

Input: "I want to learn guitar this year"
Output: {{
  "intent": "goal",
  "confidence": "high",
  "data": {{
    "title": "Learn Guitar",
    "description": "Master guitar playing skills throughout the year.",
    "category": "learning",
    "target_date": "2026-12-31",
    "is_smart": true
  }}
}}

Input: "meditate every morning for 10 minutes"
Output: {{
  "intent": "habit",
  "confidence": "high",
  "data": {{
    "name": "Morning Meditation",
    "description": "Practice 10 minutes of meditation every morning.",
    "category": "mindfulness",
    "frequency": "daily",
    "target_count": 1
  }}
}}

**CRITICAL RULES:**
- Return ONLY valid JSON, no extra text
- Always include intent, confidence, and data
- Correct any spelling or grammar errors in the transcription
- Handle multi-language input gracefully
- If transcription is unclear, use "low" confidence

Analyze the transcription now:"""

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": settings.AI_MODEL,
                        "messages": [
                            {"role": "user", "content": prompt}
                        ]
                    }
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                
                # Extract JSON from response
                content = content.strip()
                if "```json" in content:
                    start = content.find("```json") + 7
                    end = content.find("```", start)
                    content = content[start:end].strip()
                elif "```" in content:
                    start = content.find("```") + 3
                    end = content.find("```", start)
                    content = content[start:end].strip()
                
                parsed = json.loads(content)
                logger.info(f"Intent classification: {parsed.get('intent')} (confidence: {parsed.get('confidence')})")
                return parsed
                
        except Exception as e:
            logger.error(f"Intent classification error: {e}")
            # Fallback to context-based classification
            return {
                "intent": "task",
                "confidence": "low",
                "data": {
                    "title": str(transcription),
                    "description": str(transcription)
                }
            }
        return {} # Final safety
    
    async def process_voice_command(self, transcription: str, context: Optional[str] = None) -> Dict:
        """
        Process voice command and extract multiple entities with intent classification.
        Supports batch processing of multiple tasks/goals/habits from a single voice input.
        
        Args:
            transcription: Transcribed text from audio
            context: Optional context (e.g., 'tasks', 'goals', 'habits')
        
        Returns:
            Dict with array of classified items:
            {
                "items": [
                    {"intent": "task", "confidence": "high", "data": {...}},
                    ...
                ],
                "transcription": "original text",
                "language": "detected language"
            }
        """
        from datetime import datetime, timedelta
        
        context_hint = f"The user is currently on the {context} page." if context else ""
        today = datetime.now().strftime("%Y-%m-%d")
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        
        prompt = f"""You are an advanced AI assistant that processes voice commands and extracts multiple actionable items. Your mission is to parse natural language input and identify ALL distinct tasks, goals, or habits mentioned.

**VOICE TRANSCRIPTION:** "{transcription}"

**CONTEXT:** {context_hint}
**TODAY'S DATE:** {today}
**TOMORROW'S DATE:** {tomorrow}

**YOUR MISSION:**
1. **Identify ALL distinct items** in the transcription (tasks, goals, habits)
2. **Classify each item** as TASK, GOAL, or HABIT
3. **Extract structured data** for each item
4. **Correct spelling and grammar** in all extracted text
5. **Handle multilingual input** gracefully

**CRITICAL RULES FOR ENTITY EXTRACTION:**

🔍 **Entity Boundary Detection:**
- Look for conjunctions: "and", "then", "also", "plus", "after that"
- Look for list patterns: "first..., second...", "1..., 2..., 3..."
- Look for sentence boundaries and commas separating distinct actions
- Example: "go to city, buy groceries, and buy clothes" = 3 separate tasks

⚠️ **DO NOT split if:**
- Items are part of a single action: "buy milk and eggs" = 1 task (not 2)
- Items describe the same thing: "exercise and workout" = 1 task/habit
- One item modifies another: "call mom at 5pm" = 1 task (not 2)

**CLASSIFICATION RULES:**

📋 **TASK** - One-time actions with deadlines
- Keywords: "do", "complete", "finish", "buy", "call", "send", "submit", "go to", "pick up", "today", "tomorrow", "by [date]"
- Examples: "buy groceries tomorrow", "call mom at 5pm", "submit report by Friday"

🎯 **GOAL** - Long-term objectives with milestones
- Keywords: "achieve", "learn", "become", "improve", "master", "get", "reach", "want to", "goal"
- Examples: "learn Spanish", "lose 10kg", "save $5000", "become a developer"

🔄 **HABIT** - Recurring activities
- Keywords: "every day", "daily", "weekly", "routine", "regularly", "habit", "practice", "every morning/evening"
- Examples: "exercise every morning", "read daily", "meditate for 10 minutes"

📵 **BAD_HABIT** - Digital limits and app usage tracking
- Keywords: "limit", "screen time", "restrict", "stop using", "less of", "reduce", "minutes on", "hours on"
- Examples: "limit Instagram to 30 minutes", "reduce screen time on Facebook", "restrict TikTok"

**CONTEXT-BASED DEFAULTS:**
- If context is "tasks" and intent is ambiguous → TASK
- If context is "goals" and intent is ambiguous → GOAL
- If context is "habits" and intent is ambiguous → HABIT
- If context is "bad_habits" or "digital" and intent is ambiguous → BAD_HABIT
- If no context and ambiguous → use best judgment

**DATA EXTRACTION:**

For **TASK**:
- title: Clear, action-oriented title (corrected spelling/grammar)
- description: Brief 1-2 sentence description
- priority: low | medium | high | urgent (infer from urgency words like "urgent", "asap", "important")
- category: work | personal | health | finance | shopping | learning | social | home | creative | general
- due_date: YYYY-MM-DD (parse "today" → {today}, "tomorrow" → {tomorrow}, "Monday", "next week", etc.)
- due_time: HH:MM format if mentioned (e.g., "5pm" → "17:00", "noon" → "12:00")
- start_date: YYYY-MM-DD - when the task starts (if a date range is mentioned like "from Monday to Friday" use the start; otherwise same as due_date; null if no date mentioned)
- end_date: YYYY-MM-DD - the task deadline (if a date range mentioned use the end; otherwise same as due_date; null if no date mentioned)

For **GOAL**:
- title: Clear goal statement (corrected spelling/grammar)
- description: What the goal involves
- category: health | career | finance | learning | personal | fitness | creative | social
- target_date: YYYY-MM-DD if mentioned (e.g., "this year" → "2026-12-31")
- start_date: YYYY-MM-DD - when the user intends to start the goal (null if not clearly mentioned)
- end_date: YYYY-MM-DD - the goal deadline (same as target_date if mentioned, otherwise null)
- is_smart: true if goal is specific, measurable, achievable

For **HABIT**:
- name: Clear habit name (corrected spelling/grammar)
- description: What the habit involves
- category: health | productivity | learning | fitness | mindfulness | social | creative | finance | personal
- frequency: daily | weekly
- target_count: Number of times per frequency period (default: 1)

For **BAD_HABIT**:
- app_name: Name of the app (e.g., "Instagram")
- package_name: Android package name if you can guess it (e.g., "com.instagram.android"), otherwise null
- daily_limit_minutes: Integer number of minutes for the limit (default: 30)

**OUTPUT FORMAT:**
Return ONLY valid JSON (no markdown, no extra text):
{{
  "items": [
    {{
      "intent": "task" | "goal" | "habit" | "bad_habit",
      "confidence": "high" | "medium" | "low",
      "data": {{
        // Fields based on intent type
      }}
    }}
  ]
}}

**EXAMPLES:**

Input: "go to city, buy groceries, and buy clothes"
Output: {{
  "items": [
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Go to City",
        "description": "Travel to the city.",
        "priority": "medium",
        "category": "personal",
        "due_date": null,
        "due_time": null
      }}
    }},
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Buy Groceries",
        "description": "Purchase groceries from the store.",
        "priority": "medium",
        "category": "shopping",
        "due_date": null,
        "due_time": null
      }}
    }},
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Buy Clothes",
        "description": "Purchase clothing items.",
        "priority": "medium",
        "category": "shopping",
        "due_date": null,
        "due_time": null
      }}
    }}
  ]
}}

Input: "buy milk tomorrow and exercise daily"
Output: {{
  "items": [
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Buy Milk",
        "description": "Purchase milk from the store.",
        "priority": "medium",
        "category": "shopping",
        "due_date": "{tomorrow}",
        "due_time": null
      }}
    }},
    {{
      "intent": "habit",
      "confidence": "high",
      "data": {{
        "name": "Daily Exercise",
        "description": "Exercise every day to maintain fitness.",
        "category": "fitness",
        "frequency": "daily",
        "target_count": 1
      }}
    }}
  ]
}}

Input: "call mom at 5pm, submit report by Friday, and start meditating every morning"
Output: {{
  "items": [
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Call Mom",
        "description": "Make a phone call to mom.",
        "priority": "medium",
        "category": "personal",
        "due_date": "{today}",
        "due_time": "17:00"
      }}
    }},
    {{
      "intent": "task",
      "confidence": "high",
      "data": {{
        "title": "Submit Report",
        "description": "Submit the report by the deadline.",
        "priority": "high",
        "category": "work",
        "due_date": "2026-02-07",
        "due_time": null
      }}
    }},
    {{
      "intent": "habit",
      "confidence": "high",
      "data": {{
        "name": "Morning Meditation",
        "description": "Practice meditation every morning.",
        "category": "mindfulness",
        "frequency": "daily",
        "target_count": 1
      }}
    }}
  ]
}}

**QUALITY CHECKS:**
- ✅ Correct all spelling errors
- ✅ Fix grammar issues
- ✅ Capitalize titles properly
- ✅ Infer missing information intelligently
- ✅ Return empty array if transcription is unclear
- ✅ Use "low" confidence if uncertain

Analyze the transcription now and return ONLY the JSON:"""

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": settings.AI_MODEL,
                        "messages": [
                            {"role": "user", "content": prompt}
                        ],
                        "temperature": 0.3  # Lower temperature for more consistent parsing
                    }
                )
                response.raise_for_status()
                result = response.json()
                content = result["choices"][0]["message"]["content"]
                
                # Extract JSON from response
                content = content.strip()
                if "```json" in content:
                    start = content.find("```json") + 7
                    end = content.find("```", start)
                    content = content[start:end].strip()
                elif "```" in content:
                    start = content.find("```") + 3
                    end = content.find("```", start)
                    content = content[start:end].strip()
                
                parsed = json.loads(content)
                logger.info(f"Processed voice command: {len(parsed.get('items', []))} items extracted")
                
                return {
                    "items": parsed.get("items", []),
                    "transcription": transcription
                }
                
        except Exception as e:
            logger.error(f"Voice command processing error: {e}")
            # Fallback: try single-intent classification
            try:
                single_result = await self.classify_intent(transcription, context)
                return {
                    "items": [single_result],
                    "transcription": transcription
                }
            except:
                raise Exception(f"Failed to process voice command: {str(e)}")
        return {"items": [], "transcription": transcription} # Final safety

# Create singleton instance
voice_service = VoiceService()
