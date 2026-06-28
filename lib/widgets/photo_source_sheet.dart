import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

/// Shows a small action sheet asking Camera or Gallery, returning the
/// chosen [ImageSource] or null if dismissed.
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
