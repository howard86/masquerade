import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/case_parser.dart';

void main() {
  test('converts helloWorld to all twelve variants', () {
    final CaseConversions result = CaseParser.parse('helloWorld')!;

    expect(result.tokens, <String>['hello', 'world']);
    expect(result.camelCase, 'helloWorld');
    expect(result.pascalCase, 'HelloWorld');
    expect(result.snakeCase, 'hello_world');
    expect(result.screamingSnake, 'HELLO_WORLD');
    expect(result.kebabCase, 'hello-world');
    expect(result.trainCase, 'Hello-World');
    expect(result.titleCase, 'Hello World');
    expect(result.sentenceCase, 'Hello world');
    expect(result.dotCase, 'hello.world');
    expect(result.pathCase, 'hello/world');
    expect(result.lowerCase, 'hello world');
    expect(result.upperCase, 'HELLO WORLD');
  });

  test('splits acronyms, delimiters, and both sides of digits', () {
    expect(CaseParser.parse('XMLHttpRequest')!.tokens, <String>[
      'xml',
      'http',
      'request',
    ]);
    expect(CaseParser.parse('user_id_42')!.tokens, <String>[
      'user',
      'id',
      '42',
    ]);
    expect(CaseParser.parse('user_id_42')!.screamingSnake, 'USER_ID_42');
    expect(CaseParser.parse('my-component.tsx')!.tokens, <String>[
      'my',
      'component',
      'tsx',
    ]);
    expect(CaseParser.parse('HTTP2Server')!.tokens, <String>[
      'http',
      '2',
      'server',
    ]);
    expect(CaseParser.parse('a1b')!.tokens, <String>['a', '1', 'b']);
    expect(CaseParser.parse('__my--component..tsx//42')!.tokens, <String>[
      'my',
      'component',
      'tsx',
      '42',
    ]);
  });

  test('keeps the named mixed initialisms sensible', () {
    expect(CaseParser.parse('IPv4')!.tokens, <String>['ipv', '4']);
    expect(CaseParser.parse('OAuth2')!.tokens, <String>['oauth', '2']);
    expect(CaseParser.parse('IPv4Address')!.tokens, <String>[
      'ipv',
      '4',
      'address',
    ]);
  });

  test('rejects blank, punctuation, and oversized input', () {
    expect(CaseParser.parse(''), isNull);
    expect(CaseParser.parse('   '), isNull);
    expect(CaseParser.parse('!!!'), isNull);
    expect(CaseParser.parse('déjàVu'), isNull);
    expect(CaseParser.parse('https://example.com/fooBar'), isNull);
    expect(CaseParser.parse('hello@world'), isNull);
    expect(CaseParser.parse('a' * (CaseParser.maxInputLength + 1)), isNull);
  });

  test('parses the maximum input in bounded time', () {
    final String input = List<String>.filled(2500, 'a1').join();
    final Stopwatch stopwatch = Stopwatch()..start();
    final CaseConversions? result = CaseParser.parse(input);
    stopwatch.stop();

    expect(result, isNotNull);
    expect(result!.tokens.length, 5000);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
