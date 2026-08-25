// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SurahMetadataTable extends SurahMetadata
    with TableInfo<$SurahMetadataTable, SurahMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurahMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surahNumberMeta = const VerificationMeta(
    'surahNumber',
  );
  @override
  late final GeneratedColumn<int> surahNumber = GeneratedColumn<int>(
    'surah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _officialNameMeta = const VerificationMeta(
    'officialName',
  );
  @override
  late final GeneratedColumn<String> officialName = GeneratedColumn<String>(
    'official_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahCountMeta = const VerificationMeta(
    'ayahCount',
  );
  @override
  late final GeneratedColumn<int> ayahCount = GeneratedColumn<int>(
    'ayah_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceVersionMeta = const VerificationMeta(
    'sourceVersion',
  );
  @override
  late final GeneratedColumn<String> sourceVersion = GeneratedColumn<String>(
    'source_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surahNumber,
    officialName,
    ayahCount,
    sourceId,
    sourceVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'surah_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurahMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('surah_number')) {
      context.handle(
        _surahNumberMeta,
        surahNumber.isAcceptableOrUnknown(
          data['surah_number']!,
          _surahNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_surahNumberMeta);
    }
    if (data.containsKey('official_name')) {
      context.handle(
        _officialNameMeta,
        officialName.isAcceptableOrUnknown(
          data['official_name']!,
          _officialNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_officialNameMeta);
    }
    if (data.containsKey('ayah_count')) {
      context.handle(
        _ayahCountMeta,
        ayahCount.isAcceptableOrUnknown(data['ayah_count']!, _ayahCountMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahCountMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('source_version')) {
      context.handle(
        _sourceVersionMeta,
        sourceVersion.isAcceptableOrUnknown(
          data['source_version']!,
          _sourceVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SurahMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurahMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      surahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah_number'],
      )!,
      officialName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}official_name'],
      )!,
      ayahCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_count'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      sourceVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_version'],
      ),
    );
  }

  @override
  $SurahMetadataTable createAlias(String alias) {
    return $SurahMetadataTable(attachedDatabase, alias);
  }
}

class SurahMetadataRow extends DataClass
    implements Insertable<SurahMetadataRow> {
  final String id;
  final int surahNumber;
  final String officialName;
  final int ayahCount;
  final String? sourceId;
  final String? sourceVersion;
  const SurahMetadataRow({
    required this.id,
    required this.surahNumber,
    required this.officialName,
    required this.ayahCount,
    this.sourceId,
    this.sourceVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['surah_number'] = Variable<int>(surahNumber);
    map['official_name'] = Variable<String>(officialName);
    map['ayah_count'] = Variable<int>(ayahCount);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sourceVersion != null) {
      map['source_version'] = Variable<String>(sourceVersion);
    }
    return map;
  }

  SurahMetadataCompanion toCompanion(bool nullToAbsent) {
    return SurahMetadataCompanion(
      id: Value(id),
      surahNumber: Value(surahNumber),
      officialName: Value(officialName),
      ayahCount: Value(ayahCount),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      sourceVersion: sourceVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceVersion),
    );
  }

  factory SurahMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurahMetadataRow(
      id: serializer.fromJson<String>(json['id']),
      surahNumber: serializer.fromJson<int>(json['surahNumber']),
      officialName: serializer.fromJson<String>(json['officialName']),
      ayahCount: serializer.fromJson<int>(json['ayahCount']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sourceVersion: serializer.fromJson<String?>(json['sourceVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'surahNumber': serializer.toJson<int>(surahNumber),
      'officialName': serializer.toJson<String>(officialName),
      'ayahCount': serializer.toJson<int>(ayahCount),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sourceVersion': serializer.toJson<String?>(sourceVersion),
    };
  }

  SurahMetadataRow copyWith({
    String? id,
    int? surahNumber,
    String? officialName,
    int? ayahCount,
    Value<String?> sourceId = const Value.absent(),
    Value<String?> sourceVersion = const Value.absent(),
  }) => SurahMetadataRow(
    id: id ?? this.id,
    surahNumber: surahNumber ?? this.surahNumber,
    officialName: officialName ?? this.officialName,
    ayahCount: ayahCount ?? this.ayahCount,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    sourceVersion: sourceVersion.present
        ? sourceVersion.value
        : this.sourceVersion,
  );
  SurahMetadataRow copyWithCompanion(SurahMetadataCompanion data) {
    return SurahMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      officialName: data.officialName.present
          ? data.officialName.value
          : this.officialName,
      ayahCount: data.ayahCount.present ? data.ayahCount.value : this.ayahCount,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceVersion: data.sourceVersion.present
          ? data.sourceVersion.value
          : this.sourceVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurahMetadataRow(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('officialName: $officialName, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceVersion: $sourceVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surahNumber,
    officialName,
    ayahCount,
    sourceId,
    sourceVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurahMetadataRow &&
          other.id == this.id &&
          other.surahNumber == this.surahNumber &&
          other.officialName == this.officialName &&
          other.ayahCount == this.ayahCount &&
          other.sourceId == this.sourceId &&
          other.sourceVersion == this.sourceVersion);
}

class SurahMetadataCompanion extends UpdateCompanion<SurahMetadataRow> {
  final Value<String> id;
  final Value<int> surahNumber;
  final Value<String> officialName;
  final Value<int> ayahCount;
  final Value<String?> sourceId;
  final Value<String?> sourceVersion;
  final Value<int> rowid;
  const SurahMetadataCompanion({
    this.id = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.officialName = const Value.absent(),
    this.ayahCount = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurahMetadataCompanion.insert({
    required String id,
    required int surahNumber,
    required String officialName,
    required int ayahCount,
    this.sourceId = const Value.absent(),
    this.sourceVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       surahNumber = Value(surahNumber),
       officialName = Value(officialName),
       ayahCount = Value(ayahCount);
  static Insertable<SurahMetadataRow> custom({
    Expression<String>? id,
    Expression<int>? surahNumber,
    Expression<String>? officialName,
    Expression<int>? ayahCount,
    Expression<String>? sourceId,
    Expression<String>? sourceVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (officialName != null) 'official_name': officialName,
      if (ayahCount != null) 'ayah_count': ayahCount,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceVersion != null) 'source_version': sourceVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurahMetadataCompanion copyWith({
    Value<String>? id,
    Value<int>? surahNumber,
    Value<String>? officialName,
    Value<int>? ayahCount,
    Value<String?>? sourceId,
    Value<String?>? sourceVersion,
    Value<int>? rowid,
  }) {
    return SurahMetadataCompanion(
      id: id ?? this.id,
      surahNumber: surahNumber ?? this.surahNumber,
      officialName: officialName ?? this.officialName,
      ayahCount: ayahCount ?? this.ayahCount,
      sourceId: sourceId ?? this.sourceId,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (surahNumber.present) {
      map['surah_number'] = Variable<int>(surahNumber.value);
    }
    if (officialName.present) {
      map['official_name'] = Variable<String>(officialName.value);
    }
    if (ayahCount.present) {
      map['ayah_count'] = Variable<int>(ayahCount.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceVersion.present) {
      map['source_version'] = Variable<String>(sourceVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurahMetadataCompanion(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('officialName: $officialName, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MasteredSurahsTable extends MasteredSurahs
    with TableInfo<$MasteredSurahsTable, MasteredSurahRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasteredSurahsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _surahIdMeta = const VerificationMeta(
    'surahId',
  );
  @override
  late final GeneratedColumn<String> surahId = GeneratedColumn<String>(
    'surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES surah_metadata (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _hasEnteredRotationMeta =
      const VerificationMeta('hasEnteredRotation');
  @override
  late final GeneratedColumn<bool> hasEnteredRotation = GeneratedColumn<bool>(
    'has_entered_rotation',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_entered_rotation" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _activationBaselineScoreMeta =
      const VerificationMeta('activationBaselineScore');
  @override
  late final GeneratedColumn<int> activationBaselineScore =
      GeneratedColumn<int>(
        'activation_baseline_score',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cachedRotationScoreMeta =
      const VerificationMeta('cachedRotationScore');
  @override
  late final GeneratedColumn<int> cachedRotationScore = GeneratedColumn<int>(
    'cached_rotation_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _cachedTotalRecitationsMeta =
      const VerificationMeta('cachedTotalRecitations');
  @override
  late final GeneratedColumn<int> cachedTotalRecitations = GeneratedColumn<int>(
    'cached_total_recitations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _cachedLastUsedAtUtcMeta =
      const VerificationMeta('cachedLastUsedAtUtc');
  @override
  late final GeneratedColumn<DateTime> cachedLastUsedAtUtc =
      GeneratedColumn<DateTime>(
        'cached_last_used_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    surahId,
    isActive,
    hasEnteredRotation,
    activationBaselineScore,
    cachedRotationScore,
    cachedTotalRecitations,
    cachedLastUsedAtUtc,
    alias,
    displayOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mastered_surahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasteredSurahRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('surah_id')) {
      context.handle(
        _surahIdMeta,
        surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surahIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('has_entered_rotation')) {
      context.handle(
        _hasEnteredRotationMeta,
        hasEnteredRotation.isAcceptableOrUnknown(
          data['has_entered_rotation']!,
          _hasEnteredRotationMeta,
        ),
      );
    }
    if (data.containsKey('activation_baseline_score')) {
      context.handle(
        _activationBaselineScoreMeta,
        activationBaselineScore.isAcceptableOrUnknown(
          data['activation_baseline_score']!,
          _activationBaselineScoreMeta,
        ),
      );
    }
    if (data.containsKey('cached_rotation_score')) {
      context.handle(
        _cachedRotationScoreMeta,
        cachedRotationScore.isAcceptableOrUnknown(
          data['cached_rotation_score']!,
          _cachedRotationScoreMeta,
        ),
      );
    }
    if (data.containsKey('cached_total_recitations')) {
      context.handle(
        _cachedTotalRecitationsMeta,
        cachedTotalRecitations.isAcceptableOrUnknown(
          data['cached_total_recitations']!,
          _cachedTotalRecitationsMeta,
        ),
      );
    }
    if (data.containsKey('cached_last_used_at_utc')) {
      context.handle(
        _cachedLastUsedAtUtcMeta,
        cachedLastUsedAtUtc.isAcceptableOrUnknown(
          data['cached_last_used_at_utc']!,
          _cachedLastUsedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {surahId};
  @override
  MasteredSurahRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasteredSurahRow(
      surahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surah_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      hasEnteredRotation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_entered_rotation'],
      )!,
      activationBaselineScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activation_baseline_score'],
      ),
      cachedRotationScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_rotation_score'],
      )!,
      cachedTotalRecitations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_total_recitations'],
      )!,
      cachedLastUsedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_last_used_at_utc'],
      ),
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $MasteredSurahsTable createAlias(String alias) {
    return $MasteredSurahsTable(attachedDatabase, alias);
  }
}

class MasteredSurahRow extends DataClass
    implements Insertable<MasteredSurahRow> {
  final String surahId;
  final bool isActive;
  final bool hasEnteredRotation;
  final int? activationBaselineScore;
  final int cachedRotationScore;
  final int cachedTotalRecitations;
  final DateTime? cachedLastUsedAtUtc;
  final String? alias;
  final int displayOrder;
  const MasteredSurahRow({
    required this.surahId,
    required this.isActive,
    required this.hasEnteredRotation,
    this.activationBaselineScore,
    required this.cachedRotationScore,
    required this.cachedTotalRecitations,
    this.cachedLastUsedAtUtc,
    this.alias,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['surah_id'] = Variable<String>(surahId);
    map['is_active'] = Variable<bool>(isActive);
    map['has_entered_rotation'] = Variable<bool>(hasEnteredRotation);
    if (!nullToAbsent || activationBaselineScore != null) {
      map['activation_baseline_score'] = Variable<int>(activationBaselineScore);
    }
    map['cached_rotation_score'] = Variable<int>(cachedRotationScore);
    map['cached_total_recitations'] = Variable<int>(cachedTotalRecitations);
    if (!nullToAbsent || cachedLastUsedAtUtc != null) {
      map['cached_last_used_at_utc'] = Variable<DateTime>(cachedLastUsedAtUtc);
    }
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  MasteredSurahsCompanion toCompanion(bool nullToAbsent) {
    return MasteredSurahsCompanion(
      surahId: Value(surahId),
      isActive: Value(isActive),
      hasEnteredRotation: Value(hasEnteredRotation),
      activationBaselineScore: activationBaselineScore == null && nullToAbsent
          ? const Value.absent()
          : Value(activationBaselineScore),
      cachedRotationScore: Value(cachedRotationScore),
      cachedTotalRecitations: Value(cachedTotalRecitations),
      cachedLastUsedAtUtc: cachedLastUsedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedLastUsedAtUtc),
      alias: alias == null && nullToAbsent
          ? const Value.absent()
          : Value(alias),
      displayOrder: Value(displayOrder),
    );
  }

  factory MasteredSurahRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasteredSurahRow(
      surahId: serializer.fromJson<String>(json['surahId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      hasEnteredRotation: serializer.fromJson<bool>(json['hasEnteredRotation']),
      activationBaselineScore: serializer.fromJson<int?>(
        json['activationBaselineScore'],
      ),
      cachedRotationScore: serializer.fromJson<int>(
        json['cachedRotationScore'],
      ),
      cachedTotalRecitations: serializer.fromJson<int>(
        json['cachedTotalRecitations'],
      ),
      cachedLastUsedAtUtc: serializer.fromJson<DateTime?>(
        json['cachedLastUsedAtUtc'],
      ),
      alias: serializer.fromJson<String?>(json['alias']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'surahId': serializer.toJson<String>(surahId),
      'isActive': serializer.toJson<bool>(isActive),
      'hasEnteredRotation': serializer.toJson<bool>(hasEnteredRotation),
      'activationBaselineScore': serializer.toJson<int?>(
        activationBaselineScore,
      ),
      'cachedRotationScore': serializer.toJson<int>(cachedRotationScore),
      'cachedTotalRecitations': serializer.toJson<int>(cachedTotalRecitations),
      'cachedLastUsedAtUtc': serializer.toJson<DateTime?>(cachedLastUsedAtUtc),
      'alias': serializer.toJson<String?>(alias),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  MasteredSurahRow copyWith({
    String? surahId,
    bool? isActive,
    bool? hasEnteredRotation,
    Value<int?> activationBaselineScore = const Value.absent(),
    int? cachedRotationScore,
    int? cachedTotalRecitations,
    Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
    Value<String?> alias = const Value.absent(),
    int? displayOrder,
  }) => MasteredSurahRow(
    surahId: surahId ?? this.surahId,
    isActive: isActive ?? this.isActive,
    hasEnteredRotation: hasEnteredRotation ?? this.hasEnteredRotation,
    activationBaselineScore: activationBaselineScore.present
        ? activationBaselineScore.value
        : this.activationBaselineScore,
    cachedRotationScore: cachedRotationScore ?? this.cachedRotationScore,
    cachedTotalRecitations:
        cachedTotalRecitations ?? this.cachedTotalRecitations,
    cachedLastUsedAtUtc: cachedLastUsedAtUtc.present
        ? cachedLastUsedAtUtc.value
        : this.cachedLastUsedAtUtc,
    alias: alias.present ? alias.value : this.alias,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  MasteredSurahRow copyWithCompanion(MasteredSurahsCompanion data) {
    return MasteredSurahRow(
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      hasEnteredRotation: data.hasEnteredRotation.present
          ? data.hasEnteredRotation.value
          : this.hasEnteredRotation,
      activationBaselineScore: data.activationBaselineScore.present
          ? data.activationBaselineScore.value
          : this.activationBaselineScore,
      cachedRotationScore: data.cachedRotationScore.present
          ? data.cachedRotationScore.value
          : this.cachedRotationScore,
      cachedTotalRecitations: data.cachedTotalRecitations.present
          ? data.cachedTotalRecitations.value
          : this.cachedTotalRecitations,
      cachedLastUsedAtUtc: data.cachedLastUsedAtUtc.present
          ? data.cachedLastUsedAtUtc.value
          : this.cachedLastUsedAtUtc,
      alias: data.alias.present ? data.alias.value : this.alias,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasteredSurahRow(')
          ..write('surahId: $surahId, ')
          ..write('isActive: $isActive, ')
          ..write('hasEnteredRotation: $hasEnteredRotation, ')
          ..write('activationBaselineScore: $activationBaselineScore, ')
          ..write('cachedRotationScore: $cachedRotationScore, ')
          ..write('cachedTotalRecitations: $cachedTotalRecitations, ')
          ..write('cachedLastUsedAtUtc: $cachedLastUsedAtUtc, ')
          ..write('alias: $alias, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    surahId,
    isActive,
    hasEnteredRotation,
    activationBaselineScore,
    cachedRotationScore,
    cachedTotalRecitations,
    cachedLastUsedAtUtc,
    alias,
    displayOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasteredSurahRow &&
          other.surahId == this.surahId &&
          other.isActive == this.isActive &&
          other.hasEnteredRotation == this.hasEnteredRotation &&
          other.activationBaselineScore == this.activationBaselineScore &&
          other.cachedRotationScore == this.cachedRotationScore &&
          other.cachedTotalRecitations == this.cachedTotalRecitations &&
          other.cachedLastUsedAtUtc == this.cachedLastUsedAtUtc &&
          other.alias == this.alias &&
          other.displayOrder == this.displayOrder);
}

class MasteredSurahsCompanion extends UpdateCompanion<MasteredSurahRow> {
  final Value<String> surahId;
  final Value<bool> isActive;
  final Value<bool> hasEnteredRotation;
  final Value<int?> activationBaselineScore;
  final Value<int> cachedRotationScore;
  final Value<int> cachedTotalRecitations;
  final Value<DateTime?> cachedLastUsedAtUtc;
  final Value<String?> alias;
  final Value<int> displayOrder;
  final Value<int> rowid;
  const MasteredSurahsCompanion({
    this.surahId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.hasEnteredRotation = const Value.absent(),
    this.activationBaselineScore = const Value.absent(),
    this.cachedRotationScore = const Value.absent(),
    this.cachedTotalRecitations = const Value.absent(),
    this.cachedLastUsedAtUtc = const Value.absent(),
    this.alias = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MasteredSurahsCompanion.insert({
    required String surahId,
    this.isActive = const Value.absent(),
    this.hasEnteredRotation = const Value.absent(),
    this.activationBaselineScore = const Value.absent(),
    this.cachedRotationScore = const Value.absent(),
    this.cachedTotalRecitations = const Value.absent(),
    this.cachedLastUsedAtUtc = const Value.absent(),
    this.alias = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : surahId = Value(surahId);
  static Insertable<MasteredSurahRow> custom({
    Expression<String>? surahId,
    Expression<bool>? isActive,
    Expression<bool>? hasEnteredRotation,
    Expression<int>? activationBaselineScore,
    Expression<int>? cachedRotationScore,
    Expression<int>? cachedTotalRecitations,
    Expression<DateTime>? cachedLastUsedAtUtc,
    Expression<String>? alias,
    Expression<int>? displayOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (surahId != null) 'surah_id': surahId,
      if (isActive != null) 'is_active': isActive,
      if (hasEnteredRotation != null)
        'has_entered_rotation': hasEnteredRotation,
      if (activationBaselineScore != null)
        'activation_baseline_score': activationBaselineScore,
      if (cachedRotationScore != null)
        'cached_rotation_score': cachedRotationScore,
      if (cachedTotalRecitations != null)
        'cached_total_recitations': cachedTotalRecitations,
      if (cachedLastUsedAtUtc != null)
        'cached_last_used_at_utc': cachedLastUsedAtUtc,
      if (alias != null) 'alias': alias,
      if (displayOrder != null) 'display_order': displayOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MasteredSurahsCompanion copyWith({
    Value<String>? surahId,
    Value<bool>? isActive,
    Value<bool>? hasEnteredRotation,
    Value<int?>? activationBaselineScore,
    Value<int>? cachedRotationScore,
    Value<int>? cachedTotalRecitations,
    Value<DateTime?>? cachedLastUsedAtUtc,
    Value<String?>? alias,
    Value<int>? displayOrder,
    Value<int>? rowid,
  }) {
    return MasteredSurahsCompanion(
      surahId: surahId ?? this.surahId,
      isActive: isActive ?? this.isActive,
      hasEnteredRotation: hasEnteredRotation ?? this.hasEnteredRotation,
      activationBaselineScore:
          activationBaselineScore ?? this.activationBaselineScore,
      cachedRotationScore: cachedRotationScore ?? this.cachedRotationScore,
      cachedTotalRecitations:
          cachedTotalRecitations ?? this.cachedTotalRecitations,
      cachedLastUsedAtUtc: cachedLastUsedAtUtc ?? this.cachedLastUsedAtUtc,
      alias: alias ?? this.alias,
      displayOrder: displayOrder ?? this.displayOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (surahId.present) {
      map['surah_id'] = Variable<String>(surahId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (hasEnteredRotation.present) {
      map['has_entered_rotation'] = Variable<bool>(hasEnteredRotation.value);
    }
    if (activationBaselineScore.present) {
      map['activation_baseline_score'] = Variable<int>(
        activationBaselineScore.value,
      );
    }
    if (cachedRotationScore.present) {
      map['cached_rotation_score'] = Variable<int>(cachedRotationScore.value);
    }
    if (cachedTotalRecitations.present) {
      map['cached_total_recitations'] = Variable<int>(
        cachedTotalRecitations.value,
      );
    }
    if (cachedLastUsedAtUtc.present) {
      map['cached_last_used_at_utc'] = Variable<DateTime>(
        cachedLastUsedAtUtc.value,
      );
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasteredSurahsCompanion(')
          ..write('surahId: $surahId, ')
          ..write('isActive: $isActive, ')
          ..write('hasEnteredRotation: $hasEnteredRotation, ')
          ..write('activationBaselineScore: $activationBaselineScore, ')
          ..write('cachedRotationScore: $cachedRotationScore, ')
          ..write('cachedTotalRecitations: $cachedTotalRecitations, ')
          ..write('cachedLastUsedAtUtc: $cachedLastUsedAtUtc, ')
          ..write('alias: $alias, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RotationStatesTable extends RotationStates
    with TableInfo<$RotationStatesTable, RotationStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RotationStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(1),
  );
  static const VerificationMeta _rotationTargetMeta = const VerificationMeta(
    'rotationTarget',
  );
  @override
  late final GeneratedColumn<int> rotationTarget = GeneratedColumn<int>(
    'rotation_target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(1),
  );
  static const VerificationMeta _lastJournalSequenceMeta =
      const VerificationMeta('lastJournalSequence');
  @override
  late final GeneratedColumn<int> lastJournalSequence = GeneratedColumn<int>(
    'last_journal_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(0),
  );
  static const VerificationMeta _projectionVersionMeta = const VerificationMeta(
    'projectionVersion',
  );
  @override
  late final GeneratedColumn<int> projectionVersion = GeneratedColumn<int>(
    'projection_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant<int>(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    rotationTarget,
    lastJournalSequence,
    projectionVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rotation_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<RotationStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('rotation_target')) {
      context.handle(
        _rotationTargetMeta,
        rotationTarget.isAcceptableOrUnknown(
          data['rotation_target']!,
          _rotationTargetMeta,
        ),
      );
    }
    if (data.containsKey('last_journal_sequence')) {
      context.handle(
        _lastJournalSequenceMeta,
        lastJournalSequence.isAcceptableOrUnknown(
          data['last_journal_sequence']!,
          _lastJournalSequenceMeta,
        ),
      );
    }
    if (data.containsKey('projection_version')) {
      context.handle(
        _projectionVersionMeta,
        projectionVersion.isAcceptableOrUnknown(
          data['projection_version']!,
          _projectionVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  RotationStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RotationStateRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      rotationTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotation_target'],
      )!,
      lastJournalSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_journal_sequence'],
      )!,
      projectionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}projection_version'],
      )!,
    );
  }

  @override
  $RotationStatesTable createAlias(String alias) {
    return $RotationStatesTable(attachedDatabase, alias);
  }
}

class RotationStateRow extends DataClass
    implements Insertable<RotationStateRow> {
  final int singletonId;
  final int rotationTarget;
  final int lastJournalSequence;
  final int projectionVersion;
  const RotationStateRow({
    required this.singletonId,
    required this.rotationTarget,
    required this.lastJournalSequence,
    required this.projectionVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['rotation_target'] = Variable<int>(rotationTarget);
    map['last_journal_sequence'] = Variable<int>(lastJournalSequence);
    map['projection_version'] = Variable<int>(projectionVersion);
    return map;
  }

  RotationStatesCompanion toCompanion(bool nullToAbsent) {
    return RotationStatesCompanion(
      singletonId: Value(singletonId),
      rotationTarget: Value(rotationTarget),
      lastJournalSequence: Value(lastJournalSequence),
      projectionVersion: Value(projectionVersion),
    );
  }

  factory RotationStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RotationStateRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      rotationTarget: serializer.fromJson<int>(json['rotationTarget']),
      lastJournalSequence: serializer.fromJson<int>(
        json['lastJournalSequence'],
      ),
      projectionVersion: serializer.fromJson<int>(json['projectionVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'rotationTarget': serializer.toJson<int>(rotationTarget),
      'lastJournalSequence': serializer.toJson<int>(lastJournalSequence),
      'projectionVersion': serializer.toJson<int>(projectionVersion),
    };
  }

  RotationStateRow copyWith({
    int? singletonId,
    int? rotationTarget,
    int? lastJournalSequence,
    int? projectionVersion,
  }) => RotationStateRow(
    singletonId: singletonId ?? this.singletonId,
    rotationTarget: rotationTarget ?? this.rotationTarget,
    lastJournalSequence: lastJournalSequence ?? this.lastJournalSequence,
    projectionVersion: projectionVersion ?? this.projectionVersion,
  );
  RotationStateRow copyWithCompanion(RotationStatesCompanion data) {
    return RotationStateRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      rotationTarget: data.rotationTarget.present
          ? data.rotationTarget.value
          : this.rotationTarget,
      lastJournalSequence: data.lastJournalSequence.present
          ? data.lastJournalSequence.value
          : this.lastJournalSequence,
      projectionVersion: data.projectionVersion.present
          ? data.projectionVersion.value
          : this.projectionVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RotationStateRow(')
          ..write('singletonId: $singletonId, ')
          ..write('rotationTarget: $rotationTarget, ')
          ..write('lastJournalSequence: $lastJournalSequence, ')
          ..write('projectionVersion: $projectionVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singletonId,
    rotationTarget,
    lastJournalSequence,
    projectionVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RotationStateRow &&
          other.singletonId == this.singletonId &&
          other.rotationTarget == this.rotationTarget &&
          other.lastJournalSequence == this.lastJournalSequence &&
          other.projectionVersion == this.projectionVersion);
}

class RotationStatesCompanion extends UpdateCompanion<RotationStateRow> {
  final Value<int> singletonId;
  final Value<int> rotationTarget;
  final Value<int> lastJournalSequence;
  final Value<int> projectionVersion;
  const RotationStatesCompanion({
    this.singletonId = const Value.absent(),
    this.rotationTarget = const Value.absent(),
    this.lastJournalSequence = const Value.absent(),
    this.projectionVersion = const Value.absent(),
  });
  RotationStatesCompanion.insert({
    this.singletonId = const Value.absent(),
    this.rotationTarget = const Value.absent(),
    this.lastJournalSequence = const Value.absent(),
    this.projectionVersion = const Value.absent(),
  });
  static Insertable<RotationStateRow> custom({
    Expression<int>? singletonId,
    Expression<int>? rotationTarget,
    Expression<int>? lastJournalSequence,
    Expression<int>? projectionVersion,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (rotationTarget != null) 'rotation_target': rotationTarget,
      if (lastJournalSequence != null)
        'last_journal_sequence': lastJournalSequence,
      if (projectionVersion != null) 'projection_version': projectionVersion,
    });
  }

  RotationStatesCompanion copyWith({
    Value<int>? singletonId,
    Value<int>? rotationTarget,
    Value<int>? lastJournalSequence,
    Value<int>? projectionVersion,
  }) {
    return RotationStatesCompanion(
      singletonId: singletonId ?? this.singletonId,
      rotationTarget: rotationTarget ?? this.rotationTarget,
      lastJournalSequence: lastJournalSequence ?? this.lastJournalSequence,
      projectionVersion: projectionVersion ?? this.projectionVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (rotationTarget.present) {
      map['rotation_target'] = Variable<int>(rotationTarget.value);
    }
    if (lastJournalSequence.present) {
      map['last_journal_sequence'] = Variable<int>(lastJournalSequence.value);
    }
    if (projectionVersion.present) {
      map['projection_version'] = Variable<int>(projectionVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RotationStatesCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('rotationTarget: $rotationTarget, ')
          ..write('lastJournalSequence: $lastJournalSequence, ')
          ..write('projectionVersion: $projectionVersion')
          ..write(')'))
        .toString();
  }
}

class $RotationSchemesTable extends RotationSchemes
    with TableInfo<$RotationSchemesTable, RotationSchemeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RotationSchemesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surahIdMeta = const VerificationMeta(
    'surahId',
  );
  @override
  late final GeneratedColumn<String> surahId = GeneratedColumn<String>(
    'surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mastered_surahs (surah_id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahCountSnapshotMeta = const VerificationMeta(
    'ayahCountSnapshot',
  );
  @override
  late final GeneratedColumn<int> ayahCountSnapshot = GeneratedColumn<int>(
    'ayah_count_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineScoreMeta = const VerificationMeta(
    'baselineScore',
  );
  @override
  late final GeneratedColumn<int> baselineScore = GeneratedColumn<int>(
    'baseline_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineTotalRecitationsMeta =
      const VerificationMeta('baselineTotalRecitations');
  @override
  late final GeneratedColumn<int> baselineTotalRecitations =
      GeneratedColumn<int>(
        'baseline_total_recitations',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _baselineLastUsedAtUtcMeta =
      const VerificationMeta('baselineLastUsedAtUtc');
  @override
  late final GeneratedColumn<DateTime> baselineLastUsedAtUtc =
      GeneratedColumn<DateTime>(
        'baseline_last_used_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activatedJournalSequenceMeta =
      const VerificationMeta('activatedJournalSequence');
  @override
  late final GeneratedColumn<int> activatedJournalSequence =
      GeneratedColumn<int>(
        'activated_journal_sequence',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _supersededJournalSequenceMeta =
      const VerificationMeta('supersededJournalSequence');
  @override
  late final GeneratedColumn<int> supersededJournalSequence =
      GeneratedColumn<int>(
        'superseded_journal_sequence',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surahId,
    version,
    ayahCountSnapshot,
    baselineScore,
    baselineTotalRecitations,
    baselineLastUsedAtUtc,
    activatedJournalSequence,
    supersededJournalSequence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rotation_schemes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RotationSchemeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('surah_id')) {
      context.handle(
        _surahIdMeta,
        surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surahIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('ayah_count_snapshot')) {
      context.handle(
        _ayahCountSnapshotMeta,
        ayahCountSnapshot.isAcceptableOrUnknown(
          data['ayah_count_snapshot']!,
          _ayahCountSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ayahCountSnapshotMeta);
    }
    if (data.containsKey('baseline_score')) {
      context.handle(
        _baselineScoreMeta,
        baselineScore.isAcceptableOrUnknown(
          data['baseline_score']!,
          _baselineScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baselineScoreMeta);
    }
    if (data.containsKey('baseline_total_recitations')) {
      context.handle(
        _baselineTotalRecitationsMeta,
        baselineTotalRecitations.isAcceptableOrUnknown(
          data['baseline_total_recitations']!,
          _baselineTotalRecitationsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baselineTotalRecitationsMeta);
    }
    if (data.containsKey('baseline_last_used_at_utc')) {
      context.handle(
        _baselineLastUsedAtUtcMeta,
        baselineLastUsedAtUtc.isAcceptableOrUnknown(
          data['baseline_last_used_at_utc']!,
          _baselineLastUsedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('activated_journal_sequence')) {
      context.handle(
        _activatedJournalSequenceMeta,
        activatedJournalSequence.isAcceptableOrUnknown(
          data['activated_journal_sequence']!,
          _activatedJournalSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activatedJournalSequenceMeta);
    }
    if (data.containsKey('superseded_journal_sequence')) {
      context.handle(
        _supersededJournalSequenceMeta,
        supersededJournalSequence.isAcceptableOrUnknown(
          data['superseded_journal_sequence']!,
          _supersededJournalSequenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {surahId, version},
    {id, surahId},
  ];
  @override
  RotationSchemeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RotationSchemeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      surahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surah_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      ayahCountSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_count_snapshot'],
      )!,
      baselineScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baseline_score'],
      )!,
      baselineTotalRecitations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baseline_total_recitations'],
      )!,
      baselineLastUsedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}baseline_last_used_at_utc'],
      ),
      activatedJournalSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activated_journal_sequence'],
      )!,
      supersededJournalSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}superseded_journal_sequence'],
      ),
    );
  }

  @override
  $RotationSchemesTable createAlias(String alias) {
    return $RotationSchemesTable(attachedDatabase, alias);
  }
}

class RotationSchemeRow extends DataClass
    implements Insertable<RotationSchemeRow> {
  final String id;
  final String surahId;
  final int version;
  final int ayahCountSnapshot;
  final int baselineScore;
  final int baselineTotalRecitations;
  final DateTime? baselineLastUsedAtUtc;
  final int activatedJournalSequence;
  final int? supersededJournalSequence;
  const RotationSchemeRow({
    required this.id,
    required this.surahId,
    required this.version,
    required this.ayahCountSnapshot,
    required this.baselineScore,
    required this.baselineTotalRecitations,
    this.baselineLastUsedAtUtc,
    required this.activatedJournalSequence,
    this.supersededJournalSequence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['surah_id'] = Variable<String>(surahId);
    map['version'] = Variable<int>(version);
    map['ayah_count_snapshot'] = Variable<int>(ayahCountSnapshot);
    map['baseline_score'] = Variable<int>(baselineScore);
    map['baseline_total_recitations'] = Variable<int>(baselineTotalRecitations);
    if (!nullToAbsent || baselineLastUsedAtUtc != null) {
      map['baseline_last_used_at_utc'] = Variable<DateTime>(
        baselineLastUsedAtUtc,
      );
    }
    map['activated_journal_sequence'] = Variable<int>(activatedJournalSequence);
    if (!nullToAbsent || supersededJournalSequence != null) {
      map['superseded_journal_sequence'] = Variable<int>(
        supersededJournalSequence,
      );
    }
    return map;
  }

  RotationSchemesCompanion toCompanion(bool nullToAbsent) {
    return RotationSchemesCompanion(
      id: Value(id),
      surahId: Value(surahId),
      version: Value(version),
      ayahCountSnapshot: Value(ayahCountSnapshot),
      baselineScore: Value(baselineScore),
      baselineTotalRecitations: Value(baselineTotalRecitations),
      baselineLastUsedAtUtc: baselineLastUsedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineLastUsedAtUtc),
      activatedJournalSequence: Value(activatedJournalSequence),
      supersededJournalSequence:
          supersededJournalSequence == null && nullToAbsent
          ? const Value.absent()
          : Value(supersededJournalSequence),
    );
  }

  factory RotationSchemeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RotationSchemeRow(
      id: serializer.fromJson<String>(json['id']),
      surahId: serializer.fromJson<String>(json['surahId']),
      version: serializer.fromJson<int>(json['version']),
      ayahCountSnapshot: serializer.fromJson<int>(json['ayahCountSnapshot']),
      baselineScore: serializer.fromJson<int>(json['baselineScore']),
      baselineTotalRecitations: serializer.fromJson<int>(
        json['baselineTotalRecitations'],
      ),
      baselineLastUsedAtUtc: serializer.fromJson<DateTime?>(
        json['baselineLastUsedAtUtc'],
      ),
      activatedJournalSequence: serializer.fromJson<int>(
        json['activatedJournalSequence'],
      ),
      supersededJournalSequence: serializer.fromJson<int?>(
        json['supersededJournalSequence'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'surahId': serializer.toJson<String>(surahId),
      'version': serializer.toJson<int>(version),
      'ayahCountSnapshot': serializer.toJson<int>(ayahCountSnapshot),
      'baselineScore': serializer.toJson<int>(baselineScore),
      'baselineTotalRecitations': serializer.toJson<int>(
        baselineTotalRecitations,
      ),
      'baselineLastUsedAtUtc': serializer.toJson<DateTime?>(
        baselineLastUsedAtUtc,
      ),
      'activatedJournalSequence': serializer.toJson<int>(
        activatedJournalSequence,
      ),
      'supersededJournalSequence': serializer.toJson<int?>(
        supersededJournalSequence,
      ),
    };
  }

  RotationSchemeRow copyWith({
    String? id,
    String? surahId,
    int? version,
    int? ayahCountSnapshot,
    int? baselineScore,
    int? baselineTotalRecitations,
    Value<DateTime?> baselineLastUsedAtUtc = const Value.absent(),
    int? activatedJournalSequence,
    Value<int?> supersededJournalSequence = const Value.absent(),
  }) => RotationSchemeRow(
    id: id ?? this.id,
    surahId: surahId ?? this.surahId,
    version: version ?? this.version,
    ayahCountSnapshot: ayahCountSnapshot ?? this.ayahCountSnapshot,
    baselineScore: baselineScore ?? this.baselineScore,
    baselineTotalRecitations:
        baselineTotalRecitations ?? this.baselineTotalRecitations,
    baselineLastUsedAtUtc: baselineLastUsedAtUtc.present
        ? baselineLastUsedAtUtc.value
        : this.baselineLastUsedAtUtc,
    activatedJournalSequence:
        activatedJournalSequence ?? this.activatedJournalSequence,
    supersededJournalSequence: supersededJournalSequence.present
        ? supersededJournalSequence.value
        : this.supersededJournalSequence,
  );
  RotationSchemeRow copyWithCompanion(RotationSchemesCompanion data) {
    return RotationSchemeRow(
      id: data.id.present ? data.id.value : this.id,
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      version: data.version.present ? data.version.value : this.version,
      ayahCountSnapshot: data.ayahCountSnapshot.present
          ? data.ayahCountSnapshot.value
          : this.ayahCountSnapshot,
      baselineScore: data.baselineScore.present
          ? data.baselineScore.value
          : this.baselineScore,
      baselineTotalRecitations: data.baselineTotalRecitations.present
          ? data.baselineTotalRecitations.value
          : this.baselineTotalRecitations,
      baselineLastUsedAtUtc: data.baselineLastUsedAtUtc.present
          ? data.baselineLastUsedAtUtc.value
          : this.baselineLastUsedAtUtc,
      activatedJournalSequence: data.activatedJournalSequence.present
          ? data.activatedJournalSequence.value
          : this.activatedJournalSequence,
      supersededJournalSequence: data.supersededJournalSequence.present
          ? data.supersededJournalSequence.value
          : this.supersededJournalSequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RotationSchemeRow(')
          ..write('id: $id, ')
          ..write('surahId: $surahId, ')
          ..write('version: $version, ')
          ..write('ayahCountSnapshot: $ayahCountSnapshot, ')
          ..write('baselineScore: $baselineScore, ')
          ..write('baselineTotalRecitations: $baselineTotalRecitations, ')
          ..write('baselineLastUsedAtUtc: $baselineLastUsedAtUtc, ')
          ..write('activatedJournalSequence: $activatedJournalSequence, ')
          ..write('supersededJournalSequence: $supersededJournalSequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    version,
    ayahCountSnapshot,
    baselineScore,
    baselineTotalRecitations,
    baselineLastUsedAtUtc,
    activatedJournalSequence,
    supersededJournalSequence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RotationSchemeRow &&
          other.id == this.id &&
          other.surahId == this.surahId &&
          other.version == this.version &&
          other.ayahCountSnapshot == this.ayahCountSnapshot &&
          other.baselineScore == this.baselineScore &&
          other.baselineTotalRecitations == this.baselineTotalRecitations &&
          other.baselineLastUsedAtUtc == this.baselineLastUsedAtUtc &&
          other.activatedJournalSequence == this.activatedJournalSequence &&
          other.supersededJournalSequence == this.supersededJournalSequence);
}

class RotationSchemesCompanion extends UpdateCompanion<RotationSchemeRow> {
  final Value<String> id;
  final Value<String> surahId;
  final Value<int> version;
  final Value<int> ayahCountSnapshot;
  final Value<int> baselineScore;
  final Value<int> baselineTotalRecitations;
  final Value<DateTime?> baselineLastUsedAtUtc;
  final Value<int> activatedJournalSequence;
  final Value<int?> supersededJournalSequence;
  final Value<int> rowid;
  const RotationSchemesCompanion({
    this.id = const Value.absent(),
    this.surahId = const Value.absent(),
    this.version = const Value.absent(),
    this.ayahCountSnapshot = const Value.absent(),
    this.baselineScore = const Value.absent(),
    this.baselineTotalRecitations = const Value.absent(),
    this.baselineLastUsedAtUtc = const Value.absent(),
    this.activatedJournalSequence = const Value.absent(),
    this.supersededJournalSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RotationSchemesCompanion.insert({
    required String id,
    required String surahId,
    required int version,
    required int ayahCountSnapshot,
    required int baselineScore,
    required int baselineTotalRecitations,
    this.baselineLastUsedAtUtc = const Value.absent(),
    required int activatedJournalSequence,
    this.supersededJournalSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       surahId = Value(surahId),
       version = Value(version),
       ayahCountSnapshot = Value(ayahCountSnapshot),
       baselineScore = Value(baselineScore),
       baselineTotalRecitations = Value(baselineTotalRecitations),
       activatedJournalSequence = Value(activatedJournalSequence);
  static Insertable<RotationSchemeRow> custom({
    Expression<String>? id,
    Expression<String>? surahId,
    Expression<int>? version,
    Expression<int>? ayahCountSnapshot,
    Expression<int>? baselineScore,
    Expression<int>? baselineTotalRecitations,
    Expression<DateTime>? baselineLastUsedAtUtc,
    Expression<int>? activatedJournalSequence,
    Expression<int>? supersededJournalSequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahId != null) 'surah_id': surahId,
      if (version != null) 'version': version,
      if (ayahCountSnapshot != null) 'ayah_count_snapshot': ayahCountSnapshot,
      if (baselineScore != null) 'baseline_score': baselineScore,
      if (baselineTotalRecitations != null)
        'baseline_total_recitations': baselineTotalRecitations,
      if (baselineLastUsedAtUtc != null)
        'baseline_last_used_at_utc': baselineLastUsedAtUtc,
      if (activatedJournalSequence != null)
        'activated_journal_sequence': activatedJournalSequence,
      if (supersededJournalSequence != null)
        'superseded_journal_sequence': supersededJournalSequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RotationSchemesCompanion copyWith({
    Value<String>? id,
    Value<String>? surahId,
    Value<int>? version,
    Value<int>? ayahCountSnapshot,
    Value<int>? baselineScore,
    Value<int>? baselineTotalRecitations,
    Value<DateTime?>? baselineLastUsedAtUtc,
    Value<int>? activatedJournalSequence,
    Value<int?>? supersededJournalSequence,
    Value<int>? rowid,
  }) {
    return RotationSchemesCompanion(
      id: id ?? this.id,
      surahId: surahId ?? this.surahId,
      version: version ?? this.version,
      ayahCountSnapshot: ayahCountSnapshot ?? this.ayahCountSnapshot,
      baselineScore: baselineScore ?? this.baselineScore,
      baselineTotalRecitations:
          baselineTotalRecitations ?? this.baselineTotalRecitations,
      baselineLastUsedAtUtc:
          baselineLastUsedAtUtc ?? this.baselineLastUsedAtUtc,
      activatedJournalSequence:
          activatedJournalSequence ?? this.activatedJournalSequence,
      supersededJournalSequence:
          supersededJournalSequence ?? this.supersededJournalSequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (surahId.present) {
      map['surah_id'] = Variable<String>(surahId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (ayahCountSnapshot.present) {
      map['ayah_count_snapshot'] = Variable<int>(ayahCountSnapshot.value);
    }
    if (baselineScore.present) {
      map['baseline_score'] = Variable<int>(baselineScore.value);
    }
    if (baselineTotalRecitations.present) {
      map['baseline_total_recitations'] = Variable<int>(
        baselineTotalRecitations.value,
      );
    }
    if (baselineLastUsedAtUtc.present) {
      map['baseline_last_used_at_utc'] = Variable<DateTime>(
        baselineLastUsedAtUtc.value,
      );
    }
    if (activatedJournalSequence.present) {
      map['activated_journal_sequence'] = Variable<int>(
        activatedJournalSequence.value,
      );
    }
    if (supersededJournalSequence.present) {
      map['superseded_journal_sequence'] = Variable<int>(
        supersededJournalSequence.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RotationSchemesCompanion(')
          ..write('id: $id, ')
          ..write('surahId: $surahId, ')
          ..write('version: $version, ')
          ..write('ayahCountSnapshot: $ayahCountSnapshot, ')
          ..write('baselineScore: $baselineScore, ')
          ..write('baselineTotalRecitations: $baselineTotalRecitations, ')
          ..write('baselineLastUsedAtUtc: $baselineLastUsedAtUtc, ')
          ..write('activatedJournalSequence: $activatedJournalSequence, ')
          ..write('supersededJournalSequence: $supersededJournalSequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RotationPartsTable extends RotationParts
    with TableInfo<$RotationPartsTable, RotationPartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RotationPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeIdMeta = const VerificationMeta(
    'schemeId',
  );
  @override
  late final GeneratedColumn<String> schemeId = GeneratedColumn<String>(
    'scheme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rotation_schemes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAyahMeta = const VerificationMeta(
    'startAyah',
  );
  @override
  late final GeneratedColumn<int> startAyah = GeneratedColumn<int>(
    'start_ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAyahMeta = const VerificationMeta(
    'endAyah',
  );
  @override
  late final GeneratedColumn<int> endAyah = GeneratedColumn<int>(
    'end_ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedScoreMeta = const VerificationMeta(
    'cachedScore',
  );
  @override
  late final GeneratedColumn<int> cachedScore = GeneratedColumn<int>(
    'cached_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedRecitationCountMeta =
      const VerificationMeta('cachedRecitationCount');
  @override
  late final GeneratedColumn<int> cachedRecitationCount = GeneratedColumn<int>(
    'cached_recitation_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedLastUsedAtUtcMeta =
      const VerificationMeta('cachedLastUsedAtUtc');
  @override
  late final GeneratedColumn<DateTime> cachedLastUsedAtUtc =
      GeneratedColumn<DateTime>(
        'cached_last_used_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schemeId,
    ordinal,
    startAyah,
    endAyah,
    cachedScore,
    cachedRecitationCount,
    cachedLastUsedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rotation_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RotationPartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scheme_id')) {
      context.handle(
        _schemeIdMeta,
        schemeId.isAcceptableOrUnknown(data['scheme_id']!, _schemeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schemeIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('start_ayah')) {
      context.handle(
        _startAyahMeta,
        startAyah.isAcceptableOrUnknown(data['start_ayah']!, _startAyahMeta),
      );
    } else if (isInserting) {
      context.missing(_startAyahMeta);
    }
    if (data.containsKey('end_ayah')) {
      context.handle(
        _endAyahMeta,
        endAyah.isAcceptableOrUnknown(data['end_ayah']!, _endAyahMeta),
      );
    } else if (isInserting) {
      context.missing(_endAyahMeta);
    }
    if (data.containsKey('cached_score')) {
      context.handle(
        _cachedScoreMeta,
        cachedScore.isAcceptableOrUnknown(
          data['cached_score']!,
          _cachedScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedScoreMeta);
    }
    if (data.containsKey('cached_recitation_count')) {
      context.handle(
        _cachedRecitationCountMeta,
        cachedRecitationCount.isAcceptableOrUnknown(
          data['cached_recitation_count']!,
          _cachedRecitationCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedRecitationCountMeta);
    }
    if (data.containsKey('cached_last_used_at_utc')) {
      context.handle(
        _cachedLastUsedAtUtcMeta,
        cachedLastUsedAtUtc.isAcceptableOrUnknown(
          data['cached_last_used_at_utc']!,
          _cachedLastUsedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {schemeId, ordinal},
    {id, schemeId},
  ];
  @override
  RotationPartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RotationPartRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      startAyah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ayah'],
      )!,
      endAyah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ayah'],
      )!,
      cachedScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_score'],
      )!,
      cachedRecitationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_recitation_count'],
      )!,
      cachedLastUsedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_last_used_at_utc'],
      ),
    );
  }

  @override
  $RotationPartsTable createAlias(String alias) {
    return $RotationPartsTable(attachedDatabase, alias);
  }
}

class RotationPartRow extends DataClass implements Insertable<RotationPartRow> {
  final String id;
  final String schemeId;
  final int ordinal;
  final int startAyah;
  final int endAyah;
  final int cachedScore;
  final int cachedRecitationCount;
  final DateTime? cachedLastUsedAtUtc;
  const RotationPartRow({
    required this.id,
    required this.schemeId,
    required this.ordinal,
    required this.startAyah,
    required this.endAyah,
    required this.cachedScore,
    required this.cachedRecitationCount,
    this.cachedLastUsedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scheme_id'] = Variable<String>(schemeId);
    map['ordinal'] = Variable<int>(ordinal);
    map['start_ayah'] = Variable<int>(startAyah);
    map['end_ayah'] = Variable<int>(endAyah);
    map['cached_score'] = Variable<int>(cachedScore);
    map['cached_recitation_count'] = Variable<int>(cachedRecitationCount);
    if (!nullToAbsent || cachedLastUsedAtUtc != null) {
      map['cached_last_used_at_utc'] = Variable<DateTime>(cachedLastUsedAtUtc);
    }
    return map;
  }

  RotationPartsCompanion toCompanion(bool nullToAbsent) {
    return RotationPartsCompanion(
      id: Value(id),
      schemeId: Value(schemeId),
      ordinal: Value(ordinal),
      startAyah: Value(startAyah),
      endAyah: Value(endAyah),
      cachedScore: Value(cachedScore),
      cachedRecitationCount: Value(cachedRecitationCount),
      cachedLastUsedAtUtc: cachedLastUsedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedLastUsedAtUtc),
    );
  }

  factory RotationPartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RotationPartRow(
      id: serializer.fromJson<String>(json['id']),
      schemeId: serializer.fromJson<String>(json['schemeId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      startAyah: serializer.fromJson<int>(json['startAyah']),
      endAyah: serializer.fromJson<int>(json['endAyah']),
      cachedScore: serializer.fromJson<int>(json['cachedScore']),
      cachedRecitationCount: serializer.fromJson<int>(
        json['cachedRecitationCount'],
      ),
      cachedLastUsedAtUtc: serializer.fromJson<DateTime?>(
        json['cachedLastUsedAtUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schemeId': serializer.toJson<String>(schemeId),
      'ordinal': serializer.toJson<int>(ordinal),
      'startAyah': serializer.toJson<int>(startAyah),
      'endAyah': serializer.toJson<int>(endAyah),
      'cachedScore': serializer.toJson<int>(cachedScore),
      'cachedRecitationCount': serializer.toJson<int>(cachedRecitationCount),
      'cachedLastUsedAtUtc': serializer.toJson<DateTime?>(cachedLastUsedAtUtc),
    };
  }

  RotationPartRow copyWith({
    String? id,
    String? schemeId,
    int? ordinal,
    int? startAyah,
    int? endAyah,
    int? cachedScore,
    int? cachedRecitationCount,
    Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
  }) => RotationPartRow(
    id: id ?? this.id,
    schemeId: schemeId ?? this.schemeId,
    ordinal: ordinal ?? this.ordinal,
    startAyah: startAyah ?? this.startAyah,
    endAyah: endAyah ?? this.endAyah,
    cachedScore: cachedScore ?? this.cachedScore,
    cachedRecitationCount: cachedRecitationCount ?? this.cachedRecitationCount,
    cachedLastUsedAtUtc: cachedLastUsedAtUtc.present
        ? cachedLastUsedAtUtc.value
        : this.cachedLastUsedAtUtc,
  );
  RotationPartRow copyWithCompanion(RotationPartsCompanion data) {
    return RotationPartRow(
      id: data.id.present ? data.id.value : this.id,
      schemeId: data.schemeId.present ? data.schemeId.value : this.schemeId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      startAyah: data.startAyah.present ? data.startAyah.value : this.startAyah,
      endAyah: data.endAyah.present ? data.endAyah.value : this.endAyah,
      cachedScore: data.cachedScore.present
          ? data.cachedScore.value
          : this.cachedScore,
      cachedRecitationCount: data.cachedRecitationCount.present
          ? data.cachedRecitationCount.value
          : this.cachedRecitationCount,
      cachedLastUsedAtUtc: data.cachedLastUsedAtUtc.present
          ? data.cachedLastUsedAtUtc.value
          : this.cachedLastUsedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RotationPartRow(')
          ..write('id: $id, ')
          ..write('schemeId: $schemeId, ')
          ..write('ordinal: $ordinal, ')
          ..write('startAyah: $startAyah, ')
          ..write('endAyah: $endAyah, ')
          ..write('cachedScore: $cachedScore, ')
          ..write('cachedRecitationCount: $cachedRecitationCount, ')
          ..write('cachedLastUsedAtUtc: $cachedLastUsedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schemeId,
    ordinal,
    startAyah,
    endAyah,
    cachedScore,
    cachedRecitationCount,
    cachedLastUsedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RotationPartRow &&
          other.id == this.id &&
          other.schemeId == this.schemeId &&
          other.ordinal == this.ordinal &&
          other.startAyah == this.startAyah &&
          other.endAyah == this.endAyah &&
          other.cachedScore == this.cachedScore &&
          other.cachedRecitationCount == this.cachedRecitationCount &&
          other.cachedLastUsedAtUtc == this.cachedLastUsedAtUtc);
}

class RotationPartsCompanion extends UpdateCompanion<RotationPartRow> {
  final Value<String> id;
  final Value<String> schemeId;
  final Value<int> ordinal;
  final Value<int> startAyah;
  final Value<int> endAyah;
  final Value<int> cachedScore;
  final Value<int> cachedRecitationCount;
  final Value<DateTime?> cachedLastUsedAtUtc;
  final Value<int> rowid;
  const RotationPartsCompanion({
    this.id = const Value.absent(),
    this.schemeId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.startAyah = const Value.absent(),
    this.endAyah = const Value.absent(),
    this.cachedScore = const Value.absent(),
    this.cachedRecitationCount = const Value.absent(),
    this.cachedLastUsedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RotationPartsCompanion.insert({
    required String id,
    required String schemeId,
    required int ordinal,
    required int startAyah,
    required int endAyah,
    required int cachedScore,
    required int cachedRecitationCount,
    this.cachedLastUsedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schemeId = Value(schemeId),
       ordinal = Value(ordinal),
       startAyah = Value(startAyah),
       endAyah = Value(endAyah),
       cachedScore = Value(cachedScore),
       cachedRecitationCount = Value(cachedRecitationCount);
  static Insertable<RotationPartRow> custom({
    Expression<String>? id,
    Expression<String>? schemeId,
    Expression<int>? ordinal,
    Expression<int>? startAyah,
    Expression<int>? endAyah,
    Expression<int>? cachedScore,
    Expression<int>? cachedRecitationCount,
    Expression<DateTime>? cachedLastUsedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schemeId != null) 'scheme_id': schemeId,
      if (ordinal != null) 'ordinal': ordinal,
      if (startAyah != null) 'start_ayah': startAyah,
      if (endAyah != null) 'end_ayah': endAyah,
      if (cachedScore != null) 'cached_score': cachedScore,
      if (cachedRecitationCount != null)
        'cached_recitation_count': cachedRecitationCount,
      if (cachedLastUsedAtUtc != null)
        'cached_last_used_at_utc': cachedLastUsedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RotationPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? schemeId,
    Value<int>? ordinal,
    Value<int>? startAyah,
    Value<int>? endAyah,
    Value<int>? cachedScore,
    Value<int>? cachedRecitationCount,
    Value<DateTime?>? cachedLastUsedAtUtc,
    Value<int>? rowid,
  }) {
    return RotationPartsCompanion(
      id: id ?? this.id,
      schemeId: schemeId ?? this.schemeId,
      ordinal: ordinal ?? this.ordinal,
      startAyah: startAyah ?? this.startAyah,
      endAyah: endAyah ?? this.endAyah,
      cachedScore: cachedScore ?? this.cachedScore,
      cachedRecitationCount:
          cachedRecitationCount ?? this.cachedRecitationCount,
      cachedLastUsedAtUtc: cachedLastUsedAtUtc ?? this.cachedLastUsedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schemeId.present) {
      map['scheme_id'] = Variable<String>(schemeId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (startAyah.present) {
      map['start_ayah'] = Variable<int>(startAyah.value);
    }
    if (endAyah.present) {
      map['end_ayah'] = Variable<int>(endAyah.value);
    }
    if (cachedScore.present) {
      map['cached_score'] = Variable<int>(cachedScore.value);
    }
    if (cachedRecitationCount.present) {
      map['cached_recitation_count'] = Variable<int>(
        cachedRecitationCount.value,
      );
    }
    if (cachedLastUsedAtUtc.present) {
      map['cached_last_used_at_utc'] = Variable<DateTime>(
        cachedLastUsedAtUtc.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RotationPartsCompanion(')
          ..write('id: $id, ')
          ..write('schemeId: $schemeId, ')
          ..write('ordinal: $ordinal, ')
          ..write('startAyah: $startAyah, ')
          ..write('endAyah: $endAyah, ')
          ..write('cachedScore: $cachedScore, ')
          ..write('cachedRecitationCount: $cachedRecitationCount, ')
          ..write('cachedLastUsedAtUtc: $cachedLastUsedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrayerSessionsTable extends PrayerSessions
    with TableInfo<$PrayerSessionsTable, PrayerSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrayerSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prayerTypeMeta = const VerificationMeta(
    'prayerType',
  );
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
    'prayer_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isQadaMeta = const VerificationMeta('isQada');
  @override
  late final GeneratedColumn<bool> isQada = GeneratedColumn<bool>(
    'is_qada',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_qada" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> startedAtUtc = GeneratedColumn<DateTime>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    prayerType,
    isQada,
    startedAtUtc,
    localDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prayer_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrayerSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
        _prayerTypeMeta,
        prayerType.isAcceptableOrUnknown(data['prayer_type']!, _prayerTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('is_qada')) {
      context.handle(
        _isQadaMeta,
        isQada.isAcceptableOrUnknown(data['is_qada']!, _isQadaMeta),
      );
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrayerSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrayerSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      prayerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prayer_type'],
      )!,
      isQada: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_qada'],
      )!,
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at_utc'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      ),
    );
  }

  @override
  $PrayerSessionsTable createAlias(String alias) {
    return $PrayerSessionsTable(attachedDatabase, alias);
  }
}

class PrayerSessionRow extends DataClass
    implements Insertable<PrayerSessionRow> {
  final String id;
  final String prayerType;
  final bool isQada;
  final DateTime startedAtUtc;
  final String? localDate;
  const PrayerSessionRow({
    required this.id,
    required this.prayerType,
    required this.isQada,
    required this.startedAtUtc,
    this.localDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['prayer_type'] = Variable<String>(prayerType);
    map['is_qada'] = Variable<bool>(isQada);
    map['started_at_utc'] = Variable<DateTime>(startedAtUtc);
    if (!nullToAbsent || localDate != null) {
      map['local_date'] = Variable<String>(localDate);
    }
    return map;
  }

  PrayerSessionsCompanion toCompanion(bool nullToAbsent) {
    return PrayerSessionsCompanion(
      id: Value(id),
      prayerType: Value(prayerType),
      isQada: Value(isQada),
      startedAtUtc: Value(startedAtUtc),
      localDate: localDate == null && nullToAbsent
          ? const Value.absent()
          : Value(localDate),
    );
  }

  factory PrayerSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrayerSessionRow(
      id: serializer.fromJson<String>(json['id']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      isQada: serializer.fromJson<bool>(json['isQada']),
      startedAtUtc: serializer.fromJson<DateTime>(json['startedAtUtc']),
      localDate: serializer.fromJson<String?>(json['localDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'prayerType': serializer.toJson<String>(prayerType),
      'isQada': serializer.toJson<bool>(isQada),
      'startedAtUtc': serializer.toJson<DateTime>(startedAtUtc),
      'localDate': serializer.toJson<String?>(localDate),
    };
  }

  PrayerSessionRow copyWith({
    String? id,
    String? prayerType,
    bool? isQada,
    DateTime? startedAtUtc,
    Value<String?> localDate = const Value.absent(),
  }) => PrayerSessionRow(
    id: id ?? this.id,
    prayerType: prayerType ?? this.prayerType,
    isQada: isQada ?? this.isQada,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    localDate: localDate.present ? localDate.value : this.localDate,
  );
  PrayerSessionRow copyWithCompanion(PrayerSessionsCompanion data) {
    return PrayerSessionRow(
      id: data.id.present ? data.id.value : this.id,
      prayerType: data.prayerType.present
          ? data.prayerType.value
          : this.prayerType,
      isQada: data.isQada.present ? data.isQada.value : this.isQada,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrayerSessionRow(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('isQada: $isQada, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('localDate: $localDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, prayerType, isQada, startedAtUtc, localDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrayerSessionRow &&
          other.id == this.id &&
          other.prayerType == this.prayerType &&
          other.isQada == this.isQada &&
          other.startedAtUtc == this.startedAtUtc &&
          other.localDate == this.localDate);
}

class PrayerSessionsCompanion extends UpdateCompanion<PrayerSessionRow> {
  final Value<String> id;
  final Value<String> prayerType;
  final Value<bool> isQada;
  final Value<DateTime> startedAtUtc;
  final Value<String?> localDate;
  final Value<int> rowid;
  const PrayerSessionsCompanion({
    this.id = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.isQada = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.localDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrayerSessionsCompanion.insert({
    required String id,
    required String prayerType,
    this.isQada = const Value.absent(),
    required DateTime startedAtUtc,
    this.localDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       prayerType = Value(prayerType),
       startedAtUtc = Value(startedAtUtc);
  static Insertable<PrayerSessionRow> custom({
    Expression<String>? id,
    Expression<String>? prayerType,
    Expression<bool>? isQada,
    Expression<DateTime>? startedAtUtc,
    Expression<String>? localDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prayerType != null) 'prayer_type': prayerType,
      if (isQada != null) 'is_qada': isQada,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (localDate != null) 'local_date': localDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrayerSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? prayerType,
    Value<bool>? isQada,
    Value<DateTime>? startedAtUtc,
    Value<String?>? localDate,
    Value<int>? rowid,
  }) {
    return PrayerSessionsCompanion(
      id: id ?? this.id,
      prayerType: prayerType ?? this.prayerType,
      isQada: isQada ?? this.isQada,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      localDate: localDate ?? this.localDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (isQada.present) {
      map['is_qada'] = Variable<bool>(isQada.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<DateTime>(startedAtUtc.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrayerSessionsCompanion(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('isQada: $isQada, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('localDate: $localDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecitationEventsTable extends RecitationEvents
    with TableInfo<$RecitationEventsTable, RecitationEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecitationEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _journalSequenceMeta = const VerificationMeta(
    'journalSequence',
  );
  @override
  late final GeneratedColumn<int> journalSequence = GeneratedColumn<int>(
    'journal_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _surahIdMeta = const VerificationMeta(
    'surahId',
  );
  @override
  late final GeneratedColumn<String> surahId = GeneratedColumn<String>(
    'surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mastered_surahs (surah_id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _rotationSchemeIdMeta = const VerificationMeta(
    'rotationSchemeId',
  );
  @override
  late final GeneratedColumn<String> rotationSchemeId = GeneratedColumn<String>(
    'rotation_scheme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rakaatSpanCountMeta = const VerificationMeta(
    'rakaatSpanCount',
  );
  @override
  late final GeneratedColumn<int> rakaatSpanCount = GeneratedColumn<int>(
    'rakaat_span_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prayerSessionIdMeta = const VerificationMeta(
    'prayerSessionId',
  );
  @override
  late final GeneratedColumn<String> prayerSessionId = GeneratedColumn<String>(
    'prayer_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES prayer_sessions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prayerTypeMeta = const VerificationMeta(
    'prayerType',
  );
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
    'prayer_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isQadaMeta = const VerificationMeta('isQada');
  @override
  late final GeneratedColumn<bool> isQada = GeneratedColumn<bool>(
    'is_qada',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_qada" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    journalSequence,
    surahId,
    rotationSchemeId,
    rakaatSpanCount,
    prayerSessionId,
    createdAtUtc,
    localDate,
    prayerType,
    isQada,
    deletedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recitation_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecitationEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('journal_sequence')) {
      context.handle(
        _journalSequenceMeta,
        journalSequence.isAcceptableOrUnknown(
          data['journal_sequence']!,
          _journalSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_journalSequenceMeta);
    }
    if (data.containsKey('surah_id')) {
      context.handle(
        _surahIdMeta,
        surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surahIdMeta);
    }
    if (data.containsKey('rotation_scheme_id')) {
      context.handle(
        _rotationSchemeIdMeta,
        rotationSchemeId.isAcceptableOrUnknown(
          data['rotation_scheme_id']!,
          _rotationSchemeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rotationSchemeIdMeta);
    }
    if (data.containsKey('rakaat_span_count')) {
      context.handle(
        _rakaatSpanCountMeta,
        rakaatSpanCount.isAcceptableOrUnknown(
          data['rakaat_span_count']!,
          _rakaatSpanCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rakaatSpanCountMeta);
    }
    if (data.containsKey('prayer_session_id')) {
      context.handle(
        _prayerSessionIdMeta,
        prayerSessionId.isAcceptableOrUnknown(
          data['prayer_session_id']!,
          _prayerSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
        _prayerTypeMeta,
        prayerType.isAcceptableOrUnknown(data['prayer_type']!, _prayerTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('is_qada')) {
      context.handle(
        _isQadaMeta,
        isQada.isAcceptableOrUnknown(data['is_qada']!, _isQadaMeta),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id, rotationSchemeId},
  ];
  @override
  RecitationEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecitationEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      journalSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}journal_sequence'],
      )!,
      surahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surah_id'],
      )!,
      rotationSchemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rotation_scheme_id'],
      )!,
      rakaatSpanCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rakaat_span_count'],
      )!,
      prayerSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prayer_session_id'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      prayerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prayer_type'],
      )!,
      isQada: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_qada'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at_utc'],
      ),
    );
  }

  @override
  $RecitationEventsTable createAlias(String alias) {
    return $RecitationEventsTable(attachedDatabase, alias);
  }
}

class RecitationEventRow extends DataClass
    implements Insertable<RecitationEventRow> {
  final String id;
  final int journalSequence;
  final String surahId;
  final String rotationSchemeId;
  final int rakaatSpanCount;
  final String? prayerSessionId;
  final DateTime createdAtUtc;
  final String localDate;
  final String prayerType;
  final bool isQada;
  final DateTime? deletedAtUtc;
  const RecitationEventRow({
    required this.id,
    required this.journalSequence,
    required this.surahId,
    required this.rotationSchemeId,
    required this.rakaatSpanCount,
    this.prayerSessionId,
    required this.createdAtUtc,
    required this.localDate,
    required this.prayerType,
    required this.isQada,
    this.deletedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['journal_sequence'] = Variable<int>(journalSequence);
    map['surah_id'] = Variable<String>(surahId);
    map['rotation_scheme_id'] = Variable<String>(rotationSchemeId);
    map['rakaat_span_count'] = Variable<int>(rakaatSpanCount);
    if (!nullToAbsent || prayerSessionId != null) {
      map['prayer_session_id'] = Variable<String>(prayerSessionId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['local_date'] = Variable<String>(localDate);
    map['prayer_type'] = Variable<String>(prayerType);
    map['is_qada'] = Variable<bool>(isQada);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    return map;
  }

  RecitationEventsCompanion toCompanion(bool nullToAbsent) {
    return RecitationEventsCompanion(
      id: Value(id),
      journalSequence: Value(journalSequence),
      surahId: Value(surahId),
      rotationSchemeId: Value(rotationSchemeId),
      rakaatSpanCount: Value(rakaatSpanCount),
      prayerSessionId: prayerSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(prayerSessionId),
      createdAtUtc: Value(createdAtUtc),
      localDate: Value(localDate),
      prayerType: Value(prayerType),
      isQada: Value(isQada),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory RecitationEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecitationEventRow(
      id: serializer.fromJson<String>(json['id']),
      journalSequence: serializer.fromJson<int>(json['journalSequence']),
      surahId: serializer.fromJson<String>(json['surahId']),
      rotationSchemeId: serializer.fromJson<String>(json['rotationSchemeId']),
      rakaatSpanCount: serializer.fromJson<int>(json['rakaatSpanCount']),
      prayerSessionId: serializer.fromJson<String?>(json['prayerSessionId']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      localDate: serializer.fromJson<String>(json['localDate']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      isQada: serializer.fromJson<bool>(json['isQada']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'journalSequence': serializer.toJson<int>(journalSequence),
      'surahId': serializer.toJson<String>(surahId),
      'rotationSchemeId': serializer.toJson<String>(rotationSchemeId),
      'rakaatSpanCount': serializer.toJson<int>(rakaatSpanCount),
      'prayerSessionId': serializer.toJson<String?>(prayerSessionId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'localDate': serializer.toJson<String>(localDate),
      'prayerType': serializer.toJson<String>(prayerType),
      'isQada': serializer.toJson<bool>(isQada),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
    };
  }

  RecitationEventRow copyWith({
    String? id,
    int? journalSequence,
    String? surahId,
    String? rotationSchemeId,
    int? rakaatSpanCount,
    Value<String?> prayerSessionId = const Value.absent(),
    DateTime? createdAtUtc,
    String? localDate,
    String? prayerType,
    bool? isQada,
    Value<DateTime?> deletedAtUtc = const Value.absent(),
  }) => RecitationEventRow(
    id: id ?? this.id,
    journalSequence: journalSequence ?? this.journalSequence,
    surahId: surahId ?? this.surahId,
    rotationSchemeId: rotationSchemeId ?? this.rotationSchemeId,
    rakaatSpanCount: rakaatSpanCount ?? this.rakaatSpanCount,
    prayerSessionId: prayerSessionId.present
        ? prayerSessionId.value
        : this.prayerSessionId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    localDate: localDate ?? this.localDate,
    prayerType: prayerType ?? this.prayerType,
    isQada: isQada ?? this.isQada,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
  );
  RecitationEventRow copyWithCompanion(RecitationEventsCompanion data) {
    return RecitationEventRow(
      id: data.id.present ? data.id.value : this.id,
      journalSequence: data.journalSequence.present
          ? data.journalSequence.value
          : this.journalSequence,
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      rotationSchemeId: data.rotationSchemeId.present
          ? data.rotationSchemeId.value
          : this.rotationSchemeId,
      rakaatSpanCount: data.rakaatSpanCount.present
          ? data.rakaatSpanCount.value
          : this.rakaatSpanCount,
      prayerSessionId: data.prayerSessionId.present
          ? data.prayerSessionId.value
          : this.prayerSessionId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      prayerType: data.prayerType.present
          ? data.prayerType.value
          : this.prayerType,
      isQada: data.isQada.present ? data.isQada.value : this.isQada,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecitationEventRow(')
          ..write('id: $id, ')
          ..write('journalSequence: $journalSequence, ')
          ..write('surahId: $surahId, ')
          ..write('rotationSchemeId: $rotationSchemeId, ')
          ..write('rakaatSpanCount: $rakaatSpanCount, ')
          ..write('prayerSessionId: $prayerSessionId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('localDate: $localDate, ')
          ..write('prayerType: $prayerType, ')
          ..write('isQada: $isQada, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    journalSequence,
    surahId,
    rotationSchemeId,
    rakaatSpanCount,
    prayerSessionId,
    createdAtUtc,
    localDate,
    prayerType,
    isQada,
    deletedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecitationEventRow &&
          other.id == this.id &&
          other.journalSequence == this.journalSequence &&
          other.surahId == this.surahId &&
          other.rotationSchemeId == this.rotationSchemeId &&
          other.rakaatSpanCount == this.rakaatSpanCount &&
          other.prayerSessionId == this.prayerSessionId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.localDate == this.localDate &&
          other.prayerType == this.prayerType &&
          other.isQada == this.isQada &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class RecitationEventsCompanion extends UpdateCompanion<RecitationEventRow> {
  final Value<String> id;
  final Value<int> journalSequence;
  final Value<String> surahId;
  final Value<String> rotationSchemeId;
  final Value<int> rakaatSpanCount;
  final Value<String?> prayerSessionId;
  final Value<DateTime> createdAtUtc;
  final Value<String> localDate;
  final Value<String> prayerType;
  final Value<bool> isQada;
  final Value<DateTime?> deletedAtUtc;
  final Value<int> rowid;
  const RecitationEventsCompanion({
    this.id = const Value.absent(),
    this.journalSequence = const Value.absent(),
    this.surahId = const Value.absent(),
    this.rotationSchemeId = const Value.absent(),
    this.rakaatSpanCount = const Value.absent(),
    this.prayerSessionId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.localDate = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.isQada = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecitationEventsCompanion.insert({
    required String id,
    required int journalSequence,
    required String surahId,
    required String rotationSchemeId,
    required int rakaatSpanCount,
    this.prayerSessionId = const Value.absent(),
    required DateTime createdAtUtc,
    required String localDate,
    required String prayerType,
    this.isQada = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       journalSequence = Value(journalSequence),
       surahId = Value(surahId),
       rotationSchemeId = Value(rotationSchemeId),
       rakaatSpanCount = Value(rakaatSpanCount),
       createdAtUtc = Value(createdAtUtc),
       localDate = Value(localDate),
       prayerType = Value(prayerType);
  static Insertable<RecitationEventRow> custom({
    Expression<String>? id,
    Expression<int>? journalSequence,
    Expression<String>? surahId,
    Expression<String>? rotationSchemeId,
    Expression<int>? rakaatSpanCount,
    Expression<String>? prayerSessionId,
    Expression<DateTime>? createdAtUtc,
    Expression<String>? localDate,
    Expression<String>? prayerType,
    Expression<bool>? isQada,
    Expression<DateTime>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journalSequence != null) 'journal_sequence': journalSequence,
      if (surahId != null) 'surah_id': surahId,
      if (rotationSchemeId != null) 'rotation_scheme_id': rotationSchemeId,
      if (rakaatSpanCount != null) 'rakaat_span_count': rakaatSpanCount,
      if (prayerSessionId != null) 'prayer_session_id': prayerSessionId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (localDate != null) 'local_date': localDate,
      if (prayerType != null) 'prayer_type': prayerType,
      if (isQada != null) 'is_qada': isQada,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecitationEventsCompanion copyWith({
    Value<String>? id,
    Value<int>? journalSequence,
    Value<String>? surahId,
    Value<String>? rotationSchemeId,
    Value<int>? rakaatSpanCount,
    Value<String?>? prayerSessionId,
    Value<DateTime>? createdAtUtc,
    Value<String>? localDate,
    Value<String>? prayerType,
    Value<bool>? isQada,
    Value<DateTime?>? deletedAtUtc,
    Value<int>? rowid,
  }) {
    return RecitationEventsCompanion(
      id: id ?? this.id,
      journalSequence: journalSequence ?? this.journalSequence,
      surahId: surahId ?? this.surahId,
      rotationSchemeId: rotationSchemeId ?? this.rotationSchemeId,
      rakaatSpanCount: rakaatSpanCount ?? this.rakaatSpanCount,
      prayerSessionId: prayerSessionId ?? this.prayerSessionId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      localDate: localDate ?? this.localDate,
      prayerType: prayerType ?? this.prayerType,
      isQada: isQada ?? this.isQada,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (journalSequence.present) {
      map['journal_sequence'] = Variable<int>(journalSequence.value);
    }
    if (surahId.present) {
      map['surah_id'] = Variable<String>(surahId.value);
    }
    if (rotationSchemeId.present) {
      map['rotation_scheme_id'] = Variable<String>(rotationSchemeId.value);
    }
    if (rakaatSpanCount.present) {
      map['rakaat_span_count'] = Variable<int>(rakaatSpanCount.value);
    }
    if (prayerSessionId.present) {
      map['prayer_session_id'] = Variable<String>(prayerSessionId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (isQada.present) {
      map['is_qada'] = Variable<bool>(isQada.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecitationEventsCompanion(')
          ..write('id: $id, ')
          ..write('journalSequence: $journalSequence, ')
          ..write('surahId: $surahId, ')
          ..write('rotationSchemeId: $rotationSchemeId, ')
          ..write('rakaatSpanCount: $rakaatSpanCount, ')
          ..write('prayerSessionId: $prayerSessionId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('localDate: $localDate, ')
          ..write('prayerType: $prayerType, ')
          ..write('isQada: $isQada, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecitationEventPartsTable extends RecitationEventParts
    with TableInfo<$RecitationEventPartsTable, RecitationEventPartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecitationEventPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeIdMeta = const VerificationMeta(
    'schemeId',
  );
  @override
  late final GeneratedColumn<String> schemeId = GeneratedColumn<String>(
    'scheme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, schemeId, partId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recitation_event_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecitationEventPartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('scheme_id')) {
      context.handle(
        _schemeIdMeta,
        schemeId.isAcceptableOrUnknown(data['scheme_id']!, _schemeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schemeIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId, partId};
  @override
  RecitationEventPartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecitationEventPartRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      schemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
    );
  }

  @override
  $RecitationEventPartsTable createAlias(String alias) {
    return $RecitationEventPartsTable(attachedDatabase, alias);
  }
}

class RecitationEventPartRow extends DataClass
    implements Insertable<RecitationEventPartRow> {
  final String eventId;
  final String schemeId;
  final String partId;
  const RecitationEventPartRow({
    required this.eventId,
    required this.schemeId,
    required this.partId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['scheme_id'] = Variable<String>(schemeId);
    map['part_id'] = Variable<String>(partId);
    return map;
  }

  RecitationEventPartsCompanion toCompanion(bool nullToAbsent) {
    return RecitationEventPartsCompanion(
      eventId: Value(eventId),
      schemeId: Value(schemeId),
      partId: Value(partId),
    );
  }

  factory RecitationEventPartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecitationEventPartRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      schemeId: serializer.fromJson<String>(json['schemeId']),
      partId: serializer.fromJson<String>(json['partId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'schemeId': serializer.toJson<String>(schemeId),
      'partId': serializer.toJson<String>(partId),
    };
  }

  RecitationEventPartRow copyWith({
    String? eventId,
    String? schemeId,
    String? partId,
  }) => RecitationEventPartRow(
    eventId: eventId ?? this.eventId,
    schemeId: schemeId ?? this.schemeId,
    partId: partId ?? this.partId,
  );
  RecitationEventPartRow copyWithCompanion(RecitationEventPartsCompanion data) {
    return RecitationEventPartRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      schemeId: data.schemeId.present ? data.schemeId.value : this.schemeId,
      partId: data.partId.present ? data.partId.value : this.partId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecitationEventPartRow(')
          ..write('eventId: $eventId, ')
          ..write('schemeId: $schemeId, ')
          ..write('partId: $partId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, schemeId, partId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecitationEventPartRow &&
          other.eventId == this.eventId &&
          other.schemeId == this.schemeId &&
          other.partId == this.partId);
}

class RecitationEventPartsCompanion
    extends UpdateCompanion<RecitationEventPartRow> {
  final Value<String> eventId;
  final Value<String> schemeId;
  final Value<String> partId;
  final Value<int> rowid;
  const RecitationEventPartsCompanion({
    this.eventId = const Value.absent(),
    this.schemeId = const Value.absent(),
    this.partId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecitationEventPartsCompanion.insert({
    required String eventId,
    required String schemeId,
    required String partId,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       schemeId = Value(schemeId),
       partId = Value(partId);
  static Insertable<RecitationEventPartRow> custom({
    Expression<String>? eventId,
    Expression<String>? schemeId,
    Expression<String>? partId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (schemeId != null) 'scheme_id': schemeId,
      if (partId != null) 'part_id': partId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecitationEventPartsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? schemeId,
    Value<String>? partId,
    Value<int>? rowid,
  }) {
    return RecitationEventPartsCompanion(
      eventId: eventId ?? this.eventId,
      schemeId: schemeId ?? this.schemeId,
      partId: partId ?? this.partId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (schemeId.present) {
      map['scheme_id'] = Variable<String>(schemeId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecitationEventPartsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('schemeId: $schemeId, ')
          ..write('partId: $partId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RotationAdjustmentsTable extends RotationAdjustments
    with TableInfo<$RotationAdjustmentsTable, RotationAdjustmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RotationAdjustmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _journalSequenceMeta = const VerificationMeta(
    'journalSequence',
  );
  @override
  late final GeneratedColumn<int> journalSequence = GeneratedColumn<int>(
    'journal_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _surahIdMeta = const VerificationMeta(
    'surahId',
  );
  @override
  late final GeneratedColumn<String> surahId = GeneratedColumn<String>(
    'surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mastered_surahs (surah_id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _rotationSchemeIdMeta = const VerificationMeta(
    'rotationSchemeId',
  );
  @override
  late final GeneratedColumn<String> rotationSchemeId = GeneratedColumn<String>(
    'rotation_scheme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAtUtc = GeneratedColumn<DateTime>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    journalSequence,
    surahId,
    rotationSchemeId,
    delta,
    reason,
    createdAtUtc,
    deletedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rotation_adjustments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RotationAdjustmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('journal_sequence')) {
      context.handle(
        _journalSequenceMeta,
        journalSequence.isAcceptableOrUnknown(
          data['journal_sequence']!,
          _journalSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_journalSequenceMeta);
    }
    if (data.containsKey('surah_id')) {
      context.handle(
        _surahIdMeta,
        surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surahIdMeta);
    }
    if (data.containsKey('rotation_scheme_id')) {
      context.handle(
        _rotationSchemeIdMeta,
        rotationSchemeId.isAcceptableOrUnknown(
          data['rotation_scheme_id']!,
          _rotationSchemeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rotationSchemeIdMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RotationAdjustmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RotationAdjustmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      journalSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}journal_sequence'],
      )!,
      surahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surah_id'],
      )!,
      rotationSchemeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rotation_scheme_id'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at_utc'],
      ),
    );
  }

  @override
  $RotationAdjustmentsTable createAlias(String alias) {
    return $RotationAdjustmentsTable(attachedDatabase, alias);
  }
}

class RotationAdjustmentRow extends DataClass
    implements Insertable<RotationAdjustmentRow> {
  final String id;
  final int journalSequence;
  final String surahId;
  final String rotationSchemeId;
  final int delta;
  final String reason;
  final DateTime createdAtUtc;
  final DateTime? deletedAtUtc;
  const RotationAdjustmentRow({
    required this.id,
    required this.journalSequence,
    required this.surahId,
    required this.rotationSchemeId,
    required this.delta,
    required this.reason,
    required this.createdAtUtc,
    this.deletedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['journal_sequence'] = Variable<int>(journalSequence);
    map['surah_id'] = Variable<String>(surahId);
    map['rotation_scheme_id'] = Variable<String>(rotationSchemeId);
    map['delta'] = Variable<int>(delta);
    map['reason'] = Variable<String>(reason);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc);
    }
    return map;
  }

  RotationAdjustmentsCompanion toCompanion(bool nullToAbsent) {
    return RotationAdjustmentsCompanion(
      id: Value(id),
      journalSequence: Value(journalSequence),
      surahId: Value(surahId),
      rotationSchemeId: Value(rotationSchemeId),
      delta: Value(delta),
      reason: Value(reason),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory RotationAdjustmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RotationAdjustmentRow(
      id: serializer.fromJson<String>(json['id']),
      journalSequence: serializer.fromJson<int>(json['journalSequence']),
      surahId: serializer.fromJson<String>(json['surahId']),
      rotationSchemeId: serializer.fromJson<String>(json['rotationSchemeId']),
      delta: serializer.fromJson<int>(json['delta']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<DateTime?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'journalSequence': serializer.toJson<int>(journalSequence),
      'surahId': serializer.toJson<String>(surahId),
      'rotationSchemeId': serializer.toJson<String>(rotationSchemeId),
      'delta': serializer.toJson<int>(delta),
      'reason': serializer.toJson<String>(reason),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<DateTime?>(deletedAtUtc),
    };
  }

  RotationAdjustmentRow copyWith({
    String? id,
    int? journalSequence,
    String? surahId,
    String? rotationSchemeId,
    int? delta,
    String? reason,
    DateTime? createdAtUtc,
    Value<DateTime?> deletedAtUtc = const Value.absent(),
  }) => RotationAdjustmentRow(
    id: id ?? this.id,
    journalSequence: journalSequence ?? this.journalSequence,
    surahId: surahId ?? this.surahId,
    rotationSchemeId: rotationSchemeId ?? this.rotationSchemeId,
    delta: delta ?? this.delta,
    reason: reason ?? this.reason,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
  );
  RotationAdjustmentRow copyWithCompanion(RotationAdjustmentsCompanion data) {
    return RotationAdjustmentRow(
      id: data.id.present ? data.id.value : this.id,
      journalSequence: data.journalSequence.present
          ? data.journalSequence.value
          : this.journalSequence,
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      rotationSchemeId: data.rotationSchemeId.present
          ? data.rotationSchemeId.value
          : this.rotationSchemeId,
      delta: data.delta.present ? data.delta.value : this.delta,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RotationAdjustmentRow(')
          ..write('id: $id, ')
          ..write('journalSequence: $journalSequence, ')
          ..write('surahId: $surahId, ')
          ..write('rotationSchemeId: $rotationSchemeId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    journalSequence,
    surahId,
    rotationSchemeId,
    delta,
    reason,
    createdAtUtc,
    deletedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RotationAdjustmentRow &&
          other.id == this.id &&
          other.journalSequence == this.journalSequence &&
          other.surahId == this.surahId &&
          other.rotationSchemeId == this.rotationSchemeId &&
          other.delta == this.delta &&
          other.reason == this.reason &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class RotationAdjustmentsCompanion
    extends UpdateCompanion<RotationAdjustmentRow> {
  final Value<String> id;
  final Value<int> journalSequence;
  final Value<String> surahId;
  final Value<String> rotationSchemeId;
  final Value<int> delta;
  final Value<String> reason;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime?> deletedAtUtc;
  final Value<int> rowid;
  const RotationAdjustmentsCompanion({
    this.id = const Value.absent(),
    this.journalSequence = const Value.absent(),
    this.surahId = const Value.absent(),
    this.rotationSchemeId = const Value.absent(),
    this.delta = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RotationAdjustmentsCompanion.insert({
    required String id,
    required int journalSequence,
    required String surahId,
    required String rotationSchemeId,
    required int delta,
    required String reason,
    required DateTime createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       journalSequence = Value(journalSequence),
       surahId = Value(surahId),
       rotationSchemeId = Value(rotationSchemeId),
       delta = Value(delta),
       reason = Value(reason),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<RotationAdjustmentRow> custom({
    Expression<String>? id,
    Expression<int>? journalSequence,
    Expression<String>? surahId,
    Expression<String>? rotationSchemeId,
    Expression<int>? delta,
    Expression<String>? reason,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journalSequence != null) 'journal_sequence': journalSequence,
      if (surahId != null) 'surah_id': surahId,
      if (rotationSchemeId != null) 'rotation_scheme_id': rotationSchemeId,
      if (delta != null) 'delta': delta,
      if (reason != null) 'reason': reason,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RotationAdjustmentsCompanion copyWith({
    Value<String>? id,
    Value<int>? journalSequence,
    Value<String>? surahId,
    Value<String>? rotationSchemeId,
    Value<int>? delta,
    Value<String>? reason,
    Value<DateTime>? createdAtUtc,
    Value<DateTime?>? deletedAtUtc,
    Value<int>? rowid,
  }) {
    return RotationAdjustmentsCompanion(
      id: id ?? this.id,
      journalSequence: journalSequence ?? this.journalSequence,
      surahId: surahId ?? this.surahId,
      rotationSchemeId: rotationSchemeId ?? this.rotationSchemeId,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (journalSequence.present) {
      map['journal_sequence'] = Variable<int>(journalSequence.value);
    }
    if (surahId.present) {
      map['surah_id'] = Variable<String>(surahId.value);
    }
    if (rotationSchemeId.present) {
      map['rotation_scheme_id'] = Variable<String>(rotationSchemeId.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<DateTime>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RotationAdjustmentsCompanion(')
          ..write('id: $id, ')
          ..write('journalSequence: $journalSequence, ')
          ..write('surahId: $surahId, ')
          ..write('rotationSchemeId: $rotationSchemeId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningSurahsTable extends LearningSurahs
    with TableInfo<$LearningSurahsTable, LearningSurahRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningSurahsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surahIdMeta = const VerificationMeta(
    'surahId',
  );
  @override
  late final GeneratedColumn<String> surahId = GeneratedColumn<String>(
    'surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES surah_metadata (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _ayahCountMeta = const VerificationMeta(
    'ayahCount',
  );
  @override
  late final GeneratedColumn<int> ayahCount = GeneratedColumn<int>(
    'ayah_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageKindMeta = const VerificationMeta(
    'stageKind',
  );
  @override
  late final GeneratedColumn<String> stageKind = GeneratedColumn<String>(
    'stage_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageEndAyahMeta = const VerificationMeta(
    'stageEndAyah',
  );
  @override
  late final GeneratedColumn<int> stageEndAyah = GeneratedColumn<int>(
    'stage_end_ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastLearningActivityAtUtcMeta =
      const VerificationMeta('lastLearningActivityAtUtc');
  @override
  late final GeneratedColumn<DateTime> lastLearningActivityAtUtc =
      GeneratedColumn<DateTime>(
        'last_learning_activity_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _inactivityRollbackForActivityAtUtcMeta =
      const VerificationMeta('inactivityRollbackForActivityAtUtc');
  @override
  late final GeneratedColumn<DateTime> inactivityRollbackForActivityAtUtc =
      GeneratedColumn<DateTime>(
        'inactivity_rollback_for_activity_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surahId,
    ayahCount,
    stageKind,
    stageEndAyah,
    status,
    lastLearningActivityAtUtc,
    inactivityRollbackForActivityAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_surahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningSurahRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('surah_id')) {
      context.handle(
        _surahIdMeta,
        surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surahIdMeta);
    }
    if (data.containsKey('ayah_count')) {
      context.handle(
        _ayahCountMeta,
        ayahCount.isAcceptableOrUnknown(data['ayah_count']!, _ayahCountMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahCountMeta);
    }
    if (data.containsKey('stage_kind')) {
      context.handle(
        _stageKindMeta,
        stageKind.isAcceptableOrUnknown(data['stage_kind']!, _stageKindMeta),
      );
    } else if (isInserting) {
      context.missing(_stageKindMeta);
    }
    if (data.containsKey('stage_end_ayah')) {
      context.handle(
        _stageEndAyahMeta,
        stageEndAyah.isAcceptableOrUnknown(
          data['stage_end_ayah']!,
          _stageEndAyahMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stageEndAyahMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_learning_activity_at_utc')) {
      context.handle(
        _lastLearningActivityAtUtcMeta,
        lastLearningActivityAtUtc.isAcceptableOrUnknown(
          data['last_learning_activity_at_utc']!,
          _lastLearningActivityAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('inactivity_rollback_for_activity_at_utc')) {
      context.handle(
        _inactivityRollbackForActivityAtUtcMeta,
        inactivityRollbackForActivityAtUtc.isAcceptableOrUnknown(
          data['inactivity_rollback_for_activity_at_utc']!,
          _inactivityRollbackForActivityAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningSurahRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningSurahRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      surahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}surah_id'],
      )!,
      ayahCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_count'],
      )!,
      stageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_kind'],
      )!,
      stageEndAyah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_end_ayah'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastLearningActivityAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_learning_activity_at_utc'],
      ),
      inactivityRollbackForActivityAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}inactivity_rollback_for_activity_at_utc'],
      ),
    );
  }

  @override
  $LearningSurahsTable createAlias(String alias) {
    return $LearningSurahsTable(attachedDatabase, alias);
  }
}

class LearningSurahRow extends DataClass
    implements Insertable<LearningSurahRow> {
  final String id;
  final String surahId;
  final int ayahCount;
  final String stageKind;
  final int stageEndAyah;
  final String status;
  final DateTime? lastLearningActivityAtUtc;
  final DateTime? inactivityRollbackForActivityAtUtc;
  const LearningSurahRow({
    required this.id,
    required this.surahId,
    required this.ayahCount,
    required this.stageKind,
    required this.stageEndAyah,
    required this.status,
    this.lastLearningActivityAtUtc,
    this.inactivityRollbackForActivityAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['surah_id'] = Variable<String>(surahId);
    map['ayah_count'] = Variable<int>(ayahCount);
    map['stage_kind'] = Variable<String>(stageKind);
    map['stage_end_ayah'] = Variable<int>(stageEndAyah);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastLearningActivityAtUtc != null) {
      map['last_learning_activity_at_utc'] = Variable<DateTime>(
        lastLearningActivityAtUtc,
      );
    }
    if (!nullToAbsent || inactivityRollbackForActivityAtUtc != null) {
      map['inactivity_rollback_for_activity_at_utc'] = Variable<DateTime>(
        inactivityRollbackForActivityAtUtc,
      );
    }
    return map;
  }

  LearningSurahsCompanion toCompanion(bool nullToAbsent) {
    return LearningSurahsCompanion(
      id: Value(id),
      surahId: Value(surahId),
      ayahCount: Value(ayahCount),
      stageKind: Value(stageKind),
      stageEndAyah: Value(stageEndAyah),
      status: Value(status),
      lastLearningActivityAtUtc:
          lastLearningActivityAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLearningActivityAtUtc),
      inactivityRollbackForActivityAtUtc:
          inactivityRollbackForActivityAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(inactivityRollbackForActivityAtUtc),
    );
  }

  factory LearningSurahRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningSurahRow(
      id: serializer.fromJson<String>(json['id']),
      surahId: serializer.fromJson<String>(json['surahId']),
      ayahCount: serializer.fromJson<int>(json['ayahCount']),
      stageKind: serializer.fromJson<String>(json['stageKind']),
      stageEndAyah: serializer.fromJson<int>(json['stageEndAyah']),
      status: serializer.fromJson<String>(json['status']),
      lastLearningActivityAtUtc: serializer.fromJson<DateTime?>(
        json['lastLearningActivityAtUtc'],
      ),
      inactivityRollbackForActivityAtUtc: serializer.fromJson<DateTime?>(
        json['inactivityRollbackForActivityAtUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'surahId': serializer.toJson<String>(surahId),
      'ayahCount': serializer.toJson<int>(ayahCount),
      'stageKind': serializer.toJson<String>(stageKind),
      'stageEndAyah': serializer.toJson<int>(stageEndAyah),
      'status': serializer.toJson<String>(status),
      'lastLearningActivityAtUtc': serializer.toJson<DateTime?>(
        lastLearningActivityAtUtc,
      ),
      'inactivityRollbackForActivityAtUtc': serializer.toJson<DateTime?>(
        inactivityRollbackForActivityAtUtc,
      ),
    };
  }

  LearningSurahRow copyWith({
    String? id,
    String? surahId,
    int? ayahCount,
    String? stageKind,
    int? stageEndAyah,
    String? status,
    Value<DateTime?> lastLearningActivityAtUtc = const Value.absent(),
    Value<DateTime?> inactivityRollbackForActivityAtUtc = const Value.absent(),
  }) => LearningSurahRow(
    id: id ?? this.id,
    surahId: surahId ?? this.surahId,
    ayahCount: ayahCount ?? this.ayahCount,
    stageKind: stageKind ?? this.stageKind,
    stageEndAyah: stageEndAyah ?? this.stageEndAyah,
    status: status ?? this.status,
    lastLearningActivityAtUtc: lastLearningActivityAtUtc.present
        ? lastLearningActivityAtUtc.value
        : this.lastLearningActivityAtUtc,
    inactivityRollbackForActivityAtUtc:
        inactivityRollbackForActivityAtUtc.present
        ? inactivityRollbackForActivityAtUtc.value
        : this.inactivityRollbackForActivityAtUtc,
  );
  LearningSurahRow copyWithCompanion(LearningSurahsCompanion data) {
    return LearningSurahRow(
      id: data.id.present ? data.id.value : this.id,
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      ayahCount: data.ayahCount.present ? data.ayahCount.value : this.ayahCount,
      stageKind: data.stageKind.present ? data.stageKind.value : this.stageKind,
      stageEndAyah: data.stageEndAyah.present
          ? data.stageEndAyah.value
          : this.stageEndAyah,
      status: data.status.present ? data.status.value : this.status,
      lastLearningActivityAtUtc: data.lastLearningActivityAtUtc.present
          ? data.lastLearningActivityAtUtc.value
          : this.lastLearningActivityAtUtc,
      inactivityRollbackForActivityAtUtc:
          data.inactivityRollbackForActivityAtUtc.present
          ? data.inactivityRollbackForActivityAtUtc.value
          : this.inactivityRollbackForActivityAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningSurahRow(')
          ..write('id: $id, ')
          ..write('surahId: $surahId, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('stageKind: $stageKind, ')
          ..write('stageEndAyah: $stageEndAyah, ')
          ..write('status: $status, ')
          ..write('lastLearningActivityAtUtc: $lastLearningActivityAtUtc, ')
          ..write(
            'inactivityRollbackForActivityAtUtc: $inactivityRollbackForActivityAtUtc',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    ayahCount,
    stageKind,
    stageEndAyah,
    status,
    lastLearningActivityAtUtc,
    inactivityRollbackForActivityAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningSurahRow &&
          other.id == this.id &&
          other.surahId == this.surahId &&
          other.ayahCount == this.ayahCount &&
          other.stageKind == this.stageKind &&
          other.stageEndAyah == this.stageEndAyah &&
          other.status == this.status &&
          other.lastLearningActivityAtUtc == this.lastLearningActivityAtUtc &&
          other.inactivityRollbackForActivityAtUtc ==
              this.inactivityRollbackForActivityAtUtc);
}

class LearningSurahsCompanion extends UpdateCompanion<LearningSurahRow> {
  final Value<String> id;
  final Value<String> surahId;
  final Value<int> ayahCount;
  final Value<String> stageKind;
  final Value<int> stageEndAyah;
  final Value<String> status;
  final Value<DateTime?> lastLearningActivityAtUtc;
  final Value<DateTime?> inactivityRollbackForActivityAtUtc;
  final Value<int> rowid;
  const LearningSurahsCompanion({
    this.id = const Value.absent(),
    this.surahId = const Value.absent(),
    this.ayahCount = const Value.absent(),
    this.stageKind = const Value.absent(),
    this.stageEndAyah = const Value.absent(),
    this.status = const Value.absent(),
    this.lastLearningActivityAtUtc = const Value.absent(),
    this.inactivityRollbackForActivityAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningSurahsCompanion.insert({
    required String id,
    required String surahId,
    required int ayahCount,
    required String stageKind,
    required int stageEndAyah,
    required String status,
    this.lastLearningActivityAtUtc = const Value.absent(),
    this.inactivityRollbackForActivityAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       surahId = Value(surahId),
       ayahCount = Value(ayahCount),
       stageKind = Value(stageKind),
       stageEndAyah = Value(stageEndAyah),
       status = Value(status);
  static Insertable<LearningSurahRow> custom({
    Expression<String>? id,
    Expression<String>? surahId,
    Expression<int>? ayahCount,
    Expression<String>? stageKind,
    Expression<int>? stageEndAyah,
    Expression<String>? status,
    Expression<DateTime>? lastLearningActivityAtUtc,
    Expression<DateTime>? inactivityRollbackForActivityAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahId != null) 'surah_id': surahId,
      if (ayahCount != null) 'ayah_count': ayahCount,
      if (stageKind != null) 'stage_kind': stageKind,
      if (stageEndAyah != null) 'stage_end_ayah': stageEndAyah,
      if (status != null) 'status': status,
      if (lastLearningActivityAtUtc != null)
        'last_learning_activity_at_utc': lastLearningActivityAtUtc,
      if (inactivityRollbackForActivityAtUtc != null)
        'inactivity_rollback_for_activity_at_utc':
            inactivityRollbackForActivityAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningSurahsCompanion copyWith({
    Value<String>? id,
    Value<String>? surahId,
    Value<int>? ayahCount,
    Value<String>? stageKind,
    Value<int>? stageEndAyah,
    Value<String>? status,
    Value<DateTime?>? lastLearningActivityAtUtc,
    Value<DateTime?>? inactivityRollbackForActivityAtUtc,
    Value<int>? rowid,
  }) {
    return LearningSurahsCompanion(
      id: id ?? this.id,
      surahId: surahId ?? this.surahId,
      ayahCount: ayahCount ?? this.ayahCount,
      stageKind: stageKind ?? this.stageKind,
      stageEndAyah: stageEndAyah ?? this.stageEndAyah,
      status: status ?? this.status,
      lastLearningActivityAtUtc:
          lastLearningActivityAtUtc ?? this.lastLearningActivityAtUtc,
      inactivityRollbackForActivityAtUtc:
          inactivityRollbackForActivityAtUtc ??
          this.inactivityRollbackForActivityAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (surahId.present) {
      map['surah_id'] = Variable<String>(surahId.value);
    }
    if (ayahCount.present) {
      map['ayah_count'] = Variable<int>(ayahCount.value);
    }
    if (stageKind.present) {
      map['stage_kind'] = Variable<String>(stageKind.value);
    }
    if (stageEndAyah.present) {
      map['stage_end_ayah'] = Variable<int>(stageEndAyah.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastLearningActivityAtUtc.present) {
      map['last_learning_activity_at_utc'] = Variable<DateTime>(
        lastLearningActivityAtUtc.value,
      );
    }
    if (inactivityRollbackForActivityAtUtc.present) {
      map['inactivity_rollback_for_activity_at_utc'] = Variable<DateTime>(
        inactivityRollbackForActivityAtUtc.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningSurahsCompanion(')
          ..write('id: $id, ')
          ..write('surahId: $surahId, ')
          ..write('ayahCount: $ayahCount, ')
          ..write('stageKind: $stageKind, ')
          ..write('stageEndAyah: $stageEndAyah, ')
          ..write('status: $status, ')
          ..write('lastLearningActivityAtUtc: $lastLearningActivityAtUtc, ')
          ..write(
            'inactivityRollbackForActivityAtUtc: $inactivityRollbackForActivityAtUtc, ',
          )
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningEventsTable extends LearningEvents
    with TableInfo<$LearningEventsTable, LearningEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _learningSurahIdMeta = const VerificationMeta(
    'learningSurahId',
  );
  @override
  late final GeneratedColumn<String> learningSurahId = GeneratedColumn<String>(
    'learning_surah_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_surahs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStageKindMeta = const VerificationMeta(
    'fromStageKind',
  );
  @override
  late final GeneratedColumn<String> fromStageKind = GeneratedColumn<String>(
    'from_stage_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStageEndAyahMeta = const VerificationMeta(
    'fromStageEndAyah',
  );
  @override
  late final GeneratedColumn<int> fromStageEndAyah = GeneratedColumn<int>(
    'from_stage_end_ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toStageKindMeta = const VerificationMeta(
    'toStageKind',
  );
  @override
  late final GeneratedColumn<String> toStageKind = GeneratedColumn<String>(
    'to_stage_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toStageEndAyahMeta = const VerificationMeta(
    'toStageEndAyah',
  );
  @override
  late final GeneratedColumn<int> toStageEndAyah = GeneratedColumn<int>(
    'to_stage_end_ayah',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sequence,
    learningSurahId,
    type,
    createdAtUtc,
    fromStageKind,
    fromStageEndAyah,
    toStageKind,
    toStageEndAyah,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('learning_surah_id')) {
      context.handle(
        _learningSurahIdMeta,
        learningSurahId.isAcceptableOrUnknown(
          data['learning_surah_id']!,
          _learningSurahIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningSurahIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('from_stage_kind')) {
      context.handle(
        _fromStageKindMeta,
        fromStageKind.isAcceptableOrUnknown(
          data['from_stage_kind']!,
          _fromStageKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromStageKindMeta);
    }
    if (data.containsKey('from_stage_end_ayah')) {
      context.handle(
        _fromStageEndAyahMeta,
        fromStageEndAyah.isAcceptableOrUnknown(
          data['from_stage_end_ayah']!,
          _fromStageEndAyahMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromStageEndAyahMeta);
    }
    if (data.containsKey('to_stage_kind')) {
      context.handle(
        _toStageKindMeta,
        toStageKind.isAcceptableOrUnknown(
          data['to_stage_kind']!,
          _toStageKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toStageKindMeta);
    }
    if (data.containsKey('to_stage_end_ayah')) {
      context.handle(
        _toStageEndAyahMeta,
        toStageEndAyah.isAcceptableOrUnknown(
          data['to_stage_end_ayah']!,
          _toStageEndAyahMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toStageEndAyahMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequence};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id},
  ];
  @override
  LearningEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      learningSurahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_surah_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      fromStageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_stage_kind'],
      )!,
      fromStageEndAyah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_stage_end_ayah'],
      )!,
      toStageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_stage_kind'],
      )!,
      toStageEndAyah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_stage_end_ayah'],
      )!,
    );
  }

  @override
  $LearningEventsTable createAlias(String alias) {
    return $LearningEventsTable(attachedDatabase, alias);
  }
}

class LearningEventRow extends DataClass
    implements Insertable<LearningEventRow> {
  final String id;
  final int sequence;
  final String learningSurahId;
  final String type;
  final DateTime createdAtUtc;
  final String fromStageKind;
  final int fromStageEndAyah;
  final String toStageKind;
  final int toStageEndAyah;
  const LearningEventRow({
    required this.id,
    required this.sequence,
    required this.learningSurahId,
    required this.type,
    required this.createdAtUtc,
    required this.fromStageKind,
    required this.fromStageEndAyah,
    required this.toStageKind,
    required this.toStageEndAyah,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sequence'] = Variable<int>(sequence);
    map['learning_surah_id'] = Variable<String>(learningSurahId);
    map['type'] = Variable<String>(type);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['from_stage_kind'] = Variable<String>(fromStageKind);
    map['from_stage_end_ayah'] = Variable<int>(fromStageEndAyah);
    map['to_stage_kind'] = Variable<String>(toStageKind);
    map['to_stage_end_ayah'] = Variable<int>(toStageEndAyah);
    return map;
  }

  LearningEventsCompanion toCompanion(bool nullToAbsent) {
    return LearningEventsCompanion(
      id: Value(id),
      sequence: Value(sequence),
      learningSurahId: Value(learningSurahId),
      type: Value(type),
      createdAtUtc: Value(createdAtUtc),
      fromStageKind: Value(fromStageKind),
      fromStageEndAyah: Value(fromStageEndAyah),
      toStageKind: Value(toStageKind),
      toStageEndAyah: Value(toStageEndAyah),
    );
  }

  factory LearningEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningEventRow(
      id: serializer.fromJson<String>(json['id']),
      sequence: serializer.fromJson<int>(json['sequence']),
      learningSurahId: serializer.fromJson<String>(json['learningSurahId']),
      type: serializer.fromJson<String>(json['type']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      fromStageKind: serializer.fromJson<String>(json['fromStageKind']),
      fromStageEndAyah: serializer.fromJson<int>(json['fromStageEndAyah']),
      toStageKind: serializer.fromJson<String>(json['toStageKind']),
      toStageEndAyah: serializer.fromJson<int>(json['toStageEndAyah']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sequence': serializer.toJson<int>(sequence),
      'learningSurahId': serializer.toJson<String>(learningSurahId),
      'type': serializer.toJson<String>(type),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'fromStageKind': serializer.toJson<String>(fromStageKind),
      'fromStageEndAyah': serializer.toJson<int>(fromStageEndAyah),
      'toStageKind': serializer.toJson<String>(toStageKind),
      'toStageEndAyah': serializer.toJson<int>(toStageEndAyah),
    };
  }

  LearningEventRow copyWith({
    String? id,
    int? sequence,
    String? learningSurahId,
    String? type,
    DateTime? createdAtUtc,
    String? fromStageKind,
    int? fromStageEndAyah,
    String? toStageKind,
    int? toStageEndAyah,
  }) => LearningEventRow(
    id: id ?? this.id,
    sequence: sequence ?? this.sequence,
    learningSurahId: learningSurahId ?? this.learningSurahId,
    type: type ?? this.type,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    fromStageKind: fromStageKind ?? this.fromStageKind,
    fromStageEndAyah: fromStageEndAyah ?? this.fromStageEndAyah,
    toStageKind: toStageKind ?? this.toStageKind,
    toStageEndAyah: toStageEndAyah ?? this.toStageEndAyah,
  );
  LearningEventRow copyWithCompanion(LearningEventsCompanion data) {
    return LearningEventRow(
      id: data.id.present ? data.id.value : this.id,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      learningSurahId: data.learningSurahId.present
          ? data.learningSurahId.value
          : this.learningSurahId,
      type: data.type.present ? data.type.value : this.type,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      fromStageKind: data.fromStageKind.present
          ? data.fromStageKind.value
          : this.fromStageKind,
      fromStageEndAyah: data.fromStageEndAyah.present
          ? data.fromStageEndAyah.value
          : this.fromStageEndAyah,
      toStageKind: data.toStageKind.present
          ? data.toStageKind.value
          : this.toStageKind,
      toStageEndAyah: data.toStageEndAyah.present
          ? data.toStageEndAyah.value
          : this.toStageEndAyah,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningEventRow(')
          ..write('id: $id, ')
          ..write('sequence: $sequence, ')
          ..write('learningSurahId: $learningSurahId, ')
          ..write('type: $type, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('fromStageKind: $fromStageKind, ')
          ..write('fromStageEndAyah: $fromStageEndAyah, ')
          ..write('toStageKind: $toStageKind, ')
          ..write('toStageEndAyah: $toStageEndAyah')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sequence,
    learningSurahId,
    type,
    createdAtUtc,
    fromStageKind,
    fromStageEndAyah,
    toStageKind,
    toStageEndAyah,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningEventRow &&
          other.id == this.id &&
          other.sequence == this.sequence &&
          other.learningSurahId == this.learningSurahId &&
          other.type == this.type &&
          other.createdAtUtc == this.createdAtUtc &&
          other.fromStageKind == this.fromStageKind &&
          other.fromStageEndAyah == this.fromStageEndAyah &&
          other.toStageKind == this.toStageKind &&
          other.toStageEndAyah == this.toStageEndAyah);
}

class LearningEventsCompanion extends UpdateCompanion<LearningEventRow> {
  final Value<String> id;
  final Value<int> sequence;
  final Value<String> learningSurahId;
  final Value<String> type;
  final Value<DateTime> createdAtUtc;
  final Value<String> fromStageKind;
  final Value<int> fromStageEndAyah;
  final Value<String> toStageKind;
  final Value<int> toStageEndAyah;
  const LearningEventsCompanion({
    this.id = const Value.absent(),
    this.sequence = const Value.absent(),
    this.learningSurahId = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.fromStageKind = const Value.absent(),
    this.fromStageEndAyah = const Value.absent(),
    this.toStageKind = const Value.absent(),
    this.toStageEndAyah = const Value.absent(),
  });
  LearningEventsCompanion.insert({
    required String id,
    this.sequence = const Value.absent(),
    required String learningSurahId,
    required String type,
    required DateTime createdAtUtc,
    required String fromStageKind,
    required int fromStageEndAyah,
    required String toStageKind,
    required int toStageEndAyah,
  }) : id = Value(id),
       learningSurahId = Value(learningSurahId),
       type = Value(type),
       createdAtUtc = Value(createdAtUtc),
       fromStageKind = Value(fromStageKind),
       fromStageEndAyah = Value(fromStageEndAyah),
       toStageKind = Value(toStageKind),
       toStageEndAyah = Value(toStageEndAyah);
  static Insertable<LearningEventRow> custom({
    Expression<String>? id,
    Expression<int>? sequence,
    Expression<String>? learningSurahId,
    Expression<String>? type,
    Expression<DateTime>? createdAtUtc,
    Expression<String>? fromStageKind,
    Expression<int>? fromStageEndAyah,
    Expression<String>? toStageKind,
    Expression<int>? toStageEndAyah,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sequence != null) 'sequence': sequence,
      if (learningSurahId != null) 'learning_surah_id': learningSurahId,
      if (type != null) 'type': type,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (fromStageKind != null) 'from_stage_kind': fromStageKind,
      if (fromStageEndAyah != null) 'from_stage_end_ayah': fromStageEndAyah,
      if (toStageKind != null) 'to_stage_kind': toStageKind,
      if (toStageEndAyah != null) 'to_stage_end_ayah': toStageEndAyah,
    });
  }

  LearningEventsCompanion copyWith({
    Value<String>? id,
    Value<int>? sequence,
    Value<String>? learningSurahId,
    Value<String>? type,
    Value<DateTime>? createdAtUtc,
    Value<String>? fromStageKind,
    Value<int>? fromStageEndAyah,
    Value<String>? toStageKind,
    Value<int>? toStageEndAyah,
  }) {
    return LearningEventsCompanion(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      learningSurahId: learningSurahId ?? this.learningSurahId,
      type: type ?? this.type,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      fromStageKind: fromStageKind ?? this.fromStageKind,
      fromStageEndAyah: fromStageEndAyah ?? this.fromStageEndAyah,
      toStageKind: toStageKind ?? this.toStageKind,
      toStageEndAyah: toStageEndAyah ?? this.toStageEndAyah,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (learningSurahId.present) {
      map['learning_surah_id'] = Variable<String>(learningSurahId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (fromStageKind.present) {
      map['from_stage_kind'] = Variable<String>(fromStageKind.value);
    }
    if (fromStageEndAyah.present) {
      map['from_stage_end_ayah'] = Variable<int>(fromStageEndAyah.value);
    }
    if (toStageKind.present) {
      map['to_stage_kind'] = Variable<String>(toStageKind.value);
    }
    if (toStageEndAyah.present) {
      map['to_stage_end_ayah'] = Variable<int>(toStageEndAyah.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningEventsCompanion(')
          ..write('id: $id, ')
          ..write('sequence: $sequence, ')
          ..write('learningSurahId: $learningSurahId, ')
          ..write('type: $type, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('fromStageKind: $fromStageKind, ')
          ..write('fromStageEndAyah: $fromStageEndAyah, ')
          ..write('toStageKind: $toStageKind, ')
          ..write('toStageEndAyah: $toStageEndAyah')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTypeMeta = const VerificationMeta(
    'valueType',
  );
  @override
  late final GeneratedColumn<String> valueType = GeneratedColumn<String>(
    'value_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, valueType, updatedAtUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('value_type')) {
      context.handle(
        _valueTypeMeta,
        valueType.isAcceptableOrUnknown(data['value_type']!, _valueTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTypeMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      valueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_type'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  final String valueType;
  final DateTime updatedAtUtc;
  const AppSettingRow({
    required this.key,
    required this.value,
    required this.valueType,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['value_type'] = Variable<String>(valueType);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      valueType: Value(valueType),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      valueType: serializer.fromJson<String>(json['valueType']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'valueType': serializer.toJson<String>(valueType),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  AppSettingRow copyWith({
    String? key,
    String? value,
    String? valueType,
    DateTime? updatedAtUtc,
  }) => AppSettingRow(
    key: key ?? this.key,
    value: value ?? this.value,
    valueType: valueType ?? this.valueType,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, valueType, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.valueType == this.valueType &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> valueType;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.valueType = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required String valueType,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       valueType = Value(valueType),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? valueType,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (valueType != null) 'value_type': valueType,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<String>? valueType,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<String>(valueType.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SurahMetadataTable surahMetadata = $SurahMetadataTable(this);
  late final $MasteredSurahsTable masteredSurahs = $MasteredSurahsTable(this);
  late final $RotationStatesTable rotationStates = $RotationStatesTable(this);
  late final $RotationSchemesTable rotationSchemes = $RotationSchemesTable(
    this,
  );
  late final $RotationPartsTable rotationParts = $RotationPartsTable(this);
  late final $PrayerSessionsTable prayerSessions = $PrayerSessionsTable(this);
  late final $RecitationEventsTable recitationEvents = $RecitationEventsTable(
    this,
  );
  late final $RecitationEventPartsTable recitationEventParts =
      $RecitationEventPartsTable(this);
  late final $RotationAdjustmentsTable rotationAdjustments =
      $RotationAdjustmentsTable(this);
  late final $LearningSurahsTable learningSurahs = $LearningSurahsTable(this);
  late final $LearningEventsTable learningEvents = $LearningEventsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    surahMetadata,
    masteredSurahs,
    rotationStates,
    rotationSchemes,
    rotationParts,
    prayerSessions,
    recitationEvents,
    recitationEventParts,
    rotationAdjustments,
    learningSurahs,
    learningEvents,
    appSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rotation_schemes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rotation_parts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'prayer_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recitation_events', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learning_surahs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learning_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SurahMetadataTableCreateCompanionBuilder =
    SurahMetadataCompanion Function({
      required String id,
      required int surahNumber,
      required String officialName,
      required int ayahCount,
      Value<String?> sourceId,
      Value<String?> sourceVersion,
      Value<int> rowid,
    });
typedef $$SurahMetadataTableUpdateCompanionBuilder =
    SurahMetadataCompanion Function({
      Value<String> id,
      Value<int> surahNumber,
      Value<String> officialName,
      Value<int> ayahCount,
      Value<String?> sourceId,
      Value<String?> sourceVersion,
      Value<int> rowid,
    });

final class $$SurahMetadataTableReferences
    extends
        BaseReferences<_$AppDatabase, $SurahMetadataTable, SurahMetadataRow> {
  $$SurahMetadataTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MasteredSurahsTable, List<MasteredSurahRow>>
  _masteredSurahsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.masteredSurahs,
    aliasName: 'surah_metadata__id__mastered_surahs__surah_id',
  );

  $$MasteredSurahsTableProcessedTableManager get masteredSurahsRefs {
    final manager = $$MasteredSurahsTableTableManager(
      $_db,
      $_db.masteredSurahs,
    ).filter((f) => f.surahId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_masteredSurahsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearningSurahsTable, List<LearningSurahRow>>
  _learningSurahsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.learningSurahs,
    aliasName: 'surah_metadata__id__learning_surahs__surah_id',
  );

  $$LearningSurahsTableProcessedTableManager get learningSurahsRefs {
    final manager = $$LearningSurahsTableTableManager(
      $_db,
      $_db.learningSurahs,
    ).filter((f) => f.surahId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_learningSurahsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SurahMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SurahMetadataTable> {
  $$SurahMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialName => $composableBuilder(
    column: $table.officialName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> masteredSurahsRefs(
    Expression<bool> Function($$MasteredSurahsTableFilterComposer f) f,
  ) {
    final $$MasteredSurahsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.masteredSurahs,
      getReferencedColumn: (t) => t.surahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MasteredSurahsTableFilterComposer(
            $db: $db,
            $table: $db.masteredSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learningSurahsRefs(
    Expression<bool> Function($$LearningSurahsTableFilterComposer f) f,
  ) {
    final $$LearningSurahsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningSurahs,
      getReferencedColumn: (t) => t.surahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSurahsTableFilterComposer(
            $db: $db,
            $table: $db.learningSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SurahMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SurahMetadataTable> {
  $$SurahMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialName => $composableBuilder(
    column: $table.officialName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SurahMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurahMetadataTable> {
  $$SurahMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officialName => $composableBuilder(
    column: $table.officialName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ayahCount =>
      $composableBuilder(column: $table.ayahCount, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => column,
  );

  Expression<T> masteredSurahsRefs<T extends Object>(
    Expression<T> Function($$MasteredSurahsTableAnnotationComposer a) f,
  ) {
    final $$MasteredSurahsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.masteredSurahs,
      getReferencedColumn: (t) => t.surahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MasteredSurahsTableAnnotationComposer(
            $db: $db,
            $table: $db.masteredSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learningSurahsRefs<T extends Object>(
    Expression<T> Function($$LearningSurahsTableAnnotationComposer a) f,
  ) {
    final $$LearningSurahsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningSurahs,
      getReferencedColumn: (t) => t.surahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSurahsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SurahMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SurahMetadataTable,
          SurahMetadataRow,
          $$SurahMetadataTableFilterComposer,
          $$SurahMetadataTableOrderingComposer,
          $$SurahMetadataTableAnnotationComposer,
          $$SurahMetadataTableCreateCompanionBuilder,
          $$SurahMetadataTableUpdateCompanionBuilder,
          (SurahMetadataRow, $$SurahMetadataTableReferences),
          SurahMetadataRow,
          PrefetchHooks Function({
            bool masteredSurahsRefs,
            bool learningSurahsRefs,
          })
        > {
  $$SurahMetadataTableTableManager(_$AppDatabase db, $SurahMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurahMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurahMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurahMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<String> officialName = const Value.absent(),
                Value<int> ayahCount = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurahMetadataCompanion(
                id: id,
                surahNumber: surahNumber,
                officialName: officialName,
                ayahCount: ayahCount,
                sourceId: sourceId,
                sourceVersion: sourceVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int surahNumber,
                required String officialName,
                required int ayahCount,
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurahMetadataCompanion.insert(
                id: id,
                surahNumber: surahNumber,
                officialName: officialName,
                ayahCount: ayahCount,
                sourceId: sourceId,
                sourceVersion: sourceVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SurahMetadataTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({masteredSurahsRefs = false, learningSurahsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (masteredSurahsRefs) db.masteredSurahs,
                    if (learningSurahsRefs) db.learningSurahs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (masteredSurahsRefs)
                        await $_getPrefetchedData<
                          SurahMetadataRow,
                          $SurahMetadataTable,
                          MasteredSurahRow
                        >(
                          currentTable: table,
                          referencedTable: $$SurahMetadataTableReferences
                              ._masteredSurahsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SurahMetadataTableReferences(
                                db,
                                table,
                                p0,
                              ).masteredSurahsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.surahId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learningSurahsRefs)
                        await $_getPrefetchedData<
                          SurahMetadataRow,
                          $SurahMetadataTable,
                          LearningSurahRow
                        >(
                          currentTable: table,
                          referencedTable: $$SurahMetadataTableReferences
                              ._learningSurahsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SurahMetadataTableReferences(
                                db,
                                table,
                                p0,
                              ).learningSurahsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.surahId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SurahMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SurahMetadataTable,
      SurahMetadataRow,
      $$SurahMetadataTableFilterComposer,
      $$SurahMetadataTableOrderingComposer,
      $$SurahMetadataTableAnnotationComposer,
      $$SurahMetadataTableCreateCompanionBuilder,
      $$SurahMetadataTableUpdateCompanionBuilder,
      (SurahMetadataRow, $$SurahMetadataTableReferences),
      SurahMetadataRow,
      PrefetchHooks Function({bool masteredSurahsRefs, bool learningSurahsRefs})
    >;
typedef $$MasteredSurahsTableCreateCompanionBuilder =
    MasteredSurahsCompanion Function({
      required String surahId,
      Value<bool> isActive,
      Value<bool> hasEnteredRotation,
      Value<int?> activationBaselineScore,
      Value<int> cachedRotationScore,
      Value<int> cachedTotalRecitations,
      Value<DateTime?> cachedLastUsedAtUtc,
      Value<String?> alias,
      Value<int> displayOrder,
      Value<int> rowid,
    });
typedef $$MasteredSurahsTableUpdateCompanionBuilder =
    MasteredSurahsCompanion Function({
      Value<String> surahId,
      Value<bool> isActive,
      Value<bool> hasEnteredRotation,
      Value<int?> activationBaselineScore,
      Value<int> cachedRotationScore,
      Value<int> cachedTotalRecitations,
      Value<DateTime?> cachedLastUsedAtUtc,
      Value<String?> alias,
      Value<int> displayOrder,
      Value<int> rowid,
    });

final class $$MasteredSurahsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MasteredSurahsTable, MasteredSurahRow> {
  $$MasteredSurahsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SurahMetadataTable _surahIdTable(_$AppDatabase db) => db.surahMetadata
      .createAlias('mastered_surahs__surah_id__surah_metadata__id');

  $$SurahMetadataTableProcessedTableManager get surahId {
    final $_column = $_itemColumn<String>('surah_id')!;

    final manager = $$SurahMetadataTableTableManager(
      $_db,
      $_db.surahMetadata,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_surahIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MasteredSurahsTableFilterComposer
    extends Composer<_$AppDatabase, $MasteredSurahsTable> {
  $$MasteredSurahsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasEnteredRotation => $composableBuilder(
    column: $table.hasEnteredRotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activationBaselineScore => $composableBuilder(
    column: $table.activationBaselineScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedRotationScore => $composableBuilder(
    column: $table.cachedRotationScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedTotalRecitations => $composableBuilder(
    column: $table.cachedTotalRecitations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$SurahMetadataTableFilterComposer get surahId {
    final $$SurahMetadataTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableFilterComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MasteredSurahsTableOrderingComposer
    extends Composer<_$AppDatabase, $MasteredSurahsTable> {
  $$MasteredSurahsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasEnteredRotation => $composableBuilder(
    column: $table.hasEnteredRotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activationBaselineScore => $composableBuilder(
    column: $table.activationBaselineScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedRotationScore => $composableBuilder(
    column: $table.cachedRotationScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedTotalRecitations => $composableBuilder(
    column: $table.cachedTotalRecitations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$SurahMetadataTableOrderingComposer get surahId {
    final $$SurahMetadataTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableOrderingComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MasteredSurahsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MasteredSurahsTable> {
  $$MasteredSurahsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get hasEnteredRotation => $composableBuilder(
    column: $table.hasEnteredRotation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activationBaselineScore => $composableBuilder(
    column: $table.activationBaselineScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedRotationScore => $composableBuilder(
    column: $table.cachedRotationScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedTotalRecitations => $composableBuilder(
    column: $table.cachedTotalRecitations,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  $$SurahMetadataTableAnnotationComposer get surahId {
    final $$SurahMetadataTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableAnnotationComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MasteredSurahsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MasteredSurahsTable,
          MasteredSurahRow,
          $$MasteredSurahsTableFilterComposer,
          $$MasteredSurahsTableOrderingComposer,
          $$MasteredSurahsTableAnnotationComposer,
          $$MasteredSurahsTableCreateCompanionBuilder,
          $$MasteredSurahsTableUpdateCompanionBuilder,
          (MasteredSurahRow, $$MasteredSurahsTableReferences),
          MasteredSurahRow,
          PrefetchHooks Function({bool surahId})
        > {
  $$MasteredSurahsTableTableManager(
    _$AppDatabase db,
    $MasteredSurahsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasteredSurahsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MasteredSurahsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MasteredSurahsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> surahId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> hasEnteredRotation = const Value.absent(),
                Value<int?> activationBaselineScore = const Value.absent(),
                Value<int> cachedRotationScore = const Value.absent(),
                Value<int> cachedTotalRecitations = const Value.absent(),
                Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MasteredSurahsCompanion(
                surahId: surahId,
                isActive: isActive,
                hasEnteredRotation: hasEnteredRotation,
                activationBaselineScore: activationBaselineScore,
                cachedRotationScore: cachedRotationScore,
                cachedTotalRecitations: cachedTotalRecitations,
                cachedLastUsedAtUtc: cachedLastUsedAtUtc,
                alias: alias,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String surahId,
                Value<bool> isActive = const Value.absent(),
                Value<bool> hasEnteredRotation = const Value.absent(),
                Value<int?> activationBaselineScore = const Value.absent(),
                Value<int> cachedRotationScore = const Value.absent(),
                Value<int> cachedTotalRecitations = const Value.absent(),
                Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
                Value<String?> alias = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MasteredSurahsCompanion.insert(
                surahId: surahId,
                isActive: isActive,
                hasEnteredRotation: hasEnteredRotation,
                activationBaselineScore: activationBaselineScore,
                cachedRotationScore: cachedRotationScore,
                cachedTotalRecitations: cachedTotalRecitations,
                cachedLastUsedAtUtc: cachedLastUsedAtUtc,
                alias: alias,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MasteredSurahsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({surahId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (surahId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.surahId,
                                referencedTable: $$MasteredSurahsTableReferences
                                    ._surahIdTable(db),
                                referencedColumn:
                                    $$MasteredSurahsTableReferences
                                        ._surahIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MasteredSurahsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MasteredSurahsTable,
      MasteredSurahRow,
      $$MasteredSurahsTableFilterComposer,
      $$MasteredSurahsTableOrderingComposer,
      $$MasteredSurahsTableAnnotationComposer,
      $$MasteredSurahsTableCreateCompanionBuilder,
      $$MasteredSurahsTableUpdateCompanionBuilder,
      (MasteredSurahRow, $$MasteredSurahsTableReferences),
      MasteredSurahRow,
      PrefetchHooks Function({bool surahId})
    >;
typedef $$RotationStatesTableCreateCompanionBuilder =
    RotationStatesCompanion Function({
      Value<int> singletonId,
      Value<int> rotationTarget,
      Value<int> lastJournalSequence,
      Value<int> projectionVersion,
    });
typedef $$RotationStatesTableUpdateCompanionBuilder =
    RotationStatesCompanion Function({
      Value<int> singletonId,
      Value<int> rotationTarget,
      Value<int> lastJournalSequence,
      Value<int> projectionVersion,
    });

class $$RotationStatesTableFilterComposer
    extends Composer<_$AppDatabase, $RotationStatesTable> {
  $$RotationStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotationTarget => $composableBuilder(
    column: $table.rotationTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastJournalSequence => $composableBuilder(
    column: $table.lastJournalSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RotationStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $RotationStatesTable> {
  $$RotationStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotationTarget => $composableBuilder(
    column: $table.rotationTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastJournalSequence => $composableBuilder(
    column: $table.lastJournalSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RotationStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RotationStatesTable> {
  $$RotationStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rotationTarget => $composableBuilder(
    column: $table.rotationTarget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastJournalSequence => $composableBuilder(
    column: $table.lastJournalSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => column,
  );
}

class $$RotationStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RotationStatesTable,
          RotationStateRow,
          $$RotationStatesTableFilterComposer,
          $$RotationStatesTableOrderingComposer,
          $$RotationStatesTableAnnotationComposer,
          $$RotationStatesTableCreateCompanionBuilder,
          $$RotationStatesTableUpdateCompanionBuilder,
          (
            RotationStateRow,
            BaseReferences<
              _$AppDatabase,
              $RotationStatesTable,
              RotationStateRow
            >,
          ),
          RotationStateRow,
          PrefetchHooks Function()
        > {
  $$RotationStatesTableTableManager(
    _$AppDatabase db,
    $RotationStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RotationStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RotationStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RotationStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> rotationTarget = const Value.absent(),
                Value<int> lastJournalSequence = const Value.absent(),
                Value<int> projectionVersion = const Value.absent(),
              }) => RotationStatesCompanion(
                singletonId: singletonId,
                rotationTarget: rotationTarget,
                lastJournalSequence: lastJournalSequence,
                projectionVersion: projectionVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> rotationTarget = const Value.absent(),
                Value<int> lastJournalSequence = const Value.absent(),
                Value<int> projectionVersion = const Value.absent(),
              }) => RotationStatesCompanion.insert(
                singletonId: singletonId,
                rotationTarget: rotationTarget,
                lastJournalSequence: lastJournalSequence,
                projectionVersion: projectionVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RotationStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RotationStatesTable,
      RotationStateRow,
      $$RotationStatesTableFilterComposer,
      $$RotationStatesTableOrderingComposer,
      $$RotationStatesTableAnnotationComposer,
      $$RotationStatesTableCreateCompanionBuilder,
      $$RotationStatesTableUpdateCompanionBuilder,
      (
        RotationStateRow,
        BaseReferences<_$AppDatabase, $RotationStatesTable, RotationStateRow>,
      ),
      RotationStateRow,
      PrefetchHooks Function()
    >;
typedef $$RotationSchemesTableCreateCompanionBuilder =
    RotationSchemesCompanion Function({
      required String id,
      required String surahId,
      required int version,
      required int ayahCountSnapshot,
      required int baselineScore,
      required int baselineTotalRecitations,
      Value<DateTime?> baselineLastUsedAtUtc,
      required int activatedJournalSequence,
      Value<int?> supersededJournalSequence,
      Value<int> rowid,
    });
typedef $$RotationSchemesTableUpdateCompanionBuilder =
    RotationSchemesCompanion Function({
      Value<String> id,
      Value<String> surahId,
      Value<int> version,
      Value<int> ayahCountSnapshot,
      Value<int> baselineScore,
      Value<int> baselineTotalRecitations,
      Value<DateTime?> baselineLastUsedAtUtc,
      Value<int> activatedJournalSequence,
      Value<int?> supersededJournalSequence,
      Value<int> rowid,
    });

final class $$RotationSchemesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RotationSchemesTable,
          RotationSchemeRow
        > {
  $$RotationSchemesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$RotationPartsTable, List<RotationPartRow>>
  _rotationPartsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.rotationParts,
    aliasName: 'rotation_schemes__id__rotation_parts__scheme_id',
  );

  $$RotationPartsTableProcessedTableManager get rotationPartsRefs {
    final manager = $$RotationPartsTableTableManager(
      $_db,
      $_db.rotationParts,
    ).filter((f) => f.schemeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rotationPartsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RotationSchemesTableFilterComposer
    extends Composer<_$AppDatabase, $RotationSchemesTable> {
  $$RotationSchemesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahCountSnapshot => $composableBuilder(
    column: $table.ayahCountSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baselineScore => $composableBuilder(
    column: $table.baselineScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baselineTotalRecitations => $composableBuilder(
    column: $table.baselineTotalRecitations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get baselineLastUsedAtUtc => $composableBuilder(
    column: $table.baselineLastUsedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activatedJournalSequence => $composableBuilder(
    column: $table.activatedJournalSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get supersededJournalSequence => $composableBuilder(
    column: $table.supersededJournalSequence,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> rotationPartsRefs(
    Expression<bool> Function($$RotationPartsTableFilterComposer f) f,
  ) {
    final $$RotationPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotationParts,
      getReferencedColumn: (t) => t.schemeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationPartsTableFilterComposer(
            $db: $db,
            $table: $db.rotationParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RotationSchemesTableOrderingComposer
    extends Composer<_$AppDatabase, $RotationSchemesTable> {
  $$RotationSchemesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahCountSnapshot => $composableBuilder(
    column: $table.ayahCountSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baselineScore => $composableBuilder(
    column: $table.baselineScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baselineTotalRecitations => $composableBuilder(
    column: $table.baselineTotalRecitations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get baselineLastUsedAtUtc => $composableBuilder(
    column: $table.baselineLastUsedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activatedJournalSequence => $composableBuilder(
    column: $table.activatedJournalSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get supersededJournalSequence => $composableBuilder(
    column: $table.supersededJournalSequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RotationSchemesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RotationSchemesTable> {
  $$RotationSchemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get ayahCountSnapshot => $composableBuilder(
    column: $table.ayahCountSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baselineScore => $composableBuilder(
    column: $table.baselineScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baselineTotalRecitations => $composableBuilder(
    column: $table.baselineTotalRecitations,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get baselineLastUsedAtUtc => $composableBuilder(
    column: $table.baselineLastUsedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activatedJournalSequence => $composableBuilder(
    column: $table.activatedJournalSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get supersededJournalSequence => $composableBuilder(
    column: $table.supersededJournalSequence,
    builder: (column) => column,
  );

  Expression<T> rotationPartsRefs<T extends Object>(
    Expression<T> Function($$RotationPartsTableAnnotationComposer a) f,
  ) {
    final $$RotationPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rotationParts,
      getReferencedColumn: (t) => t.schemeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.rotationParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RotationSchemesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RotationSchemesTable,
          RotationSchemeRow,
          $$RotationSchemesTableFilterComposer,
          $$RotationSchemesTableOrderingComposer,
          $$RotationSchemesTableAnnotationComposer,
          $$RotationSchemesTableCreateCompanionBuilder,
          $$RotationSchemesTableUpdateCompanionBuilder,
          (RotationSchemeRow, $$RotationSchemesTableReferences),
          RotationSchemeRow,
          PrefetchHooks Function({bool rotationPartsRefs})
        > {
  $$RotationSchemesTableTableManager(
    _$AppDatabase db,
    $RotationSchemesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RotationSchemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RotationSchemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RotationSchemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> surahId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> ayahCountSnapshot = const Value.absent(),
                Value<int> baselineScore = const Value.absent(),
                Value<int> baselineTotalRecitations = const Value.absent(),
                Value<DateTime?> baselineLastUsedAtUtc = const Value.absent(),
                Value<int> activatedJournalSequence = const Value.absent(),
                Value<int?> supersededJournalSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationSchemesCompanion(
                id: id,
                surahId: surahId,
                version: version,
                ayahCountSnapshot: ayahCountSnapshot,
                baselineScore: baselineScore,
                baselineTotalRecitations: baselineTotalRecitations,
                baselineLastUsedAtUtc: baselineLastUsedAtUtc,
                activatedJournalSequence: activatedJournalSequence,
                supersededJournalSequence: supersededJournalSequence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String surahId,
                required int version,
                required int ayahCountSnapshot,
                required int baselineScore,
                required int baselineTotalRecitations,
                Value<DateTime?> baselineLastUsedAtUtc = const Value.absent(),
                required int activatedJournalSequence,
                Value<int?> supersededJournalSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationSchemesCompanion.insert(
                id: id,
                surahId: surahId,
                version: version,
                ayahCountSnapshot: ayahCountSnapshot,
                baselineScore: baselineScore,
                baselineTotalRecitations: baselineTotalRecitations,
                baselineLastUsedAtUtc: baselineLastUsedAtUtc,
                activatedJournalSequence: activatedJournalSequence,
                supersededJournalSequence: supersededJournalSequence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RotationSchemesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rotationPartsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (rotationPartsRefs) db.rotationParts,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rotationPartsRefs)
                    await $_getPrefetchedData<
                      RotationSchemeRow,
                      $RotationSchemesTable,
                      RotationPartRow
                    >(
                      currentTable: table,
                      referencedTable: $$RotationSchemesTableReferences
                          ._rotationPartsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RotationSchemesTableReferences(
                            db,
                            table,
                            p0,
                          ).rotationPartsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.schemeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RotationSchemesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RotationSchemesTable,
      RotationSchemeRow,
      $$RotationSchemesTableFilterComposer,
      $$RotationSchemesTableOrderingComposer,
      $$RotationSchemesTableAnnotationComposer,
      $$RotationSchemesTableCreateCompanionBuilder,
      $$RotationSchemesTableUpdateCompanionBuilder,
      (RotationSchemeRow, $$RotationSchemesTableReferences),
      RotationSchemeRow,
      PrefetchHooks Function({bool rotationPartsRefs})
    >;
typedef $$RotationPartsTableCreateCompanionBuilder =
    RotationPartsCompanion Function({
      required String id,
      required String schemeId,
      required int ordinal,
      required int startAyah,
      required int endAyah,
      required int cachedScore,
      required int cachedRecitationCount,
      Value<DateTime?> cachedLastUsedAtUtc,
      Value<int> rowid,
    });
typedef $$RotationPartsTableUpdateCompanionBuilder =
    RotationPartsCompanion Function({
      Value<String> id,
      Value<String> schemeId,
      Value<int> ordinal,
      Value<int> startAyah,
      Value<int> endAyah,
      Value<int> cachedScore,
      Value<int> cachedRecitationCount,
      Value<DateTime?> cachedLastUsedAtUtc,
      Value<int> rowid,
    });

final class $$RotationPartsTableReferences
    extends
        BaseReferences<_$AppDatabase, $RotationPartsTable, RotationPartRow> {
  $$RotationPartsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RotationSchemesTable _schemeIdTable(_$AppDatabase db) => db
      .rotationSchemes
      .createAlias('rotation_parts__scheme_id__rotation_schemes__id');

  $$RotationSchemesTableProcessedTableManager get schemeId {
    final $_column = $_itemColumn<String>('scheme_id')!;

    final manager = $$RotationSchemesTableTableManager(
      $_db,
      $_db.rotationSchemes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_schemeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RotationPartsTableFilterComposer
    extends Composer<_$AppDatabase, $RotationPartsTable> {
  $$RotationPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAyah => $composableBuilder(
    column: $table.startAyah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endAyah => $composableBuilder(
    column: $table.endAyah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedScore => $composableBuilder(
    column: $table.cachedScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedRecitationCount => $composableBuilder(
    column: $table.cachedRecitationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$RotationSchemesTableFilterComposer get schemeId {
    final $$RotationSchemesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.schemeId,
      referencedTable: $db.rotationSchemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationSchemesTableFilterComposer(
            $db: $db,
            $table: $db.rotationSchemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RotationPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $RotationPartsTable> {
  $$RotationPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAyah => $composableBuilder(
    column: $table.startAyah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endAyah => $composableBuilder(
    column: $table.endAyah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedScore => $composableBuilder(
    column: $table.cachedScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedRecitationCount => $composableBuilder(
    column: $table.cachedRecitationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$RotationSchemesTableOrderingComposer get schemeId {
    final $$RotationSchemesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.schemeId,
      referencedTable: $db.rotationSchemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationSchemesTableOrderingComposer(
            $db: $db,
            $table: $db.rotationSchemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RotationPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RotationPartsTable> {
  $$RotationPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get startAyah =>
      $composableBuilder(column: $table.startAyah, builder: (column) => column);

  GeneratedColumn<int> get endAyah =>
      $composableBuilder(column: $table.endAyah, builder: (column) => column);

  GeneratedColumn<int> get cachedScore => $composableBuilder(
    column: $table.cachedScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedRecitationCount => $composableBuilder(
    column: $table.cachedRecitationCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedLastUsedAtUtc => $composableBuilder(
    column: $table.cachedLastUsedAtUtc,
    builder: (column) => column,
  );

  $$RotationSchemesTableAnnotationComposer get schemeId {
    final $$RotationSchemesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.schemeId,
      referencedTable: $db.rotationSchemes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RotationSchemesTableAnnotationComposer(
            $db: $db,
            $table: $db.rotationSchemes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RotationPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RotationPartsTable,
          RotationPartRow,
          $$RotationPartsTableFilterComposer,
          $$RotationPartsTableOrderingComposer,
          $$RotationPartsTableAnnotationComposer,
          $$RotationPartsTableCreateCompanionBuilder,
          $$RotationPartsTableUpdateCompanionBuilder,
          (RotationPartRow, $$RotationPartsTableReferences),
          RotationPartRow,
          PrefetchHooks Function({bool schemeId})
        > {
  $$RotationPartsTableTableManager(_$AppDatabase db, $RotationPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RotationPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RotationPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RotationPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> schemeId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> startAyah = const Value.absent(),
                Value<int> endAyah = const Value.absent(),
                Value<int> cachedScore = const Value.absent(),
                Value<int> cachedRecitationCount = const Value.absent(),
                Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationPartsCompanion(
                id: id,
                schemeId: schemeId,
                ordinal: ordinal,
                startAyah: startAyah,
                endAyah: endAyah,
                cachedScore: cachedScore,
                cachedRecitationCount: cachedRecitationCount,
                cachedLastUsedAtUtc: cachedLastUsedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String schemeId,
                required int ordinal,
                required int startAyah,
                required int endAyah,
                required int cachedScore,
                required int cachedRecitationCount,
                Value<DateTime?> cachedLastUsedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationPartsCompanion.insert(
                id: id,
                schemeId: schemeId,
                ordinal: ordinal,
                startAyah: startAyah,
                endAyah: endAyah,
                cachedScore: cachedScore,
                cachedRecitationCount: cachedRecitationCount,
                cachedLastUsedAtUtc: cachedLastUsedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RotationPartsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({schemeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (schemeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.schemeId,
                                referencedTable: $$RotationPartsTableReferences
                                    ._schemeIdTable(db),
                                referencedColumn: $$RotationPartsTableReferences
                                    ._schemeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RotationPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RotationPartsTable,
      RotationPartRow,
      $$RotationPartsTableFilterComposer,
      $$RotationPartsTableOrderingComposer,
      $$RotationPartsTableAnnotationComposer,
      $$RotationPartsTableCreateCompanionBuilder,
      $$RotationPartsTableUpdateCompanionBuilder,
      (RotationPartRow, $$RotationPartsTableReferences),
      RotationPartRow,
      PrefetchHooks Function({bool schemeId})
    >;
typedef $$PrayerSessionsTableCreateCompanionBuilder =
    PrayerSessionsCompanion Function({
      required String id,
      required String prayerType,
      Value<bool> isQada,
      required DateTime startedAtUtc,
      Value<String?> localDate,
      Value<int> rowid,
    });
typedef $$PrayerSessionsTableUpdateCompanionBuilder =
    PrayerSessionsCompanion Function({
      Value<String> id,
      Value<String> prayerType,
      Value<bool> isQada,
      Value<DateTime> startedAtUtc,
      Value<String?> localDate,
      Value<int> rowid,
    });

final class $$PrayerSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PrayerSessionsTable, PrayerSessionRow> {
  $$PrayerSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$RecitationEventsTable, List<RecitationEventRow>>
  _recitationEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recitationEvents,
    aliasName: 'prayer_sessions__id__recitation_events__prayer_session_id',
  );

  $$RecitationEventsTableProcessedTableManager get recitationEventsRefs {
    final manager =
        $$RecitationEventsTableTableManager($_db, $_db.recitationEvents).filter(
          (f) => f.prayerSessionId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _recitationEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PrayerSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PrayerSessionsTable> {
  $$PrayerSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isQada => $composableBuilder(
    column: $table.isQada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recitationEventsRefs(
    Expression<bool> Function($$RecitationEventsTableFilterComposer f) f,
  ) {
    final $$RecitationEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recitationEvents,
      getReferencedColumn: (t) => t.prayerSessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecitationEventsTableFilterComposer(
            $db: $db,
            $table: $db.recitationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PrayerSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrayerSessionsTable> {
  $$PrayerSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isQada => $composableBuilder(
    column: $table.isQada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrayerSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrayerSessionsTable> {
  $$PrayerSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isQada =>
      $composableBuilder(column: $table.isQada, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  Expression<T> recitationEventsRefs<T extends Object>(
    Expression<T> Function($$RecitationEventsTableAnnotationComposer a) f,
  ) {
    final $$RecitationEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recitationEvents,
      getReferencedColumn: (t) => t.prayerSessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecitationEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.recitationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PrayerSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrayerSessionsTable,
          PrayerSessionRow,
          $$PrayerSessionsTableFilterComposer,
          $$PrayerSessionsTableOrderingComposer,
          $$PrayerSessionsTableAnnotationComposer,
          $$PrayerSessionsTableCreateCompanionBuilder,
          $$PrayerSessionsTableUpdateCompanionBuilder,
          (PrayerSessionRow, $$PrayerSessionsTableReferences),
          PrayerSessionRow,
          PrefetchHooks Function({bool recitationEventsRefs})
        > {
  $$PrayerSessionsTableTableManager(
    _$AppDatabase db,
    $PrayerSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrayerSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrayerSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrayerSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> prayerType = const Value.absent(),
                Value<bool> isQada = const Value.absent(),
                Value<DateTime> startedAtUtc = const Value.absent(),
                Value<String?> localDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrayerSessionsCompanion(
                id: id,
                prayerType: prayerType,
                isQada: isQada,
                startedAtUtc: startedAtUtc,
                localDate: localDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String prayerType,
                Value<bool> isQada = const Value.absent(),
                required DateTime startedAtUtc,
                Value<String?> localDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrayerSessionsCompanion.insert(
                id: id,
                prayerType: prayerType,
                isQada: isQada,
                startedAtUtc: startedAtUtc,
                localDate: localDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrayerSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recitationEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (recitationEventsRefs) db.recitationEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recitationEventsRefs)
                    await $_getPrefetchedData<
                      PrayerSessionRow,
                      $PrayerSessionsTable,
                      RecitationEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$PrayerSessionsTableReferences
                          ._recitationEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PrayerSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).recitationEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.prayerSessionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PrayerSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrayerSessionsTable,
      PrayerSessionRow,
      $$PrayerSessionsTableFilterComposer,
      $$PrayerSessionsTableOrderingComposer,
      $$PrayerSessionsTableAnnotationComposer,
      $$PrayerSessionsTableCreateCompanionBuilder,
      $$PrayerSessionsTableUpdateCompanionBuilder,
      (PrayerSessionRow, $$PrayerSessionsTableReferences),
      PrayerSessionRow,
      PrefetchHooks Function({bool recitationEventsRefs})
    >;
typedef $$RecitationEventsTableCreateCompanionBuilder =
    RecitationEventsCompanion Function({
      required String id,
      required int journalSequence,
      required String surahId,
      required String rotationSchemeId,
      required int rakaatSpanCount,
      Value<String?> prayerSessionId,
      required DateTime createdAtUtc,
      required String localDate,
      required String prayerType,
      Value<bool> isQada,
      Value<DateTime?> deletedAtUtc,
      Value<int> rowid,
    });
typedef $$RecitationEventsTableUpdateCompanionBuilder =
    RecitationEventsCompanion Function({
      Value<String> id,
      Value<int> journalSequence,
      Value<String> surahId,
      Value<String> rotationSchemeId,
      Value<int> rakaatSpanCount,
      Value<String?> prayerSessionId,
      Value<DateTime> createdAtUtc,
      Value<String> localDate,
      Value<String> prayerType,
      Value<bool> isQada,
      Value<DateTime?> deletedAtUtc,
      Value<int> rowid,
    });

final class $$RecitationEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecitationEventsTable,
          RecitationEventRow
        > {
  $$RecitationEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PrayerSessionsTable _prayerSessionIdTable(_$AppDatabase db) => db
      .prayerSessions
      .createAlias('recitation_events__prayer_session_id__prayer_sessions__id');

  $$PrayerSessionsTableProcessedTableManager? get prayerSessionId {
    final $_column = $_itemColumn<String>('prayer_session_id');
    if ($_column == null) return null;
    final manager = $$PrayerSessionsTableTableManager(
      $_db,
      $_db.prayerSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prayerSessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecitationEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RecitationEventsTable> {
  $$RecitationEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rakaatSpanCount => $composableBuilder(
    column: $table.rakaatSpanCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isQada => $composableBuilder(
    column: $table.isQada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$PrayerSessionsTableFilterComposer get prayerSessionId {
    final $$PrayerSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prayerSessionId,
      referencedTable: $db.prayerSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrayerSessionsTableFilterComposer(
            $db: $db,
            $table: $db.prayerSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecitationEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecitationEventsTable> {
  $$RecitationEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rakaatSpanCount => $composableBuilder(
    column: $table.rakaatSpanCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isQada => $composableBuilder(
    column: $table.isQada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$PrayerSessionsTableOrderingComposer get prayerSessionId {
    final $$PrayerSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prayerSessionId,
      referencedTable: $db.prayerSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrayerSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.prayerSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecitationEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecitationEventsTable> {
  $$RecitationEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rakaatSpanCount => $composableBuilder(
    column: $table.rakaatSpanCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
    column: $table.prayerType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isQada =>
      $composableBuilder(column: $table.isQada, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  $$PrayerSessionsTableAnnotationComposer get prayerSessionId {
    final $$PrayerSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prayerSessionId,
      referencedTable: $db.prayerSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrayerSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.prayerSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecitationEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecitationEventsTable,
          RecitationEventRow,
          $$RecitationEventsTableFilterComposer,
          $$RecitationEventsTableOrderingComposer,
          $$RecitationEventsTableAnnotationComposer,
          $$RecitationEventsTableCreateCompanionBuilder,
          $$RecitationEventsTableUpdateCompanionBuilder,
          (RecitationEventRow, $$RecitationEventsTableReferences),
          RecitationEventRow,
          PrefetchHooks Function({bool prayerSessionId})
        > {
  $$RecitationEventsTableTableManager(
    _$AppDatabase db,
    $RecitationEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecitationEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecitationEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecitationEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> journalSequence = const Value.absent(),
                Value<String> surahId = const Value.absent(),
                Value<String> rotationSchemeId = const Value.absent(),
                Value<int> rakaatSpanCount = const Value.absent(),
                Value<String?> prayerSessionId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<String> prayerType = const Value.absent(),
                Value<bool> isQada = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecitationEventsCompanion(
                id: id,
                journalSequence: journalSequence,
                surahId: surahId,
                rotationSchemeId: rotationSchemeId,
                rakaatSpanCount: rakaatSpanCount,
                prayerSessionId: prayerSessionId,
                createdAtUtc: createdAtUtc,
                localDate: localDate,
                prayerType: prayerType,
                isQada: isQada,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int journalSequence,
                required String surahId,
                required String rotationSchemeId,
                required int rakaatSpanCount,
                Value<String?> prayerSessionId = const Value.absent(),
                required DateTime createdAtUtc,
                required String localDate,
                required String prayerType,
                Value<bool> isQada = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecitationEventsCompanion.insert(
                id: id,
                journalSequence: journalSequence,
                surahId: surahId,
                rotationSchemeId: rotationSchemeId,
                rakaatSpanCount: rakaatSpanCount,
                prayerSessionId: prayerSessionId,
                createdAtUtc: createdAtUtc,
                localDate: localDate,
                prayerType: prayerType,
                isQada: isQada,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecitationEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({prayerSessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (prayerSessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.prayerSessionId,
                                referencedTable:
                                    $$RecitationEventsTableReferences
                                        ._prayerSessionIdTable(db),
                                referencedColumn:
                                    $$RecitationEventsTableReferences
                                        ._prayerSessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecitationEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecitationEventsTable,
      RecitationEventRow,
      $$RecitationEventsTableFilterComposer,
      $$RecitationEventsTableOrderingComposer,
      $$RecitationEventsTableAnnotationComposer,
      $$RecitationEventsTableCreateCompanionBuilder,
      $$RecitationEventsTableUpdateCompanionBuilder,
      (RecitationEventRow, $$RecitationEventsTableReferences),
      RecitationEventRow,
      PrefetchHooks Function({bool prayerSessionId})
    >;
typedef $$RecitationEventPartsTableCreateCompanionBuilder =
    RecitationEventPartsCompanion Function({
      required String eventId,
      required String schemeId,
      required String partId,
      Value<int> rowid,
    });
typedef $$RecitationEventPartsTableUpdateCompanionBuilder =
    RecitationEventPartsCompanion Function({
      Value<String> eventId,
      Value<String> schemeId,
      Value<String> partId,
      Value<int> rowid,
    });

class $$RecitationEventPartsTableFilterComposer
    extends Composer<_$AppDatabase, $RecitationEventPartsTable> {
  $$RecitationEventPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemeId => $composableBuilder(
    column: $table.schemeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecitationEventPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecitationEventPartsTable> {
  $$RecitationEventPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemeId => $composableBuilder(
    column: $table.schemeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecitationEventPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecitationEventPartsTable> {
  $$RecitationEventPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get schemeId =>
      $composableBuilder(column: $table.schemeId, builder: (column) => column);

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);
}

class $$RecitationEventPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecitationEventPartsTable,
          RecitationEventPartRow,
          $$RecitationEventPartsTableFilterComposer,
          $$RecitationEventPartsTableOrderingComposer,
          $$RecitationEventPartsTableAnnotationComposer,
          $$RecitationEventPartsTableCreateCompanionBuilder,
          $$RecitationEventPartsTableUpdateCompanionBuilder,
          (
            RecitationEventPartRow,
            BaseReferences<
              _$AppDatabase,
              $RecitationEventPartsTable,
              RecitationEventPartRow
            >,
          ),
          RecitationEventPartRow,
          PrefetchHooks Function()
        > {
  $$RecitationEventPartsTableTableManager(
    _$AppDatabase db,
    $RecitationEventPartsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecitationEventPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecitationEventPartsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecitationEventPartsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> schemeId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecitationEventPartsCompanion(
                eventId: eventId,
                schemeId: schemeId,
                partId: partId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String schemeId,
                required String partId,
                Value<int> rowid = const Value.absent(),
              }) => RecitationEventPartsCompanion.insert(
                eventId: eventId,
                schemeId: schemeId,
                partId: partId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecitationEventPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecitationEventPartsTable,
      RecitationEventPartRow,
      $$RecitationEventPartsTableFilterComposer,
      $$RecitationEventPartsTableOrderingComposer,
      $$RecitationEventPartsTableAnnotationComposer,
      $$RecitationEventPartsTableCreateCompanionBuilder,
      $$RecitationEventPartsTableUpdateCompanionBuilder,
      (
        RecitationEventPartRow,
        BaseReferences<
          _$AppDatabase,
          $RecitationEventPartsTable,
          RecitationEventPartRow
        >,
      ),
      RecitationEventPartRow,
      PrefetchHooks Function()
    >;
typedef $$RotationAdjustmentsTableCreateCompanionBuilder =
    RotationAdjustmentsCompanion Function({
      required String id,
      required int journalSequence,
      required String surahId,
      required String rotationSchemeId,
      required int delta,
      required String reason,
      required DateTime createdAtUtc,
      Value<DateTime?> deletedAtUtc,
      Value<int> rowid,
    });
typedef $$RotationAdjustmentsTableUpdateCompanionBuilder =
    RotationAdjustmentsCompanion Function({
      Value<String> id,
      Value<int> journalSequence,
      Value<String> surahId,
      Value<String> rotationSchemeId,
      Value<int> delta,
      Value<String> reason,
      Value<DateTime> createdAtUtc,
      Value<DateTime?> deletedAtUtc,
      Value<int> rowid,
    });

class $$RotationAdjustmentsTableFilterComposer
    extends Composer<_$AppDatabase, $RotationAdjustmentsTable> {
  $$RotationAdjustmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RotationAdjustmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RotationAdjustmentsTable> {
  $$RotationAdjustmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RotationAdjustmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RotationAdjustmentsTable> {
  $$RotationAdjustmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get journalSequence => $composableBuilder(
    column: $table.journalSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rotationSchemeId => $composableBuilder(
    column: $table.rotationSchemeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );
}

class $$RotationAdjustmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RotationAdjustmentsTable,
          RotationAdjustmentRow,
          $$RotationAdjustmentsTableFilterComposer,
          $$RotationAdjustmentsTableOrderingComposer,
          $$RotationAdjustmentsTableAnnotationComposer,
          $$RotationAdjustmentsTableCreateCompanionBuilder,
          $$RotationAdjustmentsTableUpdateCompanionBuilder,
          (
            RotationAdjustmentRow,
            BaseReferences<
              _$AppDatabase,
              $RotationAdjustmentsTable,
              RotationAdjustmentRow
            >,
          ),
          RotationAdjustmentRow,
          PrefetchHooks Function()
        > {
  $$RotationAdjustmentsTableTableManager(
    _$AppDatabase db,
    $RotationAdjustmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RotationAdjustmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RotationAdjustmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RotationAdjustmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> journalSequence = const Value.absent(),
                Value<String> surahId = const Value.absent(),
                Value<String> rotationSchemeId = const Value.absent(),
                Value<int> delta = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationAdjustmentsCompanion(
                id: id,
                journalSequence: journalSequence,
                surahId: surahId,
                rotationSchemeId: rotationSchemeId,
                delta: delta,
                reason: reason,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int journalSequence,
                required String surahId,
                required String rotationSchemeId,
                required int delta,
                required String reason,
                required DateTime createdAtUtc,
                Value<DateTime?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RotationAdjustmentsCompanion.insert(
                id: id,
                journalSequence: journalSequence,
                surahId: surahId,
                rotationSchemeId: rotationSchemeId,
                delta: delta,
                reason: reason,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RotationAdjustmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RotationAdjustmentsTable,
      RotationAdjustmentRow,
      $$RotationAdjustmentsTableFilterComposer,
      $$RotationAdjustmentsTableOrderingComposer,
      $$RotationAdjustmentsTableAnnotationComposer,
      $$RotationAdjustmentsTableCreateCompanionBuilder,
      $$RotationAdjustmentsTableUpdateCompanionBuilder,
      (
        RotationAdjustmentRow,
        BaseReferences<
          _$AppDatabase,
          $RotationAdjustmentsTable,
          RotationAdjustmentRow
        >,
      ),
      RotationAdjustmentRow,
      PrefetchHooks Function()
    >;
typedef $$LearningSurahsTableCreateCompanionBuilder =
    LearningSurahsCompanion Function({
      required String id,
      required String surahId,
      required int ayahCount,
      required String stageKind,
      required int stageEndAyah,
      required String status,
      Value<DateTime?> lastLearningActivityAtUtc,
      Value<DateTime?> inactivityRollbackForActivityAtUtc,
      Value<int> rowid,
    });
typedef $$LearningSurahsTableUpdateCompanionBuilder =
    LearningSurahsCompanion Function({
      Value<String> id,
      Value<String> surahId,
      Value<int> ayahCount,
      Value<String> stageKind,
      Value<int> stageEndAyah,
      Value<String> status,
      Value<DateTime?> lastLearningActivityAtUtc,
      Value<DateTime?> inactivityRollbackForActivityAtUtc,
      Value<int> rowid,
    });

final class $$LearningSurahsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LearningSurahsTable, LearningSurahRow> {
  $$LearningSurahsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SurahMetadataTable _surahIdTable(_$AppDatabase db) => db.surahMetadata
      .createAlias('learning_surahs__surah_id__surah_metadata__id');

  $$SurahMetadataTableProcessedTableManager get surahId {
    final $_column = $_itemColumn<String>('surah_id')!;

    final manager = $$SurahMetadataTableTableManager(
      $_db,
      $_db.surahMetadata,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_surahIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LearningEventsTable, List<LearningEventRow>>
  _learningEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.learningEvents,
    aliasName: 'learning_surahs__id__learning_events__learning_surah_id',
  );

  $$LearningEventsTableProcessedTableManager get learningEventsRefs {
    final manager = $$LearningEventsTableTableManager($_db, $_db.learningEvents)
        .filter(
          (f) => f.learningSurahId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_learningEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LearningSurahsTableFilterComposer
    extends Composer<_$AppDatabase, $LearningSurahsTable> {
  $$LearningSurahsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stageKind => $composableBuilder(
    column: $table.stageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageEndAyah => $composableBuilder(
    column: $table.stageEndAyah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLearningActivityAtUtc => $composableBuilder(
    column: $table.lastLearningActivityAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inactivityRollbackForActivityAtUtc =>
      $composableBuilder(
        column: $table.inactivityRollbackForActivityAtUtc,
        builder: (column) => ColumnFilters(column),
      );

  $$SurahMetadataTableFilterComposer get surahId {
    final $$SurahMetadataTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableFilterComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> learningEventsRefs(
    Expression<bool> Function($$LearningEventsTableFilterComposer f) f,
  ) {
    final $$LearningEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningEvents,
      getReferencedColumn: (t) => t.learningSurahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningEventsTableFilterComposer(
            $db: $db,
            $table: $db.learningEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearningSurahsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningSurahsTable> {
  $$LearningSurahsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahCount => $composableBuilder(
    column: $table.ayahCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stageKind => $composableBuilder(
    column: $table.stageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageEndAyah => $composableBuilder(
    column: $table.stageEndAyah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLearningActivityAtUtc => $composableBuilder(
    column: $table.lastLearningActivityAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inactivityRollbackForActivityAtUtc =>
      $composableBuilder(
        column: $table.inactivityRollbackForActivityAtUtc,
        builder: (column) => ColumnOrderings(column),
      );

  $$SurahMetadataTableOrderingComposer get surahId {
    final $$SurahMetadataTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableOrderingComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningSurahsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningSurahsTable> {
  $$LearningSurahsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ayahCount =>
      $composableBuilder(column: $table.ayahCount, builder: (column) => column);

  GeneratedColumn<String> get stageKind =>
      $composableBuilder(column: $table.stageKind, builder: (column) => column);

  GeneratedColumn<int> get stageEndAyah => $composableBuilder(
    column: $table.stageEndAyah,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLearningActivityAtUtc => $composableBuilder(
    column: $table.lastLearningActivityAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get inactivityRollbackForActivityAtUtc =>
      $composableBuilder(
        column: $table.inactivityRollbackForActivityAtUtc,
        builder: (column) => column,
      );

  $$SurahMetadataTableAnnotationComposer get surahId {
    final $$SurahMetadataTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surahId,
      referencedTable: $db.surahMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurahMetadataTableAnnotationComposer(
            $db: $db,
            $table: $db.surahMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> learningEventsRefs<T extends Object>(
    Expression<T> Function($$LearningEventsTableAnnotationComposer a) f,
  ) {
    final $$LearningEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learningEvents,
      getReferencedColumn: (t) => t.learningSurahId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LearningSurahsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningSurahsTable,
          LearningSurahRow,
          $$LearningSurahsTableFilterComposer,
          $$LearningSurahsTableOrderingComposer,
          $$LearningSurahsTableAnnotationComposer,
          $$LearningSurahsTableCreateCompanionBuilder,
          $$LearningSurahsTableUpdateCompanionBuilder,
          (LearningSurahRow, $$LearningSurahsTableReferences),
          LearningSurahRow,
          PrefetchHooks Function({bool surahId, bool learningEventsRefs})
        > {
  $$LearningSurahsTableTableManager(
    _$AppDatabase db,
    $LearningSurahsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningSurahsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningSurahsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningSurahsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> surahId = const Value.absent(),
                Value<int> ayahCount = const Value.absent(),
                Value<String> stageKind = const Value.absent(),
                Value<int> stageEndAyah = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastLearningActivityAtUtc =
                    const Value.absent(),
                Value<DateTime?> inactivityRollbackForActivityAtUtc =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningSurahsCompanion(
                id: id,
                surahId: surahId,
                ayahCount: ayahCount,
                stageKind: stageKind,
                stageEndAyah: stageEndAyah,
                status: status,
                lastLearningActivityAtUtc: lastLearningActivityAtUtc,
                inactivityRollbackForActivityAtUtc:
                    inactivityRollbackForActivityAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String surahId,
                required int ayahCount,
                required String stageKind,
                required int stageEndAyah,
                required String status,
                Value<DateTime?> lastLearningActivityAtUtc =
                    const Value.absent(),
                Value<DateTime?> inactivityRollbackForActivityAtUtc =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningSurahsCompanion.insert(
                id: id,
                surahId: surahId,
                ayahCount: ayahCount,
                stageKind: stageKind,
                stageEndAyah: stageEndAyah,
                status: status,
                lastLearningActivityAtUtc: lastLearningActivityAtUtc,
                inactivityRollbackForActivityAtUtc:
                    inactivityRollbackForActivityAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearningSurahsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({surahId = false, learningEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (learningEventsRefs) db.learningEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (surahId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.surahId,
                                    referencedTable:
                                        $$LearningSurahsTableReferences
                                            ._surahIdTable(db),
                                    referencedColumn:
                                        $$LearningSurahsTableReferences
                                            ._surahIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (learningEventsRefs)
                        await $_getPrefetchedData<
                          LearningSurahRow,
                          $LearningSurahsTable,
                          LearningEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$LearningSurahsTableReferences
                              ._learningEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LearningSurahsTableReferences(
                                db,
                                table,
                                p0,
                              ).learningEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.learningSurahId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LearningSurahsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningSurahsTable,
      LearningSurahRow,
      $$LearningSurahsTableFilterComposer,
      $$LearningSurahsTableOrderingComposer,
      $$LearningSurahsTableAnnotationComposer,
      $$LearningSurahsTableCreateCompanionBuilder,
      $$LearningSurahsTableUpdateCompanionBuilder,
      (LearningSurahRow, $$LearningSurahsTableReferences),
      LearningSurahRow,
      PrefetchHooks Function({bool surahId, bool learningEventsRefs})
    >;
typedef $$LearningEventsTableCreateCompanionBuilder =
    LearningEventsCompanion Function({
      required String id,
      Value<int> sequence,
      required String learningSurahId,
      required String type,
      required DateTime createdAtUtc,
      required String fromStageKind,
      required int fromStageEndAyah,
      required String toStageKind,
      required int toStageEndAyah,
    });
typedef $$LearningEventsTableUpdateCompanionBuilder =
    LearningEventsCompanion Function({
      Value<String> id,
      Value<int> sequence,
      Value<String> learningSurahId,
      Value<String> type,
      Value<DateTime> createdAtUtc,
      Value<String> fromStageKind,
      Value<int> fromStageEndAyah,
      Value<String> toStageKind,
      Value<int> toStageEndAyah,
    });

final class $$LearningEventsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LearningEventsTable, LearningEventRow> {
  $$LearningEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LearningSurahsTable _learningSurahIdTable(_$AppDatabase db) => db
      .learningSurahs
      .createAlias('learning_events__learning_surah_id__learning_surahs__id');

  $$LearningSurahsTableProcessedTableManager get learningSurahId {
    final $_column = $_itemColumn<String>('learning_surah_id')!;

    final manager = $$LearningSurahsTableTableManager(
      $_db,
      $_db.learningSurahs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_learningSurahIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearningEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStageKind => $composableBuilder(
    column: $table.fromStageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromStageEndAyah => $composableBuilder(
    column: $table.fromStageEndAyah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStageKind => $composableBuilder(
    column: $table.toStageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toStageEndAyah => $composableBuilder(
    column: $table.toStageEndAyah,
    builder: (column) => ColumnFilters(column),
  );

  $$LearningSurahsTableFilterComposer get learningSurahId {
    final $$LearningSurahsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.learningSurahId,
      referencedTable: $db.learningSurahs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSurahsTableFilterComposer(
            $db: $db,
            $table: $db.learningSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStageKind => $composableBuilder(
    column: $table.fromStageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromStageEndAyah => $composableBuilder(
    column: $table.fromStageEndAyah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStageKind => $composableBuilder(
    column: $table.toStageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toStageEndAyah => $composableBuilder(
    column: $table.toStageEndAyah,
    builder: (column) => ColumnOrderings(column),
  );

  $$LearningSurahsTableOrderingComposer get learningSurahId {
    final $$LearningSurahsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.learningSurahId,
      referencedTable: $db.learningSurahs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSurahsTableOrderingComposer(
            $db: $db,
            $table: $db.learningSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromStageKind => $composableBuilder(
    column: $table.fromStageKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fromStageEndAyah => $composableBuilder(
    column: $table.fromStageEndAyah,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStageKind => $composableBuilder(
    column: $table.toStageKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toStageEndAyah => $composableBuilder(
    column: $table.toStageEndAyah,
    builder: (column) => column,
  );

  $$LearningSurahsTableAnnotationComposer get learningSurahId {
    final $$LearningSurahsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.learningSurahId,
      referencedTable: $db.learningSurahs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearningSurahsTableAnnotationComposer(
            $db: $db,
            $table: $db.learningSurahs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearningEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningEventsTable,
          LearningEventRow,
          $$LearningEventsTableFilterComposer,
          $$LearningEventsTableOrderingComposer,
          $$LearningEventsTableAnnotationComposer,
          $$LearningEventsTableCreateCompanionBuilder,
          $$LearningEventsTableUpdateCompanionBuilder,
          (LearningEventRow, $$LearningEventsTableReferences),
          LearningEventRow,
          PrefetchHooks Function({bool learningSurahId})
        > {
  $$LearningEventsTableTableManager(
    _$AppDatabase db,
    $LearningEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> learningSurahId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<String> fromStageKind = const Value.absent(),
                Value<int> fromStageEndAyah = const Value.absent(),
                Value<String> toStageKind = const Value.absent(),
                Value<int> toStageEndAyah = const Value.absent(),
              }) => LearningEventsCompanion(
                id: id,
                sequence: sequence,
                learningSurahId: learningSurahId,
                type: type,
                createdAtUtc: createdAtUtc,
                fromStageKind: fromStageKind,
                fromStageEndAyah: fromStageEndAyah,
                toStageKind: toStageKind,
                toStageEndAyah: toStageEndAyah,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> sequence = const Value.absent(),
                required String learningSurahId,
                required String type,
                required DateTime createdAtUtc,
                required String fromStageKind,
                required int fromStageEndAyah,
                required String toStageKind,
                required int toStageEndAyah,
              }) => LearningEventsCompanion.insert(
                id: id,
                sequence: sequence,
                learningSurahId: learningSurahId,
                type: type,
                createdAtUtc: createdAtUtc,
                fromStageKind: fromStageKind,
                fromStageEndAyah: fromStageEndAyah,
                toStageKind: toStageKind,
                toStageEndAyah: toStageEndAyah,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearningEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({learningSurahId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (learningSurahId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.learningSurahId,
                                referencedTable: $$LearningEventsTableReferences
                                    ._learningSurahIdTable(db),
                                referencedColumn:
                                    $$LearningEventsTableReferences
                                        ._learningSurahIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearningEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningEventsTable,
      LearningEventRow,
      $$LearningEventsTableFilterComposer,
      $$LearningEventsTableOrderingComposer,
      $$LearningEventsTableAnnotationComposer,
      $$LearningEventsTableCreateCompanionBuilder,
      $$LearningEventsTableUpdateCompanionBuilder,
      (LearningEventRow, $$LearningEventsTableReferences),
      LearningEventRow,
      PrefetchHooks Function({bool learningSurahId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required String valueType,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<String> valueType,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueType => $composableBuilder(
    column: $table.valueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> valueType = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                valueType: valueType,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required String valueType,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                valueType: valueType,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SurahMetadataTableTableManager get surahMetadata =>
      $$SurahMetadataTableTableManager(_db, _db.surahMetadata);
  $$MasteredSurahsTableTableManager get masteredSurahs =>
      $$MasteredSurahsTableTableManager(_db, _db.masteredSurahs);
  $$RotationStatesTableTableManager get rotationStates =>
      $$RotationStatesTableTableManager(_db, _db.rotationStates);
  $$RotationSchemesTableTableManager get rotationSchemes =>
      $$RotationSchemesTableTableManager(_db, _db.rotationSchemes);
  $$RotationPartsTableTableManager get rotationParts =>
      $$RotationPartsTableTableManager(_db, _db.rotationParts);
  $$PrayerSessionsTableTableManager get prayerSessions =>
      $$PrayerSessionsTableTableManager(_db, _db.prayerSessions);
  $$RecitationEventsTableTableManager get recitationEvents =>
      $$RecitationEventsTableTableManager(_db, _db.recitationEvents);
  $$RecitationEventPartsTableTableManager get recitationEventParts =>
      $$RecitationEventPartsTableTableManager(_db, _db.recitationEventParts);
  $$RotationAdjustmentsTableTableManager get rotationAdjustments =>
      $$RotationAdjustmentsTableTableManager(_db, _db.rotationAdjustments);
  $$LearningSurahsTableTableManager get learningSurahs =>
      $$LearningSurahsTableTableManager(_db, _db.learningSurahs);
  $$LearningEventsTableTableManager get learningEvents =>
      $$LearningEventsTableTableManager(_db, _db.learningEvents);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
