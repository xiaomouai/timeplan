import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api_service.dart';
import 'auth_service.dart';

/// 会员服务管理
class MembershipService {
  static final MembershipService _instance = MembershipService._internal();
  factory MembershipService() => _instance;
  MembershipService._internal();

  static MembershipService get instance => _instance;

  // 存储键
  static const String _membershipKey = 'membership_status';
  static const String _lastCheckKey = 'membership_last_check';

  MembershipStatus? _cachedStatus;
  DateTime? _lastCheckTime;

  /// 获取会员状态（带缓存）
  Future<MembershipStatus?> getMembershipStatus({bool forceRefresh = false}) async {
    // 如果距离上次检查不到5分钟，使用缓存
    if (!forceRefresh && _cachedStatus != null && _lastCheckTime != null) {
      final diff = DateTime.now().difference(_lastCheckTime!);
      if (diff.inMinutes < 5) {
        return _cachedStatus;
      }
    }

    try {
      final response = await BackendApiService.getMembershipStatus();
      if (response['success'] == true && response['data'] != null) {
        final status = MembershipStatus.fromJson(response['data']);
        
        // 缓存结果
        _cachedStatus = status;
        _lastCheckTime = DateTime.now();
        await _saveMembershipStatus(status);
        
        return status;
      }
    } catch (e) {
      print('获取会员状态失败: $e');
    }
    
    // 失败时从本地缓存读取
    return await _loadMembershipStatus();
  }

  /// 获取会员套餐列表
  Future<List<MembershipPlan>> getMembershipPlans() async {
    try {
      final response = await BackendApiService.getMembershipPlans();
      if (response['success'] == true && response['data'] != null) {
        final plans = (response['data']['plans'] as List?)
            ?.map((p) => MembershipPlan.fromJson(p))
            .toList() ?? [];
        return plans;
      }
    } catch (e) {
      print('获取会员套餐失败: $e');
    }
    
    return [];
  }

  /// 激活会员（激活码）
  Future<bool> activateMembership(String activationCode, String userId) async {
    try {
      final response = await BackendApiService.activateMembership(activationCode, userId);
      return response['success'] == true;
    } catch (e) {
      print('激活会员失败: $e');
      return false;
    }
  }

  /// 激活会员（带详细结果返回）
  Future<ActivationResult> activateWithCode(String code) async {
    final uid = AuthService.instance.userId;
    if (uid == null || uid.isEmpty) {
      return ActivationResult(success: false, message: '请先登录');
    }

    try {
      final response = await BackendApiService.activateMembership(code, uid);
      if (response['success'] == true) {
        // 激活成功，刷新本地缓存
        await getMembershipStatus(forceRefresh: true);
        return ActivationResult(success: true, message: '激活成功');
      } else {
        return ActivationResult(
          success: false, 
          message: response['message'] ?? '激活码无效或已过期',
        );
      }
    } catch (e) {
      print('激活请求异常: $e');
      return ActivationResult(success: false, message: '激活失败: $e');
    }
  }

  /// 检查功能访问权限
  Future<bool> checkFeatureAccess(String userId, String feature) async {
    try {
      final response = await BackendApiService.checkFeatureAccess(userId, feature);
      if (response['success'] == true && response['data'] != null) {
        return response['data']['has_access'] == true;
      }
    } catch (e) {
      print('检查功能权限失败: $e');
    }
    return false;
  }

  /// 是否应该显示付费弹窗
  Future<bool> shouldShowPaymentDialog() async {
    final status = await getMembershipStatus();
    return status?.shouldShowPaymentDialog ?? false;
  }

  /// 清除缓存
  void clearCache() {
    _cachedStatus = null;
    _lastCheckTime = null;
  }

  Future<PaymentOrder?> createOrder({
    required String planId,
    required String userId,
    String provider = 'wechat',
  }) async {
    try {
      final response = await BackendApiService.createMembershipOrder(planId, userId, provider: provider);
      if (response['success'] == true && response['data'] != null) {
        return PaymentOrder.fromJson(response['data']);
      }
    } catch (e) {
      print('创建订单失败: $e');
    }
    return null;
  }

  Future<bool> queryOrderPaid(String orderId) async {
    try {
      final response = await BackendApiService.getOrderStatus(orderId);
      if (response['success'] == true && response['data'] != null) {
        return response['data']['paid'] == true;
      }
    } catch (e) {
      print('查询订单状态失败: $e');
    }
    return false;
  }

  /// 保存会员状态到本地
  Future<void> _saveMembershipStatus(MembershipStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_membershipKey, status.toJsonString());
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 从本地加载会员状态
  Future<MembershipStatus?> _loadMembershipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_membershipKey);
    if (jsonStr != null) {
      try {
        return MembershipStatus.fromJsonString(jsonStr);
      } catch (e) {
        print('解析本地会员状态失败: $e');
      }
    }
    return null;
  }
}

/// 会员状态
class MembershipStatus {
  final String userId;
  final String vipLevel; // free/basic/ai/vip
  final DateTime? trialEndDate;
  final bool isTrialExpired;
  final bool hasPaid;
  final bool shouldShowPaymentDialog;
  final MembershipInfo? membershipInfo;

  MembershipStatus({
    required this.userId,
    required this.vipLevel,
    this.trialEndDate,
    required this.isTrialExpired,
    required this.hasPaid,
    required this.shouldShowPaymentDialog,
    this.membershipInfo,
  });

  factory MembershipStatus.fromJson(Map<String, dynamic> json) {
    return MembershipStatus(
      userId: json['user_id'] ?? '',
      vipLevel: json['vip_level'] ?? 'free',
      trialEndDate: json['trial_end_date'] != null 
          ? DateTime.parse(json['trial_end_date']) 
          : null,
      isTrialExpired: json['is_trial_expired'] ?? false,
      hasPaid: json['has_paid'] ?? false,
      shouldShowPaymentDialog: json['should_show_payment_dialog'] ?? false,
      membershipInfo: json['membership_info'] != null 
          ? MembershipInfo.fromJson(json['membership_info']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'vip_level': vipLevel,
      'trial_end_date': trialEndDate?.toIso8601String(),
      'is_trial_expired': isTrialExpired,
      'has_paid': hasPaid,
      'should_show_payment_dialog': shouldShowPaymentDialog,
      'membership_info': membershipInfo?.toJson(),
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory MembershipStatus.fromJsonString(String jsonStr) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      return MembershipStatus.fromJson(json);
    } catch (e) {
      print('解析会员状态JSON失败: $e');
      return MembershipStatus(
        userId: '',
        vipLevel: 'free',
        isTrialExpired: true,
        hasPaid: false,
        shouldShowPaymentDialog: false,
      );
    }
  }

  bool get isVip => vipLevel != 'free';
  bool get isTrial => vipLevel == 'free' && !isTrialExpired;
}

/// 会员信息
class MembershipInfo {
  final String type; // month/season/year
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  MembershipInfo({
    required this.type,
    this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory MembershipInfo.fromJson(Map<String, dynamic> json) {
    return MembershipInfo(
      type: json['type'] ?? '',
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
    };
  }
}

/// 会员套餐
class MembershipPlan {
  final String id;
  final String name;
  final double price; // 单位：元
  final double originalPrice;
  final String duration;
  final List<String> features;
  final String? tag;
  final bool recommended;

  MembershipPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.duration,
    required this.features,
    this.tag,
    required this.recommended,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      originalPrice: (json['original_price'] ?? 0).toDouble(),
      duration: json['duration'] ?? '',
      features: (json['features'] as List?)?.map((f) => f.toString()).toList() ?? [],
      tag: json['tag'],
      recommended: json['recommended'] ?? false,
    );
  }

  double get discount => originalPrice > 0 ? (price / originalPrice) : 1.0;
  String get discountText => '${(discount * 10).toStringAsFixed(1)}折';
}

class PaymentOrder {
  final String orderId;
  final String payUrl;
  final String? qrcodeUrl;
  PaymentOrder({
    required this.orderId,
    required this.payUrl,
    this.qrcodeUrl,
  });
  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      orderId: json['order_id'] ?? '',
      payUrl: json['pay_url'] ?? '',
      qrcodeUrl: json['qrcode_url'],
    );
  }
}

/// 激活结果
class ActivationResult {
  final bool success;
  final String message;

  ActivationResult({
    required this.success,
    required this.message,
  });
}
