import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 认证服务
/// 处理用户注册、登录、登出等认证相关功能
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  final ApiService _api = ApiService.instance;

  // 存储键
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userInfoKey = 'user_info';

  String? _token;
  String? _refreshToken;
  String? _userId;
  UserInfo? _userInfo;

  /// 是否已登录
  bool get isLoggedIn => _token != null && _userId != null;

  /// 获取当前 token
  String? get token => _token;

  /// 获取当前用户ID
  String? get userId => _userId;

  /// 获取当前用户信息
  UserInfo? get userInfo => _userInfo;

  /// 初始化服务（从本地加载token）
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getString(_userIdKey);
    
    // 加载用户信息
    final nickname = prefs.getString('user_nickname');
    final avatar = prefs.getString('user_avatar');
    final role = prefs.getString('user_role');
    final vipLevel = prefs.getString('user_vip_level');
    final phone = prefs.getString('user_phone');
    
    if (nickname != null && avatar != null) {
      _userInfo = UserInfo(
        nickname: nickname,
        avatar: avatar,
        role: role ?? 'student',
        vipLevel: vipLevel ?? 'free',
        phone: phone,
      );
    }
  }

  /// 用户注册
  Future<RegisterResult> register({
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/register',
        body: {
          'phone': phone,
          'code': code,
          'password': password,
          if (inviteCode != null) 'invite_code': inviteCode,
        },
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        
        // 保存认证信息
        await _saveAuth(
          token: data['token'],
          refreshToken: data['refresh_token'],
          userId: data['user_id'],
        );

        return RegisterResult(
          success: true,
          isNewUser: data['is_new_user'] ?? true,
          gifts: (data['gifts'] as List?)
              ?.map((g) => Gift.fromJson(g))
              .toList() ?? [],
        );
      }

      return RegisterResult(
        success: false,
        error: response['message'] ?? '注册失败',
      );
    } catch (e) {
      return RegisterResult(
        success: false,
        error: '注册失败: $e',
      );
    }
  }

  /// 用户登录（密码登录）
  Future<LoginResult> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/login',
        body: {
          'phone': phone,
          'password': password,
        },
      );

      return _handleLoginResponse(response);
    } catch (e) {
      return LoginResult(
        success: false,
        error: '登录失败: $e',
      );
    }
  }

  /// 用户登录（验证码登录）
  Future<LoginResult> loginWithCode({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/login',
        body: {
          'phone': phone,
          'code': code,
        },
      );

      return _handleLoginResponse(response);
    } catch (e) {
      return LoginResult(
        success: false,
        error: '登录失败: $e',
      );
    }
  }

  /// 处理登录响应
  Future<LoginResult> _handleLoginResponse(Map<String, dynamic> response) async {
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      
      // 保存认证信息
      await _saveAuth(
        token: data['token'],
        refreshToken: data['refresh_token'],
        userId: data['user_id'],
      );

      // 保存用户信息
      if (data['user_info'] != null) {
        _userInfo = UserInfo.fromJson(data['user_info']);
        await _saveUserInfo(_userInfo!);
      }

      return LoginResult(success: true);
    }

    return LoginResult(
      success: false,
      error: response['message'] ?? '登录失败',
    );
  }

  /// 发送验证码
  Future<SendCodeResult> sendCode({
    required String phone,
    String type = 'register', // register/login/reset
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/auth/send-code',
        body: {
          'phone': phone,
          'type': type,
        },
      );

      if (response['success'] == true) {
        return SendCodeResult(
          success: true,
          expireAt: response['data']?['expire_at'],
        );
      }

      return SendCodeResult(
        success: false,
        error: response['message'] ?? '发送失败',
      );
    } catch (e) {
      return SendCodeResult(
        success: false,
        error: '发送失败: $e',
      );
    }
  }

  /// 刷新token
  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _api.post(
        '/api/v1/auth/refresh-token',
        body: {
          'refresh_token': _refreshToken,
        },
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        await _saveAuth(
          token: data['token'],
          refreshToken: data['refresh_token'],
          userId: _userId,
        );
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    await clearAuth();
  }

  /// 保存认证信息
  Future<void> _saveAuth({
    required String token,
    required String refreshToken,
    String? userId,
  }) async {
    _token = token;
    _refreshToken = refreshToken;
    if (userId != null) _userId = userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshTokenKey, refreshToken);
    if (userId != null) {
      await prefs.setString(_userIdKey, userId);
    }
  }

  /// 获取用户手机号
  String getUserPhone() {
    return _userInfo?.phone ?? '';
  }

  /// 更新用户昵称
  Future<bool> updateNickname(String nickname) async {
    if (!isLoggedIn) return false;

    try {
      final response = await _api.put(
        '/api/v1/user/profile',
        body: {'nickname': nickname},
        headers: getAuthHeaders(),
      );

      if (response['success'] == true) {
        // 更新内存中的用户信息
        if (_userInfo != null) {
          _userInfo = UserInfo(
            nickname: nickname,
            avatar: _userInfo!.avatar,
            role: _userInfo!.role,
            vipLevel: _userInfo!.vipLevel,
            phone: _userInfo!.phone,
          );
          // 同步到本地存储
          await _saveUserInfo(_userInfo!);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('更新昵称失败: $e');
      return false;
    }
  }

  /// 保存用户信息
  Future<void> _saveUserInfo(UserInfo userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    // 使用 JSON 格式保存
    final userInfoMap = userInfo.toJson();
    await prefs.setString(_userInfoKey, userInfoMap.toString());
    
    // 分别保存关键字段，方便快速读取
    await prefs.setString('user_nickname', userInfo.nickname);
    await prefs.setString('user_avatar', userInfo.avatar);
    await prefs.setString('user_role', userInfo.role);
    await prefs.setString('user_vip_level', userInfo.vipLevel);
    if (userInfo.phone != null) {
      await prefs.setString('user_phone', userInfo.phone!);
    }
  }

  /// 清除认证信息
  Future<void> clearAuth() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _userInfo = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userInfoKey);
    await prefs.remove('user_nickname');
    await prefs.remove('user_avatar');
    await prefs.remove('user_role');
    await prefs.remove('user_vip_level');
    await prefs.remove('user_phone');
  }

  /// 获取认证头
  Map<String, String> getAuthHeaders() {
    if (_token != null) {
      return {'Authorization': 'Bearer $_token'};
    }
    return {};
  }

  /// 获取用户昵称
  String getUserNickname() {
    return _userInfo?.nickname ?? '新用户';
  }

  /// 获取用户头像URL
  String getUserAvatar() {
    return _userInfo?.avatar ?? '';
  }

  /// 获取用户角色
  String getUserRole() {
    return _userInfo?.role ?? 'student';
  }

  /// 获取VIP等级
  String getVipLevel() {
    return _userInfo?.vipLevel ?? 'free';
  }

  /// 是否是VIP用户
  bool isVip() {
    final level = getVipLevel();
    return level != 'free';
  }

  /// 提交用户反馈
  Future<bool> submitFeedback({
    required String content,
    String? contact,
  }) async {
    try {
      final response = await _api.post(
        '/api/v1/feedback', // 使用 v1 接口
        body: {
          'content': content,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
          'feedback_type': 'general',
        },
        headers: getAuthHeaders(), // 自动附加认证token
      );
      
      // ApiService._processResponse 已经处理了 success 字段
      return response?['success'] == true;
    } catch (e) {
      print('提交反馈失败: $e');
      return false;
    }
  }
}

/// 注册结果
class RegisterResult {
  final bool success;
  final String? error;
  final bool isNewUser;
  final List<Gift> gifts;

  RegisterResult({
    required this.success,
    this.error,
    this.isNewUser = true,
    this.gifts = const [],
  });
}

/// 登录结果
class LoginResult {
  final bool success;
  final String? error;

  LoginResult({
    required this.success,
    this.error,
  });
}

/// 发送验证码结果
class SendCodeResult {
  final bool success;
  final String? error;
  final String? expireAt;

  SendCodeResult({
    required this.success,
    this.error,
    this.expireAt,
  });
}

/// 用户信息
class UserInfo {
  final String nickname;
  final String avatar;
  final String role;
  final String vipLevel;
  final String? vipExpireAt;
  final String? phone;

  UserInfo({
    required this.nickname,
    required this.avatar,
    required this.role,
    required this.vipLevel,
    this.vipExpireAt,
    this.phone,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      role: json['role'] ?? 'student',
      vipLevel: json['vip_level'] ?? 'free',
      vipExpireAt: json['vip_expire_at'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'avatar': avatar,
      'role': role,
      'vip_level': vipLevel,
      'vip_expire_at': vipExpireAt,
      'phone': phone,
    };
  }
}

/// 礼物
class Gift {
  final String type;
  final int? days;

  Gift({
    required this.type,
    this.days,
  });

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      type: json['type'] ?? '',
      days: json['days'],
    );
  }
}
