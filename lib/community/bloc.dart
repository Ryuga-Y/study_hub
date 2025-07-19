import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'community_services.dart';
import 'models.dart';

// Events
abstract class CommunityEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// Post Events
class LoadFeed extends CommunityEvent {
  final String organizationCode;
  final bool refresh;

  LoadFeed({required this.organizationCode, this.refresh = false});

  @override
  List<Object> get props => [organizationCode, refresh];
}

class LoadMoreFeed extends CommunityEvent {}

class CreatePost extends CommunityEvent {
  final List<File> mediaFiles;
  final List<MediaType> mediaTypes;
  final String caption;
  final PostPrivacy privacy;

  CreatePost({
    required this.mediaFiles,
    required this.mediaTypes,
    required this.caption,
    required this.privacy,
  });

  @override
  List<Object> get props => [mediaFiles, mediaTypes, caption, privacy];
}

class UpdatePost extends CommunityEvent {
  final String postId;
  final String caption;
  final PostPrivacy privacy;

  UpdatePost({
    required this.postId,
    required this.caption,
    required this.privacy,
  });

  @override
  List<Object> get props => [postId, caption, privacy];
}

class DeletePost extends CommunityEvent {
  final String postId;

  DeletePost(this.postId);

  @override
  List<Object> get props => [postId];
}

class ToggleLike extends CommunityEvent {
  final String postId;

  ToggleLike(this.postId);

  @override
  List<Object> get props => [postId];
}

class AddReaction extends CommunityEvent {
  final String postId;
  final String reaction;

  AddReaction({required this.postId, required this.reaction});

  @override
  List<Object> get props => [postId, reaction];
}

// Comment Events
class LoadComments extends CommunityEvent {
  final String postId;

  LoadComments(this.postId);

  @override
  List<Object> get props => [postId];
}

class AddComment extends CommunityEvent {
  final String postId;
  final String content;
  final String? parentId;
  final List<String> mentions;

  AddComment({
    required this.postId,
    required this.content,
    this.parentId,
    this.mentions = const [],
  });

  @override
  List<Object?> get props => [postId, content, parentId, mentions];
}

class DeleteComment extends CommunityEvent {
  final String commentId;
  final String postId;

  DeleteComment({required this.commentId, required this.postId});

  @override
  List<Object> get props => [commentId, postId];
}

// Friend Events
class LoadFriends extends CommunityEvent {}

class LoadPendingRequests extends CommunityEvent {}

class SendFriendRequest extends CommunityEvent {
  final String friendId;

  SendFriendRequest(this.friendId);

  @override
  List<Object> get props => [friendId];
}

class AcceptFriendRequest extends CommunityEvent {
  final String requestId;

  AcceptFriendRequest(this.requestId);

  @override
  List<Object> get props => [requestId];
}

class DeclineFriendRequest extends CommunityEvent {
  final String requestId;

  DeclineFriendRequest(this.requestId);

  @override
  List<Object> get props => [requestId];
}

class RemoveFriend extends CommunityEvent {
  final String friendId;

  RemoveFriend(this.friendId);

  @override
  List<Object> get props => [friendId];
}

// User Events
class SearchUsers extends CommunityEvent {
  final String query;
  final String organizationCode;

  SearchUsers({required this.query, required this.organizationCode});

  @override
  List<Object> get props => [query, organizationCode];
}

class LoadUserProfile extends CommunityEvent {
  final String userId;

  LoadUserProfile(this.userId);

  @override
  List<Object> get props => [userId];
}

class UpdateUserProfile extends CommunityEvent {
  final String? bio;
  final File? avatarFile;

  UpdateUserProfile({this.bio, this.avatarFile});

  @override
  List<Object?> get props => [bio, avatarFile];
}

class SyncFriendCount extends CommunityEvent {
  final String userId;

  SyncFriendCount(this.userId);

  @override
  List<Object> get props => [userId];
}

// Notification Events
class LoadNotifications extends CommunityEvent {}

class MarkNotificationRead extends CommunityEvent {
  final String notificationId;

  MarkNotificationRead(this.notificationId);

  @override
  List<Object> get props => [notificationId];
}

class MarkAllNotificationsRead extends CommunityEvent {}

// State
class CommunityState extends Equatable {
  final List<Post> feedPosts;
  final List<Post> userPosts;
  final Map<String, List<Comment>> postComments;
  final List<Friend> friends;
  final List<Friend> pendingRequests;
  final List<CommunityUser> searchResults;
  final List<CommunityNotification> notifications;
  final CommunityUser? currentUserProfile;
  final CommunityUser? viewingUserProfile;
  final bool isLoadingFeed;
  final bool isLoadingMore;
  final bool isCreatingPost;
  final bool hasMorePosts;
  final String? error;
  final String? successMessage;
  final int unreadNotificationCount;

  const CommunityState({
    this.feedPosts = const [],
    this.userPosts = const [],
    this.postComments = const {},
    this.friends = const [],
    this.pendingRequests = const [],
    this.searchResults = const [],
    this.notifications = const [],
    this.currentUserProfile,
    this.viewingUserProfile,
    this.isLoadingFeed = false,
    this.isLoadingMore = false,
    this.isCreatingPost = false,
    this.hasMorePosts = true,
    this.error,
    this.successMessage,
    this.unreadNotificationCount = 0,
  });

  CommunityState copyWith({
    List<Post>? feedPosts,
    List<Post>? userPosts,
    Map<String, List<Comment>>? postComments,
    List<Friend>? friends,
    List<Friend>? pendingRequests,
    List<CommunityUser>? searchResults,
    List<CommunityNotification>? notifications,
    CommunityUser? currentUserProfile,
    CommunityUser? viewingUserProfile,
    bool? isLoadingFeed,
    bool? isLoadingMore,
    bool? isCreatingPost,
    bool? hasMorePosts,
    String? error,
    String? successMessage,
    int? unreadNotificationCount,
  }) {
    return CommunityState(
      feedPosts: feedPosts ?? this.feedPosts,
      userPosts: userPosts ?? this.userPosts,
      postComments: postComments ?? this.postComments,
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      searchResults: searchResults ?? this.searchResults,
      notifications: notifications ?? this.notifications,
      currentUserProfile: currentUserProfile ?? this.currentUserProfile,
      viewingUserProfile: viewingUserProfile ?? this.viewingUserProfile,
      isLoadingFeed: isLoadingFeed ?? this.isLoadingFeed,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreatingPost: isCreatingPost ?? this.isCreatingPost,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      error: error,
      successMessage: successMessage,
      unreadNotificationCount: unreadNotificationCount ?? this.unreadNotificationCount,
    );
  }

  @override
  List<Object?> get props => [
    feedPosts,
    userPosts,
    postComments,
    friends,
    pendingRequests,
    searchResults,
    notifications,
    currentUserProfile,
    viewingUserProfile,
    isLoadingFeed,
    isLoadingMore,
    isCreatingPost,
    hasMorePosts,
    error,
    successMessage,
    unreadNotificationCount,
  ];
}

// BLoC
class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  final CommunityService _service;

  CommunityBloc({CommunityService? service})
      : _service = service ?? CommunityService(),
        super(const CommunityState()) {

    // Post Events
    on<LoadFeed>(_onLoadFeed);
    on<LoadMoreFeed>(_onLoadMoreFeed);
    on<CreatePost>(_onCreatePost);
    on<UpdatePost>(_onUpdatePost);
    on<DeletePost>(_onDeletePost);
    on<ToggleLike>(_onToggleLike);
    on<AddReaction>(_onAddReaction);

    // Comment Events
    on<LoadComments>(_onLoadComments);
    on<AddComment>(_onAddComment);
    on<DeleteComment>(_onDeleteComment);

    // Friend Events
    on<LoadFriends>(_onLoadFriends);
    on<LoadPendingRequests>(_onLoadPendingRequests);
    on<SendFriendRequest>(_onSendFriendRequest);
    on<AcceptFriendRequest>(_onAcceptFriendRequest);
    on<DeclineFriendRequest>(_onDeclineFriendRequest);
    on<RemoveFriend>(_onRemoveFriend);

    // User Events
    on<SearchUsers>(_onSearchUsers);
    on<LoadUserProfile>(_onLoadUserProfile);
    on<UpdateUserProfile>(_onUpdateUserProfile);
    on<SyncFriendCount>(_onSyncFriendCount);

    // Notification Events
    on<LoadNotifications>(_onLoadNotifications);
    on<MarkNotificationRead>(_onMarkNotificationRead);
    on<MarkAllNotificationsRead>(_onMarkAllNotificationsRead);
  }

  // Post Handlers
  Future<void> _onLoadFeed(LoadFeed event, Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(
        isLoadingFeed: true,
        error: null,
        feedPosts: event.refresh ? [] : state.feedPosts,
      ));

      await emit.forEach(
        _service.getFeedPosts(organizationCode: event.organizationCode),
        onData: (posts) => state.copyWith(
          feedPosts: posts,
          isLoadingFeed: false,
          hasMorePosts: posts.length >= 20,
        ),
        onError: (error, stackTrace) => state.copyWith(
          isLoadingFeed: false,
          error: error.toString(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(
        isLoadingFeed: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMoreFeed(LoadMoreFeed event, Emitter<CommunityState> emit) async {
    if (state.isLoadingMore || !state.hasMorePosts) return;

    try {
      emit(state.copyWith(isLoadingMore: true));

      // Implementation would include pagination logic
      // For now, we'll just set loading to false
      emit(state.copyWith(isLoadingMore: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreatePost(CreatePost event, Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      final postId = await _service.createPost(
        mediaFiles: event.mediaFiles,
        mediaTypes: event.mediaTypes,
        caption: event.caption,
        privacy: event.privacy,
      );

      emit(state.copyWith(
        isCreatingPost: false,
        successMessage: 'Post created successfully!',
      ));

      // Reload feed to show new post
      add(LoadFeed(
        organizationCode: state.currentUserProfile?.organizationCode ?? '',
        refresh: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isCreatingPost: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdatePost(UpdatePost event, Emitter<CommunityState> emit) async {
    try {
      await _service.updatePost(
        postId: event.postId,
        caption: event.caption,
        privacy: event.privacy,
      );

      // Update post in local state
      final updatedPosts = state.feedPosts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            caption: event.caption,
            isEdited: true,
            editedAt: DateTime.now(),
          );
        }
        return post;
      }).toList();

      emit(state.copyWith(
        feedPosts: updatedPosts,
        successMessage: 'Post updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeletePost(DeletePost event, Emitter<CommunityState> emit) async {
    try {
      await _service.deletePost(event.postId);

      // Remove post from local state
      final updatedPosts = state.feedPosts
          .where((post) => post.id != event.postId)
          .toList();

      emit(state.copyWith(
        feedPosts: updatedPosts,
        successMessage: 'Post deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Updated toggle like handler to use default reaction
  Future<void> _onToggleLike(ToggleLike event, Emitter<CommunityState> emit) async {
    try {
      final currentUserId = _service.currentUserId;
      if (currentUserId == null) return;

      // Use default like reaction
      await _handleReaction(event.postId, ReactionType.like, emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Updated add reaction handler
  Future<void> _onAddReaction(AddReaction event, Emitter<CommunityState> emit) async {
    try {
      await _handleReaction(event.postId, event.reaction, emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Helper method to handle reactions
  Future<void> _handleReaction(String postId, String reaction, Emitter<CommunityState> emit) async {
    final currentUserId = _service.currentUserId;
    if (currentUserId == null) return;

    // Store original posts for potential rollback
    final originalPosts = List<Post>.from(state.feedPosts);

    // Optimistically update local state
    final updatedPosts = state.feedPosts.map((post) {
      if (post.id == postId) {
        final likedBy = List<String>.from(post.likedBy);
        final reactions = Map<String, List<String>>.from(post.reactions);
        final userReactions = Map<String, String>.from(post.userReactions);
        final currentReaction = userReactions[currentUserId];

        if (currentReaction == reaction) {
          // Removing reaction
          likedBy.remove(currentUserId);
          userReactions.remove(currentUserId);
          if (reactions[reaction] != null) {
            reactions[reaction] = List<String>.from(reactions[reaction]!)
              ..remove(currentUserId);
            if (reactions[reaction]!.isEmpty) {
              reactions.remove(reaction);
            }
          }
        } else {
          // Adding/changing reaction
          if (currentReaction != null) {
            // Remove from old reaction
            if (reactions[currentReaction] != null) {
              reactions[currentReaction] = List<String>.from(reactions[currentReaction]!)
                ..remove(currentUserId);
              if (reactions[currentReaction]!.isEmpty) {
                reactions.remove(currentReaction);
              }
            }
          } else {
            // New reaction
            likedBy.add(currentUserId);
          }

          userReactions[currentUserId] = reaction;
          reactions[reaction] = List<String>.from(reactions[reaction] ?? [])
            ..add(currentUserId);
        }

        return post.copyWith(
          likedBy: likedBy,
          likeCount: likedBy.length,
          reactions: reactions,
          userReactions: userReactions,
        );
      }
      return post;
    }).toList();

    emit(state.copyWith(feedPosts: updatedPosts));

    // Make API call
    try {
      await _service.toggleReaction(postId, reaction);
    } catch (e) {
      // Revert on failure
      emit(state.copyWith(
        feedPosts: originalPosts,
        error: 'Failed to update reaction',
      ));
    }
  }

  // Comment Handlers
  Future<void> _onLoadComments(LoadComments event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getComments(event.postId),
        onData: (comments) {
          final updatedComments = Map<String, List<Comment>>.from(state.postComments);
          updatedComments[event.postId] = comments;
          return state.copyWith(postComments: updatedComments);
        },
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAddComment(AddComment event, Emitter<CommunityState> emit) async {
    try {
      await _service.addComment(
        postId: event.postId,
        content: event.content,
        parentId: event.parentId,
        mentions: event.mentions,
      );

      // Update comment count in local state
      final updatedPosts = state.feedPosts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(commentCount: post.commentCount + 1);
        }
        return post;
      }).toList();

      emit(state.copyWith(
        feedPosts: updatedPosts,
        successMessage: 'Comment added!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteComment(DeleteComment event, Emitter<CommunityState> emit) async {
    try {
      await _service.deleteComment(
        commentId: event.commentId,
        postId: event.postId,
      );

      // Update the local state by removing the comment
      final updatedComments = Map<String, List<Comment>>.from(state.postComments);
      final postComments = updatedComments[event.postId] ?? [];

      // Remove the comment from the list
      final filteredComments = postComments.where((comment) => comment.id != event.commentId).toList();
      updatedComments[event.postId] = filteredComments;

      // Update the post's comment count
      final updatedPosts = state.feedPosts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(commentCount: post.commentCount > 0 ? post.commentCount - 1 : 0);
        }
        return post;
      }).toList();

      emit(state.copyWith(
        postComments: updatedComments,
        feedPosts: updatedPosts,
        successMessage: 'Comment deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Friend Handlers
  Future<void> _onLoadFriends(LoadFriends event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getFriends(status: FriendStatus.accepted), // Explicitly request accepted friends
        onData: (friends) {
          print('DEBUG: BLoC - Loaded ${friends.length} friends');
          return state.copyWith(friends: friends);
        },
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }


  Future<void> _onLoadPendingRequests(LoadPendingRequests event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getPendingFriendRequests(),
        onData: (requests) => state.copyWith(pendingRequests: requests),
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSendFriendRequest(SendFriendRequest event, Emitter<CommunityState> emit) async {
    try {
      await _service.sendFriendRequest(event.friendId);

      emit(state.copyWith(successMessage: 'Friend request sent!'));

      // Refresh search results to update button states
      if (state.searchResults.isNotEmpty) {
        final lastQuery = state.searchResults.first.fullName; // This is a hack, you might want to store the last query
        add(SearchUsers(
          query: lastQuery,
          organizationCode: state.currentUserProfile?.organizationCode ?? '',
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAcceptFriendRequest(AcceptFriendRequest event, Emitter<CommunityState> emit) async {
    try {
      print('DEBUG: BLoC - Accepting friend request: ${event.requestId}');

      await _service.acceptFriendRequest(event.requestId);

      // Remove the accepted request from pending requests immediately
      final updatedRequests = state.pendingRequests
          .where((request) => request.id != event.requestId)
          .toList();

      emit(state.copyWith(
        pendingRequests: updatedRequests,
        successMessage: 'Friend request accepted!',
      ));

      // Reload friends list and user profile to update counts
      add(LoadFriends());
      add(LoadPendingRequests());

      // Reload current user profile to update friend count
      if (_service.currentUserId != null) {
        add(LoadUserProfile(_service.currentUserId!));
      }
    } catch (e) {
      print('DEBUG: BLoC - Error accepting friend request: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeclineFriendRequest(DeclineFriendRequest event, Emitter<CommunityState> emit) async {
    try {
      await _service.declineFriendRequest(event.requestId);

      // Remove from local state immediately
      final updatedRequests = state.pendingRequests
          .where((request) => request.id != event.requestId)
          .toList();

      emit(state.copyWith(
        pendingRequests: updatedRequests,
        successMessage: 'Friend request declined',
      ));

      // Reload pending requests to ensure consistency
      add(LoadPendingRequests());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemoveFriend(RemoveFriend event, Emitter<CommunityState> emit) async {
    try {
      await _service.removeFriend(event.friendId);

      // Remove from local state immediately
      final updatedFriends = state.friends
          .where((friend) => friend.friendId != event.friendId)
          .toList();

      emit(state.copyWith(
        friends: updatedFriends,
        successMessage: 'Friend removed',
      ));

      // Reload friends and update profile
      add(LoadFriends());
      if (_service.currentUserId != null) {
        add(LoadUserProfile(_service.currentUserId!));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // User Handlers
  Future<void> _onSearchUsers(SearchUsers event, Emitter<CommunityState> emit) async {
    try {
      if (event.query.isEmpty) {
        emit(state.copyWith(searchResults: []));
        return;
      }

      final results = await _service.searchUsers(event.query, event.organizationCode);
      emit(state.copyWith(searchResults: results));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadUserProfile(LoadUserProfile event, Emitter<CommunityState> emit) async {
    try {
      if (event.userId == _service.currentUserId) {
        await _service.syncFriendCount(event.userId);
      }

      await emit.forEach(
        _service.getUserStream(event.userId),
        onData: (user) {
          if (event.userId == _service.currentUserId) {
            return state.copyWith(currentUserProfile: user);
          } else {
            return state.copyWith(viewingUserProfile: user);
          }
        },
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateUserProfile(UpdateUserProfile event, Emitter<CommunityState> emit) async {
    try {
      await _service.updateUserProfile(
        bio: event.bio,
        avatarFile: event.avatarFile,
      );

      emit(state.copyWith(successMessage: 'Profile updated successfully!'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSyncFriendCount(SyncFriendCount event, Emitter<CommunityState> emit) async {
    try {
      await _service.syncFriendCount(event.userId);

      // Reload user profile to get updated count
      add(LoadUserProfile(event.userId));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to sync friend count: $e'));
    }
  }

  // Notification Handlers
  Future<void> _onLoadNotifications(LoadNotifications event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getNotifications(),
        onData: (notifications) {
          final unreadCount = notifications.where((n) => !n.isRead).length;
          return state.copyWith(
            notifications: notifications,
            unreadNotificationCount: unreadCount,
          );
        },
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onMarkNotificationRead(MarkNotificationRead event, Emitter<CommunityState> emit) async {
    try {
      await _service.markNotificationAsRead(event.notificationId);

      // Update local state
      final updatedNotifications = state.notifications.map((notification) {
        if (notification.id == event.notificationId) {
          return CommunityNotification(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            actionUserId: notification.actionUserId,
            actionUserName: notification.actionUserName,
            actionUserAvatar: notification.actionUserAvatar,
            postId: notification.postId,
            commentId: notification.commentId,
            createdAt: notification.createdAt,
            isRead: true,
            data: notification.data,
          );
        }
        return notification;
      }).toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      emit(state.copyWith(
        notifications: updatedNotifications,
        unreadNotificationCount: unreadCount,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onMarkAllNotificationsRead(MarkAllNotificationsRead event, Emitter<CommunityState> emit) async {
    try {
      await _service.markAllNotificationsAsRead();

      // Update local state
      final updatedNotifications = state.notifications.map((notification) {
        return CommunityNotification(
          id: notification.id,
          userId: notification.userId,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          actionUserId: notification.actionUserId,
          actionUserName: notification.actionUserName,
          actionUserAvatar: notification.actionUserAvatar,
          postId: notification.postId,
          commentId: notification.commentId,
          createdAt: notification.createdAt,
          isRead: true,
          data: notification.data,
        );
      }).toList();

      emit(state.copyWith(
        notifications: updatedNotifications,
        unreadNotificationCount: 0,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}