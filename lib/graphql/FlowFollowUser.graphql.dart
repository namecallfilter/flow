// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Mutation$FlowFollowUser {
  factory Variables$Mutation$FlowFollowUser({required String targetID}) =>
      Variables$Mutation$FlowFollowUser._({r'targetID': targetID});

  Variables$Mutation$FlowFollowUser._(this._$data);

  factory Variables$Mutation$FlowFollowUser.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$targetID = data['targetID'];
    result$data['targetID'] = (l$targetID as String);
    return Variables$Mutation$FlowFollowUser._(result$data);
  }

  Map<String, dynamic> _$data;

  String get targetID => (_$data['targetID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$targetID = targetID;
    result$data['targetID'] = l$targetID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Mutation$FlowFollowUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$targetID = targetID;
    final lOther$targetID = other.targetID;
    if (l$targetID != lOther$targetID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$targetID = targetID;
    return Object.hashAll([l$targetID]);
  }
}

class Mutation$FlowFollowUser {
  Mutation$FlowFollowUser({this.followUser});

  factory Mutation$FlowFollowUser.fromJson(Map<String, dynamic> json) {
    final l$followUser = json.containsKey('followUser')
        ? json['followUser']
        : null;
    return Mutation$FlowFollowUser(
      followUser: l$followUser == null
          ? null
          : Mutation$FlowFollowUser$followUser.fromJson(
              (l$followUser as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowFollowUser$followUser? followUser;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$followUser = followUser;
    _resultData['followUser'] = l$followUser?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$followUser = followUser;
    return Object.hashAll([l$followUser]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowFollowUser || runtimeType != other.runtimeType) {
      return false;
    }
    final l$followUser = followUser;
    final lOther$followUser = other.followUser;
    if (l$followUser != lOther$followUser) {
      return false;
    }
    return true;
  }
}

const documentNodeMutationFlowFollowUser = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.mutation,
      name: NameNode(value: 'FlowFollowUser'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'targetID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'followUser'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'input'),
                value: ObjectValueNode(
                  fields: [
                    ObjectFieldNode(
                      name: NameNode(value: 'targetID'),
                      value: VariableNode(name: NameNode(value: 'targetID')),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'disableNotifications'),
                      value: BooleanValueNode(value: false),
                    ),
                  ],
                ),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'follow'),
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
                      FieldNode(
                        name: NameNode(value: 'user'),
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
                FieldNode(
                  name: NameNode(value: 'error'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'code'),
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
Mutation$FlowFollowUser _parserFn$Mutation$FlowFollowUser(
  Map<String, dynamic> data,
) => Mutation$FlowFollowUser.fromJson(data);
typedef OnMutationCompleted$Mutation$FlowFollowUser =
    FutureOr<void> Function(Map<String, dynamic>?, Mutation$FlowFollowUser?);

class Options$Mutation$FlowFollowUser
    extends graphql.MutationOptions<Mutation$FlowFollowUser> {
  Options$Mutation$FlowFollowUser({
    String? operationName,
    required Variables$Mutation$FlowFollowUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowFollowUser? typedOptimisticResult,
    graphql.Context? context,
    OnMutationCompleted$Mutation$FlowFollowUser? onCompleted,
    graphql.OnMutationUpdate<Mutation$FlowFollowUser>? update,
    graphql.OnError? onError,
  }) : onCompletedWithParsed = onCompleted,
       super(
         variables: variables.toJson(),
         operationName: operationName,
         fetchPolicy: fetchPolicy,
         errorPolicy: errorPolicy,
         cacheRereadPolicy: cacheRereadPolicy,
         optimisticResult: optimisticResult ?? typedOptimisticResult?.toJson(),
         context: context,
         onCompleted: onCompleted == null
             ? null
             : (data) => onCompleted(
                 data,
                 data == null ? null : _parserFn$Mutation$FlowFollowUser(data),
               ),
         update: update,
         onError: onError,
         document: documentNodeMutationFlowFollowUser,
         parserFn: _parserFn$Mutation$FlowFollowUser,
       );

  final OnMutationCompleted$Mutation$FlowFollowUser? onCompletedWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onCompleted == null
        ? super.properties
        : super.properties.where((property) => property != onCompleted),
    onCompletedWithParsed,
  ];
}

class WatchOptions$Mutation$FlowFollowUser
    extends graphql.WatchQueryOptions<Mutation$FlowFollowUser> {
  WatchOptions$Mutation$FlowFollowUser({
    String? operationName,
    required Variables$Mutation$FlowFollowUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowFollowUser? typedOptimisticResult,
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
         document: documentNodeMutationFlowFollowUser,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Mutation$FlowFollowUser,
       );
}

extension ClientExtension$Mutation$FlowFollowUser on graphql.GraphQLClient {
  Future<graphql.QueryResult<Mutation$FlowFollowUser>> mutate$FlowFollowUser(
    Options$Mutation$FlowFollowUser options,
  ) async => await this.mutate(options);

  graphql.ObservableQuery<Mutation$FlowFollowUser> watchMutation$FlowFollowUser(
    WatchOptions$Mutation$FlowFollowUser options,
  ) => this.watchMutation(options);
}

class Mutation$FlowFollowUser$followUser {
  Mutation$FlowFollowUser$followUser({this.follow, this.error});

  factory Mutation$FlowFollowUser$followUser.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$follow = json.containsKey('follow') ? json['follow'] : null;
    final l$error = json.containsKey('error') ? json['error'] : null;
    return Mutation$FlowFollowUser$followUser(
      follow: l$follow == null
          ? null
          : Mutation$FlowFollowUser$followUser$follow.fromJson(
              (l$follow as Map<String, dynamic>),
            ),
      error: l$error == null
          ? null
          : Mutation$FlowFollowUser$followUser$error.fromJson(
              (l$error as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowFollowUser$followUser$follow? follow;

  final Mutation$FlowFollowUser$followUser$error? error;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$follow = follow;
    _resultData['follow'] = l$follow?.toJson();
    final l$error = error;
    _resultData['error'] = l$error?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$follow = follow;
    final l$error = error;
    return Object.hashAll([l$follow, l$error]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowFollowUser$followUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$follow = follow;
    final lOther$follow = other.follow;
    if (l$follow != lOther$follow) {
      return false;
    }
    final l$error = error;
    final lOther$error = other.error;
    if (l$error != lOther$error) {
      return false;
    }
    return true;
  }
}

class Mutation$FlowFollowUser$followUser$follow {
  Mutation$FlowFollowUser$followUser$follow({this.followedAt, this.user});

  factory Mutation$FlowFollowUser$followUser$follow.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$followedAt = json.containsKey('followedAt')
        ? json['followedAt']
        : null;
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Mutation$FlowFollowUser$followUser$follow(
      followedAt: (l$followedAt as String?),
      user: l$user == null
          ? null
          : Mutation$FlowFollowUser$followUser$follow$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final String? followedAt;

  final Mutation$FlowFollowUser$followUser$follow$user? user;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$followedAt = followedAt;
    _resultData['followedAt'] = l$followedAt;
    final l$user = user;
    _resultData['user'] = l$user?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$followedAt = followedAt;
    final l$user = user;
    return Object.hashAll([l$followedAt, l$user]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowFollowUser$followUser$follow ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$followedAt = followedAt;
    final lOther$followedAt = other.followedAt;
    if (l$followedAt != lOther$followedAt) {
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

class Mutation$FlowFollowUser$followUser$follow$user {
  Mutation$FlowFollowUser$followUser$follow$user({this.id});

  factory Mutation$FlowFollowUser$followUser$follow$user.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    return Mutation$FlowFollowUser$followUser$follow$user(
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
    if (other is! Mutation$FlowFollowUser$followUser$follow$user ||
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

class Mutation$FlowFollowUser$followUser$error {
  Mutation$FlowFollowUser$followUser$error({this.code});

  factory Mutation$FlowFollowUser$followUser$error.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$code = json.containsKey('code') ? json['code'] : null;
    return Mutation$FlowFollowUser$followUser$error(code: (l$code as String?));
  }

  final String? code;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$code = code;
    _resultData['code'] = l$code;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$code = code;
    return Object.hashAll([l$code]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowFollowUser$followUser$error ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$code = code;
    final lOther$code = other.code;
    if (l$code != lOther$code) {
      return false;
    }
    return true;
  }
}
