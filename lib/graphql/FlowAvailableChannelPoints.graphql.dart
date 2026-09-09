// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowAvailableChannelPoints {
  factory Variables$Query$FlowAvailableChannelPoints({required String login}) =>
      Variables$Query$FlowAvailableChannelPoints._({r'login': login});

  Variables$Query$FlowAvailableChannelPoints._(this._$data);

  factory Variables$Query$FlowAvailableChannelPoints.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    return Variables$Query$FlowAvailableChannelPoints._(result$data);
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
    if (other is! Variables$Query$FlowAvailableChannelPoints ||
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

class Query$FlowAvailableChannelPoints {
  Query$FlowAvailableChannelPoints({this.user});

  factory Query$FlowAvailableChannelPoints.fromJson(Map<String, dynamic> json) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowAvailableChannelPoints(
      user: l$user == null
          ? null
          : Query$FlowAvailableChannelPoints$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowAvailableChannelPoints$user? user;

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
    if (other is! Query$FlowAvailableChannelPoints ||
        runtimeType != other.runtimeType) {
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

const documentNodeQueryFlowAvailableChannelPoints = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowAvailableChannelPoints'),
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
                  name: NameNode(value: 'channel'),
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
                        name: NameNode(value: 'self'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'communityPoints'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: SelectionSetNode(
                                selections: [
                                  FieldNode(
                                    name: NameNode(value: 'availableClaim'),
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
Query$FlowAvailableChannelPoints _parserFn$Query$FlowAvailableChannelPoints(
  Map<String, dynamic> data,
) => Query$FlowAvailableChannelPoints.fromJson(data);
typedef OnQueryComplete$Query$FlowAvailableChannelPoints =
    FutureOr<void> Function(
      Map<String, dynamic>?,
      Query$FlowAvailableChannelPoints?,
    );

class Options$Query$FlowAvailableChannelPoints
    extends graphql.QueryOptions<Query$FlowAvailableChannelPoints> {
  Options$Query$FlowAvailableChannelPoints({
    String? operationName,
    required Variables$Query$FlowAvailableChannelPoints variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowAvailableChannelPoints? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowAvailableChannelPoints? onComplete,
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
                     : _parserFn$Query$FlowAvailableChannelPoints(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowAvailableChannelPoints,
         parserFn: _parserFn$Query$FlowAvailableChannelPoints,
       );

  final OnQueryComplete$Query$FlowAvailableChannelPoints? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowAvailableChannelPoints
    extends graphql.WatchQueryOptions<Query$FlowAvailableChannelPoints> {
  WatchOptions$Query$FlowAvailableChannelPoints({
    String? operationName,
    required Variables$Query$FlowAvailableChannelPoints variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowAvailableChannelPoints? typedOptimisticResult,
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
         document: documentNodeQueryFlowAvailableChannelPoints,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowAvailableChannelPoints,
       );
}

class FetchMoreOptions$Query$FlowAvailableChannelPoints
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowAvailableChannelPoints({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowAvailableChannelPoints variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowAvailableChannelPoints,
       );
}

extension ClientExtension$Query$FlowAvailableChannelPoints
    on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowAvailableChannelPoints>>
  query$FlowAvailableChannelPoints(
    Options$Query$FlowAvailableChannelPoints options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowAvailableChannelPoints>
  watchQuery$FlowAvailableChannelPoints(
    WatchOptions$Query$FlowAvailableChannelPoints options,
  ) => this.watchQuery(options);

  void writeQuery$FlowAvailableChannelPoints({
    required Query$FlowAvailableChannelPoints data,
    required Variables$Query$FlowAvailableChannelPoints variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowAvailableChannelPoints,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowAvailableChannelPoints? readQuery$FlowAvailableChannelPoints({
    required Variables$Query$FlowAvailableChannelPoints variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowAvailableChannelPoints,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null
        ? null
        : Query$FlowAvailableChannelPoints.fromJson(result);
  }
}

class Query$FlowAvailableChannelPoints$user {
  Query$FlowAvailableChannelPoints$user({this.id, this.login, this.channel});

  factory Query$FlowAvailableChannelPoints$user.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$channel = json.containsKey('channel') ? json['channel'] : null;
    return Query$FlowAvailableChannelPoints$user(
      id: (l$id as String?),
      login: (l$login as String?),
      channel: l$channel == null
          ? null
          : Query$FlowAvailableChannelPoints$user$channel.fromJson(
              (l$channel as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final Query$FlowAvailableChannelPoints$user$channel? channel;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$channel = channel;
    _resultData['channel'] = l$channel?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$channel = channel;
    return Object.hashAll([l$id, l$login, l$channel]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowAvailableChannelPoints$user ||
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
    final l$channel = channel;
    final lOther$channel = other.channel;
    if (l$channel != lOther$channel) {
      return false;
    }
    return true;
  }
}

class Query$FlowAvailableChannelPoints$user$channel {
  Query$FlowAvailableChannelPoints$user$channel({this.id, this.self});

  factory Query$FlowAvailableChannelPoints$user$channel.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$self = json.containsKey('self') ? json['self'] : null;
    return Query$FlowAvailableChannelPoints$user$channel(
      id: (l$id as String?),
      self: l$self == null
          ? null
          : Query$FlowAvailableChannelPoints$user$channel$self.fromJson(
              (l$self as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowAvailableChannelPoints$user$channel$self? self;

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
    if (other is! Query$FlowAvailableChannelPoints$user$channel ||
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

class Query$FlowAvailableChannelPoints$user$channel$self {
  Query$FlowAvailableChannelPoints$user$channel$self({this.communityPoints});

  factory Query$FlowAvailableChannelPoints$user$channel$self.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$communityPoints = json.containsKey('communityPoints')
        ? json['communityPoints']
        : null;
    return Query$FlowAvailableChannelPoints$user$channel$self(
      communityPoints: l$communityPoints == null
          ? null
          : Query$FlowAvailableChannelPoints$user$channel$self$communityPoints.fromJson(
              (l$communityPoints as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowAvailableChannelPoints$user$channel$self$communityPoints?
  communityPoints;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$communityPoints = communityPoints;
    _resultData['communityPoints'] = l$communityPoints?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$communityPoints = communityPoints;
    return Object.hashAll([l$communityPoints]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowAvailableChannelPoints$user$channel$self ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$communityPoints = communityPoints;
    final lOther$communityPoints = other.communityPoints;
    if (l$communityPoints != lOther$communityPoints) {
      return false;
    }
    return true;
  }
}

class Query$FlowAvailableChannelPoints$user$channel$self$communityPoints {
  Query$FlowAvailableChannelPoints$user$channel$self$communityPoints({
    this.availableClaim,
  });

  factory Query$FlowAvailableChannelPoints$user$channel$self$communityPoints.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$availableClaim = json.containsKey('availableClaim')
        ? json['availableClaim']
        : null;
    return Query$FlowAvailableChannelPoints$user$channel$self$communityPoints(
      availableClaim: l$availableClaim == null
          ? null
          : Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim.fromJson(
              (l$availableClaim as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim?
  availableClaim;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$availableClaim = availableClaim;
    _resultData['availableClaim'] = l$availableClaim?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$availableClaim = availableClaim;
    return Object.hashAll([l$availableClaim]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowAvailableChannelPoints$user$channel$self$communityPoints ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$availableClaim = availableClaim;
    final lOther$availableClaim = other.availableClaim;
    if (l$availableClaim != lOther$availableClaim) {
      return false;
    }
    return true;
  }
}

class Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim {
  Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim({
    this.id,
  });

  factory Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    return Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim(
      id: (l$id as String?),
    );
  }

  final String? id;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    return Object.hashAll([l$id]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowAvailableChannelPoints$user$channel$self$communityPoints$availableClaim ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    return true;
  }
}
