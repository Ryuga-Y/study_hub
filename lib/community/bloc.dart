import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// New combined event for creating post with poll
class CreatePostWithPoll extends CommunityEvent {
  final String caption;
  final PostPrivacy privacy;
  final String pollQuestion;
  final List<String> pollOptions;
  final bool allowMultipleVotes;
  final DateTime? endsAt;
  final bool isAnonymous;

  CreatePostWithPoll({
    required this.caption,
    required this.privacy,
    required this.pollQuestion,
    required this.pollOptions,
    this.allowMultipleVotes = false,
    this.endsAt,
    this.isAnonymous = false,
  });

  @override
  List<Object?> get props => [
    caption,
    privacy,
    pollQuestion,
    pollOptions,
    allowMultipleVotes,
    endsAt,
    isAnonymous,
  ];
}

class CreatePostWithMediaAndPoll extends CommunityEvent {
  final List<File> mediaFiles;
  final List<MediaType> mediaTypes;
  final String caption;
  final PostPrivacy privacy;
  final String? pollQuestion;
  final List<String>? pollOptions;
  final bool? allowMultipleVotes;
  final DateTime? pollEndsAt;
  final bool? pollIsAnonymous;

  CreatePostWithMediaAndPoll({
    required this.mediaFiles,
    required this.mediaTypes,
    required this.caption,
    required this.privacy,
    this.pollQuestion,
    this.pollOptions,
    this.allowMultipleVotes,
    this.pollEndsAt,
    this.pollIsAnonymous,
  });

  @override
  List<Object?> get props => [
    mediaFiles,
    mediaTypes,
    caption,
    privacy,
    pollQuestion,
    pollOptions,
    allowMultipleVotes,
    pollEndsAt,
    pollIsAnonymous,
  ];
}

// Poll Events - Add to your CommunityEvent classes
class CreatePoll extends CommunityEvent {
  final String postId;
  final String question;
  final List<String> options;
  final bool allowMultipleVotes;
  final DateTime? endsAt;
  final bool isAnonymous;

  CreatePoll({
    required this.postId,
    required this.question,
    required this.options,
    this.allowMultipleVotes = false,
    this.endsAt,
    this.isAnonymous = false,
  });

  @override
  List<Object?> get props => [postId, question, options, allowMultipleVotes, endsAt, isAnonymous];
}

class VoteOnPoll extends CommunityEvent {
  final String pollId;
  final String optionId;

  VoteOnPoll({required this.pollId, required this.optionId});

  @override
  List<Object> get props => [pollId, optionId];
}

class UpdatePoll extends CommunityEvent {
  final String pollId;
  final String? question;
  final List<PollOption>? options;
  final DateTime? endsAt;

  UpdatePoll({
    required this.pollId,
    this.question,
    this.options,
    this.endsAt,
  });

  @override
  List<Object?> get props => [pollId, question, options, endsAt];
}

class DeletePoll extends CommunityEvent {
  final String pollId;
  final String postId;

  DeletePoll({required this.pollId, required this.postId});

  @override
  List<Object> get props => [pollId, postId];
}

class LoadPoll extends CommunityEvent {
  final String pollId;

  LoadPoll(this.pollId);

  @override
  List<Object> get props => [pollId];
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

class SharePost extends CommunityEvent {
  final String postId;
  final String? comment;
  final PostPrivacy privacy;

  SharePost({
    required this.postId,
    this.comment,
    required this.privacy,
  });

  @override
  List<Object?> get props => [postId, comment, privacy];
}

class ExternalSharePost extends CommunityEvent {
  final Post post;

  ExternalSharePost(this.post);

  @override
  List<Object> get props => [post];
}

// Report Events
class ReportPost extends CommunityEvent {
  final String postId;
  final String reason;
  final String details;

  ReportPost({
    required this.postId,
    required this.reason,
    required this.details,
  });

  @override
  List<Object> get props => [postId, reason, details];
}

// Admin Events
class LoadReportedPosts extends CommunityEvent {
  final String organizationCode;

  LoadReportedPosts({required this.organizationCode});

  @override
  List<Object> get props => [organizationCode];
}

class ReviewReport extends CommunityEvent {
  final String reportId;
  final String postId;
  final bool isValid;
  final String adminNotes;

  ReviewReport({
    required this.reportId,
    required this.postId,
    required this.isValid,
    required this.adminNotes,
  });

  @override
  List<Object> get props => [reportId, postId, isValid, adminNotes];
}

class AdminDeletePost extends CommunityEvent {
  final String postId;
  final String reason;

  AdminDeletePost({
    required this.postId,
    required this.reason,
  });

  @override
  List<Object> get props => [postId, reason];
}

class HidePost extends CommunityEvent {
  final String postId;
  final String reason;

  HidePost({
    required this.postId,
    required this.reason,
  });

  @override
  List<Object> get props => [postId, reason];
}

class UnhidePost extends CommunityEvent {
  final String postId;

  UnhidePost({required this.postId});

  @override
  List<Object> get props => [postId];
}

class LoadHiddenPosts extends CommunityEvent {
  final String organizationCode;

  LoadHiddenPosts({required this.organizationCode});

  @override
  List<Object> get props => [organizationCode];
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
class LoadFriends extends CommunityEvent {
  final String? userId; // Optional userId to load friends for a specific user

  LoadFriends({this.userId});

  @override
  List<Object?> get props => [userId];
}

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
  final String? fullName; // Add full name support
  final File? avatarFile;
  final FriendsListPrivacy? friendsListPrivacy;
  final bool removeAvatar;

  UpdateUserProfile({
    this.bio,
    this.fullName, // Add this parameter
    this.avatarFile,
    this.friendsListPrivacy,
    this.removeAvatar = false,
  });

  @override
  List<Object?> get props => [bio, fullName, avatarFile, friendsListPrivacy, removeAvatar];
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

class LoadAnalytics extends CommunityEvent {
  final String organizationCode;

  LoadAnalytics({required this.organizationCode});

  @override
  List<Object> get props => [organizationCode];
}

class UpdatePostWithMedia extends CommunityEvent {
  final String postId;
  final String caption;
  final PostPrivacy privacy;
  final List<File>? newMediaFiles;
  final List<MediaType>? newMediaTypes;
  final List<String>? keepExistingMediaUrls; // URLs of existing media to keep

  UpdatePostWithMedia({
    required this.postId,
    required this.caption,
    required this.privacy,
    this.newMediaFiles,
    this.newMediaTypes,
    this.keepExistingMediaUrls,
  });

  @override
  List<Object?> get props => [
    postId,
    caption,
    privacy,
    newMediaFiles,
    newMediaTypes,
    keepExistingMediaUrls
  ];
}

// Enhanced UpdatePoll event to include options
class UpdatePollWithOptions extends CommunityEvent {
  final String pollId;
  final String? question;
  final List<String>? optionTexts; // New option texts
  final DateTime? endsAt;
  final bool? isAnonymous;

  UpdatePollWithOptions({
    required this.pollId,
    this.question,
    this.optionTexts,
    this.endsAt,
    this.isAnonymous,
  });

  @override
  List<Object?> get props => [pollId, question, optionTexts, endsAt, isAnonymous];
}

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
  final List<PostReport> reportedPosts;
  final Map<String, int> analytics;
  final Map<String, Poll> polls;
  final List<Post> hiddenPosts;

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
    this.reportedPosts = const [],
    this.analytics = const {
      'totalPosts': 0,
      'totalReports': 0,
      'validReports': 0,
      'invalidReports': 0,
      'pendingReports': 0,
    },
    this.polls = const {},
    this.hiddenPosts = const [],
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
    List<PostReport>? reportedPosts,
    Map<String, int>? analytics,
    Map<String, Poll>? polls,
    List<Post>? hiddenPosts,
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
      reportedPosts: reportedPosts ?? this.reportedPosts,
      analytics: analytics ?? this.analytics,
      polls: polls ?? this.polls,
      hiddenPosts: hiddenPosts ?? this.hiddenPosts,
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
    reportedPosts,
    analytics,
    polls,
    hiddenPosts,
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
    on<CreatePostWithPoll>(_onCreatePostWithPoll); // New handler
    on<UpdatePost>(_onUpdatePost);
    on<DeletePost>(_onDeletePost);
    on<ToggleLike>(_onToggleLike);
    on<AddReaction>(_onAddReaction);
    on<SharePost>(_onSharePost);
    on<ExternalSharePost>(_onExternalSharePost);
    on<CreatePostWithMediaAndPoll>(_onCreatePostWithMediaAndPoll);
    on<UpdatePostWithMedia>(_onUpdatePostWithMedia);
    on<UpdatePollWithOptions>(_onUpdatePollWithOptions);

    on<ReportPost>(_onReportPost);
    on<LoadReportedPosts>(_onLoadReportedPosts);
    on<ReviewReport>(_onReviewReport);
    on<AdminDeletePost>(_onAdminDeletePost);

    on<HidePost>(_onHidePost);
    on<UnhidePost>(_onUnhidePost);
    on<LoadHiddenPosts>(_onLoadHiddenPosts);

    on<LoadAnalytics>(_onLoadAnalytics);

    // Poll Events
    on<CreatePoll>(_onCreatePoll);
    on<VoteOnPoll>(_onVoteOnPoll);
    on<UpdatePoll>(_onUpdatePoll);
    on<DeletePoll>(_onDeletePoll);
    on<LoadPoll>(_onLoadPoll);

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

  // 🆕 NEW: Hide post handler
  Future<void> _onHidePost(HidePost event, Emitter<CommunityState> emit) async {
    try {
      await _service.hidePost(event.postId, event.reason);

      // Remove from feed posts and reported posts
      final updatedFeedPosts = state.feedPosts
          .where((post) => post.id != event.postId)
          .toList();

      emit(state.copyWith(
        feedPosts: updatedFeedPosts,
        successMessage: 'Post hidden successfully',
      ));

      // Reload reported posts to refresh the list
      final orgCode = state.currentUserProfile?.organizationCode ?? '';
      if (orgCode.isNotEmpty) {
        add(LoadReportedPosts(organizationCode: orgCode));
        add(LoadHiddenPosts(organizationCode: orgCode));
      }

    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // 🆕 NEW: Unhide post handler
  Future<void> _onUnhidePost(UnhidePost event, Emitter<CommunityState> emit) async {
    try {
      await _service.unhidePost(event.postId);

      // Remove from hidden posts list
      final updatedHiddenPosts = state.hiddenPosts
          .where((post) => post.id != event.postId)
          .toList();

      emit(state.copyWith(
        hiddenPosts: updatedHiddenPosts,
        successMessage: 'Post unhidden successfully',
      ));

      // Reload feed to show the unhidden post
      add(LoadFeed(
        organizationCode: state.currentUserProfile?.organizationCode ?? '',
        refresh: true,
      ));

    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // 🆕 NEW: Load hidden posts handler
  Future<void> _onLoadHiddenPosts(LoadHiddenPosts event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getHiddenPosts(event.organizationCode),
        onData: (hiddenPosts) => state.copyWith(hiddenPosts: hiddenPosts),
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }


  Future<void> _onLoadAnalytics(LoadAnalytics event, Emitter<CommunityState> emit) async {
    try {
      final analytics = await _service.getCommunityAnalytics(event.organizationCode);
      emit(state.copyWith(analytics: analytics));
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  Future<void> _onUpdatePostWithMedia(UpdatePostWithMedia event, Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      await _service.updatePostWithMedia(
        postId: event.postId,
        caption: event.caption,
        privacy: event.privacy,
        newMediaFiles: event.newMediaFiles,
        newMediaTypes: event.newMediaTypes,
        keepExistingMediaUrls: event.keepExistingMediaUrls,
      );

      // Update post in local state
      final updatedPosts = state.feedPosts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
            caption: event.caption,
            privacy: event.privacy,
            isEdited: true,
            editedAt: DateTime.now(),
          );
        }
        return post;
      }).toList();

      emit(state.copyWith(
        feedPosts: updatedPosts,
        isCreatingPost: false,
        successMessage: 'Post updated successfully!',
      ));

      // Reload feed to get updated media URLs
      add(LoadFeed(
        organizationCode: state.currentUserProfile?.organizationCode ?? '',
        refresh: true,
      ));

    } catch (e) {
      emit(state.copyWith(
        isCreatingPost: false,
        error: 'Failed to update post: ${e.toString()}',
      ));
    }
  }

// Enhanced poll update handler
  Future<void> _onUpdatePollWithOptions(UpdatePollWithOptions event, Emitter<CommunityState> emit) async {
    try {
      await _service.updatePollWithOptions(
        pollId: event.pollId,
        question: event.question,
        optionTexts: event.optionTexts,
        endsAt: event.endsAt,
        isAnonymous: event.isAnonymous,
      );

      emit(state.copyWith(successMessage: 'Poll updated successfully!'));

      // Reload the poll to get updated data
      add(LoadPoll(event.pollId));

    } catch (e) {
      emit(state.copyWith(error: 'Failed to update poll: ${e.toString()}'));
    }
  }

  // New handler for creating post with poll
  Future<void> _onCreatePostWithPoll(CreatePostWithPoll event, Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      print('🔄 Creating post with poll...');
      print('   Question: ${event.pollQuestion}');
      print('   Options: ${event.pollOptions}');

      // Create post with poll using the service
      final postId = await _service.createPost(
        mediaFiles: [], // No media for poll posts
        mediaTypes: [],
        caption: event.caption,
        privacy: event.privacy,
      );

      print('✅ Post created with ID: $postId');

      // Create the poll
      final pollId = await _service.createPoll(
        postId: postId,
        question: event.pollQuestion,
        options: event.pollOptions,
        allowMultipleVotes: event.allowMultipleVotes,
        endsAt: event.endsAt,
        isAnonymous: event.isAnonymous,
      );

      print('✅ Poll created with ID: $pollId');

      // Update current user's post count in local state
      final updatedCurrentUser = state.currentUserProfile?.copyWith(
        postCount: state.currentUserProfile!.postCount + 1,
      );

      emit(state.copyWith(
        isCreatingPost: false,
        currentUserProfile: updatedCurrentUser,
        successMessage: 'Poll created successfully!',
      ));

      // Reload feed to show new post
      add(LoadFeed(
        organizationCode: state.currentUserProfile?.organizationCode ?? '',
        refresh: true,
      ));

    } catch (e) {
      // 🆕 ADD: Better error handling for moderation
      String errorMessage = e.toString();

      if (errorMessage.contains('violates community guidelines')) {
        errorMessage = 'Your post contains content that violates our community guidelines. Please revise and try again.';
      } else if (errorMessage.contains('Spam detected')) {
        errorMessage = 'Your post appears to contain spam. Please remove promotional content and try again.';
      }

      emit(state.copyWith(
        isCreatingPost: false,
        error: errorMessage,
      ));
    }
  }

  Future<void> _onCreatePostWithMediaAndPoll(
      CreatePostWithMediaAndPoll event,
      Emitter<CommunityState> emit
      ) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      print('🔄 Creating post with media and poll...');
      print('   Media files: ${event.mediaFiles.length}');
      print('   Poll question: ${event.pollQuestion}');
      print('   Poll options: ${event.pollOptions}');

      // Create post with media
      final postId = await _service.createPost(
        mediaFiles: event.mediaFiles,
        mediaTypes: event.mediaTypes,
        caption: event.caption,
        privacy: event.privacy,
      );

      print('✅ Post created with ID: $postId');

      // If poll data is provided, create the poll
      if (event.pollQuestion != null &&
          event.pollOptions != null &&
          event.pollOptions!.isNotEmpty) {

        final pollId = await _service.createPoll(
          postId: postId,
          question: event.pollQuestion!,
          options: event.pollOptions!,
          allowMultipleVotes: event.allowMultipleVotes ?? false,
          endsAt: event.pollEndsAt,
          isAnonymous: event.pollIsAnonymous ?? false,
        );

        print('✅ Poll created with ID: $pollId');
      }

      // Update current user's post count in local state
      final updatedCurrentUser = state.currentUserProfile?.copyWith(
        postCount: state.currentUserProfile!.postCount + 1,
      );

      emit(state.copyWith(
        isCreatingPost: false,
        currentUserProfile: updatedCurrentUser,
        successMessage: 'Post created successfully!',
      ));

      // Reload feed to show new post
      add(LoadFeed(
        organizationCode: state.currentUserProfile?.organizationCode ?? '',
        refresh: true,
      ));

    } catch (e) {
      print('❌ Error creating post with media and poll: $e');
      emit(state.copyWith(
        isCreatingPost: false,
        error: 'Failed to create post: ${e.toString()}',
      ));
    }
  }

  Future<void> _onCreatePoll(CreatePoll event, Emitter<CommunityState> emit) async {
    try {
      await _service.createPoll(
        postId: event.postId,
        question: event.question,
        options: event.options,
        allowMultipleVotes: event.allowMultipleVotes,
        endsAt: event.endsAt,
        isAnonymous: event.isAnonymous,
      );

      emit(state.copyWith(successMessage: 'Poll created successfully!'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onVoteOnPoll(VoteOnPoll event, Emitter<CommunityState> emit) async {
    try {
      print('🗳️ Voting on poll: ${event.pollId}, option: ${event.optionId}');

      await _service.voteOnPoll(event.pollId, event.optionId);

      print('✅ Vote submitted successfully');

      // Reload poll to get updated data
      add(LoadPoll(event.pollId));

      // Show success message
      emit(state.copyWith(successMessage: 'Vote recorded!'));

    } catch (e) {
      print('❌ Error voting on poll: $e');
      emit(state.copyWith(error: 'Failed to vote: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePoll(UpdatePoll event, Emitter<CommunityState> emit) async {
    try {
      await _service.updatePoll(
        pollId: event.pollId,
        question: event.question,
        options: event.options,
        endsAt: event.endsAt,
      );

      emit(state.copyWith(successMessage: 'Poll updated successfully!'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeletePoll(DeletePoll event, Emitter<CommunityState> emit) async {
    try {
      await _service.deletePoll(event.pollId, event.postId);

      // Remove from local state
      final updatedPolls = Map<String, Poll>.from(state.polls);
      updatedPolls.remove(event.pollId);

      emit(state.copyWith(
        polls: updatedPolls,
        successMessage: 'Poll deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadPoll(LoadPoll event, Emitter<CommunityState> emit) async {
    try {
      print('📊 Loading poll: ${event.pollId}');

      await emit.forEach(
        _service.getPoll(event.pollId),
        onData: (poll) {
          if (poll != null) {
            print('✅ Poll loaded: ${poll.question} (${poll.totalVotes} votes)');
            final updatedPolls = Map<String, Poll>.from(state.polls);
            updatedPolls[poll.id] = poll;
            return state.copyWith(polls: updatedPolls);
          } else {
            print('⚠️ Poll not found: ${event.pollId}');
          }
          return state;
        },
        onError: (error, stackTrace) {
          print('❌ Error loading poll: $error');
          return state.copyWith(error: 'Failed to load poll: $error');
        },
      );
    } catch (e) {
      print('❌ Exception loading poll: $e');
      emit(state.copyWith(error: 'Failed to load poll: ${e.toString()}'));
    }
  }

  // Post Handlers
  Future<void> _onLoadFeed(LoadFeed event, Emitter<CommunityState> emit) async {
    try {
      // Refresh authentication before loading feed
      await _refreshAuth();

      emit(state.copyWith(
        isLoadingFeed: true,
        error: null,
        feedPosts: event.refresh ? [] : state.feedPosts,
      ));

      await emit.forEach(
        _service.getFeedPosts(organizationCode: event.organizationCode),
        onData: (posts) =>
            state.copyWith(
              feedPosts: posts,
              isLoadingFeed: false,
              hasMorePosts: posts.length >= 20,
            ),
        onError: (error, stackTrace) =>
            state.copyWith(
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

  Future<void> _onLoadMoreFeed(LoadMoreFeed event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onCreatePost(CreatePost event,
      Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      final postId = await _service.createPost(
        mediaFiles: event.mediaFiles,
        mediaTypes: event.mediaTypes,
        caption: event.caption,
        privacy: event.privacy,
      );

      // Update current user's post count in local state
      final updatedCurrentUser = state.currentUserProfile?.copyWith(
        postCount: state.currentUserProfile!.postCount + 1,
      );

      emit(state.copyWith(
        isCreatingPost: false,
        currentUserProfile: updatedCurrentUser,
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

  Future<void> _onUpdatePost(UpdatePost event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onDeletePost(DeletePost event,
      Emitter<CommunityState> emit) async {
    try {
      await _service.deletePost(event.postId);

      // Remove post from local state
      final updatedPosts = state.feedPosts
          .where((post) => post.id != event.postId)
          .toList();

      // Update current user's post count in local state
      final updatedCurrentUser = state.currentUserProfile?.copyWith(
        postCount: state.currentUserProfile!.postCount > 0
            ? state.currentUserProfile!.postCount - 1
            : 0,
      );

      emit(state.copyWith(
        feedPosts: updatedPosts,
        currentUserProfile: updatedCurrentUser,
        successMessage: 'Post deleted successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Updated toggle like handler to use default reaction
  Future<void> _onToggleLike(ToggleLike event,
      Emitter<CommunityState> emit) async {
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
  Future<void> _onAddReaction(AddReaction event,
      Emitter<CommunityState> emit) async {
    try {
      await _handleReaction(event.postId, event.reaction, emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Helper method to handle reactions
  Future<void> _handleReaction(String postId, String reaction,
      Emitter<CommunityState> emit) async {
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
              reactions[currentReaction] =
              List<String>.from(reactions[currentReaction]!)
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

  // Share post handlers
  Future<void> _onSharePost(SharePost event,
      Emitter<CommunityState> emit) async {
    try {
      emit(state.copyWith(isCreatingPost: true, error: null));

      await _service.sharePost(
        postId: event.postId,
        comment: event.comment,
        privacy: event.privacy,
      );

      emit(state.copyWith(
        isCreatingPost: false,
        successMessage: 'Post shared successfully!',
      ));

      // Reload feed to show the repost
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

  Future<void> _onExternalSharePost(ExternalSharePost event,
      Emitter<CommunityState> emit) async {
    try {
      await _service.externalSharePost(event.post);
      emit(state.copyWith(
        successMessage: 'Post shared!',
      ));
    } catch (e) {
      emit(state.copyWith(
        error: 'Failed to share post',
      ));
    }
  }

  // Comment Handlers
  Future<void> _onLoadComments(LoadComments event,
      Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getComments(event.postId),
        onData: (comments) {
          final updatedComments = Map<String, List<Comment>>.from(
              state.postComments);
          updatedComments[event.postId] = comments;
          return state.copyWith(postComments: updatedComments);
        },
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAddComment(AddComment event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onDeleteComment(DeleteComment event,
      Emitter<CommunityState> emit) async {
    try {
      await _service.deleteComment(
        commentId: event.commentId,
        postId: event.postId,
      );

      // Update the local state by removing the comment
      final updatedComments = Map<String, List<Comment>>.from(
          state.postComments);
      final postComments = updatedComments[event.postId] ?? [];

      // Remove the comment from the list
      final filteredComments = postComments.where((comment) =>
      comment.id != event.commentId).toList();
      updatedComments[event.postId] = filteredComments;

      // Update the post's comment count
      final updatedPosts = state.feedPosts.map((post) {
        if (post.id == event.postId) {
          return post.copyWith(
              commentCount: post.commentCount > 0 ? post.commentCount - 1 : 0);
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
  Future<void> _onLoadFriends(LoadFriends event,
      Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getFriends(status: FriendStatus.accepted),
        // Explicitly request accepted friends
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

  Future<void> _onLoadPendingRequests(LoadPendingRequests event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onSendFriendRequest(SendFriendRequest event,
      Emitter<CommunityState> emit) async {
    try {
      await _service.sendFriendRequest(event.friendId);

      emit(state.copyWith(successMessage: 'Friend request sent!'));

      // Refresh search results to update button states
      if (state.searchResults.isNotEmpty) {
        final lastQuery = state.searchResults.first
            .fullName; // This is a hack, you might want to store the last query
        add(SearchUsers(
          query: lastQuery,
          organizationCode: state.currentUserProfile?.organizationCode ?? '',
        ));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAcceptFriendRequest(AcceptFriendRequest event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onDeclineFriendRequest(DeclineFriendRequest event,
      Emitter<CommunityState> emit) async {
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

  Future<void> _onRemoveFriend(RemoveFriend event,
      Emitter<CommunityState> emit) async {
    try {
      print('DEBUG: Starting to remove friend: ${event.friendId}');

      // Show loading state (optional - you could add a loading flag to state)
      // emit(state.copyWith(isLoadingFriends: true));

      await _service.removeFriend(event.friendId);

      // Remove from local state immediately for better UX
      final updatedFriends = state.friends
          .where((friend) => friend.friendId != event.friendId)
          .toList();

      emit(state.copyWith(
        friends: updatedFriends,
        successMessage: 'Friend removed successfully',
        error: null, // Clear any previous errors
      ));

      print('DEBUG: Friend removed from local state. New count: ${updatedFriends
          .length}');

      // Reload friends list to ensure consistency
      add(LoadFriends());

      // Reload current user profile to update friend count
      if (_service.currentUserId != null) {
        add(LoadUserProfile(_service.currentUserId!));
      }
    } catch (e) {
      print('DEBUG: BLoC - Error removing friend: $e');

      emit(state.copyWith(
        error: 'Failed to remove friend. Please try again.',
        successMessage: null,
      ));

      // Reload friends list in case of error to ensure consistency
      add(LoadFriends());
    }
  }

  // User Handlers
  Future<void> _onSearchUsers(SearchUsers event,
      Emitter<CommunityState> emit) async {
    try {
      if (event.query.isEmpty) {
        emit(state.copyWith(searchResults: []));
        return;
      }

      final results = await _service.searchUsers(
          event.query, event.organizationCode);
      emit(state.copyWith(searchResults: results));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadUserProfile(LoadUserProfile event,
      Emitter<CommunityState> emit) async {
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
        fullName: event.fullName, // Add this parameter
        avatarFile: event.avatarFile,
        friendsListPrivacy: event.friendsListPrivacy,
        removeAvatar: event.removeAvatar,
      );

      emit(state.copyWith(successMessage: 'Profile updated successfully!'));

      // Reload current user profile to reflect changes
      if (_service.currentUserId != null) {
        add(LoadUserProfile(_service.currentUserId!));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onSyncFriendCount(SyncFriendCount event,
      Emitter<CommunityState> emit) async {
    try {
      await _service.syncFriendCount(event.userId);

      // Reload user profile to get updated count
      add(LoadUserProfile(event.userId));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to sync friend count: $e'));
    }
  }

  // Notification Handlers
  Future<void> _onLoadNotifications(LoadNotifications event,
      Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getNotifications(),
        onData: (notifications) {
          final unreadCount = notifications
              .where((n) => !n.isRead)
              .length;
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

  Future<void> _onMarkNotificationRead(MarkNotificationRead event,
      Emitter<CommunityState> emit) async {
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

      final unreadCount = updatedNotifications
          .where((n) => !n.isRead)
          .length;

      emit(state.copyWith(
        notifications: updatedNotifications,
        unreadNotificationCount: unreadCount,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onMarkAllNotificationsRead(MarkAllNotificationsRead event,
      Emitter<CommunityState> emit) async {
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

  // Add this method at the end of CommunityBloc class
  Future<void> _refreshAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        print('✅ BLoC: Auth token refreshed');
      }
    } catch (e) {
      print('❌ BLoC: Failed to refresh auth: $e');
    }
  }

  Future<void> _onReportPost(ReportPost event, Emitter<CommunityState> emit) async {
    try {
      await _service.reportPost(
        postId: event.postId,
        reason: event.reason,
        details: event.details,
      );

      emit(state.copyWith(
        successMessage: 'Post reported successfully',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadReportedPosts(LoadReportedPosts event, Emitter<CommunityState> emit) async {
    try {
      await emit.forEach(
        _service.getReportedPosts(event.organizationCode),
        onData: (reports) => state.copyWith(reportedPosts: reports),
        onError: (error, stackTrace) => state.copyWith(error: error.toString()),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onReviewReport(ReviewReport event, Emitter<CommunityState> emit) async {
    try {
      await _service.reviewReport(
        reportId: event.reportId,
        postId: event.postId,
        isValid: event.isValid,
        adminNotes: event.adminNotes,
      );

      emit(state.copyWith(
        successMessage: event.isValid
            ? 'Report marked as valid and post removed'
            : 'Report marked as invalid',
      ));

      // Reload reported posts
      final orgCode = state.currentUserProfile?.organizationCode ?? '';
      if (orgCode.isNotEmpty) {
        add(LoadReportedPosts(organizationCode: orgCode));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onAdminDeletePost(AdminDeletePost event, Emitter<CommunityState> emit) async {
    try {
      await _service.adminDeletePost(event.postId, event.reason);

      // Remove from local state
      final updatedPosts = state.feedPosts
          .where((post) => post.id != event.postId)
          .toList();

      emit(state.copyWith(
        feedPosts: updatedPosts,
        successMessage: 'Post deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}