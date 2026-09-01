"""
单词拼读 API - 集成到主应用
"""
from flask import Blueprint, request, jsonify
import sys
import os

# 添加父目录到路径以导入 test_spelling
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from test_spelling import WordSpeller, BatchSpeller, SpellingMode
    SPELLING_AVAILABLE = True
except ImportError:
    SPELLING_AVAILABLE = False
    WordSpeller = None
    BatchSpeller = None
    SpellingMode = None

spelling_bp = Blueprint('spelling', __name__)

# 初始化拼读器（延迟加载）
_speller = None
_batch_speller = None


def get_speller():
    """获取拼读器实例"""
    global _speller, _batch_speller
    if not SPELLING_AVAILABLE:
        return None, None
    
    if _speller is None:
        _speller = WordSpeller()
        _batch_speller = BatchSpeller(_speller)
    
    return _speller, _batch_speller


@spelling_bp.route('/spell', methods=['GET', 'POST'])
def spell_word():
    """
    拼读单词
    ---
    tags:
      - 单词拼读
    parameters:
      - name: word
        in: query
        type: string
        required: true
        description: 要拼读的单词
      - name: mode
        in: query
        type: string
        required: false
        default: letter
        description: 拼读模式 (letter/syllable/phoneme/phonics)
    responses:
      200:
        description: 拼读结果
    """
    if not SPELLING_AVAILABLE:
        return jsonify({
            'success': False,
            'error': 'Spelling service not available'
        }), 503
    
    if request.method == 'GET':
        word = request.args.get('word', '')
        mode = request.args.get('mode', 'letter')
    else:
        data = request.get_json() or {}
        word = data.get('word', '')
        mode = data.get('mode', 'letter')
    
    if not word:
        return jsonify({
            'success': False,
            'error': 'Missing word parameter'
        }), 400
    
    try:
        speller, _ = get_speller()
        mode_enum = SpellingMode(mode)
        result = speller.spell(word, mode_enum)
        
        return jsonify({
            'success': True,
            'data': {
                'word': result.word,
                'mode': result.mode.value,
                'parts': result.parts,
                'display': result.display,
                'speak_text': result.speak_text,
                'ipa': result.ipa
            }
        })
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': f'Invalid mode: {mode}'
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@spelling_bp.route('/spell/all', methods=['GET', 'POST'])
def spell_all():
    """
    获取所有拼读模式
    ---
    tags:
      - 单词拼读
    parameters:
      - name: word
        in: query
        type: string
        required: true
        description: 要拼读的单词
    responses:
      200:
        description: 所有拼读模式结果
    """
    if not SPELLING_AVAILABLE:
        return jsonify({
            'success': False,
            'error': 'Spelling service not available'
        }), 503
    
    if request.method == 'GET':
        word = request.args.get('word', '')
    else:
        data = request.get_json() or {}
        word = data.get('word', '')
    
    if not word:
        return jsonify({
            'success': False,
            'error': 'Missing word parameter'
        }), 400
    
    try:
        speller, _ = get_speller()
        all_results = speller.spell_all(word)
        
        return jsonify({
            'success': True,
            'data': {
                'word': word,
                'spellings': {
                    mode.value: {
                        'parts': result.parts,
                        'display': result.display,
                        'ipa': result.ipa
                    }
                    for mode, result in all_results.items()
                }
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@spelling_bp.route('/batch', methods=['POST'])
def spell_batch():
    """
    批量拼读
    ---
    tags:
      - 单词拼读
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            words:
              type: array
              items:
                type: string
            mode:
              type: string
              default: letter
    responses:
      200:
        description: 批量拼读结果
    """
    if not SPELLING_AVAILABLE:
        return jsonify({
            'success': False,
            'error': 'Spelling service not available'
        }), 503
    
    data = request.get_json() or {}
    words = data.get('words', [])
    mode = data.get('mode', 'letter')
    
    if not words:
        return jsonify({
            'success': False,
            'error': 'Missing words parameter'
        }), 400
    
    try:
        _, batch_speller = get_speller()
        mode_enum = SpellingMode(mode)
        results = batch_speller.spell_words(words, mode_enum)
        
        return jsonify({
            'success': True,
            'data': {
                'mode': mode,
                'results': [
                    {
                        'word': r.word,
                        'display': r.display,
                        'parts': r.parts,
                        'ipa': r.ipa
                    }
                    for r in results
                ]
            }
        })
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': f'Invalid mode: {mode}'
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@spelling_bp.route('/pronunciation', methods=['GET'])
def get_pronunciation():
    """
    获取发音信息
    ---
    tags:
      - 单词拼读
    parameters:
      - name: word
        in: query
        type: string
        required: true
        description: 单词
    responses:
      200:
        description: 发音信息
    """
    if not SPELLING_AVAILABLE:
        return jsonify({
            'success': False,
            'error': 'Spelling service not available'
        }), 503
    
    word = request.args.get('word', '')
    
    if not word:
        return jsonify({
            'success': False,
            'error': 'Missing word parameter'
        }), 400
    
    try:
        speller, _ = get_speller()
        result = speller.spell_phonemes(word)
        
        return jsonify({
            'success': True,
            'data': {
                'word': word,
                'ipa': result.ipa,
                'phonemes': result.parts,
                'display': result.display
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
