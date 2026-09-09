// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Mutation$FlowUnfollowUser {
  factory Variables$Mutation$FlowUnfollowUser({required String targetID}) =>
      Variables$Mutation$FlowUnfollowUser._({r'targetID': targetID});

  Variables$Mutation$FlowUnfollowUser._(this._$data);

  factory Variables$Mutation$FlowUnfollowUser.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$targetID = data['targetID'];
    result$data['targetID'] = (l$targetID as String);
    return Variables$Mutation$FlowUnfollowUser._(result$data);
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
    if (other is! Variables$Mutation$FlowUnfollowUser ||
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

class Mutation$FlowUnfollowUser {
  Mutation$FlowUnfollowUser({this.unfollowUser});

  factory Mutation$FlowUnfollowUser.fromJson(Map<String, dynamic> json) {
    final l$unfollowUser = json.containsKey('unfollowUser')
        ? json['unfollowUser']
        : null;
    return Mutation$FlowUnfollowUser(
      unfollowUser: l$unfollowUser == null
          ? null
          : Mutation$FlowUnfollowUser$unfollowUser.fromJson(
              (l$unfollowUser as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowUnfollowUser$unfollowUser? unfollowUser;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$unfollowUser = unfollowUser;
    _resultData['unfollowUser'] = l$unfollowUser?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$unfollowUser = unfollowUser;
    return Object.hashAll([l$unfollowUser]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowUnfollowUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$unfollowUser = unfollowUser;
    final lOther$unfollowUser = other.unfollowUser;
    if (l$unfollowUser != lOther$unfollowUser) {
      return false;
    }
    return true;
  }
}

const documentNodeMutationFlowUnfollowUser = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.mutation,
      name: NameNode(value: 'FlowUnfollowUser'),
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
            name: NameNode(value: 'unfollowUser'),
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
              ],
            ),
          ),
        ],
      ),
    ),
  ],
);
Mutation$FlowUnfollowUser _parserFn$Mutation$FlowUnfollowUser(
  Map<String, dynamic> data,
) => Mutation$FlowUnfollowUser.fromJson(data);
typedef OnMutationCompleted$Mutation$FlowUnfollowUser =
    FutureOr<void> Function(Map<String, dynamic>?, Mutation$FlowUnfollowUser?);

class Options$Mutation$FlowUnfollowUser
    extends graphql.MutationOptions<Mutation$FlowUnfollowUser> {
  Options$Mutation$FlowUnfollowUser({
    String? operationName,
    required Variables$Mutation$FlowUnfollowUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowUnfollowUser? typedOptimisticResult,
    graphql.Context? context,
    OnMutationCompleted$Mutation$FlowUnfollowUser? onCompleted,
    graphql.OnMutationUpdate<Mutation$FlowUnfollowUser>? update,
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
                 data == null
                     ? null
                     : _parserFn$Mutation$FlowUnfollowUser(data),
               ),
         update: update,
         onError: onError,
         document: documentNodeMutationFlowUnfollowUser,
         parserFn: _parserFn$Mutation$FlowUnfollowUser,
       );

  final OnMutationCompleted$Mutation$FlowUnfollowUser? onCompletedWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onCompleted == null
        ? super.properties
        : super.properties.where((property) => property != onCompleted),
    onCompletedWithParsed,
  ];
}

class WatchOptions$Mutation$FlowUnfollowUser
    extends graphql.WatchQueryOptions<Mutation$FlowUnfollowUser> {
  WatchOptions$Mutation$FlowUnfollowUser({
    String? operationName,
    required Variables$Mutation$FlowUnfollowUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowUnfollowUser? typedOptimisticResult,
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
         document: documentNodeMutationFlowUnfollowUser,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Mutation$FlowUnfollowUser,
       );
}

extension ClientExtension$Mutation$FlowUnfollowUser on graphql.GraphQLClient {
  Future<graphql.QueryResult<Mutation$FlowUnfollowUser>>
  mutate$FlowUnfollowUser(Options$Mutation$FlowUnfollowUser options) async =>
      await this.mutate(options);

  graphql.ObservableQuery<Mutation$FlowUnfollowUser>
  watchMutation$FlowUnfollowUser(
    WatchOptions$Mutation$FlowUnfollowUser options,
  ) => this.watchMutation(options);
}

class Mutation$FlowUnfollowUser$unfollowUser {
  Mutation$FlowUnfollowUser$unfollowUser({this.follow});

  factory Mutation$FlowUnfollowUser$unfollowUser.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$follow = json.containsKey('follow') ? json['follow'] : null;
    return Mutation$FlowUnfollowUser$unfollowUser(
      follow: l$follow == null
          ? null
          : Mutation$FlowUnfollowUser$unfollowUser$follow.fromJson(
              (l$follow as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowUnfollowUser$unfollowUser$follow? follow;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$follow = follow;
    _resultData['follow'] = l$follow?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$follow = follow;
    return Object.hashAll([l$follow]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowUnfollowUser$unfollowUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$follow = follow;
    final lOther$follow = other.follow;
    if (l$follow != lOther$follow) {
      return false;
    }
    return true;
  }
}

class Mutation$FlowUnfollowUser$unfollowUser$follow {
  Mutation$FlowUnfollowUser$unfollowUser$follow({this.user});

  factory Mutation$FlowUnfollowUser$unfollowUser$follow.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Mutation$FlowUnfollowUser$unfollowUser$follow(
      user: l$user == null
          ? null
          : Mutation$FlowUnfollowUser$unfollowUser$follow$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowUnfollowUser$unfollowUser$follow$user? user;

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
    if (other is! Mutation$FlowUnfollowUser$unfollowUser$follow ||
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

class Mutation$FlowUnfollowUser$unfollowUser$follow$user {
  Mutation$FlowUnfollowUser$unfollowUser$follow$user({this.id});

  factory Mutation$FlowUnfollowUser$unfollowUser$follow$user.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    return Mutation$FlowUnfollowUser$unfollowUser$follow$user(
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
    if (other is! Mutation$FlowUnfollowUser$unfollowUser$follow$user ||
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
