// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/english_word_api_service.dart';
import '../utils/deepseek_api_service.dart';
import '../utils/settings_helper.dart';
import '../utils/learning_data_service.dart';
import '../utils/cache_service.dart';
import '../utils/file_helper.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';
import '../utils/performance_optimizer.dart';
import '../utils/auto_update_service.dart';
import '../utils/render_compatibility_helper.dart';
import '../utils/compatible_page_route.dart';
import '../services/auth_service.dart';
import '../main.dart';

/// 导入模式枚举
enum ImportMode {
  update,    // 数据更新：只更新学习进度更好的记录
  overwrite, // 全部覆盖：清空现有数据，完全替换
}

/// 设置页面 - 用于配置应用的基本设置
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 设置项状态
  bool _autoPlayPronunciation = true;
  String _themeMode = 'light'; // light, dark, parchment, cream
  double _fontScale = 1.0;
  bool _smartSyncEnabled = true; // 智能同步开关状态
  PronunciationType _pronunciationType = PronunciationType.uk;
  LearningMode? _learningMode; // 改为可空类型，避免默认值闪烁
  int _dailyGoalWords = 30;
  
  // 版本信息
  String _appVersion = '加载中...';
// 当前应用版本
  
  // DeepSeek API设置
  final TextEditingController _deepSeekApiKeyController = TextEditingController();
  bool _isApiKeyValid = false;
  bool _showApiKey = false;
  
  // 学习算法设置

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _deepSeekApiKeyController.addListener(_onApiKeyChanged);
  }
  
  @override
  void dispose() {
    _deepSeekApiKeyController.dispose();
    super.dispose();
  }
  
  /// API Key 变化监听
  void _onApiKeyChanged() {
    final apiKey = _deepSeekApiKeyController.text.trim();
    final isValid = apiKey.isNotEmpty && apiKey.length >= 10;
    
    if (isValid != _isApiKeyValid) {
      setState(() {
        _isApiKeyValid = isValid;
      });
      
      // 如果API Key变为无效且当前是深入学习模式，自动切换到快速学习模式
      if (!isValid && _learningMode == LearningMode.deepLearning) {
        setState(() {
          _learningMode = LearningMode.quickMemory;
        });
        _saveSettings();
        
        // 显示提示信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OptimizedText(
                    'API Key无效，已自动切换到快速学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkBackgroundColor 
              : AppTheme.backgroundColor,
          appBar: AcrylicAppBar(
            title: '设置',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                SoundService.playTapOffSound();
                Navigator.pop(context);
              },
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxContentWidth(context),
              ),
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: ResponsiveHelper.getResponsivePadding(context),
                children: [
                  // 学习设置部分
                  _buildSectionHeader('学习设置'),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      title: '自动播放发音',
                      subtitle: '显示单词时自动播放发音',
                      value: _autoPlayPronunciation,
                      onChanged: (value) {
                        setState(() {
                          _autoPlayPronunciation = value;
                        });
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '每日目标',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkPrimaryTextColor
                                  : AppTheme.darkGray,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _dailyGoalWords.toDouble(),
                                  min: 5,
                                  max: 100,
                                  divisions: 19,
                                  label: '$_dailyGoalWords',
                                  onChanged: (v) {
                                    final stepped = (v / 5).round() * 5;
                                    setState(() {
                                      _dailyGoalWords = stepped.clamp(5, 100);
                                    });
                                  },
                                  onChangeEnd: (_) => _saveSettings(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkCardColor
                                      : AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_dailyGoalWords 词',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppTheme.mediumGray
                                        : AppTheme.coolGray600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 学习模式设置部分
                  _buildSectionHeader('学习模式'),
                  if (_learningMode != null) 
                    _buildSettingsCard([
                      _buildRadioListTile<LearningMode>(
                        title: '快速记忆',
                        subtitle: '不显示造句，点击认识就进入下一个单词',
                        value: LearningMode.quickMemory,
                        groupValue: _learningMode!,
                        onChanged: (LearningMode? value) {
                          if (value != null) {
                            setState(() {
                              _learningMode = value;
                            });
                            _saveSettings();
                          }
                        },
                      ),
                      _buildRadioListTile<LearningMode>(
                        title: '深入学习',
                        subtitle: _isApiKeyValid 
                          ? '包含造句练习和AI评估功能'
                          : '需要配置DeepSeek API Key才能使用此功能',
                        value: LearningMode.deepLearning,
                        groupValue: _learningMode!,
                        onChanged: _isApiKeyValid ? (LearningMode? value) {
                          if (value != null) {
                            setState(() {
                              _learningMode = value;
                            });
                            _saveSettings();
                          }
                        } : (LearningMode? value) {
                          // API Key无效时，显示提示但不执行任何操作
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.warning_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RenderCompatibilityHelper.createCompatibleText(
                                      '请先配置有效的DeepSeek API Key',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black87
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.coolGray600
                                  : AppTheme.coolGray300,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ])
                  else
                    _buildSettingsCard([
                      ListTile(
                        leading: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        title: RenderCompatibilityHelper.createCompatibleText('正在加载学习模式设置...'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ]),
                    
                  const SizedBox(height: 16),

                  // 显示设置部分
                  _buildSectionHeader('显示设置'),
                  _buildSettingsCard([
                    _buildFontScaleTile(),
                  ]),
                    
                  const SizedBox(height: 16),

                  // 发音设置部分
                  _buildSectionHeader('发音设置'),
                  _buildSettingsCard([
                    _buildRadioListTile<PronunciationType>(
                      title: '英音',
                      subtitle: '使用英式发音和音标',
                      value: PronunciationType.uk,
                      groupValue: _pronunciationType,
                      onChanged: (PronunciationType? value) {
                        setState(() {
                          _pronunciationType = value!;
                        });
                        _saveSettings();
                      },
                    ),
                    _buildRadioListTile<PronunciationType>(
                      title: '美音',
                      subtitle: '使用美式发音和音标',
                      value: PronunciationType.us,
                      groupValue: _pronunciationType,
                      onChanged: (PronunciationType? value) {
                        setState(() {
                          _pronunciationType = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),
                  
                  // AI设置部分
                  // _buildSectionHeader('AI设置'),
                  // _buildSettingsCard([
                  //   _buildApiKeyTile(),
                  // ]),

                  const SizedBox(height: 16),

                  // 界面设置部分
                  _buildSectionHeader('界面设置'),
                  _buildSettingsCard([
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(
                        '主题模式',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkPrimaryTextColor
                              : AppTheme.darkGray,
                        ),
                      ),
                      subtitle: Text(
                        _getThemeModeLabel(_themeMode),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.mediumGray
                              : AppTheme.coolGray500,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        SoundService.playTapSound();
                        _showThemeSelector();
                      },
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 学习算法设置部分
                  _buildSectionHeader('学习算法'),
                  _buildSettingsCard([
                    _buildCompactListTile(
                      leading: const Icon(Icons.psychology_outlined),
                      title: '高级算法设置',
                      subtitle: '配置SuperMemo、Anki、自适应算法参数',
                      onTap: _openAlgorithmSettings,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 数据管理部分
                  _buildSectionHeader('数据管理'),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      title: '智能同步',
                      subtitle: '切换词书时自动继承学习记录',
                      value: _smartSyncEnabled,
                      onChanged: (value) {
                        setState(() {
                          _smartSyncEnabled = value;
                        });
                        _saveSettings();

                        // 显示状态变化提示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  value ? Icons.sync : Icons.sync_disabled,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RenderCompatibilityHelper.createCompatibleText(
                                    value ? '智能同步已开启' : '智能同步已关闭',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkCardColor
                                : AppTheme.cardColor,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: '导出学习数据',
                      subtitle: '选择目录导出当前词书的学习记录',
                      onTap: _exportLearningData,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: '导入学习数据',
                      subtitle: '选择CSV文件导入学习记录',
                      onTap: _importLearningData,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: '增强学习分析',
                      subtitle: '详细的学习历史、统计图表、算法效果分析',
                      onTap: _openWordReviewPage,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.refresh_outlined),
                      title: '重置学习进度',
                      subtitle: '清除所有学习记录',
                      onTap: _showResetDialog,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 账户部分
                  _buildSectionHeader('账户'),
                  _buildSettingsCard([
                    _buildCompactListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: '退出登录',
                      subtitle: '退出当前账号',
                      titleColor: Colors.red,
                      onTap: _handleLogout,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 关于部分
                  _buildSectionHeader('关于'),
                  _buildSettingsCard([
                    _buildCompactListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: _appVersion,
                      subtitle: '点击检查更新',
                      onTap: _checkForUpdates,
                    ),
                    _buildCompactListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: '隐私政策',
                      subtitle: '查看并了解我们如何处理您的信息',
                      onTap: () {
                        Navigator.pushNamed(context, '/privacy');
                      },
                    ),
                    // _buildCompactListTile(
                    //   leading: const Icon(Icons.feedback_outlined),
                    //   title: '意见反馈',
                    //   subtitle: '提交您发现的问题或改进建议',
                    //   onTap: _showFeedbackDialog,
                    // ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示意见反馈对话框
  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    final contactController = TextEditingController();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      padding: const EdgeInsets.all(16),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.feedback_outlined, color: AppTheme.coolGray600),
              const SizedBox(width: 10),
              Text(
                "意见反馈",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: feedbackController,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: "请在此输入您的宝贵意见或遇到的问题...",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkBackgroundColor.withOpacity(0.5)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contactController,
            decoration: InputDecoration(
              hintText: "联系方式（选填）",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkBackgroundColor.withOpacity(0.5)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.contact_mail_outlined, size: 20),
            ),
          ),
        ],
      ),
      btnCancelText: '取消',
      btnOkText: '提交',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final content = feedbackController.text.trim();
        if (content.isEmpty) {
          SmartDialog.showToast('反馈内容不能为空哦');
          return;
        }

        SmartDialog.showLoading(msg: '正在提交...');
        final success = await AuthService.instance.submitFeedback(
          content: content,
          contact: contactController.text.trim(),
        );
        SmartDialog.dismiss();
        
        if (success) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.scale,
            title: '感谢反馈',
            desc: '您的反馈已收到，我们会尽快处理。',
            btnOkText: '好的',
            btnOkOnPress: () {},
          ).show();
        } else {
          SmartDialog.showToast('提交失败，请稍后重试');
        }
      },
      buttonsTextStyle: const TextStyle(color: Colors.white),
    ).show();
  }

  /// 构建节标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6, top: 6),
      child: OptimizedText(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.primaryTextColor),
        ),
      ),
    );
  }

  /// 构建设置卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkCardColor 
          : AppTheme.cardColor,
      elevation: 0, // 移除默认阴影，使用自定义阴影
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkCardColor 
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: Theme.of(context).brightness == Brightness.dark 
              ? null 
              : [
            BoxShadow(
              color: AppTheme.coolGray200.withOpacity(0.25),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
                ],
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  /// 构建紧凑的列表项
  Widget _buildCompactListTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? (Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.mediumGray
              : AppTheme.coolGray500,
        ),
      ),
      onTap: () {
        SoundService.playTapSound();
        onTap();
      },
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: OptimizedText(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.mediumGray 
              : AppTheme.coolGray500,
        ),
      ),
      value: value,
      onChanged: (bool newValue) {
        if (newValue) {
          SoundService.playSwitchOnSound();
        } else {
          SoundService.playSwitchOffSound();
        }
        onChanged(newValue);
      },
      inactiveThumbColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkPrimaryGray
          : AppTheme.darkAccentGreen,
      inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSecondaryTextColor
          : AppTheme.darkPrimaryTextColor,
      activeTrackColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSecondaryTextColor
          : AppTheme.darkAccentGreen,
      activeColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.secondaryTextColor
          : AppTheme.secondaryTextColor,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建单选按钮设置项
  Widget _buildRadioListTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      title: OptimizedText(
        title,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.darkPrimaryTextColor
              : AppTheme.darkGray,
        ),
      ),
      subtitle: OptimizedText(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppTheme.mediumGray 
              : AppTheme.coolGray500,
        ),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: (T? newValue) {
        if (newValue != null) {
          SoundService.playChooseButtonSound();
        }
        onChanged(newValue);
      },
      activeColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkPrimaryGray 
          : AppTheme.primaryGray,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  /// 构建字体缩放设置项
  Widget _buildFontScaleTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields_outlined,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              OptimizedText(
                '整体字体缩放',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryTextColor 
                      : AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_fontScale * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7, // 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5
                  label: '${(_fontScale * 100).toInt()}%',
                  onChanged: (value) {
                    setState(() {
                      _fontScale = value;
                    });
                    // 同步到全局主题
                    ThemeProvider.of(context)?.updateFontScale(value);
                  },
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 20)),
            ],
          ),
          OptimizedText(
            '调整应用内文字的整体大小',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkSecondaryTextColor 
                  : AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }



  /// 构建API Key设置项
  Widget _buildApiKeyTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vpn_key_outlined,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              OptimizedText(
                'DeepSeek API Key',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryTextColor 
                      : AppTheme.primaryTextColor,
                ),
              ),
              if (_isApiKeyValid)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: Theme.of(context).brightness == Brightness.dark 
                        ? null 
                        : [
                            BoxShadow(
                              color: AppTheme.coolGray200.withOpacity(0.15),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                  ),
                  child: OptimizedText(
                    '已配置',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deepSeekApiKeyController,
            decoration: InputDecoration(
              hintText: '请输入DeepSeek API Key',
              hintStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppTheme.darkSecondaryTextColor 
                    : AppTheme.secondaryTextColor,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isApiKeyValid)
                    Icon(
                      Icons.check_circle_outlined,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.paste,
                      size: 20,
                    ),
                    onPressed: _pasteApiKey,
                    tooltip: '粘贴API Key',
                  ),
                  IconButton(
                    icon: Icon(
                      _showApiKey ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppTheme.darkSecondaryTextColor 
                          : AppTheme.secondaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showApiKey = !_showApiKey;
                      });
                    },
                    tooltip: _showApiKey ? '隐藏API Key' : '显示API Key',
                  ),
                ],
              ),
            ),
            style: const TextStyle(fontSize: 14),
            obscureText: !_showApiKey,
            onChanged: (_) => _saveSettings(),
          ),
          const SizedBox(height: 6),
          OptimizedText(
            '用于AI造句判断功能，请在DeepSeek官网获取API Key',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkSecondaryTextColor 
                  : AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _testApiConnection,
                icon: Icon(
                  Icons.network_check, 
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryGray 
                      : AppTheme.primaryGray,
                ),
                label: OptimizedText(
                  '测试连接',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.primaryGray,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showApiKeyHelp(),
                icon: Icon(
                  Icons.help_outline, 
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryGray 
                      : AppTheme.primaryGray,
                ),
                label: OptimizedText(
                  '获取帮助',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppTheme.darkPrimaryGray 
                        : AppTheme.primaryGray,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  /// 加载设置
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = await DeepSeekApiService.getApiKey();
    final learningMode = await SettingsHelper.getLearningMode();
    final dailyGoal = await SettingsHelper.getDailyGoalWords();
    final fontScale = await SettingsHelper.getFontScale();
    
    // 加载算法配置

    if (mounted) {
      final isApiKeyValid = apiKey != null && apiKey.isNotEmpty && apiKey.length >= 10;
      
      // 如果API Key无效且当前是深入学习模式，自动切换到快速学习模式
      LearningMode finalLearningMode = learningMode;
      if (!isApiKeyValid && learningMode == LearningMode.deepLearning) {
        finalLearningMode = LearningMode.quickMemory;
        // 保存切换后的模式
        await SettingsHelper.setLearningMode(finalLearningMode);
      }
      
      setState(() {
        _autoPlayPronunciation = prefs.getBool('auto_play_pronunciation') ?? true;
        _themeMode = prefs.getString('theme_mode') ?? 'light';
        _smartSyncEnabled = prefs.getBool('smart_sync_enabled') ?? true;
        final pronunciationTypeStr = prefs.getString('pronunciation_type') ?? 'uk';
        _pronunciationType = pronunciationTypeStr == 'us' ? PronunciationType.us : PronunciationType.uk;
        _learningMode = finalLearningMode;
        _dailyGoalWords = dailyGoal;
        _fontScale = fontScale;
        
        // 加载DeepSeek API key
        _deepSeekApiKeyController.text = apiKey ?? '';
        _isApiKeyValid = isApiKeyValid;
        
        // 加载算法配置
      });
      
      // 如果自动切换了学习模式，显示提示信息
      if (!isApiKeyValid && learningMode == LearningMode.deepLearning) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '检测到无效的API Key，已自动切换到快速学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 保存设置
  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_pronunciation', _autoPlayPronunciation);
    await prefs.setString('theme_mode', _themeMode);
    await prefs.setBool('smart_sync_enabled', _smartSyncEnabled);
    await prefs.setString('pronunciation_type', _pronunciationType.code);
    await SettingsHelper.setDailyGoalWords(_dailyGoalWords);
    
    // 只在学习模式不为null时保存，且确保API Key有效时才能保存深入学习模式
    if (_learningMode != null) {
      // 如果API Key无效且尝试保存深入学习模式，强制切换到快速学习模式
      if (!_isApiKeyValid && _learningMode == LearningMode.deepLearning) {
        setState(() {
          _learningMode = LearningMode.quickMemory;
        });
        await SettingsHelper.setLearningMode(LearningMode.quickMemory);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API Key无效，无法使用深入学习模式',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await SettingsHelper.setLearningMode(_learningMode!);
      }
    }
    
    // 保存DeepSeek API key
    final apiKey = _deepSeekApiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await DeepSeekApiService.setApiKey(apiKey);
    }
  }

  /// 显示重置对话框
  void _showResetDialog() {
    showDialog(
      
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: const Text('重置学习进度'),
        content: const Text('确定要清除所有学习记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryTextColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetProgress();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkAccentRed 
                  : AppTheme.accentRed,
              foregroundColor: Colors.white,
              elevation: 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 重置学习进度
  void _resetProgress() async {
    try {
      // 使用新的学习数据服务清除所有学习数据
      await LearningDataService.instance.clearLearningData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.refresh_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '学习进度已重置',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '重置失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// 测试API连接
  void _testApiConnection() async {
    if (!_isApiKeyValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请先输入有效的API Key',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );
    
    try {
      final isConnected = await DeepSeekApiService.testApiConnection();
      Navigator.pop(context); // 关闭加载对话框
      
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.gpp_good_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API连接成功！',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API连接失败，请检查API Key是否正确',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '测试失败: $e',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// 粘贴API Key
  void _pasteApiKey() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        setState(() {
          _deepSeekApiKeyController.text = data.text!;
        });
        _saveSettings();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ API Key已粘贴',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '❌ 剪贴板为空',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '❌ 粘贴失败: $e',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示API Key帮助
  void _showApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: const Text('如何获取DeepSeek API Key'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. 访问DeepSeek官网：'),
              SelectableText(
                'https://platform.deepseek.com',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              SizedBox(height: 8),
              Text('2. 注册并登录账户'),
              SizedBox(height: 8),
              Text('3. 进入API Keys页面'),
              SizedBox(height: 8),
              Text('4. 创建新的API Key'),
              SizedBox(height: 8),
              Text('5. 复制API Key并粘贴到此处'),
              SizedBox(height: 16),
              Text(
                '注意：请妥善保管您的API Key，不要分享给他人',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGray,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }



  /// 导出学习数据
  void _exportLearningData() async {
    try {
      // 直接选择导出目录
      final selectedDirectory = await FileHelper.selectExportDirectory();
      if (selectedDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未选择导出位置',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // 显示导出中的提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在导出数据...'),
            ],
          ),
        ),
      );

      // 获取公共单词本的CSV数据（传入null表示导出全局记录）
      final csvData = await LearningDataService.instance.getLearningDataCsv();
      
      // 生成文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '猫头鹰学英语_公共单词本_$timestamp.csv';
      
      // 保存文件到选择的目录
      final filePath = await FileHelper.saveFile(selectedDirectory, fileName, csvData);
      
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          action: SnackBarAction(
            label: '复制路径',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
            },
          ),
          content: Row(
            children: [
              Icon(
                Icons.catching_pokemon_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '公共单词本数据已导出到:\n$filePath',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '导出失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 导入学习数据
  void _importLearningData() async {
    try {
      // 直接选择CSV文件
      final selectedFile = await FileHelper.selectImportFile();
      if (selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未选择文件',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // 显示导入中的提示
    showDialog(
      context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
          content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在读取文件...'),
            ],
          ),
        ),
      );

      // 读取文件内容
      String csvData;
      if (selectedFile.bytes != null) {
        // 从内存读取，使用UTF-8解码
        csvData = utf8.decode(selectedFile.bytes!);
      } else if (selectedFile.path != null) {
        // 从文件路径读取
        csvData = await FileHelper.readFile(selectedFile.path!);
      } else {
        throw Exception('无法读取文件内容');
      }

      Navigator.of(context).pop(); // 关闭加载对话框

      // 显示文件信息并确认导入
      _showImportConfirmation(selectedFile, csvData);
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '读取文件失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 显示导入确认对话框
  void _showImportConfirmation(dynamic file, String csvData) {
    final lines = csvData.split('\n').where((line) => line.trim().isNotEmpty).length;
    final fileSize = file.bytes?.length ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardColor : AppTheme.cardColor,
        title: const Text('确认导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: ${file.name}'),
            Text('文件大小: ${FileHelper.getFileSizeString(fileSize)}'),
            Text('数据行数: $lines'),
            const SizedBox(height: 16),
            const Text('请选择导入模式：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.coolGray700
                    : AppTheme.coolGray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.update, size: 16, color: AppTheme.darkGray),
                      const SizedBox(width: 8),
                      Text(
                        '数据更新',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '只更新学习进度更好的记录，保留现有数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.coolGray700
                    : AppTheme.coolGray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.refresh, size: 16, color: AppTheme.accentGreen),
                      const SizedBox(width: 8),
                      Text(
                        '全部覆盖',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清空现有数据，完全替换为导入的数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.getSecondaryTextColor(context),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('取消'),
              ),
            ),
            SizedBox(width: 8,),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _performImport(csvData, ImportMode.update);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkGray,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                child: const Text('数据更新'),
              ),
            ),
            SizedBox(width: 8,),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _performImport(csvData, ImportMode.overwrite);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                child: const Text('全部覆盖'),
              ),
            ),],)
        ],
      ),
    );
  }

  /// 执行导入
  Future<void> _performImport(String csvData, ImportMode importMode) async {
    if (csvData.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请输入有效的CSV数据',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // 导入到公共单词本（传入null表示导入到全局记录）
      final result = await LearningDataService.instance.importLearningDataFromCsv(csvData, null, importMode);
      
      if (result.success) {
        final modeText = importMode == ImportMode.update ? '数据更新' : '全部覆盖';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已通过$modeText模式导入到公共单词本：${result.message}',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.message,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.coolGray600
                : AppTheme.coolGray300,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '导入失败: ${e.toString()}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }



  /// 打开单词回溯页面
  void _openWordReviewPage() async {
    final selectedWordBook = await CacheService.getSelectedWordBook();
    if (selectedWordBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请先选择一个词书',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.coolGray600
              : AppTheme.coolGray300,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    CompatibleNavigator.pushNamed(
      context,
      '/enhanced_word_review',
      transitionType: PageTransitionType.slideFromBottom,
    );
  }

  /// 打开算法设置页面
  void _openAlgorithmSettings() {
    CompatibleNavigator.pushNamed(
      context,
      '/algorithm_settings',
      transitionType: PageTransitionType.slideFromBottom,
    );
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _appVersion = '版本信息获取失败';
      });
    }
  }

  /// 检查应用更新
  Future<void> _checkForUpdates() async {
    // 使用自动更新服务进行手动检查
    await AutoUpdateService.instance.checkManually(context);
  }

  /// 获取主题模式标签
  String _getThemeModeLabel(String mode) {
    switch (mode) {
      case 'light':
        return '浅色模式';
      case 'dark':
        return '深色模式';
      case 'parchment':
        return '羊皮纸模式';
      case 'cream':
        return '奶油模式';
      default:
        return '浅色模式';
    }
  }

  /// 显示主题选择器
  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '选择主题',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkPrimaryTextColor
                      : AppTheme.primaryTextColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildThemeOption('light', '浅色模式', Icons.light_mode, AppTheme.backgroundColor),
            _buildThemeOption('dark', '深色模式', Icons.dark_mode, AppTheme.darkBackgroundColor),
            _buildThemeOption('parchment', '羊皮纸模式', Icons.article, AppTheme.parchmentBackgroundColor),
            _buildThemeOption('cream', '奶油模式', Icons.coffee, AppTheme.creamBackgroundColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption(String mode, String label, IconData icon, Color previewColor) {
    final isSelected = _themeMode == mode;
    
    return InkWell(
      onTap: () {
        SoundService.playTapSound();
        setState(() {
          _themeMode = mode;
        });
        _saveSettings();
        Navigator.pop(context);
        
        // 通知主应用切换主题
        // 这里需要重启应用或使用状态管理来切换主题
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到$label，重启应用后生效'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkPrimaryGray.withOpacity(0.2)
                  : AppTheme.primaryGray.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkPrimaryGray
                    : AppTheme.primaryGray)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: mode == 'dark' ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkPrimaryTextColor
                      : AppTheme.primaryTextColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkPrimaryGray
                    : AppTheme.primaryGray,
              ),
          ],
        ),
      ),
    );
  }

  /// 处理登出
  Future<void> _handleLogout() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('退出登录'),
          ],
        ),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 执行登出
      await AuthService.instance.logout();
      
      // 显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出登录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 跳转到登录页并清除所有路由
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

}
