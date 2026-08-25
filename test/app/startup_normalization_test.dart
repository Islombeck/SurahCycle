import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup deactivates legacy Fatiha once without changing history or stats',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final surahs = SurahRepository(database);
      const fatihaId = 'surah-1';
      await surahs.upsertCatalog(<SurahDescriptor>[
        SurahDescriptor(
          id: fatihaId,
          surahNumber: 1,
          officialName: 'Fatiha fixture',
          ayahCount: 7,
        ),
      ]);
      await surahs.addMastered(fatihaId);
      final scheme = (await surahs.getRotationSnapshot())
          .surahById(fatihaId)
          .rotationScheme;
      final usedAt = DateTime.utc(2026, 8, 20, 5);

      await database.transaction(() async {
        await (database.update(
          database.masteredSurahs,
        )..where((row) => row.surahId.equals(fatihaId))).write(
          MasteredSurahsCompanion(
            isActive: const Value<bool>(true),
            hasEnteredRotation: const Value<bool>(true),
            activationBaselineScore: const Value<int?>(0),
            cachedRotationScore: const Value<int>(1),
            cachedTotalRecitations: const Value<int>(1),
            cachedLastUsedAtUtc: Value<DateTime?>(usedAt),
          ),
        );
        await (database.update(
          database.rotationParts,
        )..where((row) => row.id.equals(scheme.parts.single.id))).write(
          RotationPartsCompanion(
            cachedScore: const Value<int>(1),
            cachedRecitationCount: const Value<int>(1),
            cachedLastUsedAtUtc: Value<DateTime?>(usedAt),
          ),
        );
        await database
            .into(database.recitationEvents)
            .insert(
              RecitationEventsCompanion.insert(
                id: 'legacy-fatiha-event',
                journalSequence: 1,
                surahId: fatihaId,
                rotationSchemeId: scheme.id,
                rakaatSpanCount: 1,
                createdAtUtc: usedAt,
                localDate: '2026-08-20',
                prayerType: PrayerType.fajr.name,
              ),
            );
        await database
            .into(database.recitationEventParts)
            .insert(
              RecitationEventPartsCompanion.insert(
                eventId: 'legacy-fatiha-event',
                schemeId: scheme.id,
                partId: scheme.parts.single.id,
              ),
            );
        await (database.update(
          database.rotationStates,
        )..where((row) => row.singletonId.equals(1))).write(
          const RotationStatesCompanion(lastJournalSequence: Value<int>(1)),
        );
      });

      final recitations = RecitationRepository(database);
      final historyBefore = await recitations.getHistory();
      final statsBefore = await recitations.getStats();
      final timeProvider = _MutableTimeProvider(DateTime.utc(2026, 8, 25, 12));
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          timeProviderProvider.overrideWithValue(timeProvider),
        ],
      );
      addTearDown(container.dispose);

      await container.read(startupProvider.future);

      final row = await (database.select(
        database.masteredSurahs,
      )..where((table) => table.surahId.equals(fatihaId))).getSingle();
      expect(row.isActive, isFalse);
      expect(row.hasEnteredRotation, isTrue);
      expect(row.cachedRotationScore, 1);
      expect(row.cachedTotalRecitations, 1);
      expect(
        _historyFingerprint(await recitations.getHistory()),
        _historyFingerprint(historyBefore),
      );
      expect(
        _statsFingerprint(await recitations.getStats()),
        _statsFingerprint(statsBefore),
      );
      expect(
        await AppSettingsRepository(
          database,
        ).getBool('rotation_exclusions_v1_normalized'),
        isTrue,
      );

      final markerBefore =
          await (database.select(database.appSettings)..where(
                (table) =>
                    table.key.equals('rotation_exclusions_v1_normalized'),
              ))
              .getSingle();
      timeProvider.value = DateTime.utc(2026, 8, 26, 12);
      container.invalidate(startupProvider);
      await container.read(startupProvider.future);
      final markerAfter =
          await (database.select(database.appSettings)..where(
                (table) =>
                    table.key.equals('rotation_exclusions_v1_normalized'),
              ))
              .getSingle();

      expect(markerAfter.updatedAtUtc, markerBefore.updatedAtUtc);
      expect(
        _historyFingerprint(await recitations.getHistory()),
        _historyFingerprint(historyBefore),
      );
      expect(
        _statsFingerprint(await recitations.getStats()),
        _statsFingerprint(statsBefore),
      );
    },
  );
}

List<Object?> _historyFingerprint(List<RecitationHistoryEntry> entries) =>
    entries
        .map<Object?>(
          (entry) => <Object?>[
            entry.event.id,
            entry.event.surahId,
            entry.event.rotationSchemeId,
            entry.event.rakaatSpanCount,
            entry.event.createdAtUtc,
            entry.event.localDate,
            entry.event.prayerType,
            entry.event.isQada,
            entry.event.coveredPartIds,
            entry.surah.id,
            entry.journalSequence,
            entry.coveredParts.map((part) => part.id).toList(growable: false),
            entry.isWholeSurah,
          ],
        )
        .toList(growable: false);

List<Object?> _statsFingerprint(RecitationStats stats) => <Object?>[
  stats.total,
  stats.actionCount,
  stats.bySurah
      .map<Object?>(
        (entry) => <Object?>[
          entry.surah.id,
          entry.count,
          entry.actionCount,
          entry.lastUsedAtUtc,
          entry.byPrayer,
          entry.byPart,
        ],
      )
      .toList(growable: false),
  stats.byPrayer
      .map<Object?>(
        (entry) => <Object?>[entry.context, entry.count, entry.actionCount],
      )
      .toList(growable: false),
];

final class _MutableTimeProvider implements TimeProvider {
  _MutableTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
