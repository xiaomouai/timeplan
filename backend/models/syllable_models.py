"""
音节数据模型

表示一个单词拆解后的音节结构，
包含每个音节的文本、音标、重音位置等信息。
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Syllable:
    """单个音节"""
    text: str               # 音节文本，如 "ap"
    phoneme: str             # 音标，如 "æp"
    stress: int = 0          # 重音级别：0=无重音, 1=主重音, 2=次重音
    index: int = 0           # 音节在单词中的位置索引

    def to_dict(self) -> dict:
        return {
            "text": self.text,
            "phoneme": self.phoneme,
            "stress": self.stress,
            "index": self.index,
        }


@dataclass
class WordSyllableInfo:
    """单词的完整音节信息"""
    word: str                          # 原始单词
    phonetic: str                      # 完整音标，如 "/ˈæp.əl/"
    phonetic_us: Optional[str] = None  # 美式音标
    phonetic_uk: Optional[str] = None  # 英式音标
    syllables: list[Syllable] = field(default_factory=list)
    syllable_count: int = 0            # 音节数量
    stress_pattern: str = ""           # 重音模式，如 "10"（第一个重读）
    audio_url: Optional[str] = None    # 标准读音URL

    def to_dict(self) -> dict:
        return {
            "word": self.word,
            "phonetic": self.phonetic,
            "phonetic_us": self.phonetic_us,
            "phonetic_uk": self.phonetic_uk,
            "syllables": [s.to_dict() for s in self.syllables],
            "syllable_count": self.syllable_count,
            "stress_pattern": self.stress_pattern,
            "audio_url": self.audio_url,
        }
