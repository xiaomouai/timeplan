"""
提示词构建器

职责：
- 加载并解析 YAML 配置文件
- 处理 ${base.xxx} 变量替换
- 支持运行时参数注入
- 缓存已构建的提示词
"""

import os
import re
import logging
from typing import Optional
from functools import lru_cache

import yaml

logger = logging.getLogger(__name__)

# YAML 配置文件路径
_PROMPTS_FILE = os.path.join(os.path.dirname(__file__), "prompts.yaml")

# 变量引用正则: ${base.identity}
_VAR_PATTERN = re.compile(r"\$\{base\.(\w+)\}")


def _load_yaml() -> dict:
    """加载并解析 YAML 文件"""
    try:
        with open(_PROMPTS_FILE, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        logger.info(
            f"[PromptBuilder] 提示词配置加载成功, "
            f"版本={data.get('meta', {}).get('version', 'unknown')}, "
            f"场景数={len(data.get('scenes', {}))}"
        )
        return data
    except FileNotFoundError:
        logger.error(f"[PromptBuilder] 配置文件不存在: {_PROMPTS_FILE}")
        raise
    except yaml.YAMLError as e:
        logger.error(f"[PromptBuilder] YAML 解析失败: {e}")
        raise


def _resolve_variables(template: str, base_fragments: dict) -> str:
    """
    替换模板中的 ${base.xxx} 变量引用

    Args:
        template: 包含变量引用的模板字符串
        base_fragments: base 区块的所有片段

    Returns:
        替换后的完整提示词
    """

    def _replace(match):
        key = match.group(1)
        fragment = base_fragments.get(key)
        if fragment is None:
            logger.warning(f"[PromptBuilder] 未找到基础片段: base.{key}")
            return f"[未定义: base.{key}]"
        return fragment.strip()

    resolved = _VAR_PATTERN.sub(_replace, template)
    return resolved.strip()


class PromptBuilder:
    """
    提示词构建器

    使用方法:
        builder = PromptBuilder()
        prompt = builder.get_prompt("grammar")
        welcome = builder.get_welcome("grammar")
        config = builder.get_scene_config("grammar")
    """

    def __init__(self):
        self._data = _load_yaml()
        self._base = self._data.get("base", {})
        self._scenes = self._data.get("scenes", {})
        self._meta = self._data.get("meta", {})
        self._cache: dict[str, str] = {}

    @property
    def version(self) -> str:
        return self._meta.get("version", "unknown")

    @property
    def scene_names(self) -> list[str]:
        return list(self._scenes.keys())

    def get_prompt(
        self,
        scene: str,
        runtime_vars: Optional[dict[str, str]] = None,
    ) -> str:
        """
        获取指定场景的完整提示词

        Args:
            scene: 场景标识（如 "grammar", "speaking"）
            runtime_vars: 运行时变量（如 {"user_name": "小明"}）

        Returns:
            构建完成的提示词字符串

        Raises:
            KeyError: 场景不存在
        """
        # 缓存键
        cache_key = f"{scene}:{hash(frozenset((runtime_vars or {}).items()))}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        scene_config = self._scenes.get(scene)
        if scene_config is None:
            raise KeyError(f"未知的提示词场景: '{scene}'")

        template = scene_config.get("prompt", "")

        # 第一步：替换 ${base.xxx}
        prompt = _resolve_variables(template, self._base)

        # 第二步：替换运行时变量 {user_name}
        if runtime_vars:
            for key, value in runtime_vars.items():
                prompt = prompt.replace(f"{{{key}}}", str(value))

        self._cache[cache_key] = prompt
        return prompt

    def get_welcome(self, scene: str) -> str:
        """获取场景欢迎语"""
        scene_config = self._scenes.get(scene)
        if scene_config is None:
            return "你好！有什么可以帮你的吗？"
        return scene_config.get("welcome", "你好！有什么可以帮你的吗？")

    def get_scene_config(self, scene: str) -> dict:
        """
        获取场景的完整配置

        Returns:
            {
                "name": "语法专家",
                "description": "...",
                "welcome": "...",
                "temperature": 0.5,
                "max_tokens": 2500,
                "prompt": "(完整提示词)"
            }
        """
        scene_config = self._scenes.get(scene)
        if scene_config is None:
            raise KeyError(f"未知的场景: '{scene}'")

        return {
            "name": scene_config.get("name", scene),
            "description": scene_config.get("description", ""),
            "welcome": scene_config.get("welcome", ""),
            "temperature": scene_config.get("temperature", 0.7),
            "max_tokens": scene_config.get("max_tokens", 2000),
            "prompt": self.get_prompt(scene),
        }

    def get_all_scenes(self) -> dict[str, dict]:
        """
        获取所有场景配置（不含完整prompt，用于列表展示）

        Returns:
            {"general": {"name": "...", "description": "...", "welcome": "..."}, ...}
        """
        result = {}
        for scene_id, config in self._scenes.items():
            result[scene_id] = {
                "name": config.get("name", scene_id),
                "description": config.get("description", ""),
                "welcome": config.get("welcome", ""),
                "temperature": config.get("temperature", 0.7),
                "max_tokens": config.get("max_tokens", 2000),
            }
        return result

    def reload(self):
        """热重载配置（用于开发调试）"""
        self._data = _load_yaml()
        self._base = self._data.get("base", {})
        self._scenes = self._data.get("scenes", {})
        self._meta = self._data.get("meta", {})
        self._cache.clear()
        logger.info(f"[PromptBuilder] 配置已重载, 版本={self.version}")
