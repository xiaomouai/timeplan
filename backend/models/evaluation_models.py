"""
发音评测结果模型
"""

from dataclasses import dataclass, field
from typing import Optional
from enum import Enum


class ScoreLevel(str, Enum):
    """评分等级"""
    EXCELLENT = "excellent"    # 90-100
    GOOD = "good"              # 70-89
    FAIR = "fair"              # 50-69
    POOR = "poor"              # 0-49


@dataclass
class SyllableScore:
    """单个音节的评分"""
    syllable_index: int
    syllable_text: str
    expected_phoneme: str      # 期望音标
    recognized_phoneme: str    # 识别到的音标
    score: float               # 0-100
    is_correct: bool
    feedback: str = ""         # 针对该音节的反馈

    def to_dict(self) -> dict:
        return {
            "syllable_index": self.syllable_index,
            "syllable_text": self.syllable_text,
            "expected_phoneme": self.expected_phoneme,
            "recognized_phoneme": self.recognized_phoneme,
            "score": round(self.score, 1),
            "is_correct": self.is_correct,
            "feedback": self.feedback,
        }


@dataclass
class PronunciationResult:
    """完整发音评测结果"""
    word: str
    recognized_text: str            # 语音识别出的文本
    overall_score: float            # 总分 0-100
    level: ScoreLevel               # 评分等级
    accuracy_score: float           # 准确度分
    fluency_score: float            # 流利度分
    syllable_scores: list[SyllableScore] = field(default_factory=list)
    feedback: str = ""              # 总体反馈
    suggestions: list[str] = field(default_factory=list)  # 改进建议
    is_correct: bool = False        # 是否完全正确

    def to_dict(self) -> dict:
        return {
            "word": self.word,
            "recognized_text": self.recognized_text,
            "overall_score": round(self.overall_score, 1),
            "level": self.level.value,
            "accuracy_score": round(self.accuracy_score, 1),
            "fluency_score": round(self.fluency_score, 1),
            "syllable_scores": [s.to_dict() for s in self.syllable_scores],
            "feedback": self.feedback,
            "suggestions": self.suggestions,
            "is_correct": self.is_correct,
        }

    @staticmethod
    def get_level(score: float) -> ScoreLevel:
        if score >= 90:
            return ScoreLevel.EXCELLENT
        elif score >= 70:
            return ScoreLevel.GOOD
        elif score >= 50:
            return ScoreLevel.FAIR
        else:
            return ScoreLevel.POOR
