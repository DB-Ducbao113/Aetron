import 'dart:async';
import 'dart:io';

import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/core/providers/app_providers.dart';
import 'package:fitness_exercise_application/features/profile/domain/entities/user_profile.dart';
import 'package:fitness_exercise_application/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Object _avatarOverrideUnset = Object();
const Object _localAvatarOverrideUnset = Object();
const Object _localAvatarBytesOverrideUnset = Object();

class AvatarState {
  final bool isUploading;
  final String? errorMessage;
  final String? avatarUrlOverride;
  final bool hasAvatarUrlOverride;
  final String? localAvatarPathOverride;
  final Uint8List? localAvatarBytesOverride;

  const AvatarState({
    this.isUploading = false,
    this.errorMessage,
    this.avatarUrlOverride,
    this.hasAvatarUrlOverride = false,
    this.localAvatarPathOverride,
    this.localAvatarBytesOverride,
  });

  AvatarState copyWith({
    bool? isUploading,
    String? errorMessage,
    Object? avatarUrlOverride = _avatarOverrideUnset,
    bool? hasAvatarUrlOverride,
    Object? localAvatarPathOverride = _localAvatarOverrideUnset,
    Object? localAvatarBytesOverride = _localAvatarBytesOverrideUnset,
  }) => AvatarState(
    isUploading: isUploading ?? this.isUploading,
    errorMessage: errorMessage,
    avatarUrlOverride: identical(avatarUrlOverride, _avatarOverrideUnset)
        ? this.avatarUrlOverride
        : avatarUrlOverride as String?,
    hasAvatarUrlOverride: hasAvatarUrlOverride ?? this.hasAvatarUrlOverride,
    localAvatarPathOverride:
        identical(localAvatarPathOverride, _localAvatarOverrideUnset)
        ? this.localAvatarPathOverride
        : localAvatarPathOverride as String?,
    localAvatarBytesOverride:
        identical(localAvatarBytesOverride, _localAvatarBytesOverrideUnset)
        ? this.localAvatarBytesOverride
        : localAvatarBytesOverride as Uint8List?,
  );

  String? resolveAvatarUrl(String? profileAvatarUrl) {
    return hasAvatarUrlOverride ? avatarUrlOverride : profileAvatarUrl;
  }
}

class AvatarDisplayState {
  final String? remoteUrl;
  final String? localPath;
  final Uint8List? localBytes;

  const AvatarDisplayState({this.remoteUrl, this.localPath, this.localBytes});

  bool get hasAvatar =>
      localBytes != null ||
      (localPath != null && localPath!.isNotEmpty) ||
      (remoteUrl != null && remoteUrl!.isNotEmpty);

  ImageProvider? get imageProvider {
    if (localBytes != null) {
      return MemoryImage(localBytes!);
    }
    if (localPath != null && localPath!.isNotEmpty) {
      if (kIsWeb) {
        return NetworkImage(localPath!);
      }
      return FileImage(File(localPath!));
    }
    if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      return NetworkImage(remoteUrl!);
    }
    return null;
  }
}

final currentAvatarDisplayProvider = Provider<AvatarDisplayState>((ref) {
  final profileAvatarUrl = ref
      .watch(currentUserProfileProvider)
      .valueOrNull
      ?.avatarUrl;
  final avatarState = ref.watch(avatarUploadProvider);

  return AvatarDisplayState(
    remoteUrl: avatarState.resolveAvatarUrl(profileAvatarUrl),
    localPath: avatarState.localAvatarPathOverride,
    localBytes: avatarState.localAvatarBytesOverride,
  );
});

final currentUserProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  if (kDebugBypassAuth) {
    final now = DateTime.now();
    return AsyncValue.data(
      UserProfile(
        id: 'debug-profile-1',
        userId: 'debug-user',
        weightKg: 68.0,
        heightCm: 175.0,
        legacyAge: 25,
        gender: 'male',
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now,
      ),
    );
  }
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const AsyncValue.data(null);
  }
  return ref.watch(userProfileProvider(userId));
});

final avatarUploadProvider =
    StateNotifierProvider<AvatarUploadNotifier, AvatarState>(
      (ref) => AvatarUploadNotifier(ref),
    );

class AvatarUploadNotifier extends StateNotifier<AvatarState> {
  final Ref _ref;
  final _picker = ImagePicker();

  AvatarUploadNotifier(this._ref) : super(const AvatarState());

  Future<void> pickAndUpload(ImageSource source) async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(errorMessage: null);

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
      state = state.copyWith(
        errorMessage: isVi
            ? 'Vui lòng hoàn tất hồ sơ của bạn trước khi thêm ảnh đại diện.'
            : 'Complete your profile before adding a photo.',
      );
      return;
    }

    final permissionError = await _requestImagePermission(source);
    if (permissionError != null) {
      state = state.copyWith(errorMessage: permissionError);
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      state = state.copyWith(
        isUploading: true,
        errorMessage: null,
        localAvatarPathOverride: picked.path,
        localAvatarBytesOverride: bytes,
        avatarUrlOverride: null,
        hasAvatarUrlOverride: false,
      );

      final remoteDatasource = _ref.read(userProfileRemoteDataSourceProvider);
      final repository = _ref.read(userProfileRepositoryProvider);
      final publicUrl = await remoteDatasource.uploadAvatarBytes(userId, bytes);
      final previousAvatarUrl = profile.avatarUrl;
      final updatedProfile = profile.copyWith(
        avatarUrl: publicUrl,
        updatedAt: DateTime.now(),
      );

      await repository.cacheLocal(updatedProfile);
      await _syncRemoteAvatarUrl(
        remoteDatasource,
        userId,
        publicUrl,
        previousAvatarUrl: previousAvatarUrl,
      );
      _ref.invalidate(userProfileProvider(userId));

      state = state.copyWith(
        isUploading: false,
        avatarUrlOverride: publicUrl,
        hasAvatarUrlOverride: true,
        localAvatarPathOverride: null,
        localAvatarBytesOverride: null,
      );
    } on StorageException catch (e) {
      debugPrint('Avatar upload storage sync failed: ${e.message}');
      state = state.copyWith(
        isUploading: false,
        errorMessage: state.localAvatarBytesOverride != null
            ? null
            : _storageErrorMessage(e),
      );
    } on PostgrestException catch (e) {
      debugPrint('Avatar upload profile sync failed: ${e.message}');
      state = state.copyWith(
        isUploading: false,
        errorMessage: state.localAvatarBytesOverride != null
            ? null
            : _profileUpdateErrorMessage(e),
      );
    } catch (e, stackTrace) {
      debugPrint('Avatar upload failed: $e\n$stackTrace');
      state = state.copyWith(
        isUploading: false,
        errorMessage: state.localAvatarBytesOverride != null
            ? null
            : _unknownAvatarErrorMessage(
                e,
                fallback: 'Could not upload your photo.',
              ),
      );
    }
  }

  Future<void> removeAvatar() async {
    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(errorMessage: null);

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
      state = state.copyWith(
        errorMessage: isVi
            ? 'Vui lòng hoàn tất hồ sơ trước khi đổi ảnh đại diện.'
            : 'Complete your profile before changing your photo.',
      );
      return;
    }
    final avatarUrl = state.resolveAvatarUrl(profile.avatarUrl);
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return;
    }

    try {
      state = state.copyWith(
        isUploading: true,
        errorMessage: null,
        avatarUrlOverride: null,
        hasAvatarUrlOverride: true,
        localAvatarPathOverride: null,
        localAvatarBytesOverride: null,
      );

      final remoteDatasource = _ref.read(userProfileRemoteDataSourceProvider);
      final repository = _ref.read(userProfileRepositoryProvider);
      final updatedProfile = profile.copyWith(
        avatarUrl: null,
        updatedAt: DateTime.now(),
      );
      await repository.cacheLocal(updatedProfile);
      await _syncRemoteAvatarUrl(
        remoteDatasource,
        userId,
        null,
        previousAvatarUrl: avatarUrl,
      );
      _ref.invalidate(userProfileProvider(userId));

      state = state.copyWith(
        isUploading: false,
        avatarUrlOverride: null,
        hasAvatarUrlOverride: true,
      );
    } on PostgrestException catch (e) {
      debugPrint('Avatar removal profile sync failed: ${e.message}');
      state = state.copyWith(
        isUploading: false,
        errorMessage: _profileUpdateErrorMessage(e),
      );
    } catch (e, stackTrace) {
      final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
      debugPrint('Avatar removal failed: $e\n$stackTrace');
      state = state.copyWith(
        isUploading: false,
        errorMessage: _unknownAvatarErrorMessage(
          e,
          fallback: isVi
              ? 'Không thể gỡ ảnh đại diện. Vui lòng thử lại.'
              : 'Could not remove your photo. Please try again.',
        ),
      );
    }
  }

  Future<String?> _requestImagePermission(ImageSource source) async {
    if (kIsWeb) return null;
    final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) return null;
      if (status.isPermanentlyDenied) {
        return isVi
            ? 'Quyền truy cập Camera bị chặn. Vui lòng bật lại trong Cài đặt.'
            : 'Camera access is blocked. Allow it in Settings.';
      }
      return isVi
          ? 'Cần quyền Camera để chụp ảnh đại diện mới.'
          : 'Camera access is needed to take a photo.';
    }

    if (!kIsWeb && Platform.isIOS) {
      final ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        ),
      );
      if (ps.isAuth) return null;
      if (ps == PermissionState.limited) {
        return isVi
            ? 'Cần toàn quyền truy cập ảnh. Vui lòng chuyển thành Toàn quyền trong Cài đặt.'
            : 'Full photo access is needed. Change Photos to Full Access in Settings.';
      }

      final status = await Permission.photos.status;
      if (status.isPermanentlyDenied) {
        return isVi
            ? 'Quyền truy cập thư viện ảnh bị chặn. Vui lòng cấp quyền trong Cài đặt.'
            : 'Photo access is blocked. Allow Full Access in Settings.';
      }
      return isVi
          ? 'Cần quyền truy cập ảnh để chọn ảnh đại diện.'
          : 'Photo access is needed to choose an image.';
    }

    return null;
  }

  String _storageErrorMessage(StorageException error) {
    final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('not allowed') ||
        message.contains('unauthorized')) {
      return isVi
          ? 'Tải ảnh đại diện bị chặn lúc này. Vui lòng đăng nhập lại.'
          : 'Photo upload is blocked right now. Please sign in again.';
    }
    if (message.contains('bucket')) {
      return isVi
          ? 'Bộ nhớ lưu ảnh chưa sẵn sàng. Vui lòng thử lại sau.'
          : 'Photo storage is not ready yet. Please try again later.';
    }
    return isVi ? 'Không thể tải ảnh đại diện lên.' : 'Could not upload your photo.';
  }

  String _profileUpdateErrorMessage(PostgrestException error) {
    final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('permission')) {
      return isVi
          ? 'Không thể cập nhật hồ sơ của bạn lúc này.'
          : 'Your profile could not be updated right now.';
    }
    return isVi ? 'Không thể cập nhật ảnh đại diện.' : 'Could not update your profile photo.';
  }

  String _unknownAvatarErrorMessage(Object error, {required String fallback}) {
    final isVi = _ref.read(appLanguageProvider) == AppLanguage.vi;
    final message = error.toString();
    if (message.contains('PathAccessException') ||
        message.contains('FileSystemException')) {
      return isVi
          ? 'Không thể đọc tệp ảnh đã chọn. Vui lòng chọn ảnh khác.'
          : 'Could not read the selected photo. Please choose another image.';
    }
    if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('socket')) {
      return isVi
          ? 'Lỗi kết nối mạng khi tải ảnh. Vui lòng thử lại.'
          : 'Network error while updating your photo. Please try again.';
    }
    return fallback;
  }

  Future<void> _syncRemoteAvatarUrl(
    dynamic remoteDatasource,
    String userId,
    String? avatarUrl, {
    String? previousAvatarUrl,
  }) async {
    try {
      await remoteDatasource.updateAvatarUrl(userId, avatarUrl);
      if (previousAvatarUrl != null && previousAvatarUrl.isNotEmpty) {
        await remoteDatasource.deleteAvatarObject(
          userId,
          avatarUrl: previousAvatarUrl,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Avatar remote sync failed: $e\n$stackTrace');
    }
  }
}
