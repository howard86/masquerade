import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/utils/ip_parser.dart';

void main() {
  group('IPv4 CIDR', () {
    test('192.168.1.0/24 → network, broadcast, hostCount, netmask, scope', () {
      final IpParseResult r = IpParser.parse('192.168.1.0/24');
      expect(r, isA<IpOk>());
      final IpOk ok = r as IpOk;
      expect(ok.family, IpFamily.v4);
      expect(ok.prefix, 24);
      expect(IpParser.formatV4(ok.network!), '192.168.1.0');
      expect(IpParser.formatV4(ok.broadcast!), '192.168.1.255');
      // hostCount = 2^(32-24) = 256 (total addresses in the block)
      expect(ok.hostCount, BigInt.from(256));
      expect(ok.netmask, '255.255.255.0');
      expect(ok.scopes, contains(IpScope.private));
    });
  });

  group('IPv4 scopes', () {
    test('10.0.0.1 → private', () {
      final IpOk ok = IpParser.parse('10.0.0.1') as IpOk;
      expect(ok.scopes, contains(IpScope.private));
    });

    test('127.0.0.1 → loopback', () {
      final IpOk ok = IpParser.parse('127.0.0.1') as IpOk;
      expect(ok.scopes, contains(IpScope.loopback));
    });

    test('224.0.0.1 → multicast', () {
      final IpOk ok = IpParser.parse('224.0.0.1') as IpOk;
      expect(ok.scopes, contains(IpScope.multicast));
    });
  });

  group('IPv6', () {
    test('::1 → loopback', () {
      final IpOk ok = IpParser.parse('::1') as IpOk;
      expect(ok.family, IpFamily.v6);
      expect(ok.scopes, contains(IpScope.loopback));
    });

    test('fe80::1 → link-local', () {
      final IpOk ok = IpParser.parse('fe80::1') as IpOk;
      expect(ok.scopes, contains(IpScope.linkLocal));
    });

    test('2001:db8::/32 → documentation', () {
      final IpOk ok = IpParser.parse('2001:db8::/32') as IpOk;
      expect(ok.scopes, contains(IpScope.documentation));
      expect(ok.prefix, 32);
    });

    test('2001:db8::1 compresses and expands correctly', () {
      final IpOk ok = IpParser.parse('2001:db8::1') as IpOk;
      expect(IpParser.formatV6(ok.address), '2001:db8::1');
      expect(
        IpParser.formatV6(ok.address, compress: false),
        '2001:0db8:0000:0000:0000:0000:0000:0001',
      );
    });
  });

  group('edge prefixes', () {
    test('/0 v4 parses without overflow', () {
      final IpParseResult r = IpParser.parse('192.168.1.1/0');
      expect(r, isA<IpOk>());
      final IpOk ok = r as IpOk;
      expect(ok.prefix, 0);
    });

    test('/32 v4 parses without overflow', () {
      final IpParseResult r = IpParser.parse('192.168.1.1/32');
      expect(r, isA<IpOk>());
      final IpOk ok = r as IpOk;
      expect(ok.prefix, 32);
      expect(ok.hostCount, BigInt.one);
    });

    test('/128 v6 parses without overflow', () {
      final IpParseResult r = IpParser.parse('::1/128');
      expect(r, isA<IpOk>());
      final IpOk ok = r as IpOk;
      expect(ok.prefix, 128);
      expect(ok.hostCount, BigInt.one);
    });
  });

  group('errors', () {
    test('256.0.0.1 → IpErr', () {
      expect(IpParser.parse('256.0.0.1'), isA<IpErr>());
    });

    test('1.2.3 → IpErr', () {
      expect(IpParser.parse('1.2.3'), isA<IpErr>());
    });

    test('g::1 → IpErr', () {
      expect(IpParser.parse('g::1'), isA<IpErr>());
    });

    test('::1::2 → IpErr', () {
      expect(IpParser.parse('::1::2'), isA<IpErr>());
    });

    test('192.168.1.1/33 → IpErr', () {
      expect(IpParser.parse('192.168.1.1/33'), isA<IpErr>());
    });
  });
}
