"""无外部网络的确定性 AI provider，用于本地演示和联调。"""

import json
from typing import List

from models.ai_message import ChatMessageDTO, ChatResponse, MessageRole
from .base import BaseAIProvider


class SimulatedProvider(BaseAIProvider):
    """以 qwen/deepseek provider ID 返回页面可直接消费的模拟内容。"""

    def _build_headers(self) -> dict:
        return {}

    def _build_request_body(
        self,
        messages: List[ChatMessageDTO],
        temperature: float,
        max_tokens: int,
    ) -> dict:
        return {
            "messages": [message.to_dict() for message in messages],
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

    def _parse_response(self, response_data: dict) -> str:
        content = response_data.get("content")
        if not isinstance(content, str):
            raise ValueError("模拟响应缺少 content")
        return content

    def call(
        self,
        messages: List[ChatMessageDTO],
        temperature: float = 0.7,
        max_tokens: int = 2000,
    ) -> ChatResponse:
        return ChatResponse(
            success=True,
            content=self._reply(messages),
            provider=self.provider_id,
            model=self.config.model,
        )

    def _reply(self, messages: List[ChatMessageDTO]) -> str:
        system_prompt = next(
            (
                message.content
                for message in messages
                if message.role == MessageRole.SYSTEM
            ),
            "",
        )
        user_message = next(
            (
                message.content
                for message in reversed(messages)
                if message.role == MessageRole.USER
            ),
            "",
        )

        if "recommended_expressions" in system_prompt or "只返回 JSON" in system_prompt:
            return self._knowledge_json(user_message)
        if "Training phase:" in system_prompt or "speaking coach" in system_prompt:
            return self._speaking_feedback(system_prompt)
        return f"这是 {self.name} 的模拟回复。真实模式开启后将由对应模型生成内容。"

    def _knowledge_json(self, user_message: str) -> str:
        try:
            request = json.loads(user_message)
        except (TypeError, ValueError):
            request = {}

        source = str(request.get("source_zh") or "今天的工作沟通").strip()
        scenario = str(request.get("scenario_zh") or "工作沟通").strip()
        focus_word = str(request.get("focus_word") or "").strip()
        target_word = focus_word or self._target_for_scenario(scenario)
        return json.dumps(
            {
                "source_zh": source,
                "target_word": target_word,
                "meaning_zh": f"在{scenario}中自然表达重点、细节和下一步。",
                "part_of_speech": "phrasal verb" if " " in target_word else "verb",
                "pronunciation": "/ˈfɑːloʊ ʌp/",
                "recommended_expressions": [
                    "I’d like to follow up on this matter.",
                    "Could you let me know if you have any questions?",
                ],
                "intent_structure_zh": [
                    "先说明联系或表达的目的。",
                    "补充一个关键事实、细节或限制。",
                    "明确希望对方完成的下一步。",
                ],
                "opening_line": "I wanted to follow up on the quotation we sent.",
                "fallback_line": "If you need more time, I’m happy to answer any questions.",
                "collocations": [
                    "follow up on a quote",
                    "follow up with a client",
                    "a follow-up email",
                ],
                "example_sentences": [
                    "I’m following up on the quote we shared last week.",
                    "Please let me know if you need any additional information.",
                ],
                "grammar_notes_zh": [
                    "follow up on 后面接要跟进的事情。",
                    "Could you let me know if... 比直接说 Tell me 更礼貌。",
                ],
                "scenarios": [
                    "Follow up with a client by email",
                    "Clarify the next step during a client call",
                ],
                "speaking_prompts_zh": [
                    f"请先用英文说明你想在“{scenario}”中解决什么问题。",
                    "请补充一个具体事实、时间或限制。",
                    "请明确询问对方的下一步决定或行动。",
                ],
                "short_article": (
                    "A clear follow-up message helps a conversation move forward. "
                    "Start by explaining why you are contacting the other person. "
                    "Then add one useful detail, such as a deadline, a price, or a delivery update. "
                    "Finish with a simple question or a specific next step. "
                    "This structure sounds professional without making the message too formal."
                ),
                "speech": (
                    "Today I’d like to follow up on our recent discussion. "
                    "I want to make sure we have the same understanding of the key details. "
                    "If anything is unclear, I’m happy to explain it. "
                    "Could you let me know what the next step should be and when we can expect a decision?"
                ),
            },
            ensure_ascii=False,
        )

    @staticmethod
    def _target_for_scenario(scenario: str) -> str:
        targets = (
            ("报价", "follow up"),
            ("需求", "clarify"),
            ("价格", "negotiate"),
            ("交期", "handle a delay"),
            ("会议", "give an update"),
            ("升级", "escalate"),
            ("问题", "escalate"),
        )
        for keyword, target in targets:
            if keyword in scenario:
                return target
        return "follow up"

    def _speaking_feedback(self, system_prompt: str) -> str:
        if "retry after feedback" in system_prompt:
            return (
                "这次表达更清楚了。你已经补充了关键信息，当前场景可以通过。"
                "自然表达：I’d like to follow up on this matter and confirm the next step."
                "现在进入下一个工作场景。"
            )
        return (
            "先肯定一点：你已经表达了核心意图。"
            "主要改进：把目的、一个具体细节和下一步按顺序说清楚。"
            "更自然的说法：I’d like to follow up on this matter."
            "请重说一次，并补充一个具体细节。"
        )
