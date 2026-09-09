import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: December 2025',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                'Information We Collect',
                'We collect information you provide directly to us, including your name, email address, phone number, and any other information you choose to provide. We also collect information about your usage of the app, including tasks, habits, goals, and mood logs.',
              ),
              _buildSection(
                context,
                'How We Use Your Information',
                'We use the information we collect to provide, maintain, and improve our services, including to personalize your experience with AI-powered insights and recommendations. We also use your information to communicate with you about updates and features.',
              ),
              _buildSection(
                context,
                'Data Storage and Security',
                'Your data is stored securely on our servers. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
              ),
              _buildSection(
                context,
                'AI and Data Processing',
                'We use AI services to analyze your habits, tasks, and mood patterns to provide personalized insights. This processing is done securely and your data is not shared with third parties for marketing purposes.',
              ),
              _buildSection(
                context,
                'Your Rights',
                'You have the right to access, update, or delete your personal information at any time. You can do this through the app settings or by contacting us directly.',
              ),
              _buildSection(
                context,
                'Changes to This Policy',
                'We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy on this page and updating the "Last updated" date.',
              ),
              _buildSection(
                context,
                'Contact Us',
                'If you have any questions about this privacy policy, please contact us through the app or via email.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
