# Docker 文件汇总 - 狮子英语 API

本文档介绍所有 Docker 相关文件及其用途。

## 📁 生成的文件清单

### 核心 Docker 文件

| 文件 | 说明 | 用途 |
|------|------|------|
| **Dockerfile** | 开发版镜像定义 | 构建开发环境镜像 |
| **Dockerfile.prod** | 生产版镜像定义（多阶段） | 构建生产优化镜像（更小体积） |
| **.dockerignore** | Docker 构建忽略文件 | 排除不必要的文件，减小镜像体积 |

### Docker Compose 配置

| 文件 | 说明 | 场景 |
|------|------|------|
| **docker-compose.yml** | 标准配置 | 开发环境，完整功能（API + MySQL + Redis + Celery + Flower） |
| **docker-compose.prod.yml** | 生产优化配置 | 生产环境，优化资源限制和配置 |
| **docker-compose.nginx.yml** | 包含 Nginx 的配置 | 生产环境，带反向代理和 SSL/TLS 支持 |

### 环境配置

| 文件 | 说明 | 备注 |
|------|------|------|
| **.env.docker** | Docker 环境变量模板 | 复制为 `.env` 后使用 |

### 启动脚本

| 文件 | 说明 | 平台 |
|------|------|------|
| **docker-start.bat** | 交互式菜单启动脚本 | Windows |
| **docker-start.sh** | 交互式菜单启动脚本 | macOS/Linux |

### 配置文件

| 文件 | 说明 | 用途 |
|------|------|------|
| **nginx.conf** | Nginx 反向代理配置 | 生产环境，SSL/TLS 和请求转发 |

### 文档文件

| 文件 | 说明 | 内容 |
|------|------|------|
| **DOCKER_GUIDE.md** | 完整 Docker 部署指南 | 详细说明、命令参考、故障排除 |
| **QUICKSTART_DOCKER.md** | 快速开始指南 | 最常用操作、快速验证 |
| **DOCKER_FILES_SUMMARY.md** | 本文件 | Docker 文件汇总说明 |

## 🚀 快速开始

### 方式一：最简（推荐）

Windows:
```bash
docker-start.bat
```

macOS/Linux:
```bash
chmod +x docker-start.sh
./docker-start.sh
```

### 方式二：命令行

```bash
cp .env.docker .env
docker-compose up -d
```

### 方式三：生产环境

```bash
docker-compose -f docker-compose.prod.yml up -d
```

### 方式四：带 Nginx 反向代理

```bash
docker-compose -f docker-compose.nginx.yml up -d
```

## 📋 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                     External Client                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                ┌──────▼──────┐
                │    Nginx    │  (可选，docker-compose.nginx.yml)
                │  Port 80/443│
                └──────┬──────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────▼────┐  ┌─────▼────┐  ┌─────▼──────┐
   │   API   │  │  Celery  │  │   Flower   │
   │ :5000   │  │  Worker  │  │   :5555    │
   └────┬────┘  └─────┬────┘  └────────────┘
        │             │
        └─────┬──────┬┘
              │      │
        ┌─────▼─┐  ┌─▼──────┐
        │ MySQL │  │ Redis  │
        │ :3306 │  │ :6379  │
        └───────┘  └────────┘
```

## 🔧 文件用途详解

### Dockerfile（开发版）

```dockerfile
# 包含 Python 3.11 slim 基础镜像
# 安装编译工具和 Python 依赖
# 暴露 5000 端口
# 使用 Flask 开发服务器运行（支持热重载）
# 包含健康检查
```

**用途**：
- 开发环境快速迭代
- 调试和测试

**特点**：
- 包含所有开发工具
- 支持热重载
- 文件体积较大（但包含开发所需工具）

### Dockerfile.prod（生产版）

```dockerfile
# 多阶段构建：Builder + Runtime
# Builder 阶段：编译和安装依赖
# Runtime 阶段：仅包含运行所需文件
# 非 root 用户运行（安全）
# 使用 gunicorn 作为 WSGI 服务器
# 集成 SSL/TLS 支持
```

**用途**：
- 生产环境部署
- 负载均衡
- 容器编排

**优势**：
- 文件体积小（减少 50%+ 体积）
- 更安全（非 root 用户）
- 更稳定（gunicorn 多进程）
- 更高效（多阶段构建优化）

### docker-compose.yml（标准配置）

**包含服务**：
- MySQL 8.0（数据库）
- Redis 7（缓存）
- API（Flask 应用）
- Celery Worker（异步任务）
- Flower（Celery 监控）

**特点**：
- 完整功能
- 自动初始化数据库
- 服务间自动发现
- 健康检查配置
- 卷持久化

### docker-compose.prod.yml（生产优化）

**改进**：
- 资源限制和预留
- 安全配置（仅本机访问某些服务）
- 性能优化（MySQL 连接数、内存限制等）
- 副本支持（可扩展 API 服务）
- 更强的重启策略

### docker-compose.nginx.yml（带反向代理）

**新增**：
- Nginx 容器
- SSL/TLS 支持
- 静态文件缓存
- 负载均衡
- 安全头部
- API 隐藏在内部网络

**适用场景**：
- 生产环境公网部署
- 需要 HTTPS
- 多 API 副本负载均衡

### .dockerignore

排除的内容：
- 版本控制文件（.git）
- Python 缓存（__pycache__）
- IDE 配置（.vscode, .idea）
- 测试和覆盖率文件
- 文档文件（减小构建体积）
- 临时文件

**效果**：
- 减小构建上下文大小
- 加快镜像构建速度
- 减小镜像体积

### nginx.conf

**主要功能**：
- HTTP 转 HTTPS 重定向
- 反向代理到 API
- SSL/TLS 配置
- 安全头部设置
- 连接池和超时配置
- 静态文件缓存
- 日志记录

**配置特点**：
- 支持 HTTP/2
- 上游服务器健康检查
- Gzip 压缩
- 缓冲配置优化

## 🌍 环境变量说明

### 关键环境变量

```env
# Flask 配置
FLASK_ENV=development          # 运行模式
SECRET_KEY=xxx                 # 应用密钥（必须修改）
JWT_SECRET_KEY=xxx             # JWT 密钥（必须修改）

# 数据库
DB_HOST=mysql                  # 数据库主机
DB_PORT=3306                   # 数据库端口
DB_USER=xuebadict              # 数据库用户
DB_PASSWORD=123456             # 数据库密码（必须修改）
DB_NAME=xuebadict              # 数据库名

# Redis
REDIS_HOST=redis               # Redis 主机
REDIS_PORT=6379               # Redis 端口
REDIS_PASSWORD=                # Redis 密码（可选）

# 第三方服务（可选）
QWEN_API_KEY=xxx               # 阿里通义千问
DEEPSEEK_API_KEY=xxx           # DeepSeek API
ALIYUN_ACCESS_KEY_ID=xxx       # 阿里云密钥
```

## 📊 服务端口映射

| 服务 | 容器端口 | 宿主机端口 | 说明 |
|------|---------|----------|------|
| API | 5000 | 5000 | Flask 应用 |
| MySQL | 3306 | 3306 | 数据库（开发环境） |
| Redis | 6379 | 6379 | 缓存（开发环境） |
| Flower | 5555 | 5555 | Celery 监控 |
| Nginx | 80/443 | 80/443 | 反向代理（仅 nginx.yml） |

## 🔐 生产环境安全建议

### 必须修改

1. **应用密钥**
   ```env
   SECRET_KEY=<使用 openssl rand -hex 32 生成>
   JWT_SECRET_KEY=<使用 openssl rand -hex 32 生成>
   ```

2. **数据库密码**
   ```env
   DB_PASSWORD=<使用强密码>
   ```

3. **Redis 密码**
   ```env
   REDIS_PASSWORD=<使用强密码>
   ```

### 推荐配置

1. **启用 HTTPS**
   - 使用 Let's Encrypt 证书
   - 配置在 Nginx 中

2. **限制访问**
   - MySQL 和 Redis 仅本机访问
   - 使用防火墙规则

3. **监控告警**
   - 配置日志收集
   - 设置性能告警

4. **定期备份**
   - 自动每日备份数据库
   - 定期测试恢复

## 📈 扩展指南

### 增加 API 副本

修改 `docker-compose.yml`：
```yaml
api:
  deploy:
    replicas: 3  # 增加到 3 个副本
```

### 增加 Celery Worker

创建多个 Worker 服务或修改 Worker 参数：
```yaml
celery_worker:
  command: celery -A services.tasks worker -l info --concurrency=8
```

### 连接外部 MySQL

修改 `.env`：
```env
DB_HOST=your-mysql-server.com
DB_PORT=3306
```

移除 `docker-compose.yml` 中的 MySQL 服务。

## 🐛 常见问题

**Q: 如何修改默认端口？**
A: 编辑 `docker-compose.yml` 中的 `ports` 字段。

**Q: 如何使用生产数据库？**
A: 修改 `.env` 中的 `DB_HOST` 和数据库连接字符串。

**Q: 如何启用 HTTPS？**
A: 使用 `docker-compose.nginx.yml`，将 SSL 证书放在 `certs/` 目录。

**Q: 容器出现内存不足怎么办？**
A: 使用 `docker stats` 查看资源，增加主机内存或调整资源限制。

## 📚 文件阅读顺序

1. **QUICKSTART_DOCKER.md** - 快速上手（5 分钟）
2. **DOCKER_GUIDE.md** - 详细指南（20 分钟）
3. **本文件** - 文件总结和参考（10 分钟）
4. **源代码文件** - 了解应用结构

## 🔗 相关资源

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Nginx 反向代理指南](https://nginx.org/en/docs/)
- [Flask 生产部署](https://flask.palletsprojects.com/en/latest/deploying/)
- [Celery 文档](https://docs.celeryproject.io/)

---

**创建日期**：2024 年
**维护者**：狮子英语团队
**最后更新**：2024 年
