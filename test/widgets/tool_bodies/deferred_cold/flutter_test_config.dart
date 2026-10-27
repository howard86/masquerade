import 'dart:async';

/// Overrides `test/flutter_test_config.dart` for this directory: the deferred
/// tool-body library is NOT preloaded, so tests here see the cold path.
Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    Future<void>.sync(testMain);
