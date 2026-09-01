# 狮子英语 API - Docker 部署指南

## 快速开始

### 前置条件
- 已安装 Docker 和 Docker Compose
- 系统内存 >= 4GB

### 一键启动

#### 方式一：使用现有的 .env 文件
```bash
docker-compose up -d
```

#### 方式二：使用 Docker 环境配置
```bash
# 1. 复制环境配置文件
cp .env.docker .env

# 2. 编辑 .env 文件，配置敏感信息（数据库密码、密钥等）
# 开发环境可保持默认值，生产环境请修改安全配置

# 3. 启动所有服务
docker-compose up -d
```

### 服务状态查询

```bash
# 查看所有容器状态
docker-compose ps

# 查看日志
docker-compose logs -f api          # 查看API日志
docker-compose logs -f mysql        # 查看MySQL日志
docker-compose logs -f redis        # 查看Redis日志
docker-compose logs -f celery_worker  # 查看Celery日志
```

## 服务访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| API 主服务 | http://localhost:5000 | RESTful API 主入口 |
| API 文档 | http://localhost:5000/api/docs | Swagger 交互式文档 |
| 健康检查 | http://localhost:5000/health | API 健康检查接口 |
| Flower 监控 | http://localhost:5555 | Celery 任务监控面板 |
| MySQL | localhost:3306 | 数据库服务 |
| Redis | localhost:6379 | 缓存服务 |

## 关键 API 端点

```bash
# 获取教材列表
curl http://localhost:5000/api/v1/textbooks

# 获取特定教材的书籍
curl http://localhost:5000/api/v1/textbooks/PEP/books?grade=3&category=小学

# 获取单词列表
curl http://localhost:5000/api/v1/books/PEPXiaoXue3_1/words

# 获取单个单词
curl http://localhost:5000/api/v1/words/PEPXiaoXue3_1/1

# 单词搜索
curl "http://localhost:5000/api/v1/words/search?keyword=hello"

# 获取闯关列表
curl http://localhost:5000/api/v1/units/unit_001/challenges

# 开始听写练习
curl -X POST http://localhost:5000/api/v1/units/unit_001/dictation/start

# 查看 API 文档
curl http://localhost:5000/apispec.json
```

## 常用命令

### 启动和停止

```bash
# 启动所有服务（后台运行）
docker-compose up -d

# 启动特定服务
docker-compose up -d api          # 仅启动 API
docker-compose up -d mysql        # 仅启动 MySQL

# 停止所有服务
docker-compose down

# 停止并删除所有数据
docker-compose down -v

# 查看运行日志
docker-compose logs -f [service_name]

# 实时查看 API 日志（最后 100 行）
docker-compose logs --tail 100 -f api
```

### 数据库操作

```bash
# 连接到 MySQL 容器
docker-compose exec mysql mysql -uroot -p123456 xuebadict

# 备份数据库
docker-compose exec mysql mysqldump -uroot -p123456 xuebadict > backup.sql

# 恢复数据库
docker-compose exec mysql mysql -uroot -p123456 xuebadict < backup.sql

# 查看 MySQL 容器内的 SQL 日志
docker-compose exec mysql tail -f /var/log/mysql/error.log
```

### 应用内操作

```bash
# 进入 API 容器的 shell
docker-compose exec api bash

# 运行 Flask 迁移
docker-compose exec api flask db upgrade

# 运行测试
docker-compose exec api pytest

# 清空数据库并重新初始化（危险操作，谨慎使用）
docker-compose exec api python -c "from extensions import db; db.drop_all(); db.create_all()"
```

### Redis 操作

```bash
# 连接到 Redis
docker-compose exec redis redis-cli

# 查看 Redis 内存统计
docker-compose exec redis redis-cli info memory

# 清空所有 Redis 数据
docker-compose exec redis redis-cli FLUSHALL
```

## 环境变量配置

所有配置项都在 `.env` 文件中管理。关键配置项说明：

### 应用配置
- `FLASK_ENV`: Flask 运行模式（development/production）
- `SECRET_KEY`: Flask 应用密钥（务必在生产环境修改）
- `JWT_SECRET_KEY`: JWT 签名密钥（务必在生产环境修改）

### 数据库配置
- `DB_HOST`: MySQL 主机（Docker 环境设置为 `mysql`）
- `DB_PORT`: MySQL 端口（默认 3306）
- `DB_USER`: MySQL 用户名
- `DB_PASSWORD`: MySQL 密码
- `DB_NAME`: 数据库名称

### Redis 配置
- `REDIS_HOST`: Redis 主机（Docker 环境设置为 `redis`）
- `REDIS_PORT`: Redis 端口（默认 6379）

### 第三方服务（可选）
- 微信支付、支付宝、阿里云 SMS/OSS、AI 服务等

## 数据持久化

Docker Compose 配置中的 Volumes 确保数据持久化：

```yaml
volumes:
  mysql_data: /var/lib/mysql        # MySQL 数据库文件
  redis_data: /data                 # Redis 持久化文件
```

数据存储位置：
- MySQL: 系统 Docker 卷目录中
- Redis: 系统 Docker 卷目录中
- 应用日志: `/app/logs`（容器内挂载到本地 `./logs`）
- 上传文件: `/app/uploads`（容器内挂载到本地 `./uploads`）

## 生产环境部署建议

### 1. 安全配置
```bash
# 必须修改的关键密钥
FLASK_ENV=production
SECRET_KEY=<使用强随机密钥>
JWT_SECRET_KEY=<使用强随机密钥>
DB_PASSWORD=<使用强密码>
REDIS_PASSWORD=<可选，设置 Redis 密码>
```

### 2. 性能优化
- 增加 API 副本：修改 docker-compose.yml 中的 `deploy.replicas`
- 配置 Nginx 反向代理和负载均衡
- 调整 Celery Worker 数量根据 CPU 核心数

### 3. 监控和日志
- 使用 ELK Stack (Elasticsearch, Logstash, Kibana) 集中日志
- 配置 Prometheus + Grafana 进行性能监控
- 设置告警规则

### 4. 备份策略
```bash
# 定期备份数据库（每天凌晨2点）
0 2 * * * docker-compose exec -T mysql mysqldump -uroot -p$DB_PASSWORD $DB_NAME > /backup/db_$(date +\%Y\%m\%d).sql
```

### 5. 网络隔离
- 只暴露 API 服务到公网（端口 5000）
- MySQL 和 Redis 仅在内部网络暴露
- 配置防火墙规则

## 故障排除

### 问题 1: 容器无法启动
```bash
# 查看启动错误日志
docker-compose logs api

# 检查 Docker 守护进程是否运行
docker ps
```

### 问题 2: 数据库连接失败
```bash
# 确认 MySQL 容器健康状态
docker-compose ps mysql

# 验证数据库连接
docker-compose exec api python -c "from extensions import db; print('DB connected')"

# 检查数据库初始化 SQL 是否执行
docker-compose exec mysql mysql -uroot -p123456 xuebadict -e "SHOW TABLES;"
```

### 问题 3: 端口被占用
```bash
# 查找占用 5000 端口的进程
netstat -ano | findstr :5000  # Windows
lsof -i :5000                 # macOS/Linux

# 修改 docker-compose.yml 中的端口映射
# 例如：将 "5000:5000" 改为 "5001:5000"
```

### 问题 4: 性能问题
```bash
# 检查容器资源使用情况
docker stats

# 增加 MySQL 最大连接数
docker-compose exec mysql mysql -uroot -p123456 -e "SET GLOBAL max_connections = 1000;"

# 清理 Docker 缓存
docker system prune -a
```

## 更新应用

```bash
# 1. 拉取最新代码
git pull origin main

# 2. 重建镜像
docker-compose build

# 3. 重启服务
docker-compose up -d

# 4. 执行数据库迁移（如有需要）
docker-compose exec api flask db upgrade
```

## 扩展配置

### 使用外部 MySQL（非 Docker）
修改 `.env` 文件中的 `DB_HOST` 为外部 MySQL 地址，并注释掉 docker-compose.yml 中的 MySQL 服务。

### 使用外部 Redis（非 Docker）
修改 `.env` 文件中的 `REDIS_HOST` 为外部 Redis 地址，并注释掉 docker-compose.yml 中的 Redis 服务。

### 启用 HTTPS
```bash
# 1. 获取 SSL 证书（使用 Let's Encrypt）
# 2. 配置 Nginx 反向代理处理 HTTPS
# 3. 修改 config.py 中的 `host` 为 HTTPS 地址
```

## 常见问题解答

**Q: 如何在容器中运行 Flask CLI 命令？**
```bash
docker-compose exec api flask [command]
```

**Q: 如何查看实时日志？**
```bash
docker-compose logs -f --tail 100 api
```

**Q: 如何重置所有数据？**
```bash
docker-compose down -v
docker-compose up -d
```

**Q: 生产环境应该保留 DEBUG 模式吗？**
不应该。确保在生产环境设置 `FLASK_ENV=production`，这会自动禁用 DEBUG 模式。

**Q: Celery Worker 无法连接 Redis 怎么办？**
```bash
# 检查 Redis 是否正确启动
docker-compose ps redis

# 手动测试连接
docker-compose exec api redis-cli -h redis ping
```

## 获取帮助

如遇到问题，请：
1. 查看 Docker 日志：`docker-compose logs -f`
2. 检查网络连接：`docker network inspect xuebadict_xuebadict-network`
3. 验证环境变量：`docker-compose config`
4. 查看应用日志：`./logs/app.log`

---

**最后更新**: 2024年
**维护者**: 狮子英语团队
