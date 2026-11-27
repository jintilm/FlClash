import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(const SetupBase(path: '', overlay: ''));
  registerFallbackValue(
    const SetupParams(
      selectedMap: {},
      options: CoreOptions(testUrl: ''),
    ),
  );

  for (final coldStart in [false, true]) {
    test(
      'the real aggregate apply builds and loads a chain (source changes while loading: $coldStart)',
      () async {
        final root = await Directory.systemTemp.createTemp('aggregate-apply-');
        await useAppPaths(root);
        await mockPreferences();
        final database = db.Database(NativeDatabase.memory());
        db.database = database;
        final core = _Core();
        final baseLoading = Completer<void>();
        final resumeBase = Completer<void>();
        var holdBase = false;
        loadAppLocalizations(const Locale('en'));
        globalState.packageInfo = PackageInfo(
          appName: 'FlClash',
          packageName: 'test',
          version: '0.0.0',
          buildNumber: '0',
        );
        const base = Profile(
          id: 1,
          type: ProfileType.file,
          label: 'Base',
          autoUpdateDuration: Duration.zero,
          selectedMap: {'Proxy': 'entry', 'GLOBAL': 'entry'},
        );
        const subscription = Profile(
          id: 2,
          type: ProfileType.file,
          label: 'Subscription',
          autoUpdateDuration: Duration.zero,
        );
        final entry = aggregateNodes(
          sourceId: 1,
          label: 'Base',
          provider: '',
          definitions: [
            {
              'name': 'entry',
              'type': 'http',
              'server': '192.0.2.1',
              'port': 80,
            },
          ],
        ).single;
        final exit = aggregateNodes(
          sourceId: 2,
          label: 'Subscription',
          provider: '',
          definitions: [
            {
              'name': 'exit',
              'type': 'socks5',
              'server': '192.0.2.2',
              'port': 1080,
            },
          ],
        ).single;
        final recipe = AggregateConfig(
          baseProfileId: 1,
          sourceIds: {1, 2},
          targetGroup: 'Proxy',
          chains: [
            ProxyChain(
              id: 'chain',
              name: 'Chain',
              entry: entry.ref,
              exit: exit.ref,
            ),
          ],
        );
        when(() => core.getProfileBase(any())).thenAnswer(
          (_) async => const ProfileBase(
            config: {
              'dns': {
                'enable': true,
                'nameserver': ['https://1.1.1.1/dns-query#Proxy'],
                'proxy-server-nameserver': ['223.5.5.5'],
              },
            },
            digest: 'base',
            matchRules: ['MATCH,Proxy'],
            proxies: 1,
            proxyGroups: 1,
            rules: 1,
          ),
        );
        var spillId = 0;
        when(() => core.buildProfile(any())).thenAnswer((call) async {
          final overlay =
              loadPlainYaml(
                    (call.positionalArguments.single as SetupBase).overlay,
                  )
                  as Map;
          final output = {
            ...overlay,
            'proxies': [entry.definition],
            'proxy-groups': [
              {
                'name': 'Proxy',
                'type': 'select',
                'proxies': ['entry'],
              },
            ],
            'rules': ['MATCH,Proxy'],
          };
          final file = File('${root.path}/responses/${spillId++}.yaml');
          await file.parent.create(recursive: true);
          await file.writeAsString(yaml.encode(output));
          return file.path;
        });
        when(() => core.readConfig(any())).thenAnswer(
          (_) async => {
            'proxies': [exit.definition],
            'rule': <String>[],
          },
        );
        when(() => core.validateConfig(any())).thenAnswer((_) async {
          holdBase = coldStart;
          return null;
        });
        final pushed = <SetupParams>[];
        when(() => core.setupConfig(any())).thenAnswer((call) async {
          pushed.add(call.positionalArguments.single as SetupParams);
        });
        when(
          () => core.getProxies(),
        ).thenAnswer((_) async => const ProxiesData(proxies: {}, all: []));
        when(() => core.getExternalProviders()).thenAnswer((_) async => []);
        final container = ProviderContainer(
          overrides: [
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            profilesProvider.overrideWith(
              () => TestProfiles([base, subscription]),
            ),
            currentProfileIdProvider.overrideWithBuild((_, _) => base.id),
            aggregateWorkspaceSettingProvider.overrideWithBuild(
              (_, _) => AggregateWorkspace(draft: recipe),
            ),
            safeModeProvider.overrideWithValue(true),
            if (coldStart)
              setupStateProvider(base.id).overrideWith((ref) async {
                final value = setupState(ref, base.id);
                if (holdBase) {
                  if (!baseLoading.isCompleted) baseLoading.complete();
                  await resumeBase.future;
                }
                return value;
              }),
          ],
        );
        globalState.container = container;
        addTearDown(() async {
          container.dispose();
          globalState.lastConfigMd5 = null;
          globalState.lastConfigCounts = null;
          await database.close();
          await root.delete(recursive: true);
        });
        container.listen(currentProfileIdProvider, (_, _) {});
        container.listen(aggregateWorkspaceSettingProvider, (_, _) {});
        final firstApply = container
            .read(aggregateActionProvider.notifier)
            .apply();
        if (coldStart) {
          await baseLoading.future.timeout(const Duration(seconds: 5));
          container
              .read(profilesProvider.notifier)
              .put(
                subscription.copyWith(
                  lastUpdateDate: DateTime.fromMillisecondsSinceEpoch(1000),
                ),
              );
          await container.pump();
          resumeBase.complete();
        }
        await firstApply;
        expect(pushed, hasLength(1));
        expect(pushed.single.preserveOnFailure, isTrue);
        expect(pushed.single.selectedMap['Proxy'], recipe.groupName);
        expect(pushed.single.selectedMap['GLOBAL'], recipe.groupName);
        expect(pushed.single.selectedMap[recipe.groupName], 'Chain [chain]');
        final selected = container.read(currentProfileProvider)!;
        expect(selected.type, ProfileType.aggregate);
        expect(
          (await database.profilesDao.get(selected.id))?.aggregate,
          recipe,
        );
        expect(container.read(aggregateRuntimeProvider).applied, isTrue);
        final output =
            loadPlainYaml(
                  await File(await appPath.configFilePath).readAsString(),
                )
                as Map;
        expect((output['dns'] as Map)['proxy-server-nameserver'], [
          '223.5.5.5',
        ]);
        final chainExit = (output['proxies'] as List).cast<Map>().singleWhere(
          (node) => node['name'] == 'Chain [chain]',
        );
        expect(
          chainExit['dialer-proxy'],
          aggregateEntryName(recipe.chains.single),
        );
        final second = recipe.chains.single.copyWith(
          id: 'second',
          name: 'Second',
        );
        final updated = recipe.copyWith(chains: [...recipe.chains, second]);
        container.read(aggregateActionProvider.notifier).setDraft(updated);
        await container
            .read(aggregateActionProvider.notifier)
            .apply(chainId: second.id);
        expect(
          pushed.last.selectedMap[recipe.groupName],
          aggregateChainName(second),
        );
        expect(pushed.last.selectedMap['Proxy'], recipe.groupName);
        expect(
          (await database.profilesDao.get(
            selected.id,
          ))?.selectedMap[recipe.groupName],
          aggregateChainName(second),
        );
      },
    );
  }
}
