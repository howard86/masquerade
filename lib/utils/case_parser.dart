class CaseConversions {
  const CaseConversions({
    required this.tokens,
    required this.camelCase,
    required this.pascalCase,
    required this.snakeCase,
    required this.screamingSnake,
    required this.kebabCase,
    required this.trainCase,
    required this.titleCase,
    required this.sentenceCase,
    required this.dotCase,
    required this.pathCase,
    required this.lowerCase,
    required this.upperCase,
  });

  final List<String> tokens;
  final String camelCase;
  final String pascalCase;
  final String snakeCase;
  final String screamingSnake;
  final String kebabCase;
  final String trainCase;
  final String titleCase;
  final String sentenceCase;
  final String dotCase;
  final String pathCase;
  final String lowerCase;
  final String upperCase;
}

class CaseParser {
  const CaseParser._();

  static const int maxInputLength = 10000;

  static final RegExp _validInput = RegExp(r'^[A-Za-z0-9_\-./\s]+$');
  static final RegExp _delimiters = RegExp(r'[_\-./\s]+');
  static final RegExp _acronymBoundary = RegExp(r'([A-Z]+)([A-Z][a-z])');
  static final RegExp _caseBoundary = RegExp(r'([a-z])([A-Z])');
  static final RegExp _letterDigitBoundary = RegExp(r'([A-Za-z])([0-9])');
  static final RegExp _digitLetterBoundary = RegExp(r'([0-9])([A-Za-z])');

  static CaseConversions? parse(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty ||
        trimmed.length > maxInputLength ||
        !_validInput.hasMatch(trimmed)) {
      return null;
    }

    // These mixed initialisms are explicitly useful as one word; the generic
    // acronym rule would otherwise split them as I/Pv and O/Auth.
    final String separated = trimmed
        .replaceAll('IPv', 'Ipv')
        .replaceAll('OAuth', 'Oauth')
        .replaceAllMapped(_acronymBoundary, (Match m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(_caseBoundary, (Match m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(_letterDigitBoundary, (Match m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(_digitLetterBoundary, (Match m) => '${m[1]} ${m[2]}');
    final List<String> tokens = List<String>.unmodifiable(
      separated
          .split(_delimiters)
          .where((String token) => token.isNotEmpty)
          .map((String token) => token.toLowerCase()),
    );
    if (tokens.isEmpty) return null;

    final List<String> titled = tokens.map(_capitalize).toList(growable: false);
    final String lower = tokens.join(' ');
    return CaseConversions(
      tokens: tokens,
      camelCase: '${tokens.first}${titled.skip(1).join()}',
      pascalCase: titled.join(),
      snakeCase: tokens.join('_'),
      screamingSnake: tokens.join('_').toUpperCase(),
      kebabCase: tokens.join('-'),
      trainCase: titled.join('-'),
      titleCase: titled.join(' '),
      sentenceCase:
          '${_capitalize(tokens.first)}${tokens.length == 1 ? '' : ' ${tokens.skip(1).join(' ')}'}',
      dotCase: tokens.join('.'),
      pathCase: tokens.join('/'),
      lowerCase: lower,
      upperCase: lower.toUpperCase(),
    );
  }

  static String _capitalize(String token) =>
      token.isEmpty ? token : '${token[0].toUpperCase()}${token.substring(1)}';
}
