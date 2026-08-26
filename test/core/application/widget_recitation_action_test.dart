import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/application/widget_recitation_action.dart';

void main() {
  const token = '12345678-1234-4abc-8def-1234567890ab';

  test('versioned whole and part actions round-trip through URI and JSON', () {
    for (final partId in <String?>[null, 'scheme-2:part:3']) {
      final action = WidgetRecitationAction(
        actionToken: token,
        surahId: '2',
        rotationSchemeId: 'scheme-2',
        partId: partId,
      );

      expect(WidgetRecitationAction.tryParseUri(action.uri), action);
      expect(WidgetRecitationAction.fromJson(action.toJson()), action);
      expect(action.uri.scheme, WidgetRecitationAction.uriScheme);
      expect(action.uri.host, WidgetRecitationAction.uriHost);
      expect(action.uri.queryParameters['schema'], '1');
    }
  });

  test('URI parser fails closed for malformed or extended payloads', () {
    final valid = WidgetRecitationAction(
      actionToken: token,
      surahId: '2',
      rotationSchemeId: 'scheme-2',
    ).uri.toString();
    final malformed = <String>[
      'https://recitation?schema=1&token=$token&surah=2&scheme=scheme-2',
      'murajaah-widget://other?schema=1&token=$token&surah=2&scheme=scheme-2',
      'murajaah-widget://recitation/path?schema=1&token=$token&surah=2&scheme=scheme-2',
      'murajaah-widget://recitation?schema=2&token=$token&surah=2&scheme=scheme-2',
      'murajaah-widget://recitation?schema=1&token=not-a-uuid&surah=2&scheme=scheme-2',
      'murajaah-widget://recitation?schema=1&token=$token&surah=2%2F3&scheme=scheme-2',
      '$valid&unknown=true',
      '$valid&surah=3',
      '$valid#fragment',
    ];

    for (final source in malformed) {
      expect(
        WidgetRecitationAction.tryParseUri(Uri.parse(source)),
        isNull,
        reason: source,
      );
    }
    expect(WidgetRecitationAction.tryParseUri(null), isNull);
  });

  test('factory requires UUID v4 and bounded safe identifiers', () {
    expect(
      () => WidgetRecitationAction(
        actionToken: '12345678-1234-1abc-8def-1234567890ab',
        surahId: '2',
        rotationSchemeId: 'scheme-2',
      ),
      throwsArgumentError,
    );
    expect(
      () => WidgetRecitationAction(
        actionToken: token,
        surahId: '2/3',
        rotationSchemeId: 'scheme-2',
      ),
      throwsArgumentError,
    );
    expect(
      () => WidgetRecitationAction(
        actionToken: token,
        surahId: '2',
        rotationSchemeId: List<String>.filled(129, 'x').join(),
      ),
      throwsArgumentError,
    );
  });

  test('JSON decoder rejects wrong types, versions, and unknown fields', () {
    final action = WidgetRecitationAction(
      actionToken: token,
      surahId: '2',
      rotationSchemeId: 'scheme-2',
    );
    final base = action.toJson();

    expect(
      () => WidgetRecitationAction.fromJson(<String, Object?>{
        ...base,
        'schemaVersion': 2,
      }),
      throwsFormatException,
    );
    expect(
      () => WidgetRecitationAction.fromJson(<String, Object?>{
        ...base,
        'surahId': 2,
      }),
      throwsFormatException,
    );
    expect(
      () => WidgetRecitationAction.fromJson(<String, Object?>{
        ...base,
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });
}
