import 'todo_item.dart';

/// Repository interface for persisting and querying hierarchical todo items.
abstract interface class TodoRepository {
  /// Returns all persisted todo items.
  Future<List<TodoItem>> getAllTodos();

  /// Persists or updates a single [item].
  Future<void> saveTodo(TodoItem item);

  /// Persists or updates multiple [items] atomically.
  Future<void> saveAllTodos(Iterable<TodoItem> items);

  /// Deletes all todo items whose IDs are in [ids].
  Future<void> deleteTodosByIds(Iterable<String> ids);

  /// Clears all todo items from storage.
  Future<void> clearAll();
}
