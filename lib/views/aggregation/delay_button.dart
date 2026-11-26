import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AggregateDelayButton extends ConsumerWidget {
  const AggregateDelayButton({super.key, required this.target, this.label});

  final AggregateDelayTarget target;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final result = ref.watch(aggregateDelayTestProvider(target.key));
    final delay = result.delay;
    final testedAt = result.testedAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              delay == null
                  ? l.aggregateUntested
                  : delay > 0
                  ? '$delay ms'
                  : l.aggregateUnreachable,
              style: AppTextStyle.caption1.of(context),
            ),
            if (result.error != null) InfoMessageButton(message: result.error!),
            if (testedAt != null)
              Text(
                '${testedAt.hour.toString().padLeft(2, '0')}:${testedAt.minute.toString().padLeft(2, '0')}',
                style: AppTextStyle.caption2.of(context).toLighter,
              ),
          ],
        ),
        if (!target.testable)
          InfoMessageButton(message: l.aggregateExistingDialer),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.bolt,
          label: result.testing ? l.aggregateTesting : label ?? l.delayTest,
          onPressed: target.testable && !result.testing
              ? () => ref
                    .read(aggregateDelayTestProvider(target.key).notifier)
                    .test(target)
              : null,
        ),
      ],
    );
  }
}
