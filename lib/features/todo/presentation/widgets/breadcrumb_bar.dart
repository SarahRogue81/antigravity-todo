import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/todo_controller.dart';

/// Displays an interactive breadcrumb bar when the user focuses ("hoists")
/// into a nested sub-task or sub-sub-task.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key, required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SignalBuilder(
      builder: (context) {
        final crumbs = controller.focusBreadcrumbs.value;
        if (crumbs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          key: const Key('focus_breadcrumb_bar'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        key: const Key('breadcrumb_root_button'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => controller.focusTask(null),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_tree_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'All Tasks',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (var i = 0; i < crumbs.length; i++) ...[
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        _BreadcrumbChip(
                          title: crumbs[i].title,
                          depth: i,
                          isCurrent: i == crumbs.length - 1,
                          onTap: i == crumbs.length - 1
                              ? null
                              : () => controller.focusTask(crumbs[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const Key('exit_focus_mode_button'),
                onPressed: () => controller.focusTask(null),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.zoom_out_map_rounded, size: 15),
                label: const Text('Exit Focus'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.title,
    required this.depth,
    required this.isCurrent,
    this.onTap,
  });

  final String title;
  final int depth;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = AppTheme.accentForDepth(depth);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: isCurrent
            ? BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              )
            : null,
        child: Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: isCurrent
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
