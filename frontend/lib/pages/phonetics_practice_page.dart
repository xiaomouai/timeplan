import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import '../models/phonetic_data.dart';
import '../utils/app_theme.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';

class PhoneticsPracticePage extends StatefulWidget {
  const PhoneticsPracticePage({super.key});

  @override
  State<PhoneticsPracticePage> createState() => _PhoneticsPracticePageState();
}

class _PhoneticsPracticePageState extends State<PhoneticsPracticePage> {
  final FlutterTts _flutterTts = FlutterTts();
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  String _language = "en-GB";
  double _rate = 0.5;
  double _pitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initVideo();
  }

  Future<void> _initVideo() async {
    const videoUrl = 'https://cn-gddg-ct-01-11.bilivideo.com/upgcxcode/05/83/31018648305/31018648305-1-160.mp4?e=ig8euxZM2rNcNbRVhwdVhwdlhWdVhwdVhoNvNC8BqJIzNbfq9rVEuxTEnE8L5F6VnEsSTx0vkX8fqJeYTj_lta53NCM=&trid=000017a0e617a58746aa8ad11cb3639d49bh&deadline=1770699753&oi=1782024106&platform=html5&nbs=1&uipk=5&os=bcache&og=hw&mid=0&gen=playurlv3&upsig=3fb90edfff58d7031c7928ea6a3b87f2&uparams=e,trid,deadline,oi,platform,nbs,uipk,os,og,mid,gen&cdnid=61311&bvc=vod&nettype=0&bw=299971&agrr=0&buvid=&build=0&dl=0&f=h_0_0&orderid=0,1';
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
      });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(_language);
    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _videoController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AcrylicAppBar(
        title: '字母 & 国际音标',
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () => _flutterTts.stop(),
            tooltip: '停止播放',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_voice),
            onSelected: (String value) {
              setState(() {
                _language = value;
                _flutterTts.setLanguage(_language);
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'en-GB',
                child: Text('英式口音 (en-GB)'),
              ),
              const PopupMenuItem<String>(
                value: 'en-US',
                child: Text('美式口音 (en-US)'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoPlayer(),
            _buildControls(),
            _buildSectionTitle('26 个英文字母'),
            _buildGrid(PhoneticData.letters),
            _buildSectionTitle('48 个国际音标'),
            _buildGrid(PhoneticData.phonemes),
            _buildFooter(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_videoController),
              _VideoControls(controller: _videoController),
              VideoProgressIndicator(
                _videoController,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF00C897),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A535C).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1A535C)),
              SizedBox(width: 8),
              Text(
                '说明',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A535C),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '本页面使用语音合成技术（TTS）播放示例词。你可以调整语速和音高来听清每个音素的发音细节。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('语速', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  value: _rate,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      _rate = val;
                      _flutterTts.setSpeechRate(_rate);
                    });
                  },
                ),
              ),
              Text(_rate.toStringAsFixed(1)),
            ],
          ),
          Row(
            children: [
              const Text('音高', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (val) {
                    setState(() {
                      _pitch = val;
                      _flutterTts.setPitch(_pitch);
                    });
                  },
                ),
              ),
              Text(_pitch.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A535C),
        ),
      ),
    );
  }

  Widget _buildGrid(List<PhoneticItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildCard(items[index]);
        },
      ),
    );
  }

  Widget _buildCard(PhoneticItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Center(
              child: Text(
                item.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A535C),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.ipa,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF00C897),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.example,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00C897), size: 24),
            onPressed: () {
              SoundService.playTapSound();
              _speak(item.speakText ?? item.symbol);
            },
          ),
        ],
      ),
    );
  }
}

/// 简单的视频控制按钮组件
class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.controller.value.isPlaying ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () {
          widget.controller.value.isPlaying
              ? widget.controller.pause()
              : widget.controller.play();
        },
        child: Container(
          color: Colors.black26,
          child: Center(
            child: Icon(
              widget.controller.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
