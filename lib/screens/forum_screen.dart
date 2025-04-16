import 'dart:io';
import 'package:flutter/material.dart';
import 'package:finsight/forum/forum_enhancements.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({Key? key}) : super(key: key);

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _createNewPost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreatePostScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B3A55),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search community...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Community', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: NotificationBadge(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              color: Colors.white,
            ),
            onPressed: () {
              if (FirebaseAuth.instance.currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(
                      userId: FirebaseAuth.instance.currentUser!.uid,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to view notifications')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createNewPost,
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            color: Colors.white,
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE5BA73),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Popular'),
            Tab(text: 'Recent'),
            Tab(text: 'My Posts'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsList('popular'),
            _buildPostsList('recent'),
            _buildPostsList('my_posts'),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(String type) {
    Query query;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FirebaseAuth auth = FirebaseAuth.instance;

    if (_searchQuery.isNotEmpty) {
      query = firestore
          .collection('forum_posts')
          .where('title', isGreaterThanOrEqualTo: _searchQuery)
          .where('title', isLessThan: _searchQuery + 'z');
    } else {
      switch (type) {
        case 'popular':
          query = firestore
              .collection('forum_posts')
              .orderBy('likes', descending: true);
          break;
        case 'recent':
          query = firestore
              .collection('forum_posts')
              .orderBy('timestamp', descending: true);
          break;
        case 'my_posts':
          if (auth.currentUser != null) {
            query = firestore
                .collection('forum_posts')
                .where('userId', isEqualTo: auth.currentUser!.uid);
          } else {
            query = firestore.collection('forum_posts').limit(0);
          }
          break;
        default:
          query = firestore
              .collection('forum_posts')
              .orderBy('timestamp', descending: true);
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (type == 'my_posts' && auth.currentUser == null) {
            return const Center(child: Text('Please sign in to see your posts'));
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No results found for "$_searchQuery"'
                        : 'No posts yet',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5BA73),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _createNewPost,
                    child: const Text(
                      'Create a post',
                      style: TextStyle(color: Color(0xFF2B3A55)),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final postData = doc.data() as Map<String, dynamic>;

            return PostCard(
              postId: doc.id,
              title: postData['title'] ?? 'No title',
              content: postData['content'] ?? 'No content',
              author: postData['authorName'] ?? auth.currentUser?.email ?? 'User',
              authorId: postData['userId'] ?? '',
              timestamp: postData['timestamp'] != null
                  ? (postData['timestamp'] as Timestamp).toDate()
                  : DateTime.now(),
              likes: postData['likes'] ?? 0,
              commentCount: postData['commentCount'] ?? 0,
              imageUrl: postData['imageUrl'],
              category: postData['category'] ?? 'General',
            );
          },
        );
      },
    );
  }
}

class PostCard extends StatelessWidget {
  final String postId;
  final String title;
  final String content;
  final String author;
  final String authorId;
  final DateTime timestamp;
  final int likes;
  final int commentCount;
  final String? imageUrl;
  final String category;

  const PostCard({
    Key? key,
    required this.postId,
    required this.title,
    required this.content,
    required this.author,
    required this.authorId,
    required this.timestamp,
    required this.likes,
    required this.commentCount,
    this.imageUrl,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeAgo = _getTimeAgo(timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(postId: postId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF2B3A55).withOpacity(0.1),
                    child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF2B3A55),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap( // Replaced Row with Wrap to prevent overflow
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              author,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            ReputationBadge(userId: authorId),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5BA73).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2B3A55),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3A55),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content.length > 100 ? '${content.substring(0, 100)}...' : content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (imageUrl != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.thumb_up_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$likes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$commentCount',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSubmitting = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _incrementViewCount() async {
    try {
      await _firestore.collection('forum_posts').doc(widget.postId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  void _checkIfLiked() async {
    if (_auth.currentUser != null) {
      try {
        final likeDoc = await _firestore
            .collection('forum_posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(_auth.currentUser!.uid)
            .get();

        setState(() {
          _isLiked = likeDoc.exists;
        });
      } catch (e) {
        print('Error checking like status: $e');
      }
    }
  }

  void _toggleLike() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    final userId = _auth.currentUser!.uid;
    final likeRef = _firestore
        .collection('forum_posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(userId);

    final postRef = _firestore.collection('forum_posts').doc(widget.postId);

    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      if (_isLiked) {
        // Add like
        await likeRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });

        // Add notification and reputation tracking
        final postDoc = await postRef.get();
        final postData = postDoc.data() as Map<String, dynamic>?;
        if (postData != null) {
          final authorId = postData['userId'];
          final currentUser = _auth.currentUser;
          if (authorId != currentUser?.uid) {
            final notificationService = NotificationService();
            notificationService.notifyPostLike(
              widget.postId,
              authorId,
              currentUser?.displayName ?? 'Someone',
            );

            // Track reputation
            final reputationService = ReputationService();
            reputationService.trackPostLiked(authorId);
          }
        }
      } else {
        // Remove like
        await likeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      // Revert state if operation fails
      setState(() {
        _isLiked = !_isLiked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _submitComment() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    final User? ownUser = _auth.currentUser;
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Add comment to post
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'content': commentText,
        'userId': _auth.currentUser!.uid,
        'authorName': ownUser?.displayName ?? ownUser?.email ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Increment comment count
      await _firestore.collection('forum_posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Add notification and reputation tracking
      final postDoc = await _firestore.collection('forum_posts').doc(widget.postId).get();
      final postData = postDoc.data() as Map<String, dynamic>?;
      if (postData != null) {
        final authorId = postData['userId'];
        final currentUser = _auth.currentUser;
        if (authorId != currentUser?.uid) {
          final notificationService = NotificationService();
          notificationService.notifyNewComment(
            widget.postId,
            authorId,
            currentUser?.displayName ?? 'Someone',
          );
        }

        // Track reputation for commenter
        final reputationService = ReputationService();
        reputationService.trackCommentAdded(currentUser!.uid);
      }

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B3A55),
        title: const Text('Post Details', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('forum_posts').doc(widget.postId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
              );
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Post not found'));
            }

            final postData = snapshot.data!.data() as Map<String, dynamic>;
            final DateTime timestamp = postData['timestamp'] != null
                ? (postData['timestamp'] as Timestamp).toDate()
                : DateTime.now();

            return Column(
              children: [
                // Post content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post details
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF2B3A55).withOpacity(0.1),
                                    child: Text(
                                      postData['authorName'] != null &&
                                              (postData['authorName'] as String).isNotEmpty
                                          ? (postData['authorName'] as String)[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Color(0xFF2B3A55),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          postData['authorName'] ??
                                              _auth.currentUser?.email ??
                                              'User',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('MMM d, yyyy • h:mm a').format(timestamp),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5BA73).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  postData['category'] ?? 'General',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF2B3A55),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                postData['title'] ?? 'No title',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B3A55),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                postData['content'] ?? 'No content',
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              if (postData['imageUrl'] != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      postData['imageUrl'],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _toggleLike,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                            size: 20,
                                            color: _isLiked ? const Color(0xFFE5BA73) : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${postData['likes'] ?? 0}',
                                            style: TextStyle(
                                              color: _isLiked ? const Color(0xFFE5BA73) : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      Icon(Icons.remove_red_eye_outlined,
                                          size: 20, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${postData['views'] ?? 0}',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Comments section
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Comments (${postData['commentCount'] ?? 0})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3A55),
                            ),
                          ),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('forum_posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, commentSnapshot) {
                            if (commentSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: Color(0xFFE5BA73)),
                              );
                            }

                            if (!commentSnapshot.hasData || commentSnapshot.data!.docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.chat_bubble_outline,
                                          size: 40, color: Colors.grey[300]),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No comments yet',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Be the first to comment',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: commentSnapshot.data!.docs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                final commentDoc = commentSnapshot.data!.docs[index];
                                final commentData = commentDoc.data() as Map<String, dynamic>;
                                final DateTime commentTime = commentData['timestamp'] != null
                                    ? (commentData['timestamp'] as Timestamp).toDate()
                                    : DateTime.now();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF2B3A55).withOpacity(0.1),
                                        child: Text(
                                          commentData['authorName'] != null &&
                                                  (commentData['authorName'] as String).isNotEmpty
                                              ? (commentData['authorName'] as String)[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Color(0xFF2B3A55),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  commentData['authorName'] ?? 'User',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  DateFormat('MMM d • h:mm a').format(commentTime),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              commentData['content'] ?? '',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Comment input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(0xFFE5BA73),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: _isSubmitting ? null : _submitComment,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF2B3A55),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Color(0xFF2B3A55),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedCategory = 'General';
  List<String> _selectedTags = [];
  bool _isPosting = false;
  File? _imageFile;

  final List<String> _categories = [
    'General',
    'Budgeting',
    'Investing',
    'Saving',
    'Debt Management',
    'Financial Planning'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) {
      return null;
    }

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('post_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _createPost() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a post')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // Upload image if selected
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage();
      }

      final ownUser = _auth.currentUser;
      // Create post document
      await _firestore.collection('forum_posts').add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'tags': _selectedTags,
        'userId': _auth.currentUser!.uid,
        'authorName': ownUser?.displayName ?? ownUser?.email ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'likes': 0,
        'commentCount': 0,
        'views': 0,
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B3A55),
        title: const Text('Create Post', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _createPost,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFFE5BA73),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: Color(0xFFE5BA73),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Selection
                const Text(
                  'Category',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2B3A55),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE5BA73)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF2B3A55)
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TopicTagSelector(
                  selectedTags: _selectedTags,
                  onTagsChanged: (tags) {
                    setState(() {
                      _selectedTags = tags;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A55),
                  ),
                  maxLines: 2,
                ),
                const Divider(),

                // Content
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                  maxLines: null,
                  minLines: 6,
                ),

                // Image Preview
                if (_imageFile != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imageFile!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _imageFile = null;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Add image button
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_outlined, color: Color(0xFF2B3A55)),
                  label: const Text('Add Image', style: TextStyle(color: Color(0xFF2B3A55))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}