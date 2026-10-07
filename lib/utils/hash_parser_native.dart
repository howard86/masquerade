import 'hash_parser.dart';

/// Native has no SubtleCrypto; [HashTool.shaDigests] stays synchronous.
Future<ShaDigests>? subtleShaDigests(List<int> bytes) => null;
