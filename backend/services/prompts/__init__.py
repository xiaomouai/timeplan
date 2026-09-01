"""
提示词模块入口

提供全局单例和便捷访问函数。

使用方式:
    from services.prompts import get_prompt, get_welcome, get_scene_config

    prompt = get_prompt("grammar")
    welcome = get_welcome("speaking")
"""

from .prompt_builder import PromptBuilder

# 全局单例
_builder = PromptBuilder()


def get_prompt(scene: str, runtime_vars: dict = None) -> str:
    """获取指定场景的完整提示词"""
    return _builder.get_prompt(scene, runtime_vars)


def get_welcome(scene: str) -> str:
    """获取场景欢迎语"""
    return _builder.get_welcome(scene)


def get_scene_config(scene: str) -> dict:
    """获取场景完整配置（含提示词）"""
    return _builder.get_scene_config(scene)


def get_all_scenes() -> dict:
    """获取所有场景摘要"""
    return _builder.get_all_scenes()


def get_version() -> str:
    """获取提示词版本号"""
    return _builder.version


def reload():
    """热重载提示词配置"""
    _builder.reload()
