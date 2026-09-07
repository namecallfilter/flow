// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowSearchChannels {
  factory Variables$Query$FlowSearchChannels({
    required String queryFragment,
    String? requestID,
    bool? withOfflineChannelContent,
  }) => Variables$Query$FlowSearchChannels._({
    r'queryFragment': queryFragment,
    if (requestID != null) r'requestID': requestID,
    if (withOfflineChannelContent != null)
      r'withOfflineChannelContent': withOfflineChannelContent,
  });

  Variables$Query$FlowSearchChannels._(this._$data);

  factory Variables$Query$FlowSearchChannels.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$queryFragment = data['queryFragment'];
    result$data['queryFragment'] = (l$queryFragment as String);
    if (data.containsKey('requestID')) {
      final l$requestID = data['requestID'];
      result$data['requestID'] = (l$requestID as String?);
    }
    if (data.containsKey('withOfflineChannelContent')) {
      final l$withOfflineChannelContent = data['withOfflineChannelContent'];
      result$data['withOfflineChannelContent'] =
          (l$withOfflineChannelContent as bool?);
    }
    return Variables$Query$FlowSearchChannels._(result$data);
  }

  Map<String, dynamic> _$data;

  String get queryFragment => (_$data['queryFragment'] as String);

  String? get requestID => (_$data['requestID'] as String?);

  bool? get withOfflineChannelContent =>
      (_$data['withOfflineChannelContent'] as bool?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$queryFragment = queryFragment;
    result$data['queryFragment'] = l$queryFragment;
    final l$requestID = _$data.containsKey('requestID') ? requestID : null;
    result$data['requestID'] = l$requestID;
    final l$withOfflineChannelContent =
        _$data.containsKey('withOfflineChannelContent')
        ? withOfflineChannelContent
        : null;
    result$data['withOfflineChannelContent'] = l$withOfflineChannelContent;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowSearchChannels ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$queryFragment = queryFragment;
    final lOther$queryFragment = other.queryFragment;
    if (l$queryFragment != lOther$queryFragment) {
      return false;
    }
    final l$requestID = requestID;
    final lOther$requestID = other.requestID;
    if (_$data.containsKey('requestID') !=
        other._$data.containsKey('requestID')) {
      return false;
    }
    if (l$requestID != lOther$requestID) {
      return false;
    }
    final l$withOfflineChannelContent = withOfflineChannelContent;
    final lOther$withOfflineChannelContent = other.withOfflineChannelContent;
    if (_$data.containsKey('withOfflineChannelContent') !=
        other._$data.containsKey('withOfflineChannelContent')) {
      return false;
    }
    if (l$withOfflineChannelContent != lOther$withOfflineChannelContent) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$queryFragment = queryFragment;
    final l$requestID = requestID;
    final l$withOfflineChannelContent = withOfflineChannelContent;
    return Object.hashAll([
      l$queryFragment,
      _$data.containsKey('requestID') ? l$requestID : const {},
      _$data.containsKey('withOfflineChannelContent')
          ? l$withOfflineChannelContent
          : const {},
    ]);
  }
}

class Query$FlowSearchChannels {
  Query$FlowSearchChannels({this.searchSuggestions});

  factory Query$FlowSearchChannels.fromJson(Map<String, dynamic> json) {
    final l$searchSuggestions = json.containsKey('searchSuggestions')
        ? json['searchSuggestions']
        : null;
    return Query$FlowSearchChannels(
      searchSuggestions: l$searchSuggestions == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions.fromJson(
              (l$searchSuggestions as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowSearchChannels$searchSuggestions? searchSuggestions;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$searchSuggestions = searchSuggestions;
    _resultData['searchSuggestions'] = l$searchSuggestions?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$searchSuggestions = searchSuggestions;
    return Object.hashAll([l$searchSuggestions]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchChannels ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$searchSuggestions = searchSuggestions;
    final lOther$searchSuggestions = other.searchSuggestions;
    if (l$searchSuggestions != lOther$searchSuggestions) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowSearchChannels = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowSearchChannels'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'queryFragment')),
          type: NamedTypeNode(name: NameNode(value: 'String'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'requestID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: false),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
        VariableDefinitionNode(
          variable: VariableNode(
            name: NameNode(value: 'withOfflineChannelContent'),
          ),
          type: NamedTypeNode(
            name: NameNode(value: 'Boolean'),
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
            name: NameNode(value: 'searchSuggestions'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'queryFragment'),
                value: VariableNode(name: NameNode(value: 'queryFragment')),
              ),
              ArgumentNode(
                name: NameNode(value: 'requestID'),
                value: VariableNode(name: NameNode(value: 'requestID')),
              ),
              ArgumentNode(
                name: NameNode(value: 'withOfflineChannelContent'),
                value: VariableNode(
                  name: NameNode(value: 'withOfflineChannelContent'),
                ),
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
                        name: NameNode(value: 'node'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'content'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: SelectionSetNode(
                                selections: [
                                  FieldNode(
                                    name: NameNode(value: '__typename'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  InlineFragmentNode(
                                    typeCondition: TypeConditionNode(
                                      on: NamedTypeNode(
                                        name: NameNode(
                                          value: 'SearchSuggestionChannel',
                                        ),
                                        isNonNull: false,
                                      ),
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
                                          name: NameNode(value: 'isLive'),
                                          alias: null,
                                          arguments: [],
                                          directives: [],
                                          selectionSet: null,
                                        ),
                                        FieldNode(
                                          name: NameNode(value: 'isVerified'),
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
                                          name: NameNode(
                                            value: 'profileImageURL',
                                          ),
                                          alias: null,
                                          arguments: [
                                            ArgumentNode(
                                              name: NameNode(value: 'width'),
                                              value: IntValueNode(value: '50'),
                                            ),
                                          ],
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
                                              FieldNode(
                                                name: NameNode(
                                                  value: 'isPartner',
                                                ),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: null,
                                              ),
                                              FieldNode(
                                                name: NameNode(value: 'stream'),
                                                alias: null,
                                                arguments: [],
                                                directives: [],
                                                selectionSet: SelectionSetNode(
                                                  selections: [
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'id',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'viewersCount',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'createdAt',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: null,
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'game',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet:
                                                          SelectionSetNode(
                                                            selections: [
                                                              FieldNode(
                                                                name: NameNode(
                                                                  value: 'id',
                                                                ),
                                                                alias: null,
                                                                arguments: [],
                                                                directives: [],
                                                                selectionSet:
                                                                    null,
                                                              ),
                                                              FieldNode(
                                                                name: NameNode(
                                                                  value:
                                                                      'displayName',
                                                                ),
                                                                alias: null,
                                                                arguments: [],
                                                                directives: [],
                                                                selectionSet:
                                                                    null,
                                                              ),
                                                            ],
                                                          ),
                                                    ),
                                                    FieldNode(
                                                      name: NameNode(
                                                        value: 'broadcaster',
                                                      ),
                                                      alias: null,
                                                      arguments: [],
                                                      directives: [],
                                                      selectionSet: SelectionSetNode(
                                                        selections: [
                                                          FieldNode(
                                                            name: NameNode(
                                                              value: 'id',
                                                            ),
                                                            alias: null,
                                                            arguments: [],
                                                            directives: [],
                                                            selectionSet: null,
                                                          ),
                                                          FieldNode(
                                                            name: NameNode(
                                                              value:
                                                                  'broadcastSettings',
                                                            ),
                                                            alias: null,
                                                            arguments: [],
                                                            directives: [],
                                                            selectionSet: SelectionSetNode(
                                                              selections: [
                                                                FieldNode(
                                                                  name: NameNode(
                                                                    value: 'id',
                                                                  ),
                                                                  alias: null,
                                                                  arguments: [],
                                                                  directives:
                                                                      [],
                                                                  selectionSet:
                                                                      null,
                                                                ),
                                                                FieldNode(
                                                                  name: NameNode(
                                                                    value:
                                                                        'title',
                                                                  ),
                                                                  alias: null,
                                                                  arguments: [],
                                                                  directives:
                                                                      [],
                                                                  selectionSet:
                                                                      null,
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
                            FieldNode(
                              name: NameNode(value: 'id'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: null,
                            ),
                            FieldNode(
                              name: NameNode(value: 'text'),
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
Query$FlowSearchChannels _parserFn$Query$FlowSearchChannels(
  Map<String, dynamic> data,
) => Query$FlowSearchChannels.fromJson(data);
typedef OnQueryComplete$Query$FlowSearchChannels =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowSearchChannels?);

class Options$Query$FlowSearchChannels
    extends graphql.QueryOptions<Query$FlowSearchChannels> {
  Options$Query$FlowSearchChannels({
    String? operationName,
    required Variables$Query$FlowSearchChannels variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowSearchChannels? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowSearchChannels? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowSearchChannels(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowSearchChannels,
         parserFn: _parserFn$Query$FlowSearchChannels,
       );

  final OnQueryComplete$Query$FlowSearchChannels? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowSearchChannels
    extends graphql.WatchQueryOptions<Query$FlowSearchChannels> {
  WatchOptions$Query$FlowSearchChannels({
    String? operationName,
    required Variables$Query$FlowSearchChannels variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowSearchChannels? typedOptimisticResult,
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
         document: documentNodeQueryFlowSearchChannels,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowSearchChannels,
       );
}

class FetchMoreOptions$Query$FlowSearchChannels
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowSearchChannels({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowSearchChannels variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowSearchChannels,
       );
}

extension ClientExtension$Query$FlowSearchChannels on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowSearchChannels>>
  query$FlowSearchChannels(Options$Query$FlowSearchChannels options) async =>
      await this.query(options);

  graphql.ObservableQuery<Query$FlowSearchChannels>
  watchQuery$FlowSearchChannels(
    WatchOptions$Query$FlowSearchChannels options,
  ) => this.watchQuery(options);

  void writeQuery$FlowSearchChannels({
    required Query$FlowSearchChannels data,
    required Variables$Query$FlowSearchChannels variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowSearchChannels,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowSearchChannels? readQuery$FlowSearchChannels({
    required Variables$Query$FlowSearchChannels variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowSearchChannels,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowSearchChannels.fromJson(result);
  }
}

class Query$FlowSearchChannels$searchSuggestions {
  Query$FlowSearchChannels$searchSuggestions({this.edges});

  factory Query$FlowSearchChannels$searchSuggestions.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$edges = json.containsKey('edges') ? json['edges'] : null;
    return Query$FlowSearchChannels$searchSuggestions(
      edges: (l$edges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowSearchChannels$searchSuggestions$edges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<Query$FlowSearchChannels$searchSuggestions$edges?>? edges;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$edges = edges;
    _resultData['edges'] = l$edges?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$edges = edges;
    return Object.hashAll([
      l$edges == null ? null : Object.hashAll(l$edges.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchChannels$searchSuggestions ||
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
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges {
  Query$FlowSearchChannels$searchSuggestions$edges({this.node});

  factory Query$FlowSearchChannels$searchSuggestions$edges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$node = json.containsKey('node') ? json['node'] : null;
    return Query$FlowSearchChannels$searchSuggestions$edges(
      node: l$node == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node.fromJson(
              (l$node as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowSearchChannels$searchSuggestions$edges$node? node;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$node = node;
    _resultData['node'] = l$node?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$node = node;
    return Object.hashAll([l$node]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchChannels$searchSuggestions$edges ||
        runtimeType != other.runtimeType) {
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

class Query$FlowSearchChannels$searchSuggestions$edges$node {
  Query$FlowSearchChannels$searchSuggestions$edges$node({
    this.content,
    this.id,
    this.text,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$text = json.containsKey('text') ? json['text'] : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node(
      content: l$content == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      id: (l$id as String?),
      text: (l$text as String?),
    );
  }

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content? content;

  final String? id;

  final String? text;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$id = id;
    _resultData['id'] = l$id;
    final l$text = text;
    _resultData['text'] = l$text;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$content = content;
    final l$id = id;
    final l$text = text;
    return Object.hashAll([l$content, l$id, l$text]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowSearchChannels$searchSuggestions$edges$node ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content({
    required this.$__typename,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "SearchSuggestionChannel":
        return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel.fromJson(
          json,
        );

      case "SearchSuggestionCategory":
        return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory.fromJson(
          json,
        );

      case "SearchSuggestionCollection":
        return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Query$FlowSearchChannels$searchSuggestions$edges$node$content(
          $__typename: (l$$__typename as String),
        );
    }
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

extension UtilityExtension$Query$FlowSearchChannels$searchSuggestions$edges$node$content
    on Query$FlowSearchChannels$searchSuggestions$edges$node$content {
  _T when<_T>({
    required _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel,
    )
    searchSuggestionChannel,
    required _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory,
    )
    searchSuggestionCategory,
    required _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection,
    )
    searchSuggestionCollection,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "SearchSuggestionChannel":
        return searchSuggestionChannel(
          this
              as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel,
        );

      case "SearchSuggestionCategory":
        return searchSuggestionCategory(
          this
              as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory,
        );

      case "SearchSuggestionCollection":
        return searchSuggestionCollection(
          this
              as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel,
    )?
    searchSuggestionChannel,
    _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory,
    )?
    searchSuggestionCategory,
    _T Function(
      Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection,
    )?
    searchSuggestionCollection,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "SearchSuggestionChannel":
        if (searchSuggestionChannel != null) {
          return searchSuggestionChannel(
            this
                as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel,
          );
        } else {
          return orElse();
        }

      case "SearchSuggestionCategory":
        if (searchSuggestionCategory != null) {
          return searchSuggestionCategory(
            this
                as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory,
          );
        } else {
          return orElse();
        }

      case "SearchSuggestionCollection":
        if (searchSuggestionCollection != null) {
          return searchSuggestionCollection(
            this
                as Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel
    implements Query$FlowSearchChannels$searchSuggestions$edges$node$content {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel({
    this.id,
    this.isLive,
    this.isVerified,
    this.login,
    this.profileImageURL,
    this.user,
    this.$__typename = 'SearchSuggestionChannel',
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$isLive = json.containsKey('isLive') ? json['isLive'] : null;
    final l$isVerified = json.containsKey('isVerified')
        ? json['isVerified']
        : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$profileImageURL = json.containsKey('profileImageURL')
        ? json['profileImageURL']
        : null;
    final l$user = json.containsKey('user') ? json['user'] : null;
    final l$$__typename = json['__typename'];
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel(
      id: (l$id as String?),
      isLive: (l$isLive as bool?),
      isVerified: (l$isVerified as bool?),
      login: (l$login as String?),
      profileImageURL: (l$profileImageURL as String?),
      user: l$user == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user.fromJson(
              (l$user as Map<String, dynamic>),
            ),
      $__typename: (l$$__typename as String),
    );
  }

  final String? id;

  final bool? isLive;

  final bool? isVerified;

  final String? login;

  final String? profileImageURL;

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user?
  user;

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$isLive = isLive;
    _resultData['isLive'] = l$isLive;
    final l$isVerified = isVerified;
    _resultData['isVerified'] = l$isVerified;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$profileImageURL = profileImageURL;
    _resultData['profileImageURL'] = l$profileImageURL;
    final l$user = user;
    _resultData['user'] = l$user?.toJson();
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$isLive = isLive;
    final l$isVerified = isVerified;
    final l$login = login;
    final l$profileImageURL = profileImageURL;
    final l$user = user;
    final l$$__typename = $__typename;
    return Object.hashAll([
      l$id,
      l$isLive,
      l$isVerified,
      l$login,
      l$profileImageURL,
      l$user,
      l$$__typename,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$isLive = isLive;
    final lOther$isLive = other.isLive;
    if (l$isLive != lOther$isLive) {
      return false;
    }
    final l$isVerified = isVerified;
    final lOther$isVerified = other.isVerified;
    if (l$isVerified != lOther$isVerified) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    final l$profileImageURL = profileImageURL;
    final lOther$profileImageURL = other.profileImageURL;
    if (l$profileImageURL != lOther$profileImageURL) {
      return false;
    }
    final l$user = user;
    final lOther$user = other.user;
    if (l$user != lOther$user) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user({
    this.id,
    this.isPartner,
    this.stream,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$isPartner = json.containsKey('isPartner')
        ? json['isPartner']
        : null;
    final l$stream = json.containsKey('stream') ? json['stream'] : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user(
      id: (l$id as String?),
      isPartner: (l$isPartner as bool?),
      stream: l$stream == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream.fromJson(
              (l$stream as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final bool? isPartner;

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream?
  stream;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$isPartner = isPartner;
    _resultData['isPartner'] = l$isPartner;
    final l$stream = stream;
    _resultData['stream'] = l$stream?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$isPartner = isPartner;
    final l$stream = stream;
    return Object.hashAll([l$id, l$isPartner, l$stream]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$isPartner = isPartner;
    final lOther$isPartner = other.isPartner;
    if (l$isPartner != lOther$isPartner) {
      return false;
    }
    final l$stream = stream;
    final lOther$stream = other.stream;
    if (l$stream != lOther$stream) {
      return false;
    }
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream({
    this.id,
    this.viewersCount,
    this.createdAt,
    this.game,
    this.broadcaster,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$viewersCount = json.containsKey('viewersCount')
        ? json['viewersCount']
        : null;
    final l$createdAt = json.containsKey('createdAt')
        ? json['createdAt']
        : null;
    final l$game = json.containsKey('game') ? json['game'] : null;
    final l$broadcaster = json.containsKey('broadcaster')
        ? json['broadcaster']
        : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream(
      id: (l$id as String?),
      viewersCount: (l$viewersCount as int?),
      createdAt: (l$createdAt as String?),
      game: l$game == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game.fromJson(
              (l$game as Map<String, dynamic>),
            ),
      broadcaster: l$broadcaster == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster.fromJson(
              (l$broadcaster as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final int? viewersCount;

  final String? createdAt;

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game?
  game;

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster?
  broadcaster;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$viewersCount = viewersCount;
    _resultData['viewersCount'] = l$viewersCount;
    final l$createdAt = createdAt;
    _resultData['createdAt'] = l$createdAt;
    final l$game = game;
    _resultData['game'] = l$game?.toJson();
    final l$broadcaster = broadcaster;
    _resultData['broadcaster'] = l$broadcaster?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$viewersCount = viewersCount;
    final l$createdAt = createdAt;
    final l$game = game;
    final l$broadcaster = broadcaster;
    return Object.hashAll([
      l$id,
      l$viewersCount,
      l$createdAt,
      l$game,
      l$broadcaster,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$viewersCount = viewersCount;
    final lOther$viewersCount = other.viewersCount;
    if (l$viewersCount != lOther$viewersCount) {
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
    final l$broadcaster = broadcaster;
    final lOther$broadcaster = other.broadcaster;
    if (l$broadcaster != lOther$broadcaster) {
      return false;
    }
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game({
    this.id,
    this.displayName,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game(
      id: (l$id as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$game ||
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
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster({
    this.id,
    this.broadcastSettings,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$broadcastSettings = json.containsKey('broadcastSettings')
        ? json['broadcastSettings']
        : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster(
      id: (l$id as String?),
      broadcastSettings: l$broadcastSettings == null
          ? null
          : Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings.fromJson(
              (l$broadcastSettings as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings?
  broadcastSettings;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$broadcastSettings = broadcastSettings;
    _resultData['broadcastSettings'] = l$broadcastSettings?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$broadcastSettings = broadcastSettings;
    return Object.hashAll([l$id, l$broadcastSettings]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
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

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings({
    this.id,
    this.title,
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$title = json.containsKey('title') ? json['title'] : null;
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings(
      id: (l$id as String?),
      title: (l$title as String?),
    );
  }

  final String? id;

  final String? title;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$title = title;
    _resultData['title'] = l$title;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$title = title;
    return Object.hashAll([l$id, l$title]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionChannel$user$stream$broadcaster$broadcastSettings ||
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
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory
    implements Query$FlowSearchChannels$searchSuggestions$edges$node$content {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory({
    this.$__typename = 'SearchSuggestionCategory',
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCategory ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}

class Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection
    implements Query$FlowSearchChannels$searchSuggestions$edges$node$content {
  Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection({
    this.$__typename = 'SearchSuggestionCollection',
  });

  factory Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection(
      $__typename: (l$$__typename as String),
    );
  }

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$$__typename = $__typename;
    return Object.hashAll([l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowSearchChannels$searchSuggestions$edges$node$content$$SearchSuggestionCollection ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$$__typename = $__typename;
    final lOther$$__typename = other.$__typename;
    if (l$$__typename != lOther$$__typename) {
      return false;
    }
    return true;
  }
}
