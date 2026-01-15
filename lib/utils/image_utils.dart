import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageUtils {
  static final ImageUtils _instance = ImageUtils._internal();
  factory ImageUtils() => _instance;
  ImageUtils._internal();

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

 /// Request camera and storage permissions
 Future<bool> requestPermissions(BuildContext context) async {
   // Check and request camera permission
   var cameraStatus = await Permission.camera.status;
   if (!cameraStatus.isGranted) {
     cameraStatus = await Permission.camera.request();
     if (!cameraStatus.isGranted) {
       _showPermissionDeniedDialog(context, 'Camera');
       return false;
     }
   }

   // Check and request storage/gallery permission
   if (Platform.isAndroid) {
     var photosStatus = await Permission.photos.status;
     if (!photosStatus.isGranted) {
       photosStatus = await Permission.photos.request();
       if (!photosStatus.isGranted) {
         _showPermissionDeniedDialog(context, 'Photos');
         return false;
       }
     }
   }

   return true;
 }

  /// Show permission denied dialog
  void _showPermissionDeniedDialog(BuildContext context, String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text('The $permissionType permission is required to use this feature. Please grant it in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  /// Pick image from gallery
  Future<File?> pickImageFromGallery(BuildContext context) async {
    if (!await requestPermissions(context)) {
      return null;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }

    return null;
  }

  /// Take photo using camera
  Future<File?> takePhoto(BuildContext context) async {
    if (!await requestPermissions(context)) {
      return null;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }

    return null;
  }

  /// Save image to local storage
  Future<String?> saveImageToStorage(Uint8List imageBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/images/$fileName';
      
      // Create images directory if it doesn't exist
      final imageDir = Directory('${directory.path}/images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);
      
      return imagePath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  /// Load image from local storage
  Future<Uint8List?> loadImageFromStorage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
    return null;
  }

  /// Delete image from local storage
  Future<bool> deleteImageFromStorage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
    return false;
  }

  /// Generate unique filename for image
  String generateImageFileName(String productName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanName = productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    
    return 'product_${cleanName}_$timestamp.jpg';
  }

  /// Get image widget from local path
  Widget buildImageWidget(String imagePath, {double? width, double? height}) {
    return FutureBuilder<Uint8List?>(
      future: loadImageFromStorage(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage(width, height);
              },
            );
          } else {
            return _buildPlaceholderImage(width, height);
          }
        }
        return _buildPlaceholderImage(width, height);
      },
    );
  }

  /// Build placeholder image widget
  Widget _buildPlaceholderImage(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: width != null ? width * 0.5 : 40,
      ),
    );
  }

  /// Compress image to reduce file size
  Future<Uint8List?> compressImage(Uint8List imageBytes, {int quality = 80}) async {
    try {
      // For now, we'll just return the original bytes
      // In a real implementation, you might want to use image compression libraries
      return imageBytes;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  /// Get file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}