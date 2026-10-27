import 'dart:async';

import 'package:masquerade/widgets/tool_bodies/deferred_tool_body.dart';
// Only `loadLibrary` is used; the analyzer counts that as unused.
// ignore: unused_import
import 'package:masquerade/widgets/tool_bodies/seed_source.dart'
    deferred as vm_unit_warmup;

/// Loads the deferred tool-body library once per test isolate, before any
/// test runs, so catalog builders render the real body synchronously (as they
/// do in the app once the post-first-frame prefetch lands).
///
/// VM quirk: in a JIT test run every deferred prefix shares ONE loading unit,
/// and `loadLibrary()` awaits a per-unit Completer created in the zone of the
/// FIRST load. If that zone is the root zone, a later `loadLibrary()` from a
/// test's fake-async zone (e.g. a `DeferredToolBody` loading its library)
/// gets its continuation queued on the real microtask queue, which
/// `tester.pump()` never drains, so it hangs. Issuing the first load from a
/// zone that forwards microtasks to the *calling* zone keeps those later
/// loads drivable by `pump()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await runZoned(
    vm_unit_warmup.loadLibrary,
    zoneSpecification: ZoneSpecification(
      scheduleMicrotask:
          (Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
            final Zone caller = Zone.current;
            if (identical(caller, zone)) {
              parent.scheduleMicrotask(zone, f);
            } else {
              caller.scheduleMicrotask(f);
            }
          },
    ),
  );
  await ensureToolBodiesLoaded();
  await testMain();
}
