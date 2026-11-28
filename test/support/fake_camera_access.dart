import 'package:foodsavr/services/camera_permission_service.dart';

/// A scriptable browser or operating system camera.
class FakeCameraAccess implements CameraAccessPlatform {
  CameraAccessStatus? current;
  CameraAccessStatus answer;
  Object? error;
  int queries = 0;
  int requests = 0;

  FakeCameraAccess({this.current, this.answer = CameraAccessStatus.granted});

  @override
  Future<CameraAccessStatus?> query() async {
    queries++;
    if (error != null) throw error!;
    return current;
  }

  @override
  Future<CameraAccessStatus> request() async {
    requests++;
    if (error != null) throw error!;
    return answer;
  }
}
