import 'package:hive_ce/hive_ce.dart';

import '../../features/todo/domain/todo_item.dart';

@GenerateAdapters([AdapterSpec<TodoItem>(), AdapterSpec<TodoPriority>()])
part 'hive_adapters.g.dart';
