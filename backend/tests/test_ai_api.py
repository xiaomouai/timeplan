import requests
import json
import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

BASE_URL = "http://localhost:5000/api/v1/ai"

def test_list_providers():
    print("\n--- 测试获取提供商列表 ---")
    try:
        response = requests.get(f"{BASE_URL}/providers")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"Error: {e}")

def test_chat():
    print("\n--- 测试AI聊天 (自动选择提供商) ---")
    payload = {
        "message": "你好，请介绍一下你自己。",
        "system_prompt": "你是一个幽默的助手。",
        "conversation_history": [],
        "temperature": 0.7,
        "max_tokens": 100
    }
    try:
        response = requests.post(f"{BASE_URL}/chat", json=payload)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"Error: {e}")

def test_chat_with_provider(provider):
    print(f"\n--- 测试AI聊天 (指定提供商: {provider}) ---")
    payload = {
        "message": "1+1等于几？",
        "provider": provider,
        "temperature": 0.1,
        "max_tokens": 50
    }
    try:
        response = requests.post(f"{BASE_URL}/chat", json=payload)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"Error: {e}")

def test_health_check(provider):
    print(f"\n--- 测试健康检查: {provider} ---")
    try:
        response = requests.get(f"{BASE_URL}/health/{provider}")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # 注意：运行此测试前需要启动 Flask 后端
    print("开始测试 AI API...")
    test_list_providers()
    test_chat()
    # test_chat_with_provider("qwen")
    # test_chat_with_provider("deepseek")
    # test_health_check("qwen")
    print("\n测试完成。")
