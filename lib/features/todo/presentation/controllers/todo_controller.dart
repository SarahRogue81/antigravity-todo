import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/todo_item.dart';
import '../../domain/todo_repository.dart';

/// Reactive controller managing hierarchical todos, sub-tasks, focus navigation,
/// inline expansion, filtering, and search using `signals_flutter`.
class TodoController {
  TodoController(this._repository);

  final TodoRepository _repository;

  // Private writable signals encapsulated inside the controller
  final Signal<Map<String, TodoItem>> _itemsById = signal(
    const <String, TodoItem>{},
  );
  final Signal<Set<String>> _expandedIds = signal(const <String>{});
  final Signal<String?> _focusedTaskId = signal(null);
  final Signal<String?> _selectedTaskId = signal(null);
  final Signal<TodoFilter> _activeFilter = signal(TodoFilter.all);
  final Signal<String> _searchQuery = signal('');
  final Signal<bool> _isLoading = signal(false);
  final Signal<String?> _errorMessage = signal(null);

  // Public read-only signals exposed to UI widgets
  ReadonlySignal<Map<String, TodoItem>> get itemsById => _itemsById.readonly();
  ReadonlySignal<Set<String>> get expandedIds => _expandedIds.readonly();
  ReadonlySignal<String?> get focusedTaskId => _focusedTaskId.readonly();
  ReadonlySignal<String?> get selectedTaskId => _selectedTaskId.readonly();
  ReadonlySignal<TodoFilter> get activeFilter => _activeFilter.readonly();
  ReadonlySignal<String> get searchQuery => _searchQuery.readonly();
  ReadonlySignal<bool> get isLoading => _isLoading.readonly();
  ReadonlySignal<String?> get errorMessage => _errorMessage.readonly();

  /// Currently focused task (when hoisted / drilled down), or `null` if viewing Root.
  late final Computed<TodoItem?> focusedTask = computed(() {
    final id = _focusedTaskId.value;
    if (id == null) return null;
    return _itemsById.value[id];
  });

  /// Currently selected task for the detail/inspector pane (or focused task fallback).
  late final Computed<TodoItem?> activeInspectorTask = computed(() {
    final map = _itemsById.value;
    final selectedId = _selectedTaskId.value;
    if (selectedId != null && map.containsKey(selectedId)) {
      return map[selectedId];
    }
    final focusedId = _focusedTaskId.value;
    if (focusedId != null && map.containsKey(focusedId)) {
      return map[focusedId];
    }
    return null;
  });

  /// Breadcrumb trail from Root down to the currently focused task.
  late final Computed<List<TodoItem>> focusBreadcrumbs = computed(() {
    final startId = _focusedTaskId.value;
    if (startId == null) return const <TodoItem>[];
    return getAncestorChain(startId);
  });

  /// Breadcrumb trail for the currently inspected task.
  late final Computed<List<TodoItem>> inspectorBreadcrumbs = computed(() {
    final task = activeInspectorTask.value;
    if (task == null) return const <TodoItem>[];
    return getAncestorChain(task.id);
  });

  /// Top-level items for the current focus scope (either root tasks or direct
  /// children of `focusedTaskId`), filtered by `activeFilter` and `searchQuery`.
  late final Computed<List<TodoItem>> visibleScopeTasks = computed(() {
    final focusId = _focusedTaskId.value;
    final filter = _activeFilter.value;
    final query = _searchQuery.value.trim().toLowerCase();

    final rawList = childrenOf(focusId);

    return rawList
        .where((item) {
          final matchesFilter = switch (filter) {
            TodoFilter.all => true,
            TodoFilter.active => !item.isCompleted,
            TodoFilter.completed => item.isCompleted,
          };
          if (!matchesFilter) return false;

          if (query.isEmpty) return true;
          return _subtreeMatchesQuery(item.id, query);
        })
        .toList(growable: false);
  });

  /// Global statistics across all tasks in the workspace.
  late final Computed<({int total, int completed, int active, int rootCount})>
  stats = computed(() {
    final values = _itemsById.value.values;
    var total = 0;
    var completed = 0;
    var rootCount = 0;
    for (final item in values) {
      total++;
      if (item.isCompleted) completed++;
      if (item.parentId == null) rootCount++;
    }
    return (
      total: total,
      completed: completed,
      active: total - completed,
      rootCount: rootCount,
    );
  });

  /// Loads all tasks from local storage without seeding any starter tasks.
  /// Also removes any legacy pre-populated `seed_*` tasks from storage.
  Future<void> loadTodos() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final loaded = await _repository.getAllTodos();
      final byId = <String, TodoItem>{for (final item in loaded) item.id: item};

      bool isSeedOrDescendant(TodoItem item) {
        var current = item;
        final visited = <String>{};
        while (true) {
          if (current.id.startsWith('seed_')) return true;
          final parentId = current.parentId;
          if (parentId == null || !visited.add(current.id)) return false;
          if (parentId.startsWith('seed_')) return true;
          final parent = byId[parentId];
          if (parent == null) return false;
          current = parent;
        }
      }

      final seedIds = <String>[];
      final map = <String, TodoItem>{};
      for (final item in loaded) {
        if (isSeedOrDescendant(item)) {
          seedIds.add(item.id);
        } else {
          map[item.id] = item;
        }
      }

      if (seedIds.isNotEmpty) {
        await _repository.deleteTodosByIds(seedIds);
      }

      final defaultExpanded = <String>{
        for (final item in map.values)
          if (item.parentId == null) item.id,
      };
      batch(() {
        _itemsById.value = Map.unmodifiable(map);
        _expandedIds.value = Set.unmodifiable(defaultExpanded);
        _focusedTaskId.value = null;
        _selectedTaskId.value = null;
      });
    } on AppFailure catch (e) {
      _errorMessage.value = e.message;
    } catch (e) {
      _errorMessage.value = 'Unexpected error loading tasks.';
    } finally {
      _isLoading.value = false;
    }
  }

  /// Returns direct children of [parentId] sorted by `isCompleted`, `order`, and `createdAt`.
  List<TodoItem> childrenOf(String? parentId) {
    final map = _itemsById.value;
    final list = map.values
        .where((item) => item.parentId == parentId)
        .toList(growable: false);
    list.sort((a, b) {
      if (a.order != b.order) return a.order.compareTo(b.order);
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// Returns the nesting depth of [taskId] (0 for root tasks, 1 for sub-tasks, 2 for sub-sub-tasks, etc.).
  int depthOf(String taskId) {
    final map = _itemsById.value;
    var depth = 0;
    var current = map[taskId];
    final visited = <String>{};
    while (current != null && current.parentId != null) {
      if (!visited.add(current.id)) break; // guard against cycles
      depth++;
      current = map[current.parentId!];
    }
    return depth;
  }

  /// Returns the ancestor chain from the root task down to [taskId] (inclusive).
  List<TodoItem> getAncestorChain(String taskId) {
    final map = _itemsById.value;
    final chain = <TodoItem>[];
    var current = map[taskId];
    final visited = <String>{};
    while (current != null) {
      if (!visited.add(current.id)) break;
      chain.add(current);
      final pId = current.parentId;
      current = pId != null ? map[pId] : null;
    }
    return chain.reversed.toList(growable: false);
  }

  /// Computes recursive completion metrics for all descendants of [taskId].
  SubtreeProgress progressFor(String taskId) {
    final direct = childrenOf(taskId);
    if (direct.isEmpty) return SubtreeProgress.empty;

    var totalDescendants = 0;
    var completedDescendants = 0;
    var completedDirect = 0;

    void walk(String parentId) {
      final kids = childrenOf(parentId);
      for (final kid in kids) {
        totalDescendants++;
        if (kid.isCompleted) completedDescendants++;
        walk(kid.id);
      }
    }

    for (final kid in direct) {
      if (kid.isCompleted) completedDirect++;
    }
    walk(taskId);

    return SubtreeProgress(
      totalDescendants: totalDescendants,
      completedDescendants: completedDescendants,
      directChildrenCount: direct.length,
      completedDirectChildren: completedDirect,
    );
  }

  bool isExpanded(String taskId) => _expandedIds.value.contains(taskId);

  void toggleExpanded(String taskId) {
    final next = Set<String>.from(_expandedIds.value);
    if (!next.remove(taskId)) {
      next.add(taskId);
    }
    _expandedIds.value = Set.unmodifiable(next);
  }

  void expandAll() {
    _expandedIds.value = Set.unmodifiable(_itemsById.value.keys.toSet());
  }

  void collapseAll() {
    _expandedIds.value = const <String>{};
  }

  /// Hoists / focuses a specific task (or `null` to return to the root workspace).
  void focusTask(String? taskId) {
    batch(() {
      _focusedTaskId.value = taskId;
      if (taskId != null) {
        _selectedTaskId.value = taskId;
        final nextExpanded = Set<String>.from(_expandedIds.value)..add(taskId);
        _expandedIds.value = Set.unmodifiable(nextExpanded);
      }
    });
  }

  /// Selects a task for inspection in the detail panel or sheet.
  void selectTask(String? taskId) {
    _selectedTaskId.value = taskId;
  }

  void setFilter(TodoFilter filter) {
    _activeFilter.value = filter;
  }

  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  void clearError() {
    _errorMessage.value = null;
  }

  /// Creates a new root task, sub-task, or sub-sub-task under [parentId].
  Future<TodoItem?> addTodo({
    required String title,
    String notes = '',
    String? parentId,
    TodoPriority priority = TodoPriority.medium,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      _errorMessage.value = 'Task title cannot be empty.';
      return null;
    }

    final siblings = childrenOf(parentId);
    final nextOrder = siblings.isEmpty
        ? 0
        : siblings.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    final id = 'todo_${now.microsecondsSinceEpoch}_${_itemsById.value.length}';
    final newItem = TodoItem(
      id: id,
      title: trimmedTitle,
      notes: notes.trim(),
      parentId: parentId,
      createdAt: now,
      priority: priority,
      order: nextOrder,
    );

    try {
      await _repository.saveTodo(newItem);
      final nextMap = Map<String, TodoItem>.from(_itemsById.value)
        ..[newItem.id] = newItem;
      final nextExpanded = Set<String>.from(_expandedIds.value)
        ..add(newItem.id);
      if (parentId != null) {
        nextExpanded.add(parentId);
      }
      batch(() {
        _itemsById.value = Map.unmodifiable(nextMap);
        _expandedIds.value = Set.unmodifiable(nextExpanded);
        _selectedTaskId.value = newItem.id;
        _errorMessage.value = null;
      });
      return newItem;
    } on AppFailure catch (e) {
      _errorMessage.value = e.message;
      return null;
    } catch (_) {
      _errorMessage.value = 'Failed to create task.';
      return null;
    }
  }

  /// Updates an existing task's title, notes, or priority.
  Future<void> updateTodo({
    required String id,
    String? title,
    String? notes,
    TodoPriority? priority,
  }) async {
    final existing = _itemsById.value[id];
    if (existing == null) return;

    final nextTitle = title != null ? title.trim() : existing.title;
    if (nextTitle.isEmpty) {
      _errorMessage.value = 'Task title cannot be empty.';
      return;
    }

    final updated = existing.copyWith(
      title: nextTitle,
      notes: notes != null ? notes.trim() : existing.notes,
      priority: priority ?? existing.priority,
    );

    try {
      await _repository.saveTodo(updated);
      final nextMap = Map<String, TodoItem>.from(_itemsById.value)
        ..[id] = updated;
      batch(() {
        _itemsById.value = Map.unmodifiable(nextMap);
        _errorMessage.value = null;
      });
    } on AppFailure catch (e) {
      _errorMessage.value = e.message;
    } catch (_) {
      _errorMessage.value = 'Failed to update task.';
    }
  }

  /// Toggles completion of [id] and cascades the completion state to all
  /// nested sub-tasks, while also auto-updating ancestor completion if all
  /// siblings are completed/uncompleted.
  Future<void> toggleTodoCompletion(
    String id, {
    bool cascadeToSubtasks = true,
  }) async {
    final existing = _itemsById.value[id];
    if (existing == null) return;

    final targetCompleted = !existing.isCompleted;
    final nextMap = Map<String, TodoItem>.from(_itemsById.value);
    final modified = <TodoItem>[];

    final updatedSelf = existing.copyWith(isCompleted: targetCompleted);
    nextMap[id] = updatedSelf;
    modified.add(updatedSelf);

    if (cascadeToSubtasks) {
      final descendantIds = _collectDescendantIds(id);
      for (final descId in descendantIds) {
        final desc = nextMap[descId];
        if (desc != null && desc.isCompleted != targetCompleted) {
          final updatedDesc = desc.copyWith(isCompleted: targetCompleted);
          nextMap[descId] = updatedDesc;
          modified.add(updatedDesc);
        }
      }
    }

    // Bubble up: if all children of an ancestor are now complete, mark ancestor complete;
    // if an ancestor was complete and a child was unchecked, mark ancestor incomplete.
    var parentId = existing.parentId;
    final visited = <String>{};
    while (parentId != null && visited.add(parentId)) {
      final parent = nextMap[parentId];
      if (parent == null) break;
      final siblings = nextMap.values
          .where((item) => item.parentId == parentId)
          .toList(growable: false);
      final allSiblingsDone =
          siblings.isNotEmpty && siblings.every((s) => s.isCompleted);
      if (parent.isCompleted != allSiblingsDone) {
        final updatedParent = parent.copyWith(isCompleted: allSiblingsDone);
        nextMap[parentId] = updatedParent;
        modified.add(updatedParent);
      }
      parentId = parent.parentId;
    }

    try {
      await _repository.saveAllTodos(modified);
      batch(() {
        _itemsById.value = Map.unmodifiable(nextMap);
        _errorMessage.value = null;
      });
    } on AppFailure catch (e) {
      _errorMessage.value = e.message;
    } catch (_) {
      _errorMessage.value = 'Failed to update task status.';
    }
  }

  /// Deletes [id] and all of its nested sub-tasks recursively.
  Future<void> deleteTodo(String id) async {
    if (!_itemsById.value.containsKey(id)) return;

    final toRemove = <String>{id, ..._collectDescendantIds(id)};
    final deletedItemParent = _itemsById.value[id]?.parentId;

    try {
      await _repository.deleteTodosByIds(toRemove);
      final nextMap = Map<String, TodoItem>.from(_itemsById.value)
        ..removeWhere((key, _) => toRemove.contains(key));
      final nextExpanded = Set<String>.from(_expandedIds.value)
        ..removeAll(toRemove);

      batch(() {
        _itemsById.value = Map.unmodifiable(nextMap);
        _expandedIds.value = Set.unmodifiable(nextExpanded);
        if (_focusedTaskId.value != null &&
            toRemove.contains(_focusedTaskId.value)) {
          _focusedTaskId.value = deletedItemParent;
        }
        if (_selectedTaskId.value != null &&
            toRemove.contains(_selectedTaskId.value)) {
          _selectedTaskId.value = _focusedTaskId.value;
        }
        _errorMessage.value = null;
      });
    } on AppFailure catch (e) {
      _errorMessage.value = e.message;
    } catch (_) {
      _errorMessage.value = 'Failed to delete task.';
    }
  }

  Set<String> _collectDescendantIds(String rootId) {
    final result = <String>{};
    void walk(String parentId) {
      for (final item in _itemsById.value.values) {
        if (item.parentId == parentId && result.add(item.id)) {
          walk(item.id);
        }
      }
    }

    walk(rootId);
    return result;
  }

  bool _subtreeMatchesQuery(String taskId, String query) {
    final item = _itemsById.value[taskId];
    if (item == null) return false;
    if (item.title.toLowerCase().contains(query) ||
        item.notes.toLowerCase().contains(query)) {
      return true;
    }
    for (final child in childrenOf(taskId)) {
      if (_subtreeMatchesQuery(child.id, query)) {
        return true;
      }
    }
    return false;
  }
}
