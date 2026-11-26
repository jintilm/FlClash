import 'dart:async';

import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
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

  @override
  void initialize([int? profileId]) {}

  @override
  Future<void> apply() async {
    applications++;
    if (fail) throw const MessageException('Application failed');
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
    'shows nodes, edits a draft and only applies through the apply control',
    (tester) async {
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
