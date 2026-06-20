import 'dart:io';

import 'package:image/image.dart' as img;

const _iconScale = 0.82;

final _pngTargets = <String, int>{
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': 16,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': 32,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': 64,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': 128,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': 256,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': 512,
  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': 1024,
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,
  'web/icons/Icon-maskable-192.png': 192,
  'web/icons/Icon-maskable-512.png': 512,
  'web/favicon.png': 32,
};

void main() async {
  final source = File('assets/images/ORBI_ICON_LOGO.png');
  if (!source.existsSync()) {
    stderr.writeln('Missing source icon: ${source.path}');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(await source.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Unable to decode ${source.path}');
    exitCode = 1;
    return;
  }

  for (final entry in _pngTargets.entries) {
    final resized = _renderCenteredIcon(decoded, entry.value);
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(img.encodePng(resized, level: 6));
    stdout.writeln('Wrote ${file.path} (${entry.value}x${entry.value})');
  }

  final windowsIcon = _renderCenteredIcon(decoded, 256);
  final windowsFile = File('windows/runner/resources/app_icon.ico');
  await windowsFile.writeAsBytes(img.encodeIco(windowsIcon));
  stdout.writeln('Wrote ${windowsFile.path} (ico)');
}

img.Image _renderCenteredIcon(img.Image source, int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final targetSize = (size * _iconScale).round().clamp(1, size);
  final srcAspect = source.width / source.height;

  final int width;
  final int height;
  if (srcAspect >= 1) {
    width = targetSize;
    height = (targetSize / srcAspect).round().clamp(1, size);
  } else {
    height = targetSize;
    width = (targetSize * srcAspect).round().clamp(1, size);
  }

  final resized = img.copyResize(
    source,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );

  final dx = ((size - width) / 2).round();
  final dy = ((size - height) / 2).round();
  img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
  return canvas;
}
