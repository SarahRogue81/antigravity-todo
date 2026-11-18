import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../features/todo/domain/todo_item.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';
import 'hive_registrar.g.dart';

/// Centralizes Hive CE initialization, adapter registration, and box opening.
abstract final class HiveStorageService {
  static bool _adaptersRegistered = false;

  /// Registers generated Hive CE adapters idempotently.
  static void registerAdaptersIfNeeded() {
    if (_adaptersRegistered) return;
    Hive.registerAdapters();
    _adaptersRegistered = true;
  }

  /// Initializes Hive for Flutter and opens the primary `TodoItem` box.
  static Future<Box<TodoItem>> initializeAndOpenTodoBox() async {
    try {
      await Hive.initFlutter();
      registerAdaptersIfNeeded();
      return await Hive.openBox<TodoItem>(AppConstants.todoBoxName);
    } catch (e) {
      throw StorageFailure('Failed to initialize Hive storage.', e);
    }
  }
}
