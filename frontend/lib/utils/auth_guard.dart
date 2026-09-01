import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../pages/login_page.dart';

/// 认证守卫
/// 用于保护需要登录才能访问的页面
class AuthGuard extends StatelessWidget {
  final Widget child;
  final bool requireAuth;

  const AuthGuard({
    super.key,
    required this.child,
    this.requireAuth = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!requireAuth) {
      return child;
    }

    // 检查登录状态
    final isLoggedIn = AuthService.instance.isLoggedIn;

    if (!isLoggedIn) {
      // 未登录，跳转到登录页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });

      // 显示加载中
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF666666),
          ),
        ),
      );
    }

    return child;
  }

  /// 创建需要认证的路由
  static Route<T> route<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<T>(
      settings: settings,
      builder: (context) => AuthGuard(
        child: Builder(builder: builder),
      ),
    );
  }
}

/// 路由守卫包装器
/// 用于在路由表中包装需要认证的页面
Widget authGuard(Widget child) {
  return AuthGuard(child: child);
}

/// 检查是否已登录的辅助函数
bool isAuthenticated() {
  return AuthService.instance.isLoggedIn;
}

/// 导航到登录页
void navigateToLogin(BuildContext context, {bool clearStack = false}) {
  if (clearStack) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  } else {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}

/// 导航到首页
void navigateToHome(BuildContext context, {bool clearStack = true}) {
  if (clearStack) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  } else {
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
