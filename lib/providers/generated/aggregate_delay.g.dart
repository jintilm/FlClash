// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../aggregate_delay.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aggregateDelayPool)
final aggregateDelayPoolProvider = AggregateDelayPoolProvider._();

final class AggregateDelayPoolProvider
    extends $FunctionalProvider<TaskPool, TaskPool, TaskPool>
    with $Provider<TaskPool> {
  AggregateDelayPoolProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aggregateDelayPoolProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aggregateDelayPoolHash();

  @$internal
  @override
  $ProviderElement<TaskPool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskPool create(Ref ref) {
    return aggregateDelayPool(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskPool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskPool>(value),
    );
  }
}

String _$aggregateDelayPoolHash() =>
    r'9440c313ef41ad293e6e8ee0c0538939b5e4f092';

@ProviderFor(AggregateDelayTest)
final aggregateDelayTestProvider = AggregateDelayTestFamily._();

final class AggregateDelayTestProvider
    extends $NotifierProvider<AggregateDelayTest, AggregateDelayResult> {
  AggregateDelayTestProvider._({
    required AggregateDelayTestFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'aggregateDelayTestProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$aggregateDelayTestHash();

  @override
  String toString() {
    return r'aggregateDelayTestProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AggregateDelayTest create() => AggregateDelayTest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AggregateDelayResult value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AggregateDelayResult>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AggregateDelayTestProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aggregateDelayTestHash() =>
    r'b3549efd1ff5d865784c548cfde9680a3f8306ec';

final class AggregateDelayTestFamily extends $Family
    with
        $ClassFamilyOverride<
          AggregateDelayTest,
          AggregateDelayResult,
          AggregateDelayResult,
          AggregateDelayResult,
          String
        > {
  AggregateDelayTestFamily._()
    : super(
        retry: null,
        name: r'aggregateDelayTestProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AggregateDelayTestProvider call(String targetKey) =>
      AggregateDelayTestProvider._(argument: targetKey, from: this);

  @override
  String toString() => r'aggregateDelayTestProvider';
}

abstract class _$AggregateDelayTest extends $Notifier<AggregateDelayResult> {
  late final _$args = ref.$arg as String;
  String get targetKey => _$args;

  AggregateDelayResult build(String targetKey);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AggregateDelayResult, AggregateDelayResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AggregateDelayResult, AggregateDelayResult>,
              AggregateDelayResult,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
