package dev.murajaah.murajaah.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
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
import androidx.glance.text.TextStyle
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity

private val COMPACT_SIZE = DpSize(150.dp, 100.dp)
private val MEDIUM_SIZE = DpSize(250.dp, 180.dp)
private val LARGE_SIZE = DpSize(250.dp, 320.dp)

class PrayerWidget : GlanceAppWidget(errorUiLayout = R.layout.widget_error) {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()
    override val sizeMode = SizeMode.Responsive(setOf(COMPACT_SIZE, MEDIUM_SIZE, LARGE_SIZE))

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
            widgetType = "PrayerWidget",
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

        Column(
            modifier =
                GlanceModifier.fillMaxSize()
                    .background(Color(0xFFEFF3F6))
                    .cornerRadius(22.dp)
                    .clickable(homeAction)
                    .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                context.getString(R.string.prayer_widget_title),
                style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold),
                maxLines = 1,
            )
            if (prayer == null || !prayer.isAvailable) {
                Spacer(GlanceModifier.height(6.dp))
                Text(
                    prayer?.messageLabel ?: context.getString(R.string.widget_open_murajaah),
                    style = TextStyle(fontSize = 13.sp),
                    maxLines = 3,
                )
                return@Column
            }
            if (prayer.isStale) {
                Spacer(GlanceModifier.height(2.dp))
                Text(
                    prayer.staleLabel ?: context.getString(R.string.prayer_widget_stale),
                    style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium),
                    maxLines = 2,
                )
            }
            // Read once per composition, and the only clock reading there is.
            // Which row is current follows from it and the windows; nothing
            // here decides anything about prayer.
            val nowUtcMs = System.currentTimeMillis()
            val currentIndex = prayer.currentIndexAt(nowUtcMs)
            val nextIndex = prayer.nextIndexAt(nowUtcMs)
            when {
                size.width < MEDIUM_SIZE.width ->
                    CompactBody(context, prayer, currentIndex, nextIndex)
                size.height < LARGE_SIZE.height ->
                    MediumBody(context, prayer, currentIndex, nextIndex)
                else -> LargeBody(context, prayer, currentIndex, nextIndex)
            }
        }
    }

    @Composable
    private fun CompactBody(
        context: Context,
        prayer: NativePrayerProjection,
        currentIndex: Int?,
        nextIndex: Int?,
    ) {
        Spacer(GlanceModifier.height(4.dp))
        Text(
            currentIndex?.let { prayer.entries[it].label }
                ?: context.getString(R.string.prayer_widget_between),
            style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        nextIndex?.let { index ->
            val next = prayer.entries[index]
            Text(
                context.getString(
                    R.string.prayer_widget_next_at,
                    next.label,
                    next.timeLabel,
                ),
                style = TextStyle(fontSize = 12.sp),
                maxLines = 1,
            )
        }
        Text(prayer.regionLabel ?: "", style = TextStyle(fontSize = 11.sp), maxLines = 1)
    }

    // Glance renders at most ten children per Row or Column and drops the rest
    // without a word (LayoutSelection: "container cannot have more than 10
    // elements"). Six rows emitted straight into the widget's root column, with
    // the title and spacers around them, came to eleven and twelve — and what
    // fell off the end was the region line, in both of these sizes, since the
    // day this widget shipped. The rows live in a column of their own.
    @Composable
    private fun MediumBody(
        context: Context,
        prayer: NativePrayerProjection,
        currentIndex: Int?,
        nextIndex: Int?,
    ) {
        Spacer(GlanceModifier.height(4.dp))
        PrayerRows {
            prayer.entries.forEachIndexed { index, entry ->
                if (entry.isBoundaryOnly) return@forEachIndexed
                PrayerRow(entry, secondary = false, index, currentIndex, nextIndex)
            }
            val sunriseIndex = prayer.entries.indexOfFirst { it.isBoundaryOnly }
            if (sunriseIndex >= 0) {
                Spacer(GlanceModifier.height(2.dp))
                PrayerRow(
                    prayer.entries[sunriseIndex],
                    secondary = true,
                    sunriseIndex,
                    currentIndex,
                    nextIndex,
                )
            }
        }
        Spacer(GlanceModifier.height(4.dp))
        Text(prayer.regionLabel ?: "", style = TextStyle(fontSize = 11.sp), maxLines = 1)
    }

    @Composable
    private fun PrayerRows(content: @Composable () -> Unit) {
        Column(modifier = GlanceModifier.fillMaxWidth()) { content() }
    }

    @Composable
    private fun LargeBody(
        context: Context,
        prayer: NativePrayerProjection,
        currentIndex: Int?,
        nextIndex: Int?,
    ) {
        Spacer(GlanceModifier.height(4.dp))
        Text(
            prayer.dateLabel ?: "",
            style = TextStyle(fontSize = 12.sp),
            maxLines = 1,
        )
        Spacer(GlanceModifier.height(4.dp))
        PrayerRows {
            prayer.entries.forEachIndexed { index, entry ->
                PrayerRow(entry, entry.isBoundaryOnly, index, currentIndex, nextIndex)
            }
        }
        Spacer(GlanceModifier.height(6.dp))
        Text(
            listOfNotNull(prayer.regionLabel, prayer.providerLabel)
                .joinToString(" · "),
            style = TextStyle(fontSize = 11.sp),
            maxLines = 1,
        )
    }

    @Composable
    private fun PrayerRow(
        entry: NativePrayerEntry,
        secondary: Boolean,
        index: Int,
        currentIndex: Int?,
        nextIndex: Int?,
    ) {
        val isCurrent = index == currentIndex
        val isNext = index == nextIndex
        Row(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .background(if (isCurrent) Color(0xFFDCE7EF) else Color.Transparent)
                    .cornerRadius(10.dp)
                    .padding(horizontal = 6.dp, vertical = 3.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Text(
                entry.label,
                modifier = GlanceModifier.defaultWeight(),
                style =
                    TextStyle(
                        fontSize = if (secondary) 12.sp else 14.sp,
                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                    ),
                maxLines = 1,
            )
            Text(
                entry.timeLabel,
                style =
                    TextStyle(
                        fontSize = if (secondary) 12.sp else 14.sp,
                        fontWeight =
                            if (isCurrent || isNext) {
                                FontWeight.Bold
                            } else {
                                FontWeight.Normal
                            },
                    ),
                maxLines = 1,
            )
        }
    }
}

class PrayerWidgetReceiver : HomeWidgetGlanceWidgetReceiver<PrayerWidget>() {
    override val glanceAppWidget = PrayerWidget()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        PrayerWidgetRefresh.reschedule(context, PrayerWidgetReceiver::class.java)
    }

    override fun onDisabled(context: Context) {
        PrayerWidgetRefresh.cancel(context, PrayerWidgetReceiver::class.java)
        super.onDisabled(context)
    }
}
