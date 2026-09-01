# 🐳 狮子英语 API - Docker 部署

完整的 Docker 和 Docker Compose 配置文件已生成！

## 📦 快速开始（选择一种方式）

### ⚡ 方式 1：一键启动（推荐）

**Windows 用户**
```bash
docker-start.bat
```

**Linux/macOS 用户**
```bash
chmod +x docker-start.sh
./docker-start.sh
```

然后选择菜单选项 `1` 启动所有服务。

### 📝 方式 2：配置并启动

```bash
# 1. 创建环境文件
cp .env.docker .env

# 2. 根据需要编辑 .env 文件中的配置

# 3. 启动所有服务
docker-compose up -d

# 4. 查看服务状态
docker-compose ps
```

### 🚀 方式 3：直接命令行启动

```bash
docker-compose up -d
```

## 🎯 启动成功标志

运行以下命令验证所有服务是否正常运行：

```bash
# 查看所有容器状态
docker-compose ps

# 预期输出：所有容器状态为 "Up"
# xuebadict-mysql    ...    Up (healthy)
# xuebadict-redis    ...    Up (healthy)
# xuebadict-api      ...    Up (healthy)
# xuebadict-celery   ...    Up
# xuebadict-flower   ...    Up
```

如果看到以上输出，恭喜！🎉 服务已成功启动！

## 🌐 访问应用

启动后可访问以下地址：

| 功能 | URL | 说明 |
|------|-----|------|
| **API 主页** | http://localhost:5000 | 应用主入口 |
| **健康检查** | http://localhost:5000/health | 检查 API 是否在线 |
| **API 文档** | http://localhost:5000/api/docs | Swagger 交互式 API 文档 |
| **Flower 监控** | http://localhost:5555 | Celery 任务监控面板 |

## 📚 文档导航

| 文档 | 用途 | 阅读时间 |
|------|------|---------|
| **QUICKSTART_DOCKER.md** | 快速上手指南 | 5 分钟 |
| **DOCKER_GUIDE.md** | 完整部署指南 | 20 分钟 |
| **DOCKER_FILES_SUMMARY.md** | Docker 文件详解 | 10 分钟 |
| **DOCKER_CHECKLIST.md** | 部署检查清单 | 15 分钟 |

## 🛠️ 常用命令

### 查看日志

```bash
# 查看 API 日志
docker-compose logs -f api

# 查看最后 100 行日志
docker-compose logs --tail 100 api

# 查看所有服务日志
docker-compose logs -f
```

### 进入容器

```bash
# 进入 API 容器的 shell
docker-compose exec api bash

# 进入数据库容器
docker-compose exec mysql bash

# 连接到 MySQL 数据库
docker-compose exec mysql mysql -uroot -p123456 xuebadict
```

### 停止服务

```bash
# 停止所有服务（数据保留）
docker-compose down

# 停止并删除所有数据（谨慎！）
docker-compose down -v

# 重启服务
docker-compose restart
```

## 📋 生成的 Docker 文件清单

### 核心 Docker 文件
- ✅ `Dockerfile` - 开发环境镜像定义
- ✅ `Dockerfile.prod` - 生产环境镜像（多阶段优化）
- ✅ `.dockerignore` - 构建忽略文件

### Docker Compose 配置
- ✅ `docker-compose.yml` - 标准开发配置
- ✅ `docker-compose.prod.yml` - 生产优化配置
- ✅ `docker-compose.nginx.yml` - 带 Nginx 反向代理配置

### 环境配置
- ✅ `.env.docker` - 环境变量模板（复制为 `.env` 使用）

### 启动脚本
- ✅ `docker-start.bat` - Windows 交互式菜单脚本
- ✅ `docker-start.sh` - Linux/macOS 交互式菜单脚本

### 生产配置
- ✅ `nginx.conf` - Nginx 反向代理配置

### 文档
- ✅ `QUICKSTART_DOCKER.md` - 快速开始指南
- ✅ `DOCKER_GUIDE.md` - 完整部署指南
- ✅ `DOCKER_FILES_SUMMARY.md` - 文件汇总说明
- ✅ `DOCKER_CHECKLIST.md` - 部署检查清单

## 🏗️ 服务架构

```
┌─────────────────────────────────────────┐
│         Docker 容器化架构                 │
├─────────────────────────────────────────┤
│                                          │
│  ┌──────────────────────────────────┐   │
│  │   Flask API (5000)                │   │
│  │  - RESTful 接口                    │   │
│  │  - Swagger 文档                    │   │
│  │  - WebSocket 支持                  │   │
│  └──────────────────────────────────┘   │
│           ↓           ↓                  │
│  ┌──────────────┐  ┌──────────────┐    │
│  │   MySQL      │  │    Redis     │    │
│  │  (3306)      │  │   (6379)     │    │
│  │  - 数据库    │  │  - 缓存      │    │
│  │  - 持久化    │  │  - Session   │    │
│  └──────────────┘  └──────────────┘    │
│           ↓                              │
│  ┌──────────────────────────────────┐   │
│  │   Celery Worker                   │   │
│  │  - 异步任务                        │   │
│  │  - 定时任务                        │   │
│  └──────────────────────────────────┘   │
│           ↓                              │
│  ┌──────────────────────────────────┐   │
│  │   Flower (5555)                   │   │
│  │  - Celery 监控面板                │   │
│  └──────────────────────────────────┘   │
│                                          │
└─────────────────────────────────────────┘
```

## 🔧 配置说明

### 默认环境变量

```env
# Flask
FLASK_ENV=development
SECRET_KEY=dev-secret-key
JWT_SECRET_KEY=dev-jwt-secret

# 数据库
DB_HOST=mysql
DB_PORT=3306
DB_USER=xuebadict
DB_PASSWORD=123456
DB_NAME=xuebadict

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
```

**注意**：生产环境必须修改密钥和密码！

### 修改配置

编辑 `.env` 文件：

```bash
# 1. 打开 .env 文件
nano .env    # Linux/macOS
notepad .env # Windows

# 2. 修改需要的配置项
# 3. 保存文件
# 4. 重启服务
docker-compose restart
```

## 📊 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| API | 5000 | Flask 应用 |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存 |
| Flower | 5555 | Celery 监控 |

## 🔐 生产环境建议

### 1. 修改敏感信息

```bash
# 生成强随机密钥
openssl rand -hex 32

# 修改 .env
SECRET_KEY=<生成的密钥>
JWT_SECRET_KEY=<生成的密钥>
DB_PASSWORD=<强密码>
REDIS_PASSWORD=<强密码>
```

### 2. 使用生产配置

```bash
docker-compose -f docker-compose.prod.yml up -d
```

### 3. 配置 HTTPS

使用 `docker-compose.nginx.yml` 和 SSL 证书：

```bash
# 1. 获取 SSL 证书
# 2. 放置在 certs/ 目录
# 3. 启动 Nginx 配置
docker-compose -f docker-compose.nginx.yml up -d
```

### 4. 定期备份

```bash
# 备份数据库
docker-compose exec mysql mysqldump -uroot -p123456 xuebadict > backup.sql

# 定时任务（crontab）
0 2 * * * cd /path/to/xuebaApi && docker-compose exec -T mysql mysqldump -uroot -p123456 xuebadict > backups/db_$(date +\%Y\%m\%d).sql
```

## 🆘 故障排除

### 问题 1：容器无法启动

```bash
# 查看错误日志
docker-compose logs api

# 重新构建镜像
docker-compose build --no-cache api

# 重启服务
docker-compose up -d api
```

### 问题 2：数据库连接失败

```bash
# 检查 MySQL 状态
docker-compose ps mysql

# 查看 MySQL 日志
docker-compose logs mysql

# 重启 MySQL
docker-compose restart mysql
```

### 问题 3：端口被占用

```bash
# 查找占用的进程
netstat -ano | findstr :5000     # Windows
lsof -i :5000                     # macOS/Linux

# 修改 docker-compose.yml 中的端口
# "5000:5000" → "5001:5000"
```

## 📖 更多帮助

- **快速问题** → 查看 [QUICKSTART_DOCKER.md](QUICKSTART_DOCKER.md)
- **详细说明** → 查看 [DOCKER_GUIDE.md](DOCKER_GUIDE.md)
- **技术细节** → 查看 [DOCKER_FILES_SUMMARY.md](DOCKER_FILES_SUMMARY.md)
- **部署检查** → 查看 [DOCKER_CHECKLIST.md](DOCKER_CHECKLIST.md)

## 🎯 下一步

1. ✅ 运行 `docker-compose up -d` 启动服务
2. ✅ 访问 http://localhost:5000/api/docs 查看 API 文档
3. ✅ 根据需要修改 `.env` 文件配置
4. ✅ 在生产环境前运行 `DOCKER_CHECKLIST.md` 检查清单
5. ✅ 阅读 [DOCKER_GUIDE.md](DOCKER_GUIDE.md) 了解更多细节

---

**版本**：1.0  
**创建日期**：2024 年  
**维护者**：狮子英语团队

🎉 **Docker 配置完成！现在可以轻松部署应用了！**
