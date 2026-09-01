# """
# 单词拼读工具类
# 支持：字母拼读、音节划分、音素分解、语音合成
# """

# import re
# import os
# import time
# import tempfile
# from typing import List, Dict, Optional, Tuple
# from dataclasses import dataclass
# from enum import Enum

# # 第三方库
# import pyphen
# import pyttsx3
# from gtts import gTTS
# import nltk

# # 下载 CMU 发音词典
# try:
#     from nltk.corpus import cmudict
#     cmudict.dict()
# except LookupError:
#     nltk.download('cmudict')
#     from nltk.corpus import cmudict

# # G2P 模型（延迟加载）
# _g2p_model = None

# def get_g2p():
#     """延迟加载 G2P 模型"""
#     global _g2p_model
#     if _g2p_model is None:
#         from g2p_en import G2p
#         _g2p_model = G2p()
#     return _g2p_model


# class SpellingMode(Enum):
#     """拼读模式"""
#     LETTER = "letter"           # 字母拼读
#     SYLLABLE = "syllable"       # 音节拼读
#     PHONEME = "phoneme"         # 音素拼读
#     PHONICS = "phonics"         # 自然拼读（简化版）


# @dataclass
# class SpellingResult:
#     """拼读结果"""
#     word: str                   # 原单词
#     mode: SpellingMode          # 拼读模式
#     parts: List[str]            # 拆分后的部分
#     display: str                # 显示文本
#     speak_text: str             # 朗读文本
#     ipa: Optional[str] = None   # 国际音标


# class WordSpeller:
#     """
#     单词拼读器
    
#     使用示例:
#         speller = WordSpeller()
#         result = speller.spell("computer", SpellingMode.SYLLABLE)
#         print(result.display)
#         speller.speak(result)
#     """
    
#     # ARPABET 到 IPA 的映射表
#     ARPABET_TO_IPA = {
#         'AA': 'ɑ', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔ', 'AW': 'aʊ',
#         'AY': 'aɪ', 'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð',
#         'EH': 'ɛ', 'ER': 'ɝ', 'EY': 'eɪ', 'F': 'f', 'G': 'g',
#         'HH': 'h', 'IH': 'ɪ', 'IY': 'i', 'JH': 'dʒ', 'K': 'k',
#         'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'OW': 'oʊ',
#         'OY': 'ɔɪ', 'P': 'p', 'R': 'r', 'S': 's', 'SH': 'ʃ',
#         'T': 't', 'TH': 'θ', 'UH': 'ʊ', 'UW': 'u', 'V': 'v',
#         'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ'
#     }
    
#     # 自然拼读规则（字母组合 -> 发音）
#     PHONICS_RULES = {
#         # 元音
#         'ee': 'iː', 'ea': 'iː', 'oo': 'uː', 'ou': 'aʊ', 'ow': 'aʊ',
#         'ai': 'eɪ', 'ay': 'eɪ', 'oi': 'ɔɪ', 'oy': 'ɔɪ',
#         'au': 'ɔː', 'aw': 'ɔː', 'ew': 'juː',
#         # 辅音
#         'sh': 'ʃ', 'ch': 'tʃ', 'th': 'θ', 'ph': 'f',
#         'wh': 'w', 'ck': 'k', 'ng': 'ŋ', 'qu': 'kw',
#         # 单元音
#         'a': 'æ', 'e': 'ɛ', 'i': 'ɪ', 'o': 'ɒ', 'u': 'ʌ',
#         # 单辅音
#         'b': 'b', 'c': 'k', 'd': 'd', 'f': 'f', 'g': 'g',
#         'h': 'h', 'j': 'dʒ', 'k': 'k', 'l': 'l', 'm': 'm',
#         'n': 'n', 'p': 'p', 'r': 'r', 's': 's', 't': 't',
#         'v': 'v', 'w': 'w', 'x': 'ks', 'y': 'j', 'z': 'z'
#     }
    
#     def __init__(self, lang: str = 'en_US'):
#         """
#         初始化拼读器
        
#         Args:
#             lang: 语言代码，用于音节划分
#         """
#         self.lang = lang
#         self.hyphenator = pyphen.Pyphen(lang=lang)
#         self.cmu_dict = cmudict.dict()
#         self.tts_engine = None
        
#     def _init_tts(self):
#         """初始化 TTS 引擎"""
#         if self.tts_engine is None:
#             self.tts_engine = pyttsx3.init()
#             self.tts_engine.setProperty('rate', 150)
            
#     # ==================== 字母拼读 ====================
    
#     def spell_letters(self, word: str) -> SpellingResult:
#         """
#         字母拼读
        
#         Args:
#             word: 待拼读单词
            
#         Returns:
#             SpellingResult 对象
#         """
#         word = word.strip().lower()
#         letters = list(word.upper())
        
#         return SpellingResult(
#             word=word,
#             mode=SpellingMode.LETTER,
#             parts=letters,
#             display=' - '.join(letters),
#             speak_text=', '.join(letters)
#         )
    
#     # ==================== 音节拼读 ====================
    
#     def spell_syllables(self, word: str) -> SpellingResult:
#         """
#         音节拼读
        
#         Args:
#             word: 待拼读单词
            
#         Returns:
#             SpellingResult 对象
#         """
#         word = word.strip().lower()
#         hyphenated = self.hyphenator.inserted(word)
#         syllables = hyphenated.split('-')
        
#         return SpellingResult(
#             word=word,
#             mode=SpellingMode.SYLLABLE,
#             parts=syllables,
#             display=' - '.join(syllables),
#             speak_text=' ... '.join(syllables)
#         )
    
#     # ==================== 音素拼读 ====================
    
#     def _arpabet_to_ipa(self, arpabet: str) -> str:
#         """将 ARPABET 转换为 IPA"""
#         # 去除重音标记
#         clean = re.sub(r'[0-9]', '', arpabet)
#         return self.ARPABET_TO_IPA.get(clean, arpabet)
    
#     def spell_phonemes(self, word: str, use_g2p: bool = True) -> SpellingResult:
#         """
#         音素拼读
        
#         Args:
#             word: 待拼读单词
#             use_g2p: 如果 CMU 词典中没有，是否使用 G2P 模型
            
#         Returns:
#             SpellingResult 对象
#         """
#         word = word.strip().lower()
        
#         # 尝试从 CMU 词典获取
#         if word in self.cmu_dict:
#             phonemes = self.cmu_dict[word][0]
#         elif use_g2p:
#             # 使用 G2P 模型
#             g2p = get_g2p()
#             phonemes = g2p(word)
#             # 过滤空格
#             phonemes = [p for p in phonemes if p.strip()]
#         else:
#             phonemes = list(word)
        
#         # 转换为 IPA
#         ipa_list = [self._arpabet_to_ipa(p) for p in phonemes]
#         ipa = ''.join(ipa_list)
        
#         return SpellingResult(
#             word=word,
#             mode=SpellingMode.PHONEME,
#             parts=phonemes,
#             display=' '.join([f"/{self._arpabet_to_ipa(p)}/" for p in phonemes]),
#             speak_text=' '.join(phonemes),
#             ipa=f"/{ipa}/"
#         )
    
#     # ==================== 自然拼读 ====================
    
#     def spell_phonics(self, word: str) -> SpellingResult:
#         """
#         自然拼读（基于规则的拆分）
        
#         Args:
#             word: 待拼读单词
            
#         Returns:
#             SpellingResult 对象
#         """
#         word = word.strip().lower()
#         parts = []
#         sounds = []
#         i = 0
        
#         while i < len(word):
#             matched = False
#             # 尝试匹配双字母组合
#             if i + 1 < len(word):
#                 two_chars = word[i:i+2]
#                 if two_chars in self.PHONICS_RULES:
#                     parts.append(two_chars)
#                     sounds.append(self.PHONICS_RULES[two_chars])
#                     i += 2
#                     matched = True
            
#             # 单字母匹配
#             if not matched:
#                 char = word[i]
#                 parts.append(char)
#                 sounds.append(self.PHONICS_RULES.get(char, char))
#                 i += 1
        
#         return SpellingResult(
#             word=word,
#             mode=SpellingMode.PHONICS,
#             parts=parts,
#             display=' + '.join([f"{p}(/{s}/)" for p, s in zip(parts, sounds)]),
#             speak_text=' '.join(parts),
#             ipa='/' + ''.join(sounds) + '/'
#         )
    
#     # ==================== 统一接口 ====================
    
#     def spell(self, word: str, mode: SpellingMode = SpellingMode.LETTER) -> SpellingResult:
#         """
#         统一拼读接口
        
#         Args:
#             word: 待拼读单词
#             mode: 拼读模式
            
#         Returns:
#             SpellingResult 对象
#         """
#         if mode == SpellingMode.LETTER:
#             return self.spell_letters(word)
#         elif mode == SpellingMode.SYLLABLE:
#             return self.spell_syllables(word)
#         elif mode == SpellingMode.PHONEME:
#             return self.spell_phonemes(word)
#         elif mode == SpellingMode.PHONICS:
#             return self.spell_phonics(word)
#         else:
#             raise ValueError(f"Unknown spelling mode: {mode}")
    
#     def spell_all(self, word: str) -> Dict[SpellingMode, SpellingResult]:
#         """
#         获取所有拼读模式的结果
        
#         Args:
#             word: 待拼读单词
            
#         Returns:
#             字典，键为模式，值为结果
#         """
#         return {mode: self.spell(word, mode) for mode in SpellingMode}
    
#     # ==================== 语音合成 ====================
    
#     def speak(self, result: SpellingResult, engine: str = 'pyttsx3', 
#               slow: bool = True, save_path: Optional[str] = None) -> Optional[str]:
#         """
#         朗读拼读结果
        
#         Args:
#             result: 拼读结果
#             engine: TTS 引擎 ('pyttsx3' 或 'gtts')
#             slow: 是否慢速朗读
#             save_path: 保存音频的路径（仅 gtts 支持）
            
#         Returns:
#             音频文件路径（如果保存的话）
#         """
#         if engine == 'pyttsx3':
#             self._speak_pyttsx3(result, slow)
#             return None
#         elif engine == 'gtts':
#             return self._speak_gtts(result, slow, save_path)
#         else:
#             raise ValueError(f"Unknown TTS engine: {engine}")
    
#     def _speak_pyttsx3(self, result: SpellingResult, slow: bool = True):
#         """使用 pyttsx3 朗读"""
#         self._init_tts()
        
#         # 设置语速
#         rate = 100 if slow else 150
#         self.tts_engine.setProperty('rate', rate)
        
#         # 先读原单词，再拼读
#         text = f"{result.word}. {result.speak_text}"
#         self.tts_engine.say(text)
#         self.tts_engine.runAndWait()
    
#     def _speak_gtts(self, result: SpellingResult, slow: bool = True, 
#                     save_path: Optional[str] = None) -> str:
#         """使用 Google TTS 朗读"""
#         # 生成音频
#         text = f"{result.word}. {result.speak_text}"
#         tts = gTTS(text=text, lang='en', slow=slow)
        
#         # 确定保存路径
#         if save_path is None:
#             save_path = os.path.join(
#                 tempfile.gettempdir(), 
#                 f"spelling_{result.word}_{int(time.time())}.mp3"
#             )
        
#         tts.save(save_path)
        
#         # 播放音频
#         try:
#             from playsound import playsound
#             playsound(save_path)
#         except Exception as e:
#             print(f"播放失败: {e}，音频已保存到: {save_path}")
        
#         return save_path
    
#     def speak_word_only(self, word: str, engine: str = 'pyttsx3'):
#         """只朗读单词本身"""
#         if engine == 'pyttsx3':
#             self._init_tts()
#             self.tts_engine.say(word)
#             self.tts_engine.runAndWait()
#         else:
#             tts = gTTS(text=word, lang='en')
#             with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as f:
#                 tts.save(f.name)
#                 try:
#                     from playsound import playsound
#                     playsound(f.name)
#                 finally:
#                     os.unlink(f.name)


# class BatchSpeller:
#     """
#     批量拼读器
#     """
    
#     def __init__(self, speller: Optional[WordSpeller] = None):
#         self.speller = speller or WordSpeller()
    
#     def spell_words(self, words: List[str], 
#                     mode: SpellingMode = SpellingMode.LETTER) -> List[SpellingResult]:
#         """批量拼读"""
#         return [self.speller.spell(word, mode) for word in words]
    
#     def spell_sentence(self, sentence: str, 
#                        mode: SpellingMode = SpellingMode.SYLLABLE) -> List[SpellingResult]:
#         """拼读句子中的每个单词"""
#         words = re.findall(r'\b[a-zA-Z]+\b', sentence)
#         return self.spell_words(words, mode)
    
#     def export_to_dict(self, words: List[str]) -> List[Dict]:
#         """导出所有拼读信息为字典格式"""
#         results = []
#         for word in words:
#             all_spellings = self.speller.spell_all(word)
#             results.append({
#                 'word': word,
#                 'letter': all_spellings[SpellingMode.LETTER].display,
#                 'syllable': all_spellings[SpellingMode.SYLLABLE].display,
#                 'phoneme': all_spellings[SpellingMode.PHONEME].display,
#                 'phonics': all_spellings[SpellingMode.PHONICS].display,
#                 'ipa': all_spellings[SpellingMode.PHONEME].ipa
#             })
#         return results


# # ==================== 辅助函数 ====================

# def quick_spell(word: str, mode: str = 'letter') -> str:
#     """
#     快速拼读函数
    
#     Args:
#         word: 单词
#         mode: 模式 ('letter', 'syllable', 'phoneme', 'phonics')
        
#     Returns:
#         拼读显示文本
#     """
#     speller = WordSpeller()
#     mode_enum = SpellingMode(mode)
#     result = speller.spell(word, mode_enum)
#     return result.display


# def get_pronunciation(word: str) -> Tuple[str, List[str]]:
#     """
#     获取单词发音信息
    
#     Returns:
#         (IPA音标, 音素列表)
#     """
#     speller = WordSpeller()
#     result = speller.spell_phonemes(word)
#     return result.ipa, result.parts
"""
单词拼读工具类 - 精简版
兼容 Python 3.10+，无复杂依赖
"""

import re
import os
import tempfile
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# 基础依赖
import pyphen
import pyttsx3


class SpellingMode(Enum):
    """拼读模式"""
    LETTER = "letter"           # 字母拼读
    SYLLABLE = "syllable"       # 音节拼读
    PHONEME = "phoneme"         # 音素拼读
    PHONICS = "phonics"         # 自然拼读


@dataclass
class SpellingResult:
    """拼读结果"""
    word: str
    mode: SpellingMode
    parts: List[str]
    display: str
    speak_text: str
    ipa: Optional[str] = None


class WordSpeller:
    """
    单词拼读器
    
    示例:
        speller = WordSpeller()
        result = speller.spell("computer", SpellingMode.SYLLABLE)
        print(result.display)
    """
    
    # ARPABET 到 IPA 映射
    ARPABET_TO_IPA = {
        'AA': 'ɑ', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔ', 'AW': 'aʊ',
        'AY': 'aɪ', 'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð',
        'EH': 'ɛ', 'ER': 'ɝ', 'EY': 'eɪ', 'F': 'f', 'G': 'g',
        'HH': 'h', 'IH': 'ɪ', 'IY': 'i', 'JH': 'dʒ', 'K': 'k',
        'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'OW': 'oʊ',
        'OY': 'ɔɪ', 'P': 'p', 'R': 'r', 'S': 's', 'SH': 'ʃ',
        'T': 't', 'TH': 'θ', 'UH': 'ʊ', 'UW': 'u', 'V': 'v',
        'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ'
    }
    
    # 自然拼读规则
    PHONICS_RULES = {
        # 双字母组合
        'ee': 'iː', 'ea': 'iː', 'oo': 'uː', 'ou': 'aʊ', 'ow': 'aʊ',
        'ai': 'eɪ', 'ay': 'eɪ', 'oi': 'ɔɪ', 'oy': 'ɔɪ',
        'au': 'ɔː', 'aw': 'ɔː', 'ew': 'juː', 'ie': 'iː', 'ue': 'uː',
        'sh': 'ʃ', 'ch': 'tʃ', 'th': 'θ', 'ph': 'f',
        'wh': 'w', 'ck': 'k', 'ng': 'ŋ', 'qu': 'kw', 'gh': '',
        # 单字母
        'a': 'æ', 'e': 'ɛ', 'i': 'ɪ', 'o': 'ɒ', 'u': 'ʌ',
        'b': 'b', 'c': 'k', 'd': 'd', 'f': 'f', 'g': 'g',
        'h': 'h', 'j': 'dʒ', 'k': 'k', 'l': 'l', 'm': 'm',
        'n': 'n', 'p': 'p', 'r': 'r', 's': 's', 't': 't',
        'v': 'v', 'w': 'w', 'x': 'ks', 'y': 'j', 'z': 'z'
    }
    
    def __init__(self, lang: str = 'en_US'):
        self.lang = lang
        self.hyphenator = pyphen.Pyphen(lang=lang)
        self.tts_engine = None
        self.cmu_dict = None
        
    def _load_cmu_dict(self):
        """延迟加载 CMU 词典"""
        if self.cmu_dict is None:
            try:
                import nltk
                from nltk.corpus import cmudict
                try:
                    self.cmu_dict = cmudict.dict()
                except LookupError:
                    nltk.download('cmudict', quiet=True)
                    self.cmu_dict = cmudict.dict()
            except ImportError:
                self.cmu_dict = {}
        return self.cmu_dict
        
    def _init_tts(self):
        """初始化 TTS 引擎"""
        if self.tts_engine is None:
            self.tts_engine = pyttsx3.init()
            self.tts_engine.setProperty('rate', 150)
    
    # ==================== 字母拼读 ====================
    
    def spell_letters(self, word: str) -> SpellingResult:
        """字母拼读: cat -> C - A - T"""
        word = word.strip().lower()
        letters = list(word.upper())
        
        return SpellingResult(
            word=word,
            mode=SpellingMode.LETTER,
            parts=letters,
            display=' - '.join(letters),
            speak_text=', '.join(letters)
        )
    
    # ==================== 音节拼读 ====================
    
    def spell_syllables(self, word: str) -> SpellingResult:
        """音节拼读: computer -> com-put-er"""
        word = word.strip().lower()
        hyphenated = self.hyphenator.inserted(word)
        syllables = hyphenated.split('-')
        
        return SpellingResult(
            word=word,
            mode=SpellingMode.SYLLABLE,
            parts=syllables,
            display=' - '.join(syllables),
            speak_text=' ... '.join(syllables)
        )
    
    # ==================== 音素拼读 ====================
    
    def _arpabet_to_ipa(self, arpabet: str) -> str:
        """ARPABET 转 IPA"""
        clean = re.sub(r'[0-9]', '', arpabet)
        return self.ARPABET_TO_IPA.get(clean, arpabet.lower())
    
    def spell_phonemes(self, word: str) -> SpellingResult:
        """音素拼读: cat -> /k/ /æ/ /t/"""
        word = word.strip().lower()
        cmu = self._load_cmu_dict()
        
        if word in cmu:
            phonemes = cmu[word][0]
        else:
            # 回退到自然拼读
            return self.spell_phonics(word)
        
        ipa_list = [self._arpabet_to_ipa(p) for p in phonemes]
        ipa = ''.join(ipa_list)
        
        return SpellingResult(
            word=word,
            mode=SpellingMode.PHONEME,
            parts=phonemes,
            display=' '.join([f"/{self._arpabet_to_ipa(p)}/" for p in phonemes]),
            speak_text=' '.join(phonemes),
            ipa=f"/{ipa}/"
        )
    
    # ==================== 自然拼读 ====================
    
    def spell_phonics(self, word: str) -> SpellingResult:
        """自然拼读: cat -> c(/k/) + a(/æ/) + t(/t/)"""
        word = word.strip().lower()
        parts = []
        sounds = []
        i = 0
        
        while i < len(word):
            matched = False
            
            # 尝试三字母组合
            if i + 2 < len(word):
                three = word[i:i+3]
                if three in self.PHONICS_RULES:
                    parts.append(three)
                    sounds.append(self.PHONICS_RULES[three])
                    i += 3
                    matched = True
            
            # 尝试双字母组合
            if not matched and i + 1 < len(word):
                two = word[i:i+2]
                if two in self.PHONICS_RULES:
                    parts.append(two)
                    sounds.append(self.PHONICS_RULES[two])
                    i += 2
                    matched = True
            
            # 单字母
            if not matched:
                char = word[i]
                parts.append(char)
                sounds.append(self.PHONICS_RULES.get(char, char))
                i += 1
        
        # 过滤空音
        filtered = [(p, s) for p, s in zip(parts, sounds) if s]
        if filtered:
            parts, sounds = zip(*filtered)
            parts, sounds = list(parts), list(sounds)
        
        return SpellingResult(
            word=word,
            mode=SpellingMode.PHONICS,
            parts=parts,
            display=' + '.join([f"{p}(/{s}/)" for p, s in zip(parts, sounds)]),
            speak_text=' '.join(parts),
            ipa='/' + ''.join(sounds) + '/'
        )
    
    # ==================== 统一接口 ====================
    
    def spell(self, word: str, mode: SpellingMode = SpellingMode.LETTER) -> SpellingResult:
        """统一拼读接口"""
        methods = {
            SpellingMode.LETTER: self.spell_letters,
            SpellingMode.SYLLABLE: self.spell_syllables,
            SpellingMode.PHONEME: self.spell_phonemes,
            SpellingMode.PHONICS: self.spell_phonics,
        }
        return methods[mode](word)
    
    def spell_all(self, word: str) -> Dict[SpellingMode, SpellingResult]:
        """获取所有拼读模式结果"""
        return {mode: self.spell(word, mode) for mode in SpellingMode}
    
    # ==================== 语音合成 ====================
    
    def speak(self, result: SpellingResult, slow: bool = True):
        """朗读拼读结果（使用 pyttsx3）"""
        self._init_tts()
        
        rate = 100 if slow else 150
        self.tts_engine.setProperty('rate', rate)
        
        # 先读单词，再拼读
        text = f"{result.word}. {result.speak_text}"
        self.tts_engine.say(text)
        self.tts_engine.runAndWait()
    
    def speak_word(self, word: str):
        """只朗读单词"""
        self._init_tts()
        self.tts_engine.say(word)
        self.tts_engine.runAndWait()
    
    def speak_text(self, text: str, rate: int = 150):
        """朗读任意文本"""
        self._init_tts()
        self.tts_engine.setProperty('rate', rate)
        self.tts_engine.say(text)
        self.tts_engine.runAndWait()


class BatchSpeller:
    """批量拼读器"""
    
    def __init__(self, speller: Optional[WordSpeller] = None):
        self.speller = speller or WordSpeller()
    
    def spell_words(self, words: List[str], 
                    mode: SpellingMode = SpellingMode.LETTER) -> List[SpellingResult]:
        """批量拼读单词列表"""
        return [self.speller.spell(word.strip(), mode) 
                for word in words if word.strip()]
    
    def spell_sentence(self, sentence: str, 
                       mode: SpellingMode = SpellingMode.SYLLABLE) -> List[SpellingResult]:
        """拼读句子中的所有单词"""
        words = re.findall(r'\b[a-zA-Z]+\b', sentence)
        return self.spell_words(words, mode)
    
    def export_to_dict(self, words: List[str]) -> List[Dict]:
        """导出为字典格式"""
        results = []
        for word in words:
            word = word.strip()
            if not word:
                continue
            all_spellings = self.speller.spell_all(word)
            results.append({
                'word': word,
                'letter': all_spellings[SpellingMode.LETTER].display,
                'syllable': all_spellings[SpellingMode.SYLLABLE].display,
                'phoneme': all_spellings[SpellingMode.PHONEME].display,
                'phonics': all_spellings[SpellingMode.PHONICS].display,
                'ipa': all_spellings[SpellingMode.PHONEME].ipa
            })
        return results


# ==================== 快捷函数 ====================

_default_speller = None

def get_speller() -> WordSpeller:
    """获取默认拼读器实例"""
    global _default_speller
    if _default_speller is None:
        _default_speller = WordSpeller()
    return _default_speller


def spell(word: str, mode: str = 'letter') -> str:
    """
    快速拼读
    
    Args:
        word: 单词
        mode: 'letter', 'syllable', 'phoneme', 'phonics'
    
    Returns:
        拼读显示文本
    """
    return get_speller().spell(word, SpellingMode(mode)).display


def get_ipa(word: str) -> str:
    """获取单词的 IPA 音标"""
    result = get_speller().spell_phonemes(word)
    return result.ipa or ''


def get_syllables(word: str) -> List[str]:
    """获取单词的音节列表"""
    return get_speller().spell_syllables(word).parts


def speak(word: str, mode: str = 'letter'):
    """朗读拼读"""
    speller = get_speller()
    result = speller.spell(word, SpellingMode(mode))
    speller.speak(result)


# ==================== 主程序 ====================

if __name__ == "__main__":
    # 测试
    speller = WordSpeller()
    
    test_words = ["cat", "computer", "beautiful", "python", "elephant"]
    
    for word in test_words:
        print(f"\n{'='*50}")
        print(f"单词: {word}")
        print('='*50)
        
        for mode in SpellingMode:
            result = speller.spell(word, mode)
            print(f"{mode.value:10}: {result.display}")
            if result.ipa:
                print(f"{'':10}  IPA: {result.ipa}")