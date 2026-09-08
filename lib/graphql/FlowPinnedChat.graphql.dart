// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowPinnedChat {
  factory Variables$Query$FlowPinnedChat({required String channelID}) =>
      Variables$Query$FlowPinnedChat._({r'channelID': channelID});

  Variables$Query$FlowPinnedChat._(this._$data);

  factory Variables$Query$FlowPinnedChat.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    return Variables$Query$FlowPinnedChat._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowPinnedChat ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    return Object.hashAll([l$channelID]);
  }
}

class Query$FlowPinnedChat {
  Query$FlowPinnedChat({this.channel});

  factory Query$FlowPinnedChat.fromJson(Map<String, dynamic> json) {
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowPinnedChat(
      channel: l$channel == null
          ? null
          : Query$FlowPinnedChat$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowPinnedChat$channel? channel;

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
    if (other is! Query$FlowPinnedChat || runtimeType != other.runtimeType) {
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

const documentNodeQueryFlowPinnedChat = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowPinnedChat'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'channelID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
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
                  name: NameNode(value: 'pinnedChatMessages'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'first'),
                      value: IntValueNode(value: '1'),
                    ),
                    ArgumentNode(
                      name: NameNode(value: 'messageType'),
                      value: EnumValueNode(name: NameNode(value: 'MOD')),
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
                                    name: NameNode(value: 'endsAt'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'pinnedBy'),
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
                                    name: NameNode(value: 'pinnedMessage'),
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
                                          name: NameNode(value: 'sentAt'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(
                                            value: 'senderChatColor',
                                          ),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(value: 'senderBadges'),
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
                                          name: NameNode(value: 'content'),
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
                                                name: NameNode(
                                                  value: 'fragments',
                                                ),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'text',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'content',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: SelectionSetNode(
                                                        selections: [
                                                          FieldNode(
                                                            name: NameNode(
                                                              value:
                                                                  '__typename',
                                                            ),
                                                            alias: null,
                                                            arguments: [],
                                                            directives: [],
                                                            selectionSet: null,
                                                          ),
                                                          InlineFragmentNode(
                                                            typeCondition:
                                                                TypeConditionNode(
                                                                  on: NamedTypeNode(
                                                                    name: NameNode(
                                                                      value:
                                                                          'Emote',
                                                                    ),
                                                                    isNonNull:
                                                                        false,
                                                                  ),
                                                                ),
                                                            directives: [],
                                                            selectionSet: SelectionSetNode(
                                                              selections: [
                                                                FieldNode(
                                                                  name: NameNode(
                                                                    value: 'id',
                                                                  ),
                                                                  alias: NameNode(
                                                                    value:
                                                                        'emoteID',
                                                                  ),
                                                                  arguments: [],
                                                                  directives:
                                                                      [],
                                                                  selectionSet:
                                                                      null,
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
                                        FieldNode(
                                          name: NameNode(value: 'sender'),
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
                                                name: NameNode(
                                                  value: 'displayName',
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
                                          name: NameNode(
                                            value: 'parentMessage',
                                          ),
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
                                                  value: 'content',
                                                ),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'text',
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
                                                name: NameNode(value: 'sender'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'id',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'login',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'displayName',
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
                                          name: NameNode(
                                            value: 'threadParentMessage',
                                          ),
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
                                                name: NameNode(value: 'sender'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'login',
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
      ),
    ),
  ],
);
Query$FlowPinnedChat _parserFn$Query$FlowPinnedChat(
  Map<String, dynamic> data,
) => Query$FlowPinnedChat.fromJson(data);
typedef OnQueryComplete$Query$FlowPinnedChat =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowPinnedChat?);

class Options$Query$FlowPinnedChat
    extends graphql.QueryOptions<Query$FlowPinnedChat> {
  Options$Query$FlowPinnedChat({
    String? operationName,
    required Variables$Query$FlowPinnedChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowPinnedChat? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowPinnedChat? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowPinnedChat(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowPinnedChat,
         parserFn: _parserFn$Query$FlowPinnedChat,
       );

  final OnQueryComplete$Query$FlowPinnedChat? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowPinnedChat
    extends graphql.WatchQueryOptions<Query$FlowPinnedChat> {
  WatchOptions$Query$FlowPinnedChat({
    String? operationName,
    required Variables$Query$FlowPinnedChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowPinnedChat? typedOptimisticResult,
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
         document: documentNodeQueryFlowPinnedChat,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowPinnedChat,
       );
}

class FetchMoreOptions$Query$FlowPinnedChat extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowPinnedChat({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowPinnedChat variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowPinnedChat,
       );
}

extension ClientExtension$Query$FlowPinnedChat on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowPinnedChat>> query$FlowPinnedChat(
    Options$Query$FlowPinnedChat options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowPinnedChat> watchQuery$FlowPinnedChat(
    WatchOptions$Query$FlowPinnedChat options,
  ) => this.watchQuery(options);

  void writeQuery$FlowPinnedChat({
    required Query$FlowPinnedChat data,
    required Variables$Query$FlowPinnedChat variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowPinnedChat),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowPinnedChat? readQuery$FlowPinnedChat({
    required Variables$Query$FlowPinnedChat variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowPinnedChat),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowPinnedChat.fromJson(result);
  }
}

class Query$FlowPinnedChat$channel {
  Query$FlowPinnedChat$channel({this.id, this.pinnedChatMessages});

  factory Query$FlowPinnedChat$channel.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$pinnedChatMessages = json.containsKey('pinnedChatMessages')
        ? json['pinnedChatMessages']
        : null;
    return Query$FlowPinnedChat$channel(
      id: (l$id as String?),
      pinnedChatMessages: l$pinnedChatMessages == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages.fromJson(
              (l$pinnedChatMessages as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowPinnedChat$channel$pinnedChatMessages? pinnedChatMessages;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$pinnedChatMessages = pinnedChatMessages;
    _resultData['pinnedChatMessages'] = l$pinnedChatMessages?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$pinnedChatMessages = pinnedChatMessages;
    return Object.hashAll([l$id, l$pinnedChatMessages]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPinnedChat$channel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$pinnedChatMessages = pinnedChatMessages;
    final lOther$pinnedChatMessages = other.pinnedChatMessages;
    if (l$pinnedChatMessages != lOther$pinnedChatMessages) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages {
  Query$FlowPinnedChat$channel$pinnedChatMessages({this.edges});

  factory Query$FlowPinnedChat$channel$pinnedChatMessages.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowPinnedChat$channel$pinnedChatMessages$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowPinnedChat$channel$pinnedChatMessages$edges?>? edges;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$edges = edges;
    _resultData['edges'] = l$edges?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$edges = edges;
    return Object.hashAll([
      l$edges == null ? null : Object.hashAll(l$edges.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPinnedChat$channel$pinnedChatMessages ||
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
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges({this.node});

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges(
      node: l$node == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node? node;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$node = node;
    _resultData['node'] = l$node?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$node = node;
    return Object.hashAll([l$node]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges ||
        runtimeType != other.runtimeType) {
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

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node({
    this.id,
    this.endsAt,
    this.pinnedBy,
    this.pinnedMessage,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$endsAt = json.containsKey('endsAt') ? json['endsAt'] : null;
    final l$pinnedBy = json.containsKey('pinnedBy') ? json['pinnedBy'] : null;
    final l$pinnedMessage = json.containsKey('pinnedMessage')
        ? json['pinnedMessage']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node(
      id: (l$id as String?),
      endsAt: (l$endsAt as String?),
      pinnedBy: l$pinnedBy == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy.fromJson(
              (l$pinnedBy as Map<String, dynamic>),
            ),
      pinnedMessage: l$pinnedMessage == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage.fromJson(
              (l$pinnedMessage as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? endsAt;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy?
  pinnedBy;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage?
  pinnedMessage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$endsAt = endsAt;
    _resultData['endsAt'] = l$endsAt;
    final l$pinnedBy = pinnedBy;
    _resultData['pinnedBy'] = l$pinnedBy?.toJson();
    final l$pinnedMessage = pinnedMessage;
    _resultData['pinnedMessage'] = l$pinnedMessage?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$endsAt = endsAt;
    final l$pinnedBy = pinnedBy;
    final l$pinnedMessage = pinnedMessage;
    return Object.hashAll([l$id, l$endsAt, l$pinnedBy, l$pinnedMessage]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$endsAt = endsAt;
    final lOther$endsAt = other.endsAt;
    if (l$endsAt != lOther$endsAt) {
      return false;
    }
    final l$pinnedBy = pinnedBy;
    final lOther$pinnedBy = other.pinnedBy;
    if (l$pinnedBy != lOther$pinnedBy) {
      return false;
    }
    final l$pinnedMessage = pinnedMessage;
    final lOther$pinnedMessage = other.pinnedMessage;
    if (l$pinnedMessage != lOther$pinnedMessage) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy(
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
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedBy ||
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

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage({
    this.id,
    this.sentAt,
    this.senderChatColor,
    this.senderBadges,
    this.content,
    this.sender,
    this.parentMessage,
    this.threadParentMessage,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sentAt = json.containsKey('sentAt') ? json['sentAt'] : null;
    final l$senderChatColor = json.containsKey('senderChatColor')
        ? json['senderChatColor']
        : null;
    final l$senderBadges = json.containsKey('senderBadges')
        ? json['senderBadges']
        : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    final l$parentMessage = json.containsKey('parentMessage')
        ? json['parentMessage']
        : null;
    final l$threadParentMessage = json.containsKey('threadParentMessage')
        ? json['threadParentMessage']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage(
      id: (l$id as String?),
      sentAt: (l$sentAt as String?),
      senderChatColor: (l$senderChatColor as String?),
      senderBadges: (l$senderBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      content: l$content == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      sender: l$sender == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
      parentMessage: l$parentMessage == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage.fromJson(
              (l$parentMessage as Map<String, dynamic>),
            ),
      threadParentMessage: l$threadParentMessage == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage.fromJson(
              (l$threadParentMessage as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? sentAt;

  final String? senderChatColor;

  final List<
    Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges?
  >?
  senderBadges;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content?
  content;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender?
  sender;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage?
  parentMessage;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage?
  threadParentMessage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sentAt = sentAt;
    _resultData['sentAt'] = l$sentAt;
    final l$senderChatColor = senderChatColor;
    _resultData['senderChatColor'] = l$senderChatColor;
    final l$senderBadges = senderBadges;
    _resultData['senderBadges'] = l$senderBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    final l$parentMessage = parentMessage;
    _resultData['parentMessage'] = l$parentMessage?.toJson();
    final l$threadParentMessage = threadParentMessage;
    _resultData['threadParentMessage'] = l$threadParentMessage?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sentAt = sentAt;
    final l$senderChatColor = senderChatColor;
    final l$senderBadges = senderBadges;
    final l$content = content;
    final l$sender = sender;
    final l$parentMessage = parentMessage;
    final l$threadParentMessage = threadParentMessage;
    return Object.hashAll([
      l$id,
      l$sentAt,
      l$senderChatColor,
      l$senderBadges == null
          ? null
          : Object.hashAll(l$senderBadges.map((v) => v)),
      l$content,
      l$sender,
      l$parentMessage,
      l$threadParentMessage,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sentAt = sentAt;
    final lOther$sentAt = other.sentAt;
    if (l$sentAt != lOther$sentAt) {
      return false;
    }
    final l$senderChatColor = senderChatColor;
    final lOther$senderChatColor = other.senderChatColor;
    if (l$senderChatColor != lOther$senderChatColor) {
      return false;
    }
    final l$senderBadges = senderBadges;
    final lOther$senderBadges = other.senderBadges;
    if (l$senderBadges != null && lOther$senderBadges != null) {
      if (l$senderBadges.length != lOther$senderBadges.length) {
        return false;
      }
      for (int i = 0; i < l$senderBadges.length; i++) {
        final l$senderBadges$entry = l$senderBadges[i];
        final lOther$senderBadges$entry = lOther$senderBadges[i];
        if (l$senderBadges$entry != lOther$senderBadges$entry) {
          return false;
        }
      }
    } else if (l$senderBadges != lOther$senderBadges) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    final l$parentMessage = parentMessage;
    final lOther$parentMessage = other.parentMessage;
    if (l$parentMessage != lOther$parentMessage) {
      return false;
    }
    final l$threadParentMessage = threadParentMessage;
    final lOther$threadParentMessage = other.threadParentMessage;
    if (l$threadParentMessage != lOther$threadParentMessage) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges({
    this.setID,
    this.version,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges(
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
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$senderBadges ||
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

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content({
    this.text,
    this.fragments,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content(
      text: (l$text as String?),
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? text;

  final List<
    Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments?
  >?
  fragments;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$fragments = fragments;
    _resultData['fragments'] = l$fragments?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$fragments = fragments;
    return Object.hashAll([
      l$text,
      l$fragments == null ? null : Object.hashAll(l$fragments.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
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
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments({
    this.text,
    this.content,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments(
      text: (l$text as String?),
      content: l$content == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content?
  content;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$content = content;
    return Object.hashAll([l$text, l$content]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content({
    required this.$__typename,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "Emote":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote.fromJson(
          json,
        );

      case "ActivityFeedCheermote":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
          json,
        );

      case "ActivityFeedIntegerToken":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
          json,
        );

      case "ActivityFeedPercentToken":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
          json,
        );

      case "ActivityFeedTextToken":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
          json,
        );

      case "User":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User.fromJson(
          json,
        );

      case "UserDoesNotExist":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist.fromJson(
          json,
        );

      case "UserError":
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content(
          $__typename: (l$$__typename as String),
        );
    }
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content
    on
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  _T when<_T>({
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote,
    )
    emote,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote,
    )
    activityFeedCheermote,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )
    activityFeedIntegerToken,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken,
    )
    activityFeedPercentToken,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken,
    )
    activityFeedTextToken,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User,
    )
    user,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist,
    )
    userDoesNotExist,
    required _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError,
    )
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        return emote(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote,
        );

      case "ActivityFeedCheermote":
        return activityFeedCheermote(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote,
        );

      case "ActivityFeedIntegerToken":
        return activityFeedIntegerToken(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken,
        );

      case "ActivityFeedPercentToken":
        return activityFeedPercentToken(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken,
        );

      case "ActivityFeedTextToken":
        return activityFeedTextToken(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken,
        );

      case "User":
        return user(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User,
        );

      case "UserDoesNotExist":
        return userDoesNotExist(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist,
        );

      case "UserError":
        return userError(
          this
              as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote,
    )?
    emote,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote,
    )?
    activityFeedCheermote,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )?
    activityFeedIntegerToken,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken,
    )?
    activityFeedPercentToken,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken,
    )?
    activityFeedTextToken,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User,
    )?
    user,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist,
    )?
    userDoesNotExist,
    _T Function(
      Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError,
    )?
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        if (emote != null) {
          return emote(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedCheermote":
        if (activityFeedCheermote != null) {
          return activityFeedCheermote(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedIntegerToken":
        if (activityFeedIntegerToken != null) {
          return activityFeedIntegerToken(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedPercentToken":
        if (activityFeedPercentToken != null) {
          return activityFeedPercentToken(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedTextToken":
        if (activityFeedTextToken != null) {
          return activityFeedTextToken(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken,
          );
        } else {
          return orElse();
        }

      case "User":
        if (user != null) {
          return user(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User,
          );
        } else {
          return orElse();
        }

      case "UserDoesNotExist":
        if (userDoesNotExist != null) {
          return userDoesNotExist(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist,
          );
        } else {
          return orElse();
        }

      case "UserError":
        if (userError != null) {
          return userError(
            this
                as Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote({
    this.emoteID,
    this.$__typename = 'Emote',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote(
      emoteID: (l$emoteID as String?),
      $__typename: (l$$__typename as String),
    );
  }

  final String? emoteID;

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emoteID = emoteID;
    _resultData['emoteID'] = l$emoteID;
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emoteID = emoteID;
    final l$$__typename = $__typename;
    return Object.hashAll([l$emoteID, l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$Emote ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$emoteID = emoteID;
    final lOther$emoteID = other.emoteID;
    if (l$emoteID != lOther$emoteID) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote({
    this.$__typename = 'ActivityFeedCheermote',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedCheermote ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken({
    this.$__typename = 'ActivityFeedIntegerToken',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedIntegerToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken({
    this.$__typename = 'ActivityFeedPercentToken',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedPercentToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken({
    this.$__typename = 'ActivityFeedTextToken',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$ActivityFeedTextToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User({
    this.$__typename = 'User',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$User ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist({
    this.$__typename = 'UserDoesNotExist',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserDoesNotExist ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError
    implements
        Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError({
    this.$__typename = 'UserError',
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$content$fragments$content$$UserError ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender(
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
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$sender ||
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

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage({
    this.id,
    this.content,
    this.sender,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage(
      id: (l$id as String?),
      content: l$content == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      sender: l$sender == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content?
  content;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender?
  sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$content = content;
    final l$sender = sender;
    return Object.hashAll([l$id, l$content, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content({
    this.text,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content(
      text: (l$text as String?),
    );
  }

  final String? text;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    return Object.hashAll([l$text]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender(
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
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$parentMessage$sender ||
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

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage({
    this.id,
    this.sender,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage(
      id: (l$id as String?),
      sender: l$sender == null
          ? null
          : Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender?
  sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sender = sender;
    return Object.hashAll([l$id, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender {
  Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender({
    this.login,
  });

  factory Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender(
      login: (l$login as String?),
    );
  }

  final String? login;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$login = login;
    _resultData['login'] = l$login;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$login = login;
    return Object.hashAll([l$login]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPinnedChat$channel$pinnedChatMessages$edges$node$pinnedMessage$threadParentMessage$sender ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    return true;
  }
}
