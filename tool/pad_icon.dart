import 'dart:io';
import 'package:image/image.dart' as img;

// Pads the input PNG with transparent margins and exports a square PNG sized for adaptive icon foregrounds.
// Usage: dart run tool/pad_icon.dart assets/images/mediavault_logo.png assets/images/mediavault_logo_foreground_padded.png
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/pad_icon.dart <input_png> <output_png>');
    exit(1);
  }
  final inputPath = args[0];
  final outputPath = args[1];
  final inputBytes = File(inputPath).readAsBytesSync();
  final original = img.decodeImage(inputBytes);
  if (original == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exit(2);
  }

  // Create a square canvas based on the larger dimension
  final baseSize = original.width > original.height ? original.width : original.height;
  // Target canvas size; scale a bit larger to improve quality
  final canvasSize = baseSize;
  final canvas = img.Image(width: canvasSize, height: canvasSize);
  // Transparent background (default is zeroed/transparent for RGBA)

  // Place the original scaled to 80% of the canvas, centered
  final targetSize = (canvasSize * 0.8).round();
  final scaled = img.copyResize(original, width: targetSize, interpolation: img.Interpolation.average);
  final dx = ((canvasSize - scaled.width) / 2).round();
  final dy = ((canvasSize - scaled.height) / 2).round();
  img.compositeImage(canvas, scaled, dstX: dx, dstY: dy);

  // Ensure PNG output
  final outBytes = img.encodePng(canvas);
  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(outBytes);

  stdout.writeln('Wrote padded icon to: $outputPath');
}


