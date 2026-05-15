import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/math_parser.dart';
import 'package:rational/rational.dart';

void main() {
  const MathContext radCtx = MathContext();
  const MathContext degCtx = MathContext(angleUnit: AngleUnit.degrees);

  MathValue ok(String src, {MathContext ctx = radCtx}) {
    final MathParseResult r = MathParser.parse(src, ctx: ctx);
    expect(r, isA<MathOk>(), reason: 'expected MathOk for "$src", got $r');
    return (r as MathOk).value;
  }

  MathError err(String src, {MathContext ctx = radCtx}) {
    final MathParseResult r = MathParser.parse(src, ctx: ctx);
    expect(r, isA<MathErr>(), reason: 'expected MathErr for "$src", got $r');
    return (r as MathErr).error;
  }

  void incomplete(String src, {MathContext ctx = radCtx}) {
    expect(
      MathParser.parse(src, ctx: ctx),
      isA<MathIncomplete>(),
      reason: '"$src" should be incomplete',
    );
  }

  group('arithmetic precedence', () {
    test('1 + 2 * 3 = 7', () {
      expect(ok('1 + 2 * 3').exact, Rational.fromInt(7));
    });

    test('2 ^ 3 ^ 2 = 512 (right associative)', () {
      expect(ok('2 ^ 3 ^ 2').exact, Rational.fromInt(512));
    });

    test('-2 ^ 2 = -4 (unary binds looser than ^)', () {
      expect(ok('-2 ^ 2').exact, Rational.fromInt(-4));
    });

    test('(-2) ^ 2 = 4 (parens override)', () {
      expect(ok('(-2) ^ 2').exact, Rational.fromInt(4));
    });

    test('parentheses change precedence', () {
      expect(ok('(1 + 2) * 3').exact, Rational.fromInt(9));
    });

    test('modulo binds like multiplication', () {
      expect(ok('10 + 7 % 3').exact, Rational.fromInt(11));
    });
  });

  group('exact rationals', () {
    test('0.1 + 0.2 = 0.3 exactly', () {
      final MathValue v = ok('0.1 + 0.2');
      expect(v.isApproximate, isFalse);
      expect(v.exact, Rational.parse('0.3'));
    });

    test('1 / 3 stays exact', () {
      final MathValue v = ok('1 / 3');
      expect(v.isApproximate, isFalse);
      expect(v.exact, Rational(BigInt.one, BigInt.from(3)));
    });

    test('2/7 + 5/7 = 1 exactly', () {
      final MathValue v = ok('2/7 + 5/7');
      expect(v.isApproximate, isFalse);
      expect(v.exact, Rational.one);
    });

    test('1/3 * 3 = 1 exactly', () {
      expect(ok('1/3 * 3').exact, Rational.one);
    });

    test('large integer power stays exact', () {
      final MathValue v = ok('2 ^ 100');
      expect(v.isApproximate, isFalse);
      expect(v.exact, Rational(BigInt.from(2).pow(100)));
    });
  });

  group('implicit multiplication', () {
    test('2pi parses as 2*pi', () {
      final MathValue v = ok('2pi');
      expect(v.isApproximate, isFalse);
      expect(
        v.exact!.toDecimal(scaleOnInfinitePrecision: 5).toDouble(),
        closeTo(6.28318, 1e-3),
      );
    });

    test('2(3+4) parses as 2*(3+4)', () {
      expect(ok('2(3+4)').exact, Rational.fromInt(14));
    });

    test('3sin(0) parses as 3 * sin(0)', () {
      final MathValue v = ok('3 sin(0)');
      // sin(0) snaps to exact 0; 3*0 = 0.
      expect(v.exact, Rational.zero);
    });
  });

  group('transcendentals', () {
    test('sin(pi/2) ≈ 1 in radians, snaps to exact via integer promotion', () {
      final MathValue v = ok('sin(pi/2)');
      // Float result lands ~1.0; integer-snap promotes to exact 1.
      expect(v.exact, Rational.one);
    });

    test('sin(pi) snaps to 0', () {
      final MathValue v = ok('sin(pi)');
      expect(v.exact, Rational.zero);
    });

    test('sqrt(2) is approximate', () {
      final MathValue v = ok('sqrt(2)');
      expect(v.isApproximate, isTrue);
      expect(v.approx.toDouble(), closeTo(1.41421356, 1e-6));
    });

    test('sqrt(4) snaps to exact 2', () {
      final MathValue v = ok('sqrt(4)');
      expect(v.exact, Rational.fromInt(2));
    });

    test('log(100) ≈ 2', () {
      final MathValue v = ok('log(100)');
      expect(v.exact, Rational.fromInt(2));
    });

    test('ln(e) ≈ 1', () {
      final MathValue v = ok('ln(e)');
      expect(v.exact, Rational.one);
    });
  });

  group('angle units', () {
    test('sin(30 deg) = 0.5 in degree mode', () {
      final MathValue v = ok('sin(30)', ctx: degCtx);
      // Float result rounds to 0.5 within tolerance — exact promotion expects
      // integer, so this should stay approximate at ~0.5.
      expect(v.approx.toDouble(), closeTo(0.5, 1e-12));
    });

    test('cos(0) = 1 in either unit', () {
      expect(ok('cos(0)', ctx: radCtx).exact, Rational.one);
      expect(ok('cos(0)', ctx: degCtx).exact, Rational.one);
    });

    test('asin(1) returns 90 in degree mode', () {
      final MathValue v = ok('asin(1)', ctx: degCtx);
      expect(v.exact, Rational.fromInt(90));
    });
  });

  group('ans recall', () {
    test('ans returns lastAnswer', () {
      final MathContext ctx = MathContext(
        lastAnswer: MathValue.exact(Rational.fromInt(5)),
      );
      expect(ok('ans * 2', ctx: ctx).exact, Rational.fromInt(10));
    });

    test('ans without lastAnswer fails', () {
      final MathError e = err('ans + 1');
      expect(e.kind, MathErrorKind.unknownIdentifier);
    });
  });

  group('errors', () {
    test('division by zero', () {
      expect(err('1 / 0').kind, MathErrorKind.divisionByZero);
    });

    test('0/0 is indeterminate', () {
      final MathError e = err('0 / 0');
      expect(e.kind, MathErrorKind.divisionByZero);
      expect(e.message, contains('Indeterminate'));
    });

    test('sqrt of negative', () {
      expect(err('sqrt(-1)').kind, MathErrorKind.domainError);
    });

    test('log of zero', () {
      expect(err('log(0)').kind, MathErrorKind.domainError);
    });

    test('log of negative', () {
      expect(err('ln(-1)').kind, MathErrorKind.domainError);
    });

    test('asin out of domain', () {
      expect(err('asin(2)').kind, MathErrorKind.domainError);
    });

    test('unknown function', () {
      expect(err('frobnicate(3)').kind, MathErrorKind.unknownIdentifier);
    });

    test('unknown identifier', () {
      expect(err('x + 1').kind, MathErrorKind.unknownIdentifier);
    });

    test('catastrophic exponent rejected', () {
      expect(err('2 ^ 100000').kind, MathErrorKind.overflow);
    });

    test('0^0 is indeterminate', () {
      expect(err('0 ^ 0').kind, MathErrorKind.indeterminate);
    });

    test('negative ^ non-integer is a domain error', () {
      expect(err('(-2) ^ 0.5').kind, MathErrorKind.domainError);
    });

    test('malformed: two binary operators', () {
      expect(err('1 ++ 2').kind, MathErrorKind.malformedSyntax);
    });

    test('malformed: unmatched closing paren', () {
      expect(err('1 + 2)').kind, MathErrorKind.malformedSyntax);
    });
  });

  group('incomplete syntax', () {
    test('trailing operator', () {
      incomplete('1 +');
    });

    test('unbalanced opening paren', () {
      incomplete('(1 + 2');
    });

    test('function with no args yet', () {
      incomplete('sin(');
    });

    test('empty string', () {
      incomplete('');
    });

    test('whitespace only', () {
      incomplete('   ');
    });

    test('lone unary minus', () {
      incomplete('-');
    });

    test('exponent suffix with no digits', () {
      incomplete('1e');
    });
  });

  group('functions arity', () {
    test('floor', () {
      expect(ok('floor(2.7)').exact, Rational.fromInt(2));
      expect(ok('floor(-2.3)').exact, Rational.fromInt(-3));
    });

    test('ceil', () {
      expect(ok('ceil(2.1)').exact, Rational.fromInt(3));
    });

    test('round', () {
      expect(ok('round(2.5)').exact, Rational.fromInt(3));
      expect(ok('round(2.4)').exact, Rational.fromInt(2));
    });

    test('abs', () {
      expect(ok('abs(-5)').exact, Rational.fromInt(5));
      expect(ok('abs(7)').exact, Rational.fromInt(7));
    });

    test('min / max', () {
      expect(ok('min(3, 5)').exact, Rational.fromInt(3));
      expect(ok('max(3, 5)').exact, Rational.fromInt(5));
    });

    test('wrong arity', () {
      expect(err('sin(1, 2)').kind, MathErrorKind.malformedSyntax);
      expect(err('min(1)').kind, MathErrorKind.malformedSyntax);
    });
  });

  group('scientific number literals', () {
    test('1e3 = 1000', () {
      expect(ok('1e3').exact, Rational.fromInt(1000));
    });

    test('1.5e-2 = 0.015', () {
      expect(ok('1.5e-2').exact, Rational.parse('0.015'));
    });

    test('2e2 + 1 = 201', () {
      expect(ok('2e2 + 1').exact, Rational.fromInt(201));
    });
  });
}
