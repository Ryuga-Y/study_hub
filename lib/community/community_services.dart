import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'models.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Post Operations
  Future<String> createPost({
    required List<File> mediaFiles,
    required List<MediaType> mediaTypes,
    required String caption,
    required PostPrivacy privacy,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;

      // Upload media files
      List<String> mediaUrls = [];
      for (int i = 0; i < mediaFiles.length; i++) {
        final file = mediaFiles[i];
        final type = mediaTypes[i];
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i';
        final ref = _storage.ref().child('posts/$userId/$fileName');

        final uploadTask = await ref.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();
        mediaUrls.add(url);
      }

      // Create post document
      final postRef = _firestore.collection('posts').doc();
      final post = Post(
        id: postRef.id,
        userId: userId,
        userName: userData['fullName'] ?? 'Unknown',
        userAvatar: userData['avatarUrl'],
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        caption: caption,
        createdAt: DateTime.now(),
        privacy: privacy,
      );

      await postRef.set(post.toMap());

      // Update user's post count
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(1),
      });

      // Create notifications for friends if public/friends-only
      if (privacy != PostPrivacy.private) {
        await _notifyFriendsOfNewPost(userId, postRef.id, userData['fullName']);
      }

      return postRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<void> updatePost({
    required String postId,
    required String caption,
    required PostPrivacy privacy,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.data()?['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      await _firestore.collection('posts').doc(postId).update({
        'caption': caption,
        'privacy': privacy.toString().split('.').last,
        'isEdited': true,
        'editedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postData = postDoc.data();
      if (postData?['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      // Delete media from storage
      final mediaUrls = List<String>.from(postData?['mediaUrls'] ?? []);
      for (final url in mediaUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }

      // Delete comments
      final commentsQuery = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete post
      batch.delete(_firestore.collection('posts').doc(postId));
      await batch.commit();

      // Update user's post count
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Stream<List<Post>> getFeedPosts({
    required String organizationCode,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().asyncMap((snapshot) async {
      // Get user's friends list once
      final friendIds = await _getFriendIds(userId);

      // Get all posts and filter based on visibility
      final List<Post> posts = [];

      for (final doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);

        // Get post creator's organization
        final userDoc = await _firestore.collection('users').doc(post.userId).get();
        final userOrgCode = userDoc.data()?['organizationCode'];

        // Skip if not same organization
        if (userOrgCode != organizationCode) continue;

        // Determine if post should be visible
        bool shouldShow = false;

        switch (post.privacy) {
          case PostPrivacy.public:
          // Public posts are visible to everyone in the same organization
            shouldShow = true;
            break;

          case PostPrivacy.friendsOnly:
          // Friends-only posts are visible to the poster and their friends
            shouldShow = post.userId == userId || friendIds.contains(post.userId);
            break;

          case PostPrivacy.private:
          // Private posts are only visible to the poster
            shouldShow = post.userId == userId;
            break;
        }

        if (shouldShow) {
          posts.add(post);
        }
      }

      return posts;
    });
  }

  Stream<List<Post>> getUserPosts(String userId, {int limit = 20}) {
    final currentUser = currentUserId;

    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      // Check if current user can see these posts
      final isFriend = currentUser != null ? await _areFriends(currentUser, userId) : false;

      final posts = <Post>[];
      for (final doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);

        bool shouldShow = false;
        switch (post.privacy) {
          case PostPrivacy.public:
            shouldShow = true;
            break;
          case PostPrivacy.friendsOnly:
            shouldShow = post.userId == currentUser || isFriend;
            break;
          case PostPrivacy.private:
            shouldShow = post.userId == currentUser;
            break;
        }

        if (shouldShow) {
          posts.add(post);
        }
      }

      return posts;
    });
  }

  // Like/Reaction Operations
  Future<void> toggleLike(String postId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();
      final postData = postDoc.data()!;

      List<String> likedBy = List<String>.from(postData['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        await postRef.update({
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        likedBy.add(userId);
        await postRef.update({
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(1),
        });

        // Send notification
        if (postData['userId'] != userId) {
          final userData = await _firestore.collection('users').doc(userId).get();
          await _createNotification(
            userId: postData['userId'],
            type: NotificationType.like,
            title: 'New Like',
            message: '${userData.data()?['fullName']} liked your post',
            actionUserId: userId,
            postId: postId,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  Future<void> addReaction(String postId, String reaction) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final reactions = Map<String, int>.from(postDoc.data()?['reactions'] ?? {});

        reactions[reaction] = (reactions[reaction] ?? 0) + 1;

        transaction.update(postRef, {'reactions': reactions});
      });
    } catch (e) {
      throw Exception('Failed to add reaction: $e');
    }
  }

  // Comment Operations
  Future<String> addComment({
    required String postId,
    required String content,
    String? parentId,
    List<String> mentions = const [],
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final userData = await _firestore.collection('users').doc(userId).get();
      final userDataMap = userData.data()!;

      final commentRef = _firestore.collection('comments').doc();
      final comment = Comment(
        id: commentRef.id,
        postId: postId,
        userId: userId,
        userName: userDataMap['fullName'] ?? 'Unknown',
        userAvatar: userDataMap['avatarUrl'],
        content: content,
        createdAt: DateTime.now(),
        parentId: parentId,
        mentions: mentions,
      );

      await commentRef.set(comment.toMap());

      // Update post comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Send notifications
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postData = postDoc.data()!;

      if (postData['userId'] != userId) {
        await _createNotification(
          userId: postData['userId'],
          type: NotificationType.comment,
          title: 'New Comment',
          message: '${userDataMap['fullName']} commented on your post',
          actionUserId: userId,
          postId: postId,
          commentId: commentRef.id,
        );
      }

      // Notify mentioned users
      for (final mentionedUserId in mentions) {
        if (mentionedUserId != userId) {
          await _createNotification(
            userId: mentionedUserId,
            type: NotificationType.mention,
            title: 'You were mentioned',
            message: '${userDataMap['fullName']} mentioned you in a comment',
            actionUserId: userId,
            postId: postId,
            commentId: commentRef.id,
          );
        }
      }

      return commentRef.id;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }

  // Friend Operations
  Future<void> sendFriendRequest(String friendId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print('DEBUG: Sending friend request from $userId to $friendId');

      // Check if already friends or request exists
      final existingRequest = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('friendId', isEqualTo: friendId)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request already exists');
      }

      // Get user data
      final userData = await _firestore.collection('users').doc(userId).get();
      final friendData = await _firestore.collection('users').doc(friendId).get();

      if (!userData.exists || !friendData.exists) {
        throw Exception('User data not found');
      }

      final userDataMap = userData.data()!;
      final friendDataMap = friendData.data()!;

      // Create batch for atomic operation
      final batch = _firestore.batch();

      // Create request FROM user TO friend (sender's perspective)
      final sentRequestRef = _firestore.collection('friends').doc();
      batch.set(sentRequestRef, {
        'userId': userId,
        'friendId': friendId,
        'friendName': friendDataMap['fullName'] ?? 'Unknown',
        'friendAvatar': friendDataMap['avatarUrl'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isReceived': false, // This is the sent request
      });

      // Create request FROM friend TO user (recipient's perspective)
      final receivedRequestRef = _firestore.collection('friends').doc();
      batch.set(receivedRequestRef, {
        'userId': friendId,
        'friendId': userId,
        'friendName': userDataMap['fullName'] ?? 'Unknown',
        'friendAvatar': userDataMap['avatarUrl'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isReceived': true, // This is the received request that can be accepted
      });

      // Commit the batch
      await batch.commit();

      print('DEBUG: Friend request documents created successfully');
      print('DEBUG: Sent request ID: ${sentRequestRef.id}');
      print('DEBUG: Received request ID: ${receivedRequestRef.id}');

      // Send notification
      await _createNotification(
        userId: friendId,
        type: NotificationType.friendRequest,
        title: 'New Friend Request',
        message: '${userDataMap['fullName']} sent you a friend request',
        actionUserId: userId,
      );

    } catch (e) {
      print('Error sending friend request: $e');
      throw Exception('Failed to send friend request: $e');
    }
  }

  Future<void> debugFriendRequestData(String requestId) async {
    try {
      final userId = currentUserId;
      print('=== FRIEND REQUEST DEBUG ===');
      print('Current User ID: $userId');
      print('Request ID: $requestId');

      // Get the friend request document
      final requestDoc = await _firestore.collection('friends').doc(requestId).get();
      print('Request document exists: ${requestDoc.exists}');

      if (requestDoc.exists) {
        final data = requestDoc.data()!;
        print('Request document data: $data');
        print('- userId (sender): ${data['userId']}');
        print('- friendId (recipient): ${data['friendId']}');
        print('- isReceived: ${data['isReceived']}');
        print('- status: ${data['status']}');
        print('- friendName: ${data['friendName']}');

        // Check validation conditions
        print('--- VALIDATION CHECK ---');
        print('Is current user the recipient? ${data['friendId'] == userId}');
        print('Is marked as received? ${data['isReceived'] == true}');
        print('Both conditions met? ${data['friendId'] == userId && data['isReceived'] == true}');
      }

      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.runTransaction((transaction) async {
        // Get the friend request document
        final requestDoc = await transaction.get(_firestore.collection('friends').doc(requestId));
        if (!requestDoc.exists) {
          throw Exception('Friend request not found');
        }

        final requestData = requestDoc.data()!;

        // Validate request - Fixed the validation logic
        if (requestData['friendId'] != userId || requestData['isReceived'] != true) {
          throw Exception('You can only accept requests sent to you');
        }

        final senderId = requestData['userId']; // The actual sender
        final recipientId = userId; // Current user accepting

        // Update friend request status
        transaction.update(requestDoc.reference, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Find and update reverse request
        final reverseQuery = await _firestore
            .collection('friends')
            .where('userId', isEqualTo: senderId)
            .where('friendId', isEqualTo: recipientId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (final doc in reverseQuery.docs) {
          if (doc.id != requestId) {
            transaction.update(doc.reference, {
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Update friend counts
        transaction.update(_firestore.collection('users').doc(recipientId), {
          'friendCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(_firestore.collection('users').doc(senderId), {
          'friendCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Send notification outside transaction
      final userData = await _firestore.collection('users').doc(userId).get();
      if (userData.exists) {
        final requestDoc = await _firestore.collection('friends').doc(requestId).get();
        final senderId = requestDoc.data()!['userId']; // Fixed: get the actual sender

        await _createNotification(
          userId: senderId,
          type: NotificationType.friendAccepted,
          title: 'Friend Request Accepted',
          message: '${userData.data()?['fullName']} accepted your friend request',
          actionUserId: userId,
        );
      }

    } catch (e) {
      print('Error accepting friend request: $e');
      throw Exception('Failed to accept friend request: $e');
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Delete both friend records
      final batch = _firestore.batch();

      // Delete received request
      batch.delete(_firestore.collection('friends').doc(requestId));

      // Find and delete sent request
      final requestDoc = await _firestore.collection('friends').doc(requestId).get();
      final requestData = requestDoc.data()!;

      final sentRequestQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: requestData['friendId'])
          .where('friendId', isEqualTo: requestData['userId'])
          .get();

      if (sentRequestQuery.docs.isNotEmpty) {
        batch.delete(sentRequestQuery.docs.first.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to decline friend request: $e');
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Delete both friend records
      final batch = _firestore.batch();

      // Delete user's friend record
      final userFriendQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('friendId', isEqualTo: friendId)
          .get();

      if (userFriendQuery.docs.isNotEmpty) {
        batch.delete(userFriendQuery.docs.first.reference);
      }

      // Delete friend's record
      final friendRecordQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: userId)
          .get();

      if (friendRecordQuery.docs.isNotEmpty) {
        batch.delete(friendRecordQuery.docs.first.reference);
      }

      await batch.commit();

      // Update friend counts
      await _firestore.collection('users').doc(userId).update({
        'friendCount': FieldValue.increment(-1),
      });
      await _firestore.collection('users').doc(friendId).update({
        'friendCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to remove friend: $e');
    }
  }

  Stream<List<Friend>> getFriends({FriendStatus? status}) {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.toString().split('.').last);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Friend.fromFirestore(doc)).toList());
  }

  Stream<List<Friend>> getPendingFriendRequests() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId) // Requests where current user is the recipient
        .where('status', isEqualTo: 'pending')
        .where('isReceived', isEqualTo: true) // Only received requests
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('DEBUG: Found ${snapshot.docs.length} pending requests for user $userId');
      return snapshot.docs.map((doc) {
        print('DEBUG: Pending request: ${doc.id} - ${doc.data()}');
        return Friend.fromFirestore(doc);
      }).toList();
    });
  }

  // User Operations
  Stream<CommunityUser?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? CommunityUser.fromFirestore(doc) : null);
  }

  Future<List<CommunityUser>> searchUsers(String query, String organizationCode) async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      // Search by name (case-insensitive approximation)
      final snapshot = await _firestore
          .collection('users')
          .where('organizationCode', isEqualTo: organizationCode)
          .where('isActive', isEqualTo: true)
          .get();

      final users = snapshot.docs
          .map((doc) => CommunityUser.fromFirestore(doc))
          .where((user) =>
      user.uid != userId &&
          (user.fullName.toLowerCase().contains(query.toLowerCase()) ||
              user.email.toLowerCase().contains(query.toLowerCase())))
          .toList();

      return users;
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUserProfile({
    String? bio,
    File? avatarFile,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      Map<String, dynamic> updates = {};

      if (bio != null) {
        updates['bio'] = bio;
      }

      if (avatarFile != null) {
        // Upload avatar
        final ref = _storage.ref().child('avatars/$userId');
        final uploadTask = await ref.putFile(avatarFile);
        final avatarUrl = await uploadTask.ref.getDownloadURL();
        updates['avatarUrl'] = avatarUrl;
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = Timestamp.now();
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Notification Operations
  Stream<List<CommunityNotification>> getNotifications() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CommunityNotification.fromFirestore(doc))
        .toList());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  // Helper Methods
  Future<List<String>> _getFriendIds(String userId) async {
    final friendsQuery = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .get();

    return friendsQuery.docs.map((doc) => doc.data()['friendId'] as String).toList();
  }

  Future<bool> _areFriends(String userId1, String userId2) async {
    // Check both directions of the friendship
    final query1 = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId1)
        .where('friendId', isEqualTo: userId2)
        .where('status', isEqualTo: 'accepted')
        .get();

    if (query1.docs.isNotEmpty) return true;

    // Also check the reverse direction
    final query2 = await _firestore
        .collection('friends')
        .where('userId', isEqualTo: userId2)
        .where('friendId', isEqualTo: userId1)
        .where('status', isEqualTo: 'accepted')
        .get();

    return query2.docs.isNotEmpty;
  }

  Future<void> _createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? actionUserId,
    String? postId,
    String? commentId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final actionUserData = actionUserId != null
          ? await _firestore.collection('users').doc(actionUserId).get()
          : null;

      final notificationRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      final notification = CommunityNotification(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: title,
        message: message,
        actionUserId: actionUserId,
        actionUserName: actionUserData?.data()?['fullName'],
        actionUserAvatar: actionUserData?.data()?['avatarUrl'],
        postId: postId,
        commentId: commentId,
        createdAt: DateTime.now(),
        data: data ?? {},
      );

      await notificationRef.set(notification.toMap());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> _notifyFriendsOfNewPost(String userId, String postId, String userName) async {
    try {
      final friendIds = await _getFriendIds(userId);

      for (final friendId in friendIds) {
        await _createNotification(
          userId: friendId,
          type: NotificationType.newPost,
          title: 'New Post',
          message: '$userName shared a new post',
          actionUserId: userId,
          postId: postId,
        );
      }
    } catch (e) {
      print('Error notifying friends: $e');
    }
  }

  // Get suggested friends based on mutual connections
  Future<List<CommunityUser>> getSuggestedFriends(String organizationCode) async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      // Get current user's friends
      final friendIds = await _getFriendIds(userId);

      // Get all users in organization
      final usersSnapshot = await _firestore
          .collection('users')
          .where('organizationCode', isEqualTo: organizationCode)
          .where('isActive', isEqualTo: true)
          .get();

      final suggestedUsers = <CommunityUser>[];

      for (final doc in usersSnapshot.docs) {
        if (doc.id == userId || friendIds.contains(doc.id)) continue;

        // Check if there's a pending request
        final pendingRequest = await _firestore
            .collection('friends')
            .where('userId', isEqualTo: userId)
            .where('friendId', isEqualTo: doc.id)
            .get();

        if (pendingRequest.docs.isEmpty) {
          // Check for mutual friends
          final userFriends = await _getFriendIds(doc.id);
          final mutualFriends = friendIds.where((id) => userFriends.contains(id)).toList();

          if (mutualFriends.isNotEmpty) {
            suggestedUsers.add(CommunityUser.fromFirestore(doc));
          }
        }
      }

      // Sort by number of mutual friends
      return suggestedUsers.take(10).toList();
    } catch (e) {
      return [];
    }
  }
}