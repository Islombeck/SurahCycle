import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../core/domain/domain.dart';
import '../domain/quran_audio_models.dart';
import '../application/learning_audio_controller.dart';

final class LearningAudioControls extends ConsumerStatefulWidget {
  const LearningAudioControls({
    required this.learningState,
    required this.surahNumber,
    super.key,
  });

  final LearningSurahState learningState;
  final int surahNumber;

  @override
  ConsumerState<LearningAudioControls> createState() =>
      _LearningAudioControlsState();
}

final class _LearningAudioControlsState
    extends ConsumerState<LearningAudioControls> {
  late final LearningAudioController _controller;
  String? _selection;
  QuranAudioRepeat _repeat = QuranAudioRepeat.once;
  QuranAudioRange? _resolvedRange;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(learningAudioControllerProvider);
  }

  @override
  void didUpdateWidget(covariant LearningAudioControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber ||
        oldWidget.learningState.stage != widget.learningState.stage) {
      unawaited(_controller.stop());
      _resolvedRange = null;
      _error = null;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AudioCopy(Localizations.localeOf(context).languageCode);
    final catalogState = ref.watch(quranAudioCatalogProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: catalogState.when(
          loading: () => const Center(child: LinearProgressIndicator()),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.catalogUnavailable),
              TextButton.icon(
                onPressed: () => ref.invalidate(quranAudioCatalogProvider),
                icon: const Icon(Icons.refresh),
                label: Text(copy.retry),
              ),
            ],
          ),
          data: (catalog) => _buildReady(context, catalog, copy),
        ),
      ),
    );
  }

  Widget _buildReady(
    BuildContext context,
    List<QuranReciter> catalog,
    _AudioCopy copy,
  ) {
    final options = <({QuranReciter reciter, QuranMoshaf moshaf})>[
      for (final reciter in catalog)
        for (final moshaf in reciter.moshafs)
          if (moshaf.hasSurah(widget.surahNumber))
            (reciter: reciter, moshaf: moshaf),
    ];
    if (options.isEmpty) return Text(copy.noRecording);
    final keys = {
      for (final option in options) _key(option.reciter, option.moshaf),
    };
    final selectedKey = keys.contains(_selection)
        ? _selection!
        : _key(options.first.reciter, options.first.moshaf);
    final selected = options.firstWhere(
      (option) => _key(option.reciter, option.moshaf) == selectedKey,
    );
    final controller = _controller;

    return StreamBuilder<QuranAudioPlaybackState>(
      stream: controller.states,
      initialData: const QuranAudioPlaybackState(),
      builder: (context, snapshot) {
        final playback = snapshot.data ?? const QuranAudioPlaybackState();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedKey,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: copy.reciter,
                isDense: true,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: _key(option.reciter, option.moshaf),
                    child: Text(
                      '${option.reciter.displayName} · ${option.moshaf.riwayaName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == selectedKey) return;
                unawaited(controller.stop());
                setState(() {
                  _selection = value;
                  _resolvedRange = null;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 6),
            Text(
              '${selected.moshaf.availableSurahs.length} ${copy.surahs} · '
              '${selected.moshaf.timingReadId == null ? copy.fullSurahOnly : copy.exactTiming} · '
              'MP3Quran.net',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(copy.repeat),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<QuranAudioRepeat>(
                    value: _repeat,
                    isExpanded: true,
                    items: [
                      for (final value in QuranAudioRepeat.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(copy.repeatLabel(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(controller.stop());
                      setState(() => _repeat = value);
                    },
                  ),
                ),
              ],
            ),
            if (_resolvedRange?.kind == QuranAudioRangeKind.fullSurahOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  copy.fullSurahExplanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  copy.playbackFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _starting || playback.isLoading
                        ? null
                        : () => _play(catalog, selected, copy),
                    icon: _starting || playback.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(copy.playRange),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: playback.isPlaying ? copy.pause : copy.resume,
                  onPressed: !playback.hasAudio
                      ? null
                      : playback.isPlaying
                      ? controller.pause
                      : controller.resume,
                  icon: Icon(
                    playback.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  tooltip: copy.stop,
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _play(
    List<QuranReciter> catalog,
    ({QuranReciter reciter, QuranMoshaf moshaf}) selected,
    _AudioCopy copy,
  ) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final range = await _controller.play(
        catalog: catalog,
        reciterId: selected.reciter.id,
        moshafId: selected.moshaf.id,
        surahNumber: widget.surahNumber,
        stage: widget.learningState.stage,
        repeat: _repeat,
      );
      if (mounted) setState(() => _resolvedRange = range);
    } on QuranAudioOperationCancelled {
      // A newer selection or lifecycle event intentionally superseded this load.
    } on Object {
      if (mounted) setState(() => _error = copy.playbackFailed);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  static String _key(QuranReciter reciter, QuranMoshaf moshaf) =>
      '${reciter.id}:${moshaf.id}';
}

final class _AudioCopy {
  const _AudioCopy(this.languageCode);
  final String languageCode;
  bool get _ru => languageCode == 'ru';
  bool get _uz => languageCode == 'uz';
  String get title => _ru
      ? 'Аудио для заучивания'
      : _uz
      ? 'Yodlash audiosi'
      : 'Learning audio';
  String get reciter => _ru
      ? 'Чтец и риваят'
      : _uz
      ? 'Qori va rivoyat'
      : 'Reciter and riwaya';
  String get surahs => _ru
      ? 'сур'
      : _uz
      ? 'sura'
      : 'surahs';
  String get exactTiming => _ru
      ? 'точные тайминги аятов'
      : _uz
      ? 'oyatlarning aniq vaqti'
      : 'exact ayah timing';
  String get fullSurahOnly => _ru
      ? 'только вся сура'
      : _uz
      ? 'faqat to‘liq sura'
      : 'full surah only';
  String get fullSurahExplanation => _ru
      ? 'Для этой записи нет проверенных таймингов: доступно только воспроизведение всей суры.'
      : _uz
      ? 'Bu yozuv uchun tekshirilgan vaqtlar yo‘q: faqat to‘liq surani tinglash mumkin.'
      : 'Verified timing is unavailable for this recording; only full-surah playback is available.';
  String get repeat => _ru
      ? 'Повтор'
      : _uz
      ? 'Takror'
      : 'Repeat';
  String repeatLabel(QuranAudioRepeat value) =>
      value == QuranAudioRepeat.infinite ? '∞' : '${value.count}×';
  String get playRange => _ru
      ? 'Слушать этап'
      : _uz
      ? 'Bosqichni tinglash'
      : 'Play stage';
  String get pause => _ru
      ? 'Пауза'
      : _uz
      ? 'Pauza'
      : 'Pause';
  String get resume => _ru
      ? 'Продолжить'
      : _uz
      ? 'Davom etish'
      : 'Resume';
  String get stop => _ru
      ? 'Остановить'
      : _uz
      ? 'To‘xtatish'
      : 'Stop';
  String get catalogUnavailable => _ru
      ? 'Каталог аудио недоступен.'
      : _uz
      ? 'Audio katalog mavjud emas.'
      : 'Audio catalog is unavailable.';
  String get retry => _ru
      ? 'Повторить'
      : _uz
      ? 'Qayta urinish'
      : 'Retry';
  String get noRecording => _ru
      ? 'Для этой суры нет записи в каталоге Hafs.'
      : _uz
      ? 'Hafs katalogida bu sura yozuvi yo‘q.'
      : 'No Hafs recording is available for this surah.';
  String get playbackFailed => _ru
      ? 'Не удалось запустить аудио. Проверьте сеть и повторите.'
      : _uz
      ? 'Audio ishga tushmadi. Tarmoqni tekshirib, qayta urinib ko‘ring.'
      : 'Audio could not start. Check the network and try again.';
}
