import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../services/checkin_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  final CheckinService _checkinService = CheckinService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _pageData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _checkinService.getCheckinPageData();
    if (result['success']) {
      setState(() {
        _pageData = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckin() async {
    SmartDialog.showLoading(msg: '签到中...');
    final result = await _checkinService.doCheckin();
    SmartDialog.dismiss();
    
    if (result['success']) {
      // 签到成功，显示奖励弹窗并重新加载数据
      final data = result['data'];
      _showCheckinSuccessDialog(data);
      _loadData();
    } else {
      SmartDialog.showToast(result['message'] ?? '签到失败');
    }
  }

  void _showCheckinSuccessDialog(Map<String, dynamic> data) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      headerAnimationLoop: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '签到成功',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('🎉', style: TextStyle(fontSize: 50)),
          const SizedBox(height: 16),
          Text('连续签到 ${data['streak_days']} 天', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('获得积分: +${data['total_earned']}'),
          if (data['level_up'] == true) ...[
            const SizedBox(height: 16),
            const Text('恭喜升级！', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            Text('当前等级: LV.${data['new_level']}'),
          ],
          if ((data['rewards_earned'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('获得额外奖励:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...(data['rewards_earned'] as List).map((r) => Text('🎁 ${r['reward_name']}')),
          ],
          const SizedBox(height: 20),
        ],
      ),
      btnOkText: '太棒了',
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('每日签到'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading && _pageData == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      ElevatedButton(onPressed: _loadData, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _pageData!;
    final levelInfo = data['level_info'];
    final isChecked = data['is_checked_today'] ?? false;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户与等级信息卡片
            _buildLevelCard(data, levelInfo),
            const SizedBox(height: 20),
            
            // 签到按钮
            Center(
              child: ElevatedButton(
                onPressed: isChecked ? null : _handleCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isChecked ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(isChecked ? '今日已签到' : '立即签到', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // 签到日历
            const Text('签到日历', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCalendar(data['calendar_days']),
            const SizedBox(height: 20),

            // 连续签到奖励
            const Text('连续签到奖励', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildRewards(data['consecutive_rewards']),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> data, Map<String, dynamic> levelInfo) {
    final Color levelColor = _parseColor(levelInfo['color']);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: data['avatar'] != null ? NetworkImage(data['avatar']) : null,
                  child: data['avatar'] == null ? const Icon(Icons.person, size: 30) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['nickname'] ?? '用户', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: levelColor),
                            ),
                            child: Text(
                              '${levelInfo['icon']} ${levelInfo['level_name']}',
                              style: TextStyle(color: levelColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('积分: ${data['points']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LV.${levelInfo['level']}', style: const TextStyle(fontSize: 12)),
                Text('LV.${(levelInfo['level'] as int) + 1}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (levelInfo['progress'] as num).toDouble(),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '当前已连续签到 ${data['streak_days']} 天，累计 ${data['total_checkin_days']} 天',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(List<dynamic> days) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final date = DateTime.parse(day['date']);
            final isChecked = day['is_checked'] ?? false;
            final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());

            return Container(
              decoration: BoxDecoration(
                color: isChecked ? Colors.blue.withOpacity(0.1) : (isToday ? Colors.orange.withOpacity(0.1) : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: isChecked 
                  ? Border.all(color: Colors.blue) 
                  : (isToday ? Border.all(color: Colors.orange) : null),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${date.day}', style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isChecked ? Colors.blue : (isToday ? Colors.orange : Colors.black),
                  )),
                  if (isChecked) const Icon(Icons.check_circle, size: 14, color: Colors.blue),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRewards(List<dynamic> rewards) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rewards.length,
        itemBuilder: (context, index) {
          final reward = rewards[index];
          final bool isClaimed = reward['is_claimed'] ?? false;
          final bool isCurrent = reward['is_current_target'] ?? false;

          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.blue.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCurrent ? Colors.blue : Colors.grey[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${reward['reward_icon']}', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text('${reward['consecutive_days']}天', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  isClaimed ? '已领取' : '+${reward['reward_value']}',
                  style: TextStyle(fontSize: 10, color: isClaimed ? Colors.green : Colors.orange),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}
