import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/home/presentation/widgets/recommendation_rank_badge.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  for (final scale in <double>[1, 1.3, 1.5]) {
    testWidgets('recommendation ranks 1..8 stay centred at text scale $scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_BadgeHarness(textScale: scale));

        for (var rank = 1; rank <= 8; rank += 1) {
          final badge = find.byKey(
            ValueKey<String>('recommendation-rank-badge-$rank'),
          );
          final text = find.byKey(
            ValueKey<String>('recommendation-rank-text-$rank'),
          );
          expect(tester.getSize(badge), const Size.square(24));
          expect(
            (tester.getCenter(badge) - tester.getCenter(text)).distance,
            lessThan(0.6),
          );
          expect(tester.getSemantics(badge).label, 'Recommendation $rank');
        }

        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('recommendation chips wrap without overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _BadgeHarness(textScale: 1.5));

    expect(find.byType(RecommendationChip), findsNWidgets(8));
    expect(tester.takeException(), isNull);
  });
}

final class _BadgeHarness extends StatelessWidget {
  const _BadgeHarness({required this.textScale});

  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (var rank = 1; rank <= 8; rank += 1)
                      RecommendationChip(
                        rank: rank,
                        label: 'A distinct surah title $rank',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
