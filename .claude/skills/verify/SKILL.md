---
name: verify
description: Run the same gates this project's CI runs — dart format check, flutter analyze, and the test suite with coverage. Use before claiming a change complete or before opening a PR.
---

# Verify

Reproduce CI locally, in order. Stop on the first failure and report what failed verbatim — do not auto-fix without telling the user.

## Steps

1. **Format check** (CI flag, not auto-format):

   ```bash
   dart format --output=none --set-exit-if-changed .
   ```

   If this fails, the right fix is `dart format .`, then re-run the check. Mention which files changed.

2. **Static analysis:**

   ```bash
   flutter analyze
   ```

   Treat any warning as a failure — `flutter_lints` is the lint set, no rules are suppressed in `analysis_options.yaml`.

3. **Tests with coverage** (matches CI exactly — see `.github/workflows/ci.yml`):

   ```bash
   flutter test --coverage
   ```

## Reporting

After all three pass, say "verify: format ok, analyze ok, tests ok (N passed)" with the actual count from the test output. If any step fails, paste the relevant output (not a paraphrase) and stop.

## Notes

- Pre-commit runs format + analyze, but not tests (they're on the `[manual]` stage). Running this skill is the safest pre-PR check.
- `flutter test` and `flutter analyze` are independent gates — `flutter test` does not run analyze under the hood.
- This skill does not run `flutter build` — release builds are local-only; replicate only when debugging a platform-specific issue.
