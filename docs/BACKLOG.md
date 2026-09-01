# Backlog после Sprint 4

Ниже только осознанно не реализованные функции. Автоматическое расписание
намаза, добровольная location, Android direct widget mark и Quran display
layers уже не являются backlog.

1. Prayer notifications и системные alarms.
2. Adhan audio.
3. Qibla compass.
4. Mosque finder.
5. Ramadan calendar и Hijri calendar.
6. Полноценный Quran reader.
7. Word-by-word translation.
8. Quran audio и выбор чтеца.
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
14. Prayer rules beyond the implemented schedule boundaries, explicit
    Hanafi/Shafi Asr selector and manual offsets.
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

Отдельные release/operational gates, а не новые product features:

- physical Android QA интерактивного widget на целевых launchers;
- измерение tap → DB → redraw и Home micro-lag на реальном устройстве;
- offline/airplane-mode проверка Quran translation и prayer cache;
- iOS device QA location permission.

Новая религиозная логика требует подтверждённых источников. Геолокация остаётся
только добровольной, а server/sync и backup требуют threat model и privacy
policy. План backend находится в [SERVER_PLAN.md](SERVER_PLAN.md).
