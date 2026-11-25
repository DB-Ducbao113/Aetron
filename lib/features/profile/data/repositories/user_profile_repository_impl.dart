import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:fitness_exercise_application/features/profile/data/models/user_profile_model.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/local/user_profile_local_datasource.dart';
import 'package:fitness_exercise_application/features/profile/data/datasources/remote/user_profile_remote_datasource.dart';
import 'package:fitness_exercise_application/features/workout/data/local/local_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileLocalDataSource _localDataSource;
  final UserProfileRemoteDataSource _remoteDataSource;

  UserProfileRepositoryImpl(this._localDataSource, this._remoteDataSource);

  static const _remoteProfileTimeout = Duration(seconds: 8);

  @override
  Future<UserProfile?> fetchRemote(String userId) async {
    final remoteProfile = await _remoteDataSource
        .getProfile(userId)
        .timeout(_remoteProfileTimeout);
    return remoteProfile?.toEntity();
  }

  @override
  Future<void> saveRemote(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    await _remoteDataSource.updateProfile(model);
  }

  @override
  Future<void> cacheLocal(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    // Try to update, if missing insert. The local data source handles this via insert/update
    await _localDataSource.insertProfile(model);
  }

  @override
  Future<UserProfile?> getLocal(String userId) async {
    final localProfile = await _localDataSource.getProfile(userId);
    return localProfile?.toEntity();
  }

  @override
  Future<UserProfile?> getProfile(String userId) async {
    // 1. Return fast local cache immediately if present (0ms display)
    final localProfile = await getLocal(userId);
    if (localProfile != null) {
      unawaited(() async {
        try {
          final remote = await fetchRemote(userId);
          if (remote != null) {
            await cacheLocal(remote);
          }
        } catch (_) {}
      }());
      return localProfile;
    }

    // 2. Initial login without local cache: fetch remote
    try {
      final remoteProfile = await fetchRemote(userId);
      if (remoteProfile != null) {
        await cacheLocal(remoteProfile);
        return remoteProfile;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> createProfile(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);

    // 1. Save locally (safe across web and mobile)
    try {
      await _localDataSource.insertProfile(model);
    } catch (e) {
      debugPrint('[UserProfileRepositoryImpl] Local cache warning during creation: $e');
    }

    // 2. Sync to remote Supabase
    await _remoteDataSource.createProfile(model);
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);

    // 1. Update locally
    try {
      await _localDataSource.updateProfile(model);
    } catch (e) {
      debugPrint('[UserProfileRepositoryImpl] Local cache warning during update: $e');
    }

    // 2. Sync to remote Supabase
    await _remoteDataSource.updateProfile(model);
  }

  @override
  Future<bool> hasProfile(String userId) async {
    // 1. Fast path: local SQLite check
    final localResult = await _localDataSource.hasProfile(userId);
    if (localResult) return true;

    // 2. Fallback: check remote (covers fresh-install / cleared-storage case)
    try {
      final remoteProfile = await fetchRemote(userId)
          .timeout(const Duration(seconds: 4));
      if (remoteProfile != null) {
        await cacheLocal(remoteProfile);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[UserProfileRepositoryImpl] hasProfile fallback to false: $e');
      return false;
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    // 1. Wipe all remote data & trigger RPC account removal.
    // MUST NOT swallow remote errors — if remote wipe fails, abort local wipe so
    // user is not mistakenly logged out while data remains on the server.
    await _remoteDataSource.deleteAllUserData(userId);

    // 2. Wipe local SQLite profile data
    try {
      await _localDataSource.deleteProfile(userId);
    } catch (e) {
      debugPrint('[UserProfileRepository] Local profile delete error: $e');
    }

    // 3. Wipe all local Isar workout data
    try {
      await LocalDB.clearAllForUser(userId);
    } catch (e) {
      debugPrint('[UserProfileRepository] LocalDB clear error: $e');
    }

    // 4. Force sign out from Supabase auth
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[UserProfileRepository] SignOut error: $e');
    }
  }
}
