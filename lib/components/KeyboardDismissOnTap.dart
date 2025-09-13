import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 点击空白区域自动关闭键盘的组件封装
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _dismissKeyboard();
      },
      child: child,
    );
  }

  /// 关闭键盘的方法
  void _dismissKeyboard() {
    // 方法1: 使用 SystemChannels 强制关闭键盘
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    // 方法2: 清除焦点
    FocusManager.instance.primaryFocus?.unfocus();
    
    // 方法3: 使用 ServicesBinding 确保键盘完全关闭
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }
}
