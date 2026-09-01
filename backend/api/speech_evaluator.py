"""独立单词发音评测 API。"""

import base64
import binascii
import os
import tempfile

from flask import Blueprint, Flask, jsonify, request


speech_bp = Blueprint("speech_evaluator", __name__)
_evaluator = None
_reporter = None


def _load_evaluator():
    global _evaluator, _reporter
    if _evaluator is None or _reporter is None:
        try:
            from utils.speech_evaluator import EvaluationReporter, PronunciationEvaluator
        except ImportError as error:
            raise RuntimeError(f"语音评测依赖未安装: {error}") from error
        _evaluator = PronunciationEvaluator(recognizer_engine="google")
        _reporter = EvaluationReporter
    return _evaluator, _reporter


@speech_bp.route("/evaluate", methods=["POST"])
def evaluate():
    data = request.get_json(silent=True) or {}
    word = data.get("word", "")
    audio_base64 = data.get("audio_base64", "")
    if not isinstance(word, str) or not word.strip():
        return jsonify({"error": "Missing word"}), 400
    if not isinstance(audio_base64, str) or not audio_base64:
        return jsonify({"error": "Missing audio"}), 400

    temp_path = None
    try:
        audio_data = base64.b64decode(audio_base64, validate=True)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as audio_file:
            audio_file.write(audio_data)
            temp_path = audio_file.name
        evaluator, reporter = _load_evaluator()
        result = evaluator.evaluate_from_file(word.strip(), temp_path)
        return jsonify(reporter.to_dict(result))
    except (ValueError, TypeError, binascii.Error) as error:
        return jsonify({"error": f"音频格式错误: {error}"}), 400
    except Exception as error:
        return jsonify({"error": str(error)}), 503
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


@speech_bp.route("/health", methods=["GET"])
def health():
    try:
        from utils import speech_evaluator as _speech_module  # noqa: F401
        available = True
    except ImportError:
        available = False
    return jsonify({"status": "ok", "available": available})


def create_standalone_app():
    standalone_app = Flask(__name__)
    standalone_app.register_blueprint(speech_bp, url_prefix="/api")
    return standalone_app


app = create_standalone_app()

if __name__ == "__main__":
    app.run(debug=True, port=5000)
