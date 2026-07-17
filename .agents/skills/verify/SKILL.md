---
name: verify
description: Run the same gates this project's CI runs — dependency resolution, formatting, analysis, tests, and a release web build. Use before claiming a change complete or before opening a PR.
---

# Verify

Reproduce CI locally, in order. Stop on the first failure and report what failed verbatim — do not auto-fix without telling the user.

## Steps

1. **Resolve dependencies:**

   ```bash
   flutter pub get
   ```

2. **Format check** (CI flag, not auto-format):

   ```bash
   dart format --output=none --set-exit-if-changed .
   ```

   If this fails, the right fix is `dart format .`, then re-run the check. Mention which files changed.

3. **Static analysis:**

   ```bash
   flutter analyze
   ```

   Treat any warning as a failure — `flutter_lints` is the lint set, no rules are suppressed in `analysis_options.yaml`.

4. **Tests with coverage:**

   ```bash
   flutter test --coverage
   ```

5. **Release web build:**

   ```bash
   flutter build web --release
   ```

## Reporting

After all five pass, say "verify: pub get ok, format ok, analyze ok, tests ok (N passed), web build ok" with the actual count from the test output. If any step fails, paste the relevant output (not a paraphrase) and stop.

## Notes

- Pre-commit runs format + analyze, but not tests (they're on the `[manual]` stage). Running this skill is the safest pre-PR check.
- `flutter test` and `flutter analyze` are independent gates — `flutter test` does not run analyze under the hood.
- Native release builds remain local-only; CI builds web as a smoke test.
