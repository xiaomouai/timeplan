import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';

/// 更新提示对话框
class UpdateDialog extends StatelessWidget {
  final UpdateCheckResult updateResult;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.updateResult,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final updateInfo = updateResult.updateInfo;
    if (updateInfo == null) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C897).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.system_update,
              color: Color(0xFF00C897),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '发现新版本',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前版本',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updateResult.currentVersion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '最新版本',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updateInfo.version,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C897),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 更新内容
            const Text(
              '更新内容',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...updateInfo.changelog.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            
            // 文件大小和发布日期
            Row(
              children: [
                Icon(Icons.file_download, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  updateInfo.fileSize,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  updateInfo.releaseDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            // 强制更新提示
            if (updateResult.forceUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '此版本为强制更新，请立即更新',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 稍后更新按钮（非强制更新时显示）
        if (!updateResult.forceUpdate)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onLater?.call();
            },
            child: Text(
              '稍后',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        
        // 立即更新按钮
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _launchUpdate(context, updateInfo.downloadUrl);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C897),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('立即更新'),
        ),
      ],
    );
  }

  /// 启动更新下载
  Future<void> _launchUpdate(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开下载链接失败: $e')),
        );
      }
    }
  }

  /// 显示更新对话框
  static Future<void> show(
    BuildContext context,
    UpdateCheckResult updateResult, {
    VoidCallback? onLater,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: !updateResult.forceUpdate,
      builder: (context) => UpdateDialog(
        updateResult: updateResult,
        onLater: onLater,
      ),
    );
  }
}

/// 兼容性警告对话框
class CompatibilityDialog extends StatelessWidget {
  final CompatibilityResult result;

  const CompatibilityDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning,
              color: Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '版本兼容性提示',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildInfoRow('应用版本', result.appVersion),
                const Divider(height: 16),
                _buildInfoRow('API版本', result.apiVersion),
                const Divider(height: 16),
                _buildInfoRow('最低要求', result.minAppVersion),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('我知道了'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 显示兼容性对话框
  static Future<void> show(
    BuildContext context,
    CompatibilityResult result,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => CompatibilityDialog(result: result),
    );
  }
}
