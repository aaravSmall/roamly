import 'package:photo_manager/photo_manager.dart';

/// Single request option used for permission checks and prompts.
/// `mediaLocation` is required on many Android builds to read GPS from image files.
const PermissionRequestOption kPhotoPermissionOption = PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.image,
    mediaLocation: true,
  ),
);
