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
