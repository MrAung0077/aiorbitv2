// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_task_execution_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMissionTaskExecutionRecordCollection on Isar {
  IsarCollection<MissionTaskExecutionRecord> get missionTaskExecutionRecords =>
      this.collection();
}

const MissionTaskExecutionRecordSchema = CollectionSchema(
  name: r'MissionTaskExecutionRecord',
  id: -175110504483127902,
  properties: {
    r'executionId': PropertySchema(
      id: 0,
      name: r'executionId',
      type: IsarType.string,
    ),
    r'failureMessage': PropertySchema(
      id: 1,
      name: r'failureMessage',
      type: IsarType.string,
    ),
    r'finishedAt': PropertySchema(
      id: 2,
      name: r'finishedAt',
      type: IsarType.dateTime,
    ),
    r'missionId': PropertySchema(
      id: 3,
      name: r'missionId',
      type: IsarType.string,
    ),
    r'outputText': PropertySchema(
      id: 4,
      name: r'outputText',
      type: IsarType.string,
    ),
    r'progress': PropertySchema(
      id: 5,
      name: r'progress',
      type: IsarType.double,
    ),
    r'startedAt': PropertySchema(
      id: 6,
      name: r'startedAt',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(id: 7, name: r'status', type: IsarType.string),
    r'structuredResultReference': PropertySchema(
      id: 8,
      name: r'structuredResultReference',
      type: IsarType.string,
    ),
    r'taskId': PropertySchema(id: 9, name: r'taskId', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 10,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _missionTaskExecutionRecordEstimateSize,
  serialize: _missionTaskExecutionRecordSerialize,
  deserialize: _missionTaskExecutionRecordDeserialize,
  deserializeProp: _missionTaskExecutionRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'executionId': IndexSchema(
      id: -4898329389316137742,
      name: r'executionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'executionId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'missionId': IndexSchema(
      id: 3765417159790828251,
      name: r'missionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'missionId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'taskId': IndexSchema(
      id: -6391211041487498726,
      name: r'taskId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'taskId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _missionTaskExecutionRecordGetId,
  getLinks: _missionTaskExecutionRecordGetLinks,
  attach: _missionTaskExecutionRecordAttach,
  version: '3.3.2',
);

int _missionTaskExecutionRecordEstimateSize(
  MissionTaskExecutionRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.executionId.length * 3;
  {
    final value = object.failureMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.missionId.length * 3;
  {
    final value = object.outputText;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  {
    final value = object.structuredResultReference;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.taskId.length * 3;
  return bytesCount;
}

void _missionTaskExecutionRecordSerialize(
  MissionTaskExecutionRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.executionId);
  writer.writeString(offsets[1], object.failureMessage);
  writer.writeDateTime(offsets[2], object.finishedAt);
  writer.writeString(offsets[3], object.missionId);
  writer.writeString(offsets[4], object.outputText);
  writer.writeDouble(offsets[5], object.progress);
  writer.writeDateTime(offsets[6], object.startedAt);
  writer.writeString(offsets[7], object.status);
  writer.writeString(offsets[8], object.structuredResultReference);
  writer.writeString(offsets[9], object.taskId);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

MissionTaskExecutionRecord _missionTaskExecutionRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MissionTaskExecutionRecord();
  object.executionId = reader.readString(offsets[0]);
  object.failureMessage = reader.readStringOrNull(offsets[1]);
  object.finishedAt = reader.readDateTimeOrNull(offsets[2]);
  object.id = id;
  object.missionId = reader.readString(offsets[3]);
  object.outputText = reader.readStringOrNull(offsets[4]);
  object.progress = reader.readDouble(offsets[5]);
  object.startedAt = reader.readDateTimeOrNull(offsets[6]);
  object.status = reader.readString(offsets[7]);
  object.structuredResultReference = reader.readStringOrNull(offsets[8]);
  object.taskId = reader.readString(offsets[9]);
  object.updatedAt = reader.readDateTime(offsets[10]);
  return object;
}

P _missionTaskExecutionRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDouble(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _missionTaskExecutionRecordGetId(MissionTaskExecutionRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _missionTaskExecutionRecordGetLinks(
  MissionTaskExecutionRecord object,
) {
  return [];
}

void _missionTaskExecutionRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  MissionTaskExecutionRecord object,
) {
  object.id = id;
}

extension MissionTaskExecutionRecordQueryWhereSort
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QWhere
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhere
  >
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MissionTaskExecutionRecordQueryWhere
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QWhereClause
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  executionIdEqualTo(String executionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'executionId',
          value: [executionId],
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  executionIdNotEqualTo(String executionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'executionId',
                lower: [],
                upper: [executionId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'executionId',
                lower: [executionId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'executionId',
                lower: [executionId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'executionId',
                lower: [],
                upper: [executionId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  missionIdEqualTo(String missionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'missionId', value: [missionId]),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  missionIdNotEqualTo(String missionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'missionId',
                lower: [],
                upper: [missionId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'missionId',
                lower: [missionId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'missionId',
                lower: [missionId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'missionId',
                lower: [],
                upper: [missionId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  taskIdEqualTo(String taskId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'taskId', value: [taskId]),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterWhereClause
  >
  taskIdNotEqualTo(String taskId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'taskId',
                lower: [],
                upper: [taskId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'taskId',
                lower: [taskId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'taskId',
                lower: [taskId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'taskId',
                lower: [],
                upper: [taskId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MissionTaskExecutionRecordQueryFilter
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QFilterCondition
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'executionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'executionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'executionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'executionId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  executionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'executionId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'failureMessage'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'failureMessage'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'failureMessage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'failureMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'failureMessage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'failureMessage', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  failureMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'failureMessage', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'finishedAt', value: value),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  finishedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'finishedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'missionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'missionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'missionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'missionId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  missionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'missionId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'outputText'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'outputText'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'outputText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'outputText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputText', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  outputTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'outputText', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  progressEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  progressGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  progressLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  progressBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'progress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startedAt', value: value),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  startedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'structuredResultReference'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'structuredResultReference'),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'structuredResultReference',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'structuredResultReference',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'structuredResultReference',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'structuredResultReference',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  structuredResultReferenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'structuredResultReference',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taskId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'taskId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'taskId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  taskIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'taskId', value: ''),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterFilterCondition
  >
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MissionTaskExecutionRecordQueryObject
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QFilterCondition
        > {}

extension MissionTaskExecutionRecordQueryLinks
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QFilterCondition
        > {}

extension MissionTaskExecutionRecordQuerySortBy
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QSortBy
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByExecutionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'executionId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByExecutionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'executionId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByFailureMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureMessage', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByFailureMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureMessage', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByMissionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missionId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByMissionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missionId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByOutputText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputText', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByOutputTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputText', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStructuredResultReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'structuredResultReference', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByStructuredResultReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'structuredResultReference', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByTaskId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByTaskIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MissionTaskExecutionRecordQuerySortThenBy
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QSortThenBy
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByExecutionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'executionId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByExecutionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'executionId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByFailureMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureMessage', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByFailureMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'failureMessage', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByMissionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missionId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByMissionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'missionId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByOutputText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputText', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByOutputTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputText', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStructuredResultReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'structuredResultReference', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByStructuredResultReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'structuredResultReference', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByTaskId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByTaskIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.desc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QAfterSortBy
  >
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension MissionTaskExecutionRecordQueryWhereDistinct
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QDistinct
        > {
  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByExecutionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'executionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByFailureMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'failureMessage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'finishedAt');
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByMissionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'missionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByOutputText({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'progress');
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startedAt');
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByStructuredResultReference({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'structuredResultReference',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByTaskId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taskId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    MissionTaskExecutionRecord,
    MissionTaskExecutionRecord,
    QDistinct
  >
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension MissionTaskExecutionRecordQueryProperty
    on
        QueryBuilder<
          MissionTaskExecutionRecord,
          MissionTaskExecutionRecord,
          QQueryProperty
        > {
  QueryBuilder<MissionTaskExecutionRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String, QQueryOperations>
  executionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'executionId');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String?, QQueryOperations>
  failureMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'failureMessage');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, DateTime?, QQueryOperations>
  finishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'finishedAt');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String, QQueryOperations>
  missionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'missionId');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String?, QQueryOperations>
  outputTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputText');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, double, QQueryOperations>
  progressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'progress');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, DateTime?, QQueryOperations>
  startedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startedAt');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String, QQueryOperations>
  statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String?, QQueryOperations>
  structuredResultReferenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'structuredResultReference');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, String, QQueryOperations>
  taskIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taskId');
    });
  }

  QueryBuilder<MissionTaskExecutionRecord, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
