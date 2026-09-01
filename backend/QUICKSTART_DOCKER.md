# 快速开始 - Docker 部署

## 最简快速启动（3 步）

### Windows 用户
```bash
# 1. 进入项目目录
cd xuebaApi

# 2. 运行启动脚本
docker-start.bat

# 3. 选择选项 1 "启动所有服务"
```

### macOS/Linux 用户
```bash
# 1. 进入项目目录
cd xuebaApi

# 2. 运行启动脚本
chmod +x docker-start.sh
./docker-start.sh

# 3. 选择选项 1 "启动所有服务"
```

### 使用命令行直接启动
```bash
# 复制环境配置
cp .env.docker .env

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看 API 日志
docker-compose logs -f api
```

## 启动后验证

### 检查服务
```bash
# 查看所有容器是否健康运行
docker-compose ps

# 输出应该显示所有服务状态为 "Up"
```

### 测试 API 连接
```bash
# 访问主页
curl http://localhost:5000

# 测试健康检查
curl http://localhost:5000/health

# 查看 API 文档
# 在浏览器中打开: http://localhost:5000/api/docs
```

### 验证核心功能
```bash
# 获取教材列表
curl http://localhost:5000/api/v1/textbooks

# 获取单词
curl http://localhost:5000/api/v1/words/PEPXiaoXue3_1/1

# 单词搜索
curl "http://localhost:5000/api/v1/words/search?keyword=hello"
```

## 关键服务地址

| 功能 | 地址 | 说明 |
|------|------|------|
| API 主入口 | http://localhost:5000 | 应用主页 |
| 健康检查 | http://localhost:5000/health | API 状态检查 |
| API 文档 | http://localhost:5000/api/docs | Swagger 交互式文档 |
| Swagger JSON | http://localhost:5000/apispec.json | API 规范文件 |
| Flower 监控 | http://localhost:5555 | Celery 任务监控 |

## 常用操作

### 查看日志
```bash
# 查看 API 日志（最后 50 行）
docker-compose logs --tail 50 api

# 实时查看 API 日志（按 Ctrl+C 退出）
docker-compose logs -f api

# 查看特定服务的日志
docker-compose logs -f mysql    # MySQL 日志
docker-compose logs -f redis    # Redis 日志
```

### 进入容器
```bash
# 进入 API 容器的 bash
docker-compose exec api bash

# 在容器内运行命令
docker-compose exec api python -c "print('Hello from container')"
```

### 数据库操作
```bash
# 连接到 MySQL
docker-compose exec mysql mysql -uroot -p123456 xuebadict

# 在 MySQL 中执行查询
docker-compose exec mysql mysql -uroot -p123456 xuebadict -e "SELECT COUNT(*) FROM users;"

# 备份数据库
docker-compose exec mysql mysqldump -uroot -p123456 xuebadict > backup.sql

# 恢复数据库
docker-compose exec mysql mysql -uroot -p123456 xuebadict < backup.sql
```

### Redis 操作
```bash
# 连接到 Redis
docker-compose exec redis redis-cli

# 检查 Redis 连接
docker-compose exec redis redis-cli ping

# 查看 Redis 内存使用
docker-compose exec redis redis-cli info memory
```

## 停止和清理

### 正常停止
```bash
# 停止所有容器但保留数据
docker-compose down

# 查看停止后的服务
docker-compose ps -a
```

### 完全清理（删除所有数据）
```bash
# 警告：此操作会删除所有数据库和缓存数据
docker-compose down -v

# 清理不使用的 Docker 资源
docker system prune -a
```

### 重启服务
```bash
# 重启特定服务
docker-compose restart api

# 重启所有服务
docker-compose restart
```

## 环境配置

默认配置存储在 `.env` 文件中。关键配置项：

```env
# Flask 环境
FLASK_ENV=development              # development/production
SECRET_KEY=dev-secret-key          # 应用密钥
JWT_SECRET_KEY=dev-jwt-secret      # JWT 密钥

# 数据库
DB_USER=xuebadict                  # 数据库用户
DB_PASSWORD=123456                 # 数据库密码
DB_NAME=xuebadict                  # 数据库名

# Redis
REDIS_HOST=redis                   # Redis 主机
REDIS_PORT=6379                    # Redis 端口
REDIS_PASSWORD=                    # Redis 密码
```

## 生产环境部署

### 使用生产配置
```bash
# 使用生产版 Dockerfile 和配置
docker-compose -f docker-compose.prod.yml up -d

# 需要先准备 .env 文件并修改敏感配置
```

### 生产环境建议
1. 修改所有密钥和密码为强随机值
2. 设置 `FLASK_ENV=production`
3. 关闭 DEBUG 模式
4. 配置 HTTPS/SSL 证书
5. 设置反向代理（Nginx/Apache）
6. 配置监控和日志收集
7. 定期备份数据库

## 故障排除

### 容器无法启动
```bash
# 查看启动错误
docker-compose logs api

# 重新构建镜像
docker-compose build --no-cache api

# 重新启动
docker-compose up -d api
```

### 数据库连接失败
```bash
# 检查 MySQL 容器是否运行
docker-compose ps mysql

# 检查 MySQL 日志
docker-compose logs mysql

# 验证数据库连接
docker-compose exec api python -c "from extensions import db; print('OK')"
```

### 端口被占用
```bash
# 查看占用的端口
netstat -ano | findstr :5000      # Windows
lsof -i :5000                      # macOS/Linux

# 修改 docker-compose.yml 中的端口映射
# 例如：将 "5000:5000" 改为 "5001:5000"
```

### 内存不足
```bash
# 查看容器资源使用
docker stats

# 清理不使用的 Docker 资源
docker system prune -a --volumes

# 减少副本数或调整资源限制
```

## 获取帮助

更多详细信息请查看 [DOCKER_GUIDE.md](DOCKER_GUIDE.md)

---

**快速参考**：[docker-start.bat](docker-start.bat) (Windows) / [docker-start.sh](docker-start.sh) (Linux/macOS)
