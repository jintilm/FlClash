import 'package:collection/collection.dart';
import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'connections_table.dart';

class AggregateRouteCard extends ConsumerWidget {
  const AggregateRouteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(aggregateRouteContextProvider);
    if (current == null) return const SizedBox.shrink();
    final runtime = ref.watch(aggregateRuntimeProvider);
    final loaded =
        runtime.applied &&
        runtime.profileId == current.profileId &&
        runtime.settings == current.settings;
    return _RouteStatus(
      key: ValueKey((current, loaded)),
      settings: current.settings,
      loaded: loaded,
    );
  }
}

class _RouteStatus extends ConsumerStatefulWidget {
  const _RouteStatus({super.key, required this.settings, required this.loaded});

  final AggregateConfig settings;
  final bool loaded;

  @override
  ConsumerState<_RouteStatus> createState() => _RouteStatusState();
}

class _RouteStatusState extends ConsumerState<_RouteStatus>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<_RouteStatus>,
        RouteMotionHoldMixin<_RouteStatus> {
  late final RouteTracker _routes;
  ChainStatus? _status;
  RouteState? _observedRoute;
  String? _error;

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _routes = ref.read(routeTrackerProvider.notifier)..attach();
    ref.listenManual(routeTrackerProvider, (_, _) => restartPolling());
  }

  @override
  void dispose() {
    _routes.detach();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final route = ref.read(routeTrackerProvider);
    if (!widget.loaded ||
        !route.synced ||
        !route.live ||
        !route.proxied ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ChainStatus? status;
    String? error;
    try {
      status = await ref
          .read(coreHandlerProvider)
          .getChainStatus(target: widget.settings.targetGroup);
    } catch (e) {
      error = userFacingErrorMessage(e, currentAppLocalizations);
    }
    if (!isCurrent() || ref.read(routeTrackerProvider) != route) return;
    updateWhenRouteSettled(() {
      if (!isCurrent() || ref.read(routeTrackerProvider) != route) return;
      setState(() {
        _status = status;
        _error = error;
        _observedRoute = route;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final route = ref.watch(routeTrackerProvider);
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final status =
        connected &&
            route.live &&
            route.synced &&
            route.proxied &&
            _observedRoute == route &&
            _status?.coreEpoch == route.coreEpoch &&
            _status?.routeVersion == route.routeVersion
        ? _status
        : null;
    final String label;
    final DashboardChipTone tone;
    if (!connected || !route.proxied) {
      label = l.notRunning;
      tone = DashboardChipTone.idle;
    } else if (!widget.loaded) {
      label = l.aggregateEntryNotLoaded;
      tone = DashboardChipTone.warn;
    } else if (_observedRoute == route && _error != null) {
      label = l.aggregateEntryUnknown;
      tone = DashboardChipTone.warn;
    } else if (status == null) {
      label = l.loading;
      tone = DashboardChipTone.idle;
    } else if (!status.running) {
      label = l.notRunning;
      tone = DashboardChipTone.idle;
    } else if (status.proxy.isEmpty) {
      label = l.aggregateEntryUnknown;
      tone = DashboardChipTone.warn;
    } else if (status.entryConnections > 0 || status.exitConnections > 0) {
      label = status.upload + status.download > 0
          ? l.aggregateEntryTransferring
          : l.aggregateEntryConnected;
      tone = DashboardChipTone.ok;
    } else {
      label = status.selected
          ? l.aggregateEntryIdle
          : l.aggregateEntryUnselected;
      tone = DashboardChipTone.idle;
    }
    final chain = status == null
        ? null
        : widget.settings.chains.firstWhereOrNull(
            (chain) =>
                aggregateChainName(chain) == status.proxy &&
                status.entry.isNotEmpty,
          );
    final hasEntry = status?.entry.isNotEmpty ?? false;
    final routeLabel = status == null || status.proxy.isEmpty
        ? '—'
        : chain != null
        ? chain.hops.map((hop) => hop.name).join(' → ')
        : status.hops.length > 1
        ? status.hops.map((hop) => hop.name).join(' → ')
        : hasEntry
        ? '${status.entry} → ${status.proxy}'
        : status.proxy;
    final kind = hasEntry
        ? l.aggregateChains
        : status?.proxyType == 'Direct'
        ? l.direct
        : status?.proxyType == 'LoadBalance'
        ? l.proxyGroup
        : l.aggregateSingleProxy;
    final connections = status == null
        ? '—'
        : status.hops.isNotEmpty
        ? status.hops.map((hop) => '${hop.connections}').join(' / ')
        : hasEntry
        ? '${status.entryConnections} / ${status.exitConnections}'
        : '${status.exitConnections}';
    return DashboardCard(
      semanticLabel: l.aggregateCurrentProxy,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onTap: () => openDashboardFeed(context, DashboardFeed.connections),
      child: WidthBuilder(
        builder: (context, width) {
          final wide = width >= 640;
          final values = <Widget>[
            _RouteMetric(
              label: status != null && status.hops.length > 2
                  ? l.aggregateAllHopConnections
                  : hasEntry
                  ? l.aggregateHopConnections
                  : l.liveConnections,
              value: connections,
              compact: !wide,
            ),
            _RouteMetric(
              label: l.upload,
              value: status == null ? '—' : status.upload.traffic.show,
              compact: !wide,
            ),
            _RouteMetric(
              label: l.download,
              value: status == null ? '—' : status.download.traffic.show,
              compact: !wide,
            ),
          ];
          final metrics = wide
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 24,
                  children: values,
                )
              : Wrap(spacing: 16, runSpacing: 4, children: values);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                spacing: 8,
                children: [
                  const GlyphIcon(AppGlyphs.proxies, size: 18),
                  Expanded(
                    child: Tooltip(
                      message: l.aggregateProxyTrafficHint,
                      child: Text(
                        l.aggregateCurrentProxy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.subheadline.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ),
                  ),
                  DashboardChip(
                    label: label,
                    tone: tone,
                    dot: tone == DashboardChipTone.ok,
                  ),
                ],
              ),
              Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 8,
                      children: [
                        if (status != null && status.proxy.isNotEmpty)
                          DashboardChip(label: kind),
                        Expanded(
                          child: TooltipText(
                            text: Text(
                              routeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.subheadline.of(
                                context,
                                emphasized: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wide) metrics,
                ],
              ),
              if (!wide) metrics,
            ],
          );
        },
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = Text(label, style: DashboardText.label(context));
    final amount = Text(
      value,
      style: (compact ? AppTextStyle.caption1 : AppTextStyle.subheadline)
          .of(context, emphasized: true)
          .toTabular,
    );
    return compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [title, amount],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [title, amount],
          );
  }
}
