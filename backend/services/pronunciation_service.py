"""
发音评测业务编排服务

职责：
- 接收音频数据
- 调用语音识别引擎
- 与预期发音对比
- 生成评分和反馈
"""

import os
import logging
import tempfile
import speech_recognition as sr
from typing import Optional, List, Dict, Any

from models.evaluation_models import PronunciationResult, SyllableScore, ScoreLevel
from models.syllable_models import WordSyllableInfo
from services.syllable_service import analyze_word

logger = logging.getLogger(__name__)


def evaluate_pronunciation(
    word: str,
    audio_path: str,
) -> PronunciationResult:
    """
    评测发音

    Args:
        word: 目标单词
        audio_path: 音频文件路径

    Returns:
        PronunciationResult 评测结果
    """
    word = word.strip().lower()
    logger.info(f"[PronunciationService] 评测: '{word}', 音频: {audio_path}")

    try:
        # 1. 语音识别
        recognized_text, confidence = _recognize_audio(audio_path)
        logger.info(f"[PronunciationService] 识别结果: '{recognized_text}', 置信度: {confidence}")

        # 2. 获取音节信息
        syllable_info = analyze_word(word)

        # 3. 计算评分
        result = _compute_scores(word, recognized_text, confidence, syllable_info)

        return result

    except Exception as e:
        logger.error(f"[PronunciationService] 评测失败: {str(e)}")
        # 返回一个基本的错误结果
        return PronunciationResult(
            word=word,
            recognized_text="",
            overall_score=0,
            level=ScoreLevel.POOR,
            accuracy_score=0,
            fluency_score=0,
            feedback=f"评测出错: {str(e)}",
            is_correct=False
        )


def _recognize_audio(audio_path: str) -> tuple[str, float]:
    """使用 SpeechRecognition 识别音频"""
    recognizer = sr.Recognizer()
    
    # 支持多种格式（SpeechRecognition 会尝试转换）
    with sr.AudioFile(audio_path) as source:
        audio_data = recognizer.record(source)
        
    try:
        # 使用 Google Web Speech API (无需 API key，但有次数限制)
        # 在生产环境中建议使用 Google Cloud Speech, Azure, 或 local Whisper
        result = recognizer.recognize_google(audio_data, language="en-US", show_all=True)
        
        if not result or 'alternative' not in result:
            return "", 0.0
            
        best_guess = result['alternative'][0]
        return best_guess.get('transcript', "").lower(), best_guess.get('confidence', 0.0)
        
    except sr.UnknownValueError:
        return "", 0.0
    except sr.RequestError as e:
        logger.error(f"无法请求识别服务: {e}")
        return "", 0.0


def _compute_scores(
    target_word: str,
    recognized_text: str,
    confidence: float,
    syllable_info: WordSyllableInfo
) -> PronunciationResult:
    """计算详细评分"""
    
    # 基础准确度：识别出的文本是否匹配
    # 这里使用简单的文本匹配，进阶版可以使用音素匹配
    is_match = target_word in recognized_text.lower()
    
    # 计算准确度分
    # 如果识别出的单词正好是目标单词，分数为置信度 * 100
    # 如果没识别出，给个保底分（如果置信度高但词不对，分数低）
    if is_match:
        accuracy_score = max(70.0, confidence * 100)
    else:
        # 如果识别结果为空
        if not recognized_text:
            accuracy_score = 0.0
        else:
            # 部分匹配或完全不匹配
            import difflib
            similarity = difflib.SequenceMatcher(None, target_word, recognized_text).ratio()
            accuracy_score = similarity * 50.0 # 最高50分

    # 计算流利度分 (基于识别速度，这里暂定为固定值或基于 confidence)
    fluency_score = confidence * 100 if is_match else 30.0
    
    # 总分
    overall_score = (accuracy_score * 0.7) + (fluency_score * 0.3)
    
    # 评分等级
    level = PronunciationResult.get_level(overall_score)
    
    # 音节评分 (简化版：如果单词对，所有音节都对；否则根据相似度分配)
    syllable_scores = []
    for i, syl in enumerate(syllable_info.syllables):
        syl_score = accuracy_score if is_match else accuracy_score * 0.8
        syllable_scores.append(SyllableScore(
            syllable_index=i,
            syllable_text=syl.text,
            expected_phoneme=syl.phoneme,
            recognized_phoneme="", # 暂时无法提取单个音节的识别音素
            score=syl_score,
            is_correct=is_match and syl_score > 60,
            feedback="优秀" if is_match else "需加强"
        ))
        
    # 生成反馈
    feedback = "发音非常标准！" if level == ScoreLevel.EXCELLENT else \
               "发音很棒，继续加油！" if level == ScoreLevel.GOOD else \
               "发音基本清晰，部分细节待提高。" if level == ScoreLevel.FAIR else \
               "没听清，请再试一次。"
               
    suggestions = []
    if not is_match:
        suggestions.append(f"请确保读音更清晰，目标单词是 '{target_word}'")
    if level == ScoreLevel.POOR or level == ScoreLevel.FAIR:
        suggestions.append("可以点击单词旁边的喇叭图标多听几遍标准发音")

    return PronunciationResult(
        word=target_word,
        recognized_text=recognized_text,
        overall_score=overall_score,
        level=level,
        accuracy_score=accuracy_score,
        fluency_score=fluency_score,
        syllable_scores=syllable_scores,
        feedback=feedback,
        suggestions=suggestions,
        is_correct=is_match and overall_score >= 80
    )
