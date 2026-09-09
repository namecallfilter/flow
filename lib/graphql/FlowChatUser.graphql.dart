// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Fragment$FlowChatUserBadge {
  Fragment$FlowChatUserBadge({
    this.id,
    this.setID,
    this.version,
    this.title,
    this.imageURL,
  });

  factory Fragment$FlowChatUserBadge.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$imageURL = json.containsKey('imageURL') ? json['imageURL'] : null;
    return Fragment$FlowChatUserBadge(
      id: (l$id as String?),
      setID: (l$setID as String?),
      version: (l$version as String?),
      title: (l$title as String?),
      imageURL: (l$imageURL as String?),
    );
  }

  final String? id;

  final String? setID;

  final String? version;

  final String? title;

  final String? imageURL;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    final l$title = title;
    _resultData['title'] = l$title;
    final l$imageURL = imageURL;
    _resultData['imageURL'] = l$imageURL;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$setID = setID;
    final l$version = version;
    final l$title = title;
    final l$imageURL = imageURL;
    return Object.hashAll([l$id, l$setID, l$version, l$title, l$imageURL]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatUserBadge ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$setID = setID;
    final lOther$setID = other.setID;
    if (l$setID != lOther$setID) {
      return false;
    }
    final l$version = version;
    final lOther$version = other.version;
    if (l$version != lOther$version) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    final l$imageURL = imageURL;
    final lOther$imageURL = other.imageURL;
    if (l$imageURL != lOther$imageURL) {
      return false;
    }
    return true;
  }
}

const fragmentDefinitionFlowChatUserBadge = FragmentDefinitionNode(
  name: NameNode(value: 'FlowChatUserBadge'),
  typeCondition: TypeConditionNode(
    on: NamedTypeNode(name: NameNode(value: 'Badge'), isNonNull: false),
  ),
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
        name: NameNode(value: 'setID'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'version'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'title'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'imageURL'),
        alias: null,
        arguments: [
          ArgumentNode(
            name: NameNode(value: 'size'),
            value: EnumValueNode(name: NameNode(value: 'DOUBLE')),
          ),
        ],
        directives: [],
        selectionSet: null,
      ),
    ],
  ),
);
const documentNodeFragmentFlowChatUserBadge = DocumentNode(
  definitions: [fragmentDefinitionFlowChatUserBadge],
);

extension ClientExtension$Fragment$FlowChatUserBadge on graphql.GraphQLClient {
  void writeFragment$FlowChatUserBadge({
    required Fragment$FlowChatUserBadge data,
    required Map<String, dynamic> idFields,
    bool broadcast = true,
  }) => this.writeFragment(
    graphql.FragmentRequest(
      idFields: idFields,
      fragment: const graphql.Fragment(
        fragmentName: 'FlowChatUserBadge',
        document: documentNodeFragmentFlowChatUserBadge,
      ),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Fragment$FlowChatUserBadge? readFragment$FlowChatUserBadge({
    required Map<String, dynamic> idFields,
    bool optimistic = true,
  }) {
    final result = this.readFragment(
      graphql.FragmentRequest(
        idFields: idFields,
        fragment: const graphql.Fragment(
          fragmentName: 'FlowChatUserBadge',
          document: documentNodeFragmentFlowChatUserBadge,
        ),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Fragment$FlowChatUserBadge.fromJson(result);
  }
}

class Variables$Query$FlowChatUser {
  factory Variables$Query$FlowChatUser({
    String? userID,
    String? lookupLogin,
    required String login,
    String? channelID,
    required String channelLogin,
    required bool withRelationship,
  }) => Variables$Query$FlowChatUser._({
    if (userID != null) r'userID': userID,
    if (lookupLogin != null) r'lookupLogin': lookupLogin,
    r'login': login,
    if (channelID != null) r'channelID': channelID,
    r'channelLogin': channelLogin,
    r'withRelationship': withRelationship,
  });

  Variables$Query$FlowChatUser._(this._$data);

  factory Variables$Query$FlowChatUser.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('userID')) {
      final l$userID = data['userID'];
      result$data['userID'] = (l$userID as String?);
    }
    if (data.containsKey('lookupLogin')) {
      final l$lookupLogin = data['lookupLogin'];
      result$data['lookupLogin'] = (l$lookupLogin as String?);
    }
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    if (data.containsKey('channelID')) {
      final l$channelID = data['channelID'];
      result$data['channelID'] = (l$channelID as String?);
    }
    final l$channelLogin = data['channelLogin'];
    result$data['channelLogin'] = (l$channelLogin as String);
    final l$withRelationship = data['withRelationship'];
    result$data['withRelationship'] = (l$withRelationship as bool);
    return Variables$Query$FlowChatUser._(result$data);
  }

  Map<String, dynamic> _$data;

  String? get userID => (_$data['userID'] as String?);

  String? get lookupLogin => (_$data['lookupLogin'] as String?);

  String get login => (_$data['login'] as String);

  String? get channelID => (_$data['channelID'] as String?);

  String get channelLogin => (_$data['channelLogin'] as String);

  bool get withRelationship => (_$data['withRelationship'] as bool);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$userID = _$data.containsKey('userID') ? userID : null;
    result$data['userID'] = l$userID;
    final l$lookupLogin = _$data.containsKey('lookupLogin')
        ? lookupLogin
        : null;
    result$data['lookupLogin'] = l$lookupLogin;
    final l$login = login;
    result$data['login'] = l$login;
    final l$channelID = _$data.containsKey('channelID') ? channelID : null;
    result$data['channelID'] = l$channelID;
    final l$channelLogin = channelLogin;
    result$data['channelLogin'] = l$channelLogin;
    final l$withRelationship = withRelationship;
    result$data['withRelationship'] = l$withRelationship;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowChatUser ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$userID = userID;
    final lOther$userID = other.userID;
    if (_$data.containsKey('userID') != other._$data.containsKey('userID')) {
      return false;
    }
    if (l$userID != lOther$userID) {
      return false;
    }
    final l$lookupLogin = lookupLogin;
    final lOther$lookupLogin = other.lookupLogin;
    if (_$data.containsKey('lookupLogin') !=
        other._$data.containsKey('lookupLogin')) {
      return false;
    }
    if (l$lookupLogin != lOther$lookupLogin) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (_$data.containsKey('channelID') !=
        other._$data.containsKey('channelID')) {
      return false;
    }
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$channelLogin = channelLogin;
    final lOther$channelLogin = other.channelLogin;
    if (l$channelLogin != lOther$channelLogin) {
      return false;
    }
    final l$withRelationship = withRelationship;
    final lOther$withRelationship = other.withRelationship;
    if (l$withRelationship != lOther$withRelationship) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$userID = userID;
    final l$lookupLogin = lookupLogin;
    final l$login = login;
    final l$channelID = channelID;
    final l$channelLogin = channelLogin;
    final l$withRelationship = withRelationship;
    return Object.hashAll([
      _$data.containsKey('userID') ? l$userID : const {},
      _$data.containsKey('lookupLogin') ? l$lookupLogin : const {},
      l$login,
      _$data.containsKey('channelID') ? l$channelID : const {},
      l$channelLogin,
      l$withRelationship,
    ]);
  }
}

class Query$FlowChatUser {
  Query$FlowChatUser({this.targetUser, this.channelViewer});

  factory Query$FlowChatUser.fromJson(Map<String, dynamic> json) {
    final l$targetUser = json.containsKey('targetUser')
        ? json['targetUser']
        : null;
    final l$channelViewer = json.containsKey('channelViewer')
        ? json['channelViewer']
        : null;
    return Query$FlowChatUser(
      targetUser: l$targetUser == null
          ? null
          : Query$FlowChatUser$targetUser.fromJson(
              (l$targetUser as Map<String, dynamic>),
            ),
      channelViewer: l$channelViewer == null
          ? null
          : Query$FlowChatUser$channelViewer.fromJson(
              (l$channelViewer as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatUser$targetUser? targetUser;

  final Query$FlowChatUser$channelViewer? channelViewer;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$targetUser = targetUser;
    _resultData['targetUser'] = l$targetUser?.toJson();
    final l$channelViewer = channelViewer;
    _resultData['channelViewer'] = l$channelViewer?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$targetUser = targetUser;
    final l$channelViewer = channelViewer;
    return Object.hashAll([l$targetUser, l$channelViewer]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatUser || runtimeType != other.runtimeType) {
      return false;
    }
    final l$targetUser = targetUser;
    final lOther$targetUser = other.targetUser;
    if (l$targetUser != lOther$targetUser) {
      return false;
    }
    final l$channelViewer = channelViewer;
    final lOther$channelViewer = other.channelViewer;
    if (l$channelViewer != lOther$channelViewer) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowChatUser = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChatUser'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'userID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: false),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'lookupLogin')),
          type: NamedTypeNode(
            name: NameNode(value: 'String'),
            isNonNull: false,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'login')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'channelID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: false),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'channelLogin')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'withRelationship')),
          type: NamedTypeNode(
            name: NameNode(value: 'Boolean'),
            isNonNull: true,
          ),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'user'),
            alias: NameNode(value: 'targetUser'),
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'userID')),
              ),
              ArgumentNode(
                name: NameNode(value: 'login'),
                value: VariableNode(name: NameNode(value: 'lookupLogin')),
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
                  name: NameNode(value: 'profileImageURL'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'width'),
                      value: IntValueNode(value: '300'),
                    ),
                  ],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'createdAt'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'chatColor'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'displayBadges'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'channelID'),
                      value: VariableNode(name: NameNode(value: 'channelID')),
                    ),
                  ],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FragmentSpreadNode(
                        name: NameNode(value: 'FlowChatUserBadge'),
                        directives: [],
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'relationship'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'targetUserID'),
                      value: VariableNode(name: NameNode(value: 'channelID')),
                    ),
                  ],
                  directives: [
                    DirectiveNode(
                      name: NameNode(value: 'include'),
                      arguments: [
                        ArgumentNode(
                          name: NameNode(value: 'if'),
                          value: VariableNode(
                            name: NameNode(value: 'withRelationship'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'subscriptionTenure'),
                        alias: NameNode(value: 'cumulativeTenure'),
                        arguments: [
                          ArgumentNode(
                            name: NameNode(value: 'tenureMethod'),
                            value: EnumValueNode(
                              name: NameNode(value: 'CUMULATIVE'),
                            ),
                          ),
                        ],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'months'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                          ],
                        ),
                      ),
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
                            FieldNode(
                              name: NameNode(value: 'tier'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'purchasedWithPrime'),
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
          FieldNode(
            name: NameNode(value: 'channelViewer'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'userLogin'),
                value: VariableNode(name: NameNode(value: 'login')),
              ),
              ArgumentNode(
                name: NameNode(value: 'channelLogin'),
                value: VariableNode(name: NameNode(value: 'channelLogin')),
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
                  name: NameNode(value: 'earnedBadges'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FragmentSpreadNode(
                        name: NameNode(value: 'FlowChatUserBadge'),
                        directives: [],
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
    fragmentDefinitionFlowChatUserBadge,
  ],
);
Query$FlowChatUser _parserFn$Query$FlowChatUser(Map<String, dynamic> data) =>
    Query$FlowChatUser.fromJson(data);
typedef OnQueryComplete$Query$FlowChatUser =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChatUser?);

class Options$Query$FlowChatUser
    extends graphql.QueryOptions<Query$FlowChatUser> {
  Options$Query$FlowChatUser({
    String? operationName,
    required Variables$Query$FlowChatUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatUser? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChatUser? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChatUser(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChatUser,
         parserFn: _parserFn$Query$FlowChatUser,
       );

  final OnQueryComplete$Query$FlowChatUser? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChatUser
    extends graphql.WatchQueryOptions<Query$FlowChatUser> {
  WatchOptions$Query$FlowChatUser({
    String? operationName,
    required Variables$Query$FlowChatUser variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatUser? typedOptimisticResult,
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
         document: documentNodeQueryFlowChatUser,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChatUser,
       );
}

class FetchMoreOptions$Query$FlowChatUser extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChatUser({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChatUser variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChatUser,
       );
}

extension ClientExtension$Query$FlowChatUser on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChatUser>> query$FlowChatUser(
    Options$Query$FlowChatUser options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChatUser> watchQuery$FlowChatUser(
    WatchOptions$Query$FlowChatUser options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChatUser({
    required Query$FlowChatUser data,
    required Variables$Query$FlowChatUser variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowChatUser),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChatUser? readQuery$FlowChatUser({
    required Variables$Query$FlowChatUser variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(document: documentNodeQueryFlowChatUser),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChatUser.fromJson(result);
  }
}

class Query$FlowChatUser$targetUser {
  Query$FlowChatUser$targetUser({
    this.id,
    this.login,
    this.displayName,
    this.profileImageURL,
    this.createdAt,
    this.chatColor,
    this.displayBadges,
    this.relationship,
  });

  factory Query$FlowChatUser$targetUser.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$profileImageURL = json.containsKey('profileImageURL')
        ? json['profileImageURL']
        : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$chatColor = json.containsKey('chatColor')
        ? json['chatColor']
        : null;
    final l$displayBadges = json.containsKey('displayBadges')
        ? json['displayBadges']
        : null;
    final l$relationship = json.containsKey('relationship')
        ? json['relationship']
        : null;
    return Query$FlowChatUser$targetUser(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
      profileImageURL: (l$profileImageURL as String?),
      createdAt: (l$createdAt as String?),
      chatColor: (l$chatColor as String?),
      displayBadges: (l$displayBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Fragment$FlowChatUserBadge.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      relationship: l$relationship == null
          ? null
          : Query$FlowChatUser$targetUser$relationship.fromJson(
              (l$relationship as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  final String? profileImageURL;

  final String? createdAt;

  final String? chatColor;

  final List<Fragment$FlowChatUserBadge?>? displayBadges;

  final Query$FlowChatUser$targetUser$relationship? relationship;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$profileImageURL = profileImageURL;
    _resultData['profileImageURL'] = l$profileImageURL;
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$chatColor = chatColor;
    _resultData['chatColor'] = l$chatColor;
    final l$displayBadges = displayBadges;
    _resultData['displayBadges'] = l$displayBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$relationship = relationship;
    _resultData['relationship'] = l$relationship?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    final l$profileImageURL = profileImageURL;
    final l$createdAt = createdAt;
    final l$chatColor = chatColor;
    final l$displayBadges = displayBadges;
    final l$relationship = relationship;
    return Object.hashAll([
      l$id,
      l$login,
      l$displayName,
      l$profileImageURL,
      l$createdAt,
      l$chatColor,
      l$displayBadges == null
          ? null
          : Object.hashAll(l$displayBadges.map((v) => v)),
      l$relationship,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatUser$targetUser ||
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
    final l$profileImageURL = profileImageURL;
    final lOther$profileImageURL = other.profileImageURL;
    if (l$profileImageURL != lOther$profileImageURL) {
      return false;
    }
    final l$createdAt = createdAt;
    final lOther$createdAt = other.createdAt;
    if (l$createdAt != lOther$createdAt) {
      return false;
    }
    final l$chatColor = chatColor;
    final lOther$chatColor = other.chatColor;
    if (l$chatColor != lOther$chatColor) {
      return false;
    }
    final l$displayBadges = displayBadges;
    final lOther$displayBadges = other.displayBadges;
    if (l$displayBadges != null && lOther$displayBadges != null) {
      if (l$displayBadges.length != lOther$displayBadges.length) {
        return false;
      }
      for (int i = 0; i < l$displayBadges.length; i++) {
        final l$displayBadges$entry = l$displayBadges[i];
        final lOther$displayBadges$entry = lOther$displayBadges[i];
        if (l$displayBadges$entry != lOther$displayBadges$entry) {
          return false;
        }
      }
    } else if (l$displayBadges != lOther$displayBadges) {
      return false;
    }
    final l$relationship = relationship;
    final lOther$relationship = other.relationship;
    if (l$relationship != lOther$relationship) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatUser$targetUser$relationship {
  Query$FlowChatUser$targetUser$relationship({
    this.cumulativeTenure,
    this.subscriptionBenefit,
  });

  factory Query$FlowChatUser$targetUser$relationship.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cumulativeTenure = json.containsKey('cumulativeTenure')
        ? json['cumulativeTenure']
        : null;
    final l$subscriptionBenefit = json.containsKey('subscriptionBenefit')
        ? json['subscriptionBenefit']
        : null;
    return Query$FlowChatUser$targetUser$relationship(
      cumulativeTenure: l$cumulativeTenure == null
          ? null
          : Query$FlowChatUser$targetUser$relationship$cumulativeTenure.fromJson(
              (l$cumulativeTenure as Map<String, dynamic>),
            ),
      subscriptionBenefit: l$subscriptionBenefit == null
          ? null
          : Query$FlowChatUser$targetUser$relationship$subscriptionBenefit.fromJson(
              (l$subscriptionBenefit as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatUser$targetUser$relationship$cumulativeTenure?
  cumulativeTenure;

  final Query$FlowChatUser$targetUser$relationship$subscriptionBenefit?
  subscriptionBenefit;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$cumulativeTenure = cumulativeTenure;
    _resultData['cumulativeTenure'] = l$cumulativeTenure?.toJson();
    final l$subscriptionBenefit = subscriptionBenefit;
    _resultData['subscriptionBenefit'] = l$subscriptionBenefit?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$cumulativeTenure = cumulativeTenure;
    final l$subscriptionBenefit = subscriptionBenefit;
    return Object.hashAll([l$cumulativeTenure, l$subscriptionBenefit]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatUser$targetUser$relationship ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$cumulativeTenure = cumulativeTenure;
    final lOther$cumulativeTenure = other.cumulativeTenure;
    if (l$cumulativeTenure != lOther$cumulativeTenure) {
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

class Query$FlowChatUser$targetUser$relationship$cumulativeTenure {
  Query$FlowChatUser$targetUser$relationship$cumulativeTenure({this.months});

  factory Query$FlowChatUser$targetUser$relationship$cumulativeTenure.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$months = json.containsKey('months') ? json['months'] : null;
    return Query$FlowChatUser$targetUser$relationship$cumulativeTenure(
      months: (l$months as int?),
    );
  }

  final int? months;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$months = months;
    _resultData['months'] = l$months;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$months = months;
    return Object.hashAll([l$months]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatUser$targetUser$relationship$cumulativeTenure ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$months = months;
    final lOther$months = other.months;
    if (l$months != lOther$months) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatUser$targetUser$relationship$subscriptionBenefit {
  Query$FlowChatUser$targetUser$relationship$subscriptionBenefit({
    this.id,
    this.tier,
    this.purchasedWithPrime,
  });

  factory Query$FlowChatUser$targetUser$relationship$subscriptionBenefit.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$tier = json.containsKey('tier') ? json['tier'] : null;
    final l$purchasedWithPrime = json.containsKey('purchasedWithPrime')
        ? json['purchasedWithPrime']
        : null;
    return Query$FlowChatUser$targetUser$relationship$subscriptionBenefit(
      id: (l$id as String?),
      tier: (l$tier as String?),
      purchasedWithPrime: (l$purchasedWithPrime as bool?),
    );
  }

  final String? id;

  final String? tier;

  final bool? purchasedWithPrime;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$tier = tier;
    _resultData['tier'] = l$tier;
    final l$purchasedWithPrime = purchasedWithPrime;
    _resultData['purchasedWithPrime'] = l$purchasedWithPrime;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$tier = tier;
    final l$purchasedWithPrime = purchasedWithPrime;
    return Object.hashAll([l$id, l$tier, l$purchasedWithPrime]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowChatUser$targetUser$relationship$subscriptionBenefit ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$tier = tier;
    final lOther$tier = other.tier;
    if (l$tier != lOther$tier) {
      return false;
    }
    final l$purchasedWithPrime = purchasedWithPrime;
    final lOther$purchasedWithPrime = other.purchasedWithPrime;
    if (l$purchasedWithPrime != lOther$purchasedWithPrime) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatUser$channelViewer {
  Query$FlowChatUser$channelViewer({this.id, this.earnedBadges});

  factory Query$FlowChatUser$channelViewer.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$earnedBadges = json.containsKey('earnedBadges')
        ? json['earnedBadges']
        : null;
    return Query$FlowChatUser$channelViewer(
      id: (l$id as String?),
      earnedBadges: (l$earnedBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Fragment$FlowChatUserBadge.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? id;

  final List<Fragment$FlowChatUserBadge?>? earnedBadges;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$earnedBadges = earnedBadges;
    _resultData['earnedBadges'] = l$earnedBadges
        ?.map((e) => e?.toJson())
        .toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$earnedBadges = earnedBadges;
    return Object.hashAll([
      l$id,
      l$earnedBadges == null
          ? null
          : Object.hashAll(l$earnedBadges.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatUser$channelViewer ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$earnedBadges = earnedBadges;
    final lOther$earnedBadges = other.earnedBadges;
    if (l$earnedBadges != null && lOther$earnedBadges != null) {
      if (l$earnedBadges.length != lOther$earnedBadges.length) {
        return false;
      }
      for (int i = 0; i < l$earnedBadges.length; i++) {
        final l$earnedBadges$entry = l$earnedBadges[i];
        final lOther$earnedBadges$entry = lOther$earnedBadges[i];
        if (l$earnedBadges$entry != lOther$earnedBadges$entry) {
          return false;
        }
      }
    } else if (l$earnedBadges != lOther$earnedBadges) {
      return false;
    }
    return true;
  }
}
