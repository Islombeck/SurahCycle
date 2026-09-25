/// The test account an acceptance build signs in as, if it was given one.
///
/// Compiled in through `--dart-define`, never written down here. A default
/// build has neither value, so [AcceptanceCredentials.configured] is false and
/// the account screen shows nothing — the owner's real builds are unaffected
/// whether or not anyone remembers this file exists.
///
/// Why they are build-time rather than typed: the acceptance run is driven over
/// ADB, and filling two text fields with `adb shell input text` is the kind of
/// step that fails silently and gets skipped. One tap can be scripted and
/// checked; typing cannot.
library;

abstract final class AcceptanceCredentials {
  static const String email = String.fromEnvironment('ACCEPTANCE_EMAIL');

  static const String password = String.fromEnvironment('ACCEPTANCE_PASSWORD');

  /// Whether this build carries a test account at all.
  static bool get configured => email.isNotEmpty && password.isNotEmpty;
}
