import 'package:flutter/material.dart';
import '../components/app_pdf_viewer.dart';
import '../pages/pdf_viewer_page.dart';

/// 简单使用示例
/// 展示如何快速集成 PDF 查看器组件
class SimpleExample extends StatelessWidget {
  const SimpleExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 查看器示例'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择查看方式',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // 示例1：直接使用组件
            ElevatedButton.icon(
              onPressed: () => _showDirectComponent(context),
              icon: const Icon(Icons.widgets),
              label: const Text('直接使用组件'),
            ),
            
            const SizedBox(height: 12),
            
            // 示例2：使用完整页面
            ElevatedButton.icon(
              onPressed: () => _showFullPage(context),
              icon: const Icon(Icons.fullscreen),
              label: const Text('使用完整页面'),
            ),
            
            const SizedBox(height: 12),
            
            // 示例3：本地文件（需要用户提供路径）
            ElevatedButton.icon(
              onPressed: () => _showLocalFileDialog(context),
              icon: const Icon(Icons.folder),
              label: const Text('打开本地文件'),
            ),
          ],
        ),
      ),
    );
  }

  /// 直接使用组件示例
  void _showDirectComponent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('直接使用组件')),
          body: const AppPdfViewer(
            url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
            showToolbar: true,
          ),
        ),
      ),
    );
  }

  /// 使用完整页面示例
  void _showFullPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PdfViewerPage(
          url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          title: '示例文档',
          showPageInfo: true,
        ),
      ),
    );
  }

  /// 本地文件对话框
  void _showLocalFileDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入本地文件路径'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例如: /storage/emulated/0/Download/document.pdf',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerPage(
                      filePath: controller.text,
                      title: '本地文档',
                    ),
                  ),
                );
              }
            },
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }
}