import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/todo/presentation/controllers/todo_controller.dart';
import 'features/todo/presentation/screens/todo_workspace_screen.dart';

/// Root MaterialApp configured strictly in dark mode.
class FractalTodoApp extends StatelessWidget {
  const FractalTodoApp({super.key, required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fractal Todo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.darkTheme,
      home: TodoWorkspaceScreen(controller: controller),
    );
  }
}
