import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 可复用的 PDF 查看器组件
/// 支持本地文件和网络文件，具备完整的交互功能
class AppPdfViewer extends StatefulWidget {
  /// 本地文件路径
  final String? filePath;

  /// 网络文件 URL
  final String? url;

  /// 是否显示工具栏
  final bool showToolbar;

  /// 初始缩放级别
  final double initialZoomLevel;

  /// 是否启用文本选择
  final bool enableTextSelection;

  /// 页面变化回调
  final Function(int pageNumber, int totalPages)? onPageChanged;

  /// 文档加载完成回调
  final Function(int totalPages)? onDocumentLoaded;

  /// 文档加载失败回调
  final Function(String error)? onDocumentLoadFailed;

  const AppPdfViewer({
    super.key,
    this.filePath,
    this.url,
    this.showToolbar = true,
    this.initialZoomLevel = 1.0,
    this.enableTextSelection = true,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDocumentLoadFailed,
  }) : assert(filePath != null || url != null, '必须提供 filePath 或 url 其中之一');

  @override
  State<AppPdfViewer> createState() => _AppPdfViewerState();
}

class _AppPdfViewerState extends State<AppPdfViewer> {
  PDFViewController? _pdfViewController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _localFilePath;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  /// 初始化 PDF 文件
  Future<void> _initializePdf() async {
    if (widget.url != null) {
      await _downloadPdfFromUrl();
    } else if (widget.filePath != null) {
      _localFilePath = widget.filePath;
    }
  }

  /// 从网络下载 PDF 文件到本地
  Future<void> _downloadPdfFromUrl() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.url!));

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = widget.url!.split('/').last.split('?').first;
        final file = File('${directory.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);
        _localFilePath = file.path;
      } else {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '下载 PDF 失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载 PDF...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializePdf();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_localFilePath == null) {
      return const Center(
        child: Text('PDF 文件路径无效'),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        return Column(
          children: [
            if (widget.showToolbar) _buildToolbar(),
            Expanded(
              child: PDFView(
                filePath: _localFilePath!,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: false,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (pages) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  });
                  widget.onDocumentLoaded?.call(_totalPages);
                },
                onError: (error) {
                  setState(() {
                    _errorMessage = error.toString();
                  });
                  widget.onDocumentLoadFailed?.call(error.toString());
                },
                onPageError: (page, error) {
                  setState(() {
                    _errorMessage = '页面 $page 加载失败: $error';
                  });
                },
                onViewCreated: (PDFViewController pdfViewController) {
                  _pdfViewController = pdfViewController;
                },
                onLinkHandler: (uri) {
                  // 处理链接点击
                },
                onPageChanged: (page, total) {
                  setState(() {
                    _currentPage = page! + 1;
                    _totalPages = total!;
                  });
                  widget.onPageChanged?.call(_currentPage, _totalPages);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建工具栏
  Widget _buildToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Color(0xFF6366F1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // IconButton(
          //   icon: const Icon(Icons.zoom_out, color: Colors.white),
          //   onPressed: _isReady ? () async {
          //     final currentZoom = await _pdfViewController?.getCurrentPage();
          //     // flutter_pdfview 不直接支持缩放控制，这里可以实现其他逻辑
          //   } : null,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.zoom_in, color: Colors.white),
          //   onPressed: _isReady ? () async {
          //     // flutter_pdfview 不直接支持缩放控制，这里可以实现其他逻辑
          //   } : null,
          // ),
          // const Spacer(),
          Text(
            '$_currentPage / $_totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.first_page, color: Colors.white),
            onPressed: _isReady ? () async {
              await _pdfViewController?.setPage(0);
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before, color: Colors.white),
            onPressed: _isReady && _currentPage > 1 ? () async {
              await _pdfViewController?.setPage(_currentPage - 2);
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next, color: Colors.white),
            onPressed: _isReady && _currentPage < _totalPages ? () async {
              await _pdfViewController?.setPage(_currentPage);
            } : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page, color: Colors.white),
            onPressed: _isReady ? () async {
              await _pdfViewController?.setPage(_totalPages - 1);
            } : null,
          ),
        ],
      ),
    );
  }
}