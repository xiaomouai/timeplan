# Windows 本地启动

## 一键启动

前置条件：安装 Python 3.11 或更高版本，并勾选 `Add python.exe to PATH`。

在资源管理器中双击：

```text
xuebadictApp\xuebaApi\start_local_windows.bat
```

脚本会自动完成：

1. 创建 `.venv` 虚拟环境；
2. 从 `.env.example` 创建本机 `.env`；
3. 安装 `requirements.txt`；
4. 使用 SQLite 和模拟 AI 启动 Flask API。

脚本会自动切换到自身所在目录，因此不要求从特定命令行目录运行。

## 命令行启动

```bat
cd /d E:\your-path\englistapp\xuebadictApp\xuebaApi
start_local_windows.bat
```

如果依赖有更新，删除本机文件 `.venv\.requirements-installed` 后重新启动即可。

## 本地地址

```text
健康检查：http://localhost:5000/health
API 文档：http://localhost:5000/api/docs
Swagger JSON：http://localhost:5000/apispec.json
```

默认配置不需要 MySQL、Redis、千问或 DeepSeek 密钥，适合先联调 Flutter 页面和 API 闭环。

## 切换真实服务

只编辑本机的 `xuebadictApp\xuebaApi\.env`，不要提交 `.env`：

```dotenv
AI_MODE=live
AI_SIMULATION=false
QWEN_API_KEY=你的千问密钥
QWEN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
DEEPSEEK_API_KEY=你的DeepSeek密钥
DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
```

使用 MySQL 时，把 `SQLALCHEMY_DATABASE_URI` 换成真实连接串，并确认数据库已创建。

## 常见问题

- `Python was not found`：重新安装 Python，并勾选加入 PATH；重新打开命令行。
- `Address already in use`：修改 `.env` 中的 `PORT`，然后用新端口访问地址。
- 数据库创建失败：本地模式先保持 SQLite；接 MySQL 时检查服务、库名和连接串。
- 依赖安装失败：确认网络可访问 PyPI，或在已配置镜像的终端重新运行脚本。
