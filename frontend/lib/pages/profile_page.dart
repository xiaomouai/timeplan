import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import '../services/backend_api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  final _nicknameController = TextEditingController();
  String? _gender;
  int? _grade;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await BackendApiService.getUserProfile();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _nicknameController.text = profile['nickname'] ?? '';
          _gender = profile['gender'];
          _grade = profile['grade'];
        });
      }
    } catch (e) {
      SmartDialog.showToast('加载用户信息失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    SmartDialog.showLoading(msg: '正在保存...');
    try {
      final success = await BackendApiService.updateUserProfile(
        nickname: _nicknameController.text,
        gender: _gender,
        grade: _grade,
      );
      
      SmartDialog.dismiss();
      if (success) {
        SmartDialog.showToast('保存成功');
        _loadProfile(); // 重新加载以获取最新数据
      } else {
        SmartDialog.showToast('保存失败');
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('保存出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        actions: [
          TextButton(
            onPressed: _updateProfile,
            child: const Text('保存', style: TextStyle(color: Color(0xFF00C897))),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 头像部分
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _userProfile?['avatar'] != null
                              ? NetworkImage(_userProfile!['avatar'])
                              : null,
                          child: _userProfile?['avatar'] == null
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00C897),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 信息列表
                  _buildInfoItem(
                    label: '昵称',
                    content: TextField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '请输入昵称',
                      ),
                    ),
                  ),
                  _buildInfoItem(
                    label: '性别',
                    content: DropdownButton<String>(
                      value: _gender,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('男')),
                        DropdownMenuItem(value: 'female', child: Text('女')),
                        DropdownMenuItem(value: 'unknown', child: Text('保密')),
                      ],
                      onChanged: (value) {
                        setState(() => _gender = value);
                      },
                    ),
                  ),
                  _buildInfoItem(
                    label: '年级',
                    content: DropdownButton<int>(
                      value: _grade,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: List.generate(12, (index) => index + 1).map((g) {
                        String gradeName = '';
                        if (g <= 6) gradeName = '小学$g年级';
                        else if (g <= 9) gradeName = '初中${g-6}年级';
                        else gradeName = '高中${g-9}年级';
                        return DropdownMenuItem(value: g, child: Text(gradeName));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _grade = value);
                      },
                    ),
                  ),
                  _buildInfoItem(
                    label: '手机号',
                    content: Text(
                      _userProfile?['phone'] ?? '未绑定',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 统计信息展示
                  if (_userProfile?['statistics'] != null) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('学习统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('已学单词', _userProfile!['statistics']['learned_count'].toString()),
                        _buildStatItem('坚持天数', _userProfile!['streak_days'].toString()),
                        _buildStatItem('我的积分', _userProfile!['points'].toString()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem({required String label, required Widget content}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00C897))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
