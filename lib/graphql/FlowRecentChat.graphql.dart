// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowRecentChat {
  factory Variables$Query$FlowRecentChat({required String channelID}) =>
      Variables$Query$FlowRecentChat._({r'channelID': channelID});

  Variables$Query$FlowRecentChat._(this._$data);

  factory Variables$Query$FlowRecentChat.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    return Variables$Query$FlowRecentChat._(result$data);
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
    if (other is! Variables$Query$FlowRecentChat ||
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

class Query$FlowRecentChat {
  Query$FlowRecentChat({this.channel});

  factory Query$FlowRecentChat.fromJson(Map<String, dynamic> json) {
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowRecentChat(
      channel: l$channel == null
          ? null
          : Query$FlowRecentChat$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowRecentChat$channel? channel;

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
    if (other is! Query$FlowRecentChat || runtimeType != other.runtimeType) {
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

const documentNodeQueryFlowRecentChat = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowRecentChat'),
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
                  name: NameNode(value: 'recentChatMessages'),
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
                        name: NameNode(value: 'deletedAt'),
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
                        name: NameNode(value: 'senderChatColor'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'senderBadges'),
                        alias: null,
                        arguments: [
                          ArgumentNode(
                            name: NameNode(value: 'channelID'),
                            value: VariableNode(
                              name: NameNode(value: 'channelID'),
                            ),
                          ),
                        ],
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
                              name: NameNode(value: 'version'),
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
                                    name: NameNode(value: 'content'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: SelectionSetNode(
                                      selections: [
                                        FieldNode(
                                          name: NameNode(value: '__typename'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        InlineFragmentNode(
                                          typeCondition: TypeConditionNode(
                                            on: NamedTypeNode(
                                              name: NameNode(value: 'Emote'),
                                              isNonNull: false,
                                            ),
                                          ),
                                          directives: [],
                                          selectionSet: SelectionSetNode(
                                            selections: [
                                              FieldNode(
                                                name: NameNode(value: 'id'),
                                                alias: NameNode(
                                                  value: 'emoteID',
                                                ),
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
                      FieldNode(
                        name: NameNode(value: 'parentMessage'),
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
                                          name: NameNode(value: 'content'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: SelectionSetNode(
                                            selections: [
                                              FieldNode(
                                                name: NameNode(
                                                  value: '__typename',
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
                                                          value: 'Emote',
                                                        ),
                                                        isNonNull: false,
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
                                                        value: 'emoteID',
                                                      ),
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
                                    name: NameNode(value: 'displayName'),
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
                        name: NameNode(value: 'threadParentMessage'),
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
                                    name: NameNode(value: 'login'),
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
Query$FlowRecentChat _parserFn$Query$FlowRecentChat(
  Map<String, dynamic> data,
) => Query$FlowRecentChat.fromJson(data);
typedef OnQueryComplete$Query$FlowRecentChat =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowRecentChat?);

class Options$Query$FlowRecentChat
    extends graphql.QueryOptions<Query$FlowRecentChat> {
  Options$Query$FlowRecentChat({
    String? operationName,
    required Variables$Query$FlowRecentChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowRecentChat? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowRecentChat? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowRecentChat(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowRecentChat,
         parserFn: _parserFn$Query$FlowRecentChat,
       );

  final OnQueryComplete$Query$FlowRecentChat? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowRecentChat
    extends graphql.WatchQueryOptions<Query$FlowRecentChat> {
  WatchOptions$Query$FlowRecentChat({
    String? operationName,
    required Variables$Query$FlowRecentChat variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowRecentChat? typedOptimisticResult,
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
         document: documentNodeQueryFlowRecentChat,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowRecentChat,
       );
}

class FetchMoreOptions$Query$FlowRecentChat extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowRecentChat({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowRecentChat variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowRecentChat,
       );
}

extension ClientExtension$Query$FlowRecentChat on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowRecentChat>> query$FlowRecentChat(
    Options$Query$FlowRecentChat options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowRecentChat> watchQuery$FlowRecentChat(
    WatchOptions$Query$FlowRecentChat options,
  ) => this.watchQuery(options);

  void writeQuery$FlowRecentChat({
    required Query$FlowRecentChat data,
    required Variables$Query$FlowRecentChat variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowRecentChat),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowRecentChat? readQuery$FlowRecentChat({
    required Variables$Query$FlowRecentChat variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowRecentChat),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowRecentChat.fromJson(result);
  }
}

class Query$FlowRecentChat$channel {
  Query$FlowRecentChat$channel({this.id, this.recentChatMessages});

  factory Query$FlowRecentChat$channel.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$recentChatMessages = json.containsKey('recentChatMessages')
        ? json['recentChatMessages']
        : null;
    return Query$FlowRecentChat$channel(
      id: (l$id as String?),
      recentChatMessages: (l$recentChatMessages as List<dynamic>?)
          ?.map(
            (e) => Query$FlowRecentChat$channel$recentChatMessages.fromJson(
              (e as Map<String, dynamic>),
            ),
          )
          .toList(),
    );
  }

  final String? id;

  final List<Query$FlowRecentChat$channel$recentChatMessages>?
  recentChatMessages;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$recentChatMessages = recentChatMessages;
    _resultData['recentChatMessages'] = l$recentChatMessages
        ?.map((e) => e.toJson())
        .toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$recentChatMessages = recentChatMessages;
    return Object.hashAll([
      l$id,
      l$recentChatMessages == null
          ? null
          : Object.hashAll(l$recentChatMessages.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowRecentChat$channel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$recentChatMessages = recentChatMessages;
    final lOther$recentChatMessages = other.recentChatMessages;
    if (l$recentChatMessages != null && lOther$recentChatMessages != null) {
      if (l$recentChatMessages.length != lOther$recentChatMessages.length) {
        return false;
      }
      for (int i = 0; i < l$recentChatMessages.length; i++) {
        final l$recentChatMessages$entry = l$recentChatMessages[i];
        final lOther$recentChatMessages$entry = lOther$recentChatMessages[i];
        if (l$recentChatMessages$entry != lOther$recentChatMessages$entry) {
          return false;
        }
      }
    } else if (l$recentChatMessages != lOther$recentChatMessages) {
      return false;
    }
    return true;
  }
}

class Query$FlowRecentChat$channel$recentChatMessages {
  Query$FlowRecentChat$channel$recentChatMessages({
    this.id,
    this.sentAt,
    this.deletedAt,
    this.sender,
    this.senderChatColor,
    this.senderBadges,
    this.content,
    this.parentMessage,
    this.threadParentMessage,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sentAt = json.containsKey('sentAt') ? json['sentAt'] : null;
    final l$deletedAt = json.containsKey('deletedAt')
        ? json['deletedAt']
        : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    final l$senderChatColor = json.containsKey('senderChatColor')
        ? json['senderChatColor']
        : null;
    final l$senderBadges = json.containsKey('senderBadges')
        ? json['senderBadges']
        : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$parentMessage = json.containsKey('parentMessage')
        ? json['parentMessage']
        : null;
    final l$threadParentMessage = json.containsKey('threadParentMessage')
        ? json['threadParentMessage']
        : null;
    return Query$FlowRecentChat$channel$recentChatMessages(
      id: (l$id as String?),
      sentAt: (l$sentAt as String?),
      deletedAt: (l$deletedAt as String?),
      sender: l$sender == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
      senderChatColor: (l$senderChatColor as String?),
      senderBadges: (l$senderBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowRecentChat$channel$recentChatMessages$senderBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      content: l$content == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      parentMessage: l$parentMessage == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$parentMessage.fromJson(
              (l$parentMessage as Map<String, dynamic>),
            ),
      threadParentMessage: l$threadParentMessage == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage.fromJson(
              (l$threadParentMessage as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? sentAt;

  final String? deletedAt;

  final Query$FlowRecentChat$channel$recentChatMessages$sender? sender;

  final String? senderChatColor;

  final List<Query$FlowRecentChat$channel$recentChatMessages$senderBadges?>?
  senderBadges;

  final Query$FlowRecentChat$channel$recentChatMessages$content? content;

  final Query$FlowRecentChat$channel$recentChatMessages$parentMessage?
  parentMessage;

  final Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage?
  threadParentMessage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sentAt = sentAt;
    _resultData['sentAt'] = l$sentAt;
    final l$deletedAt = deletedAt;
    _resultData['deletedAt'] = l$deletedAt;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    final l$senderChatColor = senderChatColor;
    _resultData['senderChatColor'] = l$senderChatColor;
    final l$senderBadges = senderBadges;
    _resultData['senderBadges'] = l$senderBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
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
    final l$deletedAt = deletedAt;
    final l$sender = sender;
    final l$senderChatColor = senderChatColor;
    final l$senderBadges = senderBadges;
    final l$content = content;
    final l$parentMessage = parentMessage;
    final l$threadParentMessage = threadParentMessage;
    return Object.hashAll([
      l$id,
      l$sentAt,
      l$deletedAt,
      l$sender,
      l$senderChatColor,
      l$senderBadges == null
          ? null
          : Object.hashAll(l$senderBadges.map((v) => v)),
      l$content,
      l$parentMessage,
      l$threadParentMessage,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowRecentChat$channel$recentChatMessages ||
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
    final l$deletedAt = deletedAt;
    final lOther$deletedAt = other.deletedAt;
    if (l$deletedAt != lOther$deletedAt) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
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

class Query$FlowRecentChat$channel$recentChatMessages$sender {
  Query$FlowRecentChat$channel$recentChatMessages$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowRecentChat$channel$recentChatMessages$sender(
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
    if (other is! Query$FlowRecentChat$channel$recentChatMessages$sender ||
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

class Query$FlowRecentChat$channel$recentChatMessages$senderBadges {
  Query$FlowRecentChat$channel$recentChatMessages$senderBadges({
    this.setID,
    this.version,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$senderBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$senderBadges(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$senderBadges ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content {
  Query$FlowRecentChat$channel$recentChatMessages$content({
    this.text,
    this.fragments,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    return Query$FlowRecentChat$channel$recentChatMessages$content(
      text: (l$text as String?),
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowRecentChat$channel$recentChatMessages$content$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? text;

  final List<
    Query$FlowRecentChat$channel$recentChatMessages$content$fragments?
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
    if (other is! Query$FlowRecentChat$channel$recentChatMessages$content ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments({
    this.text,
    this.content,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments(
      text: (l$text as String?),
      content: l$content == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content?
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content({
    required this.$__typename,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "Emote":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote.fromJson(
          json,
        );

      case "ActivityFeedCheermote":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote.fromJson(
          json,
        );

      case "ActivityFeedIntegerToken":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
          json,
        );

      case "ActivityFeedPercentToken":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken.fromJson(
          json,
        );

      case "ActivityFeedTextToken":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken.fromJson(
          json,
        );

      case "User":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User.fromJson(
          json,
        );

      case "UserDoesNotExist":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist.fromJson(
          json,
        );

      case "UserError":
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content ||
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

extension UtilityExtension$Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content
    on Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  _T when<_T>({
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote,
    )
    emote,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote,
    )
    activityFeedCheermote,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken,
    )
    activityFeedIntegerToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken,
    )
    activityFeedPercentToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken,
    )
    activityFeedTextToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User,
    )
    user,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist,
    )
    userDoesNotExist,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError,
    )
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        return emote(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote,
        );

      case "ActivityFeedCheermote":
        return activityFeedCheermote(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote,
        );

      case "ActivityFeedIntegerToken":
        return activityFeedIntegerToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken,
        );

      case "ActivityFeedPercentToken":
        return activityFeedPercentToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken,
        );

      case "ActivityFeedTextToken":
        return activityFeedTextToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken,
        );

      case "User":
        return user(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User,
        );

      case "UserDoesNotExist":
        return userDoesNotExist(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist,
        );

      case "UserError":
        return userError(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote,
    )?
    emote,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote,
    )?
    activityFeedCheermote,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken,
    )?
    activityFeedIntegerToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken,
    )?
    activityFeedPercentToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken,
    )?
    activityFeedTextToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User,
    )?
    user,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist,
    )?
    userDoesNotExist,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError,
    )?
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        if (emote != null) {
          return emote(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedCheermote":
        if (activityFeedCheermote != null) {
          return activityFeedCheermote(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedIntegerToken":
        if (activityFeedIntegerToken != null) {
          return activityFeedIntegerToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedPercentToken":
        if (activityFeedPercentToken != null) {
          return activityFeedPercentToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedTextToken":
        if (activityFeedTextToken != null) {
          return activityFeedTextToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken,
          );
        } else {
          return orElse();
        }

      case "User":
        if (user != null) {
          return user(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User,
          );
        } else {
          return orElse();
        }

      case "UserDoesNotExist":
        if (userDoesNotExist != null) {
          return userDoesNotExist(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist,
          );
        } else {
          return orElse();
        }

      case "UserError":
        if (userError != null) {
          return userError(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote({
    this.emoteID,
    this.$__typename = 'Emote',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$Emote ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote({
    this.$__typename = 'ActivityFeedCheermote',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedCheermote ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken({
    this.$__typename = 'ActivityFeedIntegerToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedIntegerToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken({
    this.$__typename = 'ActivityFeedPercentToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedPercentToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken({
    this.$__typename = 'ActivityFeedTextToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$ActivityFeedTextToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User({
    this.$__typename = 'User',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$User ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist({
    this.$__typename = 'UserDoesNotExist',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserDoesNotExist ||
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

class Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError
    implements
        Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError({
    this.$__typename = 'UserError',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$content$fragments$content$$UserError ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage({
    this.id,
    this.content,
    this.sender,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage(
      id: (l$id as String?),
      content: l$content == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      sender: l$sender == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content?
  content;

  final Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender?
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content({
    this.text,
    this.fragments,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content(
      text: (l$text as String?),
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? text;

  final List<
    Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments?
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments({
    this.text,
    this.content,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments(
      text: (l$text as String?),
      content: l$content == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content?
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content({
    required this.$__typename,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "Emote":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote.fromJson(
          json,
        );

      case "ActivityFeedCheermote":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
          json,
        );

      case "ActivityFeedIntegerToken":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
          json,
        );

      case "ActivityFeedPercentToken":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
          json,
        );

      case "ActivityFeedTextToken":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
          json,
        );

      case "User":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User.fromJson(
          json,
        );

      case "UserDoesNotExist":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist.fromJson(
          json,
        );

      case "UserError":
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content ||
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

extension UtilityExtension$Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content
    on
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  _T when<_T>({
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote,
    )
    emote,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote,
    )
    activityFeedCheermote,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )
    activityFeedIntegerToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken,
    )
    activityFeedPercentToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken,
    )
    activityFeedTextToken,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User,
    )
    user,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist,
    )
    userDoesNotExist,
    required _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError,
    )
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        return emote(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote,
        );

      case "ActivityFeedCheermote":
        return activityFeedCheermote(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote,
        );

      case "ActivityFeedIntegerToken":
        return activityFeedIntegerToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken,
        );

      case "ActivityFeedPercentToken":
        return activityFeedPercentToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken,
        );

      case "ActivityFeedTextToken":
        return activityFeedTextToken(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken,
        );

      case "User":
        return user(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User,
        );

      case "UserDoesNotExist":
        return userDoesNotExist(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist,
        );

      case "UserError":
        return userError(
          this
              as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote,
    )?
    emote,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote,
    )?
    activityFeedCheermote,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )?
    activityFeedIntegerToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken,
    )?
    activityFeedPercentToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken,
    )?
    activityFeedTextToken,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User,
    )?
    user,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist,
    )?
    userDoesNotExist,
    _T Function(
      Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError,
    )?
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        if (emote != null) {
          return emote(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedCheermote":
        if (activityFeedCheermote != null) {
          return activityFeedCheermote(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedIntegerToken":
        if (activityFeedIntegerToken != null) {
          return activityFeedIntegerToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedPercentToken":
        if (activityFeedPercentToken != null) {
          return activityFeedPercentToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedTextToken":
        if (activityFeedTextToken != null) {
          return activityFeedTextToken(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken,
          );
        } else {
          return orElse();
        }

      case "User":
        if (user != null) {
          return user(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User,
          );
        } else {
          return orElse();
        }

      case "UserDoesNotExist":
        if (userDoesNotExist != null) {
          return userDoesNotExist(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist,
          );
        } else {
          return orElse();
        }

      case "UserError":
        if (userError != null) {
          return userError(
            this
                as Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote({
    this.emoteID,
    this.$__typename = 'Emote',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$Emote ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote({
    this.$__typename = 'ActivityFeedCheermote',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedCheermote ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken({
    this.$__typename = 'ActivityFeedIntegerToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedIntegerToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken({
    this.$__typename = 'ActivityFeedPercentToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedPercentToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken({
    this.$__typename = 'ActivityFeedTextToken',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$ActivityFeedTextToken ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User({
    this.$__typename = 'User',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$User ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist({
    this.$__typename = 'UserDoesNotExist',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserDoesNotExist ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError
    implements
        Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError({
    this.$__typename = 'UserError',
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$content$fragments$content$$UserError ||
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

class Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender {
  Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$parentMessage$sender ||
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

class Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage {
  Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage({
    this.id,
    this.sender,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage(
      id: (l$id as String?),
      sender: l$sender == null
          ? null
          : Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender?
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
            is! Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage ||
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

class Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender {
  Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender({
    this.login,
  });

  factory Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender(
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
            is! Query$FlowRecentChat$channel$recentChatMessages$threadParentMessage$sender ||
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
