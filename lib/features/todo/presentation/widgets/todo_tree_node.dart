import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/todo_item.dart';
import '../controllers/todo_controller.dart';
import 'todo_form_dialog.dart';

/// Recursive widget that renders a task card along with its expandable nested
/// sub-tasks and sub-sub-tasks.
class TodoTreeNode extends StatelessWidget {
  const TodoTreeNode({
    super.key,
    required this.taskId,
    required this.controller,
    required this.onInspectTask,
    this.visualDepth = 0,
  });

  final String taskId;
  final TodoController controller;
  final ValueChanged<TodoItem> onInspectTask;
  final int visualDepth;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final item = controller.itemsById.value[taskId];
        if (item == null) return const SizedBox.shrink();

        final trueDepth = controller.depthOf(taskId);
        final accent = AppTheme.accentForDepth(trueDepth);
        final children = controller.childrenOf(taskId);
        final progress = controller.progressFor(taskId);
        final expanded = controller.isExpanded(taskId);
        final isSelected = controller.selectedTaskId.value == taskId;

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.75)
                      : colorScheme.outline.withValues(alpha: 0.65),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Luminous depth indicator stripe
                      Container(width: 4, color: accent),
                      Expanded(
                        child: InkWell(
                          key: Key('todo_card_${item.id}'),
                          onTap: () => onInspectTask(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Expand / collapse chevron (if has sub-tasks)
                                if (children.isNotEmpty)
                                  IconButton(
                                    key: Key('toggle_expand_${item.id}'),
                                    tooltip: expanded
                                        ? 'Collapse sub-tasks'
                                        : 'Expand sub-tasks',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        controller.toggleExpanded(item.id),
                                    icon: AnimatedRotation(
                                      turns: expanded ? 0.25 : 0,
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: accent,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 12),

                                // Completion checkbox
                                Checkbox(
                                  key: Key('todo_checkbox_${item.id}'),
                                  value: item.isCompleted,
                                  activeColor: accent,
                                  onChanged: (_) =>
                                      controller.toggleTodoCompletion(item.id),
                                ),
                                const SizedBox(width: 6),

                                // Title, notes preview, and subtree progress badge
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    decoration: item.isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: item.isCompleted
                                                        ? colorScheme
                                                              .onSurfaceVariant
                                                        : colorScheme.onSurface,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _PriorityPill(
                                            priority: item.priority,
                                          ),
                                        ],
                                      ),
                                      if (item.notes.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.notes,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      if (progress.hasSubtasks) ...[
                                        const SizedBox(height: 8),
                                        _SubtreeProgressBar(
                                          progress: progress,
                                          accent: accent,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 4),

                                // Quick action buttons: Add Sub-Task, Focus/Hoist, More
                                IconButton(
                                  key: Key('add_subtask_button_${item.id}'),
                                  tooltip: 'Add Sub-Task',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () =>
                                      _promptAddSubtask(context, item),
                                  icon: const Icon(
                                    Icons.subdirectory_arrow_right_rounded,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  key: Key('focus_task_button_${item.id}'),
                                  tooltip: 'Focus on this task tree',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () =>
                                      controller.focusTask(item.id),
                                  icon: Icon(
                                    Icons.center_focus_strong_rounded,
                                    size: 18,
                                    color:
                                        controller.focusedTaskId.value ==
                                            item.id
                                        ? accent
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  key: Key('more_actions_${item.id}'),
                                  tooltip: 'Task options',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onSelected: (action) async {
                                    switch (action) {
                                      case 'edit':
                                        await _promptEditTask(context, item);
                                      case 'focus':
                                        controller.focusTask(item.id);
                                      case 'delete':
                                        await controller.deleteTodo(item.id);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.edit_outlined),
                                        title: Text('Edit Task'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'focus',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.center_focus_strong_rounded,
                                        ),
                                        title: Text('Focus Sub-Tree'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFFB7185),
                                        ),
                                        title: Text(
                                          'Delete Task & Sub-Tasks',
                                          style: TextStyle(
                                            color: Color(0xFFFB7185),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Render nested sub-tasks if expanded
            if (expanded && children.isNotEmpty)
              // If visual depth gets very deep on a narrow screen, offer a one-tap Focus prompt
              if (visualDepth >= 4)
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 4, bottom: 6),
                  child: OutlinedButton.icon(
                    onPressed: () => controller.focusTask(item.id),
                    icon: Icon(
                      Icons.zoom_in_map_rounded,
                      size: 16,
                      color: accent,
                    ),
                    label: Text(
                      'Focus "${item.title}" (${children.length} nested sub-tasks)',
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(left: 18),
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in children)
                        TodoTreeNode(
                          key: ValueKey('tree_node_${child.id}'),
                          taskId: child.id,
                          controller: controller,
                          onInspectTask: onInspectTask,
                          visualDepth: visualDepth + 1,
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _promptAddSubtask(BuildContext context, TodoItem parent) async {
    final result = await TodoFormDialog.show(
      context,
      parentTaskTitle: parent.title,
    );
    if (!context.mounted || result == null) return;
    await controller.addTodo(
      title: result.title,
      notes: result.notes,
      priority: result.priority,
      parentId: parent.id,
    );
  }

  Future<void> _promptEditTask(BuildContext context, TodoItem item) async {
    final result = await TodoFormDialog.show(
      context,
      initialTitle: item.title,
      initialNotes: item.notes,
      initialPriority: item.priority,
      isEditing: true,
    );
    if (!context.mounted || result == null) return;
    await controller.updateTodo(
      id: item.id,
      title: result.title,
      notes: result.notes,
      priority: result.priority,
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      TodoPriority.high => (const Color(0xFFFB7185), 'High'),
      TodoPriority.medium => (const Color(0xFF38BDF8), 'Med'),
      TodoPriority.low => (const Color(0xFF94A3B8), 'Low'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SubtreeProgressBar extends StatelessWidget {
  const _SubtreeProgressBar({required this.progress, required this.accent});

  final SubtreeProgress progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(Icons.account_tree_outlined, size: 13, color: accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${progress.completedDescendants}/${progress.totalDescendants}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 5,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${progress.percentage}%',
          style: textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
