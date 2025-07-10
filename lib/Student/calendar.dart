import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';

enum CalendarView { month, week, day, agenda }
enum EventType { normal, allDay, recurring }
enum RecurrenceType { none, daily, weekly, monthly, yearly }

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final AuthService _authService = AuthService();
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  CalendarView _currentView = CalendarView.month;
  Map<DateTime, List<CalendarEvent>> _events = {};
  List<String> _enabledCalendars = ['personal', 'work', 'family'];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<CalendarEvent> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => _isLoading = true);

      final user = _authService.currentUser;
      if (user == null) {
        print('No user found');
        return;
      }

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        print('No user data found');
        return;
      }

      final orgCode = userData['organizationCode'];
      if (orgCode == null) {
        print('No organization code found');
        return;
      }

      print('Loading events for user: ${user.uid}, org: $orgCode');

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .get();

      print('Found ${eventsSnapshot.docs.length} event documents');

      Map<DateTime, List<CalendarEvent>> events = {};

      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        print('Processing event document: ${doc.id}');
        print('Event data: $data');

        try {
          final event = CalendarEvent.fromMap(doc.id, data);
          print('Created event: ${event.title} for ${event.startTime}');

          // Handle recurring events
          if (event.recurrenceType != RecurrenceType.none) {
            final recurringEvents = _generateRecurringEvents(event);
            for (var recurringEvent in recurringEvents) {
              final eventDate = DateTime(
                recurringEvent.startTime.year,
                recurringEvent.startTime.month,
                recurringEvent.startTime.day,
              );
              events[eventDate] = events[eventDate] ?? [];
              events[eventDate]!.add(recurringEvent);
              print('Added recurring event for date: $eventDate');
            }
          } else {
            // IMPORTANT: Normalize the date properly
            final eventDate = DateTime(
              event.startTime.year,
              event.startTime.month,
              event.startTime.day,
            );
            events[eventDate] = events[eventDate] ?? [];
            events[eventDate]!.add(event);
            print('Added event for date: $eventDate');
          }
        } catch (e) {
          print('Error processing event ${doc.id}: $e');
        }
      }

      // Sort events by start time for each date
      events.forEach((date, eventList) {
        eventList.sort((a, b) => a.startTime.compareTo(b.startTime));
      });

      print('Final events map has ${events.length} dates');
      events.forEach((date, eventList) {
        print('Date $date has ${eventList.length} events');
      });

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchEvents(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    List<CalendarEvent> results = [];
    final lowerQuery = query.toLowerCase();

    // Search through all events
    _events.forEach((date, eventList) {
      for (var event in eventList) {
        if (event.title.toLowerCase().contains(lowerQuery) ||
            event.description.toLowerCase().contains(lowerQuery) ||
            event.location.toLowerCase().contains(lowerQuery)) {
          results.add(event);
        }
      }
    });

    // Sort results by date (upcoming first)
    results.sort((a, b) => a.startTime.compareTo(b.startTime));

    setState(() {
      _searchResults = results;
    });
  }

  List<CalendarEvent> _generateRecurringEvents(CalendarEvent event) {
    List<CalendarEvent> events = [];
    DateTime current = event.startTime;
    final endDate = DateTime.now().add(Duration(days: 365)); // Generate for next year

    while (current.isBefore(endDate)) {
      events.add(CalendarEvent(
        id: '${event.id}_${current.millisecondsSinceEpoch}',
        title: event.title,
        description: event.description,
        startTime: current,
        endTime: current.add(event.endTime.difference(event.startTime)),
        color: event.color,
        calendar: event.calendar,
        eventType: event.eventType,
        recurrenceType: event.recurrenceType,
        reminderMinutes: event.reminderMinutes,
        location: event.location,
        isRecurring: true,
        originalEventId: event.id,
      ));

      switch (event.recurrenceType) {
        case RecurrenceType.daily:
          current = current.add(Duration(days: 1));
          break;
        case RecurrenceType.weekly:
          current = current.add(Duration(days: 7));
          break;
        case RecurrenceType.monthly:
          current = DateTime(current.year, current.month + 1, current.day);
          break;
        case RecurrenceType.yearly:
          current = DateTime(current.year + 1, current.month, current.day);
          break;
        default:
          break;
      }
    }

    return events;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // Normalize the day to remove time component
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _events[normalizedDay] ?? [];

    // Debug print to check if events are being found
    print('Getting events for $normalizedDay: found ${events.length} events');
    if (events.isNotEmpty) {
      for (var event in events) {
        print('  - Event: ${event.title} at ${event.startTime}');
      }
    }

    return events.where((event) => _enabledCalendars.contains(event.calendar)).toList();
  }

  List<CalendarEvent> _getEventsForDateRange(DateTime start, DateTime end) {
    List<CalendarEvent> events = [];
    DateTime current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      events.addAll(_getEventsForDay(current));
      current = current.add(Duration(days: 1));
    }

    return events;
  }

  Future<void> _addEvent(CalendarEvent event) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .add(event.toMap());

      _loadEvents();
    } catch (e) {
      print('Error adding event: $e');
    }
  }

  Future<void> _updateEvent(CalendarEvent event) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      String eventId = event.isRecurring ? event.originalEventId : event.id;

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .doc(eventId)
          .update(event.toMap());

      _loadEvents();
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .doc(eventId)
          .delete();

      _loadEvents();
    } catch (e) {
      print('Error deleting event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching) _buildSearchResults(),
          if (!_isSearching) ...[
            _buildViewSelector(),
            _buildDateNavigation(),
            Expanded(child: _buildCurrentView()),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        backgroundColor: Colors.blue[600],
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.blue[600],
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'Calendar',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 22,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: Colors.grey[700]),
          onPressed: () => _showSearchDialog(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _searchEvents,
                    autofocus: true,
                  ),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                    _searchController.clear();
                  },
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Type to search notes'
                        : 'No notes found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _buildSearchResultCard(_searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(CalendarEvent event) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getMonthName(event.startTime.month)} ${event.startTime.day}, ${event.startTime.year}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (event.description.isNotEmpty)
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: CalendarView.values.map((view) {
          final isSelected = _currentView == view;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentView = view),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    view.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.blue[600] : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateNavigation() {
    String title;
    switch (_currentView) {
      case CalendarView.month:
        title = '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}';
        break;
      case CalendarView.week:
        final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
        final weekEnd = weekStart.add(Duration(days: 6));
        title = '${_getMonthName(weekStart.month)} ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
        break;
      case CalendarView.day:
        title = '${_getDayName(_focusedDate.weekday)}, ${_getMonthName(_focusedDate.month)} ${_focusedDate.day}';
        break;
      case CalendarView.agenda:
        title = 'Agenda (Next 2 Weeks)';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () => _navigateDate(-1),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _showDatePicker(),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () => _navigateDate(1),
          ),
          TextButton(
            onPressed: () => setState(() {
              _focusedDate = DateTime.now();
              _selectedDate = DateTime.now();
            }),
            child: Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case CalendarView.month:
        return _buildMonthView();
      case CalendarView.week:
        return _buildWeekView();
      case CalendarView.day:
        return _buildDayView();
      case CalendarView.agenda:
        return _buildAgendaView();
    }
  }

  Widget _buildMonthView() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }

    // Add all days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedDate.year, _focusedDate.month, day);
      final events = _getEventsForDay(date);
      final isToday = _isSameDay(date, DateTime.now());
      final isSelected = _isSameDay(date, _selectedDate);

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
              if (_currentView == CalendarView.month) {
                _currentView = CalendarView.day;
              }
            });
          },
          child: Container(
            margin: EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[100] : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Day number - Fixed height
                Container(
                  width: 32,
                  height: 32,
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue[600] : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isToday ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                // Events section with fixed constraints
                if (events.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 40, // Fixed height to prevent overflow
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        SizedBox(height: 2),
                        // Show up to 2 events to fit in the fixed space
                        ...events.take(2).map((event) {
                          return Container(
                            width: double.infinity,
                            height: 12,
                            margin: EdgeInsets.only(bottom: 1),
                            decoration: BoxDecoration(
                              color: event.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                event.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          );
                        }).toList(),
                        // Show more indicator if there are more than 2 events
                        if (events.length > 2)
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              '+${events.length - 2} more',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // Fixed spacer for days without events
                if (events.isEmpty)
                  SizedBox(height: 44), // Day number (36) + events space (40) + margin (8)
              ],
            ),
          ),
        ),
      );
    }

    // Fill remaining empty cells to complete the last week
    while (dayWidgets.length % 7 != 0) {
      dayWidgets.add(Container());
    }

    // Create weeks with fixed heights
    List<Widget> weeks = [];

    // Week headers
    weeks.add(
      Container(
        height: 40,
        child: Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ))
              .toList(),
        ),
      ),
    );

    // Calculate number of weeks and fixed height for each week
    final numberOfWeeks = (dayWidgets.length / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerHeight = 40.0;
        final availableHeight = constraints.maxHeight - headerHeight;
        final weekHeight = availableHeight / numberOfWeeks;

        // Create week rows
        for (int i = 0; i < dayWidgets.length; i += 7) {
          final weekWidgets = dayWidgets.skip(i).take(7).toList();

          weeks.add(
            Container(
              height: weekHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align to top to prevent overflow
                children: weekWidgets.map((widget) => Expanded(child: widget)).toList(),
              ),
            ),
          );
        }

        return Column(
          children: weeks,
        );
      },
    );
  }

  Widget _buildWeekView() {
    final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));

    return Column(
      children: [
        // Week header with fixed height and proper constraints
        Container(
          height: 70, // Increased height to prevent overflow
          child: Row(
            children: [
              Container(width: 60), // Time column space
              ...weekDays.map((day) {
                final isToday = _isSameDay(day, DateTime.now());
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Use minimum space needed
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayName(day.weekday).substring(0, 3),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4), // Fixed spacing
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isToday ? Colors.blue[600] : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isToday ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        // Time slots
        Expanded(
          child: SingleChildScrollView(
            child: _buildTimeSlots(weekDays),
          ),
        ),
      ],
    );
  }

  Widget _buildDayView() {
    return Column(
      children: [
        // Day header
        Container(
          height: 60,
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                _getDayName(_selectedDate.weekday),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${_selectedDate.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        // Time slots
        Expanded(
          child: SingleChildScrollView(
            child: _buildTimeSlots([_selectedDate]),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots(List<DateTime> days) {
    return Column(
      children: List.generate(24, (hour) {
        return Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                padding: EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              ...days.map((day) {
                final dayEvents = _getEventsForDay(day)
                    .where((event) => event.startTime.hour == hour)
                    .toList();

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Stack(
                      children: dayEvents.map((event) {
                        return Positioned(
                          left: 2,
                          right: 2,
                          top: (event.startTime.minute / 60) * 60,
                          height: (event.endTime.difference(event.startTime).inMinutes / 60) * 60,
                          child: GestureDetector(
                            onTap: () => _showEventDetails(event),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: event.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                event.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAgendaView() {
    // Show events for next 2 weeks
    final upcomingEvents = _getEventsForDateRange(
      DateTime.now(),
      DateTime.now().add(Duration(days: 14)), // 2 weeks
    );

    if (upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No upcoming notes in the next 2 weeks',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Group events by date
    Map<DateTime, List<CalendarEvent>> groupedEvents = {};
    for (var event in upcomingEvents) {
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      groupedEvents[eventDate] = groupedEvents[eventDate] ?? [];
      groupedEvents[eventDate]!.add(event);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final date = groupedEvents.keys.elementAt(index);
        final events = groupedEvents[date]!;
        final isToday = _isSameDay(date, DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                isToday
                    ? 'Today, ${_getMonthName(date.month)} ${date.day}'
                    : '${_getDayName(date.weekday)}, ${_getMonthName(date.month)} ${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.blue[600] : Colors.grey[800],
                ),
              ),
            ),
            ...events.map((event) => _buildAgendaEventCard(event)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildAgendaEventCard(CalendarEvent event) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.eventType == EventType.allDay)
              Text('All day')
            else
              Text('${TimeOfDay.fromDateTime(event.startTime).format(context)} - ${TimeOfDay.fromDateTime(event.endTime).format(context)}'),
            if (event.location.isNotEmpty)
              Text('📍 ${event.location}'),
            if (event.description.isNotEmpty)
              Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: PopupMenuButton(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditNoteDialog(event);
            } else if (value == 'delete') {
              _showDeleteEventDialog(event);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  void _navigateDate(int direction) {
    setState(() {
      switch (_currentView) {
        case CalendarView.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + direction, 1);
          break;
        case CalendarView.week:
          _focusedDate = _focusedDate.add(Duration(days: 7 * direction));
          break;
        case CalendarView.day:
          _focusedDate = _focusedDate.add(Duration(days: direction));
          _selectedDate = _focusedDate;
          break;
        case CalendarView.agenda:
        // No navigation for agenda view
          break;
      }
    });
  }

  void _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _focusedDate = date;
        _selectedDate = date;
      });
    }
  }

  void _showNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => NoteDialog(
        selectedDate: _selectedDate,
        onSave: (event) => _addEvent(event),
      ),
    );
  }

  void _showEditNoteDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => NoteDialog(
        selectedDate: _selectedDate,
        event: event,
        onSave: (updatedEvent) => _updateEvent(updatedEvent),
      ),
    );
  }

  void _showDeleteEventDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Note'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              String eventId = event.isRecurring ? event.originalEventId : event.id;
              _deleteEvent(eventId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(
        event: event,
        onEdit: () => _showEditNoteDialog(event),
        onDelete: () => _showDeleteEventDialog(event),
      ),
    );
  }

  void _showSearchDialog() {
    setState(() {
      _isSearching = true;
    });
  }

  Color _getCalendarColor(String calendar) {
    switch (calendar) {
      case 'personal':
        return Colors.blue;
      case 'work':
        return Colors.orange;
      case 'family':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final String calendar;
  final EventType eventType;
  final RecurrenceType recurrenceType;
  final int reminderMinutes;
  final String location;
  final bool isRecurring;
  final String originalEventId;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.calendar = 'personal',
    this.eventType = EventType.normal,
    this.recurrenceType = RecurrenceType.none,
    this.reminderMinutes = 15,
    this.location = '',
    this.isRecurring = false,
    this.originalEventId = '',
  });

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> map) {
    return CalendarEvent(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      color: Color(map['color'] ?? Colors.blue.value),
      calendar: map['calendar'] ?? 'personal',
      eventType: EventType.values[map['eventType'] ?? 0],
      recurrenceType: RecurrenceType.values[map['recurrenceType'] ?? 0],
      reminderMinutes: map['reminderMinutes'] ?? 15,
      location: map['location'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      originalEventId: map['originalEventId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'color': color.value,
      'calendar': calendar,
      'eventType': eventType.index,
      'recurrenceType': recurrenceType.index,
      'reminderMinutes': reminderMinutes,
      'location': location,
      'isRecurring': isRecurring,
      'originalEventId': originalEventId,
    };
  }
}

class NoteDialog extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarEvent? event;
  final Function(CalendarEvent) onSave;

  NoteDialog({
    required this.selectedDate,
    this.event,
    required this.onSave,
  });

  @override
  _NoteDialogState createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Color _selectedColor = Colors.blue;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;

    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _selectedDate = widget.event!.startTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.startTime);
      _selectedColor = widget.event!.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add Note' : 'Edit Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Note Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.title),
              ),
              autofocus: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Note Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(Duration(days: 365)),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_selectedTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Choose Color:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: _selectedColor == color
                        ? Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final startDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );

              final endDateTime = startDateTime.add(Duration(hours: 1));

              final event = CalendarEvent(
                id: widget.event?.id ?? '',
                title: _titleController.text,
                description: _descriptionController.text,
                startTime: startDateTime,
                endTime: endDateTime,
                color: _selectedColor,
                calendar: 'personal',
                eventType: EventType.normal,
                recurrenceType: RecurrenceType.none,
                reminderMinutes: 15,
                location: '',
              );

              widget.onSave(event);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
          ),
          child: Text(
            'Save Note',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class EventDetailsDialog extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  EventDetailsDialog({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.description.isNotEmpty) ...[
            Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(event.description),
            SizedBox(height: 16),
          ],
          Text('Date & Time:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '${event.startTime.day}/${event.startTime.month}/${event.startTime.year} at ${TimeOfDay.fromDateTime(event.startTime).format(context)}',
          ),
          SizedBox(height: 16),
          Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: event.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onEdit();
          },
          child: Text('Edit'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}