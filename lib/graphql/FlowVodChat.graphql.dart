// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowVodChat {
  factory Variables$Query$FlowVodChat({
    required String videoId,
    int? offsetSeconds,
    String? cursor,
  }) => Variables$Query$FlowVodChat._({
    r'videoId': videoId,
    if (offsetSeconds != null) r'offsetSeconds': offsetSeconds,
    if (cursor != null) r'cursor': cursor,
  });

  Variables$Query$FlowVodChat._(this._$data);

  factory Variables$Query$FlowVodChat.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$videoId = data['videoId'];
    result$data['videoId'] = (l$videoId as String);
    if (data.containsKey('offsetSeconds')) {
      final l$offsetSeconds = data['offsetSeconds'];
      result$data['offsetSeconds'] = (l$offsetSeconds as int?);
    }
    if (data.containsKey('cursor')) {
      final l$cursor = data['cursor'];
      result$data['cursor'] = (l$cursor as String?);
    }
    return Variables$Query$FlowVodChat._(result$data);
  }

  Map<String, dynamic> _$data;

  String get videoId => (_$data['videoId'] as String);

  int? get offsetSeconds => (_$data['offsetSeconds'] as int?);

  String? get cursor => (_$data['cursor'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$videoId = videoId;
    result$data['videoId'] = l$videoId;
    final l$offsetSeconds = _$data.containsKey('offsetSeconds')
        ? offsetSeconds
        : null;
    result$data['offsetSeconds'] = l$offsetSeconds;
    final l$cursor = _$data.containsKey('cursor') ? cursor : null;
    result$data['cursor'] = l$cursor;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowVodChat ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$videoId = videoId;
    final lOther$videoId = other.videoId;
    if (l$videoId != lOther$videoId) {
      return false;
    }
    final l$offsetSeconds = offsetSeconds;
    final lOther$offsetSeconds = other.offsetSeconds;
    if (_$data.containsKey('offsetSeconds') !=
        other._$data.containsKey('offsetSeconds')) {
      return false;
    }
    if (l$offsetSeconds != lOther$offsetSeconds) {
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
    final l$videoId = videoId;
    final l$offsetSeconds = offsetSeconds;
    final l$cursor = cursor;
    return Object.hashAll([
      l$videoId,
      _$data.containsKey('offsetSeconds') ? l$offsetSeconds : const {},
      _$data.containsKey('cursor') ? l$cursor : const {},
    ]);
  }
}

class Query$FlowVodChat {
  Query$FlowVodChat({this.video});

  factory Query$FlowVodChat.fromJson(Map<String, dynamic> json) {
    final l$video = json.containsKey('video') ? json['video'] : null;
    return Query$FlowVodChat(
      video: l$video == null
          ? null
          : Query$FlowVodChat$video.fromJson((l$video as Map<String, dynamic>)),
    );
  }

  final Query$FlowVodChat$video? video;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$video = video;
    _resultData['video'] = l$video?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$video = video;
    return Object.hashAll([l$video]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodChat || runtimeType != other.runtimeType) {
      return false;
    }
    final l$video = video;
    final lOther$video = other.video;
    if (l$video != lOther$video) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowVodChat = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowVodChat'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'videoId')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'offsetSeconds')),
          type: NamedTypeNode(name: NameNode(value: 'Int'), isNonNull: false),
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
            name: NameNode(value: 'video'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'videoId')),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'comments'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'contentOffsetSeconds'),
                      value: VariableNode(
                        name: NameNode(value: 'offsetSeconds'),
                      ),
                    ),
                    ArgumentNode(
                      name: NameNode(value: 'after'),
                      value: VariableNode(name: NameNode(value: 'cursor')),
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
                                    name: NameNode(
                                      value: 'contentOffsetSeconds',
                                    ),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'commenter'),
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
                                      ],
                                    ),
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'message'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: SelectionSetNode(
                                      selections: [
                                        FieldNode(
                                          name: NameNode(value: 'fragments'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: SelectionSetNode(
                                            selections: [
                                              FieldNode(
                                                name: NameNode(value: 'text'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: null,
                                              ),
                                              FieldNode(
                                                name: NameNode(value: 'emote'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'emoteID',
                                                      ),
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
                                          name: NameNode(value: 'userBadges'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: SelectionSetNode(
                                            selections: [
                                              FieldNode(
                                                name: NameNode(value: 'setID'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: null,
                                              ),
                                              FieldNode(
                                                name: NameNode(
                                                  value: 'version',
                                                ),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        FieldNode(
                                          name: NameNode(value: 'userColor'),
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
);
Query$FlowVodChat _parserFn$Query$FlowVodChat(Map<String, dynamic> data) =>
    Query$FlowVodChat.fromJson(data);
typedef OnQueryComplete$Query$FlowVodChat =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowVodChat?);

class Options$Query$FlowVodChat
    extends graphql.QueryOptions<Query$FlowVodChat> {
  Options$Query$FlowVodChat({
    String? operationName,
    required Variables$Query$FlowVodChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowVodChat? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowVodChat? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowVodChat(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowVodChat,
         parserFn: _parserFn$Query$FlowVodChat,
       );

  final OnQueryComplete$Query$FlowVodChat? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowVodChat
    extends graphql.WatchQueryOptions<Query$FlowVodChat> {
  WatchOptions$Query$FlowVodChat({
    String? operationName,
    required Variables$Query$FlowVodChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowVodChat? typedOptimisticResult,
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
         document: documentNodeQueryFlowVodChat,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowVodChat,
       );
}

class FetchMoreOptions$Query$FlowVodChat extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowVodChat({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowVodChat variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowVodChat,
       );
}

extension ClientExtension$Query$FlowVodChat on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowVodChat>> query$FlowVodChat(
    Options$Query$FlowVodChat options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowVodChat> watchQuery$FlowVodChat(
    WatchOptions$Query$FlowVodChat options,
  ) => this.watchQuery(options);

  void writeQuery$FlowVodChat({
    required Query$FlowVodChat data,
    required Variables$Query$FlowVodChat variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowVodChat),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowVodChat? readQuery$FlowVodChat({
    required Variables$Query$FlowVodChat variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowVodChat),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowVodChat.fromJson(result);
  }
}

class Query$FlowVodChat$video {
  Query$FlowVodChat$video({this.comments});

  factory Query$FlowVodChat$video.fromJson(Map<String, dynamic> json) {
    final l$comments = json.containsKey('comments') ? json['comments'] : null;
    return Query$FlowVodChat$video(
      comments: l$comments == null
          ? null
          : Query$FlowVodChat$video$comments.fromJson(
              (l$comments as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowVodChat$video$comments? comments;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$comments = comments;
    _resultData['comments'] = l$comments?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$comments = comments;
    return Object.hashAll([l$comments]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodChat$video || runtimeType != other.runtimeType) {
      return false;
    }
    final l$comments = comments;
    final lOther$comments = other.comments;
    if (l$comments != lOther$comments) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments {
  Query$FlowVodChat$video$comments({this.edges, this.pageInfo});

  factory Query$FlowVodChat$video$comments.fromJson(Map<String, dynamic> json) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowVodChat$video$comments(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowVodChat$video$comments$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowVodChat$video$comments$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowVodChat$video$comments$edges?>? edges;

  final Query$FlowVodChat$video$comments$pageInfo? pageInfo;

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
    if (other is! Query$FlowVodChat$video$comments ||
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

class Query$FlowVodChat$video$comments$edges {
  Query$FlowVodChat$video$comments$edges({this.cursor, this.node});

  factory Query$FlowVodChat$video$comments$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowVodChat$video$comments$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowVodChat$video$comments$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowVodChat$video$comments$edges$node? node;

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
    if (other is! Query$FlowVodChat$video$comments$edges ||
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

class Query$FlowVodChat$video$comments$edges$node {
  Query$FlowVodChat$video$comments$edges$node({
    this.id,
    this.contentOffsetSeconds,
    this.commenter,
    this.message,
  });

  factory Query$FlowVodChat$video$comments$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$contentOffsetSeconds = json.containsKey('contentOffsetSeconds')
        ? json['contentOffsetSeconds']
        : null;
    final l$commenter = json.containsKey('commenter')
        ? json['commenter']
        : null;
    final l$message = json.containsKey('message') ? json['message'] : null;
    return Query$FlowVodChat$video$comments$edges$node(
      id: (l$id as String?),
      contentOffsetSeconds: (l$contentOffsetSeconds as int?),
      commenter: l$commenter == null
          ? null
          : Query$FlowVodChat$video$comments$edges$node$commenter.fromJson(
              (l$commenter as Map<String, dynamic>),
            ),
      message: l$message == null
          ? null
          : Query$FlowVodChat$video$comments$edges$node$message.fromJson(
              (l$message as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final int? contentOffsetSeconds;

  final Query$FlowVodChat$video$comments$edges$node$commenter? commenter;

  final Query$FlowVodChat$video$comments$edges$node$message? message;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$contentOffsetSeconds = contentOffsetSeconds;
    _resultData['contentOffsetSeconds'] = l$contentOffsetSeconds;
    final l$commenter = commenter;
    _resultData['commenter'] = l$commenter?.toJson();
    final l$message = message;
    _resultData['message'] = l$message?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$contentOffsetSeconds = contentOffsetSeconds;
    final l$commenter = commenter;
    final l$message = message;
    return Object.hashAll([
      l$id,
      l$contentOffsetSeconds,
      l$commenter,
      l$message,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodChat$video$comments$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$contentOffsetSeconds = contentOffsetSeconds;
    final lOther$contentOffsetSeconds = other.contentOffsetSeconds;
    if (l$contentOffsetSeconds != lOther$contentOffsetSeconds) {
      return false;
    }
    final l$commenter = commenter;
    final lOther$commenter = other.commenter;
    if (l$commenter != lOther$commenter) {
      return false;
    }
    final l$message = message;
    final lOther$message = other.message;
    if (l$message != lOther$message) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments$edges$node$commenter {
  Query$FlowVodChat$video$comments$edges$node$commenter({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowVodChat$video$comments$edges$node$commenter.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowVodChat$video$comments$edges$node$commenter(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$login, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodChat$video$comments$edges$node$commenter ||
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
    return true;
  }
}

class Query$FlowVodChat$video$comments$edges$node$message {
  Query$FlowVodChat$video$comments$edges$node$message({
    this.fragments,
    this.userBadges,
    this.userColor,
  });

  factory Query$FlowVodChat$video$comments$edges$node$message.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    final l$userBadges = json.containsKey('userBadges')
        ? json['userBadges']
        : null;
    final l$userColor = json.containsKey('userColor')
        ? json['userColor']
        : null;
    return Query$FlowVodChat$video$comments$edges$node$message(
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowVodChat$video$comments$edges$node$message$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      userBadges: (l$userBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowVodChat$video$comments$edges$node$message$userBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      userColor: (l$userColor as String?),
    );
  }

  final List<Query$FlowVodChat$video$comments$edges$node$message$fragments?>?
  fragments;

  final List<Query$FlowVodChat$video$comments$edges$node$message$userBadges?>?
  userBadges;

  final String? userColor;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$fragments = fragments;
    _resultData['fragments'] = l$fragments?.map((e) => e?.toJson()).toList();
    final l$userBadges = userBadges;
    _resultData['userBadges'] = l$userBadges?.map((e) => e?.toJson()).toList();
    final l$userColor = userColor;
    _resultData['userColor'] = l$userColor;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$fragments = fragments;
    final l$userBadges = userBadges;
    final l$userColor = userColor;
    return Object.hashAll([
      l$fragments == null ? null : Object.hashAll(l$fragments.map((v) => v)),
      l$userBadges == null ? null : Object.hashAll(l$userBadges.map((v) => v)),
      l$userColor,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodChat$video$comments$edges$node$message ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$fragments = fragments;
    final lOther$fragments = other.fragments;
    if (l$fragments != null && lOther$fragments != null) {
      if (l$fragments.length != lOther$fragments.length) {
        return false;
      }
      for (int i = 0; i < l$fragments.length; i++) {
        final l$fragments$entry = l$fragments[i];
        final lOther$fragments$entry = lOther$fragments[i];
        if (l$fragments$entry != lOther$fragments$entry) {
          return false;
        }
      }
    } else if (l$fragments != lOther$fragments) {
      return false;
    }
    final l$userBadges = userBadges;
    final lOther$userBadges = other.userBadges;
    if (l$userBadges != null && lOther$userBadges != null) {
      if (l$userBadges.length != lOther$userBadges.length) {
        return false;
      }
      for (int i = 0; i < l$userBadges.length; i++) {
        final l$userBadges$entry = l$userBadges[i];
        final lOther$userBadges$entry = lOther$userBadges[i];
        if (l$userBadges$entry != lOther$userBadges$entry) {
          return false;
        }
      }
    } else if (l$userBadges != lOther$userBadges) {
      return false;
    }
    final l$userColor = userColor;
    final lOther$userColor = other.userColor;
    if (l$userColor != lOther$userColor) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments$edges$node$message$fragments {
  Query$FlowVodChat$video$comments$edges$node$message$fragments({
    this.text,
    this.emote,
  });

  factory Query$FlowVodChat$video$comments$edges$node$message$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$emote = json.containsKey('emote') ? json['emote'] : null;
    return Query$FlowVodChat$video$comments$edges$node$message$fragments(
      text: (l$text as String?),
      emote: l$emote == null
          ? null
          : Query$FlowVodChat$video$comments$edges$node$message$fragments$emote.fromJson(
              (l$emote as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Query$FlowVodChat$video$comments$edges$node$message$fragments$emote?
  emote;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$emote = emote;
    _resultData['emote'] = l$emote?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$emote = emote;
    return Object.hashAll([l$text, l$emote]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodChat$video$comments$edges$node$message$fragments ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$emote = emote;
    final lOther$emote = other.emote;
    if (l$emote != lOther$emote) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments$edges$node$message$fragments$emote {
  Query$FlowVodChat$video$comments$edges$node$message$fragments$emote({
    this.emoteID,
  });

  factory Query$FlowVodChat$video$comments$edges$node$message$fragments$emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    return Query$FlowVodChat$video$comments$edges$node$message$fragments$emote(
      emoteID: (l$emoteID as String?),
    );
  }

  final String? emoteID;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emoteID = emoteID;
    _resultData['emoteID'] = l$emoteID;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emoteID = emoteID;
    return Object.hashAll([l$emoteID]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodChat$video$comments$edges$node$message$fragments$emote ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$emoteID = emoteID;
    final lOther$emoteID = other.emoteID;
    if (l$emoteID != lOther$emoteID) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments$edges$node$message$userBadges {
  Query$FlowVodChat$video$comments$edges$node$message$userBadges({
    this.setID,
    this.version,
  });

  factory Query$FlowVodChat$video$comments$edges$node$message$userBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    return Query$FlowVodChat$video$comments$edges$node$message$userBadges(
      setID: (l$setID as String?),
      version: (l$version as String?),
    );
  }

  final String? setID;

  final String? version;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$setID = setID;
    final l$version = version;
    return Object.hashAll([l$setID, l$version]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodChat$video$comments$edges$node$message$userBadges ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$setID = setID;
    final lOther$setID = other.setID;
    if (l$setID != lOther$setID) {
      return false;
    }
    final l$version = version;
    final lOther$version = other.version;
    if (l$version != lOther$version) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodChat$video$comments$pageInfo {
  Query$FlowVodChat$video$comments$pageInfo({this.hasNextPage});

  factory Query$FlowVodChat$video$comments$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowVodChat$video$comments$pageInfo(
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
    if (other is! Query$FlowVodChat$video$comments$pageInfo ||
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
