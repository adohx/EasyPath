# Flutter Development Guidelines

## Project Structure

Standard Flutter project. Entry point: `lib/main.dart`. Organize by feature for
larger features; each feature has `presentation/`, `domain/`, and `data/`
subfolders. Shared code lives in `core/`.

## Key Commands

```shell
# Run the app
flutter run

# Run tests
flutter test

# Analyze
flutter analyze

# Format
dart format .

# Apply fixes
dart fix --apply

# Code generation (after modifying annotated files)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

Follow MVVM with four layers:

- **Presentation** — widgets and screens
- **Domain** — business logic
- **Data** — models, API clients, repositories
- **Core** — shared utilities, extensions

Use manual constructor injection for dependencies. Do not introduce third-party
DI frameworks unless explicitly requested.

## State Management

Use Flutter built-ins only unless a third-party solution is explicitly requested:

- `ValueNotifier` + `ValueListenableBuilder` for simple single-value state
- `ChangeNotifier` + `ListenableBuilder` for shared or complex state
- `FutureBuilder` for a single async operation
- `StreamBuilder` for sequences of async events

## Navigation

Use `go_router` for all screens that need deep linking. Use `Navigator` only for
short-lived overlays (dialogs, bottom sheets).

## Dart Conventions

- Follow [Effective Dart](https://dart.dev/effective-dart).
- `PascalCase` for types, `camelCase` for members/variables/functions/enum
  values, `snake_case` for file names.
- Prefer `const` constructors wherever possible.
- Use `async`/`await`; avoid raw `Future.then` chains.
- Write soundly null-safe code; avoid `!` unless the non-null guarantee is
  provable.
- Prefer exhaustive `switch` expressions over `if`/`else` chains on enums.
- Use arrow syntax for single-expression functions.
- Keep functions under 20 lines with a single purpose.
- Never use `print`; use `dart:developer`'s `log` function.

## Code Quality Rules

- No abbreviations in names.
- No clever or obscure code — prefer clarity.
- No silent error swallowing; always surface or log exceptions.
- No trailing comments.
- No comments that restate what the code already says.
- Lines ≤ 80 characters.
- Break large `build()` methods into small private `Widget` classes, not helper
  methods returning `Widget`.
- Use `ListView.builder` / `SliverList` for long lists.
- Never perform network calls or heavy computation inside `build()`.

## Data Serialization

Use `json_serializable` + `json_annotation` for JSON models. Apply
`fieldRename: FieldRename.snake` to map `camelCase` Dart fields to `snake_case`
JSON keys. Regenerate with `build_runner` after model changes.

## Logging

```dart
import 'dart:developer' as developer;

developer.log('message', name: 'myapp.module');

// Errors:
developer.log('Failed', name: 'myapp.network', level: 1000,
    error: e, stackTrace: s);
```

## Testing

- Unit tests: `package:test`
- Widget tests: `package:flutter_test`
- Integration tests: `package:integration_test` (dev dependency, `sdk: flutter`)
- Assertions: prefer `package:checks` over default matchers.
- Prefer fakes/stubs over mocks. Use `mockito` or `mocktail` only when
  necessary.
- Follow Arrange–Act–Assert (Given–When–Then).
- Aim for high coverage.

## Theming

- Use `ColorScheme.fromSeed()` to generate palettes for light and dark modes.
- Define both `theme` and `darkTheme` on `MaterialApp`.
- Centralize component styles inside `ThemeData` (e.g., `appBarTheme`,
  `elevatedButtonTheme`).
- Use `ThemeExtension<T>` for custom design tokens not covered by `ThemeData`.
- Target WCAG 2.1 contrast ratios: **4.5:1** for normal text, **3:1** for large
  text.
- Apply the 60-30-10 rule for color balance.

## Layout

- Use `Expanded`/`Flexible` inside `Row`/`Column` to prevent overflow.
- Use `Wrap` when items may overflow a single row.
- Use `LayoutBuilder` or `MediaQuery` for responsive layouts.
- Use `OverlayPortal` for custom dropdowns or tooltips rendered above all other
  content.

## Assets

Declare all assets in `pubspec.yaml`. Use `Image.asset` for bundled images.
Always provide `loadingBuilder` and `errorBuilder` for `Image.network`.

## Documentation

- Write `///` doc comments for all public APIs.
- First line: single-sentence summary ending with a period.
- Blank line after the first sentence before further detail.
- Do not document both getter and setter — document one only.
- Include code samples for non-trivial APIs.
- Explain parameters, return values, and thrown exceptions in prose.
- Place doc comments before annotations.

## Accessibility

- All interactive widgets must have `Semantics` labels.
- Test with TalkBack (Android) and VoiceOver (iOS).
- Ensure the UI remains usable at large system font sizes.
- Verify color contrast ratios (≥ 4.5:1 for body text).

## Dependencies

- Add a package: `flutter pub add <name>`
- Add a dev dependency: `flutter pub add dev:<name>`
- Remove a package: `dart pub remove <name>`
- Before adding a new package, confirm it is stable and well-maintained on
  pub.dev.
