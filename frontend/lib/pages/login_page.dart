import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../utils/sound_service.dart';

/// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  
  // 表单控制器
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  
  // 登录方式：password / code
  String _loginMode = 'password';
  
  // 验证码倒计时
  int _countdown = 0;
  Timer? _countdownTimer;
  
  // 加载状态
  bool _isLoading = false;
  
  // 密码可见性
  bool _passwordVisible = false;
  
  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo和标题
                _buildHeader(),
                
                const SizedBox(height: 48),
                
                // 登录方式切换
                _buildLoginModeSwitch(),
                
                const SizedBox(height: 24),
                
                // 手机号输入
                _buildPhoneInput(),
                
                const SizedBox(height: 16),
                
                // 密码或验证码输入
                if (_loginMode == 'password')
                  _buildPasswordInput()
                else
                  _buildCodeInput(),
                
                const SizedBox(height: 16),
                
                // 忘记密码
                if (_loginMode == 'password')
                  _buildForgotPassword(),
                
                const SizedBox(height: 32),
                
                // 登录按钮
                _buildLoginButton(),
                
                const SizedBox(height: 16),
                
                // 注册提示
                _buildRegisterHint(),
                
                const SizedBox(height: 24),
                
                // 第三方登录
                _buildThirdPartyLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00C897)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C897).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 48,
              height: 48,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.school,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '猫头鹰学英语',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '智能英语学习助手',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 构建登录方式切换
  Widget _buildLoginModeSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton('密码登录', 'password'),
          ),
          Expanded(
            child: _buildModeButton('验证码登录', 'code'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String mode) {
    final isSelected = _loginMode == mode;
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        setState(() => _loginMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF00C897) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  /// 构建手机号输入
  Widget _buildPhoneInput() {
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
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        maxLength: 11,
        decoration: InputDecoration(
          hintText: '请输入手机号',
          prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF00C897)),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  /// 构建密码输入
  Widget _buildPasswordInput() {
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
        controller: _passwordController,
        obscureText: !_passwordVisible,
        decoration: InputDecoration(
          hintText: '请输入密码',
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00C897)),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade400,
            ),
            onPressed: () {
              SoundService.playTapSound();
              setState(() => _passwordVisible = !_passwordVisible);
            },
          ),
          border: InputBorder.none,
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

  /// 构建忘记密码
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          SoundService.playTapSound();
          // TODO: 跳转到忘记密码页面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('忘记密码功能开发中')),
          );
        },
        child: Text(
          '忘记密码？',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  /// 构建登录按钮
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
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
                  '登录',
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

  /// 构建注册提示
  Widget _buildRegisterHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '还没有账号？',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        TextButton(
          onPressed: () {
            SoundService.playTapSound();
            Navigator.pushNamed(context, '/register');
          },
          child: const Text(
            '立即注册',
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

  /// 构建第三方登录
  Widget _buildThirdPartyLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '其他登录方式',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildThirdPartyButton(Icons.wechat, '微信', Colors.green),
            const SizedBox(width: 24),
            _buildThirdPartyButton(Icons.apple, 'Apple', Colors.black),
          ],
        ),
      ],
    );
  }

  Widget _buildThirdPartyButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label登录功能开发中')),
        );
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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
      type: 'login',
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

  /// 处理登录
  Future<void> _handleLogin() async {
    SoundService.playTapSound();
    
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      SmartDialog.showToast('请输入正确的手机号');
      return;
    }

    if (_loginMode == 'password') {
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        SmartDialog.showToast('请输入密码');
        return;
      }

      SmartDialog.showLoading(msg: '登录中...');
      final result = await _authService.loginWithPassword(
        phone: phone,
        password: password,
      );
      SmartDialog.dismiss();

      if (result.success) {
        SmartDialog.showToast('登录成功');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/grade_select', (route) => false);
        }
      } else {
        SmartDialog.showToast(result.error ?? '登录失败');
      }
    } else {
      final code = _codeController.text.trim();
      if (code.length != 6) {
        SmartDialog.showToast('请输入6位验证码');
        return;
      }

      SmartDialog.showLoading(msg: '登录中...');
      final result = await _authService.loginWithCode(
        phone: phone,
        code: code,
      );
      SmartDialog.dismiss();

      if (result.success) {
        SmartDialog.showToast('登录成功');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/grade_select', (route) => false);
        }
      } else {
        SmartDialog.showToast(result.error ?? '登录失败');
      }
    }
  }



  /// 显示错误提示
  void _showError(String message) {
    SmartDialog.showToast(message);
  }

  /// 显示成功提示
  void _showSuccess(String message) {
    SmartDialog.showToast(message);
  }
}
