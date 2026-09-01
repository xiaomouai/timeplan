"""
音频代理API - 解决Web平台跨域和格式问题
"""
from flask import request, Response, jsonify
from . import api_v1
import requests
import os
import tempfile
from services.syllable_service import analyze_word
from services.pronunciation_service import evaluate_pronunciation
from utils.response import success_response as success, error_response as error
from flask_jwt_extended import jwt_required


@api_v1.route('/audio/proxy', methods=['GET'])
def audio_proxy():
    """
    音频代理接口
    ---
    tags:
      - 音频服务
    summary: 音频代理
    description: 代理外部音频URL，解决Web平台的CORS和格式问题
    parameters:
      - name: url
        in: query
        type: string
        required: true
        description: 外部音频URL
        example: https://dict.youdao.com/dictvoice?audio=hello&type=1
      - name: word
        in: query
        type: string
        required: false
        description: 单词（用于快捷方式）
        example: hello
      - name: type
        in: query
        type: integer
        required: false
        description: 发音类型（1=英式，2=美式）
        example: 1
    responses:
      200:
        description: 成功返回音频流
        content:
          audio/mpeg:
            schema:
              type: string
              format: binary
      400:
        description: 缺少必需参数
      500:
        description: 音频获取失败
    """
    # 获取音频URL
    audio_url = request.args.get('url')
    
    # 支持快捷方式：传入word和type直接生成URL
    if not audio_url:
        word = request.args.get('word')
        audio_type = request.args.get('type', '1')
        
        if word:
            audio_url = f'https://dict.youdao.com/dictvoice?audio={word}&type={audio_type}'
        else:
            return {'code': 400, 'msg': '缺少参数：url 或 word'}, 400
    
    try:
        # 设置请求头，模拟浏览器
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
            'Accept-Encoding': 'identity',
            'Connection': 'keep-alive',
        }
        
        # 请求外部音频
        response = requests.get(audio_url, headers=headers, timeout=10, stream=True)
        
        if response.status_code == 200:
            # 返回音频流，添加CORS头
            return Response(
                response.content,
                mimetype='audio/mpeg',
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Cache-Control': 'public, max-age=86400',  # 缓存1天
                }
            )
        else:
            return {
                'code': 500, 
                'msg': f'音频获取失败: HTTP {response.status_code}'
            }, 500
            
    except Exception as e:
        return {
            'code': 500,
            'msg': f'音频代理失败: {str(e)}'
        }, 500


@api_v1.route('/audio/syllables/<word>', methods=['GET'])
@jwt_required()
def get_syllables(word):
    """获取单词音节拆解"""
    try:
        result = analyze_word(word)
        return success(result.to_dict())
    except Exception as e:
        return error(f"获取音节失败: {str(e)}")

@api_v1.route('/audio/evaluate', methods=['POST'])
@jwt_required()
def evaluate_audio():
    """发音评测接口"""
    word = request.form.get('word')
    if not word:
        return error("缺少参数: word")
        
    if 'audio' not in request.files:
        return error("缺少音频文件")
        
    audio_file = request.files['audio']
    
    # 保存临时文件
    suffix = os.path.splitext(audio_file.filename)[1] or '.m4a'
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as temp:
        audio_file.save(temp.name)
        temp_path = temp.name
        
    try:
        # 如果是 m4a/aac 格式，SpeechRecognition 可能需要转换
        # 这里简单处理，生产环境建议使用 pydub/ffmpeg 转换为 wav
        # sr.AudioFile 支持 wav, aiff, flac
        
        # 尝试转换（如果需要）
        processed_path = temp_path
        if suffix.lower() in ['.m4a', '.mp4', '.aac']:
            try:
                from pydub import AudioSegment
                audio = AudioSegment.from_file(temp_path)
                wav_temp = temp_path.replace(suffix, '.wav')
                audio.export(wav_temp, format='wav')
                processed_path = wav_temp
            except Exception as ex:
                print(f"音频转换失败: {ex}, 尝试直接处理")
        
        result = evaluate_pronunciation(word, processed_path)
        
        # 清理转换后的文件
        if processed_path != temp_path and os.path.exists(processed_path):
            os.remove(processed_path)
            
        return success(result.to_dict())
    except Exception as e:
        return error(f"评测失败: {str(e)}")
    finally:
        # 清理临时文件
        if os.path.exists(temp_path):
            os.remove(temp_path)

@api_v1.route('/audio/tts', methods=['GET'])
def text_to_speech():
    """
    文本转语音（备用方案）
    ---
    tags:
      - 音频服务
    summary: 文本转语音
    description: 使用备用TTS服务生成单词或句子发音
    parameters:
      - name: text
        in: query
        type: string
        required: true
        description: 要发音的文本（单词或句子）
        example: hello
      - name: lang
        in: query
        type: string
        required: false
        description: 语言（en-US或en-GB）
        example: en-US
        default: en-US
    responses:
      200:
        description: 成功返回音频流
        content:
          audio/mpeg:
            schema:
              type: string
              format: binary
      400:
        description: 缺少文本参数
    """
    text = request.args.get('text') or request.args.get('word')  # 兼容旧参数
    lang = request.args.get('lang', 'en-US')  # en-US=美式, en-GB=英式
    
    if not text:
        return {'code': 400, 'msg': '缺少参数：text'}, 400
    
    try:
        # 使用Google TTS作为备用
        import urllib.parse
        encoded_text = urllib.parse.quote(text)
        tts_url = f'https://translate.google.com/translate_tts?ie=UTF-8&tl={lang}&client=tw-ob&q={encoded_text}'
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }
        
        response = requests.get(tts_url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            return Response(
                response.content,
                mimetype='audio/mpeg',
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Cache-Control': 'public, max-age=86400',
                }
            )
        else:
            return {'code': 500, 'msg': 'TTS服务失败'}, 500
            
    except Exception as e:
        return {'code': 500, 'msg': f'TTS失败: {str(e)}'}, 500
