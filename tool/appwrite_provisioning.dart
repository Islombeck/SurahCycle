/// The cloud shape SurahCycle's sync needs, declared once and diffed.
///
/// This file **cannot reach Appwrite**, and that is deliberate. Provisioning is
/// applied through the authenticated MCP connection, which belongs to the
/// agent's session, not to a script; a script that could apply it would need an
/// admin API key, and §6.2 forbids one ever reaching this repository. So the
/// declaration and the diff live here, in something reviewable and testable,
/// and the apply step is a separate, deliberate act that executes exactly the
/// operations this planner emits.
///
/// Two properties the tests pin, because both are easy to lose:
///
/// - **Idempotent.** Planning against the state the plan produces yields an
///   empty plan. Re-running is a no-op, not a second database.
/// - **Additive only.** No operation this planner can emit drops, truncates or
///   overwrites anything. A migration that needs to remove something is a
///   separate, explicit exercise with the owner in the room.
library;

/// Appwrite column types this declaration uses, spelled exactly as the
/// `tables_db` operator surface spells them.
enum AppwriteColumnType { string, integer, datetime, enumeration, longtext }

final class AppwriteColumn {
  const AppwriteColumn({
    required this.key,
    required this.type,
    required this.required,
    this.size,
    this.elements = const <String>[],
  });

  final String key;
  final AppwriteColumnType type;

  // ignore: avoid_positional_boolean_parameters
  final bool required;

  /// Mandatory for `string`; meaningless for the rest.
  final int? size;

  /// The white-list for an `enum` column.
  final List<String> elements;

  Map<String, Object?> toArgument() => <String, Object?>{
    'key': key,
    'type': switch (type) {
      AppwriteColumnType.string => 'string',
      AppwriteColumnType.integer => 'integer',
      AppwriteColumnType.datetime => 'datetime',
      AppwriteColumnType.enumeration => 'enum',
      AppwriteColumnType.longtext => 'longtext',
    },
    if (size != null) 'size': size,
    if (elements.isNotEmpty) 'elements': elements,
    'required': required,
  };
}

final class AppwriteIndex {
  const AppwriteIndex({
    required this.key,
    required this.type,
    required this.columns,
  });

  final String key;

  /// `key` or `unique`; the spatial and fulltext kinds are not used here.
  final String type;
  final List<String> columns;

  Map<String, Object?> toArgument() => <String, Object?>{
    'key': key,
    'type': type,
    'attributes': columns,
  };
}

/// One step of the plan, carrying the exact MCP call that performs it.
final class AppwriteOperation {
  const AppwriteOperation({
    required this.toolName,
    required this.arguments,
    required this.description,
  });

  final String toolName;
  final Map<String, Object?> arguments;
  final String description;

  @override
  String toString() => '$toolName — $description';
}

/// What the project must contain for sync to work. Derived from
/// `docs/ACCOUNT_SYNC_ARCHITECTURE.md`, not invented here.
abstract final class AppwriteDesiredState {
  /// Both ids stay well inside Appwrite's 36-character limit and use only
  /// characters it accepts.
  static const String databaseId = 'surahcycle';
  static const String databaseName = 'SurahCycle';

  /// One table holds the whole sync log. The envelope is already the unit that
  /// crosses the boundary, so a table per entity type would add joins and a
  /// second place for the entity vocabulary to drift out of step.
  static const String syncTableId = 'sync_log';
  static const String syncTableName = 'Sync log';

  /// Authenticated users may create their own rows, and nothing more. Read,
  /// update and delete are decided per row, which is what keeps one account's
  /// history invisible to another.
  static const List<String> syncTablePermissions = <String>['create("users")'];

  /// Per-row permissions are the whole point: without this, table-level rights
  /// would apply to every row and every user.
  static const bool syncTableRowSecurity = true;

  static const List<String> entityTypes = <String>[
    'recitationEvent',
    'learningState',
    'learningEvent',
    'recallAttempt',
    'rotationState',
    'rotationScheme',
    'rotationAdjustment',
    'masteredSurah',
    'prayerRoutineTemplate',
    'prayerSession',
    'appSetting',
  ];

  static const List<AppwriteColumn> syncColumns = <AppwriteColumn>[
    // The owner. Also carried in every row's permissions; stored as data too so
    // a query can filter by it without relying on permission filtering.
    AppwriteColumn(
      key: 'userId',
      type: AppwriteColumnType.string,
      size: 64,
      required: true,
    ),
    AppwriteColumn(
      key: 'deviceId',
      type: AppwriteColumnType.string,
      size: 64,
      required: true,
    ),
    AppwriteColumn(
      key: 'entityType',
      type: AppwriteColumnType.enumeration,
      elements: entityTypes,
      required: true,
    ),
    AppwriteColumn(
      key: 'entityId',
      type: AppwriteColumnType.string,
      size: 64,
      required: true,
    ),
    AppwriteColumn(
      key: 'operation',
      type: AppwriteColumnType.enumeration,
      elements: <String>['upsert', 'delete'],
      required: true,
    ),
    AppwriteColumn(
      key: 'schemaVersion',
      type: AppwriteColumnType.integer,
      required: true,
    ),
    // The client clock, never rewritten by the server: it records when the fact
    // happened, which the server cannot know.
    AppwriteColumn(
      key: 'createdAtUtc',
      type: AppwriteColumnType.datetime,
      required: true,
    ),
    AppwriteColumn(
      key: 'updatedAtUtc',
      type: AppwriteColumnType.datetime,
      required: true,
    ),
    AppwriteColumn(
      key: 'idempotencyKey',
      type: AppwriteColumnType.string,
      size: 128,
      required: true,
    ),
    // Optional because a tombstone carries no payload — keeping the last known
    // values on a delete is how resurrection bugs start.
    AppwriteColumn(
      key: 'payload',
      type: AppwriteColumnType.longtext,
      required: false,
    ),
  ];

  static const List<AppwriteIndex> syncIndexes = <AppwriteIndex>[
    // The pull cursor: one owner's changes, oldest first.
    AppwriteIndex(
      key: 'by_owner_updated',
      type: 'key',
      columns: <String>['userId', 'updatedAtUtc'],
    ),
    // Finding the current row for one entity.
    AppwriteIndex(
      key: 'by_owner_entity',
      type: 'key',
      columns: <String>['userId', 'entityType', 'entityId'],
    ),
    // Scoped to the owner rather than global: an idempotency key is generated
    // on a device and means nothing outside the account that produced it, so a
    // global unique index would let one account's key collide with another's.
    AppwriteIndex(
      key: 'by_owner_idempotency',
      type: 'unique',
      columns: <String>['userId', 'idempotencyKey'],
    ),
  ];
}

/// What the project currently has, as read back from Appwrite.
final class AppwriteObservedState {
  const AppwriteObservedState({
    this.databaseIds = const <String>{},
    this.tableIds = const <String>{},
    this.indexKeys = const <String>{},
  });

  final Set<String> databaseIds;

  /// Table ids **within** [AppwriteDesiredState.databaseId].
  final Set<String> tableIds;

  /// Index keys within the sync table.
  final Set<String> indexKeys;
}

final class AppwriteProvisioner {
  const AppwriteProvisioner();

  /// The ordered operations that bring [observed] up to the declaration.
  ///
  /// Order matters and is not cosmetic: a table cannot be created before its
  /// database, and an index cannot be created before the table it indexes.
  List<AppwriteOperation> plan(AppwriteObservedState observed) {
    final operations = <AppwriteOperation>[];

    if (!observed.databaseIds.contains(AppwriteDesiredState.databaseId)) {
      operations.add(
        const AppwriteOperation(
          toolName: 'tables_db_create',
          arguments: <String, Object?>{
            'database_id': AppwriteDesiredState.databaseId,
            'name': AppwriteDesiredState.databaseName,
            'enabled': true,
          },
          description: 'Create the SurahCycle database (serverless).',
        ),
      );
    }

    final hasTable = observed.tableIds.contains(
      AppwriteDesiredState.syncTableId,
    );
    if (!hasTable) {
      // Columns and indexes go in the same call. One round trip means the table
      // cannot exist in a half-built state that a later failure would leave
      // behind for someone to finish by hand.
      operations.add(
        AppwriteOperation(
          toolName: 'tables_db_create_table',
          arguments: <String, Object?>{
            'database_id': AppwriteDesiredState.databaseId,
            'table_id': AppwriteDesiredState.syncTableId,
            'name': AppwriteDesiredState.syncTableName,
            'permissions': AppwriteDesiredState.syncTablePermissions,
            'row_security': AppwriteDesiredState.syncTableRowSecurity,
            'enabled': true,
            'columns': <Map<String, Object?>>[
              for (final column in AppwriteDesiredState.syncColumns)
                column.toArgument(),
            ],
            'indexes': <Map<String, Object?>>[
              for (final index in AppwriteDesiredState.syncIndexes)
                index.toArgument(),
            ],
          },
          description:
              'Create the sync log table with row-level security, '
              '${AppwriteDesiredState.syncColumns.length} columns and '
              '${AppwriteDesiredState.syncIndexes.length} indexes.',
        ),
      );
      return List<AppwriteOperation>.unmodifiable(operations);
    }

    // The table already exists, so only missing indexes remain. Existing
    // columns are deliberately not touched: changing one is a migration, not
    // provisioning, and doing it silently could drop data.
    for (final index in AppwriteDesiredState.syncIndexes) {
      if (observed.indexKeys.contains(index.key)) continue;
      operations.add(
        AppwriteOperation(
          toolName: 'tables_db_create_index',
          arguments: <String, Object?>{
            'database_id': AppwriteDesiredState.databaseId,
            'table_id': AppwriteDesiredState.syncTableId,
            'key': index.key,
            'type': index.type,
            'columns': index.columns,
          },
          description: 'Create the missing index "${index.key}".',
        ),
      );
    }
    return List<AppwriteOperation>.unmodifiable(operations);
  }

  /// The state that applying [plan] to [observed] produces, so a caller — and
  /// the idempotency test — can plan again without touching the network.
  AppwriteObservedState apply(AppwriteObservedState observed) {
    final operations = plan(observed);
    var databases = observed.databaseIds;
    var tables = observed.tableIds;
    var indexes = observed.indexKeys;
    for (final operation in operations) {
      switch (operation.toolName) {
        case 'tables_db_create':
          databases = <String>{...databases, AppwriteDesiredState.databaseId};
        case 'tables_db_create_table':
          tables = <String>{...tables, AppwriteDesiredState.syncTableId};
          indexes = <String>{
            ...indexes,
            for (final index in AppwriteDesiredState.syncIndexes) index.key,
          };
        case 'tables_db_create_index':
          indexes = <String>{...indexes, operation.arguments['key']! as String};
      }
    }
    return AppwriteObservedState(
      databaseIds: databases,
      tableIds: tables,
      indexKeys: indexes,
    );
  }
}

/// Prints the plan. Reads nothing and writes nothing.
void main(List<String> arguments) {
  final observed = const AppwriteObservedState();
  final operations = const AppwriteProvisioner().plan(observed);
  if (operations.isEmpty) {
    // ignore: avoid_print
    print('Nothing to do: the project already matches the declaration.');
    return;
  }
  // ignore: avoid_print
  print('Dry run — ${operations.length} operation(s), nothing was sent:');
  for (var index = 0; index < operations.length; index += 1) {
    // ignore: avoid_print
    print('  ${index + 1}. ${operations[index]}');
  }
}
