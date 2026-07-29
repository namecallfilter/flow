// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowSearchCategories {
  factory Variables$Query$FlowSearchCategories({
    required String query,
    int? first,
    String? after,
  }) => Variables$Query$FlowSearchCategories._({
    r'query': query,
    if (first != null) r'first': first,
    if (after != null) r'after': after,
  });

  Variables$Query$FlowSearchCategories._(this._$data);

  factory Variables$Query$FlowSearchCategories.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$query = data['query'];
    result$data['query'] = (l$query as String);
    if (data.containsKey('first')) {
      final l$first = data['first'];
      result$data['first'] = (l$first as int?);
    }
    if (data.containsKey('after')) {
      final l$after = data['after'];
      result$data['after'] = (l$after as String?);
    }
    return Variables$Query$FlowSearchCategories._(result$data);
  }

  Map<String, dynamic> _$data;

  String get query => (_$data['query'] as String);

  int? get first => (_$data['first'] as int?);

  String? get after => (_$data['after'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$query = query;
    result$data['query'] = l$query;
    final l$first = _$data.containsKey('first') ? first : null;
    result$data['first'] = l$first;
    final l$after = _$data.containsKey('after') ? after : null;
    result$data['after'] = l$after;
    return result$data;
  }

  CopyWith$Variables$Query$FlowSearchCategories<
    Variables$Query$FlowSearchCategories
  >
  get copyWith => CopyWith$Variables$Query$FlowSearchCategories(this, (i) => i);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowSearchCategories ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$query = query;
    final lOther$query = other.query;
    if (l$query != lOther$query) {
      return false;
    }
    final l$first = first;
    final lOther$first = other.first;
    if (_$data.containsKey('first') != other._$data.containsKey('first')) {
      return false;
    }
    if (l$first != lOther$first) {
      return false;
    }
    final l$after = after;
    final lOther$after = other.after;
    if (_$data.containsKey('after') != other._$data.containsKey('after')) {
      return false;
    }
    if (l$after != lOther$after) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$query = query;
    final l$first = first;
    final l$after = after;
    return Object.hashAll([
      l$query,
      _$data.containsKey('first') ? l$first : const {},
      _$data.containsKey('after') ? l$after : const {},
    ]);
  }
}

abstract class CopyWith$Variables$Query$FlowSearchCategories<TRes> {
  factory CopyWith$Variables$Query$FlowSearchCategories(
    Variables$Query$FlowSearchCategories instance,
    TRes Function(Variables$Query$FlowSearchCategories) then,
  ) = _CopyWithImpl$Variables$Query$FlowSearchCategories;

  factory CopyWith$Variables$Query$FlowSearchCategories.stub(TRes res) =
      _CopyWithStubImpl$Variables$Query$FlowSearchCategories;

  TRes call({String? query, int? first, String? after});
}

class _CopyWithImpl$Variables$Query$FlowSearchCategories<TRes>
    implements CopyWith$Variables$Query$FlowSearchCategories<TRes> {
  _CopyWithImpl$Variables$Query$FlowSearchCategories(
    this._instance,
    this._then,
  );

  final Variables$Query$FlowSearchCategories _instance;

  final TRes Function(Variables$Query$FlowSearchCategories) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({
    Object? query = _undefined,
    Object? first = _undefined,
    Object? after = _undefined,
  }) => _then(
    Variables$Query$FlowSearchCategories._({
      ..._instance._$data,
      if (query != _undefined && query != null) 'query': (query as String),
      if (first != _undefined) 'first': (first as int?),
      if (after != _undefined) 'after': (after as String?),
    }),
  );
}

class _CopyWithStubImpl$Variables$Query$FlowSearchCategories<TRes>
    implements CopyWith$Variables$Query$FlowSearchCategories<TRes> {
  _CopyWithStubImpl$Variables$Query$FlowSearchCategories(this._res);

  TRes _res;

  call({String? query, int? first, String? after}) => _res;
}

class Query$FlowSearchCategories {
  Query$FlowSearchCategories({this.searchCategories});

  factory Query$FlowSearchCategories.fromJson(Map<String, dynamic> json) {
    final l$searchCategories = json.containsKey('searchCategories')
        ? json['searchCategories']
        : null;
    return Query$FlowSearchCategories(
      searchCategories: l$searchCategories == null
          ? null
          : Query$FlowSearchCategories$searchCategories.fromJson(
              (l$searchCategories as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowSearchCategories$searchCategories? searchCategories;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$searchCategories = searchCategories;
    _resultData['searchCategories'] = l$searchCategories?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$searchCategories = searchCategories;
    return Object.hashAll([l$searchCategories]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchCategories ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$searchCategories = searchCategories;
    final lOther$searchCategories = other.searchCategories;
    if (l$searchCategories != lOther$searchCategories) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchCategories
    on Query$FlowSearchCategories {
  CopyWith$Query$FlowSearchCategories<Query$FlowSearchCategories>
  get copyWith => CopyWith$Query$FlowSearchCategories(this, (i) => i);
}

abstract class CopyWith$Query$FlowSearchCategories<TRes> {
  factory CopyWith$Query$FlowSearchCategories(
    Query$FlowSearchCategories instance,
    TRes Function(Query$FlowSearchCategories) then,
  ) = _CopyWithImpl$Query$FlowSearchCategories;

  factory CopyWith$Query$FlowSearchCategories.stub(TRes res) =
      _CopyWithStubImpl$Query$FlowSearchCategories;

  TRes call({Query$FlowSearchCategories$searchCategories? searchCategories});
  CopyWith$Query$FlowSearchCategories$searchCategories<TRes>
  get searchCategories;
}

class _CopyWithImpl$Query$FlowSearchCategories<TRes>
    implements CopyWith$Query$FlowSearchCategories<TRes> {
  _CopyWithImpl$Query$FlowSearchCategories(this._instance, this._then);

  final Query$FlowSearchCategories _instance;

  final TRes Function(Query$FlowSearchCategories) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? searchCategories = _undefined}) => _then(
    Query$FlowSearchCategories(
      searchCategories: searchCategories == _undefined
          ? _instance.searchCategories
          : (searchCategories as Query$FlowSearchCategories$searchCategories?),
    ),
  );

  CopyWith$Query$FlowSearchCategories$searchCategories<TRes>
  get searchCategories {
    final local$searchCategories = _instance.searchCategories;
    return local$searchCategories == null
        ? CopyWith$Query$FlowSearchCategories$searchCategories.stub(
            _then(_instance),
          )
        : CopyWith$Query$FlowSearchCategories$searchCategories(
            local$searchCategories,
            (e) => call(searchCategories: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowSearchCategories<TRes>
    implements CopyWith$Query$FlowSearchCategories<TRes> {
  _CopyWithStubImpl$Query$FlowSearchCategories(this._res);

  TRes _res;

  call({Query$FlowSearchCategories$searchCategories? searchCategories}) => _res;

  CopyWith$Query$FlowSearchCategories$searchCategories<TRes>
  get searchCategories =>
      CopyWith$Query$FlowSearchCategories$searchCategories.stub(_res);
}

const documentNodeQueryFlowSearchCategories = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowSearchCategories'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'query')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'first')),
          type: NamedTypeNode(name: NameNode(value: 'Int'), isNonNull: false),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'after')),
          type: NamedTypeNode(
            name: NameNode(value: 'Cursor'),
            isNonNull: false,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'searchCategories'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'query'),
                value: VariableNode(name: NameNode(value: 'query')),
              ),
              ArgumentNode(
                name: NameNode(value: 'first'),
                value: VariableNode(name: NameNode(value: 'first')),
              ),
              ArgumentNode(
                name: NameNode(value: 'after'),
                value: VariableNode(name: NameNode(value: 'after')),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'edges'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'cursor'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'node'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'id'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'displayName'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'boxArtURL'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'viewersCount'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'pageInfo'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'hasNextPage'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
);
Query$FlowSearchCategories _parserFn$Query$FlowSearchCategories(
  Map<String, dynamic> data,
) => Query$FlowSearchCategories.fromJson(data);
typedef OnQueryComplete$Query$FlowSearchCategories =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowSearchCategories?);

class Options$Query$FlowSearchCategories
    extends graphql.QueryOptions<Query$FlowSearchCategories> {
  Options$Query$FlowSearchCategories({
    String? operationName,
    required Variables$Query$FlowSearchCategories variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowSearchCategories? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowSearchCategories? onComplete,
    graphql.OnQueryError? onError,
  }) : onCompleteWithParsed = onComplete,
       super(
         variables: variables.toJson(),
         operationName: operationName,
         fetchPolicy: fetchPolicy,
         errorPolicy: errorPolicy,
         cacheRereadPolicy: cacheRereadPolicy,
         optimisticResult: optimisticResult ?? typedOptimisticResult?.toJson(),
         pollInterval: pollInterval,
         context: context,
         onComplete: onComplete == null
             ? null
             : (data) => onComplete(
                 data,
                 data == null
                     ? null
                     : _parserFn$Query$FlowSearchCategories(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowSearchCategories,
         parserFn: _parserFn$Query$FlowSearchCategories,
       );

  final OnQueryComplete$Query$FlowSearchCategories? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowSearchCategories
    extends graphql.WatchQueryOptions<Query$FlowSearchCategories> {
  WatchOptions$Query$FlowSearchCategories({
    String? operationName,
    required Variables$Query$FlowSearchCategories variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowSearchCategories? typedOptimisticResult,
    graphql.Context? context,
    Duration? pollInterval,
    bool? eagerlyFetchResults,
    bool carryForwardDataOnException = true,
    bool fetchResults = false,
  }) : super(
         variables: variables.toJson(),
         operationName: operationName,
         fetchPolicy: fetchPolicy,
         errorPolicy: errorPolicy,
         cacheRereadPolicy: cacheRereadPolicy,
         optimisticResult: optimisticResult ?? typedOptimisticResult?.toJson(),
         context: context,
         document: documentNodeQueryFlowSearchCategories,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowSearchCategories,
       );
}

class FetchMoreOptions$Query$FlowSearchCategories
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowSearchCategories({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowSearchCategories variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowSearchCategories,
       );
}

extension ClientExtension$Query$FlowSearchCategories on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowSearchCategories>>
  query$FlowSearchCategories(
    Options$Query$FlowSearchCategories options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowSearchCategories>
  watchQuery$FlowSearchCategories(
    WatchOptions$Query$FlowSearchCategories options,
  ) => this.watchQuery(options);

  void writeQuery$FlowSearchCategories({
    required Query$FlowSearchCategories data,
    required Variables$Query$FlowSearchCategories variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowSearchCategories,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowSearchCategories? readQuery$FlowSearchCategories({
    required Variables$Query$FlowSearchCategories variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowSearchCategories,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowSearchCategories.fromJson(result);
  }
}

class Query$FlowSearchCategories$searchCategories {
  Query$FlowSearchCategories$searchCategories({this.edges, this.pageInfo});

  factory Query$FlowSearchCategories$searchCategories.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowSearchCategories$searchCategories(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowSearchCategories$searchCategories$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowSearchCategories$searchCategories$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowSearchCategories$searchCategories$edges?>? edges;

  final Query$FlowSearchCategories$searchCategories$pageInfo? pageInfo;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$edges = edges;
    _resultData['edges'] = l$edges?.map((e) => e?.toJson()).toList();
    final l$pageInfo = pageInfo;
    _resultData['pageInfo'] = l$pageInfo?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$edges = edges;
    final l$pageInfo = pageInfo;
    return Object.hashAll([
      l$edges == null ? null : Object.hashAll(l$edges.map((v) => v)),
      l$pageInfo,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchCategories$searchCategories ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$edges = edges;
    final lOther$edges = other.edges;
    if (l$edges != null && lOther$edges != null) {
      if (l$edges.length != lOther$edges.length) {
        return false;
      }
      for (int i = 0; i < l$edges.length; i++) {
        final l$edges$entry = l$edges[i];
        final lOther$edges$entry = lOther$edges[i];
        if (l$edges$entry != lOther$edges$entry) {
          return false;
        }
      }
    } else if (l$edges != lOther$edges) {
      return false;
    }
    final l$pageInfo = pageInfo;
    final lOther$pageInfo = other.pageInfo;
    if (l$pageInfo != lOther$pageInfo) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchCategories$searchCategories
    on Query$FlowSearchCategories$searchCategories {
  CopyWith$Query$FlowSearchCategories$searchCategories<
    Query$FlowSearchCategories$searchCategories
  >
  get copyWith =>
      CopyWith$Query$FlowSearchCategories$searchCategories(this, (i) => i);
}

abstract class CopyWith$Query$FlowSearchCategories$searchCategories<TRes> {
  factory CopyWith$Query$FlowSearchCategories$searchCategories(
    Query$FlowSearchCategories$searchCategories instance,
    TRes Function(Query$FlowSearchCategories$searchCategories) then,
  ) = _CopyWithImpl$Query$FlowSearchCategories$searchCategories;

  factory CopyWith$Query$FlowSearchCategories$searchCategories.stub(TRes res) =
      _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories;

  TRes call({
    List<Query$FlowSearchCategories$searchCategories$edges?>? edges,
    Query$FlowSearchCategories$searchCategories$pageInfo? pageInfo,
  });
  TRes edges(
    Iterable<Query$FlowSearchCategories$searchCategories$edges?>? Function(
      Iterable<
        CopyWith$Query$FlowSearchCategories$searchCategories$edges<
          Query$FlowSearchCategories$searchCategories$edges
        >?
      >?,
    )
    _fn,
  );
  CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<TRes>
  get pageInfo;
}

class _CopyWithImpl$Query$FlowSearchCategories$searchCategories<TRes>
    implements CopyWith$Query$FlowSearchCategories$searchCategories<TRes> {
  _CopyWithImpl$Query$FlowSearchCategories$searchCategories(
    this._instance,
    this._then,
  );

  final Query$FlowSearchCategories$searchCategories _instance;

  final TRes Function(Query$FlowSearchCategories$searchCategories) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({
    Object? edges = _undefined,
    Object? pageInfo = _undefined,
  }) => _then(
    Query$FlowSearchCategories$searchCategories(
      edges: edges == _undefined
          ? _instance.edges
          : (edges
                as List<Query$FlowSearchCategories$searchCategories$edges?>?),
      pageInfo: pageInfo == _undefined
          ? _instance.pageInfo
          : (pageInfo as Query$FlowSearchCategories$searchCategories$pageInfo?),
    ),
  );

  TRes edges(
    Iterable<Query$FlowSearchCategories$searchCategories$edges?>? Function(
      Iterable<
        CopyWith$Query$FlowSearchCategories$searchCategories$edges<
          Query$FlowSearchCategories$searchCategories$edges
        >?
      >?,
    )
    _fn,
  ) => call(
    edges: _fn(
      _instance.edges?.map(
        (e) => e == null
            ? null
            : CopyWith$Query$FlowSearchCategories$searchCategories$edges(
                e,
                (i) => i,
              ),
      ),
    )?.toList(),
  );

  CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<TRes>
  get pageInfo {
    final local$pageInfo = _instance.pageInfo;
    return local$pageInfo == null
        ? CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo.stub(
            _then(_instance),
          )
        : CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo(
            local$pageInfo,
            (e) => call(pageInfo: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories<TRes>
    implements CopyWith$Query$FlowSearchCategories$searchCategories<TRes> {
  _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories(this._res);

  TRes _res;

  call({
    List<Query$FlowSearchCategories$searchCategories$edges?>? edges,
    Query$FlowSearchCategories$searchCategories$pageInfo? pageInfo,
  }) => _res;

  edges(_fn) => _res;

  CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<TRes>
  get pageInfo =>
      CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo.stub(_res);
}

class Query$FlowSearchCategories$searchCategories$edges {
  Query$FlowSearchCategories$searchCategories$edges({this.cursor, this.node});

  factory Query$FlowSearchCategories$searchCategories$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowSearchCategories$searchCategories$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowSearchCategories$searchCategories$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowSearchCategories$searchCategories$edges$node? node;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$cursor = cursor;
    _resultData['cursor'] = l$cursor;
    final l$node = node;
    _resultData['node'] = l$node?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$cursor = cursor;
    final l$node = node;
    return Object.hashAll([l$cursor, l$node]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchCategories$searchCategories$edges ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$cursor = cursor;
    final lOther$cursor = other.cursor;
    if (l$cursor != lOther$cursor) {
      return false;
    }
    final l$node = node;
    final lOther$node = other.node;
    if (l$node != lOther$node) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchCategories$searchCategories$edges
    on Query$FlowSearchCategories$searchCategories$edges {
  CopyWith$Query$FlowSearchCategories$searchCategories$edges<
    Query$FlowSearchCategories$searchCategories$edges
  >
  get copyWith => CopyWith$Query$FlowSearchCategories$searchCategories$edges(
    this,
    (i) => i,
  );
}

abstract class CopyWith$Query$FlowSearchCategories$searchCategories$edges<
  TRes
> {
  factory CopyWith$Query$FlowSearchCategories$searchCategories$edges(
    Query$FlowSearchCategories$searchCategories$edges instance,
    TRes Function(Query$FlowSearchCategories$searchCategories$edges) then,
  ) = _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges;

  factory CopyWith$Query$FlowSearchCategories$searchCategories$edges.stub(
    TRes res,
  ) = _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges;

  TRes call({
    String? cursor,
    Query$FlowSearchCategories$searchCategories$edges$node? node,
  });
  CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<TRes>
  get node;
}

class _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges<TRes>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$edges<TRes> {
  _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges(
    this._instance,
    this._then,
  );

  final Query$FlowSearchCategories$searchCategories$edges _instance;

  final TRes Function(Query$FlowSearchCategories$searchCategories$edges) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? cursor = _undefined, Object? node = _undefined}) => _then(
    Query$FlowSearchCategories$searchCategories$edges(
      cursor: cursor == _undefined ? _instance.cursor : (cursor as String?),
      node: node == _undefined
          ? _instance.node
          : (node as Query$FlowSearchCategories$searchCategories$edges$node?),
    ),
  );

  CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<TRes>
  get node {
    final local$node = _instance.node;
    return local$node == null
        ? CopyWith$Query$FlowSearchCategories$searchCategories$edges$node.stub(
            _then(_instance),
          )
        : CopyWith$Query$FlowSearchCategories$searchCategories$edges$node(
            local$node,
            (e) => call(node: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges<TRes>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$edges<TRes> {
  _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges(
    this._res,
  );

  TRes _res;

  call({
    String? cursor,
    Query$FlowSearchCategories$searchCategories$edges$node? node,
  }) => _res;

  CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<TRes>
  get node =>
      CopyWith$Query$FlowSearchCategories$searchCategories$edges$node.stub(
        _res,
      );
}

class Query$FlowSearchCategories$searchCategories$edges$node {
  Query$FlowSearchCategories$searchCategories$edges$node({
    this.id,
    this.displayName,
    this.boxArtURL,
    this.viewersCount,
  });

  factory Query$FlowSearchCategories$searchCategories$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$boxArtURL = json.containsKey('boxArtURL')
        ? json['boxArtURL']
        : null;
    final l$viewersCount = json.containsKey('viewersCount')
        ? json['viewersCount']
        : null;
    return Query$FlowSearchCategories$searchCategories$edges$node(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
      boxArtURL: (l$boxArtURL as String?),
      viewersCount: (l$viewersCount as int?),
    );
  }

  final String? id;

  final String? displayName;

  final String? boxArtURL;

  final int? viewersCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$boxArtURL = boxArtURL;
    _resultData['boxArtURL'] = l$boxArtURL;
    final l$viewersCount = viewersCount;
    _resultData['viewersCount'] = l$viewersCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    final l$boxArtURL = boxArtURL;
    final l$viewersCount = viewersCount;
    return Object.hashAll([l$id, l$displayName, l$boxArtURL, l$viewersCount]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchCategories$searchCategories$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$displayName = displayName;
    final lOther$displayName = other.displayName;
    if (l$displayName != lOther$displayName) {
      return false;
    }
    final l$boxArtURL = boxArtURL;
    final lOther$boxArtURL = other.boxArtURL;
    if (l$boxArtURL != lOther$boxArtURL) {
      return false;
    }
    final l$viewersCount = viewersCount;
    final lOther$viewersCount = other.viewersCount;
    if (l$viewersCount != lOther$viewersCount) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchCategories$searchCategories$edges$node
    on Query$FlowSearchCategories$searchCategories$edges$node {
  CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<
    Query$FlowSearchCategories$searchCategories$edges$node
  >
  get copyWith =>
      CopyWith$Query$FlowSearchCategories$searchCategories$edges$node(
        this,
        (i) => i,
      );
}

abstract class CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<
  TRes
> {
  factory CopyWith$Query$FlowSearchCategories$searchCategories$edges$node(
    Query$FlowSearchCategories$searchCategories$edges$node instance,
    TRes Function(Query$FlowSearchCategories$searchCategories$edges$node) then,
  ) = _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges$node;

  factory CopyWith$Query$FlowSearchCategories$searchCategories$edges$node.stub(
    TRes res,
  ) = _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges$node;

  TRes call({
    String? id,
    String? displayName,
    String? boxArtURL,
    int? viewersCount,
  });
}

class _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges$node<TRes>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<TRes> {
  _CopyWithImpl$Query$FlowSearchCategories$searchCategories$edges$node(
    this._instance,
    this._then,
  );

  final Query$FlowSearchCategories$searchCategories$edges$node _instance;

  final TRes Function(Query$FlowSearchCategories$searchCategories$edges$node)
  _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({
    Object? id = _undefined,
    Object? displayName = _undefined,
    Object? boxArtURL = _undefined,
    Object? viewersCount = _undefined,
  }) => _then(
    Query$FlowSearchCategories$searchCategories$edges$node(
      id: id == _undefined ? _instance.id : (id as String?),
      displayName: displayName == _undefined
          ? _instance.displayName
          : (displayName as String?),
      boxArtURL: boxArtURL == _undefined
          ? _instance.boxArtURL
          : (boxArtURL as String?),
      viewersCount: viewersCount == _undefined
          ? _instance.viewersCount
          : (viewersCount as int?),
    ),
  );
}

class _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges$node<
  TRes
>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$edges$node<TRes> {
  _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$edges$node(
    this._res,
  );

  TRes _res;

  call({
    String? id,
    String? displayName,
    String? boxArtURL,
    int? viewersCount,
  }) => _res;
}

class Query$FlowSearchCategories$searchCategories$pageInfo {
  Query$FlowSearchCategories$searchCategories$pageInfo({this.hasNextPage});

  factory Query$FlowSearchCategories$searchCategories$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowSearchCategories$searchCategories$pageInfo(
      hasNextPage: (l$hasNextPage as bool?),
    );
  }

  final bool? hasNextPage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$hasNextPage = hasNextPage;
    _resultData['hasNextPage'] = l$hasNextPage;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$hasNextPage = hasNextPage;
    return Object.hashAll([l$hasNextPage]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchCategories$searchCategories$pageInfo ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$hasNextPage = hasNextPage;
    final lOther$hasNextPage = other.hasNextPage;
    if (l$hasNextPage != lOther$hasNextPage) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchCategories$searchCategories$pageInfo
    on Query$FlowSearchCategories$searchCategories$pageInfo {
  CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<
    Query$FlowSearchCategories$searchCategories$pageInfo
  >
  get copyWith => CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo(
    this,
    (i) => i,
  );
}

abstract class CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<
  TRes
> {
  factory CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo(
    Query$FlowSearchCategories$searchCategories$pageInfo instance,
    TRes Function(Query$FlowSearchCategories$searchCategories$pageInfo) then,
  ) = _CopyWithImpl$Query$FlowSearchCategories$searchCategories$pageInfo;

  factory CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo.stub(
    TRes res,
  ) = _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$pageInfo;

  TRes call({bool? hasNextPage});
}

class _CopyWithImpl$Query$FlowSearchCategories$searchCategories$pageInfo<TRes>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<TRes> {
  _CopyWithImpl$Query$FlowSearchCategories$searchCategories$pageInfo(
    this._instance,
    this._then,
  );

  final Query$FlowSearchCategories$searchCategories$pageInfo _instance;

  final TRes Function(Query$FlowSearchCategories$searchCategories$pageInfo)
  _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? hasNextPage = _undefined}) => _then(
    Query$FlowSearchCategories$searchCategories$pageInfo(
      hasNextPage: hasNextPage == _undefined
          ? _instance.hasNextPage
          : (hasNextPage as bool?),
    ),
  );
}

class _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$pageInfo<
  TRes
>
    implements
        CopyWith$Query$FlowSearchCategories$searchCategories$pageInfo<TRes> {
  _CopyWithStubImpl$Query$FlowSearchCategories$searchCategories$pageInfo(
    this._res,
  );

  TRes _res;

  call({bool? hasNextPage}) => _res;
}
