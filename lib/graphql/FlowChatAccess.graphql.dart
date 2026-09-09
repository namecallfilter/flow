// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowChatAccess {
  factory Variables$Query$FlowChatAccess({required String login}) =>
      Variables$Query$FlowChatAccess._({r'login': login});

  Variables$Query$FlowChatAccess._(this._$data);

  factory Variables$Query$FlowChatAccess.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    return Variables$Query$FlowChatAccess._(result$data);
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
    if (other is! Variables$Query$FlowChatAccess ||
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

class Query$FlowChatAccess {
  Query$FlowChatAccess({this.user});

  factory Query$FlowChatAccess.fromJson(Map<String, dynamic> json) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowChatAccess(
      user: l$user == null
          ? null
          : Query$FlowChatAccess$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatAccess$user? user;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$user = user;
    _resultData['user'] = l$user?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$user = user;
    return Object.hashAll([l$user]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAccess || runtimeType != other.runtimeType) {
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

const documentNodeQueryFlowChatAccess = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChatAccess'),
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
                  name: NameNode(value: 'chatSettings'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'rules'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'self'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'follower'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'followedAt'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                          ],
                        ),
                      ),
                      FieldNode(
                        name: NameNode(value: 'isModerator'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'isVIP'),
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
Query$FlowChatAccess _parserFn$Query$FlowChatAccess(
  Map<String, dynamic> data,
) => Query$FlowChatAccess.fromJson(data);
typedef OnQueryComplete$Query$FlowChatAccess =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChatAccess?);

class Options$Query$FlowChatAccess
    extends graphql.QueryOptions<Query$FlowChatAccess> {
  Options$Query$FlowChatAccess({
    String? operationName,
    required Variables$Query$FlowChatAccess variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatAccess? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChatAccess? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChatAccess(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChatAccess,
         parserFn: _parserFn$Query$FlowChatAccess,
       );

  final OnQueryComplete$Query$FlowChatAccess? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChatAccess
    extends graphql.WatchQueryOptions<Query$FlowChatAccess> {
  WatchOptions$Query$FlowChatAccess({
    String? operationName,
    required Variables$Query$FlowChatAccess variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatAccess? typedOptimisticResult,
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
         document: documentNodeQueryFlowChatAccess,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChatAccess,
       );
}

class FetchMoreOptions$Query$FlowChatAccess extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChatAccess({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChatAccess variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChatAccess,
       );
}

extension ClientExtension$Query$FlowChatAccess on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChatAccess>> query$FlowChatAccess(
    Options$Query$FlowChatAccess options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChatAccess> watchQuery$FlowChatAccess(
    WatchOptions$Query$FlowChatAccess options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChatAccess({
    required Query$FlowChatAccess data,
    required Variables$Query$FlowChatAccess variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowChatAccess),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChatAccess? readQuery$FlowChatAccess({
    required Variables$Query$FlowChatAccess variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowChatAccess),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChatAccess.fromJson(result);
  }
}

class Query$FlowChatAccess$user {
  Query$FlowChatAccess$user({
    this.id,
    this.login,
    this.displayName,
    this.chatSettings,
    this.self,
  });

  factory Query$FlowChatAccess$user.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$chatSettings = json.containsKey('chatSettings')
        ? json['chatSettings']
        : null;
    final l$self = json.containsKey('self') ? json['self'] : null;
    return Query$FlowChatAccess$user(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
      chatSettings: l$chatSettings == null
          ? null
          : Query$FlowChatAccess$user$chatSettings.fromJson(
              (l$chatSettings as Map<String, dynamic>),
            ),
      self: l$self == null
          ? null
          : Query$FlowChatAccess$user$self.fromJson(
              (l$self as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  final Query$FlowChatAccess$user$chatSettings? chatSettings;

  final Query$FlowChatAccess$user$self? self;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$chatSettings = chatSettings;
    _resultData['chatSettings'] = l$chatSettings?.toJson();
    final l$self = self;
    _resultData['self'] = l$self?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    final l$chatSettings = chatSettings;
    final l$self = self;
    return Object.hashAll([
      l$id,
      l$login,
      l$displayName,
      l$chatSettings,
      l$self,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAccess$user ||
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
    final l$chatSettings = chatSettings;
    final lOther$chatSettings = other.chatSettings;
    if (l$chatSettings != lOther$chatSettings) {
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

class Query$FlowChatAccess$user$chatSettings {
  Query$FlowChatAccess$user$chatSettings({this.rules});

  factory Query$FlowChatAccess$user$chatSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$rules = json.containsKey('rules') ? json['rules'] : null;
    return Query$FlowChatAccess$user$chatSettings(
      rules: (l$rules as List<dynamic>?)?.map((e) => (e as String?)).toList(),
    );
  }

  final List<String?>? rules;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$rules = rules;
    _resultData['rules'] = l$rules?.map((e) => e).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$rules = rules;
    return Object.hashAll([
      l$rules == null ? null : Object.hashAll(l$rules.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAccess$user$chatSettings ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$rules = rules;
    final lOther$rules = other.rules;
    if (l$rules != null && lOther$rules != null) {
      if (l$rules.length != lOther$rules.length) {
        return false;
      }
      for (int i = 0; i < l$rules.length; i++) {
        final l$rules$entry = l$rules[i];
        final lOther$rules$entry = lOther$rules[i];
        if (l$rules$entry != lOther$rules$entry) {
          return false;
        }
      }
    } else if (l$rules != lOther$rules) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatAccess$user$self {
  Query$FlowChatAccess$user$self({this.follower, this.isModerator, this.isVIP});

  factory Query$FlowChatAccess$user$self.fromJson(Map<String, dynamic> json) {
    final l$follower = json.containsKey('follower') ? json['follower'] : null;
    final l$isModerator = json.containsKey('isModerator')
        ? json['isModerator']
        : null;
    final l$isVIP = json.containsKey('isVIP') ? json['isVIP'] : null;
    return Query$FlowChatAccess$user$self(
      follower: l$follower == null
          ? null
          : Query$FlowChatAccess$user$self$follower.fromJson(
              (l$follower as Map<String, dynamic>),
            ),
      isModerator: (l$isModerator as bool?),
      isVIP: (l$isVIP as bool?),
    );
  }

  final Query$FlowChatAccess$user$self$follower? follower;

  final bool? isModerator;

  final bool? isVIP;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$follower = follower;
    _resultData['follower'] = l$follower?.toJson();
    final l$isModerator = isModerator;
    _resultData['isModerator'] = l$isModerator;
    final l$isVIP = isVIP;
    _resultData['isVIP'] = l$isVIP;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$follower = follower;
    final l$isModerator = isModerator;
    final l$isVIP = isVIP;
    return Object.hashAll([l$follower, l$isModerator, l$isVIP]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAccess$user$self ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$follower = follower;
    final lOther$follower = other.follower;
    if (l$follower != lOther$follower) {
      return false;
    }
    final l$isModerator = isModerator;
    final lOther$isModerator = other.isModerator;
    if (l$isModerator != lOther$isModerator) {
      return false;
    }
    final l$isVIP = isVIP;
    final lOther$isVIP = other.isVIP;
    if (l$isVIP != lOther$isVIP) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatAccess$user$self$follower {
  Query$FlowChatAccess$user$self$follower({this.followedAt});

  factory Query$FlowChatAccess$user$self$follower.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$followedAt = json.containsKey('followedAt')
        ? json['followedAt']
        : null;
    return Query$FlowChatAccess$user$self$follower(
      followedAt: (l$followedAt as String?),
    );
  }

  final String? followedAt;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$followedAt = followedAt;
    _resultData['followedAt'] = l$followedAt;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$followedAt = followedAt;
    return Object.hashAll([l$followedAt]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatAccess$user$self$follower ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$followedAt = followedAt;
    final lOther$followedAt = other.followedAt;
    if (l$followedAt != lOther$followedAt) {
      return false;
    }
    return true;
  }
}
