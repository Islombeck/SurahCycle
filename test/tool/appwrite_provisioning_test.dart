import 'package:flutter_test/flutter_test.dart';

import '../../tool/appwrite_provisioning.dart';

/// Stage J §6.2: the provisioning definition is versioned, reviewable,
/// idempotent, and has a dry run. Nothing here touches a network — the planner
/// cannot, by design, because a script able to apply this would need an admin
/// API key and one must never reach this repository.
void main() {
  const provisioner = AppwriteProvisioner();
  const empty = AppwriteObservedState();

  group('a fresh project', () {
    test('is brought up in two operations, database first', () {
      final plan = provisioner.plan(empty);

      expect(
        plan.map((operation) => operation.toolName),
        <String>['tables_db_create', 'tables_db_create_table'],
        reason: 'a table cannot exist before its database',
      );
    });

    test('the table is created with its columns and indexes in one call', () {
      final table = provisioner
          .plan(empty)
          .firstWhere(
            (operation) => operation.toolName == 'tables_db_create_table',
          );
      final columns = table.arguments['columns']! as List<Object?>;
      final indexes = table.arguments['indexes']! as List<Object?>;

      expect(
        columns,
        hasLength(AppwriteDesiredState.syncColumns.length),
        reason: 'one round trip leaves no half-built table behind on failure',
      );
      expect(indexes, hasLength(AppwriteDesiredState.syncIndexes.length));
    });
  });

  group('observed state read back from a live project', () {
    test('a fully provisioned project plans nothing', () {
      // The exact shape Appwrite returned on 2026-09-18, after the apply. This
      // is what makes the declaration *checkable* against the project instead
      // of merely applicable to it.
      final observed = AppwriteObservedState.fromJson(<String, Object?>{
        'databaseIds': <Object?>['surahcycle'],
        'tableIds': <Object?>['sync_log'],
        'indexKeys': <Object?>[
          'by_owner_updated',
          'by_owner_entity',
          'by_owner_idempotency',
        ],
      });

      expect(provisioner.plan(observed), isEmpty);
    });

    test('a missing key is absent, not an error', () {
      final observed = AppwriteObservedState.fromJson(
        const <String, Object?>{},
      );

      expect(
        provisioner.plan(observed).map((operation) => operation.toolName),
        <String>['tables_db_create', 'tables_db_create_table'],
        reason:
            'treating an unreadable field as "already there" would skip work '
            'and leave a half-built project nobody notices',
      );
    });

    test('values that are not strings are ignored rather than trusted', () {
      final observed = AppwriteObservedState.fromJson(<String, Object?>{
        'databaseIds': <Object?>[42, null, 'surahcycle'],
        'tableIds': 'sync_log',
      });

      expect(observed.databaseIds, <String>{'surahcycle'});
      expect(
        observed.tableIds,
        isEmpty,
        reason:
            'a bare string is not a list, and guessing at it would claim '
            'the table exists on the strength of a typo',
      );
    });

    test('a half-provisioned project plans only what is missing', () {
      final observed = AppwriteObservedState.fromJson(<String, Object?>{
        'databaseIds': <Object?>['surahcycle'],
      });

      expect(
        provisioner.plan(observed).map((operation) => operation.toolName),
        <String>['tables_db_create_table'],
        reason: 'the database is there; creating it again would fail loudly',
      );
    });
  });

  group('owner isolation is in the declaration, not in a promise', () {
    test('rows carry their own permissions', () {
      final table = provisioner
          .plan(empty)
          .firstWhere(
            (operation) => operation.toolName == 'tables_db_create_table',
          );

      expect(
        table.arguments['row_security'],
        isTrue,
        reason:
            'without this, table rights would apply to every row and one '
            'account would see another\'s history',
      );
    });

    test('the table grants create, and nothing else', () {
      final table = provisioner
          .plan(empty)
          .firstWhere(
            (operation) => operation.toolName == 'tables_db_create_table',
          );
      final permissions = table.arguments['permissions']! as List<Object?>;

      expect(permissions, <String>['create("users")']);
      for (final permission in permissions) {
        expect(
          permission,
          isNot(contains('any')),
          reason: 'no public read or write, ever',
        );
      }
    });

    test('idempotency is unique per owner, not globally', () {
      final index = AppwriteDesiredState.syncIndexes.firstWhere(
        (candidate) => candidate.type == 'unique',
      );

      expect(index.columns.first, 'userId');
      expect(
        index.columns,
        contains('idempotencyKey'),
        reason:
            'a key generated on one device means nothing outside the '
            'account that produced it, so a global unique index would let two '
            'accounts collide',
      );
    });
  });

  group('idempotent', () {
    test('planning against what the plan produces yields nothing', () {
      final after = provisioner.apply(empty);

      expect(
        provisioner.plan(after),
        isEmpty,
        reason: 'running it twice must not create a second database',
      );
    });

    test('an existing database still gets its table', () {
      final plan = provisioner.plan(
        const AppwriteObservedState(databaseIds: <String>{'surahcycle'}),
      );

      expect(plan.map((operation) => operation.toolName), <String>[
        'tables_db_create_table',
      ]);
    });

    test('a table missing one index gets exactly that index', () {
      final plan = provisioner.plan(
        AppwriteObservedState(
          databaseIds: const <String>{'surahcycle'},
          tableIds: const <String>{'sync_log'},
          indexKeys: <String>{
            for (final index in AppwriteDesiredState.syncIndexes.skip(1))
              index.key,
          },
        ),
      );

      expect(plan, hasLength(1));
      expect(plan.single.toolName, 'tables_db_create_index');
      expect(
        plan.single.arguments['key'],
        AppwriteDesiredState.syncIndexes.first.key,
      );
    });

    test('an existing table is never rebuilt', () {
      final plan = provisioner.plan(
        AppwriteObservedState(
          databaseIds: const <String>{'surahcycle'},
          tableIds: const <String>{'sync_log'},
          indexKeys: <String>{
            for (final index in AppwriteDesiredState.syncIndexes) index.key,
          },
        ),
      );

      expect(plan, isEmpty);
    });
  });

  group('additive only', () {
    test('no operation can destroy anything', () {
      // Guards the rule rather than today's list: a later edit that adds a
      // delete or update step fails here instead of in the owner's project.
      final states = <AppwriteObservedState>[
        empty,
        const AppwriteObservedState(databaseIds: <String>{'surahcycle'}),
        const AppwriteObservedState(
          databaseIds: <String>{'surahcycle'},
          tableIds: <String>{'sync_log'},
        ),
      ];
      for (final state in states) {
        for (final operation in provisioner.plan(state)) {
          expect(
            operation.toolName,
            startsWith('tables_db_create'),
            reason:
                'provisioning creates; removing anything is a separate, '
                'deliberate exercise',
          );
        }
      }
    });
  });

  group('the declaration matches the sync model', () {
    test('every envelope field has a column', () {
      final keys = <String>{
        for (final column in AppwriteDesiredState.syncColumns) column.key,
      };

      expect(keys, <String>{
        'userId',
        'deviceId',
        'entityType',
        'entityId',
        'operation',
        'schemaVersion',
        'createdAtUtc',
        'updatedAtUtc',
        'idempotencyKey',
        'payload',
      });
    });

    test('a tombstone can be stored, so payload is optional', () {
      final payload = AppwriteDesiredState.syncColumns.firstWhere(
        (column) => column.key == 'payload',
      );

      expect(
        payload.required,
        isFalse,
        reason:
            'a delete carries no payload; keeping the last known values is '
            'how resurrection bugs start',
      );
    });

    test('the entity vocabulary is the domain\'s, in full', () {
      final entityType = AppwriteDesiredState.syncColumns.firstWhere(
        (column) => column.key == 'entityType',
      );

      expect(entityType.elements, AppwriteDesiredState.entityTypes);
      expect(entityType.elements, hasLength(11));
      expect(
        entityType.elements,
        isNot(contains('widgetSnapshot')),
        reason:
            'derived snapshots are rebuildable and are deliberately not '
            'synced; syncing one would create a second source of truth',
      );
    });

    test('ids stay inside Appwrite\'s limits', () {
      for (final id in <String>[
        AppwriteDesiredState.databaseId,
        AppwriteDesiredState.syncTableId,
      ]) {
        expect(id.length, lessThanOrEqualTo(36));
        expect(RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$').hasMatch(id), isTrue);
      }
      for (final index in AppwriteDesiredState.syncIndexes) {
        expect(index.key.length, lessThanOrEqualTo(36));
      }
    });

    test('every string column declares a size, and no other type does', () {
      for (final column in AppwriteDesiredState.syncColumns) {
        if (column.type == AppwriteColumnType.string) {
          expect(column.size, isNotNull, reason: '${column.key} needs a size');
        } else {
          expect(
            column.size,
            isNull,
            reason: '${column.key} must not have one',
          );
        }
      }
    });
  });
}
