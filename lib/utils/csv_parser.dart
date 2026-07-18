import 'dart:convert';

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
    if (input.length > maxInputChars ||
        utf8.encode(input).length > maxInputChars) {
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
      final _ReadResult read = _read(source, candidate);
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
          !delimiters.any(source.contains)) {
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
    if (output.length > maxOutputChars ||
        utf8.encode(output).length > maxOutputChars) {
      throw const FormatException('JSON output exceeds the 2 MiB limit.');
    }
    return output;
  }

  static String fromJson(String json, {String delimiter = ','}) {
    _validateDelimiter(delimiter);
    if (json.length > maxInputChars ||
        utf8.encode(json).length > maxInputChars) {
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
    if (utf8.encode(output).length > maxOutputChars) {
      throw const FormatException('CSV output exceeds the 2 MiB limit.');
    }
    return output;
  }

  static _ReadResult _read(String input, String delimiter) {
    final List<List<String>> records = <List<String>>[];
    List<String> row = <String>[];
    final StringBuffer field = StringBuffer();
    bool quoted = false;
    bool closedQuote = false;
    bool fieldStarted = false;
    int totalCells = 0;

    String? addField() {
      if (field.length > maxCellChars) {
        return 'A cell exceeds 65,536 characters.';
      }
      row.add(field.toString());
      if (row.length > maxColumns) return 'A row exceeds the 100 column limit.';
      field.clear();
      fieldStarted = false;
      closedQuote = false;
      return null;
    }

    String? addRow() {
      final String? error = addField();
      if (error != null) return error;
      records.add(List<String>.unmodifiable(row));
      totalCells += row.length;
      row = <String>[];
      if (records.length > maxRows) {
        return 'Input exceeds the 10,000 row limit.';
      }
      if (totalCells > maxCells) return 'Input exceeds the 100,000 cell limit.';
      return null;
    }

    for (int i = 0; i < input.length; i++) {
      final String char = input[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closedQuote = true;
          }
        } else {
          field.write(char);
          if (field.length > maxCellChars) {
            return const _ReadResult.error('A cell exceeds 65,536 characters.');
          }
        }
        continue;
      }

      if (closedQuote && char != delimiter && char != '\r' && char != '\n') {
        return _ReadResult.error(
          'Unexpected character after closing quote at character ${i + 1}.',
        );
      }
      if (char == '"') {
        if (fieldStarted || field.isNotEmpty) {
          return _ReadResult.error(
            'Unexpected quote in an unquoted field at character ${i + 1}.',
          );
        }
        quoted = true;
        fieldStarted = true;
      } else if (char == delimiter) {
        final String? error = addField();
        if (error != null) return _ReadResult.error(error);
      } else if (char == '\r' || char == '\n') {
        final String? error = addRow();
        if (error != null) return _ReadResult.error(error);
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      } else {
        fieldStarted = true;
        field.write(char);
        if (field.length > maxCellChars) {
          return const _ReadResult.error('A cell exceeds 65,536 characters.');
        }
      }
    }
    if (quoted) return const _ReadResult.error('Unclosed quoted field.');

    final bool endedWithLineBreak =
        input.endsWith('\n') || input.endsWith('\r');
    if (!endedWithLineBreak ||
        row.isNotEmpty ||
        field.isNotEmpty ||
        closedQuote) {
      final String? error = addRow();
      if (error != null) return _ReadResult.error(error);
    }
    if (records.isEmpty) return const _ReadResult.error('Empty input.');
    final int columns = records.first.length;
    for (int i = 1; i < records.length; i++) {
      if (records[i].length != columns) {
        return _ReadResult.error(
          'Row ${i + 1} has ${records[i].length} columns; expected $columns.',
        );
      }
    }
    return _ReadResult.ok(List<List<String>>.unmodifiable(records));
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
      rows: List<List<String>>.unmodifiable(
        hasHeader ? records.skip(1) : records,
      ),
    );
  }

  static bool _looksLikeHeader(List<List<String>> records) {
    if (records.length < 2) return false;
    final List<String> first = records.first;
    if (first.any((String value) => value.isEmpty) ||
        first.toSet().length != first.length) {
      return false;
    }
    final RegExp name = RegExp(r'^[A-Za-z_][A-Za-z0-9_ .-]*$');
    if (!first.every(name.hasMatch)) return false;
    for (int column = 0; column < first.length; column++) {
      if (records
          .skip(1)
          .any(
            (List<String> row) =>
                _cellType(row[column]) != _cellType(first[column]),
          )) {
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
