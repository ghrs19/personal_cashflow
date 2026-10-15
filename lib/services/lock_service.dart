import 'package:local_auth/local_auth.dart';

/// App lock built on the device credential — the same approach the
/// reference app used (Android Keyguard / device PIN + biometrics)
/// instead of storing a custom PIN inside the app.
class LockService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the user authenticated with biometrics or the
  /// device credential (PIN/pattern/password).
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
