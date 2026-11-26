import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/models/aggregation.dart';
import 'package:fl_clash/models/references.dart';

class AggregateNode {
  final AggregateNodeRef ref;
  final String sourceLabel;
  final Map<String, dynamic> definition;

  const AggregateNode(this.ref, this.sourceLabel, this.definition);

  String get name => definition['name'] as String;
  String get type => definition['type'] as String;
  String get runtimeName =>
      '$name · $sourceLabel [${sha256.convert(utf8.encode(ref.key)).toString().substring(0, 10)}]';
  bool get hasDialer =>
      (definition['dialer-proxy'] as String? ?? '').isNotEmpty;
}

class AggregateSource {
  final int id;
  final String label;
  final List<AggregateNode> nodes;
  final List<String> errors;

  const AggregateSource({
    required this.id,
    required this.label,
    this.nodes = const [],
    this.errors = const [],
  });
}

class AggregateDelayTarget {
  final List<AggregateNode> nodes;

  const AggregateDelayTarget(this.nodes);

  String get key => nodes.map((node) => node.ref.key).join(' → ');
  bool get testable =>
      nodes.isNotEmpty &&
      nodes.length <= 2 &&
      nodes.every((node) => !node.hasDialer);
}

enum AggregateIssue {
  missingBase,
  missingSource,
  sourceUnavailable,
  missingGroup,
  empty,
  missingNode,
  duplicateName,
  existingDialer,
  sameHop,
  udpEntry,
  cycle,
  dnsBootstrap,
  missingDnsProxy,
}

class AggregateException implements Exception {
  final AggregateIssue issue;
  final String detail;

  const AggregateException(this.issue, [this.detail = '']);

  @override
  String toString() => '${issue.name}: $detail';
}

Object? _canonical(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.map((key) => key.toString()).sorted())
      key: _canonical(value[key]),
  },
  List() => value.map(_canonical).toList(),
  _ => value,
};

List<AggregateNode> aggregateNodes({
  required int sourceId,
  required String label,
  required String provider,
  required List<Map<String, dynamic>> definitions,
}) {
  final seen = <String>{};
  final nodes = <AggregateNode>[];
  for (final definition in definitions) {
    if (definition['name'] is! String || definition['type'] is! String) {
      continue;
    }
    final identity = _canonical(
      Map<String, dynamic>.of(definition)..remove('name'),
    );
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(identity)))
        .toString();
    if (!seen.add(fingerprint)) continue;
    nodes.add(
      AggregateNode(
        AggregateNodeRef(
          sourceId: sourceId,
          provider: provider,
          fingerprint: fingerprint,
          name: definition['name'] as String,
        ),
        label,
        definition,
      ),
    );
  }
  return nodes;
}

String aggregateChainName(ProxyChain chain) => '${chain.name} [${chain.id}]';

Map<String, String> aggregateSelectedMap(
  AggregateConfig settings,
  Map<String, String> previous, {
  String? chainId,
}) {
  final chain = chainId == null
      ? settings.chains.firstWhereOrNull(
              (chain) =>
                  aggregateChainName(chain) == previous[settings.groupName],
            ) ??
            settings.chains.firstOrNull
      : settings.chains.firstWhereOrNull((chain) => chain.id == chainId);
  if (chainId != null && chain == null) {
    throw AggregateException(AggregateIssue.missingNode, chainId);
  }
  return {
    ...previous,
    settings.targetGroup: settings.groupName,
    'GLOBAL': settings.groupName,
    if (chain != null) settings.groupName: aggregateChainName(chain),
  };
}

List<Map<String, dynamic>> aggregateMappings(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : [];

typedef AggregateBuildInput = ({
  AggregateConfig settings,
  Map<String, dynamic> base,
  List<AggregateSource> sources,
  Set<String> interfaces,
});

Map<String, dynamic> composeAggregate(AggregateBuildInput input) {
  final settings = input.settings;
  final sources = input.sources;
  final base = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(input.base)) as Map,
  );
  final groups = aggregateMappings(base['proxy-groups']);
  final target = groups.firstWhereOrNull(
    (group) =>
        group['name'] == settings.targetGroup && group['type'] == 'select',
  );
  if (target == null) {
    throw AggregateException(AggregateIssue.missingGroup, settings.targetGroup);
  }
  final proxies = aggregateMappings(base['proxies']);
  final baseProxyNames = [for (final proxy in proxies) proxy['name'] as String]
    ..sort();
  for (final group in groups) {
    if (group['include-all'] == true || group['include-all-proxies'] == true) {
      group['proxies'] = {
        ...?((group['proxies'] as List?)?.cast<String>()),
        ...baseProxyNames,
      }.toList();
      if (group['include-all'] == true) group['include-all-providers'] = true;
      group.remove('include-all');
      group.remove('include-all-proxies');
    }
  }
  final names = <String>{
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
    'GLOBAL',
    for (final node in proxies) node['name'] as String,
    for (final group in groups) group['name'] as String,
    for (final source in sources)
      if (source.id == settings.baseProfileId)
        for (final node in source.nodes) node.name,
  };
  void reserve(String name) {
    if (name.trim().isEmpty || !names.add(name)) {
      throw AggregateException(AggregateIssue.duplicateName, name);
    }
  }

  reserve(settings.groupName);
  final sourceMap = {for (final source in sources) source.id: source};
  final nodes = <String, AggregateNode>{};
  final pool = <String>[];
  for (final id in {...settings.sourceIds, ?settings.baseProfileId}) {
    final source = sourceMap[id];
    if (source == null) {
      throw AggregateException(AggregateIssue.missingSource, '$id');
    }
    if (source.errors.isNotEmpty) {
      throw AggregateException(AggregateIssue.sourceUnavailable, source.label);
    }
    for (final node in source.nodes) {
      nodes[node.ref.key] = node;
      if (id == settings.baseProfileId && node.ref.provider.isEmpty) {
        pool.add(node.name);
      } else {
        if (node.hasDialer && id != settings.baseProfileId) {
          throw AggregateException(AggregateIssue.existingDialer, node.name);
        }
        reserve(node.runtimeName);
        proxies.add({...node.definition, 'name': node.runtimeName});
        pool.add(node.runtimeName);
      }
    }
  }
  AggregateNode resolve(AggregateNodeRef ref) =>
      nodes[ref.key] ??
      (throw AggregateException(AggregateIssue.missingNode, ref.name));
  final chainIds = <String>{};
  for (final chain in settings.chains) {
    if (!chainIds.add(chain.id) || chain.name.trim().isEmpty) {
      throw AggregateException(AggregateIssue.duplicateName, chain.name);
    }
    final entry = resolve(chain.entry);
    final exit = resolve(chain.exit);
    if (entry.ref.fingerprint == exit.ref.fingerprint) {
      throw AggregateException(AggregateIssue.sameHop, chain.name);
    }
    for (final node in [entry, exit]) {
      if (node.hasDialer) {
        throw AggregateException(AggregateIssue.existingDialer, node.name);
      }
    }
    if (const {
          'hysteria',
          'hysteria2',
          'tuic',
          'wireguard',
        }.contains(exit.type) &&
        entry.definition['udp'] != true &&
        !const {
          'hysteria',
          'hysteria2',
          'tuic',
          'wireguard',
        }.contains(entry.type)) {
      throw AggregateException(AggregateIssue.udpEntry, entry.name);
    }
    final entryName = '@aggregate-entry:${chain.id}';
    final exitName = aggregateChainName(chain);
    reserve(entryName);
    reserve(exitName);
    proxies.add({...entry.definition, 'name': entryName});
    proxies.add({
      ...exit.definition,
      'name': exitName,
      'dialer-proxy': entryName,
    });
    pool.add(exitName);
  }
  if (pool.isEmpty) throw const AggregateException(AggregateIssue.empty);
  target['proxies'] = [...?target['proxies'] as List?, settings.groupName];
  groups.add({
    'name': settings.groupName,
    'type': 'select',
    'proxies': pool.toSet().toList(),
  });
  base['proxies'] = proxies;
  base['proxy-groups'] = groups;
  validateAggregateDependencies(
    base,
    sources.where((source) => source.id == settings.baseProfileId).toList(),
    interfaces: input.interfaces,
  );
  return base;
}

void validateAggregateDependencies(
  Map<String, dynamic> config,
  List<AggregateSource> sources, {
  Set<String> interfaces = const {},
}) {
  final definitions = {
    for (final source in sources)
      for (final node in source.nodes) node.name: node.definition,
    for (final node in aggregateMappings(config['proxies']))
      node['name'] as String: node,
  };
  final groups = aggregateMappings(config['proxy-groups']);
  final providerNodes = <String, Set<String>>{};
  for (final source in sources) {
    for (final node in source.nodes) {
      providerNodes.putIfAbsent(node.ref.provider, () => {}).add(node.name);
    }
  }
  final edges = <String, Set<String>>{
    for (final MapEntry(:key, :value) in definitions.entries)
      key: {
        if (value['dialer-proxy'] case final String dialer
            when dialer.isNotEmpty)
          dialer,
      },
    for (final group in groups)
      group['name'] as String: {
        ...?((group['proxies'] as List?)?.cast<String>()),
        if (group['include-all'] == true ||
            group['include-all-proxies'] == true)
          ...definitions.keys,
        for (final name in (group['use'] as List? ?? const []))
          ...?providerNodes[name],
        if (group['include-all-providers'] == true ||
            group['include-all'] == true)
          for (final name in providerNodes.keys.where(
            (name) => name.isNotEmpty,
          ))
            ...providerNodes[name]!,
      },
  };
  final visited = <String>{};
  final active = <String>{};
  void visit(String name) {
    if (active.contains(name)) {
      throw AggregateException(AggregateIssue.cycle, name);
    }
    if (!visited.add(name)) return;
    active.add(name);
    for (final next in edges[name] ?? const <String>{}) {
      visit(next);
    }
    active.remove(name);
  }

  for (final name in edges.keys) {
    visit(name);
  }
  final dns = config['dns'];
  if (dns is! Map || dns['enable'] != true) return;
  List<String> servers(Object? value) => switch (value) {
    String() => [value],
    List() => value.whereType<String>().toList(),
    Map() => value.values.expand(servers).toList(),
    _ => [],
  };
  final mainServers = [
    ...servers(dns['nameserver']),
    ...servers(dns['fallback']),
    ...servers(dns['nameserver-policy']),
  ];
  final allServers = [
    ...mainServers,
    ...servers(dns['proxy-server-nameserver']),
    ...servers(dns['proxy-server-nameserver-policy']),
    ...servers(dns['default-nameserver']),
    ...servers(dns['direct-nameserver']),
  ];
  for (final server in allServers) {
    for (final name in dnsServerProxies(server)) {
      if (!edges.containsKey(name) &&
          !interfaces.contains(name) &&
          !const {
            'DIRECT',
            'RULES',
            'GLOBAL',
            'REJECT',
            'PASS',
          }.contains(name)) {
        throw AggregateException(AggregateIssue.missingDnsProxy, name);
      }
    }
  }
  final usesProxy =
      dns['respect-rules'] == true ||
      mainServers.any(
        (server) => dnsServerProxies(
          server,
        ).any((name) => name == 'RULES' || edges.containsKey(name)),
      );
  final proxyServers = servers(dns['proxy-server-nameserver']);
  if (usesProxy && proxyServers.isEmpty) {
    throw const AggregateException(AggregateIssue.dnsBootstrap);
  }
  final bootstrap = [
    ...proxyServers,
    ...servers(dns['proxy-server-nameserver-policy']),
    ...servers(dns['default-nameserver']),
  ];
  for (final server in bootstrap) {
    for (final target in dnsServerProxies(server)) {
      if (target == 'RULES') {
        throw const AggregateException(AggregateIssue.dnsBootstrap);
      }
      final pending = [target];
      final checked = <String>{};
      while (pending.isNotEmpty) {
        final name = pending.removeLast();
        if (!checked.add(name)) continue;
        final host = definitions[name]?['server'];
        if (host is String && InternetAddress.tryParse(host) == null) {
          final hosts = config['hosts'];
          if (hosts is! Map || !hosts.containsKey(host)) {
            throw AggregateException(AggregateIssue.dnsBootstrap, name);
          }
        }
        pending.addAll(edges[name] ?? const {});
      }
    }
  }
}
