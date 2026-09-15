# Backlog после Sprint 5E2

Ниже только осознанно не реализованные функции. Автоматическое расписание
намаза, добровольная location, Android direct widget mark, Quran display
layers, configurable prayer routines, contextual prayer recommendations
(включая Isha → Witr transition), Home prayer schedule strip, Prayer Times
widget, opt-in Learning notification и опциональный `MurajaahDreamService`
screensaver уже не являются backlog.

Полноценный lock-screen widget (в стиле pre-API-21 keyguard widgets) не
входит в backlog как *невыполненная* задача: современный Android не
предоставляет для этого публичный, не обходящий lock screen API, поэтому
это задокументированное платформенное ограничение, а не элемент, который
можно запланировать. См. [LOCK_SCREEN_LEARNING.md](LOCK_SCREEN_LEARNING.md).

0. **Пожелание пользователя от 2026-09-14, отложено до следующего спринта по его
   прямому указанию:** виджет «Время намаза» должен выглядеть как в приложении
   **Sajda**. Текущий вид (compact/medium/large, собственная вёрстка Glance)
   остаётся как есть, потому что этого требования не было в действующем
   continuation-промте. Перед реализацией нужен конкретный референс (скриншот
   или описание нужной компоновки) — копировать чужой дизайн один в один
   нельзя, требуется собственная вёрстка, передающая ту же идею.
1. Prayer notifications и системные alarms.
2. Adhan audio.
3. Qibla compass.
4. Mosque finder.
5. Ramadan calendar и Hijri calendar.
6. Полноценный Quran reader.
7. Word-by-word translation.
8. Optional per-surah offline audio with explicit storage size, integrity metadata, and removal controls.

## After Sprint 5D audio

- Persist the preferred reciter/moshaf only after defining behavior when the live catalog removes or changes it.
- Optional configurable silence between finite learning repeats.
- Device matrix validation for Bluetooth/headset interruption, Android Auto, and OEM battery restrictions.
9. Tajweed highlighting.
10. Более читабельная transliteration от нового документированного provider;
    источник с client secret требует backend proxy.
11. Разрешение на commercial/monetized redistribution bundled Tanzil English
    Transliteration; до этого production release с asset заблокирован.
12. Разрешение неоднозначных district aliases Namoz-vaqti.uz после публикации
    стабильных provider slugs.
13. Подтверждённая публичная спецификация
    `Fatvo markazi taqvim mezonlari`; до неё generic calculation не
    называется методом ОМИ.
14. Prayer rules beyond the implemented schedule boundaries and the existing
    explicit Hanafi/Shafi Asr selector/manual offsets.
15. Рекомендации для пары сур между ракаатами.
16. Полная модель каждого отдельного ракаата; сейчас хранится
    `rakaatSpanCount` 1–4.
17. Импорт Google Tasks.
18. Server, account registration и multi-device sync.
19. Cloud backup, Google Drive и iCloud.
20. Apple/Google sign-in.
21. Production WidgetKit extension и отдельный iOS location/widget QA sprint.
22. Wearable integration.
23. Дополнительная аналитика поверх full-equivalent/action/part-credit metrics.
24. Streaks и социальные функции.
25. Повторно проверить JSON API для официальных `uzbek_mokhtasar` и
    `uzbek_moyassar`; подключать только после полного 114/6236/hash audit.
26. Подключить Cyrillic transliteration только из полного coordinate-aligned
    dataset с доказанными provenance и license; generated conversion запрещена.
    Аудит 20 кандидатов (2026-09-04) не нашёл ни одного проходящего source;
    подробности и что могло бы изменить решение —
    [QURAN_CYRILLIC_TRANSLITERATION_AUDIT.md](QURAN_CYRILLIC_TRANSLITERATION_AUDIT.md).
27. Второй вариант Prayer Times Widget — **горизонтальный список**, как полоса
    времён намаза в самом приложении под текущим намазом. Запрошен владельцем
    2026-09-15 во время приёмки; он же попросил не делать это сейчас, а взять в
    следующий спринт. Текущий вертикальный вариант остаётся; это дополнительный
    размер/раскладка того же провайдера, а не второй resolver — Kotlin
    по-прежнему только рисует. Уже существующий `SizeMode.Responsive` в
    `PrayerWidget.kt` и чистый `PrayerWidgetProjectionFactory` — подходящая
    точка расширения. Ранее владелец упоминал как ориентир виджет приложения
    Sajda; **не копировать их дизайн** — взять собственную полосу приложения.

Отдельные release/operational gates, а не новые product features:

- physical Android QA интерактивного widget на целевых launchers;
- измерение tap → DB → redraw и Home micro-lag на реальном устройстве;
- offline/airplane-mode проверка Quran translation и prayer cache;
- iOS device QA location permission.

Новая религиозная логика требует подтверждённых источников. Геолокация остаётся
только добровольной, а server/sync и backup требуют threat model и privacy
policy. План backend находится в [SERVER_PLAN.md](SERVER_PLAN.md).
