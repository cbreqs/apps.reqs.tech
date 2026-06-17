import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen, pinch-to-zoom receipt image viewer.
/// Pass the image file path as a route argument (String).
///   Navigator.pushNamed(context, '/view-image', arguments: imagePath)
class ReceiptImageViewer extends StatelessWidget {
  const ReceiptImageViewer({super.key});

  @override
  Widget build(BuildContext context) {
    final imagePath =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt Image',
            style: TextStyle(color: Colors.white)),
        actions: [
          // Hint label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Center(
              child: Text(
                'Pinch to zoom',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6.0,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white38, size: 64),
                SizedBox(height: 12),
                Text('Image not found',
                    style: TextStyle(color: Colors.white38)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
