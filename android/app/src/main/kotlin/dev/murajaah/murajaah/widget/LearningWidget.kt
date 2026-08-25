package dev.murajaah.murajaah.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity

class LearningWidget : GlanceAppWidget() {
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
        val learningItem = snapshot?.learning?.item

        LazyColumn(
            modifier =
                GlanceModifier.fillMaxSize()
                    .background(Color(0xFFF2F5F0))
                    .cornerRadius(22.dp)
                    .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            item(itemId = HEADER_ID) {
                Text(
                    context.getString(R.string.learning_widget_title),
                    modifier =
                        GlanceModifier.fillMaxWidth()
                            .clickable(homeAction)
                            .padding(vertical = 7.dp),
                    style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                )
            }

            when {
                snapshot == null ->
                    item(itemId = FALLBACK_ID) {
                        FallbackRow(
                            text = context.getString(R.string.widget_open_murajaah),
                            onClick = homeAction,
                        )
                    }
                learningItem == null ->
                    item(itemId = EMPTY_ID) {
                        FallbackRow(
                            text = context.getString(R.string.learning_widget_empty),
                            onClick = homeAction,
                        )
                    }
                else -> {
                    item(itemId = METADATA_ID) { LearningMetadata(context, learningItem) }
                    if (learningItem.verifiedTextLines.isEmpty()) {
                        item(itemId = UNAVAILABLE_ID) {
                            Text(
                                learningItem.unavailableTextLabel,
                                modifier =
                                    GlanceModifier.fillMaxWidth()
                                        .clickable(
                                            actionStartActivity<MainActivity>(
                                                context,
                                                learningItem.deepLink,
                                            )
                                        )
                                        .padding(vertical = 10.dp),
                                style = TextStyle(fontSize = 13.sp),
                                maxLines = 3,
                            )
                        }
                    } else {
                        items(
                            items = learningItem.verifiedTextLines.withIndex().toList(),
                            itemId = { stableWidgetItemId("quran:${it.index}") },
                        ) { indexedText ->
                            Text(
                                indexedText.value,
                                modifier =
                                    GlanceModifier.fillMaxWidth()
                                        .clickable(
                                            actionStartActivity<MainActivity>(
                                                context,
                                                learningItem.deepLink,
                                            )
                                        )
                                        .padding(vertical = 8.dp),
                                style =
                                    TextStyle(fontSize = 20.sp, textAlign = TextAlign.End),
                            )
                        }
                    }
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
    private fun LearningMetadata(context: Context, item: NativeLearningItem) {
        val action = actionStartActivity<MainActivity>(context, item.deepLink)
        Column(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .background(Color(0xFFE3EBE1))
                    .cornerRadius(14.dp)
                    .clickable(action)
                    .padding(11.dp)
        ) {
            Text(
                item.title,
                style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold),
                maxLines = 1,
            )
            Spacer(GlanceModifier.height(3.dp))
            Text(item.stageLabel, style = TextStyle(fontSize = 13.sp), maxLines = 2)
            Text(item.rangeLabel, style = TextStyle(fontSize = 14.sp), maxLines = 1)
        }
        Spacer(GlanceModifier.height(4.dp))
    }

    @Composable
    private fun FallbackRow(text: String, onClick: Action) {
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
        const val HEADER_ID = Long.MIN_VALUE + 11
        const val FALLBACK_ID = Long.MIN_VALUE + 12
        const val EMPTY_ID = Long.MIN_VALUE + 13
        const val METADATA_ID = Long.MIN_VALUE + 14
        const val UNAVAILABLE_ID = Long.MIN_VALUE + 15
        const val FOOTER_ID = Long.MIN_VALUE + 16
    }
}

class LearningWidgetReceiver : HomeWidgetGlanceWidgetReceiver<LearningWidget>() {
    override val glanceAppWidget = LearningWidget()
}
