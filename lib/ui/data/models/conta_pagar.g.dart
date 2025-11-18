// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conta_pagar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetContaPagarCollection on Isar {
  IsarCollection<ContaPagar> get contaPagars => this.collection();
}

const ContaPagarSchema = CollectionSchema(
  name: r'ContaPagar',
  id: -1135641229005695369,
  properties: {
    r'dataPagamento': PropertySchema(
      id: 0,
      name: r'dataPagamento',
      type: IsarType.dateTime,
    ),
    r'dataVencimento': PropertySchema(
      id: 1,
      name: r'dataVencimento',
      type: IsarType.dateTime,
    ),
    r'descricao': PropertySchema(
      id: 2,
      name: r'descricao',
      type: IsarType.string,
    ),
    r'grupoParcelas': PropertySchema(
      id: 3,
      name: r'grupoParcelas',
      type: IsarType.string,
    ),
    r'pago': PropertySchema(
      id: 4,
      name: r'pago',
      type: IsarType.bool,
    ),
    r'parcelaNumero': PropertySchema(
      id: 5,
      name: r'parcelaNumero',
      type: IsarType.long,
    ),
    r'parcelaTotal': PropertySchema(
      id: 6,
      name: r'parcelaTotal',
      type: IsarType.long,
    ),
    r'valor': PropertySchema(
      id: 7,
      name: r'valor',
      type: IsarType.double,
    )
  },
  estimateSize: _contaPagarEstimateSize,
  serialize: _contaPagarSerialize,
  deserialize: _contaPagarDeserialize,
  deserializeProp: _contaPagarDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _contaPagarGetId,
  getLinks: _contaPagarGetLinks,
  attach: _contaPagarAttach,
  version: '3.1.0+1',
);

int _contaPagarEstimateSize(
  ContaPagar object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.descricao.length * 3;
  {
    final value = object.grupoParcelas;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _contaPagarSerialize(
  ContaPagar object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.dataPagamento);
  writer.writeDateTime(offsets[1], object.dataVencimento);
  writer.writeString(offsets[2], object.descricao);
  writer.writeString(offsets[3], object.grupoParcelas);
  writer.writeBool(offsets[4], object.pago);
  writer.writeLong(offsets[5], object.parcelaNumero);
  writer.writeLong(offsets[6], object.parcelaTotal);
  writer.writeDouble(offsets[7], object.valor);
}

ContaPagar _contaPagarDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ContaPagar();
  object.dataPagamento = reader.readDateTimeOrNull(offsets[0]);
  object.dataVencimento = reader.readDateTime(offsets[1]);
  object.descricao = reader.readString(offsets[2]);
  object.grupoParcelas = reader.readStringOrNull(offsets[3]);
  object.id = id;
  object.pago = reader.readBool(offsets[4]);
  object.parcelaNumero = reader.readLongOrNull(offsets[5]);
  object.parcelaTotal = reader.readLongOrNull(offsets[6]);
  object.valor = reader.readDouble(offsets[7]);
  return object;
}

P _contaPagarDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _contaPagarGetId(ContaPagar object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _contaPagarGetLinks(ContaPagar object) {
  return [];
}

void _contaPagarAttach(IsarCollection<dynamic> col, Id id, ContaPagar object) {
  object.id = id;
}

extension ContaPagarQueryWhereSort
    on QueryBuilder<ContaPagar, ContaPagar, QWhere> {
  QueryBuilder<ContaPagar, ContaPagar, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ContaPagarQueryWhere
    on QueryBuilder<ContaPagar, ContaPagar, QWhereClause> {
  QueryBuilder<ContaPagar, ContaPagar, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<ContaPagar, ContaPagar, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterWhereClause> idBetween(
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
}

extension ContaPagarQueryFilter
    on QueryBuilder<ContaPagar, ContaPagar, QFilterCondition> {
  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dataPagamento',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dataPagamento',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataPagamentoBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataPagamento',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataVencimentoEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataVencimento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataVencimentoGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataVencimento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataVencimentoLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataVencimento',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      dataVencimentoBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataVencimento',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      descricaoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'descricao',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      descricaoStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'descricao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> descricaoMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'descricao',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      descricaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descricao',
        value: '',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      descricaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'descricao',
        value: '',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'grupoParcelas',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'grupoParcelas',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'grupoParcelas',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'grupoParcelas',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'grupoParcelas',
        value: '',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      grupoParcelasIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'grupoParcelas',
        value: '',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> pagoEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pago',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parcelaNumero',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parcelaNumero',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parcelaNumero',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parcelaNumero',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parcelaNumero',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaNumeroBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parcelaNumero',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parcelaTotal',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parcelaTotal',
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parcelaTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parcelaTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parcelaTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition>
      parcelaTotalBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parcelaTotal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> valorEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'valor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> valorGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'valor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> valorLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'valor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterFilterCondition> valorBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'valor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension ContaPagarQueryObject
    on QueryBuilder<ContaPagar, ContaPagar, QFilterCondition> {}

extension ContaPagarQueryLinks
    on QueryBuilder<ContaPagar, ContaPagar, QFilterCondition> {}

extension ContaPagarQuerySortBy
    on QueryBuilder<ContaPagar, ContaPagar, QSortBy> {
  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByDataPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByDataVencimento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataVencimento', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy>
      sortByDataVencimentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataVencimento', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByGrupoParcelas() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByGrupoParcelasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByPagoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByParcelaNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByParcelaTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> sortByValorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.desc);
    });
  }
}

extension ContaPagarQuerySortThenBy
    on QueryBuilder<ContaPagar, ContaPagar, QSortThenBy> {
  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByDataPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByDataVencimento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataVencimento', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy>
      thenByDataVencimentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataVencimento', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByGrupoParcelas() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByGrupoParcelasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByPagoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByParcelaNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByParcelaTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.desc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.asc);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QAfterSortBy> thenByValorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.desc);
    });
  }
}

extension ContaPagarQueryWhereDistinct
    on QueryBuilder<ContaPagar, ContaPagar, QDistinct> {
  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataPagamento');
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByDataVencimento() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataVencimento');
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByDescricao(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descricao', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByGrupoParcelas(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'grupoParcelas',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pago');
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parcelaNumero');
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parcelaTotal');
    });
  }

  QueryBuilder<ContaPagar, ContaPagar, QDistinct> distinctByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'valor');
    });
  }
}

extension ContaPagarQueryProperty
    on QueryBuilder<ContaPagar, ContaPagar, QQueryProperty> {
  QueryBuilder<ContaPagar, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ContaPagar, DateTime?, QQueryOperations>
      dataPagamentoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataPagamento');
    });
  }

  QueryBuilder<ContaPagar, DateTime, QQueryOperations>
      dataVencimentoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataVencimento');
    });
  }

  QueryBuilder<ContaPagar, String, QQueryOperations> descricaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descricao');
    });
  }

  QueryBuilder<ContaPagar, String?, QQueryOperations> grupoParcelasProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'grupoParcelas');
    });
  }

  QueryBuilder<ContaPagar, bool, QQueryOperations> pagoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pago');
    });
  }

  QueryBuilder<ContaPagar, int?, QQueryOperations> parcelaNumeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parcelaNumero');
    });
  }

  QueryBuilder<ContaPagar, int?, QQueryOperations> parcelaTotalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parcelaTotal');
    });
  }

  QueryBuilder<ContaPagar, double, QQueryOperations> valorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'valor');
    });
  }
}
