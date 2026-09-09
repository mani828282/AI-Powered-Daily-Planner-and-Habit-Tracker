import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/task_service.dart';
import '../../models/task.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  final TaskService? taskService;
  const TasksScreen({super.key, this.taskService});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TaskService _taskService;
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, completed
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _taskService = widget.taskService ?? TaskService();
    _loadTasks();
    // Re-register any existing task reminders (in case of app restart)
    _taskService.rescheduleAllNotifications();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      List<Task> tasks;
      if (_filter == 'pending') {
        tasks = await _taskService.getTasks(status: 'pending', date: _selectedDate);
      } else if (_filter == 'completed') {
        tasks = await _taskService.getTasks(status: 'completed', date: _selectedDate);
      } else {
        tasks = await _taskService.getTasks(date: _selectedDate);
      }
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  Future<void> _toggleTaskStatus(Task task) async {
    try {
      if (task.status == 'pending') {
        await _taskService.completeTask(task.taskId);
      } else {
        await _taskService.updateTask(task.taskId, status: 'pending');
      }
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e')),
        );
      }
    }
  }

  Future<void> _editTask(Task task) async {
    final titleController = TextEditingController(text: task.title);
    DateTime? startDate = task.startDate;
    DateTime? endDate = task.endDate ?? task.dueDate;
    String? startTime = task.startTime ?? task.dueTime;
    if (startTime != null && startTime.length > 5) {
      startTime = startTime.substring(0, 5);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                      'Edit Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'Enter task title',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today,
                          color: Colors.orange),
                      title: Text(startDate == null
                          ? 'Start Date'
                          : 'Start: ${startDate!.day}/${startDate!.month}/${startDate!.year}'),
                      trailing: startDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setModalState(() => startDate = null),
                            )
                          : null,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startDate = picked;
                            if (endDate != null && endDate!.isBefore(picked)) {
                              endDate = picked;
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available,
                          color: Colors.redAccent),
                      title: Text(endDate == null
                          ? 'End Date'
                          : 'End: ${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                      trailing: endDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setModalState(() => endDate = null),
                            )
                          : null,
                      onTap: () async {
                        final initial = startDate ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: endDate ?? initial,
                          firstDate: initial,
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() => endDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.access_time, color: Colors.blue),
                      title: Text(
                          startTime == null ? 'Time' : 'Time: $startTime'),
                      trailing: startTime != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setModalState(() => startTime = null),
                            )
                          : null,
                      onTap: () async {
                        TimeOfDay? initial;
                        if (startTime != null) {
                          final parts = startTime!.split(':');
                          if (parts.length >= 2) {
                            initial = TimeOfDay(
                              hour: int.tryParse(parts[0]) ?? 0,
                              minute: int.tryParse(parts[1]) ?? 0,
                            );
                          }
                        }
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: initial ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startTime = picked.format(ctx);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newTitle = titleController.text.trim();
                          if (newTitle.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Title cannot be empty')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await _taskService.updateTask(
                              task.taskId,
                              title: newTitle,
                              startDate: startDate,
                              endDate: endDate,
                              startTime: startTime,
                              dueDate: endDate,
                              dueTime: startTime,
                            );
                            _loadTasks();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Task updated successfully!')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error updating task: $e')),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _taskService.deleteTask(task.taskId);
        _loadTasks();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting task: $e')),
          );
        }
      }
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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tasks',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          Text(
                            '${_tasks.length} tasks',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddTaskScreen(),
                            ),
                          );
                          if (result == true) _loadTasks();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Date Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        });
                        _loadTasks();
                      },
                    ),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                          _loadTasks();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              _formatSelectedDate(_selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                        });
                        _loadTasks();
                      },
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', 'completed'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress Stats
              if (_tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTaskStats(),
                ),

              const SizedBox(height: 16),

              // Task List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tasks.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadTasks,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _tasks.length,
                              itemBuilder: (context, index) {
                                return _buildTaskCard(_tasks[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    
    if (selected == today) return 'Today';
    if (selected == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (selected == today.add(const Duration(days: 1))) return 'Tomorrow';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
        _loadTasks();
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isCompleted = task.status == 'completed';
    Gradient priorityGradient;
    switch (task.priority) {
      case 'high':
        priorityGradient = const LinearGradient(
          colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case 'medium':
        priorityGradient = AppTheme.sunsetGradient;
        break;
      default:
        priorityGradient = const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? LinearGradient(
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade200,
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.white,
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? Colors.grey.withValues(alpha: 0.2)
                : AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isCompleted
              ? Colors.grey.shade300
              : AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleTaskStatus(task),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: isCompleted ? AppTheme.primaryGradient : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? Colors.transparent
                        : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : null,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  // Description removed to reduce clutter
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: priorityGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task.priority.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildDueDateBadge(task),
                      if (task.aiGenerated)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: AppTheme.magentaGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              size: 12, color: Colors.white),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Edit + Delete Buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppTheme.primaryColor,
                  onPressed: () => _editTask(task),
                  tooltip: 'Edit task',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.errorColor,
                  onPressed: () => _deleteTask(task),
                  tooltip: 'Delete task',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first task',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(Task task) {
    // Determine the relevant date to show. Start date takes priority since we filter by it.
    final dateToShow = task.startDate ?? task.dueDate;
    final timeToShow = task.startTime ?? task.dueTime;
    
    if (dateToShow == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      dateToShow.year,
      dateToShow.month,
      dateToShow.day,
    );

    // Determine status: overdue, today, or upcoming
    final isOverdue = targetDate.isBefore(today);
    final isToday = targetDate.isAtSameMomentAs(today);

    Color badgeColor;
    IconData icon;
    String label;

    if (isOverdue) {
      badgeColor = const Color(0xFFFF1744); // Red
      icon = Icons.warning_amber_rounded;
      label = 'Overdue';
    } else if (isToday) {
      badgeColor = const Color(0xFFFF9800); // Orange
      icon = Icons.today;
      label = 'Today';
    } else {
      badgeColor = const Color(0xFF2196F3); // Blue
      icon = Icons.calendar_today;
      label = '${dateToShow.day}/${dateToShow.month}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (timeToShow != null) ...[
            const SizedBox(width: 4),
            Text(
              // Trim seconds if time is in HH:MM:SS format
              timeToShow.length > 5
                  ? timeToShow.substring(0, 5)
                  : timeToShow,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskStats() {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.status == 'completed').length;
    final pending = total - completed;

    return Container(
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
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.list_alt,
            label: 'Total',
            value: '$total',
            color: AppTheme.primaryColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.pending_actions,
            label: 'Pending',
            value: '$pending',
            color: AppTheme.accentColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: '$completed',
            color: AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
