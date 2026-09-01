#!/bin/bash
set -e
cd /tmp/xuebaApi_run
export no_proxy="127.0.0.1,localhost"; export NO_PROXY="127.0.0.1,localhost"
export SQLALCHEMY_DATABASE_URI="sqlite:///health_dev.db"
export AUTO_CREATE_DB=false
export FLASK_DEBUG=false
export FLASK_ENV=development
export PORT=5055
export CORS_ORIGINS="http://127.0.0.1:5055,http://localhost:5055"

PY=/Users/wangliyan/.workbuddy/binaries/python/envs/default/bin/python
A=http://127.0.0.1:5055/api/v1/agents

$PY app.py > /tmp/xuebaApi_run/server.log 2>&1 &
SRV=$!
echo "server pid=$SRV"; sleep 7

echo "=== create TASK-20260831-004 ==="
curl -s -X POST $A/tasks -H "Content-Type: application/json" -d '{
  "id":"TASK-20260831-004",
  "title":"健康产品与多 Agent 框架后端化 + AI 化",
  "goal":"把健康计划产品与多 Agent 写作框架全部改为动态后端 API + LLM 真实生成，彻底去除本地模拟/hardcode 数据",
  "scope":"Flutter 健康页 + HTML 计划表 + 多 Agent 任务框架，全部接 xuebaApi 动态后端；AI 计划由 DeepSeek 真实生成",
  "owner":"Coordinator",
  "status":"completed"
}' | head -c 300; echo ""

echo "=== append logs (start/progress/finish) ==="
curl -s -X POST $A/tasks/TASK-20260831-004/logs -H "Content-Type: application/json" -d '{"node":"start","actor":"Coordinator","content":"立项：确认后端归属 xuebaApi、AI 用 LLM 动态生成、范围含健康产品+多Agent框架"}' | head -c 120; echo ""
curl -s -X POST $A/tasks/TASK-20260831-004/logs -H "Content-Type: application/json" -d '{"node":"progress","actor":"Implementer","content":"建 health_models/agent_models、health_service/health_ai_service/agent_service、api/health+agents 蓝图；AI 调用真实 DeepSeek，失败即报错不回退模拟"}' | head -c 120; echo ""
curl -s -X POST $A/tasks/TASK-20260831-004/logs -H "Content-Type: application/json" -d '{"node":"finish","actor":"Coordinator","content":"本地 SQLite 起服验证：bootstrap/habits/checkin/dashboard/plan(generate 真实AI)/coach/agents 全链路通过"}' | head -c 120; echo ""

echo "=== upsert result ==="
curl -s -X POST $A/tasks/TASK-20260831-004/result -H "Content-Type: application/json" -d '{
  "receipt":"健康产品与多 Agent 框架已完全后端化/AI 化，零模拟数据，本地 SQLite 验证全链路通过",
  "acceptance":"curl 验证 bootstrap/habits/checkin/dashboard/plan/generate(真实DeepSeek)/coach/agents 均返回真实数据",
  "changed_files":"api/health.py(新建), services/health_ai_service.py(重写+异常兜底), services/health_service.py(新建), models/health_models.py(新建), models/agent_models.py(新建), services/agent_service.py(新建), api/agents.py(新建), config.py(本地路径运算修复)",
  "boundary":"生产 .env 仍指向 MySQL；本机验证用 SQLite。DeepSeek key 在 .env 已配置。Flutter/HTML 客户端需在 5000 端口或对应 CORS 下联调",
  "next_steps":"把新文件同步回真实工程目录；Flutter health_api/health_store 联调；HTML 页面接入；生产部署改用 MySQL+迁移"
}' | head -c 300; echo ""

echo "=== registry ==="
curl -s $A/registry | $PY -c "import sys,json;d=json.load(sys.stdin);ts=d.get('data',{}).get('tasks',[]);print('registry tasks:',len(ts));[print(' -',t.get('id'),t.get('status'),t.get('title')) for t in ts]"

echo "=== task detail (with logs+result) ==="
curl -s $A/tasks/TASK-20260831-004 | $PY -c "import sys,json;d=json.load(sys.stdin)['data'];print('logs:',len(d.get('logs',[])),'has_result:',bool(d.get('result')))"

kill $SRV 2>/dev/null
echo "DONE"
