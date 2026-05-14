import 'package:flutter/material.dart';

class ChildMascotAvatar extends StatelessWidget {
  const ChildMascotAvatar({
    super.key,
    required this.poseAssetPath,
    required this.width,
    required this.height,
    this.outfitAssetPath,
    this.accessoryAssetPath,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.scale = 1,
    this.clipBehavior = Clip.none,
  });

  final String poseAssetPath;
  final double width;
  final double height;
  final String? outfitAssetPath;
  final String? accessoryAssetPath;
  final BoxFit fit;
  final Alignment alignment;
  final double scale;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final poseSpec = _poseSpecs[poseAssetPath];
    if (poseSpec == null) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.asset(poseAssetPath, fit: fit, alignment: alignment),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cleanOutfitAssetPath = _cleanPath(outfitAssetPath);
          final cleanAccessoryAssetPath = _cleanPath(accessoryAssetPath);
          final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
          final fittedSizes = applyBoxFit(fit, poseSpec.sourceSize, widgetSize);
          final baseSize = fittedSizes.destination;
          final renderSize = Size(
            baseSize.width * scale,
            baseSize.height * scale,
          );
          final poseRect = Rect.fromLTWH(
            (widgetSize.width - renderSize.width) * (alignment.x + 1) / 2,
            (widgetSize.height - renderSize.height) * (alignment.y + 1) / 2,
            renderSize.width,
            renderSize.height,
          );

          final overlays = <_ResolvedOverlay>[
            if (cleanOutfitAssetPath != null)
              _resolveOverlay(
                assetPath: cleanOutfitAssetPath,
                poseRect: poseRect,
                basePlacement: poseSpec.outfitPlacement,
              ),
            if (cleanAccessoryAssetPath != null)
              _resolveOverlay(
                assetPath: cleanAccessoryAssetPath,
                poseRect: poseRect,
                basePlacement: poseSpec.accessoryPlacement,
              ),
          ]..sort(_compareOverlays);

          return Stack(
            clipBehavior: clipBehavior,
            children: [
              for (final overlay in overlays)
                if (overlay.drawBehindPose) overlay.build(),
              Positioned(
                left: poseRect.left,
                top: poseRect.top,
                width: poseRect.width,
                height: poseRect.height,
                child: Image.asset(poseAssetPath, fit: fit),
              ),
              for (final overlay in overlays)
                if (!overlay.drawBehindPose) overlay.build(),
            ],
          );
        },
      ),
    );
  }

  _ResolvedOverlay _resolveOverlay({
    required String assetPath,
    required Rect poseRect,
    required _OverlayPlacement basePlacement,
  }) {
    final style = _overlayStyleForPose(
      poseAssetPath: poseAssetPath,
      assetPath: assetPath,
    );
    final widthFactor =
        (((style.widthFactor ?? basePlacement.widthFactor) + style.widthDelta)
                .clamp(0.14, 1.2))
            .toDouble();
    final topFactor =
        (style.topFactor ?? basePlacement.topFactor) + style.topDelta;
    final dxFactor = (style.dxFactor ?? basePlacement.dxFactor) + style.dxDelta;
    final overlayWidth = poseRect.width * widthFactor;
    final overlayLeft =
        poseRect.left +
        ((poseRect.width - overlayWidth) / 2) +
        (poseRect.width * dxFactor);
    final overlayTop = poseRect.top + (poseRect.height * topFactor);

    return _ResolvedOverlay(
      assetPath: assetPath,
      left: overlayLeft,
      top: overlayTop,
      width: overlayWidth,
      layerOrder: style.layerOrder ?? basePlacement.layerOrder,
      drawBehindPose: style.drawBehindPose ?? basePlacement.drawBehindPose,
    );
  }

  int _compareOverlays(_ResolvedOverlay a, _ResolvedOverlay b) {
    if (a.drawBehindPose != b.drawBehindPose) {
      return a.drawBehindPose ? -1 : 1;
    }
    return a.layerOrder.compareTo(b.layerOrder);
  }

  String? _cleanPath(String? value) {
    final cleanValue = value?.trim();
    if (cleanValue == null || cleanValue.isEmpty) {
      return null;
    }
    return cleanValue;
  }
}

class _ResolvedOverlay {
  const _ResolvedOverlay({
    required this.assetPath,
    required this.left,
    required this.top,
    required this.width,
    required this.layerOrder,
    required this.drawBehindPose,
  });

  final String assetPath;
  final double left;
  final double top;
  final double width;
  final int layerOrder;
  final bool drawBehindPose;

  Widget build() {
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(child: Image.asset(assetPath, fit: BoxFit.contain)),
    );
  }
}

class _PoseSpec {
  const _PoseSpec({
    required this.sourceSize,
    required this.outfitPlacement,
    required this.accessoryPlacement,
  });

  final Size sourceSize;
  final _OverlayPlacement outfitPlacement;
  final _OverlayPlacement accessoryPlacement;
}

class _OverlayPlacement {
  const _OverlayPlacement({
    required this.topFactor,
    required this.widthFactor,
    required this.layerOrder,
    this.dxFactor = 0,
    this.drawBehindPose = false,
  });

  final double topFactor;
  final double widthFactor;
  final double dxFactor;
  final int layerOrder;
  final bool drawBehindPose;
}

class _OverlayStyle {
  const _OverlayStyle({
    this.topFactor,
    this.widthFactor,
    this.dxFactor,
    // ignore: unused_element_parameter
    this.topDelta = 0,
    // ignore: unused_element_parameter
    this.widthDelta = 0,
    // ignore: unused_element_parameter
    this.dxDelta = 0,
    this.layerOrder,
    this.drawBehindPose,
  });

  final double? topFactor;
  final double? widthFactor;
  final double? dxFactor;
  final double topDelta;
  final double widthDelta;
  final double dxDelta;
  final int? layerOrder;
  final bool? drawBehindPose;
}

const int _outfitLayerOrder = 10;
const int _accessoryLayerOrder = 20;

const Map<String, _PoseSpec> _poseSpecs = <String, _PoseSpec>{
  'assets/risha/risha_normal.png': _PoseSpec(
    sourceSize: Size(386, 432),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.34,
      widthFactor: 0.46,
      layerOrder: _outfitLayerOrder,
      drawBehindPose: false,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.05,
      widthFactor: 0.41,
      layerOrder: _accessoryLayerOrder,
      drawBehindPose: false,
    ),
  ),
  'assets/risha/risha_reading.png': _PoseSpec(
    sourceSize: Size(344, 346),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.42,
      widthFactor: 0.67,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.07,
      widthFactor: 0.33,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_brushing.png': _PoseSpec(
    sourceSize: Size(435, 435),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.42,
      widthFactor: 0.64,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.07,
      widthFactor: 0.33,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_drink.png': _PoseSpec(
    sourceSize: Size(177, 226),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.40,
      widthFactor: 0.63,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.05,
      widthFactor: 0.30,
      dxFactor: -0.01,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_thinking.png': _PoseSpec(
    sourceSize: Size(213, 266),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.41,
      widthFactor: 0.64,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.06,
      widthFactor: 0.31,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_athlete.png': _PoseSpec(
    sourceSize: Size(167, 225),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.39,
      widthFactor: 0.59,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.04,
      widthFactor: 0.27,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_happy.png': _PoseSpec(
    sourceSize: Size(300, 300),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.38,
      widthFactor: 0.63,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.08,
      widthFactor: 0.31,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_sleep.png': _PoseSpec(
    sourceSize: Size(824, 748),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.37,
      widthFactor: 0.35,
      dxFactor: 0.02,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.08,
      widthFactor: 0.18,
      dxFactor: 0.02,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha_read_blue_book.png': _PoseSpec(
    sourceSize: Size(135, 217),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.39,
      widthFactor: 0.55,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.04,
      widthFactor: 0.24,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
  'assets/risha/risha.png': _PoseSpec(
    sourceSize: Size(66, 67),
    outfitPlacement: _OverlayPlacement(
      topFactor: 0.39,
      widthFactor: 0.62,
      layerOrder: _outfitLayerOrder,
    ),
    accessoryPlacement: _OverlayPlacement(
      topFactor: 0.06,
      widthFactor: 0.30,
      layerOrder: _accessoryLayerOrder,
    ),
  ),
};

_OverlayStyle _overlayStyleForPose({
  required String poseAssetPath,
  required String assetPath,
}) {
  switch (poseAssetPath) {
    case 'assets/risha/risha_normal.png':
      return _marketOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_reading.png':
      return _readingPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_brushing.png':
      return _brushingPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_drink.png':
      return _drinkPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_thinking.png':
      return _thinkingPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_athlete.png':
      return _athletePoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_happy.png':
      return _happyPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_sleep.png':
      return _sleepPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha_read_blue_book.png':
      return _blueBookPoseOverlayStyleForAsset(assetPath);
    case 'assets/risha/risha.png':
      return _smallMascotOverlayStyleForAsset(assetPath);
    default:
      return const _OverlayStyle();
  }
}

// اضبط ملابس شخصية المتجر فقط من هنا.
// هذه هي الدالة الوحيدة المفعلة حاليا للضبط الخاص بكل قطعة.
_OverlayStyle _marketOverlayStyleForAsset(String assetPath) {
  switch (assetPath) {
    case 'assets/market_clothes/light_pink_dress.png':
      return const _OverlayStyle(
        topFactor: 0.36,
        widthFactor: 0.68,
        dxFactor: -0.024,
        layerOrder: _outfitLayerOrder,
        drawBehindPose: false,
      );
    case 'assets/market_clothes/pink_dress.png':
      return const _OverlayStyle(
        topFactor: 0.36,
        widthFactor: 0.49,
        dxFactor: 0,
        layerOrder: _outfitLayerOrder,
        drawBehindPose: false,
      );
    case 'assets/market_clothes/black_dress.png':
      return const _OverlayStyle(
        topFactor: 0.36,
        widthFactor: 0.50,
        dxFactor: 0,
        layerOrder: _outfitLayerOrder,
        drawBehindPose: false,
      );
    case 'assets/market_clothes/wight_dress.png':
      return const _OverlayStyle(
        topFactor: 0.34,
        widthFactor: 0.78,
        dxFactor: 0.0,
        layerOrder: _outfitLayerOrder,
        drawBehindPose: false,
      );
    case 'assets/market_clothes/hair_clip.png':
      return const _OverlayStyle(
        topFactor: 0.02,
        widthFactor: 0.30,
        dxFactor: -0.18,
        layerOrder: _accessoryLayerOrder,
        drawBehindPose: false,
      );
    case 'assets/market_clothes/headband.png':
      return const _OverlayStyle(
        topFactor: -0.01,
        widthFactor: 1,
        dxFactor: 0,
        layerOrder: _accessoryLayerOrder,
        drawBehindPose: true,
      );
    default:
      return const _OverlayStyle();
  }
}

// دوال الأوضاع الأخرى جاهزة، لكن اتركها كما هي حاليا حتى نضبطها لاحقا.
_OverlayStyle _readingPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _brushingPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _drinkPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _thinkingPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _athletePoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _happyPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _sleepPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _blueBookPoseOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}

_OverlayStyle _smallMascotOverlayStyleForAsset(String _) {
  return const _OverlayStyle();
}
