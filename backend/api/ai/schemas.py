"""
AI模块请求与响应 Schema (基于 marshmallow)

职责：
- 定义请求参数的结构和校验规则
- 定义响应数据的序列化格式
"""

from marshmallow import Schema, fields, validate, post_load
from models.ai_message import ChatMessageDTO, MessageRole


class ChatMessageSchema(Schema):
    """单条消息校验"""

    role = fields.String(
        required=True, validate=validate.OneOf([r.value for r in MessageRole])
    )
    content = fields.String(required=True, validate=validate.Length(min=1))

    @post_load
    def make_dto(self, data, **kwargs):
        return ChatMessageDTO.from_dict(data)


class ChatRequestSchema(Schema):
    """聊天请求校验"""

    message = fields.String(required=True, validate=validate.Length(min=1, max=10000))
    system_prompt = fields.String(load_default=None, allow_none=True)
    history = fields.List(
        fields.Nested(ChatMessageSchema),
        load_default=list,
        data_key="conversation_history",
        allow_none=True,
    )
    temperature = fields.Float(
        validate=validate.Range(min=0.0, max=1.0),
        load_default=0.7,
        allow_none=True,
    )
    max_tokens = fields.Int(
        validate=validate.Range(min=1, max=8000),
        load_default=2000,
        allow_none=True,
    )
    provider = fields.String(load_default=None, allow_none=True)
    chat_type = fields.String(load_default=None, allow_none=True)


class SpeechRequestSchema(Schema):
    """语音识别请求校验"""

    # 语音文件通常在 request.files 中，此处校验其他元数据
    # 如果需要校验文件名等，可在此添加
    pass


# 预实例化以便复用
chat_request_schema = ChatRequestSchema()
speech_request_schema = SpeechRequestSchema()
