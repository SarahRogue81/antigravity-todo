/// Priority level for a task or subtask.
enum TodoPriority {
  low,
  medium,
  high;

  String get label => switch (this) {
    TodoPriority.low => 'Low',
    TodoPriority.medium => 'Medium',
    TodoPriority.high => 'High',
  };
}

/// Filter applied to the visible task list.
enum TodoFilter {
  all,
  active,
  completed;

  String get label => switch (this) {
    TodoFilter.all => 'All Tasks',
    TodoFilter.active => 'Active',
    TodoFilter.completed => 'Completed',
  };
}

/// Immutable domain model representing a task or nested sub-task of arbitrary depth.
class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.isCompleted = false,
    this.parentId,
    required this.createdAt,
    this.priority = TodoPriority.medium,
    this.order = 0,
  });

  /// Unique identifier for the task.
  final String id;

  /// Short summary title of the task.
  final String title;

  /// Optional markdown/plain-text notes or details.
  final String notes;

  /// Whether this specific task node is marked complete.
  final bool isCompleted;

  /// Optional parent task ID. `null` indicates a top-level root task.
  final String? parentId;

  /// Timestamp when the task was created.
  final DateTime createdAt;

  /// Task priority level.
  final TodoPriority priority;

  /// Sort order within its sibling group.
  final int order;

  TodoItem copyWith({
    String? id,
    String? title,
    String? notes,
    bool? isCompleted,
    String? Function()? parentId,
    DateTime? createdAt,
    TodoPriority? priority,
    int? order,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      parentId: parentId != null ? parentId() : this.parentId,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoItem &&
        other.id == id &&
        other.title == title &&
        other.notes == notes &&
        other.isCompleted == isCompleted &&
        other.parentId == parentId &&
        other.createdAt == createdAt &&
        other.priority == priority &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    isCompleted,
    parentId,
    createdAt,
    priority,
    order,
  );
}

/// Recursive progress summary for a task's entire descendant subtree.
class SubtreeProgress {
  const SubtreeProgress({
    required this.totalDescendants,
    required this.completedDescendants,
    required this.directChildrenCount,
    required this.completedDirectChildren,
  });

  static const empty = SubtreeProgress(
    totalDescendants: 0,
    completedDescendants: 0,
    directChildrenCount: 0,
    completedDirectChildren: 0,
  );

  final int totalDescendants;
  final int completedDescendants;
  final int directChildrenCount;
  final int completedDirectChildren;

  bool get hasSubtasks => totalDescendants > 0;

  double get ratio =>
      totalDescendants == 0 ? 0.0 : completedDescendants / totalDescendants;

  int get percentage => (ratio * 100).round();
}
