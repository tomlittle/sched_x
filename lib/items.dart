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
  {"icon": IconData(Icons.check.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.green},
  {"icon": IconData(Icons.check.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": IconData(Icons.watch_later_outlined .codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": null,"color": null},
  {"icon": IconData(Icons.dnd_forwardslash.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red},
];
enum urgency {HIGH, NORMAL, LOW}
final List<String> urgencyText = ['high','normal','low'];
final List urgencyIcon = [
  {"icon": IconData(Icons.label_important_rounded.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red},
  {"icon": IconData(Icons.label_outline_rounded.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.green},
  {"icon": IconData(Icons.label_off_outlined.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.grey},
];
enum importance {VERY_HIGH, HIGH, NORMAL, LOW}
// UI stuff for the enum type "importance"
final List<String> importanceText = ['very high','high','normal','low'];
final List<IconData> importanceIcon = [
  IconData(Icons.star.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.arrow_circle_up.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.remove_circle_outline.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.arrow_circle_down.codePoint, fontFamily: 'MaterialIcons'),
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
  int earliestStart;
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
        earliestStart = json['earliestStart'] as int,
        status = scheduled.NOTYET;
        
  Map<String, dynamic> toJson() =>
    {
      'id': id,
      'name': name,
      'duration': duration,
      'dueDate': dueDate,
      // 'deadlineType': null,
      'priority': priority.index,
      'earliestStart': earliestStart,
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

Future<void> reschedule () async {
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
  // List of overdue items
  List<Item> _oItems = [];
  // Filter items to separate overdue items
  for (int i=0; i<xItems.length; i++) {
    if (xItems[i].dueDate>=today) {
      // !!! Remove items longer than slots - this is a temporary filter for the PoC, will use divisibility later
      if (xItems[i].duration<=maxItemLength) {
        _sItems.add(xItems[i]);
      } else {
        xItems[i].status = scheduled.ERROR;
      }
    } else {
      _oItems.add(xItems[i]);
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
  await xCalendar.getFreeBlocks(startDate,DateTime.fromMillisecondsSinceEpoch(lastDueDate)).then((_freeSlots) {
//  await xCalendar.getFreeBlocks(startDate,startDate.add(new Duration(days: 7))).then((_freeSlots) {
    print("Recevied slots");
    for (int i=0; i<_freeSlots.length; i++) {
      print("    "+DateTime.fromMillisecondsSinceEpoch(_freeSlots[i].startTime).toString()+" - "+(_freeSlots[i].duration/60000).toString());
    }
    // If overdue scheduling is "first", do it
    if (XConfiguration.overdueScheduling=="first") {
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
    }
    // Slots need to be in specified order
    if (XConfiguration.scheduling=="soonest") {
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
    } else {
      _freeSlots.sort((x,y) => -x.startTime.compareTo(y.startTime));
    }
    // Schedule items in order
    _scheduleItems(_freeSlots,_sItems);
    // If overdue scheduling is "last", do it
    if (XConfiguration.overdueScheduling=="last") {
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
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

void _scheduleItems(List<OpenBlock> _slots, List<Item> _items, {durationOnly: false}) {
    for (int i=0; i<_items.length; i++) {
      _items[i].sessions = [];
      _items[i].status = scheduled.NOTYET;
      // Get first block that fits
      int _selectedSlot = -1;
      for (int j=0; j<_slots.length; j++) {
        if (_slots[j].duration >= _items[i].duration) {
          if (!durationOnly) {
            if (_slots[j].startTime+_slots[j].duration <= _items[i].dueDate) {
              // If the item has an earliest start, check it
              if (_items[i].earliestStart!=null) {
                if(_slots[j].startTime+_slots[j].duration-_items[i].duration>=_items[i].earliestStart) {
                  _selectedSlot = j;
                  break;
                }
              } else {
                _selectedSlot = j;
                break;
              }  // Earliest start
            } // Due date
          } // Duration only
          else {
            _selectedSlot = j;
            break;
          }
        }  // Duration 
      }
      // Leave session list empty (null) if no slot available
      if (_selectedSlot==-1) {
        _items[i].sessions = null;
        _items[i].status = scheduled.ERROR;
        break;
      }
      // Add session to item
      _items[i].sessions.add(new Session());
      _items[i].status = scheduled.SCHEDULED_OK;
      // Schedule item, modify block list
      _items[i].sessions[0].duration = _items[i].duration;
      if (_items[i].earliestStart!=null) {
        _items[i].sessions[0].startTime= _slots[_selectedSlot].startTime < _items[i].earliestStart ?
                                          _items[i].earliestStart : _slots[_selectedSlot].startTime;
      } else {
        _items[i].sessions[0].startTime= _slots[_selectedSlot].startTime;
      }
      // If the whole slot was used, remove it, otherwise shorten or split it
      if (_slots[_selectedSlot].duration==_items[i].duration) {
        _slots.remove(_slots[_selectedSlot]);
      } else {
          // Remove from the start...
          if (_slots[_selectedSlot].startTime==_items[i].earliestStart) {
            _slots[_selectedSlot].startTime += _items[i].duration;
            _slots[_selectedSlot].duration -= _items[i].duration;
          // ...or from the end...
          } else if (_items[i].sessions[0].startTime+_items[i].sessions[0].duration==
                     _slots[_selectedSlot].startTime+_slots[_selectedSlot].duration) {
            _slots[_selectedSlot].duration -= _items[i].sessions[0].duration;
          // ...or split the slot into two remaining slots
          } else {
                  int _temp = _slots[_selectedSlot].duration;
                  _slots[_selectedSlot].duration = _slots[_selectedSlot].startTime-_items[i].sessions[0].startTime;
                  OpenBlock _newSlot = new OpenBlock();
                  _newSlot.startTime = _items[i].sessions[0].startTime+_items[i].sessions[0].duration;
                  _newSlot.duration = _temp+_slots[_selectedSlot].startTime-_newSlot.startTime;
                  _slots.insert(_selectedSlot+1,_newSlot);
          }
      }
    }
}