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
  bool indivisible;
  List<Session> sessions;
  double weight;
  scheduled status;

  Item({this.id, this.name, this.duration, this.dueDate, this.priority});

  static Item copy(Item oldItem) {
    Item i = Item();
    i.id = DateTime.now().millisecondsSinceEpoch.toString()+'-c';
    i.name = "COPY - "+oldItem.name;
    i.duration = oldItem.duration;
    i.dueDate = oldItem.dueDate;
    i.priority = oldItem.priority;
    i.status = oldItem.status;
    i.earliestStart = oldItem.earliestStart;
    i.indivisible = oldItem.indivisible;
    return i;
}

  Item.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        duration = json['duration'] as int,
        dueDate = json['dueDate'] as int,
        priority = importance.values[json['priority']],
        earliestStart = json['earliestStart'] as int,
        indivisible = json['indivisible'] as bool,
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
      'indivisible': indivisible,
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
  switch (xConfiguration.calendarType) {
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
  // Need to know when "now" is
  final int today = (DateTime.now()).millisecondsSinceEpoch;
  // List of items to be scheduled - copied and filtered from "xItems"
  List<Item> _sItems = [];
  // List of overdue items
  List<Item> _oItems = [];
  // Filter items to separate overdue items
  for (int i=0; i<xItems.length; i++) {
    if (xItems[i].dueDate>=today) {
      _sItems.add(xItems[i]);
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
  consolePrint("Requesting slots");
  await xCalendar.getFreeBlocks(startDate,DateTime.fromMillisecondsSinceEpoch(lastDueDate)).then((_freeSlots) {
//  await xCalendar.getFreeBlocks(startDate,startDate.add(new Duration(days: 7))).then((_freeSlots) {
    consolePrint("Received slots");
    for (int i=0; i<_freeSlots.length; i++) {
      consolePrint("    "+DateTime.fromMillisecondsSinceEpoch(_freeSlots[i].startTime).toString()+" - "+(_freeSlots[i].duration/60000).toString()+" min");
    }
    // If overdue scheduling is "first", do it
    if (xConfiguration.overdueScheduling=="first") {
      consolePrint('Doing overdue scheduling first');
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
    }
    // Slots need to be in specified order
    if (xConfiguration.scheduling=="soonest") {
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
    } else {
      _freeSlots.sort((x,y) => -x.startTime.compareTo(y.startTime));
    }
    // Schedule items in order
    consolePrint('Scheduling items');
    _scheduleItems(_freeSlots,_sItems);
    // If overdue scheduling is "last", do it
    if (xConfiguration.overdueScheduling=="last") {
      consolePrint('Doing overdue scheduling last');
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
    }
    // Check for unscheduled items and attempt to schedule them
    for (int i=0; i<_sItems.length; i++) {
      if (_sItems[i].status == scheduled.ERROR) {
        _scheduleConflictedItem(_freeSlots, _sItems[i]);
      }
    }
    for (int i=0; i<_oItems.length; i++) {
      if (_oItems[i].status == scheduled.ERROR) {
        _scheduleConflictedItem(_freeSlots, _oItems[i]);
      }
    }
    // Change status of items that will complete after the due date from OK to SCHEDLUED_LATE
    for (int i=0; i<_sItems.length; i++) {
      if (_sItems[i].sessions!=null) {
        if (_sItems[i].sessions[0].startTime+_sItems[i].sessions[0].duration > _sItems[i].dueDate) {
          _sItems[i].status = scheduled.SCHEDULED_LATE;
        }
      }
    }
    for (int i=0; i<_oItems.length; i++) {
      if (_oItems[i].sessions!=null) {
        if (_oItems[i].sessions[0].startTime+_oItems[i].sessions[0].duration > _oItems[i].dueDate) {
          _oItems[i].status = scheduled.SCHEDULED_LATE;
        }
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

  void _scheduleItems(List<OpenBlock> _slots, List<Item> _items, {durationOnly: false}) {
    for (int i=0; i<_items.length; i++) {
      consolePrint('    Item '+_items[i].name+" due at "+DateTime.fromMillisecondsSinceEpoch(_items[i].dueDate).toString());
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
        consolePrint('    -> no slot found');
        _items[i].sessions = null;
        _items[i].status = scheduled.ERROR;
        continue;
      }
      consolePrint('    -> slot found at '+DateTime.fromMillisecondsSinceEpoch(_slots[_selectedSlot].startTime).toString());
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
          if (_slots[_selectedSlot].startTime==_items[i].sessions[0].startTime) {
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
     consolePrint("Remaining slots");
    for (int i=0; i<_slots.length; i++) {
      consolePrint("    "+DateTime.fromMillisecondsSinceEpoch(_slots[i].startTime).toString()+" - "+(_slots[i].duration/60000).toString()+" min");
    }
   }
}

void _scheduleConflictedItem (List<OpenBlock> _slots, Item item) {
  // Right now we can only try to break an item into multiple sessions which can be scheduled
  // If that isn't allowed (the "indivisble" property of the item is true), just return
  if (item.indivisible) {
    return;
  } else {
    // Shortest session per configuration or 30 minutes if not configured
    int _shortestSession = ((xConfiguration.minimumSession > 0) ? xConfiguration.minimumSession : 30) * ONE_MINUTE;
    // Use slots starting from earliest
    _slots.sort((x,y) => x.startTime.compareTo(y.startTime));
    item.sessions = [];
    for (int restDuration=item.duration, i=0, sNumber=0; i<_slots.length; i++,sNumber++) {
      if (_slots[i].duration>=_shortestSession) {
        if (restDuration<_slots[i].duration) {
          item.sessions.add(new Session());
          item.sessions[sNumber].startTime = _slots[i].startTime;
          item.sessions[sNumber].duration = restDuration;
          if (_slots[i].duration == restDuration) {
            _slots.remove(_slots[i]);
          } else {
            _slots[i].duration -= restDuration;
          }
          restDuration = 0;
        } else {
          item.sessions.add(new Session());
          item.sessions[sNumber].startTime = _slots[i].startTime;
          item.sessions[sNumber].duration = _slots[i].duration;
          restDuration -= _slots[i].duration;
          _slots.remove(_slots[i]);
        }
        // If no time remains in the item, we're done
        if (restDuration == 0) {
          item.status = scheduled.SCHEDULED_OK;
          break;
        }
      }
    }
  }
}