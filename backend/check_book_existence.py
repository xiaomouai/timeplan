from app import app
from models.word_models import WordBook, Word

with app.app_context():
    book = WordBook.query.filter_by(id='PEPXiaoXue5_1').first()
    if book:
        print(f"Book found: {book.id}, title: {book.title}")
        word_count = Word.query.filter_by(book_id='PEPXiaoXue5_1').count()
        print(f"Word count for PEPXiaoXue5_1: {word_count}")
    else:
        print("Book PEPXiaoXue5_1 not found in database.")

    # Also list some available books and their word counts
    print("\nAvailable books and word counts:")
    books = WordBook.query.limit(10).all()
    for b in books:
        word_count = Word.query.filter_by(book_id=b.id).count()
        print(f"- {b.id}: {b.title} (Words: {word_count})")
