import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/diff_parser.dart';

void main() {
  group('DiffTool.lineDiff', () {
    test('identical inputs produce all-equal, zero changes', () {
      final DiffResult r = DiffTool.lineDiff('a\nb\nc', 'a\nb\nc');
      expect(r.additions, 0);
      expect(r.deletions, 0);
      expect(r.tooLarge, isFalse);
      expect(r.lines.every((DiffLine l) => l.op == DiffOp.equal), isTrue);
      expect(r.lines.length, 3);
      expect(r.lines[0].aLine, 1);
      expect(r.lines[0].bLine, 1);
      expect(r.lines[2].aLine, 3);
      expect(r.lines[2].bLine, 3);
    });

    test(
      'one-line change yields one delete + one insert with line numbers',
      () {
        final DiffResult r = DiffTool.lineDiff('a\nb\nc', 'a\nB\nc');
        expect(r.additions, 1);
        expect(r.deletions, 1);

        final DiffLine del = r.lines.firstWhere(
          (DiffLine l) => l.op == DiffOp.delete,
        );
        expect(del.text, 'b');
        expect(del.aLine, 2);
        expect(del.bLine, isNull);

        final DiffLine ins = r.lines.firstWhere(
          (DiffLine l) => l.op == DiffOp.insert,
        );
        expect(ins.text, 'B');
        expect(ins.bLine, 2);
        expect(ins.aLine, isNull);

        // Surrounding context keeps correct numbering on both sides.
        expect(r.lines.first.op, DiffOp.equal);
        expect(r.lines.first.aLine, 1);
        expect(r.lines.last.op, DiffOp.equal);
        expect(r.lines.last.aLine, 3);
        expect(r.lines.last.bLine, 3);
      },
    );

    test('pure insertion: empty A, multi-line B → all inserts', () {
      final DiffResult r = DiffTool.lineDiff('', 'x\ny\nz');
      expect(r.additions, 3);
      expect(r.deletions, 0);
      expect(r.lines.every((DiffLine l) => l.op == DiffOp.insert), isTrue);
      expect(r.lines.map((DiffLine l) => l.bLine).toList(), <int>[1, 2, 3]);
      expect(r.lines.every((DiffLine l) => l.aLine == null), isTrue);
    });

    test('pure deletion: multi-line A, empty B → all deletes', () {
      final DiffResult r = DiffTool.lineDiff('x\ny\nz', '');
      expect(r.additions, 0);
      expect(r.deletions, 3);
      expect(r.lines.every((DiffLine l) => l.op == DiffOp.delete), isTrue);
      expect(r.lines.map((DiffLine l) => l.aLine).toList(), <int>[1, 2, 3]);
      expect(r.lines.every((DiffLine l) => l.bLine == null), isTrue);
    });

    test('change in the middle of a long block keeps line numbers exact', () {
      final List<String> a = <String>[for (int i = 0; i < 100; i++) 'line $i'];
      final List<String> b = List<String>.of(a)..[50] = 'CHANGED';
      final DiffResult r = DiffTool.lineDiff(a.join('\n'), b.join('\n'));
      expect(r.additions, 1);
      expect(r.deletions, 1);
      final DiffLine del = r.lines.firstWhere(
        (DiffLine l) => l.op == DiffOp.delete,
      );
      final DiffLine ins = r.lines.firstWhere(
        (DiffLine l) => l.op == DiffOp.insert,
      );
      expect(del.text, 'line 50');
      expect(del.aLine, 51); // 1-based
      expect(ins.text, 'CHANGED');
      expect(ins.bLine, 51);
    });

    test(
      'ignoreWhitespace treats indentation/spacing-only changes as equal',
      () {
        final DiffResult plain = DiffTool.lineDiff(
          '  the   quick  ',
          'the quick',
        );
        expect(plain.additions + plain.deletions, greaterThan(0));

        final DiffResult ignored = DiffTool.lineDiff(
          '  the   quick  ',
          'the quick',
          ignoreWhitespace: true,
        );
        expect(ignored.additions, 0);
        expect(ignored.deletions, 0);
        // Displayed text is still the original (A side for equal lines).
        expect(ignored.lines.single.text, '  the   quick  ');
      },
    );

    test('over the line cap returns tooLarge without crashing', () {
      final String big = List<String>.filled(
        DiffTool.maxLines + 1,
        'x',
      ).join('\n');
      final DiffResult r = DiffTool.lineDiff(big, '');
      expect(r.tooLarge, isTrue);
      expect(r.lines, isEmpty);
    });

    test('1,000-line pair completes well under 100 ms', () {
      final List<String> a = <String>[for (int i = 0; i < 1000; i++) 'row $i'];
      final List<String> b = List<String>.of(a)
        ..[100] = 'changed-100'
        ..[500] = 'changed-500'
        ..[900] = 'changed-900';
      final Stopwatch sw = Stopwatch()..start();
      final DiffResult r = DiffTool.lineDiff(a.join('\n'), b.join('\n'));
      sw.stop();
      expect(r.additions, 3);
      expect(r.deletions, 3);
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });

  group('DiffTool.wordDiff', () {
    test('word substitution splits into equal / delete / insert spans', () {
      final List<({DiffOp op, String text})> spans = DiffTool.wordDiff(
        'hello world',
        'hello dart',
      );
      expect(spans, <({DiffOp op, String text})>[
        (op: DiffOp.equal, text: 'hello '),
        (op: DiffOp.delete, text: 'world'),
        (op: DiffOp.insert, text: 'dart'),
      ]);
    });

    test('punctuation runs let a sub-token change highlight precisely', () {
      final List<({DiffOp op, String text})> spans = DiffTool.wordDiff(
        'foo.bar',
        'foo.baz',
      );
      expect(spans, <({DiffOp op, String text})>[
        (op: DiffOp.equal, text: 'foo.'),
        (op: DiffOp.delete, text: 'bar'),
        (op: DiffOp.insert, text: 'baz'),
      ]);
    });

    test('identical strings produce a single equal span', () {
      final List<({DiffOp op, String text})> spans = DiffTool.wordDiff(
        'same text',
        'same text',
      );
      expect(spans, <({DiffOp op, String text})>[
        (op: DiffOp.equal, text: 'same text'),
      ]);
    });
  });

  group('DiffTool.hunkify', () {
    test('no changes → no hunks', () {
      final DiffResult r = DiffTool.lineDiff('a\nb\nc', 'a\nb\nc');
      expect(DiffTool.hunkify(r.lines), isEmpty);
    });

    test('distant changes split into separate hunks; near ones merge', () {
      final List<String> a = <String>[for (int i = 0; i < 40; i++) 'l$i'];
      final List<String> far = List<String>.of(a)
        ..[2] = 'X'
        ..[30] = 'Y';
      final DiffResult rFar = DiffTool.lineDiff(a.join('\n'), far.join('\n'));
      expect(DiffTool.hunkify(rFar.lines).length, 2);

      final List<String> near = List<String>.of(a)
        ..[10] = 'X'
        ..[12] = 'Y';
      final DiffResult rNear = DiffTool.lineDiff(a.join('\n'), near.join('\n'));
      expect(DiffTool.hunkify(rNear.lines).length, 1);
    });

    test('hunk a/b ranges match the unified-diff convention', () {
      final DiffResult r = DiffTool.lineDiff('a\nb\nc', 'a\nB\nc');
      final DiffHunk h = DiffTool.hunkify(r.lines).single;
      expect(h.aStart, 1);
      expect(h.aCount, 3); // a, b, c on the A side (context + deleted)
      expect(h.bStart, 1);
      expect(h.bCount, 3); // a, B, c on the B side
    });
  });

  group('DiffTool.toUnifiedText', () {
    test('emits standard headers, hunk marker, and +/-/space prefixes', () {
      final DiffResult r = DiffTool.lineDiff('a\nb\nc', 'a\nB\nc');
      final String text = DiffTool.toUnifiedText(r, aLabel: 'A', bLabel: 'B');
      expect(text, contains('--- A'));
      expect(text, contains('+++ B'));
      expect(text, contains('@@ -1,3 +1,3 @@'));
      expect(text, contains('\n a'));
      expect(text, contains('\n-b'));
      expect(text, contains('\n+B'));
      expect(text, contains('\n c'));
    });

    test('identical inputs serialize to an empty string', () {
      final DiffResult r = DiffTool.lineDiff('a\nb', 'a\nb');
      expect(DiffTool.toUnifiedText(r), isEmpty);
    });
  });
}
