# План будущего сервера

## Статус

Backend не входит в Sprint 1 и не нужен для работы приложения. Локальная база остаётся первичным местом записи: пользователь может регистрировать чтения, учиться и смотреть историю без аккаунта и сети.

Этот документ задаёт границы будущей интеграции, но не выбирает окончательный framework. Возможный стек — Spring Boot + PostgreSQL; эквивалентная технология допустима при соблюдении контрактов.

## Задачи будущего backend

- аккаунты и управление устройствами;
- синхронизация пользовательских событий между устройствами;
- резервные копии и восстановление;
- proxy для Quran API, требующих secret credentials;
- кеширование, проверка provenance и версионирование Quran content;
- выдача клиентам манифеста доступных версий контента.

Сервер не должен становиться обязательным посредником для локальной регистрации прочтения.

## Граница мобильного приложения

Mobile domain работает через нейтральные интерфейсы:

```text
UserEventStore        // локальная запись и чтение журнала
SyncGateway           // push/pull event envelopes
BackupGateway         // export/restore пользовательских данных
QuranContentRepository
AuthSessionStore
```

HTTP DTO не проникают в `RotationEngine` или `LearningStateMachine`. Remote adapter можно заменить без миграции доменного кода. До появления сервера implementations `SyncGateway` и account features отсутствуют/выключены, а не имитируют успешную синхронизацию.

## Предлагаемая серверная модель

### Пользовательские данные

- `User` — id, lifecycle status, timestamps.
- `Device` — id, user id, public metadata, last sync cursor, revokedAt.
- `EventEnvelope` — immutable event id UUID, user/device id, event type, schema version, client UTC time, captured local date/offset, device sequence, server cursor, payload hash, payload, receivedAt.
- `EventTombstone` — id удалённого события, deleting event id, reason, timestamps.
- `BackupSnapshot` — user id, schema/projection version, encrypted object reference/checksum, cursor, createdAt.
- `UserProjection` — необязательный серверный cache статистики; его всегда можно перестроить из журнала.

### Quran content

- `QuranDataset` — provider, dataset/translation key, version, language, status, attribution, license metadata, checksum.
- `QuranDatasetArtifact` — immutable file/object reference и manifest.
- `ProviderCredential` — только в secret manager, никогда в таблице открытым текстом и никогда в mobile response.

Пользовательский event store и Quran datasets физически/логически разделяются.

## Синхронизация событий

Базовый протокол:

1. Клиент сначала коммитит событие локально и помечает его `pendingSync`.
2. `push` отправляет пачку envelope с UUID и device sequence.
3. Сервер принимает события идемпотентно: повтор UUID не создаёт дубликат.
4. Сервер назначает монотонный cursor в пределах пользователя.
5. `pull(afterCursor)` возвращает новые события и tombstones страницами.
6. Клиент сохраняет пачку транзакционно и перестраивает затронутые проекции.
7. Cursor продвигается только после успешного локального commit.

Синхронизируются факты, а не значения `totalRecitations` и не произвольно слитые snapshots. Исторический total после merge снова получается из неудалённых `RecitationEvent`; `rotationScore` — из recitations и отдельных adjustment events.

## Конфликты

До реализации нужен отдельный ADR и property-based tests. Начальные правила:

- события объединяются по UUID;
- tombstone побеждает событие, на которое ссылается, и не удаляется из sync log;
- повторная доставка безопасна;
- aliases, порядок и настройки используют versioned mutation с детерминированным разрешением конфликта, а проигравшая версия остаётся доступна аудиту;
- server time не переписывает `occurredAtUtc`, но отдельно хранит `receivedAt`;
- materialized counters не суммируются между устройствами;
- после появления канонического порядка событий клиент rebuild-проекцию;
- глобальный target при merge не уменьшается; Undo остаётся локальной отменой последнего ещё не синхронизированного действия либо порождает явное compensating event после sync.

Особенно требуется формально определить конкурентные первое включение суры, manual adjustment и удаление. До этого multi-device sync не выпускается.

## API-контуры

Возможный versioned REST-контракт:

```text
POST   /v1/auth/...
GET    /v1/devices
DELETE /v1/devices/{id}
POST   /v1/sync/events:push
GET    /v1/sync/events:pull?after=<cursor>
POST   /v1/backups
GET    /v1/backups/latest
GET    /v1/quran/datasets
GET    /v1/quran/datasets/{id}/manifest
GET    /v1/quran/datasets/{id}/artifact
```

Имена предварительные. Контракт публикуется как OpenAPI/эквивалент, поддерживает schema version, pagination, request id и ограничение размера пачки.

## Quran API proxy

Proxy нужен только если официальный provider требует секрет, непригодный для public mobile client.

- credential хранится в managed secret store;
- server соблюдает rate limits и условия provider;
- ответ кешируется только если это разрешено лицензией;
- dataset проходит проверку и получает immutable version/checksum;
- клиент получает attribution/license manifest вместе с данными;
- религиозный текст не нормализуется и не «исправляется»;
- scraping и private endpoints не используются.

Даже server proxy не делает непроверенный источник допустимым.

## Безопасность

- TLS для всего внешнего трафика;
- короткоживущие access tokens и ротация refresh tokens;
- секреты в secret manager, раздельные environments и least privilege;
- пароли, если они появятся, хешируются современной password KDF; предпочтительны проверенные identity providers;
- server-side authorization на каждом user-owned resource;
- rate limiting, audit trail административных действий и защита от replay;
- шифрование backups и server storage, управление ключами отдельно от БД;
- минимизация PII: история религиозной практики рассматривается как чувствительная;
- запрет содержимого событий и токенов в обычных application logs;
- удаление аккаунта включает понятную retention policy и очистку backups;
- security review перед включением регистрации и sync.

## Backup и восстановление

Backup содержит пользовательские события, mastered state, learning progress и настройки. Quran content не включается по умолчанию и повторно скачивается по manifest. Restore сначала валидирует schema/version/checksum во временном хранилище, затем атомарно импортирует журнал и rebuild-проекции; существующие данные не перезаписываются частично.

Пользователю заранее показываются состав, дата и результат восстановления. Серверный backup не отменяет локальный JSON export как переносимый формат.

## Наблюдаемость

Допустимы технические метрики latency/error rate/sync lag без содержимого чтений. Audit события доступа к секретам и административного изменения dataset обязательны. Алерты должны различать отказ provider и отказ основной sync-инфраструктуры.

## Этапы реализации

1. ADR протокола, threat model и версия локального event schema.
2. Анонимный локальный export/import и тест восстановления.
3. Account/device API и безопасное хранение сессии.
4. Односторонний encrypted backup.
5. Event push/pull для одного устройства с идемпотентностью.
6. Multi-device conflict suite и staged rollout.
7. Quran proxy/cache только для проверенного provider и лицензии.
8. Инструменты удаления аккаунта, audit и disaster recovery.

## Что Sprint 1 готовит заранее

- стабильные UUID событий;
- UTC timestamp и неизменяемую local date;
- event types и schema/algorithm versions;
- tombstone-ready удаление;
- snapshot + journal и воспроизводимый rebuild;
- repository boundaries вместо прямой зависимости UI от Drift или HTTP;
- отсутствие client secrets.

Никакие server endpoints, account screens, фоновые sync-задачи или credentials в Sprint 1 не создаются.
