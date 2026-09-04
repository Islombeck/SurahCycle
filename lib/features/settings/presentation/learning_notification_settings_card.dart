import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';

final class LearningNotificationSettingsCard extends ConsumerStatefulWidget {
  const LearningNotificationSettingsCard({super.key});

  @override
  ConsumerState<LearningNotificationSettingsCard> createState() =>
      _LearningNotificationSettingsCardState();
}

final class _LearningNotificationSettingsCardState
    extends ConsumerState<LearningNotificationSettingsCard> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(learningNotificationEnabledProvider).valueOrNull ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.notificationsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              key: const ValueKey<String>('learning-notification-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.learningNotificationTitle),
              subtitle: Text(context.l10n.learningNotificationSubtitle),
              value: enabled,
              onChanged: _saving ? null : _setEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _saving = true);
    try {
      final granted = await ref
          .read(learningNotificationControllerProvider)
          .setEnabled(value);
      if (value && !granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.learningNotificationPermissionDenied),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
