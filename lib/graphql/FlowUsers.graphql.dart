// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowUsers {
  factory Variables$Query$FlowUsers({
    List<String>? ids,
    List<String>? logins,
  }) => Variables$Query$FlowUsers._({
    if (ids != null) r'ids': ids,
    if (logins != null) r'logins': logins,
  });

  Variables$Query$FlowUsers._(this._$data);

  factory Variables$Query$FlowUsers.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('ids')) {
      final l$ids = data['ids'];
      result$data['ids'] = (l$ids as List<dynamic>?)
          ?.map((e) => (e as String))
          .toList();
    }
    if (data.containsKey('logins')) {
      final l$logins = data['logins'];
      result$data['logins'] = (l$logins as List<dynamic>?)
          ?.map((e) => (e as String))
          .toList();
    }
    return Variables$Query$FlowUsers._(result$data);
  }

  Map<String, dynamic> _$data;

  List<String>? get ids => (_$data['ids'] as List<String>?);

  List<String>? get logins => (_$data['logins'] as List<String>?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$ids = _$data.containsKey('ids') ? ids : null;
    result$data['ids'] = l$ids?.map((e) => e).toList();
    final l$logins = _$data.containsKey('logins') ? logins : null;
    result$data['logins'] = l$logins?.map((e) => e).toList();
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowUsers ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$ids = ids;
    final lOther$ids = other.ids;
    if (_$data.containsKey('ids') != other._$data.containsKey('ids')) {
      return false;
    }
    if (l$ids != null && lOther$ids != null) {
      if (l$ids.length != lOther$ids.length) {
        return false;
      }
      for (int i = 0; i < l$ids.length; i++) {
        final l$ids$entry = l$ids[i];
        final lOther$ids$entry = lOther$ids[i];
        if (l$ids$entry != lOther$ids$entry) {
          return false;
        }
      }
    } else if (l$ids != lOther$ids) {
      return false;
    }
    final l$logins = logins;
    final lOther$logins = other.logins;
    if (_$data.containsKey('logins') != other._$data.containsKey('logins')) {
      return false;
    }
    if (l$logins != null && lOther$logins != null) {
      if (l$logins.length != lOther$logins.length) {
        return false;
      }
      for (int i = 0; i < l$logins.length; i++) {
        final l$logins$entry = l$logins[i];
        final lOther$logins$entry = lOther$logins[i];
        if (l$logins$entry != lOther$logins$entry) {
          return false;
        }
      }
    } else if (l$logins != lOther$logins) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$ids = ids;
    final l$logins = logins;
    return Object.hashAll([
      _$data.containsKey('ids')
          ? l$ids == null
                ? null
                : Object.hashAll(l$ids.map((v) => v))
          : const {},
      _$data.containsKey('logins')
          ? l$logins == null
                ? null
                : Object.hashAll(l$logins.map((v) => v))
          : const {},
    ]);
  }
}

class Query$FlowUsers {
  Query$FlowUsers({this.users});

  factory Query$FlowUsers.fromJson(Map<String, dynamic> json) {
    final l$users = json.containsKey('users') ? json['users'] : null;
    return Query$FlowUsers(
      users: (l$users as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowUsers$users.fromJson((e as Map<String, dynamic>)),
          )
          .toList(),
    );
  }

  final List<Query$FlowUsers$users?>? users;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$users = users;
    _resultData['users'] = l$users?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$users = users;
    return Object.hashAll([
      l$users == null ? null : Object.hashAll(l$users.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers || runtimeType != other.runtimeType) {
      return false;
    }
    final l$users = users;
    final lOther$users = other.users;
    if (l$users != null && lOther$users != null) {
      if (l$users.length != lOther$users.length) {
        return false;
      }
      for (int i = 0; i < l$users.length; i++) {
        final l$users$entry = l$users[i];
        final lOther$users$entry = lOther$users[i];
        if (l$users$entry != lOther$users$entry) {
          return false;
        }
      }
    } else if (l$users != lOther$users) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowUsers = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowUsers'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'ids')),
          type: ListTypeNode(
            type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
            isNonNull: false,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'logins')),
          type: ListTypeNode(
            type: NamedTypeNode(
              name: NameNode(value: 'String'),
              isNonNull: true,
            ),
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
            name: NameNode(value: 'users'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'ids'),
                value: VariableNode(name: NameNode(value: 'ids')),
              ),
              ArgumentNode(
                name: NameNode(value: 'logins'),
                value: VariableNode(name: NameNode(value: 'logins')),
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
                  name: NameNode(value: 'profileImageURL'),
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
                  name: NameNode(value: 'lastBroadcast'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'startedAt'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'broadcastSettings'),
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
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'stream'),
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
                      FieldNode(
                        name: NameNode(value: 'broadcaster'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'broadcastSettings'),
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
Query$FlowUsers _parserFn$Query$FlowUsers(Map<String, dynamic> data) =>
    Query$FlowUsers.fromJson(data);
typedef OnQueryComplete$Query$FlowUsers =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowUsers?);

class Options$Query$FlowUsers extends graphql.QueryOptions<Query$FlowUsers> {
  Options$Query$FlowUsers({
    String? operationName,
    Variables$Query$FlowUsers? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowUsers? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowUsers? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowUsers(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowUsers,
         parserFn: _parserFn$Query$FlowUsers,
       );

  final OnQueryComplete$Query$FlowUsers? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowUsers
    extends graphql.WatchQueryOptions<Query$FlowUsers> {
  WatchOptions$Query$FlowUsers({
    String? operationName,
    Variables$Query$FlowUsers? variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowUsers? typedOptimisticResult,
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
         document: documentNodeQueryFlowUsers,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowUsers,
       );
}

class FetchMoreOptions$Query$FlowUsers extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowUsers({
    required graphql.UpdateQuery updateQuery,
    Variables$Query$FlowUsers? variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables?.toJson() ?? {},
         document: documentNodeQueryFlowUsers,
       );
}

extension ClientExtension$Query$FlowUsers on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowUsers>> query$FlowUsers([
    Options$Query$FlowUsers? options,
  ]) async => await this.query(options ?? Options$Query$FlowUsers());

  graphql.ObservableQuery<Query$FlowUsers> watchQuery$FlowUsers([
    WatchOptions$Query$FlowUsers? options,
  ]) => this.watchQuery(options ?? WatchOptions$Query$FlowUsers());

  void writeQuery$FlowUsers({
    required Query$FlowUsers data,
    Variables$Query$FlowUsers? variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowUsers),
      variables: variables?.toJson() ?? const {},
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowUsers? readQuery$FlowUsers({
    Variables$Query$FlowUsers? variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowUsers),
        variables: variables?.toJson() ?? const {},
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowUsers.fromJson(result);
  }
}

class Query$FlowUsers$users {
  Query$FlowUsers$users({
    this.id,
    this.login,
    this.displayName,
    this.isPartner,
    this.profileImageURL,
    this.lastBroadcast,
    this.broadcastSettings,
    this.stream,
  });

  factory Query$FlowUsers$users.fromJson(Map<String, dynamic> json) {
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
    final l$lastBroadcast = json.containsKey('lastBroadcast')
        ? json['lastBroadcast']
        : null;
    final l$broadcastSettings = json.containsKey('broadcastSettings')
        ? json['broadcastSettings']
        : null;
    final l$stream = json.containsKey('stream') ? json['stream'] : null;
    return Query$FlowUsers$users(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
      isPartner: (l$isPartner as bool?),
      profileImageURL: (l$profileImageURL as String?),
      lastBroadcast: l$lastBroadcast == null
          ? null
          : Query$FlowUsers$users$lastBroadcast.fromJson(
              (l$lastBroadcast as Map<String, dynamic>),
            ),
      broadcastSettings: l$broadcastSettings == null
          ? null
          : Query$FlowUsers$users$broadcastSettings.fromJson(
              (l$broadcastSettings as Map<String, dynamic>),
            ),
      stream: l$stream == null
          ? null
          : Query$FlowUsers$users$stream.fromJson(
              (l$stream as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  final bool? isPartner;

  final String? profileImageURL;

  final Query$FlowUsers$users$lastBroadcast? lastBroadcast;

  final Query$FlowUsers$users$broadcastSettings? broadcastSettings;

  final Query$FlowUsers$users$stream? stream;

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
    final l$lastBroadcast = lastBroadcast;
    _resultData['lastBroadcast'] = l$lastBroadcast?.toJson();
    final l$broadcastSettings = broadcastSettings;
    _resultData['broadcastSettings'] = l$broadcastSettings?.toJson();
    final l$stream = stream;
    _resultData['stream'] = l$stream?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    final l$isPartner = isPartner;
    final l$profileImageURL = profileImageURL;
    final l$lastBroadcast = lastBroadcast;
    final l$broadcastSettings = broadcastSettings;
    final l$stream = stream;
    return Object.hashAll([
      l$id,
      l$login,
      l$displayName,
      l$isPartner,
      l$profileImageURL,
      l$lastBroadcast,
      l$broadcastSettings,
      l$stream,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers$users || runtimeType != other.runtimeType) {
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
    final l$lastBroadcast = lastBroadcast;
    final lOther$lastBroadcast = other.lastBroadcast;
    if (l$lastBroadcast != lOther$lastBroadcast) {
      return false;
    }
    final l$broadcastSettings = broadcastSettings;
    final lOther$broadcastSettings = other.broadcastSettings;
    if (l$broadcastSettings != lOther$broadcastSettings) {
      return false;
    }
    final l$stream = stream;
    final lOther$stream = other.stream;
    if (l$stream != lOther$stream) {
      return false;
    }
    return true;
  }
}

class Query$FlowUsers$users$lastBroadcast {
  Query$FlowUsers$users$lastBroadcast({this.startedAt});

  factory Query$FlowUsers$users$lastBroadcast.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$startedAt = json.containsKey('startedAt')
        ? json['startedAt']
        : null;
    return Query$FlowUsers$users$lastBroadcast(
      startedAt: (l$startedAt as String?),
    );
  }

  final String? startedAt;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$startedAt = startedAt;
    _resultData['startedAt'] = l$startedAt;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$startedAt = startedAt;
    return Object.hashAll([l$startedAt]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers$users$lastBroadcast ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$startedAt = startedAt;
    final lOther$startedAt = other.startedAt;
    if (l$startedAt != lOther$startedAt) {
      return false;
    }
    return true;
  }
}

class Query$FlowUsers$users$broadcastSettings {
  Query$FlowUsers$users$broadcastSettings({this.title, this.game});

  factory Query$FlowUsers$users$broadcastSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    return Query$FlowUsers$users$broadcastSettings(
      title: (l$title as String?),
      game: l$game == null
          ? null
          : Query$FlowUsers$users$broadcastSettings$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
    );
  }

  final String? title;

  final Query$FlowUsers$users$broadcastSettings$game? game;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$title = title;
    _resultData['title'] = l$title;
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$title = title;
    final l$game = game;
    return Object.hashAll([l$title, l$game]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers$users$broadcastSettings ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
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

class Query$FlowUsers$users$broadcastSettings$game {
  Query$FlowUsers$users$broadcastSettings$game({this.id, this.displayName});

  factory Query$FlowUsers$users$broadcastSettings$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowUsers$users$broadcastSettings$game(
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
    if (other is! Query$FlowUsers$users$broadcastSettings$game ||
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

class Query$FlowUsers$users$stream {
  Query$FlowUsers$users$stream({
    this.id,
    this.createdAt,
    this.freeformTags,
    this.game,
    this.previewImageURL,
    this.viewersCount,
    this.broadcaster,
  });

  factory Query$FlowUsers$users$stream.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
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
    final l$broadcaster = json.containsKey('broadcaster')
        ? json['broadcaster']
        : null;
    return Query$FlowUsers$users$stream(
      id: (l$id as String?),
      createdAt: (l$createdAt as String?),
      freeformTags: (l$freeformTags as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowUsers$users$stream$freeformTags.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      game: l$game == null
          ? null
          : Query$FlowUsers$users$stream$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      previewImageURL: (l$previewImageURL as String?),
      viewersCount: (l$viewersCount as int?),
      broadcaster: l$broadcaster == null
          ? null
          : Query$FlowUsers$users$stream$broadcaster.fromJson(
              (l$broadcaster as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? createdAt;

  final List<Query$FlowUsers$users$stream$freeformTags?>? freeformTags;

  final Query$FlowUsers$users$stream$game? game;

  final String? previewImageURL;

  final int? viewersCount;

  final Query$FlowUsers$users$stream$broadcaster? broadcaster;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
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
    final l$broadcaster = broadcaster;
    _resultData['broadcaster'] = l$broadcaster?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$createdAt = createdAt;
    final l$freeformTags = freeformTags;
    final l$game = game;
    final l$previewImageURL = previewImageURL;
    final l$viewersCount = viewersCount;
    final l$broadcaster = broadcaster;
    return Object.hashAll([
      l$id,
      l$createdAt,
      l$freeformTags == null
          ? null
          : Object.hashAll(l$freeformTags.map((v) => v)),
      l$game,
      l$previewImageURL,
      l$viewersCount,
      l$broadcaster,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers$users$stream ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
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
    final l$broadcaster = broadcaster;
    final lOther$broadcaster = other.broadcaster;
    if (l$broadcaster != lOther$broadcaster) {
      return false;
    }
    return true;
  }
}

class Query$FlowUsers$users$stream$freeformTags {
  Query$FlowUsers$users$stream$freeformTags({this.name});

  factory Query$FlowUsers$users$stream$freeformTags.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$name = json.containsKey('name') ? json['name'] : null;
    return Query$FlowUsers$users$stream$freeformTags(name: (l$name as String?));
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
    if (other is! Query$FlowUsers$users$stream$freeformTags ||
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

class Query$FlowUsers$users$stream$game {
  Query$FlowUsers$users$stream$game({this.id, this.displayName});

  factory Query$FlowUsers$users$stream$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowUsers$users$stream$game(
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
    if (other is! Query$FlowUsers$users$stream$game ||
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

class Query$FlowUsers$users$stream$broadcaster {
  Query$FlowUsers$users$stream$broadcaster({this.broadcastSettings});

  factory Query$FlowUsers$users$stream$broadcaster.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$broadcastSettings = json.containsKey('broadcastSettings')
        ? json['broadcastSettings']
        : null;
    return Query$FlowUsers$users$stream$broadcaster(
      broadcastSettings: l$broadcastSettings == null
          ? null
          : Query$FlowUsers$users$stream$broadcaster$broadcastSettings.fromJson(
              (l$broadcastSettings as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowUsers$users$stream$broadcaster$broadcastSettings?
  broadcastSettings;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$broadcastSettings = broadcastSettings;
    _resultData['broadcastSettings'] = l$broadcastSettings?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$broadcastSettings = broadcastSettings;
    return Object.hashAll([l$broadcastSettings]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowUsers$users$stream$broadcaster ||
        runtimeType != other.runtimeType) {
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

class Query$FlowUsers$users$stream$broadcaster$broadcastSettings {
  Query$FlowUsers$users$stream$broadcaster$broadcastSettings({this.title});

  factory Query$FlowUsers$users$stream$broadcaster$broadcastSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$title = json.containsKey('title') ? json['title'] : null;
    return Query$FlowUsers$users$stream$broadcaster$broadcastSettings(
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
    if (other is! Query$FlowUsers$users$stream$broadcaster$broadcastSettings ||
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
