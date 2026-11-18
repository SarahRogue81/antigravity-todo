import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:todo/app.dart';
import 'package:todo/core/storage/hive_storage_service.dart';
import 'package:todo/features/todo/data/hive_todo_repository.dart';
import 'package:todo/features/todo/domain/todo_item.dart';
import 'package:todo/features/todo/domain/todo_repository.dart';
import 'package:todo/features/todo/presentation/controllers/todo_controller.dart';

/// In-memory fake implementation of [TodoRepository] for fast unit & widget tests.
class FakeTodoRepository implements TodoRepository {
  final Map<String, TodoItem> _store = {};

  @override
  Future<List<TodoItem>> getAllTodos() async =>
      _store.values.toList(growable: false);

  @override
  Future<void> saveTodo(TodoItem item) async {
    _store[item.id] = item;
  }

  @override
  Future<void> saveAllTodos(Iterable<TodoItem> items) async {
    for (final item in items) {
      _store[item.id] = item;
    }
  }

  @override
  Future<void> deleteTodosByIds(Iterable<String> ids) async {
    for (final id in ids) {
      _store.remove(id);
    }
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

void main() {
  group('TodoController & Hierarchical Sub-Task Unit Tests', () {
    late FakeTodoRepository repository;
    late TodoController controller;

    setUp(() async {
      repository = FakeTodoRepository();
      controller = TodoController(repository);
      await controller.loadTodos();
    });

    test(
      'Starts with a clean slate on launch and purges any legacy seed tasks',
      () async {
        expect(controller.itemsById.value, isEmpty);
        expect(controller.visibleScopeTasks.value, isEmpty);
        expect(controller.stats.value.total, 0);

        // Simulate legacy seeded tasks in repository alongside a user task
        final now = DateTime.now();
        await repository.saveAllTodos([
          TodoItem(id: 'seed_root_1', title: 'Legacy Seed', createdAt: now),
          TodoItem(
            id: 'seed_sub_1_1',
            parentId: 'seed_root_1',
            title: 'Legacy Seed Sub',
            createdAt: now,
          ),
          TodoItem(id: 'todo_user_1', title: 'My Real Task', createdAt: now),
        ]);

        await controller.loadTodos();
        expect(controller.itemsById.value.keys, ['todo_user_1']);
        final remainingInRepo = await repository.getAllTodos();
        expect(remainingInRepo.map((e) => e.id).toList(), ['todo_user_1']);
      },
    );

    test('Creates root tasks, sub-tasks, and sub-sub-tasks with accurate depth and progress', () async {
      final root = await controller.addTodo(
        title: 'Build Spaceship',
        notes: 'Interstellar cruiser',
        priority: TodoPriority.high,
      );
      expect(root, isNotNull);
      expect(controller.depthOf(root!.id), 0);

      final sub1 = await controller.addTodo(
        title: 'Assemble Propulsion',
        parentId: root.id,
      );
      final sub2 = await controller.addTodo(
        title: 'Install Life Support',
        parentId: root.id,
      );
      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      expect(controller.depthOf(sub1!.id), 1);

      final subSub1 = await controller.addTodo(
        title: 'Calibrate Ion Thrusters',
        parentId: sub1.id,
      );
      expect(subSub1, isNotNull);
      expect(controller.depthOf(subSub1!.id), 2);

      // Verify ancestor chain for sub-sub-task
      final chain = controller.getAncestorChain(subSub1.id);
      expect(chain.map((e) => e.id).toList(), [root.id, sub1.id, subSub1.id]);

      // Verify subtree progress calculation
      var rootProgress = controller.progressFor(root.id);
      expect(rootProgress.totalDescendants, 3);
      expect(rootProgress.completedDescendants, 0);

      // Toggle leaf sub-sub-task -> should auto-complete sub1 (since subSub1 is its only child)
      await controller.toggleTodoCompletion(subSub1.id);
      expect(controller.itemsById.value[subSub1.id]!.isCompleted, isTrue);
      expect(controller.itemsById.value[sub1.id]!.isCompleted, isTrue);
      expect(controller.itemsById.value[root.id]!.isCompleted, isFalse);

      rootProgress = controller.progressFor(root.id);
      expect(rootProgress.completedDescendants, 2);

      // Toggle root task -> cascades completion to all descendants
      await controller.toggleTodoCompletion(root.id);
      expect(controller.itemsById.value[root.id]!.isCompleted, isTrue);
      expect(controller.itemsById.value[sub2!.id]!.isCompleted, isTrue);
    });

    test(
      'Updates task details and cascades deletion to nested sub-tasks',
      () async {
        final root = await controller.addTodo(title: 'Parent Task');
        final sub = await controller.addTodo(
          title: 'Child Task',
          parentId: root!.id,
        );
        final grandChild = await controller.addTodo(
          title: 'Grandchild Task',
          parentId: sub!.id,
        );

        await controller.updateTodo(
          id: sub.id,
          title: 'Updated Child Task',
          notes: 'Updated notes',
          priority: TodoPriority.high,
        );
        expect(controller.itemsById.value[sub.id]!.title, 'Updated Child Task');
        expect(controller.itemsById.value[sub.id]!.priority, TodoPriority.high);

        // Focus grandChild, then delete sub -> grandChild and sub should both be removed
        // and focus should fall back to root
        controller.focusTask(grandChild!.id);
        expect(controller.focusedTaskId.value, grandChild.id);

        await controller.deleteTodo(sub.id);
        expect(controller.itemsById.value.containsKey(sub.id), isFalse);
        expect(controller.itemsById.value.containsKey(grandChild.id), isFalse);
        expect(controller.itemsById.value.containsKey(root.id), isTrue);
        expect(controller.focusedTaskId.value, root.id);
      },
    );
  });

  group('HiveTodoRepository Integration Tests', () {
    late Directory tempDir;
    late Box<TodoItem> box;
    late HiveTodoRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('fractal_todo_hive_test_');
      Hive.init(tempDir.path);
      HiveStorageService.registerAdaptersIfNeeded();
      box = await Hive.openBox<TodoItem>('test_todos_box');
      repository = HiveTodoRepository(box);
    });

    tearDown(() async {
      await box.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Persists and retrieves hierarchical TodoItems via Hive CE', () async {
      final now = DateTime.now();
      final root = TodoItem(
        id: 'r1',
        title: 'Root Item',
        createdAt: now,
        priority: TodoPriority.high,
      );
      final child = TodoItem(
        id: 'c1',
        parentId: 'r1',
        title: 'Child Item',
        notes: 'Nested note',
        createdAt: now,
        priority: TodoPriority.low,
      );

      await repository.saveAllTodos([root, child]);
      final loaded = await repository.getAllTodos();
      expect(loaded.length, 2);
      expect(loaded.any((e) => e.id == 'c1' && e.parentId == 'r1'), isTrue);

      await repository.deleteTodosByIds(['c1']);
      final remaining = await repository.getAllTodos();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'r1');
    });
  });

  group('Responsive & Adaptive Dark Mode Widget Tests', () {
    testWidgets(
      'Adapts cleanly across Phone (<600dp), Tablet (600-839dp), and Chromebook/Laptop (>=840dp)',
      (tester) async {
        final repository = FakeTodoRepository();
        final controller = TodoController(repository);
        await controller.loadTodos();

        // 1. Phone viewport (< 600dp)
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(412, 892);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(FractalTodoApp(controller: controller));
        await tester.pumpAndSettle();

        // Verify clean slate on launch
        expect(
          find.byKey(const Key('empty_tasks_placeholder')),
          findsOneWidget,
        );

        // Verify dark mode theme and compact NavigationBar
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);
        expect(find.byKey(const Key('compact_navigation_bar')), findsOneWidget);
        expect(find.byKey(const Key('adaptive_navigation_rail')), findsNothing);
        expect(find.byKey(const Key('expanded_detail_panel')), findsNothing);

        // 2. Tablet viewport (600dp - 839dp)
        tester.view.physicalSize = const Size(768, 1024);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('compact_navigation_bar')), findsNothing);
        expect(
          find.byKey(const Key('adaptive_navigation_rail')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('expanded_detail_panel')), findsNothing);

        // 3. Chromebook / Googlebook / Laptop viewport (>= 840dp)
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('adaptive_navigation_rail')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('expanded_detail_panel')), findsOneWidget);

        // Add a root task and sub-task to test focus mode & breadcrumbs
        final root = await controller.addTodo(title: 'Root Project');
        final sub = await controller.addTodo(
          title: 'Architecture & Local Persistence',
          parentId: root!.id,
        );
        await tester.pumpAndSettle();

        // Verify focusing a sub-task displays the breadcrumb bar & updates scope
        final focusFinder = find.byKey(Key('focus_task_button_${sub!.id}'));
        await tester.ensureVisible(focusFinder);
        await tester.pumpAndSettle();
        await tester.tap(focusFinder);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('focus_breadcrumb_bar')), findsOneWidget);
        expect(find.text('Architecture & Local Persistence'), findsWidgets);

        // Exit focus mode via breadcrumb bar
        await tester.tap(find.byKey(const Key('exit_focus_mode_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('focus_breadcrumb_bar')), findsNothing);
      },
    );

    testWidgets(
      'Quick-adds a task and drills into sub-tasks via the Inspector',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(tester.view.reset);

        final repository = FakeTodoRepository();
        final controller = TodoController(repository);
        await controller.loadTodos();

        await tester.pumpWidget(FractalTodoApp(controller: controller));
        await tester.pumpAndSettle();

        // Initially shows empty placeholder
        expect(
          find.byKey(const Key('empty_tasks_placeholder')),
          findsOneWidget,
        );

        // Quick-add a root task
        await tester.enterText(
          find.byKey(const Key('quick_add_task_field')),
          'Master Project',
        );
        await tester.tap(find.byKey(const Key('quick_add_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Master Project'), findsWidgets);

        // Add a sub-task inside the inspector panel
        await tester.enterText(
          find.byKey(const Key('inspector_quick_subtask_field')),
          'Nested Step 1',
        );
        await tester.tap(
          find.byKey(const Key('inspector_quick_subtask_submit')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nested Step 1'), findsWidgets);
      },
    );
  });
}
