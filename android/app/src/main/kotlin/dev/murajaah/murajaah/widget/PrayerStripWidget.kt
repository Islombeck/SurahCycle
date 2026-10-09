package dev.murajaah.murajaah.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity

// One launcher row: six names over six times.
private val SLIM_SIZE = DpSize(240.dp, 40.dp)

// Tall enough for the line above them: the countdown and the region.
private val HEADED_SIZE = DpSize(240.dp, 50.dp)

// Wide enough for the times to be read at a glance rather than deciphered.
private val ROOMY_WIDTH = 320.dp

private val SURFACE = Color(0xFFEFF3F6)
private val INK = Color(0xFF22303B)
private val MUTED = Color(0xFF5A6873)
private val PILL = Color(0xFF2F5D73)
private val ON_PILL = Color(0xFFFFFFFF)

/**
 * The prayer schedule as one horizontal strip — the shape of the strip under
 * the prayer card on Home, made to fit a launcher row.
 *
 * Same projection, same rule as [PrayerWidget]: Kotlin compares the clock
 * with windows Dart built and decides nothing about prayer. In particular,
 * between Sunrise and Dhuhr **nothing** is on the pill, because no prayer is
 * current then; the countdown still runs, to Dhuhr.
 *
 * Read-only. The whole surface opens Home and nothing here writes.
 */
class PrayerStripWidget : GlanceAppWidget(errorUiLayout = R.layout.widget_error) {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()
    override val sizeMode = SizeMode.Responsive(setOf(SLIM_SIZE, HEADED_SIZE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(context, currentState()) }
    }

    override fun onCompositionError(
        context: Context,
        glanceId: GlanceId,
        appWidgetId: Int,
        throwable: Throwable,
    ) {
        logWidgetCompositionError(
            context = context,
            widgetType = "PrayerStripWidget",
            appWidgetId = appWidgetId,
            throwable = throwable,
        )
        super.onCompositionError(context, glanceId, appWidgetId, throwable)
        installWidgetErrorClick(context, appWidgetId, Uri.parse("murajaah://app/home"))
    }

    @Composable
    private fun Content(context: Context, state: HomeWidgetGlanceState) {
        val snapshot =
            NativeWidgetSnapshotParser.parse(
                state.preferences.getString(WIDGET_SNAPSHOT_KEY, null)
            )
        val homeAction =
            actionStartActivity<MainActivity>(context, Uri.parse("murajaah://app/home"))
        val prayer = snapshot?.prayer
        val size = LocalSize.current
        val headed = size.height >= HEADED_SIZE.height

        Column(
            modifier =
                GlanceModifier.fillMaxSize()
                    .background(SURFACE)
                    .cornerRadius(16.dp)
                    .clickable(homeAction)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            if (prayer == null || !prayer.isAvailable) {
                Message(prayer?.messageLabel ?: context.getString(R.string.widget_open_murajaah))
                return@Column
            }
            // Without its header the strip has nowhere to say the times may be
            // wrong, and six confident times under no warning is worse than
            // the warning alone.
            if (prayer.isStale && !headed) {
                Message(prayer.staleLabel ?: context.getString(R.string.prayer_widget_stale))
                return@Column
            }
            // Read once per composition, and the only clock reading there is.
            val nowUtcMs = System.currentTimeMillis()
            if (headed) Header(context, prayer, nowUtcMs)
            Cells(
                prayer,
                currentIndex = prayer.currentIndexAt(nowUtcMs),
                boundaryIndex = prayer.nextBoundaryIndexAt(nowUtcMs),
                roomy = size.width >= ROOMY_WIDTH,
            )
        }
    }

    @Composable
    private fun Message(text: String) {
        Text(text, style = TextStyle(fontSize = 13.sp, color = ColorProvider(INK)), maxLines = 2)
    }

    @Composable
    private fun Header(context: Context, prayer: NativePrayerProjection, nowUtcMs: Long) {
        AndroidRemoteViews(
            header(context, prayer, nowUtcMs),
            modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 2.dp),
        )
    }

    /**
     * The top line as one platform layout (`prayer_strip_header.xml`).
     *
     * The first version put a Glance `Text` beside the countdown and the
     * region never appeared on his phone. The countdown has to be a platform
     * `Chronometer` — the only widget text that changes by itself — and the
     * region has to ellipsize, which Glance text cannot; one layout owns both
     * and leaves nothing to how Glance sizes a foreign view in a row.
     *
     * The `Chronometer` does not stop at zero; [PrayerWidgetRefresh] is what
     * replaces this line at the boundary.
     */
    private fun header(context: Context, prayer: NativePrayerProjection, nowUtcMs: Long): RemoteViews =
        RemoteViews(context.packageName, R.layout.prayer_strip_header).apply {
            setTextViewText(R.id.prayer_strip_region, prayer.regionLabel ?: "")
            val boundaryAt = prayer.nextBoundaryAt(nowUtcMs)
            val boundaryIndex = prayer.nextBoundaryIndexAt(nowUtcMs)
            if (!prayer.isStale && boundaryAt != null && boundaryIndex != null) {
                setChronometer(
                    R.id.prayer_strip_countdown,
                    SystemClock.elapsedRealtime() + (boundaryAt - nowUtcMs),
                    // The label is the app's own text; a stray % in it must not
                    // be read as a format directive by the Chronometer.
                    context.getString(
                        R.string.prayer_strip_countdown,
                        prayer.entries[boundaryIndex].label.replace("%", "%%"),
                    ),
                    true,
                )
                setChronometerCountDown(R.id.prayer_strip_countdown, true)
                setViewVisibility(R.id.prayer_strip_countdown, View.VISIBLE)
                setViewVisibility(R.id.prayer_strip_lead, View.GONE)
            } else {
                val lead =
                    if (prayer.isStale) {
                        prayer.staleLabel ?: context.getString(R.string.prayer_widget_stale)
                    } else {
                        // After Isha begins the next boundary is tomorrow's
                        // Fajr, which this snapshot does not carry; the date
                        // says which day these times are for.
                        prayer.dateLabel ?: ""
                    }
                setTextViewText(R.id.prayer_strip_lead, lead)
                setViewVisibility(R.id.prayer_strip_lead, View.VISIBLE)
                setViewVisibility(R.id.prayer_strip_countdown, View.GONE)
            }
        }

    @Composable
    private fun Cells(
        prayer: NativePrayerProjection,
        currentIndex: Int?,
        boundaryIndex: Int?,
        roomy: Boolean,
    ) {
        Spacer(GlanceModifier.height(1.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            prayer.entries.forEachIndexed { index, entry ->
                val isCurrent = index == currentIndex
                // Bold is "what the countdown counts to", so the line above and
                // the row agree — including Sunrise, the end of Fajr's time.
                val isNext = index == boundaryIndex
                var cell = GlanceModifier.defaultWeight()
                if (isCurrent) cell = cell.background(PILL).cornerRadius(10.dp)
                Column(
                    modifier = cell.padding(vertical = 1.dp),
                    horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
                ) {
                    Text(
                        entry.label,
                        style =
                            TextStyle(
                                fontSize = if (roomy) 11.sp else 10.sp,
                                color = ColorProvider(if (isCurrent) ON_PILL else MUTED),
                                textAlign = TextAlign.Center,
                            ),
                        maxLines = 1,
                    )
                    Text(
                        entry.timeLabel,
                        style =
                            TextStyle(
                                fontSize = if (roomy) 15.sp else 13.sp,
                                fontWeight =
                                    if (isCurrent || isNext) FontWeight.Bold else FontWeight.Medium,
                                color = ColorProvider(if (isCurrent) ON_PILL else INK),
                                textAlign = TextAlign.Center,
                            ),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

class PrayerStripWidgetReceiver : HomeWidgetGlanceWidgetReceiver<PrayerStripWidget>() {
    override val glanceAppWidget = PrayerStripWidget()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        PrayerWidgetRefresh.reschedule(context, PrayerStripWidgetReceiver::class.java)
    }

    override fun onDisabled(context: Context) {
        PrayerWidgetRefresh.cancel(context, PrayerStripWidgetReceiver::class.java)
        super.onDisabled(context)
    }
}
