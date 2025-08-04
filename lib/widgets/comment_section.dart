import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/jwt_storage.dart';

class CommentSection extends StatefulWidget {
  final int postId;

  const CommentSection({super.key, required this.postId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _controller = TextEditingController();
  final Dio _dio = Dio();
  List<dynamic> _comments = [];
  bool _isLoading = false;
  int? currentUserId;
  int? _replyTo;
  static const int maxLength = 200;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndComments();
  }

  Future<void> _loadUserIdAndComments() async {
    currentUserId = await JwtStorage.getUserId();
    _loadComments();
  }

  Future<String?> _getAccessToken() async {
    return await JwtStorage.getAccessToken();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get(
        'https://connect.io.kr/posts/${widget.postId}/comments',
      );
      setState(() => _comments = res.data);
    } catch (e) {
      debugPrint('댓글 불러오기 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty || content.length > maxLength) return;

    try {
      final accessToken = await _getAccessToken();
      await _dio.post(
        'https://connect.io.kr/posts/${widget.postId}/comments',
        data: {
          'content': content,
          if (_replyTo != null) 'parent_id': _replyTo,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );
      _controller.clear();
      _replyTo = null;
      _loadComments();
    } catch (e) {
      debugPrint('댓글 등록 실패: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      final accessToken = await _getAccessToken();
      await _dio.delete(
        'https://connect.io.kr/posts/comments/$commentId',
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );
      _loadComments();
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
    }
  }

  void _showEditDialog(Map<String, dynamic> comment) {
    final editController = TextEditingController(text: comment['content']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          maxLength: maxLength,
          decoration: const InputDecoration(hintText: '수정할 내용을 입력하세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty || newText.length > maxLength) return;

              try {
                final accessToken = await _getAccessToken();
                await _dio.put(
                  'https://connect.io.kr/posts/comments/${comment['id']}',
                  data: {'content': newText},
                  options: Options(headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Content-Type': 'application/json',
                  }),
                );
                Navigator.pop(context);
                _loadComments();
              } catch (e) {
                debugPrint('댓글 수정 실패: $e');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> c, {int indent = 0}) {
    final isMine = currentUserId != null && c['user_id'] == currentUserId;
    final isDeleted = c['is_deleted'] == true;
    final user = c['user'];
    final nickname = user?['nickname'] ?? '익명';
    final avatarUrl = user?['avatar_url'];

    return Padding(
      padding: EdgeInsets.only(left: 16.0 * indent, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: isDeleted
                ? null
                : CircleAvatar(
                    backgroundImage: avatarUrl != null
                        ? NetworkImage('https://connect.io.kr$avatarUrl')
                        : null,
                    child: avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
            title: Text(isDeleted ? '알 수 없음' : nickname),
            subtitle: Text(
              isDeleted ? '[삭제된 댓글]' : c['content'],
              style: TextStyle(color: isDeleted ? Colors.grey : null),
            ),
            trailing: isDeleted
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c['created_at']?.substring(0, 10) ?? ''),
                      if (isMine) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditDialog(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteComment(c['id']),
                        ),
                      ],
                    ],
                  ),
          ),
          if (!isDeleted)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _controller.text = '@$nickname ';
                    _replyTo = c['id'];
                  });
                },
                child: const Text('답글 달기', style: TextStyle(fontSize: 13)),
              ),
            ),
          if (c['replies'] != null && c['replies'].isNotEmpty)
            ...List.generate(
              c['replies'].length,
              (i) => _buildComment(c['replies'][i], indent: indent + 1),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('댓글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Text('아직 댓글이 없습니다.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              return _buildComment(_comments[index]);
            },
          ),
        const Divider(),
        if (_replyTo != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              children: [
                Text('답글 작성 중...', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _replyTo = null;
                      _controller.clear();
                    });
                  },
                  child: const Text('취소', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: maxLength,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitComment,
            ),
          ],
        ),
      ],
    );
  }
}
