# timePlan

AI 时间规划助手。Flutter 前端 + Flask 真实 LLM 后端，全部接口走真实动态后端 API 与真实大模型（千问 / DeepSeek 自动降级），**无 mock 数据**。

## 仓库结构

- `frontend/` — Flutter 3.47 Web / 移动端应用（计划表、健康底座、AI 生成计划、语音输入）
- `backend/` — Flask + SQLAlchemy 后端 API（`ProviderManager` 抽象 AI 层，真实 LLM 驱动 decompose / plan / coach）

## 快速开始

### 后端
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env        # 填入 QWEN / DEEPSEEK 密钥
python app.py               # 默认 http://127.0.0.1:5055
```

### 前端
```bash
cd frontend
flutter pub get
flutter run -d chrome       # 或 flutter build web
```

前端通过 `lib/services/planner_api.dart` 等调用后端；AI 模型配置收归后端 `.env`，前端不暴露密钥。
