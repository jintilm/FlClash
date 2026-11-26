import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app.dart';
import 'config.dart';
import 'core.dart';
import 'state.dart';

part 'generated/aggregate_delay.g.dart';

class AggregateDelayResult {
  final bool testing;
  final int? delay;
  final DateTime? testedAt;
  final String? error;

  const AggregateDelayResult({
    this.testing = false,
    this.delay,
    this.testedAt,
    this.error,
  });
}

@Riverpod(keepAlive: true)
TaskPool aggregateDelayPool(Ref ref) => TaskPool(maxConcurrentDelayTests);

@Riverpod(keepAlive: true)
class AggregateDelayTest extends _$AggregateDelayTest {
  @override
  AggregateDelayResult build(String targetKey) {
    ref.watch(coreStatusProvider);
    ref.watch(realTestUrlProvider(null));
    return const AggregateDelayResult();
  }

  Future<void> test(AggregateDelayTarget target) async {
    if (state.testing || !target.testable || target.key != targetKey) return;
    final runRef = ref;
    final core = runRef.read(coreHandlerProvider);
    final pool = runRef.read(aggregateDelayPoolProvider);
    final url = runRef.read(realTestUrlProvider(null));
    final timeout = runRef.read(appSettingProvider).delayTestTimeout;
    final previous = state;
    state = AggregateDelayResult(
      testing: true,
      delay: previous.delay,
      testedAt: previous.testedAt,
    );
    try {
      await pool.run(() async {
        if (!runRef.mounted) return;
        if (runRef.read(coreStatusProvider) != CoreStatus.connected) {
          throw MessageException(currentAppLocalizations.aggregateCoreRequired);
        }
        final result = await core.testDraftDelay(
          proxies: target.nodes.map((node) => node.definition).toList(),
          testUrl: url,
          timeout: timeout,
        );
        if (!runRef.mounted) return;
        state = AggregateDelayResult(
          delay: result.value,
          testedAt: DateTime.now(),
        );
      });
    } catch (error) {
      if (runRef.mounted) {
        state = AggregateDelayResult(
          delay: previous.delay,
          testedAt: previous.testedAt,
          error: userFacingErrorMessage(error, currentAppLocalizations),
        );
      }
    } finally {
      if (runRef.mounted && state.testing) {
        state = previous;
      }
    }
  }
}
