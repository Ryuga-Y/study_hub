import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'bloc.dart';
import 'models.dart';
import 'media_picker.dart';

// Enhanced Post Edit Dialog
class EnhancedEditPostDialog extends StatefulWidget {
  final Post post;

  const EnhancedEditPostDialog({Key? key, required this.post}) : super(key: key);

  @override
  _EnhancedEditPostDialogState createState() => _EnhancedEditPostDialogState();
}

class _EnhancedEditPostDialogState extends State<EnhancedEditPostDialog> {
  late TextEditingController _captionController;
  late PostPrivacy _selectedPrivacy;
  List<String> _keepExistingMedia = [];
  List<File> _newMediaFiles = [];
  List<MediaType> _newMediaTypes = [];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post.caption);
    _selectedPrivacy = widget.post.privacy;
    // Initially keep all existing media
    _keepExistingMedia = List.from(widget.post.mediaUrls);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Text(
                    'Edit Post',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption
                    TextField(
                      controller: _captionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Caption',
                        hintText: 'Write a caption...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Privacy
                    DropdownButtonFormField<PostPrivacy>(
                      value: _selectedPrivacy,
                      decoration: InputDecoration(
                        labelText: 'Privacy',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: PostPrivacy.values.map((privacy) {
                        return DropdownMenuItem(
                          value: privacy,
                          child: Row(
                            children: [
                              Icon(
                                privacy == PostPrivacy.public
                                    ? Icons.public
                                    : privacy == PostPrivacy.friendsOnly
                                    ? Icons.people
                                    : Icons.lock,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(privacy == PostPrivacy.public
                                  ? 'Public'
                                  : privacy == PostPrivacy.friendsOnly
                                  ? 'Friends Only'
                                  : 'Private'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPrivacy = value);
                        }
                      },
                    ),

                    SizedBox(height: 24),

                    // Existing Media Section
                    if (widget.post.mediaUrls.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'Current Media',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_keepExistingMedia.length == widget.post.mediaUrls.length) {
                                  _keepExistingMedia.clear();
                                } else {
                                  _keepExistingMedia = List.from(widget.post.mediaUrls);
                                }
                              });
                            },
                            child: Text(
                              _keepExistingMedia.length == widget.post.mediaUrls.length
                                  ? 'Remove All'
                                  : 'Keep All',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildExistingMediaGrid(),
                      SizedBox(height: 24),
                    ],

                    // New Media Section
                    Text(
                      'Add New Media',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    MediaPicker(
                      selectedMedia: _newMediaFiles,
                      mediaTypes: _newMediaTypes,
                      onMediaSelected: (files, types) {
                        setState(() {
                          _newMediaFiles = files;
                          _newMediaTypes = types;
                        });
                      },
                      maxMedia: 10 - _keepExistingMedia.length,
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: BlocBuilder<CommunityBloc, CommunityState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state.isCreatingPost ? null : _updatePost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[600],
                          ),
                          child: state.isCreatingPost
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Text('Update', style: TextStyle(color: Colors.white)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.post.mediaUrls.length,
      itemBuilder: (context, index) {
        final mediaUrl = widget.post.mediaUrls[index];
        final isSelected = _keepExistingMedia.contains(mediaUrl);
        final mediaType = index < widget.post.mediaTypes.length
            ? widget.post.mediaTypes[index]
            : MediaType.image;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _keepExistingMedia.remove(mediaUrl);
              } else {
                _keepExistingMedia.add(mediaUrl);
              }
            });
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (mediaType == MediaType.video)
                          Container(
                            color: Colors.black,
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          )
                        else
                          CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        if (!isSelected)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Center(
                              child: Icon(
                                Icons.remove_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _updatePost() {
    context.read<CommunityBloc>().add(UpdatePostWithMedia(
      postId: widget.post.id,
      caption: _captionController.text,
      privacy: _selectedPrivacy,
      newMediaFiles: _newMediaFiles.isNotEmpty ? _newMediaFiles : null,
      newMediaTypes: _newMediaTypes.isNotEmpty ? _newMediaTypes : null,
      keepExistingMediaUrls: _keepExistingMedia.isNotEmpty ? _keepExistingMedia : null,
    ));
    Navigator.pop(context);
  }
}

// Enhanced Poll Edit Dialog
class EnhancedEditPollDialog extends StatefulWidget {
  final Poll poll;

  const EnhancedEditPollDialog({Key? key, required this.poll}) : super(key: key);

  @override
  _EnhancedEditPollDialogState createState() => _EnhancedEditPollDialogState();
}

class _EnhancedEditPollDialogState extends State<EnhancedEditPollDialog> {
  late TextEditingController _questionController;
  late List<TextEditingController> _optionControllers;
  DateTime? _selectedEndDate;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.poll.question);
    _selectedEndDate = widget.poll.endsAt;
    _isAnonymous = widget.poll.isAnonymous;

    // Initialize option controllers
    _optionControllers = widget.poll.options
        .map((option) => TextEditingController(text: option.text))
        .toList();

    // Ensure we have at least 2 options
    while (_optionControllers.length < 2) {
      _optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Icon(Icons.poll, color: Colors.purple[600]),
                  SizedBox(width: 8),
                  Text(
                    'Edit Poll',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Warning about votes
            if (widget.poll.totalVotes > 0)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing options will reset all votes (${widget.poll.totalVotes} votes will be lost)',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poll Question
                    TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        labelText: 'Poll Question',
                        hintText: 'What would you like to ask?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),

                    SizedBox(height: 24),

                    // Options Section
                    Row(
                      children: [
                        Text(
                          'Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        if (_optionControllers.length < 6)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: Icon(Icons.add, size: 18),
                            label: Text('Add Option'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.purple[600],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8),

                    // Option inputs
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _optionControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _optionControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                    hintText: 'Enter option text',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              if (_optionControllers.length > 2)
                                IconButton(
                                  icon: Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeOption(index),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 24),

                    // Poll Settings
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),

                    // End Date
                    InkWell(
                      onTap: _selectEndDate,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.grey[600]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedEndDate != null
                                    ? 'Ends: ${_formatDate(_selectedEndDate!)}'
                                    : 'Set End Date (Optional)',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            if (_selectedEndDate != null)
                              IconButton(
                                icon: Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _selectedEndDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    // Anonymous Voting
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        title: Text('Anonymous Voting'),
                        subtitle: Text('Hide voter identities'),
                        value: _isAnonymous,
                        onChanged: (value) {
                          setState(() => _isAnonymous = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canUpdatePoll() ? _updatePoll : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                      ),
                      child: Text('Update Poll', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  bool _canUpdatePoll() {
    if (_questionController.text.trim().isEmpty) return false;

    final validOptions = _optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;

    return validOptions >= 2;
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now().add(Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedEndDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _updatePoll() {
    final optionTexts = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    context.read<CommunityBloc>().add(UpdatePollWithOptions(
      pollId: widget.poll.id,
      question: _questionController.text.trim(),
      optionTexts: optionTexts,
      endsAt: _selectedEndDate,
      isAnonymous: _isAnonymous,
    ));

    Navigator.pop(context);
  }
}