// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workoutHash() => r'd2454c57e2d5ff62dee13c5b574fc6d6e8220133';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Single Workout Provider
///
/// Copied from [workout].
@ProviderFor(workout)
const workoutProvider = WorkoutFamily();

/// Single Workout Provider
///
/// Copied from [workout].
class WorkoutFamily extends Family<AsyncValue<WorkoutSession?>> {
  /// Single Workout Provider
  ///
  /// Copied from [workout].
  const WorkoutFamily();

  /// Single Workout Provider
  ///
  /// Copied from [workout].
  WorkoutProvider call(
    String id,
  ) {
    return WorkoutProvider(
      id,
    );
  }

  @override
  WorkoutProvider getProviderOverride(
    covariant WorkoutProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workoutProvider';
}

/// Single Workout Provider
///
/// Copied from [workout].
class WorkoutProvider extends AutoDisposeFutureProvider<WorkoutSession?> {
  /// Single Workout Provider
  ///
  /// Copied from [workout].
  WorkoutProvider(
    String id,
  ) : this._internal(
          (ref) => workout(
            ref as WorkoutRef,
            id,
          ),
          from: workoutProvider,
          name: r'workoutProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workoutHash,
          dependencies: WorkoutFamily._dependencies,
          allTransitiveDependencies: WorkoutFamily._allTransitiveDependencies,
          id: id,
        );

  WorkoutProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<WorkoutSession?> Function(WorkoutRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkoutProvider._internal(
        (ref) => create(ref as WorkoutRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<WorkoutSession?> createElement() {
    return _WorkoutProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WorkoutRef on AutoDisposeFutureProviderRef<WorkoutSession?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _WorkoutProviderElement
    extends AutoDisposeFutureProviderElement<WorkoutSession?> with WorkoutRef {
  _WorkoutProviderElement(super.provider);

  @override
  String get id => (origin as WorkoutProvider).id;
}

String _$workoutRouteHash() => r'0ce658d78fa1f40cbc28d3882eb88a4387bed709';

/// See also [workoutRoute].
@ProviderFor(workoutRoute)
const workoutRouteProvider = WorkoutRouteFamily();

/// See also [workoutRoute].
class WorkoutRouteFamily extends Family<AsyncValue<List<LatLng>>> {
  /// See also [workoutRoute].
  const WorkoutRouteFamily();

  /// See also [workoutRoute].
  WorkoutRouteProvider call(
    String id,
  ) {
    return WorkoutRouteProvider(
      id,
    );
  }

  @override
  WorkoutRouteProvider getProviderOverride(
    covariant WorkoutRouteProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'workoutRouteProvider';
}

/// See also [workoutRoute].
class WorkoutRouteProvider extends AutoDisposeFutureProvider<List<LatLng>> {
  /// See also [workoutRoute].
  WorkoutRouteProvider(
    String id,
  ) : this._internal(
          (ref) => workoutRoute(
            ref as WorkoutRouteRef,
            id,
          ),
          from: workoutRouteProvider,
          name: r'workoutRouteProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$workoutRouteHash,
          dependencies: WorkoutRouteFamily._dependencies,
          allTransitiveDependencies:
              WorkoutRouteFamily._allTransitiveDependencies,
          id: id,
        );

  WorkoutRouteProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<List<LatLng>> Function(WorkoutRouteRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorkoutRouteProvider._internal(
        (ref) => create(ref as WorkoutRouteRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LatLng>> createElement() {
    return _WorkoutRouteProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutRouteProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WorkoutRouteRef on AutoDisposeFutureProviderRef<List<LatLng>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _WorkoutRouteProviderElement
    extends AutoDisposeFutureProviderElement<List<LatLng>>
    with WorkoutRouteRef {
  _WorkoutRouteProviderElement(super.provider);

  @override
  String get id => (origin as WorkoutRouteProvider).id;
}

String _$workoutListHash() => r'e3071320b8909ab3427a5720a60e78def3b940cd';

/// Workout List Provider
///
/// Copied from [WorkoutList].
@ProviderFor(WorkoutList)
final workoutListProvider = AutoDisposeAsyncNotifierProvider<WorkoutList,
    List<WorkoutSession>>.internal(
  WorkoutList.new,
  name: r'workoutListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$workoutListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WorkoutList = AutoDisposeAsyncNotifier<List<WorkoutSession>>;
String _$activeWorkoutHash() => r'26bf8da3f0954038dcf4ebeca436e8c08a90b154';

/// Active Workout Provider
///
/// Copied from [ActiveWorkout].
@ProviderFor(ActiveWorkout)
final activeWorkoutProvider =
    AutoDisposeNotifierProvider<ActiveWorkout, String?>.internal(
  ActiveWorkout.new,
  name: r'activeWorkoutProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeWorkoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveWorkout = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
