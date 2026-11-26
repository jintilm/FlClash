// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../aggregation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AggregateRuntime)
final aggregateRuntimeProvider = AggregateRuntimeProvider._();

final class AggregateRuntimeProvider
    extends
        $NotifierProvider<
          AggregateRuntime,
          ({
            bool applied,
            String? error,
            int? profileId,
            AggregateConfig? settings,
          })
        > {
  AggregateRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aggregateRuntimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aggregateRuntimeHash();

  @$internal
  @override
  AggregateRuntime create() => AggregateRuntime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({bool applied, String? error, int? profileId, AggregateConfig? settings})
    value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({
              bool applied,
              String? error,
              int? profileId,
              AggregateConfig? settings,
            })
          >(value),
    );
  }
}

String _$aggregateRuntimeHash() => r'c246354c0158e90207d6b7e9c8471b09f0efb709';

abstract class _$AggregateRuntime
    extends
        $Notifier<
          ({
            bool applied,
            String? error,
            int? profileId,
            AggregateConfig? settings,
          })
        > {
  ({bool applied, String? error, int? profileId, AggregateConfig? settings})
  build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({
                bool applied,
                String? error,
                int? profileId,
                AggregateConfig? settings,
              }),
              ({
                bool applied,
                String? error,
                int? profileId,
                AggregateConfig? settings,
              })
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({
                  bool applied,
                  String? error,
                  int? profileId,
                  AggregateConfig? settings,
                }),
                ({
                  bool applied,
                  String? error,
                  int? profileId,
                  AggregateConfig? settings,
                })
              >,
              ({
                bool applied,
                String? error,
                int? profileId,
                AggregateConfig? settings,
              }),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(aggregateSource)
final aggregateSourceProvider = AggregateSourceFamily._();

final class AggregateSourceProvider
    extends
        $FunctionalProvider<
          AsyncValue<AggregateSource>,
          AggregateSource,
          FutureOr<AggregateSource>
        >
    with $FutureModifier<AggregateSource>, $FutureProvider<AggregateSource> {
  AggregateSourceProvider._({
    required AggregateSourceFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'aggregateSourceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$aggregateSourceHash();

  @override
  String toString() {
    return r'aggregateSourceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AggregateSource> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AggregateSource> create(Ref ref) {
    final argument = this.argument as int;
    return aggregateSource(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AggregateSourceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aggregateSourceHash() => r'a94a30574c3738aada057ecdbc9d2bba7970db1f';

final class AggregateSourceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AggregateSource>, int> {
  AggregateSourceFamily._()
    : super(
        retry: null,
        name: r'aggregateSourceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AggregateSourceProvider call(int id) =>
      AggregateSourceProvider._(argument: id, from: this);

  @override
  String toString() => r'aggregateSourceProvider';
}

@ProviderFor(AggregateAction)
final aggregateActionProvider = AggregateActionProvider._();

final class AggregateActionProvider
    extends $NotifierProvider<AggregateAction, void> {
  AggregateActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aggregateActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aggregateActionHash();

  @$internal
  @override
  AggregateAction create() => AggregateAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$aggregateActionHash() => r'8e54bc922c9c5354005d15bcc7a4e9a464d6c117';

abstract class _$AggregateAction extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
