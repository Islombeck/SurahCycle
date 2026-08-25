# Backlog после Sprint 2

Ниже перечислены функции, осознанно не реализованные в Sprint 2:

1. Автоматические времена намаза.
2. Геолокация.
3. Notifications.
4. Сервер.
5. Регистрация пользователя.
6. Синхронизация нескольких устройств.
7. Полноценный Quran reader.
8. Аудио аятов.
9. Выбор чтеца.
10. Tajweed highlighting.
11. Расширенные правила мазхаба.
12. Рекомендации для пары сур между ракаатами.
13. Импорт Google Tasks.
14. Cloud backup.
15. iCloud.
16. Google Drive backup.
17. Production WidgetKit extension и iOS/Mac device QA. Общий snapshot-контракт уже подготовлен.
18. Прямая отметка прочтения из Android/iOS widget.
19. Полная модель каждого отдельного ракаата; сейчас хранится только `rakaatSpanCount` 1–4.
20. Wearable integration.
21. Дополнительная аналитика поверх уже реализованных full-equivalent/action/part-credit метрик.
22. Streaks.
23. Apple/Google sign-in.

Для будущей функции создаётся отдельный product/architecture review. В частности, религиозные правила нельзя реализовывать на предположениях, геолокация требует явного разрешения, а server/sync и cloud backup требуют threat model и политики приватности.

Этот файл не заявляет порядок реализации. План backend вынесен в [SERVER_PLAN.md](SERVER_PLAN.md).
