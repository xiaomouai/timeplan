#!/bin/bash
# Docker 启动脚本 - 狮子英语 API

echo "========================================"
echo "狮子英语 API - Docker 启动脚本"
echo "========================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "[错误] Docker 未安装"
    echo "请访问 https://www.docker.com/products/docker-desktop 下载安装"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "[错误] Docker Compose 未安装"
    echo "请确保 Docker 已正确安装 Docker Compose"
    exit 1
fi

echo "[✓] Docker 和 Docker Compose 环境检查完成"
echo ""

# 检查 .env 文件是否存在
if [ ! -f ".env" ]; then
    echo "[提示] .env 文件不存在"
    read -p "是否使用默认配置创建 .env 文件？(y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp .env.docker .env
        echo "[✓] .env 文件已创建（请根据实际需求修改配置）"
        echo ""
    fi
else
    echo "[✓] .env 文件存在"
    echo ""
fi

# 显示菜单
show_menu() {
    echo "选择操作:"
    echo "  1) 启动所有服务"
    echo "  2) 停止所有服务"
    echo "  3) 查看服务状态"
    echo "  4) 查看 API 日志"
    echo "  5) 进入 API 容器"
    echo "  6) 连接到 MySQL 数据库"
    echo "  7) 重建镜像并启动"
    echo "  8) 停止并删除所有数据"
    echo "  9) 查看完整配置"
    echo "  0) 退出"
    echo ""
}

# 菜单循环
while true; do
    show_menu
    read -p "请选择 (0-9): " choice
    echo ""
    
    case $choice in
        1)
            echo "[启动] 启动所有服务..."
            docker-compose up -d
            echo "[✓] 服务启动完成！"
            echo ""
            echo "关键地址:"
            echo "  API 主服务: http://localhost:5000"
            echo "  API 文档:  http://localhost:5000/api/docs"
            echo "  健康检查: http://localhost:5000/health"
            echo "  Flower:   http://localhost:5555"
            echo ""
            ;;
        2)
            echo "[停止] 停止所有服务..."
            docker-compose down
            echo "[✓] 服务已停止"
            echo ""
            ;;
        3)
            echo "[状态] 查看服务状态..."
            docker-compose ps
            echo ""
            ;;
        4)
            echo "[日志] 查看 API 日志（按 Ctrl+C 退出）..."
            docker-compose logs -f --tail 100 api
            echo ""
            ;;
        5)
            echo "[Shell] 进入 API 容器..."
            docker-compose exec api bash
            echo ""
            ;;
        6)
            echo "[数据库] 连接到 MySQL..."
            DB_PASS=$(grep '^DB_PASSWORD=' .env | cut -d '=' -f2)
            docker-compose exec mysql mysql -uroot -p"$DB_PASS" xuebadict
            echo ""
            ;;
        7)
            echo "[构建] 重建镜像并启动..."
            docker-compose build
            docker-compose up -d
            echo "[✓] 构建和启动完成！"
            echo ""
            ;;
        8)
            echo "[警告] 此操作将删除所有数据"
            read -p "确认继续吗？(y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[删除] 停止并删除所有服务和数据..."
                docker-compose down -v
                echo "[✓] 所有服务和数据已删除"
                echo ""
            else
                echo "[取消] 操作已取消"
                echo ""
            fi
            ;;
        9)
            echo "[配置] 查看完整配置..."
            docker-compose config
            echo ""
            ;;
        0)
            echo "退出"
            exit 0
            ;;
        *)
            echo "[错误] 无效选择，请重新选择"
            echo ""
            ;;
    esac
done
