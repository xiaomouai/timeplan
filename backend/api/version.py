"""
版本管理 API
提供应用版本检查和更新信息
"""
from flask import Blueprint, jsonify, request
from datetime import datetime
from models.version_model import AppVersion, ApiVersion

version_bp = Blueprint('version', __name__)

# 默认备用数据
DEFAULT_API_VERSION = {
    'version': '2.0.0',
    'build': 20260204,
    'release_date': '2026-02-04',
    'min_app_version': '1.0.0',
    'features': ['单词拼读API', '语音评测API', '智能学习算法', '词库管理系统']
}

DEFAULT_APP_VERSION = {
    'version': '1.2.0',
    'build_number': 12,
    'release_date': '2026-02-04',
    'min_api_version': '2.0.0',
    'download_url': 'http://app.mty.mingboai.com/download/v1.2.0/app.apk',
    'changelog': ['新增单词拼读功能', '优化语音评测准确度', '修复已知问题', '提升应用性能'],
    'force_update': False,
    'file_size': '25.6 MB',
    'md5': 'abc123def456'
}

@version_bp.route('/api', methods=['GET'])
def get_api_version():
    """获取API版本信息"""
    api_ver = ApiVersion.query.filter_by(is_active=True).order_by(ApiVersion.id.desc()).first()
    if api_ver:
        data = api_ver.to_dict()
    else:
        data = DEFAULT_API_VERSION
    
    return jsonify({
        'success': True,
        'data': data
    })

@version_bp.route('/app/latest', methods=['GET'])
def get_latest_app_version():
    """获取最新应用版本信息"""
    platform = request.args.get('platform', 'android')
    
    app_ver = AppVersion.query.filter_by(platform=platform, is_latest=True).order_by(AppVersion.id.desc()).first()
    if app_ver:
        data = app_ver.to_dict()
    else:
        data = DEFAULT_APP_VERSION
        data['platform'] = platform
    
    return jsonify({
        'success': True,
        'data': data
    })

@version_bp.route('/app/check', methods=['POST'])
def check_app_update():
    """检查应用更新"""
    data = request.get_json() or {}
    current_version = data.get('current_version', '1.0.0')
    current_build = data.get('build_number', 0)
    platform = data.get('platform', 'android')
    
    app_ver = AppVersion.query.filter_by(platform=platform, is_latest=True).order_by(AppVersion.id.desc()).first()
    if app_ver:
        latest = app_ver.to_dict()
    else:
        latest = DEFAULT_APP_VERSION
        
    has_update = current_build < latest['build_number']
    
    return jsonify({
        'success': True,
        'data': {
            'has_update': has_update,
            'current_version': current_version,
            'current_build': current_build,
            'latest_version': latest['version'] if has_update else current_version,
            'latest_build': latest['build_number'] if has_update else current_build,
            'force_update': latest.get('force_update', False) if has_update else False,
            'update_info': latest if has_update else None
        }
    })

@version_bp.route('/compatibility', methods=['POST'])
def check_compatibility():
    """检查前后端兼容性"""
    data = request.get_json() or {}
    app_version = data.get('app_version', '1.0.0')
    
    api_ver = ApiVersion.query.filter_by(is_active=True).order_by(ApiVersion.id.desc()).first()
    min_app_version = api_ver.min_app_version if api_ver else DEFAULT_API_VERSION['min_app_version']
    api_version_str = api_ver.version if api_ver else DEFAULT_API_VERSION['version']
    
    is_compatible = _compare_versions(app_version, min_app_version) >= 0
    
    return jsonify({
        'success': True,
        'data': {
            'compatible': is_compatible,
            'app_version': app_version,
            'api_version': api_version_str,
            'min_app_version': min_app_version,
            'message': '版本兼容' if is_compatible else f'应用版本过低，请升级到 {min_app_version} 或更高版本'
        }
    })

def _compare_versions(v1: str, v2: str) -> int:
    """比较版本号"""
    parts1 = [int(x) for x in v1.split('.')]
    parts2 = [int(x) for x in v2.split('.')]
    
    for i in range(max(len(parts1), len(parts2))):
        p1 = parts1[i] if i < len(parts1) else 0
        p2 = parts2[i] if i < len(parts2) else 0
        
        if p1 > p2:
            return 1
        elif p1 < p2:
            return -1
    return 0
