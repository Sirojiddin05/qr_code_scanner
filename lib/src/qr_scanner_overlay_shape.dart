import 'dart:math';

import 'package:flutter/material.dart';

class QrScannerOverlayShape extends ShapeBorder {
  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
    double? cutOutWidth,
    double? cutOutHeight,
    this.cutOutBottomOffset = 0,
  })  : cutOutWidth = cutOutWidth ?? cutOutSize ?? 250,
        cutOutHeight = cutOutHeight ?? cutOutSize ?? 250 {
    assert(
      borderLength <= min(this.cutOutWidth, this.cutOutHeight) / 2 + borderWidth * 2,
      "Border can't be larger than ${min(this.cutOutWidth, this.cutOutHeight) / 2 + borderWidth * 2}",
    );
    assert((cutOutWidth == null && cutOutHeight == null) || (cutOutSize == null && cutOutWidth != null && cutOutHeight != null),
        'Use only cutOutWidth and cutOutHeight or only cutOutSize');
  }

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double cutOutHeight;
  final double cutOutBottomOffset;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > min(cutOutHeight, cutOutHeight) / 2 + borderWidth * 2 ? borderWidthSize / 2 : borderLength;
    final _cutOutWidth = cutOutWidth < width ? cutOutWidth : width - borderOffset;
    final _cutOutHeight = cutOutHeight < height ? cutOutHeight : height - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutWidth / 2 + borderOffset,
      -cutOutBottomOffset + rect.top + height / 2 - _cutOutHeight / 2 + borderOffset,
      _cutOutWidth - borderOffset * 2,
      _cutOutHeight - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      // Draw top right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - _borderLength,
          cutOutRect.top,
          cutOutRect.right,
          cutOutRect.top + _borderLength,
          topRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw top left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + _borderLength,
          cutOutRect.top + _borderLength,
          topLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom right corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.right - _borderLength,
          cutOutRect.bottom - _borderLength,
          cutOutRect.right,
          cutOutRect.bottom,
          bottomRight: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      // Draw bottom left corner
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          cutOutRect.left,
          cutOutRect.bottom - _borderLength,
          cutOutRect.left + _borderLength,
          cutOutRect.bottom,
          bottomLeft: Radius.circular(borderRadius),
        ),
        borderPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}

class QrScannerOverlayPainter extends CustomPainter {
  final QrScannerOverlayConfig config;

  QrScannerOverlayPainter(this.config);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = config.overlayColor
      ..style = PaintingStyle.fill;

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - config.cutOutBottomOffset),
      width: config.cutOutWidth,
      height: config.cutOutHeight,
    );

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, Radius.circular(config.borderRadius)),
      clearPaint,
    );

    final paint = Paint()
      ..color = config.borderColor
      ..strokeWidth = config.borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Top-left
    final topLeft = Offset(scanRect.left, scanRect.top);
    path.moveTo(topLeft.dx + config.borderRadius, topLeft.dy);
    path.lineTo(topLeft.dx + config.borderRadius + config.borderLength, topLeft.dy);
    path.moveTo(topLeft.dx, topLeft.dy + config.borderRadius);
    path.lineTo(topLeft.dx, topLeft.dy + config.borderRadius + config.borderLength);
    path.addArc(Rect.fromCircle(center: topLeft.translate(config.borderRadius, config.borderRadius), radius: config.borderRadius), pi, pi / 2);

    // Top-right
    final topRight = Offset(scanRect.right, scanRect.top);
    path.moveTo(topRight.dx - config.borderRadius, topRight.dy);
    path.lineTo(topRight.dx - config.borderRadius - config.borderLength, topRight.dy);
    path.moveTo(topRight.dx, topRight.dy + config.borderRadius);
    path.lineTo(topRight.dx, topRight.dy + config.borderRadius + config.borderLength);
    path.addArc(Rect.fromCircle(center: topRight.translate(-config.borderRadius, config.borderRadius), radius: config.borderRadius), -pi / 2, pi / 2);

    // Bottom-right
    final bottomRight = Offset(scanRect.right, scanRect.bottom);
    path.moveTo(bottomRight.dx - config.borderRadius, bottomRight.dy);
    path.lineTo(bottomRight.dx - config.borderRadius - config.borderLength, bottomRight.dy);
    path.moveTo(bottomRight.dx, bottomRight.dy - config.borderRadius);
    path.lineTo(bottomRight.dx, bottomRight.dy - config.borderRadius - config.borderLength);
    path.addArc(Rect.fromCircle(center: bottomRight.translate(-config.borderRadius, -config.borderRadius), radius: config.borderRadius), 0, pi / 2);

    // Bottom-left
    final bottomLeft = Offset(scanRect.left, scanRect.bottom);
    path.moveTo(bottomLeft.dx + config.borderRadius, bottomLeft.dy);
    path.lineTo(bottomLeft.dx + config.borderRadius + config.borderLength, bottomLeft.dy);
    path.moveTo(bottomLeft.dx, bottomLeft.dy - config.borderRadius);
    path.lineTo(bottomLeft.dx, bottomLeft.dy - config.borderRadius - config.borderLength);
    path.addArc(Rect.fromCircle(center: bottomLeft.translate(config.borderRadius, -config.borderRadius), radius: config.borderRadius), pi / 2, pi / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class QrScannerOverlayConfig {
  final double borderWidth;
  final Color borderColor;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double cutOutHeight;
  final double cutOutBottomOffset;

  QrScannerOverlayConfig({
    this.borderWidth = 6.0,
    this.borderColor = Colors.blueAccent,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.5),
    this.borderRadius = 24,
    this.borderLength = 28,
    double? cutOutSize,
    double? cutOutWidth,
    double? cutOutHeight,
    this.cutOutBottomOffset = 0,
  })  : cutOutWidth = cutOutWidth ?? cutOutSize ?? 250,
        cutOutHeight = cutOutHeight ?? cutOutSize ?? 250 {
    assert((cutOutWidth == null && cutOutHeight == null) ||
        (cutOutSize == null && cutOutWidth != null && cutOutHeight != null),
    'Use only cutOutWidth and cutOutHeight or only cutOutSize');
  }
}


