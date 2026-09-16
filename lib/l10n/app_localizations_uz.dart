// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'SurahCycle';

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
  String recommendationRank(int rank) {
    return 'Tavsiya $rank';
  }

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
  String get jumuah => 'Juma';

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
  String get recitedInCurrentPart => 'Ushbu qismda o\'qildi';

  @override
  String get notificationsTitle => 'Bildirishnomalar';

  @override
  String get learningNotificationTitle => 'Sokin yodlash eslatmasi';

  @override
  String get learningNotificationSubtitle =>
      'Keyingi takrorlash haqida ovozsiz bildirishnoma. Sukut boʻyicha oʻchirilgan.';

  @override
  String get learningNotificationPermissionDenied =>
      'Bildirishnoma ruxsati berilmadi, eslatma oʻchirilgan holda qoladi.';

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
      'Tasdiqlangan matnni yuklash uchun SurahCycle’ni oching';

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
  String get translationLanguage => 'Tarjima tili';

  @override
  String get translationLanguageRussian => 'Ruscha';

  @override
  String get translationLanguageUzbek => 'O‘zbekcha';

  @override
  String get chooseTranslation => 'Sozlamalarda tarjimani tanlang';

  @override
  String get noTranslationsForLanguage =>
      'Tanlangan til uchun hozir tasdiqlangan QuranEnc tarjimalari mavjud emas. Arabcha matn oflayn mavjud.';

  @override
  String get additionalUzbekTranslationsUnavailable =>
      'Al-Mukhtasar (uzbek_mokhtasar) va Al-Muyassar (uzbek_moyassar): rasmiy katalog kalitlari tasdiqlangan, ammo API korpuslari hozircha mavjud emas.';

  @override
  String get translationCatalogError =>
      'QuranEnc rasmiy tarjimalar ro‘yxatini yuklab bo‘lmadi.';

  @override
  String get translationNoNetwork =>
      'Tarmoq yo‘q. Avval yuklangan tarjimalar oflayn mavjud bo‘lib qoladi.';

  @override
  String get translationSourceError =>
      'Tarjima manbasi so‘rovni rad etdi. Keyinroq urinib ko‘ring.';

  @override
  String get translationValidationFailed =>
      'Manba javobi buzilgan yoki tekshiruvdan o‘tmadi. U saqlanmadi.';

  @override
  String get translationCatalogFromCache =>
      'Saqlangan oflayn katalog ko‘rsatilmoqda.';

  @override
  String get translationRefreshFailedCached =>
      'Manbani yangilab bo‘lmadi; saqlangan tasdiqlangan ma’lumotlar o‘zgarmadi.';

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

  @override
  String get tanzilTransliterationMetadata =>
      'Tanzil · English Transliteration · 2010-09-06 nusxasi · 6236 oyat';

  @override
  String get transliterationNonCommercialNotice =>
      'Transliteratsiya to‘plami faqat notijorat foydalanishga ruxsat beradi; tijoriy production relizi uchun alohida ruxsat kerak.';

  @override
  String get quranDisplayLayers => 'Qur’on matni qatlamlari';

  @override
  String get showArabicText => 'Arabcha matnni ko‘rsatish';

  @override
  String get showTransliteration => 'Transliteratsiyani ko‘rsatish';

  @override
  String get transliterationProfile => 'Transliteratsiya profili';

  @override
  String get transliterationProfileLatinTanzil => 'Lotin — Tanzil';

  @override
  String get transliterationProfileCyrillic => 'Kirill';

  @override
  String get transliterationProfileCyrillicUnavailable =>
      'Kirill — tasdiqlangan manba hali ulanmagan';

  @override
  String get showTranslation => 'Tarjimani ko‘rsatish';

  @override
  String get transliterationSourceShort =>
      'Lotincha transliteratsiya · Tanzil · oflayn';

  @override
  String get transliterationUnavailable =>
      'Tasdiqlangan transliteratsiya mavjud emas.';

  @override
  String get prayerTimesTitle => 'Namoz vaqtlari';

  @override
  String get prayerRegion => 'Hudud';

  @override
  String get selectPrayerRegion => 'Hududni qo‘lda tanlang';

  @override
  String get useMyLocation => 'Joylashuvimdan foydalanish';

  @override
  String get locationOptionalNotice =>
      'Ixtiyoriy. Joylashuv faqat shu tugma bosilganda, fon ruxsatisiz so‘raladi.';

  @override
  String get prayerContextMode => 'Belgilash konteksti';

  @override
  String get prayerModeManual => 'Qo‘lda';

  @override
  String get prayerModeAutomatic => 'Avtomatik';

  @override
  String get useJumuahForNextRecitation =>
      'Keyingi tilovatni Juma sifatida belgilash';

  @override
  String get automaticPrayerSafetyNotice =>
      'Avtomatik tanlov faqat yangi va ishonchli jadval bilan ishlaydi. Quyosh chiqqandan Peshingacha qo‘lda tanlash kerak.';

  @override
  String get allowCalculatedFallback => 'Mahalliy hisoblashga ruxsat berish';

  @override
  String get calculatedFallbackNotice =>
      'Bu OMI rasmiy jadvali emas, alohida hisoblangan manba. Standart: Karachi va Hanafi Asr.';

  @override
  String get calculatedFallbackCoordinatesUnavailable =>
      'Bu provider hududi uchun alohida tekshirilgan koordinatalar saqlanmagan, shuning uchun mahalliy hisoblash mavjud emas.';

  @override
  String get calculationMethod => 'Hisoblash usuli';

  @override
  String get asrHanafi => 'Asr: Hanafi';

  @override
  String get asrStandard => 'Asr: standart';

  @override
  String get manualMinuteAdjustments => 'Daqiqalarda qo‘lda tuzatish';

  @override
  String get rawTimesPreserved =>
      'Manbaning asl vaqti saqlanadi; tuzatilgan qiymat alohida ko‘rsatiladi.';

  @override
  String minuteAdjustment(int value) {
    return 'Tuzatish: $value daq';
  }

  @override
  String get decreaseMinute => 'Bir daqiqaga kamaytirish';

  @override
  String get increaseMinute => 'Bir daqiqaga oshirish';

  @override
  String get locationCalculationEnabled =>
      'Joylashuv mahalliy hisoblash uchun saqlandi.';

  @override
  String get locationServicesDisabled =>
      'Geolokatsiya o‘chirilgan. Hududni qo‘lda tanlang.';

  @override
  String get locationDeniedChooseRegion =>
      'Joylashuvga ruxsat berilmadi. Hududni qo‘lda tanlang.';

  @override
  String get locationOutsideUzbekistan =>
      'Bu nuqta uchun tasdiqlangan vaqt zonasi sozlamasi yo‘q. Hududni qo‘lda tanlang.';

  @override
  String get locationFailedChooseRegion =>
      'Joylashuvni olib bo‘lmadi. Hududni qo‘lda tanlang.';

  @override
  String get prayerScheduleToday => 'Bugungi jadval';

  @override
  String get sunrise => 'Quyosh';

  @override
  String get prayerSource => 'Manba';

  @override
  String get prayerUpdated => 'Yangilangan';

  @override
  String get asrSchool => 'Asr hisobi';

  @override
  String get timesManuallyAdjusted =>
      'Vaqt qo‘lda tuzatildi; asl qiymatlar saqlandi.';

  @override
  String get prayerOfflineCache => 'Yangi oflayn kesh ishlatilmoqda.';

  @override
  String get refreshPrayerSchedule => 'Joriy va keyingi oyni yangilash';

  @override
  String prayerStartsAt(String start) {
    return '$start dan';
  }

  @override
  String prayerTimeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String nextPrayerAt(String prayer, String time) {
    return 'Keyingi: $prayer, $time da';
  }

  @override
  String get betweenPrayers => 'Namozlar orasida';

  @override
  String get prayerScheduleStale =>
      'Jadval eskirgan — avtomatik tanlov o‘chirilgan';

  @override
  String get prayerScheduleUnavailable =>
      'Jadval mavjud emas — namozni qo‘lda tanlang';

  @override
  String widgetManualPrayerContext(String prayer) {
    return 'Qo‘lda: $prayer · Aylanish';
  }

  @override
  String widgetAutomaticPrayerContext(String prayer) {
    return '$prayer · Avto · Aylanish';
  }

  @override
  String widgetAutomaticPrayerRange(String prayer, String start, String end) {
    return '$prayer · $start–$end · Aylanish';
  }

  @override
  String widgetAutomaticPrayerStart(String prayer, String start) {
    return '$prayer · $start dan · Aylanish';
  }

  @override
  String get widgetSelectPrayerInApp => 'SurahCycle’da namozni tanlang';

  @override
  String get widgetActionNotCompleted =>
      'Belgilab bo‘lmadi. Joriy ma’lumotlar tiklandi.';

  @override
  String get learningHow => 'Qanday yodlaysiz?';

  @override
  String get learningClassic => 'Klassik';

  @override
  String get learningChunked => 'Qismlarga bo‘lib';

  @override
  String get learningChunkedRecommended =>
      'Uzun surani qismlarga bo‘lib yodlash qulayroq. Tanlovni o‘zgartirish mumkin.';

  @override
  String get learningTargetRange => 'Yodlash oralig‘i';

  @override
  String get learningTargetStart => 'Birinchi oyat';

  @override
  String get learningTargetEnd => 'Oxirgi oyat';

  @override
  String get learningBlockSize => 'Blok hajmi';

  @override
  String get learningCustomBlockSize => 'Boshqa hajm';

  @override
  String get changeLearningPlan => 'Rejani o‘zgartirish';

  @override
  String get confirmPlanChangeTitle => 'Yangi davr boshlansinmi?';

  @override
  String get confirmPlanChangeBody =>
      'Joriy progress yangi reja bo‘yicha qayta boshlanadi. Yodlash tarixi saqlanadi.';

  @override
  String learningReviewRange(int start, int end) {
    return '$start–$end-oyatlarni takrorlash';
  }

  @override
  String learningBridgeRange(int start, int end) {
    return 'Bloklarni bog‘lash · $start–$end-oyatlar';
  }

  @override
  String learningSectionReview(int start, int end) {
    return 'Bo‘limni takrorlash · $start–$end-oyatlar';
  }

  @override
  String learningFinalReview(int start, int end) {
    return 'Yakuniy takrorlash · $start–$end-oyatlar';
  }

  @override
  String get rangeCompletedTitle => 'Oraliq yakunlandi';

  @override
  String get rangeCompletedBody =>
      'Yodlangan oraliq saqlandi. Butun sura yodlangan deb belgilanmadi.';

  @override
  String get completeWithoutRotation => 'Aylanishsiz yakunlash';

  @override
  String get addToRotationQuestion => 'Aylanishga qo‘shilsinmi?';

  @override
  String get returnToLearning => 'Yodlanganlardan olib tashlash';

  @override
  String get returnToLearningTitle => 'Surani yodlashga qaytarasizmi?';

  @override
  String get returnToLearningBody =>
      'Sura aylanishdan chiqadi. Tarix, statistika, bo‘linish va avvalgi ballar saqlanadi.';

  @override
  String historyAddedAt(String dateTime) {
    return 'Qo‘shildi: $dateTime';
  }

  @override
  String get historyDetailsTitle => 'Qiroat tafsilotlari';

  @override
  String get historyOpenDetails => 'Qiroat tafsilotlarini ochish';

  @override
  String get historyOccurrenceLabel => 'Qachon va qaysi namozda o‘qilgan';

  @override
  String get historyCoverageLabel => 'O‘qilgan qism';

  @override
  String get historyRakaatSpanExplanation =>
      'Bu faqat qiroat qamrab olgan rakaatlar soni. Oyatlar alohida rakaatlarga bog‘lanmagan.';

  @override
  String get registrationWhenTitle => 'Qachon va qaysi namozda o‘qilgan';

  @override
  String get registrationNow => 'Hozir';

  @override
  String get registrationPreviousPrayer => 'Oldingi namoz';

  @override
  String get registrationYesterday => 'Kecha';

  @override
  String get registrationChooseDatePrayer => 'Sana va namozni tanlash';

  @override
  String registrationOccurrenceDate(String date) {
    return 'Qiroat sanasi: $date';
  }

  @override
  String get prayerRoutines => 'Namoz tartiblari';

  @override
  String get prayerRoutineDescription =>
      'Namoz qismlari tartibini, rakatlar va zarur sura slotlari sonini sozlang.';

  @override
  String get routineEnabled => 'Bu tartibdan foydalanish';

  @override
  String get routineEmpty =>
      'Hali qismlar yo‘q. Kuzatmoqchi bo‘lgan qismlarni qo‘shing.';

  @override
  String routinePartSummary(int rakaatCount, int slotCount) {
    return '$rakaatCount rakat · $slotCount ta sura sloti';
  }

  @override
  String get addPrayerPart => 'Namoz qismini qo‘shish';

  @override
  String get editPrayerPart => 'Namoz qismini tahrirlash';

  @override
  String get deletePrayerPartTitle => 'Namoz qismi o‘chirilsinmi?';

  @override
  String deletePrayerPartBody(String label) {
    return '“$label” o‘chirilsinmi? Allaqachon o‘qilganlar o‘zgarmaydi.';
  }

  @override
  String get applyToCurrentPrayerTitle => 'Joriy namozga ham qo‘llanilsinmi?';

  @override
  String applyToCurrentPrayerBody(String prayer, String date) {
    return '$prayer, $date — bu qism hali rejada. Unda o‘qilganlar yo‘q, shuning uchun uni o‘sha rejadan ham olib tashlash mumkin.';
  }

  @override
  String applyToCurrentPrayerComposition(String parts) {
    return 'Qoladi: $parts';
  }

  @override
  String get applyToCurrentPrayerEmpty =>
      'Namoz rejasi shablon bo‘yicha qaytadan tuziladi.';

  @override
  String get applyToCurrentPrayerAction => 'Joriysidan olib tashlash';

  @override
  String get keepCurrentPrayerUnchanged => 'Shundayligicha qoldirish';

  @override
  String applyToCurrentPrayerKept(String label) {
    return '“$label” qoldi: unda o‘qilganlar bor.';
  }

  @override
  String get partKind => 'Qism turi';

  @override
  String get customPartLabel => 'Maxsus nom';

  @override
  String get customPartLabelRequired => 'Nom kiriting.';

  @override
  String get rakaatCountLabel => 'Rakatlar soni';

  @override
  String get positiveNumberRequired => 'Musbat son kiriting.';

  @override
  String get surahSlotsLabel => 'Zarur sura slotlari';

  @override
  String get nonNegativeNumberRequired => 'Nol yoki musbat son kiriting.';

  @override
  String get allowsFollowingImam => 'Imomga ergashib yakunlash mumkin';

  @override
  String get partKindFard => 'Farz';

  @override
  String get partKindSunnah => 'Sunnat';

  @override
  String get partKindWitr => 'Vitr';

  @override
  String get partKindNafl => 'Nafl';

  @override
  String get partKindCustom => 'Boshqa';

  @override
  String prayerRoutineCurrentPart(String prayer, String part) {
    return '$prayer · $part';
  }

  @override
  String prayerRoutineSlotProgress(int done, int total) {
    return 'Sura slotlari: $done/$total';
  }

  @override
  String get prayerRoutineComplete => 'Namoz tartibi yakunlandi';

  @override
  String get prayerRoutineNoAvailableSlot =>
      'Namozning joriy qismida sura uchun bo‘sh slot yo‘q.';

  @override
  String get followedImamAction => 'Imomga ergashdim';

  @override
  String get followedImamConfirmTitle => 'Imom bilan yakunlansinmi?';

  @override
  String get followedImamConfirmBody =>
      'Bu qism qiroat hodisasi va aylanish hisobisiz yakunlanadi.';

  @override
  String get followedImamCompleted => 'Imomga ergashib yakunlandi';

  @override
  String get returnToAutomaticPrayer => 'Avtomatikaga qaytish';

  @override
  String get routineEditFailed =>
      'Namoz tartibidagi o‘zgarishni saqlab bo‘lmadi';

  @override
  String get routineEditConflict =>
      'Namoz tartibi o‘zgardi. Joriy holat ko‘rsatildi — amalni qaytaring.';

  @override
  String get recallModeTitle => 'Xotiradan tekshiruv';

  @override
  String get recallStartAction => 'Xotiradan tekshirish';

  @override
  String get recallRangeTitle => 'Qaysi oyatlar?';

  @override
  String get recallRangeFrom => 'Oyatdan';

  @override
  String get recallRangeTo => 'Oyatgacha';

  @override
  String get recallRangeInvalid =>
      'Oxirgi oyat birinchisidan oldin bo‘la olmaydi.';

  @override
  String get recallBegin => 'Boshlash';

  @override
  String recallHiddenTitle(int number) {
    return '$number-oyat';
  }

  @override
  String get recallHiddenHint => 'Uni yoddan o‘qing, so‘ng matnni oching.';

  @override
  String get recallReveal => 'Oyatni ko‘rsatish';

  @override
  String get recallResultRecalled => 'Esladim';

  @override
  String get recallResultWithMistake => 'Xato bilan';

  @override
  String get recallResultNotRecalled => 'Eslay olmadim';

  @override
  String get recallSkip => 'Keyingi';

  @override
  String recallProgress(int done, int total) {
    return '$total dan $done';
  }

  @override
  String get recallFinishedTitle => 'Tekshiruv yakunlandi';

  @override
  String recallFinishedBody(int recalled, int withMistake, int notRecalled) {
    return 'Esladim: $recalled · Xato bilan: $withMistake · Eslay olmadim: $notRecalled';
  }

  @override
  String get recallSelfAssessment =>
      'Bahoni o‘zingiz qo‘yasiz — ilova qiroatni tinglamaydi va tekshirmaydi.';

  @override
  String get recallPriorityNote =>
      'Xato deb belgilangan oyatlar takrorlash takliflarida yuqoriga ko‘tariladi. Boshqa hech narsa o‘zgarmaydi.';

  @override
  String get recallSaveFailed => 'Natijani saqlab bo‘lmadi';

  @override
  String get recallClose => 'Tayyor';

  @override
  String get recallHistoryTitle => 'Xotira tekshiruvlari';

  @override
  String get recallNoHistory => 'Hozircha tekshiruv yo‘q.';

  @override
  String recallSurahSummary(int recalled, int imperfect) {
    return '$recalled esladim · $imperfect takrorlash';
  }
}
