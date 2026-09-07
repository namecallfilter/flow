// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;
import 'schema.graphqls.dart';

class Variables$Query$FlowGameStreams {
  factory Variables$Query$FlowGameStreams({
    String? id,
    int? first,
    String? after,
    Input$GameStreamOptions? options,
  }) => Variables$Query$FlowGameStreams._({
    if (id != null) r'id': id,
    if (first != null) r'first': first,
    if (after != null) r'after': after,
    if (options != null) r'options': options,
  });

  Variables$Query$FlowGameStreams._(this._$data);

  factory Variables$Query$FlowGameStreams.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('id')) {
      final l$id = data['id'];
      result$data['id'] = (l$id as String?);
    }
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
          : Input$GameStreamOptions.fromJson(
              (l$options as Map<String, dynamic>),
            );
    }
    return Variables$Query$FlowGameStreams._(result$data);
  }

  Map<String, dynamic> _$data;

  String? get id => (_$data['id'] as String?);

  int? get first => (_$data['first'] as int?);

  String? get after => (_$data['after'] as String?);

  Input$GameStreamOptions? get options =>
      (_$data['options'] as Input$GameStreamOptions?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$id = _$data.containsKey('id') ? id : null;
    result$data['id'] = l$id;
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
    if (other is! Variables$Query$FlowGameStreams ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (_$data.containsKey('id') != other._$data.containsKey('id')) {
      return false;
    }
    if (l$id != lOther$id) {
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
    final l$id = id;
    final l$first = first;
    final l$after = after;
    final l$options = options;
    return Object.hashAll([
      _$data.containsKey('id') ? l$id : const {},
      _$data.containsKey('first') ? l$first : const {},
      _$data.containsKey('after') ? l$after : const {},
      _$data.containsKey('options') ? l$options : const {},
    ]);
  }
}

class Query$FlowGameStreams {
  Query$FlowGameStreams({this.game});

  factory Query$FlowGameStreams.fromJson(Map<String, dynamic> json) {
    final l$game = json.containsKey('game') ? json['game'] : null;
    return Query$FlowGameStreams(
      game: l$game == null
          ? null
          : Query$FlowGameStreams$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowGameStreams$game? game;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$game = game;
    return Object.hashAll([l$game]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams || runtimeType != other.runtimeType) {
      return false;
    }
    final l$game = game;
    final lOther$game = other.game;
    if (l$game != lOther$game) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowGameStreams = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowGameStreams'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'id')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: false),
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
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'options')),
          type: NamedTypeNode(
            name: NameNode(value: 'GameStreamOptions'),
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
            name: NameNode(value: 'game'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'id')),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'streams'),
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
                                    name: NameNode(value: 'broadcaster'),
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
                                          name: NameNode(value: 'login'),
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
                                          name: NameNode(value: 'isPartner'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(
                                            value: 'profileImageURL',
                                          ),
                                          alias: null,
                                          arguments: [
                                            ArgumentNode(
                                              name: NameNode(value: 'width'),
                                              value: IntValueNode(value: '300'),
                                            ),
                                          ],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(
                                            value: 'broadcastSettings',
                                          ),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: SelectionSetNode(
                                            selections: [
                                              FieldNode(
                                                name: NameNode(value: 'title'),
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
                                    name: NameNode(value: 'createdAt'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'freeformTags'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: SelectionSetNode(
                                      selections: [
                                        FieldNode(
                                          name: NameNode(value: 'name'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'game'),
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
                                      ],
                                    ),
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'previewImageURL'),
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
      ),
    ),
  ],
);
Query$FlowGameStreams _parserFn$Query$FlowGameStreams(
  Map<String, dynamic> data,
) => Query$FlowGameStreams.fromJson(data);
typedef OnQueryComplete$Query$FlowGameStreams =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowGameStreams?);

class Options$Query$FlowGameStreams
    extends graphql.QueryOptions<Query$FlowGameStreams> {
  Options$Query$FlowGameStreams({
    String? operationName,
    Variables$Query$FlowGameStreams? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowGameStreams? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowGameStreams? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowGameStreams(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowGameStreams,
         parserFn: _parserFn$Query$FlowGameStreams,
       );

  final OnQueryComplete$Query$FlowGameStreams? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowGameStreams
    extends graphql.WatchQueryOptions<Query$FlowGameStreams> {
  WatchOptions$Query$FlowGameStreams({
    String? operationName,
    Variables$Query$FlowGameStreams? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowGameStreams? typedOptimisticResult,
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
         document: documentNodeQueryFlowGameStreams,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowGameStreams,
       );
}

class FetchMoreOptions$Query$FlowGameStreams extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowGameStreams({
    required graphql.UpdateQuery updateQuery,
    Variables$Query$FlowGameStreams? variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables?.toJson() ?? {},
         document: documentNodeQueryFlowGameStreams,
       );
}

extension ClientExtension$Query$FlowGameStreams on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowGameStreams>> query$FlowGameStreams([
    Options$Query$FlowGameStreams? options,
  ]) async => await this.query(options ?? Options$Query$FlowGameStreams());

  graphql.ObservableQuery<Query$FlowGameStreams> watchQuery$FlowGameStreams([
    WatchOptions$Query$FlowGameStreams? options,
  ]) => this.watchQuery(options ?? WatchOptions$Query$FlowGameStreams());

  void writeQuery$FlowGameStreams({
    required Query$FlowGameStreams data,
    Variables$Query$FlowGameStreams? variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowGameStreams),
      variables: variables?.toJson() ?? const {},
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowGameStreams? readQuery$FlowGameStreams({
    Variables$Query$FlowGameStreams? variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowGameStreams,
        ),
        variables: variables?.toJson() ?? const {},
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowGameStreams.fromJson(result);
  }
}

class Query$FlowGameStreams$game {
  Query$FlowGameStreams$game({this.streams});

  factory Query$FlowGameStreams$game.fromJson(Map<String, dynamic> json) {
    final l$streams = json.containsKey('streams') ? json['streams'] : null;
    return Query$FlowGameStreams$game(
      streams: l$streams == null
          ? null
          : Query$FlowGameStreams$game$streams.fromJson(
              (l$streams as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowGameStreams$game$streams? streams;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$streams = streams;
    _resultData['streams'] = l$streams?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$streams = streams;
    return Object.hashAll([l$streams]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams$game ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$streams = streams;
    final lOther$streams = other.streams;
    if (l$streams != lOther$streams) {
      return false;
    }
    return true;
  }
}

class Query$FlowGameStreams$game$streams {
  Query$FlowGameStreams$game$streams({this.edges, this.pageInfo});

  factory Query$FlowGameStreams$game$streams.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowGameStreams$game$streams(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowGameStreams$game$streams$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowGameStreams$game$streams$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowGameStreams$game$streams$edges?>? edges;

  final Query$FlowGameStreams$game$streams$pageInfo? pageInfo;

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
    if (other is! Query$FlowGameStreams$game$streams ||
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

class Query$FlowGameStreams$game$streams$edges {
  Query$FlowGameStreams$game$streams$edges({this.cursor, this.node});

  factory Query$FlowGameStreams$game$streams$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowGameStreams$game$streams$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowGameStreams$game$streams$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowGameStreams$game$streams$edges$node? node;

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
    if (other is! Query$FlowGameStreams$game$streams$edges ||
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

class Query$FlowGameStreams$game$streams$edges$node {
  Query$FlowGameStreams$game$streams$edges$node({
    this.id,
    this.broadcaster,
    this.createdAt,
    this.freeformTags,
    this.game,
    this.previewImageURL,
    this.viewersCount,
  });

  factory Query$FlowGameStreams$game$streams$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$broadcaster = json.containsKey('broadcaster')
        ? json['broadcaster']
        : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$freeformTags = json.containsKey('freeformTags')
        ? json['freeformTags']
        : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    final l$previewImageURL = json.containsKey('previewImageURL')
        ? json['previewImageURL']
        : null;
    final l$viewersCount = json.containsKey('viewersCount')
        ? json['viewersCount']
        : null;
    return Query$FlowGameStreams$game$streams$edges$node(
      id: (l$id as String?),
      broadcaster: l$broadcaster == null
          ? null
          : Query$FlowGameStreams$game$streams$edges$node$broadcaster.fromJson(
              (l$broadcaster as Map<String, dynamic>),
            ),
      createdAt: (l$createdAt as String?),
      freeformTags: (l$freeformTags as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowGameStreams$game$streams$edges$node$freeformTags.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      game: l$game == null
          ? null
          : Query$FlowGameStreams$game$streams$edges$node$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      previewImageURL: (l$previewImageURL as String?),
      viewersCount: (l$viewersCount as int?),
    );
  }

  final String? id;

  final Query$FlowGameStreams$game$streams$edges$node$broadcaster? broadcaster;

  final String? createdAt;

  final List<Query$FlowGameStreams$game$streams$edges$node$freeformTags?>?
  freeformTags;

  final Query$FlowGameStreams$game$streams$edges$node$game? game;

  final String? previewImageURL;

  final int? viewersCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$broadcaster = broadcaster;
    _resultData['broadcaster'] = l$broadcaster?.toJson();
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$freeformTags = freeformTags;
    _resultData['freeformTags'] = l$freeformTags
        ?.map((e) => e?.toJson())
        .toList();
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    final l$previewImageURL = previewImageURL;
    _resultData['previewImageURL'] = l$previewImageURL;
    final l$viewersCount = viewersCount;
    _resultData['viewersCount'] = l$viewersCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$broadcaster = broadcaster;
    final l$createdAt = createdAt;
    final l$freeformTags = freeformTags;
    final l$game = game;
    final l$previewImageURL = previewImageURL;
    final l$viewersCount = viewersCount;
    return Object.hashAll([
      l$id,
      l$broadcaster,
      l$createdAt,
      l$freeformTags == null
          ? null
          : Object.hashAll(l$freeformTags.map((v) => v)),
      l$game,
      l$previewImageURL,
      l$viewersCount,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams$game$streams$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$broadcaster = broadcaster;
    final lOther$broadcaster = other.broadcaster;
    if (l$broadcaster != lOther$broadcaster) {
      return false;
    }
    final l$createdAt = createdAt;
    final lOther$createdAt = other.createdAt;
    if (l$createdAt != lOther$createdAt) {
      return false;
    }
    final l$freeformTags = freeformTags;
    final lOther$freeformTags = other.freeformTags;
    if (l$freeformTags != null && lOther$freeformTags != null) {
      if (l$freeformTags.length != lOther$freeformTags.length) {
        return false;
      }
      for (int i = 0; i < l$freeformTags.length; i++) {
        final l$freeformTags$entry = l$freeformTags[i];
        final lOther$freeformTags$entry = lOther$freeformTags[i];
        if (l$freeformTags$entry != lOther$freeformTags$entry) {
          return false;
        }
      }
    } else if (l$freeformTags != lOther$freeformTags) {
      return false;
    }
    final l$game = game;
    final lOther$game = other.game;
    if (l$game != lOther$game) {
      return false;
    }
    final l$previewImageURL = previewImageURL;
    final lOther$previewImageURL = other.previewImageURL;
    if (l$previewImageURL != lOther$previewImageURL) {
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

class Query$FlowGameStreams$game$streams$edges$node$broadcaster {
  Query$FlowGameStreams$game$streams$edges$node$broadcaster({
    this.id,
    this.login,
    this.displayName,
    this.isPartner,
    this.profileImageURL,
    this.broadcastSettings,
  });

  factory Query$FlowGameStreams$game$streams$edges$node$broadcaster.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$isPartner = json.containsKey('isPartner')
        ? json['isPartner']
        : null;
    final l$profileImageURL = json.containsKey('profileImageURL')
        ? json['profileImageURL']
        : null;
    final l$broadcastSettings = json.containsKey('broadcastSettings')
        ? json['broadcastSettings']
        : null;
    return Query$FlowGameStreams$game$streams$edges$node$broadcaster(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
      isPartner: (l$isPartner as bool?),
      profileImageURL: (l$profileImageURL as String?),
      broadcastSettings: l$broadcastSettings == null
          ? null
          : Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings.fromJson(
              (l$broadcastSettings as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  final bool? isPartner;

  final String? profileImageURL;

  final Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings?
  broadcastSettings;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$isPartner = isPartner;
    _resultData['isPartner'] = l$isPartner;
    final l$profileImageURL = profileImageURL;
    _resultData['profileImageURL'] = l$profileImageURL;
    final l$broadcastSettings = broadcastSettings;
    _resultData['broadcastSettings'] = l$broadcastSettings?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    final l$isPartner = isPartner;
    final l$profileImageURL = profileImageURL;
    final l$broadcastSettings = broadcastSettings;
    return Object.hashAll([
      l$id,
      l$login,
      l$displayName,
      l$isPartner,
      l$profileImageURL,
      l$broadcastSettings,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams$game$streams$edges$node$broadcaster ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    final l$displayName = displayName;
    final lOther$displayName = other.displayName;
    if (l$displayName != lOther$displayName) {
      return false;
    }
    final l$isPartner = isPartner;
    final lOther$isPartner = other.isPartner;
    if (l$isPartner != lOther$isPartner) {
      return false;
    }
    final l$profileImageURL = profileImageURL;
    final lOther$profileImageURL = other.profileImageURL;
    if (l$profileImageURL != lOther$profileImageURL) {
      return false;
    }
    final l$broadcastSettings = broadcastSettings;
    final lOther$broadcastSettings = other.broadcastSettings;
    if (l$broadcastSettings != lOther$broadcastSettings) {
      return false;
    }
    return true;
  }
}

class Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings {
  Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings({
    this.title,
  });

  factory Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$title = json.containsKey('title') ? json['title'] : null;
    return Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings(
      title: (l$title as String?),
    );
  }

  final String? title;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$title = title;
    _resultData['title'] = l$title;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$title = title;
    return Object.hashAll([l$title]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowGameStreams$game$streams$edges$node$broadcaster$broadcastSettings ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    return true;
  }
}

class Query$FlowGameStreams$game$streams$edges$node$freeformTags {
  Query$FlowGameStreams$game$streams$edges$node$freeformTags({this.name});

  factory Query$FlowGameStreams$game$streams$edges$node$freeformTags.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$name = json.containsKey('name') ? json['name'] : null;
    return Query$FlowGameStreams$game$streams$edges$node$freeformTags(
      name: (l$name as String?),
    );
  }

  final String? name;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$name = name;
    _resultData['name'] = l$name;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$name = name;
    return Object.hashAll([l$name]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams$game$streams$edges$node$freeformTags ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$name = name;
    final lOther$name = other.name;
    if (l$name != lOther$name) {
      return false;
    }
    return true;
  }
}

class Query$FlowGameStreams$game$streams$edges$node$game {
  Query$FlowGameStreams$game$streams$edges$node$game({
    this.id,
    this.displayName,
  });

  factory Query$FlowGameStreams$game$streams$edges$node$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowGameStreams$game$streams$edges$node$game(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowGameStreams$game$streams$edges$node$game ||
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
    return true;
  }
}

class Query$FlowGameStreams$game$streams$pageInfo {
  Query$FlowGameStreams$game$streams$pageInfo({this.hasNextPage});

  factory Query$FlowGameStreams$game$streams$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowGameStreams$game$streams$pageInfo(
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
    if (other is! Query$FlowGameStreams$game$streams$pageInfo ||
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
