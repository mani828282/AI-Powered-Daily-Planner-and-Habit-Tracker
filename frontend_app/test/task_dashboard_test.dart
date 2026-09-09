import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/tasks/tasks_screen.dart';
import 'package:frontend_app/services/task_service.dart';
import 'package:frontend_app/models/task.dart';

class MockTaskService extends TaskService {
  @override
  Future<List<Task>> getTasks({String? status, String? category, DateTime? date}) async {
    return [
      Task(
        taskId: 1,
        userId: 1,
        title: 'Task 1',
        status: 'pending',
        priority: 'medium',
        createdAt: DateTime.now(),
        aiGenerated: false,
      ),
      Task(
        taskId: 2,
        userId: 1,
        title: 'Task 2',
        status: 'completed',
        priority: 'high',
        createdAt: DateTime.now(),
        aiGenerated: false,
      ),
      Task(
        taskId: 3,
        userId: 1,
        title: 'Task 3',
        status: 'pending',
        priority: 'low',
        createdAt: DateTime.now(),
        aiGenerated: false,
      ),
    ];
  }
}

void main() {
  testWidgets('Task Dashboard displays correct stats',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TasksScreen(taskService: MockTaskService()),
      ),
    );

    // Initial load
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    // Verify Counts
    // Total: 3 (from mock list)
    // Pending: 2 (Task 1, Task 3)
    // Completed: 1 (Task 2)

    expect(find.text('3'), findsOneWidget); // Total
    expect(find.text('2'), findsOneWidget); // Pending
    expect(find.text('1'), findsOneWidget); // Completed

    // Verify Labels
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pending'), findsAtLeastNWidgets(1));
    expect(find.text('Completed'), findsAtLeastNWidgets(1));
  });
}
