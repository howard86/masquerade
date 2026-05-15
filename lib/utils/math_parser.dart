import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Math expression evaluator — single-line.
///
/// Storage is `Rational` along the exact track (`+`, `-`, `×`, `÷`, `%`,
/// integer `^`) and double-coerced through `Decimal` for transcendentals.
/// Results are wrapped in [MathValue], which carries both a Decimal for
/// display and an optional Rational for exact downstream arithmetic.

enum AngleUnit { radians, degrees }

enum MathErrorKind {
  malformedSyntax,
  divisionByZero,
  indeterminate,
  domainError,
  overflow,
  unknownIdentifier,
}

class MathError {
  const MathError(this.kind, this.message, {this.position});
  final MathErrorKind kind;
  final String message;
  final int? position;
}

/// Carries an evaluated value. Exact track keeps the [exact] rational; the
/// approximate track stores [approx] only and sets [isApproximate].
class MathValue {
  const MathValue._({
    required this.approx,
    required this.exact,
    required this.isApproximate,
  });

  factory MathValue.exact(Rational r) {
    final Decimal d = r.hasFinitePrecision
        ? r.toDecimal()
        : r.toDecimal(scaleOnInfinitePrecision: 30);
    return MathValue._(approx: d, exact: r, isApproximate: false);
  }

  factory MathValue.approx(Decimal d) =>
      MathValue._(approx: d, exact: null, isApproximate: true);

  final Decimal approx;
  final Rational? exact;
  final bool isApproximate;

  @override
  String toString() =>
      'MathValue(${isApproximate ? "~" : ""}${approx.toString()})';
}

/// Inputs to a single evaluation: angle unit + optional previous answer.
class MathContext {
  const MathContext({this.angleUnit = AngleUnit.radians, this.lastAnswer});
  final AngleUnit angleUnit;
  final MathValue? lastAnswer;
}

sealed class MathParseResult {
  const MathParseResult();
}

class MathOk extends MathParseResult {
  const MathOk(this.value);
  final MathValue value;
}

/// Syntactically partial input — trailing operator or unbalanced paren. The
/// body UI suppresses errors for this case and shows the previous valid
/// result dimmed.
class MathIncomplete extends MathParseResult {
  const MathIncomplete();
}

class MathErr extends MathParseResult {
  const MathErr(this.error);
  final MathError error;
}

class MathParser {
  const MathParser._();

  static MathParseResult parse(String input, {required MathContext ctx}) {
    final String t = input.trim();
    if (t.isEmpty) return const MathIncomplete();
    try {
      final List<_Token> tokens = _Lexer(t).run();
      if (tokens.isEmpty) return const MathIncomplete();
      final _Parser p = _Parser(tokens);
      final _Expr ast = p.parse();
      final MathValue v = _Evaluator(ctx).eval(ast);
      return MathOk(v);
    } on _IncompleteException catch (_) {
      return const MathIncomplete();
    } on MathError catch (e) {
      return MathErr(e);
    } on FormatException catch (e) {
      return MathErr(MathError(MathErrorKind.malformedSyntax, e.message));
    }
  }
}

// -- Lexer --------------------------------------------------------------------

enum _Tok {
  number,
  ident,
  lparen,
  rparen,
  comma,
  plus,
  minus,
  star,
  slash,
  percent,
  caret,
}

class _Token {
  const _Token(this.type, this.text, this.start);
  final _Tok type;
  final String text;
  final int start;
}

class _IncompleteException implements Exception {
  const _IncompleteException();
}

class _Lexer {
  _Lexer(this.src);
  final String src;
  int _i = 0;

  List<_Token> run() {
    final List<_Token> out = <_Token>[];
    while (_i < src.length) {
      final int c = src.codeUnitAt(_i);
      if (_isWs(c)) {
        _i++;
        continue;
      }
      if (_isDigit(c) || (c == _dot && _peekDigit(_i + 1))) {
        out.add(_readNumber());
        // Implicit `*`: a number followed (across any whitespace) by a letter
        // or `(`. Number-followed-by-number is not implicit — `1 2` stays a
        // syntax error.
        int j = _i;
        while (j < src.length && _isWs(src.codeUnitAt(j))) {
          j++;
        }
        if (j < src.length) {
          final int next = src.codeUnitAt(j);
          if (_isAlpha(next) || next == _lp) {
            out.add(_Token(_Tok.star, '*', _i));
          }
        }
        continue;
      }
      if (_isAlpha(c)) {
        out.add(_readIdent());
        continue;
      }
      switch (c) {
        case _lp:
          out.add(_Token(_Tok.lparen, '(', _i));
          _i++;
          break;
        case _rp:
          out.add(_Token(_Tok.rparen, ')', _i));
          _i++;
          break;
        case _cm:
          out.add(_Token(_Tok.comma, ',', _i));
          _i++;
          break;
        case _pl:
          out.add(_Token(_Tok.plus, '+', _i));
          _i++;
          break;
        case _mn:
          out.add(_Token(_Tok.minus, '-', _i));
          _i++;
          break;
        case _st:
          out.add(_Token(_Tok.star, '*', _i));
          _i++;
          break;
        case _sl:
          out.add(_Token(_Tok.slash, '/', _i));
          _i++;
          break;
        case _pc:
          out.add(_Token(_Tok.percent, '%', _i));
          _i++;
          break;
        case _cr:
          out.add(_Token(_Tok.caret, '^', _i));
          _i++;
          break;
        default:
          throw MathError(
            MathErrorKind.malformedSyntax,
            'Unexpected character "${String.fromCharCode(c)}"',
            position: _i,
          );
      }
    }
    return out;
  }

  _Token _readNumber() {
    final int start = _i;
    bool sawDot = false;
    bool sawExp = false;
    while (_i < src.length) {
      final int c = src.codeUnitAt(_i);
      if (_isDigit(c)) {
        _i++;
      } else if (c == _dot && !sawDot && !sawExp) {
        sawDot = true;
        _i++;
      } else if ((c == _eL || c == _eU) && !sawExp) {
        sawExp = true;
        _i++;
        if (_i < src.length) {
          final int s = src.codeUnitAt(_i);
          if (s == _pl || s == _mn) _i++;
        }
        // Exponent must have at least one digit.
        if (_i >= src.length || !_isDigit(src.codeUnitAt(_i))) {
          throw const _IncompleteException();
        }
      } else {
        break;
      }
    }
    return _Token(_Tok.number, src.substring(start, _i), start);
  }

  _Token _readIdent() {
    final int start = _i;
    while (_i < src.length && _isAlphaNum(src.codeUnitAt(_i))) {
      _i++;
    }
    return _Token(_Tok.ident, src.substring(start, _i).toLowerCase(), start);
  }

  bool _peekDigit(int idx) => idx < src.length && _isDigit(src.codeUnitAt(idx));

  static const int _dot = 0x2E;
  static const int _lp = 0x28;
  static const int _rp = 0x29;
  static const int _cm = 0x2C;
  static const int _pl = 0x2B;
  static const int _mn = 0x2D;
  static const int _st = 0x2A;
  static const int _sl = 0x2F;
  static const int _pc = 0x25;
  static const int _cr = 0x5E;
  static const int _eL = 0x65;
  static const int _eU = 0x45;

  static bool _isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isAlpha(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;
  static bool _isAlphaNum(int c) => _isAlpha(c) || _isDigit(c);
}

// -- AST + Parser -------------------------------------------------------------

sealed class _Expr {
  const _Expr();
}

class _Num extends _Expr {
  const _Num(this.value);
  final Rational value;
}

class _Ident extends _Expr {
  const _Ident(this.name, this.position);
  final String name;
  final int position;
}

class _Call extends _Expr {
  const _Call(this.name, this.args, this.position);
  final String name;
  final List<_Expr> args;
  final int position;
}

class _Neg extends _Expr {
  const _Neg(this.inner);
  final _Expr inner;
}

class _Bin extends _Expr {
  const _Bin(this.op, this.left, this.right);
  final _Tok op;
  final _Expr left;
  final _Expr right;
}

class _Parser {
  _Parser(this.tokens);
  final List<_Token> tokens;
  int _i = 0;

  _Token? get _cur => _i < tokens.length ? tokens[_i] : null;

  _Expr parse() {
    final _Expr e = _parseExpression(0);
    if (_cur != null) {
      final _Token t = _cur!;
      if (t.type == _Tok.rparen) {
        throw MathError(
          MathErrorKind.malformedSyntax,
          'Unexpected ")"',
          position: t.start,
        );
      }
      throw MathError(
        MathErrorKind.malformedSyntax,
        'Unexpected "${t.text}"',
        position: t.start,
      );
    }
    return e;
  }

  // Higher binding power binds tighter; `^` is the only right-associative op.
  static const int _addP = 10;
  static const int _mulP = 20;
  static const int _unaryP = 30;
  static const int _powP = 40;

  _Expr _parseExpression(int minBp) {
    _Expr left = _parsePrefix();
    while (true) {
      final _Token? t = _cur;
      if (t == null) break;
      final int? lbp = _infixBp(t.type);
      if (lbp == null || lbp < minBp) break;
      _i++;
      // `^` is right-associative.
      final int rbp = t.type == _Tok.caret ? lbp : lbp + 1;
      final _Expr right = _parseExpression(rbp);
      left = _Bin(t.type, left, right);
    }
    return left;
  }

  _Expr _parsePrefix() {
    final _Token? t = _cur;
    if (t == null) throw const _IncompleteException();
    switch (t.type) {
      case _Tok.minus:
        _i++;
        final _Expr inner = _parseExpression(_unaryP);
        return _Neg(inner);
      case _Tok.number:
        _i++;
        return _Num(Rational.parse(t.text));
      case _Tok.ident:
        _i++;
        if (_cur?.type == _Tok.lparen) {
          _i++;
          final List<_Expr> args = <_Expr>[];
          if (_cur?.type != _Tok.rparen) {
            args.add(_parseExpression(0));
            while (_cur?.type == _Tok.comma) {
              _i++;
              args.add(_parseExpression(0));
            }
          }
          if (_cur == null) throw const _IncompleteException();
          if (_cur!.type != _Tok.rparen) {
            throw MathError(
              MathErrorKind.malformedSyntax,
              'Expected ")"',
              position: _cur!.start,
            );
          }
          _i++;
          return _Call(t.text, args, t.start);
        }
        return _Ident(t.text, t.start);
      case _Tok.lparen:
        _i++;
        if (_cur == null) throw const _IncompleteException();
        if (_cur!.type == _Tok.rparen) {
          throw MathError(
            MathErrorKind.malformedSyntax,
            'Empty parentheses',
            position: t.start,
          );
        }
        final _Expr inner = _parseExpression(0);
        if (_cur == null) throw const _IncompleteException();
        if (_cur!.type != _Tok.rparen) {
          throw MathError(
            MathErrorKind.malformedSyntax,
            'Expected ")"',
            position: _cur!.start,
          );
        }
        _i++;
        return inner;
      case _Tok.plus:
      case _Tok.rparen:
      case _Tok.comma:
      case _Tok.star:
      case _Tok.slash:
      case _Tok.percent:
      case _Tok.caret:
        throw MathError(
          MathErrorKind.malformedSyntax,
          'Unexpected "${t.text}"',
          position: t.start,
        );
    }
  }

  int? _infixBp(_Tok t) => switch (t) {
    _Tok.plus || _Tok.minus => _addP,
    _Tok.star || _Tok.slash || _Tok.percent => _mulP,
    _Tok.caret => _powP,
    _ => null,
  };
}

// -- Evaluator ----------------------------------------------------------------

class _Evaluator {
  const _Evaluator(this.ctx);
  final MathContext ctx;

  MathValue eval(_Expr e) {
    return switch (e) {
      _Num n => MathValue.exact(n.value),
      _Ident i => _resolveIdent(i),
      _Call c => _evalCall(c),
      _Neg neg => _negate(eval(neg.inner)),
      _Bin b => _binOp(b.op, eval(b.left), eval(b.right)),
    };
  }

  MathValue _resolveIdent(_Ident i) {
    switch (i.name) {
      case 'pi':
        return MathValue.exact(Rational.parse(_piDigits));
      case 'e':
        return MathValue.exact(Rational.parse(_eDigits));
      case 'ans':
        final MathValue? a = ctx.lastAnswer;
        if (a == null) {
          throw MathError(
            MathErrorKind.unknownIdentifier,
            'No previous answer to reference',
            position: i.position,
          );
        }
        return a;
    }
    throw MathError(
      MathErrorKind.unknownIdentifier,
      'Unknown identifier "${i.name}"',
      position: i.position,
    );
  }

  MathValue _negate(MathValue v) {
    if (!v.isApproximate) return MathValue.exact(-v.exact!);
    return _coerceDouble(-v.approx.toDouble());
  }

  MathValue _binOp(_Tok op, MathValue a, MathValue b) {
    if (op == _Tok.caret) return _pow(a, b);
    if (!a.isApproximate && !b.isApproximate) {
      final Rational ar = a.exact!;
      final Rational br = b.exact!;
      switch (op) {
        case _Tok.plus:
          return MathValue.exact(ar + br);
        case _Tok.minus:
          return MathValue.exact(ar - br);
        case _Tok.star:
          return MathValue.exact(ar * br);
        case _Tok.slash:
          if (br == Rational.zero) {
            throw MathError(
              MathErrorKind.divisionByZero,
              ar == Rational.zero ? _msgIndeterminateDiv : _msgDivByZero,
            );
          }
          return MathValue.exact(ar / br);
        case _Tok.percent:
          if (br == Rational.zero) {
            throw const MathError(MathErrorKind.divisionByZero, _msgModByZero);
          }
          final Rational q = ar / br;
          final Rational qInt = Rational(q.truncate());
          return MathValue.exact(ar - qInt * br);
        default:
          throw StateError('non-arithmetic op in arithmetic branch');
      }
    }
    final double aD = a.approx.toDouble();
    final double bD = b.approx.toDouble();
    switch (op) {
      case _Tok.plus:
        return _coerceDouble(aD + bD);
      case _Tok.minus:
        return _coerceDouble(aD - bD);
      case _Tok.star:
        return _coerceDouble(aD * bD);
      case _Tok.slash:
        if (bD == 0) {
          throw MathError(
            MathErrorKind.divisionByZero,
            aD == 0 ? _msgIndeterminateDiv : _msgDivByZero,
          );
        }
        return _coerceDouble(aD / bD);
      case _Tok.percent:
        if (bD == 0) {
          throw const MathError(MathErrorKind.divisionByZero, _msgModByZero);
        }
        return _coerceDouble(aD - (aD / bD).truncateToDouble() * bD);
      default:
        throw StateError('non-arithmetic op in approximate branch');
    }
  }

  MathValue _pow(MathValue a, MathValue b) {
    if (!a.isApproximate && !b.isApproximate) {
      final Rational exp = b.exact!;
      if (exp.isInteger) {
        final BigInt eBig = exp.truncate();
        // Guard against catastrophic exponents (memory blow-up).
        if (eBig.abs() > BigInt.from(10000)) {
          throw const MathError(MathErrorKind.overflow, 'Exponent too large');
        }
        final int e = eBig.toInt();
        if (e == 0 && a.exact! == Rational.zero) {
          throw const MathError(
            MathErrorKind.indeterminate,
            'Indeterminate (0 ^ 0)',
          );
        }
        if (e < 0 && a.exact! == Rational.zero) {
          throw const MathError(
            MathErrorKind.divisionByZero,
            '0 raised to a negative power',
          );
        }
        return MathValue.exact(_rationalIntPow(a.exact!, e));
      }
    }
    final double aD = a.approx.toDouble();
    final double bD = b.approx.toDouble();
    if (aD == 0 && bD == 0) {
      throw const MathError(
        MathErrorKind.indeterminate,
        'Indeterminate (0 ^ 0)',
      );
    }
    if (aD < 0 && bD != bD.truncateToDouble()) {
      throw const MathError(
        MathErrorKind.domainError,
        'Negative base raised to non-integer power',
      );
    }
    return _coerceDouble(math.pow(aD, bD).toDouble());
  }

  Rational _rationalIntPow(Rational base, int exp) {
    if (exp == 0) return Rational.one;
    if (exp < 0) return _rationalIntPow(base, -exp).inverse;
    final BigInt num = base.numerator.pow(exp);
    final BigInt den = base.denominator.pow(exp);
    return Rational(num, den);
  }

  MathValue _evalCall(_Call c) {
    final String name = c.name;
    final List<MathValue> args = c.args.map(eval).toList(growable: false);

    void expectArity(int n) {
      if (args.length != n) {
        throw MathError(
          MathErrorKind.malformedSyntax,
          '$name expects $n argument${n == 1 ? "" : "s"}',
          position: c.position,
        );
      }
    }

    switch (name) {
      case 'abs':
        expectArity(1);
        final MathValue v = args[0];
        if (!v.isApproximate) return MathValue.exact(v.exact!.abs());
        return _coerceDouble(v.approx.toDouble().abs());
      case 'floor':
        expectArity(1);
        return _intResult(args[0], (Rational r) => r.floor());
      case 'ceil':
        expectArity(1);
        return _intResult(args[0], (Rational r) => r.ceil());
      case 'round':
        expectArity(1);
        return _intResult(args[0], (Rational r) => r.round());
      case 'min':
        expectArity(2);
        return _pickPair(args[0], args[1], pickGreater: false);
      case 'max':
        expectArity(2);
        return _pickPair(args[0], args[1], pickGreater: true);
      case 'sqrt':
        expectArity(1);
        final double x = args[0].approx.toDouble();
        if (x < 0) {
          throw const MathError(
            MathErrorKind.domainError,
            'sqrt of negative number',
          );
        }
        return _coerceDouble(math.sqrt(x));
      case 'log':
        expectArity(1);
        final double x = args[0].approx.toDouble();
        if (x <= 0) {
          throw const MathError(
            MathErrorKind.domainError,
            'log of non-positive number',
          );
        }
        return _coerceDouble(math.log(x) / math.ln10);
      case 'ln':
        expectArity(1);
        final double x = args[0].approx.toDouble();
        if (x <= 0) {
          throw const MathError(
            MathErrorKind.domainError,
            'ln of non-positive number',
          );
        }
        return _coerceDouble(math.log(x));
      case 'sin':
        expectArity(1);
        return _coerceDouble(math.sin(_toRadians(args[0])));
      case 'cos':
        expectArity(1);
        return _coerceDouble(math.cos(_toRadians(args[0])));
      case 'tan':
        expectArity(1);
        final double rad = _toRadians(args[0]);
        final double r = math.tan(rad);
        if (r.isInfinite || r.abs() > 1e15) {
          throw const MathError(
            MathErrorKind.overflow,
            'tan undefined at this angle',
          );
        }
        return _coerceDouble(r);
      case 'asin':
        expectArity(1);
        final double x = args[0].approx.toDouble();
        if (x < -1 || x > 1) {
          throw const MathError(
            MathErrorKind.domainError,
            'asin argument must be in [-1, 1]',
          );
        }
        return _coerceDouble(_fromRadians(math.asin(x)));
      case 'acos':
        expectArity(1);
        final double x = args[0].approx.toDouble();
        if (x < -1 || x > 1) {
          throw const MathError(
            MathErrorKind.domainError,
            'acos argument must be in [-1, 1]',
          );
        }
        return _coerceDouble(_fromRadians(math.acos(x)));
      case 'atan':
        expectArity(1);
        return _coerceDouble(
          _fromRadians(math.atan(args[0].approx.toDouble())),
        );
    }
    throw MathError(
      MathErrorKind.unknownIdentifier,
      'Unknown function "$name"',
      position: c.position,
    );
  }

  double _toRadians(MathValue v) {
    final double d = v.approx.toDouble();
    return ctx.angleUnit == AngleUnit.degrees ? d * math.pi / 180.0 : d;
  }

  double _fromRadians(double radians) =>
      ctx.angleUnit == AngleUnit.degrees ? radians * 180.0 / math.pi : radians;

  MathValue _intResult(MathValue v, BigInt Function(Rational) op) {
    if (!v.isApproximate) {
      return MathValue.exact(Rational(op(v.exact!)));
    }
    return _coerceDouble(op(v.approx.toRational()).toDouble());
  }

  MathValue _pickPair(MathValue a, MathValue b, {required bool pickGreater}) {
    final int cmp = a.approx.compareTo(b.approx);
    final bool takeA = pickGreater ? cmp >= 0 : cmp <= 0;
    return takeA ? a : b;
  }
}

MathValue _coerceDouble(double v) {
  if (v.isNaN) {
    throw const MathError(MathErrorKind.domainError, 'Result is not a number');
  }
  if (v.isInfinite) {
    throw const MathError(
      MathErrorKind.overflow,
      'Result exceeds representable range',
    );
  }
  // Integer snap — when a float result is within 1e-12 of an integer, promote
  // it back to exact. Catches sqrt(4) = 2 and sin(pi) ≈ 0 cleanly.
  if (v.abs() < 1e15) {
    final double rounded = v.roundToDouble();
    final double tolerance = v.abs() < 1 ? 1e-12 : v.abs() * 1e-12;
    if ((v - rounded).abs() <= tolerance) {
      final BigInt asBig = BigInt.from(rounded.toInt());
      return MathValue.exact(Rational(asBig));
    }
  }
  // 15 significant digits keeps us within double precision without exposing
  // float noise (`0.30000000000000004`).
  final String s = v.toStringAsPrecision(15);
  final Decimal d = Decimal.parse(s);
  return MathValue.approx(d);
}

// 30-digit rational approximations of π and e. Carried through arithmetic
// exactly; if a downstream op stays in the rational track, the user gets
// 30-digit accuracy. If it touches the float track, accuracy collapses to
// IEEE 754 anyway.
const String _piDigits = '3.14159265358979323846264338328';
const String _eDigits = '2.71828182845904523536028747135';

const String _msgDivByZero = 'Division by zero';
const String _msgIndeterminateDiv = 'Indeterminate (0 / 0)';
const String _msgModByZero = 'Modulo by zero';
