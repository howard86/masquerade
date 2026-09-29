import 'dart:collection';
import 'dart:convert';

import 'utf8_length.dart';

sealed class CsvParseResult {
  const CsvParseResult();
}

class CsvOk extends CsvParseResult {
  const CsvOk({
    required this.delimiter,
    required this.hasHeader,
    required this.header,
    required this.rows,
  });

  final String delimiter;
  final bool hasHeader;
  final List<String>? header;
  final List<List<String>> rows;
}

class CsvErr extends CsvParseResult {
  const CsvErr(this.message);

  final String message;
}

class CsvParser {
  const CsvParser._();

  static const int maxInputChars = 1024 * 1024;
  static const int maxRows = 10000;
  static const int maxColumns = 100;
  static const int maxCells = 100000;
  static const int maxCellChars = 65536;
  static const int maxOutputChars = 2 * 1024 * 1024;
  static const List<String> delimiters = <String>[',', '\t', ';'];

  static CsvParseResult parse(
    String input, {
    String? delimiter,
    bool? hasHeader,
  }) {
    if (utf8LengthExceeds(input, maxInputChars)) {
      return const CsvErr('Input exceeds the 1 MiB limit.');
    }
    if (input.isEmpty || input == '\ufeff') {
      return const CsvErr('Empty input.');
    }
    if (delimiter != null && !delimiters.contains(delimiter)) {
      return const CsvErr('Delimiter must be comma, tab, or semicolon.');
    }

    final String source = input.startsWith('\ufeff')
        ? input.substring(1)
        : input;
    if (delimiter != null) {
      return _finish(_read(source, delimiter), delimiter, hasHeader);
    }

    _Candidate? best;
    _ReadResult? commaFallback;
    CsvErr? firstError;
    for (final String candidate in delimiters) {
      if (candidate != ',' && !source.contains(candidate)) {
        continue;
      }
      // Only the first failing delimiter's message is ever reported, so the
      // rest may stop at their first column-count mismatch.
      final _ReadResult read = _read(
        source,
        candidate,
        exactError: firstError == null,
      );
      if (read.error != null) {
        firstError ??= CsvErr(read.error!);
        continue;
      }
      if (candidate == ',') commaFallback = read;
      final int columns = read.records!.first.length;
      if (columns < 2 || read.records!.length < 2) continue;
      final _Candidate next = _Candidate(candidate, read, columns);
      if (best == null || next.score > best.score) best = next;
    }
    if (best == null) {
      if (commaFallback != null &&
          commaFallback.records!.length >= 2 &&
          !delimiters.any(
            (String delimiter) => _hasUnquotedDelimiter(source, delimiter),
          )) {
        return _finish(commaFallback, ',', hasHeader);
      }
      return firstError ??
          const CsvErr(
            'Could not detect a consistent comma, tab, or semicolon delimiter.',
          );
    }
    return _finish(best.read, best.delimiter, hasHeader);
  }

  static String toJson(CsvOk parsed) {
    _validateDelimiter(parsed.delimiter);
    final List<List<String>> records = <List<String>>[
      if (parsed.header != null) parsed.header!,
      ...parsed.rows,
    ];
    _validateShape(records);
    if (parsed.hasHeader != (parsed.header != null)) {
      throw const FormatException('Header metadata is inconsistent.');
    }
    if (parsed.header != null) _validateHeader(parsed.header!);

    final Object value = parsed.header == null
        ? parsed.rows
        : <Map<String, String>>[
            for (final List<String> row in parsed.rows)
              <String, String>{
                for (int i = 0; i < parsed.header!.length; i++)
                  parsed.header![i]: row[i],
              },
          ];
    final String output = const JsonEncoder.withIndent('  ').convert(value);
    if (utf8LengthExceeds(output, maxOutputChars)) {
      throw const FormatException('JSON output exceeds the 2 MiB limit.');
    }
    return output;
  }

  static String fromJson(String json, {String delimiter = ','}) {
    _validateDelimiter(delimiter);
    if (utf8LengthExceeds(json, maxInputChars)) {
      throw const FormatException('Input exceeds the 1 MiB limit.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON: ${error.message}');
    }
    if (decoded is! List<Object?>) {
      throw const FormatException('JSON must be an array of rows.');
    }
    if (decoded.length > maxRows) {
      throw const FormatException('JSON exceeds the 10,000 row limit.');
    }
    if (decoded.isEmpty) return '';

    final List<List<String>> records;
    if (decoded.first is Map<String, Object?>) {
      final Map<String, Object?> first = decoded.first! as Map<String, Object?>;
      if (first.isEmpty) {
        throw const FormatException(
          'Object rows must have at least one column.',
        );
      }
      final List<String> header = first.keys.toList(growable: false);
      _validateHeader(header);
      records = <List<String>>[header];
      for (int rowIndex = 0; rowIndex < decoded.length; rowIndex++) {
        final Object? rawRow = decoded[rowIndex];
        if (rawRow is! Map<String, Object?> ||
            !_sameKeys(rawRow.keys, header)) {
          throw FormatException(
            'Object row ${rowIndex + 1} must use the same columns.',
          );
        }
        records.add(<String>[
          for (final String key in header)
            _scalar(rawRow[key], rowIndex + 1, key),
        ]);
      }
    } else if (decoded.first is List<Object?>) {
      records = <List<String>>[];
      for (int rowIndex = 0; rowIndex < decoded.length; rowIndex++) {
        final Object? rawRow = decoded[rowIndex];
        if (rawRow is! List<Object?>) {
          throw FormatException('JSON row ${rowIndex + 1} is not an array.');
        }
        records.add(<String>[
          for (int column = 0; column < rawRow.length; column++)
            _scalar(rawRow[column], rowIndex + 1, 'column ${column + 1}'),
        ]);
      }
    } else {
      throw const FormatException(
        'JSON rows must all be objects or all be arrays.',
      );
    }

    _validateShape(records);
    final StringBuffer out = StringBuffer();
    for (int row = 0; row < records.length; row++) {
      if (row > 0) out.write('\r\n');
      for (int column = 0; column < records[row].length; column++) {
        if (column > 0) out.write(delimiter);
        out.write(_quote(records[row][column], delimiter));
        if (out.length > maxOutputChars) {
          throw const FormatException('CSV output exceeds the 2 MiB limit.');
        }
      }
    }
    final String output = out.toString();
    if (utf8LengthExceeds(output, maxOutputChars)) {
      throw const FormatException('CSV output exceeds the 2 MiB limit.');
    }
    return output;
  }

  static const int _quoteUnit = 0x22;
  static const int _cr = 0x0d;
  static const int _lf = 0x0a;

  /// Reads [input] as records split on [delimiter].
  ///
  /// Scans code units and slices each field out of [input] rather than
  /// building it a character at a time. After the first column-count
  /// mismatch the records can no longer succeed, so it stops materializing
  /// them: with [exactError] it keeps scanning only to report the same
  /// error a full read would (a later structural or limit error wins, as
  /// before); without it, it returns the mismatch at once.
  static _ReadResult _read(
    String input,
    String delimiter, {
    bool exactError = true,
  }) {
    final int delim = delimiter.codeUnitAt(0);
    final int length = input.length;
    final List<List<String>> records = <List<String>>[];
    List<String> row = <String>[];
    bool build = true;
    int rowCells = 0;
    int recordCount = 0;
    int totalCells = 0;
    int columns = 0;
    String? mismatch;

    // The current field: input[fieldStart, fieldEnd), with "" pairs still
    // doubled when [fieldEscaped]; [fieldLength] is its decoded length.
    int fieldStart = 0;
    int fieldEnd = 0;
    int fieldLength = 0;
    bool fieldEscaped = false;
    bool closedQuote = false;

    String? addField() {
      if (fieldLength > maxCellChars) {
        return 'A cell exceeds 65,536 characters.';
      }
      if (build) {
        final String value = input.substring(fieldStart, fieldEnd);
        row.add(fieldEscaped ? value.replaceAll('""', '"') : value);
      }
      if (++rowCells > maxColumns) return 'A row exceeds the 100 column limit.';
      fieldLength = 0;
      fieldEscaped = false;
      closedQuote = false;
      return null;
    }

    String? addRow() {
      final String? error = addField();
      if (error != null) return error;
      recordCount++;
      totalCells += rowCells;
      if (recordCount == 1) {
        columns = rowCells;
      } else if (rowCells != columns && mismatch == null) {
        mismatch = 'Row $recordCount has $rowCells columns; expected $columns.';
        if (!exactError) return mismatch;
        build = false;
        records.clear();
      }
      if (build) records.add(UnmodifiableListView<String>(row));
      row = <String>[];
      rowCells = 0;
      if (recordCount > maxRows) {
        return 'Input exceeds the 10,000 row limit.';
      }
      if (totalCells > maxCells) return 'Input exceeds the 100,000 cell limit.';
      return null;
    }

    int i = 0;
    while (true) {
      // At the start of a field.
      if (i < length && input.codeUnitAt(i) == _quoteUnit) {
        int j = i + 1;
        fieldStart = j;
        while (true) {
          final int quote = input.indexOf('"', j);
          final int segment = (quote < 0 ? length : quote) - j;
          // A cell overflows on the first ordinary character past the cap.
          if (segment > 0 && fieldLength + segment > maxCellChars) {
            return const _ReadResult.error('A cell exceeds 65,536 characters.');
          }
          fieldLength += segment;
          if (quote < 0) {
            return const _ReadResult.error('Unclosed quoted field.');
          }
          if (quote + 1 < length && input.codeUnitAt(quote + 1) == _quoteUnit) {
            fieldEscaped = true;
            fieldLength++;
            j = quote + 2;
            continue;
          }
          fieldEnd = quote;
          i = quote + 1;
          break;
        }
        closedQuote = true;
        if (i < length) {
          final int next = input.codeUnitAt(i);
          if (next != delim && next != _cr && next != _lf) {
            return _ReadResult.error(
              'Unexpected character after closing quote at character ${i + 1}.',
            );
          }
        }
      } else {
        int j = i;
        while (j < length) {
          final int unit = input.codeUnitAt(j);
          if (unit == delim ||
              unit == _cr ||
              unit == _lf ||
              unit == _quoteUnit) {
            break;
          }
          j++;
        }
        if (j - i > maxCellChars) {
          return const _ReadResult.error('A cell exceeds 65,536 characters.');
        }
        if (j < length && input.codeUnitAt(j) == _quoteUnit) {
          return _ReadResult.error(
            'Unexpected quote in an unquoted field at character ${j + 1}.',
          );
        }
        fieldStart = i;
        fieldEnd = j;
        fieldLength = j - i;
        i = j;
      }
      if (i >= length) break;
      final int unit = input.codeUnitAt(i);
      if (unit == delim) {
        final String? error = addField();
        if (error != null) return _ReadResult.error(error);
        i++;
      } else {
        final String? error = addRow();
        if (error != null) return _ReadResult.error(error);
        i += unit == _cr && i + 1 < length && input.codeUnitAt(i + 1) == _lf
            ? 2
            : 1;
      }
    }

    final bool endedWithLineBreak =
        input.endsWith('\n') || input.endsWith('\r');
    if (!endedWithLineBreak || rowCells > 0 || fieldLength > 0 || closedQuote) {
      final String? error = addRow();
      if (error != null) return _ReadResult.error(error);
    }
    if (recordCount == 0) return const _ReadResult.error('Empty input.');
    if (mismatch != null) return _ReadResult.error(mismatch!);
    return _ReadResult.ok(UnmodifiableListView<List<String>>(records));
  }

  static CsvParseResult _finish(
    _ReadResult read,
    String delimiter,
    bool? headerOverride,
  ) {
    if (read.error != null) return CsvErr(read.error!);
    final List<List<String>> records = read.records!;
    final bool hasHeader = headerOverride ?? _looksLikeHeader(records);
    if (hasHeader) {
      try {
        _validateHeader(records.first);
      } on FormatException catch (error) {
        return CsvErr(error.message);
      }
    }
    return CsvOk(
      delimiter: delimiter,
      hasHeader: hasHeader,
      header: hasHeader ? records.first : null,
      rows: hasHeader
          ? UnmodifiableListView<List<String>>(records.sublist(1))
          : records,
    );
  }

  static final RegExp _headerName = RegExp(r'^[A-Za-z_][A-Za-z0-9_ .-]*$');

  static bool _looksLikeHeader(List<List<String>> records) {
    if (records.length < 2) return false;
    final List<String> first = records.first;
    if (first.any((String value) => value.isEmpty) ||
        first.toSet().length != first.length) {
      return false;
    }
    final RegExp name = _headerName;
    if (!first.every(name.hasMatch)) return false;
    for (int column = 0; column < first.length; column++) {
      final int headerType = _cellType(first[column]);
      if (records
          .skip(1)
          .any((List<String> row) => _cellType(row[column]) != headerType)) {
        return true;
      }
    }
    return first.every((String value) => value == value.toLowerCase()) &&
        records
            .skip(1)
            .any(
              (List<String> row) => row.indexed.any(
                ((int, String) pair) =>
                    pair.$2 != pair.$2.toLowerCase() || !name.hasMatch(pair.$2),
              ),
            );
  }

  static int _cellType(String value) {
    if (num.tryParse(value) != null) return 1;
    if (value == 'true' || value == 'false') return 2;
    return 0;
  }

  static void _validateDelimiter(String delimiter) {
    if (!delimiters.contains(delimiter)) {
      throw const FormatException(
        'Delimiter must be comma, tab, or semicolon.',
      );
    }
  }

  static void _validateHeader(List<String> header) {
    if (header.any((String value) => value.isEmpty)) {
      throw const FormatException('Header names must not be empty.');
    }
    if (header.toSet().length != header.length) {
      throw const FormatException('Header names must be unique.');
    }
  }

  static void _validateShape(List<List<String>> records) {
    if (records.isEmpty) return;
    if (records.length > maxRows) {
      throw const FormatException('Input exceeds the 10,000 row limit.');
    }
    final int columns = records.first.length;
    if (columns == 0 || columns > maxColumns) {
      throw const FormatException('Rows must contain 1 to 100 columns.');
    }
    int cells = 0;
    for (int row = 0; row < records.length; row++) {
      if (records[row].length != columns) {
        throw FormatException(
          'Row ${row + 1} has ${records[row].length} columns; expected $columns.',
        );
      }
      cells += columns;
      if (cells > maxCells) {
        throw const FormatException('Input exceeds the 100,000 cell limit.');
      }
      if (records[row].any((String cell) => cell.length > maxCellChars)) {
        throw const FormatException('A cell exceeds 65,536 characters.');
      }
    }
  }

  static bool _sameKeys(Iterable<String> keys, List<String> expected) {
    final Set<String> actual = keys.toSet();
    return actual.length == expected.length && actual.containsAll(expected);
  }

  static bool _hasUnquotedDelimiter(String source, String delimiter) {
    bool quoted = false;
    for (int index = 0; index < source.length; index++) {
      if (source[index] == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && source[index] == delimiter) {
        return true;
      }
    }
    return false;
  }

  static String _scalar(Object? value, int row, String column) {
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value == null) {
      throw FormatException(
        'Row $row, $column is null; null cannot be preserved in CSV.',
      );
    }
    throw FormatException('Row $row, $column must be a scalar value.');
  }

  static String _quote(String value, String delimiter) {
    if (!value.contains(delimiter) &&
        !value.contains('"') &&
        !value.contains('\r') &&
        !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}

class _ReadResult {
  const _ReadResult.ok(this.records) : error = null;
  const _ReadResult.error(this.error) : records = null;

  final List<List<String>>? records;
  final String? error;
}

class _Candidate {
  const _Candidate(this.delimiter, this.read, this.score);

  final String delimiter;
  final _ReadResult read;
  final int score;
}
