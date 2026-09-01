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
B=http://127.0.0.1:5055/api/v1/health

echo ">>> start server"
$PY app.py > /tmp/xuebaApi_run/server.log 2>&1 &
SRV=$!
echo "server pid=$SRV"
sleep 7

echo "=== 1) bootstrap ==="
BOOT=$(curl -s -X POST $B/bootstrap -H "Content-Type: application/json" -d '{"client_id":"test_device_001","nickname":"测试用户"}')
echo "$BOOT" | head -c 700; echo ""
TOKEN=$(echo "$BOOT" | $PY -c "import sys,json;d=json.load(sys.stdin);print(d.get('data',{}).get('token',''))" 2>/dev/null)
echo "TOKEN_LEN=${#TOKEN}"

echo "=== 2) habits count ==="
curl -s $B/habits -H "Authorization: Bearer $TOKEN" | $PY -c "import sys,json;d=json.load(sys.stdin);print('habits count:',len(d.get('data',{}).get('habits',[])))"

echo "=== 3) checkin ==="
curl -s -X POST $B/checkin -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"log_date":"2026-08-31","entries":[{"habit_key":"sleep","value":7.6,"done":true},{"habit_key":"break","value":6,"done":true},{"habit_key":"diet","value":65,"done":true}]}' | head -c 400; echo ""

echo "=== 4) dashboard ==="
curl -s $B/dashboard -H "Authorization: Bearer $TOKEN" | $PY -c "import sys,json;d=json.load(sys.stdin);dd=d.get('data',{});print('phase:',dd.get('phase'),'streak:',dd.get('streak'),'items:',len(dd.get('items',[])))"

echo "=== 5) plan/generate (REAL DeepSeek) ==="
curl -s --max-time 90 -X POST $B/plan/generate -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"period":"daily"}' | $PY -c "import sys,json;d=json.load(sys.stdin);print('success:',d.get('success'));dd=d.get('data',{});print('plan summary:',(dd.get('plan') or {}).get('summary'));print('parsed focus:',(dd.get('parsed') or {}).get('focus'));print('error:',dd.get('error'))" 2>&1 | head -c 800; echo ""

echo "=== 6) plan list ==="
curl -s $B/plan -H "Authorization: Bearer $TOKEN" | $PY -c "import sys,json;d=json.load(sys.stdin);print('plans:',len(d.get('data',{}).get('plans',[])))"

echo "=== 7) coach (REAL DeepSeek) ==="
curl -s --max-time 90 -X POST $B/coach -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"message":"我昨晚只睡了6小时，今天怎么补？"}' | $PY -c "import sys,json;d=json.load(sys.stdin);print('success:',d.get('success'));print('content:',(d.get('data',{}) or {}).get('content'));print('error:',(d.get('data',{}) or {}).get('error'))" 2>&1 | head -c 600; echo ""

echo "=== 8) agents registry ==="
curl -s http://127.0.0.1:5055/api/v1/agents/registry | $PY -c "import sys,json;d=json.load(sys.stdin);print('registry tasks:',len(d.get('data',{}).get('tasks',[])))"

echo ">>> stop server"
kill $SRV 2>/dev/null
echo "DONE"
