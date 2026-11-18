import 'package:hive_ce/hive.dart';

import '../../../core/errors/failures.dart';
import '../domain/todo_item.dart';
import '../domain/todo_repository.dart';

/// Hive CE implementation of [TodoRepository].
/// Encapsulates all direct `Box<TodoItem>` interactions and translates
/// storage errors into [StorageFailure].
class HiveTodoRepository implements TodoRepository {
  const HiveTodoRepository(this._box);

  final Box<TodoItem> _box;

  @override
  Future<List<TodoItem>> getAllTodos() async {
    try {
      final items = _box.values.toList(growable: false);
      return items;
    } catch (e) {
      throw StorageFailure('Failed to load tasks from local storage.', e);
    }
  }

  @override
  Future<void> saveTodo(TodoItem item) async {
    try {
      await _box.put(item.id, item);
    } catch (e) {
      throw StorageFailure('Failed to save task "${item.title}".', e);
    }
  }

  @override
  Future<void> saveAllTodos(Iterable<TodoItem> items) async {
    try {
      final entries = <String, TodoItem>{
        for (final item in items) item.id: item,
      };
      await _box.putAll(entries);
    } catch (e) {
      throw StorageFailure('Failed to save tasks batch.', e);
    }
  }

  @override
  Future<void> deleteTodosByIds(Iterable<String> ids) async {
    try {
      await _box.deleteAll(ids);
    } catch (e) {
      throw StorageFailure('Failed to delete tasks.', e);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _box.clear();
    } catch (e) {
      throw StorageFailure('Failed to clear tasks.', e);
    }
  }
}
