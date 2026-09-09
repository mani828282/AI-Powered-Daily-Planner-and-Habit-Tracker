import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/task_service.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/bad_habit_service.dart';

class VoicePreviewModal extends StatefulWidget {
  final List<dynamic> parsedItems;
  final VoidCallback onComplete;

  const VoicePreviewModal({
    super.key,
    required this.parsedItems,
    required this.onComplete,
  });

  @override
  State<VoicePreviewModal> createState() => _VoicePreviewModalState();
}

class _VoicePreviewModalState extends State<VoicePreviewModal> {
  final TaskService _taskService = TaskService();
  final GoalService _goalService = GoalService();
  final HabitService _habitService = HabitService();
  final BadHabitService _badHabitService = BadHabitService();

  late List<Map<String, dynamic>> _items;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the items so we can update dates
    _items = widget.parsedItems.map((item) => Map<String, dynamic>.from(item)).toList();
    for (var item in _items) {
      if (item['data'] != null) {
        item['data'] = Map<String, dynamic>.from(item['data']);
        
        // Parse incoming dates into DateTime if they exist
        final data = item['data'];
        if (data['start_date'] != null && data['start_date'] is String) {
          try {
            data['parsed_start_date'] = DateTime.parse(data['start_date']);
          } catch (e) {
            // keep null
          }
        }
        if (data['end_date'] != null && data['end_date'] is String) {
          try {
            data['parsed_end_date'] = DateTime.parse(data['end_date']);
          } catch (e) {
            // keep null
          }
        }
        if (data['target_date'] != null && data['target_date'] is String) {
          try {
            data['parsed_end_date'] = DateTime.parse(data['target_date']);
          } catch (e) {
            // keep null
          }
        }
        if (data['due_time'] != null && data['due_time'] is String) {
          data['parsed_start_time'] = data['due_time'];
        }
      }
    }
  }

  bool _validateItems() {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final intent = item['intent'];
      final data = item['data'];

      if (intent == 'task') {
        if (data['parsed_start_date'] == null ||
            data['parsed_end_date'] == null ||
            data['parsed_start_time'] == null) {
          setState(() {
            _errorMessage = 'Item ${i + 1} (Task) needs Start Date, End Date, and Time';
          });
          return false;
        }
      } else if (intent == 'goal') {
        if (data['parsed_start_date'] == null || data['parsed_end_date'] == null) {
          setState(() {
            _errorMessage = 'Item ${i + 1} (Goal) needs Start Date and End Date';
          });
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _saveAll() async {
    setState(() => _errorMessage = null);
    if (!_validateItems()) return;

    setState(() => _isSaving = true);

    int tasks = 0, goals = 0, habits = 0, badHabits = 0;

    try {
      for (var item in _items) {
        final intent = item['intent'];
        final data = item['data'];

        if (intent == 'task') {
          await _taskService.createTask(
            userInput: data['title'] ?? 'Task',
            startDate: data['parsed_start_date'],
            endDate: data['parsed_end_date'],
            startTime: data['parsed_start_time'],
            dueDate: data['parsed_end_date'],
            dueTime: data['parsed_start_time'],
          );
          tasks++;
        } else if (intent == 'goal') {
          await _goalService.createGoal(
            title: data['title'] ?? 'Goal',
            description: data['description'],
            category: data['category'],
            startDate: data['parsed_start_date'],
            endDate: data['parsed_end_date'],
            targetDate: data['parsed_end_date'],
          );
          goals++;
        } else if (intent == 'habit') {
          // Add default reminder time if requested or handle based on properties
          await _habitService.createHabit(
            name: data['name'] ?? data['title'] ?? 'Habit',
            description: data['description'],
            frequency: data['frequency'] ?? 'daily',
            targetCount: data['target_count'] ?? 1,
            reminderEnabled: false,
          );
          habits++;
        } else if (intent == 'bad_habit') {
          await _badHabitService.addTrackedApp(
            appName: data['app_name'] ?? data['title'] ?? 'App',
            packageName: data['package_name'] ?? 'com.example.unknown',
            dailyLimitMinutes: data['daily_limit_minutes'] ?? 30,
          );
          badHabits++;
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close modal
        widget.onComplete(); // Trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created $tasks tasks, $goals goals, $habits habits, $badHabits app limits'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no items, simply show an empty state
    if (_items.isEmpty) {
      return AlertDialog(
        title: const Text('Voice Summary'),
        content: const Text('Could not categorize your request into Tasks, Goals, or Habits. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Voice Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const Text(
              'Please review and complete missing mandatory fields before saving.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildItemForm(item, index);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ElevatedButton(
              onPressed: _isSaving ? null : _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm & Save All', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemForm(Map<String, dynamic> item, int index) {
    final intent = item['intent'];
    final data = item['data'];
    final title = data['title'] ?? data['name'] ?? data['app_name'] ?? 'Unknown';

    Color intentColor = Colors.blue;
    IconData intentIcon = Icons.list;
    if (intent == 'task') {
      intentColor = Colors.orange;
      intentIcon = Icons.task_alt;
    } else if (intent == 'goal') {
      intentColor = Colors.purple;
      intentIcon = Icons.flag;
    } else if (intent == 'habit') {
      intentColor = Colors.green;
      intentIcon = Icons.fitness_center;
    } else if (intent == 'bad_habit') {
      intentColor = Colors.red;
      intentIcon = Icons.block;
    }

    final isTaskOrGoal = intent == 'task' || intent == 'goal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: intentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(intentIcon, color: intentColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: intentColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                intent.toString().toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
        if (data['description'] != null) ...[
          const SizedBox(height: 4),
          Text(data['description'], style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
        const SizedBox(height: 12),
        if (isTaskOrGoal) ...[
          // Start Date
          _buildDateField(
            label: 'Start Date',
            value: data['parsed_start_date'],
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: data['parsed_start_date'] ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() {
                  data['parsed_start_date'] = d;
                  if (data['parsed_end_date'] != null && data['parsed_end_date'].isBefore(d)) {
                    data['parsed_end_date'] = d;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 8),
          // End Date
          _buildDateField(
            label: 'End Date',
            value: data['parsed_end_date'],
            onTap: () async {
              final initial = data['parsed_start_date'] ?? DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: data['parsed_end_date'] ?? initial,
                firstDate: initial,
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() => data['parsed_end_date'] = d);
              }
            },
          ),
        ],
        if (intent == 'task') ...[
          const SizedBox(height: 8),
          // Time
          _buildTimeField(
            label: 'Time',
            value: data['parsed_start_time'],
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t != null) {
                setState(() => data['parsed_start_time'] = t.format(context));
              }
            },
          )
        ]
      ],
    );
  }

  Widget _buildDateField({required String label, required DateTime? value, required VoidCallback onTap}) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.1),
          border: Border.all(color: hasValue ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.red, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: hasValue ? AppTheme.primaryColor : Colors.red),
            const SizedBox(width: 8),
            Text(
              hasValue ? '$label: ${value.day}/${value.month}/${value.year}' : '$label (Required)',
              style: TextStyle(
                color: hasValue ? Colors.black87 : Colors.red,
                fontWeight: hasValue ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({required String label, required String? value, required VoidCallback onTap}) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? Colors.blue.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.1),
          border: Border.all(color: hasValue ? Colors.blue.withValues(alpha: 0.3) : Colors.red, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 16, color: hasValue ? Colors.blue : Colors.red),
            const SizedBox(width: 8),
            Text(
              hasValue ? '$label: $value' : '$label (Required)',
              style: TextStyle(
                color: hasValue ? Colors.black87 : Colors.red,
                fontWeight: hasValue ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
