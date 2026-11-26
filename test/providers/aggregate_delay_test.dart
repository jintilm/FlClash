import 'dart:async';

import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  late ProviderContainer container;
  late _Core core;
  var disposed = false;
  final nodes = aggregateNodes(
    sourceId: 1,
    label: 'Source',
    provider: '',
    definitions: [
      {'name': 'Entry', 'type': 'http', 'server': '192.0.2.1', 'port': 443},
      {'name': 'Exit', 'type': 'socks5', 'server': '192.0.2.2', 'port': 1080},
    ],
  );
  final target = AggregateDelayTarget(nodes);
  final provider = aggregateDelayTestProvider(target.key);

  setUp(() {
    disposed = false;
    core = _Core();
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        realTestUrlProvider(
          null,
        ).overrideWithValue('https://delay.example/204'),
      ],
    );
    container.listen(coreStatusProvider, (_, _) {});
  });
  tearDown(() {
    if (!disposed) container.dispose();
  });

  test(
    'tests a draft chain with no selected profile and coalesces repeated taps',
    () async {
      final answer = Completer<Delay>();
      when(
        () => core.testDraftDelay(
          proxies: any(named: 'proxies'),
          testUrl: any(named: 'testUrl'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) {
        expect(
          invocation.namedArguments[#proxies],
          nodes.map((node) => node.definition).toList(),
        );
        return answer.future;
      });
      expect(container.read(currentProfileIdProvider), isNull);
      final job = container.read(provider.notifier).test(target);
      expect(container.read(provider).testing, isTrue);
      await container.read(provider.notifier).test(target);
      answer.complete(
        const Delay(name: '', url: 'https://delay.example/204', value: 67),
      );
      await job;
      expect(container.read(provider).delay, 67);
      expect(container.read(provider).testing, isFalse);
      expect(container.read(provider).testedAt, isNotNull);
      expect(container.read(currentProfileIdProvider), isNull);
      verify(
        () => core.testDraftDelay(
          proxies: any(named: 'proxies'),
          testUrl: any(named: 'testUrl'),
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
    },
  );

  test('failure stops loading and retains the last measured delay', () async {
    when(
      () => core.testDraftDelay(
        proxies: any(named: 'proxies'),
        testUrl: any(named: 'testUrl'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => const Delay(name: '', url: '', value: 42));
    final notifier = container.read(provider.notifier);
    await notifier.test(target);
    when(
      () => core.testDraftDelay(
        proxies: any(named: 'proxies'),
        testUrl: any(named: 'testUrl'),
        timeout: any(named: 'timeout'),
      ),
    ).thenThrow(
      const CoreMethodException(code: 'no_response', message: 'unanswered'),
    );
    await notifier.test(target);
    expect(container.read(provider).delay, 42);
    expect(container.read(provider).error, isNotEmpty);
    expect(container.read(provider).testing, isFalse);
  });

  test('a core disconnect invalidates a pending result', () async {
    final answer = Completer<Delay>();
    when(
      () => core.testDraftDelay(
        proxies: any(named: 'proxies'),
        testUrl: any(named: 'testUrl'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) => answer.future);
    final job = container.read(provider.notifier).test(target);
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    expect(container.read(provider).testing, isFalse);
    answer.complete(const Delay(name: '', url: '', value: 9));
    await job;
    expect(container.read(provider).delay, isNull);
  });

  test(
    'disposing during a test releases its slot without writing stale state',
    () async {
      final answer = Completer<Delay>();
      when(
        () => core.testDraftDelay(
          proxies: any(named: 'proxies'),
          testUrl: any(named: 'testUrl'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) => answer.future);
      final job = container.read(provider.notifier).test(target);
      final pool = container.read(aggregateDelayPoolProvider);
      expect(pool.activeCount, 1);
      container.dispose();
      disposed = true;
      answer.complete(const Delay(name: '', url: '', value: 9));
      await job;
      expect(pool.activeCount, 0);
    },
  );
}
