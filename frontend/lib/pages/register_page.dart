import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../utils/sound_service.dart';

/// 注册页面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService.instance;
  
  // 表单控制器
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  // 验证码倒计时
  int _countdown = 0;
  Timer? _countdownTimer;
  
  // 加载状态
  bool _isLoading = false;
  
  // 密码可见性
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  
  // 同意协议
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () {
            SoundService.playTapSound();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '注册账号',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // 手机号输入
              _buildInputField(
                controller: _phoneController,
                hintText: '请输入手机号',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              
              const SizedBox(height: 16),
              
              // 验证码输入
              _buildCodeInput(),
              
              const SizedBox(height: 16),
              
              // 密码输入
              _buildPasswordField(
                controller: _passwordController,
                hintText: '请设置密码（6-20位）',
                isVisible: _passwordVisible,
                onVisibilityToggle: () {
                  setState(() => _passwordVisible = !_passwordVisible);
                },
              ),
              
              const SizedBox(height: 16),
              
              // 确认密码输入
              _buildPasswordField(
                controller: _confirmPasswordController,
                hintText: '请再次输入密码',
                isVisible: _confirmPasswordVisible,
                onVisibilityToggle: () {
                  setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
                },
              ),
              
              const SizedBox(height: 16),
              
              // 邀请码输入（可选）
              _buildInputField(
                controller: _inviteCodeController,
                hintText: '邀请码（选填）',
                icon: Icons.card_giftcard,
              ),
              
              const SizedBox(height: 24),
              
              // 协议勾选
              _buildAgreementCheckbox(),
              
              const SizedBox(height: 24),
              
              // 注册按钮
              _buildRegisterButton(),
              
              const SizedBox(height: 16),
              
              // 登录提示
              _buildLoginHint(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建输入框
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF00C897)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  /// 构建验证码输入
  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '请输入验证码',
                prefixIcon: Icon(Icons.message_outlined, color: Color(0xFF00C897)),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ),
          _buildSendCodeButton(),
        ],
      ),
    );
  }

  /// 构建发送验证码按钮
  Widget _buildSendCodeButton() {
    final canSend = _countdown == 0 && _phoneController.text.length == 11;
    
    return GestureDetector(
      onTap: canSend ? _sendCode : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: canSend ? const Color(0xFF00C897) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _countdown > 0 ? '${_countdown}s' : '发送验证码',
          style: TextStyle(
            fontSize: 12,
            color: canSend ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 构建密码输入框
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00C897)),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade400,
            ),
            onPressed: () {
              SoundService.playTapSound();
              onVisibilityToggle();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  /// 构建协议勾选
  Widget _buildAgreementCheckbox() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (value) {
              SoundService.playTapSound();
              setState(() => _agreedToTerms = value ?? false);
            },
            activeColor: const Color(0xFF00C897),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            children: [
              Text(
                '我已阅读并同意',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  SoundService.playTapSound();
                  _showAgreement('用户协议');
                },
                child: const Text(
                  '《用户协议》',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00C897),
                  ),
                ),
              ),
              Text(
                '和',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  SoundService.playTapSound();
                  _showAgreement('隐私政策');
                },
                child: const Text(
                  '《隐私政策》',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00C897),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建注册按钮
  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleRegister,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00C897)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C897).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '注册',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  /// 构建登录提示
  Widget _buildLoginHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '已有账号？',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        TextButton(
          onPressed: () {
            SoundService.playTapSound();
            Navigator.pop(context);
          },
          child: const Text(
            '立即登录',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF00C897),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    SoundService.playTapSound();
    
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showError('请输入正确的手机号');
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.sendCode(
      phone: phone,
      type: 'register',
    );

    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccess('验证码已发送');
      _startCountdown();
    } else {
      _showError(result.error ?? '发送失败');
    }
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() => _countdown = 60);
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// 处理注册
  Future<void> _handleRegister() async {
    SoundService.playTapSound();
    
    // 验证输入
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showError('请输入正确的手机号');
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('请输入6位验证码');
      return;
    }

    final password = _passwordController.text.trim();
    if (password.length < 6 || password.length > 20) {
      _showError('密码长度应为6-20位');
      return;
    }

    final confirmPassword = _confirmPasswordController.text.trim();
    if (password != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    if (!_agreedToTerms) {
      _showError('请阅读并同意用户协议和隐私政策');
      return;
    }

    // 执行注册
    setState(() => _isLoading = true);

    final result = await _authService.register(
      phone: phone,
      code: code,
      password: password,
      inviteCode: _inviteCodeController.text.trim().isEmpty 
          ? null 
          : _inviteCodeController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccess('注册成功');
      
      // 显示新用户礼包
      if (result.gifts.isNotEmpty) {
        await _showGifts(result.gifts);
      }
      
      // 跳转到首页
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        // 清除所有路由栈，跳转到首页
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } else {
      _showError(result.error ?? '注册失败');
    }
  }

  /// 显示协议
  void _showAgreement(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            '这里是$title的内容...\n\n'
            '实际应用中应该显示完整的协议内容。',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示新用户礼包
  Future<void> _showGifts(List<Gift> gifts) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.card_giftcard, color: Color(0xFF00C897)),
            SizedBox(width: 8),
            Text('新用户礼包'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: gifts.map((gift) {
            return ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF00C897)),
              title: Text(_getGiftTitle(gift)),
              subtitle: Text(_getGiftDescription(gift)),
            );
          }).toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C897),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('太好了'),
          ),
        ],
      ),
    );
  }

  String _getGiftTitle(Gift gift) {
    switch (gift.type) {
      case 'vip_trial':
        return 'VIP试用';
      default:
        return '神秘礼物';
    }
  }

  String _getGiftDescription(Gift gift) {
    switch (gift.type) {
      case 'vip_trial':
        return '${gift.days}天VIP会员体验';
      default:
        return '查看详情';
    }
  }

  /// 显示错误提示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 显示成功提示
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00C897),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
