// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../aggregation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AggregateNodeRef _$AggregateNodeRefFromJson(Map<String, dynamic> json) =>
    _AggregateNodeRef(
      sourceId: (json['sourceId'] as num).toInt(),
      provider: json['provider'] as String? ?? '',
      fingerprint: json['fingerprint'] as String,
      name: json['name'] as String,
    );

Map<String, dynamic> _$AggregateNodeRefToJson(_AggregateNodeRef instance) =>
    <String, dynamic>{
      'sourceId': instance.sourceId,
      'provider': instance.provider,
      'fingerprint': instance.fingerprint,
      'name': instance.name,
    };

_ProxyChain _$ProxyChainFromJson(Map<String, dynamic> json) => _ProxyChain(
  id: json['id'] as String,
  name: json['name'] as String,
  entry: AggregateNodeRef.fromJson(json['entry'] as Map<String, dynamic>),
  exit: AggregateNodeRef.fromJson(json['exit'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProxyChainToJson(_ProxyChain instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'entry': instance.entry,
      'exit': instance.exit,
    };

_AggregateConfig _$AggregateConfigFromJson(Map<String, dynamic> json) =>
    _AggregateConfig(
      baseProfileId: (json['baseProfileId'] as num?)?.toInt(),
      sourceIds:
          (json['sourceIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          const {},
      targetGroup: json['targetGroup'] as String? ?? '',
      groupName: json['groupName'] as String? ?? 'Aggregate',
      chains:
          (json['chains'] as List<dynamic>?)
              ?.map((e) => ProxyChain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AggregateConfigToJson(_AggregateConfig instance) =>
    <String, dynamic>{
      'baseProfileId': instance.baseProfileId,
      'sourceIds': instance.sourceIds.toList(),
      'targetGroup': instance.targetGroup,
      'groupName': instance.groupName,
      'chains': instance.chains,
    };

_AggregateWorkspace _$AggregateWorkspaceFromJson(Map<String, dynamic> json) =>
    _AggregateWorkspace(
      profileId: (json['profileId'] as num?)?.toInt(),
      draft: json['draft'] == null
          ? const AggregateConfig()
          : AggregateConfig.fromJson(json['draft'] as Map<String, dynamic>),
      favorites:
          (json['favorites'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
    );

Map<String, dynamic> _$AggregateWorkspaceToJson(_AggregateWorkspace instance) =>
    <String, dynamic>{
      'profileId': instance.profileId,
      'draft': instance.draft,
      'favorites': instance.favorites.toList(),
    };
