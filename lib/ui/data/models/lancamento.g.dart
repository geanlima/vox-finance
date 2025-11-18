// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lancamento.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLancamentoCollection on Isar {
  IsarCollection<Lancamento> get lancamentos => this.collection();
}

const LancamentoSchema = CollectionSchema(
  name: r'Lancamento',
  id: -3883721027908053903,
  properties: {
    r'categoria': PropertySchema(
      id: 0,
      name: r'categoria',
      type: IsarType.byte,
      enumMap: _LancamentocategoriaEnumValueMap,
    ),
    r'dataHora': PropertySchema(
      id: 1,
      name: r'dataHora',
      type: IsarType.dateTime,
    ),
    r'dataPagamento': PropertySchema(
      id: 2,
      name: r'dataPagamento',
      type: IsarType.dateTime,
    ),
    r'descricao': PropertySchema(
      id: 3,
      name: r'descricao',
      type: IsarType.string,
    ),
    r'formaPagamento': PropertySchema(
      id: 4,
      name: r'formaPagamento',
      type: IsarType.byte,
      enumMap: _LancamentoformaPagamentoEnumValueMap,
    ),
    r'grupoParcelas': PropertySchema(
      id: 5,
      name: r'grupoParcelas',
      type: IsarType.string,
    ),
    r'pagamentoFatura': PropertySchema(
      id: 6,
      name: r'pagamentoFatura',
      type: IsarType.bool,
    ),
    r'pago': PropertySchema(
      id: 7,
      name: r'pago',
      type: IsarType.bool,
    ),
    r'parcelaNumero': PropertySchema(
      id: 8,
      name: r'parcelaNumero',
      type: IsarType.long,
    ),
    r'parcelaTotal': PropertySchema(
      id: 9,
      name: r'parcelaTotal',
      type: IsarType.long,
    ),
    r'valor': PropertySchema(
      id: 10,
      name: r'valor',
      type: IsarType.double,
    )
  },
  estimateSize: _lancamentoEstimateSize,
  serialize: _lancamentoSerialize,
  deserialize: _lancamentoDeserialize,
  deserializeProp: _lancamentoDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _lancamentoGetId,
  getLinks: _lancamentoGetLinks,
  attach: _lancamentoAttach,
  version: '3.1.0+1',
);

int _lancamentoEstimateSize(
  Lancamento object,
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

void _lancamentoSerialize(
  Lancamento object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeByte(offsets[0], object.categoria.index);
  writer.writeDateTime(offsets[1], object.dataHora);
  writer.writeDateTime(offsets[2], object.dataPagamento);
  writer.writeString(offsets[3], object.descricao);
  writer.writeByte(offsets[4], object.formaPagamento.index);
  writer.writeString(offsets[5], object.grupoParcelas);
  writer.writeBool(offsets[6], object.pagamentoFatura);
  writer.writeBool(offsets[7], object.pago);
  writer.writeLong(offsets[8], object.parcelaNumero);
  writer.writeLong(offsets[9], object.parcelaTotal);
  writer.writeDouble(offsets[10], object.valor);
}

Lancamento _lancamentoDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Lancamento();
  object.categoria =
      _LancamentocategoriaValueEnumMap[reader.readByteOrNull(offsets[0])] ??
          Categoria.mercado;
  object.dataHora = reader.readDateTime(offsets[1]);
  object.dataPagamento = reader.readDateTimeOrNull(offsets[2]);
  object.descricao = reader.readString(offsets[3]);
  object.formaPagamento = _LancamentoformaPagamentoValueEnumMap[
          reader.readByteOrNull(offsets[4])] ??
      FormaPagamento.credito;
  object.grupoParcelas = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.pagamentoFatura = reader.readBool(offsets[6]);
  object.pago = reader.readBool(offsets[7]);
  object.parcelaNumero = reader.readLongOrNull(offsets[8]);
  object.parcelaTotal = reader.readLongOrNull(offsets[9]);
  object.valor = reader.readDouble(offsets[10]);
  return object;
}

P _lancamentoDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_LancamentocategoriaValueEnumMap[reader.readByteOrNull(offset)] ??
          Categoria.mercado) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (_LancamentoformaPagamentoValueEnumMap[
              reader.readByteOrNull(offset)] ??
          FormaPagamento.credito) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _LancamentocategoriaEnumValueMap = {
  'mercado': 0,
  'transporte': 1,
  'lazer': 2,
  'alimentacao': 3,
  'saude': 4,
  'contas': 5,
  'outros': 6,
};
const _LancamentocategoriaValueEnumMap = {
  0: Categoria.mercado,
  1: Categoria.transporte,
  2: Categoria.lazer,
  3: Categoria.alimentacao,
  4: Categoria.saude,
  5: Categoria.contas,
  6: Categoria.outros,
};
const _LancamentoformaPagamentoEnumValueMap = {
  'credito': 0,
  'debito': 1,
  'dinheiro': 2,
  'pix': 3,
  'boleto': 4,
};
const _LancamentoformaPagamentoValueEnumMap = {
  0: FormaPagamento.credito,
  1: FormaPagamento.debito,
  2: FormaPagamento.dinheiro,
  3: FormaPagamento.pix,
  4: FormaPagamento.boleto,
};

Id _lancamentoGetId(Lancamento object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _lancamentoGetLinks(Lancamento object) {
  return [];
}

void _lancamentoAttach(IsarCollection<dynamic> col, Id id, Lancamento object) {
  object.id = id;
}

extension LancamentoQueryWhereSort
    on QueryBuilder<Lancamento, Lancamento, QWhere> {
  QueryBuilder<Lancamento, Lancamento, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LancamentoQueryWhere
    on QueryBuilder<Lancamento, Lancamento, QWhereClause> {
  QueryBuilder<Lancamento, Lancamento, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Lancamento, Lancamento, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterWhereClause> idBetween(
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

extension LancamentoQueryFilter
    on QueryBuilder<Lancamento, Lancamento, QFilterCondition> {
  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> categoriaEqualTo(
      Categoria value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categoria',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      categoriaGreaterThan(
    Categoria value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'categoria',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> categoriaLessThan(
    Categoria value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'categoria',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> categoriaBetween(
    Categoria lower,
    Categoria upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'categoria',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> dataHoraEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataHora',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      dataHoraGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dataHora',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> dataHoraLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dataHora',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> dataHoraBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dataHora',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      dataPagamentoIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'dataPagamento',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      dataPagamentoIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'dataPagamento',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      dataPagamentoEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dataPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoEqualTo(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoLessThan(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoBetween(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoEndsWith(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoContains(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> descricaoMatches(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      descricaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descricao',
        value: '',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      descricaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'descricao',
        value: '',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      formaPagamentoEqualTo(FormaPagamento value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'formaPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      formaPagamentoGreaterThan(
    FormaPagamento value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'formaPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      formaPagamentoLessThan(
    FormaPagamento value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'formaPagamento',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      formaPagamentoBetween(
    FormaPagamento lower,
    FormaPagamento upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'formaPagamento',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'grupoParcelas',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'grupoParcelas',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'grupoParcelas',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'grupoParcelas',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'grupoParcelas',
        value: '',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      grupoParcelasIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'grupoParcelas',
        value: '',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      pagamentoFaturaEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pagamentoFatura',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> pagoEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pago',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaNumeroIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parcelaNumero',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaNumeroIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parcelaNumero',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaNumeroEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parcelaNumero',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaTotalIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parcelaTotal',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaTotalIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parcelaTotal',
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
      parcelaTotalEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parcelaTotal',
        value: value,
      ));
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition>
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> valorEqualTo(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> valorGreaterThan(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> valorLessThan(
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

  QueryBuilder<Lancamento, Lancamento, QAfterFilterCondition> valorBetween(
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

extension LancamentoQueryObject
    on QueryBuilder<Lancamento, Lancamento, QFilterCondition> {}

extension LancamentoQueryLinks
    on QueryBuilder<Lancamento, Lancamento, QFilterCondition> {}

extension LancamentoQuerySortBy
    on QueryBuilder<Lancamento, Lancamento, QSortBy> {
  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByCategoria() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByCategoriaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDataHora() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataHora', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDataHoraDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataHora', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDataPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByFormaPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'formaPagamento', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy>
      sortByFormaPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'formaPagamento', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByGrupoParcelas() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByGrupoParcelasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByPagamentoFatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagamentoFatura', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy>
      sortByPagamentoFaturaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagamentoFatura', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByPagoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByParcelaNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByParcelaTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> sortByValorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.desc);
    });
  }
}

extension LancamentoQuerySortThenBy
    on QueryBuilder<Lancamento, Lancamento, QSortThenBy> {
  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByCategoria() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByCategoriaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDataHora() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataHora', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDataHoraDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataHora', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDataPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dataPagamento', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDescricao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByDescricaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descricao', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByFormaPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'formaPagamento', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy>
      thenByFormaPagamentoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'formaPagamento', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByGrupoParcelas() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByGrupoParcelasDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'grupoParcelas', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByPagamentoFatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagamentoFatura', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy>
      thenByPagamentoFaturaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pagamentoFatura', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByPagoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pago', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByParcelaNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaNumero', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByParcelaTotalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parcelaTotal', Sort.desc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.asc);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QAfterSortBy> thenByValorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'valor', Sort.desc);
    });
  }
}

extension LancamentoQueryWhereDistinct
    on QueryBuilder<Lancamento, Lancamento, QDistinct> {
  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByCategoria() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoria');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByDataHora() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataHora');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByDataPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dataPagamento');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByDescricao(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descricao', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByFormaPagamento() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'formaPagamento');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByGrupoParcelas(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'grupoParcelas',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByPagamentoFatura() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pagamentoFatura');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByPago() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pago');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByParcelaNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parcelaNumero');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByParcelaTotal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parcelaTotal');
    });
  }

  QueryBuilder<Lancamento, Lancamento, QDistinct> distinctByValor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'valor');
    });
  }
}

extension LancamentoQueryProperty
    on QueryBuilder<Lancamento, Lancamento, QQueryProperty> {
  QueryBuilder<Lancamento, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Lancamento, Categoria, QQueryOperations> categoriaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoria');
    });
  }

  QueryBuilder<Lancamento, DateTime, QQueryOperations> dataHoraProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataHora');
    });
  }

  QueryBuilder<Lancamento, DateTime?, QQueryOperations>
      dataPagamentoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dataPagamento');
    });
  }

  QueryBuilder<Lancamento, String, QQueryOperations> descricaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descricao');
    });
  }

  QueryBuilder<Lancamento, FormaPagamento, QQueryOperations>
      formaPagamentoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'formaPagamento');
    });
  }

  QueryBuilder<Lancamento, String?, QQueryOperations> grupoParcelasProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'grupoParcelas');
    });
  }

  QueryBuilder<Lancamento, bool, QQueryOperations> pagamentoFaturaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pagamentoFatura');
    });
  }

  QueryBuilder<Lancamento, bool, QQueryOperations> pagoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pago');
    });
  }

  QueryBuilder<Lancamento, int?, QQueryOperations> parcelaNumeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parcelaNumero');
    });
  }

  QueryBuilder<Lancamento, int?, QQueryOperations> parcelaTotalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parcelaTotal');
    });
  }

  QueryBuilder<Lancamento, double, QQueryOperations> valorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'valor');
    });
  }
}
