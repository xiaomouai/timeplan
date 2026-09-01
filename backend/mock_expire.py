
from app import create_app
from extensions import db
from models.membership_models import UserMembership
from datetime import datetime, timedelta

def mock_expire(user_id):
    app = create_app()
    with app.app_context():
        membership = UserMembership.query.filter_by(user_id=user_id).first()
        if not membership:
            print(f"User {user_id} has no membership record. Creating one...")
            membership = UserMembership(
                user_id=user_id,
                membership_type='month',
                expire_time=datetime.now() - timedelta(days=1),
                status='active'
            )
            db.session.add(membership)
        else:
            print(f"Updating membership for user {user_id} to expired...")
            membership.expire_time = datetime.now() - timedelta(days=1)
            membership.status = 'active' # Status is active but time is expired
            
        db.session.commit()
        print("Success! Membership set to expire 1 day ago.")

if __name__ == "__main__":
    import sys
    user_id = sys.argv[1] if len(sys.argv) > 1 else '3c811b3ffa1041689d6620d7'
    mock_expire(user_id)
