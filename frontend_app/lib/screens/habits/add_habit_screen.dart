import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/habit_service.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final HabitService _habitService = HabitService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  String _frequency = 'daily';
  String? _category;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  // For custom frequency
  final List<bool> _selectedDays = List.generate(7, (index) => false);
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<String> _fullDayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createHabit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequency == 'custom' && !_selectedDays.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for custom frequency')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? freqDetails;
      if (_frequency == 'custom') {
        List<String> days = [];
        for (int i = 0; i < _selectedDays.length; i++) {
          if (_selectedDays[i]) days.add(_fullDayNames[i]);
        }
        freqDetails = {'days': days};
      }

      await _habitService.createHabit(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _category,
        frequency: _frequency,
        frequencyDetails: freqDetails,
        reminderEnabled: _reminderEnabled,
        reminderTime: _reminderEnabled ? _reminderTime : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Habit created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating habit: $e')),
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
        title: const Text('Add Habit'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createHabit,
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentColor.withValues(alpha: 0.1),
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Smart habit tracking with optimal frequency and timing',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Habit Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Habit Name',
                    hintText: 'e.g., Morning Exercise, Read Daily',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a habit name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Why is this habit important to you?',
                  ),
                ),

                const SizedBox(height: 16),

                // Category
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Category (Optional)',
                    hintText: 'e.g., Health, Productivity, Wellness',
                  ),
                  onChanged: (value) =>
                      _category = value.isEmpty ? null : value,
                ),

                const SizedBox(height: 24),

                // Frequency Selection
                Text(
                  'Frequency',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFrequencyChip('Daily', 'daily'),
                    _buildFrequencyChip('Custom', 'custom'),
                  ],
                ),
                if (_frequency == 'custom') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Select Days',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final isSelected = _selectedDays[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDays[index] = !_selectedDays[index];
                          });
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade200,
                          child: Text(
                            _dayLabels[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 24),

                // Reminder Section
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  _frequency == 'daily' ? 'Daily Reminder' : 'Custom Reminder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active),
                  title: Text(_frequency == 'daily' ? 'Enable Daily Reminder' : 'Enable Custom Reminder'),
                  subtitle: _reminderEnabled
                      ? Text('Remind me at ${_reminderTime.format(context)}')
                      : const Text('Get notified to complete your habit'),
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text('Reminder Time'),
                    trailing: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime,
                        );
                        if (time != null) {
                          setState(() => _reminderTime = time);
                        }
                      },
                      child: Text(
                        _reminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createHabit,
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
                              'Create Habit',
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
      ),
    );
  }

  Widget _buildFrequencyChip(String label, String value) {
    final isSelected = _frequency == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _frequency != value) {
          setState(() {
            _frequency = value;
            _reminderEnabled = false; // Reset toggle on switch
          });
        }
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.accentColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accentColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
