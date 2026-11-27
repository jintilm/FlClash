import 'dart:async';

import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/aggregate_delay.dart';
import 'package:fl_clash/views/aggregation/aggregation.dart';
import 'package:fl_clash/views/aggregation/chain_editor.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Action extends AggregateAction {
  int applications = 0;
  bool fail = false;
  String? selectedChain;

  @override
  void initialize([int? profileId]) {}

  @override
  Future<void> apply({String? chainId}) async {
    applications++;
    selectedChain = chainId;
    if (fail) throw const MessageException('Application failed');
  }
}

class _Delay extends AggregateDelayTest {
  final List<AggregateDelayTarget> tested;
  final Map<String, int> measurements;

  _Delay(this.tested, [this.measurements = const {}]);

  @override
  AggregateDelayResult build(String targetKey) =>
      AggregateDelayResult(delay: measurements[targetKey]);

  void measure(int value) => state = AggregateDelayResult(delay: value);

  @override
  Future<void> test(
    AggregateDelayTarget target, {
    bool Function()? isCurrent,
  }) async {
    tested.add(target);
    state = AggregateDelayResult(delay: 58, testedAt: DateTime(2026));
  }
}

void main() {
  const base = Profile(
    id: 1,
    type: ProfileType.file,
    label: 'Subscription A',
    autoUpdateDuration: Duration.zero,
  );
  const other = Profile(
    id: 2,
    type: ProfileType.file,
    label: 'Subscription B',
    autoUpdateDuration: Duration.zero,
  );
  final nodes = aggregateNodes(
    sourceId: 1,
    label: base.label,
    provider: '',
    definitions: [
      {'name': 'Entry', 'type': 'socks5', 'server': '192.0.2.1', 'port': 1080},
      {'name': 'Exit', 'type': 'socks5', 'server': '192.0.2.2', 'port': 1080},
    ],
  );
  const draft = AggregateConfig(
    baseProfileId: 1,
    sourceIds: {1},
    targetGroup: 'Proxy',
  );

  testWidgets(
    'sorts by measured latency without moving rows on individual replies',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base])),
          aggregateActionProvider.overrideWith(_Action.new),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => const AggregateWorkspace(draft: draft),
          ),
          aggregateSourceProvider(1).overrideWith(
            (_) async =>
                AggregateSource(id: 1, label: base.label, nodes: nodes),
          ),
          aggregateSourceProvider(0).overrideWith(
            (_) async => const AggregateSource(id: 0, label: 'Local'),
          ),
          aggregateDelayTestProvider.overrideWith2(
            (_) => _Delay([], {nodes[0].ref.key: 200, nodes[1].ref.key: 40}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AggregateProxiesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latency: low to high'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Exit')).dy,
        lessThan(tester.getTopLeft(find.text('Entry')).dy),
      );
      (container.read(aggregateDelayTestProvider(nodes[0].ref.key).notifier)
              as _Delay)
          .measure(10);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Exit')).dy,
        lessThan(tester.getTopLeft(find.text('Entry')).dy),
      );
      await tester.tap(find.byTooltip('Refresh order'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Entry')).dy,
        lessThan(tester.getTopLeft(find.text('Exit')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows nodes, edits a draft and only applies through the apply control',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final action = _Action();
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base, other])),
          aggregateActionProvider.overrideWith(() => action),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => const AggregateWorkspace(draft: draft),
          ),
          aggregateSourceProvider(1).overrideWith(
            (_) async =>
                AggregateSource(id: 1, label: base.label, nodes: nodes),
          ),
          aggregateSourceProvider(2).overrideWith(
            (_) async => AggregateSource(id: 2, label: other.label),
          ),
          aggregateSourceProvider(0).overrideWith(
            (_) async => const AggregateSource(id: 0, label: 'Local'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AggregateProxiesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aggregate proxies'), findsOneWidget);
      expect(find.text('Entry'), findsOneWidget);
      expect(action.applications, 0);
      await tester.tap(find.text('Proxy chains'));
      await tester.pumpAndSettle();
      expect(
        find.text('No chains yet. Choose nodes and create a chain.'),
        findsOneWidget,
      );
      expect(action.applications, 0);
      await tester.tap(find.text('New chain'));
      await tester.pumpAndSettle();
      expect(find.byType(AggregateChainEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Swap entry and exit'));
      await tester.pumpAndSettle();
      expect(container.read(aggregateWorkspaceSettingProvider).draft, draft);
      expect(action.applications, 0);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Apply aggregate profile'));
      await tester.pumpAndSettle();
      expect(action.applications, 1);
      action.fail = true;
      await tester.tap(find.byTooltip('Apply aggregate profile'));
      await tester.pumpAndSettle();
      expect(action.applications, 2);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).isLoading,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders loading and source failures without hiding completed sources',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final loading = Completer<AggregateSource>();
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base, other])),
          aggregateActionProvider.overrideWith(_Action.new),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => const AggregateWorkspace(draft: draft),
          ),
          aggregateSourceProvider(1).overrideWith(
            (_) async =>
                AggregateSource(id: 1, label: base.label, nodes: nodes),
          ),
          aggregateSourceProvider(2).overrideWith((_) => loading.future),
          aggregateSourceProvider(0).overrideWith(
            (_) async => const AggregateSource(id: 0, label: 'Local'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AggregateProxiesView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ActivityIndicator), findsWidgets);
      loading.complete(
        const AggregateSource(
          id: 2,
          label: 'Subscription B',
          errors: ['Download failed'],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Some sources could not be loaded. Check Sources and refresh.',
        ),
        findsOneWidget,
      );
      expect(find.text('Entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft node and chain delay tests are visible and do not apply configuration',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final action = _Action();
      final tested = <AggregateDelayTarget>[];
      final chain = ProxyChain(
        id: 'chain',
        name: 'Two hops',
        entry: nodes[0].ref,
        exit: nodes[1].ref,
      );
      final workspace = AggregateWorkspace(
        draft: draft.copyWith(chains: [chain]),
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base])),
          aggregateActionProvider.overrideWith(() => action),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => workspace,
          ),
          aggregateSourceProvider(1).overrideWith(
            (_) async =>
                AggregateSource(id: 1, label: base.label, nodes: nodes),
          ),
          aggregateSourceProvider(0).overrideWith(
            (_) async => const AggregateSource(id: 0, label: 'Local'),
          ),
          aggregateDelayTestProvider.overrideWith2((_) => _Delay(tested)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: AggregateProxiesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test visible delays'));
      await tester.pumpAndSettle();
      expect(tested.map((target) => target.nodes.single.name), [
        'Entry',
        'Exit',
      ]);
      expect(find.text('58 ms'), findsNWidgets(2));
      expect(action.applications, 0);
      await tester.tap(find.text('Proxy chains').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AggregateProbeButton),
          matching: find.byType(TonalButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(tested.last.nodes.map((node) => node.name), ['Entry', 'Exit']);
      expect(find.text('58 ms'), findsOneWidget);
      expect(container.read(aggregateWorkspaceSettingProvider), workspace);
      expect(action.applications, 0);
      await tester.tap(find.text('Use this chain'));
      await tester.pumpAndSettle();
      expect(action.applications, 1);
      expect(action.selectedChain, chain.id);
      final applied = base.copyWith(
        id: 3,
        type: ProfileType.aggregate,
        aggregate: workspace.draft,
        selectedMap: {
          'Proxy': 'Entry',
          draft.groupName: aggregateChainName(chain),
        },
      );
      container.read(profilesProvider.notifier).put(applied);
      container.read(currentProfileIdProvider.notifier).value = applied.id;
      container.read(aggregateWorkspaceSettingProvider.notifier).value =
          workspace.copyWith(profileId: applied.id);
      container
          .read(aggregateRuntimeProvider.notifier)
          .record(applied.id, workspace.draft, true);
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsNothing);
      container
          .read(profilesProvider.notifier)
          .put(
            applied.copyWith(
              selectedMap: {
                'Proxy': draft.groupName,
                draft.groupName: aggregateChainName(chain),
              },
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large node collections only mount visible rows', (tester) async {
    final many = aggregateNodes(
      sourceId: 1,
      label: base.label,
      provider: '',
      definitions: [
        for (var i = 0; i < 5000; i++)
          {
            'name': 'Node $i',
            'type': 'socks5',
            'server': 'node$i.example',
            'port': 1080,
          },
      ],
    );
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base])),
          aggregateActionProvider.overrideWith(_Action.new),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => const AggregateWorkspace(draft: draft),
          ),
          aggregateSourceProvider(1).overrideWith(
            (_) async => AggregateSource(id: 1, label: base.label, nodes: many),
          ),
          aggregateSourceProvider(0).overrideWith(
            (_) async => const AggregateSource(id: 0, label: 'Local'),
          ),
        ],
        child: const AggregateProxiesView(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AggregateProbeButton).evaluate().length, lessThan(30));
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AggregateProbeButton).evaluate().length, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
