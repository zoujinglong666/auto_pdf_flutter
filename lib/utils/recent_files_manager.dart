import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// 最近文件管理器
/// 负责管理用户最近打开的PDF文件历史记录
class RecentFilesManager {
  static const String _recentFilesKey = 'recent_pdf_files';
  static const int _maxRecentFiles = 10;
  
  // 内存缓存作为备用方案
  static List<RecentFileItem> _memoryCache = [];
  static bool _useMemoryCache = false;

  /// 添加最近文件
  static Future<void> addRecentFile(RecentFileItem item) async {
    try {
      if (_useMemoryCache) {
        _addToMemoryCache(item);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final recentFiles = await getRecentFiles();
      
      // 移除已存在的相同文件
      recentFiles.removeWhere((file) => 
        file.path == item.path || file.url == item.url);
      
      // 添加到列表开头
      recentFiles.insert(0, item);
      
      // 限制最大数量
      if (recentFiles.length > _maxRecentFiles) {
        recentFiles.removeRange(_maxRecentFiles, recentFiles.length);
      }
      
      // 保存到本地存储
      final jsonList = recentFiles.map((file) => file.toJson()).toList();
      await prefs.setString(_recentFilesKey, jsonEncode(jsonList));
    } catch (e) {
      print('添加最近文件失败: $e，切换到内存模式');
      _useMemoryCache = true;
      _addToMemoryCache(item);
    }
  }

  /// 获取最近文件列表
  static Future<List<RecentFileItem>> getRecentFiles() async {
    try {
      if (_useMemoryCache) {
        return List.from(_memoryCache);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentFilesKey);
      
      if (jsonString == null) return [];
      
      final jsonList = jsonDecode(jsonString) as List;
      final recentFiles = jsonList
          .map((json) => RecentFileItem.fromJson(json))
          .toList();
      
      // 过滤掉不存在的本地文件
      final validFiles = <RecentFileItem>[];
      for (final file in recentFiles) {
        if (file.isNetworkFile || await _fileExists(file.path)) {
          validFiles.add(file);
        }
      }
      
      // 如果有文件被过滤掉，更新存储
      if (validFiles.length != recentFiles.length) {
        final jsonList = validFiles.map((file) => file.toJson()).toList();
        await prefs.setString(_recentFilesKey, jsonEncode(jsonList));
      }
      
      return validFiles;
    } catch (e) {
      print('获取最近文件失败: $e，切换到内存模式');
      _useMemoryCache = true;
      return List.from(_memoryCache);
    }
  }

  /// 移除最近文件
  static Future<void> removeRecentFile(String identifier) async {
    try {
      if (_useMemoryCache) {
        _memoryCache.removeWhere((file) => 
          file.path == identifier || file.url == identifier);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final recentFiles = await getRecentFiles();
      
      recentFiles.removeWhere((file) => 
        file.path == identifier || file.url == identifier);
      
      final jsonList = recentFiles.map((file) => file.toJson()).toList();
      await prefs.setString(_recentFilesKey, jsonEncode(jsonList));
    } catch (e) {
      print('移除最近文件失败: $e');
      _useMemoryCache = true;
      _memoryCache.removeWhere((file) => 
        file.path == identifier || file.url == identifier);
    }
  }

  /// 清空最近文件
  static Future<void> clearRecentFiles() async {
    try {
      if (_useMemoryCache) {
        _memoryCache.clear();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentFilesKey);
    } catch (e) {
      print('清空最近文件失败: $e');
      _useMemoryCache = true;
      _memoryCache.clear();
    }
  }

  /// 添加到内存缓存
  static void _addToMemoryCache(RecentFileItem item) {
    // 移除已存在的相同文件
    _memoryCache.removeWhere((file) => 
      file.path == item.path || file.url == item.url);
    
    // 添加到列表开头
    _memoryCache.insert(0, item);
    
    // 限制最大数量
    if (_memoryCache.length > _maxRecentFiles) {
      _memoryCache.removeRange(_maxRecentFiles, _memoryCache.length);
    }
  }

  /// 检查文件是否存在
  static Future<bool> _fileExists(String? path) async {
    if (path == null) return false;
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }
}

/// 最近文件项
class RecentFileItem {
  final String title;
  final String? path;      // 本地文件路径
  final String? url;       // 网络文件URL
  final DateTime openTime;
  final int? fileSize;     // 文件大小（字节）
  final String? thumbnail; // 缩略图路径（预留）

  RecentFileItem({
    required this.title,
    this.path,
    this.url,
    required this.openTime,
    this.fileSize,
    this.thumbnail,
  }) : assert(path != null || url != null, '路径和URL不能同时为空');

  /// 是否为网络文件
  bool get isNetworkFile => url != null;

  /// 获取显示用的副标题
  String get subtitle {
    if (isNetworkFile) {
      return '网络文件 • ${_formatTime(openTime)}';
    } else {
      final sizeText = fileSize != null ? _formatFileSize(fileSize!) : '';
      return '本地文件${sizeText.isNotEmpty ? ' • $sizeText' : ''} • ${_formatTime(openTime)}';
    }
  }

  /// 获取文件标识符
  String get identifier => path ?? url!;

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'path': path,
      'url': url,
      'openTime': openTime.millisecondsSinceEpoch,
      'fileSize': fileSize,
      'thumbnail': thumbnail,
    };
  }

  /// 从JSON创建
  factory RecentFileItem.fromJson(Map<String, dynamic> json) {
    return RecentFileItem(
      title: json['title'] ?? '',
      path: json['path'],
      url: json['url'],
      openTime: DateTime.fromMillisecondsSinceEpoch(json['openTime'] ?? 0),
      fileSize: json['fileSize'],
      thumbnail: json['thumbnail'],
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
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

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}