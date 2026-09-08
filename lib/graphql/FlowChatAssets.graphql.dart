// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowChatAssets {
  factory Variables$Query$FlowChatAssets({required String login}) =>
      Variables$Query$FlowChatAssets._({r'login': login});

  Variables$Query$FlowChatAssets._(this._$data);

  factory Variables$Query$FlowChatAssets.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    return Variables$Query$FlowChatAssets._(result$data);
  }

  Map<String, dynamic> _$data;

  String get login => (_$data['login'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$login = login;
    result$data['login'] = l$login;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowChatAssets ||
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

  @override
  int get hashCode {
    final l$login = login;
    return Object.hashAll([l$login]);
  }
}

class Query$FlowChatAssets {
  Query$FlowChatAssets({this.badges, this.emoteSet, this.user});

  factory Query$FlowChatAssets.fromJson(Map<String, dynamic> json) {
    final l$badges = json.containsKey('badges') ? json['badges'] : null;
    final l$emoteSet = json.containsKey('emoteSet') ? json['emoteSet'] : null;
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowChatAssets(
      badges: (l$badges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$badges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      emoteSet: l$emoteSet == null
          ? null
          : Query$FlowChatAssets$emoteSet.fromJson(
              (l$emoteSet as Map<String, dynamic>),
            ),
      user: l$user == null
          ? null
          : Query$FlowChatAssets$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowChatAssets$badges?>? badges;

  final Query$FlowChatAssets$emoteSet? emoteSet;

  final Query$FlowChatAssets$user? user;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$badges = badges;
    _resultData['badges'] = l$badges?.map((e) => e?.toJson()).toList();
    final l$emoteSet = emoteSet;
    _resultData['emoteSet'] = l$emoteSet?.toJson();
    final l$user = user;
    _resultData['user'] = l$user?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$badges = badges;
    final l$emoteSet = emoteSet;
    final l$user = user;
    return Object.hashAll([
      l$badges == null ? null : Object.hashAll(l$badges.map((v) => v)),
      l$emoteSet,
      l$user,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets || runtimeType != other.runtimeType) {
      return false;
    }
    final l$badges = badges;
    final lOther$badges = other.badges;
    if (l$badges != null && lOther$badges != null) {
      if (l$badges.length != lOther$badges.length) {
        return false;
      }
      for (int i = 0; i < l$badges.length; i++) {
        final l$badges$entry = l$badges[i];
        final lOther$badges$entry = lOther$badges[i];
        if (l$badges$entry != lOther$badges$entry) {
          return false;
        }
      }
    } else if (l$badges != lOther$badges) {
      return false;
    }
    final l$emoteSet = emoteSet;
    final lOther$emoteSet = other.emoteSet;
    if (l$emoteSet != lOther$emoteSet) {
      return false;
    }
    final l$user = user;
    final lOther$user = other.user;
    if (l$user != lOther$user) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowChatAssets = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChatAssets'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'login')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'badges'),
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
                  name: NameNode(value: 'version'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'title'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'imageURL'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'size'),
                      value: EnumValueNode(name: NameNode(value: 'DOUBLE')),
                    ),
                  ],
                  directives: [],
                  selectionSet: null,
                ),
              ],
            ),
          ),
          FieldNode(
            name: NameNode(value: 'emoteSet'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: StringValueNode(value: '0', isBlock: false),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
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
          FieldNode(
            name: NameNode(value: 'user'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'login'),
                value: VariableNode(name: NameNode(value: 'login')),
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
                  name: NameNode(value: 'broadcastBadges'),
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
                        name: NameNode(value: 'version'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'title'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'imageURL'),
                        alias: null,
                        arguments: [
                          ArgumentNode(
                            name: NameNode(value: 'size'),
                            value: EnumValueNode(
                              name: NameNode(value: 'DOUBLE'),
                            ),
                          ),
                        ],
                        directives: [],
                        selectionSet: null,
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'subscriptionProducts'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
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
                FieldNode(
                  name: NameNode(value: 'channel'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'localEmoteSets'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
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
              ],
            ),
          ),
        ],
      ),
    ),
  ],
);
Query$FlowChatAssets _parserFn$Query$FlowChatAssets(
  Map<String, dynamic> data,
) => Query$FlowChatAssets.fromJson(data);
typedef OnQueryComplete$Query$FlowChatAssets =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChatAssets?);

class Options$Query$FlowChatAssets
    extends graphql.QueryOptions<Query$FlowChatAssets> {
  Options$Query$FlowChatAssets({
    String? operationName,
    required Variables$Query$FlowChatAssets variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatAssets? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChatAssets? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChatAssets(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChatAssets,
         parserFn: _parserFn$Query$FlowChatAssets,
       );

  final OnQueryComplete$Query$FlowChatAssets? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChatAssets
    extends graphql.WatchQueryOptions<Query$FlowChatAssets> {
  WatchOptions$Query$FlowChatAssets({
    String? operationName,
    required Variables$Query$FlowChatAssets variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatAssets? typedOptimisticResult,
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
         document: documentNodeQueryFlowChatAssets,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChatAssets,
       );
}

class FetchMoreOptions$Query$FlowChatAssets extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChatAssets({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChatAssets variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChatAssets,
       );
}

extension ClientExtension$Query$FlowChatAssets on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChatAssets>> query$FlowChatAssets(
    Options$Query$FlowChatAssets options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChatAssets> watchQuery$FlowChatAssets(
    WatchOptions$Query$FlowChatAssets options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChatAssets({
    required Query$FlowChatAssets data,
    required Variables$Query$FlowChatAssets variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowChatAssets),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChatAssets? readQuery$FlowChatAssets({
    required Variables$Query$FlowChatAssets variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowChatAssets),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChatAssets.fromJson(result);
  }
}

class Query$FlowChatAssets$badges {
  Query$FlowChatAssets$badges({
    this.setID,
    this.version,
    this.title,
    this.imageURL,
  });

  factory Query$FlowChatAssets$badges.fromJson(Map<String, dynamic> json) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$imageURL = json.containsKey('imageURL') ? json['imageURL'] : null;
    return Query$FlowChatAssets$badges(
      setID: (l$setID as String?),
      version: (l$version as String?),
      title: (l$title as String?),
      imageURL: (l$imageURL as String?),
    );
  }

  final String? setID;

  final String? version;

  final String? title;

  final String? imageURL;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    final l$title = title;
    _resultData['title'] = l$title;
    final l$imageURL = imageURL;
    _resultData['imageURL'] = l$imageURL;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$setID = setID;
    final l$version = version;
    final l$title = title;
    final l$imageURL = imageURL;
    return Object.hashAll([l$setID, l$version, l$title, l$imageURL]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$badges ||
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
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    final l$imageURL = imageURL;
    final lOther$imageURL = other.imageURL;
    if (l$imageURL != lOther$imageURL) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatAssets$emoteSet {
  Query$FlowChatAssets$emoteSet({this.emotes});

  factory Query$FlowChatAssets$emoteSet.fromJson(Map<String, dynamic> json) {
    final l$emotes = json.containsKey('emotes') ? json['emotes'] : null;
    return Query$FlowChatAssets$emoteSet(
      emotes: (l$emotes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$emoteSet$emotes.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowChatAssets$emoteSet$emotes?>? emotes;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emotes = emotes;
    _resultData['emotes'] = l$emotes?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emotes = emotes;
    return Object.hashAll([
      l$emotes == null ? null : Object.hashAll(l$emotes.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$emoteSet ||
        runtimeType != other.runtimeType) {
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

class Query$FlowChatAssets$emoteSet$emotes {
  Query$FlowChatAssets$emoteSet$emotes({this.id, this.token});

  factory Query$FlowChatAssets$emoteSet$emotes.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$token = json.containsKey('token') ? json['token'] : null;
    return Query$FlowChatAssets$emoteSet$emotes(
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
    if (other is! Query$FlowChatAssets$emoteSet$emotes ||
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

class Query$FlowChatAssets$user {
  Query$FlowChatAssets$user({
    this.id,
    this.broadcastBadges,
    this.subscriptionProducts,
    this.channel,
  });

  factory Query$FlowChatAssets$user.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$broadcastBadges = json.containsKey('broadcastBadges')
        ? json['broadcastBadges']
        : null;
    final l$subscriptionProducts = json.containsKey('subscriptionProducts')
        ? json['subscriptionProducts']
        : null;
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowChatAssets$user(
      id: (l$id as String?),
      broadcastBadges: (l$broadcastBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$user$broadcastBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      subscriptionProducts: (l$subscriptionProducts as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$user$subscriptionProducts.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      channel: l$channel == null
          ? null
          : Query$FlowChatAssets$user$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final List<Query$FlowChatAssets$user$broadcastBadges?>? broadcastBadges;

  final List<Query$FlowChatAssets$user$subscriptionProducts?>?
  subscriptionProducts;

  final Query$FlowChatAssets$user$channel? channel;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$broadcastBadges = broadcastBadges;
    _resultData['broadcastBadges'] = l$broadcastBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$subscriptionProducts = subscriptionProducts;
    _resultData['subscriptionProducts'] = l$subscriptionProducts
        ?.map((e) => e?.toJson())
        .toList();
    final l$channel = channel;
    _resultData['channel'] = l$channel?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$broadcastBadges = broadcastBadges;
    final l$subscriptionProducts = subscriptionProducts;
    final l$channel = channel;
    return Object.hashAll([
      l$id,
      l$broadcastBadges == null
          ? null
          : Object.hashAll(l$broadcastBadges.map((v) => v)),
      l$subscriptionProducts == null
          ? null
          : Object.hashAll(l$subscriptionProducts.map((v) => v)),
      l$channel,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$user ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$broadcastBadges = broadcastBadges;
    final lOther$broadcastBadges = other.broadcastBadges;
    if (l$broadcastBadges != null && lOther$broadcastBadges != null) {
      if (l$broadcastBadges.length != lOther$broadcastBadges.length) {
        return false;
      }
      for (int i = 0; i < l$broadcastBadges.length; i++) {
        final l$broadcastBadges$entry = l$broadcastBadges[i];
        final lOther$broadcastBadges$entry = lOther$broadcastBadges[i];
        if (l$broadcastBadges$entry != lOther$broadcastBadges$entry) {
          return false;
        }
      }
    } else if (l$broadcastBadges != lOther$broadcastBadges) {
      return false;
    }
    final l$subscriptionProducts = subscriptionProducts;
    final lOther$subscriptionProducts = other.subscriptionProducts;
    if (l$subscriptionProducts != null && lOther$subscriptionProducts != null) {
      if (l$subscriptionProducts.length != lOther$subscriptionProducts.length) {
        return false;
      }
      for (int i = 0; i < l$subscriptionProducts.length; i++) {
        final l$subscriptionProducts$entry = l$subscriptionProducts[i];
        final lOther$subscriptionProducts$entry =
            lOther$subscriptionProducts[i];
        if (l$subscriptionProducts$entry != lOther$subscriptionProducts$entry) {
          return false;
        }
      }
    } else if (l$subscriptionProducts != lOther$subscriptionProducts) {
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

class Query$FlowChatAssets$user$broadcastBadges {
  Query$FlowChatAssets$user$broadcastBadges({
    this.setID,
    this.version,
    this.title,
    this.imageURL,
  });

  factory Query$FlowChatAssets$user$broadcastBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$imageURL = json.containsKey('imageURL') ? json['imageURL'] : null;
    return Query$FlowChatAssets$user$broadcastBadges(
      setID: (l$setID as String?),
      version: (l$version as String?),
      title: (l$title as String?),
      imageURL: (l$imageURL as String?),
    );
  }

  final String? setID;

  final String? version;

  final String? title;

  final String? imageURL;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    final l$title = title;
    _resultData['title'] = l$title;
    final l$imageURL = imageURL;
    _resultData['imageURL'] = l$imageURL;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$setID = setID;
    final l$version = version;
    final l$title = title;
    final l$imageURL = imageURL;
    return Object.hashAll([l$setID, l$version, l$title, l$imageURL]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$user$broadcastBadges ||
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
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    final l$imageURL = imageURL;
    final lOther$imageURL = other.imageURL;
    if (l$imageURL != lOther$imageURL) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatAssets$user$subscriptionProducts {
  Query$FlowChatAssets$user$subscriptionProducts({this.emotes});

  factory Query$FlowChatAssets$user$subscriptionProducts.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emotes = json.containsKey('emotes') ? json['emotes'] : null;
    return Query$FlowChatAssets$user$subscriptionProducts(
      emotes: (l$emotes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$user$subscriptionProducts$emotes.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowChatAssets$user$subscriptionProducts$emotes?>? emotes;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emotes = emotes;
    _resultData['emotes'] = l$emotes?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emotes = emotes;
    return Object.hashAll([
      l$emotes == null ? null : Object.hashAll(l$emotes.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$user$subscriptionProducts ||
        runtimeType != other.runtimeType) {
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

class Query$FlowChatAssets$user$subscriptionProducts$emotes {
  Query$FlowChatAssets$user$subscriptionProducts$emotes({this.id, this.token});

  factory Query$FlowChatAssets$user$subscriptionProducts$emotes.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$token = json.containsKey('token') ? json['token'] : null;
    return Query$FlowChatAssets$user$subscriptionProducts$emotes(
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
    if (other is! Query$FlowChatAssets$user$subscriptionProducts$emotes ||
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

class Query$FlowChatAssets$user$channel {
  Query$FlowChatAssets$user$channel({this.localEmoteSets});

  factory Query$FlowChatAssets$user$channel.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$localEmoteSets = json.containsKey('localEmoteSets')
        ? json['localEmoteSets']
        : null;
    return Query$FlowChatAssets$user$channel(
      localEmoteSets: (l$localEmoteSets as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$user$channel$localEmoteSets.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowChatAssets$user$channel$localEmoteSets?>? localEmoteSets;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$localEmoteSets = localEmoteSets;
    _resultData['localEmoteSets'] = l$localEmoteSets
        ?.map((e) => e?.toJson())
        .toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$localEmoteSets = localEmoteSets;
    return Object.hashAll([
      l$localEmoteSets == null
          ? null
          : Object.hashAll(l$localEmoteSets.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$user$channel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$localEmoteSets = localEmoteSets;
    final lOther$localEmoteSets = other.localEmoteSets;
    if (l$localEmoteSets != null && lOther$localEmoteSets != null) {
      if (l$localEmoteSets.length != lOther$localEmoteSets.length) {
        return false;
      }
      for (int i = 0; i < l$localEmoteSets.length; i++) {
        final l$localEmoteSets$entry = l$localEmoteSets[i];
        final lOther$localEmoteSets$entry = lOther$localEmoteSets[i];
        if (l$localEmoteSets$entry != lOther$localEmoteSets$entry) {
          return false;
        }
      }
    } else if (l$localEmoteSets != lOther$localEmoteSets) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatAssets$user$channel$localEmoteSets {
  Query$FlowChatAssets$user$channel$localEmoteSets({this.emotes});

  factory Query$FlowChatAssets$user$channel$localEmoteSets.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emotes = json.containsKey('emotes') ? json['emotes'] : null;
    return Query$FlowChatAssets$user$channel$localEmoteSets(
      emotes: (l$emotes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatAssets$user$channel$localEmoteSets$emotes.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowChatAssets$user$channel$localEmoteSets$emotes?>? emotes;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emotes = emotes;
    _resultData['emotes'] = l$emotes?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emotes = emotes;
    return Object.hashAll([
      l$emotes == null ? null : Object.hashAll(l$emotes.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAssets$user$channel$localEmoteSets ||
        runtimeType != other.runtimeType) {
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

class Query$FlowChatAssets$user$channel$localEmoteSets$emotes {
  Query$FlowChatAssets$user$channel$localEmoteSets$emotes({
    this.id,
    this.token,
  });

  factory Query$FlowChatAssets$user$channel$localEmoteSets$emotes.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$token = json.containsKey('token') ? json['token'] : null;
    return Query$FlowChatAssets$user$channel$localEmoteSets$emotes(
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
    if (other is! Query$FlowChatAssets$user$channel$localEmoteSets$emotes ||
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
