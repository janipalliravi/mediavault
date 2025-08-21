import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageCropScreen({super.key, required this.imageBytes});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final CropController _controller = CropController();
  bool _isCropping = false;
  double? _aspectRatio; // null = freeform

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Image'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Crop(
                controller: _controller,
                image: widget.imageBytes,
                aspectRatio: _aspectRatio,
                withCircleUi: false,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.5),
                interactive: true,
                onCropped: (bytes) async {
                  if (!mounted) return;
                  setState(() => _isCropping = false);
                  Navigator.of(context).pop<Uint8List>(bytes);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Wrap(
              spacing: 8,
              children: [
                _ratioChip(label: 'Free', ratio: null),
                _ratioChip(label: '1:1', ratio: 1 / 1),
                _ratioChip(label: '3:4', ratio: 3 / 4),
                _ratioChip(label: '4:5', ratio: 4 / 5),
                _ratioChip(label: '2:3', ratio: 2 / 3),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCropping
                      ? null
                      : () {
                          setState(() => _isCropping = true);
                          _controller.crop();
                        },
                  icon: const Icon(Icons.check),
                  label: Text(_isCropping ? 'Processing...' : 'Use Image'),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _ratioChip({required String label, required double? ratio}) {
    final bool selected = _aspectRatio == ratio || (_aspectRatio == null && ratio == null);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _aspectRatio = ratio),
    );
  }
}


