# 狮子英语 API - Docker 镜像
# 基础镜像：Python 3.11 slim版本，更轻量级
FROM python:3.11-slim

# 工作目录
WORKDIR /app

# 设置Python路径，确保可以正确导入模块
ENV PYTHONPATH=/app:$PYTHONPATH
ENV PYTHONUNBUFFERED=1

# 安装系统依赖（git, gcc等编译工具）
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    libmariadb-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制项目代码
COPY . .

# 创建必要目录
RUN mkdir -p logs uploads data

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 启动应用
CMD ["python", "-u", "app.py"]
