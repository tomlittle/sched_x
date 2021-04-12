library sched_x.global;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sched_x/globals.dart';

// Global variables
List<Item> xItems = []; // List of items to be scheduled - this list drives EVERYTHING

// Type definitions
enum dueType { HARD, SOFT }
enum importance {VERY_HIGH, HIGH, NORMAL, LOW}
// UI stuff for the enum type "importance"
final List<String> importanceText = ['very high','high','normal','low'];
final List<IconData> importanceIcon = [
  IconData(58804, fontFamily: 'MaterialIcons'),
  IconData(61565, fontFamily: 'MaterialIcons'),
  IconData(61571, fontFamily: 'MaterialIcons'),
  IconData(61566, fontFamily: 'MaterialIcons'),
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

  Item({this.id, this.name, this.duration, this.dueDate, this.priority});

  Item.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        duration = json['duration'] as int,
        dueDate = json['dueDate'] as int,
        priority = importance.values[json['priority']];

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
// Blocks of available time in the calendar
class OpenBlock {
  int startTime;
  int duration;
}

List<OpenBlock> getAvailableSlots () {
  // !!! Code to fake free blocks of time for PoC
  // !!! 4 hours from 1 PM every day from today for a week
  List<OpenBlock> _slots = [];
  DateTime _today = DateTime.now();
  DateTime _startTime = DateTime(_today.year,_today.month,_today.day,13);
  for (int _n=0; _n<7; _n++) {
    _slots.add(new OpenBlock());
    _slots[_n].startTime = (_startTime.add(Duration(days: _n))).millisecondsSinceEpoch;
    _slots[_n].duration = ONE_HOUR * 4;
  }
  return _slots;
}

void reschedule (bool slotsFromEarliest) {
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
      }
    }
  }
  // Additonal data for debugging scheduling (<-> _sItems)
  List<ItemScheduleProperties> _sProps = [];
  // Blocks of free time avilable to scheduler - sorted earliest to latest
  List<OpenBlock> _slots = getAvailableSlots();
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
 // Schedule items in order
  // Slots need to be in order
  if (slotsFromEarliest) {
    _slots.sort((x,y) => x.startTime.compareTo(y.startTime));
  } else {
    _slots.sort((x,y) => -x.startTime.compareTo(y.startTime));
  }
  for(int i=0; i<_sItems.length; i++) {
    _sItems[i].sessions = [];
    // Get earliest block that fits
    int _selectedSlot = -1;
    for (var j=0; j<_slots.length; j++) {
      if (_slots[j].startTime+_slots[j].duration <= _sItems[i].dueDate) {
        if (_slots[j].duration >= _sItems[i].duration) {
          _selectedSlot = j;
          break;
        }
      }
    }
    // Add session to item, set session if we found a slot
    _sItems[i].sessions.add(new Session());
    if (_selectedSlot==-1) {
      break;
    }
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
}
