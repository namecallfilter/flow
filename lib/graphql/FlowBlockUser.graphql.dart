// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Mutation$FlowBlockUser {
  factory Variables$Mutation$FlowBlockUser({required String targetUserID}) =>
      Variables$Mutation$FlowBlockUser._({r'targetUserID': targetUserID});

  Variables$Mutation$FlowBlockUser._(this._$data);

  factory Variables$Mutation$FlowBlockUser.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$targetUserID = data['targetUserID'];
    result$data['targetUserID'] = (l$targetUserID as String);
    return Variables$Mutation$FlowBlockUser._(result$data);
  }

  Map<String, dynamic> _$data;

  String get targetUserID => (_$data['targetUserID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$targetUserID = targetUserID;
    result$data['targetUserID'] = l$targetUserID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Mutation$FlowBlockUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$targetUserID = targetUserID;
    final lOther$targetUserID = other.targetUserID;
    if (l$targetUserID != lOther$targetUserID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$targetUserID = targetUserID;
    return Object.hashAll([l$targetUserID]);
  }
}

class Mutation$FlowBlockUser {
  Mutation$FlowBlockUser({this.blockUser});

  factory Mutation$FlowBlockUser.fromJson(Map<String, dynamic> json) {
    final l$blockUser = json.containsKey('blockUser')
        ? json['blockUser']
        : null;
    return Mutation$FlowBlockUser(
      blockUser: l$blockUser == null
          ? null
          : Mutation$FlowBlockUser$blockUser.fromJson(
              (l$blockUser as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowBlockUser$blockUser? blockUser;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$blockUser = blockUser;
    _resultData['blockUser'] = l$blockUser?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$blockUser = blockUser;
    return Object.hashAll([l$blockUser]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowBlockUser || runtimeType != other.runtimeType) {
      return false;
    }
    final l$blockUser = blockUser;
    final lOther$blockUser = other.blockUser;
    if (l$blockUser != lOther$blockUser) {
      return false;
    }
    return true;
  }
}

const documentNodeMutationFlowBlockUser = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.mutation,
      name: NameNode(value: 'FlowBlockUser'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'targetUserID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'blockUser'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'input'),
                value: ObjectValueNode(
                  fields: [
                    ObjectFieldNode(
                      name: NameNode(value: 'targetUserID'),
                      value: VariableNode(
                        name: NameNode(value: 'targetUserID'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'targetUser'),
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
);
Mutation$FlowBlockUser _parserFn$Mutation$FlowBlockUser(
  Map<String, dynamic> data,
) => Mutation$FlowBlockUser.fromJson(data);
typedef OnMutationCompleted$Mutation$FlowBlockUser =
    FutureOr<void> Function(Map<String, dynamic>?, Mutation$FlowBlockUser?);

class Options$Mutation$FlowBlockUser
    extends graphql.MutationOptions<Mutation$FlowBlockUser> {
  Options$Mutation$FlowBlockUser({
    String? operationName,
    required Variables$Mutation$FlowBlockUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowBlockUser? typedOptimisticResult,
    graphql.Context? context,
    OnMutationCompleted$Mutation$FlowBlockUser? onCompleted,
    graphql.OnMutationUpdate<Mutation$FlowBlockUser>? update,
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
                 data == null ? null : _parserFn$Mutation$FlowBlockUser(data),
               ),
         update: update,
         onError: onError,
         document: documentNodeMutationFlowBlockUser,
         parserFn: _parserFn$Mutation$FlowBlockUser,
       );

  final OnMutationCompleted$Mutation$FlowBlockUser? onCompletedWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onCompleted == null
        ? super.properties
        : super.properties.where((property) => property != onCompleted),
    onCompletedWithParsed,
  ];
}

class WatchOptions$Mutation$FlowBlockUser
    extends graphql.WatchQueryOptions<Mutation$FlowBlockUser> {
  WatchOptions$Mutation$FlowBlockUser({
    String? operationName,
    required Variables$Mutation$FlowBlockUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowBlockUser? typedOptimisticResult,
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
         document: documentNodeMutationFlowBlockUser,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Mutation$FlowBlockUser,
       );
}

extension ClientExtension$Mutation$FlowBlockUser on graphql.GraphQLClient {
  Future<graphql.QueryResult<Mutation$FlowBlockUser>> mutate$FlowBlockUser(
    Options$Mutation$FlowBlockUser options,
  ) async => await this.mutate(options);

  graphql.ObservableQuery<Mutation$FlowBlockUser> watchMutation$FlowBlockUser(
    WatchOptions$Mutation$FlowBlockUser options,
  ) => this.watchMutation(options);
}

class Mutation$FlowBlockUser$blockUser {
  Mutation$FlowBlockUser$blockUser({this.targetUser});

  factory Mutation$FlowBlockUser$blockUser.fromJson(Map<String, dynamic> json) {
    final l$targetUser = json.containsKey('targetUser')
        ? json['targetUser']
        : null;
    return Mutation$FlowBlockUser$blockUser(
      targetUser: l$targetUser == null
          ? null
          : Mutation$FlowBlockUser$blockUser$targetUser.fromJson(
              (l$targetUser as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowBlockUser$blockUser$targetUser? targetUser;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$targetUser = targetUser;
    _resultData['targetUser'] = l$targetUser?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$targetUser = targetUser;
    return Object.hashAll([l$targetUser]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowBlockUser$blockUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$targetUser = targetUser;
    final lOther$targetUser = other.targetUser;
    if (l$targetUser != lOther$targetUser) {
      return false;
    }
    return true;
  }
}

class Mutation$FlowBlockUser$blockUser$targetUser {
  Mutation$FlowBlockUser$blockUser$targetUser({this.id});

  factory Mutation$FlowBlockUser$blockUser$targetUser.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    return Mutation$FlowBlockUser$blockUser$targetUser(id: (l$id as String?));
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
    if (other is! Mutation$FlowBlockUser$blockUser$targetUser ||
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
