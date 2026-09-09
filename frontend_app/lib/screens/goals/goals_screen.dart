import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/goal_service.dart';
import '../../models/goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _goalService = GoalService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Goal> _goals = [];
  bool _isLoading = true;
  bool _isCreating = false;
  bool _showAddForm = false;
  final Set<int> _expandedGoals = {};

  String _selectedCategory = 'Personal';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _categories = [
    'Health',
    'Career',
    'Finance',
    'Learning',
    'Personal'
  ];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _goalService.getGoals();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: $e')),
        );
      }
    }
  }

  Future<void> _toggleSubtask(int goalId, int subtaskId) async {
    try {
      final result = await _goalService.toggleSubtask(subtaskId);
      await _loadGoals();

      // Check for milestone
      if (result['milestone_reached'] == true) {
        final message = result['celebration_message'] ?? 'Great progress!';
        final progress = result['progress_percentage'] ?? 0.0;

        if (mounted) {
          _showCelebrationDialog(message, progress);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating subtask: $e')),
        );
      }
    }
  }

  void _showCelebrationDialog(String message, double progress) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.1),
                AppTheme.accentColor.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Progress
              Text(
                '${progress.toInt()}%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Goal'),
          content: Text(
            'Delete "${goal.title}"? All subtasks will also be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && goal.goalId != null) {
      try {
        await _goalService.deleteGoal(goal.goalId!);
        _loadGoals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${goal.title} deleted'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting goal: $e')),
          );
        }
      }
    }
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Date and End Date are mandatory')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _goalService.createGoal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        startDate: _startDate,
        endDate: _endDate,
        targetDate: _endDate, // for backwards compatibility
        aiDecompose: true,
      );

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _showAddForm = false;
        _isCreating = false;
        _startDate = null;
        _endDate = null;
        _selectedCategory = 'Personal';
      });
      _loadGoals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Goal created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating goal: $e')),
        );
      }
    }
  }

  int get _completedGoals => _goals.where((g) {
        final completed = g.subtasks?.where((s) => s.completed).length ?? 0;
        final total = g.subtasks?.length ?? 0;
        return total > 0 && completed == total;
      }).length;

  int get _inProgressGoals => _goals.length - _completedGoals;

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
                            'Goals',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '${_goals.length} active goals',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showAddForm ? Icons.close : Icons.add_circle,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () =>
                          setState(() => _showAddForm = !_showAddForm),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Progress Stats
                      if (_goals.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildProgressStats(),
                        ),

                      // Add Goal Form
                      if (_showAddForm) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Goal Title',
                                    hintText: 'e.g., Learn Flutter Development',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a goal title';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Description (Optional)',
                                    hintText: 'Why is this goal important?',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: _categories.map((String category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCategory = newValue!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365 * 5)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _startDate = picked;
                                        if (_endDate != null && _endDate!.isBefore(picked)) {
                                          _endDate = picked;
                                        }
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date (Required)',
                                      suffixIcon: Icon(Icons.calendar_today, color: Colors.orange),
                                    ),
                                    child: Text(
                                      _startDate == null
                                          ? 'Select Start Date'
                                          : '${_startDate!.toLocal()}'
                                              .split(' ')[0],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    final initial = _startDate ?? DateTime.now();
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: initial,
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365 * 5)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _endDate = picked;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date (Required)',
                                      suffixIcon: Icon(Icons.event_available, color: Colors.redAccent),
                                    ),
                                    child: Text(
                                      _endDate == null
                                          ? 'Select End Date'
                                          : '${_endDate!.toLocal()}'
                                              .split(' ')[0],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isCreating ? null : _createGoal,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: _isCreating
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text('Create Goal'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Goals List
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: CircularProgressIndicator(),
                        )
                      else if (_goals.isEmpty && !_showAddForm)
                        _buildEmptyState()
                      else if (_goals.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _goals.length,
                          itemBuilder: (context, index) {
                            return _buildGoalCard(_goals[index]);
                          },
                        ),
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

  Widget _buildProgressStats() {
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
            icon: Icons.flag,
            label: 'Total',
            value: '${_goals.length}',
            color: AppTheme.primaryColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.trending_up,
            label: 'In Progress',
            value: '$_inProgressGoals',
            color: AppTheme.accentColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'Completed',
            value: '$_completedGoals',
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

  Widget _buildGoalCard(Goal goal) {
    // Determine category color
    Color categoryColor = AppTheme.primaryColor;
    switch (goal.category?.toLowerCase()) {
      case 'health':
        categoryColor = Colors.green;
        break;
      case 'career':
        categoryColor = Colors.blue;
        break;
      case 'finance':
        categoryColor = Colors.amber.shade700;
        break;
      case 'learning':
        categoryColor = Colors.purple;
        break;
      case 'personal':
        categoryColor = Colors.orange;
        break;
    }

    final endDate = goal.endDate ?? goal.targetDate;
    final int daysLeft = endDate != null
        ? endDate.difference(DateTime.now()).inDays
        : -1;
    final String deadlineText = endDate == null
        ? 'No deadline'
        : (daysLeft >= 0 ? '$daysLeft days left' : 'Overdue');

    final progress = goal.progressPercentage / 100.0;

    // Find next step
    Subtask? nextStep;
    if (goal.subtasks != null) {
      for (var subtask in goal.subtasks!) {
        if (!subtask.completed) {
          nextStep = subtask;
          break;
        }
      }
    }

    final isExpanded = _expandedGoals.contains(goal.goalId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade300,
                  onPressed: () => _deleteGoal(goal),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category Tag & Deadline
            Row(
              children: [
                if (goal.category != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      goal.category!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                if (goal.category != null) const SizedBox(width: 12),
                if (endDate != null)
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        deadlineText,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              daysLeft < 0 ? Colors.red : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                if (goal.aiDecomposed)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.magentaGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 12),
                  ),
              ],
            ),

            if (goal.description != null) ...[
              const SizedBox(height: 12),
              Text(
                goal.description!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),

            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '${goal.completedSubtasks}/${goal.totalSubtasks} steps (${(progress * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),

            const SizedBox(height: 20),

            // Next Step Highlight
            if (nextStep != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          size: 16, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Next Step',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            nextStep.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: nextStep.completed,
                      onChanged: (_) =>
                          _toggleSubtask(goal.goalId!, nextStep!.subtaskId!),
                      activeColor: AppTheme.successColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (goal.totalSubtasks > 0 &&
                goal.completedSubtasks == goal.totalSubtasks) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.successColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Goal completed! Amazing work!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Subtasks Toggle
            if (goal.subtasks != null && goal.subtasks!.isNotEmpty)
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGoals.remove(goal.goalId);
                    } else {
                      _expandedGoals.add(goal.goalId!);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? 'Hide Steps' : 'View Steps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ],
                ),
              ),

            // Collapsed Subtasks List
            if (isExpanded && goal.subtasks != null) ...[
              const SizedBox(height: 8),
              ...goal.subtasks!.map((subtask) {
                // A subtask is locked if ANY earlier step (lower order_index) is incomplete
                final isLocked = goal.subtasks!.any(
                  (s) => s.orderIndex < subtask.orderIndex && !s.completed,
                );
                final textColor = subtask.completed
                    ? Colors.grey
                    : isLocked
                        ? Colors.grey.shade400
                        : Colors.black87;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: isLocked
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(Icons.lock_outline,
                              size: 20, color: Colors.grey.shade400),
                        )
                      : Checkbox(
                          value: subtask.completed,
                          onChanged: subtask.completed
                              ? null // already done — allow unchecking via toggle
                              : (_) => _toggleSubtask(
                                  goal.goalId!, subtask.subtaskId!),
                          activeColor: AppTheme.successColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                  title: Text(
                    subtask.title,
                    style: TextStyle(
                      decoration: subtask.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: isLocked
                      ? Text(
                          'Complete the previous step first',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        )
                      : null,
                  // Allow tapping a completed subtask to uncheck it
                  onTap: (!isLocked && subtask.completed)
                      ? () => _toggleSubtask(goal.goalId!, subtask.subtaskId!)
                      : null,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'No Goals Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set your first goal and let AI help you achieve it!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddForm = true),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
