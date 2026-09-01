import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import '../services/backend_api_service.dart';
import '../utils/sound_service.dart';
import '../utils/responsive_helper.dart';

/// 帮助与反馈页面
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  String _feedbackType = 'general';
  bool _isSubmitting = false;

  final List<Map<String, String>> _types = [
    {'label': '常规建议', 'value': 'general'},
    {'label': '功能异常', 'value': 'bug'},
    {'label': '内容错误', 'value': 'content'},
    {'label': '其他', 'value': 'other'},
  ];

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      SmartDialog.showToast('请输入反馈内容');
      return;
    }

    setState(() => _isSubmitting = true);
    SmartDialog.showLoading(msg: '提交中...');

    try {
      final result = await BackendApiService.submitFeedback(
        content: content,
        contact: _contactController.text.trim(),
        feedbackType: _feedbackType,
      );

      SmartDialog.dismiss();

      if (result['code'] == 200 || result['code'] == 201) {
        SmartDialog.showToast(result['msg'] ?? '感谢您的反馈！');
        if (mounted) Navigator.pop(context);
      } else {
        SmartDialog.showToast(result['msg'] ?? '提交失败，请稍后重试');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('提交出错，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = (double size) => ResponsiveHelper.s(context, size);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('帮助与反馈', style: TextStyle(color: Color(0xFF1A535C), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A535C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('反馈类型'),
            SizedBox(height: s(12)),
            _buildTypeSelector(s),
            SizedBox(height: s(24)),
            _buildSectionTitle('反馈内容'),
            SizedBox(height: s(12)),
            _buildContentInput(s),
            SizedBox(height: s(24)),
            _buildSectionTitle('联系方式 (可选)'),
            SizedBox(height: s(12)),
            _buildContactInput(s),
            SizedBox(height: s(40)),
            _buildSubmitButton(s),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A535C),
      ),
    );
  }

  Widget _buildTypeSelector(double Function(double) s) {
    return Wrap(
      spacing: s(10),
      runSpacing: s(10),
      children: _types.map((type) {
        final isSelected = _feedbackType == type['value'];
        return GestureDetector(
          onTap: () {
            SoundService.playTapSound();
            setState(() => _feedbackType = type['value']!);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(8)),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A535C) : Colors.white,
              borderRadius: BorderRadius.circular(s(20)),
              border: Border.all(
                color: isSelected ? const Color(0xFF1A535C) : Colors.grey.shade300,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFF1A535C).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Text(
              type['label']!,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContentInput(double Function(double) s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: '请详细描述您遇到的问题或改进建议...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(s(16)),
        ),
      ),
    );
  }

  Widget _buildContactInput(double Function(double) s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(s(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _contactController,
        decoration: InputDecoration(
          hintText: '邮箱或手机号，方便我们联系您',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(12)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(double Function(double) s) {
    return SizedBox(
      width: double.infinity,
      height: s(50),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A535C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s(25)),
          ),
          elevation: 2,
        ),
        child: Text(
          _isSubmitting ? '提交中...' : '提交反馈',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
