import 'dart:async';

import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/aggregation/chain_editor.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _Delay extends AggregateDelayTest {
  _Delay(this.tested, this.completed);

  final List<AggregateDelayTarget> tested;
  final Map<String, int> completed;

  @override
  AggregateDelayResult build(String targetKey) =>
      AggregateDelayResult(delay: completed[targetKey]);

  @override
  Future<void> test(
    AggregateDelayTarget target, {
    bool Function()? isCurrent,
  }) async {
    tested.add(target);
    state = const AggregateDelayResult(delay: 123);
  }
}

class _PendingDelay extends AggregateDelayTest {
  _PendingDelay(this.pending);

  final List<Completer<void>> pending;

  @override
  AggregateDelayResult build(String targetKey) => const AggregateDelayResult();

  @override
  Future<void> test(
    AggregateDelayTarget target, {
    bool Function()? isCurrent,
  }) async {
    state = const AggregateDelayResult(testing: true);
    final done = Completer<void>();
    pending.add(done);
    await done.future;
    state = const AggregateDelayResult(delay: 123);
  }
}

void main() {
  final nodes = aggregateNodes(
    sourceId: 1,
    label: 'Subscription',
    provider: '',
    definitions: [
      {'name': 'SG', 'type': 'socks5', 'server': '192.0.2.1', 'port': 1080},
      {'name': 'LT', 'type': 'socks5', 'server': '192.0.2.2', 'port': 1080},
      {'name': 'JP', 'type': 'socks5', 'server': '192.0.2.3', 'port': 1080},
    ],
  );

  testWidgets(
    'exit choices reuse both measurements and automatically test missing chains',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1050, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tested = <AggregateDelayTarget>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            aggregateDelayTestProvider.overrideWith2(
              (_) => _Delay(tested, {
                nodes[1].ref.key: 58,
                AggregateDelayTarget([nodes[0], nodes[1]]).key: 90,
              }),
            ),
          ],
          child: AggregateChainEditor(nodes: nodes, entry: nodes[0].ref),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit node'));
      await tester.pumpAndSettle();
      expect(find.text('Node latency: 58 ms'), findsOneWidget);
      expect(find.text('Node latency: Not tested'), findsOneWidget);
      expect(find.text('SG'), findsNothing);
      expect(find.text('90 ms'), findsOneWidget);
      expect(find.text('123 ms'), findsOneWidget);
      expect(tested.single.nodes.map((node) => node.name), ['SG', 'JP']);
      await tester.tap(find.text('Test chain').first);
      await tester.pumpAndSettle();
      expect(tested.last.nodes.map((node) => node.name), ['SG', 'LT']);
      expect(find.text('123 ms'), findsNWidgets(2));
      expect(find.text('LT'), findsOneWidget);
      await tester.tap(find.text('LT'));
      await tester.pumpAndSettle();
      expect(find.text('LT · Subscription'), findsOneWidget);
      await tester.tap(find.text('Exit node'));
      await tester.pumpAndSettle();
      expect(tested, hasLength(2));
      await tester.tap(find.text('LT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Swap entry and exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit node'));
      await tester.pumpAndSettle();
      expect(find.text('LT'), findsNothing);
      expect(
        tested
            .skip(2)
            .map((target) => target.nodes.map((node) => node.name).join(' → ')),
        ['LT → SG', 'LT → JP'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry choices reuse existing single-node results', (
    tester,
  ) async {
    final tested = <AggregateDelayTarget>[];
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          aggregateDelayTestProvider.overrideWith2(
            (_) => _Delay(tested, {nodes[0].ref.key: 42}),
          ),
        ],
        child: AggregateChainEditor(nodes: nodes),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entry node'));
    await tester.pumpAndSettle();
    expect(find.text('42 ms'), findsOneWidget);
    await tester.tap(find.byType(TonalButton).first);
    await tester.pumpAndSettle();
    expect(tested.single.nodes.single.name, 'SG');
    expect(find.text('123 ms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing the exit picker stops scheduling the rest of a large batch',
    (tester) async {
      final many = aggregateNodes(
        sourceId: 1,
        label: 'Subscription',
        provider: '',
        definitions: [
          nodes[0].definition,
          for (var i = 0; i < maxConcurrentDelayTests * 3; i++)
            {
              'name': 'Exit $i',
              'type': 'socks5',
              'server': 'exit$i.example',
              'port': 1080,
            },
        ],
      );
      final pending = <Completer<void>>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            aggregateDelayTestProvider.overrideWith2(
              (_) => _PendingDelay(pending),
            ),
          ],
          child: AggregateChainEditor(nodes: many, entry: many.first.ref),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit node'));
      await tester.pumpAndSettle();
      expect(pending, hasLength(maxConcurrentDelayTests));
      await tester.tap(find.text('Exit 0'));
      await tester.pumpAndSettle();
      for (final done in pending) {
        done.complete();
      }
      await tester.pumpAndSettle();
      expect(pending, hasLength(maxConcurrentDelayTests));
      expect(find.text('Exit 0 · Subscription'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
