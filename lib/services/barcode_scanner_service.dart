import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeScannerService {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<List<Barcode>> processImage(InputImage inputImage) =>
      _barcodeScanner.processImage(inputImage);

  Future<void> close() => _barcodeScanner.close();
}
