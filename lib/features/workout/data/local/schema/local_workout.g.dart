// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_workout.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalWorkoutCollection on Isar {
  IsarCollection<LocalWorkout> get localWorkouts => this.collection();
}

const LocalWorkoutSchema = CollectionSchema(
  name: r'LocalWorkout',
  id: -3038458621972263742,
  properties: {
    r'activityType': PropertySchema(
      id: 0,
      name: r'activityType',
      type: IsarType.string,
    ),
    r'avgSpeedKmh': PropertySchema(
      id: 1,
      name: r'avgSpeedKmh',
      type: IsarType.double,
    ),
    r'caloriesKcal': PropertySchema(
      id: 2,
      name: r'caloriesKcal',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'distanceKm': PropertySchema(
      id: 4,
      name: r'distanceKm',
      type: IsarType.double,
    ),
    r'durationSec': PropertySchema(
      id: 5,
      name: r'durationSec',
      type: IsarType.long,
    ),
    r'endedAt': PropertySchema(
      id: 6,
      name: r'endedAt',
      type: IsarType.dateTime,
    ),
    r'filteredRouteJson': PropertySchema(
      id: 7,
      name: r'filteredRouteJson',
      type: IsarType.string,
    ),
    r'gpsAnalysisJson': PropertySchema(
      id: 8,
      name: r'gpsAnalysisJson',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 9,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'lapSplitsJson': PropertySchema(
      id: 10,
      name: r'lapSplitsJson',
      type: IsarType.string,
    ),
    r'matchedDistanceKm': PropertySchema(
      id: 11,
      name: r'matchedDistanceKm',
      type: IsarType.double,
    ),
    r'matchedRouteJson': PropertySchema(
      id: 12,
      name: r'matchedRouteJson',
      type: IsarType.string,
    ),
    r'mode': PropertySchema(
      id: 13,
      name: r'mode',
      type: IsarType.string,
    ),
    r'movingTimeSec': PropertySchema(
      id: 14,
      name: r'movingTimeSec',
      type: IsarType.long,
    ),
    r'routeDistanceSource': PropertySchema(
      id: 15,
      name: r'routeDistanceSource',
      type: IsarType.string,
    ),
    r'routeMatchConfidence': PropertySchema(
      id: 16,
      name: r'routeMatchConfidence',
      type: IsarType.double,
    ),
    r'routeMatchMetricsJson': PropertySchema(
      id: 17,
      name: r'routeMatchMetricsJson',
      type: IsarType.string,
    ),
    r'routeMatchStatus': PropertySchema(
      id: 18,
      name: r'routeMatchStatus',
      type: IsarType.string,
    ),
    r'sessionId': PropertySchema(
      id: 19,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'startedAt': PropertySchema(
      id: 20,
      name: r'startedAt',
      type: IsarType.dateTime,
    ),
    r'steps': PropertySchema(
      id: 21,
      name: r'steps',
      type: IsarType.long,
    ),
    r'userId': PropertySchema(
      id: 22,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _localWorkoutEstimateSize,
  serialize: _localWorkoutSerialize,
  deserialize: _localWorkoutDeserialize,
  deserializeProp: _localWorkoutDeserializeProp,
  idName: r'id',
  indexes: {
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: true,
      replace: true,
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
  getId: _localWorkoutGetId,
  getLinks: _localWorkoutGetLinks,
  attach: _localWorkoutAttach,
  version: '3.1.0+1',
);

int _localWorkoutEstimateSize(
  LocalWorkout object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.activityType.length * 3;
  bytesCount += 3 + object.filteredRouteJson.length * 3;
  bytesCount += 3 + object.gpsAnalysisJson.length * 3;
  bytesCount += 3 + object.lapSplitsJson.length * 3;
  bytesCount += 3 + object.matchedRouteJson.length * 3;
  bytesCount += 3 + object.mode.length * 3;
  bytesCount += 3 + object.routeDistanceSource.length * 3;
  bytesCount += 3 + object.routeMatchMetricsJson.length * 3;
  bytesCount += 3 + object.routeMatchStatus.length * 3;
  bytesCount += 3 + object.sessionId.length * 3;
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _localWorkoutSerialize(
  LocalWorkout object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.activityType);
  writer.writeDouble(offsets[1], object.avgSpeedKmh);
  writer.writeDouble(offsets[2], object.caloriesKcal);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDouble(offsets[4], object.distanceKm);
  writer.writeLong(offsets[5], object.durationSec);
  writer.writeDateTime(offsets[6], object.endedAt);
  writer.writeString(offsets[7], object.filteredRouteJson);
  writer.writeString(offsets[8], object.gpsAnalysisJson);
  writer.writeBool(offsets[9], object.isSynced);
  writer.writeString(offsets[10], object.lapSplitsJson);
  writer.writeDouble(offsets[11], object.matchedDistanceKm);
  writer.writeString(offsets[12], object.matchedRouteJson);
  writer.writeString(offsets[13], object.mode);
  writer.writeLong(offsets[14], object.movingTimeSec);
  writer.writeString(offsets[15], object.routeDistanceSource);
  writer.writeDouble(offsets[16], object.routeMatchConfidence);
  writer.writeString(offsets[17], object.routeMatchMetricsJson);
  writer.writeString(offsets[18], object.routeMatchStatus);
  writer.writeString(offsets[19], object.sessionId);
  writer.writeDateTime(offsets[20], object.startedAt);
  writer.writeLong(offsets[21], object.steps);
  writer.writeString(offsets[22], object.userId);
}

LocalWorkout _localWorkoutDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalWorkout();
  object.activityType = reader.readString(offsets[0]);
  object.avgSpeedKmh = reader.readDouble(offsets[1]);
  object.caloriesKcal = reader.readDouble(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.distanceKm = reader.readDouble(offsets[4]);
  object.durationSec = reader.readLong(offsets[5]);
  object.endedAt = reader.readDateTime(offsets[6]);
  object.filteredRouteJson = reader.readString(offsets[7]);
  object.gpsAnalysisJson = reader.readString(offsets[8]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[9]);
  object.lapSplitsJson = reader.readString(offsets[10]);
  object.matchedDistanceKm = reader.readDoubleOrNull(offsets[11]);
  object.matchedRouteJson = reader.readString(offsets[12]);
  object.mode = reader.readString(offsets[13]);
  object.movingTimeSec = reader.readLong(offsets[14]);
  object.routeDistanceSource = reader.readString(offsets[15]);
  object.routeMatchConfidence = reader.readDoubleOrNull(offsets[16]);
  object.routeMatchMetricsJson = reader.readString(offsets[17]);
  object.routeMatchStatus = reader.readString(offsets[18]);
  object.sessionId = reader.readString(offsets[19]);
  object.startedAt = reader.readDateTime(offsets[20]);
  object.steps = reader.readLong(offsets[21]);
  object.userId = reader.readString(offsets[22]);
  return object;
}

P _localWorkoutDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readDoubleOrNull(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readDoubleOrNull(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readString(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readDateTime(offset)) as P;
    case 21:
      return (reader.readLong(offset)) as P;
    case 22:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localWorkoutGetId(LocalWorkout object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localWorkoutGetLinks(LocalWorkout object) {
  return [];
}

void _localWorkoutAttach(
    IsarCollection<dynamic> col, Id id, LocalWorkout object) {
  object.id = id;
}

extension LocalWorkoutByIndex on IsarCollection<LocalWorkout> {
  Future<LocalWorkout?> getBySessionId(String sessionId) {
    return getByIndex(r'sessionId', [sessionId]);
  }

  LocalWorkout? getBySessionIdSync(String sessionId) {
    return getByIndexSync(r'sessionId', [sessionId]);
  }

  Future<bool> deleteBySessionId(String sessionId) {
    return deleteByIndex(r'sessionId', [sessionId]);
  }

  bool deleteBySessionIdSync(String sessionId) {
    return deleteByIndexSync(r'sessionId', [sessionId]);
  }

  Future<List<LocalWorkout?>> getAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'sessionId', values);
  }

  List<LocalWorkout?> getAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sessionId', values);
  }

  Future<int> deleteAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sessionId', values);
  }

  int deleteAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sessionId', values);
  }

  Future<Id> putBySessionId(LocalWorkout object) {
    return putByIndex(r'sessionId', object);
  }

  Id putBySessionIdSync(LocalWorkout object, {bool saveLinks = true}) {
    return putByIndexSync(r'sessionId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySessionId(List<LocalWorkout> objects) {
    return putAllByIndex(r'sessionId', objects);
  }

  List<Id> putAllBySessionIdSync(List<LocalWorkout> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sessionId', objects, saveLinks: saveLinks);
  }
}

extension LocalWorkoutQueryWhereSort
    on QueryBuilder<LocalWorkout, LocalWorkout, QWhere> {
  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalWorkoutQueryWhere
    on QueryBuilder<LocalWorkout, LocalWorkout, QWhereClause> {
  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause> sessionIdEqualTo(
      String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [sessionId],
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterWhereClause>
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

extension LocalWorkoutQueryFilter
    on QueryBuilder<LocalWorkout, LocalWorkout, QFilterCondition> {
  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activityType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'activityType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'activityType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activityType',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      activityTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'activityType',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      avgSpeedKmhEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'avgSpeedKmh',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      avgSpeedKmhGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'avgSpeedKmh',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      avgSpeedKmhLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'avgSpeedKmh',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      avgSpeedKmhBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'avgSpeedKmh',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      caloriesKcalEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'caloriesKcal',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      caloriesKcalGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'caloriesKcal',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      caloriesKcalLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'caloriesKcal',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      caloriesKcalBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'caloriesKcal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      distanceKmEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'distanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      distanceKmGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'distanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      distanceKmLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'distanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      distanceKmBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'distanceKm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      durationSecEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      durationSecGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      durationSecLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'durationSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      durationSecBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'durationSec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      endedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      endedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      endedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      endedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'filteredRouteJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'filteredRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'filteredRouteJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filteredRouteJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      filteredRouteJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'filteredRouteJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gpsAnalysisJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'gpsAnalysisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'gpsAnalysisJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gpsAnalysisJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      gpsAnalysisJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'gpsAnalysisJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lapSplitsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lapSplitsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lapSplitsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lapSplitsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      lapSplitsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lapSplitsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'matchedDistanceKm',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'matchedDistanceKm',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matchedDistanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'matchedDistanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'matchedDistanceKm',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedDistanceKmBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'matchedDistanceKm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'matchedRouteJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'matchedRouteJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'matchedRouteJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'matchedRouteJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      matchedRouteJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'matchedRouteJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      modeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      modeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> modeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      modeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mode',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      modeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mode',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      movingTimeSecEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'movingTimeSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      movingTimeSecGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'movingTimeSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      movingTimeSecLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'movingTimeSec',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      movingTimeSecBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'movingTimeSec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routeDistanceSource',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routeDistanceSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routeDistanceSource',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeDistanceSource',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeDistanceSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routeDistanceSource',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'routeMatchConfidence',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'routeMatchConfidence',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeMatchConfidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routeMatchConfidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routeMatchConfidence',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchConfidenceBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routeMatchConfidence',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routeMatchMetricsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routeMatchMetricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routeMatchMetricsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeMatchMetricsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchMetricsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routeMatchMetricsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'routeMatchStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'routeMatchStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'routeMatchStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'routeMatchStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      routeMatchStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'routeMatchStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      sessionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      sessionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      startedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      startedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      startedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      startedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> stepsEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      stepsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> stepsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'steps',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> stepsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'steps',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> userIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition> userIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension LocalWorkoutQueryObject
    on QueryBuilder<LocalWorkout, LocalWorkout, QFilterCondition> {}

extension LocalWorkoutQueryLinks
    on QueryBuilder<LocalWorkout, LocalWorkout, QFilterCondition> {}

extension LocalWorkoutQuerySortBy
    on QueryBuilder<LocalWorkout, LocalWorkout, QSortBy> {
  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByActivityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByActivityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByAvgSpeedKmh() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgSpeedKmh', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByAvgSpeedKmhDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgSpeedKmh', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByCaloriesKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesKcal', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByCaloriesKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesKcal', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceKm', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByDistanceKmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceKm', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByDurationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByEndedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByEndedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByFilteredRouteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filteredRouteJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByFilteredRouteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filteredRouteJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByGpsAnalysisJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gpsAnalysisJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByGpsAnalysisJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gpsAnalysisJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByLapSplitsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lapSplitsJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByLapSplitsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lapSplitsJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByMatchedDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedDistanceKm', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByMatchedDistanceKmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedDistanceKm', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByMatchedRouteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedRouteJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByMatchedRouteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedRouteJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByMovingTimeSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movingTimeSec', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByMovingTimeSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movingTimeSec', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteDistanceSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDistanceSource', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteDistanceSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDistanceSource', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchConfidence', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchConfidence', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchMetricsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchMetricsJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchMetricsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchMetricsJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchStatus', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      sortByRouteMatchStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchStatus', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByStepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension LocalWorkoutQuerySortThenBy
    on QueryBuilder<LocalWorkout, LocalWorkout, QSortThenBy> {
  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByActivityType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByActivityTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activityType', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByAvgSpeedKmh() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgSpeedKmh', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByAvgSpeedKmhDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'avgSpeedKmh', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByCaloriesKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesKcal', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByCaloriesKcalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'caloriesKcal', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceKm', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByDistanceKmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distanceKm', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByDurationSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationSec', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByEndedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByEndedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByFilteredRouteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filteredRouteJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByFilteredRouteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filteredRouteJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByGpsAnalysisJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gpsAnalysisJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByGpsAnalysisJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gpsAnalysisJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByLapSplitsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lapSplitsJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByLapSplitsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lapSplitsJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByMatchedDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedDistanceKm', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByMatchedDistanceKmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedDistanceKm', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByMatchedRouteJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedRouteJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByMatchedRouteJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchedRouteJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByMovingTimeSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movingTimeSec', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByMovingTimeSecDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'movingTimeSec', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteDistanceSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDistanceSource', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteDistanceSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeDistanceSource', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchConfidence', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchConfidence', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchMetricsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchMetricsJson', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchMetricsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchMetricsJson', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchStatus', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy>
      thenByRouteMatchStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'routeMatchStatus', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByStepsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'steps', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QAfterSortBy> thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension LocalWorkoutQueryWhereDistinct
    on QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> {
  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByActivityType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activityType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByAvgSpeedKmh() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'avgSpeedKmh');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByCaloriesKcal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'caloriesKcal');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'distanceKm');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByDurationSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationSec');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByEndedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endedAt');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByFilteredRouteJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filteredRouteJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByGpsAnalysisJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gpsAnalysisJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByLapSplitsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lapSplitsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByMatchedDistanceKm() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'matchedDistanceKm');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByMatchedRouteJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'matchedRouteJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByMode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByMovingTimeSec() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'movingTimeSec');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByRouteDistanceSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routeDistanceSource',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByRouteMatchConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routeMatchConfidence');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByRouteMatchMetricsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routeMatchMetricsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct>
      distinctByRouteMatchStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'routeMatchStatus',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctBySessionId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startedAt');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctBySteps() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'steps');
    });
  }

  QueryBuilder<LocalWorkout, LocalWorkout, QDistinct> distinctByUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension LocalWorkoutQueryProperty
    on QueryBuilder<LocalWorkout, LocalWorkout, QQueryProperty> {
  QueryBuilder<LocalWorkout, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations> activityTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activityType');
    });
  }

  QueryBuilder<LocalWorkout, double, QQueryOperations> avgSpeedKmhProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'avgSpeedKmh');
    });
  }

  QueryBuilder<LocalWorkout, double, QQueryOperations> caloriesKcalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'caloriesKcal');
    });
  }

  QueryBuilder<LocalWorkout, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<LocalWorkout, double, QQueryOperations> distanceKmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'distanceKm');
    });
  }

  QueryBuilder<LocalWorkout, int, QQueryOperations> durationSecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationSec');
    });
  }

  QueryBuilder<LocalWorkout, DateTime, QQueryOperations> endedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endedAt');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      filteredRouteJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filteredRouteJson');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      gpsAnalysisJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gpsAnalysisJson');
    });
  }

  QueryBuilder<LocalWorkout, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations> lapSplitsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lapSplitsJson');
    });
  }

  QueryBuilder<LocalWorkout, double?, QQueryOperations>
      matchedDistanceKmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'matchedDistanceKm');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      matchedRouteJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'matchedRouteJson');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations> modeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mode');
    });
  }

  QueryBuilder<LocalWorkout, int, QQueryOperations> movingTimeSecProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'movingTimeSec');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      routeDistanceSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routeDistanceSource');
    });
  }

  QueryBuilder<LocalWorkout, double?, QQueryOperations>
      routeMatchConfidenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routeMatchConfidence');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      routeMatchMetricsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routeMatchMetricsJson');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations>
      routeMatchStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'routeMatchStatus');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations> sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<LocalWorkout, DateTime, QQueryOperations> startedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startedAt');
    });
  }

  QueryBuilder<LocalWorkout, int, QQueryOperations> stepsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'steps');
    });
  }

  QueryBuilder<LocalWorkout, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
