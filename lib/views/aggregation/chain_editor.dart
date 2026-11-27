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
  late AggregateNodeRef? _entry = widget.chain?.entry ?? widget.entry;
  late AggregateNodeRef? _exit = widget.chain?.exit ?? widget.exit;

  Future<void> _pick(bool entry) async {
    final other = entry ? _exit : _entry;
    final entryNode = entry
        ? null
        : widget.nodes.firstWhereOrNull((node) => node.ref.key == _entry?.key);
    final candidates = widget.nodes
        .where(
          (node) =>
              !node.hasDialer && node.ref.fingerprint != other?.fingerprint,
        )
        .toList();
    var pickerOpen = true;
    final selection = showNestedSheet<AggregateNode>(
      context,
      builder: (context) => SelectionSheet<AggregateNode>(
        title: entry
            ? context.appLocalizations.aggregateEntry
            : context.appLocalizations.aggregateExit,
        sections: [
          SelectionSection(
            label: entryNode == null
                ? null
                : context.appLocalizations.aggregateExitDelayHint(
                    entryNode.name,
                  ),
            items: candidates,
            subtitleBuilder: (_, node) => '${node.sourceLabel} · ${node.type}',
          ),
        ],
        labelBuilder: (node) => node.name,
        titleBuilder: (node, title) =>
            _NodeChoice(node: node, entry: entryNode, title: title),
        selectedOf: (_) => candidates.firstWhereOrNull(
          (node) => node.ref.key == (entry ? _entry : _exit)?.key,
        ),
        emptyLabel: context.appLocalizations.aggregateNoNodes,
        onSelected: (node) => Navigator.of(context).pop(node),
      ),
    );
    if (!entry) {
      unawaited(
        _testCandidates(candidates, entryNode, () => mounted && pickerOpen),
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
    setState(() {
      if (entry) {
        _entry = chosen.ref;
      } else {
        _exit = chosen.ref;
      }
    });
  }

  Future<void> _testCandidates(
    List<AggregateNode> candidates,
    AggregateNode? entry,
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
        final target = AggregateDelayTarget([?entry, pending.current]);
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
        _entry != null &&
        _exit != null &&
        _entry!.fingerprint != _exit!.fingerprint &&
        widget.nodes.any(
          (node) => node.ref.key == _entry!.key && !node.hasDialer,
        ) &&
        widget.nodes.any(
          (node) => node.ref.key == _exit!.key && !node.hasDialer,
        );
    return Scaffold(
      title: widget.chain == null ? l.aggregateNewChain : l.aggregateChains,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: l.save,
        onPressed: !valid
            ? null
            : () => Navigator.of(context).pop(
                ProxyChain(
                  id: widget.chain?.id ?? '${snowflake.id}',
                  name: _name.trim(),
                  entry: _entry!,
                  exit: _exit!,
                ),
              ),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.swap,
          tooltip: l.aggregateSwap,
          onPressed: () => setState(() {
            final previous = _entry;
            _entry = _exit;
            _exit = previous;
          }),
        ),
      ],
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            context.bottomInset + 16,
          ),
          children: [
            generateGroup([
              FormRow(
                title: l.name,
                trailing: FormRowTextField(
                  initialValue: _name,
                  onChanged: (value) => setState(() => _name = value),
                ),
              ),
              FormRow(
                title: l.aggregateEntry,
                trailing: Text(_label(_entry)),
                onPressed: () => _pick(true),
              ),
              FormRow(
                title: l.aggregateExit,
                trailing: Text(_label(_exit)),
                onPressed: () => _pick(false),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l.aggregateRouteHint),
            ),
            if (_entry != null &&
                _exit != null &&
                _entry!.fingerprint == _exit!.fingerprint)
              Text(l.aggregateSameHop),
          ],
        ),
      ),
    );
  }
}

class _NodeChoice extends ConsumerWidget {
  const _NodeChoice({
    required this.node,
    required this.entry,
    required this.title,
  });

  final AggregateNode node;
  final AggregateNode? entry;
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
    final target = AggregateDelayTarget([?entry, node]);
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (entry != null)
                Text(
                  '${l.aggregateNodeDelay}: $nodeDelay',
                  style: AppTextStyle.caption1.of(context).toLighter,
                ),
            ],
          ),
        ),
        AggregateDelayButton(
          target: target,
          label: entry == null ? null : l.aggregateTestChain,
        ),
      ],
    );
  }
}
