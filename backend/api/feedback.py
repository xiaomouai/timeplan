"""
用户反馈接口
"""
from flask import request
from flask_jwt_extended import jwt_required, get_jwt_identity
from . import api_v1
from models import db
from models.feedback_model import Feedback
from utils.response import success_response, error_response

@api_v1.route("/feedback", methods=["POST"])
@jwt_required(optional=True)
def submit_feedback():
    """
    提交用户反馈
    ---
    tags:
      - Feedback
    description: 提交用户反馈，登录用户会自动记录user_id，匿名用户也可以提交。
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - content
          properties:
            content:
              type: string
              description: 反馈的具体内容
              example: "这个单词的发音好像不太对。"
            contact:
              type: string
              description: 用户的联系方式（邮箱/手机号），可选
              example: "user@example.com"
            feedback_type:
              type: string
              description: 反馈类型 (bug, suggestion, general)，可选，默认为 general
              example: "bug"
    security:
      - Bearer: []
    responses:
      201:
        description: 反馈提交成功
      400:
        description: 请求参数错误，例如内容为空
    """
    data = request.get_json()
    if not data or not data.get("content"):
        return error_response(400, "反馈内容不能为空")

    # 如果用户已登录，获取用户ID
    user_id = get_jwt_identity()

    try:
        new_feedback = Feedback(
            user_id=user_id,
            content=data["content"],
            contact=data.get("contact"),
            feedback_type=data.get("feedback_type", "general"),
        )

        db.session.add(new_feedback)
        db.session.commit()

        return success_response(
            new_feedback.to_dict(),
            message="感谢您的反馈！我们已经收到您的消息。",
            status_code=201,
        )
    except Exception as e:
        db.session.rollback()
        # 在生产环境中应该记录错误日志
        print(f"Error submitting feedback: {e}")
        return error_response(500, "提交失败，请稍后重试")
