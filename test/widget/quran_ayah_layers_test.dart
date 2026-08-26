import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  const ayah = QuranReadingAyah(
    surahNumber: 1,
    ayahNumber: 1,
    arabicText: 'بِسْمِ اللَّهِ',
    transliteration: '<u>Bismi</u> Allāhi',
    translation: 'In the name of Allah',
  );

  final configurations =
      <
        ({
          String name,
          QuranDisplayPreferences preferences,
          bool arabic,
          bool transliteration,
          bool translation,
        })
      >[
        (
          name: 'Arabic only',
          preferences: const QuranDisplayPreferences(
            showTransliteration: false,
            showTranslation: false,
          ),
          arabic: true,
          transliteration: false,
          translation: false,
        ),
        (
          name: 'Arabic and transliteration',
          preferences: const QuranDisplayPreferences(showTranslation: false),
          arabic: true,
          transliteration: true,
          translation: false,
        ),
        (
          name: 'Arabic and translation',
          preferences: const QuranDisplayPreferences(
            showTransliteration: false,
          ),
          arabic: true,
          transliteration: false,
          translation: true,
        ),
        (
          name: 'all three independent layers',
          preferences: QuranDisplayPreferences.defaults,
          arabic: true,
          transliteration: true,
          translation: true,
        ),
      ];

  for (final configuration in configurations) {
    testWidgets('${configuration.name} preserves per-ayah coordinates', (
      tester,
    ) async {
      await _pump(
        tester,
        QuranAyahLayers(ayah: ayah, preferences: configuration.preferences),
      );

      expect(
        find.byKey(const ValueKey<String>('quran-arabic-1-1')),
        configuration.arabic ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('quran-transliteration-1-1')),
        configuration.transliteration ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('quran-translation-1-1')),
        configuration.translation ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact content is bounded and transliteration stays LTR', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        width: 150,
        child: QuranAyahLayers(
          ayah: QuranReadingAyah(
            surahNumber: 2,
            ayahNumber: 255,
            arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
            transliteration: '<strong>Allāhu</strong> lā ilāha illā huwa',
            translation: 'Allah—there is no deity except Him, the Ever-Living.',
          ),
          preferences: QuranDisplayPreferences.defaults,
          compact: true,
        ),
      ),
    );

    final arabic = tester.widget<Text>(
      find.byKey(const ValueKey<String>('quran-arabic-2-255')),
    );
    final transliteration = tester.widget<TanzilTransliterationText>(
      find.byKey(const ValueKey<String>('quran-transliteration-2-255')),
    );
    final translation = tester.widget<Text>(
      find.byKey(const ValueKey<String>('quran-translation-2-255')),
    );
    expect(arabic.maxLines, 2);
    expect(arabic.overflow, TextOverflow.ellipsis);
    expect(transliteration.maxLines, 1);
    expect(transliteration.overflow, TextOverflow.ellipsis);
    expect(translation.maxLines, 1);
    expect(translation.overflow, TextOverflow.ellipsis);

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('quran-transliteration-2-255')),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.textDirection, TextDirection.ltr);
    expect(richText.text.toPlainText(), 'Allāhu lā ilāha illā huwa');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cumulative ayahs keep each three-layer block aligned', (
    tester,
  ) async {
    const second = QuranReadingAyah(
      surahNumber: 1,
      ayahNumber: 2,
      arabicText: 'الْحَمْدُ لِلَّهِ',
      transliteration: 'Al-ḥamdu lillāhi',
      translation: 'All praise is for Allah',
    );
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          QuranAyahLayers(
            ayah: ayah,
            preferences: QuranDisplayPreferences.defaults,
          ),
          SizedBox(height: 16),
          QuranAyahLayers(
            ayah: second,
            preferences: QuranDisplayPreferences.defaults,
          ),
        ],
      ),
    );

    for (final coordinate in <String>['1-1', '1-2']) {
      final arabic = find.byKey(ValueKey<String>('quran-arabic-$coordinate'));
      final transliteration = find.byKey(
        ValueKey<String>('quran-transliteration-$coordinate'),
      );
      final translation = find.byKey(
        ValueKey<String>('quran-translation-$coordinate'),
      );
      expect(arabic, findsOneWidget);
      expect(transliteration, findsOneWidget);
      expect(translation, findsOneWidget);
      expect(
        tester.getTopLeft(arabic).dy,
        lessThan(tester.getTopLeft(transliteration).dy),
      );
      expect(
        tester.getTopLeft(transliteration).dy,
        lessThan(tester.getTopLeft(translation).dy),
      );
    }
    expect(
      tester
          .getBottomLeft(
            find.byKey(const ValueKey<String>('quran-translation-1-1')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey<String>('quran-arabic-1-2')))
            .dy,
      ),
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);
