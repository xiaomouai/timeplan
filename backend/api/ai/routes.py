"""
AI 模块路由定义

职责：
- 定义API端点
- 解析请求参数（使用 Schemas）
- 调用 Service 层处理业务
- 统一异常处理和响应格式
"""

import os
import uuid
import logging
from flask import Blueprint, request, current_app, jsonify
from marshmallow import ValidationError

from utils.response import success_response, error_response
from exceptions.ai_exceptions import AIBaseException, InvalidRequestError
import services.ai_chat_service as ai_chat_service
import services.speech_service as speech_service
from services.prompts import (
    get_prompt,
    get_all_scenes,
    get_scene_config,
    get_version,
    reload as reload_prompts_config,
)
from .schemas import chat_request_schema

logger = logging.getLogger(__name__)

# 创建子蓝图
ai_bp = Blueprint("ai", __name__)


@ai_bp.app_errorhandler(AIBaseException)
def handle_ai_exception(e):
    """全局处理AI模块自定义异常"""
    logger.error(f"AI模块异常: {e.message} - {e.detail}")
    return error_response(message=e.message, code=e.status_code, data={"detail": e.detail})


@ai_bp.route("/chat", methods=["POST"])
def chat():
    """
    AI 聊天接口
    POST /api/v1/ai/chat
    """
    try:
        # 1. 校验请求参数
        json_data = request.get_json()
        if not json_data:
            raise InvalidRequestError("缺少请求体")

        data = chat_request_schema.load(json_data)

        # 2. 自动注入提示词逻辑
        chat_type = data.get("chat_type")
        system_prompt = data.get("system_prompt")
        temperature = data.get("temperature")
        max_tokens = data.get("max_tokens")

        # 设置默认值（如果参数为 None）
        if temperature is None: temperature = 0.7
        if max_tokens is None: max_tokens = 2000

        if chat_type and not system_prompt:
            try:
                scene_config = get_scene_config(chat_type)
                system_prompt = scene_config["prompt"]
                # 如果用户未显式设置参数，则使用场景默认值
                if "temperature" not in json_data:
                    temperature = scene_config["temperature"]
                if "max_tokens" not in json_data:
                    max_tokens = scene_config["max_tokens"]
            except KeyError:
                logger.warning(f"未知的聊天场景类型: {chat_type}")

        # 3. 调用服务层
        result = ai_chat_service.chat(
            message=data["message"],
            system_prompt=system_prompt,
            conversation_history=data.get("history"),
            temperature=temperature,
            max_tokens=max_tokens,
            preferred_provider=data.get("provider"),
        )

        # 3. 返回结果
        if result.success:
            return success_response(data=result.to_dict())
        else:
            return error_response(message=result.error)

    except ValidationError as err:
        logger.warning(f"AI聊天参数校验失败: {err.messages}, 请求数据: {json_data}")
        return error_response(message="参数验证失败", data=err.messages, code=400)


@ai_bp.route("/providers", methods=["GET"])
def list_providers():
    """
    获取可用AI提供商列表
    GET /api/v1/ai/providers
    """
    providers = ai_chat_service.get_providers()
    return success_response(data={"providers": providers})


@ai_bp.route("/health/<provider_id>", methods=["GET"])
def health_check(provider_id):
    """
    指定提供商健康检查
    GET /api/v1/ai/health/<provider_id>
    """
    result = ai_chat_service.check_provider_health(provider_id)
    return success_response(data=result)


@ai_bp.route("/scenes", methods=["GET"])
def list_scenes():
    """
    获取所有可用的聊天场景
    GET /api/v1/ai/scenes
    """
    return success_response({
        "version": get_version(),
        "scenes": get_all_scenes(),
    })


@ai_bp.route("/scenes/<scene_id>", methods=["GET"])
def get_scene(scene_id: str):
    """获取指定场景的完整配置（含提示词）"""
    try:
        config = get_scene_config(scene_id)
        return success_response(config)
    except KeyError:
        raise InvalidRequestError(detail=f"未知的场景: '{scene_id}'")


@ai_bp.route("/prompts/reload", methods=["POST"])
def reload_prompts():
    """热重载提示词配置"""
    reload_prompts_config()
    return success_response({
        "version": get_version(),
        "scenes": list(get_all_scenes().keys()),
        "message": "提示词配置已重载",
    })


@ai_bp.route("/speech", methods=["POST"])
def speech_to_text():
    """
    语音转文字接口
    POST /api/v1/ai/speech
    """
    if "file" not in request.files:
        return error_response(message="未上传音频文件", code=400)

    audio_file = request.files["file"]
    if audio_file.filename == "":
        return error_response(message="文件名为空", code=400)

    # 保存临时文件
    temp_dir = os.path.join(current_app.root_path, "temp", "audio")
    os.makedirs(temp_dir, exist_ok=True)

    file_ext = os.path.splitext(audio_file.filename)[1] or ".mp3"
    temp_filename = f"{uuid.uuid4()}{file_ext}"
    temp_path = os.path.join(temp_dir, temp_filename)

    try:
        audio_file.save(temp_path)

        # 调用服务层
        text = speech_service.recognize_speech(temp_path)

        return success_response(data={"text": text})

    finally:
        # 清理临时文件
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as e:
                logger.warning(f"无法删除临时文件 {temp_path}: {e}")
