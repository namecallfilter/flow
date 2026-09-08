// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowChatters {
  factory Variables$Query$FlowChatters({required String login}) =>
      Variables$Query$FlowChatters._({r'login': login});

  Variables$Query$FlowChatters._(this._$data);

  factory Variables$Query$FlowChatters.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    return Variables$Query$FlowChatters._(result$data);
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
    if (other is! Variables$Query$FlowChatters ||
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

class Query$FlowChatters {
  Query$FlowChatters({this.user});

  factory Query$FlowChatters.fromJson(Map<String, dynamic> json) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowChatters(
      user: l$user == null
          ? null
          : Query$FlowChatters$user.fromJson((l$user as Map<String, dynamic>)),
    );
  }

  final Query$FlowChatters$user? user;

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
    if (other is! Query$FlowChatters || runtimeType != other.runtimeType) {
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

const documentNodeQueryFlowChatters = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChatters'),
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
                  name: NameNode(value: 'channel'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'chatters'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'count'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'broadcasters'),
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
                            FieldNode(
                              name: NameNode(value: 'moderators'),
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
                            FieldNode(
                              name: NameNode(value: 'vips'),
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
                            FieldNode(
                              name: NameNode(value: 'staff'),
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
                            FieldNode(
                              name: NameNode(value: 'viewers'),
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
Query$FlowChatters _parserFn$Query$FlowChatters(Map<String, dynamic> data) =>
    Query$FlowChatters.fromJson(data);
typedef OnQueryComplete$Query$FlowChatters =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChatters?);

class Options$Query$FlowChatters
    extends graphql.QueryOptions<Query$FlowChatters> {
  Options$Query$FlowChatters({
    String? operationName,
    required Variables$Query$FlowChatters variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatters? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChatters? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChatters(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChatters,
         parserFn: _parserFn$Query$FlowChatters,
       );

  final OnQueryComplete$Query$FlowChatters? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChatters
    extends graphql.WatchQueryOptions<Query$FlowChatters> {
  WatchOptions$Query$FlowChatters({
    String? operationName,
    required Variables$Query$FlowChatters variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatters? typedOptimisticResult,
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
         document: documentNodeQueryFlowChatters,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChatters,
       );
}

class FetchMoreOptions$Query$FlowChatters extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChatters({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChatters variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChatters,
       );
}

extension ClientExtension$Query$FlowChatters on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChatters>> query$FlowChatters(
    Options$Query$FlowChatters options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChatters> watchQuery$FlowChatters(
    WatchOptions$Query$FlowChatters options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChatters({
    required Query$FlowChatters data,
    required Variables$Query$FlowChatters variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowChatters),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChatters? readQuery$FlowChatters({
    required Variables$Query$FlowChatters variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowChatters),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChatters.fromJson(result);
  }
}

class Query$FlowChatters$user {
  Query$FlowChatters$user({this.channel});

  factory Query$FlowChatters$user.fromJson(Map<String, dynamic> json) {
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowChatters$user(
      channel: l$channel == null
          ? null
          : Query$FlowChatters$user$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatters$user$channel? channel;

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
    if (other is! Query$FlowChatters$user || runtimeType != other.runtimeType) {
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

class Query$FlowChatters$user$channel {
  Query$FlowChatters$user$channel({this.chatters});

  factory Query$FlowChatters$user$channel.fromJson(Map<String, dynamic> json) {
    final l$chatters = json.containsKey('chatters') ? json['chatters'] : null;
    return Query$FlowChatters$user$channel(
      chatters: l$chatters == null
          ? null
          : Query$FlowChatters$user$channel$chatters.fromJson(
              (l$chatters as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatters$user$channel$chatters? chatters;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$chatters = chatters;
    _resultData['chatters'] = l$chatters?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$chatters = chatters;
    return Object.hashAll([l$chatters]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatters$user$channel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$chatters = chatters;
    final lOther$chatters = other.chatters;
    if (l$chatters != lOther$chatters) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatters$user$channel$chatters {
  Query$FlowChatters$user$channel$chatters({
    this.count,
    this.broadcasters,
    this.moderators,
    this.vips,
    this.staff,
    this.viewers,
  });

  factory Query$FlowChatters$user$channel$chatters.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$count = json.containsKey('count') ? json['count'] : null;
    final l$broadcasters = json.containsKey('broadcasters')
        ? json['broadcasters']
        : null;
    final l$moderators = json.containsKey('moderators')
        ? json['moderators']
        : null;
    final l$vips = json.containsKey('vips') ? json['vips'] : null;
    final l$staff = json.containsKey('staff') ? json['staff'] : null;
    final l$viewers = json.containsKey('viewers') ? json['viewers'] : null;
    return Query$FlowChatters$user$channel$chatters(
      count: (l$count as int?),
      broadcasters: (l$broadcasters as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatters$user$channel$chatters$broadcasters.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      moderators: (l$moderators as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatters$user$channel$chatters$moderators.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      vips: (l$vips as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatters$user$channel$chatters$vips.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      staff: (l$staff as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatters$user$channel$chatters$staff.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      viewers: (l$viewers as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatters$user$channel$chatters$viewers.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final int? count;

  final List<Query$FlowChatters$user$channel$chatters$broadcasters?>?
  broadcasters;

  final List<Query$FlowChatters$user$channel$chatters$moderators?>? moderators;

  final List<Query$FlowChatters$user$channel$chatters$vips?>? vips;

  final List<Query$FlowChatters$user$channel$chatters$staff?>? staff;

  final List<Query$FlowChatters$user$channel$chatters$viewers?>? viewers;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$count = count;
    _resultData['count'] = l$count;
    final l$broadcasters = broadcasters;
    _resultData['broadcasters'] = l$broadcasters
        ?.map((e) => e?.toJson())
        .toList();
    final l$moderators = moderators;
    _resultData['moderators'] = l$moderators?.map((e) => e?.toJson()).toList();
    final l$vips = vips;
    _resultData['vips'] = l$vips?.map((e) => e?.toJson()).toList();
    final l$staff = staff;
    _resultData['staff'] = l$staff?.map((e) => e?.toJson()).toList();
    final l$viewers = viewers;
    _resultData['viewers'] = l$viewers?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$count = count;
    final l$broadcasters = broadcasters;
    final l$moderators = moderators;
    final l$vips = vips;
    final l$staff = staff;
    final l$viewers = viewers;
    return Object.hashAll([
      l$count,
      l$broadcasters == null
          ? null
          : Object.hashAll(l$broadcasters.map((v) => v)),
      l$moderators == null ? null : Object.hashAll(l$moderators.map((v) => v)),
      l$vips == null ? null : Object.hashAll(l$vips.map((v) => v)),
      l$staff == null ? null : Object.hashAll(l$staff.map((v) => v)),
      l$viewers == null ? null : Object.hashAll(l$viewers.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatters$user$channel$chatters ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$count = count;
    final lOther$count = other.count;
    if (l$count != lOther$count) {
      return false;
    }
    final l$broadcasters = broadcasters;
    final lOther$broadcasters = other.broadcasters;
    if (l$broadcasters != null && lOther$broadcasters != null) {
      if (l$broadcasters.length != lOther$broadcasters.length) {
        return false;
      }
      for (int i = 0; i < l$broadcasters.length; i++) {
        final l$broadcasters$entry = l$broadcasters[i];
        final lOther$broadcasters$entry = lOther$broadcasters[i];
        if (l$broadcasters$entry != lOther$broadcasters$entry) {
          return false;
        }
      }
    } else if (l$broadcasters != lOther$broadcasters) {
      return false;
    }
    final l$moderators = moderators;
    final lOther$moderators = other.moderators;
    if (l$moderators != null && lOther$moderators != null) {
      if (l$moderators.length != lOther$moderators.length) {
        return false;
      }
      for (int i = 0; i < l$moderators.length; i++) {
        final l$moderators$entry = l$moderators[i];
        final lOther$moderators$entry = lOther$moderators[i];
        if (l$moderators$entry != lOther$moderators$entry) {
          return false;
        }
      }
    } else if (l$moderators != lOther$moderators) {
      return false;
    }
    final l$vips = vips;
    final lOther$vips = other.vips;
    if (l$vips != null && lOther$vips != null) {
      if (l$vips.length != lOther$vips.length) {
        return false;
      }
      for (int i = 0; i < l$vips.length; i++) {
        final l$vips$entry = l$vips[i];
        final lOther$vips$entry = lOther$vips[i];
        if (l$vips$entry != lOther$vips$entry) {
          return false;
        }
      }
    } else if (l$vips != lOther$vips) {
      return false;
    }
    final l$staff = staff;
    final lOther$staff = other.staff;
    if (l$staff != null && lOther$staff != null) {
      if (l$staff.length != lOther$staff.length) {
        return false;
      }
      for (int i = 0; i < l$staff.length; i++) {
        final l$staff$entry = l$staff[i];
        final lOther$staff$entry = lOther$staff[i];
        if (l$staff$entry != lOther$staff$entry) {
          return false;
        }
      }
    } else if (l$staff != lOther$staff) {
      return false;
    }
    final l$viewers = viewers;
    final lOther$viewers = other.viewers;
    if (l$viewers != null && lOther$viewers != null) {
      if (l$viewers.length != lOther$viewers.length) {
        return false;
      }
      for (int i = 0; i < l$viewers.length; i++) {
        final l$viewers$entry = l$viewers[i];
        final lOther$viewers$entry = lOther$viewers[i];
        if (l$viewers$entry != lOther$viewers$entry) {
          return false;
        }
      }
    } else if (l$viewers != lOther$viewers) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatters$user$channel$chatters$broadcasters {
  Query$FlowChatters$user$channel$chatters$broadcasters({this.login});

  factory Query$FlowChatters$user$channel$chatters$broadcasters.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatters$user$channel$chatters$broadcasters(
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
    if (other is! Query$FlowChatters$user$channel$chatters$broadcasters ||
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

class Query$FlowChatters$user$channel$chatters$moderators {
  Query$FlowChatters$user$channel$chatters$moderators({this.login});

  factory Query$FlowChatters$user$channel$chatters$moderators.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatters$user$channel$chatters$moderators(
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
    if (other is! Query$FlowChatters$user$channel$chatters$moderators ||
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

class Query$FlowChatters$user$channel$chatters$vips {
  Query$FlowChatters$user$channel$chatters$vips({this.login});

  factory Query$FlowChatters$user$channel$chatters$vips.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatters$user$channel$chatters$vips(
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
    if (other is! Query$FlowChatters$user$channel$chatters$vips ||
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

class Query$FlowChatters$user$channel$chatters$staff {
  Query$FlowChatters$user$channel$chatters$staff({this.login});

  factory Query$FlowChatters$user$channel$chatters$staff.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatters$user$channel$chatters$staff(
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
    if (other is! Query$FlowChatters$user$channel$chatters$staff ||
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

class Query$FlowChatters$user$channel$chatters$viewers {
  Query$FlowChatters$user$channel$chatters$viewers({this.login});

  factory Query$FlowChatters$user$channel$chatters$viewers.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatters$user$channel$chatters$viewers(
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
    if (other is! Query$FlowChatters$user$channel$chatters$viewers ||
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
