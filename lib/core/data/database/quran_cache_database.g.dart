// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quran_cache_database.dart';

// ignore_for_file: type=lint
class $QuranSourceMetadataTable extends QuranSourceMetadata
    with TableInfo<$QuranSourceMetadataTable, QuranSourceMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuranSourceMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datasetTypeMeta = const VerificationMeta(
    'datasetType',
  );
  @override
  late final GeneratedColumn<String> datasetType = GeneratedColumn<String>(
    'dataset_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationKeyMeta = const VerificationMeta(
    'translationKey',
  );
  @override
  late final GeneratedColumn<String> translationKey = GeneratedColumn<String>(
    'translation_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attributionMeta = const VerificationMeta(
    'attribution',
  );
  @override
  late final GeneratedColumn<String> attribution = GeneratedColumn<String>(
    'attribution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtUtcMeta = const VerificationMeta(
    'fetchedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAtUtc = GeneratedColumn<DateTime>(
    'fetched_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    datasetType,
    version,
    languageCode,
    translationKey,
    sourceUri,
    attribution,
    license,
    fetchedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quran_source_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuranSourceMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('dataset_type')) {
      context.handle(
        _datasetTypeMeta,
        datasetType.isAcceptableOrUnknown(
          data['dataset_type']!,
          _datasetTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_datasetTypeMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    }
    if (data.containsKey('translation_key')) {
      context.handle(
        _translationKeyMeta,
        translationKey.isAcceptableOrUnknown(
          data['translation_key']!,
          _translationKeyMeta,
        ),
      );
    }
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    }
    if (data.containsKey('attribution')) {
      context.handle(
        _attributionMeta,
        attribution.isAcceptableOrUnknown(
          data['attribution']!,
          _attributionMeta,
        ),
      );
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    }
    if (data.containsKey('fetched_at_utc')) {
      context.handle(
        _fetchedAtUtcMeta,
        fetchedAtUtc.isAcceptableOrUnknown(
          data['fetched_at_utc']!,
          _fetchedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuranSourceMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuranSourceMetadataRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      datasetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_type'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      ),
      translationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation_key'],
      ),
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      ),
      attribution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attribution'],
      ),
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      ),
      fetchedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at_utc'],
      )!,
    );
  }

  @override
  $QuranSourceMetadataTable createAlias(String alias) {
    return $QuranSourceMetadataTable(attachedDatabase, alias);
  }
}

class QuranSourceMetadataRow extends DataClass
    implements Insertable<QuranSourceMetadataRow> {
  final String id;
  final String provider;
  final String datasetType;
  final String version;
  final String? languageCode;
  final String? translationKey;
  final String? sourceUri;
  final String? attribution;
  final String? license;
  final DateTime fetchedAtUtc;
  const QuranSourceMetadataRow({
    required this.id,
    required this.provider,
    required this.datasetType,
    required this.version,
    this.languageCode,
    this.translationKey,
    this.sourceUri,
    this.attribution,
    this.license,
    required this.fetchedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider'] = Variable<String>(provider);
    map['dataset_type'] = Variable<String>(datasetType);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || languageCode != null) {
      map['language_code'] = Variable<String>(languageCode);
    }
    if (!nullToAbsent || translationKey != null) {
      map['translation_key'] = Variable<String>(translationKey);
    }
    if (!nullToAbsent || sourceUri != null) {
      map['source_uri'] = Variable<String>(sourceUri);
    }
    if (!nullToAbsent || attribution != null) {
      map['attribution'] = Variable<String>(attribution);
    }
    if (!nullToAbsent || license != null) {
      map['license'] = Variable<String>(license);
    }
    map['fetched_at_utc'] = Variable<DateTime>(fetchedAtUtc);
    return map;
  }

  QuranSourceMetadataCompanion toCompanion(bool nullToAbsent) {
    return QuranSourceMetadataCompanion(
      id: Value(id),
      provider: Value(provider),
      datasetType: Value(datasetType),
      version: Value(version),
      languageCode: languageCode == null && nullToAbsent
          ? const Value.absent()
          : Value(languageCode),
      translationKey: translationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(translationKey),
      sourceUri: sourceUri == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUri),
      attribution: attribution == null && nullToAbsent
          ? const Value.absent()
          : Value(attribution),
      license: license == null && nullToAbsent
          ? const Value.absent()
          : Value(license),
      fetchedAtUtc: Value(fetchedAtUtc),
    );
  }

  factory QuranSourceMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuranSourceMetadataRow(
      id: serializer.fromJson<String>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      datasetType: serializer.fromJson<String>(json['datasetType']),
      version: serializer.fromJson<String>(json['version']),
      languageCode: serializer.fromJson<String?>(json['languageCode']),
      translationKey: serializer.fromJson<String?>(json['translationKey']),
      sourceUri: serializer.fromJson<String?>(json['sourceUri']),
      attribution: serializer.fromJson<String?>(json['attribution']),
      license: serializer.fromJson<String?>(json['license']),
      fetchedAtUtc: serializer.fromJson<DateTime>(json['fetchedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(provider),
      'datasetType': serializer.toJson<String>(datasetType),
      'version': serializer.toJson<String>(version),
      'languageCode': serializer.toJson<String?>(languageCode),
      'translationKey': serializer.toJson<String?>(translationKey),
      'sourceUri': serializer.toJson<String?>(sourceUri),
      'attribution': serializer.toJson<String?>(attribution),
      'license': serializer.toJson<String?>(license),
      'fetchedAtUtc': serializer.toJson<DateTime>(fetchedAtUtc),
    };
  }

  QuranSourceMetadataRow copyWith({
    String? id,
    String? provider,
    String? datasetType,
    String? version,
    Value<String?> languageCode = const Value.absent(),
    Value<String?> translationKey = const Value.absent(),
    Value<String?> sourceUri = const Value.absent(),
    Value<String?> attribution = const Value.absent(),
    Value<String?> license = const Value.absent(),
    DateTime? fetchedAtUtc,
  }) => QuranSourceMetadataRow(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    datasetType: datasetType ?? this.datasetType,
    version: version ?? this.version,
    languageCode: languageCode.present ? languageCode.value : this.languageCode,
    translationKey: translationKey.present
        ? translationKey.value
        : this.translationKey,
    sourceUri: sourceUri.present ? sourceUri.value : this.sourceUri,
    attribution: attribution.present ? attribution.value : this.attribution,
    license: license.present ? license.value : this.license,
    fetchedAtUtc: fetchedAtUtc ?? this.fetchedAtUtc,
  );
  QuranSourceMetadataRow copyWithCompanion(QuranSourceMetadataCompanion data) {
    return QuranSourceMetadataRow(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      datasetType: data.datasetType.present
          ? data.datasetType.value
          : this.datasetType,
      version: data.version.present ? data.version.value : this.version,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      translationKey: data.translationKey.present
          ? data.translationKey.value
          : this.translationKey,
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      attribution: data.attribution.present
          ? data.attribution.value
          : this.attribution,
      license: data.license.present ? data.license.value : this.license,
      fetchedAtUtc: data.fetchedAtUtc.present
          ? data.fetchedAtUtc.value
          : this.fetchedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuranSourceMetadataRow(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('datasetType: $datasetType, ')
          ..write('version: $version, ')
          ..write('languageCode: $languageCode, ')
          ..write('translationKey: $translationKey, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('attribution: $attribution, ')
          ..write('license: $license, ')
          ..write('fetchedAtUtc: $fetchedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    datasetType,
    version,
    languageCode,
    translationKey,
    sourceUri,
    attribution,
    license,
    fetchedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuranSourceMetadataRow &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.datasetType == this.datasetType &&
          other.version == this.version &&
          other.languageCode == this.languageCode &&
          other.translationKey == this.translationKey &&
          other.sourceUri == this.sourceUri &&
          other.attribution == this.attribution &&
          other.license == this.license &&
          other.fetchedAtUtc == this.fetchedAtUtc);
}

class QuranSourceMetadataCompanion
    extends UpdateCompanion<QuranSourceMetadataRow> {
  final Value<String> id;
  final Value<String> provider;
  final Value<String> datasetType;
  final Value<String> version;
  final Value<String?> languageCode;
  final Value<String?> translationKey;
  final Value<String?> sourceUri;
  final Value<String?> attribution;
  final Value<String?> license;
  final Value<DateTime> fetchedAtUtc;
  final Value<int> rowid;
  const QuranSourceMetadataCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.datasetType = const Value.absent(),
    this.version = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.translationKey = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.attribution = const Value.absent(),
    this.license = const Value.absent(),
    this.fetchedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuranSourceMetadataCompanion.insert({
    required String id,
    required String provider,
    required String datasetType,
    required String version,
    this.languageCode = const Value.absent(),
    this.translationKey = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.attribution = const Value.absent(),
    this.license = const Value.absent(),
    required DateTime fetchedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       datasetType = Value(datasetType),
       version = Value(version),
       fetchedAtUtc = Value(fetchedAtUtc);
  static Insertable<QuranSourceMetadataRow> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? datasetType,
    Expression<String>? version,
    Expression<String>? languageCode,
    Expression<String>? translationKey,
    Expression<String>? sourceUri,
    Expression<String>? attribution,
    Expression<String>? license,
    Expression<DateTime>? fetchedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (datasetType != null) 'dataset_type': datasetType,
      if (version != null) 'version': version,
      if (languageCode != null) 'language_code': languageCode,
      if (translationKey != null) 'translation_key': translationKey,
      if (sourceUri != null) 'source_uri': sourceUri,
      if (attribution != null) 'attribution': attribution,
      if (license != null) 'license': license,
      if (fetchedAtUtc != null) 'fetched_at_utc': fetchedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuranSourceMetadataCompanion copyWith({
    Value<String>? id,
    Value<String>? provider,
    Value<String>? datasetType,
    Value<String>? version,
    Value<String?>? languageCode,
    Value<String?>? translationKey,
    Value<String?>? sourceUri,
    Value<String?>? attribution,
    Value<String?>? license,
    Value<DateTime>? fetchedAtUtc,
    Value<int>? rowid,
  }) {
    return QuranSourceMetadataCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      datasetType: datasetType ?? this.datasetType,
      version: version ?? this.version,
      languageCode: languageCode ?? this.languageCode,
      translationKey: translationKey ?? this.translationKey,
      sourceUri: sourceUri ?? this.sourceUri,
      attribution: attribution ?? this.attribution,
      license: license ?? this.license,
      fetchedAtUtc: fetchedAtUtc ?? this.fetchedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (datasetType.present) {
      map['dataset_type'] = Variable<String>(datasetType.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (translationKey.present) {
      map['translation_key'] = Variable<String>(translationKey.value);
    }
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (attribution.present) {
      map['attribution'] = Variable<String>(attribution.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (fetchedAtUtc.present) {
      map['fetched_at_utc'] = Variable<DateTime>(fetchedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuranSourceMetadataCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('datasetType: $datasetType, ')
          ..write('version: $version, ')
          ..write('languageCode: $languageCode, ')
          ..write('translationKey: $translationKey, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('attribution: $attribution, ')
          ..write('license: $license, ')
          ..write('fetchedAtUtc: $fetchedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuranAyahCacheTable extends QuranAyahCache
    with TableInfo<$QuranAyahCacheTable, QuranAyahCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuranAyahCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES quran_source_metadata (id) ON DELETE CASCADE',
    ),
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
  );
  static const VerificationMeta _ayahNumberMeta = const VerificationMeta(
    'ayahNumber',
  );
  @override
  late final GeneratedColumn<int> ayahNumber = GeneratedColumn<int>(
    'ayah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerAyahIdMeta = const VerificationMeta(
    'providerAyahId',
  );
  @override
  late final GeneratedColumn<String> providerAyahId = GeneratedColumn<String>(
    'provider_ayah_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arabicTextMeta = const VerificationMeta(
    'arabicText',
  );
  @override
  late final GeneratedColumn<String> arabicText = GeneratedColumn<String>(
    'arabic_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    surahNumber,
    ayahNumber,
    providerAyahId,
    arabicText,
    translation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quran_ayah_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuranAyahCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
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
    if (data.containsKey('ayah_number')) {
      context.handle(
        _ayahNumberMeta,
        ayahNumber.isAcceptableOrUnknown(data['ayah_number']!, _ayahNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahNumberMeta);
    }
    if (data.containsKey('provider_ayah_id')) {
      context.handle(
        _providerAyahIdMeta,
        providerAyahId.isAcceptableOrUnknown(
          data['provider_ayah_id']!,
          _providerAyahIdMeta,
        ),
      );
    }
    if (data.containsKey('arabic_text')) {
      context.handle(
        _arabicTextMeta,
        arabicText.isAcceptableOrUnknown(data['arabic_text']!, _arabicTextMeta),
      );
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, surahNumber, ayahNumber};
  @override
  QuranAyahCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuranAyahCacheRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      surahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah_number'],
      )!,
      ayahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_number'],
      )!,
      providerAyahId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_ayah_id'],
      ),
      arabicText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arabic_text'],
      ),
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
    );
  }

  @override
  $QuranAyahCacheTable createAlias(String alias) {
    return $QuranAyahCacheTable(attachedDatabase, alias);
  }
}

class QuranAyahCacheRow extends DataClass
    implements Insertable<QuranAyahCacheRow> {
  final String sourceId;
  final int surahNumber;
  final int ayahNumber;
  final String? providerAyahId;
  final String? arabicText;
  final String? translation;
  const QuranAyahCacheRow({
    required this.sourceId,
    required this.surahNumber,
    required this.ayahNumber,
    this.providerAyahId,
    this.arabicText,
    this.translation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['surah_number'] = Variable<int>(surahNumber);
    map['ayah_number'] = Variable<int>(ayahNumber);
    if (!nullToAbsent || providerAyahId != null) {
      map['provider_ayah_id'] = Variable<String>(providerAyahId);
    }
    if (!nullToAbsent || arabicText != null) {
      map['arabic_text'] = Variable<String>(arabicText);
    }
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    return map;
  }

  QuranAyahCacheCompanion toCompanion(bool nullToAbsent) {
    return QuranAyahCacheCompanion(
      sourceId: Value(sourceId),
      surahNumber: Value(surahNumber),
      ayahNumber: Value(ayahNumber),
      providerAyahId: providerAyahId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerAyahId),
      arabicText: arabicText == null && nullToAbsent
          ? const Value.absent()
          : Value(arabicText),
      translation: translation == null && nullToAbsent
          ? const Value.absent()
          : Value(translation),
    );
  }

  factory QuranAyahCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuranAyahCacheRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      surahNumber: serializer.fromJson<int>(json['surahNumber']),
      ayahNumber: serializer.fromJson<int>(json['ayahNumber']),
      providerAyahId: serializer.fromJson<String?>(json['providerAyahId']),
      arabicText: serializer.fromJson<String?>(json['arabicText']),
      translation: serializer.fromJson<String?>(json['translation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'surahNumber': serializer.toJson<int>(surahNumber),
      'ayahNumber': serializer.toJson<int>(ayahNumber),
      'providerAyahId': serializer.toJson<String?>(providerAyahId),
      'arabicText': serializer.toJson<String?>(arabicText),
      'translation': serializer.toJson<String?>(translation),
    };
  }

  QuranAyahCacheRow copyWith({
    String? sourceId,
    int? surahNumber,
    int? ayahNumber,
    Value<String?> providerAyahId = const Value.absent(),
    Value<String?> arabicText = const Value.absent(),
    Value<String?> translation = const Value.absent(),
  }) => QuranAyahCacheRow(
    sourceId: sourceId ?? this.sourceId,
    surahNumber: surahNumber ?? this.surahNumber,
    ayahNumber: ayahNumber ?? this.ayahNumber,
    providerAyahId: providerAyahId.present
        ? providerAyahId.value
        : this.providerAyahId,
    arabicText: arabicText.present ? arabicText.value : this.arabicText,
    translation: translation.present ? translation.value : this.translation,
  );
  QuranAyahCacheRow copyWithCompanion(QuranAyahCacheCompanion data) {
    return QuranAyahCacheRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      ayahNumber: data.ayahNumber.present
          ? data.ayahNumber.value
          : this.ayahNumber,
      providerAyahId: data.providerAyahId.present
          ? data.providerAyahId.value
          : this.providerAyahId,
      arabicText: data.arabicText.present
          ? data.arabicText.value
          : this.arabicText,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuranAyahCacheRow(')
          ..write('sourceId: $sourceId, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('providerAyahId: $providerAyahId, ')
          ..write('arabicText: $arabicText, ')
          ..write('translation: $translation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    surahNumber,
    ayahNumber,
    providerAyahId,
    arabicText,
    translation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuranAyahCacheRow &&
          other.sourceId == this.sourceId &&
          other.surahNumber == this.surahNumber &&
          other.ayahNumber == this.ayahNumber &&
          other.providerAyahId == this.providerAyahId &&
          other.arabicText == this.arabicText &&
          other.translation == this.translation);
}

class QuranAyahCacheCompanion extends UpdateCompanion<QuranAyahCacheRow> {
  final Value<String> sourceId;
  final Value<int> surahNumber;
  final Value<int> ayahNumber;
  final Value<String?> providerAyahId;
  final Value<String?> arabicText;
  final Value<String?> translation;
  final Value<int> rowid;
  const QuranAyahCacheCompanion({
    this.sourceId = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.ayahNumber = const Value.absent(),
    this.providerAyahId = const Value.absent(),
    this.arabicText = const Value.absent(),
    this.translation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuranAyahCacheCompanion.insert({
    required String sourceId,
    required int surahNumber,
    required int ayahNumber,
    this.providerAyahId = const Value.absent(),
    this.arabicText = const Value.absent(),
    this.translation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       surahNumber = Value(surahNumber),
       ayahNumber = Value(ayahNumber);
  static Insertable<QuranAyahCacheRow> custom({
    Expression<String>? sourceId,
    Expression<int>? surahNumber,
    Expression<int>? ayahNumber,
    Expression<String>? providerAyahId,
    Expression<String>? arabicText,
    Expression<String>? translation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (ayahNumber != null) 'ayah_number': ayahNumber,
      if (providerAyahId != null) 'provider_ayah_id': providerAyahId,
      if (arabicText != null) 'arabic_text': arabicText,
      if (translation != null) 'translation': translation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuranAyahCacheCompanion copyWith({
    Value<String>? sourceId,
    Value<int>? surahNumber,
    Value<int>? ayahNumber,
    Value<String?>? providerAyahId,
    Value<String?>? arabicText,
    Value<String?>? translation,
    Value<int>? rowid,
  }) {
    return QuranAyahCacheCompanion(
      sourceId: sourceId ?? this.sourceId,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      providerAyahId: providerAyahId ?? this.providerAyahId,
      arabicText: arabicText ?? this.arabicText,
      translation: translation ?? this.translation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (surahNumber.present) {
      map['surah_number'] = Variable<int>(surahNumber.value);
    }
    if (ayahNumber.present) {
      map['ayah_number'] = Variable<int>(ayahNumber.value);
    }
    if (providerAyahId.present) {
      map['provider_ayah_id'] = Variable<String>(providerAyahId.value);
    }
    if (arabicText.present) {
      map['arabic_text'] = Variable<String>(arabicText.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuranAyahCacheCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('providerAyahId: $providerAyahId, ')
          ..write('arabicText: $arabicText, ')
          ..write('translation: $translation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuranWordCacheTable extends QuranWordCache
    with TableInfo<$QuranWordCacheTable, QuranWordCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuranWordCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES quran_source_metadata (id) ON DELETE CASCADE',
    ),
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
  );
  static const VerificationMeta _ayahNumberMeta = const VerificationMeta(
    'ayahNumber',
  );
  @override
  late final GeneratedColumn<int> ayahNumber = GeneratedColumn<int>(
    'ayah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerWordIdMeta = const VerificationMeta(
    'providerWordId',
  );
  @override
  late final GeneratedColumn<String> providerWordId = GeneratedColumn<String>(
    'provider_word_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arabicTextMeta = const VerificationMeta(
    'arabicText',
  );
  @override
  late final GeneratedColumn<String> arabicText = GeneratedColumn<String>(
    'arabic_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    surahNumber,
    ayahNumber,
    position,
    providerWordId,
    arabicText,
    translation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quran_word_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuranWordCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
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
    if (data.containsKey('ayah_number')) {
      context.handle(
        _ayahNumberMeta,
        ayahNumber.isAcceptableOrUnknown(data['ayah_number']!, _ayahNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahNumberMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('provider_word_id')) {
      context.handle(
        _providerWordIdMeta,
        providerWordId.isAcceptableOrUnknown(
          data['provider_word_id']!,
          _providerWordIdMeta,
        ),
      );
    }
    if (data.containsKey('arabic_text')) {
      context.handle(
        _arabicTextMeta,
        arabicText.isAcceptableOrUnknown(data['arabic_text']!, _arabicTextMeta),
      );
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    sourceId,
    surahNumber,
    ayahNumber,
    position,
  };
  @override
  QuranWordCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuranWordCacheRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      surahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah_number'],
      )!,
      ayahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_number'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      providerWordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_word_id'],
      ),
      arabicText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arabic_text'],
      ),
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
    );
  }

  @override
  $QuranWordCacheTable createAlias(String alias) {
    return $QuranWordCacheTable(attachedDatabase, alias);
  }
}

class QuranWordCacheRow extends DataClass
    implements Insertable<QuranWordCacheRow> {
  final String sourceId;
  final int surahNumber;
  final int ayahNumber;
  final int position;
  final String? providerWordId;
  final String? arabicText;
  final String? translation;
  const QuranWordCacheRow({
    required this.sourceId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.position,
    this.providerWordId,
    this.arabicText,
    this.translation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['surah_number'] = Variable<int>(surahNumber);
    map['ayah_number'] = Variable<int>(ayahNumber);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || providerWordId != null) {
      map['provider_word_id'] = Variable<String>(providerWordId);
    }
    if (!nullToAbsent || arabicText != null) {
      map['arabic_text'] = Variable<String>(arabicText);
    }
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    return map;
  }

  QuranWordCacheCompanion toCompanion(bool nullToAbsent) {
    return QuranWordCacheCompanion(
      sourceId: Value(sourceId),
      surahNumber: Value(surahNumber),
      ayahNumber: Value(ayahNumber),
      position: Value(position),
      providerWordId: providerWordId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerWordId),
      arabicText: arabicText == null && nullToAbsent
          ? const Value.absent()
          : Value(arabicText),
      translation: translation == null && nullToAbsent
          ? const Value.absent()
          : Value(translation),
    );
  }

  factory QuranWordCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuranWordCacheRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      surahNumber: serializer.fromJson<int>(json['surahNumber']),
      ayahNumber: serializer.fromJson<int>(json['ayahNumber']),
      position: serializer.fromJson<int>(json['position']),
      providerWordId: serializer.fromJson<String?>(json['providerWordId']),
      arabicText: serializer.fromJson<String?>(json['arabicText']),
      translation: serializer.fromJson<String?>(json['translation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'surahNumber': serializer.toJson<int>(surahNumber),
      'ayahNumber': serializer.toJson<int>(ayahNumber),
      'position': serializer.toJson<int>(position),
      'providerWordId': serializer.toJson<String?>(providerWordId),
      'arabicText': serializer.toJson<String?>(arabicText),
      'translation': serializer.toJson<String?>(translation),
    };
  }

  QuranWordCacheRow copyWith({
    String? sourceId,
    int? surahNumber,
    int? ayahNumber,
    int? position,
    Value<String?> providerWordId = const Value.absent(),
    Value<String?> arabicText = const Value.absent(),
    Value<String?> translation = const Value.absent(),
  }) => QuranWordCacheRow(
    sourceId: sourceId ?? this.sourceId,
    surahNumber: surahNumber ?? this.surahNumber,
    ayahNumber: ayahNumber ?? this.ayahNumber,
    position: position ?? this.position,
    providerWordId: providerWordId.present
        ? providerWordId.value
        : this.providerWordId,
    arabicText: arabicText.present ? arabicText.value : this.arabicText,
    translation: translation.present ? translation.value : this.translation,
  );
  QuranWordCacheRow copyWithCompanion(QuranWordCacheCompanion data) {
    return QuranWordCacheRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      ayahNumber: data.ayahNumber.present
          ? data.ayahNumber.value
          : this.ayahNumber,
      position: data.position.present ? data.position.value : this.position,
      providerWordId: data.providerWordId.present
          ? data.providerWordId.value
          : this.providerWordId,
      arabicText: data.arabicText.present
          ? data.arabicText.value
          : this.arabicText,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuranWordCacheRow(')
          ..write('sourceId: $sourceId, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('position: $position, ')
          ..write('providerWordId: $providerWordId, ')
          ..write('arabicText: $arabicText, ')
          ..write('translation: $translation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    surahNumber,
    ayahNumber,
    position,
    providerWordId,
    arabicText,
    translation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuranWordCacheRow &&
          other.sourceId == this.sourceId &&
          other.surahNumber == this.surahNumber &&
          other.ayahNumber == this.ayahNumber &&
          other.position == this.position &&
          other.providerWordId == this.providerWordId &&
          other.arabicText == this.arabicText &&
          other.translation == this.translation);
}

class QuranWordCacheCompanion extends UpdateCompanion<QuranWordCacheRow> {
  final Value<String> sourceId;
  final Value<int> surahNumber;
  final Value<int> ayahNumber;
  final Value<int> position;
  final Value<String?> providerWordId;
  final Value<String?> arabicText;
  final Value<String?> translation;
  final Value<int> rowid;
  const QuranWordCacheCompanion({
    this.sourceId = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.ayahNumber = const Value.absent(),
    this.position = const Value.absent(),
    this.providerWordId = const Value.absent(),
    this.arabicText = const Value.absent(),
    this.translation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuranWordCacheCompanion.insert({
    required String sourceId,
    required int surahNumber,
    required int ayahNumber,
    required int position,
    this.providerWordId = const Value.absent(),
    this.arabicText = const Value.absent(),
    this.translation = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       surahNumber = Value(surahNumber),
       ayahNumber = Value(ayahNumber),
       position = Value(position);
  static Insertable<QuranWordCacheRow> custom({
    Expression<String>? sourceId,
    Expression<int>? surahNumber,
    Expression<int>? ayahNumber,
    Expression<int>? position,
    Expression<String>? providerWordId,
    Expression<String>? arabicText,
    Expression<String>? translation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (ayahNumber != null) 'ayah_number': ayahNumber,
      if (position != null) 'position': position,
      if (providerWordId != null) 'provider_word_id': providerWordId,
      if (arabicText != null) 'arabic_text': arabicText,
      if (translation != null) 'translation': translation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuranWordCacheCompanion copyWith({
    Value<String>? sourceId,
    Value<int>? surahNumber,
    Value<int>? ayahNumber,
    Value<int>? position,
    Value<String?>? providerWordId,
    Value<String?>? arabicText,
    Value<String?>? translation,
    Value<int>? rowid,
  }) {
    return QuranWordCacheCompanion(
      sourceId: sourceId ?? this.sourceId,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      position: position ?? this.position,
      providerWordId: providerWordId ?? this.providerWordId,
      arabicText: arabicText ?? this.arabicText,
      translation: translation ?? this.translation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (surahNumber.present) {
      map['surah_number'] = Variable<int>(surahNumber.value);
    }
    if (ayahNumber.present) {
      map['ayah_number'] = Variable<int>(ayahNumber.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (providerWordId.present) {
      map['provider_word_id'] = Variable<String>(providerWordId.value);
    }
    if (arabicText.present) {
      map['arabic_text'] = Variable<String>(arabicText.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuranWordCacheCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('ayahNumber: $ayahNumber, ')
          ..write('position: $position, ')
          ..write('providerWordId: $providerWordId, ')
          ..write('arabicText: $arabicText, ')
          ..write('translation: $translation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$QuranCacheDatabase extends GeneratedDatabase {
  _$QuranCacheDatabase(QueryExecutor e) : super(e);
  $QuranCacheDatabaseManager get managers => $QuranCacheDatabaseManager(this);
  late final $QuranSourceMetadataTable quranSourceMetadata =
      $QuranSourceMetadataTable(this);
  late final $QuranAyahCacheTable quranAyahCache = $QuranAyahCacheTable(this);
  late final $QuranWordCacheTable quranWordCache = $QuranWordCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    quranSourceMetadata,
    quranAyahCache,
    quranWordCache,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'quran_source_metadata',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quran_ayah_cache', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'quran_source_metadata',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quran_word_cache', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$QuranSourceMetadataTableCreateCompanionBuilder =
    QuranSourceMetadataCompanion Function({
      required String id,
      required String provider,
      required String datasetType,
      required String version,
      Value<String?> languageCode,
      Value<String?> translationKey,
      Value<String?> sourceUri,
      Value<String?> attribution,
      Value<String?> license,
      required DateTime fetchedAtUtc,
      Value<int> rowid,
    });
typedef $$QuranSourceMetadataTableUpdateCompanionBuilder =
    QuranSourceMetadataCompanion Function({
      Value<String> id,
      Value<String> provider,
      Value<String> datasetType,
      Value<String> version,
      Value<String?> languageCode,
      Value<String?> translationKey,
      Value<String?> sourceUri,
      Value<String?> attribution,
      Value<String?> license,
      Value<DateTime> fetchedAtUtc,
      Value<int> rowid,
    });

final class $$QuranSourceMetadataTableReferences
    extends
        BaseReferences<
          _$QuranCacheDatabase,
          $QuranSourceMetadataTable,
          QuranSourceMetadataRow
        > {
  $$QuranSourceMetadataTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$QuranAyahCacheTable, List<QuranAyahCacheRow>>
  _quranAyahCacheRefsTable(_$QuranCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.quranAyahCache,
        aliasName: 'quran_source_metadata__id__quran_ayah_cache__source_id',
      );

  $$QuranAyahCacheTableProcessedTableManager get quranAyahCacheRefs {
    final manager = $$QuranAyahCacheTableTableManager(
      $_db,
      $_db.quranAyahCache,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_quranAyahCacheRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$QuranWordCacheTable, List<QuranWordCacheRow>>
  _quranWordCacheRefsTable(_$QuranCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.quranWordCache,
        aliasName: 'quran_source_metadata__id__quran_word_cache__source_id',
      );

  $$QuranWordCacheTableProcessedTableManager get quranWordCacheRefs {
    final manager = $$QuranWordCacheTableTableManager(
      $_db,
      $_db.quranWordCache,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_quranWordCacheRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuranSourceMetadataTableFilterComposer
    extends Composer<_$QuranCacheDatabase, $QuranSourceMetadataTable> {
  $$QuranSourceMetadataTableFilterComposer({
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

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasetType => $composableBuilder(
    column: $table.datasetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationKey => $composableBuilder(
    column: $table.translationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attribution => $composableBuilder(
    column: $table.attribution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAtUtc => $composableBuilder(
    column: $table.fetchedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> quranAyahCacheRefs(
    Expression<bool> Function($$QuranAyahCacheTableFilterComposer f) f,
  ) {
    final $$QuranAyahCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quranAyahCache,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranAyahCacheTableFilterComposer(
            $db: $db,
            $table: $db.quranAyahCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> quranWordCacheRefs(
    Expression<bool> Function($$QuranWordCacheTableFilterComposer f) f,
  ) {
    final $$QuranWordCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quranWordCache,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranWordCacheTableFilterComposer(
            $db: $db,
            $table: $db.quranWordCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuranSourceMetadataTableOrderingComposer
    extends Composer<_$QuranCacheDatabase, $QuranSourceMetadataTable> {
  $$QuranSourceMetadataTableOrderingComposer({
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

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasetType => $composableBuilder(
    column: $table.datasetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationKey => $composableBuilder(
    column: $table.translationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attribution => $composableBuilder(
    column: $table.attribution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAtUtc => $composableBuilder(
    column: $table.fetchedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuranSourceMetadataTableAnnotationComposer
    extends Composer<_$QuranCacheDatabase, $QuranSourceMetadataTable> {
  $$QuranSourceMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get datasetType => $composableBuilder(
    column: $table.datasetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translationKey => $composableBuilder(
    column: $table.translationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<String> get attribution => $composableBuilder(
    column: $table.attribution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAtUtc => $composableBuilder(
    column: $table.fetchedAtUtc,
    builder: (column) => column,
  );

  Expression<T> quranAyahCacheRefs<T extends Object>(
    Expression<T> Function($$QuranAyahCacheTableAnnotationComposer a) f,
  ) {
    final $$QuranAyahCacheTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quranAyahCache,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranAyahCacheTableAnnotationComposer(
            $db: $db,
            $table: $db.quranAyahCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> quranWordCacheRefs<T extends Object>(
    Expression<T> Function($$QuranWordCacheTableAnnotationComposer a) f,
  ) {
    final $$QuranWordCacheTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quranWordCache,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranWordCacheTableAnnotationComposer(
            $db: $db,
            $table: $db.quranWordCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuranSourceMetadataTableTableManager
    extends
        RootTableManager<
          _$QuranCacheDatabase,
          $QuranSourceMetadataTable,
          QuranSourceMetadataRow,
          $$QuranSourceMetadataTableFilterComposer,
          $$QuranSourceMetadataTableOrderingComposer,
          $$QuranSourceMetadataTableAnnotationComposer,
          $$QuranSourceMetadataTableCreateCompanionBuilder,
          $$QuranSourceMetadataTableUpdateCompanionBuilder,
          (QuranSourceMetadataRow, $$QuranSourceMetadataTableReferences),
          QuranSourceMetadataRow,
          PrefetchHooks Function({
            bool quranAyahCacheRefs,
            bool quranWordCacheRefs,
          })
        > {
  $$QuranSourceMetadataTableTableManager(
    _$QuranCacheDatabase db,
    $QuranSourceMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuranSourceMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuranSourceMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$QuranSourceMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> datasetType = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> languageCode = const Value.absent(),
                Value<String?> translationKey = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> attribution = const Value.absent(),
                Value<String?> license = const Value.absent(),
                Value<DateTime> fetchedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuranSourceMetadataCompanion(
                id: id,
                provider: provider,
                datasetType: datasetType,
                version: version,
                languageCode: languageCode,
                translationKey: translationKey,
                sourceUri: sourceUri,
                attribution: attribution,
                license: license,
                fetchedAtUtc: fetchedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String provider,
                required String datasetType,
                required String version,
                Value<String?> languageCode = const Value.absent(),
                Value<String?> translationKey = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> attribution = const Value.absent(),
                Value<String?> license = const Value.absent(),
                required DateTime fetchedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => QuranSourceMetadataCompanion.insert(
                id: id,
                provider: provider,
                datasetType: datasetType,
                version: version,
                languageCode: languageCode,
                translationKey: translationKey,
                sourceUri: sourceUri,
                attribution: attribution,
                license: license,
                fetchedAtUtc: fetchedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuranSourceMetadataTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({quranAyahCacheRefs = false, quranWordCacheRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (quranAyahCacheRefs) db.quranAyahCache,
                    if (quranWordCacheRefs) db.quranWordCache,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (quranAyahCacheRefs)
                        await $_getPrefetchedData<
                          QuranSourceMetadataRow,
                          $QuranSourceMetadataTable,
                          QuranAyahCacheRow
                        >(
                          currentTable: table,
                          referencedTable: $$QuranSourceMetadataTableReferences
                              ._quranAyahCacheRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuranSourceMetadataTableReferences(
                                db,
                                table,
                                p0,
                              ).quranAyahCacheRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (quranWordCacheRefs)
                        await $_getPrefetchedData<
                          QuranSourceMetadataRow,
                          $QuranSourceMetadataTable,
                          QuranWordCacheRow
                        >(
                          currentTable: table,
                          referencedTable: $$QuranSourceMetadataTableReferences
                              ._quranWordCacheRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuranSourceMetadataTableReferences(
                                db,
                                table,
                                p0,
                              ).quranWordCacheRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
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

typedef $$QuranSourceMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$QuranCacheDatabase,
      $QuranSourceMetadataTable,
      QuranSourceMetadataRow,
      $$QuranSourceMetadataTableFilterComposer,
      $$QuranSourceMetadataTableOrderingComposer,
      $$QuranSourceMetadataTableAnnotationComposer,
      $$QuranSourceMetadataTableCreateCompanionBuilder,
      $$QuranSourceMetadataTableUpdateCompanionBuilder,
      (QuranSourceMetadataRow, $$QuranSourceMetadataTableReferences),
      QuranSourceMetadataRow,
      PrefetchHooks Function({bool quranAyahCacheRefs, bool quranWordCacheRefs})
    >;
typedef $$QuranAyahCacheTableCreateCompanionBuilder =
    QuranAyahCacheCompanion Function({
      required String sourceId,
      required int surahNumber,
      required int ayahNumber,
      Value<String?> providerAyahId,
      Value<String?> arabicText,
      Value<String?> translation,
      Value<int> rowid,
    });
typedef $$QuranAyahCacheTableUpdateCompanionBuilder =
    QuranAyahCacheCompanion Function({
      Value<String> sourceId,
      Value<int> surahNumber,
      Value<int> ayahNumber,
      Value<String?> providerAyahId,
      Value<String?> arabicText,
      Value<String?> translation,
      Value<int> rowid,
    });

final class $$QuranAyahCacheTableReferences
    extends
        BaseReferences<
          _$QuranCacheDatabase,
          $QuranAyahCacheTable,
          QuranAyahCacheRow
        > {
  $$QuranAyahCacheTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $QuranSourceMetadataTable _sourceIdTable(_$QuranCacheDatabase db) => db
      .quranSourceMetadata
      .createAlias('quran_ayah_cache__source_id__quran_source_metadata__id');

  $$QuranSourceMetadataTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$QuranSourceMetadataTableTableManager(
      $_db,
      $_db.quranSourceMetadata,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuranAyahCacheTableFilterComposer
    extends Composer<_$QuranCacheDatabase, $QuranAyahCacheTable> {
  $$QuranAyahCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerAyahId => $composableBuilder(
    column: $table.providerAyahId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  $$QuranSourceMetadataTableFilterComposer get sourceId {
    final $$QuranSourceMetadataTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.quranSourceMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranSourceMetadataTableFilterComposer(
            $db: $db,
            $table: $db.quranSourceMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuranAyahCacheTableOrderingComposer
    extends Composer<_$QuranCacheDatabase, $QuranAyahCacheTable> {
  $$QuranAyahCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerAyahId => $composableBuilder(
    column: $table.providerAyahId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuranSourceMetadataTableOrderingComposer get sourceId {
    final $$QuranSourceMetadataTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.quranSourceMetadata,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$QuranSourceMetadataTableOrderingComposer(
                $db: $db,
                $table: $db.quranSourceMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$QuranAyahCacheTableAnnotationComposer
    extends Composer<_$QuranCacheDatabase, $QuranAyahCacheTable> {
  $$QuranAyahCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerAyahId => $composableBuilder(
    column: $table.providerAyahId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  $$QuranSourceMetadataTableAnnotationComposer get sourceId {
    final $$QuranSourceMetadataTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.quranSourceMetadata,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$QuranSourceMetadataTableAnnotationComposer(
                $db: $db,
                $table: $db.quranSourceMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$QuranAyahCacheTableTableManager
    extends
        RootTableManager<
          _$QuranCacheDatabase,
          $QuranAyahCacheTable,
          QuranAyahCacheRow,
          $$QuranAyahCacheTableFilterComposer,
          $$QuranAyahCacheTableOrderingComposer,
          $$QuranAyahCacheTableAnnotationComposer,
          $$QuranAyahCacheTableCreateCompanionBuilder,
          $$QuranAyahCacheTableUpdateCompanionBuilder,
          (QuranAyahCacheRow, $$QuranAyahCacheTableReferences),
          QuranAyahCacheRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$QuranAyahCacheTableTableManager(
    _$QuranCacheDatabase db,
    $QuranAyahCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuranAyahCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuranAyahCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuranAyahCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<int> ayahNumber = const Value.absent(),
                Value<String?> providerAyahId = const Value.absent(),
                Value<String?> arabicText = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuranAyahCacheCompanion(
                sourceId: sourceId,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                providerAyahId: providerAyahId,
                arabicText: arabicText,
                translation: translation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required int surahNumber,
                required int ayahNumber,
                Value<String?> providerAyahId = const Value.absent(),
                Value<String?> arabicText = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuranAyahCacheCompanion.insert(
                sourceId: sourceId,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                providerAyahId: providerAyahId,
                arabicText: arabicText,
                translation: translation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuranAyahCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$QuranAyahCacheTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn:
                                    $$QuranAyahCacheTableReferences
                                        ._sourceIdTable(db)
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

typedef $$QuranAyahCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$QuranCacheDatabase,
      $QuranAyahCacheTable,
      QuranAyahCacheRow,
      $$QuranAyahCacheTableFilterComposer,
      $$QuranAyahCacheTableOrderingComposer,
      $$QuranAyahCacheTableAnnotationComposer,
      $$QuranAyahCacheTableCreateCompanionBuilder,
      $$QuranAyahCacheTableUpdateCompanionBuilder,
      (QuranAyahCacheRow, $$QuranAyahCacheTableReferences),
      QuranAyahCacheRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$QuranWordCacheTableCreateCompanionBuilder =
    QuranWordCacheCompanion Function({
      required String sourceId,
      required int surahNumber,
      required int ayahNumber,
      required int position,
      Value<String?> providerWordId,
      Value<String?> arabicText,
      Value<String?> translation,
      Value<int> rowid,
    });
typedef $$QuranWordCacheTableUpdateCompanionBuilder =
    QuranWordCacheCompanion Function({
      Value<String> sourceId,
      Value<int> surahNumber,
      Value<int> ayahNumber,
      Value<int> position,
      Value<String?> providerWordId,
      Value<String?> arabicText,
      Value<String?> translation,
      Value<int> rowid,
    });

final class $$QuranWordCacheTableReferences
    extends
        BaseReferences<
          _$QuranCacheDatabase,
          $QuranWordCacheTable,
          QuranWordCacheRow
        > {
  $$QuranWordCacheTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $QuranSourceMetadataTable _sourceIdTable(_$QuranCacheDatabase db) => db
      .quranSourceMetadata
      .createAlias('quran_word_cache__source_id__quran_source_metadata__id');

  $$QuranSourceMetadataTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$QuranSourceMetadataTableTableManager(
      $_db,
      $_db.quranSourceMetadata,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuranWordCacheTableFilterComposer
    extends Composer<_$QuranCacheDatabase, $QuranWordCacheTable> {
  $$QuranWordCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerWordId => $composableBuilder(
    column: $table.providerWordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  $$QuranSourceMetadataTableFilterComposer get sourceId {
    final $$QuranSourceMetadataTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.quranSourceMetadata,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuranSourceMetadataTableFilterComposer(
            $db: $db,
            $table: $db.quranSourceMetadata,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuranWordCacheTableOrderingComposer
    extends Composer<_$QuranCacheDatabase, $QuranWordCacheTable> {
  $$QuranWordCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerWordId => $composableBuilder(
    column: $table.providerWordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuranSourceMetadataTableOrderingComposer get sourceId {
    final $$QuranSourceMetadataTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.quranSourceMetadata,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$QuranSourceMetadataTableOrderingComposer(
                $db: $db,
                $table: $db.quranSourceMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$QuranWordCacheTableAnnotationComposer
    extends Composer<_$QuranCacheDatabase, $QuranWordCacheTable> {
  $$QuranWordCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ayahNumber => $composableBuilder(
    column: $table.ayahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get providerWordId => $composableBuilder(
    column: $table.providerWordId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arabicText => $composableBuilder(
    column: $table.arabicText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  $$QuranSourceMetadataTableAnnotationComposer get sourceId {
    final $$QuranSourceMetadataTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.quranSourceMetadata,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$QuranSourceMetadataTableAnnotationComposer(
                $db: $db,
                $table: $db.quranSourceMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$QuranWordCacheTableTableManager
    extends
        RootTableManager<
          _$QuranCacheDatabase,
          $QuranWordCacheTable,
          QuranWordCacheRow,
          $$QuranWordCacheTableFilterComposer,
          $$QuranWordCacheTableOrderingComposer,
          $$QuranWordCacheTableAnnotationComposer,
          $$QuranWordCacheTableCreateCompanionBuilder,
          $$QuranWordCacheTableUpdateCompanionBuilder,
          (QuranWordCacheRow, $$QuranWordCacheTableReferences),
          QuranWordCacheRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$QuranWordCacheTableTableManager(
    _$QuranCacheDatabase db,
    $QuranWordCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuranWordCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuranWordCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuranWordCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<int> ayahNumber = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String?> providerWordId = const Value.absent(),
                Value<String?> arabicText = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuranWordCacheCompanion(
                sourceId: sourceId,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                position: position,
                providerWordId: providerWordId,
                arabicText: arabicText,
                translation: translation,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required int surahNumber,
                required int ayahNumber,
                required int position,
                Value<String?> providerWordId = const Value.absent(),
                Value<String?> arabicText = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuranWordCacheCompanion.insert(
                sourceId: sourceId,
                surahNumber: surahNumber,
                ayahNumber: ayahNumber,
                position: position,
                providerWordId: providerWordId,
                arabicText: arabicText,
                translation: translation,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuranWordCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$QuranWordCacheTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn:
                                    $$QuranWordCacheTableReferences
                                        ._sourceIdTable(db)
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

typedef $$QuranWordCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$QuranCacheDatabase,
      $QuranWordCacheTable,
      QuranWordCacheRow,
      $$QuranWordCacheTableFilterComposer,
      $$QuranWordCacheTableOrderingComposer,
      $$QuranWordCacheTableAnnotationComposer,
      $$QuranWordCacheTableCreateCompanionBuilder,
      $$QuranWordCacheTableUpdateCompanionBuilder,
      (QuranWordCacheRow, $$QuranWordCacheTableReferences),
      QuranWordCacheRow,
      PrefetchHooks Function({bool sourceId})
    >;

class $QuranCacheDatabaseManager {
  final _$QuranCacheDatabase _db;
  $QuranCacheDatabaseManager(this._db);
  $$QuranSourceMetadataTableTableManager get quranSourceMetadata =>
      $$QuranSourceMetadataTableTableManager(_db, _db.quranSourceMetadata);
  $$QuranAyahCacheTableTableManager get quranAyahCache =>
      $$QuranAyahCacheTableTableManager(_db, _db.quranAyahCache);
  $$QuranWordCacheTableTableManager get quranWordCache =>
      $$QuranWordCacheTableTableManager(_db, _db.quranWordCache);
}
