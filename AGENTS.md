# AGENTS.md

Guidelines and instructions for AI coding agents working in this Flutter Todo repository.

## 1. Build, Test, and Lint Commands

Run these commands from the repository root:

- **Install dependencies**:
  ```bash
  flutter pub get
  ```
- **Static analysis & linting** (must pass with zero warnings/errors before completing tasks):
  ```bash
  flutter analyze
  ```
- **Code formatting** (verify or apply standard Dart formatting):
  ```bash
  dart format .
  dart format --output=none --set-exit-if-changed .
  ```
- **Run all tests**:
  ```bash
  flutter test
  ```
- **Run a single test file**:
  ```bash
  flutter test test/path/to/file_test.dart
  ```
- **Run code generation** (for `hive_ce_generator` type adapters / `hive_registrar.g.dart`):
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Run the app**:
  ```bash
  flutter run
  ```

## 2. Architecture, State Management, and Local Storage

### Core Stack
- **State Management**: `signals` / `signals_flutter`
- **Local Storage**: `hive_ce` / `hive_ce_flutter` (with `hive_ce_generator` and `build_runner` when using generated adapters)

### Directory Structure
Follow a clean, feature-first structure under `lib/`:

```text
lib/
├── main.dart                 # Application entry point (Hive initialization & adapter registration)
├── app.dart                  # Root MaterialApp / theme / router configuration
├── hive_registrar.g.dart     # Generated Hive CE adapter registrar (if using hive_ce_generator)
├── core/                     # Shared utilities, constants, theme, error types, extensions
│   ├── constants/
│   ├── errors/
│   ├── storage/              # Hive CE box management and initialization helpers
│   ├── theme/
│   └── utils/
└── features/                 # Feature modules (e.g., todo, categories, settings)
    └── todo/
        ├── data/             # Repositories, Hive CE data sources/boxes, DTOs/adapters
        ├── domain/           # Immutable models/entities, repository interfaces
        └── presentation/     # Screens/pages, reusable widgets, and Signals controllers/stores
test/
├── core/
└── features/                 # Mirrors lib/features/ structure for unit and widget tests
```

### Architectural Principles
- **Separation of Concerns**: Keep UI widgets free of direct `Hive` box reads/writes. UI components should observe reactive `Signal` / `ReadonlySignal` / `Computed` state and dispatch user intents to Signals controllers, which interact with repositories.
- **Unidirectional Data Flow**: State flows down reactively from signals (`signal`, `computed`) to widgets (`SignalBuilder` or `.watch(context)`); events flow up through controller method calls.
- **Immutability**: Prefer immutable domain models (`final` fields, `const` constructors, and `copyWith` methods). When updating list/map signals, assign a new immutable collection or use `ListSignal`/`MapSignal` intentionally so dependents are notified.

### Signals Guidelines (`signals_flutter`)
- **Encapsulate Writable Signals**: Expose `ReadonlySignal<T>` (via `.readonly()`) or `Computed<T>` to widgets and keep the underlying writable `Signal<T>` private within controllers/stores so state mutations only happen through explicit methods.
- **Derived State with `computed`**: Use `computed(() => ...)` for filtered/sorted todos, completion counts, and UI-derived states instead of duplicating state or recalculating inside `build`.
- **Granular Rebuilds**: Use `SignalBuilder(builder: (context) => ...)` or `mySignal.watch(context)` inside small, focused widget subtrees so signal changes only rebuild the necessary widgets.
- **Side Effects & Cleanup**: Prefer `computed` over `effect` for state derivation. Reserve `effect` for side effects (logging, syncing, analytics) and always dispose of effects or local signals when their owner is disposed.
- **Batching Updates**: Use `batch(() { ... })` when mutating multiple signals together to trigger a single downstream recomputation/rebuild.

### Local Storage Guidelines (`hive_ce`)
- **Initialization**: Initialize Hive before opening boxes (e.g., `await Hive.initFlutter()` and `Hive.registerAdapters()` in startup/bootstrap code) and keep box names centralized as constants.
- **Repository Abstraction**: Encapsulate `Box<T>` / `LazyBox<T>` access inside data sources or repositories (`features/todo/data/`). Never leak `Box` instances directly into presentation controllers or widgets.
- **Type Adapters & Schema Evolution**:
  - Never change or reuse existing `@HiveField(index)` numbers once defined; deprecate old fields and add new indices to maintain backward compatibility.
  - Run `dart run build_runner build --delete-conflicting-outputs` whenever `@HiveType` or `@HiveField` annotations change.
- **Error Handling & Corruption Recovery**: Wrap box open/read/write/delete operations in `try/catch` blocks inside the data layer and translate storage exceptions into typed domain failures.

## 3. Code Style, Error Handling, and Testing Rules

### Dart & Flutter Code Style
- **Sound Null Safety**: Write strictly null-safe Dart. Avoid the bang operator (`!`) unless nullability is guaranteed by an immediately preceding check; prefer pattern matching, null-aware operators (`?.`, `??`), or early returns.
- **`const` Everywhere**: Always use `const` for constructors, widgets, and literals whenever possible to optimize widget rebuilds.
- **Widget Decomposition**: Prefer extracting small, focused `StatelessWidget` or `StatefulWidget` classes over large helper methods returning `Widget` (`Widget _buildFoo()`).
- **Naming Conventions**:
  - `UpperCamelCase` for classes, enums, typedefs, and extensions.
  - `lowerCamelCase` for variables, methods, and parameters.
  - `snake_case.dart` for file and directory names.
- **Imports**: Use relative imports within the same feature module or consistent `package:` imports across modules, keeping imports sorted cleanly.
- **Theming**: Use `Theme.of(context).colorScheme` and `Theme.of(context).textTheme` (Material 3) rather than hardcoded colors or font sizes.

### Responsive & Adaptive Design (Phone, Tablet, Chromebook/Laptop)
The app must scale cleanly across phones, tablets, and laptops (including Chromebooks / Googlebooks with resizable windows, keyboard, and trackpad/mouse):
- **Window Size Breakpoints (Material 3)**: Base layouts on current window width (`MediaQuery.sizeOf(context).width` or `LayoutBuilder`), never on platform checks (`Platform.isAndroid`, etc.), as Chromebook/tablet windows can be resized dynamically:
  - **Compact (`< 600dp`, Phones)**: Single-column layout, bottom navigation (`NavigationBar`) or modal sheets, full-width lists.
  - **Medium (`600dp – 839dp`, Tablets / Split-screen)**: `NavigationRail`, wider content margins or two-column grid/list layouts, constrained max width for dialogs/forms.
  - **Expanded (`>= 840dp`, Chromebooks / Laptops / Large Tablets)**: Persistent `NavigationRail` or navigation drawer, master-detail split views (e.g., todo list alongside task details/editor), and centered `ConstrainedBox` (e.g., `maxWidth: 1200`) to prevent overly stretched lines on wide screens.
- **Input Parity (Touch, Mouse, Trackpad, Keyboard)**:
  - Support keyboard navigation (focus traversal, `Enter` to submit, `Escape` to dismiss, shortcuts where appropriate) and hover/focus states (`InkWell`, `MouseRegion`, Material 3 interactive widgets) for laptop/Chromebook users.
  - Ensure touch targets remain at least `48x48dp` for phone and tablet ergonomics.
- **Safe Areas & Resizing**: Wrap top-level screen content in `SafeArea` and ensure scrollable views handle soft keyboard insets (`viewInsets`) and arbitrary window resizing without overflow errors.

### Error Handling
- **No Silent Failures**: Never swallow exceptions with empty `catch (_) {}` blocks.
- **Typed Failures / Result Pattern**: Handle expected storage, validation, or I/O errors gracefully in repositories and controllers, surfacing user-friendly feedback in the UI (e.g., via `SnackBar` or inline error states).
- **Async Safety in Widgets**: Always check `if (!context.mounted) return;` before using `BuildContext` across `async` gaps (`await`).

### Testing Standards
- **Unit Tests**:
  - Test domain models, `computed` derivations, and Signals controller state transitions in isolation (`test/features/...`).
  - Test `hive_ce` repositories using a temporary directory (`Directory.systemTemp.createTempSync()`) with `Hive.init(tempDir.path)` in `setUp`, and close/delete boxes + clean up the directory in `tearDown`.
- **Widget Tests**:
  - Use `testWidgets` to verify todo creation, toggling, filtering, deletion, and empty/error states using fake/mocked repositories injected into Signals controllers. Prefer finding widgets by semantics, text, or `Key` rather than brittle widget tree indices.
  - Verify responsive layouts across phone (`< 600dp`), tablet (`600dp–839dp`), and laptop/Chromebook (`>= 840dp`) viewport sizes using `tester.view.physicalSize` / `tester.view.devicePixelRatio`.
- **Verification Requirement**: Every new feature or bug fix must include corresponding unit or widget tests, and `flutter analyze` + `flutter test` must pass before finishing a task.

## 4. Git Workflow & Commit Conventions

- **Conventional Commits**: Format commit messages as `<type>(<scope>): <concise description>`:
  - `feat`: New user-facing feature (e.g., `feat(todo): add due date filtering`)
  - `fix`: Bug fix (e.g., `fix(storage): handle corrupted local todo entries`)
  - `refactor`: Code restructuring without behavior changes
  - `test`: Adding or updating unit/widget tests
  - `chore`: Dependencies, tooling, or configuration updates
  - `docs`: Documentation updates
- **Atomic Changes**: Keep commits focused on a single logical change.
- **Pre-Commit Hygiene**:
  - Do not commit generated build artifacts (`build/`, `.dart_tool/`, platform ephemeral files).
  - Ensure `dart format .`, `flutter analyze`, and `flutter test` succeed before committing.
