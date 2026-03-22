import 'package:http/http.dart' as http;

/// Verifies real internet access using lightweight HTTPS requests.
///
/// ICMP ping to `1.1.1.1` is not available from pure Dart; this uses HTTP(S)
/// reachability to well-known endpoints instead (same practical outcome for
/// “is the network usable?”).
class InternetConnectionService {
  InternetConnectionService._();
  static final InternetConnectionService instance = InternetConnectionService._();

  /// How long to wait per probe before trying the next URL.
  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Ordered list: try Cloudflare first, then Google’s connectivity check.
  static final List<Uri> _probeUris = <Uri>[
    Uri.parse('https://1.1.1.1'),
    Uri.parse('https://www.google.com/generate_204'),
  ];

  /// Returns `true` if any probe succeeds (2xx or 204).
  ///
  /// [timeout] applies to each individual request.
  Future<bool> hasInternetAccess({Duration timeout = defaultTimeout}) async {
    for (final uri in _probeUris) {
      if (await _probe(uri, timeout: timeout)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _probe(Uri uri, {required Duration timeout}) async {
    try {
      final response = await http.get(uri).timeout(timeout);
      final code = response.statusCode;
      return code >= 200 && code < 400;
    } catch (_) {
      return false;
    }
  }

  /// Same as [hasInternetAccess] but returns a human-readable error when offline.
  Future<InternetCheckResult> check({Duration timeout = defaultTimeout}) async {
    for (final uri in _probeUris) {
      try {
        final response = await http.get(uri).timeout(timeout);
        final code = response.statusCode;
        if (code >= 200 && code < 400) {
          return InternetCheckResult(connected: true, reachedUri: uri);
        }
      } catch (_) {
        continue;
      }
    }
    return const InternetCheckResult(connected: false, reachedUri: null);
  }
}

class InternetCheckResult {
  const InternetCheckResult({required this.connected, required this.reachedUri});

  final bool connected;

  /// Which probe URL succeeded, or `null` if all failed.
  final Uri? reachedUri;

  String get message =>
      connected ? 'Connected (${reachedUri?.host ?? 'unknown'})' : 'No internet connection';
}
