// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async';
import '../models/word_book.dart';
import '../utils/cache_service.dart';
import '../utils/learning_data_service.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/performance_optimizer.dart';
import '../utils/sound_service.dart';
import '../widgets/acrylic_app_bar.dart';
import '../services/backend_api_service.dart';
import '../services/echo_type_wordbook_service.dart';
import '../config/api_config.dart';

/// 词库状态枚举
enum WordBookStatus {
  notDownloaded,  // 未下载
  downloading,    // 下载中
  downloaded,     // 已下载
  selected,       // 已选择（当前使用中）
  error,         // 下载错误
}

/// 词库项，包含状态信息和动画控制器
class WordBookItem {
  WordBook wordBook;
  WordBookStatus status;
  List<WordData>? wordData;
  String? errorMessage;
  
  // 独立的动画控制器
  AnimationController? animationController;
  Animation<double>? fadeAnimation;
  Animation<Offset>? slideAnimation;

  WordBookItem({
    required this.wordBook,
    this.status = WordBookStatus.notDownloaded,
    this.wordData,
    this.errorMessage,
  });
  
  /// 初始化动画
  void initializeAnimation(TickerProvider vsync) {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    );
    
    // 透明度动画 - 使用贝塞尔曲线
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0), // 贝塞尔曲线
    ));
    
    // 向上滑动动画 - 减少滑动距离，使用贝塞尔曲线
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15), // 减少移动距离
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0), // 贝塞尔曲线
    ));
  }
  
  /// 启动动画
  void startAnimation({Duration delay = Duration.zero}) {
    if (animationController != null) {
      Timer(delay, () {
        animationController!.forward();
      });
    }
  }
  
  /// 销毁动画控制器
  void dispose() {
    animationController?.dispose();
  }
  
  /// 更新单词数量
  void updateWordCount(int count) {
    wordBook = WordBook(
      id: wordBook.id,
      name: wordBook.name,
      translationUrl: wordBook.translationUrl,
      wordCount: count,
      coverUrl: wordBook.coverUrl,
    );
  }
}

/// 词库选择页面
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> 
    with TickerProviderStateMixin {
  
  // 性能优化：使用池化的key
  static const String _animationPoolKey = 'library_page_animations';
  static const String _timerPoolKey = 'library_page_timers';
  
  // 词库数据
  List<WordBookItem> _allWordBookItems = [];
  List<WordBookItem> _filteredWordBookItems = [];
  
  // 分页控制
  static const int _pageSize = 20;
  int _currentPage = 0;
  final List<WordBookItem> _displayedItems = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  
  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;
  
  // 分类相关
  String _selectedCategory = '全部';
  List<String> _categories = ['全部']; // 初始只有"全部"，从API动态加载
  bool _isCategoriesLoading = true;
  
  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;
  
  // 主动画控制器
  late AnimationController _fadeController;
  
  // 添加选中的词库索引

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCategories(); // 先加载分类
    _loadWordBooks();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    
    // 使用性能优化器清理资源
    PerformanceOptimizer.cancelTimers(_timerPoolKey);
    PerformanceOptimizer.disposeAnimationControllers(_animationPoolKey);
    
    // 销毁所有词库卡片的动画控制器
    for (var item in _allWordBookItems) {
      item.dispose();
    }
    
    super.dispose();
  }
  
  /// 初始化动画控制器
  void _initializeAnimations() {
    _fadeController = PerformanceOptimizer.getAnimationController(
      poolKey: _animationPoolKey,
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }
  
  /// 加载分类列表 - 从后端 API 获取
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isCategoriesLoading = true;
      });
      
      // 从后端 API 获取分类
      final categories = await BackendApiService.getCategories();
      
      setState(() {
        _categories = categories;
        _isCategoriesLoading = false;
      });
      
      print('✅ 成功加载 ${categories.length} 个分类');
    } catch (e) {
      print('⚠️ 加载分类失败，使用默认分类: $e');
      setState(() {
        // 使用默认分类作为降级方案
        _categories = [
          '全部',
          '四级',
          '六级',
          '考研',
          '专四',
          '专八',
          'IELTS',
          'TOEFL',
          'GRE',
          'GMAT',
          'SAT',
          'BEC',
          '小学',
          '初中',
          '高中',
        ];
        _isCategoriesLoading = false;
      });
    }
  }
  
  /// 滚动监听 - 实现无限滚动
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }
  
  /// 加载词库数据 - 支持缓存
  Future<void> _loadWordBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      List<WordBook> wordBooks = [];
      
      // 优先从后端API获取最新词库列表
      try {
        final booksData = await BackendApiService.getBooks();
        wordBooks = booksData.map((data) => WordBook.fromJson(data)).toList();
        
        // 更新缓存
        if (wordBooks.isNotEmpty) {
          await CacheService.cacheWordBooks(wordBooks);
        }
      } catch (e) {
        print('Error fetching books from API: $e');
        // API失败时尝试从缓存加载
        wordBooks = await CacheService.getCachedWordBooks();
      }

      final localWordBooks = EchoTypeWordBookService.definitions
          .map((book) => WordBook(
                id: 'echo-type:${book.id}',
                name: book.name,
                translationUrl: book.assetPath,
                wordCount: book.itemCount,
              ))
          .toList(growable: false);
      wordBooks = [
        ...localWordBooks,
        ...wordBooks.where((book) => !localWordBooks.any((local) => local.id == book.id)),
      ];
      await CacheService.cacheWordBooks(wordBooks);

      // 转换为WordBookItem并初始化动画
      final wordBookItems = await Future.wait(
        wordBooks.map((book) async {
          final item = WordBookItem(
            wordBook: book,
            status: WordBookStatus.notDownloaded,
          );
          
          // 检查是否已下载
          final isDownloaded = await CacheService.isWordBookDownloaded(book.name);
          if (isDownloaded) {
            final cachedWordData = await CacheService.getCachedWordData(book.name);
            if (cachedWordData != null) {
              item.wordData = cachedWordData;
              item.status = WordBookStatus.downloaded;
              item.updateWordCount(cachedWordData.length);
            }
          }
          
          // 检查是否已选中
          final selectedWordBook = await CacheService.getSelectedWordBook();
          if (selectedWordBook?.trim() == book.name.trim()) {
            item.status = WordBookStatus.selected;
          }
          
          item.initializeAnimation(this);
          return item;
        }),
      );
      
      setState(() {
        _allWordBookItems = wordBookItems;
        _filteredWordBookItems = wordBookItems;
        _isLoading = false;
        _currentPage = 0;
      });
      
      // 启动主动画
      _fadeController.forward();
      
      // 延迟加载第一页数据，让搜索栏先显示
      await Future.delayed(const Duration(milliseconds: 300));
      _loadMoreItems();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '词书走丢了：$e';
      });
    }
  }
  
  /// 加载更多项目 - 分页加载并启动独立动画
  void _loadMoreItems() {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // 模拟网络延迟
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      final startIndex = _currentPage * _pageSize;
      final endIndex = (startIndex + _pageSize).clamp(0, _filteredWordBookItems.length);
      
      if (startIndex < _filteredWordBookItems.length) {
        final newItems = _filteredWordBookItems.sublist(startIndex, endIndex);
        
        setState(() {
          _displayedItems.addAll(newItems);
          _currentPage++;
          _isLoadingMore = false;
          _isSearching = false;
        });
        
        // 为新添加的卡片启动流水般的独立动画
        for (int i = 0; i < newItems.length; i++) {
          final item = newItems[i];
          final delay = Duration(milliseconds: i * 80);
          item.startAnimation(delay: delay);
        }
      } else {
        setState(() {
          _isLoadingMore = false;
          _isSearching = false;
        });
      }
    });
  }
  
  /// 搜索词库
  void _onSearchChanged() {
    // 取消之前的搜索定时器
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    // 使用性能优化器创建防抖定时器
    _searchDebounce = PerformanceOptimizer.createTimer(
      poolKey: _timerPoolKey,
      duration: const Duration(milliseconds: 300),
      callback: () {
        final query = _searchController.text.toLowerCase().trim();
        final category = _selectedCategory;
        
        setState(() {
          _isSearching = true;
          
          _filteredWordBookItems = _allWordBookItems.where((item) {
            // 1. 搜索词过滤
            final matchesSearch = query.isEmpty || 
                item.wordBook.name.toLowerCase().contains(query);
            
            // 2. 分类过滤
            bool matchesCategory = true;
            if (category != '全部') {
              matchesCategory = item.wordBook.name.contains(category);
            }
            
            return matchesSearch && matchesCategory;
          }).toList();
          
          // 重置分页和动画状态
          _currentPage = 0;
          _displayedItems.clear();
          
          // 重置所有动画控制器
          for (var item in _allWordBookItems) {
            item.animationController?.reset();
          }
        });
        
        // 重新加载第一页
        _loadMoreItems();
      },
    );
  }

  /// 选择词库 - 支持缓存
  Future<void> _selectWordBook(WordBookItem item) async {
    // 如果还未下载，先下载词库内容
    if (item.status == WordBookStatus.notDownloaded) {
      await _downloadWordBook(item);
    }
    
    if (item.status == WordBookStatus.downloaded || item.status == WordBookStatus.selected) {
      setState(() {
        // 取消之前选中的词库，但保持已下载状态
        for (var i = 0; i < _allWordBookItems.length; i++) {
          if (_allWordBookItems[i].status == WordBookStatus.selected) {
            _allWordBookItems[i].status = WordBookStatus.downloaded;
          }
        }
        
        // 设置当前词库为选中状态
        item.status = WordBookStatus.selected;
      });
      
      // 保存选中的词库到缓存
      await CacheService.saveSelectedWordBook(item.wordBook.name, item.wordBook.id);
      
      // 自动同步词书数据
      await LearningDataService.instance.autoSyncWordBook(item.wordBook.name);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '词库《${item.wordBook.name}》已选择',
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
      

    } else if (item.status == WordBookStatus.error) {
      // 显示错误信息并提供重试选项
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('下载失败'),
          content: Text('词库下载失败：${item.errorMessage ?? "未知错误"}\n\n是否重试？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '取消',
                style: TextStyle(color: AppTheme.coolGray500),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
      
      if (retry == true) {
        await _downloadWordBook(item);
      }
    }
  }
  
  /// 下载词库内容 - 支持缓存
  Future<void> _downloadWordBook(WordBookItem item) async {
    setState(() {
      item.status = WordBookStatus.downloading;
      item.errorMessage = null;
    });
    
    try {

      // 本地 EchoType 词库无需网络，直接读取应用资产。
      List<WordData> wordData;
      List<WordData> loadedData = [];

      if (item.wordBook.isEchoType && item.wordBook.echoTypeId != null) {
        final entries = await EchoTypeWordBookService.load(item.wordBook.echoTypeId!);
        loadedData = EchoTypeWordBookService.toWordData(item.wordBook.echoTypeId!, entries);
      } else {
        try {
          if (item.wordBook.id.isNotEmpty) {
            loadedData = await BackendApiService.getBookWords(item.wordBook.id);
          }
        } catch (e) {
          print('API download failed: $e');
        }
      }
      
      if (loadedData.isNotEmpty) {
        // API获取成功，更新缓存
        await CacheService.cacheWordData(item.wordBook.name, loadedData);
        wordData = loadedData;
      } else {
        // API失败或为空，尝试从缓存加载
        final cachedWordData = await CacheService.getCachedWordData(item.wordBook.name);
        if (cachedWordData != null) {
          wordData = cachedWordData;
        } else {
          throw Exception('无法获取单词数据，请检查网络连接');
        }
      }
      
      setState(() {
        item.wordData = wordData;
        item.status = WordBookStatus.downloaded;
        item.updateWordCount(wordData.length);
      });

      // 播放下载成功音效
      SoundService.playDownloadSuccessSound();
      

    } catch (e) {
      setState(() {
        item.status = WordBookStatus.error;
        item.errorMessage = e.toString();
      });
      
    }
  }

  /// 查看已下载词库 - 修复黑色遮罩问题
  void _showDownloadedBooks() {
    final downloadedBooks = _allWordBookItems
        .where((item) => item.status == WordBookStatus.downloaded || 
                        item.status == WordBookStatus.selected)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black54, // 使用正确的遮罩颜色
      builder: (context) => GestureDetector(
        // 点击空白区域关闭
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent, // 透明容器，用于接收点击事件
          child: GestureDetector(
            // 阻止点击内容区域时关闭
            onTap: () {},
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.darkBackgroundColor
                  : AppTheme.backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: Theme.of(context).brightness == Brightness.dark 
                      ? null 
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                      margin: EdgeInsets.symmetric(vertical: 10), // 从12减少到10
                      width: 36, // 从40减少到36
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.coolGray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 标题
                Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6), // 从8减少到6
                  child: Row(
                    children: [
                      OptimizedText(
                        '我的词书收藏',
                        style: TextStyle(
                              fontSize: 18, // 从20减少到18
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkPrimaryTextColor
                              : AppTheme.primaryTextColor,
                        ),
                      ),
                      Spacer(),
                      OptimizedText(
                        '${downloadedBooks.length} 个',
                        style: TextStyle(
                              fontSize: 14, // 从16减少到14
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkSecondaryTextColor
                              : AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                    SizedBox(height: 8,),
                
                    // 分割线 - 类似指示器的圆角样式
                    Container(
                      margin: EdgeInsets.fromLTRB(20,8,20,0),
                      height: 2,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.coolGray300.withOpacity(0.3)
                            : AppTheme.coolGray300.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(0.5),
                      ),
                    ),
                
                // 词库列表
                Expanded(
                  child: downloadedBooks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.download_outlined,
                                size: 52, // 从64减少到52
                                color: AppTheme.coolGray300,
                              ),
                              SizedBox(height: 12), // 从16减少到12
                              Text(
                                '暂无已下载的词库',
                                style: TextStyle(
                                  color: AppTheme.coolGray500,
                                  fontSize: 14, // 从16减少到14
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 从20减少到16，添加垂直padding
                          itemCount: downloadedBooks.length,
                          itemBuilder: (context, index) => _buildDownloadedBookCard(
                            downloadedBooks[index],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      )
    );
  }

  /// 构建已下载词库卡片
  Widget _buildDownloadedBookCard(WordBookItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10), // 从12减少到10
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(14), // 从16减少到14
        border: Border.all(
          color: item.status == WordBookStatus.selected ? AppTheme.accentGreen : Colors.transparent, 
          width: 2
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04), // 从0.05减少到0.04
                  blurRadius: 6, // 从8减少到6
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(14), // 从16减少到14
        dense: true, // 启用紧凑模式
        leading: Container(
          width: 44, // 从48减少到44
          height: 44, // 从48减少到44
          decoration: BoxDecoration(
            color: Color(item.wordBook.coverColor),
            borderRadius: BorderRadius.circular(10), // 从12减少到10
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: Color(item.wordBook.iconColor),
            size: 22, // 从24减少到22
          ),
        ),
        title: OptimizedText(
          item.wordBook.name,
          style: TextStyle(
            fontSize: 15, // 从16减少到15
            fontWeight: FontWeight.w600,
            color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.primaryTextColor),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: OptimizedText(
          '${item.wordBook.wordCount} 个单词',
          style: TextStyle(
            fontSize: 13, // 从14减少到13
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.darkSecondaryTextColor 
                : AppTheme.secondaryTextColor,
          ),
        ),
        trailing: item.status == WordBookStatus.selected
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 从12,6减少到10,4
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16), // 从20减少到16
                ),
                child: Text(
                  '使用中',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkPrimaryTextColor
                        : AppTheme.darkGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : GestureDetector(
                onTap: () {
                  SoundService.playChooseBookSound();
                  Navigator.pop(context);
                  _selectWordBook(item);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '选择',
                    style: TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        if (ResponsiveHelper.shouldUseSideNavigation(context)) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  /// 构建手机端布局
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// 构建平板端布局
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? AppTheme.darkBackgroundColor 
          : AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxContentWidth(context),
          ),
          child: _buildBody(),
        ),
      ),
    );
  }
  
  /// 构建应用栏 - 添加查看已下载按钮
  PreferredSizeWidget _buildAppBar() {
    final downloadedCount = _allWordBookItems
        .where((item) => item.status == WordBookStatus.downloaded || 
                        item.status == WordBookStatus.selected)
        .length;

    return AcrylicAppBar(
      title: '词库选择 (${_allWordBookItems.length})',
      leading: Padding(
        padding: EdgeInsets.only(left: ResponsiveHelper.getResponsiveSpacing(context, 10)),
        child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryGray),
          iconSize: ResponsiveHelper.getResponsiveIconSize(context, 26),
        onPressed: () {
          SoundService.playTapOffSound();
          Navigator.pop(context);
        },
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: ResponsiveHelper.getResponsiveIconSize(context, 40),
            minHeight: ResponsiveHelper.getResponsiveIconSize(context, 40),
          ),
        ),
      ),
      actions: [
        // 查看已下载词库按钮
        Padding(
          padding: EdgeInsets.only(right: ResponsiveHelper.getResponsiveSpacing(context, 10)),
          child: Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.download_done_rounded,
                color: AppTheme.primaryGray,
                  size: ResponsiveHelper.getResponsiveIconSize(context, 26),
              ),
              onPressed: () {
                SoundService.playTapSound();
                _showDownloadedBooks();
              },
              tooltip: '查看我的词书收藏',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: ResponsiveHelper.getResponsiveIconSize(context, 40),
                  minHeight: ResponsiveHelper.getResponsiveIconSize(context, 40),
                ),
            ),
            if (downloadedCount > 0)
              Positioned(
                  right: 6, // 从8减少到6，适应新的图标大小
                  top: 6, // 从8减少到6，适应新的图标大小
                child: Container(
                    padding: EdgeInsets.all(3), // 从4减少到3
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                      minWidth: 14, // 从16减少到14
                      minHeight: 14, // 从16减少到14
                  ),
                  child: OptimizedText(
                    '$downloadedCount',
                    style: TextStyle(
                      color: Colors.white,
                        fontSize: 9, // 从10减少到9
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        ),
      ],
    );
  }

  /// 构建主体内容
  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeController,
      child: Row(
        children: [
          // 左侧分类侧边栏
          _buildCategorySidebar(),
          
          // 右侧内容区
          Expanded(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildStatsBar(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类侧边栏
  Widget _buildCategorySidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: _isCategoriesLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkSecondaryTextColor : AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                
                return GestureDetector(
                  onTap: () {
                    if (_selectedCategory != category) {
                      setState(() {
                        _selectedCategory = category;
                        _isSearching = true; // 显示搜索状态（加载中）
                      });
                      _onSearchChanged(); // 触发过滤
                    }
                  },
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? AppTheme.accentGreen.withOpacity(0.15) : AppTheme.accentGreen.withOpacity(0.1))
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? AppTheme.accentGreen : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected 
                            ? AppTheme.accentGreen 
                            : (isDark ? AppTheme.darkSecondaryTextColor : AppTheme.secondaryTextColor),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  /// 构建搜索栏
  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12), // 从20,8,20,8减少到16,6,16,6
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12), // 从16减少到12
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // 从0.05减少到0.04
            blurRadius: 8, // 从10减少到8
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索词库...',
          hintStyle: TextStyle(
            color: AppTheme.accentGreen,
            fontSize: 16, // 从16减少到14
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.accentGreen,
            size: 20, // 添加图标大小限制
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark 
                        ? AppTheme.coolGray500 
                        : AppTheme.primaryGray.withOpacity(0.6),
                    size: 20, // 添加图标大小限制
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // 从16,14减少到14,12
          ),
        style: TextStyle(
          fontSize: 16, // 从16减少到14
          color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.darkGray),
        ),
      ),
    );
  }
  
  /// 构建统计栏
  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), // 从20,0,20,16减少到16,0,16,12
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 从20,12减少到16,10
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12), // 从16减少到12
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // 从0.05减少到0.04
            blurRadius: 8, // 从10减少到8
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 总词库数量
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // 从8减少到6
                decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8), // 从10减少到8
                ),
                child: Icon(
                  Icons.library_books,
                  color: AppTheme.accentGreen,
                  size: 16, // 从20减少到16
                ),
              ),
              const SizedBox(width: 8),
          OptimizedText(
                '总计: ${_allWordBookItems.length}',
            style: TextStyle(
                  fontSize: 13, // 从14减少到13
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                  fontWeight: FontWeight.w500,
            ),
          ),
            ],
          ),
          
          // 已下载数量
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // 从8减少到6
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8), // 从10减少到8
                ),
                child: Icon(
                  Icons.download_done,
                  color: AppTheme.accentGreen,
                  size: 16, // 从20减少到16
                ),
              ),
              const SizedBox(width: 8),
            OptimizedText(
                '已下载: ${_allWordBookItems.where((item) => item.status == WordBookStatus.downloaded || item.status == WordBookStatus.selected).length}',
              style: TextStyle(
                  fontSize: 13, // 从14减少到13
                  color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.coolGray600),
                  fontWeight: FontWeight.w500,
              ),
              ),
            ],
            ),
        ],
      ),
    );
  }
  
  /// 构建内容区域
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    } else if (_errorMessage != null) {
      return _buildErrorState();
    } else if (_isSearching) {
      return _buildSearchingState();
    } else if (_displayedItems.isEmpty && _filteredWordBookItems.isEmpty) {
      return _buildEmptyState();
    } else {
      return _buildWordBookList();
    }
  }
  
  /// 构建搜索状态
  Widget _buildSearchingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.primaryGray)
              ),
            ),
          ),
          const SizedBox(height: 16),
          OptimizedText(
            '正在寻找词书...',
            style: TextStyle(
              color: isDark 
                  ? AppTheme.darkSecondaryTextColor 
                  : AppTheme.primaryGray.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建加载状态
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 使用更现代的加载动画
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.primaryGray)
              ),
            ),
          ),
          const SizedBox(height: 24),
          OptimizedText(
            '词书正在赶来的路上...',
            style: TextStyle(
              color: AppTheme.getSecondaryTitleColor(context, lightColor: AppTheme.primaryGray),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          OptimizedText(
            '稍等一下，好词汇马上就来',
            style: TextStyle(
              color: AppTheme.primaryGray.withOpacity(0.7),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// 构建错误状态
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.primaryGray,
            ),
            const SizedBox(height: 16),
            OptimizedText(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primaryGray,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWordBooks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGray,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const OptimizedText('重新试试'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建空状态
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.primaryGray,
          ),
          SizedBox(height: 16),
          OptimizedText(
            '未找到匹配的词库',
            style: TextStyle(
              color: AppTheme.primaryGray,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建词库列表 - 改为网格布局
  Widget _buildWordBookList() {
    return GridView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 手机端每行2个
        childAspectRatio: 0.75, // 调整长宽比以适应封面和标题
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _displayedItems.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedItems.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGray),
              ),
            ),
          );
        }
        
        return _buildAnimatedWordBookCard(_displayedItems[index]);
      },
    );
  }
  
  /// 构建带动画的词库卡片
  Widget _buildAnimatedWordBookCard(WordBookItem item) {
    if (item.animationController == null || 
        item.fadeAnimation == null || 
        item.slideAnimation == null) {
      return _buildWordBookCard(item);
    }
    
    return AnimatedBuilder(
      animation: item.animationController!,
      builder: (context, child) {
        return FadeTransition(
          opacity: item.fadeAnimation!,
          child: SlideTransition(
            position: item.slideAnimation!,
            child: _buildWordBookCard(item),
          ),
        );
      },
    );
  }

  /// 构建词库卡片 - 针对网格布局重构
  Widget _buildWordBookCard(WordBookItem item) {
    final isSelected = item.status == WordBookStatus.selected;
    final isDownloaded = item.status == WordBookStatus.downloaded || 
                        item.status == WordBookStatus.selected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accentGreen : Colors.transparent, 
          width: 2
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: isSelected 
                ? AppTheme.accentGreen.withOpacity(0.15)
                : AppTheme.coolGray200.withOpacity(0.25),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectWordBook(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 封面区域 (占比大部分)
                Expanded(
                  child: Stack(
                    children: [
                      _buildModernCover(item),
                      // 状态指示器悬浮在封面上
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildStatusIndicator(item.status),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                
                // 2. 标题
                OptimizedText(
                  item.wordBook.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getPrimaryTitleColor(context, lightColor: AppTheme.coolGray800),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // 3. 单词数量/操作状态
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isDownloaded && item.wordBook.wordCount > 0)
                      OptimizedText(
                        '${item.wordBook.wordCount} 词',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      OptimizedText(
                        '待学习',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkSecondaryTextColor : AppTheme.secondaryTextColor,
                        ),
                      ),
                    
                    // 简化的操作按钮
                    _buildMiniActionIcon(item),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建小型操作图标
  Widget _buildMiniActionIcon(WordBookItem item) {
    IconData iconData;
    Color iconColor;
    
    switch (item.status) {
      case WordBookStatus.notDownloaded:
        iconData = Icons.download_for_offline_outlined;
        iconColor = AppTheme.coolGray400;
        break;
      case WordBookStatus.downloading:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
          ),
        );
      case WordBookStatus.downloaded:
        iconData = Icons.add_circle_outline_rounded;
        iconColor = AppTheme.accentGreen;
        break;
      case WordBookStatus.selected:
        iconData = Icons.check_circle_rounded;
        iconColor = AppTheme.accentGreen;
        break;
      default:
        iconData = Icons.more_horiz;
        iconColor = AppTheme.coolGray400;
    }
    
    return Icon(iconData, size: 18, color: iconColor);
  }

  /// 构建现代化封面 - 针对网格优化
  Widget _buildModernCover(WordBookItem item) {
    final String? coverUrl = item.wordBook.coverUrl;
    
    // 处理图片 URL
    String? fullCoverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http')) {
        fullCoverUrl = coverUrl;
      } else {
        // 如果是相对路径，拼上基础 URL
        fullCoverUrl = '${ApiConfig.baseUrl}${coverUrl.startsWith('/') ? '' : '/'}$coverUrl';
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(item.wordBook.coverColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? null 
            : [
                BoxShadow(
                  color: Color(item.wordBook.coverColor).withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: fullCoverUrl != null
            ? Image.network(
                fullCoverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultCoverIcon(item);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(item.wordBook.iconColor).withOpacity(0.5),
                      ),
                    ),
                  );
                },
              )
            : _buildDefaultCoverIcon(item),
      ),
    );
  }

  /// 构建默认封面图标
  Widget _buildDefaultCoverIcon(WordBookItem item) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        color: Color(item.wordBook.iconColor),
        size: 32,
      ),
    );
  }

  /// 构建状态指示器 - 针对网格优化
  Widget _buildStatusIndicator(WordBookStatus status) {
    if (status != WordBookStatus.selected && status != WordBookStatus.downloaded) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(
        status == WordBookStatus.selected ? Icons.star_rounded : Icons.download_done_rounded,
        color: AppTheme.accentGreen,
        size: 14,
      ),
    );
  }
}
