import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'AI_Content.dart';
import 'models.dart';
import '../chat_integrated.dart';
import '../chat.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Add this method to refresh authentication
  // Add this method to refresh authentication
  Future<void> refreshUserAuth() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.getIdToken(true); // Force token refresh
        print('✅ Auth token refreshed successfully');

        // Also verify Firestore access
        await _firestore.collection('users').doc(user.uid).get();
        print('✅ Firestore access verified');
      }
    } catch (e) {
      print('❌ Failed to refresh auth token: $e');
      // If auth fails, try to re-authenticate
      if (e.toString().contains('permission-denied')) {
        await _handleAuthFailure();
      }
    }
  }

// 🆕 ADD this new method after refreshUserAuth()
  Future<void> _handleAuthFailure() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        await user.getIdToken(true);
        print('✅ Auth recovered after failure');
      }
    } catch (e) {
      print('❌ Auth recovery failed: $e');
    }
  }

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

      // 🆕 ADD: Content moderation check
      if (caption.isNotEmpty) {
        final moderationResult = await PerspectiveModerationService.shouldModerateContent(caption);

        switch (moderationResult.type) {
          case ModerationActionType.block:
            throw Exception(moderationResult.reason);
          case ModerationActionType.flag:
          // You might want to flag for review but still allow posting
            print('Content flagged: ${moderationResult.reason}');
            break;
          case ModerationActionType.warn:
          // You could return a warning that the UI can display
            print('Warning: ${moderationResult.reason}');
            break;
          case ModerationActionType.allow:
          // Continue with post creation
            break;
        }
      }

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

        // Add metadata to ensure proper permissions
        final metadata = SettableMetadata(
          contentType: type == MediaType.image ? 'image/jpeg' : 'video/mp4',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = await ref.putFile(file, metadata);
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

  // Poll Operations
  Future<String> createPoll({
    required String postId,
    required String question,
    required List<String> options,
    bool allowMultipleVotes = false,
    DateTime? endsAt,
    bool isAnonymous = false,
  }) async {
    try {
      // 🆕 ADD: Moderate poll question
      final questionModeration = await PerspectiveModerationService.shouldModerateContent(question);
      if (questionModeration.type == ModerationActionType.block) {
        throw Exception('Poll question ${questionModeration.reason}');
      }

      // 🆕 ADD: Moderate each option
      for (final option in options) {
        final optionModeration = await PerspectiveModerationService.shouldModerateContent(option);
        if (optionModeration.type == ModerationActionType.block) {
          throw Exception('Poll option "${option}" ${optionModeration.reason}');
        }
      }
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Validate inputs
      if (question.trim().isEmpty) {
        throw Exception('Poll question cannot be empty');
      }
      if (options.length < 2) {
        throw Exception('Poll must have at least 2 options');
      }
      if (options.length > 6) {
        throw Exception('Poll cannot have more than 6 options');
      }

      // Create poll document
      final pollRef = _firestore.collection('polls').doc();

      // Create poll options
      final pollOptions = options.map((text) => PollOption(
        id: DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
        text: text,
        voteCount: 0,
      )).toList();

      final poll = Poll(
        id: pollRef.id,
        postId: postId,
        question: question,
        options: pollOptions,
        allowMultipleVotes: allowMultipleVotes,
        endsAt: endsAt,
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
      );

      await pollRef.set(poll.toMap());

      // Update post to reference the poll
      await _firestore.collection('posts').doc(postId).update({
        'pollId': pollRef.id,
        'hasPoll': true,
      });

      return pollRef.id;
    } catch (e) {
      throw Exception('Failed to create poll: $e');
    }
  }

  Stream<Poll?> getPoll(String pollId) {
    return _firestore
        .collection('polls')
        .doc(pollId)
        .snapshots()
        .map((doc) => doc.exists ? Poll.fromFirestore(doc) : null);
  }

  Future<void> voteOnPoll(String pollId, String optionId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.runTransaction((transaction) async {
        final pollDoc = await transaction.get(
            _firestore.collection('polls').doc(pollId)
        );

        if (!pollDoc.exists) throw Exception('Poll not found');

        final poll = Poll.fromFirestore(pollDoc);

        // Check if poll is active
        if (!poll.isActive) throw Exception('Poll has ended');

        // Check if user already voted
        if (poll.hasVoted(userId) && !poll.allowMultipleVotes) {
          throw Exception('You have already voted');
        }

        // Get current votes
        final votes = Map<String, String>.from(poll.votes);
        final oldVote = votes[userId];

        // Update votes
        votes[userId] = optionId;

        // Update option counts
        final updatedOptions = poll.options.map((option) {
          int newCount = option.voteCount;

          if (oldVote == option.id) {
            newCount--; // Remove old vote
          }
          if (option.id == optionId) {
            newCount++; // Add new vote
          }

          return option.copyWith(voteCount: newCount);
        }).toList();

        // Update poll document
        transaction.update(pollDoc.reference, {
          'votes': votes,
          'options': updatedOptions.map((opt) => opt.toMap()).toList(),
        });
      });
    } catch (e) {
      throw Exception('Failed to vote: $e');
    }
  }

  // Enhanced post update with media support
  Future<void> updatePostWithMedia({
    required String postId,
    required String caption,
    required PostPrivacy privacy,
    List<File>? newMediaFiles,
    List<MediaType>? newMediaTypes,
    List<String>? keepExistingMediaUrls,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get current post data
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      if (postData['userId'] != userId) throw Exception('Unauthorized');

      final currentMediaUrls = List<String>.from(postData['mediaUrls'] ?? []);
      final currentMediaTypes = (postData['mediaTypes'] as List?)
          ?.map((type) => MediaType.values.firstWhere(
            (e) => e.toString() == 'MediaType.$type',
        orElse: () => MediaType.image,
      ))
          .toList() ?? [];

      // Determine which media to delete
      final mediaToDelete = currentMediaUrls.where((url) =>
      keepExistingMediaUrls == null || !keepExistingMediaUrls.contains(url)
      ).toList();

      // Delete removed media from storage
      for (final url in mediaToDelete) {
        try {
          await _storage.refFromURL(url).delete();
          print('✅ Deleted media: ${url.substring(0, 50)}...');
        } catch (e) {
          print('⚠️ Failed to delete media: $e');
        }
      }

      // Prepare final media lists
      List<String> finalMediaUrls = [];
      List<MediaType> finalMediaTypes = [];

      // Add kept existing media
      if (keepExistingMediaUrls != null) {
        for (int i = 0; i < currentMediaUrls.length; i++) {
          if (keepExistingMediaUrls.contains(currentMediaUrls[i])) {
            finalMediaUrls.add(currentMediaUrls[i]);
            if (i < currentMediaTypes.length) {
              finalMediaTypes.add(currentMediaTypes[i]);
            }
          }
        }
      }

      // Upload new media files
      if (newMediaFiles != null && newMediaTypes != null) {
        for (int i = 0; i < newMediaFiles.length; i++) {
          final file = newMediaFiles[i];
          final type = newMediaTypes[i];
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_new_$i';
          final ref = _storage.ref().child('posts/$userId/$fileName');

          final metadata = SettableMetadata(
            contentType: type == MediaType.image ? 'image/jpeg' : 'video/mp4',
            customMetadata: {
              'uploadedBy': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
              'isEdit': 'true',
            },
          );

          final uploadTask = await ref.putFile(file, metadata);
          final url = await uploadTask.ref.getDownloadURL();
          finalMediaUrls.add(url);
          finalMediaTypes.add(type);
          print('✅ Uploaded new media: ${url.substring(0, 50)}...');
        }
      }

      // Update post document
      await _firestore.collection('posts').doc(postId).update({
        'caption': caption,
        'privacy': privacy.toString().split('.').last,
        'mediaUrls': finalMediaUrls,
        'mediaTypes': finalMediaTypes.map((type) => type.toString().split('.').last).toList(),
        'isEdited': true,
        'editedAt': Timestamp.now(),
      });

      print('✅ Post updated successfully with ${finalMediaUrls.length} media files');

    } catch (e) {
      print('❌ Error updating post with media: $e');
      throw Exception('Failed to update post: $e');
    }
  }

// Enhanced poll update with options support
  Future<void> updatePollWithOptions({
    required String pollId,
    String? question,
    List<String>? optionTexts,
    DateTime? endsAt,
    bool? isAnonymous,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get poll document
      final pollDoc = await _firestore.collection('polls').doc(pollId).get();
      if (!pollDoc.exists) throw Exception('Poll not found');

      final poll = Poll.fromFirestore(pollDoc);

      // Verify ownership through post
      final postDoc = await _firestore.collection('posts').doc(poll.postId).get();
      if (postDoc.data()?['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      // Prepare update data
      Map<String, dynamic> updates = {};

      if (question != null) {
        updates['question'] = question;
      }

      if (endsAt != null) {
        updates['endsAt'] = Timestamp.fromDate(endsAt);
      }

      if (isAnonymous != null) {
        updates['isAnonymous'] = isAnonymous;
      }

      // Handle option updates
      if (optionTexts != null && optionTexts.isNotEmpty) {
        // Create new poll options
        final newOptions = optionTexts.map((text) => PollOption(
          id: DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
          text: text,
          voteCount: 0,
        )).toList();

        // If we're changing options, we need to reset votes
        // This is a design decision - you might want to handle this differently
        updates['options'] = newOptions.map((opt) => opt.toMap()).toList();
        updates['votes'] = <String, String>{}; // Reset votes when options change

        print('⚠️ Poll options updated - all votes have been reset');
      }

      // Update poll document
      await _firestore.collection('polls').doc(pollId).update(updates);

      print('✅ Poll updated successfully');

    } catch (e) {
      print('❌ Error updating poll: $e');
      throw Exception('Failed to update poll: $e');
    }
  }

// Helper method to validate media files
  bool _isValidMediaFile(File file, MediaType type) {
    try {
      final extension = file.path.toLowerCase().split('.').last;

      if (type == MediaType.image) {
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
      } else if (type == MediaType.video) {
        return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePoll({
    required String pollId,
    String? question,
    List<PollOption>? options,
    DateTime? endsAt,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership through post
      final pollDoc = await _firestore.collection('polls').doc(pollId).get();
      if (!pollDoc.exists) throw Exception('Poll not found');

      final poll = Poll.fromFirestore(pollDoc);
      final postDoc = await _firestore.collection('posts').doc(poll.postId).get();

      if (postDoc.data()?['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      Map<String, dynamic> updates = {};
      if (question != null) updates['question'] = question;
      if (options != null) updates['options'] = options.map((opt) => opt.toMap()).toList();
      if (endsAt != null) updates['endsAt'] = Timestamp.fromDate(endsAt);

      await _firestore.collection('polls').doc(pollId).update(updates);
    } catch (e) {
      throw Exception('Failed to update poll: $e');
    }
  }

  Future<void> deletePoll(String pollId, String postId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify ownership
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.data()?['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      // Delete poll
      await _firestore.collection('polls').doc(pollId).delete();

      // Update post
      await _firestore.collection('posts').doc(postId).update({
        'pollId': FieldValue.delete(),
        'hasPoll': false,
      });
    } catch (e) {
      throw Exception('Failed to delete poll: $e');
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

  // Add this method to CommunityService class
  Future<bool> canUsersChat(String userId1, String userId2) async {
    try {
      // Check if both users are mutual friends
      final query1 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .where('status', isEqualTo: 'accepted')
          .get();

      final query2 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId2)
          .where('friendId', isEqualTo: userId1)
          .where('status', isEqualTo: 'accepted')
          .get();

      bool areFriends = query1.docs.isNotEmpty && query2.docs.isNotEmpty;

      if (areFriends) {
        print('✅ Users are mutual friends - chat allowed');
      } else {
        print('❌ Users are not mutual friends - chat blocked');
      }

      return areFriends;
    } catch (e) {
      print('❌ Error checking chat permissions: $e');
      return false;
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
        .where('isHidden', isEqualTo: false) // 🆕 NEW: Filter out hidden posts
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

        // Skip hidden posts (double check since we already filter in query)
        if (post.isHidden) continue;

        // Get post creator's organization
        final userDoc = await _firestore.collection('users').doc(post.userId).get();
        final userOrgCode = userDoc.data()?['organizationCode'];

        // Skip if not same organization
        if (userOrgCode != organizationCode) continue;

        // Determine if post should be visible
        bool shouldShow = false;

        switch (post.privacy) {
          case PostPrivacy.public:
            shouldShow = true;
            break;
          case PostPrivacy.friendsOnly:
            shouldShow = post.userId == userId || friendIds.contains(post.userId);
            break;
          case PostPrivacy.private:
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

    // For admin users, show all posts including hidden ones
    // For regular users, hide hidden posts unless it's their own profile
    final shouldShowHidden = currentUser == userId; // Users can see their own hidden posts

    Query query = _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Only add hidden filter if not showing hidden posts
    if (!shouldShowHidden) {
      query = query.where('isHidden', isEqualTo: false);
    }

    return query.snapshots().asyncMap((snapshot) async {
      // Check if current user can see these posts
      final isFriend = currentUser != null ? await _areFriends(currentUser, userId) : false;

      final posts = <Post>[];
      for (final doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);

        // Skip hidden posts for non-owners (unless it's an admin viewing)
        if (post.isHidden && currentUser != userId) {
          final currentUserDoc = currentUser != null
              ? await _firestore.collection('users').doc(currentUser).get()
              : null;
          final isAdmin = currentUserDoc?.data()?['role'] == 'admin';

          if (!isAdmin) continue; // Skip hidden posts for non-admins
        }

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

  // Updated Reaction Methods
  Future<void> toggleReaction(String postId, String reaction) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final postData = postDoc.data()!;

        // Get current data
        List<String> likedBy = List<String>.from(postData['likedBy'] ?? []);
        Map<String, dynamic> reactions = Map<String, dynamic>.from(postData['reactions'] ?? {});
        Map<String, dynamic> userReactions = Map<String, dynamic>.from(postData['userReactions'] ?? {});

        // Check if user already reacted
        final currentReaction = userReactions[userId] as String?;

        if (currentReaction == reaction) {
          // User is removing their reaction
          likedBy.remove(userId);
          userReactions.remove(userId);

          // Remove user from reaction list
          if (reactions[reaction] is List) {
            (reactions[reaction] as List).remove(userId);
            if ((reactions[reaction] as List).isEmpty) {
              reactions.remove(reaction);
            }
          }
        } else {
          // User is adding/changing reaction
          if (currentReaction != null) {
            // Remove from old reaction
            if (reactions[currentReaction] is List) {
              (reactions[currentReaction] as List).remove(userId);
              if ((reactions[currentReaction] as List).isEmpty) {
                reactions.remove(currentReaction);
              }
            }
          } else {
            // New reaction - add to likedBy
            likedBy.add(userId);
          }

          // Add to new reaction
          userReactions[userId] = reaction;
          if (!reactions.containsKey(reaction)) {
            reactions[reaction] = [];
          }
          if (reactions[reaction] is List && !(reactions[reaction] as List).contains(userId)) {
            (reactions[reaction] as List).add(userId);
          }
        }

        // Update the post
        transaction.update(postRef, {
          'likedBy': likedBy,
          'likeCount': likedBy.length,
          'reactions': reactions,
          'userReactions': userReactions,
        });
      });

      // Send notification if it's a new reaction
      final postDoc = await postRef.get();
      final postData = postDoc.data()!;

      if (postData['userId'] != userId && postData['userReactions'][userId] != null) {
        final userData = await _firestore.collection('users').doc(userId).get();
        await _createNotification(
          userId: postData['userId'],
          type: NotificationType.like,
          title: 'New Reaction',
          message: '${userData.data()?['fullName']} reacted $reaction to your post',
          actionUserId: userId,
          postId: postId,
        );
      }
    } catch (e) {
      print('Error toggling reaction: $e');
      throw Exception('Failed to toggle reaction: $e');
    }
  }

  // Keep the old toggleLike for backward compatibility but redirect to toggleReaction
  Future<void> toggleLike(String postId) async {
    // Default to thumbs up reaction - assuming 'like' is the default reaction type
    await toggleReaction(postId, 'like');
  }

  // Legacy method for adding reactions (deprecated - use toggleReaction instead)
  @Deprecated('Use toggleReaction instead')
  Future<void> addReaction(String postId, String reaction) async {
    await toggleReaction(postId, reaction);
  }

  Future<void> syncFriendCount(String userId) async {
    try {
      // Get actual friend count
      final friendsQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final actualFriendCount = friendsQuery.docs.length;

      // Update user document with correct count
      await _firestore.collection('users').doc(userId).update({
        'friendCount': actualFriendCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error syncing friend count: $e');
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

      // 🆕 ADD: Content moderation check
      final moderationResult = await PerspectiveModerationService.shouldModerateContent(content);

      switch (moderationResult.type) {
        case ModerationActionType.block:
          throw Exception(moderationResult.reason);
        case ModerationActionType.flag:
        // Log for review but allow
          print('Comment flagged: ${moderationResult.reason}');
          break;
        case ModerationActionType.warn:
        // Could return warning
          print('Warning: ${moderationResult.reason}');
          break;
        case ModerationActionType.allow:
          break;
      }

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

  Future<void> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get comment to verify ownership
      final commentDoc = await _firestore.collection('comments').doc(commentId).get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      if (commentData['userId'] != userId) {
        throw Exception('Unauthorized');
      }

      // Delete the comment
      await _firestore.collection('comments').doc(commentId).delete();

      // Update post comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
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

  // UPDATED Accept Friend Request method with enhanced chat creation
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print('=== ACCEPT FRIEND REQUEST ===');
      print('Current User: $userId, Request ID: $requestId');

      // Get the request document
      final requestDoc = await _firestore.collection('friends').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final requestData = requestDoc.data()!;
      print('Request data: $requestData');

      // Validate request
      if (requestData['userId'] != userId || requestData['isReceived'] != true) {
        throw Exception('You can only accept requests sent to you');
      }

      final recipientId = requestData['userId'];  // Current user (who is accepting)
      final senderId = requestData['friendId'];   // Friend who sent request

      // Step 1: Update the main request document
      print('Step 1: Updating main request');
      await _firestore.collection('friends').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Step 2: Find and update the reverse request
      print('Step 2: Finding reverse request');
      final reverseQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: senderId)
          .where('friendId', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reverseQuery.docs.isNotEmpty) {
        final reverseRequestId = reverseQuery.docs.first.id;
        print('Updating reverse request: $reverseRequestId');
        await _firestore.collection('friends').doc(reverseRequestId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }

      // Step 3: Update friend counts
      print('Step 3: Updating friend counts');

      // Update current user's friend count
      await _firestore.collection('users').doc(recipientId).update({
        'friendCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update sender's friend count
      await _firestore.collection('users').doc(senderId).update({
        'friendCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 4: Get user data for chat creation
      print('Step 4: Creating chat and sending acceptance message');
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();

      if (senderDoc.exists && recipientDoc.exists) {
        final senderName = senderDoc.data()?['fullName'] ?? 'Unknown';
        final recipientName = recipientDoc.data()?['fullName'] ?? 'Unknown';

        // Create chat with acceptance message
        await _createChatWithAcceptanceMessage(
            senderId,
            recipientId,
            senderName,
            recipientName
        );
      }

      // Step 5: Send notification
      print('Step 5: Sending notification');
      final userData = await _firestore.collection('users').doc(userId).get();
      if (userData.exists) {
        await _createNotification(
          userId: senderId,
          type: NotificationType.friendAccepted,
          title: 'Friend Request Accepted',
          message: '${userData.data()?['fullName']} accepted your friend request',
          actionUserId: userId,
        );
      }

      print('Friend request accepted successfully');

    } catch (e, stackTrace) {
      print('Error accepting friend request: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to accept friend request: $e');
    }
  }

  // UPDATED Chat creation method with acceptance message
  Future<void> _createChatWithAcceptanceMessage(
      String senderId,
      String recipientId,
      String senderName,
      String recipientName
      ) async {
    try {
      // Generate chat ID (sorted user IDs)
      final sortedIds = [senderId, recipientId]..sort();
      final chatId = '${sortedIds[0]}_${sortedIds[1]}';

      print('Creating chat for new friends: $chatId');

      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Create the initial welcome message text
        final welcomeMessage = "You became friends, let's start chatting!";

        // Create chat document
        await _firestore.collection('chats').doc(chatId).set({
          'participants': [senderId, recipientId],
          'participantNames': {
            senderId: senderName,
            recipientId: recipientName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': welcomeMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            senderId: 1,  // Mark as unread for both users initially
            recipientId: 1,
          },
        });

        print('Chat document created successfully');

        // Add system welcome message
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add({
          'text': welcomeMessage,
          'senderId': 'system',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'isSystemMessage': true,
        });
      }

      // Send the acceptance message from the acceptor (recipientId) to the requester (senderId)
      final acceptanceMessage = "I've accepted your friend request. Now let's chat!";

// Use atomic transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        final chatRef = _firestore.collection('chats').doc(chatId);
        final messageRef = chatRef.collection('messages').doc();

        // Create message data
        final messageData = {
          'text': acceptanceMessage,
          'senderId': recipientId,  // The person who accepted sends this
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'isSystemMessage': false,
          'messageType': 'friend_accepted',
          'messageId': messageRef.id,
        };

        // Create chat metadata
        final chatData = {
          'participants': [senderId, recipientId],
          'participantNames': {
            senderId: senderName,
            recipientId: recipientName,
          },
          'lastMessage': acceptanceMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            senderId: 1,     // Original requester gets notification
            recipientId: 0,  // Acceptor sees as read (they sent it)
          },
          'createdAt': FieldValue.serverTimestamp(),
          'chatType': 'friend_chat',
        };

        // Execute both operations atomically
        transaction.set(chatRef, chatData);
        transaction.set(messageRef, messageData);
      });

      print('✅ Chat and acceptance message created consistently for both users');

      print('Acceptance message sent successfully');

    } catch (e) {
      print('Error creating chat with acceptance message: $e');
      // Don't throw here as chat creation failure shouldn't break friend acceptance
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get the request document first
      final requestDoc = await _firestore.collection('friends').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final requestData = requestDoc.data()!;

      // Validate that this user can decline this request
      if (requestData['userId'] != userId || requestData['isReceived'] != true) {
        throw Exception('You can only accept requests sent to you');
      }

      final senderId = requestData['userId'];

      // Find the reverse request before starting transaction
      final reverseQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: senderId)
          .where('friendId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      List<String> reverseRequestIds = reverseQuery.docs.map((doc) => doc.id).toList();

      // Now run the transaction
      await _firestore.runTransaction((transaction) async {
        // Delete the received request
        transaction.delete(_firestore.collection('friends').doc(requestId));

        // Delete all reverse requests
        for (final reverseId in reverseRequestIds) {
          transaction.delete(_firestore.collection('friends').doc(reverseId));
        }
      });

    } catch (e) {
      print('Error declining friend request: $e');
      throw Exception('Failed to decline friend request: $e');
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // First, find all friendship documents BEFORE the transaction
      final query1 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId)
          .where('friendId', isEqualTo: friendId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final query2 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Collect all document references to delete
      final List<DocumentReference> docsToDelete = [];
      docsToDelete.addAll(query1.docs.map((doc) => doc.reference));
      docsToDelete.addAll(query2.docs.map((doc) => doc.reference));

      if (docsToDelete.isEmpty) {
        throw Exception('No friendship found to remove');
      }

      // Now run the transaction with the pre-fetched data
      await _firestore.runTransaction((transaction) async {
        // Get user documents within transaction
        final userDocRef = _firestore.collection('users').doc(userId);
        final friendDocRef = _firestore.collection('users').doc(friendId);

        final userDoc = await transaction.get(userDocRef);
        final friendDoc = await transaction.get(friendDocRef);

        // Delete all friendship documents
        for (final docRef in docsToDelete) {
          transaction.delete(docRef);
        }

        // Update friend counts
        if (userDoc.exists) {
          final currentCount = userDoc.data()?['friendCount'] ?? 0;
          transaction.update(userDocRef, {
            'friendCount': currentCount > 0 ? currentCount - 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (friendDoc.exists) {
          final currentCount = friendDoc.data()?['friendCount'] ?? 0;
          transaction.update(friendDocRef, {
            'friendCount': currentCount > 0 ? currentCount - 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Sync friend counts after transaction
      await syncFriendCount(userId);
      await syncFriendCount(friendId);

      print('Friend removed successfully');

    } catch (e) {
      print('Error removing friend: $e');
      throw Exception('Failed to remove friend: $e');
    }
  }

  Stream<List<Friend>> getFriends({FriendStatus? status, String? userId}) {
    // Use provided userId or fall back to current user
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return Stream.value([]);

    // We need to query for BOTH cases:
    // 1. Where user is the userId
    // 2. Where user is the friendId
    final statusFilter = status?.toString().split('.').last ?? 'accepted';

    // Create two queries
    final query1 = _firestore
        .collection('friends')
        .where('userId', isEqualTo: targetUserId)
        .where('status', isEqualTo: statusFilter);

    final query2 = _firestore
        .collection('friends')
        .where('friendId', isEqualTo: targetUserId)
        .where('status', isEqualTo: statusFilter);

    // Combine both streams
    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<Friend>>(
      query1.snapshots(),
      query2.snapshots(),
          (snapshot1, snapshot2) {
        final List<Friend> friends = [];

        print('DEBUG: Query1 (userId=$targetUserId) returned ${snapshot1.docs.length} documents');
        print('DEBUG: Query2 (friendId=$targetUserId) returned ${snapshot2.docs.length} documents');

        // Process documents where user is userId
        for (final doc in snapshot1.docs) {
          final friend = Friend.fromFirestore(doc);
          print('DEBUG: Query1 friend: id=${friend.friendId}, name=${friend.friendName}');
          if (friend.status == FriendStatus.accepted || status != null) {
            friends.add(friend);
          }
        }

        // Process documents where user is friendId
        // In this case, we need to create a Friend object that represents the relationship
        // from the current user's perspective
        for (final doc in snapshot2.docs) {
          final data = doc.data() as Map<String, dynamic>;

          print('DEBUG: Query2 document data: $data');

          // Since the current user is the friendId in this document,
          // we need to swap the perspective
          // For older documents: friendName contains the sender's name (the friend we want to display)
          // For newer documents: userName contains the friend's name, friendName contains current user's name

          // Determine which field contains the friend's name
          String friendDisplayName = 'Unknown';
          String? friendDisplayAvatar;

          // If userName field exists, it's a newer document format
          if (data.containsKey('userName') && data['userName'] != null) {
            friendDisplayName = data['userName'];
            friendDisplayAvatar = data['userAvatar'];
          } else {
            // Older document format - friendName actually contains the other person's name
            friendDisplayName = data['friendName'] ?? 'Unknown';
            friendDisplayAvatar = data['friendAvatar'];
          }

          final friend = Friend(
            id: doc.id,
            userId: targetUserId, // Current user is always userId in the result
            friendId: data['userId'], // The other person (who was userId in the doc)
            friendName: friendDisplayName,
            friendAvatar: friendDisplayAvatar,
            status: FriendStatus.values.firstWhere(
                  (e) => e.toString() == 'FriendStatus.${data['status'] ?? 'pending'}',
              orElse: () => FriendStatus.pending,
            ),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
            mutualFriends: List<String>.from(data['mutualFriends'] ?? []),
            isReceived: !(data['isReceived'] ?? false), // Flip since perspective is swapped
          );

          print('DEBUG: Query2 friend after processing: id=${friend.friendId}, name=${friend.friendName}');

          if (friend.status == FriendStatus.accepted || status != null) {
            friends.add(friend);
          }
        }

        print('DEBUG: Total friends before deduplication: ${friends.length}');
        for (var i = 0; i < friends.length; i++) {
          print('DEBUG: Friend $i: id=${friends[i].friendId}, name=${friends[i].friendName}');
        }

        // Remove duplicates based on friendId (in case of data inconsistency)
        final uniqueFriends = <String, Friend>{};
        for (final friend in friends) {
          // Use a combination of friendId and document id to ensure uniqueness
          final key = friend.friendId;
          // Keep the first occurrence or the one with more complete data
          if (!uniqueFriends.containsKey(key) ||
              (uniqueFriends[key]!.friendName == 'Unknown' && friend.friendName != 'Unknown')) {
            uniqueFriends[key] = friend;
          }
        }

        final result = uniqueFriends.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by date

        print('DEBUG: After deduplication - ${result.length} unique friends');
        for (var i = 0; i < result.length; i++) {
          print('DEBUG: Unique friend $i: id=${result[i].friendId}, name=${result[i].friendName}');
        }

        return result;
      },
    );
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
    String? fullName, // Add full name update support
    File? avatarFile,
    FriendsListPrivacy? friendsListPrivacy,
    bool removeAvatar = false,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      Map<String, dynamic> updates = {};

      if (bio != null) {
        updates['bio'] = bio;
      }

      // NEW: Support for updating full name
      if (fullName != null && fullName.trim().isNotEmpty) {
        updates['fullName'] = fullName.trim();
      }

      if (friendsListPrivacy != null) {
        updates['friendsListPrivacy'] = friendsListPrivacy.toString().split('.').last;
      }

      // Handle avatar removal
      if (removeAvatar) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final existingAvatarUrl = userDoc.data()?['avatarUrl'];

          if (existingAvatarUrl != null && existingAvatarUrl.isNotEmpty) {
            try {
              final ref = _storage.refFromURL(existingAvatarUrl);
              await ref.delete();
              print('✅ Existing avatar deleted from storage');
            } catch (e) {
              print('⚠️ Could not delete existing avatar: $e');
            }
          }
        } catch (e) {
          print('⚠️ Error checking existing avatar: $e');
        }

        updates['avatarUrl'] = FieldValue.delete();
        print('🗑️ Avatar removed from user profile');
      }
      // Handle avatar upload
      else if (avatarFile != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final existingAvatarUrl = userDoc.data()?['avatarUrl'];

          if (existingAvatarUrl != null && existingAvatarUrl.isNotEmpty) {
            try {
              final oldRef = _storage.refFromURL(existingAvatarUrl);
              await oldRef.delete();
              print('✅ Old avatar deleted before uploading new one');
            } catch (e) {
              print('⚠️ Could not delete old avatar: $e');
            }
          }

          final ref = _storage.ref().child('avatars/$userId');
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploadedBy': userId,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          );

          final uploadTask = await ref.putFile(avatarFile, metadata);
          final avatarUrl = await uploadTask.ref.getDownloadURL();
          updates['avatarUrl'] = avatarUrl;
          print('✅ New avatar uploaded successfully');
        } catch (e) {
          print('❌ Error uploading avatar: $e');
          throw Exception('Failed to upload avatar: $e');
        }
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = Timestamp.now();
        await _firestore.collection('users').doc(userId).update(updates);
        print('✅ User profile updated successfully');

        // NEW: Update profile in all posts and comments for consistency
        await _updateUserProfileInContent(userId, updates);
      }
    } catch (e) {
      print('❌ Error updating user profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }
  Future<void> _updateUserProfileInContent(String userId, Map<String, dynamic> updates) async {
    try {
      final batch = _firestore.batch();

      // Update posts
      if (updates.containsKey('fullName') || updates.containsKey('avatarUrl')) {
        final postsQuery = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in postsQuery.docs) {
          Map<String, dynamic> postUpdates = {};
          if (updates.containsKey('fullName')) {
            postUpdates['userName'] = updates['fullName'];
          }
          if (updates.containsKey('avatarUrl')) {
            if (updates['avatarUrl'] is FieldValue) {
              postUpdates['userAvatar'] = null;
            } else {
              postUpdates['userAvatar'] = updates['avatarUrl'];
            }
          }
          if (postUpdates.isNotEmpty) {
            batch.update(doc.reference, postUpdates);
          }
        }

        // Update comments
        final commentsQuery = await _firestore
            .collection('comments')
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in commentsQuery.docs) {
          Map<String, dynamic> commentUpdates = {};
          if (updates.containsKey('fullName')) {
            commentUpdates['userName'] = updates['fullName'];
          }
          if (updates.containsKey('avatarUrl')) {
            if (updates['avatarUrl'] is FieldValue) {
              commentUpdates['userAvatar'] = null;
            } else {
              commentUpdates['userAvatar'] = updates['avatarUrl'];
            }
          }
          if (commentUpdates.isNotEmpty) {
            batch.update(doc.reference, commentUpdates);
          }
        }
      }

      await batch.commit();
      print('✅ User profile updated in all content');
    } catch (e) {
      print('⚠️ Error updating user profile in content: $e');
    }
  }

  Future<bool> canViewFriendsList(String targetUserId) async {
    try {
      final viewerId = currentUserId;
      if (viewerId == null) return false;

      // User can always see their own friends list
      if (viewerId == targetUserId) return true;

      // Get the target user's privacy setting
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) return false;

      final targetUserData = targetUserDoc.data()!;
      final privacyString = targetUserData['friendsListPrivacy'] ?? 'public';
      final privacy = FriendsListPrivacy.values.firstWhere(
            (e) => e.toString() == 'FriendsListPrivacy.$privacyString',
        orElse: () => FriendsListPrivacy.public,
      );

      switch (privacy) {
        case FriendsListPrivacy.public:
          return true;
        case FriendsListPrivacy.friendsOnly:
          return await _areFriends(viewerId, targetUserId);
        case FriendsListPrivacy.private:
          return false;
      }
    } catch (e) {
      print('Error checking friends list permission: $e');
      return false;
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

  Future<void> sharePost({
    required String postId,
    String? comment,
    required PostPrivacy privacy,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get the original post
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final originalPost = Post.fromFirestore(postDoc);

      // Check if user can share this post based on privacy
      if (!await _canSharePost(originalPost)) {
        throw Exception('You cannot share this post due to privacy settings');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;

      // Create repost document
      final repostRef = _firestore.collection('posts').doc();
      final repost = {
        'id': repostRef.id,
        'userId': userId,
        'userName': userData['fullName'] ?? 'Unknown',
        'userAvatar': userData['avatarUrl'],
        'isRepost': true,
        'originalPostId': originalPost.id,
        'originalPost': originalPost.toMap(),
        'repostComment': comment,
        'caption': '', // Reposts don't have their own caption
        'mediaUrls': [], // Reposts don't have their own media
        'mediaTypes': [],
        'createdAt': FieldValue.serverTimestamp(),
        'privacy': privacy.toString().split('.').last,
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'likedBy': [],
        'reactions': {},
        'userReactions': {},
      };

      // Use transaction to update both documents
      await _firestore.runTransaction((transaction) async {
        // Create the repost
        transaction.set(repostRef, repost);

        // Update share count on original post
        transaction.update(
          _firestore.collection('posts').doc(postId),
          {'shareCount': FieldValue.increment(1)},
        );
      });

      // Update user's post count
      await _firestore.collection('users').doc(userId).update({
        'postCount': FieldValue.increment(1),
      });

      // Send notification to original poster
      if (originalPost.userId != userId) {
        await _createNotification(
          userId: originalPost.userId,
          type: NotificationType.newPost,
          title: 'Your post was shared',
          message: '${userData['fullName']} shared your post',
          actionUserId: userId,
          postId: repostRef.id,
        );
      }
    } catch (e) {
      throw Exception('Failed to share post: $e');
    }
  }

  Future<bool> _canSharePost(Post post) async {
    final userId = currentUserId;
    if (userId == null) return false;

    switch (post.privacy) {
      case PostPrivacy.public:
        return true;
      case PostPrivacy.friendsOnly:
      // Check if user is friends with the poster
        return post.userId == userId || await _areFriends(userId, post.userId);
      case PostPrivacy.private:
      // Private posts cannot be shared
        return false;
    }
  }

  Future<void> externalSharePost(Post post) async {
    try {
      print('🔄 External share started for post: ${post.id}');

      // Build the text content
      final text = post.isRepost && post.originalPost != null
          ? 'Check out this post by ${post.originalPost!.userName}: "${post.originalPost!.caption}"'
          : 'Check out this post by ${post.userName}: "${post.caption}"';

      final textToShare = '$text\n\n📚 Shared from Study Hub';
      print('📤 Sharing text: $textToShare');

      // Use the correct SharePlus API with ShareParams
      await SharePlus.instance.share(ShareParams(
        text: textToShare,
        subject: 'Check out this post from Study Hub',
      ));

      print('✅ External share completed successfully');

    } catch (e) {
      print('❌ External share error: $e');
      throw Exception('Failed to share: $e');
    }
  }

  // IMPROVED Cleanup method - Fixed batch handling
  Future<void> cleanupBrokenImagePosts() async {
    try {
      print('🧹 Starting cleanup of posts with broken images...');

      // Get posts in smaller batches to avoid memory issues
      // Get posts in smaller batches to avoid memory issues
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('mediaUrls', isNotEqualTo: [])
          .limit(20) // Reduced batch size to avoid rate limits
          .get();

      int cleanedCount = 0;
      final docsToDelete = <DocumentReference>[];

      for (final doc in postsSnapshot.docs) {
        try {
          final postData = doc.data();
          final mediaUrls = List<String>.from(postData['mediaUrls'] ?? []);

          if (mediaUrls.isEmpty) continue;

          // Check first URL more thoroughly
          // Check first URL more thoroughly with better validation
          bool hasValidMedia = true;
          final firstUrl = mediaUrls.first;

// Validate URL format first
          if (!_isValidFirebaseStorageUrl(firstUrl)) {
            hasValidMedia = false;
            print('📁 Invalid storage URL format: ${firstUrl.substring(0, 50)}...');
          } else {
            try {
              final ref = _storage.refFromURL(firstUrl);
              await ref.getMetadata();
              print('✅ Valid image found: ${firstUrl.substring(0, 50)}...');
            } catch (e) {
              final errorString = e.toString().toLowerCase();
              if (errorString.contains('404') ||
                  errorString.contains('not found') ||
                  errorString.contains('object does not exist') ||
                  errorString.contains('no object exists') ||
                  errorString.contains('invalid http method') ||
                  errorString.contains('storagexception')) {
                hasValidMedia = false;
                print('📁 Confirmed broken/missing image: ${firstUrl.substring(0, 50)}...');
              } else {
                // For other errors, assume file exists to be safe
                hasValidMedia = true;
                print('⚠️ Unclear error, keeping post: ${e.toString().substring(0, 100)}...');
              }
            }
          }

          if (!hasValidMedia) {
            docsToDelete.add(doc.reference);
            cleanedCount++;
            print('🗑️ Marked for deletion: ${doc.id}');
          }

        } catch (e) {
          print('⚠️ Error processing post ${doc.id}: ${e.toString().substring(0, 100)}...');
        }

        // Add small delay to avoid overwhelming Firebase Storage API
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Delete in batches of 20 to stay within Firestore limits
      for (int i = 0; i < docsToDelete.length; i += 20) {
        final batchDocs = docsToDelete.skip(i).take(20);
        final deleteBatch = _firestore.batch();

        for (final docRef in batchDocs) {
          deleteBatch.delete(docRef);
        }

        await deleteBatch.commit();
        await Future.delayed(Duration(milliseconds: 500)); // Rate limiting
        print('🗑️ Deleted batch of ${batchDocs.length} posts');
      }

      print('✅ Cleaned up $cleanedCount posts with broken media');

    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  // Report Operations
  Future<void> reportPost({
    required String postId,
    required String reason,
    required String details,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data()!;

      // Get post data
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final post = Post.fromFirestore(postDoc);

      // Create report document
      final reportRef = _firestore.collection('postReports').doc();
      await reportRef.set({
        'postId': postId,
        'post': post.toMap(), // Store post snapshot for evidence
        'reportedBy': userId,
        'reporterName': userData['fullName'] ?? 'Unknown',
        'reporterAvatar': userData['avatarUrl'],
        'reason': reason,
        'details': details,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'organizationCode': userData['organizationCode'],
      });

      // Create notification for admins
      await _notifyAdminsOfReport(
        organizationCode: userData['organizationCode'],
        reporterName: userData['fullName'],
        postId: postId,
      );
    } catch (e) {
      throw Exception('Failed to report post: $e');
    }
  }

  Stream<List<PostReport>> getReportedPosts(String organizationCode) {
    return _firestore
        .collection('postReports')
        .where('organizationCode', isEqualTo: organizationCode)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => PostReport.fromFirestore(doc))
        .toList());
  }

  // 🆕 NEW: Get hidden posts for admin review
  Stream<List<Post>> getHiddenPosts(String organizationCode) {
    return _firestore
        .collection('posts')
        .where('isHidden', isEqualTo: true)
        .orderBy('hiddenAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Post> hiddenPosts = [];

      for (final doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);

        // Get post creator's organization
        final userDoc = await _firestore.collection('users').doc(post.userId).get();
        final userOrgCode = userDoc.data()?['organizationCode'];

        // Only include posts from the same organization
        if (userOrgCode == organizationCode) {
          hiddenPosts.add(post);
        }
      }

      return hiddenPosts;
    });
  }

  // 🆕 NEW: Hide post method
  Future<void> hidePost(String postId, String reason) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify admin status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.data()?['role'] != 'admin') {
        throw Exception('Unauthorized: Admin access required');
      }

      // Get post data before hiding
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      final postOwnerId = postData['userId'];

      // Hide the post (don't delete it)
      await _firestore.collection('posts').doc(postId).update({
        'isHidden': true,
        'hiddenReason': reason,
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': userId,
      });

      // Create hiding log
      await _firestore.collection('postHidingLogs').add({
        'postId': postId,
        'postData': postData,
        'hiddenBy': userId,
        'hiddenByName': userDoc.data()?['fullName'] ?? 'Admin',
        'reason': reason,
        'hiddenAt': FieldValue.serverTimestamp(),
        'action': 'hidden', // vs 'deleted' for adminDeletePost
      });

      // Notify post owner
      await _createNotification(
        userId: postOwnerId,
        type: NotificationType.general,
        title: 'Post Hidden',
        message: 'Your post was hidden by an administrator due to an invalid report.',
        actionUserId: userId,
        data: {'reason': reason, 'action': 'hidden'},
      );

      print('✅ Post hidden successfully: $postId');

    } catch (e) {
      print('❌ Error hiding post: $e');
      throw Exception('Failed to hide post: $e');
    }
  }

  // 🆕 NEW: Unhide post method (for admin use)
  Future<void> unhidePost(String postId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify admin status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.data()?['role'] != 'admin') {
        throw Exception('Unauthorized: Admin access required');
      }

      // Unhide the post
      await _firestore.collection('posts').doc(postId).update({
        'isHidden': false,
        'hiddenReason': FieldValue.delete(),
        'hiddenAt': FieldValue.delete(),
        'hiddenBy': FieldValue.delete(),
        'unhiddenAt': FieldValue.serverTimestamp(),
        'unhiddenBy': userId,
      });

      print('✅ Post unhidden successfully: $postId');

    } catch (e) {
      print('❌ Error unhiding post: $e');
      throw Exception('Failed to unhide post: $e');
    }
  }

  Future<void> reviewReport({
    required String reportId,
    required String postId,
    required bool isValid,
    required String adminNotes,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Get admin data
      final adminDoc = await _firestore.collection('users').doc(userId).get();
      final adminData = adminDoc.data()!;

      // Update report status
      await _firestore.collection('postReports').doc(reportId).update({
        'status': isValid ? 'valid' : 'invalid',
        'reviewedBy': userId,
        'reviewerName': adminData['fullName'] ?? 'Admin',
        'reviewedAt': FieldValue.serverTimestamp(),
        'adminNotes': adminNotes,
      });

      // 🔄 UPDATED: Handle both valid and invalid reports
      if (isValid) {
        // Valid report: Delete the post (existing behavior)
        await adminDeletePost(postId, 'Violated community guidelines: $adminNotes');
      } else {
        // 🆕 NEW: Invalid report: Hide the post
        await hidePost(postId, 'Post hidden due to invalid report: $adminNotes');
      }

      print('✅ Report reviewed successfully: $reportId (${isValid ? 'valid' : 'invalid'})');

    } catch (e) {
      print('❌ Error reviewing report: $e');
      throw Exception('Failed to review report: $e');
    }
  }

  Future<void> adminDeletePost(String postId, String reason) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify admin status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.data()?['role'] != 'admin') {
        throw Exception('Unauthorized: Admin access required');
      }

      // Get post data before deletion
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');

      final postData = postDoc.data()!;
      final postOwnerId = postData['userId'];

      // Delete media from storage
      final mediaUrls = List<String>.from(postData['mediaUrls'] ?? []);
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
      await _firestore.collection('users').doc(postOwnerId).update({
        'postCount': FieldValue.increment(-1),
      });

      // Create deletion log
      await _firestore.collection('postDeletionLogs').add({
        'postId': postId,
        'postData': postData,
        'deletedBy': userId,
        'deletedByName': userDoc.data()?['fullName'] ?? 'Admin',
        'reason': reason,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // Notify post owner
      await _createNotification(
        userId: postOwnerId,
        type: NotificationType.general,
        title: 'Post Removed',
        message: 'Your post was removed by an administrator for violating community guidelines.',
        actionUserId: userId,
        data: {'reason': reason},
      );
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<Map<String, int>> getCommunityAnalytics(String organizationCode) async {
    try {
      // Get total posts count
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', whereIn: await _getUsersInOrganization(organizationCode))
          .get();

      // Get all reports
      final reportsQuery = await _firestore
          .collection('postReports')
          .where('organizationCode', isEqualTo: organizationCode)
          .get();

      // Count report statuses
      int validReports = 0;
      int invalidReports = 0;
      int pendingReports = 0;

      for (final doc in reportsQuery.docs) {
        final status = doc.data()['status'] as String;
        switch (status) {
          case 'valid':
            validReports++;
            break;
          case 'invalid':
            invalidReports++;
            break;
          case 'pending':
            pendingReports++;
            break;
        }
      }

      return {
        'totalPosts': postsQuery.docs.length,
        'totalReports': reportsQuery.docs.length,
        'validReports': validReports,
        'invalidReports': invalidReports,
        'pendingReports': pendingReports,
      };
    } catch (e) {
      print('Error fetching analytics: $e');
      return {
        'totalPosts': 0,
        'totalReports': 0,
        'validReports': 0,
        'invalidReports': 0,
        'pendingReports': 0,
      };
    }
  }

// Helper method to get all users in an organization
  Future<List<String>> _getUsersInOrganization(String organizationCode) async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('organizationCode', isEqualTo: organizationCode)
          .get();

      return usersQuery.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting users in organization: $e');
      return [];
    }
  }

  Future<void> _notifyAdminsOfReport({
    required String organizationCode,
    required String reporterName,
    required String postId,
  }) async {
    try {
      // Get all admins in the organization
      final adminsQuery = await _firestore
          .collection('users')
          .where('organizationCode', isEqualTo: organizationCode)
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();

      // Create notification for each admin
      for (final adminDoc in adminsQuery.docs) {
        await _createNotification(
          userId: adminDoc.id,
          type: NotificationType.general,
          title: 'New Post Report',
          message: '$reporterName reported a post that requires review',
          data: {'postId': postId, 'reportType': 'post'},
        );
      }
    } catch (e) {
      print('Error notifying admins: $e');
    }
  }

  // Helper method to validate Firebase Storage URLs
  bool _isValidFirebaseStorageUrl(String url) {
    try {
      if (url.isEmpty) return false;

      // Check if it's a valid Firebase Storage URL
      final uri = Uri.parse(url);

      // Must be https
      if (uri.scheme != 'https') return false;

      // Must be firebasestorage.googleapis.com domain
      if (!uri.host.contains('firebasestorage.googleapis.com')) return false;

      // Must have proper path structure
      if (!uri.path.contains('/v0/b/') || !uri.path.contains('/o/')) return false;

      return true;
    } catch (e) {
      print('URL validation error: $e');
      return false;
    }
  }

  // Legacy cleanup method - can be removed if not used elsewhere
  @Deprecated('Use cleanupBrokenImagePosts instead')
  Future<void> cleanupBrokenPosts() async {
    await cleanupBrokenImagePosts();
  }
}

class ModerationSettings {
  static double toxicityThreshold = 0.7;
  static double severeThreshold = 0.5;
  static double spamThreshold = 0.8;
  static bool enableRealTimeChecking = true;
  static bool blockOnHighToxicity = true;
  static bool flagForReview = true;
}