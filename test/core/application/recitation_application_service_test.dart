import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/application/application.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'fatiha',
          surahNumber: 1,
          officialName: 'Al-Fatiha',
          ayahCount: 7,
        ),
        SurahDescriptor(
          id: 'test-a',
          surahNumber: 2,
          officialName: 'Test A',
          ayahCount: 12,
        ),
        SurahDescriptor(
          id: 'test-b',
          surahNumber: 3,
          officialName: 'Test B',
          ayahCount: 8,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'v1',
    );
    await surahs.addMastered('test-a');
    await surahs.addMastered('test-b');
    await surahs.addMastered('fatiha');
  });

  tearDown(() => database.close());

  test('whole widget action uses token as event ID and shared rules', () async {
    final scheme = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScheme;
    final service = _service(surahs, recitations);
    final action = _action(token: _token(1), scheme: scheme);

    final result = await service.registerFromWidget(action);

    expect(result, isA<WidgetRecitationRegistered>());
    final registration = (result as WidgetRecitationRegistered).registration;
    expect(registration.event.id, action.actionToken);
    expect(registration.event.rotationSchemeId, scheme.id);
    expect(registration.event.coveredPartIds, <String>[scheme.parts.single.id]);
    expect(registration.event.rakaatSpanCount, 1);
    expect(registration.event.prayerType, PrayerType.asr);
    expect(registration.event.localDate, LocalDate(2026, 8, 26));
    expect(
      (await recitations.getHistory()).single.event.id,
      action.actionToken,
    );
  });

  test('same token is exact-once and a refreshed token marks again', () async {
    final scheme = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScheme;
    final service = _service(surahs, recitations);
    final first = _action(token: _token(1), scheme: scheme);
    final next = _action(token: _token(2), scheme: scheme);

    expect(
      await service.registerFromWidget(first),
      isA<WidgetRecitationRegistered>(),
    );
    expect(
      await service.registerFromWidget(first),
      isA<WidgetRecitationDuplicate>(),
    );
    expect(
      await service.registerFromWidget(next),
      isA<WidgetRecitationRegistered>(),
    );

    final history = await recitations.getHistory();
    expect(history, hasLength(2));
    expect(history.map((entry) => entry.event.id).toSet(), <String>{
      first.actionToken,
      next.actionToken,
    });
  });

  test('split widget action credits exactly its current part', () async {
    final original = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScheme;
    final changed = await surahs.changeRotationScheme(
      surahId: 'test-a',
      proposedScheme: SurahRotationScheme.evenlySplit(
        id: 'test-a:scheme:2',
        surahId: 'test-a',
        version: original.version + 1,
        ayahCount: original.ayahCount,
        partCount: 3,
      ),
      createdAtUtc: DateTime.utc(2026, 8, 26, 8),
    );
    final scheme = changed.surahById('test-a').rotationScheme;
    final targetPart = scheme.parts[1];

    final result = await _service(surahs, recitations).registerFromWidget(
      _action(token: _token(3), scheme: scheme, partId: targetPart.id),
    );

    expect(result, isA<WidgetRecitationRegistered>());
    final event = (result as WidgetRecitationRegistered).registration.event;
    expect(event.coveredPartIds, <String>[targetPart.id]);
    expect(event.rakaatSpanCount, 1);
  });

  test('stale scheme and invalid part fail closed without writes', () async {
    final oldScheme = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScheme;
    final changed = await surahs.changeRotationScheme(
      surahId: 'test-a',
      proposedScheme: SurahRotationScheme.evenlySplit(
        id: 'test-a:scheme:2',
        surahId: 'test-a',
        version: oldScheme.version + 1,
        ayahCount: oldScheme.ayahCount,
        partCount: 2,
      ),
      createdAtUtc: DateTime.utc(2026, 8, 26, 8),
    );
    final current = changed.surahById('test-a').rotationScheme;
    final service = _service(surahs, recitations);

    final stale = await service.registerFromWidget(
      _action(token: _token(4), scheme: oldScheme),
    );
    final invalidPart = await service.registerFromWidget(
      _action(
        token: _token(5),
        scheme: current,
        partId: 'test-a:scheme:2:part:99',
      ),
    );

    expect(
      (stale as WidgetRecitationRejected).reason,
      WidgetRecitationRejection.staleScheme,
    );
    expect(
      (invalidPart as WidgetRecitationRejected).reason,
      WidgetRecitationRejection.invalidPart,
    );
    expect(await recitations.getHistory(), isEmpty);
  });

  test(
    'inactive, Fatiha, unknown surah, and no context are rejected',
    () async {
      final snapshot = await surahs.getRotationSnapshot();
      final schemeA = snapshot.surahById('test-a').rotationScheme;
      final schemeB = snapshot.surahById('test-b').rotationScheme;
      final fatihaScheme = snapshot.surahById('fatiha').rotationScheme;
      await surahs.setActive('test-b', isActive: false);
      final service = _service(surahs, recitations);

      final inactive = await service.registerFromWidget(
        _action(token: _token(6), scheme: schemeB, surahId: 'test-b'),
      );
      final fatiha = await service.registerFromWidget(
        _action(token: _token(7), scheme: fatihaScheme, surahId: 'fatiha'),
      );
      final unknown = await service.registerFromWidget(
        WidgetRecitationAction(
          actionToken: _token(8),
          surahId: 'unknown',
          rotationSchemeId: 'unknown:scheme',
        ),
      );
      final noContext = await _service(
        surahs,
        recitations,
        contextAvailable: false,
      ).registerFromWidget(_action(token: _token(9), scheme: schemeA));

      expect(
        (inactive as WidgetRecitationRejected).reason,
        WidgetRecitationRejection.inactiveSurah,
      );
      expect(
        (fatiha as WidgetRecitationRejected).reason,
        WidgetRecitationRejection.fatihaExcluded,
      );
      expect(
        (unknown as WidgetRecitationRejected).reason,
        WidgetRecitationRejection.unknownSurah,
      );
      expect(
        (noContext as WidgetRecitationRejected).reason,
        WidgetRecitationRejection.unknownPrayerContext,
      );
      expect(await recitations.getHistory(), isEmpty);
    },
  );

  test(
    'historical app registration separates entry time from occurrence day',
    () async {
      var nextId = 100;
      final service = RecitationApplicationService(
        surahs: surahs,
        recitations: recitations,
        prayerContextResolver: _FixedPrayerContextResolver(
          PrayerContext(prayerType: PrayerType.asr),
        ),
        timeProvider: const _FixedTimeProvider(),
        localDates: const _FixedLocalDateProvider(),
        createEventId: () => _token(nextId++),
      );

      final witr = await service.registerFromApp(
        surahId: 'test-a',
        prayerContext: PrayerContext(prayerType: PrayerType.witr),
        occurrenceLocalDate: LocalDate(2026, 8, 25),
      );
      final fajr = await service.registerFromApp(
        surahId: 'test-a',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        occurrenceLocalDate: LocalDate(2026, 8, 24),
      );
      final qada = await service.registerFromApp(
        surahId: 'test-a',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr, isQada: true),
        occurrenceLocalDate: LocalDate(2026, 8, 23),
      );

      for (final registration in <RecitationRegistration>[witr, fajr, qada]) {
        expect(registration.event.createdAtUtc, DateTime.utc(2026, 8, 26, 10));
      }
      expect(witr.event.localDate, LocalDate(2026, 8, 25));
      expect(witr.event.prayerType, PrayerType.witr);
      expect(witr.event.isQada, isFalse);
      expect(fajr.event.localDate, LocalDate(2026, 8, 24));
      expect(fajr.event.isQada, isFalse);
      expect(qada.event.localDate, LocalDate(2026, 8, 23));
      expect(qada.event.isQada, isTrue);

      final history = await recitations.getHistory();
      expect(history, hasLength(3));
      expect(history.map((entry) => entry.event.localDate).toSet(), <LocalDate>{
        LocalDate(2026, 8, 23),
        LocalDate(2026, 8, 24),
        LocalDate(2026, 8, 25),
      });
      expect(
        history.map((entry) => entry.event.createdAtUtc).toSet(),
        <DateTime>{DateTime.utc(2026, 8, 26, 10)},
      );
    },
  );

  test('app registration remains backward-compatible with today', () async {
    final service = RecitationApplicationService(
      surahs: surahs,
      recitations: recitations,
      prayerContextResolver: _FixedPrayerContextResolver(
        PrayerContext(prayerType: PrayerType.asr),
      ),
      timeProvider: const _FixedTimeProvider(),
      localDates: const _FixedLocalDateProvider(),
      createEventId: () => _token(200),
    );

    final registration = await service.registerFromApp(
      surahId: 'test-a',
      prayerContext: PrayerContext(prayerType: PrayerType.dhuhr),
    );

    expect(registration.event.localDate, LocalDate(2026, 8, 26));
  });
}

RecitationApplicationService _service(
  SurahRepository surahs,
  RecitationRepository recitations, {
  bool contextAvailable = true,
}) => RecitationApplicationService(
  surahs: surahs,
  recitations: recitations,
  prayerContextResolver: _FixedPrayerContextResolver(
    contextAvailable ? PrayerContext(prayerType: PrayerType.asr) : null,
  ),
  timeProvider: const _FixedTimeProvider(),
  localDates: const _FixedLocalDateProvider(),
  createEventId: () => throw StateError('Widget actions own their event ID.'),
);

WidgetRecitationAction _action({
  required String token,
  required SurahRotationScheme scheme,
  String? surahId,
  String? partId,
}) => WidgetRecitationAction(
  actionToken: token,
  surahId: surahId ?? scheme.surahId,
  rotationSchemeId: scheme.id,
  partId: partId,
);

String _token(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

final class _FixedPrayerContextResolver
    implements RecitationPrayerContextResolver {
  const _FixedPrayerContextResolver(this.value);

  final PrayerContext? value;

  @override
  Future<PrayerContext?> resolve() async => value;
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 26, 10);
}

final class _FixedLocalDateProvider implements RecitationLocalDateProvider {
  const _FixedLocalDateProvider();

  @override
  LocalDate today() => LocalDate(2026, 8, 26);
}
