import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/backend_api_service.dart';

/// 首页控制器，管理首页的全局状态和业务逻辑
class HomeController extends ChangeNotifier {
  // 当前选中的 Tab 索引
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  // 用户信息
  String _userName = '新用户';
  String get userName => _userName;
  
  String _userAvatar = '';
  String get userAvatar => _userAvatar;
  
  String _userPhone = '';
  String get userPhone => _userPhone;

  // 会员状态
  bool _isVip = false;
  bool get isVip => _isVip;

  // 是否加载中
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  /// 加载用户信息
  Future<void> loadUserProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await BackendApiService.getUserProfile();
      if (profile != null) {
        _userName = profile['nickname'] ?? '新用户';
        _userAvatar = profile['avatar'] ?? '';
        _userPhone = profile['phone'] ?? '';
        _isVip = AuthService.instance.isVip();
      }
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新昵称
  Future<bool> updateNickname(String newNickname) async {
    try {
      final success = await BackendApiService.updateUserProfile(nickname: newNickname);
      if (success) {
        _userName = newNickname;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('更新昵称失败: $e');
    }
    return false;
  }
  
  // 可以根据需要添加更多共享状态，如学习进度等
}
