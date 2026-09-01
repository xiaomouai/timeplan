@echo off
REM Docker 启动脚本 - 狮子英语 API

echo ========================================
echo 狮子英语 API - Docker 启动脚本
echo ========================================
echo.

REM 检查 Docker 是否安装
docker --version >nul 2>&1
if errorlevel 1 (
    echo [错误] Docker 未安装或未在 PATH 中
    echo 请访问 https://www.docker.com/products/docker-desktop 下载安装
    pause
    exit /b 1
)

REM 检查 Docker Compose 是否安装
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [错误] Docker Compose 未安装
    echo 请确保 Docker Desktop 已安装（包含 Docker Compose）
    pause
    exit /b 1
)

echo [✓] Docker 和 Docker Compose 环境检查完成
echo.

REM 检查 .env 文件是否存在
if not exist ".env" (
    echo [提示] .env 文件不存在
    echo 是否使用默认配置创建 .env 文件？
    echo.
    choice /C YN /M "选择 (Y/N): "
    if errorlevel 2 goto :skip_env
    if errorlevel 1 (
        copy .env.docker .env >nul
        echo [✓] .env 文件已创建（请根据实际需求修改配置）
        echo.
    )
) else (
    echo [✓] .env 文件存在
    echo.
)

:skip_env
echo 选择操作:
echo 1. 启动所有服务 (up -d)
echo 2. 停止所有服务 (down)
echo 3. 查看服务状态 (ps)
echo 4. 查看 API 日志 (logs)
echo 5. 进入 API 容器 (bash)
echo 6. 连接到 MySQL 数据库 (mysql)
echo 7. 重建镜像并启动 (build + up -d)
echo 8. 停止并删除所有数据 (down -v)
echo 9. 查看完整配置 (config)
echo 0. 退出
echo.
choice /C 0123456789 /M "请选择 (0-9): "

if errorlevel 10 goto :end
if errorlevel 9 goto :config
if errorlevel 8 goto :down_v
if errorlevel 7 goto :build_up
if errorlevel 6 goto :mysql
if errorlevel 5 goto :bash
if errorlevel 4 goto :logs
if errorlevel 3 goto :ps
if errorlevel 2 goto :down
if errorlevel 1 goto :up
goto :end

:up
echo.
echo [启动] 启动所有服务...
docker-compose up -d
echo [✓] 服务启动完成！
echo.
echo 关键地址:
echo   API 主服务: http://localhost:5000
echo   API 文档:  http://localhost:5000/api/docs
echo   健康检查: http://localhost:5000/health
echo   Flower:   http://localhost:5555
echo.
goto :end

:down
echo.
echo [停止] 停止所有服务...
docker-compose down
echo [✓] 服务已停止
echo.
goto :end

:ps
echo.
echo [状态] 查看服务状态...
docker-compose ps
echo.
goto :end

:logs
echo.
echo [日志] 查看 API 日志（按 Ctrl+C 退出）...
docker-compose logs -f --tail 100 api
echo.
goto :end

:bash
echo.
echo [Shell] 进入 API 容器...
docker-compose exec api bash
echo.
goto :end

:mysql
echo.
echo [数据库] 连接到 MySQL...
for /f "tokens=2" %%a in ('.env ^| findstr /B DB_PASSWORD') do set DB_PASS=%%a
docker-compose exec mysql mysql -uroot -p%DB_PASS% xuebadict
echo.
goto :end

:build_up
echo.
echo [构建] 重建镜像并启动...
docker-compose build
docker-compose up -d
echo [✓] 构建和启动完成！
echo.
goto :end

:down_v
echo.
echo [警告] 此操作将删除所有数据，确认继续吗？
choice /C YN /M "选择 (Y/N): "
if errorlevel 2 (
    echo [取消] 操作已取消
    goto :end
)
if errorlevel 1 (
    echo [删除] 停止并删除所有服务和数据...
    docker-compose down -v
    echo [✓] 所有服务和数据已删除
    echo.
)
goto :end

:config
echo.
echo [配置] 查看完整配置...
docker-compose config
echo.
goto :end

:end
echo.
echo ========================================
pause
