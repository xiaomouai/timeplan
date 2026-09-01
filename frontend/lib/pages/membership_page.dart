import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../utils/sound_service.dart';
import '../services/membership_service.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 会员开通/激活页面
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  final TextEditingController _activationCodeController = TextEditingController();
  List<MembershipPlan> _plans = [];
  bool _isLoading = true;
  int _selectedPlanIndex = 1; // 默认选中AI智能会员
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadMembershipPlans();
  }

  Future<void> _loadMembershipPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plans = await MembershipService.instance.getMembershipPlans();
      // 过滤掉免费版
      final paidPlans = plans.where((p) => p.id != 'free').toList();
      
      // 默认选中一年套餐
      int defaultIndex = 1; // 默认选中第二个
      for (int i = 0; i < paidPlans.length; i++) {
        if (paidPlans[i].name.contains('年') || paidPlans[i].id.contains('year')) {
          defaultIndex = i;
          break;
        }
      }

      setState(() {
        _plans = paidPlans;
        _selectedPlanIndex = defaultIndex;
        _isLoading = false;
      });
    } catch (e) {
      print('加载会员套餐失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A535C), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '开通会员',
          style: TextStyle(
            color: Color(0xFF1A535C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部横幅
                _buildTopBanner(),
                const SizedBox(height: 24),
                
                // 会员套餐选择
                const Text(
                  '选择套餐',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A535C),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 套餐卡片列表
                _buildPlanCards(),
                
                const SizedBox(height: 32),
                
                // 立即购买按钮
                _buildPurchaseButton(),
                
                const SizedBox(height: 24),
                
                // 激活码兑换区
                const Text(
                  '激活码兑换',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A535C),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActivationCodeInput(),
                
                const SizedBox(height: 32),
                
                // 购买须知
                _buildPurchaseNotes(),
              ],
            ),
          ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber.shade300, size: 32),
              const SizedBox(width: 12),
              const Text(
                '猫头鹰词典会员',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '智能学习 · 高效记忆 · 轻松提分',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🎉 新用户专享优惠',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCards() {
    if (_plans.isEmpty) {
      return const Center(
        child: Text('暂无套餐信息'),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          final isSelected = index == _selectedPlanIndex;
          
          return Padding(
            padding: EdgeInsets.only(
              right: 12,
              left: index == 0 ? 0 : 0,
            ),
            child: _buildPlanCard(plan, index, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(MembershipPlan plan, int index, bool isSelected) {
    Color borderColor = isSelected ? const Color(0xFF88D8C0) : Colors.grey.shade200;
    Color bgColor = isSelected ? const Color(0xFF88D8C0).withOpacity(0.05) : Colors.white;
    
    Color accentColor = const Color(0xFF1A535C);
    if (isSelected) {
      accentColor = const Color(0xFF88D8C0);
    }

    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (plan.tag != null && plan.tag!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  plan.tag!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF1A535C) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF1A535C) : Colors.grey.shade800,
                  ),
                ),
                Text(
                  '${plan.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF1A535C) : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.duration,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            if (plan.originalPrice > plan.price)
              Text(
                '¥${plan.originalPrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    if (_plans.isEmpty) return const SizedBox.shrink();
    
    final selectedPlan = _plans[_selectedPlanIndex];
    
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isPurchasing ? null : () {
          SoundService.playTapSound();
          _handlePurchase(selectedPlan);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF88D8C0),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isPurchasing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '立即开通 ${selectedPlan.name} ¥${selectedPlan.price}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildActivationCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _activationCodeController,
        decoration: InputDecoration(
          hintText: '请输入激活码',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
          suffixIcon: TextButton(
            onPressed: () {
              SoundService.playTapSound();
              _handleActivation();
            },
            child: const Text(
              '立即兑换',
              style: TextStyle(
                color: Color(0xFF88D8C0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseNotes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '购买须知',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          _buildNoteItem('1. 会员服务一经开通，不支持退款；'),
          _buildNoteItem('2. 激活码仅限单次使用，请妥善保管；'),
          _buildNoteItem('3. 会员权益仅限本账号使用，不可转让；'),
          _buildNoteItem('4. 如有任何疑问，请联系在线客服。'),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          height: 1.5,
        ),
      ),
    );
  }

  void _handlePurchase(MembershipPlan plan) {
    if (_isPurchasing) return;
    final uid = AuthService.instance.userId;
    if (uid == null || uid.isEmpty) {
      SmartDialog.showToast('请先登录');
      return;
    }

    SmartDialog.showLoading(msg: '创建订单中...');
    
    Future(() async {
      final order = await MembershipService.instance.createOrder(planId: plan.id, userId: uid);
      SmartDialog.dismiss();

      if (order == null || order.payUrl.isEmpty) {
        SmartDialog.showToast('创建订单失败');
        return;
      }

      try {
        final uri = Uri.parse(order.payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      SmartDialog.showLoading(msg: '等待支付确认...');
      
      bool paid = false;
      for (int i = 0; i < 60; i++) {
        paid = await MembershipService.instance.queryOrderPaid(order.orderId);
        if (paid) break;
        await Future.delayed(const Duration(seconds: 2));
      }
      
      SmartDialog.dismiss();

      if (mounted) {
        if (paid) {
          await MembershipService.instance.getMembershipStatus(forceRefresh: true);
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.scale,
            title: '支付成功',
            desc: '您已开通：${plan.name}',
            btnOkText: '确定',
            btnOkOnPress: () {},
          ).show();
        } else {
          SmartDialog.showToast('未检测到支付成功');
        }
      }
    });
  }

  Future<void> _handleActivation() async {
    final code = _activationCodeController.text.trim();
    if (code.isEmpty) {
      SmartDialog.showToast('请输入激活码');
      return;
    }

    SmartDialog.showLoading(msg: '激活中...');
    final result = await MembershipService.instance.activateWithCode(code);
    SmartDialog.dismiss();

    if (result.success) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.scale,
        title: '激活成功',
        desc: '恭喜您，已成功激活会员权益！',
        btnOkText: '太棒了',
        btnOkOnPress: () {
          Navigator.pop(context, true);
        },
      ).show();
    } else {
      SmartDialog.showToast(result.message);
    }
  }
}
