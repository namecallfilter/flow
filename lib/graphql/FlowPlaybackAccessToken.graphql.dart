// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowPlaybackAccessToken {
  factory Variables$Query$FlowPlaybackAccessToken({
    required String login,
    required bool isLive,
    required String vodID,
    required bool isVod,
    required String platform,
    required String playerType,
  }) => Variables$Query$FlowPlaybackAccessToken._({
    r'login': login,
    r'isLive': isLive,
    r'vodID': vodID,
    r'isVod': isVod,
    r'platform': platform,
    r'playerType': playerType,
  });

  Variables$Query$FlowPlaybackAccessToken._(this._$data);

  factory Variables$Query$FlowPlaybackAccessToken.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    final l$isLive = data['isLive'];
    result$data['isLive'] = (l$isLive as bool);
    final l$vodID = data['vodID'];
    result$data['vodID'] = (l$vodID as String);
    final l$isVod = data['isVod'];
    result$data['isVod'] = (l$isVod as bool);
    final l$platform = data['platform'];
    result$data['platform'] = (l$platform as String);
    final l$playerType = data['playerType'];
    result$data['playerType'] = (l$playerType as String);
    return Variables$Query$FlowPlaybackAccessToken._(result$data);
  }

  Map<String, dynamic> _$data;

  String get login => (_$data['login'] as String);

  bool get isLive => (_$data['isLive'] as bool);

  String get vodID => (_$data['vodID'] as String);

  bool get isVod => (_$data['isVod'] as bool);

  String get platform => (_$data['platform'] as String);

  String get playerType => (_$data['playerType'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$login = login;
    result$data['login'] = l$login;
    final l$isLive = isLive;
    result$data['isLive'] = l$isLive;
    final l$vodID = vodID;
    result$data['vodID'] = l$vodID;
    final l$isVod = isVod;
    result$data['isVod'] = l$isVod;
    final l$platform = platform;
    result$data['platform'] = l$platform;
    final l$playerType = playerType;
    result$data['playerType'] = l$playerType;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowPlaybackAccessToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    final l$isLive = isLive;
    final lOther$isLive = other.isLive;
    if (l$isLive != lOther$isLive) {
      return false;
    }
    final l$vodID = vodID;
    final lOther$vodID = other.vodID;
    if (l$vodID != lOther$vodID) {
      return false;
    }
    final l$isVod = isVod;
    final lOther$isVod = other.isVod;
    if (l$isVod != lOther$isVod) {
      return false;
    }
    final l$platform = platform;
    final lOther$platform = other.platform;
    if (l$platform != lOther$platform) {
      return false;
    }
    final l$playerType = playerType;
    final lOther$playerType = other.playerType;
    if (l$playerType != lOther$playerType) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$login = login;
    final l$isLive = isLive;
    final l$vodID = vodID;
    final l$isVod = isVod;
    final l$platform = platform;
    final l$playerType = playerType;
    return Object.hashAll([
      l$login,
      l$isLive,
      l$vodID,
      l$isVod,
      l$platform,
      l$playerType,
    ]);
  }
}

class Query$FlowPlaybackAccessToken {
  Query$FlowPlaybackAccessToken({
    this.streamPlaybackAccessToken,
    this.videoPlaybackAccessToken,
  });

  factory Query$FlowPlaybackAccessToken.fromJson(Map<String, dynamic> json) {
    final l$streamPlaybackAccessToken =
        json.containsKey('streamPlaybackAccessToken')
        ? json['streamPlaybackAccessToken']
        : null;
    final l$videoPlaybackAccessToken =
        json.containsKey('videoPlaybackAccessToken')
        ? json['videoPlaybackAccessToken']
        : null;
    return Query$FlowPlaybackAccessToken(
      streamPlaybackAccessToken: l$streamPlaybackAccessToken == null
          ? null
          : Query$FlowPlaybackAccessToken$streamPlaybackAccessToken.fromJson(
              (l$streamPlaybackAccessToken as Map<String, dynamic>),
            ),
      videoPlaybackAccessToken: l$videoPlaybackAccessToken == null
          ? null
          : Query$FlowPlaybackAccessToken$videoPlaybackAccessToken.fromJson(
              (l$videoPlaybackAccessToken as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowPlaybackAccessToken$streamPlaybackAccessToken?
  streamPlaybackAccessToken;

  final Query$FlowPlaybackAccessToken$videoPlaybackAccessToken?
  videoPlaybackAccessToken;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$streamPlaybackAccessToken = streamPlaybackAccessToken;
    _resultData['streamPlaybackAccessToken'] = l$streamPlaybackAccessToken
        ?.toJson();
    final l$videoPlaybackAccessToken = videoPlaybackAccessToken;
    _resultData['videoPlaybackAccessToken'] = l$videoPlaybackAccessToken
        ?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$streamPlaybackAccessToken = streamPlaybackAccessToken;
    final l$videoPlaybackAccessToken = videoPlaybackAccessToken;
    return Object.hashAll([
      l$streamPlaybackAccessToken,
      l$videoPlaybackAccessToken,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPlaybackAccessToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$streamPlaybackAccessToken = streamPlaybackAccessToken;
    final lOther$streamPlaybackAccessToken = other.streamPlaybackAccessToken;
    if (l$streamPlaybackAccessToken != lOther$streamPlaybackAccessToken) {
      return false;
    }
    final l$videoPlaybackAccessToken = videoPlaybackAccessToken;
    final lOther$videoPlaybackAccessToken = other.videoPlaybackAccessToken;
    if (l$videoPlaybackAccessToken != lOther$videoPlaybackAccessToken) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowPlaybackAccessToken = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowPlaybackAccessToken'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'login')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'isLive')),
          type: NamedTypeNode(
            name: NameNode(value: 'Boolean'),
            isNonNull: true,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'vodID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'isVod')),
          type: NamedTypeNode(
            name: NameNode(value: 'Boolean'),
            isNonNull: true,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'platform')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'playerType')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'streamPlaybackAccessToken'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'channelName'),
                value: VariableNode(name: NameNode(value: 'login')),
              ),
              ArgumentNode(
                name: NameNode(value: 'params'),
                value: ObjectValueNode(
                  fields: [
                    ObjectFieldNode(
                      name: NameNode(value: 'platform'),
                      value: VariableNode(name: NameNode(value: 'platform')),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'playerBackend'),
                      value: StringValueNode(
                        value: 'mediaplayer',
                        isBlock: false,
                      ),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'playerType'),
                      value: VariableNode(name: NameNode(value: 'playerType')),
                    ),
                  ],
                ),
              ),
            ],
            directives: [
              DirectiveNode(
                name: NameNode(value: 'include'),
                arguments: [
                  ArgumentNode(
                    name: NameNode(value: 'if'),
                    value: VariableNode(name: NameNode(value: 'isLive')),
                  ),
                ],
              ),
            ],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'value'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'signature'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'authorization'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'isForbidden'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'forbiddenReasonCode'),
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
            name: NameNode(value: 'videoPlaybackAccessToken'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'vodID')),
              ),
              ArgumentNode(
                name: NameNode(value: 'params'),
                value: ObjectValueNode(
                  fields: [
                    ObjectFieldNode(
                      name: NameNode(value: 'platform'),
                      value: VariableNode(name: NameNode(value: 'platform')),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'playerBackend'),
                      value: StringValueNode(
                        value: 'mediaplayer',
                        isBlock: false,
                      ),
                    ),
                    ObjectFieldNode(
                      name: NameNode(value: 'playerType'),
                      value: VariableNode(name: NameNode(value: 'playerType')),
                    ),
                  ],
                ),
              ),
            ],
            directives: [
              DirectiveNode(
                name: NameNode(value: 'include'),
                arguments: [
                  ArgumentNode(
                    name: NameNode(value: 'if'),
                    value: VariableNode(name: NameNode(value: 'isVod')),
                  ),
                ],
              ),
            ],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'value'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'signature'),
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
);
Query$FlowPlaybackAccessToken _parserFn$Query$FlowPlaybackAccessToken(
  Map<String, dynamic> data,
) => Query$FlowPlaybackAccessToken.fromJson(data);
typedef OnQueryComplete$Query$FlowPlaybackAccessToken =
    FutureOr<void> Function(
      Map<String, dynamic>?,
      Query$FlowPlaybackAccessToken?,
    );

class Options$Query$FlowPlaybackAccessToken
    extends graphql.QueryOptions<Query$FlowPlaybackAccessToken> {
  Options$Query$FlowPlaybackAccessToken({
    String? operationName,
    required Variables$Query$FlowPlaybackAccessToken variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowPlaybackAccessToken? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowPlaybackAccessToken? onComplete,
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
                     : _parserFn$Query$FlowPlaybackAccessToken(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowPlaybackAccessToken,
         parserFn: _parserFn$Query$FlowPlaybackAccessToken,
       );

  final OnQueryComplete$Query$FlowPlaybackAccessToken? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowPlaybackAccessToken
    extends graphql.WatchQueryOptions<Query$FlowPlaybackAccessToken> {
  WatchOptions$Query$FlowPlaybackAccessToken({
    String? operationName,
    required Variables$Query$FlowPlaybackAccessToken variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowPlaybackAccessToken? typedOptimisticResult,
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
         document: documentNodeQueryFlowPlaybackAccessToken,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowPlaybackAccessToken,
       );
}

class FetchMoreOptions$Query$FlowPlaybackAccessToken
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowPlaybackAccessToken({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowPlaybackAccessToken variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowPlaybackAccessToken,
       );
}

extension ClientExtension$Query$FlowPlaybackAccessToken
    on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowPlaybackAccessToken>>
  query$FlowPlaybackAccessToken(
    Options$Query$FlowPlaybackAccessToken options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowPlaybackAccessToken>
  watchQuery$FlowPlaybackAccessToken(
    WatchOptions$Query$FlowPlaybackAccessToken options,
  ) => this.watchQuery(options);

  void writeQuery$FlowPlaybackAccessToken({
    required Query$FlowPlaybackAccessToken data,
    required Variables$Query$FlowPlaybackAccessToken variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowPlaybackAccessToken,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowPlaybackAccessToken? readQuery$FlowPlaybackAccessToken({
    required Variables$Query$FlowPlaybackAccessToken variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowPlaybackAccessToken,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null
        ? null
        : Query$FlowPlaybackAccessToken.fromJson(result);
  }
}

class Query$FlowPlaybackAccessToken$streamPlaybackAccessToken {
  Query$FlowPlaybackAccessToken$streamPlaybackAccessToken({
    this.value,
    this.signature,
    this.authorization,
  });

  factory Query$FlowPlaybackAccessToken$streamPlaybackAccessToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$value = json.containsKey('value') ? json['value'] : null;
    final l$signature = json.containsKey('signature')
        ? json['signature']
        : null;
    final l$authorization = json.containsKey('authorization')
        ? json['authorization']
        : null;
    return Query$FlowPlaybackAccessToken$streamPlaybackAccessToken(
      value: (l$value as String?),
      signature: (l$signature as String?),
      authorization: l$authorization == null
          ? null
          : Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization.fromJson(
              (l$authorization as Map<String, dynamic>),
            ),
    );
  }

  final String? value;

  final String? signature;

  final Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization?
  authorization;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$value = value;
    _resultData['value'] = l$value;
    final l$signature = signature;
    _resultData['signature'] = l$signature;
    final l$authorization = authorization;
    _resultData['authorization'] = l$authorization?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$value = value;
    final l$signature = signature;
    final l$authorization = authorization;
    return Object.hashAll([l$value, l$signature, l$authorization]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPlaybackAccessToken$streamPlaybackAccessToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$value = value;
    final lOther$value = other.value;
    if (l$value != lOther$value) {
      return false;
    }
    final l$signature = signature;
    final lOther$signature = other.signature;
    if (l$signature != lOther$signature) {
      return false;
    }
    final l$authorization = authorization;
    final lOther$authorization = other.authorization;
    if (l$authorization != lOther$authorization) {
      return false;
    }
    return true;
  }
}

class Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization {
  Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization({
    this.isForbidden,
    this.forbiddenReasonCode,
  });

  factory Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$isForbidden = json.containsKey('isForbidden')
        ? json['isForbidden']
        : null;
    final l$forbiddenReasonCode = json.containsKey('forbiddenReasonCode')
        ? json['forbiddenReasonCode']
        : null;
    return Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization(
      isForbidden: (l$isForbidden as bool?),
      forbiddenReasonCode: (l$forbiddenReasonCode as String?),
    );
  }

  final bool? isForbidden;

  final String? forbiddenReasonCode;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$isForbidden = isForbidden;
    _resultData['isForbidden'] = l$isForbidden;
    final l$forbiddenReasonCode = forbiddenReasonCode;
    _resultData['forbiddenReasonCode'] = l$forbiddenReasonCode;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$isForbidden = isForbidden;
    final l$forbiddenReasonCode = forbiddenReasonCode;
    return Object.hashAll([l$isForbidden, l$forbiddenReasonCode]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowPlaybackAccessToken$streamPlaybackAccessToken$authorization ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$isForbidden = isForbidden;
    final lOther$isForbidden = other.isForbidden;
    if (l$isForbidden != lOther$isForbidden) {
      return false;
    }
    final l$forbiddenReasonCode = forbiddenReasonCode;
    final lOther$forbiddenReasonCode = other.forbiddenReasonCode;
    if (l$forbiddenReasonCode != lOther$forbiddenReasonCode) {
      return false;
    }
    return true;
  }
}

class Query$FlowPlaybackAccessToken$videoPlaybackAccessToken {
  Query$FlowPlaybackAccessToken$videoPlaybackAccessToken({
    this.value,
    this.signature,
  });

  factory Query$FlowPlaybackAccessToken$videoPlaybackAccessToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$value = json.containsKey('value') ? json['value'] : null;
    final l$signature = json.containsKey('signature')
        ? json['signature']
        : null;
    return Query$FlowPlaybackAccessToken$videoPlaybackAccessToken(
      value: (l$value as String?),
      signature: (l$signature as String?),
    );
  }

  final String? value;

  final String? signature;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$value = value;
    _resultData['value'] = l$value;
    final l$signature = signature;
    _resultData['signature'] = l$signature;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$value = value;
    final l$signature = signature;
    return Object.hashAll([l$value, l$signature]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowPlaybackAccessToken$videoPlaybackAccessToken ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$value = value;
    final lOther$value = other.value;
    if (l$value != lOther$value) {
      return false;
    }
    final l$signature = signature;
    final lOther$signature = other.signature;
    if (l$signature != lOther$signature) {
      return false;
    }
    return true;
  }
}
