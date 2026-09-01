from app import create_app
from models.user_models import User
from extensions import db
from datetime import datetime, timedelta

def mock_user_creation(user_id):
    app = create_app()
    with app.app_context():
        user = User.query.get(user_id)
        if user:
            print(f"Updating user {user_id} creation date to 10 days ago...")
            user.created_at = datetime.now() - timedelta(days=10)
            db.session.commit()
            print("Success!")
        else:
            print(f"User {user_id} not found.")

if __name__ == "__main__":
    mock_user_creation('00cd8dc12b2b477590123cae')
