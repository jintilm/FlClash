import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'delay_button.dart';

class AggregateChainEditor extends ConsumerStatefulWidget {
  const AggregateChainEditor({
    super.key,
    required this.nodes,
    this.chain,
    this.entry,
    this.exit,
  });

  final List<AggregateNode> nodes;
  final ProxyChain? chain;
  final AggregateNodeRef? entry;
  final AggregateNodeRef? exit;

  @override
  ConsumerState<AggregateChainEditor> createState() =>
      _AggregateChainEditorState();
}

class _AggregateChainEditorState extends ConsumerState<AggregateChainEditor> {
  late String _name = widget.chain?.name ?? '';
  late List<AggregateNodeRef?> _hops = [
    if (widget.chain case final chain?)
      ...chain.hops
    else ...[
      widget.entry,
      widget.exit,
    ],
  ];
  late List<Key> _keys = List.generate(_hops.length, (_) => UniqueKey());

  List<AggregateNode>? _prefix(int index) {
    final nodes = <AggregateNode>[];
    for (final hop in _hops.take(index)) {
      final node = widget.nodes.firstWhereOrNull(
        (node) => node.ref.key == hop?.key,
      );
      if (node == null) return null;
      nodes.add(node);
    }
    return nodes;
  }

  String _role(int index) {
    final l = context.appLocalizations;
    return index == 0
        ? l.aggregateEntry
        : index == _hops.length - 1
        ? l.aggregateExit
        : l.aggregateRelay(index + 1);
  }

  Future<void> _pick(int index) async {
    final prefix = _prefix(index);
    final used = {
      for (final (otherIndex, hop) in _hops.indexed)
        if (otherIndex != index && hop != null) hop.fingerprint,
    };
    final candidates = widget.nodes
        .where(
          (node) => !node.hasDialer && !used.contains(node.ref.fingerprint),
        )
        .toList();
    var pickerOpen = true;
    final selection = showNestedSheet<AggregateNode>(
      context,
      builder: (context) => SelectionSheet<AggregateNode>(
        title: _role(index),
        sections: [
          SelectionSection(
            label: index == 0
                ? null
                : prefix == null
                ? context.appLocalizations.aggregatePrefixMissing
                : context.appLocalizations.aggregateExitDelayHint(
                    prefix.map((node) => node.name).join(' → '),
                  ),
            items: candidates,
            subtitleBuilder: (_, node) => '${node.sourceLabel} · ${node.type}',
          ),
        ],
        labelBuilder: (node) => node.name,
        titleBuilder: (node, title) =>
            _NodeChoice(node: node, prefix: prefix ?? const [], title: title),
        selectedOf: (_) => candidates.firstWhereOrNull(
          (node) => node.ref.key == _hops[index]?.key,
        ),
        emptyLabel: context.appLocalizations.aggregateNoNodes,
        onSelected: (node) => Navigator.of(context).pop(node),
      ),
    );
    if (index > 0 && prefix != null) {
      unawaited(
        _testCandidates(candidates, prefix, () => mounted && pickerOpen),
      );
    }
    final AggregateNode? result;
    try {
      result = await selection;
    } finally {
      pickerOpen = false;
    }
    final chosen = result;
    if (chosen == null || !mounted) return;
    setState(() => _hops[index] = chosen.ref);
  }

  Future<void> _testCandidates(
    List<AggregateNode> candidates,
    List<AggregateNode> prefix,
    bool Function() pickerOpen,
  ) async {
    final testUrl = ref.read(realTestUrlProvider(null));
    bool isCurrent() =>
        pickerOpen() &&
        ref.read(coreStatusProvider) == CoreStatus.connected &&
        ref.read(realTestUrlProvider(null)) == testUrl;
    final pending = candidates.iterator;
    Future<void> worker() async {
      while (isCurrent() && pending.moveNext()) {
        final target = AggregateDelayTarget([...prefix, pending.current]);
        if (!target.testable) continue;
        await ref
            .read(aggregateDelayTestProvider(target.key).notifier)
            .testIfNeeded(target, isCurrent: isCurrent);
      }
    }

    await Future.wait([
      for (
        var index = 0;
        index < maxConcurrentDelayTests && index < candidates.length;
        index++
      )
        worker(),
    ]);
  }

  void _addHop() {
    if (_hops.length >= maxAggregateHops) return;
    setState(() {
      _hops.insert(_hops.length - 1, null);
      _keys.insert(_keys.length - 1, UniqueKey());
    });
  }

  void _reorder(int from, int to) {
    setState(() {
      _hops = _hops.copyAndReorder(from, to);
      _keys = _keys.copyAndReorder(from, to);
    });
  }

  Widget _hopRow(int index) => SortableItem(
    key: _keys[index],
    index: index,
    child: ContextMenuRegion(
      menuItems: [
        PopupMenuItem(
          label: context.appLocalizations.edit,
          glyph: AppGlyphs.edit,
          onPressed: () => _pick(index),
        ),
        if (_hops.length > 2)
          PopupMenuItem(
            label: context.appLocalizations.delete,
            glyph: AppGlyphs.delete,
            danger: true,
            onPressed: () => setState(() {
              _hops.removeAt(index);
              _keys.removeAt(index);
            }),
          ),
      ],
      child: ItemPositionProvider(
        position: ItemPosition.get(index, _hops.length),
        child: FormRow(
          title: _role(index),
          leading: Text('${index + 1}'),
          trailing: Text(_label(_hops[index])),
          onPressed: () => _pick(index),
        ),
      ),
    ),
  );

  String _label(AggregateNodeRef? value) {
    if (value == null) return context.appLocalizations.aggregateChoose;
    for (final node in widget.nodes) {
      if (node.ref.key == value.key) {
        return '${node.name} · ${node.sourceLabel}';
      }
    }
    return '${value.name} · ${context.appLocalizations.aggregateRepair}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final valid =
        _name.trim().isNotEmpty &&
        _hops.length >= 2 &&
        _hops.length <= maxAggregateHops &&
        _hops.every(
          (hop) =>
              hop != null &&
              widget.nodes.any(
                (node) => node.ref.key == hop.key && !node.hasDialer,
              ),
        ) &&
        _hops.map((hop) => hop?.fingerprint).toSet().length == _hops.length;
    return Scaffold(
      title: widget.chain == null ? l.aggregateNewChain : l.aggregateChains,
      canSort: _hops.length > 1,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: l.save,
        onPressed: !valid
            ? null
            : () => Navigator.of(context).pop(
                ProxyChain(
                  id: widget.chain?.id ?? '${snowflake.id}',
                  name: _name.trim(),
                  entry: _hops.first!,
                  exit: _hops.last!,
                  relays: _hops
                      .sublist(1, _hops.length - 1)
                      .cast<AggregateNodeRef>(),
                ),
              ),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.swap,
          tooltip: l.aggregateSwap,
          onPressed: () => setState(() {
            _hops = _hops.reversed.toList();
            _keys = _keys.reversed.toList();
          }),
        ),
      ],
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
                child: generateGroup([
                  FormRow(
                    title: l.name,
                    trailing: FormRowTextField(
                      initialValue: _name,
                      onChanged: (value) => setState(() => _name = value),
                    ),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverPrismReorderableList(
                itemCount: _hops.length,
                itemBuilder: (_, index) => _hopRow(index),
                proxyDecorator: (_, index, animation) =>
                    commonProxyDecorator(_hopRow(index), index, animation),
                onReorderItem: _reorder,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                context.bottomInset + 16,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    TonalButton(
                      size: TonalButtonSize.section,
                      glyph: AppGlyphs.addCircle,
                      label: l.aggregateAddRelay,
                      onPressed: _hops.length < maxAggregateHops
                          ? _addHop
                          : null,
                    ),
                    Text(l.aggregateMultiHopHint(maxAggregateHops)),
                    Text(
                      _hops
                          .map((hop) => hop?.name ?? l.aggregateChoose)
                          .join(' → '),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeChoice extends ConsumerWidget {
  const _NodeChoice({
    required this.node,
    required this.prefix,
    required this.title,
  });

  final AggregateNode node;
  final List<AggregateNode> prefix;
  final Widget title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final single = ref.watch(aggregateDelayTestProvider(node.ref.key));
    final delay = single.delay;
    final nodeDelay = delay == null
        ? l.aggregateUntested
        : delay > 0
        ? '$delay ms'
        : l.aggregateUnreachable;
    final target = AggregateDelayTarget([...prefix, node]);
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (prefix.isNotEmpty)
                Text(
                  '${l.aggregateNodeDelay}: $nodeDelay',
                  style: AppTextStyle.caption1.of(context).toLighter,
                ),
            ],
          ),
        ),
        AggregateDelayButton(
          target: target,
          label: prefix.isEmpty ? null : l.aggregateTestChain,
        ),
      ],
    );
  }
}
