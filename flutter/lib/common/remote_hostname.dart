import 'dart:io';

/// Resolve explicit hostname:port direct connections without changing RustDesk IDs.
Future<String> resolveRemoteHostname(String input) async {
  final value = input.trim();
  final match = RegExp(r'^([A-Za-z][A-Za-z0-9_.-]*):(\d{1,5})$').firstMatch(value);
  if (match == null) return value;
  final host = match.group(1)!;
  final port = int.tryParse(match.group(2)!);
  if (port == null || port < 1 || port > 65535) return value;
  // Resolve the exact name first. For a single-label LAN hostname, try
  // mDNS (.local) only if normal name resolution fails.
  final candidates = <String>[host];
  if (!host.contains('.') && host.toLowerCase() != 'localhost') {
    candidates.add('$host.local');
  }
  for (final candidate in candidates) {
    try {
      final addresses = await InternetAddress.lookup(
        candidate, type: InternetAddressType.IPv4);
      if (addresses.isNotEmpty) return '${addresses.first.address}:$port';
    } on SocketException {
      // Continue with .local or leave the original RustDesk ID unchanged.
    }
  }
  return value;
}
