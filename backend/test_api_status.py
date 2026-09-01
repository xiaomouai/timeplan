from app import create_app
from services.membership_service import MembershipService
import json

def test_status(user_id):
    app = create_app()
    with app.app_context():
        stats = MembershipService.get_membership_stats(user_id)
        print(json.dumps(stats, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    test_status('00cd8dc12b2b477590123cae')
