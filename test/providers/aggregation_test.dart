import 'package:drift/native.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';

void main() {
  test(
    'dashboard context remains available for an aggregate with only single nodes',
    () {
      const profile = Profile(
        id: 3,
        type: ProfileType.aggregate,
        autoUpdateDuration: Duration.zero,
        aggregate: AggregateConfig(targetGroup: 'Proxy'),
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => 3),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(aggregateRouteContextProvider), (
        profileId: 3,
        settings: profile.aggregate!,
      ));
    },
  );

  test(
    'aggregate profile recipe survives database storage and draft edits stay separate',
    () async {
      final database = db.Database(NativeDatabase.memory());
      addTearDown(database.close);
      const applied = AggregateConfig(
        baseProfileId: 1,
        sourceIds: {1, 2},
        targetGroup: 'Proxy',
      );
      const profile = Profile(
        id: 3,
        type: ProfileType.aggregate,
        label: 'Aggregate',
        autoUpdateDuration: Duration.zero,
        aggregate: applied,
      );
      await database.profilesDao.setAll([profile]);
      expect((await database.profilesDao.get(3))?.aggregate, applied);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          aggregateWorkspaceSettingProvider.overrideWithBuild(
            (_, _) => const AggregateWorkspace(profileId: 3, draft: applied),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(aggregateWorkspaceSettingProvider, (_, _) {});
      container
          .read(aggregateActionProvider.notifier)
          .setDraft(applied.copyWith(sourceIds: {1}));
      expect(
        container.read(aggregateWorkspaceSettingProvider).draft.sourceIds,
        {1},
      );
      expect(container.read(profilesProvider).single.aggregate, applied);
      expect((await database.profilesDao.get(3))?.aggregate, applied);
    },
  );

  test('a missing base cannot apply or change the selected profile', () async {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles()),
        aggregateWorkspaceSettingProvider.overrideWithBuild(
          (_, _) => const AggregateWorkspace(
            draft: AggregateConfig(baseProfileId: 99),
          ),
        ),
        currentProfileIdProvider.overrideWithBuild((_, _) => 7),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentProfileIdProvider, (_, _) {});
    await expectLater(
      container.read(aggregateActionProvider.notifier).apply(),
      throwsA(isA<MessageException>()),
    );
    expect(container.read(currentProfileIdProvider), 7);
  });
}
