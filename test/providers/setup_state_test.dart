import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';

void main() {
  late db.Database testDatabase;

  setUp(() {
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
  });

  tearDown(() async {
    await testDatabase.close();
  });

  test(
    'a first aggregate setup survives source updates before the base resolves',
    () async {
      const base = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const aggregate = Profile(
        id: 2,
        type: ProfileType.aggregate,
        autoUpdateDuration: Duration.zero,
        aggregate: AggregateConfig(baseProfileId: 1, sourceIds: {1, 3}),
      );
      const source = Profile(id: 3, autoUpdateDuration: Duration.zero);
      final pending = Completer<SetupState>();
      final profiles = TestProfiles([base, aggregate, source]);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => profiles),
          setupStateProvider(1).overrideWith((_) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      final future = readSetupState(container, 2);
      final result = expectLater(
        future,
        completion(
          isA<SetupState>().having(
            (state) => state.aggregateSourceVersions[3],
            'source version',
            1000,
          ),
        ),
      );
      profiles.replace([
        base,
        aggregate,
        source.copyWith(
          lastUpdateDate: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      ]);
      await container.pump();
      pending.complete(
        const SetupState(
          profileId: 1,
          profileLastUpdateDate: null,
          profileType: ProfileType.file,
          rules: [],
          proxyGroups: [],
          addedRules: [],
          script: null,
          overrides: ProfileOverrides(),
        ),
      );
      await result;
      await container.pump();
      expect(container.exists(setupStateProvider(2)), isFalse);
    },
  );

  test(
    'aggregate setup can finish after disposal while the base is pending',
    () async {
      const base = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const aggregate = Profile(
        id: 2,
        type: ProfileType.aggregate,
        autoUpdateDuration: Duration.zero,
        aggregate: AggregateConfig(baseProfileId: 1, sourceIds: {1, 0}),
      );
      final pending = Completer<SetupState>();
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base, aggregate])),
          setupStateProvider(1).overrideWith((_) => pending.future),
          customProxiesProvider.overrideWithBuild(
            (_, _) => Stream.value(const [
              CustomProxy(id: 3, definition: {'name': 'Local'}),
            ]),
          ),
        ],
      );
      container.listen(customProxiesProvider, (_, _) {});
      await container.read(customProxiesProvider.future);
      final future = container.read(setupStateProvider(2).future);
      final result = expectLater(
        future,
        completion(
          isA<SetupState>().having(
            (state) => state.aggregateSourceVersions.keys,
            'sources',
            containsAll([0, 1]),
          ),
        ),
      );
      container.dispose();
      pending.complete(
        const SetupState(
          profileId: 1,
          profileLastUpdateDate: null,
          profileType: ProfileType.file,
          rules: [],
          proxyGroups: [],
          addedRules: [],
          script: null,
          overrides: ProfileOverrides(),
        ),
      );
      await result;
    },
  );

  test(
    'first setup waits for cold local proxies and releases them after completion',
    () async {
      const base = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const aggregate = Profile(
        id: 2,
        type: ProfileType.aggregate,
        autoUpdateDuration: Duration.zero,
        aggregate: AggregateConfig(baseProfileId: 1, sourceIds: {0, 1}),
      );
      final locals = StreamController<List<CustomProxy>>();
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([base, aggregate])),
          customProxiesProvider.overrideWithBuild((_, _) => locals.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(locals.close);
      final result = readSetupState(container, 2);
      await container.pump();
      expect(locals.hasListener, isTrue);
      locals.add(const [
        CustomProxy(id: 9, definition: {'name': 'Local'}),
      ]);
      expect((await result).aggregateSourceVersions, contains(0));
      await container.pump();
      expect(container.exists(setupStateProvider(2)), isFalse);
      expect(locals.hasListener, isFalse);
    },
  );

  test(
    'failed setup releases its subscription and the next read can succeed',
    () async {
      final pending = Completer<SetupState>();
      var failed = true;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          setupStateProvider(2).overrideWith(
            (_) => failed
                ? Future<SetupState>.error(StateError('source failed'))
                : pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        readSetupState(container, 2),
        throwsA(isA<StateError>()),
      );
      await container.pump();
      expect(container.exists(setupStateProvider(2)), isFalse);
      failed = false;
      final result = readSetupState(container, 2);
      pending.complete(
        const SetupState(
          profileId: 2,
          profileLastUpdateDate: null,
          profileType: ProfileType.file,
          rules: [],
          proxyGroups: [],
          addedRules: [],
          script: null,
          overrides: ProfileOverrides(),
        ),
      );
      expect((await result).profileId, 2);
      await container.pump();
      expect(container.exists(setupStateProvider(2)), isFalse);
    },
  );

  testWidgets('a custom setup disposed before its queries return resolves', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const subscription = Profile(
      id: 2,
      label: 'Sub',
      type: ProfileType.url,
      url: 'https://example.com/sub',
      autoUpdateDuration: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([profile, subscription]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.profileType, ProfileType.custom);
    expect(state.profileProviders, {'Sub': subscription.id});
  });

  testWidgets('a custom setup leaves the extension out but keeps its exits', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
      scriptId: 5,
      exitTargets: {'PROXY': 'Proxy'},
    );
    await testDatabase.profilesDao.putAll([profile.toCompanion()]);
    await testDatabase.scripts.put(
      Script(
        id: 5,
        label: 'Script',
        lastUpdateTime: DateTime(2026),
      ).toCompanion(),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,global.com,DIRECT', id: 10),
    );
    await testDatabase.rulesDao.putRule(
      Rule.parse('DOMAIN,own.com,DIRECT', id: 11),
      profileId: profile.id,
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.script, isNull);
    expect(state.exitTargets, {'PROXY': 'Proxy'});
    expect(state.addedRules, isEmpty);
    expect(state.rules.map((rule) => rule.id), [11]);
  });

  testWidgets('a custom setup carries the dialers of its own profile', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Home',
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const other = Profile(
      id: 2,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    await testDatabase.profilesDao.putAll([
      profile.toCompanion(),
      other.toCompanion(),
    ]);
    await testDatabase.customProxies.put(
      const CustomProxy(id: 30, definition: {'name': 'Home'}).toCompanion(),
    );
    await testDatabase.proxyDialersDao.set(profile.id, 30, 'Relay');
    await testDatabase.proxyDialersDao.set(other.id, 30, 'Other');
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile, other])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    final state = await container.read(setupStateProvider(profile.id).future);

    expect(state.proxyDialers, {30: 'Relay'});
  });
}
