# 后端 API 集成指南

## 📚 概述

本指南说明如何将 Flutter 应用与猫头鹰词典后端 API 集成。

## 🚀 快速开始

### 1. 启动后端服务

```bash
cd xuebadictApp/xuebaBackend
python app.py
```

服务将在 http://localhost:5000 启动

### 2. 验证 API 可用性

在浏览器中访问：
- Swagger UI: http://localhost:5000/api/docs
- 健康检查: http://localhost:5000/api/health
- 分类列表: http://localhost:5000/api/categories

### 3. 配置 Flutter 应用

编辑 `lib/config/api_config.dart`：

```dart
class ApiConfig {
  // 开发环境
  static const String devBaseUrl = 'http://localhost:5000/api';
  
  // 生产环境
  static const String prodBaseUrl = 'https://your-domain.com/api';
  
  // 当前使用的环境
  static const bool isProduction = false; // 开发时设为 false
}
```

### 4. 添加依赖

在 `pubspec.yaml` 中确保有 http 依赖：

```yaml
dependencies:
  http: ^1.1.0
```

运行：
```bash
flutter pub get
```

### 5. 运行 Flutter 应用

```bash
flutter run
```

## 📡 API 服务使用

### BackendApiService

所有后端 API 调用都通过 `BackendApiService` 类进行。

#### 获取分类列表

```dart
import 'package:xueba_dict/services/backend_api_service.dart';

// 获取分类
final categories = await BackendApiService.getCategories();
print('分类: $categories');
```

#### 获取词书列表

```dart
// 获取所有词书
final books = await BackendApiService.getBooks();

// 按分类筛选
final cet4Books = await BackendApiService.getBooks(category: '四级');

// 按标签筛选
final youdaoBooks = await BackendApiService.getBooks(tag: '有道');
```

#### 获取词书详情

```dart
final bookDetail = await BackendApiService.getBookDetail('CET4luan_1');
print('词书名称: ${bookDetail['title']}');
print('单词数量: ${bookDetail['wordCount']}');
```

#### 获取单词列表

```dart
final wordsData = await BackendApiService.getWords(
  'CET4luan_1',
  page: 1,
  pageSize: 20,
);

print('总单词数: ${wordsData['total']}');
print('当前页: ${wordsData['page']}');
print('总页数: ${wordsData['total_pages']}');

final words = wordsData['words'];
for (var word in words) {
  print('${word['headWord']}: ${word['usphone']}');
}
```

#### 获取单词详情

```dart
final wordDetail = await BackendApiService.getWordDetail('CET4luan_1', 1);

print('单词: ${wordDetail['word']}');
print('音标: ${wordDetail['usphone']}');
print('翻译: ${wordDetail['translations']}');
print('例句: ${wordDetail['sentences']}');
```

#### 搜索单词

```dart
// 全局搜索
final searchResult = await BackendApiService.searchWords('test');

// 在指定词书中搜索
final bookSearchResult = await BackendApiService.searchWords(
  'test',
  bookId: 'CET4luan_1',
);

print('找到 ${searchResult['total']} 个结果');
```

#### 获取发音 URL

```dart
// 英音
final ukUrl = await BackendApiService.getPronunciationUrl('hello', type: '1');

// 美音
final usUrl = await BackendApiService.getPronunciationUrl('hello', type: '2');
```

#### 健康检查

```dart
final isHealthy = await BackendApiService.healthCheck();
if (isHealthy) {
  print('✅ API 服务正常');
} else {
  print('❌ API 服务异常');
}
```

## 🔧 错误处理

所有 API 方法都会抛出异常，需要使用 try-catch 处理：

```dart
try {
  final categories = await BackendApiService.getCategories();
  // 处理成功情况
} catch (e) {
  print('错误: $e');
  // 处理错误情况
  // 可以显示错误提示或使用降级方案
}
```

## 📱 在 LibraryPage 中的集成

### 动态加载分类

```dart
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
  } catch (e) {
    // 使用默认分类作为降级方案
    setState(() {
      _categories = ['全部', '四级', '六级', '考研', ...];
      _isCategoriesLoading = false;
    });
  }
}
```

### 显示加载状态

```dart
Widget _buildCategorySidebar() {
  return Container(
    child: _isCategoriesLoading
        ? Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              // 构建分类项
            },
          ),
  );
}
```

## 🌐 网络配置

### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加网络权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

允许 HTTP 请求（开发环境）：

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

### iOS

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🔄 数据流程

```
Flutter App
    ↓
BackendApiService
    ↓
HTTP Request
    ↓
Backend API (Flask)
    ↓
ZIP Files / Cache
    ↓
JSON Response
    ↓
Flutter UI
```

## 📊 API 响应格式

所有 API 响应都遵循统一格式：

```json
{
  "code": 200,
  "msg": "数据请求成功",
  "data": { ... },
  "request_id": "abc123"
}
```

### 成功响应

```json
{
  "code": 200,
  "msg": "数据请求成功",
  "data": ["四级", "六级", "考研"],
  "request_id": "abc123"
}
```

### 错误响应

```json
{
  "code": 404,
  "msg": "Resource not found",
  "request_id": "abc123"
}
```

## 🎯 最佳实践

### 1. 使用降级方案

```dart
try {
  final categories = await BackendApiService.getCategories();
  return categories;
} catch (e) {
  // 返回默认数据
  return ['全部', '四级', '六级'];
}
```

### 2. 显示加载状态

```dart
setState(() {
  _isLoading = true;
});

try {
  final data = await BackendApiService.getBooks();
  // 处理数据
} finally {
  setState(() {
    _isLoading = false;
  });
}
```

### 3. 缓存数据

```dart
// 首次从 API 获取
final categories = await BackendApiService.getCategories();

// 缓存到本地
await CacheService.cacheCategories(categories);

// 下次优先从缓存读取
final cachedCategories = await CacheService.getCachedCategories();
if (cachedCategories != null) {
  return cachedCategories;
}
```

### 4. 超时处理

```dart
try {
  final data = await BackendApiService.getBooks()
      .timeout(Duration(seconds: 10));
} on TimeoutException {
  print('请求超时');
} catch (e) {
  print('其他错误: $e');
}
```

## 🐛 常见问题

### Q1: 无法连接到 API

**A:** 检查：
1. 后端服务是否启动
2. API 地址是否正确
3. 网络权限是否配置
4. 防火墙是否阻止

### Q2: Android 上 HTTP 请求失败

**A:** 在 AndroidManifest.xml 中添加：
```xml
android:usesCleartextTraffic="true"
```

### Q3: iOS 上网络请求失败

**A:** 在 Info.plist 中配置 NSAppTransportSecurity

### Q4: 请求超时

**A:** 
1. 检查网络连接
2. 增加超时时间
3. 优化后端性能

## 📝 开发检查清单

- [ ] 后端服务已启动
- [ ] API 地址配置正确
- [ ] 网络权限已配置
- [ ] HTTP 依赖已添加
- [ ] 错误处理已实现
- [ ] 加载状态已显示
- [ ] 降级方案已准备
- [ ] 在真机上测试

## 🚀 部署到生产环境

### 1. 更新 API 配置

```dart
class ApiConfig {
  static const bool isProduction = true; // 改为 true
  static const String prodBaseUrl = 'https://api.xueba.com/api';
}
```

### 2. 移除调试日志

```dart
class ApiConfig {
  static const bool enableLogging = false; // 关闭日志
}
```

### 3. 使用 HTTPS

确保生产环境使用 HTTPS 协议。

### 4. 配置域名

将后端 API 部署到服务器并配置域名。

## 📚 相关文档

- [后端 API 文档](../xuebaBackend/README_COMPLETE.md)
- [Swagger UI](http://localhost:5000/api/docs)
- [Flutter HTTP 包](https://pub.dev/packages/http)

---

**集成完成！现在你的 Flutter 应用可以与后端 API 无缝交互了！🎉**
