# Docker 部署检查清单

按照此检查清单确保 Docker 部署正确无误。

## ✅ 前置条件检查

### 系统环境
- [ ] Docker 已安装（版本 >= 20.10）
- [ ] Docker Compose 已安装（版本 >= 1.29）
- [ ] 系统有足够磁盘空间（>= 20GB）
- [ ] 系统内存 >= 4GB（推荐 8GB 以上）
- [ ] 网络连接正常，可访问 Docker Hub

### 验证命令
```bash
# 检查 Docker
docker --version
docker run hello-world

# 检查 Docker Compose
docker-compose --version

# 检查系统信息
docker system df
docker stats
```

## ✅ 文件检查

生成的文件应在 `xuebaApi` 目录中：

```
xuebaApi/
├── Dockerfile                    ✓ 开发版镜像
├── Dockerfile.prod              ✓ 生产版镜像
├── .dockerignore                ✓ 构建忽略文件
├── docker-compose.yml           ✓ 标准配置
├── docker-compose.prod.yml      ✓ 生产配置
├── docker-compose.nginx.yml     ✓ 反向代理配置
├── .env.docker                  ✓ 环境变量模板
├── docker-start.bat             ✓ Windows 启动脚本
├── docker-start.sh              ✓ Linux/macOS 启动脚本
├── nginx.conf                   ✓ Nginx 配置
├── DOCKER_GUIDE.md              ✓ 完整指南
├── QUICKSTART_DOCKER.md         ✓ 快速开始
├── DOCKER_FILES_SUMMARY.md      ✓ 文件汇总
├── DOCKER_CHECKLIST.md          ✓ 本文件
└── requirements.txt             ✓ Python 依赖（已存在）
```

- [ ] 所有文件已生成
- [ ] 文件权限正确（脚本文件可执行）
- [ ] 没有冲突或覆盖现有文件

## ✅ 环境配置检查

### .env 文件
- [ ] `.env.docker` 文件已创建
- [ ] 已复制或创建 `.env` 文件
  ```bash
  cp .env.docker .env
  ```

### 关键配置验证
编辑 `.env` 检查以下项：

```env
# ✓ Flask 配置
FLASK_ENV=development
SECRET_KEY=<已设置>
JWT_SECRET_KEY=<已设置>

# ✓ 数据库
DB_HOST=mysql
DB_PORT=3306
DB_USER=xuebadict
DB_PASSWORD=123456

# ✓ Redis
REDIS_HOST=redis
REDIS_PORT=6379

# ✓ 其他配置
PAGINATION_PAGE_SIZE=20
LOG_LEVEL=INFO
```

- [ ] 所有必需的环境变量已配置
- [ ] 没有敏感信息被纳入版本控制（使用 `.env` 和 `.gitignore`）

## ✅ 数据库检查

### SQL 初始化文件
- [ ] `main.sql` 存在且包含表结构
- [ ] `add_new_tables.sql` 存在（如需要）
- [ ] `init_membership_data.sql` 存在（如需要）

### 数据库验证
```bash
# 检查文件大小
ls -lh *.sql

# 检查文件内容
head -20 main.sql
```

- [ ] SQL 文件非空
- [ ] SQL 文件包含 CREATE TABLE 语句

## ✅ 应用文件检查

### 关键应用文件
- [ ] `app.py` - Flask 应用入口
- [ ] `config.py` - 配置文件
- [ ] `requirements.txt` - Python 依赖
- [ ] `extensions.py` - Flask 扩展
- [ ] `api/` 目录 - API 路由
- [ ] `models/` 目录 - 数据库模型
- [ ] `services/` 目录 - 业务逻辑

### 字典文件
- [ ] `dict/` 目录存在
- [ ] `dict/` 目录包含词典数据

## ✅ 构建检查

### 测试镜像构建

```bash
# 构建开发版镜像
docker-compose build api

# 验证镜像
docker images | grep xuebaapi

# 检查构建日志
docker-compose build --verbose api 2>&1 | tail -50
```

- [ ] 镜像构建成功（无错误）
- [ ] 镜像大小合理（< 1GB）
- [ ] 所有依赖已正确安装

### 测试生产版镜像（可选）

```bash
# 构建生产版镜像
docker build -f Dockerfile.prod -t xuebaapi:prod .

# 检查镜像大小
docker images | grep xuebaapi
```

- [ ] 生产版镜像体积 < 开发版

## ✅ 启动检查

### 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 等待 30 秒，让服务完全启动
sleep 30

# 检查服务状态
docker-compose ps
```

验证所有容器状态：
- [ ] `mysql` - Up (healthy)
- [ ] `redis` - Up (healthy)
- [ ] `api` - Up (healthy)
- [ ] `celery_worker` - Up
- [ ] `flower` - Up

### 服务健康检查

```bash
# 检查 MySQL
docker-compose exec mysql mysql -uroot -p123456 -e "SELECT VERSION();"

# 检查 Redis
docker-compose exec redis redis-cli ping

# 检查 API
docker-compose exec api curl http://localhost:5000/health
```

- [ ] MySQL 可连接且版本正确
- [ ] Redis 响应 PONG
- [ ] API 返回健康状态 200

## ✅ API 功能验证

### 访问关键端点

```bash
# 主页
curl http://localhost:5000

# 健康检查
curl http://localhost:5000/health

# API 文档（在浏览器中打开）
# http://localhost:5000/api/docs

# 获取教材
curl http://localhost:5000/api/v1/textbooks

# 获取单词
curl "http://localhost:5000/api/v1/words/search?keyword=hello"
```

- [ ] 主页返回 200 及应用信息
- [ ] 健康检查端点返回 healthy 状态
- [ ] API 文档页面可访问
- [ ] 教材列表端点返回数据
- [ ] 搜索功能正常工作

### 数据库操作验证

```bash
# 进入数据库
docker-compose exec mysql mysql -uroot -p123456 xuebadict

# 查看表
SHOW TABLES;

# 查看用户表
SELECT COUNT(*) FROM users;

# 退出
EXIT;
```

- [ ] 数据库表已创建
- [ ] 可成功查询数据

## ✅ 日志检查

### 查看各服务日志

```bash
# API 日志
docker-compose logs --tail 50 api

# MySQL 日志
docker-compose logs --tail 20 mysql

# Redis 日志
docker-compose logs --tail 20 redis

# Celery 日志
docker-compose logs --tail 50 celery_worker
```

- [ ] API 日志无严重错误（ERROR, CRITICAL）
- [ ] MySQL 日志无错误
- [ ] Redis 日志正常
- [ ] Celery 日志正常

## ✅ 文件持久化检查

### 验证卷挂载

```bash
# 查看卷
docker volume ls | grep xuebadict

# 检查容器卷挂载
docker inspect xuebadict-mysql | grep -A 5 Mounts
```

### 验证数据持久化

```bash
# 创建测试数据
docker-compose exec mysql mysql -uroot -p123456 xuebadict -e "INSERT INTO users (username, email) VALUES ('test_user', 'test@example.com');"

# 停止容器
docker-compose stop mysql

# 启动容器
docker-compose start mysql

# 验证数据仍存在
docker-compose exec mysql mysql -uroot -p123456 xuebadict -e "SELECT * FROM users WHERE username='test_user';"
```

- [ ] 数据持久化正常工作
- [ ] 重启后数据未丢失

## ✅ 性能检查

### 资源使用情况

```bash
# 实时查看资源使用
docker stats

# 查看磁盘使用
docker system df
```

- [ ] API 内存使用 < 500MB
- [ ] MySQL 内存使用 < 1GB
- [ ] 磁盘使用在可接受范围内

### 响应时间测试

```bash
# 测试 API 响应时间
time curl http://localhost:5000/api/v1/textbooks

# 多次请求测试
for i in {1..10}; do curl -w "%{time_total}s\n" -o /dev/null -s http://localhost:5000/api/v1/textbooks; done
```

- [ ] API 响应时间 < 500ms
- [ ] 无超时错误

## ✅ 生产环境额外检查（如适用）

### 使用生产配置

```bash
# 使用生产配置启动
docker-compose -f docker-compose.prod.yml up -d

# 验证生产配置
docker-compose -f docker-compose.prod.yml ps
```

- [ ] 生产环境配置正确加载
- [ ] 所有服务正常运行

### 使用 Nginx（如适用）

```bash
# 使用 Nginx 配置启动
docker-compose -f docker-compose.nginx.yml up -d

# 检查 Nginx 状态
curl http://localhost:8080/nginx_status
```

- [ ] Nginx 启动成功
- [ ] 可通过 Nginx 访问 API
- [ ] SSL/TLS 配置正确（如已配置）

## ✅ 清理和维护检查

### 清理命令验证

```bash
# 查看容器
docker ps -a

# 查看镜像
docker images

# 查看卷
docker volume ls

# 清理测试（干运行）
docker system prune --dry-run
```

- [ ] 清理命令成功执行
- [ ] 没有意外删除重要文件

## ✅ 文档检查

- [ ] QUICKSTART_DOCKER.md 可读且有用
- [ ] DOCKER_GUIDE.md 包含完整说明
- [ ] DOCKER_FILES_SUMMARY.md 清晰易懂
- [ ] 所有命令都经过测试

## ✅ 备份和恢复检查

### 数据库备份

```bash
# 创建备份
docker-compose exec mysql mysqldump -uroot -p123456 xuebadict > backup_$(date +%Y%m%d).sql

# 检查备份文件
ls -lh backup_*.sql
```

- [ ] 备份文件已创建
- [ ] 备份文件大小合理

### 恢复测试（可选，仅用于验证）

```bash
# 注意：此操作会覆盖现有数据，仅在测试环境执行

# 恢复备份
docker-compose exec mysql mysql -uroot -p123456 xuebadict < backup_$(date +%Y%m%d).sql

# 验证恢复
docker-compose exec mysql mysql -uroot -p123456 xuebadict -e "SELECT COUNT(*) FROM users;"
```

- [ ] 恢复过程成功
- [ ] 恢复后数据完整

## 🎯 检查清单完成标记

所有检查完成后：

- [ ] 前置条件检查完成
- [ ] 文件检查完成
- [ ] 环境配置检查完成
- [ ] 数据库检查完成
- [ ] 应用文件检查完成
- [ ] 构建检查完成
- [ ] 启动检查完成
- [ ] API 功能验证完成
- [ ] 日志检查完成
- [ ] 文件持久化检查完成
- [ ] 性能检查完成
- [ ] 文档检查完成
- [ ] 备份检查完成

## 📝 签名确认

- 检查人员：_____________
- 检查日期：_____________
- 备注说明：_____________

## 🆘 常见问题快速解决

### 如果遇到问题

1. **查看错误日志**
   ```bash
   docker-compose logs --tail 100 [service_name]
   ```

2. **检查容器日志**
   ```bash
   docker logs -f [container_name]
   ```

3. **重启服务**
   ```bash
   docker-compose restart [service_name]
   ```

4. **清除并重新创建**
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

5. **查看详细信息**
   ```bash
   docker-compose config
   docker inspect [container_name]
   ```

---

**文档版本**：1.0
**创建日期**：2024 年
**维护者**：狮子英语团队
