import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 现代化可复用的 PDF 查看器组件
class AppPdfViewer extends StatefulWidget {
  final String? filePath;
  final String? url;
  final bool showToolbar;
  final double initialZoomLevel;
  final bool enableTextSelection;
  final Function(int pageNumber, int totalPages)? onPageChanged;
  final Function(int totalPages)? onDocumentLoaded;
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

class _AppPdfViewerState extends State<AppPdfViewer>
    with TickerProviderStateMixin {
  PDFViewController? _pdfViewController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _localFilePath;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isReady = false;
  double _downloadProgress = 0.0;
  
  late AnimationController _loadingAnimationController;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeInOut,
    ));
    _initializePdf();
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializePdf() async {
    if (widget.url != null) {
      await _downloadPdfFromUrl();
    } else if (widget.filePath != null) {
      _localFilePath = widget.filePath;
    }
  }

  Future<void> _downloadPdfFromUrl() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });
    
    _loadingAnimationController.repeat();

    try {
      final response = await http.get(Uri.parse(widget.url!));
      
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = widget.url!.split('/').last.split('?').first;
        final file = File('${directory.path}/$fileName');
        
        await file.writeAsBytes(response.bodyBytes);
        _localFilePath = file.path;
        
        setState(() {
          _downloadProgress = 1.0;
        });
      } else {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to download PDF: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _loadingAnimationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_localFilePath == null) {
      return _buildInvalidPathView();
    }

    return _buildPdfView();
  }

  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 现代化加载动画
            AnimatedBuilder(
              animation: _loadingAnimation,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF6366F1).withOpacity(0.8),
                        const Color(0xFF6366F1),
                      ],
                      stops: [0.0, 0.7, 1.0],
                      transform: GradientRotation(_loadingAnimation.value * 2 * 3.14159),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1A1A),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Loading PDF...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (widget.url != null) ...[
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _downloadProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Color(0xFFEF4444),
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Failed to Load PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializePdf();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidPathView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Invalid PDF Path',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: PDFView(
        filePath: _localFilePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        backgroundColor: const Color(0xFF1A1A1A),
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
            _errorMessage = 'Page $page loading failed: $error';
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
    );
  }
}