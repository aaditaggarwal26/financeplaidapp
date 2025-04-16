import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Tags System
class TopicTagSelector extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onTagsChanged;
  final bool readOnly;

  const TopicTagSelector({
    Key? key,
    required this.selectedTags,
    required this.onTagsChanged,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<TopicTagSelector> createState() => _TopicTagSelectorState();
}

class _TopicTagSelectorState extends State<TopicTagSelector> {
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  bool _isAddingTag = false;

  // Some predefined finance-related tags for easy access
  final List<String> _suggestedTags = [
    'Investing', 'Saving', 'Budgeting', 'Debt', 'Retirement', 
    'Taxes', 'Insurance', 'Real Estate', 'Stocks', 'Crypto',
    'Financial Independence', 'Credit Score', 'Emergency Fund'
  ];

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.trim().isEmpty) return;
    
    final newTag = tag.trim();
    if (!widget.selectedTags.contains(newTag)) {
      final updatedTags = [...widget.selectedTags, newTag];
      widget.onTagsChanged(updatedTags);
    }
    
    _tagController.clear();
    setState(() {
      _isAddingTag = false;
    });
  }

  void _removeTag(String tag) {
    if (widget.readOnly) return;
    
    final updatedTags = widget.selectedTags.where((t) => t != tag).toList();
    widget.onTagsChanged(updatedTags);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.readOnly) ...[
          const Text(
            'Tags',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2B3A55),
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // This displays teh selected tags
            ...widget.selectedTags.map((tag) => _buildTagChip(tag)),
            
            // Adds the tag button or input field
            if (!widget.readOnly && !_isAddingTag)
              InkWell(
                onTap: () {
                  setState(() {
                    _isAddingTag = true;
                  });
                  Future.delayed(const Duration(milliseconds: 50), () {
                    _tagFocusNode.requestFocus();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 4),
                      Text('Add Tag'),
                    ],
                  ),
                ),
              ),
            
            // Tag input field
            if (!widget.readOnly && _isAddingTag)
              Container(
                height: 36,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2B3A55)),
                ),
                child: TextField(
                  controller: _tagController,
                  focusNode: _tagFocusNode,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: InputBorder.none,
                    hintText: 'Add new tag',
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: _addTag,
                  onEditingComplete: () {
                    _addTag(_tagController.text);
                  },
                ),
              ),
          ],
        ),
        
        // Suggested tags
        if (!widget.readOnly && _isAddingTag) ...[
          const SizedBox(height: 12),
          const Text(
            'Suggested tags:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTags
                .where((tag) => !widget.selectedTags.contains(tag))
                .map((tag) => InkWell(
                      onTap: () => _addTag(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5BA73).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2B3A55),
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _removeTag(tag),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF2B3A55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Reputation System
class ReputationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Award points for various actions
  Future<void> awardPoints(String userId, String action, int points) async {
    if (userId.isEmpty) return;
    
    try {
      await _firestore.collection('users').doc(userId).update({
        'reputation': FieldValue.increment(points),
        'activities': FieldValue.arrayUnion([{
          'action': action,
          'points': points,
          'timestamp': FieldValue.serverTimestamp(),
        }]),
      });
      
      // Check for badges/levels after awarding points
      await _checkForNewLevel(userId);
    } catch (e) {
      print('Error awarding points: $e');
    }
  }
  
  // Get user reputation
  Future<Map<String, dynamic>> getUserReputation(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return {'reputation': 0, 'level': 'Newcomer'};
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final reputation = data['reputation'] ?? 0;
      
      return {
        'reputation': reputation,
        'level': _calculateLevel(reputation),
        'badges': data['badges'] ?? [],
      };
    } catch (e) {
      print('Error getting reputation: $e');
      return {'reputation': 0, 'level': 'Newcomer'};
    }
  }
  
  // Calculate level based on points
  String _calculateLevel(int points) {
    if (points < 50) return 'Newcomer';
    if (points < 150) return 'Regular';
    if (points < 300) return 'Contributor';
    if (points < 500) return 'Expert';
    if (points < 1000) return 'Master';
    return 'Legend';
  }
  
  // Check if user reached a new level
  Future<void> _checkForNewLevel(String userId) async {
    try {
      final data = await getUserReputation(userId);
      final newLevel = data['level'];
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentLevel = userDoc.data()?['level'] ?? '';
      
      if (newLevel != currentLevel) {
        await _firestore.collection('users').doc(userId).update({
          'level': newLevel,
        });
        
        // Notify user about new level
        _notifyLevelUp(userId, newLevel);
      }
    } catch (e) {
      print('Error checking for new level: $e');
    }
  }
  
  // Send a notification for level up
  void _notifyLevelUp(String userId, String newLevel) {
    // This would integrate with the notification system
    print('User $userId leveled up to $newLevel');
  }
  
  // Track post creation
  Future<void> trackPostCreated(String userId) async {
    await awardPoints(userId, 'post_created', 5);
  }
  
  // Track comment added
  Future<void> trackCommentAdded(String userId) async {
    await awardPoints(userId, 'comment_added', 2);
  }
  
  // Track post liked
  Future<void> trackPostLiked(String authorId) async {
    await awardPoints(authorId, 'post_liked', 2);
  }
}

// ===== Notifications System =====
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create a notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? postId,
    String? commentId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'type': type,
        'postId': postId,
        'commentId': commentId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      // Update unread count
      await _firestore.collection('users').doc(userId).update({
        'unreadNotifications': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
  
  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
      });
      
      // Update unread count
      await _firestore.collection('users').doc(userId).update({
        'unreadNotifications': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
  
  // Get notifications
  Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  
  // Get unread count
  Stream<DocumentSnapshot> getUnreadCount(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
  
  // Notify about post like
  Future<void> notifyPostLike(String postId, String authorId, String likerName) async {
    await createNotification(
      userId: authorId,
      title: 'Someone liked your post',
      message: '$likerName liked your post',
      type: 'post_like',
      postId: postId,
    );
  }
  
  // Notify about new comment
  Future<void> notifyNewComment(String postId, String authorId, String commenterName) async {
    await createNotification(
      userId: authorId,
      title: 'New comment on your post',
      message: '$commenterName commented on your post',
      type: 'new_comment',
      postId: postId,
    );
  }
}

// ===== UI Components =====

// Reputation Badge
class ReputationBadge extends StatelessWidget {
  final String userId;
  
  const ReputationBadge({Key? key, required this.userId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final reputationService = ReputationService();
    
    return FutureBuilder<Map<String, dynamic>>(
      future: reputationService.getUserReputation(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!;
        final level = data['level'];
        final reputation = data['reputation'];
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getLevelColor(level).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getLevelIcon(level),
                size: 14,
                color: _getLevelColor(level),
              ),
              const SizedBox(width: 4),
              Text(
                '$level • $reputation pts',
                style: TextStyle(
                  fontSize: 12,
                  color: _getLevelColor(level),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getLevelColor(String level) {
    switch (level) {
      case 'Newcomer': return Colors.green;
      case 'Regular': return Colors.blue;
      case 'Contributor': return Colors.orange;
      case 'Expert': return Colors.purple;
      case 'Master': return Colors.red;
      case 'Legend': return Colors.amber;
      default: return Colors.grey;
    }
  }
  
  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Newcomer': return Icons.emoji_people;
      case 'Regular': return Icons.person;
      case 'Contributor': return Icons.star;
      case 'Expert': return Icons.psychology;
      case 'Master': return Icons.workspace_premium;
      case 'Legend': return Icons.diamond;
      default: return Icons.person;
    }
  }
}

// Notification Icon with Badge
class NotificationBadge extends StatelessWidget {
  final String userId;
  
  const NotificationBadge({Key? key, required this.userId, required Color color}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    
    return StreamBuilder<DocumentSnapshot>(
      stream: notificationService.getUnreadCount(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Icon(Icons.notifications_none);
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final unreadCount = data['unreadNotifications'] ?? 0;
        
        return Stack(
          children: [
            const Icon(Icons.notifications_none),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5BA73),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Notifications Screen
class NotificationsScreen extends StatelessWidget {
  final String userId;
  
  const NotificationsScreen({Key? key, required this.userId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B3A55),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              // Mark all as read functionality
            },
            child: const Text(
              'Mark all as read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationService.getNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No notifications yet'),
            );
          }
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              
              final bool isRead = data['read'] ?? false;
              final String title = data['title'] ?? '';
              final String message = data['message'] ?? '';
              final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
              final String type = data['type'] ?? '';
              
              return ListTile(
                leading: _getNotificationIcon(type),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                tileColor: isRead ? null : Colors.blue.withOpacity(0.05),
                onTap: () {
                  notificationService.markAsRead(userId, notification.id);
                  
                  // Navigate to relevant content based on notification type
                  final String? postId = data['postId'];
                  if (postId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(postId: postId),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'post_like':
        return const CircleAvatar(
          backgroundColor: Colors.pink,
          radius: 18,
          child: Icon(Icons.favorite, color: Colors.white, size: 18),
        );
      case 'new_comment':
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          radius: 18,
          child: Icon(Icons.comment, color: Colors.white, size: 18),
        );
      default:
        return const CircleAvatar(
          backgroundColor: Colors.grey,
          radius: 18,
          child: Icon(Icons.notifications, color: Colors.white, size: 18),
        );
    }
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(date);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}

// This component should be imported from your forum_screen.dart
class PostDetailScreen extends StatefulWidget {
  final String postId;
  
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // Implementation from your forum_screen.dart
  @override
  Widget build(BuildContext context) {
    // This is just a placeholder - the actual implementation 
    // should come from your forum_screen.dart
    return Scaffold(
      appBar: AppBar(title: Text('Post Detail')),
      body: Center(child: Text('Post ID: ${widget.postId}')),
    );
  }
}