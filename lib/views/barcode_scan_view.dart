import 'dart:io';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:watch_it/watch_it.dart';

import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../widgets/product/barcode_scanner_overlay.dart';

class BarcodeScanView extends WatchingWidget {
  const BarcodeScanView({super.key});

  @override
  Widget build(BuildContext context) {
    final barcodeScannerService = getIt<BarcodeScannerService>();
    final isCameraReady = createOnce(() => ValueNotifier<bool>(false));
    final multipleBarcodesDetected =
        createOnce(() => ValueNotifier<bool>(false));
    final isFlashOn = createOnce(() => ValueNotifier<bool>(false));
    final errorMessage = createOnce(() => ValueNotifier<String?>(null));
    final cameraControllerNotifier =
        createOnce(() => ValueNotifier<CameraController?>(null));

    final cameraController = watch(cameraControllerNotifier).value;
    final ready = watch(isCameraReady).value;
    final multiple = watch(multipleBarcodesDetected).value;
    final flash = watch(isFlashOn).value;
    final error = watch(errorMessage).value;

    bool isProcessingFrame = false;

    Future<void> processCameraImage(CameraImage image) async {
      if (isProcessingFrame || !context.mounted) return;
      final controller = cameraControllerNotifier.value;
      if (controller == null || !controller.value.isInitialized) return;

      final inputImage = _toInputImage(image, controller.description);
      if (inputImage == null) return;

      isProcessingFrame = true;
      try {
        final barcodes = await barcodeScannerService.processImage(inputImage);
        if (barcodes.length > 1) {
          if (!multipleBarcodesDetected.value) {
            multipleBarcodesDetected.value = true;
          }
          return;
        }
        if (multipleBarcodesDetected.value) {
          multipleBarcodesDetected.value = false;
        }
        if (barcodes.isEmpty) {
          return;
        }
        final scannedValue = barcodes.first.rawValue;
        if (scannedValue == null || scannedValue.isEmpty) return;

        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.click);

        await controller.stopImageStream();
        if (context.mounted) {
          context.pop(scannedValue);
        }
      } finally {
        isProcessingFrame = false;
      }
    }

    Future<void> initializeCamera() async {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw StateError('No camera available');
        }
        CameraDescription selectedCamera = cameras.first;
        for (final camera in cameras) {
          if (camera.lensDirection == CameraLensDirection.back) {
            selectedCamera = camera;
            break;
          }
        }

        final imageFormat = Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21;
        final controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: imageFormat,
        );

        await controller.initialize();
        await controller.startImageStream(processCameraImage);
        if (context.mounted) {
          cameraControllerNotifier.value = controller;
          isCameraReady.value = true;
          errorMessage.value = null;
        }
      } catch (e) {
        if (context.mounted) {
          errorMessage.value = 'product.scanUnavailable'.tr(
            namedArgs: {'error': '$e'},
          );
        }
      }
    }

    Future<void> tearDownCamera() async {
      final controller = cameraControllerNotifier.value;
      if (controller != null) {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await controller.dispose();
        cameraControllerNotifier.value = null;
        isCameraReady.value = false;
      }
    }

    // Handle lifecycle
    createOnce(() {
      final observer = _BarcodeLifecycleObserver(
        onResumed: initializeCamera,
        onInactive: tearDownCamera,
      );
      WidgetsBinding.instance.addObserver(observer);
      return observer;
    }, dispose: (obs) => WidgetsBinding.instance.removeObserver(obs));

    callOnce((_) => initializeCamera());

    onDispose(() => tearDownCamera());

    Future<void> toggleFlash() async {
      final controller = cameraControllerNotifier.value;
      if (controller == null || !isCameraReady.value) return;
      try {
        if (isFlashOn.value) {
          await controller.setFlashMode(FlashMode.off);
          isFlashOn.value = false;
        } else {
          await controller.setFlashMode(FlashMode.torch);
          isFlashOn.value = true;
        }
      } catch (e) {
        debugPrint('Error toggling flash: $e');
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    Widget body = const Center(child: CircularProgressIndicator());
    if (error != null) {
      body = Center(child: Text(error));
    } else if (ready && cameraController != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(cameraController),
          const BarcodeScannerOverlay(),
          Positioned(
            bottom: 96,
            left: 24,
            right: 24,
            child: Text(
              multiple
                  ? 'product.scanSingleBarcodeHint'.tr()
                  : 'product.scanBarcodeHint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: () => context.pop('MANUAL_ENTRY'),
              icon: const Icon(Icons.edit),
              label: Text('product.enterBarcodeManually'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('product.scanBarcode'.tr()),
        backgroundColor: colorScheme.surface,
        actions: [
          if (ready)
            IconButton(
              icon: Icon(flash ? Icons.flash_on : Icons.flash_off),
              onPressed: toggleFlash,
            ),
        ],
      ),
      body: body,
    );
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}

class _BarcodeLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResumed;
  final VoidCallback onInactive;

  _BarcodeLifecycleObserver({required this.onResumed, required this.onInactive});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      onInactive();
    } else if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
