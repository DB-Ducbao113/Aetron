// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_step_interval.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalStepIntervalCollection on Isar {
  IsarCollection<LocalStepInterval> get localStepIntervals => this.collection();
}

const LocalStepIntervalSchema = CollectionSchema(
  name: r'LocalStepInterval',
  id: 131370035101032021,
  properties: {
    r'deviceSource': PropertySchema(
      id: 0,
      name: r'deviceSource',
      type: IsarType.string,
    ),
    r'intervalEnd': PropertySchema(
      id: 1,
      name: r'intervalEnd',
      type: IsarType.dateTime,
    ),
    r'intervalStart': PropertySchema(
      id: 2,
      name: r'intervalStart',
      type: IsarType.dateTime,
    ),
    r'isSynced': PropertySchema(
      id: 3,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'sessionId': PropertySchema(
      id: 4,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'stepsCount': PropertySchema(
      id: 5,
      name: r'stepsCount',
      type: IsarType.long,
    )
  },
  estimateSize: _localStepIntervalEstimateSize,
  serialize: _localStepIntervalSerialize,
  deserialize: _localStepIntervalDeserialize,
  deserializeProp: _localStepIntervalDeserializeProp,
  idName: r'id',
  indexes: {
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sessionId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _localStepIntervalGetId,
  getLinks: _localStepIntervalGetLinks,
  attach: _localStepIntervalAttach,
  version: '3.1.0+1',
);

int _localStepIntervalEstimateSize(
  LocalStepInterval object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.deviceSource;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sessionId.length * 3;
  return bytesCount;
}

void _localStepIntervalSerialize(
  LocalStepInterval object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.deviceSource);
  writer.writeDateTime(offsets[1], object.intervalEnd);
  writer.writeDateTime(offsets[2], object.intervalStart);
  writer.writeBool(offsets[3], object.isSynced);
  writer.writeString(offsets[4], object.sessionId);
  writer.writeLong(offsets[5], object.stepsCount);
}

LocalStepInterval _localStepIntervalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalStepInterval();
  object.deviceSource = reader.readStringOrNull(offsets[0]);
  object.id = id;
  object.intervalEnd = reader.readDateTime(offsets[1]);
  object.intervalStart = reader.readDateTime(offsets[2]);
  object.isSynced = reader.readBool(offsets[3]);
  object.sessionId = reader.readString(offsets[4]);
  object.stepsCount = reader.readLong(offsets[5]);
  return object;
}

P _localStepIntervalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localStepIntervalGetId(LocalStepInterval object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localStepIntervalGetLinks(
    LocalStepInterval object) {
  return [];
}

void _localStepIntervalAttach(
    IsarCollection<dynamic> col, Id id, LocalStepInterval object) {
  object.id = id;
}

extension LocalStepIntervalQueryWhereSort
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QWhere> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalStepIntervalQueryWhere
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QWhereClause> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
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

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      sessionIdEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [sessionId],
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterWhereClause>
      sessionIdNotEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension LocalStepIntervalQueryFilter
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QFilterCondition> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deviceSource',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deviceSource',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceSource',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceSource',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceSource',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      deviceSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceSource',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalEndEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intervalEnd',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalEndGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intervalEnd',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalEndLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intervalEnd',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalEndBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intervalEnd',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalStartEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intervalStart',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalStartGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intervalStart',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalStartLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intervalStart',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      intervalStartBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intervalStart',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      stepsCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stepsCount',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      stepsCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stepsCount',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      stepsCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stepsCount',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterFilterCondition>
      stepsCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stepsCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension LocalStepIntervalQueryObject
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QFilterCondition> {}

extension LocalStepIntervalQueryLinks
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QFilterCondition> {}

extension LocalStepIntervalQuerySortBy
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QSortBy> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByDeviceSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceSource', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByDeviceSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceSource', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIntervalEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalEnd', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIntervalEndDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalEnd', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIntervalStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalStart', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIntervalStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalStart', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByStepsCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepsCount', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      sortByStepsCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepsCount', Sort.desc);
    });
  }
}

extension LocalStepIntervalQuerySortThenBy
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QSortThenBy> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByDeviceSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceSource', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByDeviceSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceSource', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIntervalEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalEnd', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIntervalEndDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalEnd', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIntervalStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalStart', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIntervalStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalStart', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByStepsCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepsCount', Sort.asc);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QAfterSortBy>
      thenByStepsCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepsCount', Sort.desc);
    });
  }
}

extension LocalStepIntervalQueryWhereDistinct
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct> {
  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctByDeviceSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceSource', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctByIntervalEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intervalEnd');
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctByIntervalStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intervalStart');
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctBySessionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalStepInterval, LocalStepInterval, QDistinct>
      distinctByStepsCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stepsCount');
    });
  }
}

extension LocalStepIntervalQueryProperty
    on QueryBuilder<LocalStepInterval, LocalStepInterval, QQueryProperty> {
  QueryBuilder<LocalStepInterval, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalStepInterval, String?, QQueryOperations>
      deviceSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceSource');
    });
  }

  QueryBuilder<LocalStepInterval, DateTime, QQueryOperations>
      intervalEndProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intervalEnd');
    });
  }

  QueryBuilder<LocalStepInterval, DateTime, QQueryOperations>
      intervalStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intervalStart');
    });
  }

  QueryBuilder<LocalStepInterval, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalStepInterval, String, QQueryOperations>
      sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<LocalStepInterval, int, QQueryOperations> stepsCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stepsCount');
    });
  }
}
