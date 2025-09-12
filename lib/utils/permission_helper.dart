import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 权限管理工具类
/// 处理文件访问、网络访问等权限请求
class PermissionHelper {
  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isGranted) {
      return true;
    }
    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      return false;
    }
    
    return false;
  }

  /// 请求外部存储权限（Android 11+）
  static Future<bool> requestManageExternalStoragePermission() async {
    final status = await Permission.manageExternalStorage.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.manageExternalStorage.request();
      return result.isGranted;
    }
    
    return false;
  }

  /// 检查并请求必要权限
  static Future<bool> checkAndRequestPermissions() async {
    // 请求存储权限
    final storageGranted = await requestStoragePermission();
    
    if (!storageGranted) {
      // 尝试请求管理外部存储权限（Android 11+）
      final manageStorageGranted = await requestManageExternalStoragePermission();
      return manageStorageGranted;
    }
    
    return true;
  }

  /// 显示权限说明对话框
  static void showPermissionDialog(BuildContext context, {
    required String title,
    required String content,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 打开应用设置页面
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}