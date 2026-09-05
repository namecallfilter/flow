// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowChannelSubscription {
  factory Variables$Query$FlowChannelSubscription({required String login}) =>
      Variables$Query$FlowChannelSubscription._({r'login': login});

  Variables$Query$FlowChannelSubscription._(this._$data);

  factory Variables$Query$FlowChannelSubscription.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    return Variables$Query$FlowChannelSubscription._(result$data);
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
    if (other is! Variables$Query$FlowChannelSubscription ||
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

class Query$FlowChannelSubscription {
  Query$FlowChannelSubscription({this.user});

  factory Query$FlowChannelSubscription.fromJson(Map<String, dynamic> json) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowChannelSubscription(
      user: l$user == null
          ? null
          : Query$FlowChannelSubscription$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChannelSubscription$user? user;

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
    if (other is! Query$FlowChannelSubscription ||
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

const documentNodeQueryFlowChannelSubscription = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChannelSubscription'),
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
                  name: NameNode(value: 'self'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'subscriptionBenefit'),
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
);
Query$FlowChannelSubscription _parserFn$Query$FlowChannelSubscription(
  Map<String, dynamic> data,
) => Query$FlowChannelSubscription.fromJson(data);
typedef OnQueryComplete$Query$FlowChannelSubscription =
    FutureOr<void> Function(
      Map<String, dynamic>?,
      Query$FlowChannelSubscription?,
    );

class Options$Query$FlowChannelSubscription
    extends graphql.QueryOptions<Query$FlowChannelSubscription> {
  Options$Query$FlowChannelSubscription({
    String? operationName,
    required Variables$Query$FlowChannelSubscription variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChannelSubscription? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChannelSubscription? onComplete,
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
                     : _parserFn$Query$FlowChannelSubscription(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChannelSubscription,
         parserFn: _parserFn$Query$FlowChannelSubscription,
       );

  final OnQueryComplete$Query$FlowChannelSubscription? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChannelSubscription
    extends graphql.WatchQueryOptions<Query$FlowChannelSubscription> {
  WatchOptions$Query$FlowChannelSubscription({
    String? operationName,
    required Variables$Query$FlowChannelSubscription variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChannelSubscription? typedOptimisticResult,
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
         document: documentNodeQueryFlowChannelSubscription,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChannelSubscription,
       );
}

class FetchMoreOptions$Query$FlowChannelSubscription
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChannelSubscription({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChannelSubscription variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChannelSubscription,
       );
}

extension ClientExtension$Query$FlowChannelSubscription
    on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChannelSubscription>>
  query$FlowChannelSubscription(
    Options$Query$FlowChannelSubscription options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChannelSubscription>
  watchQuery$FlowChannelSubscription(
    WatchOptions$Query$FlowChannelSubscription options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChannelSubscription({
    required Query$FlowChannelSubscription data,
    required Variables$Query$FlowChannelSubscription variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowChannelSubscription,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChannelSubscription? readQuery$FlowChannelSubscription({
    required Variables$Query$FlowChannelSubscription variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowChannelSubscription,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null
        ? null
        : Query$FlowChannelSubscription.fromJson(result);
  }
}

class Query$FlowChannelSubscription$user {
  Query$FlowChannelSubscription$user({this.self});

  factory Query$FlowChannelSubscription$user.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$self = json.containsKey('self') ? json['self'] : null;
    return Query$FlowChannelSubscription$user(
      self: l$self == null
          ? null
          : Query$FlowChannelSubscription$user$self.fromJson(
              (l$self as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChannelSubscription$user$self? self;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$self = self;
    _resultData['self'] = l$self?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$self = self;
    return Object.hashAll([l$self]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelSubscription$user ||
        runtimeType != other.runtimeType) {
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

class Query$FlowChannelSubscription$user$self {
  Query$FlowChannelSubscription$user$self({this.subscriptionBenefit});

  factory Query$FlowChannelSubscription$user$self.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$subscriptionBenefit = json.containsKey('subscriptionBenefit')
        ? json['subscriptionBenefit']
        : null;
    return Query$FlowChannelSubscription$user$self(
      subscriptionBenefit: l$subscriptionBenefit == null
          ? null
          : Query$FlowChannelSubscription$user$self$subscriptionBenefit.fromJson(
              (l$subscriptionBenefit as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChannelSubscription$user$self$subscriptionBenefit?
  subscriptionBenefit;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$subscriptionBenefit = subscriptionBenefit;
    _resultData['subscriptionBenefit'] = l$subscriptionBenefit?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$subscriptionBenefit = subscriptionBenefit;
    return Object.hashAll([l$subscriptionBenefit]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelSubscription$user$self ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$subscriptionBenefit = subscriptionBenefit;
    final lOther$subscriptionBenefit = other.subscriptionBenefit;
    if (l$subscriptionBenefit != lOther$subscriptionBenefit) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelSubscription$user$self$subscriptionBenefit {
  Query$FlowChannelSubscription$user$self$subscriptionBenefit({this.id});

  factory Query$FlowChannelSubscription$user$self$subscriptionBenefit.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    return Query$FlowChannelSubscription$user$self$subscriptionBenefit(
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
    if (other is! Query$FlowChannelSubscription$user$self$subscriptionBenefit ||
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
