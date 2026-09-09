enum Environment { development, production }

class EnvironmentConfig {
  // Change this to switch between development and production
  static const Environment currentEnvironment = Environment.production;

  static String get apiBaseUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return 'http://localhost:8000';
      case Environment.production:
        // Live Vercel URL (Production Domain)
        return 'https://ai-planner-black.vercel.app';
    }
  }
}
