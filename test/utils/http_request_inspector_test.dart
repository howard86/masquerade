import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/http_request_inspector.dart';

void main() {
  group('HTTP request inspector', () {
    test('parses cURL into ordered immutable request data', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl -X POST -H 'X-Trace: one' -H 'X-Trace: two' "
        "-H 'Content-Type: application/json' --data-raw '{\"ok\":true}' "
        "'https://example.com/items?a=1&a=2'",
      );

      expect(request.kind, HttpSnippetKind.curl);
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.com/items');
      expect(
        request.query.map((HttpField f) => '${f.name}=${f.value}'),
        <String>['a=1', 'a=2'],
      );
      expect(
        request.headers
            .where((HttpField f) => f.name == 'X-Trace')
            .map((HttpField f) => f.value),
        <String>['one', 'two'],
      );
      expect(request.body, '{"ok":true}');
      expect(request.contentType, 'application/json');
      expect(
        () => request.headers.add(const HttpField('X', 'y')),
        throwsUnsupportedError,
      );
    });

    test('parses raw HTTP, static Fetch, Axios, and request logs', () {
      final HttpRequestDescriptor raw = HttpRequestInspector.parse(
        'PUT /v1/items?id=7 HTTP/1.1\r\nHost: api.example.com\r\nX-Test: yes\r\n\r\nhello',
      );
      expect(raw.method, 'PUT');
      expect(raw.redactedUrl, 'https://api.example.com/v1/items?id=7');
      expect(raw.body, 'hello');
      final HttpRequestDescriptor spaced = HttpRequestInspector.parse(
        'POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 4\r\n\r\na   ',
      );
      expect(spaced.body, 'a   ');

      final HttpRequestDescriptor fetch = HttpRequestInspector.parse(
        "fetch('https://example.com/a', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({nested: {ok: true}})});",
      );
      expect(fetch.kind, HttpSnippetKind.fetch);
      expect(fetch.body, '{"nested":{"ok":true}}');
      expect(
        HttpRequestInspector.parse(
          "fetch('https://example.com', {body: JSON.stringify({x: 1e-7})})",
        ).body,
        '{"x":1e-7}',
      );

      final HttpRequestDescriptor axios = HttpRequestInspector.parse(
        "axios.post('https://example.com/a', {ok: true}, {headers: {'X-Test': 'yes'}});",
      );
      expect(axios.kind, HttpSnippetKind.axios);
      expect(axios.body, '{"ok":true}');

      final HttpRequestDescriptor log = HttpRequestInspector.parse(
        '[2026-07-18] GET https://example.com/health',
      );
      expect(log.kind, HttpSnippetKind.requestLog);
    });

    test('all converters consume the recursively redacted request', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl -H 'Authorization: Bearer top-secret' "
        "-H 'Cookie: sid=cookie-secret; theme=dark' "
        "--data-raw '{\"api_key\":\"body-secret\"}' "
        "'https://example.com/a?token=query-secret&safe=yes'",
      );

      expect(request.hasSensitiveLineage, isTrue);
      expect(request.url.toString(), 'https://example.com/a');
      expect(
        request.redactedUrl,
        'https://example.com/a?token=%5BREDACTED%5D&safe=yes',
      );
      for (final HttpConversionTarget target in HttpConversionTarget.values) {
        final String output = HttpRequestInspector.convert(request, target);
        expect(output, isNot(contains('top-secret')), reason: target.name);
        expect(output, isNot(contains('cookie-secret')), reason: target.name);
        expect(output, isNot(contains('query-secret')), reason: target.name);
        expect(output, isNot(contains('body-secret')), reason: target.name);
        expect(output, contains('[REDACTED]'), reason: target.name);
      }
    });

    test('safe cURL and generated Fetch round-trip semantically', () {
      final HttpRequestDescriptor original = HttpRequestInspector.parse(
        "curl -X PATCH -H 'Content-Type: application/json' "
        "--data-raw '{\"enabled\":true}' 'https://example.com/v1?a=1&a=2'",
      );
      final HttpRequestDescriptor curl = HttpRequestInspector.parse(
        HttpRequestInspector.convert(original, HttpConversionTarget.curl),
      );
      final HttpRequestDescriptor fetch = HttpRequestInspector.parse(
        HttpRequestInspector.convert(original, HttpConversionTarget.fetch),
      );
      for (final HttpRequestDescriptor reparsed in <HttpRequestDescriptor>[
        curl,
        fetch,
      ]) {
        expect(reparsed.method, original.method);
        expect(reparsed.redactedUrl, original.redactedUrl);
        expect(reparsed.body, original.body);
        expect(reparsed.contentType, original.contentType);
      }
    });

    test('rejects dynamic code, files, injection, ambiguity, and bounds', () {
      final List<String> unsafe = <String>[
        r'curl "https://example.com/$TOKEN"',
        "curl 'https://example.com' --data-raw 'bad\u0000body'",
        r'curl "https://example.com/$(whoami)"',
        "curl 'https://example.com' | sh",
        "curl --data @secret.txt 'https://example.com'",
        "curl --unsupported-option=secret 'https://example.com'",
        "fetch(url, {method: 'GET'})",
        r'''fetch('https://example.com', {headers: {'X-Test': 'ok\r\nInjected: yes'}})''',
        "fetch('https://example.com', {headers: {'Bad Name': 'value'}})",
        "fetch('https://example.com', {headers: {'X: Authorization': 'Bearer raw-secret'}})",
        "fetch('https://example.com', {headers: {' X-Test': 'value'}})",
        "fetch('https://example.com', {method: {dynamic: true}})",
        "fetch('https://example.com', {credentials: 'include'})",
        "fetch('https://example.com', {body: JSON.stringify({x: 1e999})})",
        "fetch('https://example.com', {body: JSON.stringify({x: ${'9' * 8193}})})",
        "curl -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'a=%ZZ' 'https://example.com'",
        "axios.get(getUrl())",
        "axios.get('https://example.com', {params: {page: 1}})",
        "axios({url: 'https://example.com', timeout: 1000})",
        'CONNECT example.com:443 HTTP/1.1',
        'OPTIONS * HTTP/1.1\r\nHost: example.com\r\n\r\n',
        'GET / HTTP/1.1\r\nHost: example.com\r\nX-Test: ok\nInjected: yes',
        'POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nContent-Length: 0\r\n\r\n',
        'POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 0\r\nContent-Length: 1\r\n\r\n',
        'GET / HTTP/1.1\r\nHost: example.com\r\nHost: other.example.com\r\n\r\n',
        'GET / HTTP/1.1\r\nHost : example.com\r\n\r\n',
        'GET https://user:pass@example.com/ HTTP/1.1',
        'GET https://example.com/#secret HTTP/1.1',
        'GET https://example.com/${'a' * 65537} HTTP/1.1',
      ];
      for (final String input in unsafe) {
        expect(
          () => HttpRequestInspector.parse(input),
          throwsA(isA<HttpInspectorException>()),
          reason: input.substring(0, input.length.clamp(0, 80)),
        );
      }
      final String tooManyForm = List<String>.generate(
        101,
        (int index) => 'k$index=v',
      ).join('&');
      expect(
        () => HttpRequestInspector.parse(
          "curl -H 'Content-Type: application/x-www-form-urlencoded' "
          "--data-raw '$tooManyForm' 'https://example.com'",
        ),
        throwsA(isA<HttpInspectorException>()),
      );
    });

    test('redacts signature and session fields and handles equals JSON', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl --json='{\"ok\":true}' -H 'X-Amz-Signature: raw-signature' "
        "'https://example.com?a=1&session_id=raw-session'",
      );
      expect(request.contentType, 'application/json');
      final String output = HttpRequestInspector.convert(
        request,
        HttpConversionTarget.curl,
      );
      expect(output, isNot(contains('raw-signature')));
      expect(output, isNot(contains('raw-session')));
    });

    test('redacts sensitive artifacts under benign header and query names', () {
      const String token = 'eyJx.eyJy.signature';
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl -H 'X-Data: $token' 'https://example.com?note=$token'",
      );
      expect(request.hasSensitiveLineage, isTrue);
      expect(request.redactedUrl, contains('note=%5BREDACTED%5D'));
      for (final HttpConversionTarget target in HttpConversionTarget.values) {
        expect(
          HttpRequestInspector.convert(request, target),
          isNot(contains(token)),
          reason: target.name,
        );
      }
    });

    test('form bodies preserve order while redacting protected fields', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl -H 'Content-Type: application/x-www-form-urlencoded' "
        "--data-raw 'user=a&api_key=raw-secret&user=b' 'https://example.com'",
      );
      expect(request.hasSensitiveLineage, isTrue);
      expect(request.redacted.body, 'user=a&api_key=%5BREDACTED%5D&user=b');
      for (final HttpConversionTarget target in HttpConversionTarget.values) {
        expect(
          HttpRequestInspector.convert(request, target),
          isNot(contains('raw-secret')),
        );
      }
      final HttpRequestDescriptor nested = HttpRequestInspector.parse(
        "curl -H 'Content-Type: application/x-www-form-urlencoded' "
        "--data-raw 'note=eyJx.eyJy.signature&safe=yes' 'https://example.com'",
      );
      expect(nested.hasSensitiveLineage, isTrue);
      expect(nested.redacted.body, 'note=%5BREDACTED%5D&safe=yes');

      final HttpRequestDescriptor benign = HttpRequestInspector.parse(
        "curl -H 'Content-Type: application/x-www-form-urlencoded' "
        "--data-raw 'a=1&a=2' 'https://example.com'",
      );
      expect(benign.hasSensitiveLineage, isFalse);
      expect(benign.redacted.body, 'a=1&a=2');
    });

    test('Rust conversion emits valid control-character escapes', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "fetch('https://example.com', {method: 'POST', body: '\\b\\f'})",
      );
      final String rust = HttpRequestInspector.convert(
        request,
        HttpConversionTarget.rust,
      );
      expect(rust, contains(r'\u{0008}\u{000c}'));
      expect(rust, isNot(contains(r'\b\f')));

      final HttpRequestDescriptor literal = HttpRequestInspector.parse(
        r"fetch('https://example.com', {body: '\\b\\u001f'})",
      );
      final String literalRust = HttpRequestInspector.convert(
        literal,
        HttpConversionTarget.rust,
      );
      expect(literalRust, contains(r'\\b\\u001f'));
      expect(literalRust, isNot(contains(r'\u{0008}')));

      final String fetch = HttpRequestInspector.convert(
        request,
        HttpConversionTarget.fetch,
      );
      expect(HttpRequestInspector.parse(fetch).body, '\b\f');
    });

    test('duplicate headers are never silently collapsed', () {
      final HttpRequestDescriptor request = HttpRequestInspector.parse(
        "curl -H 'X-Test: one' -H 'X-Test: two' 'https://example.com'",
      );
      expect(
        HttpRequestInspector.convert(request, HttpConversionTarget.fetch),
        contains('["X-Test","one"]'),
      );
      expect(
        () => HttpRequestInspector.convert(request, HttpConversionTarget.axios),
        throwsA(isA<HttpInspectorException>()),
      );
      expect(
        () =>
            HttpRequestInspector.convert(request, HttpConversionTarget.python),
        throwsA(isA<HttpInspectorException>()),
      );
    });
  });
}
