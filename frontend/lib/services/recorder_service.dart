import 'package:flutter/foundation.dart';
import 'dart:io' show File;
import 'package:record/record.dart' as rec;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';

class RecorderService {
  static final rec.AudioRecorder _record = rec.AudioRecorder();
  static String? _currentFilePath;
  static bool _simulatedRecording = false;

  static Future<bool> start() async {
    if (ApiConfig.useSimulatedData) {
      _simulatedRecording = true;
      _currentFilePath = 'demo://work-english/${DateTime.now().millisecondsSinceEpoch}';
      return true;
    }
    if (kIsWeb) {
      debugPrint('Web平台录音功能暂不支持');
      return false;
    }
    
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return false;

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/pronounce_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentFilePath = filePath;

    if (await _record.hasPermission()) {
      await _record.start(
        const rec.RecordConfig(
          encoder: rec.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      return true;
    }
    return false;
  }

  static Future<String?> stop() async {
    if (_simulatedRecording) {
      _simulatedRecording = false;
      return _currentFilePath;
    }
    final path = await _record.stop();
    if (path == null) return _currentFilePath;
    return path;
  }

  static Future<bool> isRecording() async {
    if (_simulatedRecording) return true;
    return await _record.isRecording();
  }

  static Future<void> dispose() async {
    if (_simulatedRecording) {
      _simulatedRecording = false;
      return;
    }
    if (await _record.isRecording()) {
      await _record.stop();
    }
    await _record.dispose();
  }
}
