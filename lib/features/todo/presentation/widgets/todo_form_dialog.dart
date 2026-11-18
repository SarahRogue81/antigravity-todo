import 'package:material_ui/material_ui.dart';

import '../../domain/todo_item.dart';

/// Prompts the user to create a new task/sub-task or edit an existing one.
class TodoFormDialog extends StatefulWidget {
  const TodoFormDialog({
    super.key,
    this.initialTitle = '',
    this.initialNotes = '',
    this.initialPriority = TodoPriority.medium,
    this.parentTaskTitle,
    this.isEditing = false,
  });

  final String initialTitle;
  final String initialNotes;
  final TodoPriority initialPriority;
  final String? parentTaskTitle;
  final bool isEditing;

  static Future<({String title, String notes, TodoPriority priority})?> show(
    BuildContext context, {
    String initialTitle = '',
    String initialNotes = '',
    TodoPriority initialPriority = TodoPriority.medium,
    String? parentTaskTitle,
    bool isEditing = false,
  }) {
    return showDialog<({String title, String notes, TodoPriority priority})>(
      context: context,
      builder: (context) => TodoFormDialog(
        initialTitle: initialTitle,
        initialNotes: initialNotes,
        initialPriority: initialPriority,
        parentTaskTitle: parentTaskTitle,
        isEditing: isEditing,
      ),
    );
  }

  @override
  State<TodoFormDialog> createState() => _TodoFormDialogState();
}

class _TodoFormDialogState extends State<TodoFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TodoPriority _priority;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
    _priority = widget.initialPriority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _titleController.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationError = 'Please enter a task title.';
      });
      return;
    }
    Navigator.of(context).pop((
      title: trimmed,
      notes: _notesController.text.trim(),
      priority: _priority,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String heading;
    if (widget.isEditing) {
      heading = 'Edit Task';
    } else if (widget.parentTaskTitle != null) {
      heading = 'Add Sub-Task';
    } else {
      heading = 'New Root Task';
    }

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            heading,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (widget.parentTaskTitle != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Inside: ${widget.parentTaskTitle}',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, minWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('todo_form_title_field'),
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs to be done?',
                  errorText: _validationError,
                ),
                onChanged: (_) {
                  if (_validationError != null) {
                    setState(() => _validationError = null);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('todo_form_notes_field'),
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add context, links, or acceptance criteria...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Priority',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TodoPriority>(
                key: const Key('todo_form_priority_selector'),
                segments: const [
                  ButtonSegment(
                    value: TodoPriority.low,
                    label: Text('Low'),
                    icon: Icon(Icons.low_priority_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: TodoPriority.medium,
                    label: Text('Medium'),
                    icon: Icon(Icons.drag_handle_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: TodoPriority.high,
                    label: Text('High'),
                    icon: Icon(Icons.priority_high_rounded, size: 18),
                  ),
                ],
                selected: {_priority},
                onSelectionChanged: (selection) {
                  setState(() {
                    _priority = selection.first;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('todo_form_submit_button'),
          onPressed: _submit,
          icon: Icon(
            widget.isEditing ? Icons.check_rounded : Icons.add_rounded,
          ),
          label: Text(widget.isEditing ? 'Save Changes' : 'Create'),
        ),
      ],
    );
  }
}
