package dev.murajaah.murajaah.widget

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
            when {
                size.width < MEDIUM_SIZE.width -> CompactBody(context, prayer)
                size.height < LARGE_SIZE.height -> MediumBody(context, prayer)
                else -> LargeBody(context, prayer)
            }
        }
    }

    @Composable
    private fun CompactBody(context: Context, prayer: NativePrayerProjection) {
        Spacer(GlanceModifier.height(4.dp))
        Text(
            prayer.currentLabel ?: context.getString(R.string.prayer_widget_between),
            style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
            maxLines = 1,
        )
        prayer.nextLabel?.let { nextLabel ->
            val nextEntry = prayer.entries.firstOrNull { it.isNext }
            Text(
                if (nextEntry != null) {
                    context.getString(
                        R.string.prayer_widget_next_at,
                        nextLabel,
                        nextEntry.timeLabel,
                    )
                } else {
                    nextLabel
                },
                style = TextStyle(fontSize = 12.sp),
                maxLines = 1,
            )
        }
        Text(prayer.regionLabel ?: "", style = TextStyle(fontSize = 11.sp), maxLines = 1)
    }

    @Composable
    private fun MediumBody(context: Context, prayer: NativePrayerProjection) {
        Spacer(GlanceModifier.height(4.dp))
        for (entry in prayer.entries) {
            if (entry.isBoundaryOnly) continue
            PrayerRow(entry, secondary = false)
        }
        val sunrise = prayer.entries.firstOrNull { it.isBoundaryOnly }
        if (sunrise != null) {
            Spacer(GlanceModifier.height(2.dp))
            PrayerRow(sunrise, secondary = true)
        }
        Spacer(GlanceModifier.height(4.dp))
        Text(prayer.regionLabel ?: "", style = TextStyle(fontSize = 11.sp), maxLines = 1)
    }

    @Composable
    private fun LargeBody(context: Context, prayer: NativePrayerProjection) {
        Spacer(GlanceModifier.height(4.dp))
        Text(
            prayer.dateLabel ?: "",
            style = TextStyle(fontSize = 12.sp),
            maxLines = 1,
        )
        Spacer(GlanceModifier.height(4.dp))
        for (entry in prayer.entries) {
            PrayerRow(entry, secondary = entry.isBoundaryOnly)
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
    private fun PrayerRow(entry: NativePrayerEntry, secondary: Boolean) {
        Row(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .background(
                        if (entry.isCurrent) Color(0xFFDCE7EF) else Color.Transparent
                    )
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
                        fontWeight =
                            if (entry.isCurrent) FontWeight.Bold else FontWeight.Normal,
                    ),
                maxLines = 1,
            )
            Text(
                entry.timeLabel,
                style =
                    TextStyle(
                        fontSize = if (secondary) 12.sp else 14.sp,
                        fontWeight =
                            if (entry.isCurrent || entry.isNext) {
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
}
