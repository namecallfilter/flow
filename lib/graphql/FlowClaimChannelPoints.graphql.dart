// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Mutation$FlowClaimChannelPoints {
  factory Variables$Mutation$FlowClaimChannelPoints({
    required String channelID,
    required String claimID,
  }) => Variables$Mutation$FlowClaimChannelPoints._({
    r'channelID': channelID,
    r'claimID': claimID,
  });

  Variables$Mutation$FlowClaimChannelPoints._(this._$data);

  factory Variables$Mutation$FlowClaimChannelPoints.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$claimID = data['claimID'];
    result$data['claimID'] = (l$claimID as String);
    return Variables$Mutation$FlowClaimChannelPoints._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get claimID => (_$data['claimID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$claimID = claimID;
    result$data['claimID'] = l$claimID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Mutation$FlowClaimChannelPoints ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$claimID = claimID;
    final lOther$claimID = other.claimID;
    if (l$claimID != lOther$claimID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$claimID = claimID;
    return Object.hashAll([l$channelID, l$claimID]);
  }
}

class Mutation$FlowClaimChannelPoints {
  Mutation$FlowClaimChannelPoints({this.claimCommunityPoints});

  factory Mutation$FlowClaimChannelPoints.fromJson(Map<String, dynamic> json) {
    final l$claimCommunityPoints = json.containsKey('claimCommunityPoints')
        ? json['claimCommunityPoints']
        : null;
    return Mutation$FlowClaimChannelPoints(
      claimCommunityPoints: l$claimCommunityPoints == null
          ? null
          : Mutation$FlowClaimChannelPoints$claimCommunityPoints.fromJson(
              (l$claimCommunityPoints as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowClaimChannelPoints$claimCommunityPoints?
  claimCommunityPoints;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$claimCommunityPoints = claimCommunityPoints;
    _resultData['claimCommunityPoints'] = l$claimCommunityPoints?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$claimCommunityPoints = claimCommunityPoints;
    return Object.hashAll([l$claimCommunityPoints]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowClaimChannelPoints ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$claimCommunityPoints = claimCommunityPoints;
    final lOther$claimCommunityPoints = other.claimCommunityPoints;
    if (l$claimCommunityPoints != lOther$claimCommunityPoints) {
      return false;
    }
    return true;
  }
}

const documentNodeMutationFlowClaimChannelPoints = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.mutation,
      name: NameNode(value: 'FlowClaimChannelPoints'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'channelID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'claimID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'claimCommunityPoints'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'input'),
                value: ObjectValueNode(
                  fields: [
                    ObjectFieldNode(
                      name: NameNode(value: 'channelID'),
                      value: VariableNode(name: NameNode(value: 'channelID')),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'claimID'),
                      value: VariableNode(name: NameNode(value: 'claimID')),
                    ),
                  ],
                ),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'claim'),
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
                        name: NameNode(value: 'pointsEarnedTotal'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
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
Mutation$FlowClaimChannelPoints _parserFn$Mutation$FlowClaimChannelPoints(
  Map<String, dynamic> data,
) => Mutation$FlowClaimChannelPoints.fromJson(data);
typedef OnMutationCompleted$Mutation$FlowClaimChannelPoints =
    FutureOr<void> Function(
      Map<String, dynamic>?,
      Mutation$FlowClaimChannelPoints?,
    );

class Options$Mutation$FlowClaimChannelPoints
    extends graphql.MutationOptions<Mutation$FlowClaimChannelPoints> {
  Options$Mutation$FlowClaimChannelPoints({
    String? operationName,
    required Variables$Mutation$FlowClaimChannelPoints variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowClaimChannelPoints? typedOptimisticResult,
    graphql.Context? context,
    OnMutationCompleted$Mutation$FlowClaimChannelPoints? onCompleted,
    graphql.OnMutationUpdate<Mutation$FlowClaimChannelPoints>? update,
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
                     : _parserFn$Mutation$FlowClaimChannelPoints(data),
               ),
         update: update,
         onError: onError,
         document: documentNodeMutationFlowClaimChannelPoints,
         parserFn: _parserFn$Mutation$FlowClaimChannelPoints,
       );

  final OnMutationCompleted$Mutation$FlowClaimChannelPoints?
  onCompletedWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onCompleted == null
        ? super.properties
        : super.properties.where((property) => property != onCompleted),
    onCompletedWithParsed,
  ];
}

class WatchOptions$Mutation$FlowClaimChannelPoints
    extends graphql.WatchQueryOptions<Mutation$FlowClaimChannelPoints> {
  WatchOptions$Mutation$FlowClaimChannelPoints({
    String? operationName,
    required Variables$Mutation$FlowClaimChannelPoints variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Mutation$FlowClaimChannelPoints? typedOptimisticResult,
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
         document: documentNodeMutationFlowClaimChannelPoints,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Mutation$FlowClaimChannelPoints,
       );
}

extension ClientExtension$Mutation$FlowClaimChannelPoints
    on graphql.GraphQLClient {
  Future<graphql.QueryResult<Mutation$FlowClaimChannelPoints>>
  mutate$FlowClaimChannelPoints(
    Options$Mutation$FlowClaimChannelPoints options,
  ) async => await this.mutate(options);

  graphql.ObservableQuery<Mutation$FlowClaimChannelPoints>
  watchMutation$FlowClaimChannelPoints(
    WatchOptions$Mutation$FlowClaimChannelPoints options,
  ) => this.watchMutation(options);
}

class Mutation$FlowClaimChannelPoints$claimCommunityPoints {
  Mutation$FlowClaimChannelPoints$claimCommunityPoints({
    this.claim,
    this.error,
  });

  factory Mutation$FlowClaimChannelPoints$claimCommunityPoints.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$claim = json.containsKey('claim') ? json['claim'] : null;
    final l$error = json.containsKey('error') ? json['error'] : null;
    return Mutation$FlowClaimChannelPoints$claimCommunityPoints(
      claim: l$claim == null
          ? null
          : Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim.fromJson(
              (l$claim as Map<String, dynamic>),
            ),
      error: l$error == null
          ? null
          : Mutation$FlowClaimChannelPoints$claimCommunityPoints$error.fromJson(
              (l$error as Map<String, dynamic>),
            ),
    );
  }

  final Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim? claim;

  final Mutation$FlowClaimChannelPoints$claimCommunityPoints$error? error;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$claim = claim;
    _resultData['claim'] = l$claim?.toJson();
    final l$error = error;
    _resultData['error'] = l$error?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$claim = claim;
    final l$error = error;
    return Object.hashAll([l$claim, l$error]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowClaimChannelPoints$claimCommunityPoints ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$claim = claim;
    final lOther$claim = other.claim;
    if (l$claim != lOther$claim) {
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

class Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim {
  Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim({
    this.id,
    this.pointsEarnedTotal,
  });

  factory Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$pointsEarnedTotal = json.containsKey('pointsEarnedTotal')
        ? json['pointsEarnedTotal']
        : null;
    return Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim(
      id: (l$id as String?),
      pointsEarnedTotal: (l$pointsEarnedTotal as int?),
    );
  }

  final String? id;

  final int? pointsEarnedTotal;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$pointsEarnedTotal = pointsEarnedTotal;
    _resultData['pointsEarnedTotal'] = l$pointsEarnedTotal;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$pointsEarnedTotal = pointsEarnedTotal;
    return Object.hashAll([l$id, l$pointsEarnedTotal]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Mutation$FlowClaimChannelPoints$claimCommunityPoints$claim ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$pointsEarnedTotal = pointsEarnedTotal;
    final lOther$pointsEarnedTotal = other.pointsEarnedTotal;
    if (l$pointsEarnedTotal != lOther$pointsEarnedTotal) {
      return false;
    }
    return true;
  }
}

class Mutation$FlowClaimChannelPoints$claimCommunityPoints$error {
  Mutation$FlowClaimChannelPoints$claimCommunityPoints$error({this.code});

  factory Mutation$FlowClaimChannelPoints$claimCommunityPoints$error.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$code = json.containsKey('code') ? json['code'] : null;
    return Mutation$FlowClaimChannelPoints$claimCommunityPoints$error(
      code: (l$code as String?),
    );
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
    if (other is! Mutation$FlowClaimChannelPoints$claimCommunityPoints$error ||
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
