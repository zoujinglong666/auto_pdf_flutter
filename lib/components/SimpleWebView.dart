import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'AnimatedGradientLinearProgress.dart';


class SimpleWebView extends StatefulWidget {
  final String initialUrl;
  final String? pageTitle;
  final bool? showNavBar;
  final bool? showBackIcon;
  final bool? showRefresh;
  final bool? showProgress;
  final bool? enableJavaScript;
  final bool? enableZoom;
  final Map<String, String>? headers;
  final Function(String)? onUrlChanged;
  final Function(String)? onTitleChanged;
  final Widget? loadingWidget;
  final Widget? errorWidget; // 新增：自定义错误界面

  const SimpleWebView({
    super.key,
    required this.initialUrl,
    this.pageTitle,
    this.showNavBar,
    this.showBackIcon,
    this.showRefresh,
    this.showProgress,
    this.enableJavaScript,
    this.enableZoom,
    this.headers,
    this.onUrlChanged,
    this.onTitleChanged,
    this.loadingWidget,
    this.errorWidget, // 新增参数
  });

  @override
  State<SimpleWebView> createState() => _SimpleWebViewState();
}

class _SimpleWebViewState extends State<SimpleWebView> {
  late final WebViewController _controller;
  String _currentTitle = '';
  String _currentUrl = '';
  bool _isLoading = true;
  bool _hasError = false; // 新增：错误状态
  String _errorMessage = ''; // 新增：错误信息
  double _progress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _displayProgress = 0.0; // 用于显示的动画进度
  Timer? _progressTimer;
  bool _isFirstPage = false;
  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60fps
          (timer) {
        if (_displayProgress < _progress) {
          setState(() {
            _displayProgress += 0.01; // 每帧增加 1%
            if (_displayProgress >= _progress) {
              _displayProgress = _progress;
            }
          });
        }
        if (_displayProgress >= 1.0) {
          timer.cancel();
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _isFirstPage = !Navigator.canPop(context); // 👈 关键
    _initSystemUI();
    _initializeWebView();
  }

  void _initSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // void _initializeWebView() {
  //
  //   final creationParams = PlatformWebViewControllerCreationParams();
  //
  //   // 👇 创建 WebViewController 并传入 onPermissionRequest
  //   _controller = WebViewController.fromPlatformCreationParams(
  //     creationParams,
  //     onPermissionRequest: (permissionRequest) async {
  //       // 允许所有请求的资源（包括文件、摄像头、麦克风等）
  //       permissionRequest.grant();
  //     },
  //   )
  //     ..setJavaScriptMode(
  //       widget.enableJavaScript != false
  //           ? JavaScriptMode.unrestricted
  //           : JavaScriptMode.disabled,
  //     )
  //     ..setBackgroundColor(Colors.white)
  //
  //     ..setNavigationDelegate(
  //       NavigationDelegate(
  //         onPageStarted: (url) {
  //           setState(() {
  //             _isLoading = true;
  //             _hasError = false; // 重置错误状态
  //             _errorMessage = '';
  //             _progress = 0.0;
  //           });
  //           widget.onUrlChanged?.call(url);
  //         },
  //         onProgress: (progress) {
  //           setState(() {
  //             _progress = progress / 100;
  //           });
  //           _startProgressAnimation();
  //         },
  //         onPageFinished: (url) async {
  //           setState(() {
  //             _isLoading = false;
  //             _hasError = false;
  //             _currentUrl = url;
  //           });
  //
  //           // 可选：增强空内容检测
  //           try {
  //             final content = await _controller.runJavaScriptReturningResult(
  //               "document.body.innerText.trim()",
  //             );
  //
  //             if ((content as String).isEmpty) {
  //               setState(() {
  //                 _hasError = true;
  //                 _errorMessage = '页面加载内容为空';
  //               });
  //             }
  //           } catch (_) {
  //             // JS 执行失败忽略
  //           }
  //
  //           _getTitle();
  //           _checkNavigationState();
  //           widget.onUrlChanged?.call(url);
  //         },
  //         onWebResourceError: (WebResourceError error) {
  //           final isMainFrame = error.isForMainFrame ?? true; // iOS 上 null 默认 true
  //           if (isMainFrame && _shouldShowCustomError(error.errorType!)) {
  //             setState(() {
  //               _isLoading = false;
  //               _hasError = true;
  //               _errorMessage = _getErrorMessage(error);
  //             });
  //           }
  //         },
  //
  //         onNavigationRequest: (request) => NavigationDecision.navigate,
  //       ),
  //     )
  //     ..addJavaScriptChannel(
  //       'FlutterBridge',
  //       onMessageReceived: (message) => _handleJSMessage(message.message),
  //     );
  //
  //   _loadUrl();
  // }


  String _toContentUri(String filePath) {
    // 使用 android_content_provider 或自己用 ContentResolver
    // 这里给出最简单示例：把 file:// 转成 content://
    return Uri.file(filePath).toString().replaceFirst('file://', 'content://');
  }
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      // Convert the file to base64
      List<int> fileBytes = await File(filePath).readAsBytes();

      //convert filepath into uri
      final filePath1 = (await _getCacheDirectory()).uri.resolve(fileName);
      final file = await File.fromUri(filePath1).create(recursive: true);

      //convert file in bytes
      await file.writeAsBytes(fileBytes, flush: true);

      return [file.uri.toString()];
    }

    return [];
  }
  Future<Directory> _getCacheDirectory() async {
    // Use path_provider to get the temporary directory (cache directory)
    return await getTemporaryDirectory();
  }
  Future<List<String>> _iosFilePicker(
      FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return [];
    return result.files.map((e) => e.path!).toList();
  }
  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (permissionRequest) => permissionRequest.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _isLoading = true;
            _hasError = false;
            _errorMessage = '';
            _progress = 0.0;
          });
          widget.onUrlChanged?.call(url);
        },
        onProgress: (progress) {
          setState(() {
            _progress = progress / 100;
          });
          _startProgressAnimation();
        },
        onPageFinished: (url) async {
          setState(() {
            _isLoading = false;
            _hasError = false;
            _currentUrl = url;
          });

          // 检查页面内容是否为空
          try {
            final content = await _controller.runJavaScriptReturningResult(
              "document.body.innerText.trim()",
            );

            if ((content as String).isEmpty) {
              setState(() {
                _hasError = true;
                _errorMessage = '页面内容为空，请检查网络连接';
              });
            }
          } catch (_) {
            // JS 执行失败忽略
          }

          _getTitle();
          _checkNavigationState();
          widget.onUrlChanged?.call(url);
        },
        onWebResourceError: (WebResourceError error) {
          final isMainFrame = error.isForMainFrame ?? true;
          if (isMainFrame) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = _getErrorMessage(error);
            });
          }
        },
        onNavigationRequest: (request) => NavigationDecision.navigate,
      ))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) => _handleJSMessage(message.message),
      );

    // Android 文件选择
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setOnShowFileSelector(_androidFilePicker);
    }

    // iOS 文件选择
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _loadUrl();
  }

  // 新增：判断是否应该显示自定义错误界面
  bool _shouldShowCustomError(WebResourceErrorType errorType) {
    switch (errorType) {
      case WebResourceErrorType.timeout:
        return true; // 连接超时
      case WebResourceErrorType.hostLookup:
        return true; // 无法连接到服务器
      case WebResourceErrorType.unknown:
        return true; // 未知错误（通常是网络问题）
      case WebResourceErrorType.badUrl:
        return true; // 无效的网址
      case WebResourceErrorType.failedSslHandshake:
        return true; // SSL证书验证失败
      case WebResourceErrorType.tooManyRequests:
        return true; // 请求过于频繁
      case WebResourceErrorType.redirectLoop:
        return true; // 重定向循环
      default:
        return false; // 其他错误类型不显示自定义错误界面
    }
  }

  // 新增：获取错误信息
  String _getErrorMessage(WebResourceError error) {
    switch (error.errorType) {
      case WebResourceErrorType.unknown:
        return '网络连接异常，请检查网络设置';
      case WebResourceErrorType.badUrl:
        return '网址格式错误，请检查链接是否正确';
      case WebResourceErrorType.timeout:
        return '连接超时，请检查网络连接后重试';
      case WebResourceErrorType.hostLookup:
        return '无法连接到服务器，请检查网络连接';
      case WebResourceErrorType.failedSslHandshake:
        return '安全连接失败，请检查网络设置';
      case WebResourceErrorType.tooManyRequests:
        return '请求过于频繁，请稍后再试';
      case WebResourceErrorType.redirectLoop:
        return '页面重定向异常，请稍后重试';
      case WebResourceErrorType.connect:
        return '无法连接到服务器，请检查网络连接';
      case WebResourceErrorType.io:
        return '网络IO错误，请检查网络连接';
      case WebResourceErrorType.fileNotFound:
        return '请求的资源未找到';
      case WebResourceErrorType.file:
        return '文件访问错误';
      case WebResourceErrorType.authentication:
        return '身份验证失败';
      case WebResourceErrorType.proxyAuthentication:
        return '代理身份验证失败';
      case WebResourceErrorType.unsupportedAuthScheme:
        return '不支持的身份验证方案';
      case WebResourceErrorType.unsupportedScheme:
        return '不支持的URL协议';
      case WebResourceErrorType.failedSslHandshake:
        return 'SSL握手失败，请检查网络安全设置';
      case WebResourceErrorType.tooManyRequests:
        return '请求过于频繁，请稍后再试';
      case WebResourceErrorType.unsafeResource:
        return '不安全的资源，已被阻止';
      default:
        return '页面加载失败，请检查网络连接';
    }
  }

  // 新增：根据错误类型获取对应图标
  IconData _getErrorIcon() {
    if (_errorMessage.contains('网络') || _errorMessage.contains('连接')) {
      return Icons.wifi_off_rounded;
    } else if (_errorMessage.contains('超时')) {
      return Icons.access_time_rounded;
    } else if (_errorMessage.contains('服务器')) {
      return Icons.dns_rounded;
    } else if (_errorMessage.contains('网址') || _errorMessage.contains('链接')) {
      return Icons.link_off_rounded;
    } else if (_errorMessage.contains('安全') || _errorMessage.contains('SSL')) {
      return Icons.security_rounded;
    } else {
      return Icons.error_outline_rounded;
    }
  }

  // 新增：根据错误类型获取标题
  String _getErrorTitle() {
    if (_errorMessage.contains('网络') || _errorMessage.contains('连接')) {
      return '网络连接失败';
    } else if (_errorMessage.contains('超时')) {
      return '连接超时';
    } else if (_errorMessage.contains('服务器')) {
      return '服务器无响应';
    } else if (_errorMessage.contains('网址') || _errorMessage.contains('链接')) {
      return '网址错误';
    } else if (_errorMessage.contains('安全') || _errorMessage.contains('SSL')) {
      return '安全连接失败';
    } else {
      return '页面加载失败';
    }
  }

  // 新增：重试加载
  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _progress = 0.0;
    });
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      String url = widget.initialUrl.trim();
      final ts = DateTime.now().millisecondsSinceEpoch.toString();

      // 判断是否已有 query 参数
      if (url.contains('?')) {
        url = '$url&_ts=$ts';
      } else {
        url = '$url?_ts=$ts';
      }

      final uri = Uri.parse(url);
      await _controller.loadRequest(
        uri,
        headers: widget.headers ?? {},
      );
    } catch (e) {
      debugPrint('加载 URL 失败: $e');
    }
  }


  Future<void> _getTitle() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final rawTitle = await _controller.getTitle();
      if (!mounted) return;

      final title = rawTitle?.trim();
      final isValid = _isValidTitle(title);
      final newTitle = isValid ? title : (widget.pageTitle ?? '');

      if (newTitle != _currentTitle) {
        setState(() {
          _currentTitle = newTitle!;
        });
        widget.onTitleChanged?.call(newTitle!);
      }
    } catch (_) {}
  }

  bool _isValidTitle(String? title) {
    if (title == null || title.isEmpty) return false;

    // 检测 URL
    final isUrl = RegExp(r'^https?:\/\/[\w\.-]+').hasMatch(title);

    // 检测 IPv4 地址（包括局域网常见网段）
    final isIPv4 = RegExp(
        r'^(?:\d{1,3}\.){3}\d{1,3}$'
    ).hasMatch(title);

    // 局域网 IP 特殊处理（192.168.x.x / 10.x.x.x / 172.16-31.x.x）
    final isLAN = RegExp(
        r'^(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})$'
    ).hasMatch(title);

    // 检测 IPv6
    final isIPv6 = RegExp(
        r'^\[?[0-9a-fA-F:]+\]?$'
    ).hasMatch(title);

    // 其他特殊条件：包含 http/www 或太短
    final hasSpecialChars = title.contains("http") || title.contains("www") || title.length < 2;

    return !isUrl && !isIPv4 && !isIPv6 && !isLAN && !hasSpecialChars;
  }


  Future<void> _checkNavigationState() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  void _handleJSMessage(String message) {
    try {
      final data = jsonDecode(message);
      final action = data['action'];
      switch (action) {
        case 'openNewWebView':
          final url = data['url'];
          final title = data['title'];
          final showNavBar = data['showNavBar'];
          if (url != null && url.toString().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SimpleWebView(
                  initialUrl: url,
                  pageTitle: title,
                  showNavBar: showNavBar ?? false,
                ),
              ),
            );
          }
          break;
        case 'goBack':
          Navigator.pop(context);
          break;
        case 'reload':
          _controller.reload();
          break;
      }
    } catch (_) {}
  }

  void _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      Navigator.pop(context);
    }
  }

  // 新增：处理手势返回
  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false; // 阻止默认的返回行为
    }
    return true; // 允许默认的返回行为
  }

  void _goForward() async {
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  void _reload() {
    _controller.reload();
    _retry();
  }


  Future<void> _openInBrowser() async {
    String url = _currentUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接: $e')),
      );
    }
  }
  Future<void> _openInBrowser2() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL 格式错误')),
      );
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开链接')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final showNav = widget.showNavBar != false;
    final showBackIcon = widget.showBackIcon != false;
    final showRefresh = widget.showRefresh != false;
    final showProgress = widget.showProgress != false;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: showNav ? _buildAppBar(showBackIcon, showRefresh) : null,
        body: SafeArea(
          top: !showNav,
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                if (!_hasError) WebViewWidget(controller: _controller),
                if (showProgress && _isLoading && !_hasError && _progress < 1.0)
                  _buildProgressBar(),
                if (_isLoading && !showProgress && !_hasError)
                  _buildLoadingIndicator(),
                if (_hasError) _buildErrorWidget(), // 放最后一层，遮住 webview
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool showBackIcon, bool showRefresh) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        leading: _isFirstPage ? null : _buildBackButton(),
        centerTitle: true,
        title: _buildTitle(),
        actions: _buildActions(showRefresh),
      ),
    );
  }

  // Widget _buildBackButton() {
  //   return IconButton(
  //     icon: const Icon(Icons.arrow_back, color: Colors.black),
  //     onPressed: _goBack,
  //   );
  // }

  Widget _buildTitle() {
    return Text(
      _currentTitle.isNotEmpty ? _currentTitle : (widget.pageTitle ?? ''),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _buildActions(bool showRefresh) {
    final actions = <Widget>[];

    if (_canGoForward) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black),
          onPressed: _goForward,
        ),
      );
    }

    if (showRefresh) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          onPressed: _reload,
        ),
      );
    }

    actions.add(
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.black),
        onSelected: (value) {
          switch (value) {
            case 'reload':
              _reload();
              break;
            case 'copy_url':
              Clipboard.setData(ClipboardData(text: _currentUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('链接已复制')),
              );
              break;
            case 'open_browser':
              _openInBrowser();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'reload',
            child: Row(
              children: [Icon(Icons.refresh), SizedBox(width: 8), Text('刷新')],
            ),
          ),
          const PopupMenuItem(
            value: 'copy_url',
            child: Row(
              children: [Icon(Icons.copy), SizedBox(width: 8), Text('复制链接')],
            ),
          ),
          const PopupMenuItem(
            value: 'open_browser',
            child: Row(
              children: [Icon(Icons.open_in_browser), SizedBox(width: 8), Text('在浏览器打开')],
            ),
          ),
        ],
      ),
    );

    return actions;
  }

  Widget _buildProgressBar() {
    return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child:AnimatedGradientLinearProgress(
          value: _progress,
          backgroundColor: Colors.grey.shade200,
        )
    );
  }
  Widget _buildBackButton() {
    return _isFirstPage
        ? const SizedBox.shrink() // 不显示
        : IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: _goBack,
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Center(
        child: widget.loadingWidget ??
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '页面加载中...',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请稍候',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: widget.errorWidget ??
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 自定义错误图标容器
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getErrorIcon(),
                      size: 48,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _getErrorTitle(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage.isNotEmpty ? _errorMessage : '页面加载遇到问题，请稍后重试',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 重试按钮
                  Container(
                    width: double.infinity,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF1976D2).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '重新加载',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 返回按钮
                  if (!_isFirstPage)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        '返回上一页',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
