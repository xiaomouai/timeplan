import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_theme.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';

/// 音标课程详情页面
class PhoneticCoursePage extends StatefulWidget {
  final String title;
  final String type; // 'fun' 或 'international' 或 'custom'
  final String? videoUrl;

  const PhoneticCoursePage({
    super.key,
    required this.title,
    required this.type,
    this.videoUrl,
  });

  @override
  State<PhoneticCoursePage> createState() => _PhoneticCoursePageState();
}

class _PhoneticCoursePageState extends State<PhoneticCoursePage> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  
  // 模拟音标数据
  final List<Map<String, String>> _phonetics = [
    {'symbol': '[i:]', 'name': '长元音', 'example': 'see', 'desc': '舌尖抵下齿，舌前部尽量抬高，嘴唇扁平。'},
    {'symbol': '[ɪ]', 'name': '短元音', 'example': 'sit', 'desc': '舌前部抬高，舌尖抵下齿，嘴唇稍扁。'},
    {'symbol': '[e]', 'name': '短元音', 'example': 'egg', 'desc': '舌尖抵下齿，舌前部稍抬高，嘴形扁平。'},
    {'symbol': '[æ]', 'name': '短元音', 'example': 'cat', 'desc': '舌尖抵下齿，嘴张大，舌前部向硬腭抬起。'},
    {'symbol': '[ɑ:]', 'name': '长元音', 'example': 'arm', 'desc': '口张大，舌身平放，舌尖不抵下齿。'},
    {'symbol': '[ɒ]', 'name': '短元音', 'example': 'hot', 'desc': '口张大，舌身向后缩，舌根稍抬起。'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    // 获取视频 URL
    String videoUrl = widget.videoUrl ?? '';
    
    if (videoUrl.isEmpty) {
      videoUrl = widget.type == 'fun' 
          ? 'https://cn-gddg-ct-01-11.bilivideo.com/upgcxcode/43/23/31018582343/31018582343-1-192.mp4?e=ig8euxZM2rNcNbRVhwdVhwdlhWdVhwdVhoNvNC8BqJIzNbfq9rVEuxTEnE8L5F6VnEsSTx0vkX8fqJeYTj_lta53NCM=&nbs=1&trid=0000d23c1d8ebbdc46f681d4c822e8d4f59h&og=ali&oi=2672555743&deadline=1770699807&uipk=5&platform=html5&mid=0&gen=playurlv3&os=bcache&upsig=75b8d06153f861ddbeebc6bc7b9fc202&uparams=e,nbs,trid,og,oi,deadline,uipk,platform,mid,gen,os&cdnid=61311&bvc=vod&nettype=0&bw=238936&dl=0&f=h_0_0&agrr=0&buvid=&build=0&orderid=0,1' 
          : 'https://cn-gddg-ct-01-11.bilivideo.com/upgcxcode/43/23/31018582343/31018582343-1-192.mp4?e=ig8euxZM2rNcNbRVhwdVhwdlhWdVhwdVhoNvNC8BqJIzNbfq9rVEuxTEnE8L5F6VnEsSTx0vkX8fqJeYTj_lta53NCM=&nbs=1&trid=0000d23c1d8ebbdc46f681d4c822e8d4f59h&og=ali&oi=2672555743&deadline=1770699807&uipk=5&platform=html5&mid=0&gen=playurlv3&os=bcache&upsig=75b8d06153f861ddbeebc6bc7b9fc202&uparams=e,nbs,trid,og,oi,deadline,uipk,platform,mid,gen,os&cdnid=61311&bvc=vod&nettype=0&bw=238936&dl=0&f=h_0_0&agrr=0&buvid=&build=0&orderid=0,1';
    }
        
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AcrylicAppBar(
        title: widget.title,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频播放区域
            _buildVideoPlayer(),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '音标列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 音标列表网格
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _phonetics.length,
                    itemBuilder: (context, index) {
                      final phonetic = _phonetics[index];
                      return _buildPhoneticCard(phonetic);
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 课程说明
                  _buildCourseIntro(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _isInitialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_videoController),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _videoController.value.isPlaying
                            ? _videoController.pause()
                            : _videoController.play();
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Icon(
                          _videoController.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white.withOpacity(0.7),
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: VideoProgressIndicator(
                      _videoController,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Theme.of(context).primaryColor,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }

  Widget _buildPhoneticCard(Map<String, String> phonetic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        SoundService.playTapSound();
        _showPhoneticDetail(phonetic);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              phonetic['symbol']!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phonetic['name']!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                phonetic['example']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '课程简介',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.type == 'fun'
                ? '通过趣味动画教学，让孩子们在轻松愉快的氛围中掌握音标发音规则，打好英语学习的基础。'
                : '由资深外教亲自演示，清晰展现发音时的口型变化，帮助学习者纠正发音错误，说出地道英语。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhoneticDetail(Map<String, String> phonetic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phonetic['symbol']!,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        phonetic['name']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      // 这里可以添加播放音标发音的逻辑
                      SoundService.playTapSound();
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '发音要领',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phonetic['desc']!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    '代表单词：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    phonetic['example']!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
