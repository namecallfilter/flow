// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowChannelDetails {
  factory Variables$Query$FlowChannelDetails({
    required String login,
    int? videosFirst,
    String? videosAfter,
  }) => Variables$Query$FlowChannelDetails._({
    r'login': login,
    if (videosFirst != null) r'videosFirst': videosFirst,
    if (videosAfter != null) r'videosAfter': videosAfter,
  });

  Variables$Query$FlowChannelDetails._(this._$data);

  factory Variables$Query$FlowChannelDetails.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$login = data['login'];
    result$data['login'] = (l$login as String);
    if (data.containsKey('videosFirst')) {
      final l$videosFirst = data['videosFirst'];
      result$data['videosFirst'] = (l$videosFirst as int?);
    }
    if (data.containsKey('videosAfter')) {
      final l$videosAfter = data['videosAfter'];
      result$data['videosAfter'] = (l$videosAfter as String?);
    }
    return Variables$Query$FlowChannelDetails._(result$data);
  }

  Map<String, dynamic> _$data;

  String get login => (_$data['login'] as String);

  int? get videosFirst => (_$data['videosFirst'] as int?);

  String? get videosAfter => (_$data['videosAfter'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$login = login;
    result$data['login'] = l$login;
    final l$videosFirst = _$data.containsKey('videosFirst')
        ? videosFirst
        : null;
    result$data['videosFirst'] = l$videosFirst;
    final l$videosAfter = _$data.containsKey('videosAfter')
        ? videosAfter
        : null;
    result$data['videosAfter'] = l$videosAfter;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowChannelDetails ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    final l$videosFirst = videosFirst;
    final lOther$videosFirst = other.videosFirst;
    if (_$data.containsKey('videosFirst') !=
        other._$data.containsKey('videosFirst')) {
      return false;
    }
    if (l$videosFirst != lOther$videosFirst) {
      return false;
    }
    final l$videosAfter = videosAfter;
    final lOther$videosAfter = other.videosAfter;
    if (_$data.containsKey('videosAfter') !=
        other._$data.containsKey('videosAfter')) {
      return false;
    }
    if (l$videosAfter != lOther$videosAfter) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$login = login;
    final l$videosFirst = videosFirst;
    final l$videosAfter = videosAfter;
    return Object.hashAll([
      l$login,
      _$data.containsKey('videosFirst') ? l$videosFirst : const {},
      _$data.containsKey('videosAfter') ? l$videosAfter : const {},
    ]);
  }
}

class Query$FlowChannelDetails {
  Query$FlowChannelDetails({this.user});

  factory Query$FlowChannelDetails.fromJson(Map<String, dynamic> json) {
    final l$user = json.containsKey('user') ? json['user'] : null;
    return Query$FlowChannelDetails(
      user: l$user == null
          ? null
          : Query$FlowChannelDetails$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChannelDetails$user? user;

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
    if (other is! Query$FlowChannelDetails ||
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

const documentNodeQueryFlowChannelDetails = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChannelDetails'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'login')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'videosFirst')),
          type: NamedTypeNode(name: NameNode(value: 'Int'), isNonNull: false),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'videosAfter')),
          type: NamedTypeNode(
            name: NameNode(value: 'Cursor'),
            isNonNull: false,
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
                  name: NameNode(value: 'displayName'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'description'),
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
                  name: NameNode(value: 'followers'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'totalCount'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                    ],
                  ),
                ),
                FieldNode(
                  name: NameNode(value: 'stream'),
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
                        name: NameNode(value: 'createdAt'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'game'),
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
                              name: NameNode(value: 'displayName'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'name'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                          ],
                        ),
                      ),
                      FieldNode(
                        name: NameNode(value: 'previewImageURL'),
                        alias: null,
                        arguments: [
                          ArgumentNode(
                            name: NameNode(value: 'width'),
                            value: IntValueNode(value: '320'),
                          ),
                          ArgumentNode(
                            name: NameNode(value: 'height'),
                            value: IntValueNode(value: '180'),
                          ),
                        ],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'viewersCount'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: null,
                      ),
                      FieldNode(
                        name: NameNode(value: 'broadcaster'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'broadcastSettings'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: SelectionSetNode(
                                selections: [
                                  FieldNode(
                                    name: NameNode(value: 'title'),
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
                  name: NameNode(value: 'videos'),
                  alias: null,
                  arguments: [
                    ArgumentNode(
                      name: NameNode(value: 'first'),
                      value: VariableNode(name: NameNode(value: 'videosFirst')),
                    ),
                    ArgumentNode(
                      name: NameNode(value: 'after'),
                      value: VariableNode(name: NameNode(value: 'videosAfter')),
                    ),
                    ArgumentNode(
                      name: NameNode(value: 'sort'),
                      value: EnumValueNode(name: NameNode(value: 'TIME')),
                    ),
                    ArgumentNode(
                      name: NameNode(value: 'type'),
                      value: EnumValueNode(name: NameNode(value: 'ARCHIVE')),
                    ),
                  ],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'edges'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'cursor'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'node'),
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
                                    name: NameNode(value: 'title'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'game'),
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
                                          name: NameNode(value: 'displayName'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(value: 'name'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'lengthSeconds'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(
                                      value: 'previewThumbnailURL',
                                    ),
                                    alias: null,
                                    arguments: [
                                      ArgumentNode(
                                        name: NameNode(value: 'width'),
                                        value: IntValueNode(value: '320'),
                                      ),
                                      ArgumentNode(
                                        name: NameNode(value: 'height'),
                                        value: IntValueNode(value: '180'),
                                      ),
                                    ],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'publishedAt'),
                                    alias: null,
                                    arguments: [],
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
                                    name: NameNode(value: 'viewCount'),
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
                        name: NameNode(value: 'pageInfo'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'hasNextPage'),
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
Query$FlowChannelDetails _parserFn$Query$FlowChannelDetails(
  Map<String, dynamic> data,
) => Query$FlowChannelDetails.fromJson(data);
typedef OnQueryComplete$Query$FlowChannelDetails =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChannelDetails?);

class Options$Query$FlowChannelDetails
    extends graphql.QueryOptions<Query$FlowChannelDetails> {
  Options$Query$FlowChannelDetails({
    String? operationName,
    required Variables$Query$FlowChannelDetails variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChannelDetails? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChannelDetails? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChannelDetails(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChannelDetails,
         parserFn: _parserFn$Query$FlowChannelDetails,
       );

  final OnQueryComplete$Query$FlowChannelDetails? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChannelDetails
    extends graphql.WatchQueryOptions<Query$FlowChannelDetails> {
  WatchOptions$Query$FlowChannelDetails({
    String? operationName,
    required Variables$Query$FlowChannelDetails variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChannelDetails? typedOptimisticResult,
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
         document: documentNodeQueryFlowChannelDetails,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChannelDetails,
       );
}

class FetchMoreOptions$Query$FlowChannelDetails
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChannelDetails({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChannelDetails variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChannelDetails,
       );
}

extension ClientExtension$Query$FlowChannelDetails on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChannelDetails>>
  query$FlowChannelDetails(Options$Query$FlowChannelDetails options) async =>
      await this.query(options);

  graphql.ObservableQuery<Query$FlowChannelDetails>
  watchQuery$FlowChannelDetails(
    WatchOptions$Query$FlowChannelDetails options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChannelDetails({
    required Query$FlowChannelDetails data,
    required Variables$Query$FlowChannelDetails variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowChannelDetails,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChannelDetails? readQuery$FlowChannelDetails({
    required Variables$Query$FlowChannelDetails variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowChannelDetails,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChannelDetails.fromJson(result);
  }
}

class Query$FlowChannelDetails$user {
  Query$FlowChannelDetails$user({
    this.id,
    this.login,
    this.displayName,
    this.description,
    this.profileImageURL,
    this.followers,
    this.stream,
    this.videos,
  });

  factory Query$FlowChannelDetails$user.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$description = json.containsKey('description')
        ? json['description']
        : null;
    final l$profileImageURL = json.containsKey('profileImageURL')
        ? json['profileImageURL']
        : null;
    final l$followers = json.containsKey('followers')
        ? json['followers']
        : null;
    final l$stream = json.containsKey('stream') ? json['stream'] : null;
    final l$videos = json.containsKey('videos') ? json['videos'] : null;
    return Query$FlowChannelDetails$user(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
      description: (l$description as String?),
      profileImageURL: (l$profileImageURL as String?),
      followers: l$followers == null
          ? null
          : Query$FlowChannelDetails$user$followers.fromJson(
              (l$followers as Map<String, dynamic>),
            ),
      stream: l$stream == null
          ? null
          : Query$FlowChannelDetails$user$stream.fromJson(
              (l$stream as Map<String, dynamic>),
            ),
      videos: l$videos == null
          ? null
          : Query$FlowChannelDetails$user$videos.fromJson(
              (l$videos as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  final String? description;

  final String? profileImageURL;

  final Query$FlowChannelDetails$user$followers? followers;

  final Query$FlowChannelDetails$user$stream? stream;

  final Query$FlowChannelDetails$user$videos? videos;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$description = description;
    _resultData['description'] = l$description;
    final l$profileImageURL = profileImageURL;
    _resultData['profileImageURL'] = l$profileImageURL;
    final l$followers = followers;
    _resultData['followers'] = l$followers?.toJson();
    final l$stream = stream;
    _resultData['stream'] = l$stream?.toJson();
    final l$videos = videos;
    _resultData['videos'] = l$videos?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    final l$description = description;
    final l$profileImageURL = profileImageURL;
    final l$followers = followers;
    final l$stream = stream;
    final l$videos = videos;
    return Object.hashAll([
      l$id,
      l$login,
      l$displayName,
      l$description,
      l$profileImageURL,
      l$followers,
      l$stream,
      l$videos,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user ||
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
    final l$description = description;
    final lOther$description = other.description;
    if (l$description != lOther$description) {
      return false;
    }
    final l$profileImageURL = profileImageURL;
    final lOther$profileImageURL = other.profileImageURL;
    if (l$profileImageURL != lOther$profileImageURL) {
      return false;
    }
    final l$followers = followers;
    final lOther$followers = other.followers;
    if (l$followers != lOther$followers) {
      return false;
    }
    final l$stream = stream;
    final lOther$stream = other.stream;
    if (l$stream != lOther$stream) {
      return false;
    }
    final l$videos = videos;
    final lOther$videos = other.videos;
    if (l$videos != lOther$videos) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$followers {
  Query$FlowChannelDetails$user$followers({this.totalCount});

  factory Query$FlowChannelDetails$user$followers.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$totalCount = json.containsKey('totalCount')
        ? json['totalCount']
        : null;
    return Query$FlowChannelDetails$user$followers(
      totalCount: (l$totalCount as int?),
    );
  }

  final int? totalCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$totalCount = totalCount;
    _resultData['totalCount'] = l$totalCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$totalCount = totalCount;
    return Object.hashAll([l$totalCount]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$followers ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$totalCount = totalCount;
    final lOther$totalCount = other.totalCount;
    if (l$totalCount != lOther$totalCount) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$stream {
  Query$FlowChannelDetails$user$stream({
    this.id,
    this.createdAt,
    this.game,
    this.previewImageURL,
    this.viewersCount,
    this.broadcaster,
  });

  factory Query$FlowChannelDetails$user$stream.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    final l$previewImageURL = json.containsKey('previewImageURL')
        ? json['previewImageURL']
        : null;
    final l$viewersCount = json.containsKey('viewersCount')
        ? json['viewersCount']
        : null;
    final l$broadcaster = json.containsKey('broadcaster')
        ? json['broadcaster']
        : null;
    return Query$FlowChannelDetails$user$stream(
      id: (l$id as String?),
      createdAt: (l$createdAt as String?),
      game: l$game == null
          ? null
          : Query$FlowChannelDetails$user$stream$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      previewImageURL: (l$previewImageURL as String?),
      viewersCount: (l$viewersCount as int?),
      broadcaster: l$broadcaster == null
          ? null
          : Query$FlowChannelDetails$user$stream$broadcaster.fromJson(
              (l$broadcaster as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? createdAt;

  final Query$FlowChannelDetails$user$stream$game? game;

  final String? previewImageURL;

  final int? viewersCount;

  final Query$FlowChannelDetails$user$stream$broadcaster? broadcaster;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    final l$previewImageURL = previewImageURL;
    _resultData['previewImageURL'] = l$previewImageURL;
    final l$viewersCount = viewersCount;
    _resultData['viewersCount'] = l$viewersCount;
    final l$broadcaster = broadcaster;
    _resultData['broadcaster'] = l$broadcaster?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$createdAt = createdAt;
    final l$game = game;
    final l$previewImageURL = previewImageURL;
    final l$viewersCount = viewersCount;
    final l$broadcaster = broadcaster;
    return Object.hashAll([
      l$id,
      l$createdAt,
      l$game,
      l$previewImageURL,
      l$viewersCount,
      l$broadcaster,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$stream ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$createdAt = createdAt;
    final lOther$createdAt = other.createdAt;
    if (l$createdAt != lOther$createdAt) {
      return false;
    }
    final l$game = game;
    final lOther$game = other.game;
    if (l$game != lOther$game) {
      return false;
    }
    final l$previewImageURL = previewImageURL;
    final lOther$previewImageURL = other.previewImageURL;
    if (l$previewImageURL != lOther$previewImageURL) {
      return false;
    }
    final l$viewersCount = viewersCount;
    final lOther$viewersCount = other.viewersCount;
    if (l$viewersCount != lOther$viewersCount) {
      return false;
    }
    final l$broadcaster = broadcaster;
    final lOther$broadcaster = other.broadcaster;
    if (l$broadcaster != lOther$broadcaster) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$stream$game {
  Query$FlowChannelDetails$user$stream$game({
    this.id,
    this.displayName,
    this.name,
  });

  factory Query$FlowChannelDetails$user$stream$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$name = json.containsKey('name') ? json['name'] : null;
    return Query$FlowChannelDetails$user$stream$game(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
      name: (l$name as String?),
    );
  }

  final String? id;

  final String? displayName;

  final String? name;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$name = name;
    _resultData['name'] = l$name;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    final l$name = name;
    return Object.hashAll([l$id, l$displayName, l$name]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$stream$game ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$displayName = displayName;
    final lOther$displayName = other.displayName;
    if (l$displayName != lOther$displayName) {
      return false;
    }
    final l$name = name;
    final lOther$name = other.name;
    if (l$name != lOther$name) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$stream$broadcaster {
  Query$FlowChannelDetails$user$stream$broadcaster({this.broadcastSettings});

  factory Query$FlowChannelDetails$user$stream$broadcaster.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$broadcastSettings = json.containsKey('broadcastSettings')
        ? json['broadcastSettings']
        : null;
    return Query$FlowChannelDetails$user$stream$broadcaster(
      broadcastSettings: l$broadcastSettings == null
          ? null
          : Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings.fromJson(
              (l$broadcastSettings as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings?
  broadcastSettings;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$broadcastSettings = broadcastSettings;
    _resultData['broadcastSettings'] = l$broadcastSettings?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$broadcastSettings = broadcastSettings;
    return Object.hashAll([l$broadcastSettings]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$stream$broadcaster ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$broadcastSettings = broadcastSettings;
    final lOther$broadcastSettings = other.broadcastSettings;
    if (l$broadcastSettings != lOther$broadcastSettings) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings {
  Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings({
    this.title,
  });

  factory Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$title = json.containsKey('title') ? json['title'] : null;
    return Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings(
      title: (l$title as String?),
    );
  }

  final String? title;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$title = title;
    _resultData['title'] = l$title;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$title = title;
    return Object.hashAll([l$title]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowChannelDetails$user$stream$broadcaster$broadcastSettings ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos {
  Query$FlowChannelDetails$user$videos({this.edges, this.pageInfo});

  factory Query$FlowChannelDetails$user$videos.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    final l$pageInfo = json.containsKey('pageInfo') ? json['pageInfo'] : null;
    return Query$FlowChannelDetails$user$videos(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChannelDetails$user$videos$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      pageInfo: l$pageInfo == null
          ? null
          : Query$FlowChannelDetails$user$videos$pageInfo.fromJson(
              (l$pageInfo as Map<String, dynamic>),
            ),
    );
  }

  final List<Query$FlowChannelDetails$user$videos$edges?>? edges;

  final Query$FlowChannelDetails$user$videos$pageInfo? pageInfo;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$edges = edges;
    _resultData['edges'] = l$edges?.map((e) => e?.toJson()).toList();
    final l$pageInfo = pageInfo;
    _resultData['pageInfo'] = l$pageInfo?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$edges = edges;
    final l$pageInfo = pageInfo;
    return Object.hashAll([
      l$edges == null ? null : Object.hashAll(l$edges.map((v) => v)),
      l$pageInfo,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$edges = edges;
    final lOther$edges = other.edges;
    if (l$edges != null && lOther$edges != null) {
      if (l$edges.length != lOther$edges.length) {
        return false;
      }
      for (int i = 0; i < l$edges.length; i++) {
        final l$edges$entry = l$edges[i];
        final lOther$edges$entry = lOther$edges[i];
        if (l$edges$entry != lOther$edges$entry) {
          return false;
        }
      }
    } else if (l$edges != lOther$edges) {
      return false;
    }
    final l$pageInfo = pageInfo;
    final lOther$pageInfo = other.pageInfo;
    if (l$pageInfo != lOther$pageInfo) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$edges {
  Query$FlowChannelDetails$user$videos$edges({this.cursor, this.node});

  factory Query$FlowChannelDetails$user$videos$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$cursor = json.containsKey('cursor') ? json['cursor'] : null;
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowChannelDetails$user$videos$edges(
      cursor: (l$cursor as String?),
      node: l$node == null
          ? null
          : Query$FlowChannelDetails$user$videos$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final String? cursor;

  final Query$FlowChannelDetails$user$videos$edges$node? node;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$cursor = cursor;
    _resultData['cursor'] = l$cursor;
    final l$node = node;
    _resultData['node'] = l$node?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$cursor = cursor;
    final l$node = node;
    return Object.hashAll([l$cursor, l$node]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$edges ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$cursor = cursor;
    final lOther$cursor = other.cursor;
    if (l$cursor != lOther$cursor) {
      return false;
    }
    final l$node = node;
    final lOther$node = other.node;
    if (l$node != lOther$node) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$edges$node {
  Query$FlowChannelDetails$user$videos$edges$node({
    this.id,
    this.title,
    this.game,
    this.lengthSeconds,
    this.previewThumbnailURL,
    this.publishedAt,
    this.createdAt,
    this.viewCount,
  });

  factory Query$FlowChannelDetails$user$videos$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    final l$lengthSeconds = json.containsKey('lengthSeconds')
        ? json['lengthSeconds']
        : null;
    final l$previewThumbnailURL = json.containsKey('previewThumbnailURL')
        ? json['previewThumbnailURL']
        : null;
    final l$publishedAt = json.containsKey('publishedAt')
        ? json['publishedAt']
        : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$viewCount = json.containsKey('viewCount')
        ? json['viewCount']
        : null;
    return Query$FlowChannelDetails$user$videos$edges$node(
      id: (l$id as String?),
      title: (l$title as String?),
      game: l$game == null
          ? null
          : Query$FlowChannelDetails$user$videos$edges$node$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      lengthSeconds: (l$lengthSeconds as int?),
      previewThumbnailURL: (l$previewThumbnailURL as String?),
      publishedAt: (l$publishedAt as String?),
      createdAt: (l$createdAt as String?),
      viewCount: (l$viewCount as int?),
    );
  }

  final String? id;

  final String? title;

  final Query$FlowChannelDetails$user$videos$edges$node$game? game;

  final int? lengthSeconds;

  final String? previewThumbnailURL;

  final String? publishedAt;

  final String? createdAt;

  final int? viewCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$title = title;
    _resultData['title'] = l$title;
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    final l$lengthSeconds = lengthSeconds;
    _resultData['lengthSeconds'] = l$lengthSeconds;
    final l$previewThumbnailURL = previewThumbnailURL;
    _resultData['previewThumbnailURL'] = l$previewThumbnailURL;
    final l$publishedAt = publishedAt;
    _resultData['publishedAt'] = l$publishedAt;
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$viewCount = viewCount;
    _resultData['viewCount'] = l$viewCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$title = title;
    final l$game = game;
    final l$lengthSeconds = lengthSeconds;
    final l$previewThumbnailURL = previewThumbnailURL;
    final l$publishedAt = publishedAt;
    final l$createdAt = createdAt;
    final l$viewCount = viewCount;
    return Object.hashAll([
      l$id,
      l$title,
      l$game,
      l$lengthSeconds,
      l$previewThumbnailURL,
      l$publishedAt,
      l$createdAt,
      l$viewCount,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    final l$game = game;
    final lOther$game = other.game;
    if (l$game != lOther$game) {
      return false;
    }
    final l$lengthSeconds = lengthSeconds;
    final lOther$lengthSeconds = other.lengthSeconds;
    if (l$lengthSeconds != lOther$lengthSeconds) {
      return false;
    }
    final l$previewThumbnailURL = previewThumbnailURL;
    final lOther$previewThumbnailURL = other.previewThumbnailURL;
    if (l$previewThumbnailURL != lOther$previewThumbnailURL) {
      return false;
    }
    final l$publishedAt = publishedAt;
    final lOther$publishedAt = other.publishedAt;
    if (l$publishedAt != lOther$publishedAt) {
      return false;
    }
    final l$createdAt = createdAt;
    final lOther$createdAt = other.createdAt;
    if (l$createdAt != lOther$createdAt) {
      return false;
    }
    final l$viewCount = viewCount;
    final lOther$viewCount = other.viewCount;
    if (l$viewCount != lOther$viewCount) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$edges$node$game {
  Query$FlowChannelDetails$user$videos$edges$node$game({
    this.id,
    this.displayName,
    this.name,
  });

  factory Query$FlowChannelDetails$user$videos$edges$node$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$name = json.containsKey('name') ? json['name'] : null;
    return Query$FlowChannelDetails$user$videos$edges$node$game(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
      name: (l$name as String?),
    );
  }

  final String? id;

  final String? displayName;

  final String? name;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$name = name;
    _resultData['name'] = l$name;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    final l$name = name;
    return Object.hashAll([l$id, l$displayName, l$name]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$edges$node$game ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$displayName = displayName;
    final lOther$displayName = other.displayName;
    if (l$displayName != lOther$displayName) {
      return false;
    }
    final l$name = name;
    final lOther$name = other.name;
    if (l$name != lOther$name) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$edges$node$$Video
    implements Query$FlowChannelDetails$user$videos$edges$node {
  Query$FlowChannelDetails$user$videos$edges$node$$Video({
    this.id,
    this.title,
    this.game,
    this.lengthSeconds,
    this.previewThumbnailURL,
    this.publishedAt,
    this.createdAt,
    this.viewCount,
  });

  factory Query$FlowChannelDetails$user$videos$edges$node$$Video.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    final l$lengthSeconds = json.containsKey('lengthSeconds')
        ? json['lengthSeconds']
        : null;
    final l$previewThumbnailURL = json.containsKey('previewThumbnailURL')
        ? json['previewThumbnailURL']
        : null;
    final l$publishedAt = json.containsKey('publishedAt')
        ? json['publishedAt']
        : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$viewCount = json.containsKey('viewCount')
        ? json['viewCount']
        : null;
    return Query$FlowChannelDetails$user$videos$edges$node$$Video(
      id: (l$id as String?),
      title: (l$title as String?),
      game: l$game == null
          ? null
          : Query$FlowChannelDetails$user$videos$edges$node$$Video$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      lengthSeconds: (l$lengthSeconds as int?),
      previewThumbnailURL: (l$previewThumbnailURL as String?),
      publishedAt: (l$publishedAt as String?),
      createdAt: (l$createdAt as String?),
      viewCount: (l$viewCount as int?),
    );
  }

  final String? id;

  final String? title;

  final Query$FlowChannelDetails$user$videos$edges$node$$Video$game? game;

  final int? lengthSeconds;

  final String? previewThumbnailURL;

  final String? publishedAt;

  final String? createdAt;

  final int? viewCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$title = title;
    _resultData['title'] = l$title;
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    final l$lengthSeconds = lengthSeconds;
    _resultData['lengthSeconds'] = l$lengthSeconds;
    final l$previewThumbnailURL = previewThumbnailURL;
    _resultData['previewThumbnailURL'] = l$previewThumbnailURL;
    final l$publishedAt = publishedAt;
    _resultData['publishedAt'] = l$publishedAt;
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$viewCount = viewCount;
    _resultData['viewCount'] = l$viewCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$title = title;
    final l$game = game;
    final l$lengthSeconds = lengthSeconds;
    final l$previewThumbnailURL = previewThumbnailURL;
    final l$publishedAt = publishedAt;
    final l$createdAt = createdAt;
    final l$viewCount = viewCount;
    return Object.hashAll([
      l$id,
      l$title,
      l$game,
      l$lengthSeconds,
      l$previewThumbnailURL,
      l$publishedAt,
      l$createdAt,
      l$viewCount,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$edges$node$$Video ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$title = title;
    final lOther$title = other.title;
    if (l$title != lOther$title) {
      return false;
    }
    final l$game = game;
    final lOther$game = other.game;
    if (l$game != lOther$game) {
      return false;
    }
    final l$lengthSeconds = lengthSeconds;
    final lOther$lengthSeconds = other.lengthSeconds;
    if (l$lengthSeconds != lOther$lengthSeconds) {
      return false;
    }
    final l$previewThumbnailURL = previewThumbnailURL;
    final lOther$previewThumbnailURL = other.previewThumbnailURL;
    if (l$previewThumbnailURL != lOther$previewThumbnailURL) {
      return false;
    }
    final l$publishedAt = publishedAt;
    final lOther$publishedAt = other.publishedAt;
    if (l$publishedAt != lOther$publishedAt) {
      return false;
    }
    final l$createdAt = createdAt;
    final lOther$createdAt = other.createdAt;
    if (l$createdAt != lOther$createdAt) {
      return false;
    }
    final l$viewCount = viewCount;
    final lOther$viewCount = other.viewCount;
    if (l$viewCount != lOther$viewCount) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$edges$node$$Video$game
    implements Query$FlowChannelDetails$user$videos$edges$node$game {
  Query$FlowChannelDetails$user$videos$edges$node$$Video$game({
    this.id,
    this.displayName,
    this.name,
  });

  factory Query$FlowChannelDetails$user$videos$edges$node$$Video$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    final l$name = json.containsKey('name') ? json['name'] : null;
    return Query$FlowChannelDetails$user$videos$edges$node$$Video$game(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
      name: (l$name as String?),
    );
  }

  final String? id;

  final String? displayName;

  final String? name;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    final l$name = name;
    _resultData['name'] = l$name;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    final l$name = name;
    return Object.hashAll([l$id, l$displayName, l$name]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$edges$node$$Video$game ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$displayName = displayName;
    final lOther$displayName = other.displayName;
    if (l$displayName != lOther$displayName) {
      return false;
    }
    final l$name = name;
    final lOther$name = other.name;
    if (l$name != lOther$name) {
      return false;
    }
    return true;
  }
}

class Query$FlowChannelDetails$user$videos$pageInfo {
  Query$FlowChannelDetails$user$videos$pageInfo({this.hasNextPage});

  factory Query$FlowChannelDetails$user$videos$pageInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$hasNextPage = json.containsKey('hasNextPage')
        ? json['hasNextPage']
        : null;
    return Query$FlowChannelDetails$user$videos$pageInfo(
      hasNextPage: (l$hasNextPage as bool?),
    );
  }

  final bool? hasNextPage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$hasNextPage = hasNextPage;
    _resultData['hasNextPage'] = l$hasNextPage;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$hasNextPage = hasNextPage;
    return Object.hashAll([l$hasNextPage]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChannelDetails$user$videos$pageInfo ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$hasNextPage = hasNextPage;
    final lOther$hasNextPage = other.hasNextPage;
    if (l$hasNextPage != lOther$hasNextPage) {
      return false;
    }
    return true;
  }
}
