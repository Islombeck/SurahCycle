package dev.murajaah.murajaah.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
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
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import dev.murajaah.murajaah.MainActivity
import dev.murajaah.murajaah.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.actionStartActivity

class RotationWidget : GlanceAppWidget(errorUiLayout = R.layout.widget_error) {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

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
            widgetType = "RotationWidget",
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
        val omittedCount = snapshot?.rotation?.omittedCount ?: 0

        LazyColumn(
            modifier =
                GlanceModifier.fillMaxSize()
                    .background(Color(0xFFF7F4EC))
                    .cornerRadius(22.dp)
                    .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            item {
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
                        snapshot?.rotation?.contextLabel
                            ?: context.getString(R.string.rotation_widget_subtitle),
                        style = TextStyle(fontSize = 12.sp),
                        maxLines = 1,
                    )
                    snapshot?.rotation?.currentPartLabel?.let { currentPartLabel ->
                        Spacer(GlanceModifier.height(2.dp))
                        Text(
                            currentPartLabel,
                            style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium),
                            maxLines = 2,
                        )
                    }
                    snapshot?.rotation?.slotProgressLabel?.let { slotProgressLabel ->
                        Spacer(GlanceModifier.height(1.dp))
                        Text(
                            slotProgressLabel,
                            style = TextStyle(fontSize = 11.sp),
                            maxLines = 1,
                        )
                    }
                    snapshot?.rotation?.statusMessage?.let { statusMessage ->
                        Spacer(GlanceModifier.height(2.dp))
                        Text(
                            statusMessage,
                            style = TextStyle(fontSize = 11.sp),
                            maxLines = 2,
                        )
                    }
                }
            }

            if (snapshot == null) {
                item {
                    FallbackRow(
                        text = context.getString(R.string.widget_open_murajaah),
                        onClick = homeAction,
                    )
                }
            } else if (snapshot.rotation.items.isEmpty()) {
                item {
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

            item {
                Text(
                    if (omittedCount > 0) {
                        context.getString(R.string.rotation_widget_more, omittedCount)
                    } else {
                        context.getString(R.string.widget_open_app)
                    },
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
        val homeAction =
            actionStartActivity<MainActivity>(context, Uri.parse("murajaah://app/home"))
        Row(
            modifier =
                GlanceModifier.fillMaxWidth()
                    .background(
                        if (item.recommendationRank != null) {
                            Color(0xFFECE7D8)
                        } else {
                            Color.Transparent
                        }
                    )
                    .cornerRadius(14.dp)
                    .padding(horizontal = 9.dp, vertical = 9.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            val markAction =
                if (item.canMark) item.action?.let { action ->
                    actionRunCallback<RotationWidgetMarkAction>(
                        actionParametersOf(rotationActionUriKey to action.uri.toString())
                    )
                } else null
            Image(
                provider =
                    ImageProvider(
                        if (item.isMarkedInCurrentPart) {
                            R.drawable.ic_widget_mark_checked
                        } else {
                            R.drawable.ic_widget_mark
                        }
                    ),
                contentDescription =
                    context.getString(
                        if (item.isMarkedInCurrentPart) {
                            R.string.widget_recitation_marked
                        } else if (!item.canMark) {
                            R.string.widget_open_app
                        } else {
                            R.string.widget_mark_recitation
                        }
                    ),
                modifier =
                    if (markAction == null) {
                        GlanceModifier.size(30.dp)
                    } else {
                        GlanceModifier.size(30.dp).clickable(markAction)
                    },
            )
            Spacer(GlanceModifier.width(9.dp))
            Column(
                modifier = GlanceModifier.defaultWeight().clickable(rowAction)
            ) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                ) {
                    item.recommendationRank?.let { recommendationRank ->
                        Text(
                            context.getString(
                                R.string.widget_recommendation_rank,
                                recommendationRank + 1,
                            ),
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
}

class RotationWidgetReceiver : HomeWidgetGlanceWidgetReceiver<RotationWidget>() {
    override val glanceAppWidget = RotationWidget()
}

private val rotationActionUriKey = ActionParameters.Key<String>("rotationActionUri")

class RotationWidgetMarkAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val actionUri = parameters[rotationActionUriKey] ?: return
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        logWidgetActionDispatch(context, appWidgetId, actionUri)
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(actionUri)).send()
    }
}
