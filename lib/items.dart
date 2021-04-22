library sched_x.global;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sched_x/globals.dart';
import 'package:sched_x/simulatedCalendar.dart';
import 'package:sched_x/googleCalendar.dart';

// Global variables
List<Item> xItems = []; // List of items to be scheduled - this list drives EVERYTHING

// Type definitions
enum scheduled {SCHEDULED_OK, SCHEDULED_LATE, NOT_SCHEDULED, NOTYET, ERROR}
final List scheduledIcon = [
  {"icon": IconData(58956, fontFamily: 'MaterialIcons'),"color": Colors.green},
  {"icon": IconData(58956, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": IconData(58631, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": null,"color": null},
  {"icon": IconData(59078, fontFamily: 'MaterialIcons'),"color": Colors.red},
];
enum urgency {HIGH, NORMAL, LOW}
final List<String> urgencyText = ['high','normal','low'];
final List urgencyIcon = [
  {"icon": IconData(62099, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": IconData(62101, fontFamily: 'MaterialIcons'),"color": Colors.green},
  {"icon": IconData(57955, fontFamily: 'MaterialIcons'),"color": Colors.grey},
];
enum importance {VERY_HIGH, HIGH, NORMAL, LOW}
// UI stuff for the enum type "importance"
final List<String> importanceText = ['very high','high','normal','low'];
final List<IconData> importanceIcon = [
  IconData(59938, fontFamily: 'MaterialIcons'),
  IconData(58794, fontFamily: 'MaterialIcons'),
  IconData(59760, fontFamily: 'MaterialIcons'),
  IconData(58793, fontFamily: 'MaterialIcons'),
];
final List<DropdownMenuItem> importanceList = [
  DropdownMenuItem(
    child: Text('very high'),
    value: importance.VERY_HIGH,
  ),
  DropdownMenuItem(
    child: Text('high'),
    value: importance.HIGH,
  ),
  DropdownMenuItem(
    child: Text('normal'),
    value: importance.NORMAL,
  ),
  DropdownMenuItem(
    child: Text('low'),
    value: importance.LOW,
  ),
];

// The classes that define items to be scheduled and their schedules
class Item {
  String id;
  String name;
  int duration;
  int dueDate;
  // dueType deadlineType;
  importance priority;
  // int earliestStart;
  // bool indivisible;
  List<Session> sessions;
  double weight;
  scheduled status;

  Item({this.id, this.name, this.duration, this.dueDate, this.priority});

  Item.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        duration = json['duration'] as int,
        dueDate = json['dueDate'] as int,
        priority = importance.values[json['priority']],
        status = scheduled.NOTYET;
        
  Map<String, dynamic> toJson() =>
    {
      'id': id,
      'name': name,
      'duration': duration,
      'dueDate': dueDate,
      // 'deadlineType': null,
      'priority': priority.index,
      // 'earliestStart': null,
      // 'indivisible': null,
      // 'sessions': null,
    };
}
// "Items" are schedlued in one or more "Sessions"
 class Session {
  int startTime;
  int duration;
}
// Helper properties during scheduling (helpful for debugging the algorithm)
class ItemScheduleProperties {
  double priorityFactor;
  double deadlineFactor;
}

Future<void> reschedule (bool slotsFromEarliest) async {
  XCalendar xCalendar;
  switch (XConfiguration.calendarType) {
    case "google":
      xCalendar = GoogleCalendar();
      break;
    case "simulated":
      xCalendar = SimCalendar();
      break;
    default:
      xCalendar = SimCalendar();
      break;
  }
  // !!! Arbitrary constant for PoC sets maximum item length
  const int maxItemLength = 4 * ONE_HOUR;
  // Need to know when "now" is
  final int today = (DateTime.now()).millisecondsSinceEpoch;
  // List of items to be scheduled - copied and filtered from "xItems"
  List<Item> _sItems = [];
  // Filter items to remove overdue items
  for (int i=0; i<xItems.length; i++) {
    if (xItems[i].dueDate>=today) {
      // !!! Remove items longer than slots - this is a temporary filter for the PoC, will be removed later
      if (xItems[i].duration<=maxItemLength) {
        _sItems.add(xItems[i]);
      } else {
        xItems[i].status = scheduled.ERROR;
      }
    } else {
      xItems[i].status = scheduled.NOT_SCHEDULED;
    }
  }
  // Additonal data for debugging scheduling (<-> _sItems)
  List<ItemScheduleProperties> _sProps = [];
  // Find latest due date to establish range for scheduling
  int lastDueDate = 0;
  for (int i=0; i<_sItems.length; i++) {
    if (_sItems[i].dueDate>lastDueDate) {
      lastDueDate = _sItems[i].dueDate;
    }
  }
  // Calculate size of range based on last due date, scale down
  // We'll use the range for both deadlines and priorities
  const scaleFactor = 1000000;
  double range = (lastDueDate-today) / scaleFactor;
  // Calculate properties of each item
  // "weight" controls scheduling order, "heaviest" item is scheduled first
  for (int i=0; i<_sItems.length; i++) {
    _sProps.add(new ItemScheduleProperties());
    _sProps[i].priorityFactor = (3-_sItems[i].priority.index) / 3 * range;
    _sProps[i].deadlineFactor = (lastDueDate-_sItems[i].dueDate) / scaleFactor;
    _sItems[i].weight = _sProps[i].priorityFactor + _sProps[i].deadlineFactor;
  }
  _sItems.sort((x,y) => -(x.weight.compareTo(y.weight)));
  // Blocks of free time avilable to scheduler - sorted earliest to latest
  DateTime startDate = DateTime.now();
  print("Requesting slots");
  await xCalendar.getFreeBlocks(startDate,startDate.add(new Duration(days: 7))).then((_slots) {
    print("Recevied slots");
    for (int i=0; i<_slots.length; i++) {
      print("    "+DateTime.fromMillisecondsSinceEpoch(_slots[i].startTime).toString()+" - "+(_slots[i].duration/60000).toString());
    }
    // Slots need to be in order
    if (slotsFromEarliest) {
      _slots.sort((x,y) => x.startTime.compareTo(y.startTime));
    } else {
      _slots.sort((x,y) => -x.startTime.compareTo(y.startTime));
    }
    // Schedule items in order
    for (int i=0; i<_sItems.length; i++) {
      _sItems[i].sessions = [];
      _sItems[i].status = scheduled.NOTYET;
      // Get earliest block that fits
      int _selectedSlot = -1;
      for (int j=0; j<_slots.length; j++) {
        if (_slots[j].startTime+_slots[j].duration <= _sItems[i].dueDate) {
          if (_slots[j].duration >= _sItems[i].duration) {
            _selectedSlot = j;
            break;
          }
        }
      }
      // Leave session list empty (null) if no slot available
      if (_selectedSlot==-1) {
        _sItems[i].sessions = null;
        _sItems[i].status = scheduled.ERROR;
        break;
      }
      // Add session to item
      _sItems[i].sessions.add(new Session());
      _sItems[i].status = scheduled.SCHEDULED_OK;
      // Schedule item, modify block list
      _sItems[i].sessions[0].duration = _sItems[i].duration;
      _sItems[i].sessions[0].startTime = _slots[_selectedSlot].startTime;
      // If the whole slot was used, remove it, otherwise shorten it
      if (_slots[_selectedSlot].duration==_sItems[i].duration) {
        _slots.remove(_slots[_selectedSlot]);
      } else {
        _slots[_selectedSlot].startTime += _sItems[i].duration;
        _slots[_selectedSlot].duration -= _sItems[i].duration;
      }
    }
    // Move schedule entries to master list of items
    for (int i=0; i<_sItems.length; i++) {
      Item target = xItems.firstWhere((element) => 
            element.id == _sItems[i].id,
            orElse: () {
              return null;
            });
      if (target != null) {
        target.sessions =_sItems[i].sessions;
      }
    }
  });
}