import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const HabitFlowApp());
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String _habitChannelId = 'habitflow_habits';
  static const String _scheduleChannelId = 'habitflow_schedule';

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _habitChannelId,
          'Habit reminders',
          description: 'Daily reminder notifications for habits',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _scheduleChannelId,
          'Schedule reminders',
          description: 'Reminders for timetable events',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      if (Platform.isAndroid) {
        await androidPlugin.requestNotificationsPermission();
      }
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> scheduleHabitReminder(HabitItem habit) async {
    if (!habit.notificationEnabled) {
      await _plugin.cancel(_notificationId('habit', habit.id));
      return;
    }

    final reminderTime = _parseTime(habit.reminderTime);
    final nextDate = _nextDailyDate(reminderTime);
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _habitChannelId,
        'Habit reminders',
        channelDescription: 'Reminder notifications for habits',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.zonedSchedule(
      _notificationId('habit', habit.id),
      'Habit reminder',
      habit.title,
      tz.TZDateTime.from(nextDate, tz.local),
      details,
      // REQUIRED: Specifies how the notification is scheduled on Android
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleScheduleReminder(ScheduleItem item) async {
    if (!item.notificationEnabled) {
      await _plugin.cancel(_notificationId('schedule', item.id));
      return;
    }

    final reminderTime = _parseTime(item.time);
    final nextDate = _nextWeekdayDate(item.day, reminderTime);
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _scheduleChannelId,
        'Schedule reminders',
        channelDescription: 'Reminder notifications for timetable events',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.zonedSchedule(
      _notificationId('schedule', item.id),
      'Upcoming event',
      item.title,
      tz.TZDateTime.from(nextDate, tz.local),
      details,
      // REQUIRED: Specifies how the notification is scheduled on Android
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static int _notificationId(String prefix, String id) {
    return '$prefix:$id'.hashCode;
  }

  static DateTime _nextDailyDate(TimeOfDay time) {
    final now = DateTime.now();
    var candidate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static DateTime _nextWeekdayDate(String dayName, TimeOfDay time) {
    final weekdayMap = {
      'Mon': 1,
      'Tue': 2,
      'Wed': 3,
      'Thu': 4,
      'Fri': 5,
      'Sat': 6,
      'Sun': 7,
    };

    final targetWeekday = weekdayMap[dayName] ?? DateTime.now().weekday;
    final now = DateTime.now();
    var candidate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    while (candidate.weekday != targetWeekday || !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}

class HabitFlowApp extends StatelessWidget {
  const HabitFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabitFlow AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7FF),
          foregroundColor: Color(0xFF2A214F),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F1FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        chipTheme: const ChipThemeData(
          side: BorderSide.none,
          shape: StadiumBorder(),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF6C63FF).withOpacity(0.16),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<HabitItem> _habits = [];
  final List<ScheduleItem> _scheduleItems = [];
  final List<JournalEntry> _journalEntries = [];
  final List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  int _selectedIndex = 0;
  int _selectedDayIndex = DateTime.now().weekday - 1;
  DateTime _selectedJournalDate = DateTime.now();
  DateTime _journalMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final habitsJson = prefs.getStringList('habits') ?? [];
    final scheduleJson = prefs.getStringList('schedule') ?? [];
    final journalJson = prefs.getStringList('journal') ?? [];

    setState(() {
      _habits
        ..clear()
        ..addAll(
            habitsJson.map((value) => HabitItem.fromJson(jsonDecode(value))));
      _scheduleItems
        ..clear()
        ..addAll(scheduleJson
            .map((value) => ScheduleItem.fromJson(jsonDecode(value))));
      _journalEntries
        ..clear()
        ..addAll(journalJson
            .map((value) => JournalEntry.fromJson(jsonDecode(value))));

      if (_habits.isEmpty) {
        _habits.addAll([
          HabitItem(
              id: '1',
              title: 'Morning stretch',
              isDone: true,
              mood: 'Great',
              reason: 'Fresh start'),
          HabitItem(
              id: '2',
              title: 'Drink 2L water',
              mood: 'Okay',
              reason: 'Needed energy'),
          HabitItem(
              id: '3',
              title: 'Read 20 pages',
              mood: 'Calm',
              reason: 'Relaxing evening'),
        ]);
      }

      if (_scheduleItems.isEmpty) {
        _scheduleItems.addAll([
          ScheduleItem(
              id: '1',
              title: 'Workout',
              time: '07:00',
              day: 'Mon',
              duration: '45 min',
              mood: 'Energized',
              reason: 'Boosted my focus'),
          ScheduleItem(
              id: '2',
              title: 'Design review',
              time: '10:30',
              day: 'Wed',
              duration: '30 min',
              mood: 'Focused',
              reason: 'Needed clarity'),
          ScheduleItem(
              id: '3',
              title: 'Evening walk',
              time: '19:00',
              day: 'Fri',
              duration: '60 min',
              mood: 'Relaxed',
              reason: 'Fresh air'),
        ]);
      }

      if (_journalEntries.isEmpty) {
        _journalEntries.addAll([
          JournalEntry(
            id: '1',
            title: 'Today’s reflection',
            content: 'Wrote down how I felt and what mattered today.',
            createdAt: DateTime.now().toString(),
          ),
        ]);
      }

      _isLoading = false;
    });

    await _persistData();
  }

  String _shortPreview(String text) {
    if (text.length <= 70) return text;
    return '${text.substring(0, 67)}...';
  }

  Future<void> _updateWidgetData() async {
    final today = _dateOnly(DateTime.now());
    final todayEntries = _journalEntries
        .where((entry) => _sameDate(_entryDate(entry), today))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final dateLabel = '${[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ][today.weekday - 1]}, ${_monthName(today.month)} ${today.day}';
    final countLabel =
        todayEntries.length == 1 ? '1 entry' : '${todayEntries.length} entries';
    final title = todayEntries.isEmpty ? 'Journal' : todayEntries.first.title;
    final preview = todayEntries.isEmpty
        ? 'No journal entries today — tap to add one.'
        : _shortPreview(todayEntries.first.content);
    final summary = todayEntries.isEmpty
        ? 'No entries yet'
        : '${todayEntries.first.title}\n$preview';

    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_date', dateLabel);
    await HomeWidget.saveWidgetData<String>('widget_count', countLabel);
    await HomeWidget.saveWidgetData<String>('widget_summary', summary);
    await HomeWidget.updateWidget(name: 'HabitWidgetProvider');
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'habits',
      _habits.map((habit) => jsonEncode(habit.toJson())).toList(),
    );
    await prefs.setStringList(
      'schedule',
      _scheduleItems.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await prefs.setStringList(
      'journal',
      _journalEntries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    await NotificationService.cancelAll();
    for (final habit in _habits) {
      await NotificationService.scheduleHabitReminder(habit);
    }
    for (final item in _scheduleItems) {
      await NotificationService.scheduleScheduleReminder(item);
    }
    await _updateWidgetData();
  }

  Color _colorFromName(String name) {
    switch (name) {
      case 'teal':
        return Colors.teal;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'pink':
        return Colors.pink;
      case 'green':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    required IconData icon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.14),
                Theme.of(context).colorScheme.secondary.withOpacity(0.10),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.36)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 12,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorChooser(
      String selectedColor, ValueChanged<String> onChanged) {
    final options = [
      {'value': 'teal', 'label': 'Teal', 'color': Colors.teal},
      {'value': 'blue', 'label': 'Blue', 'color': Colors.blue},
      {'value': 'purple', 'label': 'Purple', 'color': Colors.purple},
      {'value': 'orange', 'label': 'Orange', 'color': Colors.orange},
      {'value': 'pink', 'label': 'Pink', 'color': Colors.pink},
      {'value': 'green', 'label': 'Green', 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedColor == option['value'];
            return ChoiceChip(
              label: Text(option['label'] as String),
              selected: isSelected,
              avatar: CircleAvatar(
                radius: 10,
                backgroundColor: option['color'] as Color,
                child: const SizedBox.shrink(),
              ),
              onSelected: (_) => onChanged(option['value'] as String),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _showHabitDialog({HabitItem? habit}) async {
    final controller = TextEditingController(text: habit?.title ?? '');
    final moodController = TextEditingController(text: habit?.mood ?? 'Okay');
    final reasonController = TextEditingController(text: habit?.reason ?? '');
    String selectedColor = habit?.color ?? 'teal';
    bool notificationEnabled = habit?.notificationEnabled ?? false;
    bool alarmEnabled = habit?.alarmEnabled ?? false;
    String reminderTime = habit?.reminderTime ?? '08:00';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(habit == null ? 'Add habit' : 'Edit habit'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'Habit name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: moodController,
                        decoration: const InputDecoration(labelText: 'Mood'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: 12),
                      _buildColorChooser(selectedColor, (value) {
                        setDialogState(() => selectedColor = value);
                      }),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reminder notification'),
                        subtitle:
                            const Text('Receive a reminder for this habit'),
                        value: notificationEnabled,
                        onChanged: (value) {
                          setDialogState(() => notificationEnabled = value);
                        },
                      ),
                      if (notificationEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm_outlined),
                          title: const Text('Reminder time'),
                          subtitle: Text(reminderTime),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: dialogContext,
                              initialTime: _parseTime(reminderTime),
                            );
                            if (picked != null) {
                              setDialogState(() =>
                                  reminderTime = picked.format(dialogContext));
                            }
                          },
                        ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Alarm sound'),
                        subtitle: const Text('Optional alarm for this habit'),
                        value: alarmEnabled,
                        onChanged: (value) {
                          setDialogState(() => alarmEnabled = value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) return;

                setState(() {
                  if (habit == null) {
                    _habits.add(HabitItem(
                      id: DateTime.now().toString(),
                      title: title,
                      mood: moodController.text.trim().isEmpty
                          ? 'Okay'
                          : moodController.text.trim(),
                      reason: reasonController.text.trim(),
                      color: selectedColor,
                      notificationEnabled: notificationEnabled,
                      alarmEnabled: alarmEnabled,
                      reminderTime: reminderTime,
                    ));
                  } else {
                    habit.title = title;
                    habit.mood = moodController.text.trim().isEmpty
                        ? 'Okay'
                        : moodController.text.trim();
                    habit.reason = reasonController.text.trim();
                    habit.color = selectedColor;
                    habit.notificationEnabled = notificationEnabled;
                    habit.alarmEnabled = alarmEnabled;
                    habit.reminderTime = reminderTime;
                  }
                });

                _persistData();
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showScheduleDialog({ScheduleItem? item}) async {
    final controller = TextEditingController(text: item?.title ?? '');
    final durationController =
        TextEditingController(text: item?.duration ?? '45 min');
    final moodController = TextEditingController(text: item?.mood ?? 'Okay');
    final reasonController = TextEditingController(text: item?.reason ?? '');
    TimeOfDay selectedTime =
        item != null ? _parseTime(item.time) : TimeOfDay.now();
    String selectedDay = item?.day ?? _weekdays[_selectedDayIndex];
    String selectedColor = item?.color ?? 'blue';
    bool notificationEnabled = item?.notificationEnabled ?? false;
    bool alarmEnabled = item?.alarmEnabled ?? false;
    String reminderTime = item?.reminderTime ?? '08:00';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
              item == null ? 'Add timetable event' : 'Edit timetable event'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'Event title'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedDay,
                        decoration: const InputDecoration(labelText: 'Day'),
                        items: _weekdays
                            .map((day) =>
                                DropdownMenuItem(value: day, child: Text(day)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                            hintText: 'Duration', labelText: 'Duration'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: moodController,
                        decoration: const InputDecoration(labelText: 'Mood'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: 12),
                      _buildColorChooser(selectedColor, (value) {
                        setDialogState(() => selectedColor = value);
                      }),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reminder notification'),
                        subtitle: const Text(
                            'Receive a reminder for this timetable event'),
                        value: notificationEnabled,
                        onChanged: (value) {
                          setDialogState(() => notificationEnabled = value);
                        },
                      ),
                      if (notificationEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm_outlined),
                          title: const Text('Reminder time'),
                          subtitle: Text(reminderTime),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: dialogContext,
                              initialTime: _parseTime(reminderTime),
                            );
                            if (picked != null) {
                              setDialogState(() =>
                                  reminderTime = picked.format(dialogContext));
                            }
                          },
                        ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Alarm sound'),
                        subtitle: const Text(
                            'Optional alarm for this timetable event'),
                        value: alarmEnabled,
                        onChanged: (value) {
                          setDialogState(() => alarmEnabled = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: const Text('Time'),
                        subtitle: Text(selectedTime.format(dialogContext)),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) return;

                setState(() {
                  if (item == null) {
                    _scheduleItems.add(
                      ScheduleItem(
                        id: DateTime.now().toString(),
                        title: title,
                        time: selectedTime.format(dialogContext),
                        day: selectedDay,
                        duration: durationController.text.trim().isEmpty
                            ? '45 min'
                            : durationController.text.trim(),
                        mood: moodController.text.trim().isEmpty
                            ? 'Okay'
                            : moodController.text.trim(),
                        reason: reasonController.text.trim(),
                        color: selectedColor,
                        notificationEnabled: notificationEnabled,
                        alarmEnabled: alarmEnabled,
                        reminderTime: reminderTime,
                      ),
                    );
                  } else {
                    item.title = title;
                    item.time = selectedTime.format(dialogContext);
                    item.day = selectedDay;
                    item.duration = durationController.text.trim().isEmpty
                        ? '45 min'
                        : durationController.text.trim();
                    item.mood = moodController.text.trim().isEmpty
                        ? 'Okay'
                        : moodController.text.trim();
                    item.reason = reasonController.text.trim();
                    item.color = selectedColor;
                    item.notificationEnabled = notificationEnabled;
                    item.alarmEnabled = alarmEnabled;
                    item.reminderTime = reminderTime;
                  }
                });

                _persistData();
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation({
    required String title,
    required VoidCallback onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this item?'),
          content: Text('Delete "$title"? This can’t be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHabitsView() {
    final completedHabits = _habits.where((habit) => habit.isDone).length;
    final progress = _habits.isEmpty ? 0.0 : completedHabits / _habits.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.58),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.92),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.84),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.34)),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.78),
                    blurRadius: 16,
                    offset: const Offset(-6, -6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Today’s focus',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$completedHabits of ${_habits.length} habits done',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.22),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionHeader(
          "Today's habits",
          'Keep your routine feeling fresh and light',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 12),
        if (_habits.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No habits yet. Add one to get started.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          ..._habits.map((habit) {
            final accent = _colorFromName(habit.color);
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.75),
                        blurRadius: 10,
                        offset: const Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: CheckboxListTile(
                    value: habit.isDone,
                    title: Text(
                      habit.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Mood: ${habit.mood}${habit.reason.isNotEmpty ? ' • ${habit.reason}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showHabitDialog(habit: habit),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _showDeleteConfirmation(
                            title: habit.title,
                            onConfirm: () {
                              setState(() {
                                _habits.remove(habit);
                              });
                              _persistData();
                            },
                          ),
                        ),
                      ],
                    ),
                    onChanged: (value) {
                      setState(() {
                        habit.isDone = value ?? false;
                      });
                      _persistData();
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildScheduleView() {
    final dayItems = _scheduleItems
        .where((item) => item.day == _weekdays[_selectedDayIndex])
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Weekly timetable',
          'Switch days and keep your routine visible',
          icon: Icons.schedule,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_weekdays.length, (index) {
            final day = _weekdays[index];
            final isSelected = index == _selectedDayIndex;
            return ChoiceChip(
              label: Text(day),
              selected: isSelected,
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.16),
              onSelected: (_) => setState(() => _selectedDayIndex = index),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (dayItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No timetable events for this day yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          ...dayItems.map((item) {
            final accent = _colorFromName(item.color);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.20)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        blurRadius: 10,
                        offset: const Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              item.time,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.duration} • ${item.mood}${item.reason.isNotEmpty ? ' • ${item.reason}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showScheduleDialog(item: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                _scheduleItems.remove(item);
                              });
                              _persistData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _entryDate(JournalEntry entry) {
    try {
      return _dateOnly(DateTime.parse(entry.createdAt));
    } catch (_) {
      return _dateOnly(DateTime.now());
    }
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysBefore = firstDay.weekday % 7;
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final totalCells = ((daysBefore + lastDay.day) / 7).ceil() * 7;

    return List.generate(totalCells, (index) {
      final dayOffset = index - daysBefore + 1;
      return DateTime(month.year, month.month, dayOffset);
    });
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
  }

  String _formatSelectedDate(DateTime date) {
    final weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    return '$weekday, ${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  Widget _buildJournalView() {
    final selectedEntries = _journalEntries
        .where((entry) => _sameDate(_entryDate(entry), _selectedJournalDate))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Calendar Notebook',
          'Capture thoughts and keep your month in view',
          icon: Icons.book_outlined,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _journalMonth = DateTime(
                              _journalMonth.year, _journalMonth.month - 1);
                          _selectedJournalDate = DateTime(
                              _journalMonth.year, _journalMonth.month, 1);
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        '${_monthName(_journalMonth.month)} ${_journalMonth.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _journalMonth = DateTime(
                              _journalMonth.year, _journalMonth.month + 1);
                          _selectedJournalDate = DateTime(
                              _journalMonth.year, _journalMonth.month, 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                  children: [
                    for (final day in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                      Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    for (final date in _daysInMonth(_journalMonth))
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _selectedJournalDate = _dateOnly(date);
                            _journalMonth = DateTime(date.year, date.month);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _sameDate(
                                    _dateOnly(date), _selectedJournalDate)
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: date.month == _journalMonth.month
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Colors.transparent,
                            ),
                            boxShadow:
                                _sameDate(_dateOnly(date), _selectedJournalDate)
                                    ? [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.16),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${date.day}'),
                              if (_journalEntries.any((entry) => _sameDate(
                                  _entryDate(entry), _dateOnly(date))))
                                Icon(
                                  Icons.bubble_chart,
                                  size: 10,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatSelectedDate(_selectedJournalDate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          _showJournalDialog(initialDate: _selectedJournalDate),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedEntries.isEmpty)
                  Text(
                    'No entries for this day yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...selectedEntries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(entry.title),
                        subtitle: Text(entry.content),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showJournalDialog(entry: entry),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  _journalEntries.remove(entry);
                                });
                                _persistData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showJournalDialog(
      {JournalEntry? entry, DateTime? initialDate}) async {
    final titleController = TextEditingController(text: entry?.title ?? '');
    final contentController = TextEditingController(text: entry?.content ?? '');
    DateTime selectedDate = entry != null
        ? _entryDate(entry)
        : (initialDate ?? _selectedJournalDate);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              Text(entry == null ? 'New journal entry' : 'Edit journal entry'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(
                        '${_monthName(selectedDate.month)} ${selectedDate.day}, ${selectedDate.year}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 6,
                    decoration:
                        const InputDecoration(labelText: 'Write your thoughts'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) return;

                setState(() {
                  if (entry == null) {
                    _journalEntries.add(JournalEntry(
                      id: DateTime.now().toString(),
                      title: title,
                      content: content,
                      createdAt: selectedDate.toIso8601String(),
                    ));
                  } else {
                    entry.title = title;
                    entry.content = content;
                    entry.createdAt = selectedDate.toIso8601String();
                  }
                  _selectedJournalDate = selectedDate;
                  _journalMonth =
                      DateTime(selectedDate.year, selectedDate.month);
                });

                _persistData();
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? 'Habit Dashboard'
            : _selectedIndex == 1
                ? 'Timetable'
                : 'Journal Notebook'),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8F6FF), Color(0xFFFFFFFF)],
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: IndexedStack(
                  key: ValueKey<int>(_selectedIndex),
                  index: _selectedIndex,
                  children: [
                    _buildHabitsView(),
                    _buildScheduleView(),
                    _buildJournalView(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Timetable'),
          NavigationDestination(
              icon: Icon(Icons.book_outlined), label: 'Journal'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedIndex == 0) {
            _showHabitDialog();
          } else if (_selectedIndex == 1) {
            _showScheduleDialog();
          } else {
            _showJournalDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_selectedIndex == 0
            ? 'Add habit'
            : _selectedIndex == 1
                ? 'Add event'
                : 'Add entry'),
      ),
    );
  }
}

class HabitItem {
  HabitItem({
    required this.id,
    required this.title,
    this.isDone = false,
    this.mood = 'Okay',
    this.reason = '',
    this.color = 'teal',
    bool? notificationEnabled,
    bool? reminderEnabled,
    this.alarmEnabled = false,
    this.reminderTime = '08:00',
  }) : notificationEnabled = notificationEnabled ?? reminderEnabled ?? false;

  final String id;
  String title;
  bool isDone;
  String mood;
  String reason;
  String color;
  bool notificationEnabled;
  bool alarmEnabled;
  String reminderTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'mood': mood,
        'reason': reason,
        'color': color,
        'notificationEnabled': notificationEnabled,
        'alarmEnabled': alarmEnabled,
        'reminderTime': reminderTime,
      };

  factory HabitItem.fromJson(Map<String, dynamic> json) {
    return HabitItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
      mood: json['mood'] as String? ?? 'Okay',
      reason: json['reason'] as String? ?? '',
      color: json['color'] as String? ?? 'teal',
      notificationEnabled: json['notificationEnabled'] as bool? ?? false,
      alarmEnabled: json['alarmEnabled'] as bool? ?? false,
      reminderTime: json['reminderTime'] as String? ?? '08:00',
    );
  }
}

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.title,
    required this.time,
    this.day = 'Mon',
    this.duration = '45 min',
    this.mood = 'Okay',
    this.reason = '',
    this.color = 'blue',
    bool? notificationEnabled,
    bool? reminderEnabled,
    this.alarmEnabled = false,
    this.reminderTime = '08:00',
  }) : notificationEnabled = notificationEnabled ?? reminderEnabled ?? false;

  final String id;
  String title;
  String time;
  String day;
  String duration;
  String mood;
  String reason;
  String color;
  bool notificationEnabled;
  bool alarmEnabled;
  String reminderTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time,
        'day': day,
        'duration': duration,
        'mood': mood,
        'reason': reason,
        'color': color,
        'notificationEnabled': notificationEnabled,
        'alarmEnabled': alarmEnabled,
        'reminderTime': reminderTime,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      title: json['title'] as String,
      time: json['time'] as String,
      day: json['day'] as String? ?? 'Mon',
      duration: json['duration'] as String? ?? '45 min',
      mood: json['mood'] as String? ?? 'Okay',
      reason: json['reason'] as String? ?? '',
      color: json['color'] as String? ?? 'blue',
      notificationEnabled: json['notificationEnabled'] as bool? ?? false,
      alarmEnabled: json['alarmEnabled'] as bool? ?? false,
      reminderTime: json['reminderTime'] as String? ?? '08:00',
    );
  }
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final String id;
  String title;
  String content;
  String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}
