import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'lifecycle_event_handler.dart';
import 'types/barcode.dart';
import 'types/barcode_format.dart';
import 'types/camera.dart';
import 'types/camera_exception.dart';
import 'types/features.dart';
import 'web/flutter_qr_stub.dart'
if (dart.library.html) 'web/flutter_qr_web.dart';

typedef QRViewCreatedCallback = void Function(QRViewController);
typedef PermissionSetCallback = void Function(QRViewController, bool);

class QRView extends StatefulWidget {
  const QRView({
    required Key key,
    required this.onQRViewCreated,
    this.overlayConfig,
    this.overlayMargin = EdgeInsets.zero,
    this.cameraFacing = CameraFacing.back,
    this.onPermissionSet,
    this.formatsAllowed = const <BarcodeFormat>[],
  }) : super(key: key);

  final QRViewCreatedCallback onQRViewCreated;
  final QrScannerOverlayConfig? overlayConfig;
  final EdgeInsetsGeometry overlayMargin;
  final CameraFacing cameraFacing;
  final PermissionSetCallback? onPermissionSet;
  final List<BarcodeFormat> formatsAllowed;

  @override
  State<StatefulWidget> createState() => _QRViewState();
}

class _QRViewState extends State<QRView> {
  late MethodChannel _channel;
  late LifecycleEventHandler _observer;

  @override
  void initState() {
    super.initState();
    _observer = LifecycleEventHandler(resumeCallBack: updateDimensions);
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: onNotification,
      child: SizeChangedLayoutNotifier(
        child: widget.overlayConfig != null
            ? _getPlatformQrViewWithOverlay()
            : _getPlatformQrView(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(_observer);
  }

  Future<void> updateDimensions() async {
    await QRViewController.updateDimensions(
      widget.key as GlobalKey<State<StatefulWidget>>,
      _channel,
      overlayConfig: widget.overlayConfig,
    );
  }

  bool onNotification(notification) {
    updateDimensions();
    return false;
  }

  Widget _getPlatformQrViewWithOverlay() {
    return Stack(
      children: [
        _getPlatformQrView(),
        if (widget.overlayConfig != null)
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: QrScannerOverlayPainter(widget.overlayConfig!),
          )
      ],
    );
  }

  Widget _getPlatformQrView() {
    Widget _platformQrView;
    if (kIsWeb) {
      _platformQrView = createWebQrView(
        onPlatformViewCreated: widget.onQRViewCreated,
        onPermissionSet: widget.onPermissionSet,
        cameraFacing: widget.cameraFacing,
      );
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          _platformQrView = AndroidView(
            viewType: 'net.touchcapture.qr.flutterqr/qrview',
            onPlatformViewCreated: _onPlatformViewCreated,
            creationParams: _QrCameraSettings(cameraFacing: widget.cameraFacing).toMap(),
            creationParamsCodec: const StandardMessageCodec(),
          );
          break;
        case TargetPlatform.iOS:
          _platformQrView = UiKitView(
            viewType: 'net.touchcapture.qr.flutterqr/qrview',
            onPlatformViewCreated: _onPlatformViewCreated,
            creationParams: _QrCameraSettings(cameraFacing: widget.cameraFacing).toMap(),
            creationParamsCodec: const StandardMessageCodec(),
          );
          break;
        default:
          throw UnsupportedError("Trying to use the default qrview implementation for $defaultTargetPlatform but there isn't a default one");
      }
    }
    return _platformQrView;
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('net.touchcapture.qr.flutterqr/qrview_$id');

    final controller = QRViewController._(
      _channel,
      widget.key as GlobalKey<State<StatefulWidget>>?,
      widget.onPermissionSet,
      widget.cameraFacing,
    ).._startScan(
      widget.key as GlobalKey<State<StatefulWidget>>,
      widget.overlayConfig,
      widget.formatsAllowed,
    );

    widget.onQRViewCreated(controller);
  }
}

class _QrCameraSettings {
  _QrCameraSettings({this.cameraFacing = CameraFacing.unknown});

  final CameraFacing cameraFacing;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cameraFacing': cameraFacing.index,
    };
  }
}

class QRViewController {
  QRViewController._(
      MethodChannel channel,
      GlobalKey? qrKey,
      PermissionSetCallback? onPermissionSet,
      CameraFacing cameraFacing,
      )   : _channel = channel,
        _cameraFacing = cameraFacing {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onRecognizeQR':
          if (call.arguments != null) {
            final args = call.arguments as Map;
            final code = args['code'] as String?;
            final rawType = args['type'] as String;
            final rawBytes = args['rawBytes'] as List<int>?;
            final format = BarcodeTypesExtension.fromString(rawType);
            if (format != BarcodeFormat.unknown) {
              final barcode = Barcode(code, format, rawBytes);
              _scanUpdateController.sink.add(barcode);
            } else {
              throw Exception('Unexpected barcode type $rawType');
            }
          }
          break;
        case 'onPermissionSet':
          if (call.arguments != null && call.arguments is bool) {
            _hasPermissions = call.arguments;
            if (onPermissionSet != null) {
              onPermissionSet(this, _hasPermissions);
            }
          }
          break;
      }
    });
  }

  final MethodChannel _channel;
  final CameraFacing _cameraFacing;
  final StreamController<Barcode> _scanUpdateController = StreamController<Barcode>();

  Stream<Barcode> get scannedDataStream => _scanUpdateController.stream;
  bool _hasPermissions = false;
  bool get hasPermissions => _hasPermissions;

  Future<void> _startScan(GlobalKey key, QrScannerOverlayConfig? overlayConfig, List<BarcodeFormat>? barcodeFormats) async {
    try {
      await QRViewController.updateDimensions(key, _channel, overlayConfig: overlayConfig);
      return await _channel.invokeMethod('startScan', barcodeFormats?.map((e) => e.asInt()).toList() ?? []);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<CameraFacing> getCameraInfo() async {
    try {
      var cameraFacing = await _channel.invokeMethod('getCameraInfo') as int;
      if (cameraFacing == -1) return _cameraFacing;
      return CameraFacing.values[cameraFacing];
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<CameraFacing> flipCamera() async {
    try {
      return CameraFacing.values[await _channel.invokeMethod('flipCamera') as int];
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<bool?> getFlashStatus() async {
    try {
      return await _channel.invokeMethod('getFlashInfo');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<void> toggleFlash() async {
    try {
      await _channel.invokeMethod('toggleFlash') as bool?;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<void> pauseCamera() async {
    try {
      await _channel.invokeMethod('pauseCamera');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<void> resumeCamera() async {
    try {
      await _channel.invokeMethod('resumeCamera');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  Future<SystemFeatures> getSystemFeatures() async {
    try {
      var features = await _channel.invokeMapMethod<String, dynamic>('getSystemFeatures');
      if (features != null) {
        return SystemFeatures.fromJson(features);
      }
      throw CameraException('Error', 'Could not get system features');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.iOS) stopCamera();
    _scanUpdateController.close();
  }

  static Future<bool> updateDimensions(GlobalKey key, MethodChannel channel, {QrScannerOverlayConfig? overlayConfig}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (key.currentContext == null) return false;
      final renderBox = key.currentContext!.findRenderObject() as RenderBox;
      try {
        await channel.invokeMethod('setDimensions', {
          'width': renderBox.size.width,
          'height': renderBox.size.height,
          'scanAreaWidth': overlayConfig?.cutOutWidth ?? 0,
          'scanAreaHeight': overlayConfig?.cutOutHeight ?? 0,
          'scanAreaOffset': overlayConfig?.cutOutBottomOffset ?? 0,
        });
        return true;
      } on PlatformException catch (e) {
        throw CameraException(e.code, e.message);
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      if (overlayConfig == null) return false;
      await channel.invokeMethod('changeScanArea', {
        'scanAreaWidth': overlayConfig.cutOutWidth,
        'scanAreaHeight': overlayConfig.cutOutHeight,
        'cutOutBottomOffset': overlayConfig.cutOutBottomOffset,
      });
      return true;
    }
    return false;
  }

  Future<void> scanInvert(bool isScanInvert) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('invertScan', {"isInvertScan": isScanInvert});
      } on PlatformException catch (e) {
        throw CameraException(e.code, e.message);
      }
    }
  }
}
