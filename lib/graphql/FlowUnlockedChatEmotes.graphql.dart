// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowUnlockedChatEmotes {
  factory Variables$Query$FlowUnlockedChatEmotes({
    required String channelID,
    String? cursor,
  }) => Variables$Query$FlowUnlockedChatEmotes._({
    r'channelID': channelID,
    if (cursor != null) r'cursor': cursor,
  });

  Variables$Query$FlowUnlockedChatEmotes._(this._$data);

  factory Variables$Query$FlowUnlockedChatEmotes.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    if (data.containsKey('cursor')) {
      final l$cursor = data['cursor'];
      result$data['cursor'] = (l$cursor as String?);
    }
    return Variables$Query$FlowUnlockedChatEmotes._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String? get cursor => (_$data['cursor'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$cursor = _$data.containsKey('cursor') ? cursor : null;
    result$data['cursor'] = l$cursor;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowUnlockedChatEmotes ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$cursor = cursor;
    final lOther$cursor = other.cursor;
    if (_$data.containsKey('cursor') != other._$data.containsKey('cursor')) {
      return false;
    }
    if (l$cursor != lOther$cursor) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$cursor = cursor;
    return Object.hashAll([
      l$channelID,
      _$data.containsKey('cursor') ? l$cursor : const {},
    ]);
  }
}

class Query$FlowUnlockedChatEmotes {
  Query$FlowUnlockedChatEmotes({this.channel});

  factory Query$FlowUnlockedChatEmotes.fromJson(Map<String, dynamic> json) {
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowUnlockedChatEmotes(
      channel: l$channel == null
          ? null
          : Query$FlowUnlockedChatEmotes$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowUnlockedChatEmotes$channel? channel;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$channel = channel;
    _resultData['channel'] = l$channel?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$channel = channel;
    return Object.hashAll([l$channel]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUnlockedChatEmotes ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channel = channel;
    final lOther$channel = other.channel;
    if (l$channel != lOther$channel) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowUnlockedChatEmotes = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowUnlockedChatEmotes'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'channelID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'cursor')),
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
            name: NameNode(value: 'channel'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'channelID')),
              ),
            ],
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
                  name: NameNode(value: 'self'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'availableEmoteSetsPaginated'),
                        alias: null,
                        arguments: [
                          ArgumentNode(
                            name: NameNode(value: 'pageLimit'),
                            value: IntValueNode(value: '100'),
                          ),
                          ArgumentNode(
                            name: NameNode(value: 'after'),
                            value: VariableNode(
                              name: NameNode(value: 'cursor'),
                            ),
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
                                          name: NameNode(value: 'emotes'),
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
                                                name: NameNode(value: 'token'),
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
      ),
    ),
  ],
);
Query$FlowUnlockedChatEmotes _parserFn$Query$FlowUnlockedChatEmotes(
  Map<String, dynamic> data,
) => Query$FlowUnlockedChatEmotes.fromJson(data);
typedef OnQueryComplete$Query$FlowUnlockedChatEmotes =
    FutureOr<void> Function(
      Map<String, dynamic>?,
      Query$FlowUnlockedChatEmotes?,
    );

class Options$Query$FlowUnlockedChatEmotes
    extends graphql.QueryOptions<Query$FlowUnlockedChatEmotes> {
  Options$Query$FlowUnlockedChatEmotes({
    String? operationName,
    required Variables$Query$FlowUnlockedChatEmotes variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowUnlockedChatEmotes? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowUnlockedChatEmotes? onComplete,
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
                     : _parserFn$Query$FlowUnlockedChatEmotes(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowUnlockedChatEmotes,
         parserFn: _parserFn$Query$FlowUnlockedChatEmotes,
       );

  final OnQueryComplete$Query$FlowUnlockedChatEmotes? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowUnlockedChatEmotes
    extends graphql.WatchQueryOptions<Query$FlowUnlockedChatEmotes> {
  WatchOptions$Query$FlowUnlockedChatEmotes({
    String? operationName,
    required Variables$Query$FlowUnlockedChatEmotes variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowUnlockedChatEmotes? typedOptimisticResult,
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
         document: documentNodeQueryFlowUnlockedChatEmotes,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowUnlockedChatEmotes,
       );
}

class FetchMoreOptions$Query$FlowUnlockedChatEmotes
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowUnlockedChatEmotes({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowUnlockedChatEmotes variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowUnlockedChatEmotes,
       );
}

extension ClientExtension$Query$FlowUnlockedChatEmotes
    on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowUnlockedChatEmotes>>
  query$FlowUnlockedChatEmotes(
    Options$Query$FlowUnlockedChatEmotes options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowUnlockedChatEmotes>
  watchQuery$FlowUnlockedChatEmotes(
    WatchOptions$Query$FlowUnlockedChatEmotes options,
  ) => this.watchQuery(options);

  void writeQuery$FlowUnlockedChatEmotes({
    required Query$FlowUnlockedChatEmotes data,
    required Variables$Query$FlowUnlockedChatEmotes variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowUnlockedChatEmotes,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowUnlockedChatEmotes? readQuery$FlowUnlockedChatEmotes({
    required Variables$Query$FlowUnlockedChatEmotes variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowUnlockedChatEmotes,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null
        ? null
        : Query$FlowUnlockedChatEmotes.fromJson(result);
  }
}

class Query$FlowUnlockedChatEmotes$channel {
  Query$FlowUnlockedChatEmotes$channel({this.id, this.self});

  factory Query$FlowUnlockedChatEmotes$channel.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$self = json.containsKey('self') ? json['self'] : null;
    return Query$FlowUnlockedChatEmotes$channel(
      id: (l$id as String?),
      self: l$self == null
          ? null
          : Query$FlowUnlockedChatEmotes$channel$self.fromJson(
              (l$self as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowUnlockedChatEmotes$channel$self? self;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$self = self;
    _resultData['self'] = l$self?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$self = self;
    return Object.hashAll([l$id, l$self]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUnlockedChatEmotes$channel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$self = self;
    final lOther$self = other.self;
    if (l$self != lOther$self) {
      return false;
    }
    return true;
  }
}

class Query$FlowUnlockedChatEmotes$channel$self {
  Query$FlowUnlockedChatEmotes$channel$self({this.availableEmoteSetsPaginated});

  factory Query$FlowUnlockedChatEmotes$channel$self.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$availableEmoteSetsPaginated =
        json.containsKey('availableEmoteSetsPaginated')
        ? json['availableEmoteSetsPaginated']
        : null;
    return Query$FlowUnlockedChatEmotes$channel$self(
      availableEmoteSetsPaginated: l$availableEmoteSetsPaginated == null
          ? null
          : Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated.fromJson(
              (l$availableEmoteSetsPaginated as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated?
  availableEmoteSetsPaginated;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$availableEmoteSetsPaginated = availableEmoteSetsPaginated;
    _resultData['availableEmoteSetsPaginated'] = l$availableEmoteSetsPaginated
        ?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$availableEmoteSetsPaginated = availableEmoteSetsPaginated;
    return Object.hashAll([l$availableEmoteSetsPaginated]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUnlockedChatEmotes$channel$self ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$availableEmoteSetsPaginated = availableEmoteSetsPaginated;
    final lOther$availableEmoteSetsPaginated =
        other.availableEmoteSetsPaginated;
    if (l$availableEmoteSetsPaginated != lOther$availableEmoteSetsPaginated) {
      return false;
    }
    return true;
  }
}

class Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated {
  Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated({
    this.edges,
    this.pageInfo,
  });

  factory Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<
    Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges?
  >?
  edges;

  final Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo?
  pageInfo;

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
    if (other
            is! Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated ||
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

class Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges {
  Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges({
    this.cursor,
    this.node,
  });

  factory Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node?
  node;

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
    if (other
            is! Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges ||
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

class Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node {
  Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node({
    this.id,
    this.emotes,
  });

  factory Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$emotes = json.containsKey('emotes') ? json['emotes'] : null;
    return Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node(
      id: (l$id as String?),
      emotes: (l$emotes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? id;

  final List<
    Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes?
  >?
  emotes;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$emotes = emotes;
    _resultData['emotes'] = l$emotes?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$emotes = emotes;
    return Object.hashAll([
      l$id,
      l$emotes == null ? null : Object.hashAll(l$emotes.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$emotes = emotes;
    final lOther$emotes = other.emotes;
    if (l$emotes != null && lOther$emotes != null) {
      if (l$emotes.length != lOther$emotes.length) {
        return false;
      }
      for (int i = 0; i < l$emotes.length; i++) {
        final l$emotes$entry = l$emotes[i];
        final lOther$emotes$entry = lOther$emotes[i];
        if (l$emotes$entry != lOther$emotes$entry) {
          return false;
        }
      }
    } else if (l$emotes != lOther$emotes) {
      return false;
    }
    return true;
  }
}

class Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes {
  Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes({
    this.id,
    this.token,
  });

  factory Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$token = json.containsKey('token') ? json['token'] : null;
    return Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes(
      id: (l$id as String?),
      token: (l$token as String?),
    );
  }

  final String? id;

  final String? token;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$token = token;
    _resultData['token'] = l$token;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$token = token;
    return Object.hashAll([l$id, l$token]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$edges$node$emotes ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$token = token;
    final lOther$token = other.token;
    if (l$token != lOther$token) {
      return false;
    }
    return true;
  }
}

class Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo {
  Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo({
    this.hasNextPage,
  });

  factory Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo(
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
    if (other
            is! Query$FlowUnlockedChatEmotes$channel$self$availableEmoteSetsPaginated$pageInfo ||
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
