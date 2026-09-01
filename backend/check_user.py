
from app import create_app
from models.user_models import User
from models.membership_models import UserMembership
from datetime import datetime, timedelta

def check_user_status(user_id):
    app = create_app()
    with app.app_context():
        user = User.query.get(user_id)
        if not user:
            print(f"User {user_id} not found.")
            return
        
        print(f"User ID: {user.id}")
        print(f"Created At: {user.created_at}")
        
        membership = UserMembership.query.filter_by(user_id=user_id).first()
        if membership:
            print(f"Membership Type: {membership.membership_type}")
            print(f"Expire Time: {membership.expire_time}")
            print(f"Status: {membership.status}")
        else:
            print("No membership record found.")

if __name__ == "__main__":
    check_user_status('00cd8dc12b2b477590123cae')
