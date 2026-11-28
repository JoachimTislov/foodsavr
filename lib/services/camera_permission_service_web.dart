import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'camera_permission_service.dart';

/// Camera access through the browser's media and permission APIs.
CameraAccessPlatform createCameraAccessPlatform() => _BrowserCameraAccess();

class _BrowserCameraAccess implements CameraAccessPlatform {
  /// Why the browser cannot offer a camera at all, or null when it can.
  CameraAccessStatus? get _blocker {
    if (!web.window.isSecureContext) return CameraAccessStatus.insecureContext;
    final navigator = web.window.navigator as JSObject;
    return navigator.getProperty('mediaDevices'.toJS) == null
        ? CameraAccessStatus.unsupported
        : null;
  }

  @override
  Future<CameraAccessStatus?> query() async {
    final blocker = _blocker;
    if (blocker != null) return blocker;
    final permission = await _permissionState();
    if (permission == CameraAccessStatus.denied) return permission;
    if (await _hasNoVideoInput()) return CameraAccessStatus.noCamera;
    return permission;
  }

  /// Null where the browser has no Permissions API or does not know the
  /// `camera` permission (for example Firefox).
  Future<CameraAccessStatus?> _permissionState() async {
    try {
      final descriptor = JSObject()..setProperty('name'.toJS, 'camera'.toJS);
      final result = await web.window.navigator.permissions
          .query(descriptor)
          .toDart;
      return switch (result.state) {
        'granted' => CameraAccessStatus.granted,
        'denied' => CameraAccessStatus.denied,
        'prompt' => CameraAccessStatus.prompt,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// Browsers list video inputs, without labels, before any grant.
  Future<bool> _hasNoVideoInput() async {
    try {
      final devices = await web.window.navigator.mediaDevices
          .enumerateDevices()
          .toDart;
      return !devices.toDart.any((device) => device.kind == 'videoinput');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CameraAccessStatus> request() async {
    final blocker = _blocker;
    if (blocker != null) return blocker;
    try {
      final stream = await _openVideoStream();
      // Only the permission matters; release the camera at once.
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      return CameraAccessStatus.granted;
    } catch (error) {
      return statusForCameraErrorCode(_errorName(error));
    }
  }

  /// Prefers the rear camera without requiring it, falling back to any camera
  /// when the browser still rejects the constraint (for example on laptops).
  Future<web.MediaStream> _openVideoStream() async {
    try {
      return await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'facingMode': {'ideal': 'environment'},
              }.jsify()!,
            ),
          )
          .toDart;
    } catch (error) {
      final name = _errorName(error);
      if (name != 'OverconstrainedError' &&
          name != 'ConstraintNotSatisfiedError') {
        rethrow;
      }
      return web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
          .toDart;
    }
  }

  String _errorName(Object error) {
    try {
      return (error as web.DOMException).name;
    } catch (_) {
      return '';
    }
  }
}
