import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum ReviewPhotoSource { camera, gallery }

enum ReviewPhotoPickFailure { permissionDenied, unavailable }

final class ReviewPhotoPickException implements Exception {
  const ReviewPhotoPickException(this.failure);

  final ReviewPhotoPickFailure failure;
}

/// 후기 사진 한 장을 촬영하거나 갤러리에서 고르는 포트.
///
/// 반환값은 픽커가 만든 임시 파일의 절대경로다 — OS가 지울 수 있는 캐시라
/// 호출자는 즉시 [ReviewPhotoFileGateway]로 복사해야 한다. 사용자가
/// 취소하면 null, 실패는 [ReviewPhotoPickException]으로 구분한다.
abstract interface class ReviewPhotoPickerPort {
  Future<String?> pick(ReviewPhotoSource source);
}

/// image_picker 어댑터.
///
/// 촬영·선택 원본을 1600px·품질 80 JPEG로 트랜스코드해 업로드 크기를 줄이고
/// iOS HEIC 원본도 JPEG로 수렴시킨다. Android는 카메라 인텐트/Photo Picker
/// 경로라 런타임 권한이 필요 없고, iOS의 권한 거부는 PlatformException
/// (`*_access_denied`)으로 도착한다.
final class NativeReviewPhotoPicker implements ReviewPhotoPickerPort {
  NativeReviewPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<String?> pick(ReviewPhotoSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source == ReviewPhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      return file?.path;
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      throw ReviewPhotoPickException(
        code.contains('access_denied') || code.contains('permission')
            ? ReviewPhotoPickFailure.permissionDenied
            : ReviewPhotoPickFailure.unavailable,
      );
    }
  }
}
