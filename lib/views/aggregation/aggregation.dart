import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chain_editor.dart';
import 'delay_button.dart';

class AggregateProxiesView extends ConsumerStatefulWidget {
  const AggregateProxiesView({super.key, this.profileId});

  final int? profileId;

  @override
  ConsumerState<AggregateProxiesView> createState() =>
      _AggregateProxiesViewState();
}

class _AggregateProxiesViewState extends ConsumerState<AggregateProxiesView> {
  bool _chains = false;
  bool _busy = false;
  bool _testing = false;
  bool _favoritesOnly = false;
  int? _source;
  String? _protocol;
  SearchQuery _query = SearchQuery('');

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        ref.read(aggregateActionProvider.notifier).initialize(widget.profileId);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await globalState.safeRun(action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testAll(List<AggregateDelayTarget> targets) async {
    if (_testing) return;
    final pending = {
      for (final target in targets.where((target) => target.testable))
        target.key: target,
    }.values.iterator;
    Future<void> worker() async {
      while (mounted && pending.moveNext()) {
        final target = pending.current;
        await ref
            .read(aggregateDelayTestProvider(target.key).notifier)
            .test(target);
      }
    }

    setState(() => _testing = true);
    try {
      await Future.wait([
        for (var i = 0; i < maxConcurrentDelayTests && i < targets.length; i++)
          worker(),
      ]);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pickBase(List<Profile> profiles) async {
    final chosen = await showNestedSheet<int>(
      context,
      builder: (context) => SelectionSheet<int>(
        title: context.appLocalizations.aggregateBase,
        sections: [SelectionSection(items: profiles.map((p) => p.id).toList())],
        labelBuilder: (id) => profiles.firstWhere((p) => p.id == id).realLabel,
        selectedOf: (ref) =>
            ref.watch(aggregateWorkspaceSettingProvider).draft.baseProfileId,
        onSelected: (id) => Navigator.of(context).pop(id),
      ),
    );
    if (chosen == null || !mounted) return;
    final draft = ref.read(aggregateWorkspaceSettingProvider).draft;
    ref
        .read(aggregateActionProvider.notifier)
        .setDraft(
          draft.copyWith(
            baseProfileId: chosen,
            sourceIds: {...draft.sourceIds, chosen},
            targetGroup: '',
          ),
        );
  }

  Future<void> _pickGroup(AggregateConfig draft) async {
    final profile = ref.read(profileProvider(draft.baseProfileId));
    if (profile == null) return;
    await _run(() async {
      final config = await ref
          .read(aggregateActionProvider.notifier)
          .sourceConfig(profile);
      final groups = aggregateMappings(config['proxy-groups'])
          .where((g) => g['type'] == 'select')
          .map((g) => g['name'] as String)
          .toList();
      if (!mounted) return;
      final chosen = await showNestedSheet<String>(
        context,
        builder: (context) => SelectionSheet<String>(
          title: context.appLocalizations.aggregateTarget,
          emptyLabel: context.appLocalizations.aggregateMissingGroup,
          sections: [SelectionSection(items: groups)],
          labelBuilder: (name) => name,
          selectedOf: (_) => draft.targetGroup,
          onSelected: (name) => Navigator.of(context).pop(name),
        ),
      );
      if (chosen != null && mounted) {
        ref
            .read(aggregateActionProvider.notifier)
            .setDraft(
              ref
                  .read(aggregateWorkspaceSettingProvider)
                  .draft
                  .copyWith(targetGroup: chosen),
            );
      }
    });
  }

  Future<void> _editChain(
    List<AggregateNode> nodes, {
    ProxyChain? chain,
    AggregateNode? entry,
    AggregateNode? exit,
  }) async {
    final result = await showFormSheet<ProxyChain>(
      context: context,
      builder: (_) => AggregateChainEditor(
        nodes: nodes,
        chain: chain,
        entry: entry?.ref,
        exit: exit?.ref,
      ),
    );
    if (result == null || !mounted) return;
    final draft = ref.read(aggregateWorkspaceSettingProvider).draft;
    ref
        .read(aggregateActionProvider.notifier)
        .setDraft(
          draft.copyWith(
            chains: [
              for (final item in draft.chains)
                if (item.id != result.id) item,
              result,
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final workspace = ref.watch(aggregateWorkspaceSettingProvider);
    final draft = workspace.draft;
    final profiles = ref
        .watch(profilesProvider)
        .where((p) => p.type != ProfileType.aggregate)
        .toList();
    final sourceProfiles = profiles
        .where(
          (p) => p.type != ProfileType.custom || p.id == draft.baseProfileId,
        )
        .toList();
    final sources = <int, AsyncValue<AggregateSource>>{
      for (final profile in sourceProfiles)
        profile.id: ref.watch(aggregateSourceProvider(profile.id)),
      0: ref.watch(aggregateSourceProvider(0)),
    };
    final baseReferences = <String, AggregateNode>{};
    final baseSource = sources[draft.baseProfileId]?.value;
    if (profiles
            .firstWhereOrNull((profile) => profile.id == draft.baseProfileId)
            ?.type ==
        ProfileType.custom) {
      for (final node in baseSource?.nodes ?? const <AggregateNode>[]) {
        baseReferences.putIfAbsent(node.ref.fingerprint, () => node);
      }
    }
    final allNodes = <AggregateNode>[];
    final displayed = <String>{};
    for (final source in sources.values) {
      for (final node in source.value?.nodes ?? const <AggregateNode>[]) {
        final effective = baseReferences[node.ref.fingerprint] ?? node;
        if (displayed.add(effective.ref.key)) allNodes.add(effective);
      }
    }
    final included = {...draft.sourceIds, ?draft.baseProfileId};
    final chainNodes = allNodes
        .where((node) => included.contains(node.ref.sourceId))
        .toList();
    final availableChainNodes = {
      for (final node in chainNodes) node.ref.key: node,
    };
    AggregateDelayTarget? chainTarget(ProxyChain chain) {
      final entry = availableChainNodes[chain.entry.key];
      final exit = availableChainNodes[chain.exit.key];
      return entry == null || exit == null
          ? null
          : AggregateDelayTarget([entry, exit]);
    }

    final nodes = allNodes
        .where(
          (node) =>
              (_source == null || node.ref.sourceId == _source) &&
              (_protocol == null || node.type == _protocol) &&
              (!_favoritesOnly || workspace.favorites.contains(node.ref.key)),
        )
        .whereMatches(
          _query,
          (node) => [node.name, node.sourceLabel, node.type],
        )
        .toList();
    final applied = ref.watch(profileProvider(workspace.profileId));
    final currentId = ref.watch(currentProfileIdProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final runtime = ref.watch(aggregateRuntimeProvider);
    final runtimeApplied =
        runtime.applied &&
        runtime.profileId == currentId &&
        runtime.settings == draft;
    final status = applied?.aggregate == draft
        ? (currentId == applied?.id && runtimeApplied
              ? l.aggregateApplied
              : l.aggregateInactive)
        : (applied == null ? l.aggregateNotApplied : l.aggregatePending);
    final base = profiles.firstWhereOrNull(
      (profile) => profile.id == draft.baseProfileId,
    );
    final errors = [
      for (final entry in sources.entries)
        if (entry.value.hasError ||
            (entry.value.value?.errors.isNotEmpty ?? false))
          entry.key,
    ];
    final testTargets = _chains
        ? [for (final chain in draft.chains) ?chainTarget(chain)]
        : [
            for (final node in nodes) AggregateDelayTarget([node]),
          ];
    return Scaffold(
      title: l.aggregateProxies,
      isLoading: _busy,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.checkCircle,
        tooltip: l.aggregateApply,
        onPressed: _busy
            ? null
            : () => _run(
                () => ref.read(aggregateActionProvider.notifier).apply(),
              ),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sync,
          tooltip: l.update,
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final failures = <String>[];
                  for (final id in sources.keys) {
                    try {
                      await ref
                          .read(aggregateActionProvider.notifier)
                          .refreshSource(id);
                    } catch (error) {
                      failures.add(error.toString());
                    }
                  }
                  if (failures.isNotEmpty) {
                    throw MessageException(failures.join('\n'));
                  }
                }),
        ),
        if (_chains)
          IconButtonData(
            glyph: AppGlyphs.addCircle,
            tooltip: l.aggregateNewChain,
            onPressed: _busy ? null : () => _editChain(chainNodes),
          ),
      ],
      menuItems: [
        PopupMenuItem(
          label: l.aggregateSources,
          glyph: AppGlyphs.profiles,
          onPressed: () =>
              showNestedSheet(context, builder: (_) => const _SourcesSheet()),
        ),
        PopupMenuItem(
          label: l.aggregateSourceFilter,
          glyph: AppGlyphs.filter,
          subItems: [
            PopupMenuItem(
              label: l.aggregateAllNodes,
              checked: _source == null,
              onPressed: () => setState(() => _source = null),
            ),
            for (final entry in sources.entries)
              PopupMenuItem(
                label: entry.value.value?.label ?? '${entry.key}',
                checked: _source == entry.key,
                onPressed: () => setState(() => _source = entry.key),
              ),
          ],
        ),
        PopupMenuItem(
          label: l.aggregateProtocol,
          subItems: [
            PopupMenuItem(
              label: l.aggregateAllNodes,
              checked: _protocol == null,
              onPressed: () => setState(() => _protocol = null),
            ),
            for (final type
                in allNodes.map((node) => node.type).toSet().sorted())
              PopupMenuItem(
                label: type,
                checked: _protocol == type,
                onPressed: () => setState(() => _protocol = type),
              ),
          ],
        ),
        PopupMenuItem(
          label: l.aggregateFavorites,
          glyph: AppGlyphs.star,
          checked: _favoritesOnly,
          onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
        ),
      ],
      searchState: _chains
          ? null
          : AppBarSearchState(
              onSearch: (value) => setState(() => _query = SearchQuery(value)),
            ),
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                context.contentTopPadding,
                16,
                12,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Text(status, style: AppTextStyle.footnote.of(context)),
                    if (runtime.profileId == workspace.profileId &&
                        runtime.error != null)
                      Text(
                        runtime.error!,
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: context.colorScheme.error),
                      ),
                    generateGroup([
                      FormRow(
                        title: l.aggregateBase,
                        trailing: Text(
                          base?.realLabel ?? l.aggregateMissingBase,
                        ),
                        onPressed: _busy ? null : () => _pickBase(profiles),
                      ),
                      FormRow(
                        title: l.aggregateTarget,
                        trailing: Text(
                          draft.targetGroup.isEmpty
                              ? l.aggregateChoose
                              : draft.targetGroup,
                        ),
                        onPressed: _busy ? null : () => _pickGroup(draft),
                      ),
                      FormRow(
                        title: l.aggregateSelection,
                        trailing: FormRowTextField(
                          key: ValueKey(draft.baseProfileId),
                          initialValue: draft.groupName,
                          onChanged: (value) => ref
                              .read(aggregateActionProvider.notifier)
                              .setDraft(
                                ref
                                    .read(aggregateWorkspaceSettingProvider)
                                    .draft
                                    .copyWith(groupName: value),
                              ),
                        ),
                      ),
                      FormRow(
                        title: l.aggregateSources,
                        trailing: Text('${included.length}'),
                        onPressed: () => showNestedSheet(
                          context,
                          builder: (_) => const _SourcesSheet(),
                        ),
                      ),
                    ]),
                    Text(
                      l.aggregateDnsInherited,
                      style: AppTextStyle.footnote.of(context).toLighter,
                    ),
                    if (errors.isNotEmpty)
                      Text(
                        l.aggregateSourceUnavailable,
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: context.colorScheme.error),
                      ),
                    if (sources.values.any((source) => source.isLoading))
                      const ActivityIndicator(),
                    SegmentedControl<bool>(
                      segments: [
                        (false, l.aggregateAllNodes),
                        (true, l.aggregateChains),
                      ],
                      value: _chains,
                      onChanged: (value) => setState(() => _chains = value),
                    ),
                    ListHeader(
                      title: _chains ? l.aggregateChains : l.aggregateAllNodes,
                      caption: l.aggregateDraftTestHint,
                      trailing: TonalButton(
                        size: TonalButtonSize.section,
                        glyph: AppGlyphs.bolt,
                        label: _testing
                            ? l.aggregateTesting
                            : l.aggregateTestAll,
                        onPressed:
                            _testing ||
                                !testTargets.any((target) => target.testable)
                            ? null
                            : () => _testAll(testTargets),
                      ),
                      actions: [
                        if (_chains && draft.chains.isNotEmpty)
                          IconButtonData(
                            glyph: AppGlyphs.addCircle,
                            tooltip: l.aggregateNewChain,
                            onPressed: _busy
                                ? null
                                : () => _editChain(chainNodes),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_chains)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverPrismList(
                  itemCount: draft.chains.length,
                  itemBuilder: (context, index) {
                    final chain = draft.chains[index];
                    final missing =
                        !availableChainNodes.containsKey(chain.entry.key) ||
                        !availableChainNodes.containsKey(chain.exit.key);
                    final loaded =
                        runtimeApplied &&
                        applied?.aggregate == draft &&
                        currentId == applied?.id;
                    final inUse =
                        loaded &&
                        selectedMap[draft.groupName] ==
                            aggregateChainName(chain) &&
                        switch (mode) {
                          Mode.global =>
                            selectedMap['GLOBAL'] == draft.groupName,
                          Mode.rule =>
                            selectedMap[draft.targetGroup] == draft.groupName,
                          Mode.direct => false,
                        };
                    return ContextMenuRegion(
                      menuItems: [
                        PopupMenuItem(
                          label: l.edit,
                          glyph: AppGlyphs.edit,
                          onPressed: () => _editChain(chainNodes, chain: chain),
                        ),
                        PopupMenuItem(
                          label: l.delete,
                          glyph: AppGlyphs.delete,
                          danger: true,
                          onPressed: () => ref
                              .read(aggregateActionProvider.notifier)
                              .setDraft(
                                draft.copyWith(
                                  chains: draft.chains
                                      .where((c) => c.id != chain.id)
                                      .toList(),
                                ),
                              ),
                        ),
                      ],
                      child: ListItem(
                        title: Text(chain.name),
                        subtitle: Text(
                          '${chain.entry.name}〔${sources[chain.entry.sourceId]?.value?.label ?? chain.entry.sourceId}〕 → ${chain.exit.name}〔${sources[chain.exit.sourceId]?.value?.label ?? chain.exit.sourceId}〕${missing ? '\n${l.aggregateRepair}' : ''}',
                        ),
                        onTap: () => _editChain(chainNodes, chain: chain),
                        trailing: missing
                            ? const GlyphIcon(AppGlyphs.info)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: [
                                  TonalButton(
                                    size: TonalButtonSize.section,
                                    glyph: AppGlyphs.checkCircle,
                                    label: inUse
                                        ? l.aggregateChainInUse
                                        : l.aggregateUseChain,
                                    onPressed: _busy || inUse
                                        ? null
                                        : () => _run(
                                            () => ref
                                                .read(
                                                  aggregateActionProvider
                                                      .notifier,
                                                )
                                                .apply(chainId: chain.id),
                                          ),
                                  ),
                                  AggregateProbeButton(
                                    key: ValueKey(chainTarget(chain)!.key),
                                    target: chainTarget(chain)!,
                                    name: aggregateChainName(chain),
                                    enabled: loaded,
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverPrismList(
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    final selected = included.contains(node.ref.sourceId);
                    final loaded =
                        runtimeApplied &&
                        applied?.aggregate == draft &&
                        currentId == applied?.id &&
                        selected;
                    return ContextMenuRegion(
                      menuItems: [
                        PopupMenuItem(
                          label: l.aggregateFavorite,
                          glyph: AppGlyphs.star,
                          checked: workspace.favorites.contains(node.ref.key),
                          onPressed: () => ref
                              .read(aggregateActionProvider.notifier)
                              .toggleFavorite(node.ref.key),
                        ),
                        if (selected) ...[
                          PopupMenuItem(
                            label: l.aggregateAsEntry,
                            glyph: AppGlyphs.link,
                            onPressed: () =>
                                _editChain(chainNodes, entry: node),
                          ),
                          PopupMenuItem(
                            label: l.aggregateAsExit,
                            glyph: AppGlyphs.link,
                            onPressed: () => _editChain(chainNodes, exit: node),
                          ),
                        ],
                      ],
                      child: ListItem(
                        title: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${node.sourceLabel} · ${node.type}${selected ? '' : ' · ${l.aggregateExcluded}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: selected
                            ? () => _editChain(chainNodes, entry: node)
                            : () => showNestedSheet(
                                context,
                                builder: (_) => const _SourcesSheet(),
                              ),
                        trailing: AggregateProbeButton(
                          key: ValueKey(node.ref.key),
                          target: AggregateDelayTarget([node]),
                          name:
                              node.ref.sourceId == draft.baseProfileId &&
                                  node.ref.provider.isEmpty
                              ? node.name
                              : node.runtimeName,
                          enabled: loaded,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if ((_chains ? draft.chains.isEmpty : nodes.isEmpty))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    spacing: 12,
                    children: [
                      Text(_chains ? l.aggregateNoChains : l.aggregateNoNodes),
                      if (_chains)
                        TonalButton(
                          label: l.aggregateNewChain,
                          glyph: AppGlyphs.addCircle,
                          onPressed: () => _editChain(chainNodes),
                        ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: context.bottomInset + 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesSheet extends ConsumerWidget {
  const _SourcesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final draft = ref.watch(aggregateWorkspaceSettingProvider).draft;
    final ids = [
      for (final profile in ref.watch(profilesProvider))
        if (profile.type == ProfileType.file ||
            profile.type == ProfileType.url ||
            profile.id == draft.baseProfileId)
          profile.id,
      0,
    ];
    return Scaffold(
      title: l.aggregateSources,
      body: Builder(
        builder: (context) => PrismListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            context.bottomInset + 16,
          ),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            final source = ref.watch(aggregateSourceProvider(id));
            final base = id == draft.baseProfileId;
            final selected = base || draft.sourceIds.contains(id);
            return ListItem(
              title: Text(
                source.value?.label ??
                    ref.watch(profileProvider(id))?.realLabel ??
                    l.localProxies,
              ),
              subtitle: Text(
                source.isLoading
                    ? l.aggregateLoading
                    : source.hasError
                    ? source.error.toString()
                    : source.value?.errors.isNotEmpty == true
                    ? source.value!.errors.join('\n')
                    : '${source.value?.nodes.length ?? 0} · ${base ? l.aggregateBase : l.aggregateSource}',
              ),
              trailing: selected ? const SelectionCheck() : null,
              onTap: base
                  ? null
                  : () {
                      final ids = {...draft.sourceIds};
                      if (!ids.remove(id)) ids.add(id);
                      ref
                          .read(aggregateActionProvider.notifier)
                          .setDraft(draft.copyWith(sourceIds: ids));
                    },
            );
          },
        ),
      ),
    );
  }
}

class AggregateProbeButton extends ConsumerStatefulWidget {
  const AggregateProbeButton({
    super.key,
    required this.target,
    required this.name,
    required this.enabled,
  });

  final String name;
  final AggregateDelayTarget target;
  final bool enabled;

  @override
  ConsumerState<AggregateProbeButton> createState() =>
      _AggregateProbeButtonState();
}

class _AggregateProbeButtonState extends ConsumerState<AggregateProbeButton> {
  late final RouteTracker _routes;

  @override
  void initState() {
    super.initState();
    _routes = ref.read(routeTrackerProvider.notifier);
    if (widget.enabled) _routes.attach();
  }

  @override
  void didUpdateWidget(AggregateProbeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _routes.attach();
      } else {
        _routes.detach();
      }
    }
  }

  @override
  void dispose() {
    if (widget.enabled) _routes.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final ip = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(widget.name)),
    );
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AggregateDelayButton(target: widget.target),
          if (widget.enabled &&
              ip.phase == ProbePhase.fresh &&
              ip.value != null)
            Text(ip.value!.ip, style: AppTextStyle.caption1.of(context)),
          if (widget.enabled)
            IconButton(
              tooltip: l.aggregateTestExitIp,
              onPressed: ip.phase == ProbePhase.probing
                  ? null
                  : () => ref.read(outboundIpProbeProvider.notifier).refresh([
                      widget.name,
                    ]),
              icon: ip.phase == ProbePhase.probing
                  ? const ActivityIndicator(size: 16)
                  : const GlyphIcon(AppGlyphs.proxies),
            ),
        ],
      ),
    );
  }
}
