import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'bloc.dart';
import 'edit_dialogs.dart';
import 'models.dart';

class PollWidget extends StatefulWidget {
  final String pollId;
  final String postId;
  final bool isPostOwner;

  const PollWidget({
    Key? key,
    required this.pollId,
    required this.postId,
    this.isPostOwner = false,
  }) : super(key: key);

  @override
  _PollWidgetState createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  @override
  void initState() {
    super.initState();
    // Load poll data when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityBloc>().add(LoadPoll(widget.pollId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityBloc, CommunityState>(
      listener: (context, state) {
        // Handle any errors or success messages related to poll operations
        if (state.error != null && state.error!.contains('poll')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state.successMessage != null && state.successMessage!.contains('Poll')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      builder: (context, state) {
        final poll = state.polls[widget.pollId];

        if (poll == null) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 8),
                  Text(
                    'Loading poll...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final currentUserId = state.currentUserProfile?.uid;
        final hasVoted = currentUserId != null && poll.hasVoted(currentUserId);
        final userVote = currentUserId != null ? poll.getUserVote(currentUserId) : null;
        final totalVotes = poll.totalVotes;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poll header
              Row(
                children: [
                  Icon(Icons.poll, color: Colors.purple[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      poll.question,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isPostOwner)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit Poll'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Poll', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEnhancedEditPollDialog(context, poll);
                        } else if (value == 'delete') {
                          _showDeletePollDialog(context, poll);
                        }
                      },
                    )
                ],
              ),

              SizedBox(height: 16),

              // Poll options
              ...poll.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final percentage = totalVotes > 0
                    ? (option.voteCount / totalVotes * 100).round()
                    : 0;
                final isSelected = userVote == option.id;

                if (hasVoted || !poll.isActive) {
                  // Show results
                  return _buildResultOption(
                    option,
                    percentage,
                    isSelected,
                    index == poll.options.length - 1,
                  );
                } else {
                  // Show voting options
                  return _buildVotingOption(
                    poll,
                    option,
                    index == poll.options.length - 1,
                  );
                }
              }).toList(),

              SizedBox(height: 12),

              // Poll footer
              Row(
                children: [
                  Icon(Icons.how_to_vote, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (!poll.isAnonymous && totalVotes > 0) ...[
                    SizedBox(width: 16),
                    InkWell(
                      onTap: () => _showVoters(context, poll),
                      child: Text(
                        'View details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  if (poll.endsAt != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: poll.isActive ? Colors.orange[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        poll.isActive
                            ? 'Ends ${_formatEndTime(poll.endsAt!)}'
                            : 'Ended',
                        style: TextStyle(
                          fontSize: 11,
                          color: poll.isActive ? Colors.orange[700] : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultOption(
      PollOption option,
      int percentage,
      bool isSelected,
      bool isLast,
      ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
              SizedBox(width: 8),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.purple[700] : Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          LinearPercentIndicator(
            lineHeight: 8,
            percent: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            progressColor: isSelected ? Colors.purple[600] : Colors.purple[300],
            barRadius: Radius.circular(4),
            padding: EdgeInsets.zero,
          ),
          SizedBox(height: 4),
          Text(
            '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingOption(
      Poll poll,
      PollOption option,
      bool isLast,
      ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: poll.isActive ? () => _voteOnOption(poll, option) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked,
                  size: 20,
                  color: poll.isActive ? Colors.purple[600] : Colors.grey[400],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: poll.isActive ? Colors.black87 : Colors.grey[500],
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

  void _voteOnOption(Poll poll, PollOption option) {
    // Show loading state briefly
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Recording your vote...'),
          ],
        ),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.purple[600],
      ),
    );

    // Submit vote
    context.read<CommunityBloc>().add(
      VoteOnPoll(pollId: poll.id, optionId: option.id),
    );
  }

  String _formatEndTime(DateTime endTime) {
    final now = DateTime.now();
    final difference = endTime.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'soon';
    }
  }

  void _showVoters(BuildContext context, Poll poll) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),

            Text(
              'Poll Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              poll.question,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: poll.options.length,
                itemBuilder: (context, index) {
                  final option = poll.options[index];
                  final percentage = poll.totalVotes > 0
                      ? (option.voteCount / poll.totalVotes * 100).round()
                      : 0;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$percentage%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          LinearPercentIndicator(
                            lineHeight: 6,
                            percent: (percentage / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            progressColor: Colors.purple[400],
                            barRadius: Radius.circular(3),
                            padding: EdgeInsets.zero,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Close button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnhancedEditPollDialog(BuildContext context, Poll poll) {
    showDialog(
      context: context,
      builder: (context) => EnhancedEditPollDialog(poll: poll),
    );
  }

  void _showDeletePollDialog(BuildContext context, Poll poll) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Poll'),
        content: Text(
          'Are you sure you want to delete this poll? This action cannot be undone and all votes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CommunityBloc>().add(
                DeletePoll(pollId: poll.id, postId: poll.postId),
              );
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Poll creation widget for the create post modal
class CreatePollWidget extends StatefulWidget {
  final Function(String question, List<String> options, DateTime? endsAt, bool isAnonymous) onPollCreated;
  final VoidCallback onCancel;

  const CreatePollWidget({
    Key? key,
    required this.onPollCreated,
    required this.onCancel,
  }) : super(key: key);

  @override
  _CreatePollWidgetState createState() => _CreatePollWidgetState();
}

class _CreatePollWidgetState extends State<CreatePollWidget> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _endsAt;
  bool _isAnonymous = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
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

  bool _canCreatePoll() {
    if (_questionController.text.trim().isEmpty) return false;

    int validOptions = 0;
    for (final controller in _optionControllers) {
      if (controller.text.trim().isNotEmpty) validOptions++;
    }

    return validOptions >= 2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll, color: Colors.purple[600]),
              SizedBox(width: 8),
              Text(
                'Create Poll',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: widget.onCancel,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Question input
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: 'Poll Question',
              hintText: 'What would you like to ask?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),

          SizedBox(height: 16),

          // Options
          Text(
            'Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),

          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _optionControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
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

          if (_optionControllers.length < 6)
            TextButton.icon(
              onPressed: _addOption,
              icon: Icon(Icons.add),
              label: Text('Add Option'),
            ),

          SizedBox(height: 16),

          // Settings
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(Duration(days: 7)),
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
                          _endsAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 20, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _endsAt != null
                                ? 'Ends ${_endsAt!.toLocal()}'.split('.')[0]
                                : 'Set End Time',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAnonymous,
                      onChanged: (value) {
                        setState(() => _isAnonymous = value ?? false);
                      },
                    ),
                    Text('Anonymous', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canCreatePoll() ? () {
                final options = _optionControllers
                    .map((controller) => controller.text.trim())
                    .where((text) => text.isNotEmpty)
                    .toList();

                widget.onPollCreated(
                  _questionController.text.trim(),
                  options,
                  _endsAt,
                  _isAnonymous,
                );
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Create Poll', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}