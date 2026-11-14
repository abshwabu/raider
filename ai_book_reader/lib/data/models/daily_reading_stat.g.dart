// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_reading_stat.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDailyReadingStatCollection on Isar {
  IsarCollection<DailyReadingStat> get dailyReadingStats => this.collection();
}

const DailyReadingStatSchema = CollectionSchema(
  name: r'DailyReadingStat',
  id: -7785768265199471293,
  properties: {
    r'activeSeconds': PropertySchema(
      id: 0,
      name: r'activeSeconds',
      type: IsarType.long,
    ),
    r'bookIds': PropertySchema(
      id: 1,
      name: r'bookIds',
      type: IsarType.longList,
    ),
    r'date': PropertySchema(
      id: 2,
      name: r'date',
      type: IsarType.string,
    ),
    r'goalMetAt': PropertySchema(
      id: 3,
      name: r'goalMetAt',
      type: IsarType.dateTime,
    ),
    r'goalMinutes': PropertySchema(
      id: 4,
      name: r'goalMinutes',
      type: IsarType.long,
    ),
    r'isGoalMet': PropertySchema(
      id: 5,
      name: r'isGoalMet',
      type: IsarType.bool,
    ),
    r'pagesRead': PropertySchema(
      id: 6,
      name: r'pagesRead',
      type: IsarType.long,
    ),
    r'sessionCount': PropertySchema(
      id: 7,
      name: r'sessionCount',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _dailyReadingStatEstimateSize,
  serialize: _dailyReadingStatSerialize,
  deserialize: _dailyReadingStatDeserialize,
  deserializeProp: _dailyReadingStatDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _dailyReadingStatGetId,
  getLinks: _dailyReadingStatGetLinks,
  attach: _dailyReadingStatAttach,
  version: '3.1.0+1',
);

int _dailyReadingStatEstimateSize(
  DailyReadingStat object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.bookIds.length * 8;
  bytesCount += 3 + object.date.length * 3;
  return bytesCount;
}

void _dailyReadingStatSerialize(
  DailyReadingStat object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.activeSeconds);
  writer.writeLongList(offsets[1], object.bookIds);
  writer.writeString(offsets[2], object.date);
  writer.writeDateTime(offsets[3], object.goalMetAt);
  writer.writeLong(offsets[4], object.goalMinutes);
  writer.writeBool(offsets[5], object.isGoalMet);
  writer.writeLong(offsets[6], object.pagesRead);
  writer.writeLong(offsets[7], object.sessionCount);
  writer.writeDateTime(offsets[8], object.updatedAt);
}

DailyReadingStat _dailyReadingStatDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DailyReadingStat();
  object.activeSeconds = reader.readLong(offsets[0]);
  object.bookIds = reader.readLongList(offsets[1]) ?? [];
  object.date = reader.readString(offsets[2]);
  object.goalMetAt = reader.readDateTimeOrNull(offsets[3]);
  object.goalMinutes = reader.readLong(offsets[4]);
  object.id = id;
  object.isGoalMet = reader.readBool(offsets[5]);
  object.pagesRead = reader.readLong(offsets[6]);
  object.sessionCount = reader.readLong(offsets[7]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[8]);
  return object;
}

P _dailyReadingStatDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLongList(offset) ?? []) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dailyReadingStatGetId(DailyReadingStat object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _dailyReadingStatGetLinks(DailyReadingStat object) {
  return [];
}

void _dailyReadingStatAttach(
    IsarCollection<dynamic> col, Id id, DailyReadingStat object) {
  object.id = id;
}

extension DailyReadingStatByIndex on IsarCollection<DailyReadingStat> {
  Future<DailyReadingStat?> getByDate(String date) {
    return getByIndex(r'date', [date]);
  }

  DailyReadingStat? getByDateSync(String date) {
    return getByIndexSync(r'date', [date]);
  }

  Future<bool> deleteByDate(String date) {
    return deleteByIndex(r'date', [date]);
  }

  bool deleteByDateSync(String date) {
    return deleteByIndexSync(r'date', [date]);
  }

  Future<List<DailyReadingStat?>> getAllByDate(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndex(r'date', values);
  }

  List<DailyReadingStat?> getAllByDateSync(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'date', values);
  }

  Future<int> deleteAllByDate(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'date', values);
  }

  int deleteAllByDateSync(List<String> dateValues) {
    final values = dateValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'date', values);
  }

  Future<Id> putByDate(DailyReadingStat object) {
    return putByIndex(r'date', object);
  }

  Id putByDateSync(DailyReadingStat object, {bool saveLinks = true}) {
    return putByIndexSync(r'date', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDate(List<DailyReadingStat> objects) {
    return putAllByIndex(r'date', objects);
  }

  List<Id> putAllByDateSync(List<DailyReadingStat> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'date', objects, saveLinks: saveLinks);
  }
}

extension DailyReadingStatQueryWhereSort
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QWhere> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DailyReadingStatQueryWhere
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QWhereClause> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause>
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

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause> idBetween(
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

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause>
      dateEqualTo(String date) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'date',
        value: [date],
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterWhereClause>
      dateNotEqualTo(String date) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ));
      }
    });
  }
}

extension DailyReadingStatQueryFilter
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QFilterCondition> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      activeSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      activeSecondsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activeSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      activeSecondsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activeSeconds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      activeSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activeSeconds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bookIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bookIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bookIds',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bookIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      bookIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'bookIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'date',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'goalMetAt',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'goalMetAt',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'goalMetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'goalMetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'goalMetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMetAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'goalMetAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMinutesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'goalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMinutesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'goalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMinutesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'goalMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      goalMinutesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'goalMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
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

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
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

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
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

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      isGoalMetEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isGoalMet',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      pagesReadEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pagesRead',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      pagesReadGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pagesRead',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      pagesReadLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pagesRead',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      pagesReadBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pagesRead',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      sessionCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      sessionCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      sessionCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionCount',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      sessionCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DailyReadingStatQueryObject
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QFilterCondition> {}

extension DailyReadingStatQueryLinks
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QFilterCondition> {}

extension DailyReadingStatQuerySortBy
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QSortBy> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByActiveSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeSeconds', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByActiveSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeSeconds', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByGoalMetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMetAt', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByGoalMetAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMetAt', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByGoalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMinutes', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByGoalMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMinutes', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByIsGoalMet() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGoalMet', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByIsGoalMetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGoalMet', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByPagesRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagesRead', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByPagesReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagesRead', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortBySessionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionCount', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortBySessionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionCount', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DailyReadingStatQuerySortThenBy
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QSortThenBy> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByActiveSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeSeconds', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByActiveSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeSeconds', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByGoalMetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMetAt', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByGoalMetAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMetAt', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByGoalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMinutes', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByGoalMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'goalMinutes', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByIsGoalMet() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGoalMet', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByIsGoalMetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isGoalMet', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByPagesRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagesRead', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByPagesReadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagesRead', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenBySessionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionCount', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenBySessionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionCount', Sort.desc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DailyReadingStatQueryWhereDistinct
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct> {
  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByActiveSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeSeconds');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByBookIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bookIds');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct> distinctByDate(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByGoalMetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'goalMetAt');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByGoalMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'goalMinutes');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByIsGoalMet() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isGoalMet');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByPagesRead() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pagesRead');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctBySessionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionCount');
    });
  }

  QueryBuilder<DailyReadingStat, DailyReadingStat, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension DailyReadingStatQueryProperty
    on QueryBuilder<DailyReadingStat, DailyReadingStat, QQueryProperty> {
  QueryBuilder<DailyReadingStat, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DailyReadingStat, int, QQueryOperations>
      activeSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeSeconds');
    });
  }

  QueryBuilder<DailyReadingStat, List<int>, QQueryOperations>
      bookIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bookIds');
    });
  }

  QueryBuilder<DailyReadingStat, String, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<DailyReadingStat, DateTime?, QQueryOperations>
      goalMetAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'goalMetAt');
    });
  }

  QueryBuilder<DailyReadingStat, int, QQueryOperations> goalMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'goalMinutes');
    });
  }

  QueryBuilder<DailyReadingStat, bool, QQueryOperations> isGoalMetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isGoalMet');
    });
  }

  QueryBuilder<DailyReadingStat, int, QQueryOperations> pagesReadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pagesRead');
    });
  }

  QueryBuilder<DailyReadingStat, int, QQueryOperations> sessionCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionCount');
    });
  }

  QueryBuilder<DailyReadingStat, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
