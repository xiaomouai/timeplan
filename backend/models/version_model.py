from extensions import db
from datetime import datetime

class AppVersion(db.Model):
    """应用版本模型"""
    __tablename__ = 'app_versions'

    id = db.Column(db.Integer, primary_key=True)
    platform = db.Column(db.String(20), nullable=False, default='android')  # android, ios
    version = db.Column(db.String(20), nullable=False)  # e.g., 1.2.0
    build_number = db.Column(db.Integer, nullable=False)  # e.g., 12
    changelog = db.Column(db.Text)  # 更新日志，可以使用 JSON 字符串或换行分隔
    download_url = db.Column(db.String(255))
    force_update = db.Column(db.Boolean, default=False)
    file_size = db.Column(db.String(50))
    md5 = db.Column(db.String(32))
    is_latest = db.Column(db.Boolean, default=False)
    release_date = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'platform': self.platform,
            'version': self.version,
            'build_number': self.build_number,
            'changelog': self.changelog.split('\n') if self.changelog else [],
            'download_url': self.download_url,
            'force_update': self.force_update,
            'file_size': self.file_size,
            'md5': self.md5,
            'is_latest': self.is_latest,
            'release_date': self.release_date.strftime('%Y-%m-%d') if self.release_date else None
        }

class ApiVersion(db.Model):
    """API 版本模型"""
    __tablename__ = 'api_versions'

    id = db.Column(db.Integer, primary_key=True)
    version = db.Column(db.String(20), nullable=False)  # e.g., 2.0.0
    build = db.Column(db.Integer, nullable=False)
    min_app_version = db.Column(db.String(20), default='1.0.0')
    features = db.Column(db.Text)  # 功能列表，换行分隔
    release_date = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)

    def to_dict(self):
        return {
            'version': self.version,
            'build': self.build,
            'release_date': self.release_date.strftime('%Y-%m-%d') if self.release_date else None,
            'min_app_version': self.min_app_version,
            'features': self.features.split('\n') if self.features else []
        }
