// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'Murajaah';

  @override
  String get homeTab => 'Bosh sahifa';

  @override
  String get surahsTab => 'Suralar';

  @override
  String get learningTab => 'O‘rganish';

  @override
  String get statisticsTab => 'Statistika';

  @override
  String get settingsTab => 'Sozlamalar';

  @override
  String get historyTitle => 'Tarix';

  @override
  String get recommendedTitle => 'Tavsiya';

  @override
  String get activeSurahsTitle => 'Faol suralar';

  @override
  String get noActiveSurahs =>
      'Yodlangan suralarni tanlang va aylanishga qo‘shing.';

  @override
  String get contentUnavailableTitle => 'Qur’on ma’lumotlari hali yuklanmagan';

  @override
  String get contentUnavailableBody =>
      'Tasdiqlangan suralar katalogi oflayn mavjud. Oyat matni va tarjimalar hali yuklanmagan; aylanish va o‘rganish bosqichlari ishlashda davom etadi.';

  @override
  String get refreshContent => 'Manbani tekshirish';

  @override
  String get sourceUnavailable => 'Tasdiqlangan manba hali ulanmagan';

  @override
  String get prayerContextTitle => 'Namoz konteksti';

  @override
  String get fajr => 'Bomdod';

  @override
  String get dhuhr => 'Peshin';

  @override
  String get asr => 'Asr';

  @override
  String get maghrib => 'Shom';

  @override
  String get isha => 'Xufton';

  @override
  String get witr => 'Vitr';

  @override
  String get nafl => 'Nafl';

  @override
  String get qada => 'Qazo';

  @override
  String get selectPrayer => 'Namozni tanlash';

  @override
  String get surahMarked => 'Sura belgilandi';

  @override
  String get undo => 'Bekor qilish';

  @override
  String get doneForCycle => 'Bajarildi';

  @override
  String recitationsRemaining(int count) {
    return '$count×';
  }

  @override
  String ayahCount(int count) {
    return '$count oyat';
  }

  @override
  String surahNumber(int number) {
    return '$number-sura';
  }

  @override
  String get searchSurahs => 'Raqam yoki nom bo‘yicha qidirish';

  @override
  String get noSearchResults => 'Bu qidiruv bo‘yicha sura topilmadi.';

  @override
  String get masteredOnly => 'Yodlangan';

  @override
  String get activeRotation => 'Aylanishda';

  @override
  String get inactiveRotation => 'To‘xtatilgan';

  @override
  String get addToMastered => 'Yodlanganlarga qo‘shish';

  @override
  String get removeFromRotation => 'To‘xtatish';

  @override
  String get returnToRotation => 'Aylanishga qaytarish';

  @override
  String get editAlias => 'Nomni o‘zgartirish';

  @override
  String get aliasHint => 'Sura uchun nomingiz';

  @override
  String get save => 'Saqlash';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get confirm => 'Tasdiqlash';

  @override
  String get delete => 'O‘chirish';

  @override
  String get deleteHistoryConfirm =>
      'Bu yozuv o‘chirilsinmi? Balans saqlangan hodisalardan qayta hisoblanadi.';

  @override
  String get emptyHistory => 'Hali qiroat yo‘q.';

  @override
  String get normalRecitation => 'Oddiy';

  @override
  String get qadaRecitation => 'Qazo';

  @override
  String get totalRecitations => 'Jami qiroatlar';

  @override
  String get lastUsed => 'Oxirgi qiroat';

  @override
  String get never => 'Hali o‘qilmagan';

  @override
  String get prayerBreakdown => 'Namozlar bo‘yicha';

  @override
  String get noStatistics =>
      'Statistika birinchi qiroatdan keyin paydo bo‘ladi.';

  @override
  String get currentLearning => 'Hozir o‘rganilmoqda';

  @override
  String get showOnHome => 'Bosh sahifada ko‘rsatish';

  @override
  String get startLearning => 'O‘rganishni boshlash';

  @override
  String get repeated => 'Takrorladim';

  @override
  String get learned => 'Yodladim';

  @override
  String newAyah(int number) {
    return 'Yangi oyat $number';
  }

  @override
  String cumulativeRange(int end) {
    return '1–$end oyatlarni takrorlash';
  }

  @override
  String get learningRolledBack =>
      '72 soat takrorsiz o‘tgach, bosqich bir qadam ortga qaytdi.';

  @override
  String get learningCompletedTitle => 'Sura yodlandi';

  @override
  String get learningCompletedBody => 'Uni faol aylanishga qo‘shilsinmi?';

  @override
  String get completeAndAdd => 'Tugatish va qo‘shish';

  @override
  String get darkMode => 'Qorong‘i mavzu';

  @override
  String get themeSystem => 'Tizim kabi';

  @override
  String get themeLight => 'Yorug‘';

  @override
  String get themeDark => 'Qorong‘i';

  @override
  String get advancedSettings => 'Kengaytirilgan sozlamalar';

  @override
  String get balanceAdjustment => 'Balansni tuzatish';

  @override
  String get balanceAdjustmentBody =>
      'Faqat mavjud balansni ko‘chirish uchun ishlating. Qiroat tarixi o‘zgarmaydi.';

  @override
  String get shiftPlusOne => 'Balansni +1 siljitish';

  @override
  String get shiftMinusOne => 'Balansni −1 siljitish';

  @override
  String get balanceConfirm =>
      'Faqat shu suraning balansi o‘zgartirilsinmi? Tarixiy statistika o‘zgarmaydi.';

  @override
  String get exportData => 'Ma’lumotlarni eksport qilish';

  @override
  String get exportPrepared =>
      'Eksport chegarasi tayyor; fayl keyingi sprintda qo‘shiladi.';

  @override
  String get sourceMetadata => 'Ma’lumot manbasi';

  @override
  String get offlineReady => 'Oflayn ishlaydi';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get errorGeneric => 'Amalni bajarib bo‘lmadi';

  @override
  String get loading => 'Yuklanmoqda…';

  @override
  String get noLearningSurahs => 'Hali o‘rganilayotgan sura yo‘q.';

  @override
  String get openHistory => 'Tarixni ochish';

  @override
  String aheadBy(int count) {
    return 'Oldinda: $count';
  }

  @override
  String get statisticsFilter => 'Namoz filtri';

  @override
  String get allPrayers => 'Barcha namozlar';

  @override
  String get isQadaLabel => 'Qazo namozi';

  @override
  String get reorderHint => 'Tartibni o‘zgartirish uchun bosib ushlab suring';

  @override
  String get selectSurah => 'Surani tanlang';

  @override
  String get contentIntegrityNotice =>
      'Matn va metama’lumotlar faqat tasdiqlangan manbadan o‘zgartirilmasdan ko‘rsatiladi.';

  @override
  String get editSegmentation => 'Takrorlash qismlari';

  @override
  String get wholeSurah => 'To‘liq sura';

  @override
  String partLabel(Object number) {
    return '$number-qism';
  }

  @override
  String ayahRange(int start, int end) {
    return '$start–$end-oyatlar';
  }

  @override
  String rakaatSpan(Object count) {
    return 'Rakaatlar: $count';
  }

  @override
  String get selectCoverage => 'O‘qilgan qismlarni tanlang';

  @override
  String splitIntoParts(Object count) {
    return '$count qismga bo‘lish';
  }

  @override
  String get automaticBoundaries => 'Avtomatik chegaralar';

  @override
  String get manualBoundaries => 'Chegaralarni o‘zgartirish';

  @override
  String schemeVersion(Object version) {
    return '$version-versiya';
  }

  @override
  String get recitationActions => 'Qiroat amallari';

  @override
  String get fullEquivalentRecitations => 'To‘liq sura ekvivalentlari';

  @override
  String dueSurahsCount(Object count) {
    return 'Takrorlash kerak: $count';
  }

  @override
  String get widgetPart => 'Qism';

  @override
  String get widgetAyah => 'Oyat';

  @override
  String get widgetAyahs => 'Oyatlar';

  @override
  String get widgetOpenAppToLoadText =>
      'Tasdiqlangan matnni yuklash uchun Murajaah’ni oching';

  @override
  String get customParts => 'Maxsus';

  @override
  String get customPartCount => 'Qismlar soni';

  @override
  String customPartCountRange(int max) {
    return '1 dan $max gacha';
  }

  @override
  String get customPartCountInvalid => 'To‘g‘ri qismlar sonini kiriting';

  @override
  String get fatihaRotationExcluded =>
      'Fotiha yodlangan holda saqlanadi, ammo odatiy aylanishda qatnashmaydi.';

  @override
  String get completeLearningOnly => 'O‘rganishni tugatish';

  @override
  String get arabicTextOfflineReady =>
      'Tasdiqlangan Tanzil arabcha matni oflayn mavjud.';

  @override
  String get quranTranslation => 'Qur’on tarjimasi';

  @override
  String get chooseTranslation => 'Sozlamalarda tarjimani tanlang';

  @override
  String get noRussianTranslations =>
      'QuranEnc rasmiy API katalogida hozir ruscha tarjimalar qaytarilmayapti. Arabcha matn oflayn mavjud.';

  @override
  String get translationCatalogError =>
      'QuranEnc rasmiy tarjimalar ro‘yxatini yuklab bo‘lmadi.';

  @override
  String get translationNotSelected => 'Tarjima tanlanmagan';

  @override
  String get translationCachedOffline =>
      'Tanlangan tarjima suralar ochilganda oflayn o‘qish uchun saqlanadi.';

  @override
  String get translationUnavailableOffline =>
      'Bu oyat tarjimasi hali saqlanmagan. Tarjima fonda yuklanayotganda arabcha matn mavjud bo‘lib qoladi.';

  @override
  String get clearTranslation => 'Tarjima tanlovini tozalash';

  @override
  String get translationSelectionInvalid =>
      'Saqlangan tarjima tanlovi noto‘g‘ri yoki endi qo‘llab-quvvatlanmaydi. Arabcha matn mavjud bo‘lib qoladi.';

  @override
  String get translationVersionChanged =>
      'Tanlangan tarjima versiyasi o‘zgargan. Yangi versiyani Sozlamalarda tasdiqlang; arabcha matn mavjud bo‘lib qoladi.';

  @override
  String translationUpdateAvailable(String version) {
    return 'Tanlangan tarjimaning yangi versiyasi mavjud: v$version. U faqat siz tanlasangiz yangilanadi.';
  }

  @override
  String useTranslationVersion(String version) {
    return 'v$version dan foydalanish';
  }

  @override
  String get tanzilTextMetadata =>
      'Tanzil Project · Uthmani Quran Text v1.1 · CC BY 3.0';
}
