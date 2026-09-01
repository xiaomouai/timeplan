"""
签到核心服务
"""
from datetime import date, datetime, timedelta
from typing import List, Optional, Dict, Any
from extensions import db
from models.user_models import User
from models.checkin_models import CheckinRecord, LevelConfig, ConsecutiveRewardConfig, PointsLog, UserReward
from sqlalchemy import and_, extract, asc

class LevelService:
    """等级服务"""
    
    @staticmethod
    def get_user_level_info(user: User) -> Dict[str, Any]:
        """获取用户等级信息"""
        levels = LevelConfig.query.order_by(asc(LevelConfig.level)).all()
        if not levels:
            return {
                "level": user.level,
                "level_name": "初学者",
                "icon": "🌱",
                "color": "#4CAF50",
                "description": "开始学习之旅",
                "min_points": 0,
                "next_level_points": 100,
                "progress": 0.0,
            }

        current = None
        next_level = None

        for i, lv in enumerate(levels):
            if lv.level == user.level:
                current = lv
                if i + 1 < len(levels):
                    next_level = levels[i + 1]
                break

        if not current:
            current = levels[0]

        # 计算进度
        if next_level:
            range_points = next_level.min_points - current.min_points
            user_progress = user.points - current.min_points
            progress = min(max(user_progress / range_points, 0.0), 1.0) if range_points > 0 else 1.0
        else:
            progress = 1.0  # 满级

        return {
            "level": current.level,
            "level_name": current.level_name,
            "icon": current.icon,
            "color": current.color,
            "description": current.description,
            "min_points": current.min_points,
            "next_level_points": next_level.min_points if next_level else None,
            "progress": round(progress, 4),
        }

    @staticmethod
    def get_daily_base_points(level: int) -> int:
        """获取该等级每日基础签到积分"""
        lv_config = LevelConfig.query.filter_by(level=level).first()
        return lv_config.daily_base_points if lv_config else 10

    @staticmethod
    def check_level_up(user: User) -> tuple:
        """检查是否升级"""
        levels = LevelConfig.query.order_by(asc(LevelConfig.level)).all()
        new_level = user.level

        for lv in levels:
            if user.points >= lv.min_points:
                new_level = lv.level

        if new_level > user.level:
            return True, new_level
        return False, None

class PointsService:
    """积分服务"""
    
    @staticmethod
    def add_points(user: User, points: int, change_type: str, description: str, ref_id: int = None):
        """增加积分"""
        before = user.points
        user.points += points
        # 如果有总积分/累计积分字段，也可以增加
        # user.total_points += points 

        log = PointsLog(
            user_id=user.id,
            change_type=change_type,
            change_points=points,
            before_points=before,
            after_points=user.points,
            description=description,
            ref_id=ref_id
        )
        db.session.add(log)

class CheckinService:
    """签到服务"""
    
    def do_checkin(self, user_id: str) -> Dict[str, Any]:
        """执行签到"""
        today = date.today()
        user = db.session.get(User, user_id)
        if not user:
            return {"success": False, "message": "用户不存在"}

        # 1) 检查今日是否已签到
        existing = CheckinRecord.query.filter_by(user_id=user_id, checkin_date=today).first()
        if existing:
            return {
                "success": False,
                "message": "今日已签到",
                "is_checked_today": True,
                "streak_days": user.streak_days,
            }

        # 2) 计算连续签到天数
        yesterday = today - timedelta(days=1)
        if user.last_checkin_date == yesterday:
            streak = user.streak_days + 1
        else:
            streak = 1  # 中断, 重新计数

        # 3) 计算积分
        base_points = LevelService.get_daily_base_points(user.level)
        
        # 连续签到额外加成: 每连续 1 天 +1 积分, 上限 +20
        streak_bonus = min(streak - 1, 20)
        bonus_points = streak_bonus

        # 4) 检查连续签到里程碑奖励
        rewards_earned = self._check_consecutive_rewards(user, streak)
        milestone_bonus = sum(r["reward_value"] for r in rewards_earned)
        bonus_points += milestone_bonus

        total_earned = base_points + bonus_points

        # 5) 创建签到记录
        record = CheckinRecord(
            user_id=user_id,
            checkin_date=today,
            consecutive_day=streak,
            base_points=base_points,
            bonus_points=bonus_points,
            total_points=total_earned
        )
        db.session.add(record)
        db.session.flush()

        # 6) 加积分
        PointsService.add_points(
            user=user,
            points=total_earned,
            change_type="checkin",
            description=f"每日签到(连续第{streak}天)",
            ref_id=record.id
        )

        # 7) 更新用户签到信息
        user.last_checkin_date = today
        user.streak_days = streak
        user.total_checkin_days += 1
        if streak > user.max_streak_days:
            user.max_streak_days = streak

        # 8) 检查是否升级
        level_up, new_level = LevelService.check_level_up(user)
        if level_up and new_level:
            user.level = new_level

        db.session.commit()

        return {
            "success": True,
            "message": "签到成功！",
            "is_checked_today": True,
            "checkin_points": base_points,
            "bonus_points": bonus_points,
            "total_earned": total_earned,
            "streak_days": streak,
            "rewards_earned": rewards_earned,
            "level_up": level_up,
            "new_level": new_level,
            "points": user.points,
        }

    def _check_consecutive_rewards(self, user: User, streak_days: int) -> List[Dict[str, Any]]:
        """检查并发放连续签到奖励"""
        rewards_earned = []
        configs = ConsecutiveRewardConfig.query.filter_by(consecutive_days=streak_days).all()

        for cfg in configs:
            # 检查是否已获得过(非可重复的)
            if not cfg.is_repeatable:
                already = UserReward.query.filter_by(
                    user_id=user.id, 
                    reward_config_id=cfg.id
                ).first()
                if already:
                    continue

            # 发放奖励
            reward = UserReward(
                user_id=user.id,
                reward_config_id=cfg.id,
                consecutive_days=streak_days,
                reward_type=cfg.reward_type,
                reward_value=cfg.reward_value,
                reward_name=cfg.reward_name
            )
            db.session.add(reward)

            rewards_earned.append({
                "consecutive_days": cfg.consecutive_days,
                "reward_name": cfg.reward_name,
                "reward_icon": cfg.reward_icon,
                "reward_value": cfg.reward_value,
                "reward_type": cfg.reward_type,
                "description": cfg.description,
            })

        return rewards_earned

    def get_checkin_page_data(self, user_id: str, year: int = None, month: int = None) -> Dict[str, Any]:
        """获取签到页面所需的全部数据"""
        today = date.today()
        year = year or today.year
        month = month or today.month
        
        user = db.session.get(User, user_id)
        if not user:
            return {"error": "用户不存在"}

        # 1) 月度签到日历
        calendar_days = self._get_month_calendar(user_id, year, month)

        # 2) 等级信息
        level_info = LevelService.get_user_level_info(user)

        # 3) 连续签到奖励进度
        rewards = self._get_consecutive_rewards_progress(user)

        # 4) 今日是否已签到
        is_checked_today = user.last_checkin_date == today

        return {
            "user_id": user.id,
            "nickname": user.nickname,
            "avatar": user.avatar,
            "level_info": level_info,
            "points": user.points,
            "total_checkin_days": user.total_checkin_days,
            "streak_days": user.streak_days,
            "max_streak_days": user.max_streak_days,
            "is_checked_today": is_checked_today,
            "calendar_days": calendar_days,
            "consecutive_rewards": rewards,
        }

    def _get_month_calendar(self, user_id: str, year: int, month: int) -> List[Dict[str, Any]]:
        """获取月度签到日历"""
        import calendar
        _, last_day = calendar.monthrange(year, month)
        
        start_date = date(year, month, 1)
        end_date = date(year, month, last_day) + timedelta(days=1)
            
        records = CheckinRecord.query.filter(
            and_(
                CheckinRecord.user_id == user_id,
                CheckinRecord.checkin_date >= start_date,
                CheckinRecord.checkin_date < end_date
            )
        ).all()
        
        record_map = {r.checkin_date: r for r in records}
        
        calendar_list = []
        curr = start_date
        while curr < end_date:
            record = record_map.get(curr)
            calendar_list.append({
                "date": curr.isoformat(),
                "is_checked": record is not None,
                "points": record.total_points if record else 0,
                "consecutive_day": record.consecutive_day if record else 0
            })
            curr += timedelta(days=1)
            
        return calendar_list

    def _get_consecutive_rewards_progress(self, user: User) -> List[Dict[str, Any]]:
        """获取连续签到奖励进度"""
        configs = ConsecutiveRewardConfig.query.order_by(asc(ConsecutiveRewardConfig.consecutive_days)).all()
        
        # 获取已领取的非重复奖励
        claimed_ids = [r.reward_config_id for r in UserReward.query.filter_by(user_id=user.id).all()]
        
        result = []
        found_next = False
        for cfg in configs:
            is_claimed = cfg.id in claimed_ids
            is_current_target = False
            
            if not found_next and user.streak_days < cfg.consecutive_days:
                is_current_target = True
                found_next = True
                
            result.append({
                "consecutive_days": cfg.consecutive_days,
                "reward_name": cfg.reward_name,
                "reward_icon": cfg.reward_icon,
                "reward_value": cfg.reward_value,
                "reward_type": cfg.reward_type,
                "description": cfg.description,
                "is_claimed": is_claimed,
                "is_current_target": is_current_target
            })
            
        return result
