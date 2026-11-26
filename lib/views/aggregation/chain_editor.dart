import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class AggregateChainEditor extends StatefulWidget {
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
  State<AggregateChainEditor> createState() => _AggregateChainEditorState();
}

class _AggregateChainEditorState extends State<AggregateChainEditor> {
  late String _name = widget.chain?.name ?? '';
  late AggregateNodeRef? _entry = widget.chain?.entry ?? widget.entry;
  late AggregateNodeRef? _exit = widget.chain?.exit ?? widget.exit;

  Future<void> _pick(bool entry) async {
    final result = await showNestedSheet<AggregateNode>(
      context,
      builder: (context) => SelectionSheet<AggregateNode>(
        title: entry
            ? context.appLocalizations.aggregateEntry
            : context.appLocalizations.aggregateExit,
        sections: [
          SelectionSection(
            items: widget.nodes,
            subtitleBuilder: (_, node) => '${node.sourceLabel} · ${node.type}',
          ),
        ],
        labelBuilder: (node) => node.name,
        selectedOf: (_) => null,
        onSelected: (node) => Navigator.of(context).pop(node),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (entry) {
        _entry = result.ref;
      } else {
        _exit = result.ref;
      }
    });
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
