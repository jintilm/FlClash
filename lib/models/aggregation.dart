import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/aggregation.freezed.dart';
part 'generated/aggregation.g.dart';

const maxAggregateHops = 5;

@freezed
abstract class AggregateNodeRef with _$AggregateNodeRef {
  const factory AggregateNodeRef({
    required int sourceId,
    @Default('') String provider,
    required String fingerprint,
    required String name,
  }) = _AggregateNodeRef;

  factory AggregateNodeRef.fromJson(Map<String, dynamic> json) =>
      _$AggregateNodeRefFromJson(json);
}

@freezed
abstract class ProxyChain with _$ProxyChain {
  const factory ProxyChain({
    required String id,
    required String name,
    required AggregateNodeRef entry,
    required AggregateNodeRef exit,
    @Default([]) List<AggregateNodeRef> relays,
  }) = _ProxyChain;

  factory ProxyChain.fromJson(Map<String, dynamic> json) =>
      _$ProxyChainFromJson(json);
}

extension ProxyChainExt on ProxyChain {
  List<AggregateNodeRef> get hops => [entry, ...relays, exit];
}

@freezed
abstract class AggregateConfig with _$AggregateConfig {
  const factory AggregateConfig({
    int? baseProfileId,
    @Default({}) Set<int> sourceIds,
    @Default('') String targetGroup,
    @Default('Aggregate') String groupName,
    @Default([]) List<ProxyChain> chains,
  }) = _AggregateConfig;

  factory AggregateConfig.fromJson(Map<String, dynamic> json) =>
      _$AggregateConfigFromJson(json);
}

@freezed
abstract class AggregateWorkspace with _$AggregateWorkspace {
  const factory AggregateWorkspace({
    int? profileId,
    @Default(AggregateConfig()) AggregateConfig draft,
    @Default({}) Set<String> favorites,
  }) = _AggregateWorkspace;

  factory AggregateWorkspace.fromJson(Map<String, dynamic> json) =>
      _$AggregateWorkspaceFromJson(json);
}

extension AggregateNodeRefExt on AggregateNodeRef {
  String get key => '$sourceId/$provider/$fingerprint';
}
