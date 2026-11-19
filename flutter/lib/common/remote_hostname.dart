import 'dart:io';

/// Resolve explicit hostname:port direct connections without changing RustDesk IDs.
Future<String> resolveRemoteHostname(String input) async {
  final value = input.trim();
  final match = RegExp(r'^([A-Za-z][A-Za-z0-9_.-]*):(\d{1,5})$').firstMatch(value);
  if (match == null) return value;
  final host = match.group(1)!;
  final port = int.tryParse(match.group(2)!);
  if (port == null || port < 1 || port > 65535) return value;
  try {
    final addresses = await InternetAddress.lookup(host, type: InternetAddressType.IPv4);
    if (addresses.isNotEmpty) return '${addresses.first.address}:$port';
  } catch (_) {}
  return value;
}
