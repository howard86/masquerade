import 'regex_worker_native.dart'
    if (dart.library.html) 'regex_worker_web.dart'
    as worker;

typedef RegexWorkerRunner =
    Future<RegexResult> Function({
      required String pattern,
      required String input,
      required bool caseSensitive,
      required bool multiLine,
      required bool dotAll,
      required bool unicode,
      required Duration timeLimit,
      void Function()? onStarted,
    });

sealed class RegexResult {
  const RegexResult();
}

class RegexOk extends RegexResult {
  const RegexOk({required this.matches, required this.truncated});

  final List<RegexMatchInfo> matches;
  final bool truncated;
}

class RegexErr extends RegexResult {
  const RegexErr(this.message);

  final String message;
}

class RegexMatchInfo {
  const RegexMatchInfo({
    required this.start,
    required this.end,
    required this.text,
    required this.groups,
    required this.named,
  });

  final int start;
  final int end;
  final String text;
  final List<String?> groups;
  final Map<String, String?> named;
}

class RegexTester {
  const RegexTester._();

  static const int maxPatternLength = 4096;
  static const int maxInputLength = 64 * 1024;
  static const int maxCaptureGroups = 100;
  static const int maxMatches = 10000;
  static const Duration timeout = Duration(milliseconds: 500);

  static Future<RegexResult> runAsync({
    required String pattern,
    required String input,
    bool caseSensitive = true,
    bool multiLine = false,
    bool dotAll = false,
    bool unicode = true,
    Duration timeLimit = timeout,
    RegexWorkerRunner? workerRunner,
    void Function()? onWorkerStarted,
  }) async {
    if (pattern.length > maxPatternLength || input.length > maxInputLength) {
      return run(
        pattern: pattern,
        input: input,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
      );
    }
    try {
      return await (workerRunner ?? worker.runRegexWorker)(
        pattern: pattern,
        input: input,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
        timeLimit: timeLimit,
        onStarted: onWorkerStarted,
      );
    } on Object {
      return const RegexErr('Regular expression matching is unavailable.');
    }
  }

  static RegexResult run({
    required String pattern,
    required String input,
    bool caseSensitive = true,
    bool multiLine = false,
    bool dotAll = false,
    bool unicode = true,
  }) {
    if (pattern.length > maxPatternLength) {
      return const RegexErr('Pattern is limited to 4,096 characters.');
    }
    if (input.length > maxInputLength) {
      return const RegexErr('Test string is limited to 64 KiB.');
    }

    final RegExp expression;
    final int captureGroups;
    try {
      expression = RegExp(
        pattern,
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
      );
      captureGroups = RegExp(
        '(?:)|(?:$pattern)',
        caseSensitive: caseSensitive,
        multiLine: multiLine,
        dotAll: dotAll,
        unicode: unicode,
      ).firstMatch('')!.groupCount;
    } on FormatException catch (error) {
      return RegexErr(formatCompileError(error.message, pattern));
    }
    if (captureGroups > maxCaptureGroups) {
      return const RegexErr('Pattern is limited to 100 capture groups.');
    }
    final List<RegexMatchInfo> matches = <RegexMatchInfo>[];
    bool truncated = false;
    for (final RegExpMatch match in expression.allMatches(input)) {
      if (matches.length == maxMatches) {
        truncated = true;
        break;
      }
      matches.add(
        RegexMatchInfo(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          groups: List<String?>.unmodifiable(<String?>[
            for (int index = 1; index <= match.groupCount; index++)
              match.group(index),
          ]),
          named: Map<String, String?>.unmodifiable(<String, String?>{
            for (final String name in match.groupNames)
              name: match.namedGroup(name),
          }),
        ),
      );
    }
    return RegexOk(
      matches: List<RegexMatchInfo>.unmodifiable(matches),
      truncated: truncated,
    );
  }

  static String formatCompileError(String message, String pattern) {
    final String detail = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (detail.isEmpty || detail.length > 160 || detail.contains(pattern)) {
      return 'Invalid regular expression.';
    }
    return 'Invalid regular expression: $detail';
  }
}
