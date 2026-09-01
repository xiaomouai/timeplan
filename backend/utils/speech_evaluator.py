"""
单词拼读评估系统
功能：录音 -> 语音识别 -> 发音评估 -> 打分反馈
"""

import os
import re
import wave
import json
import tempfile
import difflib
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import threading
import time

import numpy as np
import sounddevice as sd
from scipy.io import wavfile

# 语音识别
import speech_recognition as sr

# 本地模块
import pyphen


# ==================== 数据类定义 ====================

class EvaluationLevel(Enum):
    """评估等级"""
    EXCELLENT = "优秀"
    GOOD = "良好"
    FAIR = "及格"
    POOR = "需改进"


@dataclass
class PhonemeComparison:
    """音素对比结果"""
    expected: List[str]      # 期望的音素
    recognized: List[str]    # 识别到的音素
    matches: List[bool]      # 匹配情况
    similarity: float        # 相似度 0-1
    errors: List[Dict]       # 错误详情


@dataclass
class EvaluationResult:
    """评估结果"""
    word: str                           # 目标单词
    recognized_text: str                # 识别的文本
    is_correct: bool                    # 是否正确
    total_score: float                  # 总分 0-100
    
    # 各维度得分
    pronunciation_score: float          # 发音准确度
    clarity_score: float                # 清晰度
    completeness_score: float           # 完整度
    
    # 详细分析
    level: EvaluationLevel              # 评估等级
    phoneme_analysis: Optional[PhonemeComparison] = None
    syllable_analysis: Optional[Dict] = None
    
    # 反馈
    feedback: List[str] = field(default_factory=list)
    suggestions: List[str] = field(default_factory=list)
    
    # 元数据
    confidence: float = 0.0             # 识别置信度
    duration: float = 0.0               # 录音时长


@dataclass  
class RecordingResult:
    """录音结果"""
    audio_data: np.ndarray
    sample_rate: int
    duration: float
    file_path: Optional[str] = None


# ==================== 录音模块 ====================

class AudioRecorder:
    """音频录制器"""
    
    def __init__(self, sample_rate: int = 16000, channels: int = 1):
        self.sample_rate = sample_rate
        self.channels = channels
        self.recording = False
        self.audio_data = []
        
    def record(self, duration: float) -> RecordingResult:
        """
        录制固定时长的音频
        
        Args:
            duration: 录制时长（秒）
        """
        print(f"🎤 开始录音 ({duration}秒)...")
        
        audio = sd.rec(
            int(duration * self.sample_rate),
            samplerate=self.sample_rate,
            channels=self.channels,
            dtype='int16'
        )
        sd.wait()
        
        print("✅ 录音完成")
        
        return RecordingResult(
            audio_data=audio.flatten(),
            sample_rate=self.sample_rate,
            duration=duration
        )
    
    def record_until_silence(self, 
                             max_duration: float = 10.0,
                             silence_threshold: float = 0.01,
                             silence_duration: float = 1.0) -> RecordingResult:
        """
        录制直到检测到静音
        
        Args:
            max_duration: 最大录制时长
            silence_threshold: 静音阈值
            silence_duration: 静音持续时间
        """
        print("🎤 开始录音（说完后自动停止）...")
        
        self.audio_data = []
        self.recording = True
        silence_counter = 0
        
        def callback(indata, frames, time_info, status):
            if self.recording:
                self.audio_data.append(indata.copy())
                
                # 检测静音
                volume = np.abs(indata).mean()
                nonlocal silence_counter
                if volume < silence_threshold:
                    silence_counter += frames / self.sample_rate
                else:
                    silence_counter = 0
        
        with sd.InputStream(
            samplerate=self.sample_rate,
            channels=self.channels,
            dtype='int16',
            callback=callback
        ):
            start_time = time.time()
            while self.recording:
                time.sleep(0.1)
                elapsed = time.time() - start_time
                
                if elapsed >= max_duration:
                    break
                if silence_counter >= silence_duration and elapsed > 0.5:
                    break
        
        self.recording = False
        
        if self.audio_data:
            audio = np.concatenate(self.audio_data).flatten()
            duration = len(audio) / self.sample_rate
        else:
            audio = np.array([], dtype='int16')
            duration = 0
            
        print("✅ 录音完成")
        
        return RecordingResult(
            audio_data=audio,
            sample_rate=self.sample_rate,
            duration=duration
        )
    
    def save_wav(self, recording: RecordingResult, file_path: str) -> str:
        """保存为 WAV 文件"""
        wavfile.write(file_path, recording.sample_rate, recording.audio_data)
        recording.file_path = file_path
        return file_path
    
    def save_temp_wav(self, recording: RecordingResult) -> str:
        """保存为临时 WAV 文件"""
        temp_file = tempfile.NamedTemporaryFile(
            suffix='.wav', delete=False
        )
        temp_path = temp_file.name
        temp_file.close()
        return self.save_wav(recording, temp_path)


# ==================== 语音识别模块 ====================

class SpeechRecognizer:
    """语音识别器"""
    
    def __init__(self, engine: str = 'google'):
        """
        初始化识别器
        
        Args:
            engine: 识别引擎 ('google', 'whisper', 'vosk')
        """
        self.engine = engine
        self.recognizer = sr.Recognizer()
        self._whisper_model = None
        self._vosk_model = None
        
    def recognize(self, audio_path: str, language: str = 'en-US') -> Tuple[str, float]:
        """
        识别音频文件
        
        Returns:
            (识别文本, 置信度)
        """
        if self.engine == 'google':
            return self._recognize_google(audio_path, language)
        elif self.engine == 'whisper':
            return self._recognize_whisper(audio_path)
        elif self.engine == 'vosk':
            return self._recognize_vosk(audio_path)
        else:
            raise ValueError(f"Unknown engine: {self.engine}")
    
    def _recognize_google(self, audio_path: str, language: str) -> Tuple[str, float]:
        """使用 Google Speech Recognition"""
        with sr.AudioFile(audio_path) as source:
            audio = self.recognizer.record(source)
        
        try:
            # 使用 show_all 获取详细结果
            result = self.recognizer.recognize_google(
                audio, 
                language=language,
                show_all=True
            )
            
            if result and 'alternative' in result:
                best = result['alternative'][0]
                text = best.get('transcript', '')
                confidence = best.get('confidence', 0.8)
                return text.lower(), confidence
            else:
                return '', 0.0
                
        except sr.UnknownValueError:
            return '', 0.0
        except sr.RequestError as e:
            print(f"Google API 错误: {e}")
            return '', 0.0
    
    def _recognize_whisper(self, audio_path: str) -> Tuple[str, float]:
        """使用 OpenAI Whisper"""
        try:
            import whisper
            
            if self._whisper_model is None:
                print("正在加载 Whisper 模型...")
                self._whisper_model = whisper.load_model("base")
            
            result = self._whisper_model.transcribe(
                audio_path,
                language='en',
                fp16=False
            )
            
            text = result['text'].strip().lower()
            # Whisper 不直接提供置信度，使用 no_speech_prob 估算
            confidence = 1.0 - result.get('segments', [{}])[0].get('no_speech_prob', 0.2)
            
            return text, confidence
            
        except ImportError:
            print("请安装 whisper: pip install openai-whisper")
            return '', 0.0
    
    def _recognize_vosk(self, audio_path: str) -> Tuple[str, float]:
        """使用 Vosk（离线）"""
        try:
            from vosk import Model, KaldiRecognizer
            
            if self._vosk_model is None:
                model_path = "vosk-model-small-en-us-0.15"
                if not os.path.exists(model_path):
                    print(f"请下载 Vosk 模型到 {model_path}")
                    print("下载地址: https://alphacephei.com/vosk/models")
                    return '', 0.0
                self._vosk_model = Model(model_path)
            
            wf = wave.open(audio_path, "rb")
            rec = KaldiRecognizer(self._vosk_model, wf.getframerate())
            rec.SetWords(True)
            
            results = []
            while True:
                data = wf.readframes(4000)
                if len(data) == 0:
                    break
                rec.AcceptWaveform(data)
            
            final_result = json.loads(rec.FinalResult())
            text = final_result.get('text', '').lower()
            confidence = 0.8  # Vosk 不提供置信度
            
            return text, confidence
            
        except ImportError:
            print("请安装 vosk: pip install vosk")
            return '', 0.0


# ==================== 音素分析模块 ====================

class PhonemeAnalyzer:
    """音素分析器"""
    
    # ARPABET 音素映射
    ARPABET_MAP = {
        'AA': 'ɑ', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔ', 'AW': 'aʊ',
        'AY': 'aɪ', 'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð',
        'EH': 'ɛ', 'ER': 'ɝ', 'EY': 'eɪ', 'F': 'f', 'G': 'g',
        'HH': 'h', 'IH': 'ɪ', 'IY': 'i', 'JH': 'dʒ', 'K': 'k',
        'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'OW': 'oʊ',
        'OY': 'ɔɪ', 'P': 'p', 'R': 'r', 'S': 's', 'SH': 'ʃ',
        'T': 't', 'TH': 'θ', 'UH': 'ʊ', 'UW': 'u', 'V': 'v',
        'W': 'w', 'Y': 'j', 'Z': 'z', 'ZH': 'ʒ'
    }
    
    # 相似音素组（容易混淆的音）
    SIMILAR_PHONEMES = [
        {'b', 'p'}, {'d', 't'}, {'g', 'k'},
        {'v', 'f'}, {'z', 's'}, {'ð', 'θ'},
        {'ʃ', 'tʃ'}, {'ʒ', 'dʒ'},
        {'ɪ', 'i', 'ɛ'}, {'ʊ', 'u', 'ʌ'},
        {'æ', 'ɛ', 'ʌ'}, {'ɑ', 'ɔ'}
    ]
    
    def __init__(self):
        self.cmu_dict = None
        self._load_cmu_dict()
        
    def _load_cmu_dict(self):
        """加载 CMU 发音词典"""
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
    
    def get_phonemes(self, word: str) -> List[str]:
        """获取单词的音素列表"""
        word = word.lower().strip()
        if self.cmu_dict and word in self.cmu_dict:
            # 去除重音标记
            phonemes = self.cmu_dict[word][0]
            return [re.sub(r'[0-9]', '', p) for p in phonemes]
        return []
    
    def phonemes_to_ipa(self, phonemes: List[str]) -> str:
        """将音素列表转换为 IPA"""
        ipa = [self.ARPABET_MAP.get(p, p) for p in phonemes]
        return '/' + ''.join(ipa) + '/'
    
    def compare_phonemes(self, 
                         expected_word: str, 
                         recognized_word: str) -> PhonemeComparison:
        """比较两个单词的音素"""
        expected_phonemes = self.get_phonemes(expected_word)
        recognized_phonemes = self.get_phonemes(recognized_word)
        
        if not expected_phonemes:
            expected_phonemes = list(expected_word.upper())
        if not recognized_phonemes:
            recognized_phonemes = list(recognized_word.upper())
        
        # 使用序列匹配计算相似度
        matcher = difflib.SequenceMatcher(
            None, expected_phonemes, recognized_phonemes
        )
        similarity = matcher.ratio()
        
        # 逐个对比音素
        matches = []
        errors = []
        
        opcodes = matcher.get_opcodes()
        for tag, i1, i2, j1, j2 in opcodes:
            if tag == 'equal':
                matches.extend([True] * (i2 - i1))
            elif tag == 'replace':
                for i, j in zip(range(i1, i2), range(j1, j2)):
                    matches.append(False)
                    errors.append({
                        'type': 'substitution',
                        'position': i,
                        'expected': expected_phonemes[i],
                        'got': recognized_phonemes[j],
                        'is_similar': self._are_similar(
                            expected_phonemes[i], 
                            recognized_phonemes[j]
                        )
                    })
            elif tag == 'delete':
                for i in range(i1, i2):
                    matches.append(False)
                    errors.append({
                        'type': 'deletion',
                        'position': i,
                        'expected': expected_phonemes[i],
                        'got': None
                    })
            elif tag == 'insert':
                for j in range(j1, j2):
                    errors.append({
                        'type': 'insertion',
                        'position': j,
                        'expected': None,
                        'got': recognized_phonemes[j]
                    })
        
        return PhonemeComparison(
            expected=expected_phonemes,
            recognized=recognized_phonemes,
            matches=matches,
            similarity=similarity,
            errors=errors
        )
    
    def _are_similar(self, p1: str, p2: str) -> bool:
        """判断两个音素是否相似"""
        p1_ipa = self.ARPABET_MAP.get(p1, p1.lower())
        p2_ipa = self.ARPABET_MAP.get(p2, p2.lower())
        
        for group in self.SIMILAR_PHONEMES:
            if p1_ipa in group and p2_ipa in group:
                return True
        return False


# ==================== 评估引擎 ====================

class PronunciationEvaluator:
    """发音评估器"""
    
    def __init__(self, recognizer_engine: str = 'google'):
        self.recorder = AudioRecorder()
        self.recognizer = SpeechRecognizer(engine=recognizer_engine)
        self.phoneme_analyzer = PhonemeAnalyzer()
        self.hyphenator = pyphen.Pyphen(lang='en_US')
        
    def evaluate_word(self, 
                      target_word: str,
                      audio_path: Optional[str] = None,
                      recording: Optional[RecordingResult] = None) -> EvaluationResult:
        """
        评估单词发音
        
        Args:
            target_word: 目标单词
            audio_path: 音频文件路径（可选）
            recording: 录音结果（可选）
        """
        target_word = target_word.lower().strip()
        
        # 如果没有提供音频，进行录音
        if audio_path is None and recording is None:
            recording = self.recorder.record(duration=3.0)
            audio_path = self.recorder.save_temp_wav(recording)
            cleanup_audio = True
        elif recording is not None:
            audio_path = self.recorder.save_temp_wav(recording)
            cleanup_audio = True
        else:
            cleanup_audio = False
        
        try:
            # 语音识别
            recognized_text, confidence = self.recognizer.recognize(audio_path)
            
            # 提取识别到的单词
            recognized_words = re.findall(r'\b[a-zA-Z]+\b', recognized_text.lower())
            recognized_word = recognized_words[0] if recognized_words else ''
            
            # 计算各项得分
            result = self._calculate_scores(
                target_word, 
                recognized_word, 
                recognized_text,
                confidence,
                recording.duration if recording else 0
            )
            
            return result
            
        finally:
            # 清理临时文件
            if cleanup_audio and audio_path and os.path.exists(audio_path):
                try:
                    os.unlink(audio_path)
                except:
                    pass
    
    def evaluate_from_recording(self, 
                                target_word: str,
                                duration: float = 3.0) -> EvaluationResult:
        """录音并评估"""
        recording = self.recorder.record(duration=duration)
        return self.evaluate_word(target_word, recording=recording)
    
    def evaluate_from_file(self, 
                           target_word: str, 
                           audio_path: str) -> EvaluationResult:
        """从文件评估"""
        return self.evaluate_word(target_word, audio_path=audio_path)
    
    def _calculate_scores(self,
                          target_word: str,
                          recognized_word: str,
                          recognized_text: str,
                          confidence: float,
                          duration: float) -> EvaluationResult:
        """计算评估分数"""
        
        # 1. 文本完全匹配检查
        is_exact_match = (target_word == recognized_word)
        
        # 2. 发音准确度（基于音素对比）
        phoneme_comparison = self.phoneme_analyzer.compare_phonemes(
            target_word, recognized_word
        )
        pronunciation_score = phoneme_comparison.similarity * 100
        
        # 3. 文本相似度
        text_similarity = difflib.SequenceMatcher(
            None, target_word, recognized_word
        ).ratio()
        
        # 4. 清晰度得分（基于置信度）
        clarity_score = confidence * 100
        
        # 5. 完整度得分
        if len(recognized_word) >= len(target_word):
            completeness_score = 100.0
        else:
            completeness_score = (len(recognized_word) / len(target_word)) * 100
        
        # 6. 计算总分（加权平均）
        total_score = (
            pronunciation_score * 0.5 +  # 发音准确度权重最高
            clarity_score * 0.25 +
            completeness_score * 0.25
        )
        
        # 对于完全匹配，给予加分
        if is_exact_match:
            total_score = min(100, total_score + 10)
        
        # 7. 确定等级
        level = self._get_level(total_score)
        
        # 8. 音节分析
        syllable_analysis = self._analyze_syllables(target_word, recognized_word)
        
        # 9. 生成反馈
        feedback, suggestions = self._generate_feedback(
            target_word, recognized_word, 
            phoneme_comparison, syllable_analysis,
            total_score
        )
        
        return EvaluationResult(
            word=target_word,
            recognized_text=recognized_text,
            is_correct=is_exact_match,
            total_score=round(total_score, 1),
            pronunciation_score=round(pronunciation_score, 1),
            clarity_score=round(clarity_score, 1),
            completeness_score=round(completeness_score, 1),
            level=level,
            phoneme_analysis=phoneme_comparison,
            syllable_analysis=syllable_analysis,
            feedback=feedback,
            suggestions=suggestions,
            confidence=confidence,
            duration=duration
        )
    
    def _get_level(self, score: float) -> EvaluationLevel:
        """根据分数确定等级"""
        if score >= 90:
            return EvaluationLevel.EXCELLENT
        elif score >= 75:
            return EvaluationLevel.GOOD
        elif score >= 60:
            return EvaluationLevel.FAIR
        else:
            return EvaluationLevel.POOR
    
    def _analyze_syllables(self, target: str, recognized: str) -> Dict:
        """分析音节"""
        target_syllables = self.hyphenator.inserted(target).split('-')
        recognized_syllables = self.hyphenator.inserted(recognized).split('-') if recognized else []
        
        return {
            'target_syllables': target_syllables,
            'recognized_syllables': recognized_syllables,
            'target_count': len(target_syllables),
            'recognized_count': len(recognized_syllables),
            'match': target_syllables == recognized_syllables
        }
    
    def _generate_feedback(self,
                           target: str,
                           recognized: str,
                           phoneme_comp: PhonemeComparison,
                           syllable_analysis: Dict,
                           score: float) -> Tuple[List[str], List[str]]:
        """生成反馈和建议"""
        feedback = []
        suggestions = []
        
        # 基本反馈
        if score >= 90:
            feedback.append("🎉 发音非常标准！")
        elif score >= 75:
            feedback.append("👍 发音良好，继续保持！")
        elif score >= 60:
            feedback.append("📝 发音基本正确，但需要改进。")
        else:
            feedback.append("💪 继续练习，你可以做得更好！")
        
        # 识别结果反馈
        if recognized:
            if target == recognized:
                feedback.append(f"✅ 正确识别为: {recognized}")
            else:
                feedback.append(f"❌ 识别为: {recognized}（目标: {target}）")
        else:
            feedback.append("⚠️ 未能识别到有效发音")
            suggestions.append("请确保发音清晰，靠近麦克风")
        
        # 音素错误分析
        if phoneme_comp.errors:
            error_types = {}
            for error in phoneme_comp.errors:
                error_types[error['type']] = error_types.get(error['type'], 0) + 1
            
            if 'substitution' in error_types:
                feedback.append(f"🔤 有 {error_types['substitution']} 个发音替换")
                
                # 具体错误
                for error in phoneme_comp.errors:
                    if error['type'] == 'substitution':
                        exp_ipa = phoneme_comp.expected[error['position']]
                        got_ipa = error['got']
                        suggestions.append(
                            f"音素 /{exp_ipa}/ 发成了 /{got_ipa}/"
                        )
            
            if 'deletion' in error_types:
                feedback.append(f"📉 有 {error_types['deletion']} 个音素遗漏")
                suggestions.append("注意发音完整，不要漏掉音节")
            
            if 'insertion' in error_types:
                feedback.append(f"📈 有 {error_types['insertion']} 个多余的音")
                suggestions.append("注意不要添加多余的发音")
        
        # 音节反馈
        if not syllable_analysis['match']:
            target_syl = syllable_analysis['target_syllables']
            suggestions.append(f"单词分为 {len(target_syl)} 个音节: {'-'.join(target_syl)}")
        
        return feedback, suggestions


# ==================== 评估报告生成器 ====================

class EvaluationReporter:
    """评估报告生成器"""
    
    @staticmethod
    def print_report(result: EvaluationResult):
        """打印评估报告"""
        print("\n" + "=" * 60)
        print("📊 单词拼读评估报告")
        print("=" * 60)
        
        # 基本信息
        print(f"\n🎯 目标单词: {result.word}")
        print(f"🎤 识别结果: {result.recognized_text or '(无)'}")
        print(f"✅ 是否正确: {'是' if result.is_correct else '否'}")
        
        # 得分
        print(f"\n📈 总分: {result.total_score}/100 ({result.level.value})")
        print("-" * 40)
        print(f"   发音准确度: {result.pronunciation_score}/100")
        print(f"   清晰度:     {result.clarity_score}/100")
        print(f"   完整度:     {result.completeness_score}/100")
        
        # 音素分析
        if result.phoneme_analysis:
            pa = result.phoneme_analysis
            print(f"\n🔤 音素分析:")
            print(f"   期望音素: {' '.join(pa.expected)}")
            print(f"   识别音素: {' '.join(pa.recognized)}")
            print(f"   相似度:   {pa.similarity:.1%}")
        
        # 音节分析
        if result.syllable_analysis:
            sa = result.syllable_analysis
            print(f"\n📝 音节分析:")
            print(f"   目标音节: {'-'.join(sa['target_syllables'])}")
            if sa['recognized_syllables']:
                print(f"   识别音节: {'-'.join(sa['recognized_syllables'])}")
        
        # 反馈
        if result.feedback:
            print(f"\n💬 反馈:")
            for fb in result.feedback:
                print(f"   {fb}")
        
        # 建议
        if result.suggestions:
            print(f"\n💡 改进建议:")
            for i, sug in enumerate(result.suggestions, 1):
                print(f"   {i}. {sug}")
        
        print("\n" + "=" * 60)
    
    @staticmethod
    def to_dict(result: EvaluationResult) -> Dict:
        """转换为字典格式"""
        return {
            'word': result.word,
            'recognized_text': result.recognized_text,
            'is_correct': result.is_correct,
            'scores': {
                'total': result.total_score,
                'pronunciation': result.pronunciation_score,
                'clarity': result.clarity_score,
                'completeness': result.completeness_score
            },
            'level': result.level.value,
            'phoneme_analysis': {
                'expected': result.phoneme_analysis.expected if result.phoneme_analysis else [],
                'recognized': result.phoneme_analysis.recognized if result.phoneme_analysis else [],
                'similarity': result.phoneme_analysis.similarity if result.phoneme_analysis else 0,
                'errors': result.phoneme_analysis.errors if result.phoneme_analysis else []
            } if result.phoneme_analysis else None,
            'feedback': result.feedback,
            'suggestions': result.suggestions,
            'confidence': result.confidence
        }
    
    @staticmethod
    def to_json(result: EvaluationResult) -> str:
        """转换为 JSON 字符串"""
        return json.dumps(
            EvaluationReporter.to_dict(result), 
            ensure_ascii=False, 
            indent=2
        )


# ==================== 综合工具类 ====================

class WordPronunciationTester:
    """
    单词发音测试器 - 综合工具类
    
    使用示例:
        tester = WordPronunciationTester()
        result = tester.test_word("apple")
        tester.print_result(result)
    """
    
    def __init__(self, recognizer_engine: str = 'google'):
        self.evaluator = PronunciationEvaluator(recognizer_engine)
        self.reporter = EvaluationReporter()
        
    def test_word(self, 
                  word: str, 
                  duration: float = 3.0,
                  auto_record: bool = True) -> EvaluationResult:
        """
        测试单词发音
        
        Args:
            word: 目标单词
            duration: 录音时长
            auto_record: 是否自动录音
        """
        print(f"\n🎯 请朗读单词: {word.upper()}")
        print("-" * 40)
        
        if auto_record:
            result = self.evaluator.evaluate_from_recording(word, duration)
        else:
            input("按 Enter 开始录音...")
            result = self.evaluator.evaluate_from_recording(word, duration)
        
        return result
    
    def test_word_from_file(self, word: str, audio_path: str) -> EvaluationResult:
        """从音频文件测试"""
        return self.evaluator.evaluate_from_file(word, audio_path)
    
    def test_word_list(self, 
                       words: List[str], 
                       duration: float = 3.0) -> List[EvaluationResult]:
        """批量测试单词列表"""
        results = []
        
        for i, word in enumerate(words, 1):
            print(f"\n📝 第 {i}/{len(words)} 个单词")
            result = self.test_word(word, duration)
            results.append(result)
            self.print_result(result)
            
            if i < len(words):
                input("\n按 Enter 继续下一个单词...")
        
        return results
    
    def print_result(self, result: EvaluationResult):
        """打印结果"""
        self.reporter.print_report(result)
    
    def get_summary(self, results: List[EvaluationResult]) -> Dict:
        """获取测试总结"""
        if not results:
            return {}
        
        total_score = sum(r.total_score for r in results) / len(results)
        correct_count = sum(1 for r in results if r.is_correct)
        
        return {
            'total_words': len(results),
            'correct_count': correct_count,
            'accuracy': correct_count / len(results),
            'average_score': round(total_score, 1),
            'scores': [r.total_score for r in results],
            'words': [
                {
                    'word': r.word,
                    'score': r.total_score,
                    'correct': r.is_correct
                }
                for r in results
            ]
        }
    
    def print_summary(self, results: List[EvaluationResult]):
        """打印测试总结"""
        summary = self.get_summary(results)
        
        print("\n" + "=" * 60)
        print("📊 测试总结")
        print("=" * 60)
        print(f"总单词数: {summary['total_words']}")
        print(f"正确数:   {summary['correct_count']}")
        print(f"正确率:   {summary['accuracy']:.1%}")
        print(f"平均分:   {summary['average_score']}/100")
        print("-" * 40)
        
        for item in summary['words']:
            status = "✅" if item['correct'] else "❌"
            print(f"  {status} {item['word']:15} {item['score']}/100")
        
        print("=" * 60)


# ==================== 主程序 ====================

if __name__ == "__main__":
    # 创建测试器
    tester = WordPronunciationTester(recognizer_engine='google')
    
    print("=" * 60)
    print("🎤 单词拼读评估系统")
    print("=" * 60)
    
    # 交互模式
    while True:
        print("\n选择模式:")
        print("1. 测试单个单词")
        print("2. 测试单词列表")
        print("3. 从音频文件测试")
        print("4. 退出")
        
        choice = input("\n请选择 (1-4): ").strip()
        
        if choice == '1':
            word = input("请输入要测试的单词: ").strip()
            if word:
                result = tester.test_word(word)
                tester.print_result(result)
                
        elif choice == '2':
            words_input = input("请输入单词列表 (用空格分隔): ").strip()
            words = words_input.split()
            if words:
                results = tester.test_word_list(words)
                tester.print_summary(results)
                
        elif choice == '3':
            word = input("请输入目标单词: ").strip()
            path = input("请输入音频文件路径: ").strip()
            if word and path and os.path.exists(path):
                result = tester.test_word_from_file(word, path)
                tester.print_result(result)
            else:
                print("❌ 无效输入或文件不存在")
                
        elif choice == '4':
            print("👋 再见!")
            break
        
        else:
            print("❌ 无效选择")