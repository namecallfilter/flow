// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Variables$Query$FlowVodSeekMetadata {
  factory Variables$Query$FlowVodSeekMetadata({required String videoId}) =>
      Variables$Query$FlowVodSeekMetadata._({r'videoId': videoId});

  Variables$Query$FlowVodSeekMetadata._(this._$data);

  factory Variables$Query$FlowVodSeekMetadata.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$videoId = data['videoId'];
    result$data['videoId'] = (l$videoId as String);
    return Variables$Query$FlowVodSeekMetadata._(result$data);
  }

  Map<String, dynamic> _$data;

  String get videoId => (_$data['videoId'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$videoId = videoId;
    result$data['videoId'] = l$videoId;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowVodSeekMetadata ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$videoId = videoId;
    final lOther$videoId = other.videoId;
    if (l$videoId != lOther$videoId) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$videoId = videoId;
    return Object.hashAll([l$videoId]);
  }
}

class Query$FlowVodSeekMetadata {
  Query$FlowVodSeekMetadata({this.video});

  factory Query$FlowVodSeekMetadata.fromJson(Map<String, dynamic> json) {
    final l$video = json.containsKey('video') ? json['video'] : null;
    return Query$FlowVodSeekMetadata(
      video: l$video == null
          ? null
          : Query$FlowVodSeekMetadata$video.fromJson(
              (l$video as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowVodSeekMetadata$video? video;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$video = video;
    _resultData['video'] = l$video?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$video = video;
    return Object.hashAll([l$video]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodSeekMetadata ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$video = video;
    final lOther$video = other.video;
    if (l$video != lOther$video) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowVodSeekMetadata = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowVodSeekMetadata'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'videoId')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'video'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'videoId')),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FieldNode(
                  name: NameNode(value: 'seekPreviewsURL'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: null,
                ),
                FieldNode(
                  name: NameNode(value: 'muteInfo'),
                  alias: null,
                  arguments: [],
                  directives: [],
                  selectionSet: SelectionSetNode(
                    selections: [
                      FieldNode(
                        name: NameNode(value: 'mutedSegmentConnection'),
                        alias: null,
                        arguments: [],
                        directives: [],
                        selectionSet: SelectionSetNode(
                          selections: [
                            FieldNode(
                              name: NameNode(value: 'nodes'),
                              alias: null,
                              arguments: [],
                              directives: [],
                              selectionSet: SelectionSetNode(
                                selections: [
                                  FieldNode(
                                    name: NameNode(value: 'offset'),
                                    alias: null,
                                    arguments: [],
                                    directives: [],
                                    selectionSet: null,
                                  ),
                                  FieldNode(
                                    name: NameNode(value: 'duration'),
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
      ),
    ),
  ],
);
Query$FlowVodSeekMetadata _parserFn$Query$FlowVodSeekMetadata(
  Map<String, dynamic> data,
) => Query$FlowVodSeekMetadata.fromJson(data);
typedef OnQueryComplete$Query$FlowVodSeekMetadata =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowVodSeekMetadata?);

class Options$Query$FlowVodSeekMetadata
    extends graphql.QueryOptions<Query$FlowVodSeekMetadata> {
  Options$Query$FlowVodSeekMetadata({
    String? operationName,
    required Variables$Query$FlowVodSeekMetadata variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowVodSeekMetadata? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowVodSeekMetadata? onComplete,
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
                     : _parserFn$Query$FlowVodSeekMetadata(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowVodSeekMetadata,
         parserFn: _parserFn$Query$FlowVodSeekMetadata,
       );

  final OnQueryComplete$Query$FlowVodSeekMetadata? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowVodSeekMetadata
    extends graphql.WatchQueryOptions<Query$FlowVodSeekMetadata> {
  WatchOptions$Query$FlowVodSeekMetadata({
    String? operationName,
    required Variables$Query$FlowVodSeekMetadata variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowVodSeekMetadata? typedOptimisticResult,
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
         document: documentNodeQueryFlowVodSeekMetadata,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowVodSeekMetadata,
       );
}

class FetchMoreOptions$Query$FlowVodSeekMetadata
    extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowVodSeekMetadata({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowVodSeekMetadata variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowVodSeekMetadata,
       );
}

extension ClientExtension$Query$FlowVodSeekMetadata on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowVodSeekMetadata>>
  query$FlowVodSeekMetadata(Options$Query$FlowVodSeekMetadata options) async =>
      await this.query(options);

  graphql.ObservableQuery<Query$FlowVodSeekMetadata>
  watchQuery$FlowVodSeekMetadata(
    WatchOptions$Query$FlowVodSeekMetadata options,
  ) => this.watchQuery(options);

  void writeQuery$FlowVodSeekMetadata({
    required Query$FlowVodSeekMetadata data,
    required Variables$Query$FlowVodSeekMetadata variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(
        document: documentNodeQueryFlowVodSeekMetadata,
      ),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowVodSeekMetadata? readQuery$FlowVodSeekMetadata({
    required Variables$Query$FlowVodSeekMetadata variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowVodSeekMetadata,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowVodSeekMetadata.fromJson(result);
  }
}

class Query$FlowVodSeekMetadata$video {
  Query$FlowVodSeekMetadata$video({this.seekPreviewsURL, this.muteInfo});

  factory Query$FlowVodSeekMetadata$video.fromJson(Map<String, dynamic> json) {
    final l$seekPreviewsURL = json.containsKey('seekPreviewsURL')
        ? json['seekPreviewsURL']
        : null;
    final l$muteInfo = json.containsKey('muteInfo') ? json['muteInfo'] : null;
    return Query$FlowVodSeekMetadata$video(
      seekPreviewsURL: (l$seekPreviewsURL as String?),
      muteInfo: l$muteInfo == null
          ? null
          : Query$FlowVodSeekMetadata$video$muteInfo.fromJson(
              (l$muteInfo as Map<String, dynamic>),
            ),
    );
  }

  final String? seekPreviewsURL;

  final Query$FlowVodSeekMetadata$video$muteInfo? muteInfo;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$seekPreviewsURL = seekPreviewsURL;
    _resultData['seekPreviewsURL'] = l$seekPreviewsURL;
    final l$muteInfo = muteInfo;
    _resultData['muteInfo'] = l$muteInfo?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$seekPreviewsURL = seekPreviewsURL;
    final l$muteInfo = muteInfo;
    return Object.hashAll([l$seekPreviewsURL, l$muteInfo]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodSeekMetadata$video ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$seekPreviewsURL = seekPreviewsURL;
    final lOther$seekPreviewsURL = other.seekPreviewsURL;
    if (l$seekPreviewsURL != lOther$seekPreviewsURL) {
      return false;
    }
    final l$muteInfo = muteInfo;
    final lOther$muteInfo = other.muteInfo;
    if (l$muteInfo != lOther$muteInfo) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodSeekMetadata$video$muteInfo {
  Query$FlowVodSeekMetadata$video$muteInfo({this.mutedSegmentConnection});

  factory Query$FlowVodSeekMetadata$video$muteInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$mutedSegmentConnection = json.containsKey('mutedSegmentConnection')
        ? json['mutedSegmentConnection']
        : null;
    return Query$FlowVodSeekMetadata$video$muteInfo(
      mutedSegmentConnection: l$mutedSegmentConnection == null
          ? null
          : Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection.fromJson(
              (l$mutedSegmentConnection as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection?
  mutedSegmentConnection;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$mutedSegmentConnection = mutedSegmentConnection;
    _resultData['mutedSegmentConnection'] = l$mutedSegmentConnection?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$mutedSegmentConnection = mutedSegmentConnection;
    return Object.hashAll([l$mutedSegmentConnection]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowVodSeekMetadata$video$muteInfo ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$mutedSegmentConnection = mutedSegmentConnection;
    final lOther$mutedSegmentConnection = other.mutedSegmentConnection;
    if (l$mutedSegmentConnection != lOther$mutedSegmentConnection) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection {
  Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection({this.nodes});

  factory Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$nodes = json.containsKey('nodes') ? json['nodes'] : null;
    return Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection(
      nodes: (l$nodes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final List<
    Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes?
  >?
  nodes;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$nodes = nodes;
    _resultData['nodes'] = l$nodes?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$nodes = nodes;
    return Object.hashAll([
      l$nodes == null ? null : Object.hashAll(l$nodes.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$nodes = nodes;
    final lOther$nodes = other.nodes;
    if (l$nodes != null && lOther$nodes != null) {
      if (l$nodes.length != lOther$nodes.length) {
        return false;
      }
      for (int i = 0; i < l$nodes.length; i++) {
        final l$nodes$entry = l$nodes[i];
        final lOther$nodes$entry = lOther$nodes[i];
        if (l$nodes$entry != lOther$nodes$entry) {
          return false;
        }
      }
    } else if (l$nodes != lOther$nodes) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes {
  Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes({
    this.offset,
    this.duration,
  });

  factory Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$offset = json.containsKey('offset') ? json['offset'] : null;
    final l$duration = json.containsKey('duration') ? json['duration'] : null;
    return Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes(
      offset: (l$offset as int?),
      duration: (l$duration as int?),
    );
  }

  final int? offset;

  final int? duration;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$offset = offset;
    _resultData['offset'] = l$offset;
    final l$duration = duration;
    _resultData['duration'] = l$duration;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$offset = offset;
    final l$duration = duration;
    return Object.hashAll([l$offset, l$duration]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$offset = offset;
    final lOther$offset = other.offset;
    if (l$offset != lOther$offset) {
      return false;
    }
    final l$duration = duration;
    final lOther$duration = other.duration;
    if (l$duration != lOther$duration) {
      return false;
    }
    return true;
  }
}

class Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes$$VideoMutedSegment
    implements
        Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes {
  Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes$$VideoMutedSegment({
    this.offset,
    this.duration,
  });

  factory Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes$$VideoMutedSegment.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$offset = json.containsKey('offset') ? json['offset'] : null;
    final l$duration = json.containsKey('duration') ? json['duration'] : null;
    return Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes$$VideoMutedSegment(
      offset: (l$offset as int?),
      duration: (l$duration as int?),
    );
  }

  final int? offset;

  final int? duration;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$offset = offset;
    _resultData['offset'] = l$offset;
    final l$duration = duration;
    _resultData['duration'] = l$duration;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$offset = offset;
    final l$duration = duration;
    return Object.hashAll([l$offset, l$duration]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowVodSeekMetadata$video$muteInfo$mutedSegmentConnection$nodes$$VideoMutedSegment ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$offset = offset;
    final lOther$offset = other.offset;
    if (l$offset != lOther$offset) {
      return false;
    }
    final l$duration = duration;
    final lOther$duration = other.duration;
    if (l$duration != lOther$duration) {
      return false;
    }
    return true;
  }
}
