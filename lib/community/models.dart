import 'package:cloud_firestore/cloud_firestore.dart';

// User model for community features
class CommunityUser {
  final String uid;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String organizationCode;
  final String role;
  final int postCount;
  final int friendCount;
  final DateTime joinDate;
  final bool isActive;

  CommunityUser({
    required this.uid,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.organizationCode,
    required this.role,
    this.postCount = 0,
    this.friendCount = 0,
    required this.joinDate,
    this.isActive = true,
  });

  factory CommunityUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityUser(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      bio: data['bio'],
      organizationCode: data['organizationCode'] ?? '',
      role: data['role'] ?? 'student',
      postCount: data['postCount'] ?? 0,
      friendCount: data['friendCount'] ?? 0,
      joinDate: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'organizationCode': organizationCode,
      'role': role,
      'postCount': postCount,
      'friendCount': friendCount,
      'isActive': isActive,
    };
  }
}

// Post model
class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final List<String> mediaUrls;
  final List<MediaType> mediaTypes;
  final String caption;
  final DateTime createdAt;
  final int likeCount; // Total count of all reactions
  final int commentCount;
  final PostPrivacy privacy;
  final List<String> likedBy; // Users who reacted (any reaction)
  final Map<String, List<String>> reactions; // reaction emoji -> list of user IDs
  final Map<String, String> userReactions; // userId -> reaction emoji
  final bool isEdited;
  final DateTime? editedAt;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.mediaUrls,
    required this.mediaTypes,
    required this.caption,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.privacy = PostPrivacy.public,
    this.likedBy = const [],
    this.reactions = const {},
    this.userReactions = const {},
    this.isEdited = false,
    this.editedAt,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert reactions from Map<String, int> to Map<String, List<String>>
    final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> reactions = {};
    reactionsData.forEach((emoji, users) {
      if (users is List) {
        reactions[emoji] = List<String>.from(users);
      }
    });

    // Build userReactions map
    final Map<String, String> userReactions = Map<String, String>.from(data['userReactions'] ?? {});

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: (data['mediaTypes'] as List?)
          ?.map((type) => MediaType.values.firstWhere(
            (e) => e.toString() == 'MediaType.$type',
        orElse: () => MediaType.image,
      ))
          .toList() ?? [],
      caption: data['caption'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      privacy: PostPrivacy.values.firstWhere(
            (e) => e.toString() == 'PostPrivacy.${data['privacy'] ?? 'public'}',
        orElse: () => PostPrivacy.public,
      ),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      reactions: reactions,
      userReactions: userReactions,
      isEdited: data['isEdited'] ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    // Convert reactions to store user lists
    final reactionsMap = <String, dynamic>{};
    reactions.forEach((emoji, users) {
      reactionsMap[emoji] = users;
    });

    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes.map((type) => type.toString().split('.').last).toList(),
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'privacy': privacy.toString().split('.').last,
      'likedBy': likedBy,
      'reactions': reactionsMap,
      'userReactions': userReactions,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }

  Post copyWith({
    String? caption,
    int? likeCount,
    int? commentCount,
    List<String>? likedBy,
    Map<String, List<String>>? reactions,
    Map<String, String>? userReactions,
    bool? isEdited,
    DateTime? editedAt,
    PostPrivacy? privacy,
  }) {
    return Post(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      caption: caption ?? this.caption,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      privacy: privacy ?? this.privacy,
      likedBy: likedBy ?? this.likedBy,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

// Comment model
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final int likeCount;
  final List<String> likedBy;
  final List<String> mentions;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.likedBy = const [],
    this.mentions = const [],
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentId: data['parentId'],
      likeCount: data['likeCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      mentions: List<String>.from(data['mentions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentId': parentId,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'mentions': mentions,
    };
  }
}

// Friend model
class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendName;
  final String? friendAvatar;
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final List<String> mutualFriends;
  final bool isReceived;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.mutualFriends = const [],
    this.isReceived = false,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Add debug logging
    print('DEBUG: Friend.fromFirestore - Doc ID: ${doc.id}');
    print('DEBUG: Friend.fromFirestore - Data: $data');

    return Friend(
      id: doc.id,
      userId: data['userId'] ?? '',
      friendId: data['friendId'] ?? '',
      friendName: data['friendName'] ?? '',
      friendAvatar: data['friendAvatar'],
      status: FriendStatus.values.firstWhere(
            (e) => e.toString() == 'FriendStatus.${data['status'] ?? 'pending'}',
        orElse: () => FriendStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      mutualFriends: List<String>.from(data['mutualFriends'] ?? []),
      isReceived: data['isReceived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'friendId': friendId,
      'friendName': friendName,
      'friendAvatar': friendAvatar,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'mutualFriends': mutualFriends,
      'isReceived': isReceived,
    };
  }
}


// Notification model
class CommunityNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? actionUserId;
  final String? actionUserName;
  final String? actionUserAvatar;
  final String? postId;
  final String? commentId;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  CommunityNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.actionUserId,
    this.actionUserName,
    this.actionUserAvatar,
    this.postId,
    this.commentId,
    required this.createdAt,
    this.isRead = false,
    this.data = const {},
  });

  factory CommunityNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
            (e) => e.toString() == 'NotificationType.${data['type'] ?? 'general'}',
        orElse: () => NotificationType.general,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      actionUserId: data['actionUserId'],
      actionUserName: data['actionUserName'],
      actionUserAvatar: data['actionUserAvatar'],
      postId: data['postId'],
      commentId: data['commentId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'actionUserId': actionUserId,
      'actionUserName': actionUserName,
      'actionUserAvatar': actionUserAvatar,
      'postId': postId,
      'commentId': commentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
    };
  }
}

// Enums
enum MediaType { image, video }
enum PostPrivacy { public, friendsOnly, private }
enum FriendStatus { pending, accepted, blocked }
enum NotificationType {
  like,
  comment,
  friendRequest,
  friendAccepted,
  mention,
  newPost,
  general
}

// Feed item wrapper for mixed content
class FeedItem {
  final dynamic item; // Can be Post, Story, etc.
  final FeedItemType type;
  final DateTime timestamp;

  FeedItem({
    required this.item,
    required this.type,
    required this.timestamp,
  });
}

enum FeedItemType { post, story, suggestion }

// Media upload progress
class MediaUpload {
  final String localPath;
  final MediaType type;
  final double progress;
  final String? uploadedUrl;
  final String? error;

  MediaUpload({
    required this.localPath,
    required this.type,
    this.progress = 0.0,
    this.uploadedUrl,
    this.error,
  });

  MediaUpload copyWith({
    double? progress,
    String? uploadedUrl,
    String? error,
  }) {
    return MediaUpload(
      localPath: localPath,
      type: type,
      progress: progress ?? this.progress,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      error: error ?? this.error,
    );
  }
}

// Reaction types
class ReactionType {
  static const String like = '👍';
  static const String love = '❤️';
  static const String laugh = '😂';
  static const String wow = '😮';
  static const String sad = '😢';

  static const List<String> all = [like, love, laugh, wow, sad];
}