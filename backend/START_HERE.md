# 🚀 从这里开始

欢迎使用狮子英语 API Docker 部署配置！

这是最快的入门指南。

## ⚡ 30 秒快速启动

### Windows 用户
```bash
docker-start.bat
```
→ 选择菜单选项 `1` → 等待服务启动完成

### macOS/Linux 用户
```bash
chmod +x docker-start.sh
./docker-start.sh
```
→ 选择菜单选项 `1` → 等待服务启动完成

### 或使用命令行
```bash
docker-compose up -d
```

## ✅ 验证成功

启动后，打开浏览器访问：

**http://localhost:5000/api/docs**

如果看到 Swagger 交互式 API 文档页面，说明部署成功！ 🎉

## 🔍 其他检查

```bash
# 查看所有服务状态
docker-compose ps

# 查看实时日志
docker-compose logs -f api

# 测试 API 连接
curl http://localhost:5000/health
```

## 📚 深入了解

| 想了解什么 | 阅读哪个文件 | 用时 |
|----------|-----------|-----|
| 各文件用途 | README_DOCKER.md | 5 分钟 |
| 常用命令 | QUICKSTART_DOCKER.md | 5 分钟 |
| 完整指南 | DOCKER_GUIDE.md | 20 分钟 |
| 技术细节 | DOCKER_FILES_SUMMARY.md | 10 分钟 |
| 部署检查 | DOCKER_CHECKLIST.md | 15 分钟 |

## 🔧 常用操作

### 查看日志
```bash
docker-compose logs -f api
```

### 进入容器
```bash
docker-compose exec api bash
```

### 停止服务
```bash
docker-compose down
```

### 重启服务
```bash
docker-compose restart
```

## 🎯 主要服务地址

| 服务 | 地址 |
|------|------|
| API 主页 | http://localhost:5000 |
| API 文档 | http://localhost:5000/api/docs |
| 健康检查 | http://localhost:5000/health |
| Flower 监控 | http://localhost:5555 |

## ❓ 遇到问题？

### 问题 1：容器无法启动
```bash
docker-compose logs api  # 查看错误
```

### 问题 2：端口被占用
编辑 `docker-compose.yml`，修改 `5000:5000` 为 `5001:5000`

### 问题 3：需要更详细的帮助
查看 `DOCKER_GUIDE.md` 的"故障排除"章节

## 📋 生成的文件

所有文件都已在当前目录中：

```
✓ Dockerfile (开发版镜像)
✓ Dockerfile.prod (生产版镜像)
✓ docker-compose.yml (标准配置)
✓ docker-compose.prod.yml (生产配置)
✓ docker-compose.nginx.yml (Nginx 配置)
✓ docker-start.bat (Windows 脚本)
✓ docker-start.sh (Linux/macOS 脚本)
✓ .env.docker (环境配置模板)
✓ 5 个详细文档文件
```

总计 16 个文件，完整的 Docker 部署方案！

## 🎓 学习路径

```
1. 现在          ← 你在这里
   ↓
2. 运行启动脚本或 docker-compose up -d
   ↓
3. 打开 http://localhost:5000/api/docs
   ↓
4. 根据需要阅读其他文档
   ↓
5. 部署到生产环境
```

## 🚢 生产环境

准备上线？遵循这 3 步：

1. **修改配置**
   ```bash
   # 编辑 .env 文件
   # 修改 SECRET_KEY、DB_PASSWORD 等敏感信息
   ```

2. **使用生产配置**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. **运行检查清单**
   ```
   查看 DOCKER_CHECKLIST.md
   ```

## 📊 架构一览

```
浏览器 → API (5000) → MySQL (3306)
              ↓
             Redis (6379)
              ↓
          Celery Worker
              ↓
           Flower (5555)
```

## 🎉 准备好了吗？


docker exec -i xuebadict-mysql sh -c "mysql -uxuebadict -p123456 xuebadict < /tmp/xuebadict.sql"


**立即启动**：
```bash
docker-compose up -d
```

**查看状态**：
```bash
docker-compose ps
```

**访问 API**：
http://localhost:5000/api/docs

---

**需要帮助？** 查看 `README_DOCKER.md`

**想了解更多？** 查看 `DOCKER_GUIDE.md`

**快速参考？** 查看 `QUICKSTART_DOCKER.md`

---

祝您使用愉快！ 🚀
