/// Base failure type for expected domain and storage errors.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($message)';
}

/// Failure originating from local storage (Hive CE).
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [super.cause]);
}

/// Failure originating from invalid user input or domain constraints.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, [super.cause]);
}
