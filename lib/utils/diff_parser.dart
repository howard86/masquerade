/// Diff · text compare. Myers' O(ND) line diff with optional intra-line word
/// diff, hunk grouping (for `@@` headers + collapsed context), and a standard
/// unified-diff text serializer.
///
/// Lines are hash-interned to int ids so Myers compares ints, and a common
/// prefix/suffix is trimmed before the search — both keep the result
/// byte-identical to plain Myers while making large inputs cheap. A hard line
/// cap and an edit-distance cap bound worst-case time and memory; either trip
/// returns [DiffResult.tooLarge].
library;

/// One edit operation on a line or word token.
enum DiffOp { equal, insert, delete }

/// A coalesced run of word-diff text tagged with its [DiffOp].
typedef WordSpan = ({DiffOp op, String text});

/// A single line in a line-level diff. [aLine]/[bLine] are 1-based line numbers
/// in the A/B inputs, null on the side where the line does not exist.
class DiffLine {
  const DiffLine({
    required this.op,
    required this.text,
    this.aLine,
    this.bLine,
  });

  final DiffOp op;
  final String text;
  final int? aLine;
  final int? bLine;
}

/// Result of [DiffTool.lineDiff]. When [tooLarge] is true the inputs exceeded a
/// safety cap, [lines] is empty, and the UI should show a notice instead.
class DiffResult {
  const DiffResult({
    required this.lines,
    required this.additions,
    required this.deletions,
    this.tooLarge = false,
  });

  final List<DiffLine> lines;
  final int additions;
  final int deletions;
  final bool tooLarge;
}

/// A contiguous hunk: a run of changed lines plus surrounding context.
/// [startIndex]/[endIndex] are the inclusive/exclusive bounds into
/// [DiffResult.lines]; the a/b ranges drive the `@@ -aStart,aCount +bStart,bCount @@`
/// header.
class DiffHunk {
  const DiffHunk({
    required this.startIndex,
    required this.endIndex,
    required this.aStart,
    required this.aCount,
    required this.bStart,
    required this.bCount,
    required this.lines,
  });

  final int startIndex;
  final int endIndex;
  final int aStart;
  final int aCount;
  final int bStart;
  final int bCount;
  final List<DiffLine> lines;
}

class DiffTool {
  const DiffTool._();

  /// Hard cap on lines per side. Inputs beyond this return [DiffResult.tooLarge]
  /// without running Myers.
  static const int maxLines = 5000;

  /// Edit-distance cap. If the shortest edit script would exceed this, bail to
  /// [DiffResult.tooLarge] — this bounds both Myers' time (O(D·N)) and the
  /// trace memory (O(D²)).
  static const int _maxDelta = 2500;

  static const DiffResult _tooLarge = DiffResult(
    lines: <DiffLine>[],
    additions: 0,
    deletions: 0,
    tooLarge: true,
  );

  static final RegExp _wsRun = RegExp(r'\s+');

  // Word tokenizer: maximal runs of word chars, whitespace, or punctuation.
  // Keeping classes separate lets a change inside 'foo.bar' highlight only the
  // changed segment instead of the whole token.
  static final RegExp _token = RegExp(r'[A-Za-z0-9_]+|\s+|[^A-Za-z0-9_\s]+');

  /// Line-level Myers diff. When [ignoreWhitespace] is true, lines are compared
  /// after trimming and collapsing internal whitespace runs to a single space;
  /// the displayed [DiffLine.text] is always the original.
  static DiffResult lineDiff(
    String a,
    String b, {
    bool ignoreWhitespace = false,
  }) {
    final List<String> aLines = _splitLines(a);
    final List<String> bLines = _splitLines(b);
    final int n = aLines.length;
    final int m = bLines.length;
    if (n > maxLines || m > maxLines) {
      return _tooLarge;
    }

    final Map<String, int> intern = <String, int>{};
    int idOf(String line) {
      final String key = ignoreWhitespace ? _normalizeWs(line) : line;
      return intern.putIfAbsent(key, () => intern.length);
    }

    final List<int> aKey = <int>[for (final String l in aLines) idOf(l)];
    final List<int> bKey = <int>[for (final String l in bLines) idOf(l)];

    // Trim common prefix/suffix — cheap, exact, and shrinks the Myers grid.
    int p = 0;
    while (p < n && p < m && aKey[p] == bKey[p]) {
      p++;
    }
    int s = 0;
    while (s < n - p && s < m - p && aKey[n - 1 - s] == bKey[m - 1 - s]) {
      s++;
    }

    final List<DiffOp>? steps = _myers(
      aKey.sublist(p, n - s),
      bKey.sublist(p, m - s),
    );
    if (steps == null) {
      return _tooLarge;
    }

    final List<DiffLine> out = <DiffLine>[];
    int additions = 0;
    int deletions = 0;

    for (int i = 0; i < p; i++) {
      out.add(
        DiffLine(op: DiffOp.equal, text: aLines[i], aLine: i + 1, bLine: i + 1),
      );
    }

    int ai = p;
    int bi = p;
    for (final DiffOp op in steps) {
      switch (op) {
        case DiffOp.equal:
          out.add(
            DiffLine(
              op: DiffOp.equal,
              text: aLines[ai],
              aLine: ai + 1,
              bLine: bi + 1,
            ),
          );
          ai++;
          bi++;
        case DiffOp.delete:
          out.add(DiffLine(op: DiffOp.delete, text: aLines[ai], aLine: ai + 1));
          ai++;
          deletions++;
        case DiffOp.insert:
          out.add(DiffLine(op: DiffOp.insert, text: bLines[bi], bLine: bi + 1));
          bi++;
          additions++;
      }
    }

    for (int i = 0; i < s; i++) {
      final int aIdx = n - s + i;
      final int bIdx = m - s + i;
      out.add(
        DiffLine(
          op: DiffOp.equal,
          text: aLines[aIdx],
          aLine: aIdx + 1,
          bLine: bIdx + 1,
        ),
      );
    }

    return DiffResult(lines: out, additions: additions, deletions: deletions);
  }

  /// Intra-line word diff of two strings. Tokenizes by character class
  /// (word / whitespace / punctuation), runs Myers at token level, then
  /// coalesces adjacent same-op tokens into single spans.
  static List<WordSpan> wordDiff(String a, String b) {
    final List<String> at = _tokenize(a);
    final List<String> bt = _tokenize(b);

    final Map<String, int> intern = <String, int>{};
    int idOf(String t) => intern.putIfAbsent(t, () => intern.length);
    final List<int> ak = <int>[for (final String t in at) idOf(t)];
    final List<int> bk = <int>[for (final String t in bt) idOf(t)];

    // Token counts are bounded by line length, so the delta cap never trips
    // here; fall back to a coarse replace if it somehow does.
    final List<DiffOp> ops =
        _myers(ak, bk) ??
        <DiffOp>[
          for (int i = 0; i < at.length; i++) DiffOp.delete,
          for (int i = 0; i < bt.length; i++) DiffOp.insert,
        ];

    final List<WordSpan> spans = <WordSpan>[];
    final StringBuffer buf = StringBuffer();
    DiffOp? cur;
    void flush() {
      if (cur != null && buf.isNotEmpty) {
        spans.add((op: cur, text: buf.toString()));
      }
      buf.clear();
    }

    int ai = 0;
    int bi = 0;
    for (final DiffOp op in ops) {
      final String tok = switch (op) {
        DiffOp.equal => at[ai],
        DiffOp.delete => at[ai],
        DiffOp.insert => bt[bi],
      };
      if (cur != op) {
        flush();
        cur = op;
      }
      buf.write(tok);
      switch (op) {
        case DiffOp.equal:
          ai++;
          bi++;
        case DiffOp.delete:
          ai++;
        case DiffOp.insert:
          bi++;
      }
    }
    flush();
    return spans;
  }

  /// Groups a line list into hunks: each maximal run of changed lines plus up to
  /// [context] lines of surrounding equal context. Runs whose context windows
  /// touch are merged. Returns empty when there are no changes.
  static List<DiffHunk> hunkify(List<DiffLine> lines, {int context = 3}) {
    final int len = lines.length;
    if (len == 0) return const <DiffHunk>[];

    final List<bool> keep = List<bool>.filled(len, false);
    bool anyChange = false;
    for (int i = 0; i < len; i++) {
      if (lines[i].op != DiffOp.equal) {
        anyChange = true;
        final int lo = (i - context) < 0 ? 0 : i - context;
        final int hi = (i + context) >= len ? len - 1 : i + context;
        for (int j = lo; j <= hi; j++) {
          keep[j] = true;
        }
      }
    }
    if (!anyChange) return const <DiffHunk>[];

    final List<DiffHunk> hunks = <DiffHunk>[];
    int i = 0;
    while (i < len) {
      if (!keep[i]) {
        i++;
        continue;
      }
      final int start = i;
      while (i < len && keep[i]) {
        i++;
      }
      hunks.add(_buildHunk(lines, start, i));
    }
    return hunks;
  }

  /// Serializes [result] as a standard unified diff (`--- / +++ / @@`) with
  /// [context] lines around each change. Returns an empty string when the inputs
  /// are identical. Pass [hunks] to reuse an already-computed grouping (must
  /// have been built with the same [context]); otherwise it is derived here.
  static String toUnifiedText(
    DiffResult result, {
    int context = 3,
    String aLabel = 'a',
    String bLabel = 'b',
    List<DiffHunk>? hunks,
  }) {
    if (result.additions == 0 && result.deletions == 0) return '';
    final List<DiffHunk> hs = hunks ?? hunkify(result.lines, context: context);
    if (hs.isEmpty) return '';

    final StringBuffer sb = StringBuffer()
      ..writeln('--- $aLabel')
      ..writeln('+++ $bLabel');
    for (final DiffHunk h in hs) {
      sb.writeln('@@ -${h.aStart},${h.aCount} +${h.bStart},${h.bCount} @@');
      for (final DiffLine l in h.lines) {
        final String prefix = switch (l.op) {
          DiffOp.equal => ' ',
          DiffOp.delete => '-',
          DiffOp.insert => '+',
        };
        sb.writeln('$prefix${l.text}');
      }
    }
    return sb.toString();
  }

  static DiffHunk _buildHunk(List<DiffLine> lines, int start, int end) {
    int aStart = 0;
    int aCount = 0;
    int bStart = 0;
    int bCount = 0;
    for (int i = start; i < end; i++) {
      final DiffLine l = lines[i];
      if (l.aLine != null) {
        if (aCount == 0) aStart = l.aLine!;
        aCount++;
      }
      if (l.bLine != null) {
        if (bCount == 0) bStart = l.bLine!;
        bCount++;
      }
    }
    return DiffHunk(
      startIndex: start,
      endIndex: end,
      aStart: aStart,
      aCount: aCount,
      bStart: bStart,
      bCount: bCount,
      lines: lines.sublist(start, end),
    );
  }

  static List<String> _splitLines(String s) =>
      s.isEmpty ? const <String>[] : s.split('\n');

  static String _normalizeWs(String line) =>
      line.trim().replaceAll(_wsRun, ' ');

  static List<String> _tokenize(String s) =>
      _token.allMatches(s).map((Match m) => m.group(0)!).toList();

  /// Myers' O(ND) shortest-edit-script search over interned int sequences.
  /// Returns the ordered ops, or null if the edit distance exceeds [_maxDelta].
  static List<DiffOp>? _myers(List<int> a, List<int> b) {
    final int n = a.length;
    final int m = b.length;
    if (n == 0 && m == 0) return <DiffOp>[];
    if (n == 0) return List<DiffOp>.filled(m, DiffOp.insert);
    if (m == 0) return List<DiffOp>.filled(n, DiffOp.delete);

    final int max = n + m;
    final int off = max;
    final List<int> v = List<int>.filled(2 * max + 1, 0);
    // Compact per-depth snapshots of the active band [-d, d].
    final List<List<int>> trace = <List<int>>[];
    int dEnd = -1;

    for (int d = 0; d <= max; d++) {
      if (d > _maxDelta) return null;
      trace.add(v.sublist(off - d, off + d + 1));
      bool done = false;
      for (int k = -d; k <= d; k += 2) {
        int x;
        if (k == -d || (k != d && v[off + k - 1] < v[off + k + 1])) {
          x = v[off + k + 1];
        } else {
          x = v[off + k - 1] + 1;
        }
        int y = x - k;
        while (x < n && y < m && a[x] == b[y]) {
          x++;
          y++;
        }
        v[off + k] = x;
        if (x >= n && y >= m) {
          dEnd = d;
          done = true;
          break;
        }
      }
      if (done) break;
    }
    if (dEnd < 0) return null;

    final List<DiffOp> ops = <DiffOp>[];
    int x = n;
    int y = m;
    for (int d = dEnd; d > 0; d--) {
      final List<int> band = trace[d]; // band[k + d] == v[off + k]
      final int k = x - y;
      final bool down =
          k == -d || (k != d && band[(k - 1) + d] < band[(k + 1) + d]);
      final int prevK = down ? k + 1 : k - 1;
      final int prevX = band[prevK + d];
      final int prevY = prevX - prevK;
      while (x > prevX && y > prevY) {
        ops.add(DiffOp.equal);
        x--;
        y--;
      }
      ops.add(down ? DiffOp.insert : DiffOp.delete);
      x = prevX;
      y = prevY;
    }
    while (x > 0 && y > 0) {
      ops.add(DiffOp.equal);
      x--;
      y--;
    }
    while (x > 0) {
      ops.add(DiffOp.delete);
      x--;
    }
    while (y > 0) {
      ops.add(DiffOp.insert);
      y--;
    }
    return ops.reversed.toList();
  }
}
