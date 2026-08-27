// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_record.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const ChatMessageRecordSchema = Schema(
  name: r'ChatMessageRecord',
  id: 843036262504853700,
  properties: {
    r'attachmentId': PropertySchema(
      id: 0,
      name: r'attachmentId',
      type: IsarType.string,
    ),
    r'attachmentLocalFilePath': PropertySchema(
      id: 1,
      name: r'attachmentLocalFilePath',
      type: IsarType.string,
    ),
    r'attachmentMimeType': PropertySchema(
      id: 2,
      name: r'attachmentMimeType',
      type: IsarType.string,
    ),
    r'attachmentSourceMessageId': PropertySchema(
      id: 3,
      name: r'attachmentSourceMessageId',
      type: IsarType.string,
    ),
    r'attachmentSourcePrompt': PropertySchema(
      id: 4,
      name: r'attachmentSourcePrompt',
      type: IsarType.string,
    ),
    r'content': PropertySchema(id: 5, name: r'content', type: IsarType.string),
    r'createdAt': PropertySchema(
      id: 6,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isError': PropertySchema(id: 7, name: r'isError', type: IsarType.bool),
    r'messageId': PropertySchema(
      id: 8,
      name: r'messageId',
      type: IsarType.string,
    ),
    r'role': PropertySchema(id: 9, name: r'role', type: IsarType.string),
    r'storedAttachmentArtifactCreatedAt': PropertySchema(
      id: 10,
      name: r'storedAttachmentArtifactCreatedAt',
      type: IsarType.dateTime,
    ),
    r'storedAttachmentArtifactId': PropertySchema(
      id: 11,
      name: r'storedAttachmentArtifactId',
      type: IsarType.string,
    ),
    r'storedAttachmentArtifactType': PropertySchema(
      id: 12,
      name: r'storedAttachmentArtifactType',
      type: IsarType.string,
    ),
    r'storedAttachmentArtifactVersionCreatedAt': PropertySchema(
      id: 13,
      name: r'storedAttachmentArtifactVersionCreatedAt',
      type: IsarType.dateTime,
    ),
    r'storedAttachmentArtifactVersionId': PropertySchema(
      id: 14,
      name: r'storedAttachmentArtifactVersionId',
      type: IsarType.string,
    ),
    r'storedAttachmentRemoteStorageKey': PropertySchema(
      id: 15,
      name: r'storedAttachmentRemoteStorageKey',
      type: IsarType.string,
    ),
    r'storedAttachmentSourceArtifactVersionId': PropertySchema(
      id: 16,
      name: r'storedAttachmentSourceArtifactVersionId',
      type: IsarType.string,
    ),
    r'zStoredAttachmentArtifactVersionByteSize': PropertySchema(
      id: 17,
      name: r'zStoredAttachmentArtifactVersionByteSize',
      type: IsarType.long,
    ),
    r'zStoredAttachmentArtifactVersionFileName': PropertySchema(
      id: 18,
      name: r'zStoredAttachmentArtifactVersionFileName',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatMessageRecordEstimateSize,
  serialize: _chatMessageRecordSerialize,
  deserialize: _chatMessageRecordDeserialize,
  deserializeProp: _chatMessageRecordDeserializeProp,
);

int _chatMessageRecordEstimateSize(
  ChatMessageRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.attachmentId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentLocalFilePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentMimeType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentSourceMessageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.attachmentSourcePrompt;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  bytesCount += 3 + object.role.length * 3;
  {
    final value = object.storedAttachmentArtifactId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.storedAttachmentArtifactType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.storedAttachmentArtifactVersionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.storedAttachmentRemoteStorageKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.storedAttachmentSourceArtifactVersionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.zStoredAttachmentArtifactVersionFileName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chatMessageRecordSerialize(
  ChatMessageRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attachmentId);
  writer.writeString(offsets[1], object.attachmentLocalFilePath);
  writer.writeString(offsets[2], object.attachmentMimeType);
  writer.writeString(offsets[3], object.attachmentSourceMessageId);
  writer.writeString(offsets[4], object.attachmentSourcePrompt);
  writer.writeString(offsets[5], object.content);
  writer.writeDateTime(offsets[6], object.createdAt);
  writer.writeBool(offsets[7], object.isError);
  writer.writeString(offsets[8], object.messageId);
  writer.writeString(offsets[9], object.role);
  writer.writeDateTime(offsets[10], object.storedAttachmentArtifactCreatedAt);
  writer.writeString(offsets[11], object.storedAttachmentArtifactId);
  writer.writeString(offsets[12], object.storedAttachmentArtifactType);
  writer.writeDateTime(
    offsets[13],
    object.storedAttachmentArtifactVersionCreatedAt,
  );
  writer.writeString(offsets[14], object.storedAttachmentArtifactVersionId);
  writer.writeString(offsets[15], object.storedAttachmentRemoteStorageKey);
  writer.writeString(
    offsets[16],
    object.storedAttachmentSourceArtifactVersionId,
  );
  writer.writeLong(
    offsets[17],
    object.zStoredAttachmentArtifactVersionByteSize,
  );
  writer.writeString(
    offsets[18],
    object.zStoredAttachmentArtifactVersionFileName,
  );
}

ChatMessageRecord _chatMessageRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatMessageRecord();
  object.attachmentId = reader.readStringOrNull(offsets[0]);
  object.attachmentLocalFilePath = reader.readStringOrNull(offsets[1]);
  object.attachmentMimeType = reader.readStringOrNull(offsets[2]);
  object.attachmentSourceMessageId = reader.readStringOrNull(offsets[3]);
  object.attachmentSourcePrompt = reader.readStringOrNull(offsets[4]);
  object.content = reader.readString(offsets[5]);
  object.createdAt = reader.readDateTime(offsets[6]);
  object.isError = reader.readBool(offsets[7]);
  object.messageId = reader.readString(offsets[8]);
  object.role = reader.readString(offsets[9]);
  object.storedAttachmentArtifactCreatedAt = reader.readDateTimeOrNull(
    offsets[10],
  );
  object.storedAttachmentArtifactId = reader.readStringOrNull(offsets[11]);
  object.storedAttachmentArtifactType = reader.readStringOrNull(offsets[12]);
  object.storedAttachmentArtifactVersionCreatedAt = reader.readDateTimeOrNull(
    offsets[13],
  );
  object.storedAttachmentArtifactVersionId = reader.readStringOrNull(
    offsets[14],
  );
  object.storedAttachmentRemoteStorageKey = reader.readStringOrNull(
    offsets[15],
  );
  object.storedAttachmentSourceArtifactVersionId = reader.readStringOrNull(
    offsets[16],
  );
  object.zStoredAttachmentArtifactVersionByteSize = reader.readLongOrNull(
    offsets[17],
  );
  object.zStoredAttachmentArtifactVersionFileName = reader.readStringOrNull(
    offsets[18],
  );
  return object;
}

P _chatMessageRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readLongOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension ChatMessageRecordQueryFilter
    on QueryBuilder<ChatMessageRecord, ChatMessageRecord, QFilterCondition> {
  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'attachmentId'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'attachmentId'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachmentId', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'attachmentId', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'attachmentLocalFilePath'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'attachmentLocalFilePath'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentLocalFilePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentLocalFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentLocalFilePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentLocalFilePath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentLocalFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'attachmentLocalFilePath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'attachmentMimeType'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'attachmentMimeType'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentMimeType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentMimeType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentMimeType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachmentMimeType', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentMimeTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'attachmentMimeType', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'attachmentSourceMessageId'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'attachmentSourceMessageId'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentSourceMessageId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentSourceMessageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentSourceMessageId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentSourceMessageId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourceMessageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'attachmentSourceMessageId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'attachmentSourcePrompt'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'attachmentSourcePrompt'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentSourcePrompt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentSourcePrompt',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentSourcePrompt',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachmentSourcePrompt', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  attachmentSourcePromptIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'attachmentSourcePrompt',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  isErrorEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isError', value: value),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'messageId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'messageId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'messageId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'messageId', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'messageId', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'role',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'role',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'role', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  roleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'role', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'storedAttachmentArtifactCreatedAt',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentArtifactCreatedAt',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentArtifactCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentArtifactCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactCreatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentArtifactCreatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'storedAttachmentArtifactId'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentArtifactId',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentArtifactId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storedAttachmentArtifactId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storedAttachmentArtifactId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'storedAttachmentArtifactId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'storedAttachmentArtifactType'),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentArtifactType',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentArtifactType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storedAttachmentArtifactType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storedAttachmentArtifactType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactType',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'storedAttachmentArtifactType',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'storedAttachmentArtifactVersionCreatedAt',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentArtifactVersionCreatedAt',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactVersionCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentArtifactVersionCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentArtifactVersionCreatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionCreatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentArtifactVersionCreatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'storedAttachmentArtifactVersionId',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentArtifactVersionId',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentArtifactVersionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storedAttachmentArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storedAttachmentArtifactVersionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentArtifactVersionId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentArtifactVersionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'storedAttachmentArtifactVersionId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'storedAttachmentRemoteStorageKey',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentRemoteStorageKey',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentRemoteStorageKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storedAttachmentRemoteStorageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storedAttachmentRemoteStorageKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentRemoteStorageKey',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentRemoteStorageKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'storedAttachmentRemoteStorageKey',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'storedAttachmentSourceArtifactVersionId',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'storedAttachmentSourceArtifactVersionId',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'storedAttachmentSourceArtifactVersionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'storedAttachmentSourceArtifactVersionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  storedAttachmentSourceArtifactVersionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'storedAttachmentSourceArtifactVersionId',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'zStoredAttachmentArtifactVersionByteSize',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'zStoredAttachmentArtifactVersionByteSize',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'zStoredAttachmentArtifactVersionByteSize',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'zStoredAttachmentArtifactVersionByteSize',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'zStoredAttachmentArtifactVersionByteSize',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionByteSizeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'zStoredAttachmentArtifactVersionByteSize',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(
          property: r'zStoredAttachmentArtifactVersionFileName',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(
          property: r'zStoredAttachmentArtifactVersionFileName',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'zStoredAttachmentArtifactVersionFileName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'zStoredAttachmentArtifactVersionFileName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageRecord, ChatMessageRecord, QAfterFilterCondition>
  zStoredAttachmentArtifactVersionFileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'zStoredAttachmentArtifactVersionFileName',
          value: '',
        ),
      );
    });
  }
}

extension ChatMessageRecordQueryObject
    on QueryBuilder<ChatMessageRecord, ChatMessageRecord, QFilterCondition> {}
