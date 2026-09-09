import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/task_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TaskService _taskService = TaskService();
  final _aiInputController = TextEditingController();

  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _startTime;
  bool _reminderEnabled = false;
  int _reminderMinutesBefore = 30;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _aiInputController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (_aiInputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task description')),
      );
      return;
    }

    if (_startDate == null || _endDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Date, End Date, and Time are mandatory')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _taskService.createTask(
        userInput: _aiInputController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        startTime: _startTime,
        // For backwards compatibility, send dueDate as well just in case, or API handles it.
        dueDate: _endDate, 
        dueTime: _startTime,
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: _reminderMinutesBefore,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Task'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createTask,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
              // Task Input
              Text(
                'Describe your task',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Example: "Buy groceries tomorrow at 5pm" or "Call dentist next week"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiInputController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your task in natural language...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Start Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: Text(_startDate == null
                    ? 'Start Date (Required)'
                    : 'Start: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                trailing: _startDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startDate = null),
                      )
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate != null && _endDate!.isBefore(date)) {
                        _endDate = date; // ensure end is not before start
                      }
                    });
                  }
                },
              ),

              // End Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available, color: Colors.redAccent),
                title: Text(_endDate == null
                    ? 'End Date (Required)'
                    : 'End: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                trailing: _endDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endDate = null),
                      )
                    : null,
                onTap: () async {
                  final initial = _startDate ?? DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: initial,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),

              // Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text(_startTime == null
                    ? 'Time (Required)'
                    : 'Time: $_startTime'),
                trailing: _startTime != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startTime = null),
                      )
                    : null,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _startTime = time.format(context);
                      _reminderEnabled = true; // Auto-enable reminder when time is set
                    });
                  }
                },
              ),

              // Notification Reminder
              if (_endDate != null) ...[
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active),
                  title: const Text('Reminder Notification'),
                  subtitle: _reminderEnabled
                      ? Text(
                          'Notify $_reminderMinutesBefore minutes before due time')
                      : const Text('Get notified before task is due'),
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer),
                    title: const Text('Remind me'),
                    trailing: DropdownButton<int>(
                      value: _reminderMinutesBefore,
                      items: const [
                        DropdownMenuItem(
                            value: 15, child: Text('15 min before')),
                        DropdownMenuItem(
                            value: 30, child: Text('30 min before')),
                        DropdownMenuItem(
                            value: 60, child: Text('1 hour before')),
                        DropdownMenuItem(
                            value: 120, child: Text('2 hours before')),
                        DropdownMenuItem(
                            value: 1440, child: Text('1 day before')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reminderMinutesBefore = value);
                        }
                      },
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Create Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
