import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Setup extends SetupAction {
  bool rejectBuild = false;

  @override
  Future<BuiltProfile> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    if (rejectBuild) throw const MessageException('missing chain node');
    return (
      yaml: 'rules: [MATCH,REJECT]',
      md5: 'aggregate',
      counts: (groups: 1, proxies: 2, rules: 1),
      base: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(
    const SetupParams(
      selectedMap: {},
      options: CoreOptions(testUrl: 'test'),
    ),
  );
  const recipe = AggregateConfig(
    baseProfileId: 1,
    sourceIds: {1},
    targetGroup: 'Proxy',
  );
  const profile = Profile(
    id: 2,
    type: ProfileType.aggregate,
    label: 'Aggregate',
    autoUpdateDuration: Duration.zero,
    aggregate: recipe,
  );
  const setupState = SetupState(
    profileId: 2,
    profileLastUpdateDate: null,
    profileType: ProfileType.aggregate,
    rules: [],
    proxyGroups: [],
    addedRules: [],
    script: null,
    overrides: ProfileOverrides(),
    aggregate: recipe,
  );
  late Directory root;
  late _Core core;
  late _Setup setup;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('aggregate-setup-');
    await useAppPaths(root);
    await mockPreferences();
    loadAppLocalizations(const Locale('en'));
    await File(await appPath.configFilePath).writeAsString('previous config');
    globalState.lastConfigMd5 = 'previous';
    globalState.lastConfigCounts = (groups: 2, proxies: 3, rules: 4);
    core = _Core();
    setup = _Setup();
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(all: [], proxies: {}));
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        setupStateProvider.overrideWith((_, _) => setupState),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        safeModeProvider.overrideWithValue(true),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    container.listen(currentProfileIdProvider, (_, _) {});
    globalState.container = container;
    container.read(setupActionProvider);
  });

  tearDown(() async {
    container.dispose();
    globalState.lastConfigMd5 = null;
    globalState.lastConfigCounts = null;
    await root.delete(recursive: true);
  });

  test(
    'a missing chain node preserves the config file and never calls setup',
    () async {
      setup.rejectBuild = true;
      expect(await setup.applyProfile(force: true), isFalse);
      verifyNever(() => core.setupConfig(any()));
      expect(
        await File(await appPath.configFilePath).readAsString(),
        'previous config',
      );
      expect(globalState.lastConfigMd5, 'previous');
      expect(container.read(aggregateRuntimeProvider).applied, isFalse);
      expect(
        container.read(aggregateRuntimeProvider).error,
        contains('missing chain node'),
      );
    },
  );

  test(
    'core rejection restores the previous file, digest and counts',
    () async {
      when(() => core.setupConfig(any())).thenAnswer((call) async {
        expect(
          (call.positionalArguments.single as SetupParams).preserveOnFailure,
          isTrue,
        );
        throw const CoreMethodException(
          code: 'config_preserved',
          message: 'invalid DNS',
        );
      });
      expect(await setup.applyProfile(force: true), isFalse);
      expect(
        await File(await appPath.configFilePath).readAsString(),
        'previous config',
      );
      expect(globalState.lastConfigMd5, 'previous');
      expect(globalState.lastConfigCounts, (groups: 2, proxies: 3, rules: 4));
      expect(container.read(aggregateRuntimeProvider).applied, isFalse);
    },
  );

  test('successful application publishes the applied recipe', () async {
    when(() => core.setupConfig(any())).thenAnswer((_) async {});
    expect(await setup.applyProfile(force: true), isTrue);
    expect(container.read(aggregateRuntimeProvider).applied, isTrue);
    expect(container.read(aggregateRuntimeProvider).settings, recipe);
    expect(globalState.lastConfigMd5, 'aggregate');
  });

  test(
    'an unanswered setup does not claim the previous config is still applied',
    () async {
      when(() => core.setupConfig(any())).thenAnswer(
        (_) async => throw const CoreMethodException(
          code: 'no_response',
          message: 'unanswered',
        ),
      );
      expect(await setup.applyProfile(force: true), isFalse);
      expect(globalState.lastConfigMd5, isNull);
      expect(globalState.lastConfigCounts, isNull);
      expect(
        await File(await appPath.configFilePath).readAsString(),
        'previous config',
      );
    },
  );
}
