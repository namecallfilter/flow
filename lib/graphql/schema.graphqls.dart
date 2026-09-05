// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
class Input$AdProperty_TrackingPixels_Consent_Input {
  factory Input$AdProperty_TrackingPixels_Consent_Input({
    bool? allowAmazon,
    bool? allowComscore,
    bool? allowGoogle,
    bool? allowNielsen,
  }) => Input$AdProperty_TrackingPixels_Consent_Input._({
    if (allowAmazon != null) r'allowAmazon': allowAmazon,
    if (allowComscore != null) r'allowComscore': allowComscore,
    if (allowGoogle != null) r'allowGoogle': allowGoogle,
    if (allowNielsen != null) r'allowNielsen': allowNielsen,
  });

  Input$AdProperty_TrackingPixels_Consent_Input._(this._$data);

  factory Input$AdProperty_TrackingPixels_Consent_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('allowAmazon')) {
      final l$allowAmazon = data['allowAmazon'];
      result$data['allowAmazon'] = (l$allowAmazon as bool?);
    }
    if (data.containsKey('allowComscore')) {
      final l$allowComscore = data['allowComscore'];
      result$data['allowComscore'] = (l$allowComscore as bool?);
    }
    if (data.containsKey('allowGoogle')) {
      final l$allowGoogle = data['allowGoogle'];
      result$data['allowGoogle'] = (l$allowGoogle as bool?);
    }
    if (data.containsKey('allowNielsen')) {
      final l$allowNielsen = data['allowNielsen'];
      result$data['allowNielsen'] = (l$allowNielsen as bool?);
    }
    return Input$AdProperty_TrackingPixels_Consent_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  bool? get allowAmazon => (_$data['allowAmazon'] as bool?);

  bool? get allowComscore => (_$data['allowComscore'] as bool?);

  bool? get allowGoogle => (_$data['allowGoogle'] as bool?);

  bool? get allowNielsen => (_$data['allowNielsen'] as bool?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$allowAmazon = _$data.containsKey('allowAmazon')
        ? allowAmazon
        : null;
    result$data['allowAmazon'] = l$allowAmazon;
    final l$allowComscore = _$data.containsKey('allowComscore')
        ? allowComscore
        : null;
    result$data['allowComscore'] = l$allowComscore;
    final l$allowGoogle = _$data.containsKey('allowGoogle')
        ? allowGoogle
        : null;
    result$data['allowGoogle'] = l$allowGoogle;
    final l$allowNielsen = _$data.containsKey('allowNielsen')
        ? allowNielsen
        : null;
    result$data['allowNielsen'] = l$allowNielsen;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$AdProperty_TrackingPixels_Consent_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$allowAmazon = allowAmazon;
    final lOther$allowAmazon = other.allowAmazon;
    if (_$data.containsKey('allowAmazon') !=
        other._$data.containsKey('allowAmazon')) {
      return false;
    }
    if (l$allowAmazon != lOther$allowAmazon) {
      return false;
    }
    final l$allowComscore = allowComscore;
    final lOther$allowComscore = other.allowComscore;
    if (_$data.containsKey('allowComscore') !=
        other._$data.containsKey('allowComscore')) {
      return false;
    }
    if (l$allowComscore != lOther$allowComscore) {
      return false;
    }
    final l$allowGoogle = allowGoogle;
    final lOther$allowGoogle = other.allowGoogle;
    if (_$data.containsKey('allowGoogle') !=
        other._$data.containsKey('allowGoogle')) {
      return false;
    }
    if (l$allowGoogle != lOther$allowGoogle) {
      return false;
    }
    final l$allowNielsen = allowNielsen;
    final lOther$allowNielsen = other.allowNielsen;
    if (_$data.containsKey('allowNielsen') !=
        other._$data.containsKey('allowNielsen')) {
      return false;
    }
    if (l$allowNielsen != lOther$allowNielsen) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$allowAmazon = allowAmazon;
    final l$allowComscore = allowComscore;
    final l$allowGoogle = allowGoogle;
    final l$allowNielsen = allowNielsen;
    return Object.hashAll([
      _$data.containsKey('allowAmazon') ? l$allowAmazon : const {},
      _$data.containsKey('allowComscore') ? l$allowComscore : const {},
      _$data.containsKey('allowGoogle') ? l$allowGoogle : const {},
      _$data.containsKey('allowNielsen') ? l$allowNielsen : const {},
    ]);
  }
}

class Input$ClipAsset_VideoQualities_Params_Input {
  factory Input$ClipAsset_VideoQualities_Params_Input({
    List<Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum?>? supportedCodecs,
  }) => Input$ClipAsset_VideoQualities_Params_Input._({
    if (supportedCodecs != null) r'supportedCodecs': supportedCodecs,
  });

  Input$ClipAsset_VideoQualities_Params_Input._(this._$data);

  factory Input$ClipAsset_VideoQualities_Params_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('supportedCodecs')) {
      final l$supportedCodecs = data['supportedCodecs'];
      result$data['supportedCodecs'] = (l$supportedCodecs as List<dynamic>?)
          ?.map(
            (e) => e == null
                ? null
                : fromJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(
                    (e as String),
                  ),
          )
          .toList();
    }
    return Input$ClipAsset_VideoQualities_Params_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  List<Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum?>?
  get supportedCodecs =>
      (_$data['supportedCodecs']
          as List<Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum?>?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$supportedCodecs = _$data.containsKey('supportedCodecs')
        ? supportedCodecs
        : null;
    result$data['supportedCodecs'] = l$supportedCodecs
        ?.map(
          (e) => e == null
              ? null
              : toJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(e),
        )
        .toList();
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$ClipAsset_VideoQualities_Params_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$supportedCodecs = supportedCodecs;
    final lOther$supportedCodecs = other.supportedCodecs;
    if (_$data.containsKey('supportedCodecs') !=
        other._$data.containsKey('supportedCodecs')) {
      return false;
    }
    if (l$supportedCodecs != null && lOther$supportedCodecs != null) {
      if (l$supportedCodecs.length != lOther$supportedCodecs.length) {
        return false;
      }
      for (int i = 0; i < l$supportedCodecs.length; i++) {
        final l$supportedCodecs$entry = l$supportedCodecs[i];
        final lOther$supportedCodecs$entry = lOther$supportedCodecs[i];
        if (l$supportedCodecs$entry != lOther$supportedCodecs$entry) {
          return false;
        }
      }
    } else if (l$supportedCodecs != lOther$supportedCodecs) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$supportedCodecs = supportedCodecs;
    return Object.hashAll([
      _$data.containsKey('supportedCodecs')
          ? l$supportedCodecs == null
                ? null
                : Object.hashAll(l$supportedCodecs.map((v) => v))
          : const {},
    ]);
  }
}

class Input$Clip_PlaybackAccessToken_Params_Input {
  factory Input$Clip_PlaybackAccessToken_Params_Input({
    String? platform,
    String? playerType,
  }) => Input$Clip_PlaybackAccessToken_Params_Input._({
    if (platform != null) r'platform': platform,
    if (playerType != null) r'playerType': playerType,
  });

  Input$Clip_PlaybackAccessToken_Params_Input._(this._$data);

  factory Input$Clip_PlaybackAccessToken_Params_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('platform')) {
      final l$platform = data['platform'];
      result$data['platform'] = (l$platform as String?);
    }
    if (data.containsKey('playerType')) {
      final l$playerType = data['playerType'];
      result$data['playerType'] = (l$playerType as String?);
    }
    return Input$Clip_PlaybackAccessToken_Params_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String? get platform => (_$data['platform'] as String?);

  String? get playerType => (_$data['playerType'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$platform = _$data.containsKey('platform') ? platform : null;
    result$data['platform'] = l$platform;
    final l$playerType = _$data.containsKey('playerType') ? playerType : null;
    result$data['playerType'] = l$playerType;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Clip_PlaybackAccessToken_Params_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$platform = platform;
    final lOther$platform = other.platform;
    if (_$data.containsKey('platform') !=
        other._$data.containsKey('platform')) {
      return false;
    }
    if (l$platform != lOther$platform) {
      return false;
    }
    final l$playerType = playerType;
    final lOther$playerType = other.playerType;
    if (_$data.containsKey('playerType') !=
        other._$data.containsKey('playerType')) {
      return false;
    }
    if (l$playerType != lOther$playerType) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$platform = platform;
    final l$playerType = playerType;
    return Object.hashAll([
      _$data.containsKey('platform') ? l$platform : const {},
      _$data.containsKey('playerType') ? l$playerType : const {},
    ]);
  }
}

class Input$Extension_ChallengeConditionParticipants_Input_Input {
  factory Input$Extension_ChallengeConditionParticipants_Input_Input({
    required String conditionOwnerID,
    required String conditionParticipantOwnerID,
    Enum$Extension_ChallengeConditionParticipants_EndState_Enum? endState,
  }) => Input$Extension_ChallengeConditionParticipants_Input_Input._({
    r'conditionOwnerID': conditionOwnerID,
    r'conditionParticipantOwnerID': conditionParticipantOwnerID,
    if (endState != null) r'endState': endState,
  });

  Input$Extension_ChallengeConditionParticipants_Input_Input._(this._$data);

  factory Input$Extension_ChallengeConditionParticipants_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$conditionOwnerID = data['conditionOwnerID'];
    result$data['conditionOwnerID'] = (l$conditionOwnerID as String);
    final l$conditionParticipantOwnerID = data['conditionParticipantOwnerID'];
    result$data['conditionParticipantOwnerID'] =
        (l$conditionParticipantOwnerID as String);
    if (data.containsKey('endState')) {
      final l$endState = data['endState'];
      result$data['endState'] = l$endState == null
          ? null
          : fromJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(
              (l$endState as String),
            );
    }
    return Input$Extension_ChallengeConditionParticipants_Input_Input._(
      result$data,
    );
  }

  Map<String, dynamic> _$data;

  String get conditionOwnerID => (_$data['conditionOwnerID'] as String);

  String get conditionParticipantOwnerID =>
      (_$data['conditionParticipantOwnerID'] as String);

  Enum$Extension_ChallengeConditionParticipants_EndState_Enum? get endState =>
      (_$data['endState']
          as Enum$Extension_ChallengeConditionParticipants_EndState_Enum?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$conditionOwnerID = conditionOwnerID;
    result$data['conditionOwnerID'] = l$conditionOwnerID;
    final l$conditionParticipantOwnerID = conditionParticipantOwnerID;
    result$data['conditionParticipantOwnerID'] = l$conditionParticipantOwnerID;
    final l$endState = _$data.containsKey('endState') ? endState : null;
    result$data['endState'] = l$endState == null
        ? null
        : toJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(
            l$endState,
          );
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Extension_ChallengeConditionParticipants_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$conditionOwnerID = conditionOwnerID;
    final lOther$conditionOwnerID = other.conditionOwnerID;
    if (l$conditionOwnerID != lOther$conditionOwnerID) {
      return false;
    }
    final l$conditionParticipantOwnerID = conditionParticipantOwnerID;
    final lOther$conditionParticipantOwnerID =
        other.conditionParticipantOwnerID;
    if (l$conditionParticipantOwnerID != lOther$conditionParticipantOwnerID) {
      return false;
    }
    final l$endState = endState;
    final lOther$endState = other.endState;
    if (_$data.containsKey('endState') !=
        other._$data.containsKey('endState')) {
      return false;
    }
    if (l$endState != lOther$endState) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$conditionOwnerID = conditionOwnerID;
    final l$conditionParticipantOwnerID = conditionParticipantOwnerID;
    final l$endState = endState;
    return Object.hashAll([
      l$conditionOwnerID,
      l$conditionParticipantOwnerID,
      _$data.containsKey('endState') ? l$endState : const {},
    ]);
  }
}

class Input$Extension_ChallengeCondition_Input_Input {
  factory Input$Extension_ChallengeCondition_Input_Input({
    required String conditionID,
    required String conditionOwnerID,
  }) => Input$Extension_ChallengeCondition_Input_Input._({
    r'conditionID': conditionID,
    r'conditionOwnerID': conditionOwnerID,
  });

  Input$Extension_ChallengeCondition_Input_Input._(this._$data);

  factory Input$Extension_ChallengeCondition_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$conditionID = data['conditionID'];
    result$data['conditionID'] = (l$conditionID as String);
    final l$conditionOwnerID = data['conditionOwnerID'];
    result$data['conditionOwnerID'] = (l$conditionOwnerID as String);
    return Input$Extension_ChallengeCondition_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get conditionID => (_$data['conditionID'] as String);

  String get conditionOwnerID => (_$data['conditionOwnerID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$conditionID = conditionID;
    result$data['conditionID'] = l$conditionID;
    final l$conditionOwnerID = conditionOwnerID;
    result$data['conditionOwnerID'] = l$conditionOwnerID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Extension_ChallengeCondition_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$conditionID = conditionID;
    final lOther$conditionID = other.conditionID;
    if (l$conditionID != lOther$conditionID) {
      return false;
    }
    final l$conditionOwnerID = conditionOwnerID;
    final lOther$conditionOwnerID = other.conditionOwnerID;
    if (l$conditionOwnerID != lOther$conditionOwnerID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$conditionID = conditionID;
    final l$conditionOwnerID = conditionOwnerID;
    return Object.hashAll([l$conditionID, l$conditionOwnerID]);
  }
}

class Input$Extension_ChallengeConditions_Input_Input {
  factory Input$Extension_ChallengeConditions_Input_Input({
    required String conditionOwnerID,
    Enum$Extension_ChallengeConditions_State_Enum? state,
  }) => Input$Extension_ChallengeConditions_Input_Input._({
    r'conditionOwnerID': conditionOwnerID,
    if (state != null) r'state': state,
  });

  Input$Extension_ChallengeConditions_Input_Input._(this._$data);

  factory Input$Extension_ChallengeConditions_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$conditionOwnerID = data['conditionOwnerID'];
    result$data['conditionOwnerID'] = (l$conditionOwnerID as String);
    if (data.containsKey('state')) {
      final l$state = data['state'];
      result$data['state'] = l$state == null
          ? null
          : fromJson$Enum$Extension_ChallengeConditions_State_Enum(
              (l$state as String),
            );
    }
    return Input$Extension_ChallengeConditions_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get conditionOwnerID => (_$data['conditionOwnerID'] as String);

  Enum$Extension_ChallengeConditions_State_Enum? get state =>
      (_$data['state'] as Enum$Extension_ChallengeConditions_State_Enum?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$conditionOwnerID = conditionOwnerID;
    result$data['conditionOwnerID'] = l$conditionOwnerID;
    final l$state = _$data.containsKey('state') ? state : null;
    result$data['state'] = l$state == null
        ? null
        : toJson$Enum$Extension_ChallengeConditions_State_Enum(l$state);
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Extension_ChallengeConditions_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$conditionOwnerID = conditionOwnerID;
    final lOther$conditionOwnerID = other.conditionOwnerID;
    if (l$conditionOwnerID != lOther$conditionOwnerID) {
      return false;
    }
    final l$state = state;
    final lOther$state = other.state;
    if (_$data.containsKey('state') != other._$data.containsKey('state')) {
      return false;
    }
    if (l$state != lOther$state) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$conditionOwnerID = conditionOwnerID;
    final l$state = state;
    return Object.hashAll([
      l$conditionOwnerID,
      _$data.containsKey('state') ? l$state : const {},
    ]);
  }
}

class Input$Mutation_BeginUseBitsInExtension_Input_Input {
  factory Input$Mutation_BeginUseBitsInExtension_Input_Input({
    required String channelID,
    required String extensionClientID,
    required String sku,
  }) => Input$Mutation_BeginUseBitsInExtension_Input_Input._({
    r'channelID': channelID,
    r'extensionClientID': extensionClientID,
    r'sku': sku,
  });

  Input$Mutation_BeginUseBitsInExtension_Input_Input._(this._$data);

  factory Input$Mutation_BeginUseBitsInExtension_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$extensionClientID = data['extensionClientID'];
    result$data['extensionClientID'] = (l$extensionClientID as String);
    final l$sku = data['sku'];
    result$data['sku'] = (l$sku as String);
    return Input$Mutation_BeginUseBitsInExtension_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get extensionClientID => (_$data['extensionClientID'] as String);

  String get sku => (_$data['sku'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$extensionClientID = extensionClientID;
    result$data['extensionClientID'] = l$extensionClientID;
    final l$sku = sku;
    result$data['sku'] = l$sku;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_BeginUseBitsInExtension_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$extensionClientID = extensionClientID;
    final lOther$extensionClientID = other.extensionClientID;
    if (l$extensionClientID != lOther$extensionClientID) {
      return false;
    }
    final l$sku = sku;
    final lOther$sku = other.sku;
    if (l$sku != lOther$sku) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$extensionClientID = extensionClientID;
    final l$sku = sku;
    return Object.hashAll([l$channelID, l$extensionClientID, l$sku]);
  }
}

class Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input {
  factory Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input({
    required bool disableWhenSatisfied,
    required String extensionID,
    required String extensionInstallationChannelID,
    required String name,
  }) => Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input._({
    r'disableWhenSatisfied': disableWhenSatisfied,
    r'extensionID': extensionID,
    r'extensionInstallationChannelID': extensionInstallationChannelID,
    r'name': name,
  });

  Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input._(
    this._$data,
  );

  factory Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$disableWhenSatisfied = data['disableWhenSatisfied'];
    result$data['disableWhenSatisfied'] = (l$disableWhenSatisfied as bool);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$extensionInstallationChannelID =
        data['extensionInstallationChannelID'];
    result$data['extensionInstallationChannelID'] =
        (l$extensionInstallationChannelID as String);
    final l$name = data['name'];
    result$data['name'] = (l$name as String);
    return Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input._(
      result$data,
    );
  }

  Map<String, dynamic> _$data;

  bool get disableWhenSatisfied => (_$data['disableWhenSatisfied'] as bool);

  String get extensionID => (_$data['extensionID'] as String);

  String get extensionInstallationChannelID =>
      (_$data['extensionInstallationChannelID'] as String);

  String get name => (_$data['name'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$disableWhenSatisfied = disableWhenSatisfied;
    result$data['disableWhenSatisfied'] = l$disableWhenSatisfied;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$extensionInstallationChannelID = extensionInstallationChannelID;
    result$data['extensionInstallationChannelID'] =
        l$extensionInstallationChannelID;
    final l$name = name;
    result$data['name'] = l$name;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Input$Mutation_CreateBitsChallengeConditionForExtension_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$disableWhenSatisfied = disableWhenSatisfied;
    final lOther$disableWhenSatisfied = other.disableWhenSatisfied;
    if (l$disableWhenSatisfied != lOther$disableWhenSatisfied) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$extensionInstallationChannelID = extensionInstallationChannelID;
    final lOther$extensionInstallationChannelID =
        other.extensionInstallationChannelID;
    if (l$extensionInstallationChannelID !=
        lOther$extensionInstallationChannelID) {
      return false;
    }
    final l$name = name;
    final lOther$name = other.name;
    if (l$name != lOther$name) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$disableWhenSatisfied = disableWhenSatisfied;
    final l$extensionID = extensionID;
    final l$extensionInstallationChannelID = extensionInstallationChannelID;
    final l$name = name;
    return Object.hashAll([
      l$disableWhenSatisfied,
      l$extensionID,
      l$extensionInstallationChannelID,
      l$name,
    ]);
  }
}

class Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input {
  factory Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input({
    required int bitsAmount,
    required String conditionID,
    required String conditionOwnerID,
    required String extensionID,
    required int ttlSeconds,
  }) =>
      Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input._(
        {
          r'bitsAmount': bitsAmount,
          r'conditionID': conditionID,
          r'conditionOwnerID': conditionOwnerID,
          r'extensionID': extensionID,
          r'ttlSeconds': ttlSeconds,
        },
      );

  Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input._(
    this._$data,
  );

  factory Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$bitsAmount = data['bitsAmount'];
    result$data['bitsAmount'] = (l$bitsAmount as int);
    final l$conditionID = data['conditionID'];
    result$data['conditionID'] = (l$conditionID as String);
    final l$conditionOwnerID = data['conditionOwnerID'];
    result$data['conditionOwnerID'] = (l$conditionOwnerID as String);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$ttlSeconds = data['ttlSeconds'];
    result$data['ttlSeconds'] = (l$ttlSeconds as int);
    return Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input._(
      result$data,
    );
  }

  Map<String, dynamic> _$data;

  int get bitsAmount => (_$data['bitsAmount'] as int);

  String get conditionID => (_$data['conditionID'] as String);

  String get conditionOwnerID => (_$data['conditionOwnerID'] as String);

  String get extensionID => (_$data['extensionID'] as String);

  int get ttlSeconds => (_$data['ttlSeconds'] as int);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$bitsAmount = bitsAmount;
    result$data['bitsAmount'] = l$bitsAmount;
    final l$conditionID = conditionID;
    result$data['conditionID'] = l$conditionID;
    final l$conditionOwnerID = conditionOwnerID;
    result$data['conditionOwnerID'] = l$conditionOwnerID;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$ttlSeconds = ttlSeconds;
    result$data['ttlSeconds'] = l$ttlSeconds;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other
            is! Input$Mutation_CreateBitsChallengeConditionParticipantForExtension_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$bitsAmount = bitsAmount;
    final lOther$bitsAmount = other.bitsAmount;
    if (l$bitsAmount != lOther$bitsAmount) {
      return false;
    }
    final l$conditionID = conditionID;
    final lOther$conditionID = other.conditionID;
    if (l$conditionID != lOther$conditionID) {
      return false;
    }
    final l$conditionOwnerID = conditionOwnerID;
    final lOther$conditionOwnerID = other.conditionOwnerID;
    if (l$conditionOwnerID != lOther$conditionOwnerID) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$ttlSeconds = ttlSeconds;
    final lOther$ttlSeconds = other.ttlSeconds;
    if (l$ttlSeconds != lOther$ttlSeconds) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$bitsAmount = bitsAmount;
    final l$conditionID = conditionID;
    final l$conditionOwnerID = conditionOwnerID;
    final l$extensionID = extensionID;
    final l$ttlSeconds = ttlSeconds;
    return Object.hashAll([
      l$bitsAmount,
      l$conditionID,
      l$conditionOwnerID,
      l$extensionID,
      l$ttlSeconds,
    ]);
  }
}

class Input$Mutation_EndUseBitsInExtension_Input_Input {
  factory Input$Mutation_EndUseBitsInExtension_Input_Input({
    required String transactionID,
  }) => Input$Mutation_EndUseBitsInExtension_Input_Input._({
    r'transactionID': transactionID,
  });

  Input$Mutation_EndUseBitsInExtension_Input_Input._(this._$data);

  factory Input$Mutation_EndUseBitsInExtension_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$transactionID = data['transactionID'];
    result$data['transactionID'] = (l$transactionID as String);
    return Input$Mutation_EndUseBitsInExtension_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get transactionID => (_$data['transactionID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$transactionID = transactionID;
    result$data['transactionID'] = l$transactionID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_EndUseBitsInExtension_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$transactionID = transactionID;
    final lOther$transactionID = other.transactionID;
    if (l$transactionID != lOther$transactionID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$transactionID = transactionID;
    return Object.hashAll([l$transactionID]);
  }
}

class Input$Mutation_ExchangeRelayCode_Input_Input {
  factory Input$Mutation_ExchangeRelayCode_Input_Input({
    required String relayCode,
  }) =>
      Input$Mutation_ExchangeRelayCode_Input_Input._({r'relayCode': relayCode});

  Input$Mutation_ExchangeRelayCode_Input_Input._(this._$data);

  factory Input$Mutation_ExchangeRelayCode_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$relayCode = data['relayCode'];
    result$data['relayCode'] = (l$relayCode as String);
    return Input$Mutation_ExchangeRelayCode_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get relayCode => (_$data['relayCode'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$relayCode = relayCode;
    result$data['relayCode'] = l$relayCode;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_ExchangeRelayCode_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$relayCode = relayCode;
    final lOther$relayCode = other.relayCode;
    if (l$relayCode != lOther$relayCode) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$relayCode = relayCode;
    return Object.hashAll([l$relayCode]);
  }
}

class Input$Mutation_ExtensionLinkUser_Input_Input {
  factory Input$Mutation_ExtensionLinkUser_Input_Input({
    required String channelID,
    required String extensionID,
    required String jwt,
    required bool showUser,
  }) => Input$Mutation_ExtensionLinkUser_Input_Input._({
    r'channelID': channelID,
    r'extensionID': extensionID,
    r'jwt': jwt,
    r'showUser': showUser,
  });

  Input$Mutation_ExtensionLinkUser_Input_Input._(this._$data);

  factory Input$Mutation_ExtensionLinkUser_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$jwt = data['jwt'];
    result$data['jwt'] = (l$jwt as String);
    final l$showUser = data['showUser'];
    result$data['showUser'] = (l$showUser as bool);
    return Input$Mutation_ExtensionLinkUser_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get extensionID => (_$data['extensionID'] as String);

  String get jwt => (_$data['jwt'] as String);

  bool get showUser => (_$data['showUser'] as bool);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$jwt = jwt;
    result$data['jwt'] = l$jwt;
    final l$showUser = showUser;
    result$data['showUser'] = l$showUser;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_ExtensionLinkUser_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$jwt = jwt;
    final lOther$jwt = other.jwt;
    if (l$jwt != lOther$jwt) {
      return false;
    }
    final l$showUser = showUser;
    final lOther$showUser = other.showUser;
    if (l$showUser != lOther$showUser) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$extensionID = extensionID;
    final l$jwt = jwt;
    final l$showUser = showUser;
    return Object.hashAll([l$channelID, l$extensionID, l$jwt, l$showUser]);
  }
}

class Input$Mutation_FollowUser_Input_Input {
  factory Input$Mutation_FollowUser_Input_Input({
    required bool disableNotifications,
    required String targetID,
  }) => Input$Mutation_FollowUser_Input_Input._({
    r'disableNotifications': disableNotifications,
    r'targetID': targetID,
  });

  Input$Mutation_FollowUser_Input_Input._(this._$data);

  factory Input$Mutation_FollowUser_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$disableNotifications = data['disableNotifications'];
    result$data['disableNotifications'] = (l$disableNotifications as bool);
    final l$targetID = data['targetID'];
    result$data['targetID'] = (l$targetID as String);
    return Input$Mutation_FollowUser_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  bool get disableNotifications => (_$data['disableNotifications'] as bool);

  String get targetID => (_$data['targetID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$disableNotifications = disableNotifications;
    result$data['disableNotifications'] = l$disableNotifications;
    final l$targetID = targetID;
    result$data['targetID'] = l$targetID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_FollowUser_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$disableNotifications = disableNotifications;
    final lOther$disableNotifications = other.disableNotifications;
    if (l$disableNotifications != lOther$disableNotifications) {
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
    final l$disableNotifications = disableNotifications;
    final l$targetID = targetID;
    return Object.hashAll([l$disableNotifications, l$targetID]);
  }
}

class Input$Mutation_RefreshExtensionHelixToken_Input_Input {
  factory Input$Mutation_RefreshExtensionHelixToken_Input_Input({
    required String extensionID,
    required String jwt,
  }) => Input$Mutation_RefreshExtensionHelixToken_Input_Input._({
    r'extensionID': extensionID,
    r'jwt': jwt,
  });

  Input$Mutation_RefreshExtensionHelixToken_Input_Input._(this._$data);

  factory Input$Mutation_RefreshExtensionHelixToken_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$jwt = data['jwt'];
    result$data['jwt'] = (l$jwt as String);
    return Input$Mutation_RefreshExtensionHelixToken_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get extensionID => (_$data['extensionID'] as String);

  String get jwt => (_$data['jwt'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$jwt = jwt;
    result$data['jwt'] = l$jwt;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_RefreshExtensionHelixToken_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$jwt = jwt;
    final lOther$jwt = other.jwt;
    if (l$jwt != lOther$jwt) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$extensionID = extensionID;
    final l$jwt = jwt;
    return Object.hashAll([l$extensionID, l$jwt]);
  }
}

class Input$Mutation_RefreshExtensionToken_Input_Input {
  factory Input$Mutation_RefreshExtensionToken_Input_Input({
    required String channelID,
    required String extensionID,
    required String jwt,
  }) => Input$Mutation_RefreshExtensionToken_Input_Input._({
    r'channelID': channelID,
    r'extensionID': extensionID,
    r'jwt': jwt,
  });

  Input$Mutation_RefreshExtensionToken_Input_Input._(this._$data);

  factory Input$Mutation_RefreshExtensionToken_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$jwt = data['jwt'];
    result$data['jwt'] = (l$jwt as String);
    return Input$Mutation_RefreshExtensionToken_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get extensionID => (_$data['extensionID'] as String);

  String get jwt => (_$data['jwt'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$jwt = jwt;
    result$data['jwt'] = l$jwt;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_RefreshExtensionToken_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$jwt = jwt;
    final lOther$jwt = other.jwt;
    if (l$jwt != lOther$jwt) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$extensionID = extensionID;
    final l$jwt = jwt;
    return Object.hashAll([l$channelID, l$extensionID, l$jwt]);
  }
}

class Input$Mutation_SendExtensionMessage_Input_Input {
  factory Input$Mutation_SendExtensionMessage_Input_Input({
    required String channelID,
    required String contentType,
    required String extAuthToken,
    required String extensionID,
    required String message,
    required List<String> targets,
  }) => Input$Mutation_SendExtensionMessage_Input_Input._({
    r'channelID': channelID,
    r'contentType': contentType,
    r'extAuthToken': extAuthToken,
    r'extensionID': extensionID,
    r'message': message,
    r'targets': targets,
  });

  Input$Mutation_SendExtensionMessage_Input_Input._(this._$data);

  factory Input$Mutation_SendExtensionMessage_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$contentType = data['contentType'];
    result$data['contentType'] = (l$contentType as String);
    final l$extAuthToken = data['extAuthToken'];
    result$data['extAuthToken'] = (l$extAuthToken as String);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    final l$message = data['message'];
    result$data['message'] = (l$message as String);
    final l$targets = data['targets'];
    result$data['targets'] = (l$targets as List<dynamic>)
        .map((e) => (e as String))
        .toList();
    return Input$Mutation_SendExtensionMessage_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get contentType => (_$data['contentType'] as String);

  String get extAuthToken => (_$data['extAuthToken'] as String);

  String get extensionID => (_$data['extensionID'] as String);

  String get message => (_$data['message'] as String);

  List<String> get targets => (_$data['targets'] as List<String>);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$contentType = contentType;
    result$data['contentType'] = l$contentType;
    final l$extAuthToken = extAuthToken;
    result$data['extAuthToken'] = l$extAuthToken;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    final l$message = message;
    result$data['message'] = l$message;
    final l$targets = targets;
    result$data['targets'] = l$targets.map((e) => e).toList();
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_SendExtensionMessage_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$contentType = contentType;
    final lOther$contentType = other.contentType;
    if (l$contentType != lOther$contentType) {
      return false;
    }
    final l$extAuthToken = extAuthToken;
    final lOther$extAuthToken = other.extAuthToken;
    if (l$extAuthToken != lOther$extAuthToken) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    final l$message = message;
    final lOther$message = other.message;
    if (l$message != lOther$message) {
      return false;
    }
    final l$targets = targets;
    final lOther$targets = other.targets;
    if (l$targets.length != lOther$targets.length) {
      return false;
    }
    for (int i = 0; i < l$targets.length; i++) {
      final l$targets$entry = l$targets[i];
      final lOther$targets$entry = lOther$targets[i];
      if (l$targets$entry != lOther$targets$entry) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$contentType = contentType;
    final l$extAuthToken = extAuthToken;
    final l$extensionID = extensionID;
    final l$message = message;
    final l$targets = targets;
    return Object.hashAll([
      l$channelID,
      l$contentType,
      l$extAuthToken,
      l$extensionID,
      l$message,
      Object.hashAll(l$targets.map((v) => v)),
    ]);
  }
}

class Input$Mutation_SetExtensionConfiguration_Input_Input {
  factory Input$Mutation_SetExtensionConfiguration_Input_Input({
    required String channelID,
    required String configVersion,
    required String content,
    required String extensionID,
  }) => Input$Mutation_SetExtensionConfiguration_Input_Input._({
    r'channelID': channelID,
    r'configVersion': configVersion,
    r'content': content,
    r'extensionID': extensionID,
  });

  Input$Mutation_SetExtensionConfiguration_Input_Input._(this._$data);

  factory Input$Mutation_SetExtensionConfiguration_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$channelID = data['channelID'];
    result$data['channelID'] = (l$channelID as String);
    final l$configVersion = data['configVersion'];
    result$data['configVersion'] = (l$configVersion as String);
    final l$content = data['content'];
    result$data['content'] = (l$content as String);
    final l$extensionID = data['extensionID'];
    result$data['extensionID'] = (l$extensionID as String);
    return Input$Mutation_SetExtensionConfiguration_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get channelID => (_$data['channelID'] as String);

  String get configVersion => (_$data['configVersion'] as String);

  String get content => (_$data['content'] as String);

  String get extensionID => (_$data['extensionID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$channelID = channelID;
    result$data['channelID'] = l$channelID;
    final l$configVersion = configVersion;
    result$data['configVersion'] = l$configVersion;
    final l$content = content;
    result$data['content'] = l$content;
    final l$extensionID = extensionID;
    result$data['extensionID'] = l$extensionID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_SetExtensionConfiguration_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$channelID = channelID;
    final lOther$channelID = other.channelID;
    if (l$channelID != lOther$channelID) {
      return false;
    }
    final l$configVersion = configVersion;
    final lOther$configVersion = other.configVersion;
    if (l$configVersion != lOther$configVersion) {
      return false;
    }
    final l$content = content;
    final lOther$content = other.content;
    if (l$content != lOther$content) {
      return false;
    }
    final l$extensionID = extensionID;
    final lOther$extensionID = other.extensionID;
    if (l$extensionID != lOther$extensionID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$channelID = channelID;
    final l$configVersion = configVersion;
    final l$content = content;
    final l$extensionID = extensionID;
    return Object.hashAll([
      l$channelID,
      l$configVersion,
      l$content,
      l$extensionID,
    ]);
  }
}

class Input$Mutation_UpdateUserProductConsent_Input_Input {
  factory Input$Mutation_UpdateUserProductConsent_Input_Input({
    required List<String> productConsentUpdate,
    required String userID,
  }) => Input$Mutation_UpdateUserProductConsent_Input_Input._({
    r'productConsentUpdate': productConsentUpdate,
    r'userID': userID,
  });

  Input$Mutation_UpdateUserProductConsent_Input_Input._(this._$data);

  factory Input$Mutation_UpdateUserProductConsent_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$productConsentUpdate = data['productConsentUpdate'];
    result$data['productConsentUpdate'] =
        (l$productConsentUpdate as List<dynamic>)
            .map((e) => (e as String))
            .toList();
    final l$userID = data['userID'];
    result$data['userID'] = (l$userID as String);
    return Input$Mutation_UpdateUserProductConsent_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  List<String> get productConsentUpdate =>
      (_$data['productConsentUpdate'] as List<String>);

  String get userID => (_$data['userID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$productConsentUpdate = productConsentUpdate;
    result$data['productConsentUpdate'] = l$productConsentUpdate
        .map((e) => e)
        .toList();
    final l$userID = userID;
    result$data['userID'] = l$userID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Mutation_UpdateUserProductConsent_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$productConsentUpdate = productConsentUpdate;
    final lOther$productConsentUpdate = other.productConsentUpdate;
    if (l$productConsentUpdate.length != lOther$productConsentUpdate.length) {
      return false;
    }
    for (int i = 0; i < l$productConsentUpdate.length; i++) {
      final l$productConsentUpdate$entry = l$productConsentUpdate[i];
      final lOther$productConsentUpdate$entry = lOther$productConsentUpdate[i];
      if (l$productConsentUpdate$entry != lOther$productConsentUpdate$entry) {
        return false;
      }
    }
    final l$userID = userID;
    final lOther$userID = other.userID;
    if (l$userID != lOther$userID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$productConsentUpdate = productConsentUpdate;
    final l$userID = userID;
    return Object.hashAll([
      Object.hashAll(l$productConsentUpdate.map((v) => v)),
      l$userID,
    ]);
  }
}

class Input$Query_FeedItems_Context_Input {
  factory Input$Query_FeedItems_Context_Input({
    required String clientApp,
    required String pageviewLocation,
    String? platform,
  }) => Input$Query_FeedItems_Context_Input._({
    r'clientApp': clientApp,
    r'pageviewLocation': pageviewLocation,
    if (platform != null) r'platform': platform,
  });

  Input$Query_FeedItems_Context_Input._(this._$data);

  factory Input$Query_FeedItems_Context_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$clientApp = data['clientApp'];
    result$data['clientApp'] = (l$clientApp as String);
    final l$pageviewLocation = data['pageviewLocation'];
    result$data['pageviewLocation'] = (l$pageviewLocation as String);
    if (data.containsKey('platform')) {
      final l$platform = data['platform'];
      result$data['platform'] = (l$platform as String?);
    }
    return Input$Query_FeedItems_Context_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get clientApp => (_$data['clientApp'] as String);

  String get pageviewLocation => (_$data['pageviewLocation'] as String);

  String? get platform => (_$data['platform'] as String?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$clientApp = clientApp;
    result$data['clientApp'] = l$clientApp;
    final l$pageviewLocation = pageviewLocation;
    result$data['pageviewLocation'] = l$pageviewLocation;
    final l$platform = _$data.containsKey('platform') ? platform : null;
    result$data['platform'] = l$platform;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_FeedItems_Context_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$clientApp = clientApp;
    final lOther$clientApp = other.clientApp;
    if (l$clientApp != lOther$clientApp) {
      return false;
    }
    final l$pageviewLocation = pageviewLocation;
    final lOther$pageviewLocation = other.pageviewLocation;
    if (l$pageviewLocation != lOther$pageviewLocation) {
      return false;
    }
    final l$platform = platform;
    final lOther$platform = other.platform;
    if (_$data.containsKey('platform') !=
        other._$data.containsKey('platform')) {
      return false;
    }
    if (l$platform != lOther$platform) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$clientApp = clientApp;
    final l$pageviewLocation = pageviewLocation;
    final l$platform = platform;
    return Object.hashAll([
      l$clientApp,
      l$pageviewLocation,
      _$data.containsKey('platform') ? l$platform : const {},
    ]);
  }
}

class Input$Query_FeedItems_Input_Input {
  factory Input$Query_FeedItems_Input_Input({
    Input$Query_FeedItems_Context_Input? context,
    Enum$Query_FeedItems_FeedLocation_Enum? feedLocation,
    Enum$Query_FeedItems_Ingress_Enum? ingress,
    int? limit,
    required String requestID,
    required String sessionID,
  }) => Input$Query_FeedItems_Input_Input._({
    if (context != null) r'context': context,
    if (feedLocation != null) r'feedLocation': feedLocation,
    if (ingress != null) r'ingress': ingress,
    if (limit != null) r'limit': limit,
    r'requestID': requestID,
    r'sessionID': sessionID,
  });

  Input$Query_FeedItems_Input_Input._(this._$data);

  factory Input$Query_FeedItems_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('context')) {
      final l$context = data['context'];
      result$data['context'] = l$context == null
          ? null
          : Input$Query_FeedItems_Context_Input.fromJson(
              (l$context as Map<String, dynamic>),
            );
    }
    if (data.containsKey('feedLocation')) {
      final l$feedLocation = data['feedLocation'];
      result$data['feedLocation'] = l$feedLocation == null
          ? null
          : fromJson$Enum$Query_FeedItems_FeedLocation_Enum(
              (l$feedLocation as String),
            );
    }
    if (data.containsKey('ingress')) {
      final l$ingress = data['ingress'];
      result$data['ingress'] = l$ingress == null
          ? null
          : fromJson$Enum$Query_FeedItems_Ingress_Enum((l$ingress as String));
    }
    if (data.containsKey('limit')) {
      final l$limit = data['limit'];
      result$data['limit'] = (l$limit as int?);
    }
    final l$requestID = data['requestID'];
    result$data['requestID'] = (l$requestID as String);
    final l$sessionID = data['sessionID'];
    result$data['sessionID'] = (l$sessionID as String);
    return Input$Query_FeedItems_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  Input$Query_FeedItems_Context_Input? get context =>
      (_$data['context'] as Input$Query_FeedItems_Context_Input?);

  Enum$Query_FeedItems_FeedLocation_Enum? get feedLocation =>
      (_$data['feedLocation'] as Enum$Query_FeedItems_FeedLocation_Enum?);

  Enum$Query_FeedItems_Ingress_Enum? get ingress =>
      (_$data['ingress'] as Enum$Query_FeedItems_Ingress_Enum?);

  int? get limit => (_$data['limit'] as int?);

  String get requestID => (_$data['requestID'] as String);

  String get sessionID => (_$data['sessionID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$context = _$data.containsKey('context') ? context : null;
    result$data['context'] = l$context?.toJson();
    final l$feedLocation = _$data.containsKey('feedLocation')
        ? feedLocation
        : null;
    result$data['feedLocation'] = l$feedLocation == null
        ? null
        : toJson$Enum$Query_FeedItems_FeedLocation_Enum(l$feedLocation);
    final l$ingress = _$data.containsKey('ingress') ? ingress : null;
    result$data['ingress'] = l$ingress == null
        ? null
        : toJson$Enum$Query_FeedItems_Ingress_Enum(l$ingress);
    final l$limit = _$data.containsKey('limit') ? limit : null;
    result$data['limit'] = l$limit;
    final l$requestID = requestID;
    result$data['requestID'] = l$requestID;
    final l$sessionID = sessionID;
    result$data['sessionID'] = l$sessionID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_FeedItems_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$context = context;
    final lOther$context = other.context;
    if (_$data.containsKey('context') != other._$data.containsKey('context')) {
      return false;
    }
    if (l$context != lOther$context) {
      return false;
    }
    final l$feedLocation = feedLocation;
    final lOther$feedLocation = other.feedLocation;
    if (_$data.containsKey('feedLocation') !=
        other._$data.containsKey('feedLocation')) {
      return false;
    }
    if (l$feedLocation != lOther$feedLocation) {
      return false;
    }
    final l$ingress = ingress;
    final lOther$ingress = other.ingress;
    if (_$data.containsKey('ingress') != other._$data.containsKey('ingress')) {
      return false;
    }
    if (l$ingress != lOther$ingress) {
      return false;
    }
    final l$limit = limit;
    final lOther$limit = other.limit;
    if (_$data.containsKey('limit') != other._$data.containsKey('limit')) {
      return false;
    }
    if (l$limit != lOther$limit) {
      return false;
    }
    final l$requestID = requestID;
    final lOther$requestID = other.requestID;
    if (l$requestID != lOther$requestID) {
      return false;
    }
    final l$sessionID = sessionID;
    final lOther$sessionID = other.sessionID;
    if (l$sessionID != lOther$sessionID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$context = context;
    final l$feedLocation = feedLocation;
    final l$ingress = ingress;
    final l$limit = limit;
    final l$requestID = requestID;
    final l$sessionID = sessionID;
    return Object.hashAll([
      _$data.containsKey('context') ? l$context : const {},
      _$data.containsKey('feedLocation') ? l$feedLocation : const {},
      _$data.containsKey('ingress') ? l$ingress : const {},
      _$data.containsKey('limit') ? l$limit : const {},
      l$requestID,
      l$sessionID,
    ]);
  }
}

class Input$Query_LiveShoppingProductDetails_Input_Input {
  factory Input$Query_LiveShoppingProductDetails_Input_Input({
    required String asin,
    required String liveShoppingSessionID,
  }) => Input$Query_LiveShoppingProductDetails_Input_Input._({
    r'asin': asin,
    r'liveShoppingSessionID': liveShoppingSessionID,
  });

  Input$Query_LiveShoppingProductDetails_Input_Input._(this._$data);

  factory Input$Query_LiveShoppingProductDetails_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$asin = data['asin'];
    result$data['asin'] = (l$asin as String);
    final l$liveShoppingSessionID = data['liveShoppingSessionID'];
    result$data['liveShoppingSessionID'] = (l$liveShoppingSessionID as String);
    return Input$Query_LiveShoppingProductDetails_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get asin => (_$data['asin'] as String);

  String get liveShoppingSessionID =>
      (_$data['liveShoppingSessionID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$asin = asin;
    result$data['asin'] = l$asin;
    final l$liveShoppingSessionID = liveShoppingSessionID;
    result$data['liveShoppingSessionID'] = l$liveShoppingSessionID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_LiveShoppingProductDetails_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$asin = asin;
    final lOther$asin = other.asin;
    if (l$asin != lOther$asin) {
      return false;
    }
    final l$liveShoppingSessionID = liveShoppingSessionID;
    final lOther$liveShoppingSessionID = other.liveShoppingSessionID;
    if (l$liveShoppingSessionID != lOther$liveShoppingSessionID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$asin = asin;
    final l$liveShoppingSessionID = liveShoppingSessionID;
    return Object.hashAll([l$asin, l$liveShoppingSessionID]);
  }
}

class Input$Query_LiveShoppingProductSummaries_Input_Input {
  factory Input$Query_LiveShoppingProductSummaries_Input_Input({
    required List<String> asins,
    required String liveShoppingSessionID,
  }) => Input$Query_LiveShoppingProductSummaries_Input_Input._({
    r'asins': asins,
    r'liveShoppingSessionID': liveShoppingSessionID,
  });

  Input$Query_LiveShoppingProductSummaries_Input_Input._(this._$data);

  factory Input$Query_LiveShoppingProductSummaries_Input_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$asins = data['asins'];
    result$data['asins'] = (l$asins as List<dynamic>)
        .map((e) => (e as String))
        .toList();
    final l$liveShoppingSessionID = data['liveShoppingSessionID'];
    result$data['liveShoppingSessionID'] = (l$liveShoppingSessionID as String);
    return Input$Query_LiveShoppingProductSummaries_Input_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  List<String> get asins => (_$data['asins'] as List<String>);

  String get liveShoppingSessionID =>
      (_$data['liveShoppingSessionID'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$asins = asins;
    result$data['asins'] = l$asins.map((e) => e).toList();
    final l$liveShoppingSessionID = liveShoppingSessionID;
    result$data['liveShoppingSessionID'] = l$liveShoppingSessionID;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_LiveShoppingProductSummaries_Input_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$asins = asins;
    final lOther$asins = other.asins;
    if (l$asins.length != lOther$asins.length) {
      return false;
    }
    for (int i = 0; i < l$asins.length; i++) {
      final l$asins$entry = l$asins[i];
      final lOther$asins$entry = lOther$asins[i];
      if (l$asins$entry != lOther$asins$entry) {
        return false;
      }
    }
    final l$liveShoppingSessionID = liveShoppingSessionID;
    final lOther$liveShoppingSessionID = other.liveShoppingSessionID;
    if (l$liveShoppingSessionID != lOther$liveShoppingSessionID) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$asins = asins;
    final l$liveShoppingSessionID = liveShoppingSessionID;
    return Object.hashAll([
      Object.hashAll(l$asins.map((v) => v)),
      l$liveShoppingSessionID,
    ]);
  }
}

class Input$Query_StreamPlaybackAccessToken_Params_Input {
  factory Input$Query_StreamPlaybackAccessToken_Params_Input({
    required String platform,
    String? playerBackend,
    required String playerType,
  }) => Input$Query_StreamPlaybackAccessToken_Params_Input._({
    r'platform': platform,
    if (playerBackend != null) r'playerBackend': playerBackend,
    r'playerType': playerType,
  });

  Input$Query_StreamPlaybackAccessToken_Params_Input._(this._$data);

  factory Input$Query_StreamPlaybackAccessToken_Params_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$platform = data['platform'];
    result$data['platform'] = (l$platform as String);
    if (data.containsKey('playerBackend')) {
      final l$playerBackend = data['playerBackend'];
      result$data['playerBackend'] = (l$playerBackend as String?);
    }
    final l$playerType = data['playerType'];
    result$data['playerType'] = (l$playerType as String);
    return Input$Query_StreamPlaybackAccessToken_Params_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get platform => (_$data['platform'] as String);

  String? get playerBackend => (_$data['playerBackend'] as String?);

  String get playerType => (_$data['playerType'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$platform = platform;
    result$data['platform'] = l$platform;
    final l$playerBackend = _$data.containsKey('playerBackend')
        ? playerBackend
        : null;
    result$data['playerBackend'] = l$playerBackend;
    final l$playerType = playerType;
    result$data['playerType'] = l$playerType;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_StreamPlaybackAccessToken_Params_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$platform = platform;
    final lOther$platform = other.platform;
    if (l$platform != lOther$platform) {
      return false;
    }
    final l$playerBackend = playerBackend;
    final lOther$playerBackend = other.playerBackend;
    if (_$data.containsKey('playerBackend') !=
        other._$data.containsKey('playerBackend')) {
      return false;
    }
    if (l$playerBackend != lOther$playerBackend) {
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
    final l$platform = platform;
    final l$playerBackend = playerBackend;
    final l$playerType = playerType;
    return Object.hashAll([
      l$platform,
      _$data.containsKey('playerBackend') ? l$playerBackend : const {},
      l$playerType,
    ]);
  }
}

class Input$Query_VideoPlaybackAccessToken_Params_Input {
  factory Input$Query_VideoPlaybackAccessToken_Params_Input({
    required String platform,
    String? playerBackend,
    required String playerType,
  }) => Input$Query_VideoPlaybackAccessToken_Params_Input._({
    r'platform': platform,
    if (playerBackend != null) r'playerBackend': playerBackend,
    r'playerType': playerType,
  });

  Input$Query_VideoPlaybackAccessToken_Params_Input._(this._$data);

  factory Input$Query_VideoPlaybackAccessToken_Params_Input.fromJson(
    Map<String, dynamic> data,
  ) {
    final result$data = <String, dynamic>{};
    final l$platform = data['platform'];
    result$data['platform'] = (l$platform as String);
    if (data.containsKey('playerBackend')) {
      final l$playerBackend = data['playerBackend'];
      result$data['playerBackend'] = (l$playerBackend as String?);
    }
    final l$playerType = data['playerType'];
    result$data['playerType'] = (l$playerType as String);
    return Input$Query_VideoPlaybackAccessToken_Params_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  String get platform => (_$data['platform'] as String);

  String? get playerBackend => (_$data['playerBackend'] as String?);

  String get playerType => (_$data['playerType'] as String);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$platform = platform;
    result$data['platform'] = l$platform;
    final l$playerBackend = _$data.containsKey('playerBackend')
        ? playerBackend
        : null;
    result$data['playerBackend'] = l$playerBackend;
    final l$playerType = playerType;
    result$data['playerType'] = l$playerType;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_VideoPlaybackAccessToken_Params_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$platform = platform;
    final lOther$platform = other.platform;
    if (l$platform != lOther$platform) {
      return false;
    }
    final l$playerBackend = playerBackend;
    final lOther$playerBackend = other.playerBackend;
    if (_$data.containsKey('playerBackend') !=
        other._$data.containsKey('playerBackend')) {
      return false;
    }
    if (l$playerBackend != lOther$playerBackend) {
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
    final l$platform = platform;
    final l$playerBackend = playerBackend;
    final l$playerType = playerType;
    return Object.hashAll([
      l$platform,
      _$data.containsKey('playerBackend') ? l$playerBackend : const {},
      l$playerType,
    ]);
  }
}

class Input$Query_Video_Options_Input {
  factory Input$Query_Video_Options_Input({bool? includePrivate}) =>
      Input$Query_Video_Options_Input._({
        if (includePrivate != null) r'includePrivate': includePrivate,
      });

  Input$Query_Video_Options_Input._(this._$data);

  factory Input$Query_Video_Options_Input.fromJson(Map<String, dynamic> data) {
    final result$data = <String, dynamic>{};
    if (data.containsKey('includePrivate')) {
      final l$includePrivate = data['includePrivate'];
      result$data['includePrivate'] = (l$includePrivate as bool?);
    }
    return Input$Query_Video_Options_Input._(result$data);
  }

  Map<String, dynamic> _$data;

  bool? get includePrivate => (_$data['includePrivate'] as bool?);

  Map<String, dynamic> toJson() {
    final result$data = <String, dynamic>{};
    final l$includePrivate = _$data.containsKey('includePrivate')
        ? includePrivate
        : null;
    result$data['includePrivate'] = l$includePrivate;
    return result$data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Input$Query_Video_Options_Input ||
        runtimeType != other.runtimeType) {
      return false;
    }
    final l$includePrivate = includePrivate;
    final lOther$includePrivate = other.includePrivate;
    if (_$data.containsKey('includePrivate') !=
        other._$data.containsKey('includePrivate')) {
      return false;
    }
    if (l$includePrivate != lOther$includePrivate) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final l$includePrivate = includePrivate;
    return Object.hashAll([
      _$data.containsKey('includePrivate') ? l$includePrivate : const {},
    ]);
  }
}

enum Enum$Badge_ImageURL_Size_Enum {
  DOUBLE,
  $unknown;

  factory Enum$Badge_ImageURL_Size_Enum.fromJson(String value) =>
      fromJson$Enum$Badge_ImageURL_Size_Enum(value);

  String toJson() => toJson$Enum$Badge_ImageURL_Size_Enum(this);
}

String toJson$Enum$Badge_ImageURL_Size_Enum(Enum$Badge_ImageURL_Size_Enum e) {
  switch (e) {
    case Enum$Badge_ImageURL_Size_Enum.DOUBLE:
      return r'DOUBLE';
    case Enum$Badge_ImageURL_Size_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Badge_ImageURL_Size_Enum fromJson$Enum$Badge_ImageURL_Size_Enum(
  String value,
) {
  switch (value) {
    case r'DOUBLE':
      return Enum$Badge_ImageURL_Size_Enum.DOUBLE;
    default:
      return Enum$Badge_ImageURL_Size_Enum.$unknown;
  }
}

enum Enum$Channel_Goals_States_Enum {
  ACTIVE,
  $unknown;

  factory Enum$Channel_Goals_States_Enum.fromJson(String value) =>
      fromJson$Enum$Channel_Goals_States_Enum(value);

  String toJson() => toJson$Enum$Channel_Goals_States_Enum(this);
}

String toJson$Enum$Channel_Goals_States_Enum(Enum$Channel_Goals_States_Enum e) {
  switch (e) {
    case Enum$Channel_Goals_States_Enum.ACTIVE:
      return r'ACTIVE';
    case Enum$Channel_Goals_States_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Channel_Goals_States_Enum fromJson$Enum$Channel_Goals_States_Enum(
  String value,
) {
  switch (value) {
    case r'ACTIVE':
      return Enum$Channel_Goals_States_Enum.ACTIVE;
    default:
      return Enum$Channel_Goals_States_Enum.$unknown;
  }
}

enum Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum {
  AVC,
  HEVC,
  $unknown;

  factory Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.fromJson(
    String value,
  ) => fromJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(value);

  String toJson() =>
      toJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(this);
}

String toJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(
  Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum e,
) {
  switch (e) {
    case Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.AVC:
      return r'AVC';
    case Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.HEVC:
      return r'HEVC';
    case Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum
fromJson$Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum(String value) {
  switch (value) {
    case r'AVC':
      return Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.AVC;
    case r'HEVC':
      return Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.HEVC;
    default:
      return Enum$ClipAsset_VideoQualities_SupportedCodecs_Enum.$unknown;
  }
}

enum Enum$Extension_ChallengeConditionParticipants_EndState_Enum {
  PENDING,
  $unknown;

  factory Enum$Extension_ChallengeConditionParticipants_EndState_Enum.fromJson(
    String value,
  ) => fromJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(
    value,
  );

  String toJson() =>
      toJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(this);
}

String toJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(
  Enum$Extension_ChallengeConditionParticipants_EndState_Enum e,
) {
  switch (e) {
    case Enum$Extension_ChallengeConditionParticipants_EndState_Enum.PENDING:
      return r'PENDING';
    case Enum$Extension_ChallengeConditionParticipants_EndState_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Extension_ChallengeConditionParticipants_EndState_Enum
fromJson$Enum$Extension_ChallengeConditionParticipants_EndState_Enum(
  String value,
) {
  switch (value) {
    case r'PENDING':
      return Enum$Extension_ChallengeConditionParticipants_EndState_Enum
          .PENDING;
    default:
      return Enum$Extension_ChallengeConditionParticipants_EndState_Enum
          .$unknown;
  }
}

enum Enum$Extension_ChallengeConditions_State_Enum {
  ACTIVE,
  $unknown;

  factory Enum$Extension_ChallengeConditions_State_Enum.fromJson(
    String value,
  ) => fromJson$Enum$Extension_ChallengeConditions_State_Enum(value);

  String toJson() => toJson$Enum$Extension_ChallengeConditions_State_Enum(this);
}

String toJson$Enum$Extension_ChallengeConditions_State_Enum(
  Enum$Extension_ChallengeConditions_State_Enum e,
) {
  switch (e) {
    case Enum$Extension_ChallengeConditions_State_Enum.ACTIVE:
      return r'ACTIVE';
    case Enum$Extension_ChallengeConditions_State_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Extension_ChallengeConditions_State_Enum
fromJson$Enum$Extension_ChallengeConditions_State_Enum(String value) {
  switch (value) {
    case r'ACTIVE':
      return Enum$Extension_ChallengeConditions_State_Enum.ACTIVE;
    default:
      return Enum$Extension_ChallengeConditions_State_Enum.$unknown;
  }
}

enum Enum$Game_Tags_TagType_Enum {
  CONTENT,
  $unknown;

  factory Enum$Game_Tags_TagType_Enum.fromJson(String value) =>
      fromJson$Enum$Game_Tags_TagType_Enum(value);

  String toJson() => toJson$Enum$Game_Tags_TagType_Enum(this);
}

String toJson$Enum$Game_Tags_TagType_Enum(Enum$Game_Tags_TagType_Enum e) {
  switch (e) {
    case Enum$Game_Tags_TagType_Enum.CONTENT:
      return r'CONTENT';
    case Enum$Game_Tags_TagType_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Game_Tags_TagType_Enum fromJson$Enum$Game_Tags_TagType_Enum(String value) {
  switch (value) {
    case r'CONTENT':
      return Enum$Game_Tags_TagType_Enum.CONTENT;
    default:
      return Enum$Game_Tags_TagType_Enum.$unknown;
  }
}

enum Enum$Query_FeedItems_FeedLocation_Enum {
  CLIPS,
  $unknown;

  factory Enum$Query_FeedItems_FeedLocation_Enum.fromJson(String value) =>
      fromJson$Enum$Query_FeedItems_FeedLocation_Enum(value);

  String toJson() => toJson$Enum$Query_FeedItems_FeedLocation_Enum(this);
}

String toJson$Enum$Query_FeedItems_FeedLocation_Enum(
  Enum$Query_FeedItems_FeedLocation_Enum e,
) {
  switch (e) {
    case Enum$Query_FeedItems_FeedLocation_Enum.CLIPS:
      return r'CLIPS';
    case Enum$Query_FeedItems_FeedLocation_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Query_FeedItems_FeedLocation_Enum
fromJson$Enum$Query_FeedItems_FeedLocation_Enum(String value) {
  switch (value) {
    case r'CLIPS':
      return Enum$Query_FeedItems_FeedLocation_Enum.CLIPS;
    default:
      return Enum$Query_FeedItems_FeedLocation_Enum.$unknown;
  }
}

enum Enum$Query_FeedItems_Ingress_Enum {
  BROWSE_CATEGORY_CLIP,
  $unknown;

  factory Enum$Query_FeedItems_Ingress_Enum.fromJson(String value) =>
      fromJson$Enum$Query_FeedItems_Ingress_Enum(value);

  String toJson() => toJson$Enum$Query_FeedItems_Ingress_Enum(this);
}

String toJson$Enum$Query_FeedItems_Ingress_Enum(
  Enum$Query_FeedItems_Ingress_Enum e,
) {
  switch (e) {
    case Enum$Query_FeedItems_Ingress_Enum.BROWSE_CATEGORY_CLIP:
      return r'BROWSE_CATEGORY_CLIP';
    case Enum$Query_FeedItems_Ingress_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Query_FeedItems_Ingress_Enum fromJson$Enum$Query_FeedItems_Ingress_Enum(
  String value,
) {
  switch (value) {
    case r'BROWSE_CATEGORY_CLIP':
      return Enum$Query_FeedItems_Ingress_Enum.BROWSE_CATEGORY_CLIP;
    default:
      return Enum$Query_FeedItems_Ingress_Enum.$unknown;
  }
}

enum Enum$Query_User_LookupType_Enum {
  ACTIVE,
  $unknown;

  factory Enum$Query_User_LookupType_Enum.fromJson(String value) =>
      fromJson$Enum$Query_User_LookupType_Enum(value);

  String toJson() => toJson$Enum$Query_User_LookupType_Enum(this);
}

String toJson$Enum$Query_User_LookupType_Enum(
  Enum$Query_User_LookupType_Enum e,
) {
  switch (e) {
    case Enum$Query_User_LookupType_Enum.ACTIVE:
      return r'ACTIVE';
    case Enum$Query_User_LookupType_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Query_User_LookupType_Enum fromJson$Enum$Query_User_LookupType_Enum(
  String value,
) {
  switch (value) {
    case r'ACTIVE':
      return Enum$Query_User_LookupType_Enum.ACTIVE;
    default:
      return Enum$Query_User_LookupType_Enum.$unknown;
  }
}

enum Enum$Self_Progress_Type_Enum {
  SUBD_GIFT_SUBS_WEB,
  $unknown;

  factory Enum$Self_Progress_Type_Enum.fromJson(String value) =>
      fromJson$Enum$Self_Progress_Type_Enum(value);

  String toJson() => toJson$Enum$Self_Progress_Type_Enum(this);
}

String toJson$Enum$Self_Progress_Type_Enum(Enum$Self_Progress_Type_Enum e) {
  switch (e) {
    case Enum$Self_Progress_Type_Enum.SUBD_GIFT_SUBS_WEB:
      return r'SUBD_GIFT_SUBS_WEB';
    case Enum$Self_Progress_Type_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Self_Progress_Type_Enum fromJson$Enum$Self_Progress_Type_Enum(
  String value,
) {
  switch (value) {
    case r'SUBD_GIFT_SUBS_WEB':
      return Enum$Self_Progress_Type_Enum.SUBD_GIFT_SUBS_WEB;
    default:
      return Enum$Self_Progress_Type_Enum.$unknown;
  }
}

enum Enum$Self_SubscriptionTenure_TenureMethod_Enum {
  CUMULATIVE,
  $unknown;

  factory Enum$Self_SubscriptionTenure_TenureMethod_Enum.fromJson(
    String value,
  ) => fromJson$Enum$Self_SubscriptionTenure_TenureMethod_Enum(value);

  String toJson() =>
      toJson$Enum$Self_SubscriptionTenure_TenureMethod_Enum(this);
}

String toJson$Enum$Self_SubscriptionTenure_TenureMethod_Enum(
  Enum$Self_SubscriptionTenure_TenureMethod_Enum e,
) {
  switch (e) {
    case Enum$Self_SubscriptionTenure_TenureMethod_Enum.CUMULATIVE:
      return r'CUMULATIVE';
    case Enum$Self_SubscriptionTenure_TenureMethod_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Self_SubscriptionTenure_TenureMethod_Enum
fromJson$Enum$Self_SubscriptionTenure_TenureMethod_Enum(String value) {
  switch (value) {
    case r'CUMULATIVE':
      return Enum$Self_SubscriptionTenure_TenureMethod_Enum.CUMULATIVE;
    default:
      return Enum$Self_SubscriptionTenure_TenureMethod_Enum.$unknown;
  }
}

enum Enum$User_ProgramAgreement_InvitationType_Enum {
  PAYOUT,
  $unknown;

  factory Enum$User_ProgramAgreement_InvitationType_Enum.fromJson(
    String value,
  ) => fromJson$Enum$User_ProgramAgreement_InvitationType_Enum(value);

  String toJson() =>
      toJson$Enum$User_ProgramAgreement_InvitationType_Enum(this);
}

String toJson$Enum$User_ProgramAgreement_InvitationType_Enum(
  Enum$User_ProgramAgreement_InvitationType_Enum e,
) {
  switch (e) {
    case Enum$User_ProgramAgreement_InvitationType_Enum.PAYOUT:
      return r'PAYOUT';
    case Enum$User_ProgramAgreement_InvitationType_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$User_ProgramAgreement_InvitationType_Enum
fromJson$Enum$User_ProgramAgreement_InvitationType_Enum(String value) {
  switch (value) {
    case r'PAYOUT':
      return Enum$User_ProgramAgreement_InvitationType_Enum.PAYOUT;
    default:
      return Enum$User_ProgramAgreement_InvitationType_Enum.$unknown;
  }
}

enum Enum$User_Videos_Sort_Enum {
  TIME,
  $unknown;

  factory Enum$User_Videos_Sort_Enum.fromJson(String value) =>
      fromJson$Enum$User_Videos_Sort_Enum(value);

  String toJson() => toJson$Enum$User_Videos_Sort_Enum(this);
}

String toJson$Enum$User_Videos_Sort_Enum(Enum$User_Videos_Sort_Enum e) {
  switch (e) {
    case Enum$User_Videos_Sort_Enum.TIME:
      return r'TIME';
    case Enum$User_Videos_Sort_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$User_Videos_Sort_Enum fromJson$Enum$User_Videos_Sort_Enum(String value) {
  switch (value) {
    case r'TIME':
      return Enum$User_Videos_Sort_Enum.TIME;
    default:
      return Enum$User_Videos_Sort_Enum.$unknown;
  }
}

enum Enum$User_Videos_Type_Enum {
  ARCHIVE,
  $unknown;

  factory Enum$User_Videos_Type_Enum.fromJson(String value) =>
      fromJson$Enum$User_Videos_Type_Enum(value);

  String toJson() => toJson$Enum$User_Videos_Type_Enum(this);
}

String toJson$Enum$User_Videos_Type_Enum(Enum$User_Videos_Type_Enum e) {
  switch (e) {
    case Enum$User_Videos_Type_Enum.ARCHIVE:
      return r'ARCHIVE';
    case Enum$User_Videos_Type_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$User_Videos_Type_Enum fromJson$Enum$User_Videos_Type_Enum(String value) {
  switch (value) {
    case r'ARCHIVE':
      return Enum$User_Videos_Type_Enum.ARCHIVE;
    default:
      return Enum$User_Videos_Type_Enum.$unknown;
  }
}

enum Enum$Video_Moments_MomentRequestType_Enum {
  VIDEO_CHAPTER_MARKERS,
  $unknown;

  factory Enum$Video_Moments_MomentRequestType_Enum.fromJson(String value) =>
      fromJson$Enum$Video_Moments_MomentRequestType_Enum(value);

  String toJson() => toJson$Enum$Video_Moments_MomentRequestType_Enum(this);
}

String toJson$Enum$Video_Moments_MomentRequestType_Enum(
  Enum$Video_Moments_MomentRequestType_Enum e,
) {
  switch (e) {
    case Enum$Video_Moments_MomentRequestType_Enum.VIDEO_CHAPTER_MARKERS:
      return r'VIDEO_CHAPTER_MARKERS';
    case Enum$Video_Moments_MomentRequestType_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Video_Moments_MomentRequestType_Enum
fromJson$Enum$Video_Moments_MomentRequestType_Enum(String value) {
  switch (value) {
    case r'VIDEO_CHAPTER_MARKERS':
      return Enum$Video_Moments_MomentRequestType_Enum.VIDEO_CHAPTER_MARKERS;
    default:
      return Enum$Video_Moments_MomentRequestType_Enum.$unknown;
  }
}

enum Enum$Video_Moments_Types_Enum {
  GAME_CHANGE,
  HEARTHSTONE_VCA,
  OVERWATCH_VCA,
  PUBG_VCA,
  $unknown;

  factory Enum$Video_Moments_Types_Enum.fromJson(String value) =>
      fromJson$Enum$Video_Moments_Types_Enum(value);

  String toJson() => toJson$Enum$Video_Moments_Types_Enum(this);
}

String toJson$Enum$Video_Moments_Types_Enum(Enum$Video_Moments_Types_Enum e) {
  switch (e) {
    case Enum$Video_Moments_Types_Enum.GAME_CHANGE:
      return r'GAME_CHANGE';
    case Enum$Video_Moments_Types_Enum.HEARTHSTONE_VCA:
      return r'HEARTHSTONE_VCA';
    case Enum$Video_Moments_Types_Enum.OVERWATCH_VCA:
      return r'OVERWATCH_VCA';
    case Enum$Video_Moments_Types_Enum.PUBG_VCA:
      return r'PUBG_VCA';
    case Enum$Video_Moments_Types_Enum.$unknown:
      return r'$unknown';
  }
}

Enum$Video_Moments_Types_Enum fromJson$Enum$Video_Moments_Types_Enum(
  String value,
) {
  switch (value) {
    case r'GAME_CHANGE':
      return Enum$Video_Moments_Types_Enum.GAME_CHANGE;
    case r'HEARTHSTONE_VCA':
      return Enum$Video_Moments_Types_Enum.HEARTHSTONE_VCA;
    case r'OVERWATCH_VCA':
      return Enum$Video_Moments_Types_Enum.OVERWATCH_VCA;
    case r'PUBG_VCA':
      return Enum$Video_Moments_Types_Enum.PUBG_VCA;
    default:
      return Enum$Video_Moments_Types_Enum.$unknown;
  }
}

enum Enum$__TypeKind {
  SCALAR,
  OBJECT,
  INTERFACE,
  UNION,
  ENUM,
  INPUT_OBJECT,
  LIST,
  NON_NULL,
  $unknown;

  factory Enum$__TypeKind.fromJson(String value) =>
      fromJson$Enum$__TypeKind(value);

  String toJson() => toJson$Enum$__TypeKind(this);
}

String toJson$Enum$__TypeKind(Enum$__TypeKind e) {
  switch (e) {
    case Enum$__TypeKind.SCALAR:
      return r'SCALAR';
    case Enum$__TypeKind.OBJECT:
      return r'OBJECT';
    case Enum$__TypeKind.INTERFACE:
      return r'INTERFACE';
    case Enum$__TypeKind.UNION:
      return r'UNION';
    case Enum$__TypeKind.ENUM:
      return r'ENUM';
    case Enum$__TypeKind.INPUT_OBJECT:
      return r'INPUT_OBJECT';
    case Enum$__TypeKind.LIST:
      return r'LIST';
    case Enum$__TypeKind.NON_NULL:
      return r'NON_NULL';
    case Enum$__TypeKind.$unknown:
      return r'$unknown';
  }
}

Enum$__TypeKind fromJson$Enum$__TypeKind(String value) {
  switch (value) {
    case r'SCALAR':
      return Enum$__TypeKind.SCALAR;
    case r'OBJECT':
      return Enum$__TypeKind.OBJECT;
    case r'INTERFACE':
      return Enum$__TypeKind.INTERFACE;
    case r'UNION':
      return Enum$__TypeKind.UNION;
    case r'ENUM':
      return Enum$__TypeKind.ENUM;
    case r'INPUT_OBJECT':
      return Enum$__TypeKind.INPUT_OBJECT;
    case r'LIST':
      return Enum$__TypeKind.LIST;
    case r'NON_NULL':
      return Enum$__TypeKind.NON_NULL;
    default:
      return Enum$__TypeKind.$unknown;
  }
}

enum Enum$__DirectiveLocation {
  QUERY,
  MUTATION,
  SUBSCRIPTION,
  FIELD,
  FRAGMENT_DEFINITION,
  FRAGMENT_SPREAD,
  INLINE_FRAGMENT,
  VARIABLE_DEFINITION,
  SCHEMA,
  SCALAR,
  OBJECT,
  FIELD_DEFINITION,
  ARGUMENT_DEFINITION,
  INTERFACE,
  UNION,
  ENUM,
  ENUM_VALUE,
  INPUT_OBJECT,
  INPUT_FIELD_DEFINITION,
  $unknown;

  factory Enum$__DirectiveLocation.fromJson(String value) =>
      fromJson$Enum$__DirectiveLocation(value);

  String toJson() => toJson$Enum$__DirectiveLocation(this);
}

String toJson$Enum$__DirectiveLocation(Enum$__DirectiveLocation e) {
  switch (e) {
    case Enum$__DirectiveLocation.QUERY:
      return r'QUERY';
    case Enum$__DirectiveLocation.MUTATION:
      return r'MUTATION';
    case Enum$__DirectiveLocation.SUBSCRIPTION:
      return r'SUBSCRIPTION';
    case Enum$__DirectiveLocation.FIELD:
      return r'FIELD';
    case Enum$__DirectiveLocation.FRAGMENT_DEFINITION:
      return r'FRAGMENT_DEFINITION';
    case Enum$__DirectiveLocation.FRAGMENT_SPREAD:
      return r'FRAGMENT_SPREAD';
    case Enum$__DirectiveLocation.INLINE_FRAGMENT:
      return r'INLINE_FRAGMENT';
    case Enum$__DirectiveLocation.VARIABLE_DEFINITION:
      return r'VARIABLE_DEFINITION';
    case Enum$__DirectiveLocation.SCHEMA:
      return r'SCHEMA';
    case Enum$__DirectiveLocation.SCALAR:
      return r'SCALAR';
    case Enum$__DirectiveLocation.OBJECT:
      return r'OBJECT';
    case Enum$__DirectiveLocation.FIELD_DEFINITION:
      return r'FIELD_DEFINITION';
    case Enum$__DirectiveLocation.ARGUMENT_DEFINITION:
      return r'ARGUMENT_DEFINITION';
    case Enum$__DirectiveLocation.INTERFACE:
      return r'INTERFACE';
    case Enum$__DirectiveLocation.UNION:
      return r'UNION';
    case Enum$__DirectiveLocation.ENUM:
      return r'ENUM';
    case Enum$__DirectiveLocation.ENUM_VALUE:
      return r'ENUM_VALUE';
    case Enum$__DirectiveLocation.INPUT_OBJECT:
      return r'INPUT_OBJECT';
    case Enum$__DirectiveLocation.INPUT_FIELD_DEFINITION:
      return r'INPUT_FIELD_DEFINITION';
    case Enum$__DirectiveLocation.$unknown:
      return r'$unknown';
  }
}

Enum$__DirectiveLocation fromJson$Enum$__DirectiveLocation(String value) {
  switch (value) {
    case r'QUERY':
      return Enum$__DirectiveLocation.QUERY;
    case r'MUTATION':
      return Enum$__DirectiveLocation.MUTATION;
    case r'SUBSCRIPTION':
      return Enum$__DirectiveLocation.SUBSCRIPTION;
    case r'FIELD':
      return Enum$__DirectiveLocation.FIELD;
    case r'FRAGMENT_DEFINITION':
      return Enum$__DirectiveLocation.FRAGMENT_DEFINITION;
    case r'FRAGMENT_SPREAD':
      return Enum$__DirectiveLocation.FRAGMENT_SPREAD;
    case r'INLINE_FRAGMENT':
      return Enum$__DirectiveLocation.INLINE_FRAGMENT;
    case r'VARIABLE_DEFINITION':
      return Enum$__DirectiveLocation.VARIABLE_DEFINITION;
    case r'SCHEMA':
      return Enum$__DirectiveLocation.SCHEMA;
    case r'SCALAR':
      return Enum$__DirectiveLocation.SCALAR;
    case r'OBJECT':
      return Enum$__DirectiveLocation.OBJECT;
    case r'FIELD_DEFINITION':
      return Enum$__DirectiveLocation.FIELD_DEFINITION;
    case r'ARGUMENT_DEFINITION':
      return Enum$__DirectiveLocation.ARGUMENT_DEFINITION;
    case r'INTERFACE':
      return Enum$__DirectiveLocation.INTERFACE;
    case r'UNION':
      return Enum$__DirectiveLocation.UNION;
    case r'ENUM':
      return Enum$__DirectiveLocation.ENUM;
    case r'ENUM_VALUE':
      return Enum$__DirectiveLocation.ENUM_VALUE;
    case r'INPUT_OBJECT':
      return Enum$__DirectiveLocation.INPUT_OBJECT;
    case r'INPUT_FIELD_DEFINITION':
      return Enum$__DirectiveLocation.INPUT_FIELD_DEFINITION;
    default:
      return Enum$__DirectiveLocation.$unknown;
  }
}

const possibleTypesMap = <String, Set<String>>{
  'Fragment': {
    'ActivityFeedAlertMessageCheermoteFragment',
    'ActivityFeedAlertMessageEmoteFragment',
    'ActivityFeedAlertMessageEmoteNotFound',
    'ActivityFeedAlertMessageTextFragment',
  },
  'ActivityFeedAlert': {
    'ActivityFeedBitsSpendAlert',
    'ActivityFeedChannelPointsRedemptionAlert',
    'ActivityFeedCharityDonationAlert',
    'ActivityFeedCheerAlert',
    'ActivityFeedCombosAlert',
    'ActivityFeedCommunityGiftSubscriptionAlert',
    'ActivityFeedCreatorGoalAlert',
    'ActivityFeedCrowdControlAlert',
    'ActivityFeedFollowAlert',
    'ActivityFeedHostAlert',
    'ActivityFeedHypeTrainAlert',
    'ActivityFeedIndividualGiftSubscriptionAlert',
    'ActivityFeedPaidUpgradeSubscriptionAlert',
    'ActivityFeedPrimeResubscriptionAlert',
    'ActivityFeedPrimeSubscriptionAlert',
    'ActivityFeedRaidAlert',
    'ActivityFeedResubscriptionAlert',
    'ActivityFeedStreamElementsAlert',
    'ActivityFeedStreamLabsAlert',
    'ActivityFeedSubscriptionAlert',
    'ActivityFeedThroneAlert',
  },
  'Token': {
    'ActivityFeedCheermote',
    'ActivityFeedIntegerToken',
    'ActivityFeedPercentToken',
    'ActivityFeedTextToken',
    'Emote',
    'User',
    'UserDoesNotExist',
    'UserError',
  },
  'ActivityFeedEventDetails': {
    'ActivityFeedEventDetailAssets',
    'ActivityFeedEventDetailList',
  },
  'Value': {
    'ActivityFeedEventDetailItemNumber',
    'ActivityFeedEventDetailItemPercentage',
  },
  'AdProperty': {'AdProperties'},
  'BitsOffer': {'BitsAdOffer', 'BitsBundleOffer'},
  'BitsSpendAlertData': {
    'BitsSpendAutomaticPowerUpData',
    'BitsSpendCheerData',
    'BitsSpendCustomPowerUpData',
  },
  'TitleTokenEdge_Node': {
    'BrowsableCollection',
    'DateToken',
    'Game',
    'IntegerToken',
    'Tag',
    'TextToken',
    'User',
  },
  'Contribution': {
    'ChannelGoalIntegerContributions',
    'ChannelGoalMoneyContributions',
  },
  'OnsiteNotificationContent': {
    'Clip',
    'DropCampaign',
    'EventBasedDrop',
    'Game',
    'ManualTriggerBasedDrop',
    'OnsiteNotificationExternalLink',
    'Story',
    'Subfeed',
    'TimeBasedDrop',
    'User',
    'Video',
    'VideoComment',
  },
  'ShelfContentEdge_Node': {
    'Clip',
    'Directory',
    'Game',
    'StoryPreview',
    'Stream',
    'Tag',
    'User',
    'Video',
  },
  'VideoQuality': {'ClipVideoQuality'},
  'VariantTrainDetails': {'CommunityTrainDetails', 'MythicTrainDetails'},
  'CostreamDetail': {'CostreamDetails'},
  'Data': {
    'CrowdControlEffectData',
    'CrowdControlExchangeData',
    'CrowdControlPoolData',
    'StreamLabsCharityDonationData',
    'StreamLabsMediaData',
    'StreamLabsMerchData',
    'StreamLabsTipData',
    'ThroneBadgeEarnedData',
    'ThroneContributionPurchasedData',
    'ThroneGiftData',
  },
  'ReactionAsset': {'Emote'},
  'VendorConsent': {'GDPRVendorConsent'},
  'ChannelCollab': {'GuestStarChannelCollaboration'},
  'HypeTrainReward': {'HypeTrainBadgeReward', 'HypeTrainEmoteReward'},
  'Status': {'NonTCFCookieVendor', 'TCFCookieVendor'},
  'ProductConsent': {'ProductConsentError', 'UserConsent'},
  'Content': {
    'SearchSuggestionCategory',
    'SearchSuggestionChannel',
    'SearchSuggestionCollection',
  },
  'StoryBaseLayerDataBlock': {
    'StoryClipBlock',
    'StoryGradientBackgroundBlock',
    'StoryImageBackgroundBlock',
    'StoryReshareBackgroundBlock',
    'StoryTwitchImageBackgroundBlock',
  },
  'Body': {'StoryEmoteToken', 'StoryPlainTextToken'},
  'StoryTextToken': {
    'StoryEmoteToken',
    'StoryMentionToken',
    'StoryPlainTextToken',
  },
  'StoryInteractiveLayerDataBlock': {
    'StoryMentionStickerBlock',
    'StoryStickerBlock',
    'StoryTextBlock',
  },
  'Curator': {'User'},
  'UserResultByLogin': {'User', 'UserDoesNotExist', 'UserError'},
  'VideoEdge_Node': {'Video'},
  'MutedSegmentConnection_Node': {'VideoMutedSegment'},
};
