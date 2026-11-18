import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/todo_controller.dart';
import 'todo_form_dialog.dart';

/// Dedicated task & sub-task inspector panel.
/// Used side-by-side on Laptop/Chromebook (`>=840dp`) and as a dedicated modal
/// sheet/page on Phone/Tablet when drilling into a task.
class TaskDetailPanel extends StatefulWidget {
  const TaskDetailPanel({
    super.key,
    required this.controller,
    this.isModal = false,
  });

  final TodoController controller;
  final bool isModal;

  @override
  State<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<TaskDetailPanel> {
  final TextEditingController _quickSubtaskController = TextEditingController();

  @override
  void dispose() {
    _quickSubtaskController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickSubtask(String parentId) async {
    final text = _quickSubtaskController.text.trim();
    if (text.isEmpty) return;
    _quickSubtaskController.clear();
    await widget.controller.addTodo(title: text, parentId: parentId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SignalBuilder(
      builder: (context) {
        final task = widget.controller.activeInspectorTask.value;
        if (task == null) {
          return Container(
            key: const Key('empty_inspector_panel'),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ads_click_rounded,
                    size: 48,
                    color: colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Select any task or sub-task',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inspect its hierarchy, edit notes, or drill down into sub-sub-tasks.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final depth = widget.controller.depthOf(task.id);
        final accent = AppTheme.accentForDepth(depth);
        final breadcrumbs = widget.controller.inspectorBreadcrumbs.value;
        final subTasks = widget.controller.childrenOf(task.id);
        final progress = widget.controller.progressFor(task.id);

        return Container(
          key: Key('inspector_panel_${task.id}'),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isModal ? Colors.transparent : colorScheme.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: Ancestor path + Close/Focus controls
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          depth == 0 ? 'Root Task' : 'Level $depth Sub-Task',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (task.parentId != null)
                      IconButton(
                        key: const Key('inspector_up_to_parent_button'),
                        tooltip: 'Go to parent task',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          widget.controller.selectTask(task.parentId);
                        },
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      ),
                    IconButton(
                      key: const Key('inspector_edit_task_button'),
                      tooltip: 'Edit Task',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final result = await TodoFormDialog.show(
                          context,
                          initialTitle: task.title,
                          initialNotes: task.notes,
                          initialPriority: task.priority,
                          isEditing: true,
                        );
                        if (!context.mounted || result == null) return;
                        await widget.controller.updateTodo(
                          id: task.id,
                          title: result.title,
                          notes: result.notes,
                          priority: result.priority,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 19),
                    ),
                    IconButton(
                      key: const Key('inspector_delete_task_button'),
                      tooltip: 'Delete Task',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await widget.controller.deleteTodo(task.id);
                        if (widget.isModal && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: colorScheme.error,
                      ),
                    ),
                    if (widget.isModal)
                      IconButton(
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                  ],
                ),

                // Breadcrumb path if nested
                if (breadcrumbs.length > 1) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < breadcrumbs.length - 1; i++) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () =>
                                widget.controller.selectTask(breadcrumbs[i].id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                breadcrumbs[i].title,
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Main title + completion toggle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      activeColor: accent,
                      onChanged: (_) =>
                          widget.controller.toggleTodoCompletion(task.id),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          task.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      task.notes,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Focus button to make this task the main workspace root
                OutlinedButton.icon(
                  key: const Key('inspector_focus_subtree_button'),
                  onPressed: () {
                    final alreadyFocused =
                        widget.controller.focusedTaskId.value == task.id;
                    widget.controller.focusTask(
                      alreadyFocused ? null : task.id,
                    );
                    if (widget.isModal && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: Icon(
                    widget.controller.focusedTaskId.value == task.id
                        ? Icons.zoom_out_map_rounded
                        : Icons.center_focus_strong_rounded,
                    size: 18,
                    color: accent,
                  ),
                  label: Text(
                    widget.controller.focusedTaskId.value == task.id
                        ? 'Exit Focus View'
                        : 'Open "${task.title}" in Full Focus View',
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Sub-tasks header + progress
                Row(
                  children: [
                    Icon(Icons.account_tree_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Sub-Tasks (${subTasks.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (progress.hasSubtasks)
                      Flexible(
                        child: Text(
                          '${progress.completedDescendants}/${progress.totalDescendants} (${progress.percentage}%)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick inline add sub-task input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('inspector_quick_subtask_field'),
                        controller: _quickSubtaskController,
                        onSubmitted: (_) => _submitQuickSubtask(task.id),
                        decoration: const InputDecoration(
                          hintText: 'Add a sub-task and press Enter...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('inspector_quick_subtask_submit'),
                      tooltip: 'Add Sub-Task',
                      onPressed: () => _submitQuickSubtask(task.id),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sub-task list (each item can be clicked to drill deeper into sub-sub-tasks!)
                Expanded(
                  child: subTasks.isEmpty
                      ? Center(
                          child: Text(
                            'No sub-tasks yet. Break this task down into smaller steps above!',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: subTasks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final sub = subTasks[index];
                            final subProgress = widget.controller.progressFor(
                              sub.id,
                            );
                            return Material(
                              color: colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                key: Key('inspector_subtask_tile_${sub.id}'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  // Drilling into the sub-task switches the inspector to it!
                                  widget.controller.selectTask(sub.id);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: sub.isCompleted,
                                        activeColor: AppTheme.accentForDepth(
                                          depth + 1,
                                        ),
                                        onChanged: (_) => widget.controller
                                            .toggleTodoCompletion(sub.id),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sub.title,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    decoration: sub.isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                            ),
                                            if (subProgress.hasSubtasks)
                                              Text(
                                                '${subProgress.completedDescendants}/${subProgress.totalDescendants} nested sub-tasks',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Tooltip(
                                        message:
                                            'Drill into "${sub.title}" sub-tasks',
                                        child: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
