import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification Settings
  final bool _isLoading = false;

  // removed local _darkModeEnabled
  // removed local _selectedLanguage

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Account Security Section

                  // Account Security Section
                  _buildSectionHeader('Account & Security'),
                  _buildSettingCard(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your security credentials',
                    iconColor: Colors.teal,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                  const SizedBox(height: 24),

                  // Support Section
                  _buildSectionHeader('Support'),
                  _buildSettingCard(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Get help or send feedback',
                    iconColor: Colors.purple,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showSupportDialog,
                  ),
                  const SizedBox(height: 24),

                  // Danger Zone
                  _buildSectionHeader('Danger Zone'),
                  _buildSettingCard(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your data',
                    iconColor: Colors.red,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
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
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(icon, color: iconColor ?? AppTheme.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Old Password'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm New Password'),
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          // Better to use Provider
                          await context.read<AuthService>().changePassword(
                                oldPassword: oldPasswordController.text,
                                newPassword: newPasswordController.text,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to change password: ${e.toString().replaceAll("Exception:", "")}'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final emailController = TextEditingController(); // Optional
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Help & Support'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Have a question or feedback? Fill out the form below and we will get back to you.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      helperText: 'For us to contact you back',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          final apiService = ApiService();
                          await apiService.post('/api/support', {
                            'subject': subjectController.text,
                            'message': messageController.text,
                            'email': emailController.text.isNotEmpty
                                ? emailController.text
                                : null,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Request submitted successfully!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to submit request'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Account'),
          content: isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Deleting account...'),
                  ],
                )
              : const Text(
                  'Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.',
                ),
          actions: [
            if (!isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            if (!isLoading)
              TextButton(
                onPressed: () async {
                  setState(() => isLoading = true);
                  try {
                    await context.read<AuthService>().deleteAccount();
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      // Navigate to login is handled by auth service logout state usually,
                      // but let's force it
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => isLoading = false);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete account: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
