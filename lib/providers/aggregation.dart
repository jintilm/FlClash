import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show join, isWithin;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers.dart';

part 'generated/aggregation.g.dart';

@riverpod
({int profileId, AggregateConfig settings})? aggregateRouteContext(Ref ref) {
  final profile = ref.watch(currentProfileProvider);
  final settings = profile?.aggregate;
  if (profile == null || settings == null) {
    return null;
  }
  return (profileId: profile.id, settings: settings);
}

@Riverpod(keepAlive: true)
class AggregateRuntime extends _$AggregateRuntime {
  @override
  ({int? profileId, AggregateConfig? settings, bool applied, String? error})
  build() {
    ref.listen(coreStatusProvider, (_, next) {
      if (next != CoreStatus.connected) {
        state = (
          profileId: state.profileId,
          settings: state.settings,
          applied: false,
          error: state.error,
        );
      }
    });
    return (profileId: null, settings: null, applied: false, error: null);
  }

  void record(
    int profileId,
    AggregateConfig? settings,
    bool applied, [
    String? error,
  ]) {
    state = (
      profileId: profileId,
      settings: settings,
      applied: applied,
      error: error,
    );
  }
}

@riverpod
Future<AggregateSource> aggregateSource(Ref ref, int id) async {
  if (id == 0) {
    final proxies = await ref.watch(customProxiesProvider.future);
    return AggregateSource(
      id: 0,
      label: currentAppLocalizations.localProxies,
      nodes: [
        for (final proxy in proxies)
          ...aggregateNodes(
            sourceId: 0,
            label: currentAppLocalizations.localProxies,
            provider: '${proxy.id}',
            definitions: [proxy.definition],
          ),
      ],
    );
  }
  final profile = ref.watch(profileProvider(id));
  if (profile == null || profile.type == ProfileType.aggregate) {
    throw AggregateException(AggregateIssue.missingSource, '$id');
  }
  ref.watch(
    scriptsProvider.select(
      (value) => value.value?.firstWhereOrNull(
        (script) => script.id == profile.scriptId,
      ),
    ),
  );
  final reader = ref.read(aggregateActionProvider.notifier);
  if (profile.type == ProfileType.custom) {
    ref.watch(proxyGroupsProvider(id));
    ref.watch(profileRulesProvider(id));
    ref.watch(proxyDialersProvider(id));
    ref.watch(customProxiesProvider);
  }
  try {
    final config = await reader.sourceConfig(profile);
    return await reader.readSource(id, profile.realLabel, config);
  } catch (error) {
    return AggregateSource(
      id: id,
      label: profile.realLabel,
      errors: [error.toString()],
    );
  }
}

@Riverpod(keepAlive: true)
class AggregateAction extends _$AggregateAction {
  bool _applying = false;
  int? _selectingId;

  bool handlesSelection(int? id) => id != null && id == _selectingId;

  @override
  void build() {}

  void initialize([int? profileId]) {
    final workspace = ref.read(aggregateWorkspaceSettingProvider);
    final profiles = ref.read(profilesProvider);
    final selected = profiles.getProfile(
      profileId ?? ref.read(currentProfileIdProvider),
    );
    if (selected?.aggregate case final settings?) {
      if (workspace.profileId != selected!.id) {
        ref.read(aggregateWorkspaceSettingProvider.notifier).value = workspace
            .copyWith(profileId: selected.id, draft: settings);
      }
      return;
    }
    if (workspace.draft.baseProfileId != null) return;
    final base =
        selected ??
        profiles.firstWhereOrNull((p) => p.type != ProfileType.aggregate);
    if (base == null) return;
    setDraft(
      AggregateConfig(
        baseProfileId: base.id,
        sourceIds: {base.id},
        groupName: currentAppLocalizations.aggregateSelection,
      ),
    );
  }

  void setDraft(AggregateConfig value) {
    ref
        .read(aggregateWorkspaceSettingProvider.notifier)
        .update((state) => state.copyWith(draft: value));
  }

  void toggleFavorite(String key) {
    ref.read(aggregateWorkspaceSettingProvider.notifier).update((state) {
      final favorites = {...state.favorites};
      if (!favorites.remove(key)) favorites.add(key);
      return state.copyWith(favorites: favorites);
    });
  }

  Future<Map<String, dynamic>> sourceConfig(Profile profile) async {
    if (profile.type == ProfileType.custom) {
      final state = await readSetupState(ref.container, profile.id);
      final built = await ref
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: state,
            patchConfig: ref.read(patchClashConfigProvider),
          );
      return compute(_decodeConfig, built.yaml);
    }
    var config = await ref.read(coreHandlerProvider).readConfig(profile.id);
    if (profile.scriptId case final id?) {
      final script = await database.scriptsDao.get(id).getSingleOrNull();
      final content = await script?.content;
      if (content != null && content.isNotEmpty) {
        config = await handleEvaluate(content, config);
      }
    }
    return config;
  }

  Future<AggregateSource> readSource(
    int id,
    String label,
    Map<String, dynamic> config, {
    bool refresh = false,
  }) async {
    final definitions = <String, List<Map<String, dynamic>>>{
      '': aggregateMappings(config['proxies']),
    };
    final errors = <String>[];
    final providers = config['proxy-providers'];
    if (providers is Map) {
      for (final entry in providers.entries) {
        if (entry.value is! Map) continue;
        final name = entry.key as String;
        final definition = Map<String, dynamic>.from(entry.value as Map);
        if (definition['type'] != 'inline') {
          final url = definition['url'];
          final key = url is String && url.isNotEmpty
              ? '$name@$url'
              : 'proxy-providers/$name';
          final existingPath = definition['path'];
          if (existingPath is! String ||
              !isWithin(await appPath.profilesPath, existingPath)) {
            definition['path'] = join(
              await appPath.getProviderDirPath(
                id,
                proxiesProviderDirectoryName,
              ),
              key.toMd5(),
            );
          }
        }
        try {
          definitions[name] = await ref
              .read(coreHandlerProvider)
              .providerSnapshot(definition, refresh: refresh);
        } catch (error) {
          errors.add(
            '$name: ${userFacingErrorMessage(error, currentAppLocalizations)}',
          );
        }
      }
    }
    return compute(_makeSource, (
      id: id,
      label: label,
      definitions: definitions,
      errors: errors,
    ));
  }

  Future<void> refreshSource(int id) async {
    if (id == 0) {
      ref.invalidate(aggregateSourceProvider(id));
      return;
    }
    final profile = ref.read(profileProvider(id));
    if (profile == null) return;
    if (profile.type == ProfileType.url) {
      await ref
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }
    final result = await readSource(
      id,
      profile.realLabel,
      await sourceConfig(profile),
      refresh: true,
    );
    ref.invalidate(aggregateSourceProvider(id));
    if (result.errors.isNotEmpty) {
      throw MessageException(result.errors.join('\n'));
    }
    final aggregate = ref.read(currentProfileProvider)?.aggregate;
    if (aggregate != null &&
        (aggregate.baseProfileId == id || aggregate.sourceIds.contains(id))) {
      ref
          .read(setupActionProvider.notifier)
          .applyProfileDebounce(silence: true);
    }
  }

  Future<BuiltProfile> buildProfile(
    AggregateConfig settings,
    SetupState baseState,
    PatchClashConfig patchConfig,
  ) async {
    final setup = ref.read(setupActionProvider.notifier);
    final built = await setup.getProfile(
      setupState: baseState,
      patchConfig: patchConfig,
    );
    final core = ref.read(coreHandlerProvider);
    final base = await compute(
      _decodeConfig,
      built.base == null ? built.yaml : await core.buildProfile(built.base!),
    );
    final filtered = <String, List<String>>{};
    for (final value in base['proxy-groups'] as List? ?? const []) {
      if (value is! Map ||
          !(value['include-all'] == true ||
              value['include-all-proxies'] == true)) {
        continue;
      }
      final filter = value['filter'];
      if (filter is! String || filter.isEmpty) continue;
      var matches = filtered[filter];
      if (matches == null) {
        final nodes = await core.providerSnapshot({
          'type': 'inline',
          'payload': base['proxies'] ?? const [],
          'filter': filter,
        });
        matches = nodes.map((node) => node['name'] as String).toList()..sort();
        filtered[filter] = matches;
      }
      value['proxies'] = [...?value['proxies'] as List?, ...matches];
      if (value['include-all'] == true) value['include-all-providers'] = true;
      value.remove('include-all');
      value.remove('include-all-proxies');
    }
    final profiles = ref.read(profilesProvider);
    final baseProfile = profiles.getProfile(settings.baseProfileId);
    if (baseProfile == null) {
      throw const AggregateException(AggregateIssue.missingBase);
    }
    final sources = <AggregateSource>[
      await readSource(baseProfile.id, baseProfile.realLabel, base),
    ];
    for (final id in settings.sourceIds.where((id) => id != baseProfile.id)) {
      sources.add(await ref.read(aggregateSourceProvider(id).future));
    }
    final config = await compute(composeAggregate, (
      interfaces: await networkInterfaceNames(),
      settings: settings,
      base: base,
      sources: sources,
    ));
    final yaml = await encodeYamlTask(config);
    return (
      yaml: yaml,
      md5: yaml.toMd5(),
      counts: configCountsOf(config),
      base: null,
    );
  }

  Future<void> apply({String? chainId}) async {
    if (_applying) return;
    _applying = true;
    try {
      final workspace = ref.read(aggregateWorkspaceSettingProvider);
      final previousSelection = ref.read(currentProfileIdProvider);
      final settings = workspace.draft;
      final profiles = ref.read(profilesProvider);
      final base = profiles.getProfile(settings.baseProfileId);
      if (base == null || base.type == ProfileType.aggregate) {
        throw const AggregateException(AggregateIssue.missingBase);
      }
      final baseState = await readSetupState(ref.container, base.id);
      final built = await buildProfile(
        settings,
        baseState,
        ref.read(patchClashConfigProvider),
      );
      final error = await ref
          .read(coreHandlerProvider)
          .validateConfigWithData(utf8.encode(built.yaml));
      if (error != null) throw MessageException(error);
      final previous = profiles.getProfile(workspace.profileId);
      if (ref.read(currentProfileIdProvider) != previousSelection ||
          ref.read(aggregateWorkspaceSettingProvider).draft != settings) {
        throw MessageException(currentAppLocalizations.aggregatePending);
      }
      final candidate =
          (previous ??
                  Profile(
                    id: snowflake.id,
                    type: ProfileType.aggregate,
                    label: currentAppLocalizations.aggregateProfile,
                    autoUpdate: false,
                    autoUpdateDuration: defaultUpdateDuration,
                  ))
              .copyWith(
                aggregate: settings,
                lastUpdateDate: DateTime.now(),
                selectedMap: aggregateSelectedMap(
                  settings,
                  previous?.selectedMap ?? base.selectedMap,
                  chainId: chainId,
                ),
              );
      await ref.read(profilesProvider.notifier).save(candidate);
      if (ref.read(currentProfileIdProvider) != previousSelection) {
        throw MessageException(currentAppLocalizations.aggregateInactive);
      }
      _selectingId = candidate.id;
      try {
        ref.read(currentProfileIdProvider.notifier).value = candidate.id;
      } finally {
        _selectingId = null;
      }
      bool success;
      try {
        success = await ref
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);
      } catch (_) {
        success = false;
      }
      if (!success) {
        if (previous != null) {
          await ref.read(profilesProvider.notifier).save(previous);
        } else {
          await ref.read(profilesProvider.notifier).del(candidate.id);
        }
        if (ref.read(currentProfileIdProvider) == candidate.id) {
          ref.read(currentProfileIdProvider.notifier).value = previousSelection;
          await ref
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);
        }
        throw MessageException(currentAppLocalizations.aggregateApplyFailed);
      }
      ref
          .read(aggregateWorkspaceSettingProvider.notifier)
          .update((state) => state.copyWith(profileId: candidate.id));
    } on AggregateException catch (error) {
      throw MessageException(aggregateErrorMessage(error));
    } finally {
      _applying = false;
    }
  }
}

Map<String, dynamic> _decodeConfig(String content) =>
    Map<String, dynamic>.from(loadPlainYaml(content) as Map);

AggregateSource _makeSource(
  ({
    int id,
    String label,
    Map<String, List<Map<String, dynamic>>> definitions,
    List<String> errors,
  })
  input,
) => AggregateSource(
  id: input.id,
  label: input.label,
  nodes: [
    for (final entry in input.definitions.entries)
      ...aggregateNodes(
        sourceId: input.id,
        label: input.label,
        provider: entry.key,
        definitions: entry.value,
      ),
  ],
  errors: input.errors,
);

String aggregateErrorMessage(AggregateException error) {
  final l = currentAppLocalizations;
  final message = switch (error.issue) {
    AggregateIssue.missingBase => l.aggregateMissingBase,
    AggregateIssue.missingSource => l.aggregateMissingSource,
    AggregateIssue.sourceUnavailable => l.aggregateSourceUnavailable,
    AggregateIssue.missingGroup => l.aggregateMissingGroup,
    AggregateIssue.empty => l.aggregateNoNodes,
    AggregateIssue.missingNode => l.aggregateRepair,
    AggregateIssue.duplicateName => l.aggregateDuplicateName,
    AggregateIssue.existingDialer => l.aggregateExistingDialer,
    AggregateIssue.sameHop => l.aggregateSameHop,
    AggregateIssue.udpEntry => l.aggregateUdpEntry,
    AggregateIssue.cycle => l.aggregateCycle,
    AggregateIssue.dnsBootstrap => l.aggregateDnsBootstrap,
    AggregateIssue.missingDnsProxy => l.aggregateMissingDnsProxy,
  };
  return error.detail.isEmpty ? message : '$message: ${error.detail}';
}
