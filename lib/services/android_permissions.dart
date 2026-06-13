import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Runtime permission helpers for Android 13–16 (API 33–36).
class AndroidPermissions {
  AndroidPermissions._();

  static Future<bool> ensureGalleryAccess() async {
    if (!Platform.isAndroid) return true;

    for (final permission in [Permission.photos, Permission.storage]) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
    }

    for (final permission in [Permission.photos, Permission.storage]) {
      final status = await permission.request();
      if (status.isGranted || status.isLimited) return true;
    }
    return false;
  }

  static Future<bool> ensureCameraAccess() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Call before [ImagePicker] camera or gallery use on Android.
  static Future<bool> ensureForImagePicker({required bool fromCamera}) async {
    if (!Platform.isAndroid) return true;
    if (fromCamera) {
      final cameraOk = await ensureCameraAccess();
      if (!cameraOk) return false;
    }
    return ensureGalleryAccess();
  }
}
