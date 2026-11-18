import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/storage/hive_storage_service.dart';
import 'features/todo/data/hive_todo_repository.dart';
import 'features/todo/presentation/controllers/todo_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final box = await HiveStorageService.initializeAndOpenTodoBox();
  final repository = HiveTodoRepository(box);
  final controller = TodoController(repository);
  await controller.loadTodos();

  runApp(FractalTodoApp(controller: controller));
}
