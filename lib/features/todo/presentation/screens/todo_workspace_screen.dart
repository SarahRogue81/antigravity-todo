import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../domain/todo_item.dart';
import '../controllers/todo_controller.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/task_detail_panel.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/todo_tree_node.dart';

/// Main adaptive workspace screen that scales across:
/// - Phone (`< 600dp`): Single-column with bottom `NavigationBar` + modal task sheet.
/// - Tablet (`600dp – 839dp`): `NavigationRail` + wide task tree + modal task sheet.
/// - Chromebook / Googlebook / Laptop (`>= 840dp`): `NavigationRail` + master-detail split view.
class TodoWorkspaceScreen extends StatefulWidget {
  const TodoWorkspaceScreen({super.key, required this.controller});

  final TodoController controller;

  @override
  State<TodoWorkspaceScreen> createState() => _TodoWorkspaceScreenState();
}

class _TodoWorkspaceScreenState extends State<TodoWorkspaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickAddController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) return;
    _quickAddController.clear();
    await widget.controller.addTodo(
      title: text,
      parentId: widget.controller.focusedTaskId.value,
    );
  }

  Future<void> _openCreateDialog() async {
    final focusedTask = widget.controller.focusedTask.value;
    final result = await TodoFormDialog.show(
      context,
      parentTaskTitle: focusedTask?.title,
    );
    if (!mounted || result == null) return;
    await widget.controller.addTodo(
      title: result.title,
      notes: result.notes,
      priority: result.priority,
      parentId: focusedTask?.id,
    );
  }

  void _handleInspectTask(TodoItem item, WindowSizeClass sizeClass) {
    widget.controller.selectTask(item.id);
    if (!sizeClass.isExpanded) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: 0.86,
            child: TaskDetailPanel(
              controller: widget.controller,
              isModal: true,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SignalBuilder(
      builder: (context) {
        final activeFilter = widget.controller.activeFilter.value;
        final filterIndex = TodoFilter.values.indexOf(activeFilter);
        final error = widget.controller.errorMessage.value;

        return Scaffold(
          key: Key('workspace_scaffold_${sizeClass.name}'),
          bottomNavigationBar: sizeClass.isCompact
              ? NavigationBar(
                  key: const Key('compact_navigation_bar'),
                  selectedIndex: filterIndex,
                  onDestinationSelected: (idx) =>
                      widget.controller.setFilter(TodoFilter.values[idx]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.account_tree_outlined),
                      selectedIcon: Icon(Icons.account_tree_rounded),
                      label: 'All Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.radio_button_unchecked_rounded),
                      selectedIcon: Icon(Icons.pending_actions_rounded),
                      label: 'Active',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline_rounded),
                      selectedIcon: Icon(Icons.check_circle_rounded),
                      label: 'Completed',
                    ),
                  ],
                )
              : null,
          floatingActionButton: sizeClass.isCompact
              ? FloatingActionButton.extended(
                  key: const Key('new_task_fab'),
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    widget.controller.focusedTask.value == null
                        ? 'New Task'
                        : 'New Sub-Task',
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!sizeClass.isCompact)
                  NavigationRail(
                    key: const Key('adaptive_navigation_rail'),
                    extended: sizeClass.isExpanded,
                    selectedIndex: filterIndex,
                    onDestinationSelected: (idx) =>
                        widget.controller.setFilter(TodoFilter.values[idx]),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.hub_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 20,
                                ),
                              ),
                              if (sizeClass.isExpanded) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'Fractal Todo',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (sizeClass.isExpanded)
                            FilledButton.icon(
                              key: const Key('rail_new_task_button'),
                              onPressed: _openCreateDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(
                                widget.controller.focusedTask.value == null
                                    ? 'New Task'
                                    : 'New Sub-Task',
                              ),
                            )
                          else
                            IconButton.filled(
                              key: const Key('rail_new_task_icon_button'),
                              tooltip: 'New Task',
                              onPressed: _openCreateDialog,
                              icon: const Icon(Icons.add_rounded),
                            ),
                        ],
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.account_tree_outlined),
                        selectedIcon: Icon(Icons.account_tree_rounded),
                        label: Text('All Tasks'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.radio_button_unchecked_rounded),
                        selectedIcon: Icon(Icons.pending_actions_rounded),
                        label: Text('Active'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.check_circle_outline_rounded),
                        selectedIcon: Icon(Icons.check_circle_rounded),
                        label: Text('Completed'),
                      ),
                    ],
                  ),
                if (!sizeClass.isCompact) const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppConstants.expandedContentMaxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sizeClass.isCompact ? 14 : 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WorkspaceHeader(
                              controller: widget.controller,
                              searchController: _searchController,
                              isCompact: sizeClass.isCompact,
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              MaterialBanner(
                                backgroundColor: colorScheme.error.withValues(
                                  alpha: 0.15,
                                ),
                                content: Text(error),
                                actions: [
                                  TextButton(
                                    onPressed: widget.controller.clearError,
                                    child: const Text('Dismiss'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            BreadcrumbBar(controller: widget.controller),
                            const SizedBox(height: 12),

                            // Quick inline entry bar
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('quick_add_task_field'),
                                    controller: _quickAddController,
                                    onSubmitted: (_) => _handleQuickAdd(),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.add_task_rounded,
                                        size: 20,
                                      ),
                                      hintText:
                                          widget.controller.focusedTask.value ==
                                              null
                                          ? 'Quick-add a root task (press Enter)...'
                                          : 'Quick-add a sub-task inside "${widget.controller.focusedTask.value!.title}"...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.tonalIcon(
                                  key: const Key('quick_add_submit_button'),
                                  onPressed: _handleQuickAdd,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Main body: either single column (Phone/Tablet) or Master-Detail split (Laptop/Chromebook)
                            Expanded(
                              child: sizeClass.isExpanded
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: _TaskTreeListView(
                                            controller: widget.controller,
                                            onInspectTask: (item) =>
                                                _handleInspectTask(
                                                  item,
                                                  sizeClass,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          flex: 5,
                                          child: TaskDetailPanel(
                                            key: const Key(
                                              'expanded_detail_panel',
                                            ),
                                            controller: widget.controller,
                                          ),
                                        ),
                                      ],
                                    )
                                  : _TaskTreeListView(
                                      controller: widget.controller,
                                      onInspectTask: (item) =>
                                          _handleInspectTask(item, sizeClass),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.controller,
    required this.searchController,
    required this.isCompact,
  });

  final TodoController controller;
  final TextEditingController searchController;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SignalBuilder(
      builder: (context) {
        final stats = controller.stats.value;
        final focused = controller.focusedTask.value;
        final focusedDepth = focused != null
            ? controller.depthOf(focused.id)
            : 0;
        final accent = AppTheme.accentForDepth(focusedDepth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focused?.title ?? 'Fractal Tasks',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        focused == null
                            ? '${stats.completed} of ${stats.total} total nodes completed'
                            : 'Focused sub-tree • Level $focusedDepth',
                        style: textTheme.bodySmall?.copyWith(
                          color: focused == null
                              ? colorScheme.onSurfaceVariant
                              : accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Expand all sub-tasks',
                  onPressed: controller.expandAll,
                  icon: const Icon(Icons.unfold_more_rounded),
                ),
                IconButton(
                  tooltip: 'Collapse all sub-tasks',
                  onPressed: controller.collapseAll,
                  icon: const Icon(Icons.unfold_less_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('search_tasks_field'),
              controller: searchController,
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Search tasks, sub-tasks, or notes...',
                isDense: true,
                suffixIcon: controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          searchController.clear();
                          controller.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskTreeListView extends StatelessWidget {
  const _TaskTreeListView({
    required this.controller,
    required this.onInspectTask,
  });

  final TodoController controller;
  final ValueChanged<TodoItem> onInspectTask;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SignalBuilder(
      builder: (context) {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final visibleTasks = controller.visibleScopeTasks.value;
        if (visibleTasks.isEmpty) {
          final focused = controller.focusedTask.value;
          return Center(
            child: Container(
              key: const Key('empty_tasks_placeholder'),
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_mosaic_rounded,
                    size: 46,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    focused == null
                        ? 'No matching tasks'
                        : 'No sub-tasks inside "${focused.title}" yet',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    focused == null
                        ? 'Add a task above, then break it down into sub-tasks and sub-sub-tasks.'
                        : 'Use the quick-add bar above to break "${focused.title}" into actionable sub-tasks.',
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

        return ListView.builder(
          key: const Key('todo_tree_list_view'),
          padding: const EdgeInsets.only(bottom: 84),
          itemCount: visibleTasks.length,
          itemBuilder: (context, index) {
            final item = visibleTasks[index];
            return TodoTreeNode(
              key: ValueKey('root_tree_node_${item.id}'),
              taskId: item.id,
              controller: controller,
              onInspectTask: onInspectTask,
            );
          },
        );
      },
    );
  }
}
