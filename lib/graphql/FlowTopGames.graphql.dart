// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;
import 'schema.graphqls.dart';

class Variables$Query$FlowTopGames {
  factory Variables$Query$FlowTopGames({
    int? first,
    String? after,
    Input$GameOptions? options,
  }) => Variables$Query$FlowTopGames._({
    if (first != null) r'first': first,
    if (after != null) r'after': after,
    if (options != null) r'options': options,
  });

  Variables$Query$FlowTopGames._(this._$data);

  factory Variables$Query$FlowTopGames.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('first')) {
      final l$first = data['first'];
      result$data['first'] = (l$first as int?);
    }
    if (data.containsKey('after')) {
      final l$after = data['after'];
      result$data['after'] = (l$after as String?);
    }
    if (data.containsKey('options')) {
      final l$options = data['options'];
      result$data['options'] = l$options == null
          ? null
          : Input$GameOptions.fromJson((l$options as Map<String, dynamic>));
    }
    return Variables$Query$FlowTopGames._(result$data);
  }

  Map<String, dynamic> _$data;

  int? get first => (_$data['first'] as int?);

  String? get after => (_$data['after'] as String?);

  Input$GameOptions? get options => (_$data['options'] as Input$GameOptions?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$first = _$data.containsKey('first') ? first : null;
    result$data['first'] = l$first;
    final l$after = _$data.containsKey('after') ? after : null;
    result$data['after'] = l$after;
    final l$options = _$data.containsKey('options') ? options : null;
    result$data['options'] = l$options?.toJson();
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowTopGames ||
        runtimeType != other.runtimeType) {
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
    final l$options = options;
    final lOther$options = other.options;
    if (_$data.containsKey('options') != other._$data.containsKey('options')) {
      return false;
    }
    if (l$options != lOther$options) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$first = first;
    final l$after = after;
    final l$options = options;
    return Object.hashAll([
      _$data.containsKey('first') ? l$first : const {},
      _$data.containsKey('after') ? l$after : const {},
      _$data.containsKey('options') ? l$options : const {},
    ]);
  }
}

class Query$FlowTopGames {
  Query$FlowTopGames({this.games});

  factory Query$FlowTopGames.fromJson(Map<String, dynamic> json) {
    final l$games = json.containsKey('games') ? json['games'] : null;
    return Query$FlowTopGames(
      games: l$games == null
          ? null
          : Query$FlowTopGames$games.fromJson(
              (l$games as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowTopGames$games? games;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$games = games;
    _resultData['games'] = l$games?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$games = games;
    return Object.hashAll([l$games]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowTopGames || runtimeType != other.runtimeType) {
      return false;
    }
    final l$games = games;
    final lOther$games = other.games;
    if (l$games != lOther$games) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowTopGames = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowTopGames'),
      variableDefinitions: [
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
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'options')),
          type: NamedTypeNode(
            name: NameNode(value: 'GameOptions'),
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
            name: NameNode(value: 'games'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'first'),
                value: VariableNode(name: NameNode(value: 'first')),
              ),
              ArgumentNode(
                name: NameNode(value: 'after'),
                value: VariableNode(name: NameNode(value: 'after')),
              ),
              ArgumentNode(
                name: NameNode(value: 'options'),
                value: VariableNode(name: NameNode(value: 'options')),
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
Query$FlowTopGames _parserFn$Query$FlowTopGames(Map<String, dynamic> data) =>
    Query$FlowTopGames.fromJson(data);
typedef OnQueryComplete$Query$FlowTopGames =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowTopGames?);

class Options$Query$FlowTopGames
    extends graphql.QueryOptions<Query$FlowTopGames> {
  Options$Query$FlowTopGames({
    String? operationName,
    Variables$Query$FlowTopGames? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowTopGames? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowTopGames? onComplete,
    graphql.OnQueryError? onError,
  }) : onCompleteWithParsed = onComplete,
       super(
         variables: variables?.toJson() ?? {},
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
                 data == null ? null : _parserFn$Query$FlowTopGames(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowTopGames,
         parserFn: _parserFn$Query$FlowTopGames,
       );

  final OnQueryComplete$Query$FlowTopGames? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowTopGames
    extends graphql.WatchQueryOptions<Query$FlowTopGames> {
  WatchOptions$Query$FlowTopGames({
    String? operationName,
    Variables$Query$FlowTopGames? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowTopGames? typedOptimisticResult,
    graphql.Context? context,
    Duration? pollInterval,
    bool? eagerlyFetchResults,
    bool carryForwardDataOnException = true,
    bool fetchResults = false,
  }) : super(
         variables: variables?.toJson() ?? {},
         operationName: operationName,
         fetchPolicy: fetchPolicy,
         errorPolicy: errorPolicy,
         cacheRereadPolicy: cacheRereadPolicy,
         optimisticResult: optimisticResult ?? typedOptimisticResult?.toJson(),
         context: context,
         document: documentNodeQueryFlowTopGames,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowTopGames,
       );
}

class FetchMoreOptions$Query$FlowTopGames extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowTopGames({
    required graphql.UpdateQuery updateQuery,
    Variables$Query$FlowTopGames? variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables?.toJson() ?? {},
         document: documentNodeQueryFlowTopGames,
       );
}

extension ClientExtension$Query$FlowTopGames on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowTopGames>> query$FlowTopGames([
    Options$Query$FlowTopGames? options,
  ]) async => await this.query(options ?? Options$Query$FlowTopGames());

  graphql.ObservableQuery<Query$FlowTopGames> watchQuery$FlowTopGames([
    WatchOptions$Query$FlowTopGames? options,
  ]) => this.watchQuery(options ?? WatchOptions$Query$FlowTopGames());

  void writeQuery$FlowTopGames({
    required Query$FlowTopGames data,
    Variables$Query$FlowTopGames? variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowTopGames),
      variables: variables?.toJson() ?? const {},
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowTopGames? readQuery$FlowTopGames({
    Variables$Query$FlowTopGames? variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowTopGames),
        variables: variables?.toJson() ?? const {},
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowTopGames.fromJson(result);
  }
}

class Query$FlowTopGames$games {
  Query$FlowTopGames$games({this.edges, this.pageInfo});

  factory Query$FlowTopGames$games.fromJson(Map<String, dynamic> json) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowTopGames$games(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowTopGames$games$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowTopGames$games$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowTopGames$games$edges?>? edges;

  final Query$FlowTopGames$games$pageInfo? pageInfo;

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
    if (other is! Query$FlowTopGames$games ||
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

class Query$FlowTopGames$games$edges {
  Query$FlowTopGames$games$edges({this.cursor, this.node});

  factory Query$FlowTopGames$games$edges.fromJson(Map<String, dynamic> json) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowTopGames$games$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowTopGames$games$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowTopGames$games$edges$node? node;

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
    if (other is! Query$FlowTopGames$games$edges ||
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

class Query$FlowTopGames$games$edges$node {
  Query$FlowTopGames$games$edges$node({
    this.id,
    this.displayName,
    this.boxArtURL,
    this.viewersCount,
  });

  factory Query$FlowTopGames$games$edges$node.fromJson(
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
    return Query$FlowTopGames$games$edges$node(
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
    if (other is! Query$FlowTopGames$games$edges$node ||
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

class Query$FlowTopGames$games$pageInfo {
  Query$FlowTopGames$games$pageInfo({this.hasNextPage});

  factory Query$FlowTopGames$games$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowTopGames$games$pageInfo(
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
    if (other is! Query$FlowTopGames$games$pageInfo ||
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
