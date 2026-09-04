import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/widget_interactivity_bootstrap.dart';
import 'package:murajaah/core/application/application.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/widgets/widgets.dart';

void main() {
  late _TrackingAppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late SurahRotationScheme scheme;

  setUp(() async {
    database = _TrackingAppDatabase();
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    await _seed(surahs);
    scheme = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScheme;
  });

  tearDown(() async {
    if (!database.didClose) await database.close();
  });

  test('success refreshes all widgets and redelivery is exact-once', () async {
    final initialAction = _action(_token(1), scheme);
    final initial = _snapshot(initialAction);
    final bridge = _MemoryWidgetBridge(
      initialJson: const WidgetSnapshotCodec().encode(initial),
    );
    var nextToken = 2;
    final handler = _handler(
      surahs: surahs,
      recitations: recitations,
      bridge: bridge,
      nextToken: () => _token(nextToken++),
    );

    final first = await handler.handle(initialAction.uri);
    final duplicate = await handler.handle(initialAction.uri);

    expect(first.status, RotationWidgetInteractionStatus.registered);
    expect(first.snapshotRefreshed, isTrue);
    expect(duplicate.status, RotationWidgetInteractionStatus.duplicate);
    expect(duplicate.snapshotRefreshed, isTrue);
    expect(await recitations.getHistory(), hasLength(1));
    expect(bridge.savedJson, hasLength(2));
    expect(bridge.rotationUpdates, 2);
    expect(bridge.learningUpdates, 2);

    final afterDuplicate = _decode(bridge.savedJson.last);
    expect(afterDuplicate.snapshotRevision, 1);
    expect(afterDuplicate.learning, initial.learning);
    final refreshedItem = afterDuplicate.rotation.items.single;
    expect(refreshedItem.isMarkedInCurrentPart, isTrue);
    expect(refreshedItem.canMark, isFalse);
    expect(refreshedItem.action, isNull);
    expect(afterDuplicate.rotation.statusMessage, isNull);
    expect(await recitations.getHistory(), hasLength(1));
  });

  test('stale action is rejected and replaced from current DB state', () async {
    final staleAction = _action(_token(1), scheme);
    await surahs.changeRotationScheme(
      surahId: 'test-a',
      proposedScheme: SurahRotationScheme.evenlySplit(
        id: 'test-a:scheme:2',
        surahId: 'test-a',
        version: scheme.version + 1,
        ayahCount: scheme.ayahCount,
        partCount: 2,
      ),
      createdAtUtc: DateTime.utc(2026, 8, 26, 9),
    );
    final bridge = _MemoryWidgetBridge(
      initialJson: const WidgetSnapshotCodec().encode(_snapshot(staleAction)),
    );
    var nextToken = 2;
    final handler = _handler(
      surahs: surahs,
      recitations: recitations,
      bridge: bridge,
      nextToken: () => _token(nextToken++),
    );

    final outcome = await handler.handle(staleAction.uri);

    expect(outcome.status, RotationWidgetInteractionStatus.rejected);
    expect(outcome.rejection, WidgetRecitationRejection.staleScheme);
    expect(outcome.snapshotRefreshed, isTrue);
    expect(await recitations.getHistory(), isEmpty);
    final refreshed = _decode(bridge.savedJson.single);
    expect(refreshed.rotation.items, hasLength(2));
    expect(
      refreshed.rotation.items.map((item) => item.action!.rotationSchemeId),
      everyElement('test-a:scheme:2'),
    );
    expect(refreshed.rotation.statusMessage, isNotEmpty);
  });

  test(
    'operation failure keeps authoritative row and reports safe state',
    () async {
      final action = _action(_token(1), scheme);
      final bridge = _MemoryWidgetBridge(
        initialJson: const WidgetSnapshotCodec().encode(_snapshot(action)),
      );
      var nextToken = 2;
      final errors = <Object>[];
      final service = RecitationApplicationService(
        surahs: surahs,
        recitations: recitations,
        prayerContextResolver: _FixedPrayerResolver(
          PrayerContext(prayerType: PrayerType.asr),
        ),
        timeProvider: const _ThrowingTimeProvider(),
        localDates: const _FixedLocalDateProvider(),
        createEventId: () => throw StateError('unused'),
      );
      final refresher = InteractiveWidgetSnapshotRefresher(
        surahs: surahs,
        recitations: recitations,
        prayerContextResolver: _FixedPrayerResolver(
          PrayerContext(prayerType: PrayerType.asr),
        ),
        timeProvider: const _FixedTimeProvider(),
        createActionToken: () => _token(nextToken++),
        localDates: const _FixedLocalDateProvider(),
        bridge: bridge,
      );
      final handler = RotationWidgetInteractionHandler(
        recitations: service,
        refresher: refresher,
        onError: (error, _) => errors.add(error),
      );

      final outcome = await handler.handle(action.uri);

      expect(outcome.status, RotationWidgetInteractionStatus.failed);
      expect(outcome.snapshotRefreshed, isTrue);
      expect(errors, hasLength(1));
      expect(await recitations.getHistory(), isEmpty);
      final refreshed = _decode(bridge.savedJson.single);
      expect(refreshed.rotation.items.single.id, scheme.id);
      expect(refreshed.rotation.items.single.remaining, 1);
      expect(refreshed.rotation.statusMessage, isNotEmpty);
    },
  );

  test(
    'malformed payload writes no event but still restores snapshot',
    () async {
      final bridge = _MemoryWidgetBridge();
      var nextToken = 2;
      final handler = _handler(
        surahs: surahs,
        recitations: recitations,
        bridge: bridge,
        nextToken: () => _token(nextToken++),
      );

      final outcome = await handler.handle(
        Uri.parse('murajaah-widget://recitation?schema=99'),
      );

      expect(outcome.status, RotationWidgetInteractionStatus.malformed);
      expect(outcome.snapshotRefreshed, isTrue);
      expect(await recitations.getHistory(), isEmpty);
      expect(_decode(bridge.savedJson.single).rotation.items, hasLength(1));
    },
  );

  test(
    'exact widget slots advance parts and refresh checked state per part',
    () async {
      final routines = PrayerRoutineRepository(database);
      final template = await routines.getTemplate(PrayerType.asr);
      await routines.replaceTemplate(
        prayerType: PrayerType.asr,
        expectedRevision: template.revision,
        displayName: template.displayName,
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          PrayerRoutinePartTemplate(
            id: 'asr-fard',
            stableKey: 'fard',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.fard,
            rakaatCount: 4,
            requiredSurahSlots: 1,
          ),
          PrayerRoutinePartTemplate(
            id: 'asr-sunnah',
            stableKey: 'sunnah-after',
            orderIndex: 1,
            kind: PrayerRoutinePartKind.sunnah,
            rakaatCount: 2,
            requiredSurahSlots: 1,
          ),
        ],
      );
      final routine = await routines.ensureCurrentSession(
        context: PrayerContext(prayerType: PrayerType.asr),
        localDate: LocalDate(2026, 8, 26),
        startedAtUtc: DateTime.utc(2026, 8, 26, 9),
      );
      final firstPart = routine!.parts.first.part;
      final initialAction = WidgetRecitationAction(
        actionToken: _token(1),
        surahId: scheme.surahId,
        rotationSchemeId: scheme.id,
        prayerSessionId: routine.session.id,
        prayerSessionPartId: firstPart.id,
        slotIndex: 0,
      );
      final bridge = _MemoryWidgetBridge(
        initialJson: const WidgetSnapshotCodec().encode(
          _snapshot(initialAction, locale: 'en'),
        ),
      );
      var nextToken = 2;
      final handler = _handler(
        surahs: surahs,
        recitations: recitations,
        bridge: bridge,
        nextToken: () => _token(nextToken++),
        prayerPartLoader: (context, localDate, localization) async {
          final current = await routines.ensureCurrentSession(
            context: context,
            localDate: localDate,
            startedAtUtc: DateTime.utc(2026, 8, 26, 10),
          );
          return localization.prayerRoutineProjection(context, current);
        },
      );

      final first = await handler.handle(initialAction.uri);

      expect(first.status, RotationWidgetInteractionStatus.registered);
      var history = await recitations.getHistory();
      expect(history, hasLength(1));
      expect(history.single.event.prayerSessionPartId, firstPart.id);
      expect(history.single.event.slotIndex, 0);
      final advanced = _decode(bridge.savedJson.last);
      expect(advanced.rotation.currentPartLabel, 'Asr · Sunnah');
      expect(advanced.rotation.slotProgressLabel, 'Surah slots: 0/1');
      final nextItem = advanced.rotation.items.single;
      expect(nextItem.isMarkedInCurrentPart, isFalse);
      expect(nextItem.canMark, isTrue);
      expect(nextItem.action!.prayerSessionId, routine.session.id);
      expect(nextItem.action!.prayerSessionPartId, routine.parts.last.part.id);
      expect(nextItem.action!.slotIndex, 0);

      final second = await handler.handle(nextItem.action!.uri);

      expect(second.status, RotationWidgetInteractionStatus.registered);
      history = await recitations.getHistory();
      expect(history, hasLength(2));
      final completed = _decode(bridge.savedJson.last);
      expect(completed.rotation.currentPartLabel, 'Prayer routine complete');
      expect(completed.rotation.slotProgressLabel, 'Surah slots: 1/1');
      expect(completed.rotation.items.single.isMarkedInCurrentPart, isTrue);
      expect(completed.rotation.items.single.canMark, isFalse);
      expect(completed.rotation.items.single.action, isNull);
    },
  );

  test(
    'background bootstrap opens only local dependencies and closes DB',
    () async {
      await PrayerRepository(database).saveSelectedContext(
        PrayerContext(prayerType: PrayerType.asr),
        updatedAtUtc: DateTime.utc(2026, 8, 26, 9),
      );
      final action = _action(_token(1), scheme);
      final bridge = _MemoryWidgetBridge();
      final errors = <Object>[];
      var factoryCalls = 0;
      var nextToken = 2;

      final outcome = await runRotationWidgetBackgroundAction(
        action.uri,
        openDatabase: () {
          factoryCalls += 1;
          return database;
        },
        bridge: bridge,
        timeProvider: const _FixedTimeProvider(),
        localDates: const _FixedLocalDateProvider(),
        createEventId: () => _token(nextToken++),
        onError: (error, stackTrace) => errors.add(error),
      );

      expect(factoryCalls, 1);
      expect(
        outcome.status,
        RotationWidgetInteractionStatus.registered,
        reason: errors.join('\n'),
      );
      expect(errors, isEmpty);
      expect(outcome.snapshotRefreshed, isTrue);
      expect(database.didClose, isTrue);
      expect(bridge.savedJson, hasLength(1));
      expect(bridge.rotationUpdates, 1);
      expect(bridge.learningUpdates, 1);
    },
  );
}

RotationWidgetInteractionHandler _handler({
  required SurahRepository surahs,
  required RecitationRepository recitations,
  required _MemoryWidgetBridge bridge,
  required String Function() nextToken,
  RotationWidgetPrayerPartLoader? prayerPartLoader,
}) {
  final resolver = _FixedPrayerResolver(
    PrayerContext(prayerType: PrayerType.asr),
  );
  return RotationWidgetInteractionHandler(
    recitations: RecitationApplicationService(
      surahs: surahs,
      recitations: recitations,
      prayerContextResolver: resolver,
      timeProvider: const _FixedTimeProvider(),
      localDates: const _FixedLocalDateProvider(),
      createEventId: () => throw StateError('unused'),
    ),
    refresher: InteractiveWidgetSnapshotRefresher(
      surahs: surahs,
      recitations: recitations,
      prayerContextResolver: resolver,
      timeProvider: const _FixedTimeProvider(),
      createActionToken: nextToken,
      localDates: const _FixedLocalDateProvider(),
      bridge: bridge,
      prayerPartLoader: prayerPartLoader,
    ),
  );
}

Future<void> _seed(SurahRepository surahs) async {
  await surahs.upsertCatalog(
    <SurahDescriptor>[
      SurahDescriptor(
        id: 'test-a',
        surahNumber: 2,
        officialName: 'Test A',
        ayahCount: 12,
      ),
    ],
    sourceId: 'verified-test-source',
    sourceVersion: 'v1',
  );
  await surahs.addMastered('test-a');
}

WidgetRecitationAction _action(String token, SurahRotationScheme scheme) =>
    WidgetRecitationAction(
      actionToken: token,
      surahId: scheme.surahId,
      rotationSchemeId: scheme.id,
    );

WidgetSnapshot _snapshot(
  WidgetRecitationAction action, {
  String locale = 'ru',
}) => WidgetSnapshot(
  generatedAtUtc: DateTime.utc(2026, 8, 26, 9),
  locale: locale,
  rotation: RotationWidgetProjection(
    contextLabel: 'Аср · Ротация',
    items: <RotationWidgetItem>[
      RotationWidgetItem(
        id: action.rotationSchemeId,
        surahId: action.surahId,
        title: '2. Test A · 12',
        remaining: 1,
        deepLink: Uri.parse('murajaah://app/surah/test-a'),
        action: action,
      ),
    ],
  ),
  learning: LearningWidgetProjection.selected(
    LearningWidgetItem(
      surahId: '112',
      surahNumber: 112,
      startAyah: 1,
      endAyah: 1,
      title: '112. Ихлас',
      stageLabel: 'Новый аят',
      rangeLabel: 'Аят 1',
      unavailableTextLabel: 'Откройте приложение',
      ayahLines: <LearningWidgetAyahLine>[
        LearningWidgetAyahLine(
          surahNumber: 112,
          ayahNumber: 1,
          arabic: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
          transliteration: 'Qul huwa All<u>a</u>hu a<u>h</u>adun',
          translation: 'Скажи: «Он — Аллах Единый»',
        ),
      ],
      deepLink: Uri.parse('murajaah://app/learning/112'),
    ),
  ),
  prayer: PrayerWidgetProjection.unavailable(messageLabel: 'Open app'),
);

WidgetSnapshot _decode(String source) {
  final result = const WidgetSnapshotCodec().decode(source);
  expect(result, isA<WidgetSnapshotDecoded>());
  return (result as WidgetSnapshotDecoded).snapshot;
}

String _token(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

final class _MemoryWidgetBridge implements WidgetSnapshotBridge {
  _MemoryWidgetBridge({String? initialJson}) : _currentJson = initialJson;

  String? _currentJson;
  final List<String> savedJson = <String>[];
  int rotationUpdates = 0;
  int learningUpdates = 0;

  @override
  Future<String?> loadSnapshotJson() async => _currentJson;

  @override
  Future<bool> saveSnapshotIfCurrent(
    WidgetSnapshot snapshot,
    String json,
  ) async {
    final current = const WidgetSnapshotCodec().decode(_currentJson);
    if (current is WidgetSnapshotDecoded &&
        current.snapshot.snapshotRevision > snapshot.snapshotRevision) {
      return false;
    }
    _currentJson = json;
    savedJson.add(json);
    return true;
  }

  @override
  Future<void> updateLearningWidget() async {
    learningUpdates += 1;
  }

  @override
  Future<void> updateRotationWidget() async {
    rotationUpdates += 1;
  }
}

final class _FixedPrayerResolver implements RecitationPrayerContextResolver {
  const _FixedPrayerResolver(this.context);

  final PrayerContext? context;

  @override
  Future<PrayerContext?> resolve() async => context;
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 26, 10);
}

final class _ThrowingTimeProvider implements TimeProvider {
  const _ThrowingTimeProvider();

  @override
  DateTime nowUtc() => throw StateError('clock unavailable');
}

final class _FixedLocalDateProvider implements RecitationLocalDateProvider {
  const _FixedLocalDateProvider();

  @override
  LocalDate today() => LocalDate(2026, 8, 26);
}

final class _TrackingAppDatabase extends AppDatabase {
  _TrackingAppDatabase() : super(NativeDatabase.memory());

  bool didClose = false;

  @override
  Future<void> close() {
    didClose = true;
    return super.close();
  }
}
