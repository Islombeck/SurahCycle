package dev.murajaah.murajaah.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * His own day, 9 October 2026, as the factory builds it: seven windows, the
 * first one before Fajr belonging to last night's Isha, the one after Sunrise
 * naming no prayer at all.
 */
class PrayerBoundaryTest {
    private fun at(hour: Int, minute: Int): Long = (hour * 60L + minute) * 60_000L

    private val day =
        NativePrayerProjection(
            isAvailable = true,
            messageLabel = null,
            dateLabel = "9 октября",
            regionLabel = "Ташкент",
            providerLabel = "Namoz-vaqti.uz",
            entries =
                listOf(
                    NativePrayerEntry("Фаджр", "04:55", isBoundaryOnly = false),
                    NativePrayerEntry("Восход", "06:27", isBoundaryOnly = true),
                    NativePrayerEntry("Зухр", "12:10", isBoundaryOnly = false),
                    NativePrayerEntry("Аср", "16:07", isBoundaryOnly = false),
                    NativePrayerEntry("Магриб", "17:51", isBoundaryOnly = false),
                    NativePrayerEntry("Иша", "19:23", isBoundaryOnly = false),
                ),
            windows =
                listOf(
                    NativePrayerWindow(at(0, 0), at(4, 55), 5),
                    NativePrayerWindow(at(4, 55), at(6, 27), 0),
                    NativePrayerWindow(at(6, 27), at(12, 10), -1),
                    NativePrayerWindow(at(12, 10), at(16, 7), 2),
                    NativePrayerWindow(at(16, 7), at(17, 51), 3),
                    NativePrayerWindow(at(17, 51), at(19, 23), 4),
                    NativePrayerWindow(at(19, 23), at(24, 0), 5),
                ),
            isStale = false,
            staleLabel = null,
        )

    @Test
    fun beforeFajrTheCountdownIsToFajr() {
        assertEquals(at(4, 55), day.nextBoundaryAt(at(3, 0)))
        assertEquals(0, day.nextBoundaryIndexAt(at(3, 0)))
    }

    @Test
    fun duringFajrItCountsToSunriseWhichIsWhenFajrsTimeEnds() {
        assertEquals(at(6, 27), day.nextBoundaryAt(at(5, 0)))
        assertEquals(1, day.nextBoundaryIndexAt(at(5, 0)))
    }

    @Test
    fun betweenSunriseAndDhuhrNothingIsCurrentAndItCountsToDhuhr() {
        assertNull(day.currentIndexAt(at(10, 10)))
        assertEquals(at(12, 10), day.nextBoundaryAt(at(10, 10)))
        assertEquals(2, day.nextBoundaryIndexAt(at(10, 10)))
    }

    @Test
    fun exactlyOnABoundaryTheNewWindowHasBegun() {
        assertEquals(2, day.currentIndexAt(at(12, 10)))
        assertEquals(at(16, 7), day.nextBoundaryAt(at(12, 10)))
    }

    @Test
    fun afterIshaBeginsThereIsNoCountdownAndCertainlyNotOneToMidnight() {
        // Isha's window ends at midnight only because the snapshot covers one
        // calendar day; Isha goes on. The real next boundary is tomorrow's
        // Fajr, which this snapshot does not carry, so the honest answer is
        // none — and in particular not the window's end.
        assertNull(day.nextBoundaryAt(at(22, 0)))
        assertNull(day.nextBoundaryIndexAt(at(22, 0)))
    }

    @Test
    fun aSnapshotFromAnotherDayKnowsNothing() {
        assertNull(day.nextBoundaryAt(at(24, 30)))
        assertNull(PrayerWidgetRefresh.nextRedrawAt(day, at(24, 30)))
    }

    @Test
    fun theRedrawIsBookedAtTheEndOfTheWindowMidnightIncluded() {
        assertEquals(at(12, 10), PrayerWidgetRefresh.nextRedrawAt(day, at(10, 10)))
        // At midnight the pill must go out, so midnight *is* a redraw even
        // though it is not a countdown target.
        assertEquals(at(24, 0), PrayerWidgetRefresh.nextRedrawAt(day, at(22, 0)))
    }

    @Test
    fun nothingIsBookedWithoutASchedule() {
        val unavailable =
            day.copy(isAvailable = false, entries = emptyList(), windows = emptyList())
        assertNull(PrayerWidgetRefresh.nextRedrawAt(unavailable, at(10, 10)))
        assertNull(PrayerWidgetRefresh.nextRedrawAt(null, at(10, 10)))
    }
}
