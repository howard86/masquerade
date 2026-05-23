enum IpFamily { v4, v6 }

enum IpScope {
  private,
  loopback,
  linkLocal,
  multicast,
  documentation,
  unspecified,
}

sealed class IpParseResult {}

class IpOk extends IpParseResult {
  IpOk({
    required this.family,
    required this.address,
    required this.prefix,
    required this.scopes,
    this.network,
    this.broadcast,
    this.firstHost,
    this.lastHost,
    this.hostCount,
    this.netmask,
  });

  final IpFamily family;
  final BigInt address;
  final int? prefix;
  final BigInt? network;
  final BigInt? broadcast;
  final BigInt? firstHost;
  final BigInt? lastHost;
  final BigInt? hostCount;
  final String? netmask;
  final Set<IpScope> scopes;
}

class IpErr extends IpParseResult {
  IpErr(this.message);
  final String message;
}

class IpParser {
  static IpParseResult parse(String input) {
    final String t = input.trim();
    if (t.isEmpty) return IpErr('Empty input');

    final int slashIdx = t.lastIndexOf('/');
    final String addrPart;
    final int? prefix;

    if (slashIdx >= 0) {
      addrPart = t.substring(0, slashIdx);
      final String prefixStr = t.substring(slashIdx + 1);
      prefix = int.tryParse(prefixStr);
      if (prefix == null) return IpErr('Invalid prefix length');
    } else {
      addrPart = t;
      prefix = null;
    }

    if (addrPart.contains(':')) {
      return _parseV6(addrPart, prefix);
    } else {
      return _parseV4(addrPart, prefix);
    }
  }

  static IpParseResult _parseV4(String addr, int? prefix) {
    final List<String> parts = addr.split('.');
    if (parts.length != 4) return IpErr('IPv4 requires 4 octets');

    BigInt address = BigInt.zero;
    for (final String p in parts) {
      final int? octet = int.tryParse(p);
      if (octet == null || octet < 0 || octet > 255) {
        return IpErr('Octet out of range: $p');
      }
      address = (address << 8) | BigInt.from(octet);
    }

    if (prefix != null && (prefix < 0 || prefix > 32)) {
      return IpErr('Prefix must be 0–32 for IPv4');
    }

    final Set<IpScope> scopes = _scopesV4(address);

    if (prefix == null) {
      return IpOk(
        family: IpFamily.v4,
        address: address,
        prefix: null,
        scopes: scopes,
      );
    }

    final BigInt mask = _maskV4(prefix);
    final BigInt network = address & mask;
    final BigInt wildcard = mask ^ _allOnesV4;
    final BigInt broadcast = network | wildcard;
    final BigInt hostCount = wildcard + BigInt.one;
    final BigInt firstHost = prefix >= 31 ? network : network + BigInt.one;
    final BigInt lastHost = prefix >= 31 ? broadcast : broadcast - BigInt.one;

    return IpOk(
      family: IpFamily.v4,
      address: address,
      prefix: prefix,
      network: network,
      broadcast: broadcast,
      firstHost: firstHost,
      lastHost: lastHost,
      hostCount: hostCount,
      netmask: formatV4(mask),
      scopes: scopes,
    );
  }

  static IpParseResult _parseV6(String addr, int? prefix) {
    if (prefix != null && (prefix < 0 || prefix > 128)) {
      return IpErr('Prefix must be 0–128 for IPv6');
    }

    // Reject multiple ::
    final int dcCount = '::'.allMatches(addr).length;
    if (dcCount > 1) return IpErr('Multiple :: in address');

    List<String> groups;
    if (addr.contains('::')) {
      final List<String> halves = addr.split('::');
      final List<String> left = halves[0].isEmpty
          ? <String>[]
          : halves[0].split(':');
      final List<String> right = halves[1].isEmpty
          ? <String>[]
          : halves[1].split(':');
      final int fill = 8 - left.length - right.length;
      if (fill < 0) return IpErr('Too many groups');
      groups = <String>[...left, for (int i = 0; i < fill; i++) '0', ...right];
    } else {
      groups = addr.split(':');
    }

    if (groups.length != 8) return IpErr('IPv6 requires 8 groups');

    BigInt address = BigInt.zero;
    for (final String g in groups) {
      if (g.isEmpty || g.length > 4) return IpErr('Invalid group: $g');
      final int? val = int.tryParse(g, radix: 16);
      if (val == null || val < 0 || val > 0xFFFF) {
        return IpErr('Invalid group: $g');
      }
      address = (address << 16) | BigInt.from(val);
    }

    final Set<IpScope> scopes = _scopesV6(address);

    if (prefix == null) {
      return IpOk(
        family: IpFamily.v6,
        address: address,
        prefix: null,
        scopes: scopes,
      );
    }

    final BigInt mask = _maskV6(prefix);
    final BigInt network = address & mask;
    final BigInt wildcard = mask ^ _allOnesV6;
    final BigInt hostCount = wildcard + BigInt.one;
    final BigInt firstHost = network;
    final BigInt lastHost = network | wildcard;

    return IpOk(
      family: IpFamily.v6,
      address: address,
      prefix: prefix,
      network: network,
      firstHost: firstHost,
      lastHost: lastHost,
      hostCount: hostCount,
      scopes: scopes,
    );
  }

  static String formatV4(BigInt addr) {
    final int a = ((addr >> 24) & BigInt.from(0xFF)).toInt();
    final int b = ((addr >> 16) & BigInt.from(0xFF)).toInt();
    final int c = ((addr >> 8) & BigInt.from(0xFF)).toInt();
    final int d = (addr & BigInt.from(0xFF)).toInt();
    return '$a.$b.$c.$d';
  }

  static String formatV6(BigInt addr, {bool compress = true}) {
    final List<String> groups = <String>[];
    for (int i = 7; i >= 0; i--) {
      final int g = ((addr >> (i * 16)) & BigInt.from(0xFFFF)).toInt();
      groups.add(g.toRadixString(16));
    }
    if (!compress) {
      return groups.map((String g) => g.padLeft(4, '0')).join(':');
    }
    // Find longest run of consecutive zero groups
    int bestStart = -1;
    int bestLen = 0;
    int curStart = -1;
    int curLen = 0;
    for (int i = 0; i < 8; i++) {
      if (groups[i] == '0') {
        if (curStart < 0) curStart = i;
        curLen++;
        if (curLen > bestLen) {
          bestStart = curStart;
          bestLen = curLen;
        }
      } else {
        curStart = -1;
        curLen = 0;
      }
    }
    if (bestLen < 2) return groups.join(':');
    final String left = groups.sublist(0, bestStart).join(':');
    final String right = groups.sublist(bestStart + bestLen).join(':');
    return '$left::$right';
  }

  // --- private helpers ---

  static final BigInt _allOnesV4 = BigInt.parse('FFFFFFFF', radix: 16);
  static final BigInt _allOnesV6 = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
    radix: 16,
  );

  static BigInt _maskV4(int prefix) {
    if (prefix == 0) return BigInt.zero;
    return _allOnesV4 << (32 - prefix) & _allOnesV4;
  }

  static BigInt _maskV6(int prefix) {
    if (prefix == 0) return BigInt.zero;
    return _allOnesV6 << (128 - prefix) & _allOnesV6;
  }

  static Set<IpScope> _scopesV4(BigInt addr) {
    final Set<IpScope> s = <IpScope>{};
    if (addr == BigInt.zero) {
      s.add(IpScope.unspecified);
      return s;
    }
    // 10.0.0.0/8
    if (_inRange(addr, '0A000000', 8)) s.add(IpScope.private);
    // 172.16.0.0/12
    if (_inRange(addr, 'AC100000', 12)) s.add(IpScope.private);
    // 192.168.0.0/16
    if (_inRange(addr, 'C0A80000', 16)) s.add(IpScope.private);
    // 127.0.0.0/8
    if (_inRange(addr, '7F000000', 8)) s.add(IpScope.loopback);
    // 169.254.0.0/16
    if (_inRange(addr, 'A9FE0000', 16)) s.add(IpScope.linkLocal);
    // 224.0.0.0/4
    if (_inRange(addr, 'E0000000', 4)) s.add(IpScope.multicast);
    // 192.0.2.0/24
    if (_inRange(addr, 'C0000200', 24)) s.add(IpScope.documentation);
    // 198.51.100.0/24
    if (_inRange(addr, 'C6336400', 24)) s.add(IpScope.documentation);
    // 203.0.113.0/24
    if (_inRange(addr, 'CB007100', 24)) s.add(IpScope.documentation);
    return s;
  }

  static Set<IpScope> _scopesV6(BigInt addr) {
    final Set<IpScope> s = <IpScope>{};
    if (addr == BigInt.zero) {
      s.add(IpScope.unspecified);
      return s;
    }
    if (addr == BigInt.one) {
      s.add(IpScope.loopback);
      return s;
    }
    // fe80::/10
    if (_inRangeV6(addr, 'FE800000000000000000000000000000', 10)) {
      s.add(IpScope.linkLocal);
    }
    // ff00::/8
    if (_inRangeV6(addr, 'FF000000000000000000000000000000', 8)) {
      s.add(IpScope.multicast);
    }
    // 2001:db8::/32
    if (_inRangeV6(addr, '20010DB8000000000000000000000000', 32)) {
      s.add(IpScope.documentation);
    }
    // fc00::/7
    if (_inRangeV6(addr, 'FC000000000000000000000000000000', 7)) {
      s.add(IpScope.private);
    }
    return s;
  }

  static bool _inRange(BigInt addr, String networkHex, int prefix) {
    final BigInt network = BigInt.parse(networkHex, radix: 16);
    final BigInt mask = _maskV4(prefix);
    return (addr & mask) == (network & mask);
  }

  static bool _inRangeV6(BigInt addr, String networkHex, int prefix) {
    final BigInt network = BigInt.parse(networkHex, radix: 16);
    final BigInt mask = _maskV6(prefix);
    return (addr & mask) == (network & mask);
  }
}
