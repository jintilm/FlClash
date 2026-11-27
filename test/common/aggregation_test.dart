import 'dart:convert';

import 'package:fl_clash/common/aggregation.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> node(String name, String host, {String? dialer}) => {
  'name': name,
  'type': 'socks5',
  'server': host,
  'port': 1080,
  'udp': true,
  'dialer-proxy': ?dialer,
};

AggregateSource source(
  int id,
  List<Map<String, dynamic>> nodes, {
  String provider = '',
}) => AggregateSource(
  id: id,
  label: 'Source $id',
  nodes: aggregateNodes(
    sourceId: id,
    label: 'Source $id',
    provider: provider,
    definitions: nodes,
  ),
);

Map<String, dynamic> base(
  List<Map<String, dynamic>> proxies, {
  Map<String, dynamic>? dns,
}) => {
  'proxies': proxies,
  'proxy-groups': [
    {
      'name': 'Proxy',
      'type': 'select',
      'proxies': proxies.map((n) => n['name']).toList(),
    },
  ],
  'rules': ['DOMAIN,example.org,DIRECT', 'MATCH,Proxy'],
  'dns':
      dns ??
      {
        'enable': true,
        'nameserver': ['https://1.1.1.1/dns-query#Proxy'],
        'proxy-server-nameserver': ['223.5.5.5'],
      },
  'rule-providers': {
    'private': {
      'type': 'inline',
      'behavior': 'domain',
      'payload': ['example.org'],
    },
  },
};

void main() {
  const recipe = AggregateConfig(
    baseProfileId: 1,
    sourceIds: {1, 2},
    targetGroup: 'Proxy',
  );
  final a = source(1, [node('Same', '192.0.2.1')]);
  final b = source(2, [node('Same', '192.0.2.2')]);
  final chain = ProxyChain(
    id: 'test',
    name: 'Work',
    entry: a.nodes.single.ref,
    exit: b.nodes.single.ref,
  );
  final original = base([a.nodes.single.definition]);

  test('legacy two-hop recipes and new relay lists both round-trip', () {
    final old = jsonDecode(jsonEncode(chain.toJson())) as Map<String, dynamic>;
    old.remove('relays');
    expect(ProxyChain.fromJson(old).hops, [chain.entry, chain.exit]);
    final multi = chain.copyWith(
      relays: [chain.entry.copyWith(fingerprint: 'middle')],
    );
    final restored = ProxyChain.fromJson(
      jsonDecode(jsonEncode(multi.toJson())) as Map<String, dynamic>,
    );
    expect(restored.hops, [chain.entry, multi.relays.single, chain.exit]);
    expect(restored, multi);
  });

  for (final count in [3, maxAggregateHops]) {
    test('composes $count hops in order without changing the sources', () {
      final middle = source(3, [
        for (var i = 0; i < count - 2; i++)
          node('Relay $i', '192.0.2.${10 + i}'),
      ]);
      final multi = chain.copyWith(
        relays: middle.nodes.map((node) => node.ref).toList(),
      );
      final settings = recipe.copyWith(sourceIds: {1, 2, 3}, chains: [multi]);
      final before = jsonEncode(original);
      final result = composeAggregate((
        settings: settings,
        base: original,
        sources: [a, b, middle],
        interfaces: const {},
      ));
      final definitions = {
        for (final node in aggregateMappings(result['proxies']))
          node['name']: node,
      };
      for (var i = 0; i < count; i++) {
        final node = definitions[aggregateHopName(multi, i)]!;
        expect(
          node['dialer-proxy'],
          i == 0 ? null : aggregateHopName(multi, i - 1),
        );
        expect(
          node['server'],
          [
            a.nodes.single,
            ...middle.nodes,
            b.nodes.single,
          ][i].definition['server'],
        );
      }
      expect(result['dns'], original['dns']);
      expect(result['rules'], original['rules']);
      expect(jsonEncode(original), before);
      final changed = multi.copyWith(
        relays: [...multi.relays]
          ..[0] = multi.relays.first.copyWith(fingerprint: 'changed'),
      );
      expect(aggregateEntryName(changed), isNot(aggregateEntryName(multi)));
      expect(
        AggregateDelayTarget([
          a.nodes.single,
          ...middle.nodes,
          b.nodes.single,
        ]).testable,
        isTrue,
      );
    });
  }

  test('rejects repeated or missing relay hops and chains above the limit', () {
    void build(ProxyChain chain) => composeAggregate((
      settings: recipe.copyWith(chains: [chain]),
      base: original,
      sources: [a, b],
      interfaces: const {},
    ));
    expect(
      () => build(chain.copyWith(relays: [chain.entry])),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.sameHop,
        ),
      ),
    );
    expect(
      () => build(
        chain.copyWith(relays: [chain.entry.copyWith(fingerprint: 'missing')]),
      ),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.missingNode,
        ),
      ),
    );
    expect(
      () => build(
        chain.copyWith(relays: List.filled(maxAggregateHops, chain.entry)),
      ),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.hopLimit,
        ),
      ),
    );
  });

  test('validates UDP requirements at an intermediate hop', () {
    final middle = source(3, [
      {'name': 'TCP relay', 'type': 'http', 'server': '192.0.2.3', 'port': 80},
      {
        'name': 'QUIC relay',
        'type': 'hysteria2',
        'server': '192.0.2.4',
        'port': 443,
        'password': 'test',
      },
    ]);
    final multi = chain.copyWith(
      relays: middle.nodes.map((node) => node.ref).toList(),
    );
    expect(
      () => composeAggregate((
        settings: recipe.copyWith(sourceIds: {1, 2, 3}, chains: [multi]),
        base: original,
        sources: [a, b, middle],
        interfaces: const {},
      )),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.udpEntry,
        ),
      ),
    );
  });

  test('entry transport names change when either hop changes', () {
    final originalName = aggregateEntryName(chain);
    expect(
      aggregateEntryName(
        chain.copyWith(entry: chain.entry.copyWith(fingerprint: 'new')),
      ),
      isNot(originalName),
    );
    expect(
      aggregateEntryName(
        chain.copyWith(exit: chain.exit.copyWith(fingerprint: 'new')),
      ),
      isNot(originalName),
    );
  });

  test(
    'delay sorting is stable and puts missing and failed results last in either direction',
    () {
      final keys = ['unknown', 'fast', 'failed', 'same', 'slow'];
      final delays = {'fast': 40, 'same': 40, 'slow': 200, 'failed': -1};
      expect(
        orderAggregateDelays((
          keys: keys,
          delays: delays,
          order: AggregateDelaySort.ascending,
        )),
        ['fast', 'same', 'slow', 'unknown', 'failed'],
      );
      expect(
        orderAggregateDelays((
          keys: keys,
          delays: delays,
          order: AggregateDelaySort.descending,
        )),
        ['slow', 'fast', 'same', 'unknown', 'failed'],
      );
      expect(
        orderAggregateDelays((
          keys: keys,
          delays: delays,
          order: AggregateDelaySort.original,
        )),
        keys,
      );
    },
  );

  test('applying selects the chain behind both rule and global groups', () {
    final settings = recipe.copyWith(chains: [chain]);
    expect(
      aggregateSelectedMap(settings, {'Proxy': 'Same', 'Other': 'DIRECT'}),
      {
        'Proxy': 'Aggregate',
        'GLOBAL': 'Aggregate',
        'Aggregate': aggregateChainName(chain),
        'Other': 'DIRECT',
      },
    );
  });

  test('keeps the chosen chain and supports choosing a different chain', () {
    final second = chain.copyWith(id: 'second', name: 'Second');
    final settings = recipe.copyWith(chains: [chain, second]);
    final previous = {'Aggregate': aggregateChainName(second)};
    expect(
      aggregateSelectedMap(settings, previous)['Aggregate'],
      aggregateChainName(second),
    );
    expect(
      aggregateSelectedMap(settings, previous, chainId: chain.id)['Aggregate'],
      aggregateChainName(chain),
    );
    expect(
      () => aggregateSelectedMap(settings, previous, chainId: 'missing'),
      throwsA(isA<AggregateException>()),
    );
    expect(
      aggregateSelectedMap(recipe, {'Proxy': 'Same'})['Proxy'],
      'Aggregate',
    );
  });

  test(
    'keeps DNS, rules and original nodes while isolating names and chain instances',
    () {
      final before = jsonEncode(original);
      final result = composeAggregate((
        interfaces: const <String>{},
        settings: recipe.copyWith(chains: [chain]),
        base: original,
        sources: [a, b],
      ));
      expect(result['dns'], original['dns']);
      expect(result['rules'], original['rules']);
      expect(result['rule-providers'], original['rule-providers']);
      expect(jsonEncode(original), before);
      final proxies = aggregateMappings(result['proxies']);
      expect(proxies.map((p) => p['name']).toSet().length, proxies.length);
      final exit = proxies.singleWhere(
        (p) => p['name'] == aggregateChainName(chain),
      );
      final entry = proxies.singleWhere(
        (p) => p['name'] == exit['dialer-proxy'],
      );
      expect(entry['server'], '192.0.2.1');
      expect(entry['name'], contains(chain.entry.name));
      expect(exit['server'], '192.0.2.2');
      expect(proxies.first, a.nodes.single.definition);
      expect(aggregateMappings(result['proxy-groups']).first['proxies'], [
        'Same',
        'Aggregate',
      ]);
    },
  );

  test(
    'fingerprints ignore names and map order but distinguish changed credentials',
    () {
      final renamed = source(2, [
        {...b.nodes.single.definition, 'name': 'Renamed'},
      ]);
      expect(renamed.nodes.single.ref.key, b.nodes.single.ref.key);
      final changed = source(2, [
        {...b.nodes.single.definition, 'password': 'changed'},
      ]);
      expect(changed.nodes.single.ref.key, isNot(b.nodes.single.ref.key));
      expect(
        () => composeAggregate((
          interfaces: const <String>{},
          settings: recipe.copyWith(chains: [chain]),
          base: original,
          sources: [a, changed],
        )),
        throwsA(
          isA<AggregateException>().having(
            (e) => e.issue,
            'issue',
            AggregateIssue.missingNode,
          ),
        ),
      );
      expect(
        () => composeAggregate((
          interfaces: const <String>{},
          settings: recipe.copyWith(chains: [chain]),
          base: original,
          sources: [a, renamed],
        )),
        returnsNormally,
      );
    },
  );

  test('a provider member is materialized so a group can name it directly', () {
    final provider = source(1, [
      node('From provider', '192.0.2.3'),
    ], provider: 'Remote');
    final result = composeAggregate((
      interfaces: const <String>{},
      settings: recipe,
      base: original,
      sources: [
        AggregateSource(
          id: 1,
          label: 'Source 1',
          nodes: [...a.nodes, ...provider.nodes],
        ),
        b,
      ],
    ));
    final names = aggregateMappings(
      result['proxies'],
    ).map((p) => p['name']).toSet();
    final candidates =
        aggregateMappings(result['proxy-groups']).last['proxies'] as List;
    expect(names.containsAll(candidates), isTrue);
  });

  test('include-all-proxies keeps the original candidate set', () {
    final config = base([a.nodes.single.definition]);
    (config['proxy-groups'] as List).add({
      'name': 'Auto',
      'type': 'url-test',
      'include-all-proxies': true,
    });
    final result = composeAggregate((
      interfaces: const <String>{},
      settings: recipe.copyWith(chains: [chain]),
      base: config,
      sources: [a, b],
    ));
    final auto = aggregateMappings(
      result['proxy-groups'],
    ).singleWhere((g) => g['name'] == 'Auto');
    expect(auto['include-all-proxies'], isNull);
    expect(auto['proxies'], ['Same']);
  });

  test(
    'rejects source removal, unknown target, same hop and preexisting chains',
    () {
      expect(
        () => composeAggregate((
          interfaces: const {},
          settings: recipe,
          base: original,
          sources: [a],
        )),
        throwsA(isA<AggregateException>()),
      );
      expect(
        () => composeAggregate((
          interfaces: const <String>{},
          settings: recipe.copyWith(targetGroup: 'Gone'),
          base: original,
          sources: [a, b],
        )),
        throwsA(isA<AggregateException>()),
      );
      expect(
        () => composeAggregate((
          interfaces: const <String>{},
          settings: recipe.copyWith(
            chains: [chain.copyWith(exit: chain.entry)],
          ),
          base: original,
          sources: [a, b],
        )),
        throwsA(
          isA<AggregateException>().having(
            (e) => e.issue,
            'issue',
            AggregateIssue.sameHop,
          ),
        ),
      );
      final chained = source(2, [
        node('Chained', '192.0.2.2', dialer: 'Other'),
      ]);
      expect(
        () => composeAggregate((
          interfaces: const <String>{},
          settings: recipe,
          base: original,
          sources: [a, chained],
        )),
        throwsA(
          isA<AggregateException>().having(
            (e) => e.issue,
            'issue',
            AggregateIssue.existingDialer,
          ),
        ),
      );
    },
  );

  test('allows DNS through a chain with independent node bootstrap', () {
    final config = base(
      [a.nodes.single.definition],
      dns: {
        'enable': true,
        'respect-rules': true,
        'nameserver': [
          'https://1.1.1.1/dns-query#${aggregateChainName(chain)}',
        ],
        'proxy-server-nameserver': ['223.5.5.5'],
        'default-nameserver': ['223.5.5.5'],
      },
    );
    expect(
      () => composeAggregate((
        interfaces: const <String>{},
        settings: recipe.copyWith(chains: [chain]),
        base: config,
        sources: [a, b],
      )),
      returnsNormally,
    );
  });

  test('rejects cold-start bootstrap cycles and missing node resolver', () {
    final domain = source(1, [node('Domain node', 'entry.example.org')]);
    final config = base(
      [domain.nodes.single.definition],
      dns: {
        'enable': true,
        'nameserver': ['https://1.1.1.1/dns-query#Proxy'],
        'proxy-server-nameserver': ['https://1.1.1.1/dns-query#Proxy'],
      },
    );
    expect(
      () => composeAggregate((
        interfaces: const <String>{},
        settings: recipe,
        base: config,
        sources: [domain, b],
      )),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.dnsBootstrap,
        ),
      ),
    );
    (config['dns'] as Map).remove('proxy-server-nameserver');
    expect(
      () => composeAggregate((
        interfaces: const <String>{},
        settings: recipe,
        base: config,
        sources: [domain, b],
      )),
      throwsA(
        isA<AggregateException>().having(
          (e) => e.issue,
          'issue',
          AggregateIssue.dnsBootstrap,
        ),
      ),
    );
  });

  test('preserves drafts and applied recipes through JSON serialization', () {
    final config = recipe.copyWith(chains: [chain]);
    final workspace = AggregateWorkspace(
      profileId: 7,
      draft: config,
      favorites: {chain.entry.key},
    );
    expect(
      AggregateWorkspace.fromJson(
        jsonDecode(jsonEncode(workspace.toJson())) as Map<String, dynamic>,
      ),
      workspace,
    );
    final profile = Profile(
      id: 7,
      autoUpdateDuration: Duration.zero,
      aggregate: config,
    );
    expect(
      Profile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      ),
      profile,
    );
  });
}
