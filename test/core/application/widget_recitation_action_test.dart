import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/application/widget_recitation_action.dart';

void main() {
  const token = '12345678-1234-4abc-8def-1234567890ab';

  test('schema 2 actions round-trip with optional exact prayer slot', () {
    for (final target in <({String? partId, bool exactSlot})>[
      (partId: null, exactSlot: false),
      (partId: 'scheme-2:part:3', exactSlot: true),
    ]) {
      final action = WidgetRecitationAction(
        actionToken: token,
        surahId: '2',
        rotationSchemeId: 'scheme-2',
        partId: target.partId,
        prayerSessionId: target.exactSlot ? 'session-2' : null,
        prayerSessionPartId: target.exactSlot ? 'session-2:fard' : null,
        slotIndex: target.exactSlot ? 1 : null,
      );

      expect(WidgetRecitationAction.tryParseUri(action.uri), action);
      expect(WidgetRecitationAction.fromJson(action.toJson()), action);
      expect(action.uri.scheme, WidgetRecitationAction.uriScheme);
      expect(action.uri.host, WidgetRecitationAction.uriHost);
      expect(action.uri.queryParameters['schema'], '2');
      expect(action.hasExactPrayerSlot, target.exactSlot);
    }
  });

  test('legacy schema 1 URI and JSON remain readable', () {
    final uri = Uri.parse(
      'murajaah-widget://recitation?schema=1&token=$token&surah=2&scheme=scheme-2',
    );
    final fromUri = WidgetRecitationAction.tryParseUri(uri);
    final fromJson = WidgetRecitationAction.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'actionToken': token,
      'surahId': '2',
      'rotationSchemeId': 'scheme-2',
    });

    expect(fromUri, fromJson);
    expect(fromUri!.hasExactPrayerSlot, isFalse);
    expect(fromUri.toJson()['schemaVersion'], 2);
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
      'murajaah-widget://recitation?schema=3&token=$token&surah=2&scheme=scheme-2',
      'murajaah-widget://recitation?schema=2&token=$token&surah=2&scheme=scheme-2&session=session-2',
      'murajaah-widget://recitation?schema=2&token=$token&surah=2&scheme=scheme-2&session=session-2&sessionPart=session-2:fard&slot=-1',
      'murajaah-widget://recitation?schema=1&token=$token&surah=2&scheme=scheme-2&slot=0',
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
        surahId: '2',
        rotationSchemeId: 'scheme-2',
        prayerSessionId: 'session-2',
      ),
      throwsArgumentError,
    );
    expect(
      () => WidgetRecitationAction(
        actionToken: token,
        surahId: '2',
        rotationSchemeId: 'scheme-2',
        prayerSessionId: 'session-2',
        prayerSessionPartId: 'session-2:fard',
        slotIndex: maxWidgetPrayerSlotIndex + 1,
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
        'schemaVersion': 3,
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
    expect(
      () => WidgetRecitationAction.fromJson(<String, Object?>{
        ...base,
        'prayerSessionId': 'session-2',
      }),
      throwsFormatException,
    );
    expect(
      () => WidgetRecitationAction.fromJson(<String, Object?>{
        ...base,
        'slotIndex': '0',
      }),
      throwsFormatException,
    );
  });
}
