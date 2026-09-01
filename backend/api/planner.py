"""
计划分解 API：调用真实 LLM（经 ProviderManager，qwen/deepseek 自动降级）把自然语言待办
拆解为结构化任务。前端首页"生成计划"走此端点，确保是真实 AI 数据而非本地模拟。

绝不回退模拟数据：provider 全部不可用时明确返回 error。
"""
import json
import logging

from flask import Blueprint, request

from utils.response import success_response, error_response
import services.ai_chat_service as ai_chat_service
from services.ai_config import ai_config

logger = logging.getLogger(__name__)
bp = Blueprint("planner", __name__)

_SYSTEM = """你是时间规划 Agent。用户会给你一段他说出的待办描述（可能来自语音转写，口语化、无标点）。
请把描述拆解为今天可执行的多个具体任务，并给出建议时长（分钟）与优先级。
只输出 JSON 数组，不要输出任何解释、markdown 代码块或其他文字。格式：
[{"title":"任务名（简洁祈使句）","minutes":30,"priority":"high|medium|low"}]
规则：
1. 任务 3~8 个，单个任务 15~120 分钟；
2. 模糊描述要具体化为可执行动作（如"背东西"→"背 50 个单词"）；
3. priority 依据紧急/重要程度判断，无明确线索用 medium；
4. 只能拆解用户输入中提到的事项，禁止添加输入中未提及的新任务。
5. minutes 必须为整数，priority 只能是 high/medium/low。"""


def _extract_json_array(text):
    try:
        s = text.index("[")
        e = text.rindex("]") + 1
        return text[s:e]
    except Exception:
        return None


@bp.route("/decompose", methods=["POST"])
def decompose():
    data = request.get_json(silent=True) or {}
    text = (data.get("text") or data.get("input") or "").strip()
    if not text:
        return error_response("请输入要做的事", code=400)

    resp = ai_chat_service.chat(
        message=text,
        system_prompt=_SYSTEM,
        preferred_provider=ai_config.default_provider,
        temperature=0.5,
        max_tokens=1500,
    )
    if resp is None or not getattr(resp, "success", False):
        err = getattr(resp, "error", None) if resp else "AI 服务无响应"
        logger.error("计划分解失败: %s", err)
        return error_response(err or "AI 返回失败", code=502)

    raw = resp.content or ""
    arr = _extract_json_array(raw)
    if not arr:
        return error_response("AI 未返回合法任务数组", code=502)
    try:
        tasks = json.loads(arr)
    except Exception as e:
        logger.error("计划分解解析失败: %s", e)
        return error_response("AI 返回解析失败", code=502)
    if not isinstance(tasks, list) or not tasks:
        return error_response("AI 未返回有效任务", code=502)

    out = []
    for t in tasks:
        if not isinstance(t, dict):
            continue
        title = (t.get("title") or "").strip()
        if not title:
            continue
        try:
            minutes = int(t.get("minutes") or 30)
        except Exception:
            minutes = 30
        minutes = max(10, min(120, minutes))
        pri = str(t.get("priority", "medium")).lower()
        if pri not in ("high", "medium", "low"):
            pri = "medium"
        out.append({"title": title, "minutes": minutes, "priority": pri})

    if not out:
        return error_response("AI 未返回有效任务", code=502)

    return success_response(
        {"tasks": out, "provider": getattr(resp, "provider", None)},
        msg="generated",
    )
