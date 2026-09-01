"""
语音识别服务

封装对第三方语音转文字API的调用。
"""

import logging
import requests
import os
from typing import Optional
from exceptions.ai_exceptions import SpeechRecognitionError

logger = logging.getLogger(__name__)


def recognize_speech(audio_file_path: str) -> str:
    """
    语音转文字

    Args:
        audio_file_path: 音频文件路径

    Returns:
        识别出的文字内容

    Raises:
        SpeechRecognitionError: 识别过程发生错误
    """
    api_url = os.getenv("SPEECH_API_URL")
    api_key = os.getenv("SPEECH_API_KEY")

    if not api_url or not api_key:
        logger.error("未配置语音识别API (SPEECH_API_URL / SPEECH_API_KEY)")
        raise SpeechRecognitionError("服务器未配置语音识别服务")

    if not os.path.exists(audio_file_path):
        raise SpeechRecognitionError(f"音频文件不存在: {audio_file_path}")

    try:
        logger.info(f"正在识别语音: {audio_file_path}")
        with open(audio_file_path, "rb") as audio_file:
            files = {"file": (os.path.basename(audio_file_path), audio_file, "audio/mpeg")}
            headers = {"Authorization": f"Bearer {api_key}"}

            response = requests.post(api_url, files=files, headers=headers, timeout=60)

            if response.status_code != 200:
                logger.error(f"语音识别API返回错误: {response.status_code} - {response.text}")
                raise SpeechRecognitionError(f"API返回 HTTP {response.status_code}")

            data = response.json()
            text = data.get("text") or data.get("result")

            if not text:
                logger.warning("语音识别成功但结果为空")
                return ""

            logger.info(f"语音识别成功: {text[:50]}...")
            return text

    except Exception as e:
        logger.exception("语音识别过程发生异常")
        raise SpeechRecognitionError(f"识别失败: {str(e)}")
