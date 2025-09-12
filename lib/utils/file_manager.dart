import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件管理工具类
/// 提供文件选择、权限管理等功能
class FileManager {
  /// 选择 PDF 文件
  static Future<String?> pickPdfFile() async {
    try {
      // 检查权限
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return null;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
      
      return null;
    } catch (e) {
      debugPrint('文件选择失败: $e');
      return null;
    }
  }

  /// 选择多个 PDF 文件
  static Future<List<String>?> pickMultiplePdfFiles() async {
    try {
      // 检查权限
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return null;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('文件选择失败: $e');
      return null;
    }
  }

  /// 获取文件信息
  static Future<FileInfo?> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final fileName = file.path.split('/').last;
      final fileSize = stat.size;
      final lastModified = stat.modified;

      return FileInfo(
        name: fileName,
        path: filePath,
        size: fileSize,
        lastModified: lastModified,
      );
    } catch (e) {
      debugPrint('获取文件信息失败: $e');
      return null;
    }
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 获取常用目录中的 PDF 文件
  static Future<List<String>> findPdfFiles() async {
    final List<String> pdfFiles = [];
    
    try {
      // 检查权限
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        return pdfFiles;
      }

      // 获取常用目录
      final directories = await _getCommonDirectories();
      
      for (final directory in directories) {
        if (await directory.exists()) {
          await _searchPdfInDirectory(directory, pdfFiles);
        }
      }
    } catch (e) {
      debugPrint('搜索 PDF 文件失败: $e');
    }
    
    return pdfFiles;
  }

  /// 检查存储权限
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS 不需要额外权限
  }

  /// 获取常用目录
  static Future<List<Directory>> _getCommonDirectories() async {
    final List<Directory> directories = [];
    
    try {
      // 下载目录
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir != null) {
        directories.add(downloadDir);
      }
      
      // 文档目录
      final documentsDir = await getApplicationDocumentsDirectory();
      directories.add(documentsDir);
      
      // 外部存储目录（Android）
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          directories.add(externalDir);
        }
      }
    } catch (e) {
      debugPrint('获取目录失败: $e');
    }
    
    return directories;
  }

  /// 在目录中搜索 PDF 文件
  static Future<void> _searchPdfInDirectory(
    Directory directory, 
    List<String> pdfFiles,
  ) async {
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          pdfFiles.add(entity.path);
        }
      }
    } catch (e) {
      debugPrint('搜索目录失败: $e');
    }
  }

  /// 显示文件选择对话框
  static Future<String?> showFilePickerDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择 PDF 文件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从文件管理器选择'),
              onTap: () async {
                Navigator.pop(context);
                final filePath = await pickPdfFile();
                Navigator.pop(context, filePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索设备中的 PDF'),
              onTap: () async {
                Navigator.pop(context);
                final files = await findPdfFiles();
                if (files.isNotEmpty) {
                  final selectedFile = await _showFileListDialog(context, files);
                  Navigator.pop(context, selectedFile);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('未找到 PDF 文件')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示文件列表对话框
  static Future<String?> _showFileListDialog(
    BuildContext context, 
    List<String> files,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择 PDF 文件'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final filePath = files[index];
              final fileName = filePath.split('/').last;
              
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(fileName),
                subtitle: Text(filePath),
                onTap: () => Navigator.pop(context, filePath),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

/// 文件信息类
class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
  });

  String get formattedSize => FileManager.formatFileSize(size);
  
  String get formattedDate {
    return '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')}';
  }
}