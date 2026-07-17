# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

**webs** is a Flutter web application (targeting Flutter web via `flutter_web_plugins`). State is managed with Provider, real-time communication over WebSockets, and content is rendered from Markdown. The app embeds web content via WebView, handles file uploads, plays audio, and persists local state.

## Environment

- **Dart/Flutter SDK:** `^3.11.0` (Dart 3.11+). Do not use language features beyond this version.
- **Primary target:** Web. Prefer web-compatible plugins and guard any platform-specific code with `kIsWeb`.
- **Package is private:** `publish_to: "none"`. Never add publishing metadata.

## Commands

```bash
# Install / sync dependencies
flutter pub get

# Run (web)
flutter run -d chrome

# Codegen — required after editing any @freezed or @JsonSerializable class
dart run build_runner build --delete-conflicting-outputs
# Continuous codegen during development
dart run build_runner watch --delete-conflicting-outputs

# Analyze & format (run before every commit)
flutter analyze
dart format .

# Tests
flutter test
flutter test --coverage
flutter test test/path/to/specific_test.dart

# Production build (web)
flutter build web --release
```

## Architecture & Conventions

### Layering
Keep a clean separation. A typical feature flows: **UI (widgets) → Provider (state/notifiers) → Services (business logic, I/O) → Models (data)**. Widgets never call `http`, `web_socket_channel`, or `shared_preferences` directly — that belongs in a service.

- `lib/models/` — immutable data classes (freezed + json_serializable).
- `lib/services/` — networking (`http`), sockets (`web_socket_channel`), persistence (`shared_preferences`), crypto, file handling. No Flutter widget imports here.
- `lib/providers/` — `ChangeNotifier` / provider classes exposing state to the UI.
- `lib/screens/` (or `lib/pages/`) — top-level routed views.
- `lib/widgets/` — reusable, presentation-only components.
- `lib/utils/` — pure helpers (formatting via `intl`, mime lookups, etc.).

### State Management (Provider)
- Expose state through `ChangeNotifier`; call `notifyListeners()` only after state actually changes.
- Read with `context.watch<T>()` in `build`, and `context.read<T>()` for one-off actions in callbacks. Avoid `Provider.of` with `listen: true` outside `build`.
- Prefer `Consumer`/`Selector` to scope rebuilds to the smallest subtree.
- Dispose controllers, subscriptions, and sinks in `dispose()`.

### Models & Codegen (freezed / json_serializable)
- All DTOs and domain models are `@freezed` classes with `fromJson`/`toJson`.
- Never hand-edit generated files (`*.freezed.dart`, `*.g.dart`) — regenerate instead.
- After any model change, run `build_runner build --delete-conflicting-outputs` and commit the regenerated files.
- Keep `part '<file>.freezed.dart';` and `part '<file>.g.dart';` directives in sync with the source filename.

### Networking & Real-time
- **HTTP:** centralize base URLs, headers, and error handling in a service. Always handle non-2xx responses and `SocketException`/timeouts explicitly. Never leave a bare `http.get` in the UI.
- **WebSockets:** create channels in a service, expose a broadcast stream, and always close the sink on dispose/logout. Handle reconnection and error states deliberately.
- Parse responses through the generated `fromJson`; do not access raw `Map` keys in the UI.

### Web-specific Concerns
- Use `kIsWeb` before touching `dart:io` or platform-only APIs.
- `webview_flutter_web` and `file_picker` behave differently on web — test file picking and webview flows in an actual browser, not just an assumption.
- CORS is the server's responsibility; document any required headers rather than working around them client-side.

### Security
- Never hardcode secrets, tokens, or API keys. Read them from build-time config (`--dart-define`) or a runtime config endpoint.
- `shared_preferences` is **not** secure storage — never persist raw credentials or sensitive tokens there in plaintext. Use `crypto` for hashing/verification only, not as a substitute for real key management.
- Sanitize/validate anything rendered through `flutter_markdown` or loaded into a WebView.

## Coding Standards

- Lints are enforced via `flutter_lints` (`analysis_options.yaml`). Code must pass `flutter analyze` with no new warnings.
- Format with `dart format .` — no exceptions.
- Prefer `const` constructors; make fields `final` by default.
- Use `intl` for all user-facing dates, numbers, and any i18n — no manual string formatting of dates.
- Handle async errors; do not swallow exceptions silently. Surface user-facing failures through provider state.
- Name files `snake_case.dart`; classes `PascalCase`; members `camelCase`.

## Documentation & Comments

Comment to explain **why**, not **what** — the code already says what it does.

- **Public API:** every public class, method, and top-level function gets a `///` dartdoc comment describing its purpose, parameters, return value, and any thrown exceptions. Use `[identifier]` references so IDEs link them.
- **Providers & services:** document the state a provider owns, side effects, and lifecycle expectations (what must be disposed, what triggers a rebuild). For services, document network contracts, error/timeout behavior, and reconnection semantics.
- **Non-obvious logic:** add a short `//` comment when intent isn't clear from the code — a workaround, a web-specific quirk (`kIsWeb`), a CORS constraint, a crypto choice, or a spec/protocol assumption. Link the issue/spec where relevant.
- **Don't** comment the obvious (`// increment counter`), leave commented-out code, or let comments drift out of sync with the code — update or delete them.
- **TODOs:** format as `// TODO(owner): description` and, ideally, reference a tracking issue. Don't ship silent `FIXME`s.
- Generated files (`*.freezed.dart`, `*.g.dart`) are never commented by hand.

## Testing

- Unit-test services and providers; widget-test key UI flows with `flutter_test`.
- Mock network/socket/persistence boundaries — do not hit live services in tests.
- Keep tests deterministic; no reliance on wall-clock time or real I/O.
- Run `flutter test` (and ideally `flutter analyze`) before every commit.

## Definition of Done

Before considering a change complete:
1. `dart run build_runner build --delete-conflicting-outputs` (if models changed) and generated files committed.
2. `flutter analyze` passes clean.
3. `dart format .` applied.
4. `flutter test` passes.
5. `flutter build web --release` succeeds.

## Do / Don't for Claude

- **Do** place I/O and business logic in services, not widgets.
- **Do** regenerate and commit freezed/json code after model edits.
- **Don't** edit `*.freezed.dart` or `*.g.dart` by hand.
- **Don't** introduce dependencies without web support or add packages not already in `pubspec.yaml` without flagging it.
- **Don't** use `dart:io`-only APIs without a `kIsWeb` guard.
- **Don't** store secrets or credentials in source or `shared_preferences`.
