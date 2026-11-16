import 'package:flutter/material.dart';

/// A flexible widget that renders either an image (asset/network/custom)
/// or falls back to an [IconData].
///
/// If [imageAsset] (or [imageUrl]/[customWidget]) is provided and valid,
/// it displays the image. Otherwise, it renders the pre-added [icon].
class AppIconOrImage extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final String? imageUrl;
  final Widget? customWidget;
  final double? size;
  final double? width;
  final double? height;
  final double scale;
  final double offsetX;
  final double offsetY;
  final Alignment alignment;
  final Color? iconColor;
  final BoxFit fit;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const AppIconOrImage({
    super.key,
    this.icon,
    this.imageAsset,
    this.imageUrl,
    this.customWidget,
    this.size,
    this.width,
    this.height,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.alignment = Alignment.center,
    this.iconColor,
    this.fit = BoxFit.contain,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final double? effectiveWidth = width ?? size;
    final double? effectiveHeight = height ?? size;

    Widget content;

    if (customWidget != null) {
      content = customWidget!;
    } else if (imageAsset != null && imageAsset!.trim().isNotEmpty) {
      content = Image.asset(
        imageAsset!.trim(),
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          if (icon != null) {
            return Icon(icon, color: iconColor, size: size ?? effectiveWidth);
          }
          return SizedBox(width: effectiveWidth, height: effectiveHeight);
        },
      );
    } else if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      content = Image.network(
        imageUrl!.trim(),
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          if (icon != null) {
            return Icon(icon, color: iconColor, size: size ?? effectiveWidth);
          }
          return SizedBox(width: effectiveWidth, height: effectiveHeight);
        },
      );
    } else if (icon != null) {
      content = Icon(icon, color: iconColor, size: size ?? effectiveWidth);
    } else {
      content = SizedBox(width: effectiveWidth, height: effectiveHeight);
    }

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (scale != 1.0) {
      content = Transform.scale(
        scale: scale,
        alignment: alignment,
        child: content,
      );
    }

    if (offsetX != 0.0 || offsetY != 0.0) {
      content = Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: content,
      );
    }

    return content;
  }
}
