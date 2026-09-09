import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/mood_service.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final MoodService _moodService = MoodService();
  int? _selectedMood;
  int? _selectedEnergy;
  final _notesController = TextEditingController();
  final List<String> _selectedActivities = [];
  bool _isLoading = false;
  Map<String, dynamic>? _insights;
  List<Map<String, dynamic>> _moodLogs = [];

  final List<Map<String, dynamic>> _moodOptions = [
    {
      'level': 1,
      'emoji': '😢',
      'label': 'Very Bad',
      'color': const Color(0xFFFF5252)
    },
    {
      'level': 2,
      'emoji': '😕',
      'label': 'Bad',
      'color': const Color(0xFFFF7043)
    },
    {
      'level': 3,
      'emoji': '😐',
      'label': 'Okay',
      'color': const Color(0xFFFFA726)
    },
    {
      'level': 4,
      'emoji': '🙂',
      'label': 'Good',
      'color': const Color(0xFF66BB6A)
    },
    {
      'level': 5,
      'emoji': '😊',
      'label': 'Great',
      'color': const Color(0xFF26A69A)
    },
  ];

  final List<Map<String, dynamic>> _energyOptions = [
    {'level': 1, 'emoji': '🔋', 'label': 'Drained'},
    {'level': 2, 'emoji': '😴', 'label': 'Low'},
    {'level': 3, 'emoji': '⚡', 'label': 'Medium'},
    {'level': 4, 'emoji': '💪', 'label': 'High'},
    {'level': 5, 'emoji': '🚀', 'label': 'Energized'},
  ];

  final List<Map<String, dynamic>> _activityOptions = [
    {'name': 'Exercise', 'icon': Icons.fitness_center},
    {'name': 'Work', 'icon': Icons.work},
    {'name': 'Social', 'icon': Icons.people},
    {'name': 'Meditation', 'icon': Icons.self_improvement},
    {'name': 'Reading', 'icon': Icons.book},
    {'name': 'Gaming', 'icon': Icons.sports_esports},
    {'name': 'Cooking', 'icon': Icons.restaurant},
    {'name': 'Music', 'icon': Icons.music_note},
  ];

  @override
  void initState() {
    super.initState();
    _loadInsights();
    _loadMoodLogs();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMoodLogs() async {
    try {
      final logs = await _moodService.getMoodLogs();
      if (mounted) {
        setState(() => _moodLogs = logs);
      }
    } catch (e) {
      // print('Error loading mood logs: $e');
    }
  }

  Future<void> _loadInsights() async {
    try {
      final insights = await _moodService.getMoodInsights();
      if (mounted) {
        setState(() => _insights = insights);
      }
    } catch (e) {
      // print('Error loading insights: $e');
    }
  }

  Future<void> _logMood() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your mood')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _moodService.logMood(
        moodLevel: _selectedMood!,
        energyLevel: _selectedEnergy ?? 3,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        activities: _selectedActivities.isEmpty ? null : _selectedActivities,
      );

      if (!mounted) return;

      // Reload data first
      await _loadInsights();
      await _loadMoodLogs();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Mood logged successfully!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );

      // Reset form
      setState(() {
        _selectedMood = null;
        _selectedEnergy = null;
        _selectedActivities.clear();
        _notesController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging mood: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Back Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'How are you feeling?',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28, // Slightly smaller to fit
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMoodSelector(),

                const SizedBox(height: 32),

                // Energy Selector
                _buildSectionTitle("2. How's Your Energy?", '⚡'),
                const SizedBox(height: 16),
                _buildEnergySelector(),

                const SizedBox(height: 32),

                // Activities
                _buildSectionTitle('3. What Did You Do?', '🎯'),
                Text(
                  'Select activities (optional)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 12),
                _buildActivitiesGrid(),

                const SizedBox(height: 32),

                // Notes
                _buildSectionTitle('4. Add a Note', '📝'),
                Text(
                  'How was your day? (optional)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g., Had a great workout today!',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Log Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _logMood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Log My Mood ✨',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Always show mood history section
                _buildMoodHistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.magentaGradient.colors.first.withValues(alpha: 0.1),
            AppTheme.purpleGradient.colors.first.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.magentaGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _insights?['message'] ??
                      'Keep logging daily to get personalized insights!',
                  style: TextStyle(
                    color: Colors.grey[700],
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

  Widget _buildMoodHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Insights Section
        _buildInsightsSection(),
        const SizedBox(height: 32),

        // Mood History
        _buildSectionTitle('Your Mood History', '📊'),
        const SizedBox(height: 16),
        if (_moodLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    '📝',
                    style: TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No mood logs yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start logging your mood to see insights and trends!',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          _buildRecentLogs(),
      ],
    );
  }

  Widget _buildMoodSelector() {
    return Row(
      children: _moodOptions.map((mood) {
        final isSelected = _selectedMood == mood['level'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMood = mood['level'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (mood['color'] as Color).withValues(alpha: 0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isSelected ? (mood['color'] as Color) : Colors.grey[300]!,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              (mood['color'] as Color).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Text(
                    mood['emoji'] as String,
                    style: TextStyle(fontSize: isSelected ? 32 : 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mood['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? mood['color'] as Color
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEnergySelector() {
    return Row(
      children: _energyOptions.map((energy) {
        final isSelected = _selectedEnergy == energy['level'];
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                setState(() => _selectedEnergy = energy['level'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.accentGradient : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.grey[300]!,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Text(
                    energy['emoji'] as String,
                    style: TextStyle(fontSize: isSelected ? 28 : 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    energy['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivitiesGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _activityOptions.map((activity) {
        final isSelected = _selectedActivities.contains(activity['name']);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedActivities.remove(activity['name']);
              } else {
                _selectedActivities.add(activity['name'] as String);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.sunsetGradient : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.sunsetGradient.colors.first
                    : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activity['icon'] as IconData,
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  activity['name'] as String,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentLogs() {
    final recentLogs = _moodLogs.take(5).toList();
    final moodEmojis = ['😢', '😕', '😐', '🙂', '😊'];

    return Column(
      children: recentLogs.map((log) {
        final moodLevel = log['mood_level'] is int
            ? log['mood_level'] as int
            : int.tryParse(log['mood_level'].toString()) ?? 3;
        final emoji = moodEmojis[(moodLevel - 1).clamp(0, 4)];
        final moodId = log['mood_id'];

        return Dismissible(
          key: Key('mood_$moodId'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Mood Log?'),
                content: const Text(
                    'This will permanently delete this mood log and remove it from your insights.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            try {
              if (moodId != null) {
                await _moodService.deleteMoodLog(moodId);
                await _loadMoodLogs();
                await _loadInsights();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Mood log deleted successfully')),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting mood: $e')),
                );
                _loadMoodLogs(); // Reload to restore item
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['log_date']?.toString() ?? 'Today',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (log['notes'] != null)
                        Text(
                          log['notes'] as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Mood Log?'),
                        content: const Text(
                            'This will permanently delete this mood log.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && moodId != null) {
                      try {
                        await _moodService.deleteMoodLog(moodId);
                        await _loadMoodLogs();
                        await _loadInsights();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mood log deleted')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
