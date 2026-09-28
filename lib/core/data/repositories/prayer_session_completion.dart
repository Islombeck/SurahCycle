/// Whether a part of a prayer is finished, decided in exactly one place.
///
/// A part is complete when every surah slot it asks for is filled by a
/// recitation that still stands. That sentence is the tick on Home, the day's
/// state in the calendar, and the condition the Isha→Witr transition waits on
/// — all three read `completed_at_utc`, so all three are wrong together when
/// it is wrong.
///
/// It lives here rather than inside `RecitationRepository` because two callers
/// need it and only one had it. Recording a prayer on this phone reconciled
/// the part; **applying one that arrived from another phone did not**, so a
/// slot could be filled while the part stayed open: 2 of 2 on the screen, no
/// tick, a day the calendar called partly done, and an Isha that never moved
/// on to Witr. Reported by the owner from ordinary use on two phones.
///
/// A second implementation would have been free to disagree with the first,
/// which is the whole reason this is a function and not a copy.
library;

import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

abstract final class PrayerSessionCompletion {
  /// Recomputes whether [partId] is finished, from the recitations it holds.
  ///
  /// Call inside the transaction that changed them. Safe on a part that does
  /// not exist, asks for no slots, or was finished by following the imam —
  /// that last one is a statement about what happened, not a count, and
  /// nothing here may overwrite it.
  static Future<void> reconcile(AppDatabase database, String partId) async {
    final part =
        await (database.select(database.prayerSessionParts)
              ..where((PrayerSessionParts row) => row.id.equals(partId)))
            .getSingleOrNull();
    if (part == null || part.requiredSurahSlots == 0) return;
    if (part.completionMode == PrayerPartCompletionMode.followedImam.name &&
        part.completedAtUtc != null) {
      return;
    }

    final activeSlotEvents =
        await (database.select(database.recitationEvents)..where(
              (RecitationEvents row) =>
                  row.prayerSessionPartId.equals(partId) &
                  row.slotIndex.isNotNull() &
                  row.deletedAtUtc.isNull(),
            ))
            .get();
    if (activeSlotEvents.length < part.requiredSurahSlots) {
      // Fewer than it needs: if this part had been counted finished, it is not
      // any more. Only a part completed *by recitations* is reopened — see
      // above for why following the imam is left alone.
      if (part.completionMode == PrayerPartCompletionMode.recitations.name &&
          part.completedAtUtc != null) {
        await (database.update(
          database.prayerSessionParts,
        )..where((PrayerSessionParts row) => row.id.equals(partId))).write(
          const PrayerSessionPartsCompanion(
            completedAtUtc: Value<DateTime?>(null),
          ),
        );
      }
      return;
    }

    // Dated by the last recitation that filled it, not by now: the prayer was
    // finished when it was finished, and a phone that hears about it a day
    // later must not restate when it happened.
    final completedAtUtc = activeSlotEvents
        .map((RecitationEventRow row) => row.createdAtUtc.toUtc())
        .reduce(
          (DateTime left, DateTime right) => left.isAfter(right) ? left : right,
        );
    await (database.update(
      database.prayerSessionParts,
    )..where((PrayerSessionParts row) => row.id.equals(partId))).write(
      PrayerSessionPartsCompanion(
        completionMode: Value<String>(
          PrayerPartCompletionMode.recitations.name,
        ),
        completedAtUtc: Value<DateTime?>(completedAtUtc),
      ),
    );
  }
}
