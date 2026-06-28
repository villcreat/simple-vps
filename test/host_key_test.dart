import 'package:flutter_test/flutter_test.dart';
import 'package:vps_simple/src/services/real_ssh_service.dart';

void main() {
  test('trust-on-first-use accepts when nothing is pinned', () {
    expect(acceptHostFingerprint('', 'SHA256:abc'), isTrue);
    expect(acceptHostFingerprint('   ', 'SHA256:abc'), isTrue);
  });

  test('accepts a matching pinned fingerprint', () {
    expect(acceptHostFingerprint('SHA256:abc', 'SHA256:abc'), isTrue);
    expect(acceptHostFingerprint(' SHA256:abc ', 'SHA256:abc'), isTrue);
  });

  test('rejects a changed fingerprint (MITM protection)', () {
    expect(acceptHostFingerprint('SHA256:abc', 'SHA256:zzz'), isFalse);
  });
}
