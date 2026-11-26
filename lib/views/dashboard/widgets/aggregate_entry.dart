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

class AggregateEntryCard extends ConsumerWidget {
  const AggregateEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(aggregateCurrentChainProvider);
    if (current == null) return const SizedBox.shrink();
    final runtime = ref.watch(aggregateRuntimeProvider);
    final loaded =
        runtime.applied &&
        runtime.profileId == current.profileId &&
        runtime.settings == current.settings;
    return _EntryStatus(
      key: ValueKey((current, loaded)),
      chain: current.chain,
      target: current.settings.targetGroup,
      loaded: loaded,
    );
  }
}

class _EntryStatus extends ConsumerStatefulWidget {
  const _EntryStatus({
    super.key,
    required this.chain,
    required this.target,
    required this.loaded,
  });

  final ProxyChain chain;
  final String target;
  final bool loaded;

  @override
  ConsumerState<_EntryStatus> createState() => _EntryStatusState();
}

class _EntryStatusState extends ConsumerState<_EntryStatus>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<_EntryStatus>,
        RouteMotionHoldMixin<_EntryStatus> {
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
          .getChainStatus(
            proxy: aggregateChainName(widget.chain),
            target: widget.target,
          );
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
    } else if (status.entry.isEmpty) {
      label = l.aggregateEntryNotLoaded;
      tone = DashboardChipTone.warn;
    } else if (status.entryConnections > 0) {
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
    var details = status == null
        ? l.aggregateEntryHint
        : l.aggregateEntryCounts(
            status.entryConnections,
            status.exitConnections,
            status.upload.traffic.show,
            status.download.traffic.show,
          );
    if (status != null && !status.selected && status.entryConnections > 0) {
      details = '$details · ${l.aggregateEntryOldConnections}';
    }
    return DashboardCard(
      semanticLabel: l.aggregateEntryStatus,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onTap: () => openDashboardFeed(context, DashboardFeed.connections),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 8,
            children: [
              const GlyphIcon(AppGlyphs.proxies, size: 18),
              Expanded(
                child: Text(
                  l.aggregateEntryStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
              ),
              DashboardChip(label: label, tone: tone),
            ],
          ),
          TooltipText(
            text: Text(
              '${widget.chain.entry.name} → ${widget.chain.exit.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline.of(context),
            ),
          ),
          TooltipText(
            text: Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.label(context),
            ),
          ),
        ],
      ),
    );
  }
}
