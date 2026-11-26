import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/aggregate_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_app.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Route extends RouteTracker {
  @override
  RouteState build() => const RouteState(
    coreEpoch: 1,
    routeVersion: 2,
    synced: true,
    live: true,
    proxied: true,
  );
  @override
  void attach() {}
  @override
  void detach() {}
  void change(RouteState value) => state = value;
}

void main() {
  const chain = ProxyChain(
    id: 'one',
    name: 'SG to LT',
    entry: AggregateNodeRef(sourceId: 1, fingerprint: 'sg', name: 'SG'),
    exit: AggregateNodeRef(sourceId: 2, fingerprint: 'lt', name: 'LT'),
  );
  const settings = AggregateConfig(
    baseProfileId: 1,
    targetGroup: 'Proxy',
    chains: [chain],
  );
  const active = ChainStatus(
    coreEpoch: 1,
    routeVersion: 2,
    running: true,
    selected: true,
    proxy: 'SG to LT [one]',
    proxyType: 'Http',
    target: 'Proxy',
    entry: 'SG [entry:one]',
    entryConnections: 1,
    exitConnections: 2,
    upload: 1000,
    download: 2000,
  );
  late _Core core;
  late ProviderContainer container;

  setUp(() {
    core = _Core();
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        routeTrackerProvider.overrideWith(_Route.new),
        aggregateRuntimeProvider.overrideWithBuild(
          (_, _) =>
              (profileId: 3, settings: settings, applied: true, error: null),
        ),
        aggregateRouteContextProvider.overrideWithValue((
          profileId: 3,
          settings: settings,
        )),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 700, child: AggregateRouteCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selection alone is not displayed as entry traffic', (
    tester,
  ) async {
    when(
      () => core.getChainStatus(
        proxy: any(named: 'proxy'),
        target: any(named: 'target'),
      ),
    ).thenAnswer(
      (_) async => active.copyWith(
        entryConnections: 0,
        exitConnections: 0,
        upload: 0,
        download: 0,
      ),
    );
    await mount(tester);
    expect(find.text('SG → LT'), findsOneWidget);
    expect(find.text('Selected · no live connections'), findsOneWidget);
    expect(find.text('Traffic observed'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'single nodes show their connections instead of an unused chain',
    (tester) async {
      when(
        () => core.getChainStatus(
          proxy: any(named: 'proxy'),
          target: any(named: 'target'),
        ),
      ).thenAnswer(
        (_) async => active.copyWith(
          proxy: 'SG 229',
          entry: '',
          entryConnections: 0,
          exitConnections: 13,
        ),
      );
      await mount(tester);
      expect(find.text('Current proxy'), findsOneWidget);
      expect(find.text('SG 229'), findsOneWidget);
      expect(find.text('Single node'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('SG → LT'), findsNothing);
      expect(find.text('Not selected'), findsNothing);
      expect(find.text('Traffic observed'), findsOneWidget);
      verify(() => core.getChainStatus(target: 'Proxy')).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shows real traffic and clears it on a route change or failed poll',
    (tester) async {
      when(
        () => core.getChainStatus(
          proxy: any(named: 'proxy'),
          target: any(named: 'target'),
        ),
      ).thenAnswer((_) async => active);
      await mount(tester);
      expect(find.text('Traffic observed'), findsOneWidget);
      final pending = Completer<ChainStatus>();
      when(
        () => core.getChainStatus(
          proxy: any(named: 'proxy'),
          target: any(named: 'target'),
        ),
      ).thenAnswer((_) => pending.future);
      (container.read(routeTrackerProvider.notifier) as _Route).change(
        container.read(routeTrackerProvider).copyWith(coreEpoch: 3),
      );
      await tester.pump();
      expect(find.text('Traffic observed'), findsNothing);
      pending.complete(active);
      await tester.pumpAndSettle();
      expect(find.text('Traffic observed'), findsNothing);
      when(
        () => core.getChainStatus(
          proxy: any(named: 'proxy'),
          target: any(named: 'target'),
        ),
      ).thenThrow(StateError('unavailable'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Status unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stops polling while hidden and ignores replies after disposal', (
    tester,
  ) async {
    final pending = Completer<ChainStatus>();
    when(
      () => core.getChainStatus(
        proxy: any(named: 'proxy'),
        target: any(named: 'target'),
      ),
    ).thenAnswer((_) => pending.future);
    await mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    pending.complete(active);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Traffic observed'), findsNothing);
    verify(
      () => core.getChainStatus(
        proxy: any(named: 'proxy'),
        target: any(named: 'target'),
      ),
    ).called(1);
    final late = Completer<ChainStatus>();
    when(
      () => core.getChainStatus(
        proxy: any(named: 'proxy'),
        target: any(named: 'target'),
      ),
    ).thenAnswer((_) => late.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    late.complete(active);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
