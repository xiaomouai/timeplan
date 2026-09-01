"""
音节拆解服务

功能：
- 将英文单词拆解为音节
- 提供每个音节的音标和重音标记
- 使用 CMU Pronouncing Dictionary + 规则引擎

依赖：
  pip install nltk pronouncing eng-to-ipa
"""

import re
import logging
from typing import Optional

import pronouncing  # 基于CMU词典
import eng_to_ipa   # 英文转IPA音标

from models.syllable_models import Syllable, WordSyllableInfo

logger = logging.getLogger(__name__)


# ==================== 音节拆解规则引擎 ====================

# 元音字母组合（用于规则兜底）
_VOWEL_PATTERNS = re.compile(
    r'[aeiou]+|'           # 纯元音
    r'[aeiou][rl]|'        # 元音+r/l
    r'y(?=[^aeiou]|$)',    # y在辅音前或词尾作元音
    re.IGNORECASE
)

# 常见不拆分的辅音组合
_CONSONANT_CLUSTERS = {
    "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr",
    "pl", "pr", "sc", "sk", "sl", "sm", "sn", "sp", "st",
    "str", "sw", "tr", "tw", "spr", "spl", "scr",
    "ch", "sh", "th", "wh", "ph", "ck", "ng", "nk",
}


def _get_cmu_phones(word: str) -> Optional[list[str]]:
    """
    从CMU词典获取音素列表

    CMU格式示例：
    "apple" -> ['AE1', 'P', 'AH0', 'L']
    数字表示重音：0=无, 1=主重音, 2=次重音
    """
    phones_list = pronouncing.phones_for_word(word.lower())
    if phones_list:
        return phones_list[0].split()
    return None


def _phones_to_syllables(word: str, phones: list[str]) -> list[Syllable]:
    """
    将CMU音素序列拆分为音节

    音节拆分规则：
    1. 每个元音音素（带数字后缀）是一个音节核心
    2. 两个元音之间的辅音，归后一个音节（最大起始原则）
    3. 词首辅音归第一个音节
    """
    # 标记元音位置
    vowel_indices = []
    for i, phone in enumerate(phones):
        if phone[-1].isdigit():  # CMU中元音末尾有数字
            vowel_indices.append(i)

    if not vowel_indices:
        # 无元音（极少见），整个词作为一个音节
        return [Syllable(text=word, phoneme="".join(phones), stress=0, index=0)]

    # 按元音分组音素
    syllable_phones: list[list[str]] = []
    prev_end = 0
    for idx, vowel_idx in enumerate(vowel_indices):
        if idx == len(vowel_indices) - 1:
            # 最后一个元音，取到末尾
            syllable_phones.append(phones[prev_end:])
        else:
            # 找下一个元音之前的辅音分界点
            next_vowel = vowel_indices[idx + 1]
            # 辅音群在两个元音之间，用最大起始原则
            consonants_between = phones[vowel_idx + 1:next_vowel]
            split_point = vowel_idx + 1
            
            if len(consonants_between) > 1:
                # 把尽可能多的辅音留给下一个音节
                split_point = next_vowel - len(consonants_between) + 1
            elif len(consonants_between) == 1:
                split_point = vowel_idx + 1  # 单辅音归后
            
            syllable_phones.append(phones[prev_end:split_point])
            prev_end = split_point

    # 将字母分配给音节（近似映射）
    syllable_texts = _distribute_letters(word, len(syllable_phones))

    # 构建音节对象
    syllables = []
    for i, (syl_phones, syl_text) in enumerate(zip(syllable_phones, syllable_texts)):
        # 提取重音
        stress = 0
        for phone in syl_phones:
            if phone[-1] == "1":
                stress = 1
            elif phone[-1] == "2" and stress == 0:
                stress = 2

        # 转换音素为IPA（简化）
        phoneme = _cmu_to_ipa_simple(syl_phones)

        syllables.append(Syllable(
            text=syl_text,
            phoneme=phoneme,
            stress=stress,
            index=i,
        ))

    return syllables


def _distribute_letters(word: str, num_syllables: int) -> list[str]:
    """
    将单词字母近似分配到各音节

    使用元音检测进行分割，如果音节数不匹配则均匀分配
    """
    if num_syllables <= 1:
        return [word]

    # 找到元音位置
    vowel_positions = [i for i, c in enumerate(word.lower()) if c in "aeiouy"]

    if len(vowel_positions) < num_syllables:
        # 均匀分割
        chunk_size = max(1, len(word) // num_syllables)
        parts = []
        for i in range(num_syllables):
            start = i * chunk_size
            end = start + chunk_size if i < num_syllables - 1 else len(word)
            parts.append(word[start:end])
        return parts

    # 基于元音分割
    parts = []
    prev = 0
    for i in range(num_syllables - 1):
        if i < len(vowel_positions) - 1:
            # 在两个元音之间的辅音处分割
            curr_vowel = vowel_positions[i]
            next_vowel = vowel_positions[i + 1]
            # 分割点在两个元音中间的辅音位置
            split = (curr_vowel + next_vowel + 1) // 2
            parts.append(word[prev:split])
            prev = split
    parts.append(word[prev:])

    return parts


# CMU音素到IPA的简化映射
_CMU_TO_IPA = {
    "AA": "ɑː", "AE": "æ", "AH": "ʌ", "AO": "ɔː", "AW": "aʊ",
    "AY": "aɪ", "EH": "ɛ", "ER": "ɜːr", "EY": "eɪ", "IH": "ɪ",
    "IY": "iː", "OW": "oʊ", "OY": "ɔɪ", "UH": "ʊ", "UW": "uː",
    "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f",
    "G": "ɡ", "HH": "h", "JH": "dʒ", "K": "k", "L": "l",
    "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "r",
    "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "V": "v",
    "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
}


def _cmu_to_ipa_simple(phones: list[str]) -> str:
    """将CMU音素列表转换为IPA字符串"""
    ipa_parts = []
    for phone in phones:
        # 去掉重音数字
        base = phone.rstrip("012")
        ipa = _CMU_TO_IPA.get(base, base.lower())
        ipa_parts.append(ipa)
    return "".join(ipa_parts)


def _get_ipa_phonetic(word: str) -> str:
    """获取单词的完整IPA音标"""
    try:
        ipa = eng_to_ipa.convert(word)
        if ipa and "*" not in ipa:  # eng_to_ipa 未找到时返回带*的原文
            return f"/{ipa}/"
    except Exception:
        pass

    # 降级：从CMU转换
    phones = _get_cmu_phones(word)
    if phones:
        return f"/{_cmu_to_ipa_simple(phones)}/"
    return ""


# ==================== 公开接口 ====================

def analyze_word(word: str) -> WordSyllableInfo:
    """
    分析单词的音节结构

    Args:
        word: 英文单词

    Returns:
        WordSyllableInfo 包含完整的音节拆解信息
    """
    word_clean = word.strip().lower()
    logger.info(f"[SyllableService] 分析单词: '{word_clean}'")

    # 获取CMU音素
    phones = _get_cmu_phones(word_clean)

    if phones:
        syllables = _phones_to_syllables(word_clean, phones)
    else:
        # CMU词典中没有，使用音节计数估算
        logger.warning(f"[SyllableService] CMU词典未收录: '{word_clean}', 使用规则引擎")
        # 这里需要注意 pronouncing.syllable_count 的用法
        phones_list = pronouncing.phones_for_word(word_clean)
        if phones_list:
            count = pronouncing.syllable_count(phones_list[0])
        else:
            count = _estimate_syllable_count(word_clean)
        
        texts = _distribute_letters(word_clean, max(1, count))
        syllables = [
            Syllable(text=t, phoneme="", stress=0, index=i)
            for i, t in enumerate(texts)
        ]

    # 获取IPA音标
    phonetic = _get_ipa_phonetic(word_clean)

    # 构建重音模式
    stress_pattern = "".join(str(s.stress) for s in syllables)

    result = WordSyllableInfo(
        word=word_clean,
        phonetic=phonetic,
        syllables=syllables,
        syllable_count=len(syllables),
        stress_pattern=stress_pattern,
    )

    logger.info(
        f"[SyllableService] 结果: {word_clean} → "
        f"{[s.text for s in syllables]} ({phonetic})"
    )
    return result


def _estimate_syllable_count(word: str) -> int:
    """基于规则估算音节数"""
    word = word.lower()
    count = len(re.findall(r'[aeiouy]+', word))
    # 词尾的 silent e
    if word.endswith("e") and count > 1:
        count -= 1
    # 词尾 -le 算一个音节
    if word.endswith("le") and len(word) > 2 and word[-3] not in "aeiouy":
        count += 1
    return max(1, count)
