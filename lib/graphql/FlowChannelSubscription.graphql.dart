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

  CopyWith$Variables$Query$FlowChannelSubscription<Variables$Query$FlowChannelSubscription>
  get copyWith => CopyWith$Variables$Query$FlowChannelSubscription(this, (i) => i);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowChannelSubscription || runtimeType != other.runtimeType) {
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

abstract class CopyWith$Variables$Query$FlowChannelSubscription<TRes> {
  factory CopyWith$Variables$Query$FlowChannelSubscription(
    Variables$Query$FlowChannelSubscription instance,
    TRes Function(Variables$Query$FlowChannelSubscription) then,
  ) = _CopyWithImpl$Variables$Query$FlowChannelSubscription;

  factory CopyWith$Variables$Query$FlowChannelSubscription.stub(TRes res) =
      _CopyWithStubImpl$Variables$Query$FlowChannelSubscription;

  TRes call({String? login});
}

class _CopyWithImpl$Variables$Query$FlowChannelSubscription<TRes>
    implements CopyWith$Variables$Query$FlowChannelSubscription<TRes> {
  _CopyWithImpl$Variables$Query$FlowChannelSubscription(
    this._instance,
    this._then,
  );

  final Variables$Query$FlowChannelSubscription _instance;

  final TRes Function(Variables$Query$FlowChannelSubscription) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? login = _undefined}) => _then(
    Variables$Query$FlowChannelSubscription._({
      ..._instance._$data,
      if (login != _undefined && login != null) 'login': (login as String),
    }),
  );
}

class _CopyWithStubImpl$Variables$Query$FlowChannelSubscription<TRes>
    implements CopyWith$Variables$Query$FlowChannelSubscription<TRes> {
  _CopyWithStubImpl$Variables$Query$FlowChannelSubscription(this._res);

  TRes _res;

  call({String? login}) => _res;
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
    if (other is! Query$FlowChannelSubscription || runtimeType != other.runtimeType) {
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

extension UtilityExtension$Query$FlowChannelSubscription on Query$FlowChannelSubscription {
  CopyWith$Query$FlowChannelSubscription<Query$FlowChannelSubscription> get copyWith =>
      CopyWith$Query$FlowChannelSubscription(this, (i) => i);
}

abstract class CopyWith$Query$FlowChannelSubscription<TRes> {
  factory CopyWith$Query$FlowChannelSubscription(
    Query$FlowChannelSubscription instance,
    TRes Function(Query$FlowChannelSubscription) then,
  ) = _CopyWithImpl$Query$FlowChannelSubscription;

  factory CopyWith$Query$FlowChannelSubscription.stub(TRes res) =
      _CopyWithStubImpl$Query$FlowChannelSubscription;

  TRes call({Query$FlowChannelSubscription$user? user});
  CopyWith$Query$FlowChannelSubscription$user<TRes> get user;
}

class _CopyWithImpl$Query$FlowChannelSubscription<TRes>
    implements CopyWith$Query$FlowChannelSubscription<TRes> {
  _CopyWithImpl$Query$FlowChannelSubscription(this._instance, this._then);

  final Query$FlowChannelSubscription _instance;

  final TRes Function(Query$FlowChannelSubscription) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? user = _undefined}) => _then(
    Query$FlowChannelSubscription(
      user: user == _undefined ? _instance.user : (user as Query$FlowChannelSubscription$user?),
    ),
  );

  CopyWith$Query$FlowChannelSubscription$user<TRes> get user {
    final local$user = _instance.user;
    return local$user == null
        ? CopyWith$Query$FlowChannelSubscription$user.stub(_then(_instance))
        : CopyWith$Query$FlowChannelSubscription$user(
            local$user,
            (e) => call(user: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowChannelSubscription<TRes>
    implements CopyWith$Query$FlowChannelSubscription<TRes> {
  _CopyWithStubImpl$Query$FlowChannelSubscription(this._res);

  TRes _res;

  call({Query$FlowChannelSubscription$user? user}) => _res;

  CopyWith$Query$FlowChannelSubscription$user<TRes> get user =>
      CopyWith$Query$FlowChannelSubscription$user.stub(_res);
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
                 data == null ? null : _parserFn$Query$FlowChannelSubscription(data),
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

class FetchMoreOptions$Query$FlowChannelSubscription extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChannelSubscription({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChannelSubscription variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChannelSubscription,
       );
}

extension ClientExtension$Query$FlowChannelSubscription on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChannelSubscription>> query$FlowChannelSubscription(
    Options$Query$FlowChannelSubscription options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChannelSubscription> watchQuery$FlowChannelSubscription(
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
    return result == null ? null : Query$FlowChannelSubscription.fromJson(result);
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
    if (other is! Query$FlowChannelSubscription$user || runtimeType != other.runtimeType) {
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

extension UtilityExtension$Query$FlowChannelSubscription$user
    on Query$FlowChannelSubscription$user {
  CopyWith$Query$FlowChannelSubscription$user<Query$FlowChannelSubscription$user> get copyWith =>
      CopyWith$Query$FlowChannelSubscription$user(this, (i) => i);
}

abstract class CopyWith$Query$FlowChannelSubscription$user<TRes> {
  factory CopyWith$Query$FlowChannelSubscription$user(
    Query$FlowChannelSubscription$user instance,
    TRes Function(Query$FlowChannelSubscription$user) then,
  ) = _CopyWithImpl$Query$FlowChannelSubscription$user;

  factory CopyWith$Query$FlowChannelSubscription$user.stub(TRes res) =
      _CopyWithStubImpl$Query$FlowChannelSubscription$user;

  TRes call({Query$FlowChannelSubscription$user$self? self});
  CopyWith$Query$FlowChannelSubscription$user$self<TRes> get self;
}

class _CopyWithImpl$Query$FlowChannelSubscription$user<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user<TRes> {
  _CopyWithImpl$Query$FlowChannelSubscription$user(this._instance, this._then);

  final Query$FlowChannelSubscription$user _instance;

  final TRes Function(Query$FlowChannelSubscription$user) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? self = _undefined}) => _then(
    Query$FlowChannelSubscription$user(
      self: self == _undefined
          ? _instance.self
          : (self as Query$FlowChannelSubscription$user$self?),
    ),
  );

  CopyWith$Query$FlowChannelSubscription$user$self<TRes> get self {
    final local$self = _instance.self;
    return local$self == null
        ? CopyWith$Query$FlowChannelSubscription$user$self.stub(
            _then(_instance),
          )
        : CopyWith$Query$FlowChannelSubscription$user$self(
            local$self,
            (e) => call(self: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowChannelSubscription$user<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user<TRes> {
  _CopyWithStubImpl$Query$FlowChannelSubscription$user(this._res);

  TRes _res;

  call({Query$FlowChannelSubscription$user$self? self}) => _res;

  CopyWith$Query$FlowChannelSubscription$user$self<TRes> get self =>
      CopyWith$Query$FlowChannelSubscription$user$self.stub(_res);
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

  final Query$FlowChannelSubscription$user$self$subscriptionBenefit? subscriptionBenefit;

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
    if (other is! Query$FlowChannelSubscription$user$self || runtimeType != other.runtimeType) {
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

extension UtilityExtension$Query$FlowChannelSubscription$user$self
    on Query$FlowChannelSubscription$user$self {
  CopyWith$Query$FlowChannelSubscription$user$self<Query$FlowChannelSubscription$user$self>
  get copyWith => CopyWith$Query$FlowChannelSubscription$user$self(this, (i) => i);
}

abstract class CopyWith$Query$FlowChannelSubscription$user$self<TRes> {
  factory CopyWith$Query$FlowChannelSubscription$user$self(
    Query$FlowChannelSubscription$user$self instance,
    TRes Function(Query$FlowChannelSubscription$user$self) then,
  ) = _CopyWithImpl$Query$FlowChannelSubscription$user$self;

  factory CopyWith$Query$FlowChannelSubscription$user$self.stub(TRes res) =
      _CopyWithStubImpl$Query$FlowChannelSubscription$user$self;

  TRes call({
    Query$FlowChannelSubscription$user$self$subscriptionBenefit? subscriptionBenefit,
  });
  CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes>
  get subscriptionBenefit;
}

class _CopyWithImpl$Query$FlowChannelSubscription$user$self<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user$self<TRes> {
  _CopyWithImpl$Query$FlowChannelSubscription$user$self(
    this._instance,
    this._then,
  );

  final Query$FlowChannelSubscription$user$self _instance;

  final TRes Function(Query$FlowChannelSubscription$user$self) _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? subscriptionBenefit = _undefined}) => _then(
    Query$FlowChannelSubscription$user$self(
      subscriptionBenefit: subscriptionBenefit == _undefined
          ? _instance.subscriptionBenefit
          : (subscriptionBenefit as Query$FlowChannelSubscription$user$self$subscriptionBenefit?),
    ),
  );

  CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes>
  get subscriptionBenefit {
    final local$subscriptionBenefit = _instance.subscriptionBenefit;
    return local$subscriptionBenefit == null
        ? CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit.stub(
            _then(_instance),
          )
        : CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit(
            local$subscriptionBenefit,
            (e) => call(subscriptionBenefit: e),
          );
  }
}

class _CopyWithStubImpl$Query$FlowChannelSubscription$user$self<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user$self<TRes> {
  _CopyWithStubImpl$Query$FlowChannelSubscription$user$self(this._res);

  TRes _res;

  call({
    Query$FlowChannelSubscription$user$self$subscriptionBenefit? subscriptionBenefit,
  }) => _res;

  CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes>
  get subscriptionBenefit =>
      CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit.stub(
        _res,
      );
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

extension UtilityExtension$Query$FlowChannelSubscription$user$self$subscriptionBenefit
    on Query$FlowChannelSubscription$user$self$subscriptionBenefit {
  CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<
    Query$FlowChannelSubscription$user$self$subscriptionBenefit
  >
  get copyWith => CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit(
    this,
    (i) => i,
  );
}

abstract class CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes> {
  factory CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit(
    Query$FlowChannelSubscription$user$self$subscriptionBenefit instance,
    TRes Function(Query$FlowChannelSubscription$user$self$subscriptionBenefit) then,
  ) = _CopyWithImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit;

  factory CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit.stub(
    TRes res,
  ) = _CopyWithStubImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit;

  TRes call({String? id});
}

class _CopyWithImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes> {
  _CopyWithImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit(
    this._instance,
    this._then,
  );

  final Query$FlowChannelSubscription$user$self$subscriptionBenefit _instance;

  final TRes Function(
    Query$FlowChannelSubscription$user$self$subscriptionBenefit,
  )
  _then;

  static const _undefined = <dynamic, dynamic>{};

  TRes call({Object? id = _undefined}) => _then(
    Query$FlowChannelSubscription$user$self$subscriptionBenefit(
      id: id == _undefined ? _instance.id : (id as String?),
    ),
  );
}

class _CopyWithStubImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes>
    implements CopyWith$Query$FlowChannelSubscription$user$self$subscriptionBenefit<TRes> {
  _CopyWithStubImpl$Query$FlowChannelSubscription$user$self$subscriptionBenefit(
    this._res,
  );

  TRes _res;

  call({String? id}) => _res;
}
