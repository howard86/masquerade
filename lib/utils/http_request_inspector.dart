import 'dart:convert';

import 'sensitive_data_policy.dart';

const int _maxBytes = 65536;
const int _maxUrlLength = 8192;
const int _maxTokenLength = 8192;
const int _maxFields = 100;
const int _maxTokens = 256;
const int _maxDepth = 12;
const String _redacted = '[REDACTED]';

enum HttpSnippetKind { curl, rawHttp, fetch, axios, requestLog }

enum HttpConversionTarget { curl, fetch, axios, python, go, rust }

class HttpInspectorException implements Exception {
  const HttpInspectorException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HttpField {
  const HttpField(this.name, this.value);
  final String name;
  final String value;

  HttpField redacted({bool cookie = false}) =>
      HttpField(name, cookie || _isProtectedField(this) ? _redacted : value);
}

class HttpRequestDescriptor {
  HttpRequestDescriptor._({
    required this.kind,
    required this.method,
    required this.url,
    Iterable<HttpField> headers = const <HttpField>[],
    Iterable<HttpField> cookies = const <HttpField>[],
    Iterable<HttpField> query = const <HttpField>[],
    this.body,
    this.contentType,
  }) : headers = List<HttpField>.unmodifiable(headers),
       cookies = List<HttpField>.unmodifiable(cookies),
       query = List<HttpField>.unmodifiable(query);

  final HttpSnippetKind kind;
  final String method;
  final Uri url;
  final List<HttpField> headers;
  final List<HttpField> cookies;
  final List<HttpField> query;
  final String? body;
  final String? contentType;

  bool get hasSensitiveLineage {
    final bool sensitiveBody =
        body != null &&
        (contentType == 'application/x-www-form-urlencoded'
            ? _parseQuery(body!).any(_isProtectedField)
            : SensitiveDataPolicy.containsSensitiveArtifact(body!));
    return cookies.isNotEmpty ||
        headers.any(_isProtectedField) ||
        query.any(_isProtectedField) ||
        sensitiveBody;
  }

  HttpRequestDescriptor get redacted {
    final bool protectedBody =
        body != null && SensitiveDataPolicy.containsSensitiveArtifact(body!);
    final String? safeBody = body == null
        ? null
        : contentType == 'application/x-www-form-urlencoded'
        ? _encodeFields(
            _parseQuery(body!).map(
              (HttpField f) =>
                  _isProtectedField(f) ? HttpField(f.name, _redacted) : f,
            ),
          )
        : protectedBody
        ? _redacted
        : body;
    return HttpRequestDescriptor._(
      kind: kind,
      method: method,
      url: url,
      headers: headers
          .where(
            (HttpField f) =>
                f.name.toLowerCase() != 'content-length' &&
                f.name.toLowerCase() != 'transfer-encoding',
          )
          .map(_redactedField),
      cookies: cookies.map((HttpField f) => f.redacted(cookie: true)),
      query: query.map(_redactedField),
      body: safeBody,
      contentType: contentType,
    );
  }

  String get redactedUrl => _fullUrl(redacted);
}

abstract final class HttpRequestInspector {
  static HttpRequestDescriptor parse(String input) {
    if (input.length > _maxBytes || utf8.encode(input).length > _maxBytes) {
      throw const HttpInspectorException('Input exceeds the 64 KiB limit.');
    }
    if (input.contains('\u0000')) {
      throw const HttpInspectorException('NUL bytes are not allowed.');
    }
    if (input.trim().isEmpty) {
      throw const HttpInspectorException('Paste a request to inspect.');
    }
    final String source = input.trimLeft();
    if (RegExp(r'^curl(?:\s|$)', caseSensitive: false).hasMatch(source)) {
      return _parseCurl(source);
    }
    if (RegExp(r'^fetch\s*\(').hasMatch(source)) {
      return _parseFetch(source);
    }
    if (RegExp(r'^axios(?:\.|\s*\()').hasMatch(source)) {
      return _parseAxios(source);
    }
    return _parseRaw(source);
  }

  static String convert(
    HttpRequestDescriptor request,
    HttpConversionTarget target,
  ) {
    final HttpRequestDescriptor safe = request.redacted;
    return switch (target) {
      HttpConversionTarget.curl => _toCurl(safe),
      HttpConversionTarget.fetch => _toFetch(safe),
      HttpConversionTarget.axios => _toAxios(safe),
      HttpConversionTarget.python => _toPython(safe),
      HttpConversionTarget.go => _toGo(safe),
      HttpConversionTarget.rust => _toRust(safe),
    };
  }
}

HttpRequestDescriptor _parseCurl(String input) {
  final List<String> tokens = _shellTokens(input);
  if (tokens.isEmpty || tokens.first.toLowerCase() != 'curl') {
    throw const HttpInspectorException('Expected a cURL command.');
  }
  String method = 'GET';
  String? target;
  final List<HttpField> headers = <HttpField>[];
  final List<String> bodies = <String>[];
  String? cookie;
  var bodySeen = false;

  String takeValue(int index, String option) {
    if (index + 1 >= tokens.length) {
      throw HttpInspectorException('$option needs a value.');
    }
    return tokens[index + 1];
  }

  for (var i = 1; i < tokens.length; i++) {
    final String token = tokens[i];
    if (token == '-X' || token == '--request') {
      method = takeValue(i, token).toUpperCase();
      i++;
    } else if (token.startsWith('--request=')) {
      method = token.substring(10).toUpperCase();
    } else if (token == '-H' || token == '--header') {
      headers.add(_parseHeader(takeValue(i, token)));
      i++;
    } else if (token.startsWith('--header=')) {
      headers.add(_parseHeader(token.substring(9)));
    } else if (token.startsWith('-H') && token.length > 2) {
      headers.add(_parseHeader(token.substring(2)));
    } else if (token == '-b' || token == '--cookie') {
      cookie = takeValue(i, token);
      if (cookie.startsWith('@')) {
        throw const HttpInspectorException('Cookie files are not supported.');
      }
      i++;
    } else if (token == '-d' ||
        token == '--data' ||
        token == '--data-raw' ||
        token == '--data-binary' ||
        token == '--json') {
      final String value = takeValue(i, token);
      if (value.startsWith('@')) {
        throw const HttpInspectorException(
          'File-backed request bodies are not supported.',
        );
      }
      bodies.add(value);
      bodySeen = true;
      if (token == '--json' &&
          !headers.any(
            (HttpField f) => f.name.toLowerCase() == 'content-type',
          )) {
        headers.add(const HttpField('Content-Type', 'application/json'));
      }
      i++;
    } else if (token.startsWith('--data=') ||
        token.startsWith('--data-raw=') ||
        token.startsWith('--data-binary=') ||
        token.startsWith('--json=')) {
      final String value = token.substring(token.indexOf('=') + 1);
      if (value.startsWith('@')) {
        throw const HttpInspectorException(
          'File-backed request bodies are not supported.',
        );
      }
      bodies.add(value);
      bodySeen = true;
      if (token.startsWith('--json=') &&
          !headers.any(
            (HttpField f) => f.name.toLowerCase() == 'content-type',
          )) {
        headers.add(const HttpField('Content-Type', 'application/json'));
      }
    } else if (token == '--url') {
      target = takeValue(i, token);
      i++;
    } else if (token.startsWith('--url=')) {
      target = token.substring(6);
    } else if (token == '--compressed' ||
        token == '-s' ||
        token == '--silent' ||
        token == '-S' ||
        token == '--show-error' ||
        token == '-L' ||
        token == '--location') {
      continue;
    } else if (token.startsWith('-')) {
      throw HttpInspectorException(
        'Unsupported cURL option: ${_optionName(token)}.',
      );
    } else if (target == null) {
      target = token;
    } else {
      throw const HttpInspectorException('cURL has more than one URL.');
    }
  }
  if (bodySeen && method == 'GET') method = 'POST';
  if (cookie != null) headers.add(HttpField('Cookie', cookie));
  return _build(
    kind: HttpSnippetKind.curl,
    method: method,
    target: target,
    headers: headers,
    body: bodies.isEmpty ? null : bodies.join('&'),
  );
}

HttpRequestDescriptor _parseRaw(String input) {
  if (input.contains('\u0000')) {
    throw const HttpInspectorException('NUL bytes are not allowed.');
  }
  if (input.contains('\r\n') &&
      input.replaceAll('\r\n', '').contains(RegExp(r'[\r\n]'))) {
    throw const HttpInspectorException(
      'Mixed HTTP line endings are not allowed.',
    );
  }
  final String normalized = input.replaceAll('\r\n', '\n');
  final int split = normalized.indexOf('\n\n');
  final String head = split < 0 ? normalized : normalized.substring(0, split);
  final String? body = split < 0 ? null : normalized.substring(split + 2);
  final List<String> lines = head.split('\n');
  final RegExp requestLine = RegExp(
    r'^(?:\[[^\]]{0,200}\]\s*)?(GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS|CONNECT|TRACE)\s+(\S+?)(?:\s+HTTP/\d(?:\.\d)?)?$',
    caseSensitive: false,
  );
  final RegExpMatch? first = requestLine.firstMatch(lines.first.trim());
  if (first == null) {
    throw const HttpInspectorException(
      'Expected cURL, Fetch, Axios, or an HTTP request line.',
    );
  }
  final String method = first.group(1)!.toUpperCase();
  final String requestTarget = first.group(2)!;
  if (method == 'CONNECT' || requestTarget == '*') {
    throw const HttpInspectorException(
      'CONNECT and asterisk request targets are not supported.',
    );
  }
  final List<HttpField> headers = <HttpField>[];
  for (final String line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    if (line.startsWith(' ') || line.startsWith('\t')) {
      throw const HttpInspectorException(
        'Folded HTTP headers are not supported.',
      );
    }
    headers.add(_parseHeader(line));
  }
  String target = requestTarget;
  if (!target.startsWith('http://') && !target.startsWith('https://')) {
    final List<HttpField> hosts = headers
        .where((HttpField f) => f.name.toLowerCase() == 'host')
        .toList();
    if (hosts.length != 1) {
      throw const HttpInspectorException(
        'A relative request target needs exactly one Host header.',
      );
    }
    target =
        'https://${hosts.single.value}${target.startsWith('/') ? '' : '/'}$target';
  }
  return _build(
    kind: lines.length == 1
        ? HttpSnippetKind.requestLog
        : HttpSnippetKind.rawHttp,
    method: method,
    target: target,
    headers: headers,
    body: body,
  );
}

HttpRequestDescriptor _parseFetch(String input) {
  final _JsParser parser = _JsParser(input);
  parser.word('fetch');
  parser.char('(');
  final String target = parser.string();
  String method = 'GET';
  List<HttpField> headers = const <HttpField>[];
  String? body;
  if (parser.optional(',')) {
    final Map<String, Object?> config = parser.object();
    _requireJsKeys(config, const <String>{
      'method',
      'headers',
      'body',
    }, 'Fetch');
    method = _optionalJsString(config, 'method')?.toUpperCase() ?? method;
    headers = _jsHeaders(config['headers']);
    body = _jsBody(config['body']);
  }
  parser.char(')');
  parser.optional(';');
  parser.end();
  return _build(
    kind: HttpSnippetKind.fetch,
    method: method,
    target: target,
    headers: headers,
    body: body,
  );
}

HttpRequestDescriptor _parseAxios(String input) {
  final _JsParser parser = _JsParser(input);
  parser.word('axios');
  String method = 'GET';
  String? target;
  List<HttpField> headers = const <HttpField>[];
  String? body;
  if (parser.optional('.')) {
    method = parser.identifier().toUpperCase();
    if (!const <String>{
      'GET',
      'HEAD',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
    }.contains(method)) {
      throw const HttpInspectorException('Unsupported Axios method.');
    }
    parser.char('(');
    target = parser.string();
    if (parser.optional(',')) {
      if (const <String>{'POST', 'PUT', 'PATCH'}.contains(method)) {
        body = _jsBody(parser.value());
        if (parser.optional(',')) {
          final Map<String, Object?> config = parser.object();
          _requireJsKeys(config, const <String>{'headers'}, 'Axios');
          headers = _jsHeaders(config['headers']);
        }
      } else {
        final Map<String, Object?> config = parser.object();
        _requireJsKeys(config, const <String>{'headers'}, 'Axios');
        headers = _jsHeaders(config['headers']);
      }
    }
    parser.char(')');
  } else {
    parser.char('(');
    final Map<String, Object?> config = parser.object();
    _requireJsKeys(config, const <String>{
      'url',
      'method',
      'headers',
      'data',
    }, 'Axios');
    parser.char(')');
    target = _optionalJsString(config, 'url');
    method = _optionalJsString(config, 'method')?.toUpperCase() ?? method;
    headers = _jsHeaders(config['headers']);
    body = _jsBody(config['data']);
  }
  parser.optional(';');
  parser.end();
  return _build(
    kind: HttpSnippetKind.axios,
    method: method,
    target: target,
    headers: headers,
    body: body,
  );
}

void _requireJsKeys(
  Map<String, Object?> config,
  Set<String> supported,
  String label,
) {
  if (config.keys.any((String key) => !supported.contains(key))) {
    throw HttpInspectorException('$label option is not supported.');
  }
}

HttpRequestDescriptor _build({
  required HttpSnippetKind kind,
  required String method,
  required String? target,
  required List<HttpField> headers,
  required String? body,
}) {
  if (!RegExp(r'^[A-Z]{1,16}$').hasMatch(method)) {
    throw const HttpInspectorException('HTTP method must be a static token.');
  }
  if (target == null) {
    throw const HttpInspectorException('Request URL is missing.');
  }
  if (target.length > _maxUrlLength) {
    throw const HttpInspectorException('URL exceeds the 8 KiB limit.');
  }
  if (target.contains(RegExp(r'[\r\n\u0000]'))) {
    throw const HttpInspectorException('URL contains a control character.');
  }
  final Uri parsed;
  try {
    parsed = Uri.parse(target);
  } on FormatException {
    throw const HttpInspectorException('Request URL is malformed.');
  }
  if ((parsed.scheme != 'http' && parsed.scheme != 'https') ||
      parsed.host.isEmpty) {
    throw const HttpInspectorException('URL must be absolute HTTP or HTTPS.');
  }
  if (parsed.userInfo.isNotEmpty) {
    throw const HttpInspectorException(
      'Credentials in URL userinfo are not supported.',
    );
  }
  if (parsed.hasFragment) {
    throw const HttpInspectorException(
      'URL fragments are not sent in HTTP requests.',
    );
  }
  if (headers.length > _maxFields) {
    throw const HttpInspectorException('Request exceeds the 100-header limit.');
  }
  final List<HttpField> validatedHeaders = headers
      .map(_validateHeader)
      .toList();
  _validateFraming(validatedHeaders, body);
  if (body != null && utf8.encode(body).length > _maxBytes) {
    throw const HttpInspectorException(
      'Request body exceeds the 64 KiB limit.',
    );
  }
  final List<HttpField> cookies = <HttpField>[];
  final List<HttpField> ordinary = <HttpField>[];
  for (final HttpField header in validatedHeaders) {
    if (header.name.toLowerCase() == 'cookie') {
      cookies.addAll(_parseCookies(header.value));
    } else {
      ordinary.add(header);
    }
  }
  if (cookies.length > _maxFields) {
    throw const HttpInspectorException('Request exceeds the 100-cookie limit.');
  }
  final List<HttpField> hosts = ordinary
      .where((HttpField f) => f.name.toLowerCase() == 'host')
      .toList();
  if (hosts.length > 1) {
    throw const HttpInspectorException(
      'Duplicate Host headers are not allowed.',
    );
  }
  if (hosts.isNotEmpty &&
      hosts.single.value.toLowerCase() != parsed.authority.toLowerCase()) {
    throw const HttpInspectorException(
      'Host header does not match the request URL.',
    );
  }
  final List<HttpField> query = _parseQuery(parsed.query);
  final String? contentType = ordinary
      .where((HttpField f) => f.name.toLowerCase() == 'content-type')
      .map((HttpField f) => f.value.split(';').first.trim().toLowerCase())
      .firstOrNull;
  if (body != null && contentType == 'application/x-www-form-urlencoded') {
    _parseQuery(body);
  }
  return HttpRequestDescriptor._(
    kind: kind,
    method: method,
    url: Uri.parse(parsed.toString().split('?').first),
    headers: ordinary,
    cookies: cookies,
    query: query,
    body: body,
    contentType: contentType,
  );
}

HttpField _parseHeader(String line) {
  if (line.length > _maxTokenLength) {
    throw const HttpInspectorException('Header line exceeds the 8 KiB limit.');
  }
  if (line.contains(RegExp(r'[\r\n\u0000]'))) {
    throw const HttpInspectorException('Header contains a control character.');
  }
  final int colon = line.indexOf(':');
  if (colon <= 0) {
    throw const HttpInspectorException('Header must use Name: value syntax.');
  }
  final String rawName = line.substring(0, colon);
  if (rawName != rawName.trim()) {
    throw const HttpInspectorException(
      'Whitespace before a header colon is not allowed.',
    );
  }
  final String name = rawName;
  final String value = line.substring(colon + 1).trim();
  return _validateHeader(HttpField(name, value));
}

HttpField _validateHeader(HttpField field) {
  final String name = field.name;
  final String value = field.value;
  if (name.length + value.length + 1 > _maxTokenLength) {
    throw const HttpInspectorException('Header line exceeds the 8 KiB limit.');
  }
  if (name != name.trim() || name.contains(':')) {
    throw const HttpInspectorException(
      'Header name contains invalid characters.',
    );
  }
  if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(name)) {
    throw const HttpInspectorException(
      'Header name contains invalid characters.',
    );
  }
  if (value.contains(RegExp(r'[\x00-\x08\x0A-\x1F\x7F]'))) {
    throw const HttpInspectorException(
      'Header value contains a control character.',
    );
  }
  return field;
}

void _validateFraming(List<HttpField> headers, String? body) {
  final List<String> lengths = headers
      .where((HttpField f) => f.name.toLowerCase() == 'content-length')
      .map((HttpField f) => f.value)
      .toList();
  final bool transferEncoding = headers.any(
    (HttpField f) => f.name.toLowerCase() == 'transfer-encoding',
  );
  if (transferEncoding && lengths.isNotEmpty) {
    throw const HttpInspectorException(
      'Transfer-Encoding with Content-Length is ambiguous.',
    );
  }
  if (transferEncoding) {
    throw const HttpInspectorException(
      'Transfer-Encoding bodies are not supported.',
    );
  }
  if (lengths.length > 1) {
    throw const HttpInspectorException(
      'Duplicate Content-Length headers are not allowed.',
    );
  }
  if (lengths.isNotEmpty) {
    final int? expected = int.tryParse(lengths.single);
    if (expected == null || expected < 0) {
      throw const HttpInspectorException(
        'Content-Length must be a non-negative integer.',
      );
    }
    if (expected != utf8.encode(body ?? '').length) {
      throw const HttpInspectorException(
        'Content-Length does not match the request body.',
      );
    }
  }
}

List<HttpField> _parseCookies(String value) {
  final List<HttpField> result = <HttpField>[];
  for (final String part in value.split(';')) {
    final int equals = part.indexOf('=');
    if (equals <= 0) {
      throw const HttpInspectorException('Cookie must use name=value syntax.');
    }
    result.add(
      HttpField(
        part.substring(0, equals).trim(),
        part.substring(equals + 1).trim(),
      ),
    );
  }
  return result;
}

List<HttpField> _parseQuery(String query) {
  if (query.isEmpty) return const <HttpField>[];
  final List<HttpField> result = <HttpField>[];
  for (final String part in query.split('&')) {
    final int equals = part.indexOf('=');
    try {
      result.add(
        HttpField(
          Uri.decodeQueryComponent(
            equals < 0 ? part : part.substring(0, equals),
          ),
          equals < 0
              ? ''
              : Uri.decodeQueryComponent(part.substring(equals + 1)),
        ),
      );
    } on FormatException {
      throw const HttpInspectorException('URL query encoding is malformed.');
    } on ArgumentError {
      throw const HttpInspectorException('URL query encoding is malformed.');
    }
  }
  if (result.length > _maxFields) {
    throw const HttpInspectorException('URL exceeds the 100-query-item limit.');
  }
  return result;
}

List<String> _shellTokens(String input) {
  final List<String> tokens = <String>[];
  final StringBuffer current = StringBuffer();
  String? quote;
  var tokenStarted = false;
  for (var i = 0; i < input.length; i++) {
    final String char = input[i];
    if (quote == null &&
        char == '\\' &&
        i + 1 < input.length &&
        input[i + 1] == '\n') {
      i++;
      continue;
    }
    if (quote == null && (char == ' ' || char == '\t' || char == '\n')) {
      if (tokenStarted) {
        tokens.add(current.toString());
        current.clear();
        tokenStarted = false;
        if (tokens.length > _maxTokens) {
          throw const HttpInspectorException(
            'cURL exceeds the 256-token limit.',
          );
        }
      }
      continue;
    }
    if (char == "'" || char == '"') {
      if (quote == null) {
        quote = char;
        tokenStarted = true;
        continue;
      }
      if (quote == char) {
        quote = null;
        continue;
      }
    }
    if (char == '\\' && quote != "'") {
      if (i + 1 >= input.length) {
        throw const HttpInspectorException(
          'cURL ends with an incomplete escape.',
        );
      }
      final String escaped = input[++i];
      if (quote == '"' && !r'$`"\'.contains(escaped)) {
        current
          ..write('\\')
          ..write(escaped);
      } else {
        if (escaped == r'$' || escaped == '`') {
          throw const HttpInspectorException(
            'Shell expansion and command substitution are not supported.',
          );
        }
        current.write(escaped);
      }
      tokenStarted = true;
      continue;
    }
    if (char == r'$' ||
        char == '`' ||
        (quote == null &&
            (char == '*' || char == '?' || char == '[' || char == ']')) ||
        (quote == null && char == '~' && !tokenStarted) ||
        (quote == null && ';|&<>()#'.contains(char))) {
      throw const HttpInspectorException(
        'Shell expansion and command substitution are not supported.',
      );
    }
    current.write(char);
    tokenStarted = true;
    if (current.length > _maxTokenLength) {
      throw const HttpInspectorException('cURL token exceeds the 8 KiB limit.');
    }
  }
  if (quote != null) {
    throw const HttpInspectorException('cURL contains an unclosed quote.');
  }
  if (tokenStarted) tokens.add(current.toString());
  return tokens;
}

String _optionName(String token) {
  final String option = token.split('=').first;
  return option.substring(0, option.length.clamp(0, 40));
}

bool _isProtectedName(String name) {
  final String normalized = name.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]'),
    '',
  );
  return normalized == 'authorization' ||
      normalized == 'proxyauthorization' ||
      normalized == 'cookie' ||
      normalized == 'auth' ||
      normalized.endsWith('auth') ||
      normalized.contains('apikey') ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('signature') ||
      normalized.endsWith('sig') ||
      normalized.contains('session') ||
      normalized.contains('password') ||
      normalized.contains('credential');
}

bool _isProtectedField(HttpField field) =>
    _isProtectedName(field.name) ||
    SensitiveDataPolicy.containsSensitiveArtifact(field.value);

HttpField _redactedField(HttpField field) =>
    _isProtectedField(field) ? HttpField(field.name, _redacted) : field;

String _fullUrl(HttpRequestDescriptor request) {
  if (request.query.isEmpty) return request.url.toString();
  final String query = _encodeFields(request.query);
  return request.url.replace(query: query).toString();
}

String _encodeFields(Iterable<HttpField> fields) => fields
    .map(
      (HttpField f) =>
          '${Uri.encodeQueryComponent(f.name)}=${Uri.encodeQueryComponent(f.value)}',
    )
    .join('&');

String _cookieHeader(HttpRequestDescriptor request) =>
    request.cookies.map((HttpField f) => '${f.name}=${f.value}').join('; ');

List<HttpField> _allHeaders(HttpRequestDescriptor request) => <HttpField>[
  ...request.headers,
  if (request.cookies.isNotEmpty) HttpField('Cookie', _cookieHeader(request)),
];

void _requireUniqueHeaders(HttpRequestDescriptor request, String target) {
  final Set<String> names = <String>{};
  for (final HttpField header in _allHeaders(request)) {
    if (!names.add(header.name.toLowerCase())) {
      throw HttpInspectorException(
        '$target cannot preserve duplicate headers safely.',
      );
    }
  }
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

String _toCurl(HttpRequestDescriptor request) {
  final List<String> parts = <String>['curl', '-X', request.method];
  for (final HttpField header in _allHeaders(request)) {
    parts.addAll(<String>[
      '-H',
      _shellQuote('${header.name}: ${header.value}'),
    ]);
  }
  if (request.body != null) {
    parts.addAll(<String>['--data-raw', _shellQuote(request.body!)]);
  }
  parts.add(_shellQuote(_fullUrl(request)));
  return parts.join(' ');
}

String _toFetch(HttpRequestDescriptor request) {
  final Map<String, Object?> options = <String, Object?>{
    'method': request.method,
    if (_allHeaders(request).isNotEmpty)
      'headers': _allHeaders(
        request,
      ).map((HttpField f) => <String>[f.name, f.value]).toList(),
    if (request.body != null) 'body': request.body,
  };
  return 'fetch(${jsonEncode(_fullUrl(request))}, ${jsonEncode(options)});';
}

String _toAxios(HttpRequestDescriptor request) {
  _requireUniqueHeaders(request, 'Axios');
  return 'axios(${jsonEncode(<String, Object?>{
    'method': request.method,
    'url': _fullUrl(request),
    if (_allHeaders(request).isNotEmpty) 'headers': <String, String>{for (final HttpField f in _allHeaders(request)) f.name: f.value},
    if (request.body != null) 'data': request.body,
  })});';
}

String _toPython(HttpRequestDescriptor request) {
  _requireUniqueHeaders(request, 'Python');
  final String headers = jsonEncode(<String, String>{
    for (final HttpField f in _allHeaders(request)) f.name: f.value,
  });
  return "requests.request(${jsonEncode(request.method)}, ${jsonEncode(_fullUrl(request))}, headers=$headers${request.body == null ? '' : ', data=${jsonEncode(request.body)}'})";
}

String _toGo(HttpRequestDescriptor request) {
  final StringBuffer out = StringBuffer()
    ..writeln(
      'req, err := http.NewRequest(${jsonEncode(request.method)}, ${jsonEncode(_fullUrl(request))}, ${request.body == null ? 'nil' : 'strings.NewReader(${jsonEncode(request.body)})'})',
    )
    ..writeln('if err != nil { return err }');
  for (final HttpField header in _allHeaders(request)) {
    out.writeln(
      'req.Header.Add(${jsonEncode(header.name)}, ${jsonEncode(header.value)})',
    );
  }
  out.write('resp, err := http.DefaultClient.Do(req)');
  return out.toString();
}

String _toRust(HttpRequestDescriptor request) {
  final StringBuffer out = StringBuffer(
    'let request = client.request(reqwest::Method::from_bytes(b"${request.method}")?, ${_rustString(_fullUrl(request))})',
  );
  for (final HttpField header in _allHeaders(request)) {
    out.write(
      '\n    .header(${_rustString(header.name)}, ${_rustString(header.value)})',
    );
  }
  if (request.body != null) {
    out.write('\n    .body(${_rustString(request.body!)})');
  }
  out.write('\n    .send().await?;');
  return out.toString();
}

List<HttpField> _jsHeaders(Object? value) {
  if (value == null) return const <HttpField>[];
  if (value is Map<String, Object?>) {
    return <HttpField>[
      for (final MapEntry<String, Object?> e in value.entries)
        if (e.value is String)
          HttpField(e.key, e.value! as String)
        else
          throw const HttpInspectorException(
            'Header values must be static strings.',
          ),
    ];
  }
  if (value is List<Object?>) {
    final List<HttpField> fields = <HttpField>[];
    for (final Object? item in value) {
      if (item is! List<Object?> ||
          item.length != 2 ||
          item[0] is! String ||
          item[1] is! String) {
        throw const HttpInspectorException(
          'Headers array must contain [name, value] pairs.',
        );
      }
      fields.add(HttpField(item[0]! as String, item[1]! as String));
    }
    return fields;
  }
  throw const HttpInspectorException(
    'Headers must be a static object or pair array.',
  );
}

String? _jsBody(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map<String, Object?> || value is List<Object?>) {
    return jsonEncode(value);
  }
  throw const HttpInspectorException(
    'Request body must be a static string, object, or array.',
  );
}

String? _optionalJsString(Map<String, Object?> object, String key) {
  final Object? value = object[key];
  if (value == null) return null;
  if (value is String) return value;
  throw HttpInspectorException('$key must be a static string.');
}

String _rustString(String value) {
  final StringBuffer out = StringBuffer('"');
  for (final int rune in value.runes) {
    switch (rune) {
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (rune < 0x20 || rune == 0x7f) {
          out.write('\\u{${rune.toRadixString(16).padLeft(4, '0')}}');
        } else {
          out.writeCharCode(rune);
        }
    }
  }
  out.write('"');
  return out.toString();
}

class _JsParser {
  _JsParser(this.source);
  final String source;
  int index = 0;
  int depth = 0;
  int nodes = 0;

  void _space() {
    while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
      index++;
    }
  }

  void word(String expected) {
    _space();
    if (!source.startsWith(expected, index)) {
      throw HttpInspectorException('Expected $expected.');
    }
    index += expected.length;
  }

  bool optional(String expected) {
    _space();
    if (!source.startsWith(expected, index)) return false;
    index += expected.length;
    return true;
  }

  void char(String expected) {
    if (!optional(expected)) {
      throw HttpInspectorException('Expected $expected.');
    }
  }

  String identifier() {
    _space();
    final RegExpMatch? match = RegExp(
      r'^[A-Za-z_$][A-Za-z0-9_$]*',
    ).firstMatch(source.substring(index));
    if (match == null) {
      throw const HttpInspectorException('Expected a static property name.');
    }
    index += match.group(0)!.length;
    return match.group(0)!;
  }

  String string() {
    _space();
    if (index >= source.length ||
        (source[index] != '"' && source[index] != "'")) {
      throw const HttpInspectorException(
        'Dynamic JavaScript values are not supported.',
      );
    }
    final String quote = source[index++];
    final StringBuffer out = StringBuffer();
    while (index < source.length) {
      final String char = source[index++];
      if (char == quote) return out.toString();
      if (char == '\n' || char == '\r') {
        throw const HttpInspectorException(
          'JavaScript string contains a newline.',
        );
      }
      if (char == '\\') {
        if (index >= source.length) {
          throw const HttpInspectorException(
            'JavaScript string ends with an escape.',
          );
        }
        final String escaped = source[index++];
        if (escaped == 'u') {
          if (index + 4 > source.length) {
            throw const HttpInspectorException(
              'JavaScript Unicode escape is incomplete.',
            );
          }
          final String hex = source.substring(index, index + 4);
          final int? code = int.tryParse(hex, radix: 16);
          if (code == null) {
            throw const HttpInspectorException(
              'JavaScript Unicode escape is malformed.',
            );
          }
          out.writeCharCode(code);
          index += 4;
          continue;
        }
        out.write(switch (escaped) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          'b' => '\b',
          'f' => '\f',
          '\\' => '\\',
          '"' => '"',
          "'" => "'",
          _ => throw const HttpInspectorException(
            'Unsupported JavaScript escape.',
          ),
        });
      } else {
        out.write(char);
      }
      if (out.length > _maxTokenLength) {
        throw const HttpInspectorException(
          'JavaScript string exceeds the 8 KiB limit.',
        );
      }
    }
    throw const HttpInspectorException(
      'JavaScript contains an unclosed string.',
    );
  }

  Object? value() {
    _space();
    if (++nodes > _maxTokens) {
      throw const HttpInspectorException('JavaScript exceeds 256 values.');
    }
    if (source.startsWith('JSON.stringify', index)) {
      word('JSON.stringify');
      char('(');
      final Object? result = value();
      char(')');
      return result;
    }
    if (index < source.length &&
        (source[index] == '"' || source[index] == "'")) {
      return string();
    }
    if (index < source.length && source[index] == '{') return object();
    if (index < source.length && source[index] == '[') return array();
    for (final MapEntry<String, Object?> literal in const <String, Object?>{
      'true': true,
      'false': false,
      'null': null,
    }.entries) {
      if (source.startsWith(literal.key, index)) {
        index += literal.key.length;
        return literal.value;
      }
    }
    final RegExpMatch? number = RegExp(
      r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?',
    ).firstMatch(source.substring(index));
    if (number != null) {
      final String token = number.group(0)!;
      if (token.length > _maxTokenLength) {
        throw const HttpInspectorException(
          'JavaScript number exceeds the 8 KiB limit.',
        );
      }
      final num parsed;
      try {
        parsed = num.parse(token);
      } on FormatException {
        throw const HttpInspectorException(
          'JavaScript number is outside the supported range.',
        );
      }
      if (!parsed.isFinite) {
        throw const HttpInspectorException('JavaScript number must be finite.');
      }
      index += token.length;
      return parsed;
    }
    throw const HttpInspectorException(
      'Dynamic JavaScript values are not supported.',
    );
  }

  Map<String, Object?> object() {
    if (++depth > _maxDepth) {
      throw const HttpInspectorException(
        'JavaScript nesting exceeds 12 levels.',
      );
    }
    char('{');
    final Map<String, Object?> result = <String, Object?>{};
    if (!optional('}')) {
      while (true) {
        _space();
        final String key =
            index < source.length &&
                (source[index] == '"' || source[index] == "'")
            ? string()
            : identifier();
        char(':');
        if (result.containsKey(key)) {
          throw const HttpInspectorException(
            'Duplicate JavaScript object keys are not supported.',
          );
        }
        result[key] = value();
        if (result.length > _maxFields) {
          throw const HttpInspectorException(
            'JavaScript object exceeds 100 items.',
          );
        }
        if (optional('}')) break;
        char(',');
      }
    }
    depth--;
    return result;
  }

  List<Object?> array() {
    if (++depth > _maxDepth) {
      throw const HttpInspectorException(
        'JavaScript nesting exceeds 12 levels.',
      );
    }
    char('[');
    final List<Object?> result = <Object?>[];
    if (!optional(']')) {
      while (true) {
        result.add(value());
        if (result.length > _maxFields) {
          throw const HttpInspectorException(
            'JavaScript array exceeds 100 items.',
          );
        }
        if (optional(']')) break;
        char(',');
      }
    }
    depth--;
    return result;
  }

  void end() {
    _space();
    if (index != source.length) {
      throw const HttpInspectorException(
        'Only one static request expression is supported.',
      );
    }
  }
}
