import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../tasks/tasks_screen.dart';
import '../habits/habits_screen.dart';
import '../goals/goals_screen.dart';
import '../bad_habits/bad_habits_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/about_screen.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/voice_recorder.dart';
import '../../widgets/voice_preview_modal.dart';
import '../../services/voice_service.dart';
import '../../services/notification_service.dart';
import '../../models/task.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  int _currentIndex = 0;
  Map<String, dynamic> _dashboardData = {};
  bool _isLoadingDashboard = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardDataInBackground();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request permissions after a short delay to ensure UI is ready
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await NotificationService().requestPermissions();
    }
  }

  Future<void> _loadDashboardDataInBackground() async {
    if (_isLoadingDashboard) return;

    setState(() => _isLoadingDashboard = true);

    try {
      final data = await _dashboardService.getDashboardData();
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      // Log error and keep default values
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
      // print('Dashboard data load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F5), // Lavender blush pink color
      body: Container(
        color: Colors.transparent, // Let Scaffold background show through
        child: SafeArea(child: _getCurrentPage(user)),
      ),
      floatingActionButton: _buildVoiceFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Reload dashboard data when switching to home tab
          if (index == 0) {
            _loadDashboardDataInBackground();
          }
        },
      ),
    );
  }

  Widget _buildVoiceFAB() {
    // Return just the widget. Spacing and "docking" is handled by the FloatingActionButtonLocation.centerDocked
    // and the CircularNotchedRectangle notchMargin in CustomBottomNavBar.
    return VoiceRecorderWidget(
      onRecordingComplete: _handleVoiceRecording,
      context: _getContextFromIndex(),
    );
  }

  String _getContextFromIndex() {
    switch (_currentIndex) {
      case 1:
        return 'tasks';
      case 2:
        return 'habits';
      case 4:
        return 'goals';
      default:
        return 'tasks';
    }
  }

  Future<void> _handleVoiceRecording(dynamic audioData) async {
    final voiceService = getVoiceService();

    try {
      final context = _getContextFromIndex();

      // Show processing dialog
      showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing voice command...'),
                  SizedBox(height: 8),
                  Text(
                    'Analyzing your request',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Process voice command (preview only)
      final result = await voiceService.processVoiceCommand(
        audioData,
        context: context,
        previewOnly: true,
      );

      // Clean up audio file
      await voiceService.deleteAudioFile(audioData);

      // Close processing dialog
      if (mounted) {
        Navigator.of(this.context).pop();
      }

      // Extract batch creation results
      final items = result['parsed_items'] as List<dynamic>? ?? [];
      final totalCount = result['total_count'] ?? 0;

      if (mounted && items.isNotEmpty) {
        // Show validation modal
        await showDialog(
          context: this.context,
          barrierDismissible: false,
          builder: (context) => VoicePreviewModal(
            parsedItems: items,
            onComplete: () {
              // Reload dashboard data
              _loadDashboardDataInBackground();
            },
          ),
        );
      } else if (mounted) {
        // No items created
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No items were created. Please try again with a clearer command.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close processing dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to process voice: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _getCurrentPage(user) {
    switch (_currentIndex) {
      case 0:
        return _buildHome(user?.fullName ?? 'User');
      case 1:
        return const TasksScreen();
      case 2:
        return const HabitsScreen();
      case 3:
        return const BadHabitsScreen();
      case 4:
        return const GoalsScreen();
      case 5:
        return _buildProfile(user);
      default:
        return _buildHome(user?.fullName ?? 'User');
    }
  }

  Widget _buildHome(String userName) {
    final todayTasks = _dashboardData['today_tasks'] ?? 0;
    final todayHabits = _dashboardData['today_habits'] ?? 0;
    final longestStreak = _dashboardData['longest_streak'] ?? 0;
    final completionRate = _dashboardData['completion_rate'] ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Centered Welcome Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Hello, $userName! 👋',
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ready to make today amazing?',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedStatCard(
                        'Active Tasks',
                        todayTasks > 0 ? '$todayTasks' : '0',
                        Icons.assignment_outlined,
                        AppTheme.gradient1,
                        '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedStatCard(
                        'Active Habits',
                        todayHabits > 0 ? '$todayHabits' : '0',
                        Icons.fitness_center_outlined,
                        AppTheme.gradient2,
                        '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedStatCard(
                        'Habit Streak',
                        longestStreak > 0 ? '$longestStreak' : '0',
                        Icons.local_fire_department_outlined,
                        AppTheme.gradient6,
                        'days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedStatCard(
                        'Tasks Done',
                        completionRate > 0 ? '$completionRate%' : '0%',
                        Icons.check_circle_outline,
                        AppTheme.gradient4,
                        'today',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Visual AI Insights
                Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildVisualInsights(todayTasks, todayHabits, completionRate),
                const SizedBox(height: 24),

                // Quick Actions - Horizontal Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        'Add Task\nwith AI',
                        'Create tasks',
                        Icons.add_task,
                        const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                        ),
                        () {
                          setState(() => _currentIndex = 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        'Add Habit',
                        'Track habits',
                        Icons.fitness_center,
                        const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)],
                        ),
                        () {
                          setState(
                            () => _currentIndex = 2,
                          ); // Navigate to Habits tab
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Smart Insights Section
                Text(
                  'Smart Insights',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildSmartInsightsPreview(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartInsightsPreview() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/insights');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryPurple.withValues(alpha: 0.1),
              AppTheme.primaryPink.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.insights,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mood & Habit Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Discover patterns between your mood and habits. See which habits boost your mood and get personalized recommendations!',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'View All Insights',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatCard(
    String label,
    String value,
    IconData icon,
    Gradient gradient,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualInsights(int tasks, int habits, int completion) {
    final taskPercentage =
        (tasks > 0 ? (tasks / 10).clamp(0.0, 1.0) : 0.0) * 100;
    final habitPercentage =
        (habits > 0 ? (habits / 10).clamp(0.0, 1.0) : 0.0) * 100;
    final productivityPercentage = completion.toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppTheme.primaryColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'AI Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Circular Progress Indicators
          Row(
            children: [
              Expanded(
                child: _buildCircularProgress(
                  'Task\nFocus',
                  taskPercentage,
                  const Color(0xFFE91E63),
                  Icons.task_alt,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCircularProgress(
                  'Habit\nConsistency',
                  habitPercentage,
                  const Color(0xFF00BCD4),
                  Icons.fitness_center,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCircularProgress(
                  'Productivity',
                  productivityPercentage,
                  const Color(0xFF9C27B0),
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(
    String label,
    double percentage,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 85,
          height: 85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 7,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(Colors.grey.shade200),
                ),
              ),
              // Progress circle with gradient effect
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 7,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Gradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 32),

          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.accentColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: user?.profilePicture == null
                        ? AppTheme.primaryGradient
                        : null,
                    shape: BoxShape.circle,
                    image: user?.profilePicture != null
                        ? DecorationImage(
                            image: NetworkImage(
                              '${ApiConfig.baseUrl}${user!.profilePicture}',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.profilePicture == null
                      ? const Icon(
                          Icons.person,
                          size: 35,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phoneNumber ?? '',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                    if (result == true) {
                      setState(() {});
                    }
                  },
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Menu Items
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Notifications, appearance, and more',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                final authService = context.read<AuthService>();
                await authService.logout();
                if (!mounted) return;
                Navigator.of(context).pushReplacementNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
