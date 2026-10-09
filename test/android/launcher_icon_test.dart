import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The launcher icon is the brand's, not Flutter's.
///
/// Until 2026-10-09 the app shipped the `flutter create` placeholder in every
/// mipmap and had no adaptive icon at all, while `brand/surahcycle_logo.svg`
/// — the mark he already approved for the sign-in consent screens — sat
/// unused next to it.
void main() {
  const res = 'android/app/src/main/res';

  test('an adaptive icon with a themed (monochrome) layer exists', () {
    final adaptive = File('$res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptive.existsSync(), isTrue, reason: 'no adaptive icon');
    final xml = adaptive.readAsStringSync();
    expect(xml, contains('<adaptive-icon'));
    expect(xml, contains('@drawable/ic_launcher_background'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('<monochrome'));
  });

  test('the foreground is the brand mark: the ring and the rub el hizb', () {
    final foreground = File(
      '$res/drawable/ic_launcher_foreground.xml',
    ).readAsStringSync();
    // The two amber segments — "due for revision" — and the eight-pointed
    // star, carried over from the SVG rather than redrawn.
    expect('#F2B450'.allMatches(foreground.toUpperCase()).length, 2);
    expect('#74BCA3'.allMatches(foreground.toUpperCase()).length, 6);
    expect(foreground.toUpperCase(), contains('#F7F2E8'));
    final background = File(
      '$res/drawable/ic_launcher_background.xml',
    ).readAsStringSync();
    expect(background.toUpperCase(), contains('#2E8268'));
    expect(background.toUpperCase(), contains('#17493B'));
  });

  test('every legacy mipmap is the brand at its density, not Flutter', () {
    const sizes = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final MapEntry(key: density, value: size) in sizes.entries) {
      final bytes = File(
        '$res/mipmap-$density/ic_launcher.png',
      ).readAsBytesSync();
      final (width, height) = _pngSize(bytes);
      expect((width, height), (size, size), reason: density);
      // The Flutter placeholder is a few hundred bytes of flat blue; a
      // rendering of the brand mark at the same size is several times that.
      expect(
        bytes.length,
        greaterThan(1500 * size ~/ 48),
        reason: '$density still looks like the flutter create placeholder',
      );
    }
  });
}

(int, int) _pngSize(Uint8List bytes) {
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var index = 0; index < signature.length; index += 1) {
    expect(bytes[index], signature[index], reason: 'not a PNG');
  }
  final data = ByteData.sublistView(bytes);
  // IHDR is the first chunk: length(4) type(4) width(4) height(4).
  return (data.getUint32(16), data.getUint32(20));
}
