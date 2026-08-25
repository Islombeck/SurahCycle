package dev.murajaah.murajaah.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
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
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity

class RotationWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(context, currentState()) }
    }

    @Composable
    private fun Content(context: Context, state: HomeWidgetGlanceState) {
        val snapshot =
            NativeWidgetSnapshotParser.parse(
                state.preferences.getString(WIDGET_SNAPSHOT_KEY, null)
            )
        val homeAction =
            actionStartActivity<MainActivity>(context, Uri.parse("murajaah://app/home"))

        LazyColumn(
            modifier =
                GlanceModifier.fillMaxSize()
                    .background(Color(0xFFF7F4EC))
                    .cornerRadius(22.dp)
                    .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            item(itemId = HEADER_ID) {
                Column(
                    modifier =
                        GlanceModifier.fillMaxWidth()
                            .clickable(homeAction)
                            .padding(vertical = 6.dp)
                ) {
                    Text(
                        context.getString(R.string.rotation_widget_title),
                        style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1,
                    )
                    Text(
                        context.getString(R.string.rotation_widget_subtitle),
                        style = TextStyle(fontSize = 12.sp),
                        maxLines = 1,
                    )
                }
            }

            if (snapshot == null) {
                item(itemId = FALLBACK_ID) {
                    FallbackRow(
                        text = context.getString(R.string.widget_open_murajaah),
                        onClick = homeAction,
                    )
                }
            } else if (snapshot.rotation.items.isEmpty()) {
                item(itemId = EMPTY_ID) {
                    FallbackRow(
                        text = context.getString(R.string.rotation_widget_empty),
                        onClick = homeAction,
                    )
                }
            } else {
                items(
                    items = snapshot.rotation.items,
                    itemId = { stableWidgetItemId(it.id) },
                ) { item ->
                    RotationRow(context, item)
                }
            }

            item(itemId = FOOTER_ID) {
                Text(
                    context.getString(R.string.widget_open_app),
                    modifier =
                        GlanceModifier.fillMaxWidth()
                            .clickable(homeAction)
                            .padding(vertical = 10.dp),
                    style = TextStyle(fontSize = 12.sp),
                    maxLines = 1,
                )
            }
        }
    }

    @Composable
    private fun RotationRow(context: Context, item: NativeRotationItem) {
        val rowAction = actionStartActivity<MainActivity>(context, item.deepLink)
        Column(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .background(
                        if (item.isRecommended) Color(0xFFECE7D8) else Color.Transparent
                    )
                    .cornerRadius(14.dp)
                    .clickable(rowAction)
                    .padding(horizontal = 10.dp, vertical = 9.dp)
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                if (item.isRecommended) {
                    Text(
                        context.getString(R.string.widget_recommended_marker),
                        style = TextStyle(fontSize = 12.sp),
                        maxLines = 1,
                    )
                    Spacer(GlanceModifier.width(7.dp))
                }
                Text(
                    item.title,
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium),
                    maxLines = 1,
                )
                if (item.debtLabel.isNotEmpty()) {
                    Spacer(GlanceModifier.width(8.dp))
                    Text(
                        item.debtLabel,
                        style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1,
                    )
                }
            }
            item.subtitle?.let { subtitle ->
                Spacer(GlanceModifier.height(2.dp))
                Text(subtitle, style = TextStyle(fontSize = 12.sp), maxLines = 2)
            }
        }
        Spacer(GlanceModifier.height(4.dp))
    }

    @Composable
    private fun FallbackRow(text: String, onClick: androidx.glance.action.Action) {
        Text(
            text,
            modifier =
                GlanceModifier.fillMaxWidth()
                    .clickable(onClick)
                    .padding(vertical = 18.dp),
            style = TextStyle(fontSize = 14.sp),
            maxLines = 3,
        )
    }

    private companion object {
        const val HEADER_ID = Long.MIN_VALUE + 1
        const val FALLBACK_ID = Long.MIN_VALUE + 2
        const val EMPTY_ID = Long.MIN_VALUE + 3
        const val FOOTER_ID = Long.MIN_VALUE + 4
    }
}

class RotationWidgetReceiver : HomeWidgetGlanceWidgetReceiver<RotationWidget>() {
    override val glanceAppWidget = RotationWidget()
}
