import 'dart:typed_data';

/// Platforms without a browser cannot start a file download; returns false.
Future<bool> downloadExportFile(
  String fileName,
  String mimeType,
  Uint8List bytes,
) async => false;
