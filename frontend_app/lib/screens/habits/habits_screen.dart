import 'package:flutter/material.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../services/habit_service.dart';
import '../../models/habit.dart';
import 'add_habit_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with TickerProviderStateMixin {
  final HabitService _habitService = HabitService();
  List<Habit> _habits = [];
  bool _isLoading = true;
  final Map<int, bool> _completedToday = {};
  final Map<int, DateTime?> _lastCompletionTime = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    try {
      final habits = await _habitService.getHabits();
      setState(() {
        _habits = habits;
        _isLoading = false;
        // Initialize completion status from backend data
        for (var habit in habits) {
          _completedToday[habit.habitId] = habit.completedToday;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading habits: $e')),
        );
      }
    }
  }

  Future<void> _completeHabit(Habit habit) async {
    if (_completedToday[habit.habitId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Already completed today! Come back tomorrow'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = await _showMoodEnergyDialog(habit);
    if (data == null) return;

    try {
      final result = await _habitService.completeHabit(
        habitId: habit.habitId,
        moodAtCompletion: data['mood'],
        notes: data['note'],
      );

      setState(() {
        _completedToday[habit.habitId] = true;
        _lastCompletionTime[habit.habitId] = DateTime.now();
      });

      _loadHabits();

      if (mounted) {
        _showCelebration(habit, result, data['mood'], data['energy']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showMoodEnergyDialog(Habit habit) async {
    int? mood;
    int? energy;
    final noteCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPink.withValues(alpha: 0.05),
                  AppTheme.primaryPurple.withValues(alpha: 0.05)
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.psychology,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text('How did this make you feel?',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(habit.name,
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Mood',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildOption(
                          emoji: '😢',
                          label: 'Very\nBad',
                          value: 1,
                          isSelected: mood == 1,
                          onTap: () => setState(() => mood = 1))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '😕',
                          label: 'Bad',
                          value: 2,
                          isSelected: mood == 2,
                          onTap: () => setState(() => mood = 2))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '😐',
                          label: 'Okay',
                          value: 3,
                          isSelected: mood == 3,
                          onTap: () => setState(() => mood = 3))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '🙂',
                          label: 'Good',
                          value: 4,
                          isSelected: mood == 4,
                          onTap: () => setState(() => mood = 4))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '😄',
                          label: 'Great',
                          value: 5,
                          isSelected: mood == 5,
                          onTap: () => setState(() => mood = 5))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Energy',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildOption(
                          emoji: '😴',
                          label: 'Drained',
                          value: 1,
                          isSelected: energy == 1,
                          onTap: () => setState(() => energy = 1))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '💤',
                          label: 'Low',
                          value: 2,
                          isSelected: energy == 2,
                          onTap: () => setState(() => energy = 2))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '😐',
                          label: 'Okay',
                          value: 3,
                          isSelected: energy == 3,
                          onTap: () => setState(() => energy = 3))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '⚡',
                          label: 'Good',
                          value: 4,
                          isSelected: energy == 4,
                          onTap: () => setState(() => energy = 4))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildOption(
                          emoji: '🔥',
                          label: 'High',
                          value: 5,
                          isSelected: energy == 5,
                          onTap: () => setState(() => energy = 5))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Skip'))),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (mood == null || energy == null)
                              ? null
                              : () {
                                  Navigator.pop(context, {
                                    'mood': mood,
                                    'energy': energy,
                                    'note': noteCtrl.text.trim()
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Complete ✓'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
      {required String emoji,
      required String label,
      required int value,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: isSelected ? 28 : 24)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showCelebration(
      Habit habit, Map<String, dynamic> result, int mood, int energy) {
    final streak = result['data']?['current_streak'] ?? 0;

    String msg;
    String emoji;
    if (mood >= 4 && energy >= 4) {
      msg = 'Amazing! High mood AND energy - this habit is perfect for you!';
      emoji = '🎉';
    } else if (mood >= 4) {
      msg = 'Feeling great! This habit boosts your mood!';
      emoji = '😄';
    } else if (energy >= 4) {
      msg = 'Energized! This habit powers you up!';
      emoji = '⚡';
    } else if (mood <= 2 && energy <= 2) {
      msg = 'Tough day, but you still showed up! That\'s what matters!';
      emoji = '💪';
    } else {
      msg = 'Great job completing your habit!';
      emoji = '🎯';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryPink.withValues(alpha: 0.1),
              AppTheme.primaryPurple.withValues(alpha: 0.1)
            ]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                child: Text(emoji, style: const TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              const Text('🎉 Awesome!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('${habit.name} completed!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    gradient: AppTheme.sunsetGradient,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.white),
                    const SizedBox(width: 8),
                    Text('$streak Day Streak!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Keep Going!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Habit'),
        content: Text(
            'Delete "${habit.name}"? All completion history will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _habitService.deleteHabit(habit.habitId);
        _loadHabits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${habit.name} deleted'),
                backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting habit: $e')),
          );
        }
      }
    }
  }

  Future<void> _editHabit(Habit habit) async {
    final nameController = TextEditingController(text: habit.name);
    final descController = TextEditingController(text: habit.description ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Habit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Habit Name',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name cannot be empty')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await _habitService.updateHabit(
                          habit.habitId,
                          name: newName,
                          description: descController.text.trim(),
                        );
                        _loadHabits();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Habit updated!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTimeUntilNext(int habitId) {
    // Calculate time until midnight (next day) for completed habits
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);

    return '${diff.inHours}h ${diff.inMinutes % 60}m until next completion';
  }

  int get _completedCount => _completedToday.values.where((v) => v).length;
  int get _longestStreak => _habits.isEmpty
      ? 0
      : _habits.map((h) => h.currentStreak).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [AppTheme.backgroundLight, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Habits',
                              style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold)),
                          Text('Build your best self, one day at a time',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 28),
                        onPressed: () async {
                          final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AddHabitScreen()));
                          if (result == true) _loadHabits();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _habits.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadHabits,
                            child: ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              children: [
                                _buildProgress(),
                                const SizedBox(height: 24),
                                _buildMotivation(),
                                const SizedBox(height: 24),
                                ..._habits.map((h) => _buildHabitCard(h)),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final rate = _habits.isEmpty
        ? 0
        : ((_completedCount / _habits.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primaryPurple.withValues(alpha: 0.1),
          AppTheme.primaryPink.withValues(alpha: 0.1)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('${_habits.length}', 'Total', AppTheme.primaryPurple,
                  Icons.fitness_center),
              _buildStat('$_completedCount', 'Done Today',
                  AppTheme.successColor, Icons.check_circle),
              _buildStat('$_longestStreak', 'Best Streak', Colors.orange,
                  Icons.local_fire_department),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today\'s Progress',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('$rate%',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(rate == 100
                      ? AppTheme.successColor
                      : AppTheme.primaryPurple),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMotivation() {
    String msg;
    IconData icon;
    Gradient gradient;

    if (_completedCount == _habits.length && _habits.isNotEmpty) {
      msg = '🎉 Perfect day! All habits completed!';
      icon = Icons.emoji_events;
      gradient = AppTheme.sunsetGradient;
    } else if (_longestStreak >= 7) {
      msg = '🔥 Amazing! $_longestStreak-day streak going strong!';
      icon = Icons.local_fire_department;
      gradient = AppTheme.magentaGradient;
    } else if (_completedCount > 0) {
      msg = '💪 Great start! Keep the momentum going!';
      icon = Icons.trending_up;
      gradient = AppTheme.primaryGradient;
    } else {
      msg = '🌟 Ready to crush your habits today?';
      icon = Icons.wb_sunny;
      gradient = AppTheme.accentGradient;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _getQuote(String name) {
    final n = name.toLowerCase();
    if (n.contains('exercise') || n.contains('workout') || n.contains('gym')) {
      return '💪 "The only bad workout is the one you didn\'t do!"';
    }
    if (n.contains('read') || n.contains('book')) {
      return '📚 "A reader lives a thousand lives."';
    }
    if (n.contains('meditat')) return '🧘 "Peace comes from within."';
    if (n.contains('water')) return '💧 "Water is life\'s driving force."';
    if (n.contains('sleep')) return '😴 "Sleep is the best meditation."';
    if (n.contains('study')) return '📖 "Every expert was once a beginner."';
    if (n.contains('write')) {
      return '✍️ "Writing is the painting of the voice."';
    }
    if (n.contains('morning')) return '🌅 "Win the morning, win the day!"';
    return '⭐ "Small daily improvements lead to stunning results."';
  }

  String _getMilestone(int streak) {
    if (streak >= 365) return '🏆 LEGENDARY! One full year!';
    if (streak >= 100) return '💎 CHAMPION! 100+ days!';
    if (streak >= 66) return '🔥 UNSTOPPABLE! Habit formed!';
    if (streak >= 30) return '⭐ AMAZING! One month streak!';
    if (streak >= 21) return '🎯 GREAT! 3 weeks in!';
    if (streak >= 7) return '💪 STRONG! One week done!';
    if (streak >= 3) return '🌟 BUILDING! Keep it up!';
    return '';
  }

  Color _getStreakColor(int streak) {
    if (streak >= 30) return const Color(0xFFFFD700);
    if (streak >= 21) return const Color(0xFFFF6B35);
    if (streak >= 7) return const Color(0xFFFF8C42);
    return Colors.orange.shade300;
  }

  Widget _buildHabitCard(Habit habit) {
    final done = _completedToday[habit.habitId] ?? false;
    final streak = habit.currentStreak;
    final timeLeft = done ? _getTimeUntilNext(habit.habitId) : '';
    final quote = _getQuote(habit.name);
    final milestone = _getMilestone(streak);
    final color = _getStreakColor(streak);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: done
                ? [Colors.white, AppTheme.successColor.withValues(alpha: 0.05)]
                : [Colors.white, AppTheme.primaryPink.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: done
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
            color: done
                ? AppTheme.successColor.withValues(alpha: 0.5)
                : AppTheme.primaryPink.withValues(alpha: 0.3),
            width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: done ? null : () => _completeHabit(habit),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: done
                          ? AppTheme.primaryGradient
                          : LinearGradient(colors: [
                              Colors.grey.shade100,
                              Colors.grey.shade200
                            ]),
                      shape: BoxShape.circle,
                      boxShadow: done
                          ? [
                              BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : [],
                    ),
                    child: Icon(
                        done ? Icons.check_rounded : Icons.circle_outlined,
                        color: done ? Colors.white : Colors.grey,
                        size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: done ? Colors.grey : Colors.black)),
                      const SizedBox(height: 4),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 1.5)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: color, size: 16),
                              const SizedBox(width: 4),
                              Text('$streak day${streak > 1 ? 's' : ''} streak',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppTheme.primaryColor,
                      onPressed: () => _editHabit(habit),
                      tooltip: 'Edit habit',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red.shade300,
                      onPressed: () => _deleteHabit(habit),
                      tooltip: 'Delete habit',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.05),
                  AppTheme.primaryPink.withValues(alpha: 0.05)
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.format_quote,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(quote,
                          style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                              height: 1.4))),
                ],
              ),
            ),
            if (milestone.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1)
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: color.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(milestone,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
            ],
            if (done && timeLeft.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.successColor.withValues(alpha: 0.1),
                    AppTheme.successColor.withValues(alpha: 0.05)
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.timer_outlined,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✅ Completed for today!',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor)),
                          const SizedBox(height: 2),
                          Text(timeLeft,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle,
                        size: 24, color: AppTheme.successColor),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child:
                  const Icon(Icons.auto_awesome, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 32),
            const Text('Start Your Journey',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
                'Build positive habits and transform your life, one day at a time!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 16, height: 1.5)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddHabitScreen()));
                if (result == true) _loadHabits();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Your First Habit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
