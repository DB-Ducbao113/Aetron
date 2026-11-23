// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userProfileLocalDataSourceHash() =>
    r'601084b3ba863336069e88e576f44c030937684b';

/// See also [userProfileLocalDataSource].
@ProviderFor(userProfileLocalDataSource)
final userProfileLocalDataSourceProvider =
    AutoDisposeProvider<UserProfileLocalDataSource>.internal(
  userProfileLocalDataSource,
  name: r'userProfileLocalDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileLocalDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserProfileLocalDataSourceRef
    = AutoDisposeProviderRef<UserProfileLocalDataSource>;
String _$userProfileRemoteDataSourceHash() =>
    r'b4ecd14a879550a48321b83bd0b77f5a4c4b03e7';

/// See also [userProfileRemoteDataSource].
@ProviderFor(userProfileRemoteDataSource)
final userProfileRemoteDataSourceProvider =
    AutoDisposeProvider<UserProfileRemoteDataSource>.internal(
  userProfileRemoteDataSource,
  name: r'userProfileRemoteDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileRemoteDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserProfileRemoteDataSourceRef
    = AutoDisposeProviderRef<UserProfileRemoteDataSource>;
String _$userProfileRepositoryHash() =>
    r'5dbefcd8edc02414166589b4b737174f6a8ac243';

/// See also [userProfileRepository].
@ProviderFor(userProfileRepository)
final userProfileRepositoryProvider =
    AutoDisposeProvider<UserProfileRepository>.internal(
  userProfileRepository,
  name: r'userProfileRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserProfileRepositoryRef
    = AutoDisposeProviderRef<UserProfileRepository>;
String _$userProfileHash() => r'db59fa9504d5251b443362086db39891a7d76e3a';

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

/// See also [userProfile].
@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily();

/// See also [userProfile].
class UserProfileFamily extends Family<AsyncValue<UserProfile?>> {
  /// See also [userProfile].
  const UserProfileFamily();

  /// See also [userProfile].
  UserProfileProvider call(
    String userId,
  ) {
    return UserProfileProvider(
      userId,
    );
  }

  @override
  UserProfileProvider getProviderOverride(
    covariant UserProfileProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'userProfileProvider';
}

/// See also [userProfile].
class UserProfileProvider extends AutoDisposeFutureProvider<UserProfile?> {
  /// See also [userProfile].
  UserProfileProvider(
    String userId,
  ) : this._internal(
          (ref) => userProfile(
            ref as UserProfileRef,
            userId,
          ),
          from: userProfileProvider,
          name: r'userProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userProfileHash,
          dependencies: UserProfileFamily._dependencies,
          allTransitiveDependencies:
              UserProfileFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<UserProfile?> Function(UserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserProfileProvider._internal(
        (ref) => create(ref as UserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<UserProfile?> createElement() {
    return _UserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin UserProfileRef on AutoDisposeFutureProviderRef<UserProfile?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserProfileProviderElement
    extends AutoDisposeFutureProviderElement<UserProfile?> with UserProfileRef {
  _UserProfileProviderElement(super.provider);

  @override
  String get userId => (origin as UserProfileProvider).userId;
}

String _$hasUserProfileHash() => r'ae09df46002e6b122d7d00142a0a877dce4d1ffb';

/// See also [hasUserProfile].
@ProviderFor(hasUserProfile)
const hasUserProfileProvider = HasUserProfileFamily();

/// See also [hasUserProfile].
class HasUserProfileFamily extends Family<AsyncValue<bool>> {
  /// See also [hasUserProfile].
  const HasUserProfileFamily();

  /// See also [hasUserProfile].
  HasUserProfileProvider call(
    String userId,
  ) {
    return HasUserProfileProvider(
      userId,
    );
  }

  @override
  HasUserProfileProvider getProviderOverride(
    covariant HasUserProfileProvider provider,
  ) {
    return call(
      provider.userId,
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
  String? get name => r'hasUserProfileProvider';
}

/// See also [hasUserProfile].
class HasUserProfileProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [hasUserProfile].
  HasUserProfileProvider(
    String userId,
  ) : this._internal(
          (ref) => hasUserProfile(
            ref as HasUserProfileRef,
            userId,
          ),
          from: hasUserProfileProvider,
          name: r'hasUserProfileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$hasUserProfileHash,
          dependencies: HasUserProfileFamily._dependencies,
          allTransitiveDependencies:
              HasUserProfileFamily._allTransitiveDependencies,
          userId: userId,
        );

  HasUserProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<bool> Function(HasUserProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HasUserProfileProvider._internal(
        (ref) => create(ref as HasUserProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _HasUserProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasUserProfileProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin HasUserProfileRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _HasUserProfileProviderElement
    extends AutoDisposeFutureProviderElement<bool> with HasUserProfileRef {
  _HasUserProfileProviderElement(super.provider);

  @override
  String get userId => (origin as HasUserProfileProvider).userId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
