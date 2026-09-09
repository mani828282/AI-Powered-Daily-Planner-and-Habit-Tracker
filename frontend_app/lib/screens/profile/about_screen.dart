import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // App Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'AI Planner',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 32),

              // Description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'AI Planner is your intelligent companion for managing tasks, building habits, tracking mood, and achieving goals. Powered by AI, it provides personalized insights to help you stay productive and balanced.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Info Cards
              _buildInfoCard(
                context,
                Icons.code,
                'Developer',
                'Abdul Rehman'
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                Icons.email_outlined,
                'Contact',
                'maharabdulrehman5@gmail.com',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                Icons.language,
                'Website',
                'www.rehmandev.me',
              ),
              const SizedBox(height: 32),

              // Links
              TextButton(
                onPressed: () => _showPolicyDialog(
                  context,
                  'Terms of Service',
                  _termsOfService,
                ),
                child: const Text('Terms of Service'),
              ),
              TextButton(
                onPressed: () => _showPolicyDialog(
                  context,
                  'Privacy Policy',
                  _privacyPolicy,
                ),
                child: const Text('Privacy Policy'),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2025 AI Planner. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static const String _termsOfService = '''
1. Acceptance of Terms
By accessing and using AI Planner, you accept and agree to be bound by the terms and provision of this agreement.

2. Description of Service
AI Planner is an AI-powered daily planning application that provides task management, habit tracking, and mood logging features.

3. User Conduct
You agree to use the service only for lawful purposes. You are solely responsible for all content you generate or upload.

4. AI Features
Our service uses Artificial Intelligence to provide insights. While we strive for accuracy, AI suggestions should be used as guidance only.

5. Data Usage
We collect and process data as described in our Privacy Policy to provide and improve the service.

6. Modifications
We reserve the right to modify these terms at any time. Continued use of the service constitutes acceptance of modified terms.
''';

  static const String _privacyPolicy = '''
1. Information We Collect
- Personal information (Name, Email)
- Usage data (Tasks, Habits, Mood Logs)
- Device information

2. How We Use Your Data
- To provide personalized AI insights
- To improve app functionality and user experience
- To communicate important updates

3. Data Security
We implement industry-standard security measures to protect your data. Your personal entries are encrypted.

4. Third-Party Services
We use Google Gemini API for AI features. Data sent to AI providers is anonymized where possible.

5. User Rights
You have the right to access, correct, or delete your personal data at any time through the app settings.

6. Contact Us
For any privacy concerns, please contact us at support@rehmandev.site.
''';
}
