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
      return RegexErr(_compileError(error, pattern));
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

  static String _compileError(FormatException error, String pattern) {
    final String detail = error.message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (detail.isEmpty || detail.length > 160 || detail.contains(pattern)) {
      return 'Invalid regular expression.';
    }
    return 'Invalid regular expression: $detail';
  }
}
