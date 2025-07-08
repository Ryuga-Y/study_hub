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

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => _isLoading = true);

      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      final orgCode = userData['organizationCode'];
      if (orgCode == null) return;

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('students')
          .doc(user.uid)
          .collection('calendar_events')
          .get();

      Map<DateTime, List<CalendarEvent>> events = {};

      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        final event = CalendarEvent.fromMap(doc.id, data);

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
          }
        } else {
          final eventDate = DateTime(
            event.startTime.year,
            event.startTime.month,
            event.startTime.day,
          );
          events[eventDate] = events[eventDate] ?? [];
          events[eventDate]!.add(event);
        }
      }

      // Sort events by start time for each date
      events.forEach((date, eventList) {
        eventList.sort((a, b) => a.startTime.compareTo(b.startTime));
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
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _events[normalizedDay] ?? [];
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
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildViewSelector(),
          _buildDateNavigation(),
          Expanded(child: _buildCurrentView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickEventDialog(),
        backgroundColor: Colors.blue[600],
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
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
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[700]),
          onPressed: () => _showMoreOptions(),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[600]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.blue[600]),
                ),
                SizedBox(height: 10),
                Text(
                  'My Calendars',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          ...['Personal', 'Work', 'Family'].map((calendar) {
            final isEnabled = _enabledCalendars.contains(calendar.toLowerCase());
            return CheckboxListTile(
              title: Text(calendar),
              value: isEnabled,
              activeColor: _getCalendarColor(calendar.toLowerCase()),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _enabledCalendars.add(calendar.toLowerCase());
                  } else {
                    _enabledCalendars.remove(calendar.toLowerCase());
                  }
                });
              },
              secondary: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getCalendarColor(calendar.toLowerCase()),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {},
          ),
        ],
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
        title = 'Agenda';
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

    // Week headers
    final weekHeaders = Row(
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
    );

    // Add empty cells for days before the first day of the month
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }

    // Add day cells
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
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                Expanded(
                  child: Container(
                    width: double.infinity,
                    child: Column(
                      children: events.take(3).map((event) {
                        return Container(
                          width: double.infinity,
                          height: 16,
                          margin: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                          decoration: BoxDecoration(
                            color: event.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Center(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (events.length > 3)
                  Text(
                    '+${events.length - 3} more',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Group into weeks
    List<Widget> weeks = [weekHeaders];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      final weekWidgets = dayWidgets.skip(i).take(7).toList();
      while (weekWidgets.length < 7) {
        weekWidgets.add(Container());
      }

      weeks.add(
        Expanded(
          child: Row(
            children: weekWidgets.map((widget) => Expanded(child: widget)).toList(),
          ),
        ),
      );
    }

    return Column(children: weeks);
  }

  Widget _buildWeekView() {
    final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));

    return Column(
      children: [
        // Week header
        Container(
          height: 60,
          child: Row(
            children: [
              Container(width: 60), // Time column space
              ...weekDays.map((day) {
                final isToday = _isSameDay(day, DateTime.now());
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          _getDayName(day.weekday).substring(0, 3),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
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
                  fontSize: 24,
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
    final upcomingEvents = _getEventsForDateRange(
      DateTime.now(),
      DateTime.now().add(Duration(days: 30)),
    );

    if (upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No upcoming events',
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
              _showEditEventDialog(event);
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

  void _showQuickEventDialog() {
    showDialog(
      context: context,
      builder: (context) => QuickEventDialog(
        selectedDate: _selectedDate,
        onSave: (event) => _addEvent(event),
      ),
    );
  }

  void _showEditEventDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDialog(
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
        title: Text('Delete Event'),
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
        onEdit: () => _showEditEventDialog(event),
        onDelete: () => _showDeleteEventDialog(event),
      ),
    );
  }

  void _showSearchDialog() {
    // Implement search functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Events'),
        content: TextField(
          decoration: InputDecoration(hintText: 'Enter search term...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('Search')),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    // Implement more options
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

class QuickEventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(CalendarEvent) onSave;

  QuickEventDialog({required this.selectedDate, required this.onSave});

  @override
  _QuickEventDialogState createState() => _QuickEventDialogState();
}

class _QuickEventDialogState extends State<QuickEventDialog> {
  final _titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quick Add Event'),
      content: TextField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'Event title',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final event = CalendarEvent(
                id: '',
                title: _titleController.text,
                description: '',
                startTime: DateTime(
                  widget.selectedDate.year,
                  widget.selectedDate.month,
                  widget.selectedDate.day,
                  9,
                  0,
                ),
                endTime: DateTime(
                  widget.selectedDate.year,
                  widget.selectedDate.month,
                  widget.selectedDate.day,
                  10,
                  0,
                ),
                color: Colors.blue,
              );
              widget.onSave(event);
              Navigator.pop(context);
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}

class EventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarEvent? event;
  final Function(CalendarEvent) onSave;

  EventDialog({
    required this.selectedDate,
    this.event,
    required this.onSave,
  });

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now();
  Color _selectedColor = Colors.blue;
  String _selectedCalendar = 'personal';
  EventType _eventType = EventType.normal;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  int _reminderMinutes = 15;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.selectedDate;
    _endDate = widget.selectedDate;

    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _locationController.text = widget.event!.location;
      _startDate = widget.event!.startTime;
      _startTime = TimeOfDay.fromDateTime(widget.event!.startTime);
      _endDate = widget.event!.endTime;
      _endTime = TimeOfDay.fromDateTime(widget.event!.endTime);
      _selectedColor = widget.event!.color;
      _selectedCalendar = widget.event!.calendar;
      _eventType = widget.event!.eventType;
      _recurrenceType = widget.event!.recurrenceType;
      _reminderMinutes = widget.event!.reminderMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<EventType>(
              value: _eventType,
              decoration: InputDecoration(
                labelText: 'Event Type',
                border: OutlineInputBorder(),
              ),
              items: EventType.values.map((type) {
                String name = type.toString().split('.').last;
                return DropdownMenuItem(
                  value: type,
                  child: Text(name == 'allDay' ? 'All Day' : name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _eventType = value!),
            ),
            if (_eventType != EventType.allDay) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(Duration(days: 365)),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (time != null) {
                          setState(() => _startTime = time);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: DateTime.now().subtract(Duration(days: 365)),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (time != null) {
                          setState(() => _endTime = time);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            DropdownButtonFormField<RecurrenceType>(
              value: _recurrenceType,
              decoration: InputDecoration(
                labelText: 'Repeat',
                border: OutlineInputBorder(),
              ),
              items: RecurrenceType.values.map((type) {
                String name = type.toString().split('.').last;
                return DropdownMenuItem(
                  value: type,
                  child: Text(name == 'none' ? 'Does not repeat' : name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _recurrenceType = value!),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCalendar,
              decoration: InputDecoration(
                labelText: 'Calendar',
                border: OutlineInputBorder(),
              ),
              items: ['personal', 'work', 'family'].map((calendar) {
                return DropdownMenuItem(
                  value: calendar,
                  child: Text(calendar.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCalendar = value!),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _reminderMinutes,
              decoration: InputDecoration(
                labelText: 'Reminder',
                border: OutlineInputBorder(),
              ),
              items: [0, 5, 10, 15, 30, 60].map((minutes) {
                return DropdownMenuItem(
                  value: minutes,
                  child: Text(minutes == 0 ? 'No reminder' : '$minutes minutes before'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _reminderMinutes = value!),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text('Color: '),
                SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: _colors.map((color) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _selectedColor == color
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
              DateTime startDateTime, endDateTime;

              if (_eventType == EventType.allDay) {
                startDateTime = DateTime(_startDate.year, _startDate.month, _startDate.day);
                endDateTime = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59);
              } else {
                startDateTime = DateTime(
                  _startDate.year,
                  _startDate.month,
                  _startDate.day,
                  _startTime.hour,
                  _startTime.minute,
                );
                endDateTime = DateTime(
                  _endDate.year,
                  _endDate.month,
                  _endDate.day,
                  _endTime.hour,
                  _endTime.minute,
                );
              }

              final event = CalendarEvent(
                id: widget.event?.id ?? '',
                title: _titleController.text,
                description: _descriptionController.text,
                startTime: startDateTime,
                endTime: endDateTime,
                color: _selectedColor,
                calendar: _selectedCalendar,
                eventType: _eventType,
                recurrenceType: _recurrenceType,
                reminderMinutes: _reminderMinutes,
                location: _locationController.text,
              );

              widget.onSave(event);
              Navigator.pop(context);
            }
          },
          child: Text('Save'),
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
      title: Text(event.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.description.isNotEmpty) ...[
            Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(event.description),
            SizedBox(height: 16),
          ],
          Text('Time:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(event.eventType == EventType.allDay
              ? 'All day'
              : '${TimeOfDay.fromDateTime(event.startTime).format(context)} - ${TimeOfDay.fromDateTime(event.endTime).format(context)}'),
          SizedBox(height: 16),
          if (event.location.isNotEmpty) ...[
            Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(event.location),
            SizedBox(height: 16),
          ],
          Text('Calendar:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(event.calendar.toUpperCase()),
          if (event.recurrenceType != RecurrenceType.none) ...[
            SizedBox(height: 16),
            Text('Repeat:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(event.recurrenceType.toString().split('.').last.toUpperCase()),
          ],
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