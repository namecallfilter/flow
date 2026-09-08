// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
import 'dart:async';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as graphql;

class Fragment$FlowChatReplyMessage {
  Fragment$FlowChatReplyMessage({
    this.id,
    this.sentAt,
    this.deletedAt,
    this.sender,
    this.senderChatColor,
    this.senderBadges,
    this.content,
    this.parentMessage,
    this.threadParentMessage,
  });

  factory Fragment$FlowChatReplyMessage.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sentAt = json.containsKey('sentAt') ? json['sentAt'] : null;
    final l$deletedAt = json.containsKey('deletedAt')
        ? json['deletedAt']
        : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    final l$senderChatColor = json.containsKey('senderChatColor')
        ? json['senderChatColor']
        : null;
    final l$senderBadges = json.containsKey('senderBadges')
        ? json['senderBadges']
        : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$parentMessage = json.containsKey('parentMessage')
        ? json['parentMessage']
        : null;
    final l$threadParentMessage = json.containsKey('threadParentMessage')
        ? json['threadParentMessage']
        : null;
    return Fragment$FlowChatReplyMessage(
      id: (l$id as String?),
      sentAt: (l$sentAt as String?),
      deletedAt: (l$deletedAt as String?),
      sender: l$sender == null
          ? null
          : Fragment$FlowChatReplyMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
      senderChatColor: (l$senderChatColor as String?),
      senderBadges: (l$senderBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Fragment$FlowChatReplyMessage$senderBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      content: l$content == null
          ? null
          : Fragment$FlowChatReplyMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      parentMessage: l$parentMessage == null
          ? null
          : Fragment$FlowChatReplyMessage$parentMessage.fromJson(
              (l$parentMessage as Map<String, dynamic>),
            ),
      threadParentMessage: l$threadParentMessage == null
          ? null
          : Fragment$FlowChatReplyMessage$threadParentMessage.fromJson(
              (l$threadParentMessage as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? sentAt;

  final String? deletedAt;

  final Fragment$FlowChatReplyMessage$sender? sender;

  final String? senderChatColor;

  final List<Fragment$FlowChatReplyMessage$senderBadges?>? senderBadges;

  final Fragment$FlowChatReplyMessage$content? content;

  final Fragment$FlowChatReplyMessage$parentMessage? parentMessage;

  final Fragment$FlowChatReplyMessage$threadParentMessage? threadParentMessage;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sentAt = sentAt;
    _resultData['sentAt'] = l$sentAt;
    final l$deletedAt = deletedAt;
    _resultData['deletedAt'] = l$deletedAt;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    final l$senderChatColor = senderChatColor;
    _resultData['senderChatColor'] = l$senderChatColor;
    final l$senderBadges = senderBadges;
    _resultData['senderBadges'] = l$senderBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$parentMessage = parentMessage;
    _resultData['parentMessage'] = l$parentMessage?.toJson();
    final l$threadParentMessage = threadParentMessage;
    _resultData['threadParentMessage'] = l$threadParentMessage?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sentAt = sentAt;
    final l$deletedAt = deletedAt;
    final l$sender = sender;
    final l$senderChatColor = senderChatColor;
    final l$senderBadges = senderBadges;
    final l$content = content;
    final l$parentMessage = parentMessage;
    final l$threadParentMessage = threadParentMessage;
    return Object.hashAll([
      l$id,
      l$sentAt,
      l$deletedAt,
      l$sender,
      l$senderChatColor,
      l$senderBadges == null
          ? null
          : Object.hashAll(l$senderBadges.map((v) => v)),
      l$content,
      l$parentMessage,
      l$threadParentMessage,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sentAt = sentAt;
    final lOther$sentAt = other.sentAt;
    if (l$sentAt != lOther$sentAt) {
      return false;
    }
    final l$deletedAt = deletedAt;
    final lOther$deletedAt = other.deletedAt;
    if (l$deletedAt != lOther$deletedAt) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    final l$senderChatColor = senderChatColor;
    final lOther$senderChatColor = other.senderChatColor;
    if (l$senderChatColor != lOther$senderChatColor) {
      return false;
    }
    final l$senderBadges = senderBadges;
    final lOther$senderBadges = other.senderBadges;
    if (l$senderBadges != null && lOther$senderBadges != null) {
      if (l$senderBadges.length != lOther$senderBadges.length) {
        return false;
      }
      for (int i = 0; i < l$senderBadges.length; i++) {
        final l$senderBadges$entry = l$senderBadges[i];
        final lOther$senderBadges$entry = lOther$senderBadges[i];
        if (l$senderBadges$entry != lOther$senderBadges$entry) {
          return false;
        }
      }
    } else if (l$senderBadges != lOther$senderBadges) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$parentMessage = parentMessage;
    final lOther$parentMessage = other.parentMessage;
    if (l$parentMessage != lOther$parentMessage) {
      return false;
    }
    final l$threadParentMessage = threadParentMessage;
    final lOther$threadParentMessage = other.threadParentMessage;
    if (l$threadParentMessage != lOther$threadParentMessage) {
      return false;
    }
    return true;
  }
}

const fragmentDefinitionFlowChatReplyMessage = FragmentDefinitionNode(
  name: NameNode(value: 'FlowChatReplyMessage'),
  typeCondition: TypeConditionNode(
    on: NamedTypeNode(name: NameNode(value: 'Message'), isNonNull: false),
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
        name: NameNode(value: 'sentAt'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'deletedAt'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'sender'),
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
          ],
        ),
      ),
      FieldNode(
        name: NameNode(value: 'senderChatColor'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: null,
      ),
      FieldNode(
        name: NameNode(value: 'senderBadges'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: SelectionSetNode(
          selections: [
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
          ],
        ),
      ),
      FieldNode(
        name: NameNode(value: 'content'),
        alias: null,
        arguments: [],
        directives: [],
        selectionSet: SelectionSetNode(
          selections: [
            FieldNode(
              name: NameNode(value: 'text'),
              alias: null,
              arguments: [],
              directives: [],
              selectionSet: null,
            ),
            FieldNode(
              name: NameNode(value: 'fragments'),
              alias: null,
              arguments: [],
              directives: [],
              selectionSet: SelectionSetNode(
                selections: [
                  FieldNode(
                    name: NameNode(value: 'text'),
                    alias: null,
                    arguments: [],
                    directives: [],
                    selectionSet: null,
                  ),
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
                              name: NameNode(value: 'Emote'),
                              isNonNull: false,
                            ),
                          ),
                          directives: [],
                          selectionSet: SelectionSetNode(
                            selections: [
                              FieldNode(
                                name: NameNode(value: 'id'),
                                alias: NameNode(value: 'emoteID'),
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
      FieldNode(
        name: NameNode(value: 'parentMessage'),
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
              name: NameNode(value: 'content'),
              alias: null,
              arguments: [],
              directives: [],
              selectionSet: SelectionSetNode(
                selections: [
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
            FieldNode(
              name: NameNode(value: 'sender'),
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
                ],
              ),
            ),
          ],
        ),
      ),
      FieldNode(
        name: NameNode(value: 'threadParentMessage'),
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
              name: NameNode(value: 'sender'),
              alias: null,
              arguments: [],
              directives: [],
              selectionSet: SelectionSetNode(
                selections: [
                  FieldNode(
                    name: NameNode(value: 'login'),
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
);
const documentNodeFragmentFlowChatReplyMessage = DocumentNode(
  definitions: [fragmentDefinitionFlowChatReplyMessage],
);

extension ClientExtension$Fragment$FlowChatReplyMessage
    on graphql.GraphQLClient {
  void writeFragment$FlowChatReplyMessage({
    required Fragment$FlowChatReplyMessage data,
    required Map<String, dynamic> idFields,
    bool broadcast = true,
  }) => this.writeFragment(
    graphql.FragmentRequest(
      idFields: idFields,
      fragment: const graphql.Fragment(
        fragmentName: 'FlowChatReplyMessage',
        document: documentNodeFragmentFlowChatReplyMessage,
      ),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Fragment$FlowChatReplyMessage? readFragment$FlowChatReplyMessage({
    required Map<String, dynamic> idFields,
    bool optimistic = true,
  }) {
    final result = this.readFragment(
      graphql.FragmentRequest(
        idFields: idFields,
        fragment: const graphql.Fragment(
          fragmentName: 'FlowChatReplyMessage',
          document: documentNodeFragmentFlowChatReplyMessage,
        ),
      ),
      optimistic: optimistic,
    );
    return result == null
        ? null
        : Fragment$FlowChatReplyMessage.fromJson(result);
  }
}

class Fragment$FlowChatReplyMessage$sender {
  Fragment$FlowChatReplyMessage$sender({this.id, this.login, this.displayName});

  factory Fragment$FlowChatReplyMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Fragment$FlowChatReplyMessage$sender(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$login, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$sender ||
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
    return true;
  }
}

class Fragment$FlowChatReplyMessage$senderBadges {
  Fragment$FlowChatReplyMessage$senderBadges({this.setID, this.version});

  factory Fragment$FlowChatReplyMessage$senderBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    return Fragment$FlowChatReplyMessage$senderBadges(
      setID: (l$setID as String?),
      version: (l$version as String?),
    );
  }

  final String? setID;

  final String? version;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$setID = setID;
    final l$version = version;
    return Object.hashAll([l$setID, l$version]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$senderBadges ||
        runtimeType != other.runtimeType) {
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
    return true;
  }
}

class Fragment$FlowChatReplyMessage$content {
  Fragment$FlowChatReplyMessage$content({this.text, this.fragments});

  factory Fragment$FlowChatReplyMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    return Fragment$FlowChatReplyMessage$content(
      text: (l$text as String?),
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Fragment$FlowChatReplyMessage$content$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? text;

  final List<Fragment$FlowChatReplyMessage$content$fragments?>? fragments;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$fragments = fragments;
    _resultData['fragments'] = l$fragments?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$fragments = fragments;
    return Object.hashAll([
      l$text,
      l$fragments == null ? null : Object.hashAll(l$fragments.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$fragments = fragments;
    final lOther$fragments = other.fragments;
    if (l$fragments != null && lOther$fragments != null) {
      if (l$fragments.length != lOther$fragments.length) {
        return false;
      }
      for (int i = 0; i < l$fragments.length; i++) {
        final l$fragments$entry = l$fragments[i];
        final lOther$fragments$entry = lOther$fragments[i];
        if (l$fragments$entry != lOther$fragments$entry) {
          return false;
        }
      }
    } else if (l$fragments != lOther$fragments) {
      return false;
    }
    return true;
  }
}

class Fragment$FlowChatReplyMessage$content$fragments {
  Fragment$FlowChatReplyMessage$content$fragments({this.text, this.content});

  factory Fragment$FlowChatReplyMessage$content$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    return Fragment$FlowChatReplyMessage$content$fragments(
      text: (l$text as String?),
      content: l$content == null
          ? null
          : Fragment$FlowChatReplyMessage$content$fragments$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Fragment$FlowChatReplyMessage$content$fragments$content? content;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$content = content;
    return Object.hashAll([l$text, l$content]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$content$fragments ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    return true;
  }
}

class Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content({
    required this.$__typename,
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "Emote":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$Emote.fromJson(
          json,
        );

      case "ActivityFeedCheermote":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
          json,
        );

      case "ActivityFeedIntegerToken":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
          json,
        );

      case "ActivityFeedPercentToken":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
          json,
        );

      case "ActivityFeedTextToken":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
          json,
        );

      case "User":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$User.fromJson(
          json,
        );

      case "UserDoesNotExist":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist.fromJson(
          json,
        );

      case "UserError":
        return Fragment$FlowChatReplyMessage$content$fragments$content$$UserError.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Fragment$FlowChatReplyMessage$content$fragments$content(
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
    if (other is! Fragment$FlowChatReplyMessage$content$fragments$content ||
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

extension UtilityExtension$Fragment$FlowChatReplyMessage$content$fragments$content
    on Fragment$FlowChatReplyMessage$content$fragments$content {
  _T when<_T>({
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$Emote,
    )
    emote,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote,
    )
    activityFeedCheermote,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )
    activityFeedIntegerToken,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken,
    )
    activityFeedPercentToken,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken,
    )
    activityFeedTextToken,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$User,
    )
    user,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist,
    )
    userDoesNotExist,
    required _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$UserError,
    )
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        return emote(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$Emote,
        );

      case "ActivityFeedCheermote":
        return activityFeedCheermote(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote,
        );

      case "ActivityFeedIntegerToken":
        return activityFeedIntegerToken(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken,
        );

      case "ActivityFeedPercentToken":
        return activityFeedPercentToken(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken,
        );

      case "ActivityFeedTextToken":
        return activityFeedTextToken(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken,
        );

      case "User":
        return user(
          this as Fragment$FlowChatReplyMessage$content$fragments$content$$User,
        );

      case "UserDoesNotExist":
        return userDoesNotExist(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist,
        );

      case "UserError":
        return userError(
          this
              as Fragment$FlowChatReplyMessage$content$fragments$content$$UserError,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(Fragment$FlowChatReplyMessage$content$fragments$content$$Emote)?
    emote,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote,
    )?
    activityFeedCheermote,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken,
    )?
    activityFeedIntegerToken,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken,
    )?
    activityFeedPercentToken,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken,
    )?
    activityFeedTextToken,
    _T Function(Fragment$FlowChatReplyMessage$content$fragments$content$$User)?
    user,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist,
    )?
    userDoesNotExist,
    _T Function(
      Fragment$FlowChatReplyMessage$content$fragments$content$$UserError,
    )?
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        if (emote != null) {
          return emote(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$Emote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedCheermote":
        if (activityFeedCheermote != null) {
          return activityFeedCheermote(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedIntegerToken":
        if (activityFeedIntegerToken != null) {
          return activityFeedIntegerToken(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedPercentToken":
        if (activityFeedPercentToken != null) {
          return activityFeedPercentToken(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedTextToken":
        if (activityFeedTextToken != null) {
          return activityFeedTextToken(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken,
          );
        } else {
          return orElse();
        }

      case "User":
        if (user != null) {
          return user(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$User,
          );
        } else {
          return orElse();
        }

      case "UserDoesNotExist":
        if (userDoesNotExist != null) {
          return userDoesNotExist(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist,
          );
        } else {
          return orElse();
        }

      case "UserError":
        if (userError != null) {
          return userError(
            this
                as Fragment$FlowChatReplyMessage$content$fragments$content$$UserError,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Fragment$FlowChatReplyMessage$content$fragments$content$$Emote
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$Emote({
    this.emoteID,
    this.$__typename = 'Emote',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$Emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$Emote(
      emoteID: (l$emoteID as String?),
      $__typename: (l$$__typename as String),
    );
  }

  final String? emoteID;

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emoteID = emoteID;
    _resultData['emoteID'] = l$emoteID;
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emoteID = emoteID;
    final l$$__typename = $__typename;
    return Object.hashAll([l$emoteID, l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$Emote ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$emoteID = emoteID;
    final lOther$emoteID = other.emoteID;
    if (l$emoteID != lOther$emoteID) {
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote({
    this.$__typename = 'ActivityFeedCheermote',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken({
    this.$__typename = 'ActivityFeedIntegerToken',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken({
    this.$__typename = 'ActivityFeedPercentToken',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken({
    this.$__typename = 'ActivityFeedTextToken',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$User
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$User({
    this.$__typename = 'User',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$User.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$User(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$User ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist({
    this.$__typename = 'UserDoesNotExist',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist ||
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

class Fragment$FlowChatReplyMessage$content$fragments$content$$UserError
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Fragment$FlowChatReplyMessage$content$fragments$content$$UserError({
    this.$__typename = 'UserError',
  });

  factory Fragment$FlowChatReplyMessage$content$fragments$content$$UserError.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Fragment$FlowChatReplyMessage$content$fragments$content$$UserError(
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
            is! Fragment$FlowChatReplyMessage$content$fragments$content$$UserError ||
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

class Fragment$FlowChatReplyMessage$parentMessage {
  Fragment$FlowChatReplyMessage$parentMessage({
    this.id,
    this.content,
    this.sender,
  });

  factory Fragment$FlowChatReplyMessage$parentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Fragment$FlowChatReplyMessage$parentMessage(
      id: (l$id as String?),
      content: l$content == null
          ? null
          : Fragment$FlowChatReplyMessage$parentMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      sender: l$sender == null
          ? null
          : Fragment$FlowChatReplyMessage$parentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Fragment$FlowChatReplyMessage$parentMessage$content? content;

  final Fragment$FlowChatReplyMessage$parentMessage$sender? sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$content = content;
    final l$sender = sender;
    return Object.hashAll([l$id, l$content, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$parentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Fragment$FlowChatReplyMessage$parentMessage$content {
  Fragment$FlowChatReplyMessage$parentMessage$content({this.text});

  factory Fragment$FlowChatReplyMessage$parentMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    return Fragment$FlowChatReplyMessage$parentMessage$content(
      text: (l$text as String?),
    );
  }

  final String? text;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    return Object.hashAll([l$text]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$parentMessage$content ||
        runtimeType != other.runtimeType) {
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

class Fragment$FlowChatReplyMessage$parentMessage$sender {
  Fragment$FlowChatReplyMessage$parentMessage$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Fragment$FlowChatReplyMessage$parentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Fragment$FlowChatReplyMessage$parentMessage$sender(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$login, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$parentMessage$sender ||
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
    return true;
  }
}

class Fragment$FlowChatReplyMessage$threadParentMessage {
  Fragment$FlowChatReplyMessage$threadParentMessage({this.id, this.sender});

  factory Fragment$FlowChatReplyMessage$threadParentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Fragment$FlowChatReplyMessage$threadParentMessage(
      id: (l$id as String?),
      sender: l$sender == null
          ? null
          : Fragment$FlowChatReplyMessage$threadParentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Fragment$FlowChatReplyMessage$threadParentMessage$sender? sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sender = sender;
    return Object.hashAll([l$id, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$threadParentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Fragment$FlowChatReplyMessage$threadParentMessage$sender {
  Fragment$FlowChatReplyMessage$threadParentMessage$sender({this.login});

  factory Fragment$FlowChatReplyMessage$threadParentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Fragment$FlowChatReplyMessage$threadParentMessage$sender(
      login: (l$login as String?),
    );
  }

  final String? login;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$login = login;
    _resultData['login'] = l$login;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$login = login;
    return Object.hashAll([l$login]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Fragment$FlowChatReplyMessage$threadParentMessage$sender ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    return true;
  }
}

class Variables$Query$FlowChatReplies {
  factory Variables$Query$FlowChatReplies({required String messageID}) =>
      Variables$Query$FlowChatReplies._({r'messageID': messageID});

  Variables$Query$FlowChatReplies._(this._$data);

  factory Variables$Query$FlowChatReplies.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    final l$messageID = data['messageID'];
    result$data['messageID'] = (l$messageID as String);
    return Variables$Query$FlowChatReplies._(result$data);
  }

  Map<String, dynamic> _$data;

  String get messageID => (_$data['messageID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$messageID = messageID;
    result$data['messageID'] = l$messageID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Variables$Query$FlowChatReplies ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$messageID = messageID;
    final lOther$messageID = other.messageID;
    if (l$messageID != lOther$messageID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$messageID = messageID;
    return Object.hashAll([l$messageID]);
  }
}

class Query$FlowChatReplies {
  Query$FlowChatReplies({this.message});

  factory Query$FlowChatReplies.fromJson(Map<String, dynamic> json) {
    final l$message = json.containsKey('message') ? json['message'] : null;
    return Query$FlowChatReplies(
      message: l$message == null
          ? null
          : Query$FlowChatReplies$message.fromJson(
              (l$message as Map<String, dynamic>),
            ),
    );
  }

  final Query$FlowChatReplies$message? message;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$message = message;
    _resultData['message'] = l$message?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$message = message;
    return Object.hashAll([l$message]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies || runtimeType != other.runtimeType) {
      return false;
    }
    final l$message = message;
    final lOther$message = other.message;
    if (l$message != lOther$message) {
      return false;
    }
    return true;
  }
}

const documentNodeQueryFlowChatReplies = DocumentNode(
  definitions: [
    OperationDefinitionNode(
      type: OperationType.query,
      name: NameNode(value: 'FlowChatReplies'),
      variableDefinitions: [
        VariableDefinitionNode(
          variable: VariableNode(name: NameNode(value: 'messageID')),
          type: NamedTypeNode(name: NameNode(value: 'ID'), isNonNull: true),
          defaultValue: DefaultValueNode(value: null),
          directives: [],
        ),
      ],
      directives: [],
      selectionSet: SelectionSetNode(
        selections: [
          FieldNode(
            name: NameNode(value: 'message'),
            alias: null,
            arguments: [
              ArgumentNode(
                name: NameNode(value: 'id'),
                value: VariableNode(name: NameNode(value: 'messageID')),
              ),
            ],
            directives: [],
            selectionSet: SelectionSetNode(
              selections: [
                FragmentSpreadNode(
                  name: NameNode(value: 'FlowChatReplyMessage'),
                  directives: [],
                ),
                FieldNode(
                  name: NameNode(value: 'replies'),
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
                            FragmentSpreadNode(
                              name: NameNode(value: 'FlowChatReplyMessage'),
                              directives: [],
                            ),
                          ],
                        ),
                      ),
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
              ],
            ),
          ),
        ],
      ),
    ),
    fragmentDefinitionFlowChatReplyMessage,
  ],
);
Query$FlowChatReplies _parserFn$Query$FlowChatReplies(
  Map<String, dynamic> data,
) => Query$FlowChatReplies.fromJson(data);
typedef OnQueryComplete$Query$FlowChatReplies =
    FutureOr<void> Function(Map<String, dynamic>?, Query$FlowChatReplies?);

class Options$Query$FlowChatReplies
    extends graphql.QueryOptions<Query$FlowChatReplies> {
  Options$Query$FlowChatReplies({
    String? operationName,
    required Variables$Query$FlowChatReplies variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatReplies? typedOptimisticResult,
    Duration? pollInterval,
    graphql.Context? context,
    OnQueryComplete$Query$FlowChatReplies? onComplete,
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
                 data == null ? null : _parserFn$Query$FlowChatReplies(data),
               ),
         onError: onError,
         document: documentNodeQueryFlowChatReplies,
         parserFn: _parserFn$Query$FlowChatReplies,
       );

  final OnQueryComplete$Query$FlowChatReplies? onCompleteWithParsed;

  @override
  List<Object?> get properties => [
    ...super.onComplete == null
        ? super.properties
        : super.properties.where((property) => property != onComplete),
    onCompleteWithParsed,
  ];
}

class WatchOptions$Query$FlowChatReplies
    extends graphql.WatchQueryOptions<Query$FlowChatReplies> {
  WatchOptions$Query$FlowChatReplies({
    String? operationName,
    required Variables$Query$FlowChatReplies variables,
    graphql.FetchPolicy? fetchPolicy,
    graphql.ErrorPolicy? errorPolicy,
    graphql.CacheRereadPolicy? cacheRereadPolicy,
    Object? optimisticResult,
    Query$FlowChatReplies? typedOptimisticResult,
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
         document: documentNodeQueryFlowChatReplies,
         pollInterval: pollInterval,
         eagerlyFetchResults: eagerlyFetchResults,
         carryForwardDataOnException: carryForwardDataOnException,
         fetchResults: fetchResults,
         parserFn: _parserFn$Query$FlowChatReplies,
       );
}

class FetchMoreOptions$Query$FlowChatReplies extends graphql.FetchMoreOptions {
  FetchMoreOptions$Query$FlowChatReplies({
    required graphql.UpdateQuery updateQuery,
    required Variables$Query$FlowChatReplies variables,
  }) : super(
         updateQuery: updateQuery,
         variables: variables.toJson(),
         document: documentNodeQueryFlowChatReplies,
       );
}

extension ClientExtension$Query$FlowChatReplies on graphql.GraphQLClient {
  Future<graphql.QueryResult<Query$FlowChatReplies>> query$FlowChatReplies(
    Options$Query$FlowChatReplies options,
  ) async => await this.query(options);

  graphql.ObservableQuery<Query$FlowChatReplies> watchQuery$FlowChatReplies(
    WatchOptions$Query$FlowChatReplies options,
  ) => this.watchQuery(options);

  void writeQuery$FlowChatReplies({
    required Query$FlowChatReplies data,
    required Variables$Query$FlowChatReplies variables,
    bool broadcast = true,
  }) => this.writeQuery(
    graphql.Request(
      operation: graphql.Operation(document: documentNodeQueryFlowChatReplies),
      variables: variables.toJson(),
    ),
    data: data.toJson(),
    broadcast: broadcast,
  );

  Query$FlowChatReplies? readQuery$FlowChatReplies({
    required Variables$Query$FlowChatReplies variables,
    bool optimistic = true,
  }) {
    final result = this.readQuery(
      graphql.Request(
        operation: graphql.Operation(
          document: documentNodeQueryFlowChatReplies,
        ),
        variables: variables.toJson(),
      ),
      optimistic: optimistic,
    );
    return result == null ? null : Query$FlowChatReplies.fromJson(result);
  }
}

class Query$FlowChatReplies$message implements Fragment$FlowChatReplyMessage {
  Query$FlowChatReplies$message({
    this.id,
    this.sentAt,
    this.deletedAt,
    this.sender,
    this.senderChatColor,
    this.senderBadges,
    this.content,
    this.parentMessage,
    this.threadParentMessage,
    this.replies,
  });

  factory Query$FlowChatReplies$message.fromJson(Map<String, dynamic> json) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sentAt = json.containsKey('sentAt') ? json['sentAt'] : null;
    final l$deletedAt = json.containsKey('deletedAt')
        ? json['deletedAt']
        : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    final l$senderChatColor = json.containsKey('senderChatColor')
        ? json['senderChatColor']
        : null;
    final l$senderBadges = json.containsKey('senderBadges')
        ? json['senderBadges']
        : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$parentMessage = json.containsKey('parentMessage')
        ? json['parentMessage']
        : null;
    final l$threadParentMessage = json.containsKey('threadParentMessage')
        ? json['threadParentMessage']
        : null;
    final l$replies = json.containsKey('replies') ? json['replies'] : null;
    return Query$FlowChatReplies$message(
      id: (l$id as String?),
      sentAt: (l$sentAt as String?),
      deletedAt: (l$deletedAt as String?),
      sender: l$sender == null
          ? null
          : Query$FlowChatReplies$message$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
      senderChatColor: (l$senderChatColor as String?),
      senderBadges: (l$senderBadges as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatReplies$message$senderBadges.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      content: l$content == null
          ? null
          : Query$FlowChatReplies$message$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      parentMessage: l$parentMessage == null
          ? null
          : Query$FlowChatReplies$message$parentMessage.fromJson(
              (l$parentMessage as Map<String, dynamic>),
            ),
      threadParentMessage: l$threadParentMessage == null
          ? null
          : Query$FlowChatReplies$message$threadParentMessage.fromJson(
              (l$threadParentMessage as Map<String, dynamic>),
            ),
      replies: l$replies == null
          ? null
          : Query$FlowChatReplies$message$replies.fromJson(
              (l$replies as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final String? sentAt;

  final String? deletedAt;

  final Query$FlowChatReplies$message$sender? sender;

  final String? senderChatColor;

  final List<Query$FlowChatReplies$message$senderBadges?>? senderBadges;

  final Query$FlowChatReplies$message$content? content;

  final Query$FlowChatReplies$message$parentMessage? parentMessage;

  final Query$FlowChatReplies$message$threadParentMessage? threadParentMessage;

  final Query$FlowChatReplies$message$replies? replies;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sentAt = sentAt;
    _resultData['sentAt'] = l$sentAt;
    final l$deletedAt = deletedAt;
    _resultData['deletedAt'] = l$deletedAt;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    final l$senderChatColor = senderChatColor;
    _resultData['senderChatColor'] = l$senderChatColor;
    final l$senderBadges = senderBadges;
    _resultData['senderBadges'] = l$senderBadges
        ?.map((e) => e?.toJson())
        .toList();
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$parentMessage = parentMessage;
    _resultData['parentMessage'] = l$parentMessage?.toJson();
    final l$threadParentMessage = threadParentMessage;
    _resultData['threadParentMessage'] = l$threadParentMessage?.toJson();
    final l$replies = replies;
    _resultData['replies'] = l$replies?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sentAt = sentAt;
    final l$deletedAt = deletedAt;
    final l$sender = sender;
    final l$senderChatColor = senderChatColor;
    final l$senderBadges = senderBadges;
    final l$content = content;
    final l$parentMessage = parentMessage;
    final l$threadParentMessage = threadParentMessage;
    final l$replies = replies;
    return Object.hashAll([
      l$id,
      l$sentAt,
      l$deletedAt,
      l$sender,
      l$senderChatColor,
      l$senderBadges == null
          ? null
          : Object.hashAll(l$senderBadges.map((v) => v)),
      l$content,
      l$parentMessage,
      l$threadParentMessage,
      l$replies,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sentAt = sentAt;
    final lOther$sentAt = other.sentAt;
    if (l$sentAt != lOther$sentAt) {
      return false;
    }
    final l$deletedAt = deletedAt;
    final lOther$deletedAt = other.deletedAt;
    if (l$deletedAt != lOther$deletedAt) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    final l$senderChatColor = senderChatColor;
    final lOther$senderChatColor = other.senderChatColor;
    if (l$senderChatColor != lOther$senderChatColor) {
      return false;
    }
    final l$senderBadges = senderBadges;
    final lOther$senderBadges = other.senderBadges;
    if (l$senderBadges != null && lOther$senderBadges != null) {
      if (l$senderBadges.length != lOther$senderBadges.length) {
        return false;
      }
      for (int i = 0; i < l$senderBadges.length; i++) {
        final l$senderBadges$entry = l$senderBadges[i];
        final lOther$senderBadges$entry = lOther$senderBadges[i];
        if (l$senderBadges$entry != lOther$senderBadges$entry) {
          return false;
        }
      }
    } else if (l$senderBadges != lOther$senderBadges) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$parentMessage = parentMessage;
    final lOther$parentMessage = other.parentMessage;
    if (l$parentMessage != lOther$parentMessage) {
      return false;
    }
    final l$threadParentMessage = threadParentMessage;
    final lOther$threadParentMessage = other.threadParentMessage;
    if (l$threadParentMessage != lOther$threadParentMessage) {
      return false;
    }
    final l$replies = replies;
    final lOther$replies = other.replies;
    if (l$replies != lOther$replies) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$sender
    implements Fragment$FlowChatReplyMessage$sender {
  Query$FlowChatReplies$message$sender({this.id, this.login, this.displayName});

  factory Query$FlowChatReplies$message$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowChatReplies$message$sender(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$login, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$sender ||
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
    return true;
  }
}

class Query$FlowChatReplies$message$senderBadges
    implements Fragment$FlowChatReplyMessage$senderBadges {
  Query$FlowChatReplies$message$senderBadges({this.setID, this.version});

  factory Query$FlowChatReplies$message$senderBadges.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$setID = json.containsKey('setID') ? json['setID'] : null;
    final l$version = json.containsKey('version') ? json['version'] : null;
    return Query$FlowChatReplies$message$senderBadges(
      setID: (l$setID as String?),
      version: (l$version as String?),
    );
  }

  final String? setID;

  final String? version;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$setID = setID;
    _resultData['setID'] = l$setID;
    final l$version = version;
    _resultData['version'] = l$version;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$setID = setID;
    final l$version = version;
    return Object.hashAll([l$setID, l$version]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$senderBadges ||
        runtimeType != other.runtimeType) {
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
    return true;
  }
}

class Query$FlowChatReplies$message$content
    implements Fragment$FlowChatReplyMessage$content {
  Query$FlowChatReplies$message$content({this.text, this.fragments});

  factory Query$FlowChatReplies$message$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$fragments = json.containsKey('fragments')
        ? json['fragments']
        : null;
    return Query$FlowChatReplies$message$content(
      text: (l$text as String?),
      fragments: (l$fragments as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Query$FlowChatReplies$message$content$fragments.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
    );
  }

  final String? text;

  final List<Query$FlowChatReplies$message$content$fragments?>? fragments;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$fragments = fragments;
    _resultData['fragments'] = l$fragments?.map((e) => e?.toJson()).toList();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$fragments = fragments;
    return Object.hashAll([
      l$text,
      l$fragments == null ? null : Object.hashAll(l$fragments.map((v) => v)),
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$content ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$fragments = fragments;
    final lOther$fragments = other.fragments;
    if (l$fragments != null && lOther$fragments != null) {
      if (l$fragments.length != lOther$fragments.length) {
        return false;
      }
      for (int i = 0; i < l$fragments.length; i++) {
        final l$fragments$entry = l$fragments[i];
        final lOther$fragments$entry = lOther$fragments[i];
        if (l$fragments$entry != lOther$fragments$entry) {
          return false;
        }
      }
    } else if (l$fragments != lOther$fragments) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$content$fragments
    implements Fragment$FlowChatReplyMessage$content$fragments {
  Query$FlowChatReplies$message$content$fragments({this.text, this.content});

  factory Query$FlowChatReplies$message$content$fragments.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    return Query$FlowChatReplies$message$content$fragments(
      text: (l$text as String?),
      content: l$content == null
          ? null
          : Query$FlowChatReplies$message$content$fragments$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
    );
  }

  final String? text;

  final Query$FlowChatReplies$message$content$fragments$content? content;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    final l$content = content;
    return Object.hashAll([l$text, l$content]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$content$fragments ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$text = text;
    final lOther$text = other.text;
    if (l$text != lOther$text) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$content$fragments$content
    implements Fragment$FlowChatReplyMessage$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content({
    required this.$__typename,
  });

  factory Query$FlowChatReplies$message$content$fragments$content.fromJson(
    Map<String, dynamic> json,
  ) {
    switch (json["__typename"] as String) {
      case "Emote":
        return Query$FlowChatReplies$message$content$fragments$content$$Emote.fromJson(
          json,
        );

      case "ActivityFeedCheermote":
        return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote.fromJson(
          json,
        );

      case "ActivityFeedIntegerToken":
        return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
          json,
        );

      case "ActivityFeedPercentToken":
        return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken.fromJson(
          json,
        );

      case "ActivityFeedTextToken":
        return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken.fromJson(
          json,
        );

      case "User":
        return Query$FlowChatReplies$message$content$fragments$content$$User.fromJson(
          json,
        );

      case "UserDoesNotExist":
        return Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist.fromJson(
          json,
        );

      case "UserError":
        return Query$FlowChatReplies$message$content$fragments$content$$UserError.fromJson(
          json,
        );

      default:
        final l$$__typename = json['__typename'];
        return Query$FlowChatReplies$message$content$fragments$content(
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
    if (other is! Query$FlowChatReplies$message$content$fragments$content ||
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

extension UtilityExtension$Query$FlowChatReplies$message$content$fragments$content
    on Query$FlowChatReplies$message$content$fragments$content {
  _T when<_T>({
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$Emote,
    )
    emote,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote,
    )
    activityFeedCheermote,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken,
    )
    activityFeedIntegerToken,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken,
    )
    activityFeedPercentToken,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken,
    )
    activityFeedTextToken,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$User,
    )
    user,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist,
    )
    userDoesNotExist,
    required _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$UserError,
    )
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        return emote(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$Emote,
        );

      case "ActivityFeedCheermote":
        return activityFeedCheermote(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote,
        );

      case "ActivityFeedIntegerToken":
        return activityFeedIntegerToken(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken,
        );

      case "ActivityFeedPercentToken":
        return activityFeedPercentToken(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken,
        );

      case "ActivityFeedTextToken":
        return activityFeedTextToken(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken,
        );

      case "User":
        return user(
          this as Query$FlowChatReplies$message$content$fragments$content$$User,
        );

      case "UserDoesNotExist":
        return userDoesNotExist(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist,
        );

      case "UserError":
        return userError(
          this
              as Query$FlowChatReplies$message$content$fragments$content$$UserError,
        );

      default:
        return orElse();
    }
  }

  _T maybeWhen<_T>({
    _T Function(Query$FlowChatReplies$message$content$fragments$content$$Emote)?
    emote,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote,
    )?
    activityFeedCheermote,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken,
    )?
    activityFeedIntegerToken,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken,
    )?
    activityFeedPercentToken,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken,
    )?
    activityFeedTextToken,
    _T Function(Query$FlowChatReplies$message$content$fragments$content$$User)?
    user,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist,
    )?
    userDoesNotExist,
    _T Function(
      Query$FlowChatReplies$message$content$fragments$content$$UserError,
    )?
    userError,
    required _T Function() orElse,
  }) {
    switch ($__typename) {
      case "Emote":
        if (emote != null) {
          return emote(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$Emote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedCheermote":
        if (activityFeedCheermote != null) {
          return activityFeedCheermote(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedIntegerToken":
        if (activityFeedIntegerToken != null) {
          return activityFeedIntegerToken(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedPercentToken":
        if (activityFeedPercentToken != null) {
          return activityFeedPercentToken(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken,
          );
        } else {
          return orElse();
        }

      case "ActivityFeedTextToken":
        if (activityFeedTextToken != null) {
          return activityFeedTextToken(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken,
          );
        } else {
          return orElse();
        }

      case "User":
        if (user != null) {
          return user(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$User,
          );
        } else {
          return orElse();
        }

      case "UserDoesNotExist":
        if (userDoesNotExist != null) {
          return userDoesNotExist(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist,
          );
        } else {
          return orElse();
        }

      case "UserError":
        if (userError != null) {
          return userError(
            this
                as Query$FlowChatReplies$message$content$fragments$content$$UserError,
          );
        } else {
          return orElse();
        }

      default:
        return orElse();
    }
  }
}

class Query$FlowChatReplies$message$content$fragments$content$$Emote
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$Emote,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$Emote({
    this.emoteID,
    this.$__typename = 'Emote',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$Emote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$emoteID = json.containsKey('emoteID') ? json['emoteID'] : null;
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$Emote(
      emoteID: (l$emoteID as String?),
      $__typename: (l$$__typename as String),
    );
  }

  final String? emoteID;

  final String $__typename;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$emoteID = emoteID;
    _resultData['emoteID'] = l$emoteID;
    final l$$__typename = $__typename;
    _resultData['__typename'] = l$$__typename;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$emoteID = emoteID;
    final l$$__typename = $__typename;
    return Object.hashAll([l$emoteID, l$$__typename]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Query$FlowChatReplies$message$content$fragments$content$$Emote ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$emoteID = emoteID;
    final lOther$emoteID = other.emoteID;
    if (l$emoteID != lOther$emoteID) {
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

class Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedCheermote,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote({
    this.$__typename = 'ActivityFeedCheermote',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedCheermote ||
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

class Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedIntegerToken,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken({
    this.$__typename = 'ActivityFeedIntegerToken',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedIntegerToken ||
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

class Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedPercentToken,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken({
    this.$__typename = 'ActivityFeedPercentToken',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedPercentToken ||
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

class Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$ActivityFeedTextToken,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken({
    this.$__typename = 'ActivityFeedTextToken',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$ActivityFeedTextToken ||
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

class Query$FlowChatReplies$message$content$fragments$content$$User
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$User,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$User({
    this.$__typename = 'User',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$User.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$User(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$User ||
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

class Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$UserDoesNotExist,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist({
    this.$__typename = 'UserDoesNotExist',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$UserDoesNotExist ||
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

class Query$FlowChatReplies$message$content$fragments$content$$UserError
    implements
        Fragment$FlowChatReplyMessage$content$fragments$content$$UserError,
        Query$FlowChatReplies$message$content$fragments$content {
  Query$FlowChatReplies$message$content$fragments$content$$UserError({
    this.$__typename = 'UserError',
  });

  factory Query$FlowChatReplies$message$content$fragments$content$$UserError.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$$__typename = json['__typename'];
    return Query$FlowChatReplies$message$content$fragments$content$$UserError(
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
            is! Query$FlowChatReplies$message$content$fragments$content$$UserError ||
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

class Query$FlowChatReplies$message$parentMessage
    implements Fragment$FlowChatReplyMessage$parentMessage {
  Query$FlowChatReplies$message$parentMessage({
    this.id,
    this.content,
    this.sender,
  });

  factory Query$FlowChatReplies$message$parentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$content = json.containsKey('content') ? json['content'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowChatReplies$message$parentMessage(
      id: (l$id as String?),
      content: l$content == null
          ? null
          : Query$FlowChatReplies$message$parentMessage$content.fromJson(
              (l$content as Map<String, dynamic>),
            ),
      sender: l$sender == null
          ? null
          : Query$FlowChatReplies$message$parentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowChatReplies$message$parentMessage$content? content;

  final Query$FlowChatReplies$message$parentMessage$sender? sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$content = content;
    _resultData['content'] = l$content?.toJson();
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$content = content;
    final l$sender = sender;
    return Object.hashAll([l$id, l$content, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$parentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$parentMessage$content
    implements Fragment$FlowChatReplyMessage$parentMessage$content {
  Query$FlowChatReplies$message$parentMessage$content({this.text});

  factory Query$FlowChatReplies$message$parentMessage$content.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$text = json.containsKey('text') ? json['text'] : null;
    return Query$FlowChatReplies$message$parentMessage$content(
      text: (l$text as String?),
    );
  }

  final String? text;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$text = text;
    _resultData['text'] = l$text;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$text = text;
    return Object.hashAll([l$text]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$parentMessage$content ||
        runtimeType != other.runtimeType) {
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

class Query$FlowChatReplies$message$parentMessage$sender
    implements Fragment$FlowChatReplyMessage$parentMessage$sender {
  Query$FlowChatReplies$message$parentMessage$sender({
    this.id,
    this.login,
    this.displayName,
  });

  factory Query$FlowChatReplies$message$parentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$login = json.containsKey('login') ? json['login'] : null;
    final l$displayName = json.containsKey('displayName')
        ? json['displayName']
        : null;
    return Query$FlowChatReplies$message$parentMessage$sender(
      id: (l$id as String?),
      login: (l$login as String?),
      displayName: (l$displayName as String?),
    );
  }

  final String? id;

  final String? login;

  final String? displayName;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$login = login;
    _resultData['login'] = l$login;
    final l$displayName = displayName;
    _resultData['displayName'] = l$displayName;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$login = login;
    final l$displayName = displayName;
    return Object.hashAll([l$id, l$login, l$displayName]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$parentMessage$sender ||
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
    return true;
  }
}

class Query$FlowChatReplies$message$threadParentMessage
    implements Fragment$FlowChatReplyMessage$threadParentMessage {
  Query$FlowChatReplies$message$threadParentMessage({this.id, this.sender});

  factory Query$FlowChatReplies$message$threadParentMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$id = json.containsKey('id') ? json['id'] : null;
    final l$sender = json.containsKey('sender') ? json['sender'] : null;
    return Query$FlowChatReplies$message$threadParentMessage(
      id: (l$id as String?),
      sender: l$sender == null
          ? null
          : Query$FlowChatReplies$message$threadParentMessage$sender.fromJson(
              (l$sender as Map<String, dynamic>),
            ),
    );
  }

  final String? id;

  final Query$FlowChatReplies$message$threadParentMessage$sender? sender;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$id = id;
    _resultData['id'] = l$id;
    final l$sender = sender;
    _resultData['sender'] = l$sender?.toJson();
    return _resultData;
  }

  @override
  int get hashCode {
    final l$id = id;
    final l$sender = sender;
    return Object.hashAll([l$id, l$sender]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$threadParentMessage ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$id = id;
    final lOther$id = other.id;
    if (l$id != lOther$id) {
      return false;
    }
    final l$sender = sender;
    final lOther$sender = other.sender;
    if (l$sender != lOther$sender) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$threadParentMessage$sender
    implements Fragment$FlowChatReplyMessage$threadParentMessage$sender {
  Query$FlowChatReplies$message$threadParentMessage$sender({this.login});

  factory Query$FlowChatReplies$message$threadParentMessage$sender.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$login = json.containsKey('login') ? json['login'] : null;
    return Query$FlowChatReplies$message$threadParentMessage$sender(
      login: (l$login as String?),
    );
  }

  final String? login;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$login = login;
    _resultData['login'] = l$login;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$login = login;
    return Object.hashAll([l$login]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$threadParentMessage$sender ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$login = login;
    final lOther$login = other.login;
    if (l$login != lOther$login) {
      return false;
    }
    return true;
  }
}

class Query$FlowChatReplies$message$replies {
  Query$FlowChatReplies$message$replies({this.nodes, this.totalCount});

  factory Query$FlowChatReplies$message$replies.fromJson(
    Map<String, dynamic> json,
  ) {
    final l$nodes = json.containsKey('nodes') ? json['nodes'] : null;
    final l$totalCount = json.containsKey('totalCount')
        ? json['totalCount']
        : null;
    return Query$FlowChatReplies$message$replies(
      nodes: (l$nodes as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : Fragment$FlowChatReplyMessage.fromJson(
                    (e as Map<String, dynamic>),
                  ),
          )
          .toList(),
      totalCount: (l$totalCount as int?),
    );
  }

  final List<Fragment$FlowChatReplyMessage?>? nodes;

  final int? totalCount;

  Map<String, dynamic> toJson() {
    final _resultData = <String, dynamic>{};
    final l$nodes = nodes;
    _resultData['nodes'] = l$nodes?.map((e) => e?.toJson()).toList();
    final l$totalCount = totalCount;
    _resultData['totalCount'] = l$totalCount;
    return _resultData;
  }

  @override
  int get hashCode {
    final l$nodes = nodes;
    final l$totalCount = totalCount;
    return Object.hashAll([
      l$nodes == null ? null : Object.hashAll(l$nodes.map((v) => v)),
      l$totalCount,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Query$FlowChatReplies$message$replies ||
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
    final l$totalCount = totalCount;
    final lOther$totalCount = other.totalCount;
    if (l$totalCount != lOther$totalCount) {
      return false;
    }
    return true;
  }
}
