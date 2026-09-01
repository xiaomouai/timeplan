"""
教材相关API接口（重构版 - 使用MySQL数据库）
"""
from flask import request, jsonify
from . import api_v1
from services.word_service import WordService
from utils.response import success_response, error_response


@api_v1.route('/textbooks', methods=['GET'])
def get_textbooks():
    """
    获取教材版本列表
    ---
    tags:
      - 教材管理
    summary: 获取教材版本列表
    description: 获取所有可用的教材版本，支持按分类筛选
    parameters:
      - name: category
        in: query
        type: string
        required: false
        description: 教材分类
        enum: [小学, 初中, 高中]
        example: 小学
    responses:
      200:
        description: 成功获取教材列表
    """
    category = request.args.get('category')
    
    # 从数据库获取词书列表进行统计
    books = WordService.get_books(category=category)
    
    # 按出版社组织教材数据
    textbook_map = {}
    for book in books:
        tags = book.get('tags', [])
        publisher = '人教版'  # 默认
        
        # 解析出版社标签
        for tag in tags:
            if '人教版' in tag:
                publisher = '人教版'
            elif '外研社' in tag or '外研版' in tag:
                publisher = '外研社版'
            elif '北师大' in tag:
                publisher = '北师大版'
            elif '牛津' in tag:
                publisher = '牛津版'
        
        if publisher not in textbook_map:
            textbook_map[publisher] = {
                'id': publisher.replace('版', '').upper(),
                'name': publisher,
                'publisher': f"{publisher.replace('版', '')}出版社",
                'icon': book.get('cover', ''),
                'grades': set(),
                'categories': set(),
                'book_count': 0,
                'word_count': 0
            }
        
        # 统计信息
        textbook_map[publisher]['book_count'] += 1
        textbook_map[publisher]['word_count'] += book.get('word_num', 0)
        
        # 解析年级和分类
        for tag in tags:
            if '年级' in tag:
                try:
                    grade = int(tag.replace('年级', ''))
                    textbook_map[publisher]['grades'].add(grade)
                except:
                    pass
            if tag in ['小学', '初中', '高中']:
                textbook_map[publisher]['categories'].add(tag)
    
    # 转换为列表
    textbooks = []
    for pub, data in textbook_map.items():
        textbooks.append({
            'id': data['id'],
            'name': data['name'],
            'publisher': data['publisher'],
            'icon': data['icon'],
            'grades': sorted(list(data['grades'])),
            'categories': list(data['categories']),
            'bookCount': data['book_count'],
            'totalWords': data['word_count']
        })
    
    # 总体统计
    total_books = sum(t['bookCount'] for t in textbooks)
    total_words = sum(t['totalWords'] for t in textbooks)
    
    return success_response({
        'textbooks': textbooks,
        'statistics': {
            'totalTextbooks': len(textbooks),
            'totalBooks': total_books,
            'totalWords': total_words
        }
    })


@api_v1.route('/categories', methods=['GET'])
def get_categories():
    """
    获取教材分类列表
    ---
    tags:
      - 教材管理
    summary: 获取教材分类列表
    responses:
      200:
        description: 成功
    """
    # 这里返回系统中支持的所有分类
    categories = ["小学", "初中", "高中", "大学", "考研", "出国", "其他"]
    return success_response(categories)


@api_v1.route('/books', methods=['GET'])
def get_books():
    """
    获取所有词书列表
    ---
    tags:
      - 教材管理
    summary: 获取所有词书列表
    description: 获取所有词书，支持按分类、年级、标签筛选
    parameters:
      - name: category
        in: query
        type: string
        required: false
        description: 教材分类
      - name: grade
        in: query
        type: integer
        required: false
        description: 年级
      - name: tags
        in: query
        type: string
        required: false
        description: 标签筛选
    responses:
      200:
        description: 成功获取词书列表
    """
    category = request.args.get('category')
    grade = request.args.get('grade', type=int)
    tags = request.args.get('tags')
    
    # Handle "全部" or empty category
    if category == '全部':
        category = None
    
    books = WordService.get_books(category=category, grade=grade, tags=tags)
    
    # 格式化返回数据
    formatted_books = []
    for book in books:
        # 解析标签
        book_tags = book.get('tags', [])
        category_val = ''
        grade_val = 0
        term_val = 0
        tag_val = ''
        
        for tag in book_tags:
            if tag in ['小学', '初中', '高中']:
                category_val = tag
            if '年级' in tag:
                try:
                    grade_val = int(tag.replace('年级', ''))
                except:
                    pass
            if '上册' in tag:
                term_val = 1
            elif '下册' in tag:
                term_val = 2
            if '人教版' in tag or '外研社' in tag or '北师大' in tag:
                tag_val = tag
        
        formatted_books.append({
            'id': book['id'],
            'bookId': book['id'],
            'title': book['title'],
            'name': book['title'],
            'wordCount': book.get('word_num', 0),
            'grade': grade_val,
            'term': term_val,
            'category': category_val,
            'tag': tag_val,
            'icon': book.get('cover', ''),
            'coverUrl': book.get('cover', ''),
            'popularity': book.get('recite_user_num', 0),
            'size': book.get('size', 0),
            'introduce': book.get('introduce', ''),
            'offlineData': book.get('offline_data', ''),
        })
    
    return success_response(formatted_books)


@api_v1.route('/books/<book_id>', methods=['GET'])
def get_book_detail(book_id):
    """获取词书详情，兼容旧 Flutter 客户端路径。"""
    book = WordService.get_book_by_id(book_id)
    if not book:
        return error_response(404, '词书不存在')
    statistics = WordService.get_book_statistics(book_id)
    return success_response({
        **book,
        'bookId': book_id,
        'wordCount': statistics.get('word_count', book.get('word_num', 0)),
    })


@api_v1.route('/textbooks/<textbook_id>/books', methods=['GET'])
def get_textbook_books(textbook_id):
    """
    获取教材的词书列表
    ---
    tags:
      - 教材管理
    summary: 获取指定教材的词书列表
    parameters:
      - name: textbook_id
        in: path
        type: string
        required: true
        description: 教材ID
      - name: grade
        in: query
        type: integer
        required: false
        description: 年级
      - name: term
        in: query
        type: integer
        required: false
        description: 学期
      - name: category
        in: query
        type: string
        required: false
        description: 分类
    responses:
      200:
        description: 成功
    """
    grade = request.args.get('grade', type=int)
    term = request.args.get('term', type=int)
    category = request.args.get('category')
    
    # 根据textbook_id确定出版社标签
    textbook_tags = {
        'PEP': '人教版',
        'WAIYANSHE': '外研社',
        'BEISHI': '北师大',
        'NIUJIN': '牛津'
    }
    publisher_tag = textbook_tags.get(textbook_id, '')
    
    # 从数据库获取词书
    books = WordService.get_books(category=category, grade=grade, tags=publisher_tag)
    
    # 格式化返回数据
    formatted_books = []
    for book in books:
        book_tags = book.get('tags', [])
        
        # 解析信息
        grade_val = 0
        term_val = 0
        category_val = ''
        tag_val = ''
        
        for tag in book_tags:
            if '年级' in tag:
                try:
                    grade_val = int(tag.replace('年级', ''))
                except:
                    pass
            if '上册' in tag:
                term_val = 1
            elif '下册' in tag:
                term_val = 2
            if tag in ['小学', '初中', '高中']:
                category_val = tag
            if publisher_tag and publisher_tag in tag:
                tag_val = tag
        
        # 应用term筛选
        if term and term_val != term:
            continue
        
        formatted_books.append({
            'id': book['id'],
            'bookId': book['id'],
            'title': book['title'],
            'wordCount': book.get('word_num', 0),
            'grade': grade_val,
            'term': term_val,
            'category': category_val,
            'tag': tag_val,
            'icon': book.get('cover', ''),
            'popularity': book.get('recite_user_num', 0),
            'isLocked': False,  # TODO: 根据用户会员状态判断
            'userProgress': {
                'learnedWords': 0,
                'masteredWords': 0,
                'progress': 0
            }
        })
    
    return success_response({
        'textbook': {
            'id': textbook_id,
            'name': publisher_tag,
            'grade': grade,
            'term': term,
            'category': category
        },
        'books': formatted_books,
        'total': len(formatted_books)
    })


@api_v1.route('/books/<book_id>/words', methods=['GET'])
def get_book_words(book_id):
    """
    获取词书的单词列表
    ---
    tags:
      - 教材管理
    summary: 获取词书的单词列表（分页）
    parameters:
      - name: book_id
        in: path
        type: string
        required: true
        description: 词书ID
      - name: page
        in: query
        type: integer
        required: false
        default: 1
        description: 页码
      - name: page_size
        in: query
        type: integer
        required: false
        default: 20
        description: 每页数量
      - name: sort
        in: query
        type: string
        required: false
        default: rank
        description: 排序方式
    responses:
      200:
        description: 成功
      404:
        description: 词书不存在
    """
    page = request.args.get('page', 1, type=int)
    page_size = request.args.get('page_size', 20, type=int)
    sort = request.args.get('sort', 'rank')
    
    # 获取词书信息
    book = WordService.get_book_by_id(book_id)
    
    if not book:
        return error_response(404, '词书不存在')
    
    # 从数据库获取单词
    result = WordService.get_words_paginated(book_id, page, page_size)
    
    return success_response({
        'book': {
            'id': book_id,
            'title': book['title'],
            'wordCount': result['total']
        },
        'words': result['words'],
        'pagination': {
            'page': result['page'],
            'page_size': result['page_size'],
            'total': result['total'],
            'total_pages': result['total_pages']
        },
        'statistics': {
            'learned': 0,  # TODO: 从用户学习记录获取
            'mastered': 0,
            'progress': 0
        }
    })


@api_v1.route('/books/<book_id>/units', methods=['GET'])
def get_book_units(book_id):
    """
    获取词书的单元列表
    ---
    tags:
      - 教材管理
    summary: 获取词书的单元列表
    parameters:
      - name: book_id
        in: path
        type: string
        required: true
        description: 词书ID
    responses:
      200:
        description: 成功
      404:
        description: 词书不存在
    """
    book = WordService.get_book_by_id(book_id)
    if not book:
        return error_response(404, '词书不存在')
    
    # TODO: 从数据库获取真实单元数据
    # 目前返回模拟单元数据
    units = [
        {
            'id': f'unit_{i:03d}',
            'name': f'Unit {i}',
            'wordCount': 10,
            'learnedCount': 0,
            'progress': 0,
            'isLocked': i > 1,
            'stars': 0,
            'sortOrder': i
        }
        for i in range(1, 7)
    ]
    
    return success_response({
        'book': {
            'id': book_id,
            'title': book['title']
        },
        'units': units,
        'total': len(units)
    })


@api_v1.route('/units/<unit_id>/words', methods=['GET'])
def get_unit_words(unit_id):
    """
    获取单元的单词列表
    ---
    tags:
      - 教材管理
    summary: 获取单元的单词列表
    parameters:
      - name: unit_id
        in: path
        type: string
        required: true
        description: 单元ID
    responses:
      200:
        description: 成功
    """
    # TODO: 从数据库获取单元关联的单词
    return success_response({
        'unit': {
            'id': unit_id,
            'name': 'Unit 1',
            'bookId': 'PEPXiaoXue3_1'
        },
        'words': [],
        'total': 0
    })
