import 'package:flutter/material.dart';
import '../components/app_pdf_viewer.dart';

/// PDF 查看器页面
/// 提供完整的 PDF 查看体验，包含标题栏和导航
class PdfViewerPage extends StatefulWidget {
  /// PDF 文件路径（本地）
  final String? filePath;
  
  /// PDF 文件 URL（网络）
  final String? url;
  
  /// 页面标题
  final String title;
  
  /// 是否显示页码信息
  final bool showPageInfo;

  const PdfViewerPage({
    super.key,
    this.filePath,
    this.url,
    this.title = 'PDF 查看器',
    this.showPageInfo = true,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int _currentPageNumber = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: AppPdfViewer(
        filePath: widget.filePath,
        url: widget.url,
        showToolbar: true,
        onPageChanged: (pageNumber, totalPages) {
          setState(() {
            _currentPageNumber = pageNumber;
            _totalPages = totalPages;
          });
        },
        onDocumentLoaded: (totalPages) {
          setState(() {
            _totalPages = totalPages;
            _isDocumentLoaded = true;
          });
        },
        onDocumentLoadFailed: (error) {
          _showErrorDialog(error);
        },
      ),
    );
  }

  /// 构建应用栏
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.showPageInfo && _isDocumentLoaded)
            Text(
              '第 $_currentPageNumber 页，共 $_totalPages 页',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('文档信息'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('分享'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 处理菜单操作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showDocumentInfo();
        break;
      case 'share':
        _shareDocument();
        break;
    }
  }

  /// 显示文档信息
  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文档信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('标题', widget.title),
            _buildInfoRow('总页数', '$_totalPages'),
            _buildInfoRow('当前页', '$_currentPageNumber'),
            if (widget.filePath != null)
              _buildInfoRow('文件路径', widget.filePath!),
            if (widget.url != null)
              _buildInfoRow('网络地址', widget.url!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// 分享文档
  void _shareDocument() {
    // 这里可以集成分享功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享功能待实现'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加载失败'),
        content: Text('无法加载 PDF 文件：$error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // 返回上一页
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}