import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/app_pdf_viewer.dart';

/// 现代化 PDF 查看器页面
class PdfViewerPage extends StatefulWidget {
  final String? filePath;
  final String? url;
  final String title;
  final bool showPageInfo;

  const PdfViewerPage({
    super.key,
    this.filePath,
    this.url,
    this.title = 'PDF Document',
    this.showPageInfo = true,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage>
    with TickerProviderStateMixin {
  int _currentPageNumber = 1;
  int _totalPages = 0;
  bool _isDocumentLoaded = false;
  bool _isToolbarVisible = true;
  late AnimationController _toolbarAnimationController;
  late Animation<Offset> _toolbarSlideAnimation;

  @override
  void initState() {
    super.initState();
    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _toolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _toolbarAnimationController.forward();
  }

  @override
  void dispose() {
    _toolbarAnimationController.dispose();
    super.dispose();
  }

  void _toggleToolbar() {
    setState(() {
      _isToolbarVisible = !_isToolbarVisible;
    });
    if (_isToolbarVisible) {
      _toolbarAnimationController.forward();
    } else {
      _toolbarAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // PDF 查看器主体
          GestureDetector(
            onTap: _toggleToolbar,
            child: AppPdfViewer(
              filePath: widget.filePath,
              url: widget.url,
              showToolbar: false, // 使用自定义工具栏
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
          ),
          
          // 顶部工具栏
          SlideTransition(
            position: _toolbarSlideAnimation,
            child: _buildTopToolbar(),
          ),
          
          // 底部工具栏
          if (_isDocumentLoaded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_toolbarAnimationController),
                child: _buildBottomToolbar(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 返回按钮
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),

                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 标题和页码信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.showPageInfo && _isDocumentLoaded)
                    Text(
                      'Page $_currentPageNumber of $_totalPages',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            
            // 更多选项按钮
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showOptionsMenu();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(
            icon: Icons.first_page_rounded,
            onPressed: _isDocumentLoaded ? () {
              // 跳转到第一页的逻辑
            } : null,
          ),
          _buildToolbarButton(
            icon: Icons.navigate_before_rounded,
            onPressed: _isDocumentLoaded && _currentPageNumber > 1 ? () {
              // 上一页的逻辑
            } : null,
          ),
          
          // 页码显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_currentPageNumber / $_totalPages',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          _buildToolbarButton(
            icon: Icons.navigate_next_rounded,
            onPressed: _isDocumentLoaded && _currentPageNumber < _totalPages ? () {
              // 下一页的逻辑
            } : null,
          ),
          _buildToolbarButton(
            icon: Icons.last_page_rounded,
            onPressed: _isDocumentLoaded ? () {
              // 跳转到最后一页的逻辑
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed != null ? () {
        HapticFeedback.lightImpact();
        onPressed();
      } : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onPressed != null 
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onPressed != null 
              ? Colors.white
              : Colors.white.withOpacity(0.5),
          size: 20,
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuOption(
              icon: Icons.info_outline_rounded,
              title: 'Document Info',
              onTap: _showDocumentInfo,
            ),
            _buildMenuOption(
              icon: Icons.share_rounded,
              title: 'Share',
              onTap: _shareDocument,
            ),
            _buildMenuOption(
              icon: Icons.bookmark_add_rounded,
              title: 'Add Bookmark',
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('Bookmark');
              },
            ),
            _buildMenuOption(
              icon: Icons.search_rounded,
              title: 'Search in Document',
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('Search');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF6366F1),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showDocumentInfo() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Document Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', widget.title),
            _buildInfoRow('Total Pages', '$_totalPages'),
            _buildInfoRow('Current Page', '$_currentPageNumber'),
            if (widget.filePath != null)
              _buildInfoRow('File Path', widget.filePath!),
            if (widget.url != null)
              _buildInfoRow('URL', widget.url!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareDocument() {
    Navigator.pop(context);
    _showComingSoon('Share');
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
            ),
            SizedBox(width: 12),
            Text(
              'Loading Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text('Unable to load PDF file: $error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Go Back',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}