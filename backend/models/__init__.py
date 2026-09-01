"""
数据库模型包
"""
from extensions import db

# 导入所有模型
from .user_models import User, UserWord, UserAchievement, ParentChild
from .checkin_models import CheckinRecord, LevelConfig, ConsecutiveRewardConfig, PointsLog, UserReward
from .word_models import WordBook, Word, WordTranslation, WordSentence, WordPhrase, WordSynonym, WordRelated
from .study_models import (
    StudyLog, WrongRecord, PronunciationRecord,
    Challenge, ChallengeRecord, ChallengeAnswer,
    Dictation, DictationRecord, DictationAnswer
)
from .membership_models import (
    Membership, Order,
    MembershipPlan, UserMembership, MembershipOrder,
    MembershipBenefit, UserMembershipBenefit
)
from .textbook_models import Textbook, Unit
from .feedback_model import Feedback
from .version_model import AppVersion, ApiVersion
from .payment import PaymentOrder, PaymentLog, VIPMembership, UserCoins
from .health_models import (
    HealthProfile, HealthHabit, HealthCheckin, HealthBiometric, HealthPlan
)
from .agent_models import AgentTask, AgentLog, AgentResult

__all__ = [
    'db',
    'User', 'UserWord', 'UserAchievement', 'ParentChild', 
    'CheckinRecord', 'LevelConfig', 'ConsecutiveRewardConfig', 'PointsLog', 'UserReward',
    'WordBook', 'Word', 'WordTranslation', 'WordSentence', 'WordPhrase', 'WordSynonym', 'WordRelated',
    'StudyLog', 'WrongRecord', 'PronunciationRecord',
    'Challenge', 'ChallengeRecord', 'ChallengeAnswer',
    'Dictation', 'DictationRecord', 'DictationAnswer',
    'Membership', 'Order',
    'MembershipPlan', 'UserMembership', 'MembershipOrder',
    'MembershipBenefit', 'UserMembershipBenefit',
    'Textbook', 'Unit',
    'Feedback', 'AppVersion', 'ApiVersion',
    'PaymentOrder', 'PaymentLog', 'VIPMembership', 'UserCoins',
    'HealthProfile', 'HealthHabit', 'HealthCheckin', 'HealthBiometric', 'HealthPlan',
    'AgentTask', 'AgentLog', 'AgentResult',
]
